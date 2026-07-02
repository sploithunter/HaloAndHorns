--[[
    AutoTargetService

    Phase 5 server authority for auto systems:
    - persists target mode and selected currency choices;
    - selects breakable targets on the server;
    - persists and evaluates hatch auto-delete filters.

    The legacy Low/High buttons still work through compatibility toggles, but
    clients now ask the server to choose a target instead of sending an id.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AutoTargetService = {}
AutoTargetService.__index = AutoTargetService

local logger
local configLoader
local dataService
local breakableService
local settingsService
local monetization
local productIdMapper
local autoConfig
local petsConfig

local PAID_AUTOTARGET_PASS_ID = "auto_target_high"

local lastAttackRequest = {}

local function ensurePlayerFlags(player)
    local free = player:FindFirstChild("FreeTarget")
    if not free then
        free = Instance.new("BoolValue")
        free.Name = "FreeTarget"
        free.Value = false
        free.Parent = player
    end

    local paid = player:FindFirstChild("PaidTarget")
    if not paid then
        paid = Instance.new("BoolValue")
        paid.Name = "PaidTarget"
        paid.Value = false
        paid.Parent = player
    end

    return free, paid
end

local function asSet(value)
    local result = {}
    if type(value) ~= "table" then
        return result
    end

    for key, child in pairs(value) do
        if type(key) == "number" then
            if type(child) == "string" and child ~= "" then
                result[child] = true
            end
        elseif child == true then
            result[tostring(key)] = true
        end
    end
    return result
end

local function getBreakableId(model)
    local idValue = model and model:FindFirstChild("BreakableID")
    return idValue and tonumber(idValue.Value) or 0
end

local function getRootPosition(player)
    local character = player and player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    return root and root.Position or nil
end

local function upsertValue(parent, name, className, value)
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
    return instance
end

local function syncBoolSetFolder(parent, name, values)
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
                upsertValue(folder, id, "BoolValue", true)
            end
        end
    end

    for _, child in ipairs(folder:GetChildren()) do
        if not active[child.Name] then
            child:Destroy()
        end
    end

    return folder
end

local function getWorldShort(world)
    if world == "SpawnWorld" then
        return "Spawn"
    end
    return world
end

-- ZONE GATE (Jason's alt-account find: "unlocking from a single player perspective
-- apparently unlocks it for everybody"): ore SPAWNS are server-global (any present
-- unlocked player lights a biome), so per-MINER enforcement happens here. Reads the
-- published UnlockedAreasJson attribute with a per-player decode cache (hot path).
local HttpService = game:GetService("HttpService")
local _unlockCache = setmetatable({}, { __mode = "k" })
local function zoneUnlockedFor(player, zoneId)
    if not player or type(zoneId) ~= "string" or zoneId == "" then
        return true
    end
    local json = player:GetAttribute("UnlockedAreasJson")
    if json == nil then
        return true -- not published yet (boot grace) — never brick Spawn mining
    end
    local cache = _unlockCache[player]
    if not cache or cache.json ~= json then
        local set = {}
        local ok, arr = pcall(function()
            return HttpService:JSONDecode(json)
        end)
        if ok and type(arr) == "table" then
            for _, id in ipairs(arr) do
                set[tostring(id)] = true
            end
        end
        cache = { json = json, set = set }
        _unlockCache[player] = cache
    end
    return cache.set[zoneId] == true
end

function AutoTargetService:Init()
    logger = self._modules.Logger
    configLoader = self._modules.ConfigLoader
    dataService = self._modules.DataService
    breakableService = self._modules.BreakableService
    settingsService = self._modules.SettingsService
    monetization = self._modules.MonetizationService
    productIdMapper = self._modules.ProductIdMapper
    autoConfig = configLoader:LoadConfig("auto_systems")
    petsConfig = configLoader:LoadConfig("pets")

    local Signals = require(ReplicatedStorage.Shared.Network.Signals)

    Signals.AutoTarget_ToggleFree.OnServerEvent:Connect(function(player)
        self:_toggleCompatibilityMode(player, "free")
    end)
    Signals.AutoTarget_TogglePaid.OnServerEvent:Connect(function(player)
        self:_toggleCompatibilityMode(player, "paid")
    end)
    Signals.AutoTarget_SetMode.OnServerEvent:Connect(function(player, payload)
        self:SetAutoTargetMode(player, payload)
    end)
    Signals.AutoTarget_RequestAttack.OnServerEvent:Connect(function(player)
        self:RequestAutoTargetAttack(player)
    end)
    Signals.AutoDelete_SetFilters.OnServerEvent:Connect(function(player, payload)
        self:SetAutoDeleteFilters(player, payload)
    end)

    Players.PlayerAdded:Connect(function(player)
        ensurePlayerFlags(player)
        task.spawn(function()
            local waited = 0
            while dataService and not dataService:IsDataLoaded(player) and waited < 10 do
                task.wait(0.1)
                waited += 0.1
            end
            self:_ensureSettings(player)
            self:_syncCompatibilityFlags(player)
            task.delay(0.2, function()
                self:_sendStatus(player)
            end)
        end)
    end)

    Players.PlayerRemoving:Connect(function(player)
        lastAttackRequest[player] = nil
    end)

    for _, player in ipairs(Players:GetPlayers()) do
        ensurePlayerFlags(player)
        self:_ensureSettings(player)
        self:_syncCompatibilityFlags(player)
        self:_sendStatus(player)
    end

    logger:Info("AutoTargetService initialized", {
        context = "AutoTargetService",
        modeCount = self:_countModes(),
    })
end

function AutoTargetService:_countModes()
    local modes = autoConfig and autoConfig.auto_target and autoConfig.auto_target.modes or {}
    local count = 0
    for _ in pairs(modes) do
        count += 1
    end
    return count
end

function AutoTargetService:_defaultSettings()
    local targetConfig = autoConfig.auto_target or {}
    local deleteConfig = autoConfig.auto_delete or {}
    local deleteDefaults = deleteConfig.defaults or {}

    return {
        auto_target = {
            enabled = targetConfig.default_enabled == true,
            mode = targetConfig.default_mode or "nearest",
            selected_currency = targetConfig.default_selected_currency or "crystals",
        },
        auto_delete = {
            enabled = deleteConfig.default_enabled == true,
            rarities = asSet(deleteDefaults.rarities),
            pet_types = asSet(deleteDefaults.pet_types),
            variants = asSet(deleteDefaults.variants),
        },
    }
end

function AutoTargetService:_ensureSettings(player)
    local data = dataService and dataService:GetData(player)
    if not data then
        return self:_defaultSettings()
    end

    data.Settings = data.Settings or {}
    data.Settings.AutoSystems = data.Settings.AutoSystems or {}

    local defaults = self:_defaultSettings()
    local settings = data.Settings.AutoSystems
    settings.auto_target = type(settings.auto_target) == "table" and settings.auto_target
        or defaults.auto_target
    settings.auto_delete = type(settings.auto_delete) == "table" and settings.auto_delete
        or defaults.auto_delete

    local targetSettings = settings.auto_target
    if
        type(targetSettings.mode) ~= "string" or not self:_isValidTargetMode(targetSettings.mode)
    then
        targetSettings.mode = defaults.auto_target.mode
    end
    if type(targetSettings.enabled) ~= "boolean" then
        targetSettings.enabled = defaults.auto_target.enabled
    end
    -- ONE-TIME migration (2026-06-10, Farm-Near-on-by-default): profiles created under the
    -- old default have enabled=false STAMPED in (indistinguishable from a player choice),
    -- so the config flip alone never reaches them — Jason followed the farm tutorial step
    -- exactly and nothing mined. Flip every profile to the new default once; toggles made
    -- after this migration persist as the player's real choice.
    if not targetSettings.farm_default_v2 then
        targetSettings.farm_default_v2 = true
        targetSettings.enabled = defaults.auto_target.enabled
    end
    if
        type(targetSettings.selected_currency) ~= "string"
        or targetSettings.selected_currency == ""
    then
        targetSettings.selected_currency = defaults.auto_target.selected_currency
    end

    local deleteSettings = settings.auto_delete
    if type(deleteSettings.enabled) ~= "boolean" then
        deleteSettings.enabled = defaults.auto_delete.enabled
    end
    deleteSettings.rarities = asSet(deleteSettings.rarities)
    deleteSettings.pet_types = asSet(deleteSettings.pet_types)
    deleteSettings.variants = asSet(deleteSettings.variants)

    return settings
end

function AutoTargetService:_getSettings(player)
    return self:_ensureSettings(player)
end

function AutoTargetService:_isValidTargetMode(mode)
    local modes = autoConfig and autoConfig.auto_target and autoConfig.auto_target.modes or {}
    return type(mode) == "string" and modes[mode] ~= nil
end

function AutoTargetService:_isValidCurrency(currency)
    return type(currency) == "string" and configLoader:GetCurrency(currency) ~= nil
end

function AutoTargetService:_ownsPaidAutoTarget(player)
    local owns = player:GetAttribute("IsAdmin") == true or RunService:IsStudio()
    if monetization and monetization.PlayerOwnsPass and productIdMapper then
        owns = owns or monetization:PlayerOwnsPass(player, PAID_AUTOTARGET_PASS_ID)
    end
    return owns
end

function AutoTargetService:_sendStatus(player)
    local Signals = require(ReplicatedStorage.Shared.Network.Signals)
    local free, paid = ensurePlayerFlags(player)
    local settings = self:_getSettings(player)
    local targetSettings = settings.auto_target or {}
    local deleteSettings = settings.auto_delete or {}

    Signals.AutoTarget_Status:FireClient(player, {
        free = free.Value,
        paid = paid.Value,
        active = targetSettings.enabled == true,
        mode = targetSettings.mode,
        selected_currency = targetSettings.selected_currency,
        auto_delete = {
            enabled = deleteSettings.enabled == true,
            rarities = deleteSettings.rarities or {},
            pet_types = deleteSettings.pet_types or {},
            variants = deleteSettings.variants or {},
        },
    })
end

function AutoTargetService:_replicateAutoDeleteSettings(player, deleteSettings)
    local settingsFolder = player:FindFirstChild("Settings")
    local autoFolder = settingsFolder and settingsFolder:FindFirstChild("AutoSystems")
    if not autoFolder then
        return
    end

    local deleteFolder = autoFolder:FindFirstChild("AutoDelete")
    if not deleteFolder or not deleteFolder:IsA("Folder") then
        if deleteFolder then
            deleteFolder:Destroy()
        end
        deleteFolder = Instance.new("Folder")
        deleteFolder.Name = "AutoDelete"
        deleteFolder.Parent = autoFolder
    end

    deleteSettings = type(deleteSettings) == "table" and deleteSettings or {}
    upsertValue(deleteFolder, "Enabled", "BoolValue", deleteSettings.enabled == true)
    syncBoolSetFolder(deleteFolder, "Rarities", deleteSettings.rarities)
    syncBoolSetFolder(deleteFolder, "PetTypes", deleteSettings.pet_types)
    syncBoolSetFolder(deleteFolder, "Variants", deleteSettings.variants)
end

function AutoTargetService:_syncCompatibilityFlags(player)
    local free, paid = ensurePlayerFlags(player)
    local settings = self:_getSettings(player)
    local targetSettings = settings.auto_target or {}
    local toggles = autoConfig.auto_target and autoConfig.auto_target.compatibility_toggles or {}

    free.Value = targetSettings.enabled == true
        and targetSettings.mode == (toggles.free_mode or "weakest")
    paid.Value = targetSettings.enabled == true
        and targetSettings.mode == (toggles.paid_mode or "highest_value")
end

function AutoTargetService:SetAutoTargetMode(player, payload)
    payload = type(payload) == "table" and payload or {}
    local mode = tostring(payload.mode or "")
    if mode == "off" or payload.enabled == false then
        local settings = self:_getSettings(player)
        settings.auto_target.enabled = false
        self:_syncCompatibilityFlags(player)
        self:_sendStatus(player)
        self:_requestSave(player, "auto_target_disabled")
        return {
            ok = true,
            enabled = false,
        }
    end

    if not self:_isValidTargetMode(mode) then
        return {
            ok = false,
            error = "invalid_mode",
        }
    end

    local settings = self:_getSettings(player)
    settings.auto_target.enabled = payload.enabled ~= false
    settings.auto_target.mode = mode

    local selectedCurrency = payload.selected_currency or payload.selectedCurrency
    if selectedCurrency ~= nil then
        selectedCurrency = tostring(selectedCurrency)
        if not self:_isValidCurrency(selectedCurrency) then
            return {
                ok = false,
                error = "invalid_currency",
            }
        end
        settings.auto_target.selected_currency = selectedCurrency
    end

    self:_syncCompatibilityFlags(player)
    self:_sendStatus(player)
    self:_requestSave(player, "auto_target_mode")

    return {
        ok = true,
        enabled = settings.auto_target.enabled,
        mode = settings.auto_target.mode,
        selected_currency = settings.auto_target.selected_currency,
    }
end

function AutoTargetService:_toggleCompatibilityMode(player, kind)
    local toggles = autoConfig.auto_target and autoConfig.auto_target.compatibility_toggles or {}
    local mode = kind == "paid" and (toggles.paid_mode or "highest_value")
        or (toggles.free_mode or "weakest")

    if kind == "paid" and not self:_ownsPaidAutoTarget(player) then
        logger:Warn("AutoTarget Paid denied", {
            context = "AutoTargetService",
            player = player.Name,
        })
        self:_sendStatus(player)
        return
    end

    local settings = self:_getSettings(player)
    local targetSettings = settings.auto_target
    if targetSettings.enabled == true and targetSettings.mode == mode then
        self:SetAutoTargetMode(player, { enabled = false })
    else
        self:SetAutoTargetMode(player, { enabled = true, mode = mode })
    end
end

function AutoTargetService:SetAutoDeleteFilters(player, payload)
    payload = type(payload) == "table" and payload or {}
    local settings = self:_getSettings(player)
    local deleteSettings = settings.auto_delete

    if payload.enabled ~= nil then
        deleteSettings.enabled = payload.enabled == true
    end
    deleteSettings.rarities = self:_sanitizeFilterSet(payload.rarities, "rarity")
    deleteSettings.pet_types =
        self:_sanitizeFilterSet(payload.pet_types or payload.petTypes, "pet_type")
    deleteSettings.variants = self:_sanitizeFilterSet(payload.variants, "variant")

    self:_replicateAutoDeleteSettings(player, deleteSettings)
    self:_sendStatus(player)
    if settingsService and settingsService.ReplicateAutoSystemSettings then
        settingsService:ReplicateAutoSystemSettings(player)
    end
    self:_requestSave(player, "auto_delete_filters")

    return {
        ok = true,
        auto_delete = deleteSettings,
    }
end

function AutoTargetService:_sanitizeFilterSet(values, kind)
    local result = {}
    for id in pairs(asSet(values)) do
        if self:_isAllowedFilterId(id, kind) then
            result[id] = true
        end
    end
    return result
end

function AutoTargetService:_isAllowedFilterId(id, kind)
    if kind == "rarity" then
        return petsConfig and petsConfig.rarities and petsConfig.rarities[id] ~= nil
    elseif kind == "pet_type" then
        return petsConfig and petsConfig.pets and petsConfig.pets[id] ~= nil
    elseif kind == "variant" then
        return petsConfig and petsConfig.variants and petsConfig.variants[id] ~= nil
    end
    return false
end

function AutoTargetService:ShouldAutoDeleteHatch(player, hatchResult)
    local settings = self:_getSettings(player)
    local deleteSettings = settings.auto_delete or {}
    local deleteConfig = autoConfig.auto_delete or {}
    if deleteConfig.enabled == false or deleteSettings.enabled ~= true then
        return false, "disabled"
    end
    if type(hatchResult) ~= "table" then
        return false, "invalid_hatch"
    end

    -- ORTHOGONAL HUGES (Jason: deletion of huges+ is "simply denied"): the huge flag
    -- rides the hatch RESULT, not the species — a huge snowflakeowl is still rarity
    -- "common" by family, so the rarity protections below would never catch it. A
    -- player's common-species filter must NEVER eat a fresh huge.
    if hatchResult.huge == true then
        return false, "huge"
    end

    local petId = tostring(hatchResult.pet or hatchResult.id or ""):lower()
    local variant = tostring(hatchResult.variant or "basic"):lower()
    local petData = petsConfig and petsConfig.getPet and petsConfig.getPet(petId, variant)
    if not petData then
        return false, "unknown_pet"
    end

    local rarityId = petData.rarity_id or petData.rarity
    if
        deleteConfig.protect_unique ~= false
        and type(rarityId) == "string"
        and deleteConfig.protected_rarities
        and deleteConfig.protected_rarities[rarityId] == true
    then
        return false, "protected_rarity"
    end

    if deleteSettings.rarities and deleteSettings.rarities[rarityId] == true then
        return true, "rarity"
    end
    if deleteSettings.pet_types and deleteSettings.pet_types[petId] == true then
        return true, "pet_type"
    end
    if deleteSettings.variants and deleteSettings.variants[variant] == true then
        return true, "variant"
    end

    return false, "no_match"
end

function AutoTargetService:_requestSave(player, reason)
    if dataService and dataService.RequestSave then
        dataService:RequestSave(player, reason, {
            debounceSeconds = 5,
        })
    end
end

function AutoTargetService:_getCurrentWorld(player)
    local currentWorld = player:FindFirstChild("CurrentWorld")
    return getWorldShort(currentWorld and currentWorld.Value or "Spawn")
end

-- The player's current area id (ZoneTrackerService SSOT attribute), falling back to the legacy
-- CurrentWorld value so this still works if ZoneTracker hasn't resolved yet.
function AutoTargetService:_getCurrentArea(player)
    local attr = player:GetAttribute("CurrentArea")
    if type(attr) == "string" and attr ~= "" then
        return attr
    end
    return self:_getCurrentWorld(player)
end

function AutoTargetService:_collectCandidates(player, mode)
    local root = workspace:FindFirstChild("Game")
    local breakables = root and root:FindFirstChild("Breakables")
    if not breakables then
        return {}
    end

    local targetConfig = autoConfig.auto_target or {}
    local modeConfig = targetConfig.modes and targetConfig.modes[mode] or {}
    local settings = self:_getSettings(player)
    local selectedCurrency = settings.auto_target and settings.auto_target.selected_currency
    -- Area scoping (the fix for farm low/high crossing zones): each breakable lives in a world
    -- folder named by its biome (Spawn/Lava/Ice/Desert/Meadow), which matches the player's
    -- CurrentArea 1:1. CurrentArea is the reliable ZoneTrackerService SSOT (config-bounds, not the
    -- old stale touch value), so farming stays in whatever biome the player is standing in. Low
    -- (weakest) / High (highest_value) now only re-order targets WITHIN that biome.
    local currentArea = self:_getCurrentArea(player)
    local currentWorldOnly = targetConfig.current_world_only ~= false
    local playerPosition = getRootPosition(player)
    -- Only target breakables within this range (studs). Keeps pets from being assigned
    -- to ore across the map (which made them teleport-snap to it). 0/nil = unlimited.
    local maxTargetDistance = tonumber(targetConfig.max_target_distance) or 0
    local candidates = {}

    for _, typeFolder in ipairs(breakables:GetChildren()) do
        for _, worldFolder in ipairs(typeFolder:GetChildren()) do
            if
                (not currentWorldOnly or getWorldShort(worldFolder.Name) == currentArea)
                -- locked-zone nodes are never candidates: _mine refuses them anyway
                -- (the server gate), so assigning them just strands pets
                and zoneUnlockedFor(player, getWorldShort(worldFolder.Name))
            then
                local items = worldFolder:FindFirstChild("Items")
                if items then
                    for _, model in ipairs(items:GetChildren()) do
                        if model:IsA("Model") and getBreakableId(model) ~= 0 then
                            local hp = tonumber(model:GetAttribute("HP")) or 0
                            local currency = tostring(model:GetAttribute("Currency") or "")
                            if
                                hp > 0
                                and (
                                    modeConfig.requires_currency ~= true
                                    or currency == selectedCurrency
                                )
                            then
                                local pivot = model:GetPivot()
                                local pos = pivot.Position
                                local dist = playerPosition and (pos - playerPosition).Magnitude
                                    or 0
                                if
                                    maxTargetDistance <= 0
                                    or not playerPosition
                                    or dist <= maxTargetDistance
                                then
                                    table.insert(candidates, {
                                        model = model,
                                        id = getBreakableId(model),
                                        value = tonumber(model:GetAttribute("Value")) or 0,
                                        hp = hp,
                                        maxHp = tonumber(model:GetAttribute("MaxHP")) or hp,
                                        currency = currency,
                                        world = worldFolder.Name,
                                        distance = dist,
                                    })
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    return candidates
end

function AutoTargetService:_compareCandidates(a, b, sort)
    if sort == "value_desc" and a.value ~= b.value then
        return a.value > b.value
    elseif sort == "hp_asc" and a.hp ~= b.hp then
        return a.hp < b.hp
    elseif sort == "hp_desc" and a.hp ~= b.hp then
        return a.hp > b.hp
    elseif sort == "distance_asc" and a.distance ~= b.distance then
        return a.distance < b.distance
    end

    if a.value ~= b.value then
        return a.value > b.value
    end
    if a.distance ~= b.distance then
        return a.distance < b.distance
    end
    return a.id < b.id
end

function AutoTargetService:SelectTarget(player, overrideMode)
    local settings = self:_getSettings(player)
    local mode = overrideMode or (settings.auto_target and settings.auto_target.mode)
    if not self:_isValidTargetMode(mode) then
        return nil, {
            ok = false,
            error = "invalid_mode",
        }
    end

    local modeConfig = autoConfig.auto_target.modes[mode]
    local candidates = self:_collectCandidates(player, mode)
    if #candidates == 0 then
        return nil,
            {
                ok = false,
                error = "no_candidates",
                mode = mode,
            }
    end

    table.sort(candidates, function(a, b)
        return self:_compareCandidates(a, b, modeConfig.sort)
    end)

    local best = candidates[1]
    return best.model,
        {
            ok = true,
            id = best.id,
            mode = mode,
            value = best.value,
            hp = best.hp,
            currency = best.currency,
            world = best.world,
            distance = best.distance,
        }
end

function AutoTargetService:RequestAutoTargetAttack(player)
    local settings = self:_getSettings(player)
    if not (settings.auto_target and settings.auto_target.enabled == true) then
        return {
            ok = false,
            error = "disabled",
        }
    end

    -- COMBAT STANCE (Jason): pause auto-farm while the player is in a fight. The auto-farm setting
    -- stays ON (the player never sees it toggle) — assignment just no-ops until EnemyService clears
    -- the InCombat flag, so pets fight / hold formation instead of wandering off to mine mid-battle.
    if player:GetAttribute("InCombat") then
        return {
            ok = false,
            error = "in_combat",
        }
    end

    local interval = tonumber(
        autoConfig.auto_target and autoConfig.auto_target.request_interval_seconds
    ) or 0.3
    local now = os.clock()
    if lastAttackRequest[player] and now - lastAttackRequest[player] < interval then
        return {
            ok = false,
            error = "rate_limited",
        }
    end
    lastAttackRequest[player] = now

    local target, info = self:SelectTarget(player)
    if not target then
        return info
    end

    -- ASSIGNMENT ONLY (Jason: the old 1-damage token was LEGACY, pre-dating the
    -- design firewall "the player amplifies, the pets deal" - it ghost-drained
    -- crystals after a squad wipe and broke them for zero reward). Auto-target
    -- now only ASSIGNS pets to the node; every point of mining damage comes from
    -- the pets (PetFollowService:_mine) or powers (DoTs), both Contrib-credited.
    if breakableService and breakableService.Attack then
        breakableService:Attack(player, {
            id = info.id,
            damage = 0,
        })
    end

    return info
end

return AutoTargetService
