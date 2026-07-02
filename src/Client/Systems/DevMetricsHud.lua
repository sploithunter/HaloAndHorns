--[[
    DevMetricsHud (client, Studio-only) — live balancing bars at the top of the screen.

    Three rolling 1-minute averages so numbers settle fast without waiting for a long build:
      ⚔ DPS        — sum of pet-hit `amount` (Combat_PetHit) over the last 60s / window
      💰 Coins/sec  — sum of positive coin-currency attribute deltas over the last 60s / window
      🐾 Pet Speed  — mean measured travel speed (studs/s) of the player's pets over the last 60s

    Pure dev tool: gated to Studio, reads only replicated data + the owner's hit signal. Bars
    auto-scale to each metric's running peak so they're always readable; the NUMBER is the point.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signals = require(ReplicatedStorage.Shared.Network.Signals)

local WINDOW = 60 -- rolling window seconds
local REFRESH = 0.25 -- bar refresh / sample cadence

local DevMetricsHud = {}
DevMetricsHud.__index = DevMetricsHud

local function clock()
    return os.clock()
end

-- A timestamped sample list with windowed sum + count (rebuilt each query — tiny N, dev-only).
local function windowed(buf)
    local cutoff = clock() - WINDOW
    local kept, sum = {}, 0
    for _, e in ipairs(buf) do
        if e.t >= cutoff then
            kept[#kept + 1] = e
            sum += e.v
        end
    end
    return sum, #kept, kept
end

local function isCoinAttr(name)
    name = string.lower(tostring(name))
    return name == "coins" or name:sub(-6) == "_coins"
end

function DevMetricsHud.start()
    if not RunService:IsStudio() then
        return -- dev-only overlay
    end
    local self = setmetatable({}, DevMetricsHud)
    self.player = Players.LocalPlayer
    self.t0 = clock()
    self.hits = {} -- {t, v=damage}
    self.coins = {} -- {t, v=coinGain}
    self.speeds = {} -- {t, v=avgPetSpeed}
    self.xp = {} -- {t, v=xpGain} (from XPTotal attr deltas; keeps moving at the level cap)
    self.peaks = { dps = 1, coins = 1, speed = 1, xp = 1 }
    self._lastCoinTotal = nil
    self._lastXpTotal = nil
    self._petPos = {} -- pet -> last position
    self._lastSample = clock()

    self:_build()
    self:_connect()
    return self
end

-- ---- UI -----------------------------------------------------------------

local function corner(inst, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 6)
    c.Parent = inst
end

function DevMetricsHud:_build()
    local gui = Instance.new("ScreenGui")
    gui.Name = "DevMetricsHud"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 100
    gui.Parent = self.player:WaitForChild("PlayerGui")
    self.gui = gui

    local panel = Instance.new("Frame")
    panel.Name = "Panel"
    panel.Size = UDim2.new(0, 240, 0, 108)
    panel.Position = UDim2.new(0, 8, 0, 64) -- top-left (below the Roblox topbar inset)
    panel.AnchorPoint = Vector2.new(0, 0)
    panel.BackgroundColor3 = Color3.fromRGB(18, 20, 28)
    panel.BackgroundTransparency = 0.2
    panel.BorderSizePixel = 0
    corner(panel, 8)
    panel.Parent = gui

    local pad = Instance.new("UIPadding")
    for _, s in ipairs({ "PaddingTop", "PaddingBottom", "PaddingLeft", "PaddingRight" }) do
        pad[s] = UDim.new(0, 6)
    end
    pad.Parent = panel
    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 4)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = panel

    self.rows = {}
    local function makeRow(key, label, color, order)
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, 20)
        row.BackgroundColor3 = Color3.fromRGB(34, 37, 50)
        row.BorderSizePixel = 0
        row.LayoutOrder = order
        corner(row, 4)
        row.Parent = panel
        local fill = Instance.new("Frame")
        fill.Name = "Fill"
        fill.Size = UDim2.new(0, 0, 1, 0)
        fill.BackgroundColor3 = color
        fill.BorderSizePixel = 0
        fill.ZIndex = 2
        corner(fill, 4)
        fill.Parent = row
        local text = Instance.new("TextLabel")
        text.Size = UDim2.new(1, -8, 1, 0)
        text.Position = UDim2.new(0, 6, 0, 0)
        text.BackgroundTransparency = 1
        text.Font = Enum.Font.GothamBold
        text.TextSize = 12
        text.TextXAlignment = Enum.TextXAlignment.Left
        text.TextColor3 = Color3.fromRGB(245, 245, 250)
        text.Text = label .. ": —"
        text.ZIndex = 3
        text.Parent = row
        self.rows[key] = { fill = fill, text = text, label = label }
    end
    makeRow("dps", "⚔ DPS", Color3.fromRGB(225, 90, 80), 1)
    makeRow("coins", "💰 Coins/s", Color3.fromRGB(240, 200, 70), 2)
    makeRow("speed", "🐾 Pet Spd", Color3.fromRGB(95, 180, 235), 3)
    makeRow("xp", "✨ XP/min", Color3.fromRGB(150, 110, 235), 4)
end

-- ---- data ---------------------------------------------------------------

function DevMetricsHud:_connect()
    -- DPS: owner-only per-hit signal carries the dealt `amount`.
    Signals.Combat_PetHit.OnClientEvent:Connect(function(data)
        local amt = data and tonumber(data.amount)
        if amt and amt > 0 then
            self.hits[#self.hits + 1] = { t = clock(), v = amt }
        end
    end)

    -- Coins/sec: positive deltas across coin-currency attributes.
    local function seedCoins()
        local total = 0
        for name, val in pairs(self.player:GetAttributes()) do
            if isCoinAttr(name) and type(val) == "number" then
                total += val
            end
        end
        return total
    end
    self._lastCoinTotal = seedCoins()
    self.player.AttributeChanged:Connect(function(name)
        if not isCoinAttr(name) then
            return
        end
        local total = seedCoins()
        local gain = total - (self._lastCoinTotal or total)
        self._lastCoinTotal = total
        if gain > 0 then
            self.coins[#self.coins + 1] = { t = clock(), v = gain }
        end
    end)

    -- XP/min: positive deltas of XPTotal (lifetime XP; keeps climbing past the level cap).
    self._lastXpTotal = tonumber(self.player:GetAttribute("XPTotal"))
    self.player:GetAttributeChangedSignal("XPTotal"):Connect(function()
        local total = tonumber(self.player:GetAttribute("XPTotal"))
        if not total then
            return
        end
        local gain = total - (self._lastXpTotal or total)
        self._lastXpTotal = total
        if gain > 0 then
            self.xp[#self.xp + 1] = { t = clock(), v = gain }
        end
    end)

    -- Pet speed sampling + bar refresh.
    self._accum = 0
    RunService.Heartbeat:Connect(function(dt)
        self._accum += dt
        if self._accum < REFRESH then
            return
        end
        local sampleDt = self._accum
        self._accum = 0
        self:_samplePetSpeed(sampleDt)
        self:_refresh()
    end)
end

function DevMetricsHud:_samplePetSpeed(dt)
    local pp = workspace:FindFirstChild("PlayerPets")
    local folder = pp and pp:FindFirstChild(self.player.Name)
    if not folder then
        return
    end
    local total, n = 0, 0
    for _, m in ipairs(folder:GetChildren()) do
        local bp = m.PrimaryPart or (m:IsA("Model") and m:FindFirstChildWhichIsA("BasePart"))
        if bp then
            local prev = self._petPos[m]
            if prev and dt > 0 then
                total += (bp.Position - prev).Magnitude / dt
                n += 1
            end
            self._petPos[m] = bp.Position
        end
    end
    if n > 0 then
        self.speeds[#self.speeds + 1] = { t = clock(), v = total / n }
    end
end

function DevMetricsHud:_refresh()
    local elapsed = math.max(1, math.min(WINDOW, clock() - self.t0))

    local hitSum, _, keptH = windowed(self.hits)
    self.hits = keptH
    local dps = hitSum / elapsed

    local coinSum, _, keptC = windowed(self.coins)
    self.coins = keptC
    local cps = coinSum / elapsed

    local spdSum, spdN, keptS = windowed(self.speeds)
    self.speeds = keptS
    local spd = spdN > 0 and (spdSum / spdN) or 0

    -- XP is reported per MINUTE (rates are small integers; reads better than per-second).
    local xpSum, _, keptX = windowed(self.xp)
    self.xp = keptX
    local xpPerMin = (xpSum / elapsed) * 60

    self:_setRow("dps", dps, string.format("%.0f", dps))
    self:_setRow("coins", cps, string.format("%.1f", cps))
    self:_setRow("speed", spd, string.format("%.0f", spd))
    self:_setRow("xp", xpPerMin, string.format("%.0f", xpPerMin))
end

function DevMetricsHud:_setRow(key, value, valueText)
    local row = self.rows[key]
    if not row then
        return
    end
    self.peaks[key] = math.max(self.peaks[key], value, 1)
    row.fill.Size = UDim2.new(math.clamp(value / self.peaks[key], 0, 1), 0, 1, 0)
    row.text.Text = string.format("%s: %s", row.label, valueText)
end

return DevMetricsHud
