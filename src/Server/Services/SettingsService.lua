-- SettingsService.lua
--
-- Manages persistent player settings using ProfileStore as the single source of truth.
-- Creates replicated player folders that automatically sync to clients via Roblox's
-- built-in replication system. Handles user preference changes via Signals.
--
-- ARCHITECTURE:
-- 1. ProfileStore contains all settings data (single source of truth)
-- 2. Server creates Player/Settings/DisplayPreferences folders with StringValues
-- 3. Client reads directly from replicated folders (no DataService access needed)
-- 4. Client sends changes via Signals.SaveDisplayPreferences to server
-- 5. Server updates ProfileStore and replicated folders immediately
--
-- This pattern follows InventoryService's approach and leverages Roblox's automatic
-- Player folder replication to avoid complex client-server data synchronization.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Get shared modules
local Signals = require(ReplicatedStorage.Shared.Network.Signals)

local SettingsService = {}
SettingsService.__index = SettingsService

function SettingsService:Init()
    -- Console cleanup: route through Logger only

    -- Get injected dependencies
    self._logger = self._modules.Logger
    self._dataService = self._modules.DataService
    self._configLoader = self._modules.ConfigLoader

    -- Dependencies injected

    -- Track player settings folders for replication
    self._playerSettingsFolders = {}

    self._logger:Info("⚙️ SettingsService initializing")

    -- Connect to player events for folder management
    Players.PlayerAdded:Connect(function(player)
        self:_onPlayerAdded(player)
    end)

    Players.PlayerRemoving:Connect(function(player)
        self:_onPlayerRemoving(player)
    end)

    -- Setup Network Signals for settings operations
    self:_setupNetworkSignals()

    self._logger:Info("✅ SettingsService initialized successfully")
end

function SettingsService:Start()
    -- Startup handled via Logger

    -- Create folders for any players already in game
    for _, player in pairs(Players:GetPlayers()) do
        if self._dataService:IsDataLoaded(player) then
            self._logger:Info(
                "Creating settings folders for existing player",
                { player = player.Name }
            )
            self:_createSettingsFolders(player)
        end
    end

    self._logger:Info("🚀 SettingsService started")
    -- Ready
end

-- ═══════════════════════════════════════════════════════════════════════════════════
-- PLAYER FOLDER MANAGEMENT (following InventoryService pattern exactly)
-- ═══════════════════════════════════════════════════════════════════════════════════

function SettingsService:_onPlayerAdded(player)
    -- Wait for DataService to load player profile
    task.spawn(function()
        local maxWait = 10 -- seconds
        local waited = 0

        while not self._dataService:IsDataLoaded(player) and waited < maxWait do
            task.wait(0.1)
            waited = waited + 0.1
        end

        if self._dataService:IsDataLoaded(player) then
            self:_createSettingsFolders(player)
        else
            self._logger:Warn("⚠️ SETTINGS - Player data not loaded in time", {
                player = player.Name,
                waitedSeconds = waited,
            })
        end
    end)
end

function SettingsService:_onPlayerRemoving(player)
    -- Cleanup folder references
    self._playerSettingsFolders[player] = nil

    self._logger:Debug("🧹 SETTINGS - Cleaned up folder references", {
        player = player.Name,
    })
end

