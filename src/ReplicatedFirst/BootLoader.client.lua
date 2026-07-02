--[[
    BootLoader (ReplicatedFirst) — gates play behind a loading screen until the game is ready.

    ReplicatedFirst runs FIRST, before StarterPlayerScripts. We cover the screen immediately, lock
    the player's controls, and reveal the game once each boot PHASE is ready. The phases, their
    user-facing text, and where each reads its readiness are the SSOT in configs/boot.lua; this
    screen just renders them (see docs/BOOT_ORCHESTRATION.md). A phase reads from one of:
      - "engine" — game:IsLoaded() (asset replication)
      - "server" — ReplicatedStorage.BootStatus:GetAttribute(<milestone>), the real server-side
        readiness mirror set by BootOrchestrator as each producer signals (world_structure,
        models_ready, crystals_ready, eggs_placed, icons_ready) — NOT a workspace symptom-poll
      - "player" — a LocalPlayer attribute (DataLoaded / PetsSpawned / ClientUIReady)

    A hard timeout reveals anyway, so a stuck/never-sent signal can never trap the player. Background
    phases (e.g. icon baking) are shown but never hold play hostage.
]]

local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer = Players.LocalPlayer
local ACCENT = Color3.fromRGB(150, 85, 225) -- purple, matches the level-up / ascend accent

-- Boot phases + text + readiness sources come from configs/boot.lua (the SSOT). Fall back to a
-- minimal gate set if it can't load, so the boot can never hard-break on a config error.
local bootConfig
do
    local ok, cfg = pcall(function()
        local configs = ReplicatedStorage:WaitForChild("Configs", 10)
        return require(configs:WaitForChild("boot", 5))
    end)
    bootConfig = (ok and type(cfg) == "table") and cfg or nil
end
local PHASES = (bootConfig and bootConfig.phases)
    or {
        { key = "engine", source = "engine", blocking = true, text = "Loading world" },
        { key = "data_loaded", source = "player", blocking = true, text = "Syncing your data" },
        { key = "client_ui", source = "player", blocking = true, text = "Preparing the HUD" },
    }
local PLAYER_GATES = (bootConfig and bootConfig.player_gates) or {}
local HARD_TIMEOUT = (bootConfig and bootConfig.reveal_timeout_seconds) or 25 -- never hang the boot
local MIN_DISPLAY = (bootConfig and bootConfig.min_display_seconds) or 2 -- never blink past it
local SETTLE = 0.75 -- seconds after the last gate: restyle passes (tray/currency/quest) land

ReplicatedFirst:RemoveDefaultLoadingScreen()

-- ---- loading screen ----------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "BootLoader"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 1000000 -- above every other GUI
gui.Parent = localPlayer:WaitForChild("PlayerGui")

local bg = Instance.new("Frame")
bg.Size = UDim2.fromScale(1, 1)
bg.BackgroundColor3 = Color3.fromRGB(12, 13, 18)
bg.BorderSizePixel = 0
bg.Parent = gui

local title = Instance.new("TextLabel")
title.Size = UDim2.fromScale(0.8, 0.12)
title.Position = UDim2.fromScale(0.5, 0.42)
title.AnchorPoint = Vector2.new(0.5, 0.5)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBlack
title.TextScaled = true
title.TextColor3 = Color3.fromRGB(235, 238, 245)
title.Text = "HALO AND HORNS"
title.Parent = bg

local status = Instance.new("TextLabel")
status.Size = UDim2.fromScale(0.6, 0.05)
status.Position = UDim2.fromScale(0.5, 0.56)
status.AnchorPoint = Vector2.new(0.5, 0.5)
status.BackgroundTransparency = 1
status.Font = Enum.Font.GothamMedium
status.TextScaled = true
status.TextColor3 = Color3.fromRGB(150, 155, 170)
status.Text = "Loading…"
status.Parent = bg

local track = Instance.new("Frame")
track.Size = UDim2.fromScale(0.4, 0.012)
track.Position = UDim2.fromScale(0.5, 0.64)
track.AnchorPoint = Vector2.new(0.5, 0.5)
track.BackgroundColor3 = Color3.fromRGB(35, 37, 45)
track.BorderSizePixel = 0
track.Parent = bg
Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

local fill = Instance.new("Frame")
fill.Size = UDim2.fromScale(0, 1)
fill.BackgroundColor3 = ACCENT
fill.BorderSizePixel = 0
fill.Parent = track
Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

