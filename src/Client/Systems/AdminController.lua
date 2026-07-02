--[[
    AdminController (client) — one place to gate all the admin/dev overlays behind a single toggle.

    The dev overlays (DevSpawnPanel, DevMetricsHud, BuffStatsHud) used to be always-on in Studio,
    cluttering the play screen. Now they're HIDDEN by default and revealed by a small "🛠 ADMIN" chip
    in the lower-left — only visible to admins (player attribute IsAdmin) or in Studio.

    Toggling sets LocalPlayer attribute "AdminOverlaysOn" (the SoT other admin UI can read) and flips
    `.Enabled` on the overlay ScreenGuis by name. Default OFF → a clean screen for normal testing.

    Phase 1 of the HUD-restyle goal; later phases add the area/power toggles + kill button under the
    same chip and restyle it with the pill kit.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signals = require(ReplicatedStorage.Shared.Network.Signals)
local PowerFXProbe = require(script.Parent:WaitForChild("PowerFXProbe"))

local AdminController = {}
local started = false

-- Areas the area-cycle button rotates through (matches ZoneService ADMIN_AREAS).
local ADMIN_AREAS = { "Grass", "Desert", "Ice", "Lava", "Spawn" }

-- The dev/admin overlay ScreenGuis this chip shows/hides (by Name in PlayerGui).
local OVERLAYS = { "DevSpawnPanel", "DevMetricsHud", "BuffStatsHud", "PetSyncDiag" }

local function isAdmin(player)
    return RunService:IsStudio() or player:GetAttribute("IsAdmin") == true
end

local function setOverlays(pg, on)
    for _, name in ipairs(OVERLAYS) do
        local gui = pg:FindFirstChild(name)
        if gui and gui:IsA("ScreenGui") then
            gui.Enabled = on
        end
    end
end

function AdminController.start()
    if started then
        return
    end
    started = true
    local player = Players.LocalPlayer
    local pg = player:WaitForChild("PlayerGui")

    -- Wait for IsAdmin to replicate (data loads after boot) before deciding to show the chip.
    if not isAdmin(player) then
        local deadline = os.clock() + 15
        while os.clock() < deadline and player:GetAttribute("IsAdmin") == nil do
            task.wait(0.5)
        end
        if not isAdmin(player) then
            return -- not an admin: never build the chip, overlays stay as they were
        end
    end

    player:SetAttribute("AdminOverlaysOn", false)

    local gui = Instance.new("ScreenGui")
    gui.Name = "AdminController"
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 90
    gui.Parent = pg

    -- A UIGradient on a button tints the button's OWN text too, so put the label in a CHILD TextLabel
    -- (the gradient doesn't reach it) — that's how the coin pills read pure white over a colored fill.
    local function whiteLabel(btn, text, size)
        btn.Text = ""
        local l = Instance.new("TextLabel")
        l.Name = "Label"
        l.Size = UDim2.fromScale(1, 1)
        l.BackgroundTransparency = 1
        l.Font = Enum.Font.GothamBold
        l.TextSize = size or 13
        l.TextColor3 = Color3.fromRGB(255, 255, 255)
        l.Text = text
        l.ZIndex = (btn.ZIndex or 1) + 1
        l.Parent = btn
        return l
    end

    local chip = Instance.new("TextButton")
    chip.Name = "AdminToggle"
    chip.Size = UDim2.fromOffset(118, 30)
    -- bottom-right, stacked above the Rewards button (the old "gap right of the tray" spot
    -- lands inside the hotbar once the tray shrinks on small viewports)
    chip.Position = UDim2.new(1, -12, 1, -85)
    chip.AnchorPoint = Vector2.new(1, 1)
    chip.BackgroundColor3 = Color3.fromRGB(90, 55, 160) -- amethyst capsule (matches the currency pills)
    chip.BackgroundTransparency = 0
    chip.AutoButtonColor = true
    chip.Font = Enum.Font.GothamBold
    chip.TextSize = 13
    chip.TextColor3 = Color3.fromRGB(245, 240, 255)
    chip.Text = "🛠 ADMIN: OFF"
    -- pixel-designed chip: shrink on small viewports (UIViewportScale)
    require(script.Parent.Parent.UI.UIViewportScale).attach(chip)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = chip
    local chipGrad = Instance.new("UIGradient")
    chipGrad.Rotation = 90
    chipGrad.Color = ColorSequence.new(Color3.fromRGB(150, 100, 210), Color3.fromRGB(90, 55, 160))
    chipGrad.Parent = chip
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(160, 120, 235)
    stroke.Thickness = 2
    stroke.Transparency = 0
    stroke.Parent = chip
    chip.Parent = gui
    local chipLabel = whiteLabel(chip, "🛠 ADMIN: OFF", 13)

    -- Area-cycle button (shown only when admin mode is ON): rotate CurrentArea/HomeArea for testing
    -- the area theme + play feel.
    local areaBtn = Instance.new("TextButton")
    areaBtn.Name = "AreaCycle"
    areaBtn.Size = UDim2.fromOffset(118, 26)
    areaBtn.Position = UDim2.new(0, 315, 1, -46) -- just above the ADMIN chip
    areaBtn.AnchorPoint = Vector2.new(0, 1)
    areaBtn.BackgroundColor3 = Color3.fromRGB(45, 95, 180) -- sapphire capsule
    areaBtn.BackgroundTransparency = 0
    areaBtn.Font = Enum.Font.GothamBold
    areaBtn.TextSize = 12
    areaBtn.TextColor3 = Color3.fromRGB(240, 246, 255)
    areaBtn.Text = "AREA: …"
    areaBtn.Visible = false
    local ac = Instance.new("UICorner")
    ac.CornerRadius = UDim.new(1, 0)
    ac.Parent = areaBtn
    local areaGrad = Instance.new("UIGradient")
    areaGrad.Rotation = 90
    areaGrad.Color = ColorSequence.new(Color3.fromRGB(95, 165, 240), Color3.fromRGB(45, 95, 180))
    areaGrad.Parent = areaBtn
    local areaStroke = Instance.new("UIStroke")
    areaStroke.Color = Color3.fromRGB(95, 165, 240)
    areaStroke.Thickness = 2
    areaStroke.Parent = areaBtn
    areaBtn.Parent = gui
    local areaLabel = whiteLabel(areaBtn, "AREA: …", 12)
    local function refreshAreaLabel()
        local a = player:GetAttribute("HomeArea") or player:GetAttribute("CurrentArea") or "Spawn"
        areaLabel.Text = "AREA: " .. tostring(a) .. " ▸"
    end
    refreshAreaLabel()
    player:GetAttributeChangedSignal("CurrentArea"):Connect(refreshAreaLabel)
    player:GetAttributeChangedSignal("HomeArea"):Connect(refreshAreaLabel)
    areaBtn.Activated:Connect(function()
        local cur = player:GetAttribute("HomeArea") or player:GetAttribute("CurrentArea") or "Spawn"
        local idx = 1
        for i, a in ipairs(ADMIN_AREAS) do
            if a == cur then
                idx = i
                break
            end
        end
        local nextArea = ADMIN_AREAS[(idx % #ADMIN_AREAS) + 1]
        Signals.Admin_SetArea:FireServer({ area = nextArea })
    end)

    -- Grant-powers button (shown only when admin ON): bind the CURRENT area's full power set to the
    -- hotbar so every area's powers can be cast for testing. Capsule pill, emerald.
    local grantBtn = Instance.new("TextButton")
    grantBtn.Name = "GrantPowers"
    grantBtn.Size = UDim2.fromOffset(118, 26)
    grantBtn.Position = UDim2.new(0, 315, 1, -80) -- just above the AREA button
    grantBtn.AnchorPoint = Vector2.new(0, 1)
    grantBtn.BackgroundColor3 = Color3.fromRGB(45, 140, 80) -- emerald capsule
    grantBtn.BackgroundTransparency = 0
    grantBtn.Font = Enum.Font.GothamBold
    grantBtn.TextSize = 12
    grantBtn.TextColor3 = Color3.fromRGB(240, 255, 244)
    grantBtn.Text = "⚡ GRANT POWERS"
    grantBtn.Visible = false
    local gc = Instance.new("UICorner")
    gc.CornerRadius = UDim.new(1, 0)
    gc.Parent = grantBtn
    local grantGrad = Instance.new("UIGradient")
    grantGrad.Rotation = 90
    grantGrad.Color = ColorSequence.new(Color3.fromRGB(95, 220, 125), Color3.fromRGB(45, 140, 80))
    grantGrad.Parent = grantBtn
    local grantStroke = Instance.new("UIStroke")
    grantStroke.Color = Color3.fromRGB(95, 220, 125)
    grantStroke.Thickness = 2
    grantStroke.Parent = grantBtn
    grantBtn.Parent = gui
    whiteLabel(grantBtn, "⚡ GRANT POWERS", 12)
    grantBtn.Activated:Connect(function()
        Signals.Admin_GrantAreaPowers:FireServer()
    end)

    -- FX PROBE: cycles Casting → Impact → Real and plays the power_fx registry sequence so the
    -- effects can be eyeballed on demand (docs/PET_REALM_POWER_DATA_MODEL.md §11). Client-only.
    local fxBtn = Instance.new("TextButton")
    fxBtn.Name = "FXProbe"
    fxBtn.Size = UDim2.fromOffset(118, 26)
    fxBtn.Position = UDim2.new(0, 315, 1, -114) -- just above GRANT POWERS
    fxBtn.AnchorPoint = Vector2.new(0, 1)
    fxBtn.BackgroundColor3 = Color3.fromRGB(120, 70, 180) -- amethyst capsule (admin theme)
    fxBtn.BackgroundTransparency = 0
    fxBtn.Font = Enum.Font.GothamBold
    fxBtn.TextSize = 12
    fxBtn.TextColor3 = Color3.fromRGB(245, 240, 255)
    fxBtn.Text = "🎬 FX PROBE"
    fxBtn.Visible = false
    local fxc = Instance.new("UICorner")
    fxc.CornerRadius = UDim.new(1, 0)
    fxc.Parent = fxBtn
    local fxGrad = Instance.new("UIGradient")
    fxGrad.Rotation = 90
    fxGrad.Color = ColorSequence.new(Color3.fromRGB(175, 130, 235), Color3.fromRGB(120, 70, 180))
    fxGrad.Parent = fxBtn
    local fxStroke = Instance.new("UIStroke")
    fxStroke.Color = Color3.fromRGB(175, 130, 235)
    fxStroke.Thickness = 2
    fxStroke.Parent = fxBtn
    fxBtn.Parent = gui
    local fxLabel = whiteLabel(fxBtn, "🎬 FX PROBE", 12)
    local fxModes = { "casting", "impact", "real" }
    local fxIdx = 0
    fxBtn.Activated:Connect(function()
        fxIdx = (fxIdx % #fxModes) + 1
        local mode = fxModes[fxIdx]
        if fxLabel then
            fxLabel.Text = "🎬 FX: " .. string.upper(mode)
        end
        PowerFXProbe.run(mode)
    end)

    -- Manual FX stepping: NEXT advances one effect, REPEAT replays it — for studying timing.
    local function probeButton(name, text, yOffset, onClick)
        local b = Instance.new("TextButton")
        b.Name = name
        b.Size = UDim2.fromOffset(118, 26)
        b.Position = UDim2.new(0, 315, 1, yOffset)
        b.AnchorPoint = Vector2.new(0, 1)
        b.BackgroundColor3 = Color3.fromRGB(120, 70, 180)
        b.Font = Enum.Font.GothamBold
        b.TextSize = 12
        b.TextColor3 = Color3.fromRGB(245, 240, 255)
        b.Text = text
        b.Visible = false
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(1, 0)
        c.Parent = b
        local g = Instance.new("UIGradient")
        g.Rotation = 90
        g.Color = ColorSequence.new(Color3.fromRGB(175, 130, 235), Color3.fromRGB(120, 70, 180))
        g.Parent = b
        local s = Instance.new("UIStroke")
        s.Color = Color3.fromRGB(175, 130, 235)
        s.Thickness = 2
        s.Parent = b
        b.Parent = gui
        whiteLabel(b, text, 12)
        b.Activated:Connect(onClick)
        return b
    end
    local nextBtn = probeButton("FXNext", "▶ NEXT", -148, function()
        PowerFXProbe.next()
    end)
    local repeatBtn = probeButton("FXRepeat", "↻ REPEAT", -182, function()
        PowerFXProbe.repeatStep()
    end)

    -- Pull up the Power Choice menu as if it were called for real (dual-column NEUTRAL +
    -- origin roster; the menu itself has a SWITCH-ORIGIN button + level stepper).
    local powerChoiceBtn = probeButton("PowerChoice", "🔮 POWER CHOICE", -216, function()
        if _G.MenuManager then
            _G.MenuManager:OpenPanel("PowerChoice", "scale_in")
        end
    end)

    -- Fast-forward: XP to ~98% of the next level + the next gate's coins (skip farming when testing).
    local xpBtn = probeButton("GrantXp", "➕ XP + GATE", -250, function()
        local remote = game:GetService("ReplicatedStorage"):FindFirstChild("GameAPICommand")
        if remote then
            pcall(function()
                remote:InvokeServer("levelup.grantXp", {})
            end)
        end
    end)

    local on = false
    local function apply()
        setOverlays(pg, on)
        grantBtn.Visible = on
        fxBtn.Visible = on
        nextBtn.Visible = on
        repeatBtn.Visible = on
        powerChoiceBtn.Visible = on
        xpBtn.Visible = on
        chipLabel.Text = on and "🛠 ADMIN: ON" or "🛠 ADMIN: OFF"
        chip.BackgroundColor3 = on and Color3.fromRGB(45, 140, 80) or Color3.fromRGB(90, 55, 160)
        chipGrad.Color = on
                and ColorSequence.new(Color3.fromRGB(95, 220, 125), Color3.fromRGB(45, 140, 80))
            or ColorSequence.new(Color3.fromRGB(150, 100, 210), Color3.fromRGB(90, 55, 160))
        stroke.Color = on and Color3.fromRGB(95, 220, 125) or Color3.fromRGB(160, 120, 235)
        areaBtn.Visible = on
        player:SetAttribute("AdminOverlaysOn", on)
    end

    chip.Activated:Connect(function()
        on = not on
        apply()
    end)

    -- The overlays may not exist at this instant (they start in their own pcall blocks); apply a few
    -- times early so they begin hidden once they appear.
    task.spawn(function()
        for _ = 1, 6 do
            apply()
            task.wait(0.5)
        end
    end)
end

return AdminController