function SettingsService:_createSettingsFolders(player)
    self._logger:Info("⚙️ SETTINGS - Creating settings folders", {
        player = player.Name,
    })

    local data = self._dataService:GetData(player)
    if not data then
        self._logger:Error("❌ SETTINGS - No player data found", {
            player = player.Name,
        })
        return
    end

    -- Ensure Settings exists in ProfileStore (single source of truth)
    if not data.Settings then
        data.Settings = {
            MusicEnabled = true,
            SFXEnabled = true,
            GraphicsQuality = "Auto",
            DisplayPreferences = {},
            AutoSystems = {},
            PetFormation = self:_defaultPetFormation(),
            PetAttackStyle = self:_defaultPetAttackStyle(),
            InventoryCardScale = "small",
            EnemyLevelOffset = 0,
        }
    end

    -- Ensure DisplayPreferences exists
    if not data.Settings.DisplayPreferences then
        data.Settings.DisplayPreferences = {}
    end
    if not data.Settings.AutoSystems then
        data.Settings.AutoSystems = {}
    end

    -- Create main Settings folder (will replicate to client)
    local settingsFolder = Instance.new("Folder")
    settingsFolder.Name = "Settings"
    settingsFolder.Parent = player

    -- Store reference
    self._playerSettingsFolders[player] = settingsFolder

    -- Create DisplayPreferences subfolder
    local displayPrefFolder = Instance.new("Folder")
    displayPrefFolder.Name = "DisplayPreferences"
    displayPrefFolder.Parent = settingsFolder

    -- Create StringValues for each display preference (from ProfileStore)
    for context, method in pairs(data.Settings.DisplayPreferences) do
        local prefValue = Instance.new("StringValue")
        prefValue.Name = context
        prefValue.Value = method
        prefValue.Parent = displayPrefFolder
    end

    local autoSystemsFolder = Instance.new("Folder")
    autoSystemsFolder.Name = "AutoSystems"
    autoSystemsFolder.Parent = settingsFolder

    self:_replicateAutoSystemSettings(player)
    self:_applyPetFormation(player)
    self:_applyPetAttackStyle(player)
    self:_applyInventoryCardScale(player)
    self:_applyEnemyLevelOffset(player)

    self._logger:Info("✅ SETTINGS - Settings folders created successfully", {
        player = player.Name,
        displayPreferences = data.Settings.DisplayPreferences,
    })
end

function SettingsService:_replicateAutoSystemSettings(player)
    local data = self._dataService:GetData(player)
    local settingsFolder = self._playerSettingsFolders[player]
    if not data or not data.Settings or not settingsFolder then
        return
    end

    local autoSystems = data.Settings.AutoSystems or {}
    local autoFolder = settingsFolder:FindFirstChild("AutoSystems")
    if not autoFolder then
        autoFolder = Instance.new("Folder")
        autoFolder.Name = "AutoSystems"
        autoFolder.Parent = settingsFolder
    end

    local targetSettings = autoSystems.auto_target or {}
    local targetFolder = autoFolder:FindFirstChild("AutoTarget") or Instance.new("Folder")
    targetFolder.Name = "AutoTarget"
    targetFolder.Parent = autoFolder
    self:_upsertValue(targetFolder, "Enabled", "BoolValue", targetSettings.enabled == true)
    self:_upsertValue(targetFolder, "Mode", "StringValue", targetSettings.mode or "nearest")
    self:_upsertValue(
        targetFolder,
        "SelectedCurrency",
        "StringValue",
        targetSettings.selected_currency or "crystals"
    )

    local deleteSettings = autoSystems.auto_delete or {}
    local deleteFolder = autoFolder:FindFirstChild("AutoDelete") or Instance.new("Folder")
    deleteFolder.Name = "AutoDelete"
    deleteFolder.Parent = autoFolder
    self:_upsertValue(deleteFolder, "Enabled", "BoolValue", deleteSettings.enabled == true)
    self:_syncBoolSetFolder(deleteFolder, "Rarities", deleteSettings.rarities)
    self:_syncBoolSetFolder(deleteFolder, "PetTypes", deleteSettings.pet_types)
    self:_syncBoolSetFolder(deleteFolder, "Variants", deleteSettings.variants)

    local hatchSettings = autoSystems.hatch or {}
    local hatchFolder = autoFolder:FindFirstChild("Hatch") or Instance.new("Folder")
    hatchFolder.Name = "Hatch"
    hatchFolder.Parent = autoFolder
    self:_upsertValue(
        hatchFolder,
        "SelectedCount",
        "IntValue",
        self:_clampHatchSelectedCount(hatchSettings.selected_count)
    )
    self:_upsertValue(
        hatchFolder,
        "ActionMode",
        "StringValue",
        self:_sanitizeHatchActionMode(hatchSettings.action_mode)
    )
    local modesFolder = hatchFolder:FindFirstChild("Modes") or Instance.new("Folder")
    modesFolder.Name = "Modes"
    modesFolder.Parent = hatchFolder
    local modes = self:_sanitizeHatchModeSettings(hatchSettings.modes)
    for optionName, enabled in pairs(modes) do
        self:_upsertValue(modesFolder, optionName, "BoolValue", enabled == true)
    end
end

function SettingsService:_upsertValue(parent, name, className, value)
    local instance = parent:FindFirstChild(name)
    if not instance or instance.ClassName ~= className then
        if instance then
            instance:Destroy()
        end
        instance = Instance.new(className)
        instance.Name = name
        instance.Parent = parent
    end
    instance.Value = value
