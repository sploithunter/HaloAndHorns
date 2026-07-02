--[[
    Client Bootstrap - Initializes the client-side game systems
    
    This file:
    1. Sets up the module loader for client modules
    2. Initializes Matter ECS client world
    3. Sets up UI systems and controllers
    4. Handles networking with server
]]

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local UserInputService = game:GetService("UserInputService")
local ContentProvider = game:GetService("ContentProvider")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

-- Wait for packages and shared modules
local Packages = ReplicatedStorage:WaitForChild("Packages", 10)
if not Packages then
    error("Packages not found - make sure 'wally install' has been run")
end

local Shared = ReplicatedStorage:WaitForChild("Shared", 10)
if not Shared then
    error("Shared modules not found")
end

-- Core dependencies
local Locations = require(ReplicatedStorage.Shared.Locations)
local Matter = Locations.getLibrary("Matter") -- Matter ECS framework (manual due to Wally/Rojo sync issues)
local Reflex = Locations.getPackage("Reflex") -- Redux-like state management (via Wally)
local ModuleLoader = require(Locations.SharedUtils.ModuleLoader)

local localPlayer = Players.LocalPlayer
local TRAVEL_PROMPT_NAME = "ZoneTravelPrompt"
local UNLOCKED_AREAS_ATTRIBUTE = "UnlockedAreasJson"

-- Console noise reduction: defer logging until Logger is initialized

-- Create module loader for client
local loader = ModuleLoader.new()

-- Register shared utilities
loader:RegisterModule("Logger", Shared.Utils.Logger)
loader:RegisterModule("ConfigLoader", Shared.ConfigLoader, { "Logger" })
-- NetworkConfig removed - using Signals instead

-- Register client controllers
-- loader:RegisterModule("InputController", StarterPlayer.StarterPlayerScripts.Client.Controllers.InputController, {"Logger"})
-- loader:RegisterModule("CameraController", StarterPlayer.StarterPlayerScripts.Client.Controllers.CameraController, {"Logger", "InputController"})
-- loader:RegisterModule("UIController", StarterPlayer.StarterPlayerScripts.Client.Controllers.UIController, {"Logger", "NetworkBridge"})

-- Register client systems (lazy loaded)
-- loader:RegisterLazyModule("RenderSystem", StarterPlayer.StarterPlayerScripts.Client.Systems.RenderSystem, {"Logger"})
-- loader:RegisterLazyModule("AnimationSystem", StarterPlayer.StarterPlayerScripts.Client.Systems.AnimationSystem, {"Logger"})
-- loader:RegisterLazyModule("ParticleSystem", StarterPlayer.StarterPlayerScripts.Client.Systems.ParticleSystem, {"Logger"})

-- Load all modules
local loadOrder = loader:LoadAll()

-- Get loaded modules for easy access
local Logger = loader:Get("Logger")
local ConfigLoader = loader:Get("ConfigLoader")
-- NetworkConfig removed - using Signals instead

local petVisualsOk, PetVariantVisuals = pcall(function()
    return require(ReplicatedStorage.Shared.Services.PetVariantVisuals)
end)

if petVisualsOk and PetVariantVisuals then
    task.spawn(function()
        local playerPets = workspace:WaitForChild("PlayerPets", 30)
        if playerPets then
            PetVariantVisuals.StartClient(playerPets)
            Logger:Info("Pet variant visuals started")
        else
            Logger:Warn("PlayerPets folder not found; pet variant visuals not started")
        end
    end)
else
    Logger:Warn("Failed to load PetVariantVisuals", { error = tostring(PetVariantVisuals) })
end

-- Load client configuration
local gameConfig = ConfigLoader:LoadConfig("game")
Logger:Info("Client initialized", {
    gameMode = gameConfig.GameMode,
    player = localPlayer.Name,
    userId = localPlayer.UserId,
})

-- Initialize Matter ECS World for client
local world = Matter.World.new()
local loop = Matter.Loop.new(world)

Logger:Info("Client Matter ECS world created")

-- TODO: Register client-side Matter systems
local systems = {}

-- Add game-mode specific client systems
if gameConfig.GameMode == "Simulator" then
    Logger:Info("Loading Simulator client systems")
    -- systems.PetFollowSystem = require(...)
    -- systems.CollectionEffectsSystem = require(...)
    do
        local AutoTarget = require(script.Systems.AutoTarget)
        -- Start immediately (do not rely on systems loop)
        local ok, err = pcall(function()
            local at = AutoTarget.new()
            at:Start()
        end)
        if not ok then
            Logger:Warn("Failed to start AutoTarget client system", { error = tostring(err) })
        end
    end
elseif gameConfig.GameMode == "FPS" then
    Logger:Info("Loading FPS client systems")
    -- systems.WeaponRenderSystem = require(...)
    -- systems.CrosshairSystem = require(...)
elseif gameConfig.GameMode == "TowerDefense" then
    Logger:Info("Loading Tower Defense client systems")
    -- systems.TowerPreviewSystem = require(...)
    -- systems.PathVisualizationSystem = require(...)
end