-- ---- build/version stamp ----------------------------------------------
-- Jason: show what version this is + when it was built (Mountain Time) so a
-- published build is identifiable — "if something's not working I can tell if
-- it actually updated." Source: configs/build_info.lua, regenerated from git by
-- scripts/stamp_build.sh on every build/publish. Falls back to "dev build" when
-- unstamped (a live rojo Studio session). Bottom-center, dim — informational.
local versionText = "dev build"
do
    local ok, info = pcall(function()
        local ReplicatedStorage = game:GetService("ReplicatedStorage")
        local configs = ReplicatedStorage:WaitForChild("Configs", 10)
        local mod = configs and configs:WaitForChild("build_info", 5)
        return mod and require(mod)
    end)
    if ok and type(info) == "table" and info.commit and info.commit ~= "unknown" then
        versionText = string.format("v%s · %s", info.version or "?", info.commit)
        if info.dirty then
            versionText = versionText .. "*"
        end
        if info.built_at then
            versionText = versionText .. "  ·  updated " .. info.built_at
        end
    end
end

local versionLabel = Instance.new("TextLabel")
versionLabel.Size = UDim2.fromScale(0.9, 0.035)
versionLabel.Position = UDim2.fromScale(0.5, 0.96)
versionLabel.AnchorPoint = Vector2.new(0.5, 0.5)
versionLabel.BackgroundTransparency = 1
versionLabel.Font = Enum.Font.Gotham
versionLabel.TextScaled = true
versionLabel.TextColor3 = Color3.fromRGB(95, 100, 115)
versionLabel.Text = versionText
versionLabel.Parent = bg

-- ---- control lock ------------------------------------------------------
-- Disable the default PlayerModule controls while loading so the player can't move/interact behind
-- the cover. Wrapped in pcall + retry because PlayerModule may not exist the instant we boot.
local function setControls(enabled)
    pcall(function()
        local ps = localPlayer:FindFirstChild("PlayerScripts")
        local pm = ps and ps:FindFirstChild("PlayerModule")
        if pm then
            local controls = require(pm):GetControls()
            if enabled then
                controls:Enable()
            else
                controls:Disable()
            end
        end
    end)
end

-- ---- readiness ---------------------------------------------------------
-- A phase is ready per its config `source`: the engine bit, the server milestone mirror
-- (ReplicatedStorage.BootStatus, set by BootOrchestrator as producers signal), or a per-player
-- attribute. No workspace symptom-polling — these are the real readiness signals.
local function phaseReady(phase)
    if phase.source == "engine" then
        return game:IsLoaded()
    elseif phase.source == "server" then
        local folder = ReplicatedStorage:FindFirstChild("BootStatus")
        return folder ~= nil and folder:GetAttribute(phase.key) == true
    elseif phase.source == "player" then
        local gate = PLAYER_GATES[phase.key]
        local attr = (gate and gate.attribute) or phase.key
        return localPlayer:GetAttribute(attr) == true
    end
    return true
end

task.spawn(function()
    local start = os.clock()
    setControls(false)
    -- keep re-asserting the control lock until the reveal (PlayerModule loads after us, and
    -- a respawn mid-load would re-enable default controls)
    local revealed = false
    task.spawn(function()
        while not revealed do
            setControls(false)
            task.wait(0.2)
        end
    end)

    for i, phase in ipairs(PHASES) do
        status.Text = phase.text .. "…"
        local blocking = phase.blocking ~= false
        -- Background phases (e.g. icon baking) are shown but never hold play hostage: wait only a
        -- brief beat so the label is visible, then advance regardless.
        local phaseStart = os.clock()
        while not phaseReady(phase) do
            if os.clock() - start > HARD_TIMEOUT then
                break
            end
            if not blocking and os.clock() - phaseStart > 0.8 then
                break
            end
            task.wait(0.1)
        end
        TweenService:Create(fill, TweenInfo.new(0.25), { Size = UDim2.fromScale(i / #PHASES, 1) })
            :Play()
    end

    -- restyle passes (tray pills, currency stack, quest capsule) run just after the HUD guis
    -- appear — give them a beat so the reveal shows the FINISHED hud, and never blink the
    -- screen past MIN_DISPLAY even on instant local loads.
    status.Text = "Ready!"
    task.wait(math.max(SETTLE, MIN_DISPLAY - (os.clock() - start)))
    revealed = true
    task.wait(0.25) -- let the lock loop observe `revealed` before re-enabling
    setControls(true)

    local t = TweenInfo.new(0.4)
    TweenService:Create(bg, t, { BackgroundTransparency = 1 }):Play()
    TweenService:Create(title, t, { TextTransparency = 1 }):Play()
    TweenService:Create(status, t, { TextTransparency = 1 }):Play()
    TweenService:Create(track, t, { BackgroundTransparency = 1 }):Play()
    TweenService:Create(fill, t, { BackgroundTransparency = 1 }):Play()
    task.wait(0.45)
    gui:Destroy()
end)