end

function SettingsService:_syncBoolSetFolder(parent, name, values)
    local folder = parent:FindFirstChild(name)
    if not folder or not folder:IsA("Folder") then
        if folder then
            folder:Destroy()
        end
        folder = Instance.new("Folder")
        folder.Name = name
        folder.Parent = parent
    end

    local active = {}
    if type(values) == "table" then
        for key, value in pairs(values) do
            local id = nil
            if type(key) == "number" then
                id = type(value) == "string" and value or nil
            elseif value == true then
                id = tostring(key)
            end

            if id and id ~= "" then
                active[id] = true
                self:_upsertValue(folder, id, "BoolValue", true)
            end
        end
    end

    for _, child in ipairs(folder:GetChildren()) do
        if not active[child.Name] then
            child:Destroy()
        end
    end
end

function SettingsService:_updateDisplayPreference(player, context, method)
    local data = self._dataService:GetData(player)
    if not data or not data.Settings then
        self._logger:Error("❌ No player settings data found", {
            player = player.Name,
            context = context,
        })
        return false
    end

    -- Update ProfileStore (single source of truth)
    data.Settings.DisplayPreferences[context] = method

    -- Update replicated folder for immediate client access
    local settingsFolder = self._playerSettingsFolders[player]
    if settingsFolder then
        local displayPrefFolder = settingsFolder:FindFirstChild("DisplayPreferences")
        if displayPrefFolder then
            local prefValue = displayPrefFolder:FindFirstChild(context)
            if prefValue then
                prefValue.Value = method
            else
                -- Create new preference
                local newPrefValue = Instance.new("StringValue")
                newPrefValue.Name = context
                newPrefValue.Value = method
                newPrefValue.Parent = displayPrefFolder
            end
        end
    end

    self._logger:Info("✅ Updated display preference", {
        player = player.Name,
        context = context,
        method = method,
    })

    return true
end

function SettingsService:_getEggSystemConfig()
    if not self._configLoader then
        return {}
    end

    local ok, config = pcall(function()
        return self._configLoader:LoadConfig("egg_system")
    end)
    if ok and type(config) == "table" then
        return config
    end
    return {}
end

function SettingsService:_clampHatchSelectedCount(value)
    local eggConfig = self:_getEggSystemConfig()
    local hatching = eggConfig.hatching or {}
    local panel = eggConfig.ui and eggConfig.ui.hatch_panel or {}
    local defaultCount = tonumber(panel.default_selected_count)
        or tonumber(hatching.default_requested_count)
        or 1
    local maxCount = math.max(1, math.floor(tonumber(hatching.max_count) or 99))
    local count = math.floor(tonumber(value) or defaultCount)
    return math.clamp(count, 1, maxCount)
end

function SettingsService:_sanitizeHatchActionMode(value)
    local eggConfig = self:_getEggSystemConfig()
    local panel = eggConfig.ui and eggConfig.ui.hatch_panel or {}
    local defaultMode = tostring(panel.default_action_mode or "single")
    local valid = { single = true, max = true, auto = true }
    if not valid[defaultMode] then
        defaultMode = "single"
    end

    value = tostring(value or defaultMode):lower()
    if valid[value] then
        return value
    end
    return defaultMode
end

function SettingsService:_getHatchModeDefaults()
    local eggConfig = self:_getEggSystemConfig()
    local modesConfig = eggConfig.ui and eggConfig.ui.hatch_panel and eggConfig.ui.hatch_panel.modes
        or {}
    local defaults = {}

    for key, cfg in pairs(modesConfig) do
        if type(cfg) == "table" then
            local optionName = tostring(cfg.option or key)
            if optionName ~= "" then
                defaults[optionName] = cfg.default_enabled == true
            end
        end
    end

    if next(defaults) == nil then
        defaults.showHatch = true
        defaults.goldenMode = false
        defaults.chargedMode = false
        defaults.fastHatch = false
        defaults.skipHatch = false
        defaults.silentHatch = false
    end

    return defaults
end

function SettingsService:_sanitizeHatchModeSettings(modes)
    local sanitized = self:_getHatchModeDefaults()
    if type(modes) ~= "table" then
        return sanitized
    end

    for optionName in pairs(sanitized) do
        if modes[optionName] ~= nil then
            sanitized[optionName] = modes[optionName] == true
        end
    end
    return sanitized