-- Pet follow movement (issue #4): client-side visualisation of the local
-- player's pets (smooth, full-framerate). Self-gates on pet_follow.service_owned;
-- pets are anchored server-side (can't fall) and positioned here each frame.
do
    local ok, err = pcall(function()
        require(script.Systems.PetFollowController).start()
    end)
    if not ok then
        Logger:Warn("Failed to start PetFollowController", { error = tostring(err) })
    end
end

-- Enemy movement smoothing (Feature 10): interpolates the visible enemy model toward
-- the server's authoritative step target each frame, so chasing looks smooth despite
-- the coarse server tick. Self-gates on pet_follow.service_owned.
do
    local ok, err = pcall(function()
        require(script.Systems.EnemyMotion).start()
    end)
    if not ok then
        Logger:Warn("Failed to start EnemyMotion", { error = tostring(err) })
    end
end

-- Burn fire: a per-enemy flame while a DoT/contagion burn is live (BurnFxUntil) — the "individual
-- fires" that make a contagion read as spreading (each enemy ignites as it's infected).
do
    local ok, err = pcall(function()
        require(script.Systems.EnemyBurnFx).start()
    end)
    if not ok then
        Logger:Warn("Failed to start EnemyBurnFx", { error = tostring(err) })
    end
end

-- Squad HUD (Feature 10): right-side City-of-Heroes-style squad strip — per-pet state,
-- health, recharge, click-to-select, recall/summon. Reads pet attributes; no server feed.
do
    local ok, err = pcall(function()
        require(script.Systems.SquadHud).start()
    end)
    if not ok then
        Logger:Warn("Failed to start SquadHud", { error = tostring(err) })
    end
end

-- Enemy HUD: left-side mirror of the squad strip — one card per foe aggro'd onto YOUR squad
-- (server-mirrored AggroOwner), the indirect target (selected pet → enemy) bordered amber.
-- Same HudCard chrome as SquadHud; auto-collapses to nothing when there's no fight.
do
    local ok, err = pcall(function()
        require(script.Systems.EnemyHud).start()
    end)
    if not ok then
        Logger:Warn("Failed to start EnemyHud", { error = tostring(err) })
    end
end

-- Leaderboard consumer: drains + caches LeaderboardService's periodic LeaderboardUpdated
-- broadcast so it doesn't pile up unhandled (queue-exhaustion leak). Caches snapshots for a
-- future leaderboard UI to read (LeaderboardController.Get / .OnUpdate).
do
    local ok, err = pcall(function()
        require(script.Systems.LeaderboardController).start()
    end)
    if not ok then
        Logger:Warn("Failed to start LeaderboardController", { error = tostring(err) })
    end
end

-- Power/command hotbar (Feature 16): lower-center 20-slot bar + farming-mode cycle.
-- Number keys 1-0 / Shift+1-0 fire slots; bindings fed by HotbarService.
do
    local ok, err = pcall(function()
        require(script.Systems.HotbarBar).start()
    end)
    if not ok then
        Logger:Warn("Failed to start HotbarBar", { error = tostring(err) })
    end
end

-- Admin-only power test bar (replaces the hotbar while ADMIN mode is on). Self-gates to admins.
do
    local ok, err = pcall(function()
        require(script.Systems.AdminPowerBar).start()
    end)
    if not ok then
        Logger:Warn("Failed to start AdminPowerBar", { error = tostring(err) })
    end
end

-- Reactive combat auras: watches the combat attributes PowerService sets (CombatShield,
-- DefenseBuffUntil, HealFxUntil, player PetDamageBuffUntil, enemy Vulnerable/RootedUntil) and
-- attaches CombatFX so powers read on the battlefield (shield bubble + armor reskin, buff/heal
-- auras on pets, debuff auras on enemies).
do
    local ok, err = pcall(function()
        require(script.Systems.CombatAuraController).start()
    end)
    if not ok then
        Logger:Warn("Failed to start CombatAuraController", { error = tostring(err) })
    end
end

-- Player's OWN active power buffs (Hasten / Fortune / Prospector / …) as a small badge row under
-- the player nameplate — the self-power counterpart to the squad cards' pet-buff badges.
do
    local ok, err = pcall(function()
        require(script.Systems.PlayerPowerBadges).start()
    end)
    if not ok then
        Logger:Warn("Failed to start PlayerPowerBadges", { error = tostring(err) })
    end
end

-- In-world buff AURAS (the badge row's twin): a themed sparkle+glow on any player whose timed buff
-- is active (Windfall = gold). SSOT-driven from configs/buff_auras.lua; potions slot in as new rows.
do
    local ok, err = pcall(function()
        require(script.Systems.BuffAuraController).start()
    end)
    if not ok then
        Logger:Warn("Failed to start BuffAuraController", { error = tostring(err) })
    end
end

-- Lower-left live label for the active global event (glows + names the running event,
-- click opens the Effects/events panel). Reads Signals.ActiveEffects.
do
    local ok, err = pcall(function()
        require(script.Systems.EventLiveLabel).start()
    end)
    if not ok then
        Logger:Warn("Failed to start EventLiveLabel", { error = tostring(err) })
    end
end

-- Studio-only: bridge that lets AutomationService disable/enable local controls
-- during automated movement (see AutomationControlBridge).
if RunService:IsStudio() then
    local ok, err = pcall(function()
        require(script.Systems.AutomationControlBridge).start()
    end)
    if not ok then
        Logger:Warn("Failed to start AutomationControlBridge", { error = tostring(err) })
    end
end

-- Studio-only: on-screen buttons to spawn/clear test enemies (combat testing rig).
if RunService:IsStudio() then
    local ok, err = pcall(function()
        require(script.Systems.DevSpawnPanel).start()
    end)
    if not ok then
        Logger:Warn("Failed to start DevSpawnPanel", { error = tostring(err) })
    end
end

-- Biome unlock prompt: appears when you stand in a locked biome (reads CurrentArea), click to buy.
do
    local ok, err = pcall(function()
        require(script.Systems.ZoneUnlockPrompt).start()
    end)
    if not ok then
        Logger:Warn("Failed to start ZoneUnlockPrompt", { error = tostring(err) })
    end
end

-- Realm portals: touch a portal surface -> yes/no travel confirm (server validates + teleports).
do
    local ok, err = pcall(function()
        require(script.Systems.RealmTravelPrompt).start()
    end)
    if not ok then
        Logger:Warn("Failed to start RealmTravelPrompt", { error = tostring(err) })
    end
end

-- Realm portals: per-player 🔒 on open portals the local player is too low-level to enter (drops on
-- level-up). The server label/touch-gate is shared; the lock is per-player so it must live here.
do
    local ok, err = pcall(function()
        require(script.Systems.RealmPortalLock).start()
    end)
    if not ok then
        Logger:Warn("Failed to start RealmPortalLock", { error = tostring(err) })
    end
end

-- Level-up sequence: "LEVEL UP!" button on PendingLevels, claim -> reveal + power pick / slotting.
do
    local ok, err = pcall(function()
        require(script.Systems.LevelUpController).start()
    end)
    if not ok then
        Logger:Warn("Failed to start LevelUpController", { error = tostring(err) })
    end
end

-- Looping background music that follows the player's current area (configs/sounds.lua area_music).
do
    local ok, err = pcall(function()
        require(script.Systems.AreaMusicController).start()
    end)
    if not ok then
        Logger:Warn("Failed to start AreaMusicController", { error = tostring(err) })
    end
end

-- GameEvents dispatcher: named gameplay events -> config-defined reactions (configs/game_events).
-- start() connects the server->client bridge; client code fires via require(...GameEvents).fire(...).
do
    local ok, err = pcall(function()
        require(script.Systems.GameEvents).start()
    end)
    if not ok then
        Logger:Warn("Failed to start GameEvents", { error = tostring(err) })
    end
end

-- Dev metrics overlay (Studio-only): rolling 1-min DPS / Coins-per-sec / Pet-speed bars for balancing.
do
    local ok, err = pcall(function()
        require(script.Systems.DevMetricsHud).start()
    end)
    if not ok then
        Logger:Warn("Failed to start DevMetricsHud", { error = tostring(err) })
    end
end

do
    local ok, err = pcall(function()
        require(script.Systems.PetSyncDiag).start()
    end)
    if not ok then
        Logger:Warn("Failed to start PetSyncDiag", { error = tostring(err) })
    end
end

do
    local ok, err = pcall(function()
        require(script.Systems.TargetBeams).start()
    end)
    if not ok then
        Logger:Warn("Failed to start TargetBeams", { error = tostring(err) })
    end
end

-- Buff-stats overlay (Studio-only): current effective buff multipliers (attack/defense/coin/luck/…),
-- resolved via the same BuffStack math the server uses — for verifying powers + auras while testing.
do
    local ok, err = pcall(function()
        require(script.Systems.BuffStatsHud).start()
    end)
    if not ok then
        Logger:Warn("Failed to start BuffStatsHud", { error = tostring(err) })
    end
end

-- Admin controller (admins / Studio): one "🛠 ADMIN" chip that hides ALL the dev overlays above by
-- default and toggles them on demand — clean play screen unless an admin opts in.
do
    local ok, err = pcall(function()
        require(script.Systems.AdminController).start()
    end)
    if not ok then
        Logger:Warn("Failed to start AdminController", { error = tostring(err) })
    end
end

-- CoH-style center player bar: XP pill + 10-tick level ring, area-themed.
do
    local ok, err = pcall(function()
        require(script.Systems.PlayerBar).start()
    end)
    if not ok then
        Logger:Warn("Failed to start PlayerBar", { error = tostring(err) })
    end
end

-- Skin the lower-left tray buttons with the pill_panel + pill_frame art (area-themed).
do
    local ok, err = pcall(function()
        require(script.Systems.MenuTrayStyle).start()
    end)
    if not ok then
        Logger:Warn("Failed to start MenuTrayStyle", { error = tostring(err) })
    end
end

-- Hide other players' gem drops (owner-only pickups = owner-only visible).
do
    local ok, err = pcall(function()
        require(script.Systems.DropVisibility).start()
    end)
    if not ok then
        Logger:Warn("Failed to start DropVisibility", { error = tostring(err) })
    end
end

-- Dock the Current Quest tracker below the player bar, restyled to match.
do
    local ok, err = pcall(function()
        require(script.Systems.QuestTrackerStyle).start()
    end)
    if not ok then
        Logger:Warn("Failed to start QuestTrackerStyle", { error = tostring(err) })
    end
end

-- Skin the left-side currency boxes with area-colored pills.
do
    local ok, err = pcall(function()
        require(script.Systems.CurrencyStyle).start()
        require(script.Systems.CurrencyStack).start()
        require(script.Systems.TopHudStack).start()
        require(script.Systems.HotbarFlank).start()
        require(script.Systems.TutorialController).start()
        require(script.Systems.AudioPrefs).start()
    end)
    if not ok then
        Logger:Warn("Failed to start CurrencyStyle", { error = tostring(err) })
    end
end

-- RealmAtmosphere: retints Lighting to the player's current realm (heaven/hell skin on the
-- same map, World S3) — driven by the server-published CurrentRealm attribute.
do
    local ok, err = pcall(function()
        require(script.Systems.RealmAtmosphere).start()
    end)
    if not ok then
        Logger:Warn("Failed to start RealmAtmosphere", { error = tostring(err) })
    end
end

-- RealmHellFaces: floating demon faces in the Hell sky (clones the server-preloaded model).
do
    local ok, err = pcall(function()
        require(script.Systems.RealmHellFaces).start()
    end)
    if not ok then
        Logger:Warn("Failed to start RealmHellFaces", { error = tostring(err) })
    end
end

-- Start Matter loop with client systems
local systemsList = {}
for name, system in pairs(systems) do
    table.insert(systemsList, system)
    Logger:Debug("Registered client system", { system = name })
end

-- Start the client ECS loop (temporarily disabled for debugging)
-- loop:begin({
--     default = systemsList,
--     -- Add Matter debugger in Studio (disabled due to dependency issues)
--     -- debugger = game:GetService("RunService"):IsStudio() and Matter.Debugger.new() or nil
-- })

Logger:Info("Client Matter ECS loop started", { systemCount = #systemsList })

-- Set up economy networking
local Signals = require(ReplicatedStorage.Shared.Network.Signals)

-- Map Net RemoteEvents to prior handler names
local function onPurchaseResult(data) end -- placeholder

local noticeGui
local noticeTween
local unlockedAreas = {}
local watchedPrompts = {}

local function showNotice(message, isWarning)
    local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui")
    if not playerGui then
        return
    end

    if not noticeGui then
        noticeGui = Instance.new("ScreenGui")
        noticeGui.Name = "GameplayNoticeGui"
        noticeGui.ResetOnSpawn = false
        noticeGui.IgnoreGuiInset = true

        local label = Instance.new("TextLabel")
        label.Name = "Notice"
        label.AnchorPoint = Vector2.new(0.5, 0)
        label.Position = UDim2.new(0.5, 0, 0, 96)
        label.Size = UDim2.new(0, 420, 0, 44)
        label.BackgroundTransparency = 0.12
        label.BorderSizePixel = 0
        label.Font = Enum.Font.GothamBold
        label.TextSize = 18
        label.TextWrapped = true
        label.TextColor3 = Color3.fromRGB(255, 255, 255)
        label.Visible = false
        label.Parent = noticeGui

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = label

        noticeGui.Parent = playerGui
    end

    local label = noticeGui:FindFirstChild("Notice")
    if not label then
        return
    end

    if noticeTween then
        noticeTween:Cancel()
        noticeTween = nil
    end

    label.Text = message
    label.BackgroundColor3 = isWarning and Color3.fromRGB(190, 70, 40)
        or Color3.fromRGB(30, 120, 80)
    label.TextTransparency = 0
    label.BackgroundTransparency = 0.12
    label.Visible = true

    task.delay(2.8, function()
        if label.Text ~= message then
            return
        end
        noticeTween = TweenService:Create(label, TweenInfo.new(0.25), {
            TextTransparency = 1,
            BackgroundTransparency = 1,
        })
        noticeTween:Play()
        noticeTween.Completed:Once(function()
            if label.Text == message then
                label.Visible = false
            end
        end)
    end)
end

local function refreshUnlockedAreas()
    table.clear(unlockedAreas)

    local rawValue = localPlayer:GetAttribute(UNLOCKED_AREAS_ATTRIBUTE)
    if type(rawValue) ~= "string" or rawValue == "" then
        return
    end

    local ok, decoded = pcall(function()
        return HttpService:JSONDecode(rawValue)
    end)
    if not ok or type(decoded) ~= "table" then
        return
    end

    for _, areaId in ipairs(decoded) do
        if type(areaId) == "string" then
            unlockedAreas[areaId] = true
        end
    end
end

local function updateZoneTravelPrompt(prompt)
    if not prompt:IsA("ProximityPrompt") or prompt.Name ~= TRAVEL_PROMPT_NAME then
        return
    end

    local targetAreaId = prompt:GetAttribute("TargetAreaId")
    local requiresUnlockPrompt = prompt:GetAttribute("RequiresUnlockPrompt") == true
    prompt.Enabled = requiresUnlockPrompt
        and type(targetAreaId) == "string"
        and unlockedAreas[targetAreaId] ~= true
end

local function updateAllZoneTravelPrompts()
    for _, instance in ipairs(workspace:GetDescendants()) do
        if instance:IsA("ProximityPrompt") and instance.Name == TRAVEL_PROMPT_NAME then
            updateZoneTravelPrompt(instance)
        end
    end
end

local function watchZoneTravelPrompt(prompt)
    if not prompt:IsA("ProximityPrompt") or prompt.Name ~= TRAVEL_PROMPT_NAME then
        return
    end

    updateZoneTravelPrompt(prompt)
    if watchedPrompts[prompt] then
        return
    end

    local connections = {}
    watchedPrompts[prompt] = connections

    for _, attributeName in ipairs({ "TargetAreaId", "RequiresUnlockPrompt" }) do
        table.insert(
            connections,
            prompt:GetAttributeChangedSignal(attributeName):Connect(function()
                updateZoneTravelPrompt(prompt)
            end)
        )
    end

    table.insert(
        connections,
        prompt.AncestryChanged:Connect(function(_, parent)
            if parent then
                return
            end

            for _, connection in ipairs(connections) do
                connection:Disconnect()
            end
            watchedPrompts[prompt] = nil
        end)
    )
end

refreshUnlockedAreas()
updateAllZoneTravelPrompts()

workspace.DescendantAdded:Connect(function(instance)
    if instance:IsA("ProximityPrompt") and instance.Name == TRAVEL_PROMPT_NAME then
        watchZoneTravelPrompt(instance)
    end
end)

for _, instance in ipairs(workspace:GetDescendants()) do
    if instance:IsA("ProximityPrompt") and instance.Name == TRAVEL_PROMPT_NAME then
        watchZoneTravelPrompt(instance)
    end
end

localPlayer:GetAttributeChangedSignal(UNLOCKED_AREAS_ATTRIBUTE):Connect(function()
    refreshUnlockedAreas()
    updateAllZoneTravelPrompts()
end)

Signals.CurrencyUpdate.OnClientEvent:Connect(function(data)
    Logger:Debug("Currency updated", data)
end)
Signals.ShopItems.OnClientEvent:Connect(function(data)
    Logger:Debug("Shop items received", { itemCount = #data.items })
end)
Signals.PurchaseSuccess.OnClientEvent:Connect(function(data)
    Logger:Info("Purchase successful", data)
end)
Signals.SellSuccess.OnClientEvent:Connect(function(data)
    Logger:Info("Sell successful", data)
end)
Signals.EconomyError.OnClientEvent:Connect(function(data)
    Logger:Warn("Economy error", data)
end)
Signals.UpgradeResult.OnClientEvent:Connect(function(data)
    Logger:Info("Upgrade result", data)
end)
Signals.ZoneUnlockResult.OnClientEvent:Connect(function(data)
    Logger:Info("Zone unlock result", data)
    if data and data.ok == true then
        local displayName = data.unlock and data.unlock.displayName
            or data.zoneId
            or data.areaId
            or "Zone"
        if data.areaId then
            unlockedAreas[tostring(data.areaId)] = true
            updateAllZoneTravelPrompts()
        end
        showNotice("Unlocked " .. tostring(displayName), false)
        -- Fire the config-driven celebration (sound + burst) for unlocking new ground.
        pcall(function()
            require(script.Systems.GameEvents).fire("area_unlocked", { area = data.areaId })
        end)
    elseif data and data.reason then
        local unlock = data.unlock or {}
        local displayName = unlock.displayName or data.zoneId or "that area"
        if data.reason == "insufficient_currency" and unlock.currency and unlock.cost then
            showNotice(
                string.format(
                    "Need %d %s to unlock %s.",
                    unlock.cost,
                    unlock.currency,
                    tostring(displayName)
                ),
                true
            )
        elseif data.reason == "required_zone_locked" and data.requiredZoneId then
            showNotice(
                string.format(
                    "Unlock %s before %s.",
                    tostring(data.requiredZoneId),
                    tostring(displayName)
                ),
                true
            )
        else
            showNotice("Zone unlock failed: " .. tostring(data.reason), true)
        end
    end
end)
Signals.ZoneTravelResult.OnClientEvent:Connect(function(data)
    Logger:Info("Zone travel result", data)
    if not data or data.ok == true then
        return
    end

    if data.reason == "locked" then
        local unlock = data.unlock or {}
        local displayName = unlock.displayName or data.targetZoneId or "That area"
        local costText = ""
        if unlock.currency and unlock.cost and unlock.cost > 0 then
            costText = string.format(" Cost: %d %s.", unlock.cost, unlock.currency)
        end
        showNotice(tostring(displayName) .. " is locked." .. costText, true)
    else
        showNotice("Travel failed: " .. tostring(data.reason or "unknown"), true)
    end
end)
Signals.PlayerDebugInfo.OnClientEvent:Connect(function(data)
    print("🔍 SERVER DEBUG INFO:", data)
end)
Signals.ActiveEffects.OnClientEvent:Connect(function(data)
    if _G.MenuManager then
        local effectsPanel = _G.MenuManager:GetPanel("Effects")
        if effectsPanel and effectsPanel.UpdateEffects then
            effectsPanel:UpdateEffects(data)
        end
    end
end)
Signals.EnchantStationOpened.OnClientEvent:Connect(function(data)
    local displayName = data and data.displayName or "Enchanter"
    if _G.MenuManager then
        _G.MenuManager:OpenEnchantPanel("bounce_in")
        local enchantPanel = _G.MenuManager:GetPanel("Enchant")
        if enchantPanel and enchantPanel.SetStationContext then
            enchantPanel:SetStationContext(data)
        end
    end
    showNotice(tostring(displayName) .. " ready.", false)
end)
Signals.EnchantPetResult.OnClientEvent:Connect(function(data)
    if _G.MenuManager then
        local enchantPanel = _G.MenuManager:GetPanel("Enchant")
        if enchantPanel and enchantPanel.HandleEnchantResult then
            enchantPanel:HandleEnchantResult(data)
        end
    end

    if data and data.ok == true then
        if _G.MenuManager then
            local inventoryPanel = _G.MenuManager:GetPanel("Inventory")
            if inventoryPanel and inventoryPanel.RefreshFromRealData then
                inventoryPanel:RefreshFromRealData()
            end
        end
        return
    end

    local reason = data and data.reason or "unknown"
    if reason == "requires_station" then
        showNotice("Use an enchanter station before rerolling pet enchants.", true)
    elseif reason == "insufficient_currency" then
        showNotice(
            string.format(
                "Need %d %s to reroll.",
                tonumber(data.cost) or 0,
                tostring(data.currency or "currency")
            ),
            true
        )
    elseif reason == "slot_locked" then
        showNotice("That enchant slot is locked. Level the pet to unlock more slots.", true)
    else
        showNotice("Enchant failed: " .. tostring(reason), true)
    end
end)

-- Old NetworkBridge code removed

-- Preload sounds client-side for instant playback
task.spawn(function()
    local soundsFolder = ReplicatedStorage:WaitForChild("Assets", 10)
        and ReplicatedStorage.Assets:FindFirstChild("Sounds")
    if soundsFolder then
        local soundInstances = {}
        for _, child in ipairs(soundsFolder:GetChildren()) do
            if child:IsA("Sound") then
                table.insert(soundInstances, child)
            end
        end
        if #soundInstances > 0 then
            local ok, err = pcall(function()
                ContentProvider:PreloadAsync(soundInstances)
            end)
            if ok then
                Logger:Info("Preloaded sounds", { count = #soundInstances })
            else
                Logger:Warn("Failed to preload sounds", { error = tostring(err) })
            end
        end
    end
end)

-- Set up input handling
local function onInputBegan(input, gameProcessed)
    if gameProcessed then
        return
    end

    -- Example input handling
    if input.KeyCode == Enum.KeyCode.Tab then
        -- Toggle inventory
        Logger:Debug("Inventory toggle requested")
    elseif input.KeyCode == Enum.KeyCode.M then
        -- Toggle main menu
        Logger:Debug("Main menu toggle requested")
    elseif input.KeyCode == Enum.KeyCode.B then
        -- Open shop
        Signals.ShopItems:FireServer({ request = true })
        Logger:Debug("Shop requested")
    end
end

UserInputService.InputBegan:Connect(onInputBegan)

-- Player move-speed buff (Swift / Super Speed): WalkSpeed = base * (1 + MoveSpeedBuff) while the
-- buff is live. Pets already read MoveSpeedBuff (PetFollowController); this applies it to the PLAYER
-- too, so Swift speeds self AND squad.
local function activeMoveBuff()
    -- move_speed axis = power (MoveSpeedBuff) + potion (MoveSpeedBuffPotion), each gated by its own
    -- Until and ADDED (a Swift potion stacks with the Swift power instead of clobbering it).
    local now = os.time()
    local total = 0
    if (localPlayer:GetAttribute("MoveSpeedBuffUntil") or 0) > now then
        total += localPlayer:GetAttribute("MoveSpeedBuff") or 0
    end
    if (localPlayer:GetAttribute("MoveSpeedBuffPotionUntil") or 0) > now then
        total += localPlayer:GetAttribute("MoveSpeedBuffPotion") or 0
    end
    return total
end

local function applyWalkSpeed()
    local char = localPlayer.Character
    local humanoid = char and char:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid.WalkSpeed = gameConfig.WorldSettings.WalkSpeed * (1 + activeMoveBuff())
    end
end

-- Wait for character spawn
local function onCharacterAdded(character)
    Logger:Info("Character spawned", {
        character = character.Name,
        spawnTime = tick(),
    })

    -- Wait for character to fully load
    local humanoid = character:WaitForChild("Humanoid")
    local rootPart = character:WaitForChild("HumanoidRootPart")

    -- Apply game configuration to character (WalkSpeed includes any live move-speed buff)
    humanoid.WalkSpeed = gameConfig.WorldSettings.WalkSpeed * (1 + activeMoveBuff())
    humanoid.JumpPower = gameConfig.WorldSettings.JumpPower

    -- Set up character-specific systems
    -- This is where you'd initialize things like:
    -- - First person camera for FPS
    -- - Pet following for simulators
    -- - Tool selection for tower defense
end

-- Connect character events
if localPlayer.Character then
    onCharacterAdded(localPlayer.Character)
end
localPlayer.CharacterAdded:Connect(onCharacterAdded)

-- Re-apply WalkSpeed whenever the move-speed buff changes (Swift toggled/granted, or a timed cast
-- expires) so player speed tracks the buff live, not just on spawn.
localPlayer:GetAttributeChangedSignal("MoveSpeedBuff"):Connect(applyWalkSpeed)
localPlayer:GetAttributeChangedSignal("MoveSpeedBuffUntil"):Connect(applyWalkSpeed)
localPlayer:GetAttributeChangedSignal("MoveSpeedBuffPotion"):Connect(applyWalkSpeed)
localPlayer:GetAttributeChangedSignal("MoveSpeedBuffPotionUntil"):Connect(applyWalkSpeed)

-- Wait for data to load
local function waitForDataLoaded()
    local dataLoaded = localPlayer:GetAttribute("DataLoaded")
    if dataLoaded then
        Logger:Info("Player data loaded")

        -- Get initial currency values
        local coins = localPlayer:GetAttribute("Coins") or 0
        local gems = localPlayer:GetAttribute("Gems") or 0
        local level = localPlayer:GetAttribute("Level") or 1

        Logger:Info("Initial player state", {
            coins = coins,
            gems = gems,
            level = level,
        })

        -- Initialize UI with player data
        -- UIController:InitializeWithPlayerData({
        --     coins = coins,
        --     gems = gems,
        --     level = level
        -- })

        return true
    end

    return false
end

-- Check if data is already loaded, or wait for it
if not waitForDataLoaded() then
    Logger:Info("Waiting for player data to load...")

    local connection
    connection = localPlayer:GetAttributeChangedSignal("DataLoaded"):Connect(function()
        if waitForDataLoaded() then
            connection:Disconnect()
        end
    end)

    -- Timeout after 30 seconds
    task.delay(30, function()
        if connection and connection.Connected then
            connection:Disconnect()
            Logger:Error("Timeout waiting for player data")
        end
    end)
end

-- Performance monitoring (client-side)
task.spawn(function()
    while true do
        task.wait(60) -- Log performance every minute

        local stats = {
            fps = 1 / game:GetService("RunService").Heartbeat:Wait(),
            ping = localPlayer:GetNetworkPing() * 1000, -- Convert to ms
            memoryUsage = game:GetService("Stats"):GetTotalMemoryUsageMb(),
        }

        Logger:Debug("Client performance", stats)

        -- Warn if performance is poor
        if stats.fps < 30 then
            Logger:Warn("Low FPS detected", { fps = stats.fps })
        end

        if stats.ping > 200 then
            Logger:Warn("High ping detected", { ping = stats.ping })
        end
    end
end)

-- Handle game shutdown (only available on server)
-- Note: BindToClose only works on server, clients handle disconnection differently
if game:GetService("RunService"):IsServer() then
    game:BindToClose(function()
        Logger:Info("Client shutting down...")

        -- Stop Matter loop
        loop:stop()

        Logger:Info("Client shutdown complete")
    end)
end

-- Set up error handling (ScriptContext deprecated, using LogService instead)
local LogService = game:GetService("LogService")
LogService.MessageOut:Connect(function(message, messageType)
    if messageType == Enum.MessageType.MessageError then
        -- Skip Studio plugin errors + asset-access/load noise (already printed natively with a
        -- clickable "Click to share access" link; don't mirror/bury them).
        if
            not string.find(message, "plugin")
            and not string.find(message, "Plugin")
            and not (Logger.isSuppressedConsoleError and Logger.isSuppressedConsoleError(message))
        then
            Logger:Error("Client script error", {
                message = message,
                messageType = messageType.Name,
            })
        end
    end
end)

Logger:Info("🎯 Game Template Client started successfully!", {
    gameMode = gameConfig.GameMode,
    systemCount = #systemsList,
    player = localPlayer.Name,
})

local function waitForPetThumbnailsReady(timeoutSeconds)
    local assets = ReplicatedStorage:WaitForChild("Assets", timeoutSeconds or 10)
    if not assets then
        Logger:Warn("Asset prewarm skipped; Assets folder did not replicate")
        return nil
    end

    if assets:GetAttribute("PetThumbnailsReady") == true then
        return assets
    end

    local completed = false
    local connection = assets:GetAttributeChangedSignal("PetThumbnailsReady"):Connect(function()
        completed = assets:GetAttribute("PetThumbnailsReady") == true
    end)

    local startedAt = os.clock()
    while not completed and os.clock() - startedAt < (timeoutSeconds or 10) do
        task.wait(0.1)
    end
    connection:Disconnect()

    if completed or assets:GetAttribute("PetThumbnailsReady") == true then
        return assets
    end

    Logger:Warn("Asset prewarm timed out waiting for pet thumbnails", {
        timeout = timeoutSeconds or 10,
        thumbnailCount = assets:GetAttribute("PetThumbnailCount"),
        thumbnailFailures = assets:GetAttribute("PetThumbnailFailures"),
    })
    return assets
end

local function collectViewportFrames(root)
    local viewports = {}
    if not root then
        return viewports
    end

    for _, descendant in ipairs(root:GetDescendants()) do
        if descendant:IsA("ViewportFrame") then
            table.insert(viewports, descendant)
        end
    end
    return viewports
end

local function prewarmPetThumbnailViewports()
    local assets = waitForPetThumbnailsReady(12)
    if not assets then
        return
    end

    local images = assets:FindFirstChild("Images")
    if not images then
        Logger:Warn("Asset prewarm skipped; Images folder missing")
        return
    end

    local sourceViewports = {}
    for _, folderName in ipairs({ "Pets", "Eggs" }) do
        for _, viewport in ipairs(collectViewportFrames(images:FindFirstChild(folderName))) do
            table.insert(sourceViewports, viewport)
        end
    end

    if #sourceViewports == 0 then
        Logger:Warn("Asset prewarm skipped; no thumbnail ViewportFrames found")
        return
    end

    local playerGui = localPlayer:WaitForChild("PlayerGui", 10)
    if not playerGui then
        Logger:Warn("Asset prewarm skipped; PlayerGui missing")
        return
    end

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "PetThumbnailPrewarm"
    screenGui.DisplayOrder = 0
    screenGui.IgnoreGuiInset = true
    screenGui.ResetOnSpawn = false
    screenGui.Parent = playerGui

    local container = Instance.new("Frame")
    container.Name = "ViewportCache"
    container.BackgroundTransparency = 1
    container.BorderSizePixel = 0
    container.Position = UDim2.new(1, 128, 1, 128)
    container.Size = UDim2.new(0, 64, 0, 64)
    container.ClipsDescendants = true
    container.Parent = screenGui

    local preloadInstances = {}
    for index, sourceViewport in ipairs(sourceViewports) do
        local clone = sourceViewport:Clone()
        clone.Name = "Prewarm" .. tostring(index)
        clone.Size = UDim2.new(0, 64, 0, 64)
        clone.Position = UDim2.new(0, 0, 0, 0)
        clone.BackgroundTransparency = 1
        clone.Visible = true
        clone.Parent = container
        table.insert(preloadInstances, clone)
    end

    pcall(function()
        ContentProvider:PreloadAsync(preloadInstances)
    end)

    RunService.RenderStepped:Wait()
    RunService.RenderStepped:Wait()
    screenGui:Destroy()

    Logger:Info("Prewarmed pet thumbnail ViewportFrames", {
        count = #sourceViewports,
        ready = assets:GetAttribute("PetThumbnailsReady"),
        failures = assets:GetAttribute("PetThumbnailFailures"),
    })

    -- Also prewarm the FLAT thumbnail textures — the uploaded image ids the cards render as
    -- ImageLabels (configs/pet_thumbnail_assets). PreloadAsync pulls them into the client cache so a
    -- big inventory's cards are instant on first open instead of streaming in one by one.
    pcall(function()
        local reg = require(ReplicatedStorage.Configs:WaitForChild("pet_thumbnail_assets"))
        local ids, seen = {}, {}
        local function add(id)
            if id and not seen[id] then
                seen[id] = true
                ids[#ids + 1] = id
            end
        end
        for _, byVariant in pairs(reg.pets or {}) do
            for _, id in pairs(byVariant) do
                add(id)
            end
        end
        for _, id in pairs(reg.eggs or {}) do
            add(id)
        end
        if #ids > 0 then
            ContentProvider:PreloadAsync(ids)
            Logger:Info("Prewarmed flat pet thumbnail textures", { count = #ids })
        end
    end)
end

-- The REAL game UI boot: MenuManager + every panel + BaseUI + the ClientUIReady gate.
-- (Historically wrapped in RunService:IsStudio() from its "test GUI" days — which meant a
-- PUBLISHED build had NO menus and the boot screen only released via timeout. Always run.)
do
    task.spawn(function()
        -- OLD: require(script.UI.TestEconomyGUI) -- REMOVED: Replaced by AdminPanel
        -- OLD: require(script.UI.SimpleEffectsGUI) -- REMOVED: Replaced by EffectsPanel in MenuManager
        -- OLD: require(script.UI.GlobalEffectsGUI) -- REMOVED: Replaced by EffectsPanel in MenuManager

        -- Load proper game UI system
        task.wait(1) -- Wait a moment for other UIs to load

        -- Initialize MenuManager
        local MenuManager = require(script.UI.MenuManager)
        local menuManager = MenuManager.new()

        -- Make MenuManager globally accessible for network updates
        _G.MenuManager = menuManager

        -- Build BaseUI FIRST and on its own, BEFORE the panels. The HUD (ProfessionalBaseUI) must
        -- not depend on any panel constructor succeeding. Previously panels were built first, so a
        -- single panel ctor that hung or errored (e.g. on a NON-OWNER account whose assets fail to
        -- load in Studio) stopped the boot before BaseUI was created -> ProfessionalBaseUI never
        -- appeared -> every HUD styler infinite-yielded waiting for it -> the "old HUD". BaseUI's
        -- _createUI is synchronous with no asset waits, so building it here always produces the HUD.
        do
            local ok, err = pcall(function()
                local baseUI = require(script.UI.BaseUI).new()
                baseUI:SetMenuManager(menuManager)
                baseUI:Show()
            end)
            if not ok then
                Logger:Error("UI boot: BaseUI failed to build", { error = tostring(err) })
            end
        end

        -- Release the loading-screen gate as soon as the HUD exists, so a slow or broken panel can
        -- never strand the player on the boot screen. Panels register below; opening one before it
        -- finishes is a brief, self-correcting window — far better than a frozen client.
        localPlayer:SetAttribute("ClientUIReady", true)

        -- Build + register every panel in ITS OWN isolated task. A panel that ERRORS is caught by
        -- pcall; a panel that YIELDS FOREVER (an asset/data dependency that never resolves for this
        -- account) hangs only its own task. Neither can block the HUD or the other panels. The
        -- per-panel building/ready logs mean any hang is NAMED in the console: a "building X" with
        -- no matching "ready X" is the culprit panel.
        local function buildPanel(name, builder)
            task.spawn(function()
                Logger:Info("UI boot: building panel", { panel = name })
                local ok, err = pcall(function()
                    menuManager:RegisterPanel(name, builder())
                end)
                if ok then
                    Logger:Info("UI boot: panel ready", { panel = name })
                else
                    Logger:Warn("UI boot: panel FAILED", { panel = name, error = tostring(err) })
                end
            end)
        end

        buildPanel("Shop", function()
            return require(script.UI.Menus.RewardShopPanel).new()
        end)
        buildPanel("Inventory", function()
            return require(script.UI.Menus.InventoryPanel).new()
        end)
        buildPanel("Quest", function()
            return require(script.UI.Menus.QuestPanel).new()
        end)
        buildPanel("Daily", function()
            return require(script.UI.Menus.DailyPanel).new()
        end)
        buildPanel("Achievements", function()
            return require(script.UI.Menus.AchievementsPanel).new()
        end)
        buildPanel("Trade", function()
            return require(script.UI.Menus.TradePanel).new()
        end)
        buildPanel("EnhancementSell", function()
            return require(script.UI.Menus.EnhancementSellPanel).new()
        end)
        buildPanel("Effects", function()
            return require(script.UI.Menus.EffectsPanel).new()
        end)
        buildPanel("Enchant", function()
            return require(script.UI.Menus.EnchantPanel).new()
        end)
        buildPanel("PowerChoice", function()
            return require(script.UI.Menus.PowerChoiceMenu).new()
        end)
        -- Admin panel is registered client-side so late admin attribute replication cannot strand
        -- the UI. Server-side AdminService remains the authority for privileged actions.
        buildPanel("Admin", function()
            return require(script.UI.Menus.AdminPanel).new()
        end)

        -- Settings keeps a direct ref to wire the admin-open callback after registration.
        task.spawn(function()
            Logger:Info("UI boot: building panel", { panel = "Settings" })
            local ok, err = pcall(function()
                local settingsPanel = require(script.UI.Menus.SettingsPanel).new()
                menuManager:RegisterPanel("Settings", settingsPanel)
                settingsPanel:SetAdminPanelCallback(function()
                    menuManager:OpenAdminPanel("bounce_in")
                end)
            end)
            if ok then
                Logger:Info("UI boot: panel ready", { panel = "Settings" })
            else
                Logger:Warn("UI boot: panel FAILED", { panel = "Settings", error = tostring(err) })
            end
        end)

        -- Pet-thumbnail prewarm is cosmetic; run it in the BACKGROUND so it never delays the UI/boot.
        -- (It can block ~12s on a timeout, which used to leave MenuManager unavailable early.)
        task.spawn(prewarmPetThumbnailViewports)
    end)
end

-- Initialize EggCurrentTargetService (proximity detection and UI positioning)
task.spawn(function()
    task.wait(0.5) -- Small delay to ensure everything is loaded

    local success, eggCurrentTargetService = pcall(function()
        return require(ReplicatedStorage.Shared.Services.EggCurrentTargetService)
    end)

    if success then
        eggCurrentTargetService:Initialize()
        Logger:Info("EggCurrentTargetService initialized")
    else
        Logger:Error(
            "Failed to initialize EggCurrentTargetService",
            { error = tostring(eggCurrentTargetService) }
        )
    end
end)

-- Initialize EggInteractionService (E key handling)
task.spawn(function()
    task.wait(0.7) -- Small delay after CurrentTargetService

    local success, eggInteractionService = pcall(function()
        return require(ReplicatedStorage.Shared.Services.EggInteractionService)
    end)

    if success then
        eggInteractionService:Initialize()
        Logger:Info("EggInteractionService initialized")
    else
        Logger:Error(
            "Failed to initialize EggInteractionService",
            { error = tostring(eggInteractionService) }
        )
    end
end)
