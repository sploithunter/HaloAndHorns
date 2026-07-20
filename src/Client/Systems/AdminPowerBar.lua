--[[
    AdminPowerBar — admin-only power test surface (server backend: PowerService AdminCast /
    AdminTogglePassive, gated by IsAdmin/Studio).

    While ADMIN mode is ON (the AdminController chip → `AdminOverlaysOn` attribute) this REPLACES the
    normal hotbar with: origin TABS across the top, a MIN/MAX slotting switch, and every power in the
    selected origin —
      • CASTABLE → a cast button; fires Admin_CastPower { powerId, mode } (the real pipeline: focus +
        cooldown respected, ownership bypassed, nothing granted/saved).
      • ALWAYS-ON → an on/off toggle; fires Admin_TogglePassive { powerId, on, mode } (transient stamp;
        e.g. flip Hasten ON at MAX, then cast another origin's power and watch its cooldown shrink).

    Powers are grouped by AdminPowerPalette (the shared, tested classifier) and iconned by PetBadge —
    so the bar dogfoods the one icon path (an unwired badge trips the StatusBadges/CombatAura warning).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Signals = require(ReplicatedStorage.Shared.Network.Signals)
local PetBadge = require(script.Parent.Parent.UI.PetBadge)
local AdminPowerPalette = require(ReplicatedStorage.Shared.Game.AdminPowerPalette)
local powersConfig = require(ReplicatedStorage:WaitForChild("Configs"):WaitForChild("powers"))
local Readiness = require(ReplicatedStorage.Shared.Utils.Readiness)

local localPlayer = Players.LocalPlayer

local AdminPowerBar = {}

-- Tab order + friendly labels (archetype = origin).
local TAB_ORDER = { "geomancer", "pyromancer", "cryomancer", "sandwalker" }
local TAB_LABEL = {
    geomancer = "Earth",
    pyromancer = "Lava",
    cryomancer = "Ice",
    sandwalker = "Desert",
    [AdminPowerPalette.GENERIC] = "Utility",
}
local TAB_TINT = {
    geomancer = Color3.fromRGB(90, 190, 110),
    pyromancer = Color3.fromRGB(230, 120, 70),
    cryomancer = Color3.fromRGB(110, 190, 235),
    sandwalker = Color3.fromRGB(235, 205, 90),
    [AdminPowerPalette.GENERIC] = Color3.fromRGB(200, 200, 210),
}

local function isAdmin()
    return RunService:IsStudio() or localPlayer:GetAttribute("IsAdmin") == true
end

local function displayName(powerId)
    local def = powersConfig.powers[powerId]
    return (def and def.display_name) or powerId
end

function AdminPowerBar.start()
    -- Wait for the IsAdmin attribute to replicate (data loads after boot); bail for non-admins.
    if not isAdmin() then
        Readiness.awaitAttributePresent(localPlayer, "IsAdmin", 12)
        if not isAdmin() then
            return
        end
    end

    local playerGui = localPlayer:WaitForChild("PlayerGui")
    local palette = AdminPowerPalette.group(powersConfig, TAB_ORDER)

    local gui = Instance.new("ScreenGui")
    gui.Name = "AdminPowerBar"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 6
    gui.Enabled = false
    gui.Parent = playerGui

    local root = Instance.new("Frame")
    root.Name = "Root"
    root.AnchorPoint = Vector2.new(0.5, 1)
    root.Position = UDim2.new(0.5, 0, 1, -6)
    root.Size = UDim2.fromOffset(720, 196)
    root.BackgroundColor3 = Color3.fromRGB(18, 20, 26)
    root.BackgroundTransparency = 0.08
    root.BorderSizePixel = 0
    root.Parent = gui
    local rc = Instance.new("UICorner")
    rc.CornerRadius = UDim.new(0, 10)
    rc.Parent = root
    local rstroke = Instance.new("UIStroke")
    rstroke.Color = Color3.fromRGB(120, 90, 220)
    rstroke.Thickness = 1.5
    rstroke.Parent = root

    local title = Instance.new("TextLabel")
    title.BackgroundTransparency = 1
    title.Position = UDim2.fromOffset(12, 4)
    title.Size = UDim2.fromOffset(260, 18)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 12
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.TextColor3 = Color3.fromRGB(200, 180, 255)
    title.Text = "🛠 ADMIN POWER TEST"
    title.Parent = root

    -- MIN/MAX slotting switch (top-right). state.mode = "min" | "max".
    local state = { tab = TAB_ORDER[1], mode = "min", toggled = {} }
    local castCells = {} -- powerId -> { overlay, label } for the live cooldown sweep
    local cooldownEnd = {} -- powerId -> os.clock() expiry (from the Power_Cooldown echo)
    local modeBtn = Instance.new("TextButton")
    modeBtn.AnchorPoint = Vector2.new(1, 0)
    modeBtn.Position = UDim2.new(1, -10, 0, 4)
    modeBtn.Size = UDim2.fromOffset(150, 22)
    modeBtn.Font = Enum.Font.GothamBold
    modeBtn.TextSize = 12
    modeBtn.AutoButtonColor = true
    modeBtn.Parent = root
    local mc = Instance.new("UICorner")
    mc.CornerRadius = UDim.new(0, 6)
    mc.Parent = modeBtn
    local function refreshModeBtn()
        local max = state.mode == "max"
        modeBtn.Text = max and "SLOTTING: MAX ⚙⚙" or "SLOTTING: MIN (bare)"
        modeBtn.BackgroundColor3 = max and Color3.fromRGB(120, 80, 200)
            or Color3.fromRGB(55, 58, 70)
        modeBtn.TextColor3 = Color3.fromRGB(245, 245, 255)
    end

    -- SPAWN buttons (Jason 2026-07-02: "the ability in admin to spawn a boss" — rage-tip / balance
    -- testing). Rides the existing `combat.spawnEnemy` bus command (GameAPICommand RemoteFunction,
    -- admin-or-Studio gated server-side). Each button fires a COMPOSITION — a list of spawn calls
    -- in sequence — so one click can build a whole encounter. InvokeServer yields, so fire in a task.
    local function spawnBtn(label, offsetX, width, spawns)
        local b = Instance.new("TextButton")
        b.AnchorPoint = Vector2.new(1, 0)
        b.Position = UDim2.new(1, offsetX, 0, 4)
        b.Size = UDim2.fromOffset(width, 22)
        b.Font = Enum.Font.GothamBold
        b.TextSize = 12
        b.AutoButtonColor = true
        b.BackgroundColor3 = Color3.fromRGB(150, 60, 60)
        b.TextColor3 = Color3.fromRGB(255, 235, 235)
        b.Text = label
        b.Parent = root
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 6)
        corner.Parent = b
        b.MouseButton1Click:Connect(function()
            task.spawn(function()
                local remote = ReplicatedStorage:FindFirstChild("GameAPICommand")
                if remote then
                    for _, args in ipairs(spawns) do
                        pcall(function()
                            remote:InvokeServer("combat.spawnEnemy", args)
                        end)
                    end
                end
            end)
        end)
        return b
    end
    spawnBtn("☠ BOSS", -168, 90, { { enemyId = "infernal_boss", forward = 10 } })
    spawnBtn(
        "𖤐 PACK ×6",
        -266,
        92,
        { { enemyId = "lava_imp", count = 6, spread = 8, forward = 10 } }
    )
    -- ARCH-VILLAIN: the super-boss tier (splash cleave + telegraphed slam + arch scale)
    spawnBtn("👑 AV", -364, 66, { { enemyId = "infernal_archvillain", forward = 14 } })
    -- DANGEROUS PACK (Jason): a full CoH-style encounter in one click — boss anchor, two
    -- lieutenant tanks flanking, the moth healer tucked BEHIND the boss (kill-order check:
    -- ignore it and the fight is a treadmill), and a whelp screen up front feeding your AoE.
    spawnBtn("💀 WAR", -438, 82, {
        { enemyId = "infernal_boss", forward = 18 },
        { enemyId = "ember_brute", count = 2, spread = 10, forward = 12 },
        { enemyId = "ember_acolyte", forward = 24 },
        { enemyId = "cinder_whelp", count = 4, spread = 8, forward = 8 },
    })
    -- Five stationary members of ONE encounter group, placed directly away from the player. Spawn
    -- the anchor first, then wait five seconds so the pets settle on that near edge before the
    -- 10/20/30/40-stud members appear. At Eternal Winter's bare 20-stud radius, the first three are
    -- in and the final two are visibly out. The same geometry is useful for damage-AoE/contagion QA.
    spawnBtn("🎯 DUMMY LINE", -528, 82, {
        {
            enemyId = "training_dummy",
            count = 5,
            layout = "line",
            spacing = 10,
            delayAfterFirst = 5,
        },
    })

    -- Tab strip.
    local tabStrip = Instance.new("Frame")
    tabStrip.BackgroundTransparency = 1
    tabStrip.Position = UDim2.fromOffset(10, 28)
    tabStrip.Size = UDim2.new(1, -20, 0, 26)
    tabStrip.Parent = root
    local tabLayout = Instance.new("UIListLayout")
    tabLayout.FillDirection = Enum.FillDirection.Horizontal
    tabLayout.Padding = UDim.new(0, 6)
    tabLayout.Parent = tabStrip

    -- Power grid (current tab).
    local grid = Instance.new("ScrollingFrame")
    grid.BackgroundTransparency = 1
    grid.BorderSizePixel = 0
    grid.Position = UDim2.fromOffset(10, 58)
    grid.Size = UDim2.new(1, -20, 1, -66)
    grid.ScrollBarThickness = 4
    grid.CanvasSize = UDim2.new()
    grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
    grid.Parent = root
    local gridLayout = Instance.new("UIGridLayout")
    gridLayout.CellSize = UDim2.fromOffset(96, 92)
    gridLayout.CellPadding = UDim2.fromOffset(8, 8)
    gridLayout.Parent = grid

    -- Build ONE power cell (castable cast button OR always-on toggle).
    local function makeCell(powerId, alwaysOn)
        local cell = Instance.new("TextButton")
        cell.Name = powerId
        cell.AutoButtonColor = true
        cell.BackgroundColor3 = Color3.fromRGB(34, 37, 46)
        cell.Text = ""
        local cc = Instance.new("UICorner")
        cc.CornerRadius = UDim.new(0, 8)
        cc.Parent = cell
        local stroke = Instance.new("UIStroke")
        stroke.Color = Color3.fromRGB(70, 74, 92)
        stroke.Thickness = 1
        stroke.Parent = cell

        local iconHolder = Instance.new("Frame")
        iconHolder.BackgroundTransparency = 1
        iconHolder.Position = UDim2.fromOffset(28, 6)
        iconHolder.Size = UDim2.fromOffset(40, 40)
        iconHolder.Parent = cell
        local badge = PetBadge.forPower(powerId)
        if badge then
            PetBadge.create(
                iconHolder,
                { element = badge.element, symbol = badge.symbol, ring = badge.ring }
            )
        end

        local nameLbl = Instance.new("TextLabel")
        nameLbl.BackgroundTransparency = 1
        nameLbl.Position = UDim2.fromOffset(2, 48)
        nameLbl.Size = UDim2.fromOffset(92, 22)
        nameLbl.Font = Enum.Font.GothamMedium
        nameLbl.TextSize = 11
        nameLbl.TextWrapped = true
        nameLbl.TextColor3 = Color3.fromRGB(225, 228, 238)
        nameLbl.Text = displayName(powerId)
        nameLbl.Parent = cell

        local tag = Instance.new("TextLabel")
        tag.BackgroundTransparency = 1
        tag.Position = UDim2.fromOffset(2, 70)
        tag.Size = UDim2.fromOffset(92, 16)
        tag.Font = Enum.Font.GothamBold
        tag.TextSize = 10
        tag.Parent = cell

        local function refreshTag()
            if alwaysOn then
                local on = state.toggled[powerId] == true
                tag.Text = on and "● ON" or "○ OFF"
                tag.TextColor3 = on and Color3.fromRGB(110, 230, 130)
                    or Color3.fromRGB(150, 155, 168)
                stroke.Color = on and Color3.fromRGB(110, 230, 130) or Color3.fromRGB(70, 74, 92)
            else
                tag.Text = "▶ CAST"
                tag.TextColor3 = Color3.fromRGB(150, 200, 255)
            end
        end
        refreshTag()

        cell.Activated:Connect(function()
            if alwaysOn then
                local on = not (state.toggled[powerId] == true)
                state.toggled[powerId] = on
                Signals.Admin_TogglePassive:FireServer({
                    powerId = powerId,
                    on = on,
                    mode = state.mode,
                })
                refreshTag()
            else
                Signals.Admin_CastPower:FireServer({ powerId = powerId, mode = state.mode })
            end
        end)

        -- Cooldown sweep (castables only): a dark cover + countdown number while the power recharges,
        -- so the cooldown is VISIBLE for balancing (it's enforced server-side regardless of this).
        if not alwaysOn then
            local cdOverlay = Instance.new("Frame")
            cdOverlay.BackgroundColor3 = Color3.fromRGB(8, 9, 12)
            cdOverlay.BackgroundTransparency = 0.35
            cdOverlay.Size = UDim2.fromScale(1, 1)
            cdOverlay.Visible = false
            cdOverlay.ZIndex = 5
            local oc = Instance.new("UICorner")
            oc.CornerRadius = UDim.new(0, 8)
            oc.Parent = cdOverlay
            local cdLbl = Instance.new("TextLabel")
            cdLbl.BackgroundTransparency = 1
            cdLbl.Size = UDim2.fromScale(1, 1)
            cdLbl.Font = Enum.Font.GothamBlack
            cdLbl.TextSize = 22
            cdLbl.TextColor3 = Color3.fromRGB(255, 230, 140)
            cdLbl.ZIndex = 6
            cdLbl.Parent = cdOverlay
            cdOverlay.Parent = cell
            castCells[powerId] = { overlay = cdOverlay, label = cdLbl }
        end
        return cell
    end

    local function renderTab()
        for k in pairs(castCells) do -- drop stale refs before destroying the old cells
            castCells[k] = nil
        end
        for _, c in ipairs(grid:GetChildren()) do
            if c:IsA("TextButton") then
                c:Destroy()
            end
        end
        local g = palette.groups[state.tab] or { castable = {}, always_on = {} }
        for _, powerId in ipairs(g.castable) do
            makeCell(powerId, false).Parent = grid
        end
        for _, powerId in ipairs(g.always_on) do
            makeCell(powerId, true).Parent = grid
        end
    end

    -- Tab buttons.
    local tabButtons = {}
    local function refreshTabs()
        for origin, btn in pairs(tabButtons) do
            local active = origin == state.tab
            btn.BackgroundColor3 = active and TAB_TINT[origin] or Color3.fromRGB(40, 43, 52)
            btn.TextColor3 = active and Color3.fromRGB(20, 22, 28) or Color3.fromRGB(220, 224, 235)
        end
    end
    for _, origin in ipairs(palette.order) do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.fromOffset(96, 26)
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 12
        btn.AutoButtonColor = true
        btn.Text = TAB_LABEL[origin] or origin
        btn.Parent = tabStrip
        local bc = Instance.new("UICorner")
        bc.CornerRadius = UDim.new(0, 6)
        bc.Parent = btn
        tabButtons[origin] = btn
        btn.Activated:Connect(function()
            state.tab = origin
            refreshTabs()
            renderTab()
        end)
    end

    modeBtn.Activated:Connect(function()
        state.mode = state.mode == "max" and "min" or "max"
        refreshModeBtn()
    end)

    refreshModeBtn()
    refreshTabs()
    renderTab()

    -- Live cooldown: the server echoes Power_Cooldown on every cast; sweep the matching cast cell so
    -- you can read each power's recharge while balancing.
    Signals.Power_Cooldown.OnClientEvent:Connect(function(p)
        if type(p) == "table" and p.power then
            cooldownEnd[tostring(p.power)] = os.clock() + (tonumber(p.cooldown) or 0)
        end
    end)
    RunService.Heartbeat:Connect(function()
        local now = os.clock()
        for powerId, refs in pairs(castCells) do
            local remaining = (cooldownEnd[powerId] or 0) - now
            if remaining > 0 then
                refs.overlay.Visible = true
                refs.label.Text = tostring(math.ceil(remaining))
            elseif refs.overlay.Visible then
                refs.overlay.Visible = false
            end
        end
    end)

    -- Show with ADMIN mode; hide + restore the normal hotbar otherwise.
    local function setShown(on)
        gui.Enabled = on
        local hb = playerGui:FindFirstChild("HotbarBar")
        if hb then
            hb.Enabled = not on
        end
    end
    setShown(localPlayer:GetAttribute("AdminOverlaysOn") == true)
    localPlayer:GetAttributeChangedSignal("AdminOverlaysOn"):Connect(function()
        setShown(localPlayer:GetAttribute("AdminOverlaysOn") == true)
    end)
end

return AdminPowerBar