end

function SettingsService:_setHatchSelectedCount(player, count)
    if type(count) == "table" then
        count = count.selectedCount or count.selected_count or count.count
    end

    local data = self._dataService:GetData(player)
    if not data then
        return false
    end

    data.Settings = data.Settings or {}
    data.Settings.AutoSystems = data.Settings.AutoSystems or {}
    data.Settings.AutoSystems.hatch = data.Settings.AutoSystems.hatch or {}
    data.Settings.AutoSystems.hatch.selected_count = self:_clampHatchSelectedCount(count)
    self:_replicateAutoSystemSettings(player)

    self._logger:Info("Updated hatch selected count", {
        player = player.Name,
        selectedCount = data.Settings.AutoSystems.hatch.selected_count,
    })

    return true
end

function SettingsService:_setHatchActionMode(player, actionMode)
    if type(actionMode) == "table" then
        actionMode = actionMode.actionMode or actionMode.action_mode or actionMode.mode
    end

    local data = self._dataService:GetData(player)
    if not data then
        return false
    end

    data.Settings = data.Settings or {}
    data.Settings.AutoSystems = data.Settings.AutoSystems or {}
    data.Settings.AutoSystems.hatch = data.Settings.AutoSystems.hatch or {}
    data.Settings.AutoSystems.hatch.action_mode = self:_sanitizeHatchActionMode(actionMode)
    self:_replicateAutoSystemSettings(player)

    self._logger:Info("Updated hatch action mode", {
        player = player.Name,
        actionMode = data.Settings.AutoSystems.hatch.action_mode,
    })

    return true
end

function SettingsService:_setHatchModes(player, modes)
    if type(modes) == "table" and type(modes.modes) == "table" then
        modes = modes.modes
    end

    local data = self._dataService:GetData(player)
    if not data then
        return false
    end

    data.Settings = data.Settings or {}
    data.Settings.AutoSystems = data.Settings.AutoSystems or {}
    data.Settings.AutoSystems.hatch = data.Settings.AutoSystems.hatch or {}
    data.Settings.AutoSystems.hatch.modes = self:_sanitizeHatchModeSettings(modes)
    self:_replicateAutoSystemSettings(player)

    self._logger:Info("Updated hatch mode settings", {
        player = player.Name,
        modes = data.Settings.AutoSystems.hatch.modes,
    })

    return true
end

-- ═══════════════════════════════════════════════════════════════════════════════════
-- PET FORMATION (equipped-pet follow layout — persisted; applied as the player's
-- PetFormationMode attribute, which PetFollowController reads each frame)
-- ═══════════════════════════════════════════════════════════════════════════════════

local PET_FORMATION_MODES = { conga = true, risers = true, arc = true }

function SettingsService:_defaultPetFormation()
    local ok, cfg = pcall(function()
        return self._configLoader:LoadConfig("pet_follow")
    end)
    local mode = ok and cfg and cfg.formation and cfg.formation.default_mode
    if type(mode) == "string" and PET_FORMATION_MODES[mode] then
        return mode
    end
    return "risers"
end

function SettingsService:_sanitizePetFormation(value)
    if type(value) == "table" then
        value = value.mode or value.formation or value.value
    end
    value = type(value) == "string" and string.lower(value) or nil
    if value and PET_FORMATION_MODES[value] then
        return value
    end
    return self:_defaultPetFormation()
end

-- Push the saved formation onto the player as a (replicated) attribute the client reads.
function SettingsService:_applyPetFormation(player)
    local data = self._dataService:GetData(player)
    local mode = self:_defaultPetFormation()
    if data and data.Settings and type(data.Settings.PetFormation) == "string" then
        mode = self:_sanitizePetFormation(data.Settings.PetFormation)
    end
    player:SetAttribute("PetFormationMode", mode)
    return mode
end

function SettingsService:_setPetFormation(player, value)
    local data = self._dataService:GetData(player)
    if not data then
        return false
    end

    data.Settings = data.Settings or {}
    local mode = self:_sanitizePetFormation(value)
    data.Settings.PetFormation = mode
    player:SetAttribute("PetFormationMode", mode)

    self._logger:Info("Updated pet formation", { player = player.Name, mode = mode })
    return true
end

local PET_ATTACK_STYLES = {
    orbit = true,
    static_ring = true,
    lunge = true,
    spiral = true,
    pincer = true,
    firing_line = true,
    swarm = true,
}

