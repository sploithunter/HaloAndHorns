--[[
    ZoneUnlockPrompt — client prompt to unlock the biome you're standing in.

    Reads ZoneTrackerService's `CurrentArea` SSOT attribute: whenever you're in a biome that you
    haven't unlocked yet (and that has an unlock cost), a small bottom-centre panel appears with
    the cost and an Unlock button. Clicking fires Signals.UnlockZoneRequest; ZoneService validates
    server-side (prerequisite + currency), deducts, and republishes UnlockedAreasJson — which hides
    the panel. No map pads needed (works off CurrentArea), and a button (not the E key) avoids
    clashing with egg hatching.

    Purely a gameplay prompt; the real lockout is server-side (BreakableSpawner spawns no ore in a
    locked biome). UI is intentionally minimal — styling pass comes later.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local Signals = require(ReplicatedStorage.Shared.Network.Signals)
local Configs = ReplicatedStorage:WaitForChild("Configs")
local areasConfig = require(Configs:WaitForChild("areas"))
local currenciesConfig = require(Configs:WaitForChild("currencies"))

local ZoneUnlockPrompt = {}
local started = false

-- currency id -> emoji icon (for the cost label)
local function currencyIcon(id)
    for _, c in ipairs(currenciesConfig) do
        if c.id == id then
            return c.icon or ""
        end
    end
    return ""
end

local function zoneName(areaId)
    local z = areasConfig.zones and areasConfig.zones[areaId]
    return (z and z.display_name) or areaId
end

-- The unlock requirement for an area, or nil if it isn't a gated area.
local function unlockReq(areaId)
    local z = areasConfig.zones and areasConfig.zones[areaId]
    if not z or z.kind ~= "area" or type(z.unlock) ~= "table" then
        return nil
    end
    return z.unlock
end

local function formatAmount(n)
    n = tonumber(n) or 0
    if n >= 1000 then
        return string.format("%.1fK", n / 1000):gsub("%.0K", "K")
    end
    return tostring(n)
end

function ZoneUnlockPrompt.start()
    if started then
        return
    end
    started = true

    local player = Players.LocalPlayer

    -- unlocked-set membership (mirrors ZoneService): saved set (UnlockedAreasJson) + defaults.
    local function isUnlocked(areaId)
        local req = unlockReq(areaId)
        if not req or req.unlocked_by_default == true or not req.cost or req.cost <= 0 then
            return true -- free / starter / non-gated
        end
        local raw = player:GetAttribute("UnlockedAreasJson")
        if type(raw) == "string" and raw ~= "" then
            local ok, list = pcall(function()
                return HttpService:JSONDecode(raw)
            end)
            if ok and type(list) == "table" then
                for _, id in ipairs(list) do
                    if id == areaId then
                        return true
                    end
                end
            end
        end
        return false
    end

    -- === UI ===
    local gui = Instance.new("ScreenGui")
    gui.Name = "ZoneUnlockPrompt"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 40
    gui.Enabled = false
    gui.Parent = player:WaitForChild("PlayerGui")

    local frame = Instance.new("Frame")
    frame.AnchorPoint = Vector2.new(0.5, 1)
    frame.Position = UDim2.new(0.5, 0, 1, -120)
    frame.Size = UDim2.fromOffset(320, 96)
    frame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    frame.BackgroundTransparency = 0.2
    frame.BorderSizePixel = 0
    frame.Parent = gui
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = frame
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(255, 200, 90)
    stroke.Thickness = 2
    stroke.Transparency = 0.2
    stroke.Parent = frame

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -16, 0, 26)
    title.Position = UDim2.fromOffset(8, 8)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.TextSize = 16
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.Text = "🔒 Locked"
    title.Parent = frame

    local info = Instance.new("TextLabel")
    info.Name = "Info"
    info.Size = UDim2.new(1, -16, 0, 18)
    info.Position = UDim2.fromOffset(8, 32)
    info.BackgroundTransparency = 1
    info.Font = Enum.Font.Gotham
    info.TextSize = 12
    info.TextColor3 = Color3.fromRGB(220, 220, 220)
    info.Text = ""
    info.Parent = frame

    local button = Instance.new("TextButton")
    button.Name = "Unlock"
    button.AnchorPoint = Vector2.new(0.5, 1)
    button.Position = UDim2.new(0.5, 0, 1, -8)
    button.Size = UDim2.new(1, -16, 0, 32)
    button.BackgroundColor3 = Color3.fromRGB(70, 170, 90)
    button.TextColor3 = Color3.new(1, 1, 1)
    button.Font = Enum.Font.GothamBold
    button.TextSize = 15
    button.AutoButtonColor = true
    button.Text = "Unlock"
    button.Parent = frame
    local bcorner = Instance.new("UICorner")
    bcorner.CornerRadius = UDim.new(0, 8)
    bcorner.Parent = button

    local activeAreaId = nil

    local function refresh()
        local areaId = player:GetAttribute("CurrentArea")
        local req = areaId and unlockReq(areaId)
        if
            not areaId
            or not req
            or req.unlocked_by_default == true
            or not req.cost
            or isUnlocked(areaId)
        then
            gui.Enabled = false
            activeAreaId = nil
            return
        end
        activeAreaId = areaId
        title.Text = "🔒 " .. zoneName(areaId) .. " — locked"
        local icon = currencyIcon(req.currency)
        local needPrereq = req.required_zone and not isUnlocked(req.required_zone)
        if needPrereq then
            info.Text = "Unlock " .. zoneName(req.required_zone) .. " first"
            button.Text = "Locked"
            button.BackgroundColor3 = Color3.fromRGB(90, 90, 100)
            button.AutoButtonColor = false
        else
            info.Text = "Cost: " .. formatAmount(req.cost) .. " " .. icon
            button.Text = "Unlock — " .. formatAmount(req.cost) .. " " .. icon
            button.BackgroundColor3 = Color3.fromRGB(70, 170, 90)
            button.AutoButtonColor = true
        end
        gui.Enabled = true
    end

    button.Activated:Connect(function()
        if not activeAreaId then
            return
        end
        local req = unlockReq(activeAreaId)
        if req and req.required_zone and not isUnlocked(req.required_zone) then
            return -- prerequisite missing; button is inert
        end
        Signals.UnlockZoneRequest:FireServer({ zoneId = activeAreaId })
    end)

    -- Server result: flash failures; success arrives as an UnlockedAreasJson change (-> refresh).
    Signals.ZoneUnlockResult.OnClientEvent:Connect(function(result)
        if result and result.ok == false then
            info.Text = "Can't unlock: " .. tostring(result.reason or result.error or "unavailable")
            info.TextColor3 = Color3.fromRGB(255, 140, 140)
            task.delay(2, function()
                info.TextColor3 = Color3.fromRGB(220, 220, 220)
                refresh()
            end)
        end
    end)

    player:GetAttributeChangedSignal("CurrentArea"):Connect(refresh)
    player:GetAttributeChangedSignal("UnlockedAreasJson"):Connect(refresh)
    task.defer(refresh)
end

return ZoneUnlockPrompt