function SettingsService:_defaultPetAttackStyle()
    local ok, cfg = pcall(function()
        return self._configLoader:LoadConfig("pet_follow")
    end)
    local style = ok and cfg and cfg.attack and cfg.attack.style
    if type(style) == "string" and PET_ATTACK_STYLES[style] then
        return style
    end
    return "orbit"
end

function SettingsService:_sanitizePetAttackStyle(value)
    if type(value) == "table" then
        value = value.style or value.mode or value.value
    end
    value = type(value) == "string" and string.lower(value) or nil
    if value and PET_ATTACK_STYLES[value] then
        return value
    end
    return self:_defaultPetAttackStyle()
end

-- Push the saved attack style onto the player as the (replicated) PetAttackStyle attribute the
-- client's PetFollowController reads.
function SettingsService:_applyPetAttackStyle(player)
    local data = self._dataService:GetData(player)
    local style = self:_defaultPetAttackStyle()
    if data and data.Settings and type(data.Settings.PetAttackStyle) == "string" then
        style = self:_sanitizePetAttackStyle(data.Settings.PetAttackStyle)
    end
    player:SetAttribute("PetAttackStyle", style)
    return style
end

function SettingsService:_setPetAttackStyle(player, value)
    local data = self._dataService:GetData(player)
    if not data then
        return false
    end

    data.Settings = data.Settings or {}
    local style = self:_sanitizePetAttackStyle(value)
    data.Settings.PetAttackStyle = style
    player:SetAttribute("PetAttackStyle", style)

    self._logger:Info("Updated pet attack style", { player = player.Name, style = style })
    return true
end

-- ═══════════════════════════════════════════════════════════════════════════════════
-- INVENTORY CARD SCALE (pet-card grid size — persisted; applied as the player's
-- InventoryCardScale attribute, which InventoryPanel reads/listens to)
-- ═══════════════════════════════════════════════════════════════════════════════════

local INVENTORY_CARD_SCALES = { small = true, medium = true, large = true }

function SettingsService:_sanitizeInventoryCardScale(value)
    if type(value) == "table" then
        value = value.scale or value.size or value.value
    end
    value = type(value) == "string" and string.lower(value) or nil
    if value and INVENTORY_CARD_SCALES[value] then
        return value
    end
    return "small"
end

-- Push the saved scale onto the player as a (replicated) attribute the client reads.
function SettingsService:_applyInventoryCardScale(player)
    local data = self._dataService:GetData(player)
    local scale = "small"
    if data and data.Settings and type(data.Settings.InventoryCardScale) == "string" then
        scale = self:_sanitizeInventoryCardScale(data.Settings.InventoryCardScale)
    end
    player:SetAttribute("InventoryCardScale", scale)
    return scale
end

function SettingsService:_setInventoryCardScale(player, value)
    local data = self._dataService:GetData(player)
    if not data then
        return false
    end

    data.Settings = data.Settings or {}
    local scale = self:_sanitizeInventoryCardScale(value)
    data.Settings.InventoryCardScale = scale
    player:SetAttribute("InventoryCardScale", scale)

    self._logger:Info("Updated inventory card scale", { player = player.Name, scale = scale })
    return true
end

-- ═══════════════════════════════════════════════════════════════════════════════════
-- ENEMY LEVEL OFFSET (per-player difficulty knob — shifts enemy spawn level vs the
-- player by -3..+3; applied as the EnemyLevelOffset attribute EnemyService reads on spawn)
-- ═══════════════════════════════════════════════════════════════════════════════════

local ENEMY_LEVEL_OFFSET_MIN = -3
local ENEMY_LEVEL_OFFSET_MAX = 3

function SettingsService:_sanitizeEnemyLevelOffset(value)
    if type(value) == "table" then
        value = value.offset or value.value or value.level
    end
    value = tonumber(value)
    if not value then
        return 0
    end
    value = math.floor(value + 0.5)
    return math.clamp(value, ENEMY_LEVEL_OFFSET_MIN, ENEMY_LEVEL_OFFSET_MAX)
end

-- Push the saved offset onto the player as a (replicated) attribute EnemyService reads.
function SettingsService:_applyEnemyLevelOffset(player)
    local data = self._dataService:GetData(player)
    local offset = 0
    if data and data.Settings and data.Settings.EnemyLevelOffset ~= nil then
        offset = self:_sanitizeEnemyLevelOffset(data.Settings.EnemyLevelOffset)
    end
    player:SetAttribute("EnemyLevelOffset", offset)
    return offset
end

function SettingsService:_setEnemyLevelOffset(player, value)
    local data = self._dataService:GetData(player)
    if not data then
        return false
    end

    data.Settings = data.Settings or {}
    local offset = self:_sanitizeEnemyLevelOffset(value)
    data.Settings.EnemyLevelOffset = offset
    player:SetAttribute("EnemyLevelOffset", offset)

    self._logger:Info("Updated enemy level offset", { player = player.Name, offset = offset })
    return true
end

-- ═══════════════════════════════════════════════════════════════════════════════════
-- NETWORK SIGNALS (following InventoryService pattern)
-- ═══════════════════════════════════════════════════════════════════════════════════

function SettingsService:_setupNetworkSignals()
    -- Handle display preference updates from client
    Signals.SaveDisplayPreferences.OnServerEvent:Connect(function(player, preferences)
        self._logger:Info("📥 Received display preferences from client", {
            player = player.Name,
            preferences = preferences,
        })

        if not preferences or type(preferences) ~= "table" then
            self._logger:Warn("❌ Invalid preferences data from client", {
                player = player.Name,
                preferences = preferences,
            })
            return
        end

        -- Update each preference
        for context, method in pairs(preferences) do
            self:_updateDisplayPreference(player, context, method)
        end
    end)

    Signals.HatchSettings_SetCount.OnServerEvent:Connect(function(player, count)
        self:_setHatchSelectedCount(player, count)
    end)

    Signals.HatchSettings_SetActionMode.OnServerEvent:Connect(function(player, actionMode)
        self:_setHatchActionMode(player, actionMode)
    end)

    Signals.HatchSettings_SetModes.OnServerEvent:Connect(function(player, modes)
        self:_setHatchModes(player, modes)
    end)

    Signals.Settings_SetPetFormation.OnServerEvent:Connect(function(player, payload)
        self:_setPetFormation(player, payload)
    end)

    Signals.Settings_SetPetAttackStyle.OnServerEvent:Connect(function(player, payload)
        self:_setPetAttackStyle(player, payload)
    end)

    Signals.Settings_SetInventoryCardScale.OnServerEvent:Connect(function(player, payload)
        self:_setInventoryCardScale(player, payload)
    end)

    Signals.Settings_SetEnemyLevelOffset.OnServerEvent:Connect(function(player, payload)
        self:_setEnemyLevelOffset(player, payload)
    end)

    self._logger:Info("📡 Settings network signals configured")
end

-- ═══════════════════════════════════════════════════════════════════════════════════
-- PUBLIC API
-- ═══════════════════════════════════════════════════════════════════════════════════

function SettingsService:GetDisplayPreference(player, context)
    local data = self._dataService:GetData(player)
    if data and data.Settings and data.Settings.DisplayPreferences then
        return data.Settings.DisplayPreferences[context]
    end
    return nil
end

function SettingsService:SetHatchSelectedCount(player, count)
    return self:_setHatchSelectedCount(player, count)
end

function SettingsService:SetHatchActionMode(player, actionMode)
    return self:_setHatchActionMode(player, actionMode)
end

function SettingsService:SetHatchModes(player, modes)
    return self:_setHatchModes(player, modes)
end

function SettingsService:ReplicateAutoSystemSettings(player)
    self:_replicateAutoSystemSettings(player)
end

function SettingsService:SetPetFormation(player, value)
    return self:_setPetFormation(player, value)
end

function SettingsService:GetPetFormation(player)
    return self:_applyPetFormation(player)
end

function SettingsService:SetPetAttackStyle(player, value)
    return self:_setPetAttackStyle(player, value)
end

function SettingsService:GetPetAttackStyle(player)
    return self:_applyPetAttackStyle(player)
end

function SettingsService:SetInventoryCardScale(player, value)
    return self:_setInventoryCardScale(player, value)
end

function SettingsService:GetInventoryCardScale(player)
    return self:_applyInventoryCardScale(player)
end

function SettingsService:SetEnemyLevelOffset(player, value)
    return self:_setEnemyLevelOffset(player, value)
end

function SettingsService:GetEnemyLevelOffset(player)
    return self:_applyEnemyLevelOffset(player)
end

return SettingsService
