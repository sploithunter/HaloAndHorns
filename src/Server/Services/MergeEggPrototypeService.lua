--[[
    MergeEggPrototypeService — dedicated Merge-place gameplay and cross-place routing.

    One player enters through Home's otherwise-disabled Hall gate, is streamed to one authored
    strip under Workspace.Maps, and deploys the player's owned subset across a fixed nine-station
    lane. World stages own team capacity while egg tier increases composition-aware best-of-N
    replacement quality. Every
    completed draft contributes its weakest result to a session-only player escort reserve.
    Each independently addressed squad owns a disjoint share of the same escalating Waycoin-paying
    enemy waves, which emerge through a temporary portal and march toward one finish
    line. Reset makes the loop repeatable; Exit restores the player's runtime squad and transform.

    There is intentionally no tile-kit or mission-instance world generation here. The map is a
    persistent Studio-authored Model and this service owns only session routing and cleanup.
    Studio adds optional automation controls for balancing runs; published servers use the same
    production service without that dependency.
]]

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local TeleportService = game:GetService("TeleportService")
local Workspace = game:GetService("Workspace")

local BootReadiness = require(ReplicatedStorage.Shared.Boot.BootReadiness)
local HealingSuppression = require(ReplicatedStorage.Shared.Game.HealingSuppression)
local MergeEggDefenseAssignment = require(ReplicatedStorage.Shared.Game.MergeEggDefenseAssignment)
local MergeEggCheckpoint = require(ReplicatedStorage.Shared.Game.MergeEggCheckpoint)
local MergeEggDamageScope = require(ReplicatedStorage.Shared.Game.MergeEggDamageScope)
local MergeEggDraft = require(ReplicatedStorage.Shared.Game.MergeEggDraft)
local MergeEggEquipBest = require(ReplicatedStorage.Shared.Game.MergeEggEquipBest)
local MergeEggEnemyRoster = require(ReplicatedStorage.Shared.Game.MergeEggEnemyRoster)
local MergeEggGateAccess = require(ReplicatedStorage.Shared.Game.MergeEggGateAccess)
local MergeEggPlayerCombat = require(ReplicatedStorage.Shared.Game.MergeEggPlayerCombat)
local MergeEggPlaystate = require(ReplicatedStorage.Shared.Game.MergeEggPlaystate)
local MergeEggPricing = require(ReplicatedStorage.Shared.Game.MergeEggPricing)
local MergeEggRebirth = require(ReplicatedStorage.Shared.Game.MergeEggRebirth)
local MergeEggWaveGenerator = require(ReplicatedStorage.Shared.Game.MergeEggWaveGenerator)
local MergeBulwarkModels = require(ReplicatedStorage.Shared.Game.MergeBulwarkModels)
local MergeBulwarkPersist = require(ReplicatedStorage.Shared.Game.MergeBulwarkPersist)
local MergeBulwarkProgression = require(ReplicatedStorage.Shared.Game.MergeBulwarkProgression)
local MergeBulwarkSlots = require(ReplicatedStorage.Shared.Game.MergeBulwarkSlots)
local MergeCannonPersist = require(ReplicatedStorage.Shared.Game.MergeCannonPersist)
local MergeTierArt = require(ReplicatedStorage.Shared.Game.MergeTierArt)
local MergeTowerBallistics = require(ReplicatedStorage.Shared.Game.MergeTowerBallistics)
local MergeTowerModels = require(ReplicatedStorage.Shared.Game.MergeTowerModels)
local MergeTowerProgression = require(ReplicatedStorage.Shared.Game.MergeTowerProgression)
local MergeTowerSlots = require(ReplicatedStorage.Shared.Game.MergeTowerSlots)
local CombatApplication = require(script.Parent.Parent.CombatApplication)
local PlaceRuntime = require(ReplicatedStorage.Shared.Game.PlaceRuntime)
local SoundGroups = require(ReplicatedStorage.Shared.Effects.SoundGroups)
local Signals = require(ReplicatedStorage.Shared.Network.Signals)
local MergeEggRealmBuilder = require(script.Parent.MergeEggRealmBuilder)

local MergeEggPrototypeService = {}
MergeEggPrototypeService.__index = MergeEggPrototypeService

local CREATE_EGG_PROMPT_NAME = "MergeEggPrototypeCreateEggPrompt"
local MERGE_EGG_PROMPT_NAME = "MergeEggPrototypeMergeEggPrompt"
local RESET_PROMPT_NAME = "MergeEggPrototypeResetPrompt"
local EXIT_PROMPT_NAME = "MergeEggPrototypeExitPrompt"
local TOWER_SIZE_PROMPT_NAME = "MergeEggTowerPreviewPrompt"
local TOWER_FIRE_PROMPT_NAME = "MergeEggTowerFirePrompt"
local TOWER_SIZE_LABEL_NAME = "MergeEggTowerSizeLabel"
local BULWARK_MENU_PROMPT_NAME = "MergeEggBulwarkMenuPrompt"
local BULWARK_MENU_HOST_PREFIX = "MergeEggBulwarkMenuHost_"
local BULWARK_ENGINEER_NAME = "MergeBulwarkEngineer"
local ARTILLERY_COMMANDER_NAME = "MergeArtilleryCommander"
local ARTILLERY_COMMANDER_PROMPT_NAME = "MergeEggArtilleryCommanderPrompt"
local QUARTERMASTER_NAME = "MergeQuartermaster"
local QUARTERMASTER_PROMPT_NAME = "MergeEggQuartermasterPrompt"
local QUARTERMASTER_SPEECH_NAME = "MergeQuartermasterSpeech"
local UPGRADE_EXPERIMENT_CHANNELS = {
    speed = true,
    power = true,
    coins = true,
}

local function disconnect(connection)
    if connection then
        connection:Disconnect()
    end
end

local function firstBasePart(instance)
    if instance and instance:IsA("BasePart") then
        return instance
    end
    return instance and instance:FindFirstChildWhichIsA("BasePart", true) or nil
end

local function findNamedPart(root, name)
    local found = root and root:FindFirstChild(tostring(name or ""), true)
    return firstBasePart(found)
end

local function configuredAuthoringBayId(realmConfig)
    local selector = type(realmConfig) == "table" and realmConfig.authoring_bay or nil
    if type(selector) ~= "table" or selector.enabled ~= true then
        return nil
    end
    local side = string.lower(tostring(selector.side or ""))
    if side ~= "heaven" and side ~= "hell" then
        return nil
    end
    local bayCount = math.max(1, math.floor(tonumber(realmConfig.bays_per_side) or 5))
    local column = math.clamp(math.floor(tonumber(selector.column) or 1), 1, bayCount)
    return string.format("%s_%02d", side, column)
end

local function rgbTriplet(data, fallback)
    data = type(data) == "table" and data or fallback or { 100, 180, 255 }
    return Color3.fromRGB(
        tonumber(data[1]) or 100,
        tonumber(data[2]) or 180,
        tonumber(data[3]) or 255
    )
end

local function characterRoot(player)
    local character = player and player.Character
    return character and character:FindFirstChild("HumanoidRootPart") or nil
end

local function requiredConfigNumber(value, path)
    local resolved = tonumber(value)
    assert(resolved ~= nil, "Missing or invalid numeric config: " .. tostring(path))
    return resolved
end

local function requiredAssetUri(value, path)
    local assetId = string.match(tostring(value or ""), "(%d+)$")
    assert(assetId ~= nil, "Missing or invalid asset config: " .. tostring(path))
    return "rbxassetid://" .. assetId
end

local function stationXOffset(config, teamConfig, fallbackSlot)
    local layout = type(config.station_layout) == "table" and config.station_layout or {}
    local total = math.max(1, math.floor(tonumber(layout.total_positions) or 9))
    local spacing = math.max(1, tonumber(layout.spacing) or 8)
    local slot = math.clamp(
        math.floor(tonumber(teamConfig and teamConfig.position_slot) or fallbackSlot or 1),
        1,
        total
    )
    return (slot - (total + 1) * 0.5) * spacing, slot
end

local function randomPointOnPart(random, part, insetX, insetZ)
    local halfX = math.max(0, part.Size.X * 0.5 - math.max(0, insetX or 0))
    local halfZ = math.max(0, part.Size.Z * 0.5 - math.max(0, insetZ or 0))
    local localPoint = Vector3.new(
        random:NextNumber(-halfX, halfX),
        part.Size.Y * 0.5,
        random:NextNumber(-halfZ, halfZ)
    )
    return part.CFrame:PointToWorldSpace(localPoint)
end

local function playerCombatLevel(player, fallback)
    local value = player and (player:GetAttribute("EffectiveLevel") or player:GetAttribute("Level"))
        or fallback
    return math.max(1, math.floor(tonumber(value) or tonumber(fallback) or 1))
end

local function cloneEnemyDef(source, config, baseLevel, rankTiers)
    config = type(config) == "table" and config or {}
    local def = table.clone(source)
    def.attack = table.clone(source.attack or {})
    def.drop_table = {}
    def.display_name =
        tostring(config.display_name or "Prototype " .. tostring(source.display_name or config.id))
    def.hp = math.max(1, math.floor(tonumber(config.hp) or tonumber(source.hp) or 320))
    def.level = math.max(1, math.floor(tonumber(baseLevel) or tonumber(config.level) or 1))
    local configuredTier = type(rankTiers) == "table" and rankTiers[tostring(config.rank)]
    if configuredTier then
        def.tier = tostring(configuredTier)
    end
    def.armor = math.max(0, tonumber(config.armor) or tonumber(source.armor) or 0)
    def.attack.damage = math.max(0, tonumber(config.damage) or tonumber(def.attack.damage) or 4)
    def.attack.cadence =
        math.max(0.25, tonumber(config.cadence) or tonumber(def.attack.cadence) or 2)
    def.attack.sundering = math.max(0, tonumber(config.sundering) or 0)
    return def
end

local function applyStaticRankPresentation(source, presentation)
    if type(source) ~= "table" then
        return nil
    end
    presentation = type(presentation) == "table" and presentation or {}
    local def = table.clone(source)
    def.attack = table.clone(source.attack or {})
    local requestedTier = presentation.tier and tostring(presentation.tier) or nil
    local alreadyAtTier = requestedTier ~= nil and tostring(source.tier or "") == requestedTier
    if requestedTier then
        def.tier = requestedTier
    end
    def.hp = math.max(
        1,
        math.floor((tonumber(source.hp) or 1) * math.max(0.01, tonumber(presentation.hp_mult) or 1))
    )
    if def.attack.damage ~= nil then
        def.attack.damage = math.max(
            0,
            (tonumber(def.attack.damage) or 0) * math.max(0, tonumber(presentation.dmg_mult) or 1)
        )
    end
    if presentation.role then
        def.role = tostring(presentation.role)
        def.attack_range = nil
    end
    local scaleMultiplier = math.max(0.1, tonumber(presentation.scale_mult) or 1)
    -- Existing authored bosses (for example Magma Wyrm) are already huge. Do not multiply their
    -- boss scale a second time; ordinary models still receive the rank silhouette.
    if not alreadyAtTier and scaleMultiplier ~= 1 then
        def.model_scale = math.max(0.1, tonumber(source.model_scale) or 1) * scaleMultiplier
    end
    if presentation.display_prefix then
        def.display_name = tostring(presentation.display_prefix)
            .. tostring(source.display_name or "Enemy")
    end
    return def
end

local function configuredWaveEnemyCount(wave)
    return MergeEggWaveGenerator.count(wave)
end

local function clonePetDefinition(definition)
    if type(definition) ~= "table" then
        return nil
    end
    return table.clone(definition)
end

local function cloneSquadDefinitions(squad, count)
    local cloned = {}
    local limit = math.max(0, math.floor(tonumber(count) or #(squad or {})))
    for slot = 1, limit do
        local definition = clonePetDefinition(squad and squad[slot])
        if definition then
            cloned[slot] = definition
        end
    end
    return cloned
end

local function cloneEggVisual(eggId, fallbackColor, targetHeight, canQuery)
    local assets = ReplicatedStorage:FindFirstChild("Assets")
    local models = assets and assets:FindFirstChild("Models")
    local eggs = models and models:FindFirstChild("Eggs")
    local template = eggs and eggs:FindFirstChild(tostring(eggId or ""))
    local model = template and template:IsA("Model") and template:Clone() or nil
    if not model then
        model = Instance.new("Model")
        local shell = Instance.new("Part")
        shell.Name = "Egg"
        shell.Shape = Enum.PartType.Ball
        shell.Size = Vector3.new(targetHeight * 0.78, targetHeight, targetHeight * 0.78)
        shell.Material = Enum.Material.SmoothPlastic
        shell.Color = fallbackColor
        shell.Parent = model
        model.PrimaryPart = shell
    end

    for _, descendant in ipairs(model:GetDescendants()) do
        if descendant:IsA("BasePart") then
            descendant.Anchored = true
            descendant.CanCollide = false
            descendant.CanTouch = false
            descendant.CanQuery = canQuery == true
            descendant.Massless = true
        elseif
            descendant:IsA("Script")
            or descendant:IsA("LocalScript")
            or descendant:IsA("ModuleScript")
        then
            descendant:Destroy()
        end
    end
    model.PrimaryPart = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
    if not model.PrimaryPart then
        model:Destroy()
        return nil
    end
    local height = math.max(0.01, model:GetExtentsSize().Y)
    pcall(function()
        model:ScaleTo(model:GetScale() * math.max(0.1, targetHeight / height))
    end)
    return model
end

local function squadDefinitionCount(squad, count)
    local total = 0
    local limit = math.max(0, math.floor(tonumber(count) or #(squad or {})))
    for slot = 1, limit do
        if squad and squad[slot] then
            total += 1
        end
    end
    return total
end

local function combatCadenceMultiplier(config)
    local combat = (config and config.combat) or {}
    local value = tonumber(combat.attack_cadence_multiplier)
    if not value or value <= 0 then
        return 1
    end
    return math.clamp(value, 0.25, 8)
end

-- Translate the model's forward visual extent onto its authoritative movement position. Enemy
-- visuals are client-interpolated from MoveTarget; their server pivots normally remain at spawn.
local function leadingBoundsPoint(model, movementPosition, direction)
    if
        not (model and model.Parent)
        or typeof(movementPosition) ~= "Vector3"
        or typeof(direction) ~= "Vector3"
    then
        return nil, 0
    end
    local horizontal = Vector3.new(direction.X, 0, direction.Z)
    if horizontal.Magnitude <= 0 then
        return nil, 0
    end
    horizontal = horizontal.Unit
    local boundsCFrame, boundsSize = model:GetBoundingBox()
    local boundsOffset = boundsCFrame.Position - model:GetPivot().Position
    local extent = math.abs(horizontal:Dot(boundsCFrame.RightVector)) * boundsSize.X * 0.5
        + math.abs(horizontal:Dot(boundsCFrame.UpVector)) * boundsSize.Y * 0.5
        + math.abs(horizontal:Dot(boundsCFrame.LookVector)) * boundsSize.Z * 0.5
    return movementPosition + boundsOffset + horizontal * extent, extent
end

function MergeEggPrototypeService:Init()
    self._logger = self._modules and self._modules.Logger
    self._configLoader = self._modules and self._modules.ConfigLoader
    self._npcPrincipalService = self._modules and self._modules.NpcPrincipalService
    self._enemyService = self._modules and self._modules.EnemyService
    self._petFollowService = self._modules and self._modules.PetFollowService
    self._eggService = self._modules and self._modules.EggService
    self._dropService = self._modules and self._modules.DropService
    self._economyService = self._modules and self._modules.EconomyService
    self._dataService = self._modules and self._modules.DataService
    self._inventoryService = self._modules and self._modules.InventoryService
    self._petGrantService = self._modules and self._modules.PetGrantService
    self._settingsService = self._modules and self._modules.SettingsService
    self._automationService = self._modules and self._modules.AutomationService
    self._powerService = self._modules and self._modules.PowerService
    self._potionShopService = self._modules and self._modules.PotionShopService
    self._combatTutorialService = self._modules and self._modules.CombatTutorialService
    self._worldBindingService = self._modules and self._modules.WorldBindingService
    self._zoneService = self._modules and self._modules.ZoneService
    self._config = (self._configLoader and self._configLoader:LoadConfig("merge_egg_prototype"))
        or require(ReplicatedStorage.Configs:WaitForChild("merge_egg_prototype"))
    self._placesConfig = (self._configLoader and self._configLoader:LoadConfig("places"))
        or require(ReplicatedStorage.Configs:WaitForChild("places"))
    self._internalAccountsConfig = (
        self._configLoader and self._configLoader:LoadConfig("internal_accounts")
    ) or require(ReplicatedStorage.Configs:WaitForChild("internal_accounts"))
    self._realm = MergeEggRealmBuilder.new(self._config.realm_layout, self._logger)
    self._enemiesConfig = (self._configLoader and self._configLoader:LoadConfig("enemies"))
        or require(ReplicatedStorage.Configs:WaitForChild("enemies"))
    self._petsConfig = (self._configLoader and self._configLoader:LoadConfig("pets"))
        or require(ReplicatedStorage.Configs:WaitForChild("pets"))
    self._petRolesConfig = (self._configLoader and self._configLoader:LoadConfig("pet_roles"))
        or require(ReplicatedStorage.Configs:WaitForChild("pet_roles"))
    self._combatConfig = (self._configLoader and self._configLoader:LoadConfig("combat"))
        or require(ReplicatedStorage.Configs:WaitForChild("combat"))
    self._soundsConfig = (self._configLoader and self._configLoader:LoadConfig("sounds"))
        or require(ReplicatedStorage.Configs:WaitForChild("sounds"))
    self._activeByPlayer = setmetatable({}, { __mode = "k" })
    self._towerShots = {}
    self._enteringByPlayer = setmetatable({}, { __mode = "k" })
    self._enteringRecordByPlayer = setmetatable({}, { __mode = "k" })
    self._combatTrainingReturns = setmetatable({}, { __mode = "k" })
    self._world = nil
    self._gatePrompt = nil
    self._upgradeSweepGeneration = 0
    self._upgradeSweepRunning = false
    self._upgradeSweepPhase = nil
    self._upgradeSweepResults = {}
end

function MergeEggPrototypeService:_isDedicatedMergePlace()
    return PlaceRuntime.isMerge(game.PlaceId, self._placesConfig)
end

function MergeEggPrototypeService:_hasPreviewAccess(player)
    local access = (self._config.gate or {}).access or {}
    if RunService:IsStudio() and access.studio_bypass == true then
        return true
    end
    return MergeEggGateAccess.allows(access, self._internalAccountsConfig, player and player.UserId)
end

function MergeEggPrototypeService:_allowsGameplayActions()
    return RunService:IsStudio() or self:_isDedicatedMergePlace()
end

function MergeEggPrototypeService:_recordFor(player)
    return player and self._activeByPlayer[player] or nil
end

function MergeEggPrototypeService:_isRecordActive(record)
    return record ~= nil and record.player ~= nil and self._activeByPlayer[record.player] == record
end

function MergeEggPrototypeService:_worldFor(record)
    return record and record.world or self._world
end

function MergeEggPrototypeService:_managementUpgradeDefinition(upgradeId)
    local upgrades = type(self._config.management_upgrades) == "table"
            and self._config.management_upgrades
        or {}
    local definitions = type(upgrades.definitions) == "table" and upgrades.definitions or {}
    local definition = definitions[tostring(upgradeId or "")]
    return type(definition) == "table" and definition or nil
end

function MergeEggPrototypeService:_mergeDefenseProgress(player)
    local data = self._dataService and self._dataService:GetData(player)
    if not data then
        return nil
    end
    data.GameData = type(data.GameData) == "table" and data.GameData or {}
    local progress = MergeEggPlayerCombat.normalizeOnboarding(data.GameData.MergeDefense)
    data.GameData.MergeDefense = progress
    return progress
end

function MergeEggPrototypeService:_personalHatchRules()
    local reserve = type(self._config.player_reserve) == "table" and self._config.player_reserve
        or {}
    local fullMode = type(reserve.full_mode) == "table" and reserve.full_mode or {}
    return type(fullMode.personal_hatches) == "table" and fullMode.personal_hatches or {}
end

function MergeEggPrototypeService:_personalHatchProgression(record)
    local progression = self:_eggProgression(record)
    if #progression == 0 then
        return {}
    end
    local hugeCfg = (self._config.team or {}).prototype_huge_progression or {}
    local normalTierCount =
        math.clamp(math.floor(tonumber(hugeCfg.normal_tier_count) or #progression), 1, #progression)
    local personal = {}
    for tier = 1, normalTierCount do
        personal[tier] = progression[tier]
    end
    return personal
end

function MergeEggPrototypeService:_canAwardPersonalHatch(player)
    local data = self._dataService and self._dataService:GetData(player)
    local tutorialDone = data
        and type(data.CombatTutorial) == "table"
        and data.CombatTutorial.done == true
    return MergeEggPlayerCombat.canAwardPersonalHatch(tutorialDone, self:_personalHatchRules())
end

-- Rebirth is the source of truth for personal egg ownership. Area unlocks are a derived, monotonic
-- entitlement reconciled both on entry and immediately after purchase, so existing profiles and an
-- interrupted unlock cannot require another rebirth. ZoneService still owns persistence/events;
-- bypassing purchase requirements here does not bypass LayerService's separate travel level gate.
function MergeEggPrototypeService:_reconcilePersonalHatchAreas(player, rebirthCount)
    local progression = self:_personalHatchProgression(nil)
    local rules = self:_personalHatchRules()
    local tier = MergeEggPlayerCombat.highestPersonalHatchTier(progression, rebirthCount, rules)
    local eggId = progression[tier]
    if player then
        player:SetAttribute("MergeDefensePersonalEggTier", tier)
        player:SetAttribute("MergeDefensePersonalEggId", eggId)
    end

    local areas = MergeEggPlayerCombat.personalHatchAreas(progression, rebirthCount, rules)
    if #areas == 0 then
        return true, tier, eggId
    end
    if not (self._zoneService and self._zoneService.UnlockZone) then
        return false, tier, eggId, "zone_service_unavailable"
    end

    for _, areaId in ipairs(areas) do
        local result = self._zoneService:UnlockZone(player, areaId, {
            bypassRequirements = true,
        })
        if not (result and result.ok == true) then
            self:_log("Warn", "Merge personal egg area reconciliation failed", {
                player = player and player.Name,
                rebirthCount = rebirthCount,
                eggId = eggId,
                areaId = areaId,
                reason = result and result.reason or "unlock_failed",
            })
            return false, tier, eggId, result and result.reason or "unlock_failed"
        end
    end
    return true, tier, eggId
end

function MergeEggPrototypeService:_checkpointOptions()
    local checkpoints = type(self._config.checkpoints) == "table" and self._config.checkpoints or {}
    local layout = type(self._config.station_layout) == "table" and self._config.station_layout
        or {}
    return {
        interval = math.max(1, math.floor(tonumber(checkpoints.interval) or 10)),
        maximumTier = math.max(1, #self:_eggProgression(nil)),
        maximumTeams = math.max(1, math.floor(tonumber(layout.total_positions) or 9)),
    }
end

function MergeEggPrototypeService:_durableCheckpoint(player)
    local progress = self:_mergeDefenseProgress(player)
    return progress and MergeEggCheckpoint.normalize(progress.checkpoint, self:_checkpointOptions())
        or nil
end

function MergeEggPrototypeService:_durablePlaystate(player)
    local progress = self:_mergeDefenseProgress(player)
    return progress and MergeEggPlaystate.normalize(progress.playstate, self:_checkpointOptions())
        or nil
end

-- Logout persistence and combat checkpoints deliberately have different wave semantics. This
-- snapshot keeps the live wallet and every board/deployment choice, while normalizing only the
-- wave back to the prior ten-wave boundary. It mutates the loaded profile synchronously so
-- DataService's before-release hook can include it in ProfileStore's final release save.
function MergeEggPrototypeService:_persistPlaystate(record, reason, requestSave)
    if not (record and record.encounterSpawned == true and self._economyService) then
        return false
    end
    local pricing = self:_earthEggPricing(record)
    local currency = tostring(record.sessionCurrency or pricing.currency)
    local coins = self._economyService:GetCurrency(record.player, currency)
    if coins == nil then
        return false
    end
    local progress = self:_mergeDefenseProgress(record.player)
    if not progress then
        return false
    end
    -- A leftover profile default (hall_coins starts at 100) is not a Merge possession.
    -- Counting it as one saved a Wave-0 playstate that skipped the 600-Waycoin stacks.
    local hasBoard = self:_eggInventoryTotal(record) > 0
        or self:_initializedHatcherCount(record) > 0
        or math.max(1, math.floor(tonumber(record.baseEggTier) or 1)) > self:_baseEggTier(nil)
    -- Tutorial completion is already durable on MergeDefense itself. Do not turn an otherwise
    -- empty Admin Reset state into a saved playstate: on the next join that would suppress the
    -- authored five opening piles. A real wallet balance or any board/deployment does persist.
    local hasPossessions = hasBoard or coins > 0
    if not hasPossessions then
        return false
    end
    local interval = self:_checkpointOptions().interval
    local resumeWave = math.max(0, math.floor(tonumber(record.waveIndex) or 0))
    resumeWave -= resumeWave % interval
    progress.playstate = MergeEggPlaystate.fromRuntime({
        wave = resumeWave,
        currency = currency,
        coins = coins,
        objectiveEggsRemaining = record.objectiveEggsRemaining,
        eggInventory = record.eggInventory,
        recordState = {
            baseEggTier = record.baseEggTier,
        },
    }, record.teams, self:_checkpointOptions())
    record.durablePlaystate = progress.playstate
    if requestSave ~= false and self._dataService and self._dataService.RequestSave then
        self._dataService:RequestSave(record.player, reason or "merge_defense_playstate", {
            debounceSeconds = 0,
            critical = true,
        })
    end
    return true
end

function MergeEggPrototypeService:_persistCheckpoint(record)
    if not (record and record.checkpointSnapshot) then
        return false
    end
    local progress = self:_mergeDefenseProgress(record.player)
    if not progress then
        return false
    end
    progress.checkpoint = MergeEggCheckpoint.fromRuntime(
        record.checkpointSnapshot,
        record.teams,
        self:_checkpointOptions()
    )
    self:_persistPlaystate(record, "merge_defense_checkpoint", false)
    if self._dataService and self._dataService.RequestSave then
        self._dataService:RequestSave(record.player, "merge_defense_checkpoint", {
            debounceSeconds = 0,
            critical = true,
        })
    end
    return true
end

function MergeEggPrototypeService:_tutorialConfig()
    return type(self._config.tutorial) == "table" and self._config.tutorial or {}
end

function MergeEggPrototypeService:_tutorialRequired(record)
    local tutorial = self:_tutorialConfig()
    if tutorial.enabled ~= true then
        return false
    end
    -- Explicitly forced/admin-replayed tutorial steps still own the HUD even when the durable
    -- profile had already completed onboarding.
    if record and record.tutorialActive == true then
        return true
    end
    local progress = record and self:_mergeDefenseProgress(record.player)
    if progress and progress.tutorial_completed == true then
        return false
    end
    local reborn = progress and MergeEggRebirth.normalizeCount(progress.rebirths) > 0
    if tutorial.disable_after_rebirth == true and reborn then
        return false
    end
    return record ~= nil
end

function MergeEggPrototypeService:_tutorialUsesAutoCollector(record)
    local attribute =
        tostring(self:_tutorialConfig().auto_collector_attribute or "AutoCollectorEnabled")
    return record ~= nil and record.player ~= nil and record.player:GetAttribute(attribute) == true
end

function MergeEggPrototypeService:_tutorialWallet(record)
    if not (record and self._economyService) then
        return 0
    end
    local pricing = self:_baseEggCreationCost(record)
    return math.max(
        0,
        math.floor(tonumber(self._economyService:GetCurrency(record.player, pricing.currency)) or 0)
    )
end

function MergeEggPrototypeService:_ownedWaycoinDropExists(record)
    local player = record and record.player
    if not player then
        return false
    end
    local drops = Workspace:FindFirstChild("CoinDrops")
    for _, drop in ipairs(drops and drops:GetChildren() or {}) do
        if
            drop:GetAttribute("DropOwner") == player.UserId
            and drop:GetAttribute("DropSource") == "merge_egg_prototype"
            and drop:GetAttribute("DropCurrency") == "hall_coins"
        then
            return true
        end
    end
    return false
end

-- Soft "pick up at least one" for later tutorial pauses. We do not spawn or
-- place piles. Wallet already >= 1 is enough. No pile (or only an ungettable
-- one we refuse to wait on) credits 1 Waycoin so Install cannot deadlock.
function MergeEggPrototypeService:_ensureStageCoinCredit(record)
    if not record then
        return
    end
    if self:_tutorialWallet(record) >= 1 then
        return
    end
    if self:_ownedWaycoinDropExists(record) then
        return
    end
    if self._economyService and self._economyService.AddCurrency then
        self._economyService:AddCurrency(
            record.player,
            "hall_coins",
            1,
            "merge_egg_stage_coin_fallback"
        )
    end
end

function MergeEggPrototypeService:_tutorialShouldCollectStageCoin(record)
    return self:_tutorialWallet(record) < 1 and self:_ownedWaycoinDropExists(record)
end

function MergeEggPrototypeService:_tutorialCollectedStageCoin(record)
    if self:_tutorialWallet(record) >= 1 then
        return true
    end
    if not self:_ownedWaycoinDropExists(record) then
        self:_ensureStageCoinCredit(record)
        return self:_tutorialWallet(record) >= 1
    end
    return false
end

function MergeEggPrototypeService:_tutorialRequiredEggs()
    return math.max(2, math.floor(tonumber(self:_tutorialConfig().required_eggs) or 5))
end

function MergeEggPrototypeService:_tutorialOpeningCoinTotal()
    local opening = type(self._config.opening_economy) == "table" and self._config.opening_economy
        or {}
    local offsets = type(opening.pickup_offsets) == "table" and opening.pickup_offsets or {}
    local amount = math.max(1, math.floor(tonumber(opening.pickup_amount) or 120))
    return amount * #offsets
end

function MergeEggPrototypeService:_unlockCostMap(cfg)
    local map = {}
    for family, row in pairs(type(cfg) == "table" and cfg.unlock_costs or {}) do
        if type(row) == "table" then
            map[tostring(family)] = {
                currency = tostring(row.currency or "gems"),
                amount = math.max(0, math.floor(tonumber(row.amount) or 1)),
            }
        end
    end
    return map
end

function MergeEggPrototypeService:_openingGemSpec()
    local opening = type(self._config.opening_economy) == "table" and self._config.opening_economy
        or {}
    local gem = type(opening.gem) == "table" and opening.gem or {}
    local amount = math.max(0, math.floor(tonumber(gem.amount) or 0))
    if amount <= 0 then
        return nil
    end
    return {
        currency = tostring(gem.currency or "gems"),
        amount = amount,
        engineerPost = math.max(0, math.floor(tonumber(gem.engineer_post) or 0)),
        towardGate = tonumber(gem.toward_gate) or 12,
        inward = tonumber(gem.inward) or 8,
        offset = type(gem.offset) == "table" and gem.offset or { x = 24, z = 28 },
        visualScale = math.max(
            0.1,
            requiredConfigNumber(gem.visual_scale, "opening_economy.gem.visual_scale")
        ),
    }
end

function MergeEggPrototypeService:_openingGemWorldPosition(world, spec)
    spec = spec or self:_openingGemSpec()
    if not (world and spec) then
        return nil
    end
    local posts = self:_engineerPosts()
    local post = posts[spec.engineerPost]
    if not post then
        return nil
    end
    local stand, floorTop = self:_engineerStandCFrame(world, post.slot, post.along)
    if not stand then
        return nil
    end
    local side = tostring(world:GetAttribute("MergeEggBaySide") or "")
    local incoming = side == "hell" and Vector3.new(-1, 0, 0) or Vector3.new(1, 0, 0)
    local rightDir = Vector3.new(0, 1, 0):Cross(incoming)
    if rightDir.Magnitude <= 0 then
        rightDir = Vector3.new(0, 0, -1)
    else
        rightDir = rightDir.Unit
    end
    local hover = tonumber(spec.offset and spec.offset.y) or 3
    local floorY = floorTop or stand.Position.Y
    return Vector3.new(0, floorY + hover, 0)
        + Vector3.new(stand.Position.X, 0, stand.Position.Z)
        + incoming * (tonumber(spec.towardGate) or 12)
        - rightDir * (tonumber(spec.inward) or 8)
end

function MergeEggPrototypeService:_tutorialGemWallet(record)
    local spec = self:_openingGemSpec()
    if not (spec and record and self._economyService) then
        return 0
    end
    return math.max(
        0,
        math.floor(tonumber(self._economyService:GetCurrency(record.player, spec.currency)) or 0)
    )
end

function MergeEggPrototypeService:_openingGemDropExists(record)
    local player = record and record.player
    if not player then
        return false
    end
    local drops = Workspace:FindFirstChild("CoinDrops")
    for _, drop in ipairs(drops and drops:GetChildren() or {}) do
        if
            drop:GetAttribute("DropOwner") == player.UserId
            and drop:GetAttribute("DropSource") == "merge_egg_prototype"
            and drop:GetAttribute("DropReason") == "opening_gem"
        then
            return true
        end
    end
    return false
end

function MergeEggPrototypeService:_tutorialCollectedOpeningStash(record)
    if self:_tutorialWallet(record) < self:_tutorialOpeningCoinTotal() then
        return false
    end
    -- Stay on collect while the opening gem is still on the field, even if
    -- the wallet already has leftover gems from a prior run.
    if self:_openingGemDropExists(record) then
        return false
    end
    local spec = self:_openingGemSpec()
    if not spec then
        return true
    end
    if record.openingGemSpawned == true then
        return self:_tutorialGemWallet(record) >= spec.amount
    end
    return true
end

function MergeEggPrototypeService:_cannonGemSpec()
    local opening = type(self._config.opening_economy) == "table" and self._config.opening_economy
        or {}
    local gem = type(opening.cannon_gem) == "table" and opening.cannon_gem or {}
    local amount = math.max(0, math.floor(tonumber(gem.amount) or 0))
    if amount <= 0 then
        return nil
    end
    return {
        currency = tostring(gem.currency or "gems"),
        amount = amount,
        towardGate = tonumber(gem.toward_gate) or 12,
        inward = tonumber(gem.inward) or 8,
        offset = type(gem.offset) == "table" and gem.offset or { x = 24, z = 28 },
        visualScale = math.max(
            0.1,
            requiredConfigNumber(gem.visual_scale, "opening_economy.cannon_gem.visual_scale")
        ),
    }
end

function MergeEggPrototypeService:_cannonGemWorldPosition(world, spec)
    spec = spec or self:_cannonGemSpec()
    if not (world and spec) then
        return nil
    end
    local slot = self:_tutorialWorkshopCannonSlot()
    local pad = self:_padForSlot(world, slot)
    if not pad then
        return nil
    end
    local box, size = pad:GetBoundingBox()
    local landStrip = world:FindFirstChild("LandStrip")
    local floorTop = landStrip and landStrip.Position.Y + landStrip.Size.Y * 0.5
        or (box.Position.Y - size.Y * 0.5)
    local side = tostring(world:GetAttribute("MergeEggBaySide") or "")
    local incoming = side == "hell" and Vector3.new(-1, 0, 0) or Vector3.new(1, 0, 0)
    local look = self:_towerGateLook(world, box.Position)
    if look and look.Magnitude > 0.001 then
        look = Vector3.new(look.X, 0, look.Z)
        look = look.Magnitude > 0.001 and look.Unit or incoming
    else
        look = incoming
    end
    local rightDir = Vector3.new(0, 1, 0):Cross(incoming)
    if rightDir.Magnitude <= 0 then
        rightDir = Vector3.new(0, 0, -1)
    else
        rightDir = rightDir.Unit
    end
    -- Commander stands behind the pad on the courtyard. The gem must clear
    -- the pad and the stone wall onto LandStrip, then step toward the gate.
    local worldCfg = type(self._config.world) == "table" and self._config.world or {}
    local wall = findNamedPart(world, worldCfg.bulwark_line or "BulwarkLine")
    local padPos = Vector3.new(box.Position.X, 0, box.Position.Z)
    local pastWall = 0
    if wall then
        local wallPos = Vector3.new(wall.Position.X, 0, wall.Position.Z)
        pastWall = (wallPos - padPos):Dot(look)
    end
    local footprint = tonumber(pad:GetAttribute("MergeTowerPadFootprint"))
    local extent = footprint and footprint * 0.5 or math.max(size.X, size.Z) * 0.5
    local fieldAlong = math.max(pastWall, extent) + (tonumber(spec.towardGate) or 12)
    local hover = tonumber(spec.offset and spec.offset.y) or 3
    return Vector3.new(0, floorTop + hover, 0)
        + padPos
        + look * fieldAlong
        - rightDir * (tonumber(spec.inward) or 8)
end

function MergeEggPrototypeService:_cannonGemDropExists(record)
    local player = record and record.player
    if not player then
        return false
    end
    local drops = Workspace:FindFirstChild("CoinDrops")
    for _, drop in ipairs(drops and drops:GetChildren() or {}) do
        if
            drop:GetAttribute("DropOwner") == player.UserId
            and drop:GetAttribute("DropSource") == "merge_egg_prototype"
            and drop:GetAttribute("DropReason") == "cannon_gem"
        then
            return true
        end
    end
    return false
end

function MergeEggPrototypeService:_tutorialCollectedCannonGem(record)
    if self:_cannonGemDropExists(record) then
        return false
    end
    local spec = self:_cannonGemSpec()
    if not spec then
        return true
    end
    if self:_tutorialGemWallet(record) >= spec.amount then
        return true
    end
    if record.cannonGemSpawned == true then
        return self:_tutorialGemWallet(record) >= spec.amount
    end
    return false
end

function MergeEggPrototypeService:_tutorialHasCombination(record)
    return record ~= nil
        and (
            (record.eggsMerged or 0) > 0
            or ((record.maximumEggTier or 0) >= 2 and (record.eggsPlaced or 0) >= 2)
        )
end

function MergeEggPrototypeService:_tutorialPauseAfterWave()
    return math.max(1, math.floor(tonumber(self:_tutorialConfig().pause_after_wave) or 2))
end

function MergeEggPrototypeService:_tutorialPauseAfterCannonWave()
    return math.max(1, math.floor(tonumber(self:_tutorialConfig().pause_after_cannon_wave) or 4))
end

function MergeEggPrototypeService:_tutorialPauseAfterUpgradeWave()
    return math.max(1, math.floor(tonumber(self:_tutorialConfig().pause_after_upgrade_wave) or 6))
end

function MergeEggPrototypeService:_tutorialUpgradeCoinTarget()
    return math.max(1, math.floor(tonumber(self:_tutorialConfig().upgrade_coin_target) or 600))
end

function MergeEggPrototypeService:_tutorialUpgradeCreateCount()
    return math.max(1, math.floor(tonumber(self:_tutorialConfig().upgrade_create_count) or 2))
end

function MergeEggPrototypeService:_tutorialWorkshopSlot()
    return MergeBulwarkProgression.normalizeSlot(self:_tutorialConfig().workshop_slot or "lane")
end

function MergeEggPrototypeService:_tutorialWorkshopCannonSlot()
    return MergeTowerProgression.normalizeSlot(
        self:_tutorialConfig().workshop_cannon_slot or "right"
    )
end

function MergeEggPrototypeService:_tutorialWorkshopCompleted(record)
    local progress = record and self:_mergeDefenseProgress(record.player)
    return (progress and progress.tutorial_workshop_completed == true)
        or (progress and progress.tutorial_cannon_completed == true)
        or record.tutorialStep == "cannon_waves"
        or record.tutorialStep == "upgrade_waves"
        or self:_tutorialHasWorkshopBulwark(record)
end

function MergeEggPrototypeService:_tutorialCannonCompleted(record)
    local progress = record and self:_mergeDefenseProgress(record.player)
    return (progress and progress.tutorial_cannon_completed == true)
        or (progress and progress.tutorial_upgrade_completed == true)
        or (progress and progress.tutorial_completed == true)
        or record.tutorialStep == "upgrade_waves"
        or record.tutorialStep == "quartermaster_waves"
        or self:_tutorialHasWorkshopCannon(record)
end

function MergeEggPrototypeService:_tutorialUpgradeCompleted(record)
    local progress = record and self:_mergeDefenseProgress(record.player)
    return (progress and progress.tutorial_upgrade_completed == true)
        or (progress and progress.tutorial_completed == true)
        or record.tutorialStep == "quartermaster_waves"
end

function MergeEggPrototypeService:_upgradeTutorialBaseline(record)
    if record and type(record.upgradeTutorialBaseline) == "table" then
        return record.upgradeTutorialBaseline
    end
    local progress = record and self:_mergeDefenseProgress(record.player)
    local raw = progress and progress.upgrade_tutorial_baseline
    if type(raw) ~= "table" then
        return nil
    end
    if raw.eggs_merged == nil and raw.eggs_placed == nil and raw.base_egg_tier == nil then
        return nil
    end
    return {
        eggsMerged = math.max(0, math.floor(tonumber(raw.eggs_merged) or 0)),
        eggsPlaced = math.max(0, math.floor(tonumber(raw.eggs_placed) or 0)),
        baseEggTier = math.max(1, math.floor(tonumber(raw.base_egg_tier) or 1)),
    }
end

function MergeEggPrototypeService:_captureUpgradeTutorialBaseline(record)
    if not record then
        return
    end
    local baseline = {
        eggsMerged = math.max(0, math.floor(tonumber(record.eggsMerged) or 0)),
        eggsPlaced = math.max(0, math.floor(tonumber(record.eggsPlaced) or 0)),
        baseEggTier = math.max(1, math.floor(tonumber(record.baseEggTier) or 1)),
    }
    record.upgradeTutorialBaseline = baseline
    local progress = self:_mergeDefenseProgress(record.player)
    if progress then
        progress.upgrade_tutorial_baseline = {
            eggs_merged = baseline.eggsMerged,
            eggs_placed = baseline.eggsPlaced,
            base_egg_tier = baseline.baseEggTier,
        }
    end
end

function MergeEggPrototypeService:_hasUpgradedSinceCannon(record)
    local baseline = self:_upgradeTutorialBaseline(record)
    if not (record and baseline) then
        return false
    end
    return (record.eggsMerged or 0) > baseline.eggsMerged
        or (record.eggsPlaced or 0) > baseline.eggsPlaced
        or (record.baseEggTier or 1) > baseline.baseEggTier
end

function MergeEggPrototypeService:_tutorialVendorsReady(record, kind, slot)
    local tutorial = self:_tutorialConfig()
    if tutorial.enabled ~= true then
        return true
    end
    local progress = record and self:_mergeDefenseProgress(record.player)
    local reborn = progress and MergeEggRebirth.normalizeCount(progress.rebirths) > 0
    local step = record and record.tutorialStep
    if kind == "quartermaster" then
        if progress and progress.tutorial_completed == true then
            return true
        end
        if tutorial.disable_after_rebirth == true and reborn then
            return true
        end
        return record and record.tutorialActive == true and step == "talk_quartermaster"
    end
    if
        progress
        and (progress.tutorial_completed == true or progress.tutorial_cannon_completed == true)
    then
        return true
    end
    if tutorial.disable_after_rebirth == true and reborn then
        return true
    end
    local workshopOpen = record
        and record.tutorialActive == true
        and (
            step == "collect_workshop_coins"
            or step == "talk_engineer"
            or step == "unlock_bulwark"
            or step == "install_bulwark"
        )
    local cannonOpen = record
        and record.tutorialActive == true
        and (
            step == "collect_cannon_coins"
            or step == "collect_cannon_gem"
            or step == "talk_commander"
            or step == "unlock_cannon"
            or step == "install_cannon"
        )
    if kind == "artillery" then
        if not cannonOpen then
            return false
        end
        if slot == nil then
            return true
        end
        return MergeTowerProgression.normalizeSlot(slot) == self:_tutorialWorkshopCannonSlot()
    end
    if workshopOpen then
        if slot == nil then
            return true
        end
        return MergeBulwarkProgression.normalizeSlot(slot) == self:_tutorialWorkshopSlot()
    end
    if self:_tutorialWorkshopCompleted(record) then
        if slot == nil then
            return true
        end
        return MergeBulwarkProgression.normalizeSlot(slot) == self:_tutorialWorkshopSlot()
    end
    return false
end

function MergeEggPrototypeService:_tutorialOwnsBulwarkFamily(record)
    local state = self:_normalizeBulwarkState(record)
    local owned = MergeBulwarkProgression.menuOwned(state, self:_tutorialWorkshopSlot())
    for _, tier in pairs(type(owned) == "table" and owned or {}) do
        if math.max(0, math.floor(tonumber(tier) or 0)) > 0 then
            return true
        end
    end
    return false
end

function MergeEggPrototypeService:_tutorialHasWorkshopBulwark(record)
    local family = MergeBulwarkProgression.slotFamily(
        self:_normalizeBulwarkState(record),
        self:_tutorialWorkshopSlot()
    )
    return family ~= nil
end

function MergeEggPrototypeService:_tutorialSetupCompleted(record)
    local progress = record and self:_mergeDefenseProgress(record.player)
    return (progress and progress.tutorial_setup_completed == true)
        or record.tutorialStep == "combat_waves"
        or (self:_tutorialHasCombination(record) and self:_initializedHatcherCount(record) >= 1)
end

function MergeEggPrototypeService:_shouldStartWorkshopTutorial(record)
    if not record then
        return false
    end
    local tutorial = self:_tutorialConfig()
    local progress = self:_mergeDefenseProgress(record.player)
    local reborn = progress and MergeEggRebirth.normalizeCount(progress.rebirths) > 0
    if tutorial.enabled == false then
        return false
    end
    if progress and progress.tutorial_completed == true then
        return false
    end
    if tutorial.disable_after_rebirth == true and reborn then
        return false
    end
    if record.tutorialActive == true then
        return false
    end
    if self:_tutorialWorkshopCompleted(record) then
        return false
    end
    if (record.waveIndex or 0) ~= self:_tutorialPauseAfterWave() then
        return false
    end
    if (record.aliveEnemies or 0) > 0 or (record.pendingEnemySpawns or 0) > 0 then
        return false
    end
    return self:_tutorialSetupCompleted(record)
end

function MergeEggPrototypeService:_setTutorialStep(record, step)
    if not record or record.tutorialActive ~= true or record.tutorialStep == step then
        return
    end
    record.tutorialStep = step
    record.tutorialStepChangedAt = os.clock()
    record.tutorialStepReadyAt = record.tutorialStepChangedAt
        + math.max(0, tonumber(self:_tutorialConfig().step_pause_seconds) or 1.25)
    local world = self:_worldFor(record)
    self:_setWorldState(
        world and world:GetAttribute("PrototypeState") or "AwaitingFirstEgg",
        record
    )
end

function MergeEggPrototypeService:_markTutorialSetupCompleted(record)
    local progress = record and self:_mergeDefenseProgress(record.player)
    if progress then
        progress.tutorial_setup_completed = true
    end
end

function MergeEggPrototypeService:_markTutorialWorkshopCompleted(record)
    local progress = record and self:_mergeDefenseProgress(record.player)
    if progress then
        progress.tutorial_setup_completed = true
        progress.tutorial_workshop_completed = true
    end
end

function MergeEggPrototypeService:_markTutorialCannonCompleted(record)
    local progress = record and self:_mergeDefenseProgress(record.player)
    if progress then
        progress.tutorial_setup_completed = true
        progress.tutorial_workshop_completed = true
        progress.tutorial_cannon_completed = true
    end
    self:_captureUpgradeTutorialBaseline(record)
end

function MergeEggPrototypeService:_markTutorialUpgradeCompleted(record)
    local progress = record and self:_mergeDefenseProgress(record.player)
    if progress then
        progress.tutorial_setup_completed = true
        progress.tutorial_workshop_completed = true
        progress.tutorial_cannon_completed = true
        progress.tutorial_upgrade_completed = true
    end
end

function MergeEggPrototypeService:_shouldStartCannonTutorial(record)
    if not record then
        return false
    end
    local tutorial = self:_tutorialConfig()
    local progress = self:_mergeDefenseProgress(record.player)
    local reborn = progress and MergeEggRebirth.normalizeCount(progress.rebirths) > 0
    if tutorial.enabled == false then
        return false
    end
    if progress and progress.tutorial_completed == true then
        return false
    end
    if progress and progress.tutorial_cannon_completed == true then
        return false
    end
    if tutorial.disable_after_rebirth == true and reborn then
        return false
    end
    if record.tutorialActive == true then
        return false
    end
    if not self:_tutorialWorkshopCompleted(record) then
        return false
    end
    if (record.waveIndex or 0) ~= self:_tutorialPauseAfterCannonWave() then
        return false
    end
    if (record.aliveEnemies or 0) > 0 or (record.pendingEnemySpawns or 0) > 0 then
        return false
    end
    return true
end

function MergeEggPrototypeService:_tutorialOwnsCannonFamily(record)
    local state = self:_normalizeTowerState(record)
    local owned = MergeTowerProgression.menuOwned(state, self:_tutorialWorkshopCannonSlot())
    for _, tier in pairs(type(owned) == "table" and owned or {}) do
        if math.max(0, math.floor(tonumber(tier) or 0)) > 0 then
            return true
        end
    end
    return false
end

function MergeEggPrototypeService:_tutorialHasWorkshopCannon(record)
    local family = MergeTowerProgression.slotFamily(
        self:_normalizeTowerState(record),
        self:_tutorialWorkshopCannonSlot()
    )
    return family ~= nil
end

function MergeEggPrototypeService:_scheduleTutorialWaveResume(record)
    if
        record.terminal ~= true
        and (record.aliveEnemies or 0) == 0
        and (record.pendingEnemySpawns or 0) == 0
    then
        record.nextWaveAt = os.clock()
            + math.max(0, tonumber(self:_tutorialConfig().resume_wave_delay_seconds) or 3)
        self:_setWorldState("WaveIntermission", record)
    else
        local world = self:_worldFor(record)
        self:_setWorldState(
            world and world:GetAttribute("PrototypeState") or "AwaitingFirstEgg",
            record
        )
    end
end

-- Phase 1 is done: unlock Waves 1–2. Do not mark the whole tutorial complete
-- or Wave 3 will never pause for the workshop beat.
function MergeEggPrototypeService:_releaseTutorialForCombat(record)
    if not record or record.tutorialActive ~= true then
        return
    end
    record.tutorialActive = false
    record.tutorialStep = "combat_waves"
    record.tutorialStepReadyAt = nil
    self:_markTutorialSetupCompleted(record)
    local playstateSaved = self:_persistPlaystate(record, "merge_defense_tutorial_setup", true)
    if not playstateSaved and self._dataService and self._dataService.RequestSave then
        self._dataService:RequestSave(record.player, "merge_defense_tutorial_setup", {
            debounceSeconds = 0,
            critical = true,
        })
    end
    self:_scheduleTutorialWaveResume(record)
    self:_log("Info", "Merge Egg setup tutorial released combat", {
        player = record.player.Name,
        wave = record.waveIndex,
    })
end

function MergeEggPrototypeService:_startWorkshopTutorial(record)
    if not record then
        return
    end
    record.nextWaveAt = nil
    record.tutorialTalkedEngineer = false
    record.tutorialActive = true
    record.tutorialUsesAutoCollector = self:_tutorialUsesAutoCollector(record)
    record.tutorialStep = nil
    record.tutorialStepChangedAt = nil
    record.tutorialStepReadyAt = nil
    if self:_tutorialHasWorkshopBulwark(record) then
        self:_releaseTutorialForWorkshopCombat(record)
        return
    end
    self:_ensureStageCoinCredit(record)
    if self:_tutorialShouldCollectStageCoin(record) then
        self:_setTutorialStep(record, "collect_workshop_coins")
    elseif self:_tutorialOwnsBulwarkFamily(record) then
        self:_setTutorialStep(record, "install_bulwark")
    else
        self:_setTutorialStep(record, "talk_engineer")
    end
    self:_setWorldState("TutorialIntermission", record)
    self:_ensureBayBulwarks(record)
    self:_log("Info", "Merge Egg workshop tutorial started", {
        player = record.player.Name,
        wave = record.waveIndex,
        step = record.tutorialStep,
    })
end

-- Wave 2 workshop is done: unlock Waves 3–4. Do not mark the whole tutorial
-- complete or Wave 5 will never pause for the cannon beat.
function MergeEggPrototypeService:_releaseTutorialForWorkshopCombat(record)
    if not record or record.tutorialActive ~= true then
        return
    end
    record.tutorialActive = false
    record.tutorialStep = "cannon_waves"
    record.tutorialStepReadyAt = nil
    self:_markTutorialWorkshopCompleted(record)
    local playstateSaved = self:_persistPlaystate(record, "merge_defense_tutorial_workshop", true)
    if not playstateSaved and self._dataService and self._dataService.RequestSave then
        self._dataService:RequestSave(record.player, "merge_defense_tutorial_workshop", {
            debounceSeconds = 0,
            critical = true,
        })
    end
    self:_scheduleTutorialWaveResume(record)
    self:_ensureBayBulwarks(record)
    self:_log("Info", "Merge Egg workshop tutorial released combat", {
        player = record.player.Name,
        wave = record.waveIndex,
    })
end

function MergeEggPrototypeService:_startCannonTutorial(record)
    if not record then
        return
    end
    record.nextWaveAt = nil
    record.tutorialTalkedCommander = false
    record.tutorialActive = true
    record.tutorialUsesAutoCollector = self:_tutorialUsesAutoCollector(record)
    record.tutorialStep = nil
    record.tutorialStepChangedAt = nil
    record.tutorialStepReadyAt = nil
    if self:_tutorialHasWorkshopCannon(record) then
        self:_releaseTutorialForCannonCombat(record)
        return
    end
    self:_ensureBayTowers(record)
    self:_ensureStageCoinCredit(record)
    self:_ensureCannonGemLesson(record)
    if self:_tutorialShouldCollectStageCoin(record) then
        self:_setTutorialStep(record, "collect_cannon_coins")
    elseif not self:_tutorialCollectedCannonGem(record) then
        self:_setTutorialStep(record, "collect_cannon_gem")
    elseif self:_tutorialOwnsCannonFamily(record) then
        self:_setTutorialStep(record, "install_cannon")
    else
        self:_setTutorialStep(record, "talk_commander")
    end
    self:_setWorldState("TutorialIntermission", record)
    self:_ensureBayTowers(record)
    self:_log("Info", "Merge Egg cannon tutorial started", {
        player = record.player.Name,
        wave = record.waveIndex,
        step = record.tutorialStep,
    })
end

-- Wave 4 Heal install is done: unlock Waves 5–6. Do not mark the whole
-- tutorial complete or Wave 6 will never offer the optional upgrade beat.
function MergeEggPrototypeService:_releaseTutorialForCannonCombat(record)
    if not record or record.tutorialActive ~= true then
        return
    end
    record.tutorialActive = false
    record.tutorialStep = "upgrade_waves"
    record.tutorialStepReadyAt = nil
    self:_markTutorialCannonCompleted(record)
    local playstateSaved = self:_persistPlaystate(record, "merge_defense_tutorial_cannon", true)
    if not playstateSaved and self._dataService and self._dataService.RequestSave then
        self._dataService:RequestSave(record.player, "merge_defense_tutorial_cannon", {
            debounceSeconds = 0,
            critical = true,
        })
    end
    self:_scheduleTutorialWaveResume(record)
    self:_ensureBayBulwarks(record)
    self:_ensureBayTowers(record)
    self:_log("Info", "Merge Egg cannon tutorial released combat", {
        player = record.player.Name,
        wave = record.waveIndex,
    })
end

function MergeEggPrototypeService:_ownedWaycoinDropTotal(record)
    local player = record and record.player
    if not player then
        return 0
    end
    local total = 0
    local drops = Workspace:FindFirstChild("CoinDrops")
    for _, drop in ipairs(drops and drops:GetChildren() or {}) do
        if
            drop:GetAttribute("DropOwner") == player.UserId
            and drop:GetAttribute("DropSource") == "merge_egg_prototype"
            and drop:GetAttribute("DropCurrency") == "hall_coins"
        then
            total += math.max(0, math.floor(tonumber(drop:GetAttribute("DropAmount")) or 0))
        end
    end
    return total
end

function MergeEggPrototypeService:_spawnFieldWaycoinPiles(record, amountNeeded, reason)
    local need = math.max(0, math.floor(tonumber(amountNeeded) or 0))
    if not record or need <= 0 then
        return 0
    end
    local opening = type(self._config.opening_economy) == "table" and self._config.opening_economy
        or {}
    local offsets = type(opening.pickup_offsets) == "table" and opening.pickup_offsets or {}
    local pileAmount = math.max(1, math.floor(tonumber(opening.pickup_amount) or 120))
    local currency = tostring(opening.currency or "hall_coins")
    local worldCfg = self._config.world or {}
    local world = self:_worldFor(record)
    local anchor = findNamedPart(world, worldCfg.bulwark_line)
        or findNamedPart(world, worldCfg.player_spawn)
    if not (anchor and #offsets > 0 and self._dropService and self._dropService.SpawnCoinDrop) then
        return 0
    end
    local spawnedAmount = 0
    for _, offset in ipairs(offsets) do
        if spawnedAmount >= need then
            break
        end
        local dropAmount = math.min(pileAmount, need - spawnedAmount)
        local position = anchor.CFrame:PointToWorldSpace(
            Vector3.new(tonumber(offset.x) or 0, tonumber(offset.y) or 3, tonumber(offset.z) or 0)
        )
        local options = self:_prototypeCoinDropOptions(record)
        options.reason = reason or "upgrade_coins"
        local ok, result = pcall(function()
            return self._dropService:SpawnCoinDrop(
                record.player,
                currency,
                dropAmount,
                position,
                options
            )
        end)
        if ok and result == true then
            spawnedAmount += dropAmount
        end
    end
    return spawnedAmount
end

function MergeEggPrototypeService:_ensureUpgradeCoinLesson(record)
    if not record then
        return false
    end
    local target = self:_tutorialUpgradeCoinTarget()
    local wallet = self:_tutorialWallet(record)
    if wallet >= target then
        return true
    end
    local field = self:_ownedWaycoinDropTotal(record)
    if wallet + field >= target then
        return true
    end
    local spawned = self:_spawnFieldWaycoinPiles(record, target - wallet - field, "upgrade_coins")
    if wallet + field + spawned >= target then
        return true
    end
    local shortfall = target - wallet - field - spawned
    if shortfall > 0 and self._economyService and self._economyService.AddCurrency then
        self._economyService:AddCurrency(
            record.player,
            "hall_coins",
            shortfall,
            "merge_egg_upgrade_coin_fallback"
        )
    end
    return self:_tutorialWallet(record) >= target
end

function MergeEggPrototypeService:_tutorialCollectedUpgradeCoins(record)
    return self:_tutorialWallet(record) >= self:_tutorialUpgradeCoinTarget()
end

function MergeEggPrototypeService:_tutorialUpgradeEggsDone(record)
    if not record then
        return false
    end
    local createdNeed = self:_tutorialUpgradeCreateCount()
    local created = (record.eggsCreated or 0) - (record.upgradeBeatEggsCreated or 0)
    local merged = (record.eggsMerged or 0) - (record.upgradeBeatEggsMerged or 0)
    local placed = (record.eggsPlaced or 0) - (record.upgradeBeatEggsPlaced or 0)
    local upgradedBase = (record.baseEggTier or 1) > (record.upgradeBeatBaseEggTier or 1)
    return created >= createdNeed and (merged > 0 or upgradedBase or placed > 0)
end

function MergeEggPrototypeService:_shouldStartUpgradeTutorial(record)
    if not record then
        return false
    end
    local tutorial = self:_tutorialConfig()
    local progress = self:_mergeDefenseProgress(record.player)
    local reborn = progress and MergeEggRebirth.normalizeCount(progress.rebirths) > 0
    if tutorial.enabled == false then
        return false
    end
    if progress and progress.tutorial_completed == true then
        return false
    end
    if progress and progress.tutorial_upgrade_completed == true then
        return false
    end
    if tutorial.disable_after_rebirth == true and reborn then
        return false
    end
    if record.tutorialActive == true then
        return false
    end
    if not self:_tutorialCannonCompleted(record) then
        return false
    end
    if (record.waveIndex or 0) ~= self:_tutorialPauseAfterUpgradeWave() then
        return false
    end
    if (record.aliveEnemies or 0) > 0 or (record.pendingEnemySpawns or 0) > 0 then
        return false
    end
    -- Optional: they already upgraded or installed since the Heal install.
    if self:_hasUpgradedSinceCannon(record) then
        return false
    end
    return true
end

function MergeEggPrototypeService:_startUpgradeTutorial(record)
    if not record then
        return
    end
    if self:_hasUpgradedSinceCannon(record) then
        return
    end
    record.nextWaveAt = nil
    record.tutorialActive = true
    record.tutorialUsesAutoCollector = self:_tutorialUsesAutoCollector(record)
    record.tutorialStep = nil
    record.tutorialStepChangedAt = nil
    record.tutorialStepReadyAt = nil
    record.upgradeBeatEggsCreated = record.eggsCreated or 0
    record.upgradeBeatEggsMerged = record.eggsMerged or 0
    record.upgradeBeatEggsPlaced = record.eggsPlaced or 0
    record.upgradeBeatBaseEggTier = record.baseEggTier or 1
    self:_ensureUpgradeCoinLesson(record)
    if self:_tutorialCollectedUpgradeCoins(record) then
        self:_setTutorialStep(record, "upgrade_eggs")
    else
        self:_setTutorialStep(record, "collect_upgrade_coins")
    end
    self:_setWorldState("TutorialIntermission", record)
    self:_log("Info", "Merge Egg upgrade tutorial started", {
        player = record.player.Name,
        wave = record.waveIndex,
        step = record.tutorialStep,
    })
end

-- Wave 6 upgrade beat is done (or skipped). Unlock Waves 7–10. Do not
-- mark the whole tutorial complete or Wave 10 will never post Macros.
function MergeEggPrototypeService:_releaseTutorialForUpgradeCombat(record)
    if not record or record.tutorialActive ~= true then
        return
    end
    record.tutorialActive = false
    record.tutorialStep = "quartermaster_waves"
    record.tutorialStepReadyAt = nil
    self:_markTutorialUpgradeCompleted(record)
    local playstateSaved = self:_persistPlaystate(record, "merge_defense_tutorial_upgrade", true)
    if not playstateSaved and self._dataService and self._dataService.RequestSave then
        self._dataService:RequestSave(record.player, "merge_defense_tutorial_upgrade", {
            debounceSeconds = 0,
            critical = true,
        })
    end
    self:_scheduleTutorialWaveResume(record)
    self:_ensureBayBulwarks(record)
    self:_ensureBayTowers(record)
    self:_ensureBayQuartermaster(record)
    self:_log("Info", "Merge Egg upgrade tutorial released combat", {
        player = record.player.Name,
        wave = record.waveIndex,
    })
end

function MergeEggPrototypeService:_tutorialPauseAfterQuartermasterWave()
    return math.max(
        1,
        math.floor(tonumber(self:_tutorialConfig().pause_after_quartermaster_wave) or 10)
    )
end

function MergeEggPrototypeService:_shouldStartQuartermasterTutorial(record)
    if not record then
        return false
    end
    local tutorial = self:_tutorialConfig()
    local progress = self:_mergeDefenseProgress(record.player)
    local reborn = progress and MergeEggRebirth.normalizeCount(progress.rebirths) > 0
    if tutorial.enabled == false then
        return false
    end
    if progress and progress.tutorial_completed == true then
        return false
    end
    if tutorial.disable_after_rebirth == true and reborn then
        return false
    end
    if record.tutorialActive == true then
        return false
    end
    if not self:_tutorialCannonCompleted(record) then
        return false
    end
    if (record.waveIndex or 0) ~= self:_tutorialPauseAfterQuartermasterWave() then
        return false
    end
    if (record.aliveEnemies or 0) > 0 or (record.pendingEnemySpawns or 0) > 0 then
        return false
    end
    return true
end

function MergeEggPrototypeService:_startQuartermasterTutorial(record)
    if not record then
        return
    end
    record.nextWaveAt = nil
    record.tutorialTalkedQuartermaster = false
    record.tutorialActive = true
    record.tutorialUsesAutoCollector = self:_tutorialUsesAutoCollector(record)
    record.tutorialStep = nil
    record.tutorialStepChangedAt = nil
    record.tutorialStepReadyAt = nil
    self:_setTutorialStep(record, "talk_quartermaster")
    self:_setWorldState("TutorialIntermission", record)
    self:_ensureBayQuartermaster(record)
    self:_log("Info", "Merge Egg quartermaster tutorial started", {
        player = record.player.Name,
        wave = record.waveIndex,
        step = record.tutorialStep,
    })
end

function MergeEggPrototypeService:_completeTutorial(record)
    if not record or record.tutorialActive ~= true then
        return
    end
    record.tutorialActive = false
    record.tutorialStep = "complete"
    record.tutorialStepReadyAt = nil
    local progress = self:_mergeDefenseProgress(record.player)
    if progress then
        progress.tutorial_setup_completed = true
        progress.tutorial_workshop_completed = true
        progress.tutorial_cannon_completed = true
        progress.tutorial_upgrade_completed = true
        progress.tutorial_completed = true
    end
    local playstateSaved = self:_persistPlaystate(record, "merge_defense_tutorial_complete", true)
    if not playstateSaved and self._dataService and self._dataService.RequestSave then
        self._dataService:RequestSave(record.player, "merge_defense_tutorial_complete", {
            debounceSeconds = 0,
            critical = true,
        })
    end
    self:_scheduleTutorialWaveResume(record)
    self:_ensureBayBulwarks(record)
    self:_ensureBayTowers(record)
    self:_ensureBayQuartermaster(record)
    self:_log("Info", "Merge Egg first-visit tutorial completed", {
        player = record.player.Name,
        wave = record.waveIndex,
    })
end

function MergeEggPrototypeService:_startTutorial(record, force)
    if not record then
        return
    end
    local progress = self:_mergeDefenseProgress(record.player)
    local tutorial = self:_tutorialConfig()
    local reborn = progress and MergeEggRebirth.normalizeCount(progress.rebirths) > 0
    if tutorial.enabled == false then
        record.tutorialActive = false
        record.tutorialStep = nil
        return
    end
    if
        force ~= true
        and (
            (progress and progress.tutorial_completed == true)
            or (tutorial.disable_after_rebirth == true and reborn)
        )
    then
        record.tutorialActive = false
        record.tutorialStep = nil
        return
    end
    if force ~= true and (progress and progress.tutorial_setup_completed == true) then
        record.tutorialActive = false
        record.tutorialStep = "combat_waves"
        if self:_shouldStartWorkshopTutorial(record) then
            self:_startWorkshopTutorial(record)
        elseif self:_shouldStartCannonTutorial(record) then
            self:_startCannonTutorial(record)
        elseif self:_shouldStartUpgradeTutorial(record) then
            self:_startUpgradeTutorial(record)
        elseif self:_shouldStartQuartermasterTutorial(record) then
            self:_startQuartermasterTutorial(record)
        end
        return
    end
    record.tutorialActive = true
    record.tutorialUsesAutoCollector = self:_tutorialUsesAutoCollector(record)
    record.tutorialStep = nil
    record.tutorialStepChangedAt = nil
    record.tutorialStepReadyAt = nil
    self:_setTutorialStep(record, "collect_setup")
    self:_ensureOpeningCoinLesson(record)
end

function MergeEggPrototypeService:_updateTutorial(record, now, force)
    if not (record and record.tutorialActive == true) then
        return
    end
    local usesAutoCollector = self:_tutorialUsesAutoCollector(record)
    if record.tutorialUsesAutoCollector ~= usesAutoCollector then
        record.tutorialUsesAutoCollector = usesAutoCollector
        local world = self:_worldFor(record)
        self:_setWorldState(
            world and world:GetAttribute("PrototypeState") or "AwaitingFirstEgg",
            record
        )
    end
    now = tonumber(now) or os.clock()
    if force ~= true and now < (record.tutorialStepReadyAt or 0) then
        return
    end
    local step = record.tutorialStep
    local requiredEggs = self:_tutorialRequiredEggs()
    local hasCombination = self:_tutorialHasCombination(record)
    local hasDeployment = self:_initializedHatcherCount(record) >= 1
    if step == "collect_setup" and self:_tutorialCollectedOpeningStash(record) then
        self:_setTutorialStep(record, "create_five")
    elseif step == "create_five" and (record.eggsCreated or 0) >= requiredEggs then
        if hasCombination and hasDeployment then
            self:_releaseTutorialForCombat(record)
        elseif hasCombination then
            self:_setTutorialStep(record, "deploy_one")
        else
            self:_setTutorialStep(record, "combine_once")
        end
    elseif step == "combine_once" and hasCombination then
        if hasDeployment then
            self:_releaseTutorialForCombat(record)
        else
            self:_setTutorialStep(record, "deploy_one")
        end
    elseif step == "deploy_one" and hasCombination and hasDeployment then
        self:_releaseTutorialForCombat(record)
    elseif step == "collect_workshop_coins" and self:_tutorialCollectedStageCoin(record) then
        if self:_tutorialHasWorkshopBulwark(record) then
            self:_releaseTutorialForWorkshopCombat(record)
        elseif self:_tutorialOwnsBulwarkFamily(record) then
            self:_setTutorialStep(record, "install_bulwark")
        else
            self:_setTutorialStep(record, "talk_engineer")
        end
    elseif step == "talk_engineer" and record.tutorialTalkedEngineer == true then
        if self:_tutorialHasWorkshopBulwark(record) then
            self:_releaseTutorialForWorkshopCombat(record)
        elseif self:_tutorialOwnsBulwarkFamily(record) then
            self:_setTutorialStep(record, "install_bulwark")
        else
            self:_setTutorialStep(record, "unlock_bulwark")
        end
    elseif step == "unlock_bulwark" and self:_tutorialOwnsBulwarkFamily(record) then
        if self:_tutorialHasWorkshopBulwark(record) then
            self:_releaseTutorialForWorkshopCombat(record)
        else
            self:_setTutorialStep(record, "install_bulwark")
        end
    elseif step == "install_bulwark" and self:_tutorialHasWorkshopBulwark(record) then
        self:_releaseTutorialForWorkshopCombat(record)
    elseif step == "collect_cannon_coins" and self:_tutorialCollectedStageCoin(record) then
        if self:_tutorialHasWorkshopCannon(record) then
            self:_releaseTutorialForCannonCombat(record)
        elseif not self:_tutorialCollectedCannonGem(record) then
            self:_setTutorialStep(record, "collect_cannon_gem")
        elseif self:_tutorialOwnsCannonFamily(record) then
            self:_setTutorialStep(record, "install_cannon")
        else
            self:_setTutorialStep(record, "talk_commander")
        end
    elseif step == "collect_cannon_gem" and self:_tutorialCollectedCannonGem(record) then
        if self:_tutorialHasWorkshopCannon(record) then
            self:_releaseTutorialForCannonCombat(record)
        elseif self:_tutorialOwnsCannonFamily(record) then
            self:_setTutorialStep(record, "install_cannon")
        else
            self:_setTutorialStep(record, "talk_commander")
        end
    elseif step == "talk_commander" and record.tutorialTalkedCommander == true then
        if self:_tutorialHasWorkshopCannon(record) then
            self:_releaseTutorialForCannonCombat(record)
        elseif self:_tutorialOwnsCannonFamily(record) then
            self:_setTutorialStep(record, "install_cannon")
        else
            self:_setTutorialStep(record, "unlock_cannon")
        end
    elseif step == "unlock_cannon" and self:_tutorialOwnsCannonFamily(record) then
        if self:_tutorialHasWorkshopCannon(record) then
            self:_releaseTutorialForCannonCombat(record)
        else
            self:_setTutorialStep(record, "install_cannon")
        end
    elseif step == "install_cannon" and self:_tutorialHasWorkshopCannon(record) then
        self:_releaseTutorialForCannonCombat(record)
    elseif step == "collect_upgrade_coins" and self:_tutorialCollectedUpgradeCoins(record) then
        if self:_tutorialUpgradeEggsDone(record) then
            self:_releaseTutorialForUpgradeCombat(record)
        else
            self:_setTutorialStep(record, "upgrade_eggs")
        end
    elseif step == "upgrade_eggs" and self:_tutorialUpgradeEggsDone(record) then
        self:_releaseTutorialForUpgradeCombat(record)
    elseif step == "talk_quartermaster" and record.tutorialTalkedQuartermaster == true then
        self:_completeTutorial(record)
    end
end

function MergeEggPrototypeService:_rebirthCountForPlayer(player)
    local progress = self:_mergeDefenseProgress(player)
    return MergeEggRebirth.normalizeCount(progress and progress.rebirths)
end

function MergeEggPrototypeService:_lowestDeployedEggTier(record)
    local lowest
    for _, team in ipairs(record and record.teams or {}) do
        local tier = math.max(0, math.floor(tonumber(team.eggTier) or 0))
        lowest = lowest and math.min(lowest, tier) or tier
    end
    return lowest or 0
end

function MergeEggPrototypeService:_rebirthStatus(record)
    local config = type(self._config.rebirth) == "table" and self._config.rebirth or {}
    local count = MergeEggRebirth.normalizeCount(record and record.rebirthCount)
    local price = MergeEggRebirth.nextCost(config, count)
    local requirementMet, minimumTier =
        MergeEggRebirth.requirementMet(config, count, self:_lowestDeployedEggTier(record))
    local scaling = {}
    for _, definition in ipairs({
        { key = "cannonPower", system = "cannons", axis = "power" },
        { key = "cannonRadius", system = "cannons", axis = "radius" },
        { key = "bulwarkPower", system = "bulwarks", axis = "power" },
        { key = "bulwarkRadius", system = "bulwarks", axis = "radius" },
        { key = "coinAmount", system = "coins", axis = "amount" },
        { key = "gemAmount", system = "gems", axis = "amount" },
        { key = "gemChance", system = "gems", axis = "chance" },
    }) do
        scaling[definition.key] =
            MergeEggRebirth.scalingMultiplier(config, count, definition.system, definition.axis)
    end
    return {
        count = count,
        rank = MergeEggRebirth.rankForCount(count),
        price = price,
        maxed = price == nil,
        damageMultiplier = MergeEggRebirth.damageMultiplier(config, count),
        scaling = scaling,
        requirementMet = requirementMet,
        minimumDeployedTier = minimumTier,
    }
end

function MergeEggPrototypeService:_managementUpgradeLevel(record, upgradeId)
    local levels = record and record.managementUpgradeLevels
    return math.max(
        0,
        math.floor(tonumber(type(levels) == "table" and levels[tostring(upgradeId or "")]) or 0)
    )
end

function MergeEggPrototypeService:_managementUpgradeCost(record, upgradeId)
    local definition = self:_managementUpgradeDefinition(upgradeId)
    if not definition then
        return nil
    end
    local level = self:_managementUpgradeLevel(record, upgradeId)
    local maximum = math.max(0, math.floor(tonumber(definition.max_level) or 0))
    if maximum > 0 and level >= maximum then
        return nil
    end
    local upgrades = type(self._config.management_upgrades) == "table"
            and self._config.management_upgrades
        or {}
    local amount = math.max(
        0,
        math.floor(
            (tonumber(definition.base_cost) or 0)
                    * math.max(1, tonumber(definition.cost_growth) or 1) ^ level
                + 0.5
        )
    )
    return {
        currency = tostring(definition.currency or upgrades.currency or "gems"),
        amount = amount,
        level = level,
        nextLevel = level + 1,
        definition = definition,
    }
end

function MergeEggPrototypeService:_managementUpgradeMultiplier(record, upgradeId)
    local definition = self:_managementUpgradeDefinition(upgradeId) or {}
    local level = self:_managementUpgradeLevel(record, upgradeId)
    return math.max(0, 1 + level * math.max(0, tonumber(definition.step) or 0))
end

function MergeEggPrototypeService:_activeSlotCount(record)
    local layout = type(self._config.station_layout) == "table" and self._config.station_layout
        or {}
    local total = math.max(1, math.floor(tonumber(layout.total_positions) or 9))
    local initial = type(layout.initial_position_slots) == "table" and layout.initial_position_slots
        or { 1, 2, 3, 4 }
    return math.clamp(#initial + self:_managementUpgradeLevel(record, "active_slots"), 1, total)
end

function MergeEggPrototypeService:_activePositionSlots(record)
    local layout = type(self._config.station_layout) == "table" and self._config.station_layout
        or {}
    local total = math.max(1, math.floor(tonumber(layout.total_positions) or 9))
    local ordered = {}
    local seen = {}
    local function append(source)
        for _, rawSlot in ipairs(type(source) == "table" and source or {}) do
            local slot = math.clamp(math.floor(tonumber(rawSlot) or 1), 1, total)
            if not seen[slot] then
                seen[slot] = true
                ordered[#ordered + 1] = slot
            end
        end
    end
    append(layout.initial_position_slots)
    append(layout.unlock_position_slots)
    for slot = 1, total do
        if not seen[slot] then
            ordered[#ordered + 1] = slot
        end
    end
    local result = {}
    for index = 1, math.min(self:_activeSlotCount(record), #ordered) do
        result[index] = ordered[index]
    end
    return result
end

function MergeEggPrototypeService:_activeTeamConfigs(record)
    local configured = self._config.teams or {}
    local result = {}
    for index, positionSlot in ipairs(self:_activePositionSlots(record)) do
        local template = configured[index] or {}
        local team = table.clone(template)
        team.id = index
        team.position_slot = positionSlot
        team.principal_name = "Merge Hatcher Team " .. index
        team.principal_display_name = "Hatcher Captain " .. index
        team.display_name = "NPC Team " .. index
        result[index] = team
    end
    return result
end

function MergeEggPrototypeService:_hatcherEggMaxHealth(record)
    local base =
        math.max(1, tonumber((self._config.objective or {}).hatcher_egg_max_health) or 5000)
    return math.max(
        1,
        math.floor(base * self:_managementUpgradeMultiplier(record, "egg_health") + 0.5)
    )
end

function MergeEggPrototypeService:_applyEggHealthUpgrade(record)
    local maximum = self:_hatcherEggMaxHealth(record)
    for _, team in ipairs(record and record.teams or {}) do
        local previousMaximum = math.max(1, tonumber(team.eggMaxHealth) or maximum)
        local previousHealth =
            math.clamp(tonumber(team.eggHealth) or previousMaximum, 0, previousMaximum)
        local healthFraction = previousHealth / previousMaximum
        team.eggMaxHealth = maximum
        if math.floor(tonumber(team.eggTier) or 0) > 0 then
            self:_removeHatcherEggObjective(team)
            if self:_spawnHatcherEggObjective(record, team) then
                local damage = math.clamp(maximum * (1 - healthFraction), 0, maximum)
                team.eggDamageTaken = damage
                team.eggHealth = maximum - damage
                if team.eggObjective then
                    team.eggObjective:SetAttribute("CombatDamageTaken", damage)
                end
                self:_publishTeamEggSource(team)
            end
        end
    end
end

function MergeEggPrototypeService:_portalVisual(record)
    local name = (self._config.world or {}).enemy_portal_visual or "EnemyPortalVisual"
    local world = self:_worldFor(record)
    return world and world:FindFirstChild(tostring(name), true) or nil
end

function MergeEggPrototypeService:_setPortalVisible(record, visible)
    visible = visible == true
    if record then
        record.portalVisible = visible
    end
    local portal = self:_portalVisual(record)
    for _, descendant in ipairs(portal and portal:GetDescendants() or {}) do
        if descendant:IsA("BasePart") then
            descendant.Transparency = visible
                    and math.clamp(
                        tonumber(descendant:GetAttribute("PortalVisibleTransparency")) or 0,
                        0,
                        1
                    )
                or 1
            descendant.CanCollide = false
            descendant.CanTouch = false
            descendant.CanQuery = visible
        elseif descendant:IsA("ParticleEmitter") or descendant:IsA("PointLight") then
            descendant.Enabled = visible
        end
    end
    local world = self:_worldFor(record)
    if world then
        world:SetAttribute("EnemyPortalVisible", visible)
    end
    self:_syncSpawnGateLighting(record, visible)
end

function MergeEggPrototypeService:_syncSpawnGateLighting(record, combat)
    local mode = combat == true and "Combat" or "Idle"
    local world = (record and record.world) or self._world
    local function apply(root)
        if not root then
            return
        end
        root:SetAttribute("LightMode", mode)
        local combatFolder = root:FindFirstChild("CombatLighting", true)
        if combatFolder then
            for _, descendant in ipairs(combatFolder:GetDescendants()) do
                if descendant:IsA("Light") then
                    descendant.Enabled = combat == true
                end
            end
        end
    end
    if world then
        apply(world:FindFirstChild("OuterSpawnGate", true))
        local bayId = world:GetAttribute("MergeEggBayId")
        if type(bayId) == "string" then
            local map = Workspace:FindFirstChild("GeneratedMap_MergeEggVoxel")
            local gates = map
                and (
                    string.find(bayId, "hell", 1, true) and map:FindFirstChild("HellGates")
                    or map:FindFirstChild("HeavenGates")
                )
            if gates then
                for _, gate in ipairs(gates:GetChildren()) do
                    if gate:GetAttribute("MergeEggBayId") == bayId then
                        apply(gate)
                    end
                end
            end
        end
    end
end

function MergeEggPrototypeService:_activeWaveState(record)
    if not record or (record.waveIndex or 0) <= 0 then
        return "AwaitingFirstEgg"
    end
    return record and (record.pendingEnemySpawns or 0) > 0 and "WaveDeploying" or "WaveActive"
end

function MergeEggPrototypeService:_upgradeExperimentMultiplier(record, channel)
    if not record or record.upgradeExperimentChannel ~= channel then
        return 1
    end
    return math.max(1, tonumber(record.upgradeExperimentMultiplier) or 1)
end

function MergeEggPrototypeService:_advanceUpgradeExperiment(record)
    if not (record and UPGRADE_EXPERIMENT_CHANNELS[record.upgradeExperimentChannel]) then
        return
    end
    local attempt = math.max(1, math.floor(tonumber(record.upgradeExperimentNextAttempt) or 1))
    local step = math.max(0.01, tonumber(record.upgradeExperimentStep) or 0.05)
    record.upgradeExperimentAttempt = attempt
    record.upgradeExperimentNextAttempt = attempt + 1
    record.upgradeExperimentMultiplier = 1 + attempt * step
end

function MergeEggPrototypeService:_stampUpgradeExperiment(record)
    if not record then
        return
    end
    local cadence = combatCadenceMultiplier(self._config)
        * self:_upgradeExperimentMultiplier(record, "speed")
        * self:_managementUpgradeMultiplier(record, "fire_rate")
    local rebirthDamage =
        MergeEggRebirth.damageMultiplier(self._config.rebirth, record.rebirthCount)
    local persistentDamage = MergeEggDamageScope.additiveUpgradeMultiplier(
        self:_managementUpgradeMultiplier(record, "damage"),
        rebirthDamage
    )
    local power = self:_upgradeExperimentMultiplier(record, "power") * persistentDamage
    for _, team in ipairs(record.teams or {}) do
        local teamPower = math.max(0, tonumber(team.originPowerMultiplier) or 1) * power
        for _, model in ipairs(team.units or {}) do
            if model and model.Parent then
                model:SetAttribute("CombatCadenceMultiplier", cadence)
                model:SetAttribute("OriginProgressionMultiplier", teamPower)
            end
        end
    end
    for _, model in ipairs(record.playerUnits or {}) do
        if model and model.Parent then
            model:SetAttribute("CombatCadenceMultiplier", cadence)
            model:SetAttribute("OriginProgressionMultiplier", power)
        end
    end
end

function MergeEggPrototypeService:_progressionStage(context)
    local loop = self._config.progression_loop or {}
    local stages = loop.stages or {}
    local stageId = type(context) == "string" and context
        or type(context) == "table" and context.progressionStageId
        or loop.default_stage
        or "home"
    stageId = tostring(stageId)
    local stage = stages[stageId]
    if type(stage) ~= "table" then
        stageId = tostring(loop.default_stage or "home")
        stage = stages[stageId] or {}
    end
    return stageId, stage
end

function MergeEggPrototypeService:_progressionStageIndex(context)
    local stageId = self:_progressionStage(context)
    local order = (self._config.progression_loop or {}).order or {}
    for index, candidate in ipairs(order) do
        if tostring(candidate) == stageId then
            return index, #order
        end
    end
    return 1, math.max(1, #order)
end

function MergeEggPrototypeService:_wavesFor(context)
    local _, stage = self:_progressionStage(context)
    if type(stage.waves) == "table" and #stage.waves > 0 then
        return stage.waves
    end
    return self._config.waves or {}
end

function MergeEggPrototypeService:_endlessWavesConfig(context)
    local _, stage = self:_progressionStage(context)
    if type(stage.endless_waves) == "table" then
        return stage.endless_waves
    end
    return self._config.endless_waves or {}
end

function MergeEggPrototypeService:_waveCount(context)
    return MergeEggWaveGenerator.waveCount(
        self:_wavesFor(context),
        self:_endlessWavesConfig(context)
    )
end

function MergeEggPrototypeService:_waveFor(context, waveIndex)
    return MergeEggWaveGenerator.wave(
        self:_wavesFor(context),
        self:_endlessWavesConfig(context),
        waveIndex
    )
end

function MergeEggPrototypeService:_wavesAreEndless(context)
    local config = self:_endlessWavesConfig(context)
    return config.enabled == true and #(config.cycle or {}) > 0
end

function MergeEggPrototypeService:_combatLayerForWave(context, waveIndex)
    local stageId, stage = self:_progressionStage(context)
    local resolvedWave = math.max(
        1,
        math.floor(
            tonumber(waveIndex) or type(context) == "table" and tonumber(context.waveIndex) or 1
        )
    )
    for _, layer in ipairs(stage.combat_layers or {}) do
        local throughWave =
            math.max(1, math.floor(tonumber(layer.through_wave) or self:_waveCount(context)))
        if resolvedWave <= throughWave then
            return tostring(layer.id or stageId), layer
        end
    end
    return stageId, stage
end

function MergeEggPrototypeService:_stageEnemyConfig(context, source, waveIndex)
    local _, layer = self:_combatLayerForWave(context, waveIndex)
    local scaling = layer.enemy or {}
    local resolvedWaveIndex = math.max(
        1,
        math.floor(
            tonumber(waveIndex) or type(context) == "table" and tonumber(context.waveIndex) or 1
        )
    )
    local waveScaling = (self:_waveFor(context, resolvedWaveIndex) or {}).enemy or {}
    local resolved = table.clone(source or {})
    resolved.hp = math.max(
        1,
        math.floor(
            (tonumber(source and source.hp) or 1)
                * math.max(0.01, tonumber(scaling.hp_multiplier) or 1)
                * math.max(0.01, tonumber(waveScaling.hp_multiplier) or 1)
        )
    )
    resolved.damage = math.max(
        0,
        (tonumber(source and source.damage) or 0)
            * math.max(0, tonumber(scaling.damage_multiplier) or 1)
            * math.max(0, tonumber(waveScaling.damage_multiplier) or 1)
    )
    resolved.armor = math.max(
        0,
        (tonumber(source and source.armor) or 0)
            * math.max(0, tonumber(scaling.armor_multiplier) or 1)
            * math.max(0, tonumber(waveScaling.armor_multiplier) or 1)
    )
    return resolved
end

function MergeEggPrototypeService:_stageRewardMultiplier(context, waveIndex)
    local _, layer = self:_combatLayerForWave(context, waveIndex)
    local resolvedWaveIndex = math.max(
        1,
        math.floor(
            tonumber(waveIndex) or type(context) == "table" and tonumber(context.waveIndex) or 1
        )
    )
    local waveScaling = (self:_waveFor(context, resolvedWaveIndex) or {}).enemy or {}
    return math.max(0, tonumber((layer.enemy or {}).reward_multiplier) or 1)
        * math.max(0, tonumber(waveScaling.reward_multiplier) or 1)
end

function MergeEggPrototypeService:_buildHatchSource(record, eggId)
    eggId = tostring(eggId or "")
    local eggData = self._petsConfig
        and self._petsConfig.egg_sources
        and self._petsConfig.egg_sources[eggId]
    if
        not eggData
        or not (self._petsConfig and self._petsConfig.simulateHatch)
        or not (self._eggService and self._eggService.BuildPlayerHatchData)
    then
        return nil, "prototype_egg_unavailable"
    end
    local ok, playerData = pcall(function()
        return self._eggService:BuildPlayerHatchData(record.player, eggId, eggData, {})
    end)
    if not ok or type(playerData) ~= "table" then
        return nil, "prototype_hatch_data_failed"
    end
    return {
        eggId = eggId,
        eggName = tostring(eggData.name or eggId),
        hatchPlayerData = playerData,
    }
end

function MergeEggPrototypeService:_buildPrototypeHatchData(record)
    local teamCfg = self._config.team or {}
    local source, reason = self:_buildHatchSource(
        record,
        (self:_eggProgression(record) or teamCfg.egg_progression or {})[1] or "grass_egg"
    )
    if not source then
        return false, reason
    end
    record.eggId = source.eggId
    record.eggName = source.eggName
    record.hatchPlayerData = source.hatchPlayerData
    return true
end

function MergeEggPrototypeService:_playerCombatMode(player)
    local reserve = self._config.player_reserve or {}
    local rules = type(reserve.full_mode) == "table" and reserve.full_mode or {}
    local data = self._dataService and self._dataService:GetData(player)
    local tutorialDone = data
        and type(data.CombatTutorial) == "table"
        and data.CombatTutorial.done == true
    local eligible = MergeEggPlayerCombat.isFullEligible(
        player and player:GetAttribute("Level"),
        tutorialDone,
        rules.minimum_level
    )
    local preference = data and data.Settings and data.Settings.MergeDefenseMode
    preference = MergeEggPlayerCombat.normalizeMode(preference, rules.default_mode)
    local onboarding = data
            and data.GameData
            and MergeEggPlayerCombat.normalizeOnboarding(data.GameData.MergeDefense)
        or nil
    local choicePending = MergeEggPlayerCombat.isUnlockChoicePending(onboarding, eligible)
    local mode =
        MergeEggPlayerCombat.resolveMode(preference, eligible, rules.default_mode, choicePending)
    if player then
        player:SetAttribute("MergeDefenseFullEligible", eligible)
        player:SetAttribute("MergeDefenseModeChoicePending", choicePending)
        player:SetAttribute("MergeDefenseModePreference", preference)
        player:SetAttribute("MergeDefenseMode", mode)
    end
    return mode, eligible
end

function MergeEggPrototypeService:_playerHatchSource(record, deployedTier)
    local playerProgression = self:_personalHatchProgression(record)
    local normalTierCount = #playerProgression
    if normalTierCount == 0 then
        return nil, "player_hatch_progression_unavailable"
    end
    -- Prototype-Huge tiers repeat the origin catalog for NPC combat only. A Full-mode player's
    -- durable hatch resolves to the repeated origin's ordinary egg and never inherits the forced
    -- Huge presentation.
    local playerDeployedTier = (
        (math.max(1, math.floor(tonumber(deployedTier) or 1)) - 1) % normalTierCount
    ) + 1
    local tier, eggId = MergeEggPlayerCombat.resolveHatchTier(
        playerProgression,
        record.rebirthCount,
        playerDeployedTier,
        self:_personalHatchRules()
    )
    if not eggId then
        return nil, "player_hatch_egg_unavailable"
    end
    local source, reason = self:_buildHatchSource(record, eggId)
    if source then
        source.tier = tier
    end
    return source, reason
end

function MergeEggPrototypeService:_awardFullModeHatch(record, deployedTier)
    if
        not record
        or record.playerCombatMode ~= "full"
        or not self:_canAwardPersonalHatch(record.player)
        or not self._petGrantService
        or not self._inventoryService
    then
        return false
    end
    local source, reason = self:_playerHatchSource(record, deployedTier)
    if not source then
        self:_log("Warn", "Merge Egg real player hatch source unavailable", {
            player = record.player.Name,
            deployedTier = deployedTier,
            reason = reason,
        })
        return false
    end
    local result = self._petsConfig.simulateHatch(source.eggId, source.hatchPlayerData)
    if not (result and result.pet) then
        return false
    end
    local granted = self._petGrantService:GrantPet(record.player, {
        petType = result.pet,
        variant = result.variant or "basic",
        huge = result.huge == true,
        source = "merge_defense_hatch",
    })
    if not (granted and granted.ok and granted.uid) then
        self:_log("Warn", "Merge Egg real player hatch grant failed", {
            player = record.player.Name,
            egg = source.eggId,
            pet = result.pet,
            reason = granted and granted.error or "grant_failed",
        })
        return false
    end

    -- Full mode still obeys ordinary roster ownership: only genuinely empty, unlocked positions
    -- auto-fill. A downed or deliberately occupied slot is never replaced by the defense hatch.
    self._inventoryService:FillEmptyPetSlots(
        record.player,
        { granted.uid },
        "merge_defense_hatch_auto_fill"
    )
    if self._dataService and self._dataService.AddToCounter then
        self._dataService:AddToCounter(record.player, "eggs_hatched", 1)
    end
    record.playerRealHatchesAwarded = (record.playerRealHatchesAwarded or 0) + 1
    record.player:SetAttribute("MergeEggRealPlayerHatches", record.playerRealHatchesAwarded)

    local isNew = granted.petIndex ~= nil and granted.petIndex.isNew == true
    if isNew and Signals.MergeEggPrototypePlayerHatch then
        local petData = granted.petData or result.petData or {}
        Signals.MergeEggPrototypePlayerHatch:FireClient(record.player, {
            eggType = source.eggId,
            eggTier = source.tier,
            petType = tostring(result.pet),
            variant = tostring(result.variant or "basic"),
            huge = result.huge == true,
            rarityId = result.huge == true and "huge" or petData.rarity_id,
            power = petData.power,
            newIndexEntry = true,
        })
    end
    return true
end

function MergeEggPrototypeService:_isPrototypeHugeTier(tier)
    local cfg = (self._config.team or {}).prototype_huge_progression or {}
    local startTier = math.max(
        1,
        math.floor(requiredConfigNumber(cfg.start_tier, "prototype_huge_progression.start_tier"))
    )
    return math.max(1, math.floor(tonumber(tier) or 1)) >= startTier
end

function MergeEggPrototypeService:_rollPrototypePet(record, source, tier)
    source = source or record
    if not (record and source and source.eggId and source.hatchPlayerData) then
        return nil
    end
    local result = self._petsConfig.simulateHatch(source.eggId, source.hatchPlayerData)
    if not (result and result.pet) then
        return nil
    end
    local naturalHuge = result.huge == true
    local prototypeHuge = self:_isPrototypeHugeTier(tier)
    local definition = {
        pet = tostring(result.pet),
        variant = tostring(result.variant or "basic"),
        huge = naturalHuge or prototypeHuge,
        naturalHuge = naturalHuge,
        prototypeHuge = prototypeHuge,
    }
    local roles = self._petRolesConfig or {}
    definition.role = (roles.by_type and roles.by_type[definition.pet]) or roles.default or "melee"
    local petData = self._petsConfig.getPet
        and self._petsConfig.getPet(definition.pet, definition.variant)
    definition.combatPower = math.max(
        1,
        tonumber(definition.huge and petData and petData.huge_base_power)
            or tonumber(petData and petData.power)
            or 1
    )
    return definition
end

function MergeEggPrototypeService:_draftRollsForEggTier(tier, context)
    local _, stage = self:_progressionStage(context)
    local configured = stage.draft_rolls_by_tier or {}
    local index = math.max(1, math.floor(tonumber(tier) or 1))
    return math.max(1, math.floor(tonumber(configured[index]) or index))
end

function MergeEggPrototypeService:_draftRoster(team, excludedSlot, selected)
    local roster = {}
    for slot, definition in ipairs((team and team.config and team.config.squad) or {}) do
        if slot ~= excludedSlot and definition then
            roster[#roster + 1] = definition
        end
    end
    for _, definition in ipairs(selected or {}) do
        roster[#roster + 1] = definition
    end
    return roster
end

function MergeEggPrototypeService:_recordDraftCandidate(record, team, definition)
    record.draftCandidateRolls = (record.draftCandidateRolls or 0) + 1
    if team then
        team.draftCandidateRolls = (team.draftCandidateRolls or 0) + 1
        if team.folder and team.folder.Parent then
            team.folder:SetAttribute("MergeEggDraftCandidateRolls", team.draftCandidateRolls)
        end
    end
    local variant = tostring(definition and definition.variant or "basic")
    record.draftGoldenCandidates = (record.draftGoldenCandidates or 0)
        + (variant == "golden" and 1 or 0)
    record.draftRainbowCandidates = (record.draftRainbowCandidates or 0)
        + (variant == "rainbow" and 1 or 0)
    record.draftHugeCandidates = (record.draftHugeCandidates or 0)
        + (definition and definition.naturalHuge == true and 1 or 0)
end

function MergeEggPrototypeService:_playerReserveSlots(record)
    local cfg = self._config.player_reserve or {}
    local base = math.max(1, math.floor(tonumber(cfg.base_slots) or 3))
    local maximum = math.max(base, math.floor(tonumber(cfg.maximum_slots) or 4))
    local featureName = tostring(cfg.extra_slot_feature or "extra_equip_slots")
    local feature = self._dataService
        and self._dataService.GetFeature
        and self._dataService:GetFeature(record.player, featureName)
    local hasExtra = feature == true or (tonumber(feature) or 0) > 0
    return math.min(maximum, base + (hasExtra and 1 or 0)), hasExtra
end

function MergeEggPrototypeService:_publishPlayerReserve(record)
    if not record then
        return
    end
    local capacity, hasExtra = self:_playerReserveSlots(record)
    local active = math.max(0, math.floor(tonumber(record.playerEscortActive) or 0))
    local reserve = #(record.playerReserve or {})
    local pending = #(record.playerReplacementQueue or {})
    record.playerEscortCapacity = capacity
    record.player:SetAttribute("MergeEggPlayerCombatMode", record.playerCombatMode or "simple")
    record.player:SetAttribute("MergeEggReserveRosterCapacity", capacity)
    record.player:SetAttribute("MergeEggReserveRosterHasExtraSlot", hasExtra)
    record.player:SetAttribute("MergeEggReserveRosterActive", active)
    record.player:SetAttribute("MergeEggReserveRosterBench", reserve)
    record.player:SetAttribute("MergeEggReserveRosterPending", pending)
    record.player:SetAttribute(
        "MergeEggReserveRosterCastoffs",
        math.max(0, math.floor(tonumber(record.playerCastoffsAwarded) or 0))
    )
    record.player:SetAttribute(
        "MergeEggReserveRosterReplacements",
        math.max(0, math.floor(tonumber(record.playerReplacementsEquipped) or 0))
    )
end

function MergeEggPrototypeService:_addPlayerCastoff(record, definition)
    if
        record.playerCombatMode == "full"
        or (self._config.player_reserve or {}).enabled ~= true
        or not definition
    then
        return false
    end
    record.playerReserve = record.playerReserve or {}
    record.playerReserve[#record.playerReserve + 1] = definition
    record.playerCastoffsAwarded = (record.playerCastoffsAwarded or 0) + 1
    record.peakPlayerReserveDepth =
        math.max(record.peakPlayerReserveDepth or 0, #record.playerReserve)
    self:_publishPlayerReserve(record)
    return true
end

function MergeEggPrototypeService:_rollDraftedPrototypePet(
    record,
    team,
    source,
    tier,
    excludedSlot,
    selected
)
    local rollCount = self:_draftRollsForEggTier(tier, team or record)
    local candidates = {}
    for _ = 1, rollCount do
        local definition = self:_rollPrototypePet(record, source, tier)
        if not definition then
            return nil
        end
        candidates[#candidates + 1] = definition
        self:_recordDraftCandidate(record, team, definition)
    end
    local castoff
    local hatcherCandidates = candidates
    if #candidates > 1 then
        local weakest, weakestIndex = MergeEggDraft.weakest(candidates)
        if weakest and weakestIndex then
            castoff = weakest
            hatcherCandidates = {}
            for index, candidate in ipairs(candidates) do
                if index ~= weakestIndex then
                    hatcherCandidates[#hatcherCandidates + 1] = candidate
                end
            end
        end
    end
    local chosen =
        MergeEggDraft.select(hatcherCandidates, self:_draftRoster(team, excludedSlot, selected))
    if chosen and castoff then
        if record.playerCombatMode == "full" and record.restoringDurableCheckpoint ~= true then
            self:_awardFullModeHatch(record, tier)
        else
            self:_addPlayerCastoff(record, castoff)
        end
    end
    if chosen then
        local rejected = math.max(0, #candidates - 1 - (castoff and 1 or 0))
        record.draftRejectedRolls = (record.draftRejectedRolls or 0) + rejected
        if team then
            team.draftRejectedRolls = (team.draftRejectedRolls or 0) + rejected
            if team.folder and team.folder.Parent then
                team.folder:SetAttribute("MergeEggDraftRejectedRolls", team.draftRejectedRolls)
            end
        end
    end
    return chosen
end

function MergeEggPrototypeService:_rollPrototypeSquad(record, team, count, source, tier)
    local squad = {}
    for _ = 1, math.max(1, math.floor(tonumber(count) or 5)) do
        local definition = self:_rollDraftedPrototypePet(record, team, source, tier, nil, squad)
        if not definition then
            return nil
        end
        squad[#squad + 1] = definition
    end
    return squad
end

function MergeEggPrototypeService:_playerEscortAnchorCFrame(record)
    local root = record and characterRoot(record.player)
    if not root or (self._config.player_reserve or {}).hold_at_breach_line ~= true then
        return root and root.CFrame or nil
    end
    local worldCfg = self._config.world or {}
    local world = self:_worldFor(record)
    local breachLine = findNamedPart(world, worldCfg.breach_line or "BreachLine")
    local enemySpawn = findNamedPart(world, worldCfg.enemy_spawn_area or "EnemySpawnArea")
    if not breachLine then
        return root.CFrame
    end
    local forward = enemySpawn
            and Vector3.new(
                enemySpawn.Position.X - breachLine.Position.X,
                0,
                enemySpawn.Position.Z - breachLine.Position.Z
            )
        or Vector3.new(breachLine.CFrame.LookVector.X, 0, breachLine.CFrame.LookVector.Z)
    if forward.Magnitude <= 0.01 then
        forward = Vector3.new(0, 0, 1)
    else
        forward = forward.Unit
    end
    local position = Vector3.new(breachLine.Position.X, root.Position.Y, breachLine.Position.Z)
    return CFrame.lookAt(position, position + forward)
end

function MergeEggPrototypeService:_spawnPlayerEscortSlot(record, slot, definition)
    local folder = record.petFolder or self:_playerPetFolder(record.player, true)
    local anchor = self:_playerEscortAnchorCFrame(record)
    if not (folder and anchor and definition) then
        return nil
    end
    local spawned, models = self._npcPrincipalService:SpawnGhostSquad(
        folder,
        { definition },
        anchor,
        {
            attributes = {
                MergeEggPlayerReserveUnit = true,
                MergeEggRunId = record.runId,
                MergeEggEscortAnchorPosition = anchor.Position,
                MergeEggEscortAnchorLookVector = anchor.LookVector,
                CombatTargetOpen = true,
                CombatCadenceMultiplier = combatCadenceMultiplier(self._config),
                EphemeralDownPolicy = "destroy",
                PrincipalLevel = self:_prototypeBaseLevel(record),
                Level = self:_prototypeBaseLevel(record),
            },
            positionOffset = slot - 1,
        }
    )
    if spawned ~= 1 or not models[1] then
        for _, model in ipairs(models or {}) do
            model:Destroy()
        end
        return nil
    end
    record.playerUnits = record.playerUnits or {}
    record.playerUnits[#record.playerUnits + 1] = models[1]
    return models[1]
end

function MergeEggPrototypeService:_spawnPlayerEscortSquad(record, squad, capacity)
    capacity = math.max(0, math.floor(tonumber(capacity) or self:_playerReserveSlots(record)))
    local expected = squadDefinitionCount(squad, capacity)
    if expected <= 0 then
        return false
    end
    record.playerUnits = {}
    local spawned = 0
    for slot = 1, capacity do
        local definition = squad[slot]
        if definition then
            if not self:_spawnPlayerEscortSlot(record, slot, definition) then
                self:_clearPlayerEscortModels(record)
                return false
            end
            spawned += 1
        end
    end
    record.playerEscortActive = spawned
    return spawned == expected
end

function MergeEggPrototypeService:_ensurePlayerEscort(record)
    if record.playerCombatMode == "full" or (self._config.player_reserve or {}).enabled ~= true then
        return
    end
    local capacity = self:_playerReserveSlots(record)
    record.playerSquad = record.playerSquad or {}
    record.playerReserve = record.playerReserve or {}
    if squadDefinitionCount(record.playerSquad, capacity) == 0 then
        local squad, reserve = MergeEggDraft.composePlayerRoster(record.playerReserve, capacity)
        if
            squadDefinitionCount(squad, capacity) > 0
            and self:_spawnPlayerEscortSquad(record, squad, capacity)
        then
            record.playerSquad = squad
            record.playerReserve = reserve
            record.playerEscortInitialized = true
        end
        self:_publishPlayerReserve(record)
        return
    end

    local roles = (self._config.player_reserve or {}).roles
        or { "tank", "ranged", "melee", "support" }
    for slot = 1, capacity do
        if record.playerSquad[slot] == nil then
            local definition, reserveIndex = MergeEggDraft.selectPlayerReplacement(
                record.playerReserve,
                roles[slot],
                slot <= 3 and "non_support" or "none"
            )
            if not (definition and reserveIndex) then
                break
            end
            if not self:_spawnPlayerEscortSlot(record, slot, definition) then
                break
            end
            table.remove(record.playerReserve, reserveIndex)
            record.playerSquad[slot] = definition
            record.playerEscortActive = (record.playerEscortActive or 0) + 1
            record.playerEscortInitialized = true
        end
    end
    self:_publishPlayerReserve(record)
end

function MergeEggPrototypeService:_clearPlayerEscortModels(record)
    local folder = record and (record.petFolder or self:_playerPetFolder(record.player, false))
    for _, model in ipairs(folder and folder:GetChildren() or {}) do
        if model:IsA("Model") and model:GetAttribute("MergeEggPlayerReserveUnit") == true then
            model:Destroy()
        end
    end
    if record then
        record.playerUnits = {}
        record.playerEscortActive = 0
    end
end

function MergeEggPrototypeService:_eggProgression(context)
    local _, stage = self:_progressionStage(context)
    local progression = stage.egg_progression or (self._config.team or {}).egg_progression
    if type(progression) == "table" and #progression > 0 then
        return progression
    end
    return { "grass_egg" }
end

function MergeEggPrototypeService:_eggDisplayName(eggId)
    local source = self._petsConfig
        and self._petsConfig.egg_sources
        and self._petsConfig.egg_sources[eggId]
    return tostring(source and source.name or eggId)
end

function MergeEggPrototypeService:_markEggTierMilestone(record, tier)
    local numericTier = tonumber(tier)
    local resolvedTier = numericTier and math.floor(numericTier) or 0
    if not record or resolvedTier < 1 then
        return false
    end
    record.activityEggTierMilestones = record.activityEggTierMilestones or {}
    if record.activityEggTierMilestones[resolvedTier] == true then
        return false
    end
    record.activityEggTierMilestones[resolvedTier] = true
    return true
end

function MergeEggPrototypeService:_markPetSlotMilestone(record, eggTier)
    if not record then
        return nil
    end
    local firstTierSlots = self:_positionsForEggTier(1, record)
    local previous = tonumber(record.activityMaximumPetSlots)
    previous = previous and math.max(firstTierSlots, math.floor(previous)) or firstTierSlots
    local unlocked = self:_positionsForEggTier(eggTier, record)
    record.activityMaximumPetSlots = math.max(previous, unlocked)
    return unlocked > previous and unlocked or nil
end

-- Reconnecting to a live board must not celebrate an already-created tier again. Egg progression
-- is sequential, so any restored highest tier proves that every lower tier was created earlier.
function MergeEggPrototypeService:_restoreEggTierMilestones(record)
    record.activityEggTierMilestones = {}
    local highest = (record.eggsCreated or 0) > 0 and 1 or 0
    local baseTier = self:_baseEggTier(record)
    if baseTier > 1 then
        highest = math.max(highest, baseTier)
    end
    local maximumEggTier = tonumber(record.maximumEggTier)
    if maximumEggTier then
        highest = math.max(highest, math.floor(maximumEggTier))
    end
    for tier = 1, #self:_eggProgression(record) do
        if self:_eggInventoryCount(record, tier) > 0 then
            highest = math.max(highest, tier)
        end
    end
    for _, team in ipairs(record.teams or {}) do
        local teamTier = tonumber(team.eggTier)
        if teamTier then
            highest = math.max(highest, math.floor(teamTier))
        end
    end
    for tier = 1, highest do
        record.activityEggTierMilestones[tier] = true
    end
    record.activityMaximumPetSlots = self:_positionsForEggTier(math.max(1, highest), record)
end

function MergeEggPrototypeService:_earthEggPricing(context)
    local _, stage = self:_progressionStage(context)
    local configured = stage.egg_pricing or (self._config.team or {}).earth_egg_pricing or {}
    return {
        currency = tostring(configured.currency or "hall_coins"),
        baseAmount = math.max(0, math.floor(tonumber(configured.base_amount) or 100)),
        growth = math.max(1, tonumber(configured.growth) or 2),
    }
end

function MergeEggPrototypeService:_baseEggTier(context)
    local progression = self:_eggProgression(context)
    local cfg = (self._config.team or {}).base_egg_generator or {}
    local configured = math.max(1, math.floor(tonumber(cfg.initial_tier) or 1))
    local tier = type(context) == "table" and tonumber(context.baseEggTier) or configured
    return math.clamp(math.floor(tier or configured), 1, #progression)
end

function MergeEggPrototypeService:_baseEggCreationCost(context)
    local pricing = self:_earthEggPricing(context)
    local cfg = (self._config.team or {}).base_egg_generator or {}
    local tier = self:_baseEggTier(context)
    local amount = pricing.baseAmount
    if tier > 1 then
        local firstUpgraded = math.max(
            0,
            math.floor(tonumber(cfg.first_upgraded_egg_cost) or pricing.baseAmount * 2.5)
        )
        amount = MergeEggPricing.doublingTierCost(firstUpgraded, cfg.egg_cost_growth, tier, 2)
    end
    return {
        currency = pricing.currency,
        amount = amount,
        tier = tier,
    }
end

function MergeEggPrototypeService:_baseEggUpgradeCost(context)
    local cfg = (self._config.team or {}).base_egg_generator or {}
    local tier = self:_baseEggTier(context)
    local progression = self:_eggProgression(context)
    if tier >= #progression then
        return nil
    end
    local first = math.max(0, math.floor(tonumber(cfg.first_upgrade_cost) or 1000))
    return {
        currency = self:_earthEggPricing(context).currency,
        amount = MergeEggPricing.doublingTierCost(first, cfg.upgrade_cost_growth, tier, 1),
        tier = tier + 1,
    }
end

function MergeEggPrototypeService:_canUpgradeBaseEgg(record)
    local upgrade = self:_baseEggUpgradeCost(record)
    if not upgrade then
        return false, "maximum_base_egg_reached"
    end
    return true
end

function MergeEggPrototypeService:_raiseBoardToBaseTier(record, minimumTier)
    record.eggInventory = record.eggInventory or {}
    minimumTier = math.max(1, math.floor(tonumber(minimumTier) or 1))
    local promoted = 0
    for tier = 1, minimumTier - 1 do
        local count = self:_eggInventoryCount(record, tier)
        if count > 0 then
            promoted += count
            record.eggInventory[tier] = nil
        end
    end
    if promoted > 0 then
        record.eggInventory[minimumTier] = self:_eggInventoryCount(record, minimumTier) + promoted
    end
    return promoted
end

function MergeEggPrototypeService:_raiseHatchersToBaseTier(record, minimumTier, source)
    local promoted = 0
    local addedUnits = 0
    local expansionFailures = 0
    for _, team in ipairs(record and record.teams or {}) do
        local currentTier = math.max(0, math.floor(tonumber(team.eggTier) or 0))
        if currentTier > 0 and currentTier < minimumTier then
            local expanded, addedOrReason =
                self:_expandTeamForEggTier(record, team, source, minimumTier)
            if expanded then
                addedUnits += math.max(0, math.floor(tonumber(addedOrReason) or 0))
            else
                expansionFailures += 1
                self:_log("Warn", "Merge Egg base floor could not expand hatcher roster", {
                    team = team.id,
                    fromTier = currentTier,
                    toTier = minimumTier,
                    reason = addedOrReason,
                })
            end

            team.eggTier = minimumTier
            team.eggId = source.eggId
            team.eggName = source.eggName
            team.hatchPlayerData = source.hatchPlayerData
            self:_removeHatcherEggObjective(team)
            team.eggMaxHealth = self:_hatcherEggMaxHealth(record)
            team.eggHealth = team.eggMaxHealth
            team.eggDamageTaken = 0
            team.eggProductionLockedUntil = nil
            team.needsEggRebuild = false
            team.resetEggTier = nil
            team.resetEggId = nil
            team.resetEggName = nil
            team.resetHatchPlayerData = nil
            self:_applyTeamEggTierModifiers(team, minimumTier)
            for _, queued in ipairs(team.replacementQueue or {}) do
                queued.definition = nil
            end
            self:_spawnHatcherEggObjective(record, team)
            self:_publishTeamEggSource(team)
            self:_syncTeamState(record, team)
            promoted += 1
        elseif currentTier <= 0 then
            local recoveryTier = math.max(0, math.floor(tonumber(team.resetEggTier) or 0))
            if recoveryTier > 0 and recoveryTier < minimumTier then
                -- The installed egg may already be destroyed for this attempt. Its permanent
                -- deployment still inherits the new base floor, but remains disabled until the
                -- checkpoint recovery rebuilds every defense at full health.
                local expanded, addedOrReason =
                    self:_expandTeamForEggTier(record, team, source, minimumTier)
                if expanded then
                    addedUnits += math.max(0, math.floor(tonumber(addedOrReason) or 0))
                else
                    expansionFailures += 1
                    self:_log(
                        "Warn",
                        "Merge Egg base floor could not expand destroyed hatcher roster",
                        {
                            team = team.id,
                            fromTier = recoveryTier,
                            toTier = minimumTier,
                            reason = addedOrReason,
                        }
                    )
                end
                team.resetEggTier = minimumTier
                team.resetEggId = source.eggId
                team.resetEggName = source.eggName
                team.resetHatchPlayerData = source.hatchPlayerData
                for _, queued in ipairs(team.replacementQueue or {}) do
                    queued.definition = nil
                end
                self:_publishTeamEggSource(team)
                self:_syncTeamState(record, team)
                promoted += 1
            end
        end
    end
    record.maximumEggTier = math.max(record.maximumEggTier or 0, promoted > 0 and minimumTier or 0)
    return promoted, addedUnits, expansionFailures
end

function MergeEggPrototypeService:_prepareSessionCurrency(record)
    if not (record and self._economyService) then
        return false, "economy_unavailable"
    end
    local pricing = self:_baseEggCreationCost(record)
    local opening = type(self._config.opening_economy) == "table" and self._config.opening_economy
        or {}
    local currency = tostring(opening.currency or pricing.currency)
    local original = self._economyService:GetCurrency(record.player, currency)
    if original == nil then
        return false, "currency_unavailable"
    end
    -- Waycoins are the player's durable Merge wallet. Entry must never zero a returning player's
    -- balance; fresh/rebirth runs receive their authored opening drops separately.
    local startingCoins = math.max(0, math.floor(tonumber(original) or 0))
    record.sessionCurrency = currency
    record.sessionStartingCoins = startingCoins
    return true
end

function MergeEggPrototypeService:_prototypeCoinDropOptions(record)
    local rewardCfg = self._config.rewards or {}
    local authoredBounds = findNamedPart(self:_worldFor(record), "ArenaBounds")
    local fallbackBounds = (self._config.world or {}).bounds or {}
    return {
        -- The merge mode uses the exact same player-owned Magnet as every other world. Auto
        -- Collector remains its separate passive pet and may collect these currency records too.
        usePlayerModifiers = true,
        source = "merge_egg_prototype",
        visualScale = math.max(0.1, tonumber(rewardCfg.pickup_visual_scale) or 2),
        despawnSeconds = math.max(1, tonumber(rewardCfg.pickup_despawn_seconds) or 600),
        containmentBounds = rewardCfg.contain_pickups_to_world == true and {
            centerX = authoredBounds and authoredBounds.Position.X
                or tonumber(fallbackBounds.center_x),
            centerZ = authoredBounds and authoredBounds.Position.Z
                or tonumber(fallbackBounds.center_z),
            halfX = authoredBounds and authoredBounds.Size.X * 0.5
                or tonumber(fallbackBounds.half_x),
            halfZ = authoredBounds and authoredBounds.Size.Z * 0.5
                or tonumber(fallbackBounds.half_z),
            inset = math.max(0, tonumber(rewardCfg.pickup_wall_inset) or 2),
        } or nil,
    }
end

function MergeEggPrototypeService:_spawnOpeningCoinDrops(record)
    if not record then
        return false
    end
    local opening = type(self._config.opening_economy) == "table" and self._config.opening_economy
        or {}
    local offsets = type(opening.pickup_offsets) == "table" and opening.pickup_offsets or {}
    local amount = math.max(1, math.floor(tonumber(opening.pickup_amount) or 120))
    local worldCfg = self._config.world or {}
    local world = self:_worldFor(record)
    local anchor = findNamedPart(world, worldCfg.bulwark_line)
        or findNamedPart(world, worldCfg.player_spawn)
    if not anchor or #offsets == 0 then
        return false
    end

    local currency = tostring(opening.currency or self:_earthEggPricing(record).currency)
    local spawned = 0
    local fallbackAmount = 0
    local spawnAt = function(dropCurrency, dropAmount, position, reason, visualScale)
        local options = self:_prototypeCoinDropOptions(record)
        options.reason = reason
        if visualScale then
            options.visualScale = visualScale
        end
        local carried = false
        if self._dropService and self._dropService.SpawnCoinDrop then
            local ok, result = pcall(function()
                return self._dropService:SpawnCoinDrop(
                    record.player,
                    dropCurrency,
                    dropAmount,
                    position,
                    options
                )
            end)
            carried = ok and result == true
        end
        if carried then
            spawned += 1
            return true
        end
        return false
    end

    local spawnOne = function(dropCurrency, dropAmount, offset, reason, visualScale)
        local localOffset =
            Vector3.new(tonumber(offset.x) or 0, tonumber(offset.y) or 3, tonumber(offset.z) or 0)
        return spawnAt(
            dropCurrency,
            dropAmount,
            anchor.CFrame:PointToWorldSpace(localOffset),
            reason,
            visualScale
        )
    end

    local gem = self:_openingGemSpec()
    if gem then
        local gemPosition = self:_openingGemWorldPosition(world, gem)
        local gemCarried = if gemPosition
            then spawnAt(gem.currency, gem.amount, gemPosition, "opening_gem", gem.visualScale)
            else spawnOne(gem.currency, gem.amount, gem.offset, "opening_gem", gem.visualScale)
        record.openingGemSpawned = gemCarried == true
        if not gemCarried and self._economyService and self._economyService.AddCurrency then
            self._economyService:AddCurrency(
                record.player,
                gem.currency,
                gem.amount,
                "merge_egg_opening_gem_fallback"
            )
        end
    else
        record.openingGemSpawned = false
    end

    local optionsReason = "opening"
    for _, offset in ipairs(offsets) do
        if not spawnOne(currency, amount, offset, optionsReason, nil) then
            fallbackAmount += amount
        end
    end
    if fallbackAmount > 0 and self._economyService and self._economyService.AddCurrency then
        self._economyService:AddCurrency(
            record.player,
            currency,
            fallbackAmount,
            "merge_egg_opening_pickup_fallback"
        )
    end
    record.openingPickupsSpawned = spawned
    record.openingCoinsSpawned = #offsets * amount
    return spawned > 0
end

function MergeEggPrototypeService:_playstateHasBoard(playstate)
    playstate = type(playstate) == "table" and playstate or {}
    for _, count in
        ipairs(type(playstate.egg_inventory) == "table" and playstate.egg_inventory or {})
    do
        if math.max(0, math.floor(tonumber(count) or 0)) > 0 then
            return true
        end
    end
    for _, tier in
        ipairs(type(playstate.deployed_egg_tiers) == "table" and playstate.deployed_egg_tiers or {})
    do
        if math.max(0, math.floor(tonumber(tier) or 0)) > 0 then
            return true
        end
    end
    return math.max(1, math.floor(tonumber(playstate.base_egg_tier) or 1)) > self:_baseEggTier(nil)
end

-- First-visit / admin-reset collect beat: wallet at the authored opening amount, then five stacks.
function MergeEggPrototypeService:_ensureOpeningCoinLesson(record)
    if not record then
        return false
    end
    if (record.openingPickupsSpawned or 0) > 0 then
        return true
    end
    if self:_tutorialCollectedOpeningStash(record) then
        return true
    end
    if self._dropService and self._dropService.DiscardDrops then
        self._dropService:DiscardDrops(record.player, "merge_egg_prototype")
    end
    self:_resetSessionCurrency(record)
    return self:_spawnOpeningCoinDrops(record)
end

function MergeEggPrototypeService:_ensureCannonGemLesson(record)
    if not record then
        return false
    end
    local spec = self:_cannonGemSpec()
    if not spec then
        return true
    end
    if self:_cannonGemDropExists(record) then
        record.cannonGemSpawned = true
        return true
    end
    if self:_tutorialGemWallet(record) >= spec.amount then
        return true
    end
    if record.cannonGemSpawned == true then
        return self:_tutorialGemWallet(record) >= spec.amount
    end
    local world = self:_worldFor(record)
    local position = self:_cannonGemWorldPosition(world, spec)
    if not position then
        local worldCfg = self._config.world or {}
        local anchor = findNamedPart(world, worldCfg.bulwark_line)
            or findNamedPart(world, worldCfg.player_spawn)
        if anchor then
            local offset = spec.offset
            position = anchor.CFrame:PointToWorldSpace(
                Vector3.new(
                    tonumber(offset.x) or 0,
                    tonumber(offset.y) or 3,
                    tonumber(offset.z) or 0
                )
            )
        end
    end
    local carried = false
    if position and self._dropService and self._dropService.SpawnCoinDrop then
        local options = self:_prototypeCoinDropOptions(record)
        options.reason = "cannon_gem"
        options.visualScale = spec.visualScale
        local ok, result = pcall(function()
            return self._dropService:SpawnCoinDrop(
                record.player,
                spec.currency,
                spec.amount,
                position,
                options
            )
        end)
        carried = ok and result == true
    end
    record.cannonGemSpawned = carried == true
    if not carried and self._economyService and self._economyService.AddCurrency then
        self._economyService:AddCurrency(
            record.player,
            spec.currency,
            spec.amount,
            "merge_egg_cannon_gem_fallback"
        )
        record.cannonGemSpawned = true
    end
    return record.cannonGemSpawned == true
end

function MergeEggPrototypeService:_resetSessionCurrency(record)
    if not (record and self._economyService and record.sessionCurrency) then
        return false
    end
    local opening = type(self._config.opening_economy) == "table" and self._config.opening_economy
        or {}
    local resetAmount = math.max(0, math.floor(tonumber(opening.wallet_amount) or 0))
    return self._economyService:SetCurrency(
        record.player,
        record.sessionCurrency,
        resetAmount,
        "merge_egg_session_reset"
    )
end

function MergeEggPrototypeService:_eggInventoryCount(record, tier)
    local resolvedTier = math.max(1, math.floor(tonumber(tier) or 1))
    return math.max(
        0,
        math.floor(
            tonumber(record and record.eggInventory and record.eggInventory[resolvedTier]) or 0
        )
    )
end

function MergeEggPrototypeService:_mergeableEggTier(record)
    local progression = self:_eggProgression(record)
    local mergeCfg = (self._config.team or {}).merge_board or {}
    local ratio = math.max(2, math.floor(tonumber(mergeCfg.merge_ratio) or 2))
    for tier = 1, math.max(0, #progression - 1) do
        if self:_eggInventoryCount(record, tier) >= ratio then
            return tier, ratio
        end
    end
    return nil, ratio
end

function MergeEggPrototypeService:_boardTierAtSlot(record, slotIndex)
    local resolved = math.floor(tonumber(slotIndex) or 0)
    if resolved < 1 or resolved > self:_mergeBoardCapacity() then
        return nil
    end
    local cursor = 0
    for tier = 1, #self:_eggProgression(record) do
        cursor += self:_eggInventoryCount(record, tier)
        if resolved <= cursor then
            return tier
        end
    end
    return nil
end

function MergeEggPrototypeService:_applyEggMerge(record, tier)
    local progression = self:_eggProgression(record)
    local mergeCfg = (self._config.team or {}).merge_board or {}
    local ratio = math.max(2, math.floor(tonumber(mergeCfg.merge_ratio) or 2))
    local resolvedTier = math.floor(tonumber(tier) or 0)
    if
        resolvedTier < 1
        or resolvedTier >= #progression
        or self:_eggInventoryCount(record, resolvedTier) < ratio
    then
        return false
    end
    record.eggInventory[resolvedTier] = self:_eggInventoryCount(record, resolvedTier) - ratio
    record.eggInventory[resolvedTier + 1] = self:_eggInventoryCount(record, resolvedTier + 1) + 1
    record.eggsMerged = (record.eggsMerged or 0) + 1
    return true,
        self:_markEggTierMilestone(record, resolvedTier + 1),
        self:_markPetSlotMilestone(record, resolvedTier + 1)
end

function MergeEggPrototypeService:_publishBoardMutation(record)
    for _, team in ipairs(record.teams or {}) do
        self:_publishTeamEggSource(team)
    end
    local world = self:_worldFor(record)
    self:_setWorldState(
        world and world:GetAttribute("PrototypeState") or "AwaitingFirstEgg",
        record
    )
end

function MergeEggPrototypeService:_autoCombineBoard(record)
    local merged = 0
    local milestones = {}
    while true do
        local tier = self:_mergeableEggTier(record)
        if not tier then
            break
        end
        local applied, eggMilestone, petSlotMilestone = self:_applyEggMerge(record, tier)
        if not applied then
            break
        end
        merged += 1
        if eggMilestone or petSlotMilestone then
            local resultTier = tier + 1
            local eggId = self:_eggProgression(record)[resultTier]
            milestones[#milestones + 1] = {
                milestone = eggMilestone and "egg_created" or nil,
                eggTier = resultTier,
                eggId = eggId,
                eggName = self:_eggDisplayName(eggId),
                petSlotMilestone = petSlotMilestone,
            }
        end
    end
    if merged > 0 then
        record.lastEggMergeAt = os.clock()
        self:_publishBoardMutation(record)
    end
    return merged, milestones
end

function MergeEggPrototypeService:_publishEggInventory(record)
    local world = self:_worldFor(record)
    if not world then
        return
    end
    local progression = self:_eggProgression(record)
    local total = 0
    local summary = {}
    for tier, eggId in ipairs(progression) do
        local count = self:_eggInventoryCount(record, tier)
        total += count
        world:SetAttribute("EggInventoryTier" .. tier, count)
        world:SetAttribute("EggInventory_" .. tostring(eggId), count)
        if count > 0 then
            local data = self._petsConfig
                and self._petsConfig.egg_sources
                and self._petsConfig.egg_sources[eggId]
            summary[#summary + 1] = string.format("%s x%d", data and data.name or eggId, count)
        end
    end
    world:SetAttribute("EggInventoryTotal", total)
    world:SetAttribute(
        "EggInventorySummary",
        #summary > 0 and table.concat(summary, " • ") or "EMPTY"
    )
    world:SetAttribute("EggsCreated", record and record.eggsCreated or 0)
    world:SetAttribute("EggsMerged", record and record.eggsMerged or 0)
    world:SetAttribute("EggsPlaced", record and record.eggsPlaced or 0)
    world:SetAttribute("AutoCombineEnabled", record and record.autoCombineEnabled == true or false)

    local mergeTier, mergeRatio = self:_mergeableEggTier(record)
    local mergePrompt =
        findNamedPart(world, (self._config.world or {}).egg_merge_control or "EggMergeControl")
    mergePrompt = mergePrompt and mergePrompt:FindFirstChild(MERGE_EGG_PROMPT_NAME)
    if mergePrompt and mergePrompt:IsA("ProximityPrompt") then
        if mergeTier then
            local fromId = progression[mergeTier]
            local toId = progression[mergeTier + 1]
            local sources = self._petsConfig and self._petsConfig.egg_sources or {}
            mergePrompt.ObjectText = string.format(
                "%d %s → 1 %s",
                mergeRatio,
                sources[fromId] and sources[fromId].name or tostring(fromId),
                sources[toId] and sources[toId].name or tostring(toId)
            )
        else
            mergePrompt.ObjectText = "Need two equal eggs"
        end
    end
    self:_syncMergeBoardEggs(record)
end

function MergeEggPrototypeService:_initializedHatcherCount(record)
    local count = 0
    for _, team in ipairs(record and record.teams or {}) do
        if team.initialized == true then
            count += 1
        end
    end
    return count
end

function MergeEggPrototypeService:_nextEarthEggCost(record)
    local pricing = self:_baseEggCreationCost(record)
    local initialized = self:_initializedHatcherCount(record)
    return {
        currency = pricing.currency,
        amount = pricing.amount,
        tier = pricing.tier,
        ordinal = initialized + 1,
    }
end

function MergeEggPrototypeService:_eggTierCost(tier, context)
    local pricing = self:_earthEggPricing(context)
    local resolvedTier = math.max(1, math.floor(tonumber(tier) or 1))
    local cfg = (self._config.team or {}).base_egg_generator or {}
    local amount = pricing.baseAmount
    if resolvedTier > 1 then
        amount = MergeEggPricing.doublingTierCost(
            math.max(
                0,
                math.floor(tonumber(cfg.first_upgraded_egg_cost) or pricing.baseAmount * 2.5)
            ),
            cfg.egg_cost_growth,
            resolvedTier,
            2
        )
    end
    return {
        currency = pricing.currency,
        amount = amount,
        tier = resolvedTier,
    }
end

-- A deployed egg is one half of its next merge. An empty hatcher consumes an Earth Egg and
-- installs it unchanged; every occupied hatcher consumes another egg of its current tier and
-- produces the next tier. This keeps board merging and hatcher merging on the same 2-equal-eggs
-- rule instead of asking the player to provide the result egg.
function MergeEggPrototypeService:_deployedEggTransaction(team, context)
    local progression = self:_eggProgression(context or team)
    local currentTier =
        math.clamp(math.floor(tonumber(team and team.eggTier) or 0), 0, #progression)
    local baseTier = self:_baseEggTier(context)
    local requiredTier = currentTier > 0 and currentTier or baseTier
    local resultTier = currentTier > 0 and (currentTier + 1) or baseTier
    return {
        currentTier = currentTier,
        requiredTier = requiredTier,
        requiredEggId = progression[requiredTier],
        resultTier = resultTier,
        resultEggId = progression[resultTier],
    }
end

-- Capacity comes first: fill every empty position with its own 100-Waycoin Earth Egg. Once the
-- formation exists, advance the lowest egg tier so core progression stays roughly even across
-- teams. Permanent board upgrades are deliberately outside this selector and get their own budget.
function MergeEggPrototypeService:_nextCoreEggAction(record)
    local progression = self:_eggProgression(record)
    local candidate
    for _, team in ipairs(record and record.teams or {}) do
        local tier = math.clamp(math.floor(tonumber(team.eggTier) or 0), 0, #progression)
        if tier < #progression then
            if team.initialized ~= true then
                local baseTier = self:_baseEggTier(record)
                return team, self:_eggTierCost(baseTier, record)
            end
            if
                candidate == nil
                or tier < candidate.tier
                or (tier == candidate.tier and team.id < candidate.team.id)
            then
                candidate = { team = team, tier = tier }
            end
        end
    end
    if not candidate then
        return nil
    end
    -- Upgrading a deployed tier-N egg requires another tier-N egg, not the tier-(N+1) result.
    return candidate.team, self:_eggTierCost(math.max(1, candidate.tier), record)
end

-- Resolve build access from the authored geometry rather than a hardcoded world axis. "Behind"
-- means the finish-line side of BulwarkLine; a small depth removes ambiguous edge clicks, and the
-- captain radius makes the avatar actually return beneath the selected billboard.
function MergeEggPrototypeService:_canUseHatcher(player, team)
    local root = characterRoot(player)
    local worldCfg = self._config.world or {}
    local world = self:_worldFor(team and team.record or self:_recordFor(player))
    local bulwark = findNamedPart(world, worldCfg.bulwark_line or "BulwarkLine")
    local finish = findNamedPart(world, worldCfg.enemy_finish_line or "EnemyFinishLine")
    local hatcherRoot = team
        and team.principalModel
        and team.principalModel:FindFirstChild("HumanoidRootPart")
    if not (root and bulwark and finish and hatcherRoot) then
        return false, "hatcher_access_unavailable"
    end

    local towardFinish = Vector3.new(
        finish.Position.X - bulwark.Position.X,
        0,
        finish.Position.Z - bulwark.Position.Z
    )
    if towardFinish.Magnitude <= 0 then
        return false, "hatcher_access_unavailable"
    end
    local fromBulwark =
        Vector3.new(root.Position.X - bulwark.Position.X, 0, root.Position.Z - bulwark.Position.Z)
    local bulwarkDepth = fromBulwark:Dot(towardFinish.Unit)
    local accessCfg = (self._config.team or {}).build_access or {}
    local minimumDepth = math.max(0, tonumber(accessCfg.minimum_bulwark_depth) or 4)
    if bulwarkDepth < minimumDepth then
        return false, "behind_bulwark_required", bulwarkDepth
    end

    local fromHatcher = Vector3.new(
        root.Position.X - hatcherRoot.Position.X,
        0,
        root.Position.Z - hatcherRoot.Position.Z
    )
    local hatcherDistance = fromHatcher.Magnitude
    local maximumDistance = math.max(1, tonumber(accessCfg.maximum_hatcher_distance) or 18)
    if hatcherDistance > maximumDistance then
        return false, "hatcher_too_far", bulwarkDepth, hatcherDistance
    end
    return true, nil, bulwarkDepth, hatcherDistance
end

function MergeEggPrototypeService:_canUseEggStation(player, stationName)
    local root = characterRoot(player)
    local station = findNamedPart(self:_worldFor(self:_recordFor(player)), stationName)
    if not (root and station) then
        return false, "egg_station_unavailable"
    end
    local offset =
        Vector3.new(root.Position.X - station.Position.X, 0, root.Position.Z - station.Position.Z)
    local mergeCfg = (self._config.team or {}).merge_board or {}
    local maximumDistance = math.max(1, tonumber(mergeCfg.station_use_distance) or 16)
    if offset.Magnitude > maximumDistance then
        return false, "egg_station_too_far", offset.Magnitude
    end
    return true, nil, offset.Magnitude
end

function MergeEggPrototypeService:_healDenialConfig()
    local objective = type(self._config.objective) == "table" and self._config.objective or {}
    return type(objective.heal_denial) == "table" and objective.heal_denial or {}
end

function MergeEggPrototypeService:_publishEggHealDenial(team, now)
    local folder = team and team.folder
    if not (folder and folder.Parent) then
        return
    end
    now = tonumber(now) or os.clock()
    local cfg = self:_healDenialConfig()
    local activeUntil = tonumber(team.healDenialActiveUntil) or 0
    local readyAt = tonumber(team.healDenialReadyAt) or 0
    local active = cfg.enabled == true
        and math.floor(tonumber(team.eggTier) or 0) > 0
        and activeUntil > now
    folder:SetAttribute("MergeEggHealDenialEnabled", cfg.enabled == true)
    folder:SetAttribute("MergeEggHealDenialActive", active)
    folder:SetAttribute("MergeEggHealDenialRadius", math.max(0, tonumber(cfg.radius) or 12))
    folder:SetAttribute("MergeEggHealDenialActiveRemaining", math.max(0, activeUntil - now))
    folder:SetAttribute(
        "MergeEggHealDenialRechargeRemaining",
        math.max(0, readyAt - math.max(now, activeUntil))
    )
    folder:SetAttribute("MergeEggHealDenialReadyIn", math.max(0, readyAt - now))
    folder:SetAttribute("MergeEggHealDenialActivations", team.healDenialActivations or 0)
    folder:SetAttribute("MergeEggHealDenialLastTrigger", team.healDenialLastTrigger)
    folder:SetAttribute(
        "MergeEggHealDenialSuppressedEnemies",
        team.healDenialSuppressedEnemies or 0
    )
end

function MergeEggPrototypeService:_triggerEggHealDenial(record, team, reason, now)
    local cfg = self:_healDenialConfig()
    local objective = team and team.eggObjective
    if
        cfg.enabled ~= true
        or not self:_isRecordActive(record)
        or record.terminal == true
        or not (objective and objective.Parent)
        or math.floor(tonumber(team.eggTier) or 0) <= 0
    then
        return false
    end

    now = tonumber(now) or os.clock()
    if now < (tonumber(team.healDenialReadyAt) or 0) then
        return false
    end

    local activeSeconds = math.max(0.1, tonumber(cfg.active_seconds) or 30)
    local rechargeSeconds = math.max(0, tonumber(cfg.recharge_seconds) or 30)
    team.healDenialActiveUntil = now + activeSeconds
    -- Recharge begins after the active window, producing 30 seconds on / 30 seconds off by default.
    team.healDenialReadyAt = team.healDenialActiveUntil + rechargeSeconds
    team.healDenialActivations = (team.healDenialActivations or 0) + 1
    team.healDenialLastTrigger = tostring(reason or "unknown")
    team.healDenialSuppressedEnemies = 0
    record.healDenialActivations = (record.healDenialActivations or 0) + 1

    if team.healDenialRune and team.healDenialRune.Parent then
        team.healDenialRune:Destroy()
    end
    if self._powerService and self._powerService.SpawnGroundRune then
        local color = rgbTriplet(cfg.color, { 255, 70, 150 })
        local floor = findNamedPart(self:_worldFor(record), "LandStrip")
        local floorY = floor and (floor.Position.Y + floor.Size.Y * 0.5) or nil
        team.healDenialRune = self._powerService:SpawnGroundRune(
            objective:GetPivot().Position,
            math.max(1, tonumber(cfg.radius) or 12),
            color,
            {
                name = "MergeEggHealDenialTeam" .. tostring(team.id),
                fade_in = 0.35,
                hold = math.max(0.1, activeSeconds - 0.95),
                fade_out = 0.6,
                bright = 0.08,
                spin = true,
                spin_deg = 90,
                floor_y = floorY,
            }
        )
    end

    objective:SetAttribute("MergeEggHealDenialActive", true)
    objective:SetAttribute("MergeEggHealDenialTrigger", team.healDenialLastTrigger)
    self:_publishEggHealDenial(team, now)
    self:_log("Info", "Merge Egg heal-denial field activated", {
        player = record.player.Name,
        wave = record.waveIndex,
        team = team.id,
        trigger = team.healDenialLastTrigger,
        activeSeconds = activeSeconds,
        rechargeSeconds = rechargeSeconds,
    })
    return true
end

function MergeEggPrototypeService:_triggerAllEggHealDenial(record, reason, now)
    local activated = 0
    for _, team in ipairs(record and record.teams or {}) do
        if self:_triggerEggHealDenial(record, team, reason, now) then
            activated += 1
        end
    end
    return activated
end

function MergeEggPrototypeService:_applyEggHealDenial(record, now)
    local cfg = self:_healDenialConfig()
    if cfg.enabled ~= true or not self:_isRecordActive(record) then
        return
    end
    now = tonumber(now) or os.clock()
    if now < (tonumber(record.nextHealDenialTickAt) or 0) then
        return
    end
    record.nextHealDenialTickAt = now + math.max(0.1, tonumber(cfg.tick_seconds) or 0.25)

    local radius = math.max(1, tonumber(cfg.radius) or 12)
    local radiusSquared = radius * radius
    local activeTeams = {}
    for _, team in ipairs(record.teams or {}) do
        local objective = team.eggObjective
        local active = (tonumber(team.healDenialActiveUntil) or 0) > now
            and objective
            and objective.Parent
        team.healDenialSuppressedEnemies = 0
        if active then
            activeTeams[#activeTeams + 1] = {
                team = team,
                center = objective:GetPivot().Position,
            }
        elseif objective and objective.Parent then
            objective:SetAttribute("MergeEggHealDenialActive", false)
        end
        self:_publishEggHealDenial(team, now)
    end

    local suppressed = 0
    local wallNow = os.time()
    local refresh = math.max(0.5, tonumber(cfg.suppression_refresh_seconds) or 2)
    for _, enemy in ipairs(record.enemies or {}) do
        local model = enemy.model
        if model and model.Parent and (tonumber(model:GetAttribute("HP")) or 0) > 0 then
            local position = model:GetAttribute("MoveTarget")
            if typeof(position) ~= "Vector3" then
                position = model:GetPivot().Position
            end
            local suppressingTeam
            for _, field in ipairs(activeTeams) do
                local offset =
                    Vector3.new(position.X - field.center.X, 0, position.Z - field.center.Z)
                if offset:Dot(offset) <= radiusSquared then
                    suppressingTeam = field.team
                    break
                end
            end
            if suppressingTeam then
                model:SetAttribute(
                    HealingSuppression.ATTRIBUTE,
                    HealingSuppression.extend(
                        model:GetAttribute(HealingSuppression.ATTRIBUTE),
                        wallNow,
                        refresh
                    )
                )
                model:SetAttribute("MergeEggHealDenialTeamId", suppressingTeam.id)
                suppressingTeam.healDenialSuppressedEnemies += 1
                suppressed += 1
            end
        end
    end

    record.healDenialActiveFields = #activeTeams
    record.healDenialSuppressedEnemies = suppressed
    local world = self:_worldFor(record)
    if world then
        world:SetAttribute("HealDenialFieldsActive", #activeTeams)
        world:SetAttribute("HealDenialFieldActivations", record.healDenialActivations or 0)
        world:SetAttribute("HealDenialEnemiesSuppressed", suppressed)
    end
    for _, field in ipairs(activeTeams) do
        self:_publishEggHealDenial(field.team, now)
    end
end

function MergeEggPrototypeService:_publishTeamEggSource(team)
    local folder = team and team.folder
    if not (folder and folder.Parent) then
        return
    end
    local objective = team.eggObjective
    if objective and objective.Parent then
        local maximum = math.max(1, tonumber(team.eggMaxHealth) or 1)
        local damageTaken =
            math.clamp(tonumber(objective:GetAttribute("CombatDamageTaken")) or 0, 0, maximum)
        team.eggDamageTaken = damageTaken
        team.eggHealth = math.max(0, maximum - damageTaken)
    elseif math.floor(tonumber(team.eggTier) or 0) <= 0 then
        team.eggDamageTaken = 0
        team.eggHealth = 0
    end
    local record = team.record
    local transaction = self:_deployedEggTransaction(team, record or team)
    local tier = transaction.currentTier
    local resultId = transaction.resultEggId
    local resultData = resultId
        and self._petsConfig
        and self._petsConfig.egg_sources
        and self._petsConfig.egg_sources[resultId]
    local requiredId = transaction.requiredEggId
    local requiredData = requiredId
        and self._petsConfig
        and self._petsConfig.egg_sources
        and self._petsConfig.egg_sources[requiredId]
    local requiredOwned = resultId and self:_eggInventoryCount(record, transaction.requiredTier)
        or 0
    folder:SetAttribute("MergeEggSourceId", team.eggId)
    folder:SetAttribute("MergeEggSourceName", team.eggName)
    folder:SetAttribute("MergeEggSourceTier", tier)
    folder:SetAttribute("MergeEggPrototypeHugeTier", self:_isPrototypeHugeTier(tier))
    folder:SetAttribute("MergeEggInstalledHealth", math.max(0, tonumber(team.eggHealth) or 0))
    folder:SetAttribute("MergeEggInstalledMaxHealth", math.max(1, tonumber(team.eggMaxHealth) or 1))
    folder:SetAttribute(
        "MergeEggInstalledDamageTaken",
        math.max(0, tonumber(team.eggDamageTaken) or 0)
    )
    folder:SetAttribute("MergeEggNeedsRebuild", team.needsEggRebuild == true)
    folder:SetAttribute("MergeEggDestroyedCount", team.eggsDestroyed or 0)
    local productionLockRemaining =
        math.max(0, (tonumber(team.eggProductionLockedUntil) or 0) - os.clock())
    folder:SetAttribute("MergeEggProductionLocked", productionLockRemaining > 0)
    folder:SetAttribute("MergeEggProductionLockRemaining", productionLockRemaining)
    folder:SetAttribute("MergeEggProductionDamageHits", team.eggProductionDamageHits or 0)
    folder:SetAttribute("MergeEggProductionLockouts", team.eggProductionLockouts or 0)
    folder:SetAttribute("MergeEggCanAdvance", resultId ~= nil)
    folder:SetAttribute("MergeEggCanUpgrade", resultId ~= nil) -- legacy observer compatibility
    folder:SetAttribute("MergeEggRequiredTier", transaction.requiredTier)
    folder:SetAttribute("MergeEggRequiredSourceId", requiredId)
    folder:SetAttribute("MergeEggRequiredSourceName", requiredData and requiredData.name or nil)
    folder:SetAttribute("MergeEggRequiredEggOwned", requiredOwned)
    folder:SetAttribute("MergeEggResultTier", transaction.resultTier)
    folder:SetAttribute(
        "MergeEggNextPrototypeHugeTier",
        resultId ~= nil and self:_isPrototypeHugeTier(transaction.resultTier) or false
    )
    folder:SetAttribute("MergeEggNextSourceId", resultId)
    folder:SetAttribute("MergeEggNextSourceName", resultData and resultData.name or nil)
    folder:SetAttribute("MergeEggNextEggOwned", requiredOwned) -- legacy observer compatibility
    folder:SetAttribute(
        "MergeEggDraftRolls",
        tier > 0 and self:_draftRollsForEggTier(tier, team) or 0
    )
    folder:SetAttribute(
        "MergeEggNextDraftRolls",
        resultId and self:_draftRollsForEggTier(transaction.resultTier, team) or nil
    )
    folder:SetAttribute("MergeEggDraftCandidateRolls", team.draftCandidateRolls or 0)
    folder:SetAttribute("MergeEggDraftRejectedRolls", team.draftRejectedRolls or 0)
    local pricing = self:_earthEggPricing(team)
    local nextCost = self:_eggTierCost(transaction.requiredTier, team)
    folder:SetAttribute("MergeEggEarthEggCurrency", pricing.currency)
    folder:SetAttribute("MergeEggEarthEggBaseCost", pricing.baseAmount)
    folder:SetAttribute("MergeEggEarthEggPriceGrowth", pricing.growth)
    folder:SetAttribute("MergeEggNextEarthEggCost", nextCost.amount)
    folder:SetAttribute("MergeEggNextEggCost", nextCost.amount)
    folder:SetAttribute("MergeEggNextEggCurrency", nextCost.currency)
    self:_publishEggHealDenial(team)
    self:_syncDeploymentPad(team)
end

function MergeEggPrototypeService:_interruptHatcherProduction(record, team, now)
    if
        not self:_isRecordActive(record)
        or not team
        or math.floor(tonumber(team.eggTier) or 0) <= 0
    then
        return
    end
    local seconds = math.max(
        0,
        tonumber((self._config.reinforcement or {}).damage_production_lock_seconds) or 5
    )
    if seconds <= 0 then
        return
    end
    now = tonumber(now) or os.clock()
    local wasLocked = (tonumber(team.eggProductionLockedUntil) or 0) > now
    team.eggProductionLockedUntil = now + seconds
    team.eggProductionDamageHits = (team.eggProductionDamageHits or 0) + 1
    record.eggProductionDamageHits = (record.eggProductionDamageHits or 0) + 1
    if not wasLocked then
        team.eggProductionLockouts = (team.eggProductionLockouts or 0) + 1
        record.eggProductionLockouts = (record.eggProductionLockouts or 0) + 1
    end
end

function MergeEggPrototypeService:_removeHatcherEggObjective(team)
    if not team then
        return
    end
    local objective = team.eggObjective
    team.eggObjectiveArmed = false
    team.eggObjective = nil
    team.healDenialActiveUntil = 0
    team.healDenialReadyAt = 0
    team.healDenialSuppressedEnemies = 0
    if team.healDenialRune and team.healDenialRune.Parent then
        team.healDenialRune:Destroy()
    end
    team.healDenialRune = nil
    if objective and objective.Parent then
        objective:Destroy()
    end
end

function MergeEggPrototypeService:_spawnHatcherEggObjective(record, team)
    if
        not self:_isRecordActive(record)
        or not team
        or math.floor(tonumber(team.eggTier) or 0) <= 0
        or not (team.folder and team.folder.Parent)
    then
        return false
    end

    self:_removeHatcherEggObjective(team)
    self:_ensureHatcherStands(record.world)
    local root = team.principalModel and team.principalModel:FindFirstChild("HumanoidRootPart")
    if not root then
        return false
    end

    local cfg = self._config.objective or {}
    local sizeCfg = cfg.hatcher_egg_size or {}
    local offsetCfg = cfg.hatcher_egg_offset or {}
    local maximum = self:_hatcherEggMaxHealth(record)
    local enduranceFactor = math.max(
        0.01,
        tonumber(self._combatConfig and self._combatConfig.pet_down_threshold_factor) or 10
    )
    local power = maximum / enduranceFactor
    local tier = math.max(1, math.floor(tonumber(team.eggTier) or 1))
    local colors = {
        Color3.fromRGB(115, 205, 95),
        Color3.fromRGB(115, 205, 245),
        Color3.fromRGB(245, 105, 65),
        Color3.fromRGB(235, 190, 75),
        Color3.fromRGB(120, 225, 145),
        Color3.fromRGB(155, 135, 245),
        Color3.fromRGB(255, 170, 70),
        Color3.fromRGB(255, 220, 90),
    }

    local model = cloneEggVisual(
        team.eggId,
        colors[((tier - 1) % #colors) + 1],
        math.max(1, tonumber(sizeCfg.y) or 7),
        true
    )
    if not model then
        return false
    end
    model.Name = "HatcherEggObjective"
    pcall(function()
        model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
    end)

    local powerValue = model:FindFirstChild("Power")
    if powerValue and not powerValue:IsA("NumberValue") then
        powerValue:Destroy()
        powerValue = nil
    end
    powerValue = powerValue or Instance.new("NumberValue")
    powerValue.Name = "Power"
    powerValue.Value = power
    powerValue.Parent = model
    model:SetAttribute("MergeEggObjective", true)
    model:SetAttribute("MergeEggRunId", record.runId)
    model:SetAttribute("MergeEggTeamId", team.id)
    model:SetAttribute("MergeEggSourceId", team.eggId)
    model:SetAttribute("MergeEggSourceTier", tier)
    model:SetAttribute("PetType", "merge_egg_objective")
    model:SetAttribute("PetRole", "objective")
    model:SetAttribute("BasePower", power)
    model:SetAttribute("EffectivePower", power)
    model:SetAttribute("Threat", math.max(1, tonumber(cfg.hatcher_egg_threat) or 120))
    model:SetAttribute("PrincipalLevel", self:_prototypeBaseLevel(record))
    model:SetAttribute("Level", self:_prototypeBaseLevel(record))
    model:SetAttribute("CombatTargetGroup", team.targetGroup)
    model:SetAttribute("CombatDamageTaken", 0)
    model:SetAttribute("EphemeralDownPolicy", "destroy")
    model:SetAttribute("NoPetOffense", true)
    model:SetAttribute("NoPetSupport", true)
    model:SetAttribute("NoNaturalRegen", true)
    model:SetAttribute("ObjectiveMaxHealth", maximum)
    model.Parent = team.folder
    local _, positionSlot = stationXOffset(self._config, team.config, team.id)
    local pads = record.world and record.world:FindFirstChild("MergeEggDeploymentPads")
    local deploymentPad = pads
        and pads:FindFirstChild(string.format("DeploymentPad%02d", positionSlot))
    if deploymentPad and deploymentPad:IsA("BasePart") then
        model:PivotTo(deploymentPad.CFrame)
        local box, boxSize = model:GetBoundingBox()
        local stand = self:_authoredHatcherStand(record.world, deploymentPad.Position)
        local standBox, standSize
        if stand then
            standBox, standSize = stand:GetBoundingBox()
        end
        local layout = type(self._config.station_layout) == "table" and self._config.station_layout
            or {}
        local cupInset = tonumber(layout.stand_cup_inset) or 0.25
        local standTop = standBox and (standBox.Position.Y + standSize.Y * 0.5 - cupInset)
            or (deploymentPad.Position.Y + deploymentPad.Size.Y * 0.5)
        local modelBottom = box.Position.Y - boxSize.Y * 0.5
        model:PivotTo(model:GetPivot() + Vector3.new(0, standTop - modelBottom, 0))
    else
        model:PivotTo(
            root.CFrame
                * CFrame.new(
                    tonumber(offsetCfg.x) or 0,
                    tonumber(offsetCfg.y) or 3.5,
                    tonumber(offsetCfg.z) or 3
                )
        )
    end

    team.eggObjective = model
    team.eggObjectiveArmed = true
    team.eggMaxHealth = maximum
    team.eggHealth = maximum
    team.eggDamageTaken = 0
    team.eggProductionLockedUntil = nil
    model:GetAttributeChangedSignal("CombatDamageTaken"):Connect(function()
        if self:_isRecordActive(record) and team.eggObjective == model then
            local previousDamage = math.max(0, tonumber(team.eggDamageTaken) or 0)
            local currentDamage =
                math.max(0, tonumber(model:GetAttribute("CombatDamageTaken")) or 0)
            if currentDamage > previousDamage then
                self:_interruptHatcherProduction(record, team, os.clock())
                self:_triggerEggHealDenial(record, team, "egg_damage", os.clock())
            end
            self:_publishTeamEggSource(team)
        end
    end)
    model.Destroying:Connect(function()
        local armed = team.eggObjectiveArmed == true and team.eggObjective == model
        local finalDamage =
            math.clamp(tonumber(model:GetAttribute("CombatDamageTaken")) or maximum, 0, maximum)
        team.eggObjectiveArmed = false
        if team.eggObjective == model then
            team.eggObjective = nil
        end
        team.eggDamageTaken = finalDamage
        team.eggHealth = math.max(0, maximum - finalDamage)
        if armed then
            task.defer(function()
                if not self:_isRecordActive(record) or record.terminal == true then
                    return
                end
                if self:_destroyInstalledHatcherEgg(record, team, "combat") then
                    self:_damageObjective(record)
                end
            end)
        end
    end)
    self:_publishTeamEggSource(team)
    return true
end

function MergeEggPrototypeService:_recordEggRoll(record, team, definition)
    local variant = tostring(definition.variant or "basic")
    record.eggRolls = (record.eggRolls or 0) + 1
    record.eggGoldenRolls = (record.eggGoldenRolls or 0) + (variant == "golden" and 1 or 0)
    record.eggRainbowRolls = (record.eggRainbowRolls or 0) + (variant == "rainbow" and 1 or 0)
    record.eggHugeRolls = (record.eggHugeRolls or 0) + (definition.naturalHuge == true and 1 or 0)
    record.prototypeHugeRolls = (record.prototypeHugeRolls or 0)
        + (definition.prototypeHuge == true and 1 or 0)
    if team then
        team.eggRolls = (team.eggRolls or 0) + 1
        team.eggGoldenRolls = (team.eggGoldenRolls or 0) + (variant == "golden" and 1 or 0)
        team.eggRainbowRolls = (team.eggRainbowRolls or 0) + (variant == "rainbow" and 1 or 0)
        team.eggHugeRolls = (team.eggHugeRolls or 0) + (definition.naturalHuge == true and 1 or 0)
        team.prototypeHugeRolls = (team.prototypeHugeRolls or 0)
            + (definition.prototypeHuge == true and 1 or 0)
    end
end

function MergeEggPrototypeService:_publishTeamSlot(team, slot, definition)
    local folder = team and team.folder
    if not (folder and folder.Parent and definition) then
        return
    end
    folder:SetAttribute("MergeEggSlotPet" .. slot, definition.pet)
    folder:SetAttribute("MergeEggSlotVariant" .. slot, definition.variant or "basic")
    folder:SetAttribute("MergeEggSlotHuge" .. slot, definition.huge == true)
    folder:SetAttribute("MergeEggSlotPrototypeHuge" .. slot, definition.prototypeHuge == true)
end

function MergeEggPrototypeService:_balanceExperiment(context)
    local teamCfg = self._config.team or {}
    local experiments = teamCfg.balance_experiments or {}
    local modes = experiments.modes or {}
    local requested = context and context.balanceExperiment
    local id = tostring(requested or experiments.default or "positions")
    local mode = modes[id]
    if type(mode) ~= "table" then
        id = tostring(experiments.default or "positions")
        mode = modes[id] or {}
    end
    return id, mode
end

function MergeEggPrototypeService:_positionsForEggTier(tier, context)
    local _, experiment = self:_balanceExperiment(context)
    if experiment.stage_positions == true then
        local _, stage = self:_progressionStage(context)
        local byTier = stage.team_positions_by_egg_tier or {}
        local index = math.max(1, math.floor(tonumber(tier) or 1))
        return math.max(
            1,
            math.floor(tonumber(byTier[index]) or tonumber(stage.team_positions) or 3)
        )
    end
    local configured = experiment.positions_by_egg_tier
        or (self._config.team or {}).positions_by_egg_tier
        or {}
    local index = math.max(1, math.floor(tonumber(tier) or 1))
    local fallback = index + 2
    return math.max(1, math.floor(tonumber(configured[index]) or fallback))
end

function MergeEggPrototypeService:_originPowerForEggTier(tier, context)
    local _, experiment = self:_balanceExperiment(context)
    local perTier = math.max(0, tonumber(experiment.origin_power_per_tier) or 0)
    local completedAdvances = math.max(0, math.floor(tonumber(tier) or 1) - 1)
    return 1 + completedAdvances * perTier
end

function MergeEggPrototypeService:_applyTeamEggTierModifiers(team, tier)
    local multiplier = self:_originPowerForEggTier(tier, team)
    team.originPowerMultiplier = multiplier
    if team.folder and team.folder.Parent then
        team.folder:SetAttribute("MergeEggOriginPowerMultiplier", multiplier)
    end
    for _, model in ipairs(team.units or {}) do
        if model and model.Parent then
            model:SetAttribute("OriginProgressionMultiplier", multiplier)
        end
    end
end

function MergeEggPrototypeService:_spawnInitialTeam(record, team, source, tier)
    if team.initialized == true then
        return true, 0
    end
    tier = math.max(1, math.floor(tonumber(tier) or 1))
    local count = self:_positionsForEggTier(tier, record)
    local squad = self:_rollPrototypeSquad(record, team, count, source, tier)
    local root = team.principalModel and team.principalModel:FindFirstChild("HumanoidRootPart")
    if not (squad and root and team.folder and team.folder.Parent) then
        return false, "initial_team_unavailable"
    end
    local spawned, models =
        self._npcPrincipalService:SpawnGhostSquad(team.folder, squad, root.CFrame, {
            attributes = {
                MergeEggUnit = true,
                MergeEggRunId = record.runId,
                MergeEggTeamId = team.id,
                CombatTargetGroup = team.targetGroup,
                CombatCadenceMultiplier = combatCadenceMultiplier(self._config),
                EphemeralDownPolicy = "destroy",
                PrincipalLevel = self:_prototypeBaseLevel(record),
                Level = self:_prototypeBaseLevel(record),
                OriginProgressionMultiplier = self:_originPowerForEggTier(tier, record),
            },
        })
    if spawned ~= count then
        for _, model in ipairs(models or {}) do
            model:Destroy()
        end
        return false, "unit_assets_missing"
    end

    team.config.squad = squad
    team.expectedPets = count
    team.folder:SetAttribute("MergeEggExpectedPets", count)
    team.initialized = true
    for slot, model in ipairs(models) do
        team.units[#team.units + 1] = model
        record.units[#record.units + 1] = model
        self:_recordEggRoll(record, team, squad[slot])
        self:_publishTeamSlot(team, slot, squad[slot])
    end
    self:_ensurePlayerEscort(record)
    self:_applyTeamEggTierModifiers(team, tier)
    return true, spawned
end

function MergeEggPrototypeService:_expandTeamForEggTier(record, team, source, tier)
    local current = math.max(0, math.floor(tonumber(team.expectedPets) or 0))
    local desired = self:_positionsForEggTier(tier, team)
    if desired <= current then
        return true, 0
    end
    local added = desired - current
    local definitions = self:_rollPrototypeSquad(record, team, added, source, tier)
    local root = team.principalModel and team.principalModel:FindFirstChild("HumanoidRootPart")
    if not (definitions and root and team.folder and team.folder.Parent) then
        return false, "team_expansion_unavailable"
    end
    local spawned, models =
        self._npcPrincipalService:SpawnGhostSquad(team.folder, definitions, root.CFrame, {
            attributes = {
                MergeEggUnit = true,
                MergeEggRunId = record.runId,
                MergeEggTeamId = team.id,
                CombatTargetGroup = team.targetGroup,
                CombatCadenceMultiplier = combatCadenceMultiplier(self._config),
                EphemeralDownPolicy = "destroy",
                PrincipalLevel = self:_prototypeBaseLevel(record),
                Level = self:_prototypeBaseLevel(record),
                OriginProgressionMultiplier = self:_originPowerForEggTier(tier, team),
            },
            positionOffset = current,
        })
    if spawned ~= added then
        for _, model in ipairs(models or {}) do
            model:Destroy()
        end
        return false, "unit_assets_missing"
    end

    local squad = team.config.squad or {}
    team.config.squad = squad
    for offset, model in ipairs(models) do
        local slot = current + offset
        local definition = definitions[offset]
        squad[slot] = definition
        team.units[#team.units + 1] = model
        record.units[#record.units + 1] = model
        self:_recordEggRoll(record, team, definition)
        self:_publishTeamSlot(team, slot, definition)
    end
    team.expectedPets = desired
    team.folder:SetAttribute("MergeEggExpectedPets", desired)
    return true, added
end

function MergeEggPrototypeService:_log(level, message, data)
    if self._logger and self._logger[level] then
        self._logger[level](self._logger, message, data)
    end
end

function MergeEggPrototypeService:_prototypeBaseLevel(record)
    local fallback = tonumber((self._config.principal or {}).level) or 1
    if record and record.baseCombatLevel then
        return math.max(1, math.floor(tonumber(record.baseCombatLevel) or fallback))
    end
    return playerCombatLevel(record and record.player, fallback)
end

function MergeEggPrototypeService:_ensureBreachLine(world)
    local worldCfg = self._config.world or {}
    local name = tostring(worldCfg.breach_line or "BreachLine")
    local existing = findNamedPart(world, name)
    if existing then
        return existing
    end
    local bulwark = findNamedPart(world, worldCfg.bulwark_line or "BulwarkLine")
    local finish = findNamedPart(world, worldCfg.enemy_finish_line or "EnemyFinishLine")
    local hatcher = findNamedPart(world, worldCfg.hatcher_spawn or "HatcherSpawn")
    if not (bulwark and finish and hatcher) then
        return nil
    end
    local direction = Vector3.new(
        finish.Position.X - bulwark.Position.X,
        0,
        finish.Position.Z - bulwark.Position.Z
    )
    if direction.Magnitude <= 0 then
        return nil
    end
    direction = direction.Unit
    local position = hatcher.Position - direction * 13
    position = Vector3.new(position.X, bulwark.Position.Y + 0.01, position.Z)

    local line = Instance.new("Part")
    line.Name = name
    line.Anchored = true
    line.CanCollide = false
    line.CanTouch = false
    line.CanQuery = true
    line.Size = Vector3.new(bulwark.Size.X, 0.25, 2)
    line.CFrame = CFrame.new(position) * bulwark.CFrame.Rotation
    line.Color = Color3.fromRGB(197, 82, 72)
    line.Material = Enum.Material.Neon
    line.Transparency = 0.05
    line.TopSurface = Enum.SurfaceType.Smooth
    line.BottomSurface = Enum.SurfaceType.Smooth
    line:SetAttribute("MergeEggRuntimeBreachLine", true)
    line.Parent = world

    local labelHost = Instance.new("Part")
    labelHost.Name = "BreachGroundLabel"
    labelHost.Anchored = true
    labelHost.CanCollide = false
    labelHost.CanTouch = false
    labelHost.CanQuery = false
    labelHost.Size = Vector3.new(math.min(62, bulwark.Size.X), 0.08, 8)
    labelHost.CFrame = CFrame.new(position - direction * 6) * bulwark.CFrame.Rotation
    labelHost.Transparency = 1
    labelHost.Parent = world

    local surface = Instance.new("SurfaceGui")
    surface.Name = "BreachGroundSurface"
    surface.Face = Enum.NormalId.Top
    surface.CanvasSize = Vector2.new(160, 1240)
    surface.LightInfluence = 0
    surface.ZOffset = 1
    surface.Parent = labelHost

    local text = Instance.new("TextLabel")
    text.AnchorPoint = Vector2.new(0.5, 0.5)
    text.Position = UDim2.fromScale(0.5, 0.5)
    text.Size = UDim2.fromOffset(1180, 150)
    text.Rotation = -90
    text.BackgroundTransparency = 1
    text.Font = Enum.Font.GothamBold
    text.Text = "BREACH  •  EGGS EXPOSED"
    text.TextColor3 = line.Color
    text.TextStrokeColor3 = Color3.fromRGB(24, 30, 43)
    text.TextStrokeTransparency = 0.15
    text.TextSize = 75
    text.Parent = surface
    return line
end

-- Keep the raised play field physically readable. The player entrance remains open to the public
-- mall, but both long edges and the enemy end receive tall invisible collision walls. Currency
-- drops use these same ArenaBounds through DropService's reflected pop path, so the visual bounce
-- and the character boundary agree on one rectangle.
function MergeEggPrototypeService:_ensureContainmentWalls(world)
    local worldCfg = self._config.world or {}
    local cfg = type(worldCfg.containment_walls) == "table" and worldCfg.containment_walls or {}
    local existing = world and world:FindFirstChild("MergeEggContainmentWalls")
    if cfg.enabled == false then
        if existing then
            existing:Destroy()
        end
        return nil
    end

    local bounds = findNamedPart(world, "ArenaBounds")
    local floor = findNamedPart(world, "LandStrip")
    local playerSpawn = findNamedPart(world, worldCfg.player_spawn or "PlayerSpawn")
    local enemySpawn = findNamedPart(world, worldCfg.enemy_spawn_area or "EnemySpawnArea")
    if not (bounds and floor and playerSpawn and enemySpawn) then
        return nil
    end

    if existing and not existing:IsA("Model") then
        existing:Destroy()
        existing = nil
    end
    local walls = existing or Instance.new("Model")
    walls.Name = "MergeEggContainmentWalls"
    walls.Parent = world
    walls:SetAttribute("MergeEggContainmentWalls", true)

    local height = math.max(16, tonumber(cfg.height) or 64)
    local thickness = math.max(1, tonumber(cfg.thickness) or 2)
    local floorTop = floor.Position.Y + floor.Size.Y * 0.5
    local localEnemy = bounds.CFrame:PointToObjectSpace(enemySpawn.Position)
    local laneUsesX = math.abs(localEnemy.X) >= math.abs(localEnemy.Z)
    local enemySign = laneUsesX and (localEnemy.X >= 0 and 1 or -1)
        or (localEnemy.Z >= 0 and 1 or -1)

    local specs = {}
    if laneUsesX then
        specs = {
            {
                name = "SideNegative",
                size = Vector3.new(bounds.Size.X + thickness * 2, height, thickness),
                offset = Vector3.new(0, 0, -(bounds.Size.Z + thickness) * 0.5),
            },
            {
                name = "SidePositive",
                size = Vector3.new(bounds.Size.X + thickness * 2, height, thickness),
                offset = Vector3.new(0, 0, (bounds.Size.Z + thickness) * 0.5),
            },
            {
                name = "EnemyEnd",
                size = Vector3.new(thickness, height, bounds.Size.Z + thickness * 2),
                offset = Vector3.new(enemySign * (bounds.Size.X + thickness) * 0.5, 0, 0),
            },
        }
    else
        specs = {
            {
                name = "SideNegative",
                size = Vector3.new(thickness, height, bounds.Size.Z + thickness * 2),
                offset = Vector3.new(-(bounds.Size.X + thickness) * 0.5, 0, 0),
            },
            {
                name = "SidePositive",
                size = Vector3.new(thickness, height, bounds.Size.Z + thickness * 2),
                offset = Vector3.new((bounds.Size.X + thickness) * 0.5, 0, 0),
            },
            {
                name = "EnemyEnd",
                size = Vector3.new(bounds.Size.X + thickness * 2, height, thickness),
                offset = Vector3.new(0, 0, enemySign * (bounds.Size.Z + thickness) * 0.5),
            },
        }
    end
    if cfg.close_player_entrance == true then
        local enemyEnd = specs[#specs]
        specs[#specs + 1] = {
            name = "PlayerEnd",
            size = enemyEnd.size,
            offset = -enemyEnd.offset,
        }
    end

    local localY = bounds.CFrame:PointToObjectSpace(Vector3.new(0, floorTop + height * 0.5, 0)).Y
    for _, spec in ipairs(specs) do
        local wall = walls:FindFirstChild(spec.name)
        if wall and not wall:IsA("BasePart") then
            wall:Destroy()
            wall = nil
        end
        if not wall then
            wall = Instance.new("Part")
            wall.Name = spec.name
            wall.Parent = walls
        end
        wall.Anchored = true
        wall.CanCollide = true
        wall.CanTouch = false
        wall.CanQuery = false
        wall.CastShadow = false
        wall.Transparency = 1
        wall.Size = spec.size
        wall.CFrame = bounds.CFrame * CFrame.new(spec.offset.X, localY, spec.offset.Z)
        wall:SetAttribute("MergeEggBayBoundary", true)
        wall:SetAttribute("MergeEggBoundaryRole", spec.name)
    end
    for _, child in ipairs(walls:GetChildren()) do
        local keep = false
        for _, spec in ipairs(specs) do
            if child.Name == spec.name then
                keep = true
                break
            end
        end
        if not keep then
            child:Destroy()
        end
    end
    return walls
end

function MergeEggPrototypeService:_findControlWall(world)
    local gen = Workspace:FindFirstChild("GeneratedMap_MergeEggVoxel")
    local walls = gen and gen:FindFirstChild("PlayFieldWalls")
    if not (world and walls) then
        return nil
    end
    local side = world:GetAttribute("MergeEggBaySide")
    local col = tonumber(world:GetAttribute("MergeEggBayColumn"))
    if type(side) ~= "string" or not col then
        return nil
    end
    local prefix = side == "hell" and "Hell" or "Heaven"
    -- Right-hand wall when facing the spawn gate: Heaven faces +X (north = WallBoard),
    -- Hell faces −X (south = WallScore).
    local wallName = side == "hell" and "WallScore" or "WallBoard"
    return walls:FindFirstChild(string.format("%s_%02d_%s", prefix, col, wallName))
end

-- The dedicated place keeps its polished floor geometry in GeneratedMap_MergeEggVoxel while the
-- portable bay model supplies gameplay hooks. Resolve the matching authored artifact by bay id so
-- runtime interaction targets sit on the visible map instead of building a second floating copy.
function MergeEggPrototypeService:_authoredBayArtifact(world, folderName, suffix)
    local map = Workspace:FindFirstChild("GeneratedMap_MergeEggVoxel")
    local folder = map and map:FindFirstChild(folderName)
    if not (world and folder) then
        return nil
    end
    local side = tostring(world:GetAttribute("MergeEggBaySide") or "")
    local column = tonumber(world:GetAttribute("MergeEggBayColumn"))
    if (side ~= "heaven" and side ~= "hell") or not column then
        return nil
    end
    local prefix = side == "hell" and "Hell" or "Heaven"
    return folder:FindFirstChild(string.format("%s_%02d_%s", prefix, column, suffix))
end

function MergeEggPrototypeService:_authoredHatcherPad(world, slot, expectedPosition)
    local stations = self:_authoredBayArtifact(world, "HatcherStations", "Hatchers")
    if not stations then
        return nil
    end
    local best
    local bestDistance = math.huge
    for _, candidate in ipairs(stations:GetDescendants()) do
        if candidate:IsA("BasePart") and string.match(candidate.Name, "^Pad_%d+$") then
            local distance = expectedPosition and (candidate.Position - expectedPosition).Magnitude
                or math.abs((tonumber(string.match(candidate.Name, "%d+")) or 0) - slot)
            if distance < bestDistance then
                best = candidate
                bestDistance = distance
            end
        end
    end
    return best
end

function MergeEggPrototypeService:_authoredHatcherStand(world, padPosition)
    local stations = self:_authoredBayArtifact(world, "HatcherStations", "Hatchers")
    if not (stations and padPosition) then
        return nil
    end
    local best
    local bestDistance = 4
    for _, candidate in ipairs(stations:GetChildren()) do
        if candidate:IsA("Model") and string.match(candidate.Name, "^EggStand_") then
            local distance = (candidate:GetPivot().Position - padPosition).Magnitude
            if distance < bestDistance then
                best = candidate
                bestDistance = distance
            end
        end
    end
    return best
end

function MergeEggPrototypeService:_stationPadCFrame(world, slot, spawn)
    local layout = type(self._config.station_layout) == "table" and self._config.station_layout
        or {}
    local padCfg = type(layout.deployment_pads) == "table" and layout.deployment_pads or {}
    local stationX = stationXOffset(self._config, { position_slot = slot }, slot)
    local expected = spawn.CFrame * CFrame.new(stationX, 0.06, tonumber(padCfg.egg_offset) or 3)
    local authored = self:_authoredHatcherPad(world, slot, expected.Position)
    if authored then
        return authored.CFrame * CFrame.new(0, 0.07, 0), authored
    end
    return expected, nil
end

function MergeEggPrototypeService:_ensureHatcherStands(world)
    local stations = self:_authoredBayArtifact(world, "HatcherStations", "Hatchers")
    local pads = world and world:FindFirstChild("MergeEggDeploymentPads")
    if not (stations and pads) then
        return
    end
    local template
    for _, candidate in ipairs(stations:GetChildren()) do
        if candidate:IsA("Model") and string.match(candidate.Name, "^EggStand_") then
            template = candidate
            break
        end
    end
    if not template then
        return
    end
    for _, pad in ipairs(pads:GetChildren()) do
        if pad:IsA("BasePart") and pad:GetAttribute("MergeEggDeploymentAvailable") == true then
            if not self:_authoredHatcherStand(world, pad.Position) then
                local slot =
                    math.max(0, math.floor(tonumber(pad:GetAttribute("MergeEggPositionSlot")) or 0))
                local clone = template:Clone()
                clone.Name = string.format("EggStand_%02d", slot)
                clone:SetAttribute("MergeEggPositionSlot", slot)
                clone:SetAttribute("MergeEggRuntimeStand", true)
                clone.Parent = stations
                local box, size = clone:GetBoundingBox()
                local bottom = box.Position.Y - size.Y * 0.5
                local padTop = pad.Position.Y + pad.Size.Y * 0.5
                local pivot = clone:GetPivot()
                clone:PivotTo(
                    CFrame.new(pad.Position.X, pivot.Position.Y + (padTop - bottom), pad.Position.Z)
                        * (pivot - pivot.Position)
                )
            end
        end
    end
end

function MergeEggPrototypeService:_edgeTowerConfig()
    local team = type(self._config.team) == "table" and self._config.team or {}
    local towers = type(team.edge_towers) == "table" and team.edge_towers or {}
    local shot = type(towers.shot) == "table" and towers.shot
        or (type(towers.spear) == "table" and towers.spear or {})
    return towers, shot
end

function MergeEggPrototypeService:_edgeBulwarkConfig()
    local team = type(self._config.team) == "table" and self._config.team or {}
    return type(team.edge_bulwarks) == "table" and team.edge_bulwarks or {}
end

function MergeEggPrototypeService:_rebirthScalingMultiplier(record, system, axis)
    return MergeEggRebirth.scalingMultiplier(
        self._config.rebirth,
        record and record.rebirthCount,
        system,
        axis
    )
end

function MergeEggPrototypeService:_bulwarkCombatEffect(record, family, tier)
    local effect = MergeBulwarkProgression.combatEffect(family, tier, self:_edgeBulwarkConfig())
    return MergeBulwarkProgression.scaleCombatEffect(effect, {
        power = self:_rebirthScalingMultiplier(record, "bulwarks", "power"),
        radius = self:_rebirthScalingMultiplier(record, "bulwarks", "radius"),
        cadence = self:_rebirthScalingMultiplier(record, "bulwarks", "cadence"),
        duration = self:_rebirthScalingMultiplier(record, "bulwarks", "duration"),
        capacity = self:_rebirthScalingMultiplier(record, "bulwarks", "capacity"),
        control = self:_rebirthScalingMultiplier(record, "bulwarks", "control"),
    })
end

function MergeEggPrototypeService:_normalizeBulwarkState(source)
    return MergeBulwarkPersist.read(source, self:_edgeBulwarkConfig())
end

function MergeEggPrototypeService:_writeBulwarkState(record, progress, state)
    MergeBulwarkPersist.write(record, progress, state)
end

function MergeEggPrototypeService:_liveMergeDefense(player)
    local data = self._dataService and self._dataService:GetData(player)
    if not data then
        return nil
    end
    data.GameData = type(data.GameData) == "table" and data.GameData or {}
    local progress = data.GameData.MergeDefense
    if type(progress) ~= "table" then
        progress = MergeEggPlayerCombat.normalizeOnboarding(nil)
        data.GameData.MergeDefense = progress
    end
    return progress
end

function MergeEggPrototypeService:_normalizeTowerState(source)
    return MergeCannonPersist.read(source, self:_edgeTowerConfig())
end

function MergeEggPrototypeService:_writeTowerState(record, progress, state)
    MergeCannonPersist.write(record, progress, state)
end

function MergeEggPrototypeService:_hydrateTowerState(record, progress)
    -- Persist slots are the truth. Do not wipe a free catalog Install just
    -- because spent is still 0, and do not read wave/egg fields.
    local state = MergeCannonPersist.read(progress or record, self:_edgeTowerConfig())
    MergeCannonPersist.write(record, progress, state)
    return state
end

function MergeEggPrototypeService:_bulwarkSlotSuffix(slot)
    return MergeBulwarkSlots.attrSuffix(slot)
end

function MergeEggPrototypeService:_towerFolder(world, name)
    if not world then
        return nil
    end
    local folder = world:FindFirstChild(name)
    if folder and not folder:IsA("Folder") then
        folder:Destroy()
        folder = nil
    end
    if not folder then
        folder = Instance.new("Folder")
        folder.Name = name
        folder.Parent = world
    end
    return folder
end

function MergeEggPrototypeService:_clearTowerShots(record)
    local world = record and record.world
    for _, name in ipairs({ "MergeEggTowerShots", "MergeEggTowerSpears" }) do
        local folder = world and world:FindFirstChild(name)
        if folder then
            folder:Destroy()
        end
    end
    if record then
        record.towerShots = {}
    end
    local remaining = {}
    for _, flight in ipairs(self._towerShots or {}) do
        if
            flight.part
            and flight.part.Parent
            and (not world or not flight.part:IsDescendantOf(world))
        then
            remaining[#remaining + 1] = flight
        elseif
            flight.part
            and flight.part.Parent
            and world
            and flight.part:IsDescendantOf(world)
        then
            flight.part:Destroy()
        end
    end
    self._towerShots = remaining
end

function MergeEggPrototypeService:_worldForCannon(cannon)
    local folder = cannon and cannon.Parent
    return folder and folder.Parent or nil
end

local function flattenTowerLook(cframe)
    local look = Vector3.new(cframe.LookVector.X, 0, cframe.LookVector.Z)
    if look.Magnitude < 0.001 then
        look = Vector3.new(1, 0, 0)
    else
        look = look.Unit
    end
    return CFrame.lookAt(cframe.Position, cframe.Position + look)
end

function MergeEggPrototypeService:_instanceWorldPosition(inst)
    if not inst then
        return nil
    end
    if inst:IsA("BasePart") then
        return inst.Position
    end
    if inst:IsA("Model") then
        return inst:GetPivot().Position
    end
    local part = inst:FindFirstChildWhichIsA("BasePart", true)
    return part and part.Position or nil
end

-- Dedicated Merge bays use OuterSpawnGate. EnemyPortalVisual only exists on the
-- older authored prototype world and is absent here, so a name-only lookup
-- leaves range at 90 and the cannons wait until pets walk into the last third.
function MergeEggPrototypeService:_towerGatePosition(world)
    if not world then
        return nil
    end
    local name = (self._config.world or {}).enemy_portal_visual or "EnemyPortalVisual"
    local portal = world:FindFirstChild(tostring(name), true)
    local position = self:_instanceWorldPosition(portal)
    if position then
        return position
    end
    local gate = world:FindFirstChild("OuterSpawnGate", true)
    position =
        self:_instanceWorldPosition(gate and (gate:FindFirstChild("GateAnchor", true) or gate))
    if position then
        return position
    end
    local bayId = world:GetAttribute("MergeEggBayId")
    if type(bayId) == "string" then
        local map = Workspace:FindFirstChild("GeneratedMap_MergeEggVoxel")
        local gates = map
            and (
                string.find(bayId, "hell", 1, true) and map:FindFirstChild("HellGates")
                or map:FindFirstChild("HeavenGates")
            )
        if gates then
            for _, child in ipairs(gates:GetChildren()) do
                if child:GetAttribute("MergeEggBayId") == bayId then
                    position = self:_instanceWorldPosition(child)
                    if position then
                        return position
                    end
                end
            end
        end
    end
    return nil
end

function MergeEggPrototypeService:_towerGateLook(world, origin)
    local portalPosition = self:_towerGatePosition(world)
    if portalPosition and origin then
        local planar = Vector3.new(portalPosition.X - origin.X, 0, portalPosition.Z - origin.Z)
        if planar.Magnitude > 0.05 then
            return planar.Unit
        end
    end
    return self:_towerLook(world, nil)
end

function MergeEggPrototypeService:_towerCombatLine(world, lineId)
    local worldCfg = type(self._config.world) == "table" and self._config.world or {}
    local wanted = string.lower(tostring(lineId or "breach"))
    if wanted == "mid" then
        local bulwark = findNamedPart(world, worldCfg.bulwark_line or "BulwarkLine")
        local breach = findNamedPart(world, worldCfg.breach_line or "BreachLine")
        if bulwark and breach then
            local x, z = MergeTowerBallistics.midpoint(
                bulwark.Position.X,
                bulwark.Position.Z,
                breach.Position.X,
                breach.Position.Z
            )
            return Vector3.new(x, (bulwark.Position.Y + breach.Position.Y) * 0.5, z)
        end
        wanted = "bulwark"
    end
    if wanted == "bulwark" then
        local line = findNamedPart(world, worldCfg.bulwark_line or "BulwarkLine")
        return line and line.Position or nil
    end
    local line = findNamedPart(world, worldCfg.breach_line or "BreachLine")
    return line and line.Position or nil
end

function MergeEggPrototypeService:_towerTowardGate(world, origin)
    local breach = self:_towerCombatLine(world, "breach")
    local gate = self:_towerGatePosition(world)
    if breach and gate then
        local planar = Vector3.new(gate.X - breach.X, 0, gate.Z - breach.Z)
        if planar.Magnitude > 0.05 then
            return planar.Unit
        end
    end
    local look = self:_towerGateLook(world, origin or breach)
    if look and look.Magnitude > 0.001 then
        return Vector3.new(look.X, 0, look.Z).Unit
    end
    return nil
end

function MergeEggPrototypeService:_towerLandingSpec(role)
    local _, shot = self:_edgeTowerConfig()
    local landing = type(shot.landing) == "table" and shot.landing or {}
    local spec = landing[string.lower(tostring(role or ""))]
    return type(spec) == "table" and spec or nil, shot
end

function MergeEggPrototypeService:_towerFloorY(world)
    local floor = findNamedPart(world, "LandStrip")
    if floor then
        return floor.Position.Y + floor.Size.Y * 0.5
    end
    return nil
end

function MergeEggPrototypeService:_towerGroundPoint(world, position)
    if typeof(position) ~= "Vector3" then
        return nil
    end
    local floorY = self:_towerFloorY(world)
    if floorY == nil then
        return Vector3.new(position.X, position.Y, position.Z)
    end
    return Vector3.new(position.X, floorY, position.Z)
end

function MergeEggPrototypeService:_towerLandsOnGround(role)
    local spec, shot = self:_towerLandingSpec(role)
    local landAt = spec and spec.land_at or (shot and shot.land_at)
    if landAt == "body" then
        return false
    end
    if spec and (spec.cast or spec.visual) then
        return true
    end
    return tostring(landAt or "") == "ground"
end

function MergeEggPrototypeService:_towerImpactKind(role)
    local spec, shot = self:_towerLandingSpec(role)
    local listed = spec and spec.impact or (shot and shot.ability_impact)
    if spec and (spec.cast or spec.visual) then
        return string.lower(tostring(listed or "bloom"))
    end
    return string.lower(tostring(listed or "linger"))
end

function MergeEggPrototypeService:_towerTierIndex(cannon)
    return math.max(1, math.floor(tonumber(cannon and cannon:GetAttribute("MergeTowerTier")) or 1))
end

function MergeEggPrototypeService:_towerListedNumber(list, tier, fallback)
    local value = type(list) == "table" and tonumber(list[tier]) or nil
    if value == nil then
        value = tonumber(fallback)
    end
    return value
end

function MergeEggPrototypeService:_towerFireInterval(record, cannon, shot)
    shot = type(shot) == "table" and shot or {}
    local role = string.lower(tostring(cannon and cannon:GetAttribute("MergeTowerRole") or ""))
    local spec = type(shot.landing) == "table" and shot.landing[role] or nil
    local interval =
        self:_towerListedNumber(spec and spec.interval, self:_towerTierIndex(cannon), shot.interval)
    local cadenceMultiplier = self:_rebirthScalingMultiplier(record, "cannons", "cadence")
    assert(cadenceMultiplier > 0, "Rebirth cannon cadence multiplier must be greater than zero")
    return requiredConfigNumber(interval, "team.edge_towers.shot interval") / cadenceMultiplier
end

function MergeEggPrototypeService:_towerHealMagnitude(record, cannon)
    local spec, _ = self:_towerLandingSpec("heal")
    local listed =
        self:_towerListedNumber(spec and spec.magnitude, self:_towerTierIndex(cannon), nil)
    return requiredConfigNumber(listed, "team.edge_towers.shot.landing.heal.magnitude")
        * self:_rebirthScalingMultiplier(record, "cannons", "power")
end

function MergeEggPrototypeService:_towerRageRadius(record, cannon)
    local spec = self:_towerLandingSpec("rage")
    local listed = self:_towerListedNumber(spec and spec.radius, self:_towerTierIndex(cannon), nil)
    return requiredConfigNumber(listed, "team.edge_towers.shot.landing.rage.radius")
        * self:_rebirthScalingMultiplier(record, "cannons", "radius")
end

function MergeEggPrototypeService:_towerLandingNumber(cannon, role, key)
    local spec = self:_towerLandingSpec(role)
    local listed = self:_towerListedNumber(spec and spec[key], self:_towerTierIndex(cannon), nil)
    return requiredConfigNumber(
        listed,
        "team.edge_towers.shot.landing." .. tostring(role) .. "." .. tostring(key)
    )
end

function MergeEggPrototypeService:_towerEnemiesInRadius(record, center, radius)
    local found = {}
    if typeof(center) ~= "Vector3" then
        return found
    end
    radius = tonumber(radius)
    if radius == nil then
        return found
    end
    radius = math.max(0, radius)
    for _, enemy in ipairs(record and record.enemies or {}) do
        local model = enemy.model
        if model and model.Parent and (tonumber(model:GetAttribute("HP")) or 0) > 0 then
            local position = self:_enemyLivePosition(enemy)
            if typeof(position) == "Vector3" then
                local offset = Vector3.new(position.X - center.X, 0, position.Z - center.Z)
                if offset.Magnitude <= radius then
                    found[#found + 1] = {
                        model = model,
                        position = position,
                    }
                end
            end
        end
    end
    return found
end

function MergeEggPrototypeService:_towerRoleColor(role)
    return self:_towerShotColor(nil, role)
end

function MergeEggPrototypeService:_towerPetReady(pet)
    if not (pet and pet:IsA("Model")) or pet:GetAttribute("MergeEggObjective") == true then
        return false
    end
    if pet:GetAttribute("CombatDowned") == true then
        return false
    end
    local hp = tonumber(pet:GetAttribute("HP"))
    if hp and hp <= 0 then
        return false
    end
    return true
end

function MergeEggPrototypeService:_towerLiveEnemyById(record, targetId)
    targetId = tonumber(targetId)
    if not targetId then
        return nil
    end
    for _, enemy in ipairs(record and record.enemies or {}) do
        if tonumber(enemy.targetId) == targetId then
            local model = enemy.model
            if model and model.Parent and (tonumber(model:GetAttribute("HP")) or 0) > 0 then
                return enemy
            end
        end
    end
    return nil
end

-- Same fight signals `_teamEngagedWithEnemy` already uses: this pet is
-- swinging at a live enemy, or a live enemy has this pet as AggroTargetRef.
function MergeEggPrototypeService:_towerPetInCombat(record, pet)
    if not self:_towerPetReady(pet) then
        return false
    end
    local targetType = pet:FindFirstChild("TargetType")
    local targetId = pet:FindFirstChild("TargetID")
    if
        targetType
        and tostring(targetType.Value) == "Enemy"
        and self:_towerLiveEnemyById(record, targetId and targetId.Value)
    then
        return true
    end
    for _, enemy in ipairs(record and record.enemies or {}) do
        local model = enemy.model
        if model and model.Parent and (tonumber(model:GetAttribute("HP")) or 0) > 0 then
            local targetRef = model:FindFirstChild("AggroTargetRef")
            local target = targetRef and targetRef.Value
            if target == pet or (target and target:IsDescendantOf(pet)) then
                return true
            end
        end
    end
    return false
end

function MergeEggPrototypeService:_towerRoleFireLine(role)
    local _, shot = self:_edgeTowerConfig()
    local id = string.lower(tostring(role or ""))
    if id == "heal" then
        -- Default is the hard breach floor. "bulwark" / "mid" stay available to tune.
        return string.lower(tostring(shot.heal_fire_line or "breach"))
    end
    if id == "rage" then
        return string.lower(tostring(shot.rage_fire_line or "breach"))
    end
    return string.lower(tostring(shot.fire_line or "breach"))
end

-- Hard rule: never fire at a point on the egg/hatcher side of BreachLine.
-- Missing plane data must not silence the cannon.
function MergeEggPrototypeService:_towerAllowsFireAt(world, position, role)
    if typeof(position) ~= "Vector3" then
        return false
    end
    if not world then
        return true
    end
    local _, shot = self:_edgeTowerConfig()
    local epsilon =
        requiredConfigNumber(shot.fire_line_epsilon, "team.edge_towers.shot.fire_line_epsilon")
    local towardGate = self:_towerTowardGate(world, position)
    if not towardGate then
        return true
    end
    local breach = self:_towerCombatLine(world, "breach")
    if
        breach
        and not MergeTowerBallistics.onGateSide(
            position.X,
            position.Z,
            breach.X,
            breach.Z,
            towardGate.X,
            towardGate.Z,
            epsilon
        )
    then
        return false
    end
    local roleLine = self:_towerRoleFireLine(role)
    if roleLine ~= "" and roleLine ~= "breach" then
        local plane = self:_towerCombatLine(world, roleLine)
        if
            plane
            and not MergeTowerBallistics.onGateSide(
                position.X,
                position.Z,
                plane.X,
                plane.Z,
                towardGate.X,
                towardGate.Z,
                epsilon
            )
        then
            return false
        end
    end
    return true
end

function MergeEggPrototypeService:_towerPetLivePosition(pet)
    if not (pet and pet.Parent) then
        return nil
    end
    local follow = self._petFollowService
    if follow and follow.GetReportedPosition then
        local reported = follow:GetReportedPosition(pet)
        if typeof(reported) == "CFrame" then
            return reported.Position
        end
        if typeof(reported) == "Vector3" then
            return reported
        end
        if type(reported) == "table" and typeof(reported.Position) == "Vector3" then
            return reported.Position
        end
    end
    local position = pet:GetAttribute("NpcCombatPosition")
    if typeof(position) == "Vector3" then
        return position
    end
    return pet:GetPivot().Position
end

function MergeEggPrototypeService:_towerPetInjured(pet)
    if not (pet and pet:IsA("Model")) or pet:GetAttribute("MergeEggObjective") == true then
        return false
    end
    -- Merge ghosts use CombatDamageTaken. Owned player pets can show the same
    -- endurance channel, an HP/MaxHP pair, or both. Either signal counts.
    local taken = tonumber(pet:GetAttribute("CombatDamageTaken")) or 0
    if taken > 0.05 then
        return true
    end
    local hp = tonumber(pet:GetAttribute("HP"))
    local maxHp = tonumber(pet:GetAttribute("MaxHP"))
    if hp and maxHp and maxHp > 0 then
        return hp > 0 and hp < maxHp - 0.5
    end
    return false
end

function MergeEggPrototypeService:_towerEachAllyPet(record, visit)
    if type(visit) ~= "function" then
        return
    end
    local seen = {}
    local function consider(pet)
        if pet and pet:IsA("Model") and pet.Parent and seen[pet] ~= true then
            seen[pet] = true
            visit(pet)
        end
    end
    for _, team in ipairs(record and record.teams or {}) do
        local folder = team.folder
        if folder and folder.Parent then
            for _, pet in ipairs(folder:GetChildren()) do
                consider(pet)
            end
        end
    end
    local playerFolder = record
        and (record.petFolder or self:_playerPetFolder(record.player, false))
    if playerFolder and playerFolder.Parent then
        for _, pet in ipairs(playerFolder:GetChildren()) do
            consider(pet)
        end
    end
    for _, pet in ipairs(record and record.playerUnits or {}) do
        consider(pet)
    end
end

function MergeEggPrototypeService:_towerLook(world, fallback)
    local worldCfg = self._config.world or {}
    local spawn = findNamedPart(world, worldCfg.hatcher_spawn or "HatcherSpawn")
    local look = spawn and Vector3.new(spawn.CFrame.LookVector.X, 0, spawn.CFrame.LookVector.Z)
        or fallback
    if look and look.Magnitude > 0.001 then
        return look.Unit
    end
    local side = world and tostring(world:GetAttribute("MergeEggBaySide") or "")
    if side == "hell" then
        return Vector3.new(-1, 0, 0)
    end
    return Vector3.new(1, 0, 0)
end

function MergeEggPrototypeService:_cannonFireSoundDef(key)
    local sounds = self._soundsConfig
    if type(sounds) ~= "table" then
        sounds = (self._configLoader and self._configLoader:LoadConfig("sounds"))
            or require(ReplicatedStorage.Configs:WaitForChild("sounds"))
        self._soundsConfig = sounds
    end
    local def = sounds and sounds[key or "cannon_fire"]
    if type(def) == "table" and type(def.id) == "string" and def.id ~= "" then
        return def
    end
    return nil
end

function MergeEggPrototypeService:_playCannonImpact(position, parent)
    local def = self:_cannonFireSoundDef("cannon_impact")
    if not (def and parent and typeof(position) == "Vector3") then
        return
    end
    local emitter = Instance.new("Part")
    emitter.Name = "MergeEggTowerImpactSound"
    emitter.Anchored = true
    emitter.CanCollide = false
    emitter.CanQuery = false
    emitter.CanTouch = false
    emitter.Transparency = 1
    emitter.Size = Vector3.new(0.2, 0.2, 0.2)
    emitter.CFrame = CFrame.new(position)
    emitter.Parent = parent
    local sound = Instance.new("Sound")
    sound.Name = "MergeTowerImpactSound"
    sound.SoundId = def.id
    sound.Volume = tonumber(def.volume) or 0.5
    sound.PlaybackSpeed = tonumber(def.playback_speed) or 1
    sound.RollOffMode = Enum.RollOffMode.InverseTapered
    sound.RollOffMinDistance = math.max(0, tonumber(def.roll_off_min_distance) or 22)
    sound.RollOffMaxDistance =
        math.max(sound.RollOffMinDistance, tonumber(def.roll_off_max_distance) or 140)
    SoundGroups.assign(sound, def.bus or "effects")
    sound.Parent = emitter
    sound:Play()
    Debris:AddItem(emitter, math.max(2, (tonumber(def.duration_seconds) or 1.28) + 0.6))
end

function MergeEggPrototypeService:_towerShotColor(_world, role)
    local towers, shot = self:_edgeTowerConfig()
    local colors = type(shot.role_colors) == "table" and shot.role_colors or towers.role_colors
    local triplet = type(colors) == "table" and colors[string.lower(tostring(role or ""))] or nil
    if type(triplet) == "table" then
        return rgbTriplet(triplet)
    end
    error("Missing team.edge_towers.shot.role_colors." .. string.lower(tostring(role or "")))
end

function MergeEggPrototypeService:_castTowerHealingField(flight, position)
    if not (self._powerService and self._powerService.PlaceHealingField) then
        return
    end
    local record = flight and flight.record
    local world = record and record.world
    local floorY = self:_towerFloorY(world)
    -- The authored Healing Field, at the impact. Strength is the existing
    -- per-tick magnitude; hot_tick stays on the power. Do not rebuild ticks.
    self._powerService:PlaceHealingField(record and record.player, position, {
        floor_y = floorY,
        magnitude = self:_towerHealMagnitude(record, flight and flight.cannon),
    })
end

function MergeEggPrototypeService:_castTowerBerserkCircle(flight, position)
    if not (self._powerService and self._powerService.PlaceBerserkCircle) then
        return
    end
    local record = flight and flight.record
    local world = record and record.world
    local floorY = self:_towerFloorY(world)
    local radius = self:_towerRageRadius(record, flight and flight.cannon)
    local extras = {}
    self:_towerEachAllyPet(record, function(pet)
        local petPos = self:_towerPetLivePosition(pet)
        if not petPos then
            return
        end
        local offset = Vector3.new(petPos.X - position.X, 0, petPos.Z - position.Z)
        if offset.Magnitude <= radius then
            extras[#extras + 1] = pet
        end
    end)
    -- Existing MagicCircle, ruddy red. Shot aims one pet; extras are
    -- every ally already inside that landing radius. Stamp each, not
    -- the owner. No tick loop.
    self._powerService:PlaceBerserkCircle(position, {
        radius = radius,
        floor_y = floorY,
        extra_pets = extras,
    })
end

function MergeEggPrototypeService:_castTowerWeakenCircle(flight, position)
    if not (self._powerService and self._powerService.PlaceWeakenCircle) then
        return
    end
    local record = flight and flight.record
    local role = "debuff"
    local spec = self:_towerLandingSpec(role)
    local radius = self:_towerLandingNumber(flight and flight.cannon, role, "radius")
    local inside = self:_towerEnemiesInRadius(record, position, radius)
    local enemies = {}
    for _, item in ipairs(inside) do
        enemies[#enemies + 1] = item.model
    end
    self._powerService:PlaceWeakenCircle(position, {
        radius = radius,
        floor_y = self:_towerFloorY(record and record.world),
        color = self:_towerRoleColor(role),
        potion_id = spec and spec.cast or "weakening_vial",
        enemies = enemies,
    })
end

function MergeEggPrototypeService:_castTowerFrostBind(flight, position)
    if not (self._powerService and self._powerService.PlaceFrostBindCircle) then
        return
    end
    local record = flight and flight.record
    local role = "nullifier"
    local radius = self:_towerLandingNumber(flight and flight.cannon, role, "radius")
    local chance = self:_towerLandingNumber(flight and flight.cannon, role, "hit_chance")
    local inside = self:_towerEnemiesInRadius(record, position, radius)
    local enemies = {}
    for _, item in ipairs(inside) do
        enemies[#enemies + 1] = item.model
    end
    self._powerService:PlaceFrostBindCircle(position, {
        radius = radius,
        floor_y = self:_towerFloorY(record and record.world),
        color = self:_towerRoleColor(role),
        hit_chance = chance,
        enemies = enemies,
    })
end

function MergeEggPrototypeService:_castTowerSeismicShove(flight, position, toward)
    if not (self._powerService and self._powerService.PlaceDirectedKnockback) then
        return
    end
    local record = flight and flight.record
    local world = record and record.world
    local role = string.lower(tostring((flight and flight.role) or ""))
    local spec = self:_towerLandingSpec(role)
    local radius = self:_towerLandingNumber(flight and flight.cannon, role, "radius")
    local distance = self:_towerLandingNumber(flight and flight.cannon, role, "shove")
    local gate = toward == "gate" and self:_towerTowardGate(world, position) or nil
    local shoves = {}
    for _, item in ipairs(self:_towerEnemiesInRadius(record, position, radius)) do
        local direction = gate
        if toward == "impact" then
            direction = Vector3.new(position.X - item.position.X, 0, position.Z - item.position.Z)
        elseif toward == "outward" then
            direction = Vector3.new(item.position.X - position.X, 0, item.position.Z - position.Z)
            if not direction or direction.Magnitude <= 1e-3 then
                local yaw = math.random() * math.pi * 2
                direction = Vector3.new(math.cos(yaw), 0, math.sin(yaw))
            end
        end
        if direction and direction.Magnitude > 1e-3 then
            shoves[#shoves + 1] = {
                model = item.model,
                direction = direction.Unit,
            }
        end
    end
    self._powerService:PlaceDirectedKnockback(position, {
        radius = radius,
        floor_y = self:_towerFloorY(world),
        color = self:_towerRoleColor(role),
        distance = distance,
        shoves = shoves,
        black_hole = spec and spec.black_hole == true,
        explosion = spec and spec.explosion == true,
        fling = spec and spec.fling == true,
        hit_chance = self:_towerListedNumber(
            spec and spec.hit_chance,
            self:_towerTierIndex(flight and flight.cannon),
            nil
        ),
        height = self:_towerListedNumber(
            spec and spec.height,
            self:_towerTierIndex(flight and flight.cannon),
            nil
        ),
        flight = self:_towerListedNumber(
            spec and spec.flight,
            self:_towerTierIndex(flight and flight.cannon),
            nil
        ),
        recover = self:_towerListedNumber(
            spec and spec.recover,
            self:_towerTierIndex(flight and flight.cannon),
            nil
        ),
        tumble_spins = tonumber(spec and spec.tumble_spins),
        wall_inset = tonumber(spec and spec.wall_inset),
    })
end

function MergeEggPrototypeService:_playTowerLandingVisual(flight, position)
    if typeof(position) ~= "Vector3" then
        return
    end
    local _, shot = self:_edgeTowerConfig()
    local landing = type(shot.landing) == "table" and shot.landing or {}
    local role = string.lower(tostring((flight and flight.role) or ""))
    local spec = landing[role]
    if type(spec) ~= "table" then
        return
    end
    local visual = tostring(spec.cast or spec.visual or "")
    if visual == "healing_field" then
        self:_castTowerHealingField(flight, position)
        return
    end
    if visual == "berserk_brew" then
        self:_castTowerBerserkCircle(flight, position)
        return
    end
    if visual == "weakening_vial" then
        self:_castTowerWeakenCircle(flight, position)
        return
    end
    if visual == "frost_bind" then
        self:_castTowerFrostBind(flight, position)
        return
    end
    if visual == "seismic_hold" then
        local toward = string.lower(tostring(spec.toward or "gate"))
        self:_castTowerSeismicShove(flight, position, toward)
    end
end

-- Saw contact is a separate positional cue from the mechanism's idle whir. Call it at the
-- struck combatant only when a real shred tick lands, and throttle so the 5s clip does not stack.
function MergeEggPrototypeService:_playSawBladeImpact(position, parent)
    local def = self:_cannonFireSoundDef("merge_saw_hit")
    if not (def and parent and typeof(position) == "Vector3") then
        return
    end
    local emitter = Instance.new("Part")
    emitter.Name = "MergeSawBladeImpactEmitter"
    emitter.Anchored = true
    emitter.CanCollide = false
    emitter.CanQuery = false
    emitter.CanTouch = false
    emitter.Transparency = 1
    emitter.Size = Vector3.new(0.2, 0.2, 0.2)
    emitter.CFrame = CFrame.new(position)
    emitter.Parent = parent
    local sound = Instance.new("Sound")
    sound.Name = "MergeSawBladeImpactSound"
    sound.SoundId = def.id
    sound.Volume = tonumber(def.volume) or 0.42
    sound.PlaybackSpeed = tonumber(def.playback_speed) or 1
    sound.RollOffMode = Enum.RollOffMode.InverseTapered
    sound.RollOffMinDistance = math.max(0, tonumber(def.roll_off_min_distance) or 10)
    sound.RollOffMaxDistance =
        math.max(sound.RollOffMinDistance, tonumber(def.roll_off_max_distance) or 90)
    SoundGroups.assign(sound, def.bus or "effects")
    sound.Parent = emitter
    sound:Play()
    Debris:AddItem(emitter, math.max(2, (tonumber(def.duration_seconds) or 5) + 0.6))
end

function MergeEggPrototypeService:_ensureSawBladeIdleSound(folder, hasSaw)
    if not folder then
        return
    end
    local existing = nil
    for _, descendant in ipairs(folder:GetDescendants()) do
        if descendant:IsA("Sound") and descendant.Name == "MergeSawBladeIdleSound" then
            if hasSaw == true and existing == nil then
                existing = descendant
            else
                descendant:Destroy()
            end
        end
    end
    if hasSaw ~= true then
        return
    end
    if existing then
        if not existing.IsPlaying then
            existing:Play()
        end
        return
    end
    local tiles = {}
    for _, child in ipairs(folder:GetChildren()) do
        if
            child:IsA("Model")
            and child:GetAttribute("MergeBulwarkFamily") == "saw_blade"
            and child:GetAttribute("MergeBulwarkSpawned") == true
        then
            tiles[#tiles + 1] = child
        end
    end
    table.sort(tiles, function(a, b)
        return (tonumber(a:GetAttribute("MergeBulwarkTileIndex")) or 0)
            < (tonumber(b:GetAttribute("MergeBulwarkTileIndex")) or 0)
    end)
    local center = tiles[math.max(1, math.ceil(#tiles * 0.5))]
    local parent = center
        and (center:FindFirstChild("Base", true) or center:FindFirstChildWhichIsA("BasePart", true))
    local def = self:_cannonFireSoundDef("merge_saw_idle")
    if not (parent and parent:IsA("BasePart") and def) then
        return
    end
    local sound = Instance.new("Sound")
    sound.Name = "MergeSawBladeIdleSound"
    sound.SoundId = def.id
    sound.Volume = tonumber(def.volume) or 0.24
    sound.PlaybackSpeed = tonumber(def.playback_speed) or 1
    sound.Looped = def.looped ~= false
    sound.RollOffMode = Enum.RollOffMode.InverseTapered
    sound.RollOffMinDistance = math.max(0, tonumber(def.roll_off_min_distance) or 30)
    sound.RollOffMaxDistance =
        math.max(sound.RollOffMinDistance, tonumber(def.roll_off_max_distance) or 120)
    SoundGroups.assign(sound, def.bus or "effects")
    sound.Parent = parent
    sound:Play()
end

function MergeEggPrototypeService:_ensureCannonFireSound(cannon)
    if not cannon then
        return nil
    end
    local existing = cannon:FindFirstChild("MergeTowerFireSound", true)
    if existing and existing:IsA("Sound") then
        return existing
    end
    local def = self:_cannonFireSoundDef()
    if not def then
        return nil
    end
    local parent = cannon.PrimaryPart or cannon:FindFirstChildWhichIsA("BasePart", true)
    if not parent then
        return nil
    end
    local sound = Instance.new("Sound")
    sound.Name = "MergeTowerFireSound"
    sound.SoundId = def.id
    sound.Volume = tonumber(def.volume) or 0.49
    sound.PlaybackSpeed = tonumber(def.playback_speed) or 1
    sound.RollOffMode = Enum.RollOffMode.InverseTapered
    sound.RollOffMinDistance = math.max(0, tonumber(def.roll_off_min_distance) or 28)
    sound.RollOffMaxDistance =
        math.max(sound.RollOffMinDistance, tonumber(def.roll_off_max_distance) or 160)
    SoundGroups.assign(sound, def.bus or "effects")
    sound.Parent = parent
    return sound
end

function MergeEggPrototypeService:_playCannonFire(cannon)
    local template = self:_ensureCannonFireSound(cannon)
    if not template then
        return
    end
    local def = self:_cannonFireSoundDef()
    local shot = template:Clone()
    shot.Name = "MergeTowerFireSoundPlay"
    shot.Parent = template.Parent
    shot:Play()
    Debris:AddItem(shot, math.max(2, (tonumber(def and def.duration_seconds) or 2) + 0.6))
end

function MergeEggPrototypeService:_towerArtNumber(cannon, field)
    local entry = MergeTierArt.entry(
        self._config and self._config.tier_art,
        "cannon",
        cannon and cannon:GetAttribute("MergeTowerRole"),
        cannon and cannon:GetAttribute("MergeTowerTier")
    )
    return tonumber(entry and entry[field]) or 0
end

function MergeEggPrototypeService:_towerBarrelYawDegrees(cannon)
    return self:_towerArtNumber(cannon, "barrelYawDegrees")
end

function MergeEggPrototypeService:_towerSeatOffsetY(cannon)
    return self:_towerArtNumber(cannon, "seatOffsetY")
end

function MergeEggPrototypeService:_towerPlanarAim(from, toward)
    if typeof(from) ~= "Vector3" or typeof(toward) ~= "Vector3" then
        return nil
    end
    local x, _, z = MergeTowerBallistics.planarYaw(toward.X - from.X, 0, toward.Z - from.Z)
    return Vector3.new(x, 0, z)
end

function MergeEggPrototypeService:_towerMuzzle(cannon, look)
    if not cannon then
        return nil
    end
    local named = cannon:FindFirstChild("Muzzle", true) or cannon:FindFirstChild("Barrel", true)
    if named and named:IsA("BasePart") then
        return named.Position
    end
    local box, size = cannon:GetBoundingBox()
    local aim = look
    if not (aim and aim.Magnitude > 0.001) then
        -- Shot direction, not mesh +X. A barrelYawDegrees mesh is 90° off RightVector.
        local world = self:_worldForCannon(cannon)
        aim = self:_towerGateLook(world, cannon:GetPivot().Position)
    end
    if not aim or aim.Magnitude < 0.001 then
        aim = Vector3.new(1, 0, 0)
    else
        aim = Vector3.new(aim.X, 0, aim.Z)
        if aim.Magnitude < 0.001 then
            aim = Vector3.new(1, 0, 0)
        else
            aim = aim.Unit
        end
    end
    local along = math.max(size.X, size.Z) * 0.38
    return box.Position + aim * along
end

function MergeEggPrototypeService:_barrelCFrame(position, tangent, cannon)
    -- Always flatten. Loft belongs on the fireball, never the chassis.
    -- barrelYawDegrees rotates the authored mesh so its visual barrel
    -- matches this +X fire basis. Default 0. Rage T1 is 270 in config.
    local yawX, yawY, yawZ =
        MergeTowerBallistics.planarYaw(tangent and tangent.X or 1, 0, tangent and tangent.Z or 0)
    local rx, ry, rz, ux, uy, uz = MergeTowerBallistics.barrelBasis(yawX, yawY, yawZ)
    local extra = math.rad(self:_towerBarrelYawDegrees(cannon))
    return CFrame.fromMatrix(position, Vector3.new(rx, ry, rz), Vector3.new(ux, uy, uz))
        * CFrame.Angles(0, extra, 0)
end

function MergeEggPrototypeService:_cannonPad(cannon, world)
    if not cannon then
        return nil
    end
    local pads = self:_authoredBayArtifact(world, "TowerStations", "TowerPads")
    if not pads then
        return nil
    end
    local expected = cannon.Name:gsub("_Cannon$", "")
    local slot = cannon:GetAttribute("MergeTowerPadSlot")
    local role = cannon:GetAttribute("MergeTowerPadRole")
    local best
    local bestDistance = math.huge
    for _, pad in ipairs(pads:GetChildren()) do
        if pad:IsA("Model") then
            if pad.Name == expected then
                return pad
            end
            if
                (slot ~= nil and pad:GetAttribute("MergeTowerPadSlot") == slot)
                or (role ~= nil and pad:GetAttribute("MergeTowerPadRole") == role)
            then
                local anchor = pad:FindFirstChild("TowerAnchor", true)
                local origin = cannon:GetPivot().Position
                local position = anchor and anchor.Position or pad:GetPivot().Position
                local distance = (Vector3.new(position.X, 0, position.Z) - Vector3.new(
                    origin.X,
                    0,
                    origin.Z
                )).Magnitude
                if distance < bestDistance then
                    best = pad
                    bestDistance = distance
                end
            end
        end
    end
    return best
end

-- Authored pad plates are CanQuery=false except the foundation. A world raycast therefore
-- misses the deck and hits the marble floor, which is why the guns sat sunk in the pad.
function MergeEggPrototypeService:_padSurfaceY(pad)
    if not pad then
        return nil
    end
    local top
    for _, part in ipairs(pad:GetDescendants()) do
        if part:IsA("BasePart") and part.Transparency < 1 then
            local y = part.Position.Y + part.Size.Y * 0.5
            if not top or y > top then
                top = y
            end
        end
    end
    if top then
        return top
    end
    local anchor = pad:FindFirstChild("TowerAnchor", true)
    if not (anchor and anchor:IsA("BasePart")) then
        return nil
    end
    return tonumber(anchor:GetAttribute("MergeTowerPadTopY")) or anchor.Position.Y
end

function MergeEggPrototypeService:_seatCannonOnPad(cannon, world, pad)
    if not cannon then
        return
    end
    pad = pad or self:_cannonPad(cannon, world)
    local surfaceY = self:_padSurfaceY(pad)
    if surfaceY then
        cannon:SetAttribute("MergeTowerPadTopY", surfaceY + 0.04)
    elseif cannon:GetAttribute("MergeTowerPadTopY") == nil then
        local box, size = cannon:GetBoundingBox()
        cannon:SetAttribute("MergeTowerPadTopY", box.Position.Y - size.Y * 0.5)
    end
    self:_groundCannon(cannon)
end

function MergeEggPrototypeService:_groundCannon(cannon)
    if not cannon then
        return
    end
    local padTop = tonumber(cannon:GetAttribute("MergeTowerPadTopY"))
    if not padTop then
        return
    end
    local box, size = cannon:GetBoundingBox()
    local bottom = box.Position.Y - size.Y * 0.5
    local target = padTop + self:_towerSeatOffsetY(cannon)
    if math.abs(target - bottom) > 1e-3 then
        cannon:PivotTo(cannon:GetPivot() + Vector3.new(0, target - bottom, 0))
    end
end

function MergeEggPrototypeService:_faceCannonDownLane(cannon, world)
    if not cannon then
        return
    end
    local look = self:_towerGateLook(world, cannon:GetPivot().Position)
    cannon:PivotTo(self:_barrelCFrame(cannon:GetPivot().Position, look, cannon))
    self:_groundCannon(cannon)
    cannon:SetAttribute("MergeTowerRestCFrame", cannon:GetPivot())
end

function MergeEggPrototypeService:_aimTowerCannon(cannon, origin, target, _apexHeight)
    if not (cannon and origin and target) then
        return
    end
    local rest = cannon:GetAttribute("MergeTowerRestCFrame")
    if typeof(rest) ~= "CFrame" then
        rest = cannon:GetPivot()
        cannon:SetAttribute("MergeTowerRestCFrame", rest)
        local box, size = cannon:GetBoundingBox()
        cannon:SetAttribute("MergeTowerRestBottomY", box.Position.Y - size.Y * 0.5)
    end
    -- Flat turret: yaw only. The fireball parabola carries any loft.
    local yawX, yawY, yawZ =
        MergeTowerBallistics.planarYaw(target.X - origin.X, 0, target.Z - origin.Z)
    cannon:PivotTo(self:_barrelCFrame(rest.Position, Vector3.new(yawX, yawY, yawZ), cannon))
    self:_groundCannon(cannon)
end

-- Live march position. EnemyService never re-pivots the anchored model after
-- spawn (only the client interpolates toward MoveTarget), so GetPivot() is the
-- portal spawn. Prefer entry.pos, then the MoveTarget attribute the rest of
-- Merge already uses for breach / heal-denial.
function MergeEggPrototypeService:_enemyLivePosition(enemy)
    if not enemy then
        return nil
    end
    if self._enemyService and self._enemyService.GetLivePosition and enemy.targetId then
        local live = self._enemyService:GetLivePosition(enemy.targetId)
        if typeof(live) == "Vector3" then
            return live
        end
    end
    local model = enemy.model
    if not (model and model.Parent) then
        return nil
    end
    local position = model:GetAttribute("MoveTarget")
    if typeof(position) == "Vector3" then
        return position
    end
    return nil
end

function MergeEggPrototypeService:_towerLaneRange(record, origin)
    local _, shot = self:_edgeTowerConfig()
    local range = requiredConfigNumber(shot.range, "team.edge_towers.shot.range")
    local gatePadding =
        requiredConfigNumber(shot.range_gate_padding, "team.edge_towers.shot.range_gate_padding")
    local portalPosition = self:_towerGatePosition(record and record.world)
    if portalPosition and origin then
        local planar = Vector3.new(portalPosition.X - origin.X, 0, portalPosition.Z - origin.Z)
        range = math.max(range, planar.Magnitude + gatePadding)
    end
    return range
end

function MergeEggPrototypeService:_towerCandidateAimable(origin, look, position, range)
    if typeof(position) ~= "Vector3" or not origin then
        return nil
    end
    local planar = Vector3.new(position.X - origin.X, 0, position.Z - origin.Z)
    local distance = planar.Magnitude
    if
        distance > 4
        and distance <= range
        and look
        and look.Magnitude > 0.001
        and planar.Magnitude > 0.05
        and planar.Unit:Dot(look.Unit) > 0.12
    then
        return distance
    end
    return nil
end

function MergeEggPrototypeService:_towerEnemyTarget(record, origin, look, role)
    local range = self:_towerLaneRange(record, origin)
    local world = record and record.world
    local best
    local bestDistance = math.huge
    for _, enemy in ipairs(record and record.enemies or {}) do
        local model = enemy.model
        if model and model.Parent and (tonumber(model:GetAttribute("HP")) or 0) > 0 then
            local position = self:_enemyLivePosition(enemy)
            if self:_towerAllowsFireAt(world, position, role or "repulsor") then
                local distance = self:_towerCandidateAimable(origin, look, position, range)
                if distance and distance < bestDistance then
                    if self:_towerLandsOnGround(role) then
                        best = self:_towerGroundPoint(world, position)
                    else
                        best = Vector3.new(position.X, position.Y + 1.4, position.Z)
                    end
                    bestDistance = distance
                end
            end
        end
    end
    return best
end

function MergeEggPrototypeService:_towerHealTarget(record, origin, look)
    local range = self:_towerLaneRange(record, origin)
    local world = record and record.world
    local best
    local bestDistance = math.huge
    self:_towerEachAllyPet(record, function(pet)
        if not self:_towerPetInjured(pet) then
            return
        end
        local position = self:_towerPetLivePosition(pet)
        if not self:_towerAllowsFireAt(world, position, "heal") then
            return
        end
        local distance = self:_towerCandidateAimable(origin, look, position, range)
        if distance and distance < bestDistance then
            best = self:_towerGroundPoint(world, position)
            bestDistance = distance
        end
    end)
    return best
end

function MergeEggPrototypeService:_towerRageTarget(record, origin, look)
    local range = self:_towerLaneRange(record, origin)
    local world = record and record.world
    local best
    local bestDistance = math.huge
    self:_towerEachAllyPet(record, function(pet)
        if not self:_towerPetInCombat(record, pet) then
            return
        end
        local position = self:_towerPetLivePosition(pet)
        if not self:_towerAllowsFireAt(world, position, "rage") then
            return
        end
        local distance = self:_towerCandidateAimable(origin, look, position, range)
        if distance and distance < bestDistance then
            best = self:_towerGroundPoint(world, position)
            bestDistance = distance
        end
    end)
    return best
end

function MergeEggPrototypeService:_towerShotTarget(record, origin, look, role)
    local id = string.lower(tostring(role or ""))
    if id == "heal" then
        return self:_towerHealTarget(record, origin, look)
    end
    if id == "rage" then
        return self:_towerRageTarget(record, origin, look)
    end
    return self:_towerEnemyTarget(record, origin, look, id)
end

function MergeEggPrototypeService:_towerAimTarget(record, origin, look, role)
    return self:_towerShotTarget(record, origin, look, role)
end

function MergeEggPrototypeService:_ensureBayTowers(record)
    local world = record and record.world
    if not world then
        return
    end
    local folder = self:_towerFolder(world, "MergeEggTowers")
    if record.towersReady == true then
        self:_ensureArtilleryCommanders(record, folder)
        return
    end
    local pads = self:_authoredBayArtifact(world, "TowerStations", "TowerPads")
    if not pads then
        return
    end
    local towerState = self:_normalizeTowerState(record)
    for _, pad in ipairs(pads:GetChildren()) do
        if pad:IsA("Model") and pad:FindFirstChild("TowerAnchor", true) then
            local slot = MergeTowerSlots.fromPad(pad)
            local family, tier = MergeTowerProgression.slotFamily(towerState, slot)
            local name = pad.Name .. "_Cannon"
            local existing = folder:FindFirstChild(name)
            if not family then
                if existing then
                    existing:Destroy()
                end
            else
                local gameplayTier = math.max(1, math.floor(tonumber(tier) or 1))
                if
                    existing
                    and (
                        existing:GetAttribute("MergeTowerTier") ~= gameplayTier
                        or existing:GetAttribute("MergeTowerRole") ~= family
                        or existing:GetAttribute("MergeTowerSlot") ~= slot
                        or existing:GetAttribute("MergeTowerArtTier") ~= gameplayTier
                        or not MergeTowerModels.MatchesTemplate(
                            existing,
                            family,
                            gameplayTier,
                            nil,
                            self._config.tier_art,
                            MergeTowerModels.entryWorldScale(
                                self._config.tier_art,
                                family,
                                gameplayTier
                            )
                        )
                    )
                then
                    existing:Destroy()
                    existing = nil
                end
                if not existing then
                    local model, reason = MergeTowerModels.Spawn(
                        family,
                        gameplayTier,
                        pad,
                        folder,
                        nil,
                        self._config.tier_art
                    )
                    if model then
                        model.Name = name
                        model:SetAttribute(
                            "MergeTowerPadRole",
                            pad:GetAttribute("MergeTowerPadRole")
                        )
                        model:SetAttribute(
                            "MergeTowerPadSlot",
                            pad:GetAttribute("MergeTowerPadSlot")
                        )
                        model:SetAttribute("MergeTowerSlot", slot)
                        model:SetAttribute("MergeTowerRole", family)
                        model:SetAttribute("MergeTowerTier", gameplayTier)
                        model:SetAttribute("MergeTowerArtTier", gameplayTier)
                        model:SetAttribute("MergeTowerNextFireAt", 0)
                        self:_seatCannonOnPad(model, world, pad)
                        self:_faceCannonDownLane(model, world)
                    elseif record.towerTemplateWarned ~= true then
                        record.towerTemplateWarned = true
                        self:_log("Warn", "Merge Egg tower template missing", {
                            role = family,
                            tier = gameplayTier,
                            reason = reason,
                        })
                    end
                end
                local live = existing or folder:FindFirstChild(name)
                if live and live:IsA("Model") then
                    live:SetAttribute("MergeTowerSlot", slot)
                    self:_seatCannonOnPad(live, world, pad)
                    self:_faceCannonDownLane(live, world)
                    self:_ensureCannonFireSound(live)
                    self:_clearTowerTestPrompts(live)
                end
            end
        end
    end
    self:_ensureArtilleryCommanders(record, folder)
    record.towersReady = true
end

function MergeEggPrototypeService:_collectBulwarkAnchors(anchors, namePattern)
    local allAnchors = {}
    if not anchors then
        return allAnchors
    end
    for _, anchor in ipairs(anchors:GetChildren()) do
        if anchor:IsA("BasePart") and string.match(anchor.Name, namePattern) then
            allAnchors[#allAnchors + 1] = anchor
        end
    end
    table.sort(allAnchors, function(a, b)
        return (tonumber(a:GetAttribute("MergeBulwarkTileIndex")) or 0)
            < (tonumber(b:GetAttribute("MergeBulwarkTileIndex")) or 0)
    end)
    return allAnchors
end

function MergeEggPrototypeService:_spawnBulwarkSlot(
    record,
    folder,
    allAnchors,
    family,
    tier,
    slotDef
)
    local cfg = self:_edgeBulwarkConfig()
    slotDef = slotDef or MergeBulwarkSlots.get(MergeBulwarkSlots.defaultId())
    local slot = slotDef.id
    local namePrefix = slotDef.modelPrefix or ""

    local function planarUnit(value, fallback)
        if typeof(value) ~= "Vector3" then
            return fallback
        end
        local flat = Vector3.new(value.X, 0, value.Z)
        if flat.Magnitude < 0.001 then
            return fallback
        end
        return flat.Unit
    end

    local sharkField = nil
    if family == "land_shark" and #allAnchors >= 2 then
        local first, last = allAnchors[1], allAnchors[#allAnchors]
        local span =
            Vector3.new(last.Position.X - first.Position.X, 0, last.Position.Z - first.Position.Z)
        local along = planarUnit(span, nil)
        if along then
            local tile = tonumber(first:GetAttribute("MergeBulwarkTileLength"))
                or requiredConfigNumber(
                    cfg.canonical_tile_length_studs,
                    "team.edge_bulwarks.canonical_tile_length_studs"
                )
            local margin = requiredConfigNumber(
                cfg.land_shark_field_margin_studs,
                "team.edge_bulwarks.land_shark_field_margin_studs"
            )
            local depthDir = planarUnit(first.CFrame.LookVector, Vector3.new(-along.Z, 0, along.X))
            depthDir = planarUnit(
                depthDir - along * depthDir:Dot(along),
                Vector3.new(-along.Z, 0, along.X)
            )
            sharkField = {
                center = (first.Position + last.Position) * 0.5,
                along = along,
                depth = depthDir,
                width = math.max(
                    requiredConfigNumber(
                        cfg.land_shark_min_field_width_studs,
                        "team.edge_bulwarks.land_shark_min_field_width_studs"
                    ),
                    span.Magnitude + tile - margin * 2
                ),
                depthStuds = requiredConfigNumber(
                    cfg.land_shark_field_depth_studs,
                    "team.edge_bulwarks.land_shark_field_depth_studs"
                ),
            }
        end
    end

    -- A Land Shark defense is a small patrol of independent moving hazards. It must never use the
    -- ten-tile wall presentation shared by Palisades, Wire, Hedges, Wardstones, and Saw rigs.
    local presentationAnchors = allAnchors
    if not family then
        presentationAnchors = {}
    elseif family == "land_shark" and #allAnchors > 0 then
        presentationAnchors = {}
        local hunt = self:_bulwarkCombatEffect(record, family, tier)
        local count = math.clamp(math.floor(hunt.sharkCount), 1, #allAnchors)
        for patrolIndex = 1, count do
            local anchorIndex = math.clamp(
                math.floor((patrolIndex * (#allAnchors + 1)) / (count + 1) + 0.5),
                1,
                #allAnchors
            )
            presentationAnchors[#presentationAnchors + 1] = allAnchors[anchorIndex]
        end
    end

    local desiredNames = {}
    for patrolIndex, anchor in ipairs(presentationAnchors) do
        local tileIndex = tonumber(anchor:GetAttribute("MergeBulwarkTileIndex")) or patrolIndex
        local name = if family == "land_shark"
            then string.format("%sLandShark_%02d", namePrefix, patrolIndex)
            else string.format("%sBulwarkTile_%02d", namePrefix, tileIndex)
        desiredNames[name] = true
    end
    for _, child in ipairs(folder:GetChildren()) do
        local childSlot = child:GetAttribute("MergeBulwarkSlot")
            or MergeBulwarkProgression.SLOT_LANE
        if
            child:IsA("Model")
            and child:GetAttribute("MergeBulwarkSpawned") == true
            and childSlot == slot
            and not desiredNames[child.Name]
        then
            child:Destroy()
        end
    end

    local spawned = 0
    for patrolIndex, anchor in ipairs(presentationAnchors) do
        local index = tonumber(anchor:GetAttribute("MergeBulwarkTileIndex")) or patrolIndex
        local name = if family == "land_shark"
            then string.format("%sLandShark_%02d", namePrefix, patrolIndex)
            else string.format("%sBulwarkTile_%02d", namePrefix, index)
        local expectedScale = tonumber(anchor:GetAttribute("MergeBulwarkScale")) or 1
        local existing = folder:FindFirstChild(name)
        if
            existing
            and (
                existing:GetAttribute("MergeBulwarkSlot") ~= slot
                or existing:GetAttribute("MergeBulwarkFamily") ~= family
                or existing:GetAttribute("MergeBulwarkTier") ~= tier
                or not MergeBulwarkModels.MatchesTemplate(
                    existing,
                    family,
                    tier,
                    nil,
                    self._config.tier_art
                )
                or math.abs(
                        (tonumber(existing:GetAttribute("MergeBulwarkSpawnScale")) or 1)
                            - expectedScale
                    )
                    > 1e-3
            )
        then
            existing:Destroy()
            existing = nil
        end
        if not existing and family then
            local model, reason = MergeBulwarkModels.Spawn(
                family,
                tier,
                anchor,
                folder,
                nil,
                expectedScale,
                self._config.tier_art
            )
            if model then
                model.Name = name
                model:SetAttribute("MergeBulwarkTileIndex", index)
                model:SetAttribute("MergeBulwarkSlot", slot)
                if family == "land_shark" then
                    -- Source sharks are authored across Z for menu/showcase use. Turn them down
                    -- the lane, submerge the body below the deck, and leave only the dorsal
                    -- silhouette visible until a nearby enemy causes a bite-rise on the client.
                    model:PivotTo(model:GetPivot() * CFrame.Angles(0, math.rad(90), 0))
                    local _, boundsSize = model:GetBoundingBox()
                    local finExposure = math.clamp(
                        requiredConfigNumber(
                            cfg.land_shark_fin_exposure_studs,
                            "team.edge_bulwarks.land_shark_fin_exposure_studs"
                        ),
                        0.25,
                        math.max(0.25, boundsSize.Y)
                    )
                    local submergeDepth = math.max(0, boundsSize.Y - finExposure)
                    model:PivotTo(model:GetPivot() - Vector3.new(0, submergeDepth, 0))
                    local direction = sharkField and sharkField.along
                        or Vector3.new(anchor.CFrame.RightVector.X, 0, anchor.CFrame.RightVector.Z)
                    if direction.Magnitude < 0.001 then
                        direction = Vector3.new(1, 0, 0)
                    else
                        direction = direction.Unit
                    end
                    model:SetAttribute("MergeLandSharkPatrol", true)
                    model:SetAttribute("MergeLandSharkPatrolIndex", patrolIndex)
                    model:SetAttribute("MergeLandSharkPatrolCount", #presentationAnchors)
                    model:SetAttribute("MergeLandSharkTrackDirection", direction)
                    if sharkField then
                        model:SetAttribute("MergeLandSharkFieldCenter", sharkField.center)
                        model:SetAttribute("MergeLandSharkDepthDirection", sharkField.depth)
                        model:SetAttribute("MergeLandSharkFieldWidth", sharkField.width)
                        model:SetAttribute("MergeLandSharkFieldDepth", sharkField.depthStuds)
                    end
                    local sharkTuning = {
                        MergeLandSharkTrackStuds = "land_shark_track_studs",
                        MergeLandSharkSpeedStuds = "land_shark_speed_studs",
                        MergeLandSharkTempoDivisor = "land_shark_tempo_divisor",
                        MergeLandSharkChaseSpeedStuds = "land_shark_chase_speed_studs",
                        MergeLandSharkDragSpeedStuds = "land_shark_drag_speed_studs",
                        MergeLandSharkReturnSpeedStuds = "land_shark_return_speed_studs",
                        MergeLandSharkHuntBlendRate = "land_shark_hunt_blend_rate",
                        MergeLandSharkSampleLeadSeconds = "land_shark_sample_lead_seconds",
                        MergeLandSharkProximityPollSeconds = "land_shark_proximity_poll_seconds",
                        MergeLandSharkSurfaceDistance = "land_shark_surface_distance",
                        MergeLandSharkBitePeriodSeconds = "land_shark_bite_period_seconds",
                        MergeLandSharkBreachPeriodSeconds = "land_shark_breach_period_seconds",
                        MergeLandSharkBreachDurationSeconds = "land_shark_breach_duration_seconds",
                        MergeLandSharkBreachRiseStuds = "land_shark_breach_rise_studs",
                        MergeLandSharkBreachPitchDegrees = "land_shark_breach_pitch_degrees",
                    }
                    for attribute, key in pairs(sharkTuning) do
                        model:SetAttribute(
                            attribute,
                            requiredConfigNumber(cfg[key], "team.edge_bulwarks." .. key)
                        )
                    end
                    model:SetAttribute("MergeLandSharkSurfaceRise", boundsSize.Y * 0.5)
                    model:SetAttribute(
                        "MergeLandSharkPhase",
                        (patrolIndex - 1) / math.max(1, #presentationAnchors)
                    )
                end
                spawned += 1
            elseif record.bulwarkTemplateWarned ~= true then
                record.bulwarkTemplateWarned = true
                self:_log("Warn", "Merge Egg bulwark template missing", {
                    family = family,
                    tier = tier,
                    slot = slot,
                    reason = reason,
                })
            end
        elseif existing then
            existing:SetAttribute("MergeBulwarkSlot", slot)
            spawned += 1
        end
    end
    local expected = family and #presentationAnchors or 0
    return spawned >= expected
end

function MergeEggPrototypeService:_authorSlotAnchorsFromStrip(world, def)
    if not (world and def) then
        return nil
    end
    local cfg = self:_edgeBulwarkConfig()
    local map = Workspace:FindFirstChild("GeneratedMap_MergeEggVoxel")
    local laneLines = map and map:FindFirstChild("LaneLines")
    local playFields = map and map:FindFirstChild("PlayFields")
    if not (map and laneLines and playFields) then
        return nil
    end
    local side = tostring(world:GetAttribute("MergeEggBaySide") or "")
    local column = tonumber(world:GetAttribute("MergeEggBayColumn"))
    if (side ~= "heaven" and side ~= "hell") or not column then
        return nil
    end
    local prefix = side == "hell" and "Hell" or "Heaven"
    local lines = laneLines:FindFirstChild(string.format("%s_%02d_Lines", prefix, column))
    local lineName = MergeBulwarkSlots.stripLineName(def, self._config.world)
    local line = lines and lineName and lines:FindFirstChild(lineName)
    local field = playFields:FindFirstChild(string.format("%s_%02d", prefix, column))
    if not (line and line:IsA("BasePart") and field and field:IsA("BasePart")) then
        return nil
    end
    local stations = map:FindFirstChild(def.stationsFolder)
    if not (stations and stations:IsA("Folder")) then
        stations = Instance.new("Folder")
        stations.Name = def.stationsFolder
        stations.Parent = map
    end
    local bayName = string.format(def.bayFolderFormat, prefix, column)
    local existing = stations:FindFirstChild(bayName)
    if existing then
        return existing
    end
    local tileCount = requiredConfigNumber(cfg.tile_count, "team.edge_bulwarks.tile_count")
    local wallInset =
        requiredConfigNumber(cfg.wall_inset_studs, "team.edge_bulwarks.wall_inset_studs")
    local canonicalTileLength = requiredConfigNumber(
        cfg.canonical_tile_length_studs,
        "team.edge_bulwarks.canonical_tile_length_studs"
    )
    local longIsX = line.Size.X >= line.Size.Z
    local markerLength = longIsX and line.Size.X or line.Size.Z
    local usableLength = markerLength - wallInset * 2
    if usableLength <= 0 then
        return nil
    end
    local tileLength = usableLength / tileCount
    local direction = longIsX and line.CFrame.RightVector or line.CFrame.LookVector
    local bayId = string.format("%s_%02d", side, column)
    local portableBays = Workspace:FindFirstChild("Maps")
        and Workspace.Maps:FindFirstChild("MergeEggRealm")
        and Workspace.Maps.MergeEggRealm:FindFirstChild("Bays")
    local portableBay = portableBays and portableBays:FindFirstChild("MergeBay_" .. bayId)
    local landStrip = portableBay and portableBay:FindFirstChild("LandStrip")
    local floorTop = landStrip and landStrip.Position.Y + landStrip.Size.Y * 0.5
        or field.Position.Y + field.Size.Y * 0.5
    local bayFolder = Instance.new("Folder")
    bayFolder.Name = bayName
    bayFolder:SetAttribute("MergeEggBayId", bayId)
    bayFolder:SetAttribute("MergeBulwarkSlot", def.id)
    bayFolder.Parent = stations
    for index = 1, tileCount do
        local offset = -usableLength * 0.5 + tileLength * (index - 0.5)
        local center = line.Position + direction * offset
        local anchor = Instance.new("Part")
        anchor.Name = string.format(def.anchorNameFormat, index)
        anchor.Anchored = true
        anchor.CanCollide = false
        anchor.CanTouch = false
        anchor.CanQuery = false
        anchor.CastShadow = false
        anchor.Transparency = 1
        anchor.Size = Vector3.new(0.5, 0.1, 0.5)
        anchor.CFrame = CFrame.lookAt(
            Vector3.new(center.X, floorTop, center.Z),
            Vector3.new(center.X, floorTop, center.Z) + direction,
            Vector3.yAxis
        )
        anchor:SetAttribute("MergeEggBayId", bayId)
        anchor:SetAttribute("MergeBulwarkTileIndex", index)
        anchor:SetAttribute("MergeBulwarkTileLength", tileLength)
        anchor:SetAttribute("MergeBulwarkScale", tileLength / canonicalTileLength)
        anchor:SetAttribute("MergeBulwarkSlot", def.id)
        anchor.Parent = bayFolder
    end
    return bayFolder
end

function MergeEggPrototypeService:_ensureBayBulwarks(record)
    local world = record and record.world
    if not world then
        return
    end
    local folder = self:_towerFolder(world, "MergeEggBulwarks")
    if record.bulwarksReady == true then
        self:_ensureBulwarkEngineer(record, folder)
        return
    end
    local cfg = self:_edgeBulwarkConfig()
    if cfg.enabled == false then
        record.bulwarksReady = true
        return
    end
    local state = self:_normalizeBulwarkState(record)
    local ready = true
    local hasSaw = false
    self:_clearBulwarkMenuPrompts(folder)
    for _, def in ipairs(MergeBulwarkSlots.all()) do
        local stations = self:_authoredBayArtifact(world, def.stationsFolder, def.anchorsSuffix)
            or self:_authorSlotAnchorsFromStrip(world, def)
        if not stations then
            if def.required == true then
                return
            end
            local warnedKey = "bulwarkAnchorWarned_" .. def.id
            if record[warnedKey] ~= true then
                record[warnedKey] = true
                self:_log("Warn", "Merge Egg bulwark anchors missing; skip slot", {
                    player = record.player and record.player.Name,
                    bay = world:GetAttribute("MergeEggBayId"),
                    slot = def.id,
                    stations = def.stationsFolder,
                })
            end
        else
            local family, tier = MergeBulwarkProgression.slotFamily(state, def.id)
            local slotAnchors = self:_collectBulwarkAnchors(stations, def.anchorNamePattern)
            ready = self:_spawnBulwarkSlot(record, folder, slotAnchors, family, tier, def) and ready
            hasSaw = hasSaw or family == "saw_blade"
            self:_stampBulwarkMenuPrompts(record, slotAnchors, folder, def)
        end
    end
    self:_ensureBulwarkEngineer(record, folder)
    self:_ensureSawBladeIdleSound(folder, hasSaw)
    record.bulwarksReady = ready
end

function MergeEggPrototypeService:_bulwarkMenuState(record, slot)
    local cfg = self:_edgeBulwarkConfig()
    local state = self:_normalizeBulwarkState(record)
    slot = MergeBulwarkProgression.normalizeSlot(slot)
    local family, tier = MergeBulwarkProgression.slotFamily(state, slot)
    local price = MergeBulwarkProgression.actionCost(cfg)
    local currentWave = record and math.max(1, math.floor(tonumber(record.waveIndex) or 0)) or 1
    local wallet = record
            and self._economyService
            and self._economyService:GetCurrency(record.player, price.currency)
        or 0
    return {
        slot = slot,
        family = family,
        tier = tier,
        owned = MergeBulwarkProgression.menuOwned(state, slot),
        installed = family ~= nil,
        maximumTier = math.max(1, math.floor(tonumber(cfg.maximum_tier) or 4)),
        families = MergeBulwarkProgression.familiesForSlot(slot, self._config.tier_art),
        unlocked = MergeBulwarkProgression.isUnlocked(MergeBulwarkProgression.unlockWave(cfg), cfg),
        unlockWave = MergeBulwarkProgression.unlockWave(cfg),
        productionUnlockWave = math.max(1, math.floor(tonumber(cfg.unlock_wave) or 20)),
        tutorialIntermissionWave = math.max(
            1,
            math.floor(tonumber(cfg.tutorial_intermission_wave) or 20)
        ),
        playtestUnlock = cfg.playtest_unlock_enabled == true,
        currentWave = currentWave,
        actionCost = price.amount,
        currency = price.currency,
        wallet = math.max(0, math.floor(tonumber(wallet) or 0)),
        unlockCosts = self:_unlockCostMap(cfg),
        gemWallet = self:_tutorialGemWallet(record),
    }
end

function MergeEggPrototypeService:_engineerConfig()
    local cfg = self:_edgeBulwarkConfig()
    return type(cfg.engineer) == "table" and cfg.engineer or {}
end

function MergeEggPrototypeService:_engineerPosts()
    local engineer = self:_engineerConfig()
    if engineer.enabled ~= true then
        return {}
    end
    local posts = {}
    local rows = type(engineer.posts) == "table" and engineer.posts or nil
    if rows and #rows > 0 then
        for _, row in ipairs(rows) do
            if type(row) == "table" then
                posts[#posts + 1] = {
                    slot = MergeBulwarkProgression.normalizeSlot(
                        row.slot or engineer.slot or "egg"
                    ),
                    along = string.lower(tostring(row.along or "center")),
                    user_id = tonumber(row.user_id) or tonumber(engineer.user_id),
                    display_name = row.display_name or engineer.display_name,
                    object_text = row.object_text or engineer.object_text,
                    action_text = row.action_text or engineer.action_text,
                    idle_animation = row.idle_animation or engineer.idle_animation,
                    max_distance = tonumber(row.max_distance)
                        or tonumber(engineer.max_distance)
                        or 16,
                }
            end
        end
    else
        posts[1] = {
            slot = MergeBulwarkProgression.normalizeSlot(engineer.slot or "egg"),
            along = string.lower(tostring(engineer.along or "center")),
            user_id = tonumber(engineer.user_id),
            display_name = engineer.display_name,
            object_text = engineer.object_text,
            action_text = engineer.action_text,
            idle_animation = engineer.idle_animation,
            max_distance = tonumber(engineer.max_distance) or 16,
        }
    end
    return posts
end

function MergeEggPrototypeService:_engineerOpensSlot(slot)
    slot = MergeBulwarkProgression.normalizeSlot(slot)
    for _, post in ipairs(self:_engineerPosts()) do
        if post.slot == slot then
            return true
        end
    end
    return false
end

function MergeEggPrototypeService:_engineerModelName(slot)
    return BULWARK_ENGINEER_NAME .. "_" .. MergeBulwarkProgression.normalizeSlot(slot)
end

function MergeEggPrototypeService:_canUseBulwarkMenu(player, slot)
    local record = self:_recordFor(player)
    local root = characterRoot(player)
    local folder = record and record.world and record.world:FindFirstChild("MergeEggBulwarks")
    if not (record and root and folder) then
        return false, "bulwark_station_unavailable"
    end
    local wanted = slot and MergeBulwarkProgression.normalizeSlot(slot) or nil
    local closest = math.huge
    local cfg = self:_edgeBulwarkConfig()
    local engineer = self:_engineerConfig()
    for _, child in ipairs(folder:GetChildren()) do
        if
            child:IsA("BasePart")
            and child.Name:sub(1, #BULWARK_MENU_HOST_PREFIX) == BULWARK_MENU_HOST_PREFIX
        then
            local hostSlot = child:GetAttribute("MergeBulwarkSlot")
                or MergeBulwarkProgression.SLOT_LANE
            if wanted == nil or hostSlot == wanted then
                closest = math.min(closest, (root.Position - child.Position).Magnitude)
            end
        elseif
            child.Name == BULWARK_ENGINEER_NAME
            or string.sub(child.Name, 1, #BULWARK_ENGINEER_NAME) == BULWARK_ENGINEER_NAME
            or child:GetAttribute("MergeBulwarkEngineer") == true
        then
            local hostSlot = child:GetAttribute("MergeBulwarkSlot")
                or MergeBulwarkProgression.normalizeSlot(engineer.slot or "egg")
            if
                (wanted == nil or hostSlot == wanted)
                and child:GetAttribute("MergeVendorPosted") == true
            then
                local part = firstBasePart(child)
                if part then
                    closest = math.min(closest, (root.Position - part.Position).Magnitude)
                end
            end
        end
    end
    local maximum = math.max(4, tonumber(cfg.prompt_distance) or 14) + 4
    if wanted and self:_engineerOpensSlot(wanted) then
        local postDistance = tonumber(engineer.max_distance) or 16
        for _, post in ipairs(self:_engineerPosts()) do
            if post.slot == wanted then
                postDistance = tonumber(post.max_distance) or postDistance
                break
            end
        end
        maximum = math.max(4, postDistance) + 4
    end
    if closest > maximum then
        return false, "bulwark_station_too_far"
    end
    return true, nil, closest
end

function MergeEggPrototypeService:_openBulwarkMenu(player, slot)
    local record = self:_recordFor(player)
    if not (record and record.player == player and record.terminal ~= true) then
        return false, "not_active_encounter"
    end
    slot = MergeBulwarkProgression.normalizeSlot(slot)
    if not self:_tutorialVendorsReady(record, "bulwark", slot) then
        return false, "vendor_not_ready"
    end
    local accessOk, accessReason = self:_canUseBulwarkMenu(player, slot)
    if not accessOk then
        return false, accessReason
    end
    if
        record.tutorialActive == true
        and record.tutorialStep == "talk_engineer"
        and slot == self:_tutorialWorkshopSlot()
    then
        record.tutorialTalkedEngineer = true
        self:_updateTutorial(record, os.clock(), true)
    end
    Signals.MergeEggPrototypeBoardResult:FireClient(player, {
        ok = true,
        action = "open_bulwark_menu",
        value = self:_bulwarkMenuState(record, slot),
    })
    return true
end

function MergeEggPrototypeService:_clearBulwarkMenuPrompts(folder)
    if not folder then
        return
    end
    for _, child in ipairs(folder:GetChildren()) do
        if
            child:IsA("BasePart")
            and child.Name:sub(1, #BULWARK_MENU_HOST_PREFIX) == BULWARK_MENU_HOST_PREFIX
        then
            child:Destroy()
        end
    end
end

function MergeEggPrototypeService:_stampBulwarkMenuPrompts(record, anchors, folder, slotDef)
    if not (record and folder) then
        return
    end
    slotDef = slotDef or MergeBulwarkSlots.get(MergeBulwarkSlots.defaultId())
    local slot = slotDef.id
    local namePrefix = tostring(slotDef.promptPrefix or "")
    local endpoints = {}
    if typeof(anchors) == "Instance" then
        endpoints = self:_collectBulwarkAnchors(anchors, slotDef.anchorNamePattern)
    elseif type(anchors) == "table" then
        endpoints = anchors
    end
    if #endpoints == 0 then
        return
    end
    if self:_engineerOpensSlot(slot) then
        return
    end
    local rows = {
        { suffix = namePrefix .. "Left", anchor = endpoints[1] },
        { suffix = namePrefix .. "Right", anchor = endpoints[#endpoints] },
    }
    local cfg = self:_edgeBulwarkConfig()
    for _, row in ipairs(rows) do
        local host = Instance.new("Part")
        host.Name = BULWARK_MENU_HOST_PREFIX .. row.suffix
        host.Size = Vector3.new(2, 4, 2)
        host.CFrame = row.anchor.CFrame * CFrame.new(0, 2, 0)
        host.Anchored = true
        host.CanCollide = false
        host.CanTouch = false
        host.CanQuery = false
        host.Transparency = 1
        host:SetAttribute("MergeBulwarkSlot", slot)
        host.Parent = folder
        local prompt = self:_attachPrompt(
            host,
            BULWARK_MENU_PROMPT_NAME,
            "Manage",
            slotDef.promptObject or "Bulwark",
            function(player)
                self:_openBulwarkMenu(player, slot)
            end
        )
        if prompt then
            prompt.HoldDuration = 0
            prompt.MaxActivationDistance = math.max(4, tonumber(cfg.prompt_distance) or 14)
        end
    end
end

function MergeEggPrototypeService:_clearBulwarkEngineer(folder, slot)
    if not folder then
        return
    end
    slot = slot and MergeBulwarkProgression.normalizeSlot(slot) or nil
    for _, child in ipairs(folder:GetChildren()) do
        local isEngineer = child:GetAttribute("MergeBulwarkEngineer") == true
            or child.Name == BULWARK_ENGINEER_NAME
            or string.sub(child.Name, 1, #BULWARK_ENGINEER_NAME) == BULWARK_ENGINEER_NAME
        if isEngineer and (slot == nil or child:GetAttribute("MergeBulwarkSlot") == slot) then
            child:Destroy()
        end
    end
end

function MergeEggPrototypeService:_clearSlotMenuHosts(folder, slot)
    if not folder then
        return
    end
    slot = MergeBulwarkProgression.normalizeSlot(slot)
    for _, child in ipairs(folder:GetChildren()) do
        if
            child:IsA("BasePart")
            and child.Name:sub(1, #BULWARK_MENU_HOST_PREFIX) == BULWARK_MENU_HOST_PREFIX
            and child:GetAttribute("MergeBulwarkSlot") == slot
        then
            child:Destroy()
        end
    end
end

function MergeEggPrototypeService:_engineerStandCFrame(world, slot, along)
    if not world then
        return nil
    end
    local slotDef = MergeBulwarkSlots.get(slot)
    local lineName = MergeBulwarkSlots.stripLineName(slotDef, self._config and self._config.world)
    local line = lineName and findNamedPart(world, lineName)
    if not line and slot == "egg" then
        line = self:_ensureBreachLine(world)
    end
    if not line then
        return nil
    end
    local landStrip = world:FindFirstChild("LandStrip")
    local floorTop = landStrip and landStrip.Position.Y + landStrip.Size.Y * 0.5 or line.Position.Y
    local side = tostring(world:GetAttribute("MergeEggBaySide") or "")
    local incoming = side == "hell" and Vector3.new(-1, 0, 0) or Vector3.new(1, 0, 0)
    local rightDir = Vector3.new(0, 1, 0):Cross(incoming)
    if rightDir.Magnitude <= 0 then
        rightDir = Vector3.new(0, 0, -1)
    else
        rightDir = rightDir.Unit
    end
    local longLen = math.max(line.Size.X, line.Size.Z)
    local half = longLen * 0.5 - 1
    local alongKey = string.lower(tostring(along or "center"))
    local alongOff = 0
    if alongKey == "right" then
        alongOff = half - 4.7
    elseif alongKey == "left" then
        alongOff = -(half - 4.7)
    end
    local stand = Vector3.new(line.Position.X, floorTop, line.Position.Z)
        + rightDir * alongOff
        - incoming * 4
    return CFrame.lookAt(stand, stand + incoming, Vector3.yAxis), floorTop
end

function MergeEggPrototypeService:_groundEngineerOnFloor(model, stand)
    if not (model and stand) then
        return
    end
    local root = model:FindFirstChild("HumanoidRootPart")
    local humanoid = model:FindFirstChildOfClass("Humanoid")
    local hip = humanoid and tonumber(humanoid.HipHeight) or 2
    local rootHalf = root and root.Size.Y * 0.5 or 1
    local pos = stand.Position + Vector3.new(0, hip + rootHalf, 0)
    model:PivotTo(CFrame.lookAt(pos, pos + stand.LookVector, Vector3.yAxis))
end

function MergeEggPrototypeService:_setEngineerPassthrough(model)
    if not model then
        return
    end
    local function apply(instance)
        if instance:IsA("BasePart") then
            instance.CanCollide = false
            instance.CanTouch = false
            instance.CanQuery = false
        end
    end
    apply(model)
    for _, descendant in ipairs(model:GetDescendants()) do
        apply(descendant)
    end
    model.DescendantAdded:Connect(apply)
end

function MergeEggPrototypeService:_setVendorPosted(model, posted)
    if not model then
        return
    end
    posted = posted == true
    model:SetAttribute("MergeVendorPosted", posted)
    local function apply(instance)
        local livePosted = model:GetAttribute("MergeVendorPosted") == true
        if instance:IsA("BasePart") or instance:IsA("Decal") or instance:IsA("Texture") then
            if instance:GetAttribute("MergeVendorBaseTransparency") == nil then
                instance:SetAttribute("MergeVendorBaseTransparency", instance.Transparency)
            end
            instance.Transparency = livePosted
                    and instance:GetAttribute("MergeVendorBaseTransparency")
                or 1
            if instance:IsA("BasePart") then
                instance.CanCollide = false
                instance.CanTouch = false
                instance.CanQuery = false
                instance.CastShadow = livePosted
            end
        elseif
            instance:IsA("ParticleEmitter")
            or instance:IsA("Beam")
            or instance:IsA("Trail")
            or instance:IsA("ProximityPrompt")
            or instance:IsA("BillboardGui")
            or instance:IsA("SurfaceGui")
        then
            instance.Enabled = livePosted
        end
    end
    apply(model)
    for _, descendant in ipairs(model:GetDescendants()) do
        apply(descendant)
    end
    if model:GetAttribute("MergeVendorPostedHooked") ~= true then
        model:SetAttribute("MergeVendorPostedHooked", true)
        model.DescendantAdded:Connect(apply)
    end
    local humanoid = model:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid.DisplayDistanceType = posted and Enum.HumanoidDisplayDistanceType.Viewer
            or Enum.HumanoidDisplayDistanceType.None
        humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
    end
end

function MergeEggPrototypeService:_quartermasterConfig()
    return type(self._config.quartermaster) == "table" and self._config.quartermaster or {}
end

function MergeEggPrototypeService:_findPotionShop(world)
    if not world then
        return nil
    end
    local worldCfg = type(self._config.world) == "table" and self._config.world or {}
    local side = tostring(world:GetAttribute("MergeEggBaySide") or "")
    local column = math.max(1, math.floor(tonumber(world:GetAttribute("MergeEggBayColumn")) or 1))
    local shopName = side == "hell" and (worldCfg.potion_shop_hell or "HellPotionShop")
        or (worldCfg.potion_shop_heaven or "HeavenPotionShop")
    local fieldName = (side == "hell" and "Hell_" or "Heaven_") .. string.format("%02d", column)
    local root = Workspace:FindFirstChild(worldCfg.voxel_map_name or "GeneratedMap_MergeEggVoxel")
    local fields = root and root:FindFirstChild(worldCfg.playfields_folder or "PlayFields")
    local field = fields and fields:FindFirstChild(fieldName)
    local named = field and field:FindFirstChild(shopName)
    if named and named:IsA("Model") then
        return named
    end
    local bayId = tostring(world:GetAttribute("MergeEggBayId") or "")
    for _, child in ipairs(fields and fields:GetDescendants() or {}) do
        if child:IsA("Model") and child:GetAttribute("MergeEggBayId") == bayId then
            return child
        end
    end
    return nil
end

function MergeEggPrototypeService:_setPotionShopPosted(shop, visible)
    if not shop then
        return
    end
    -- The booth is still the visual supply landmark, but all Merge interactions belong to the
    -- Quartermaster. PotionShopService honors this attribute even when it binds after this pass.
    shop:SetAttribute("PotionShopPromptSuppressed", true)
    local visibleTransparency = math.clamp(
        requiredConfigNumber(
            self:_quartermasterConfig().shop_visible_transparency,
            "quartermaster.shop_visible_transparency"
        ),
        0,
        1
    )
    local function stash(instance)
        if instance:IsA("BasePart") and instance:GetAttribute("MergeShopBaseCanCollide") == nil then
            instance:SetAttribute("MergeShopBaseCanCollide", instance.CanCollide)
        end
    end
    stash(shop)
    for _, descendant in ipairs(shop:GetDescendants()) do
        stash(descendant)
    end
    self:_setVendorPosted(shop, visible == true)
    if visible == true then
        local function restore(instance)
            if instance:IsA("BasePart") then
                -- These authored booth/sign parts intentionally start hidden. The generic vendor
                -- helper therefore cannot infer their live transparency from the authored value;
                -- stamp the config-owned reveal value so every later hide/show cycle restores it.
                instance:SetAttribute("MergeVendorBaseTransparency", visibleTransparency)
                instance.Transparency = visibleTransparency
                instance.CanCollide = instance:GetAttribute("MergeShopBaseCanCollide") == true
                instance.CanQuery = true
            elseif instance:IsA("Decal") or instance:IsA("Texture") then
                instance:SetAttribute("MergeVendorBaseTransparency", visibleTransparency)
                instance.Transparency = visibleTransparency
            end
        end
        restore(shop)
        for _, descendant in ipairs(shop:GetDescendants()) do
            restore(descendant)
        end
    end
    for _, descendant in ipairs(shop:GetDescendants()) do
        if descendant:IsA("ProximityPrompt") and descendant.Name == "PotionShopPrompt" then
            descendant.Enabled = false
        end
    end
end

function MergeEggPrototypeService:_syncMergePotionShops(record)
    local worldCfg = type(self._config.world) == "table" and self._config.world or {}
    local root = Workspace:FindFirstChild(worldCfg.voxel_map_name or "GeneratedMap_MergeEggVoxel")
    local fields = root and root:FindFirstChild(worldCfg.playfields_folder or "PlayFields")
    if not fields then
        return
    end
    local owners = {}
    for _, live in pairs(self._activeByPlayer or {}) do
        local bayId = live.world and tostring(live.world:GetAttribute("MergeEggBayId") or "")
        if bayId ~= "" then
            owners[bayId] = live
        end
    end
    if record and record.world then
        local bayId = tostring(record.world:GetAttribute("MergeEggBayId") or "")
        if bayId ~= "" then
            owners[bayId] = record
        end
    end
    local heavenName = worldCfg.potion_shop_heaven or "HeavenPotionShop"
    local hellName = worldCfg.potion_shop_hell or "HellPotionShop"
    for _, shop in ipairs(fields:GetDescendants()) do
        if shop:IsA("Model") and (shop.Name == heavenName or shop.Name == hellName) then
            local owner = owners[tostring(shop:GetAttribute("MergeEggBayId") or "")]
            self:_setPotionShopPosted(
                shop,
                owner and self:_tutorialVendorsReady(owner, "quartermaster") == true
            )
        end
    end
end

function MergeEggPrototypeService:_quartermasterStandCFrame(world, shop)
    if not (world and shop) then
        return nil
    end
    local commander = self:_quartermasterConfig()
    local landStrip = world:FindFirstChild("LandStrip")
    local box, size = shop:GetBoundingBox()
    local floorTop = landStrip and landStrip.Position.Y + landStrip.Size.Y * 0.5
        or (box.Position.Y - size.Y * 0.5)
    local look = Vector3.new(shop:GetPivot().LookVector.X, 0, shop:GetPivot().LookVector.Z)
    if look.Magnitude < 0.001 then
        local side = tostring(world:GetAttribute("MergeEggBaySide") or "")
        look = side == "hell" and Vector3.new(-1, 0, 0) or Vector3.new(1, 0, 0)
    else
        look = look.Unit
    end
    local front =
        requiredConfigNumber(commander.stand_front_studs, "quartermaster.stand_front_studs")
    local stand = Vector3.new(box.Position.X, floorTop, box.Position.Z) + look * front
    return CFrame.lookAt(stand, stand + look, Vector3.yAxis), floorTop
end

function MergeEggPrototypeService:_setQuartermasterSpeech(model, text)
    if not model then
        return
    end
    local head = model:FindFirstChild("Head") or firstBasePart(model)
    if not head then
        return
    end
    local speech = head:FindFirstChild(QUARTERMASTER_SPEECH_NAME)
    if speech and not speech:IsA("BillboardGui") then
        speech:Destroy()
        speech = nil
    end
    if not text or text == "" then
        if speech then
            speech:Destroy()
        end
        return
    end
    if not speech then
        speech = Instance.new("BillboardGui")
        speech.Name = QUARTERMASTER_SPEECH_NAME
        speech.Size = UDim2.fromOffset(280, 56)
        speech.StudsOffset = Vector3.new(0, 3.2, 0)
        speech.AlwaysOnTop = true
        speech.Parent = head
        local label = Instance.new("TextLabel")
        label.Name = "Line"
        label.Size = UDim2.fromScale(1, 1)
        label.BackgroundColor3 = Color3.fromRGB(24, 29, 40)
        label.BackgroundTransparency = 0.12
        label.Font = Enum.Font.GothamBold
        label.TextColor3 = Color3.fromRGB(245, 248, 255)
        label.TextScaled = true
        label.Parent = speech
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = label
    end
    local line = speech:FindFirstChild("Line")
    if line and line:IsA("TextLabel") then
        line.Text = tostring(text)
    end
end

function MergeEggPrototypeService:_findQuartermaster(folder)
    if not folder then
        return nil
    end
    local named = folder:FindFirstChild(QUARTERMASTER_NAME)
    if named then
        return named
    end
    for _, child in ipairs(folder:GetChildren()) do
        if child:GetAttribute("MergeQuartermaster") == true then
            return child
        end
    end
    return nil
end

function MergeEggPrototypeService:_canUseQuartermaster(player)
    local record = self:_recordFor(player)
    local root = characterRoot(player)
    local folder = record and record.world and record.world:FindFirstChild("MergeEggQuartermaster")
    local live = self:_findQuartermaster(folder)
    local host = live and firstBasePart(live)
    if
        not (
            record
            and record.player == player
            and record.terminal ~= true
            and root
            and live
            and host
            and live:GetAttribute("MergeVendorPosted") == true
        )
    then
        return false, "quartermaster_unavailable"
    end
    if not self:_tutorialVendorsReady(record, "quartermaster") then
        return false, "vendor_not_ready"
    end
    local maximum = math.max(
        4,
        requiredConfigNumber(self:_quartermasterConfig().max_distance, "quartermaster.max_distance")
    ) + 4
    if (root.Position - host.Position).Magnitude > maximum then
        return false, "quartermaster_too_far"
    end
    return true, nil, record, live
end

function MergeEggPrototypeService:_quartermasterMenuState(record)
    local post = self:_quartermasterConfig()
    local services = type(post.services) == "table" and post.services or {}
    local data = record and self._dataService and self._dataService:GetData(record.player)
    local progress = data and data.CombatTutorial
    local done = type(progress) == "table" and progress.done == true
    local started = type(progress) == "table"
        and done ~= true
        and math.max(1, math.floor(tonumber(progress.step) or 1)) > 1
    local trainingLabel = services.training_label or "COMBAT TRAINING"
    if started then
        trainingLabel = services.training_resume_label or "RESUME COMBAT TRAINING"
    end
    local gamePassIds = {}
    for _, passId in ipairs(services.game_pass_ids or {}) do
        if type(passId) == "string" and passId ~= "" then
            gamePassIds[#gamePassIds + 1] = passId
        end
    end
    return {
        operation = "quartermaster_services",
        greeting = tostring(
            (done and post.greeting_complete) or post.greeting or "I'll get you whatever you need."
        ),
        title = tostring(services.title or "QUARTERMASTER"),
        body = tostring((done and services.body_complete) or services.body or "Choose a service."),
        gamePassesLabel = tostring(services.game_passes_label or "GAME PASSES"),
        gamePassesBody = tostring(
            services.game_passes_body or "Permanent upgrades for Merge Defense."
        ),
        gamePassesShopTitle = tostring(services.game_passes_shop_title or "QUARTERMASTER PASSES"),
        gamePassesShopSubtitle = tostring(
            services.game_passes_shop_subtitle or "Permanent upgrades selected for Merge Defense"
        ),
        gamePassIds = gamePassIds,
        potionsLabel = tostring(services.potions_label or "BROWSE POTIONS"),
        potionsBody = tostring(services.potions_body or "Buy supplies for your pets."),
        trainingLabel = tostring(trainingLabel),
        trainingBody = tostring(services.training_body or "Learn to use powers in combat."),
        closeLabel = tostring(services.close_label or "NOT NOW"),
        trainingAvailable = not done,
        combatTutorialDone = done,
        combatTutorialStarted = started,
    }
end

function MergeEggPrototypeService:_openQuartermasterTalk(player)
    local accessOk, accessReason, record = self:_canUseQuartermaster(player)
    if not accessOk then
        return false, accessReason
    end
    local folder = record.world and record.world:FindFirstChild("MergeEggQuartermaster")
    local live = self:_findQuartermaster(folder)
    local value = self:_quartermasterMenuState(record)
    self:_setQuartermasterSpeech(live, value.greeting)
    local completesTutorial = record.tutorialActive == true
        and record.tutorialStep == "talk_quartermaster"
    if completesTutorial then
        record.tutorialTalkedQuartermaster = true
        self:_updateTutorial(record, os.clock(), true)
    end
    value.milestone = completesTutorial and "quartermaster_ready" or nil
    Signals.MergeEggPrototypeBoardResult:FireClient(player, {
        ok = true,
        action = "quartermaster_talk",
        value = value,
    })
    return true
end

-- Combat Training manages ordinary inventory-backed pets, including its temporary tutorial loan
-- records. If Merge is currently in Simple mode, first leave the prototype escort path through the
-- existing Full-mode transition: destroy the ghosts and restore the parked durable models before
-- the Merge session closes. The handoff itself does not unlock eligibility. If training completes,
-- the return path persists Full through Settings; otherwise normal eligibility rebuilds Simple.
function MergeEggPrototypeService:_prepareCombatTrainingPets(record)
    if not self:_isRecordActive(record) then
        return false
    end
    if record.playerCombatMode == "full" then
        return true
    end
    return self:_switchPlayerCombatMode(record, "full")
end

function MergeEggPrototypeService:UseQuartermasterService(player, request)
    local accessOk, accessReason, record, live = self:_canUseQuartermaster(player)
    if not accessOk then
        return false, accessReason
    end
    local choice = tostring(type(request) == "table" and request.choice or "")
    local menuState = self:_quartermasterMenuState(record)
    if choice == "game_passes" then
        if #menuState.gamePassIds == 0 then
            return false, "game_pass_catalog_unavailable"
        end
        return true,
            {
                operation = "game_passes_opened",
                passIds = menuState.gamePassIds,
                title = menuState.gamePassesShopTitle,
                subtitle = menuState.gamePassesShopSubtitle,
            }
    end
    if choice == "potions" then
        local shop = self:_findPotionShop(record.world)
        local service = self._potionShopService
        if not (shop and service and service.OpenForPlayer) then
            return false, "potion_shop_unavailable"
        end
        local opened, reason = service:OpenForPlayer(player, shop, live)
        if not opened then
            return false, reason or "potion_shop_unavailable"
        end
        return true, { operation = "potions_opened" }
    end
    if choice == "combat_training" then
        if menuState.trainingAvailable ~= true then
            return false, "combat_tutorial_complete"
        end
        local service = self._combatTutorialService
        if not (service and service.OpenForPlayer) then
            return false, "combat_tutorial_unavailable"
        end
        local bayId = record.bayId
        local previousPetMode = record.playerCombatMode
        local opened, result = service:OpenForPlayer(player, {
            beforeOpen = function()
                if not self:_isRecordActive(record) then
                    return false
                end
                if not self:_prepareCombatTrainingPets(record) then
                    return false
                end
                self._combatTrainingReturns[player] = {
                    bayId = bayId,
                    previousPetMode = previousPetMode,
                }
                self:_end(record, false, false)
                return true
            end,
            onOpenFailed = function(reason)
                self:_resumeAfterCombatTraining(player, reason or "open_failed")
            end,
        })
        if not opened then
            return false, result or "combat_tutorial_unavailable"
        end
        return true, result
    end
    return false, "invalid_quartermaster_service"
end

function MergeEggPrototypeService:_spawnQuartermaster(record, folder, shop)
    if not (record and folder and folder.Parent and shop) then
        return
    end
    if self:_findQuartermaster(folder) then
        return
    end
    local post = self:_quartermasterConfig()
    if post.enabled ~= true then
        return
    end
    local stand = self:_quartermasterStandCFrame(record.world, shop)
    if not stand then
        self:_log("Warn", "Merge Egg quartermaster has no stand pose", {
            player = record.player and record.player.Name,
        })
        return
    end
    local userId = tonumber(post.user_id)
    local model
    if userId then
        local ok, desc = pcall(function()
            return Players:GetHumanoidDescriptionFromUserId(userId)
        end)
        if ok and desc then
            local ok2, rig = pcall(function()
                return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
            end)
            if ok2 then
                model = rig
            end
        end
    end
    if not model then
        self:_log("Warn", "Merge Egg quartermaster avatar failed", {
            userId = userId,
        })
        return
    end
    model.Name = QUARTERMASTER_NAME
    model:SetAttribute("MergeQuartermaster", true)
    local humanoid = model:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid.DisplayName = post.display_name or "Macros"
        humanoid.WalkSpeed = 0
        humanoid.JumpPower = 0
        humanoid.AutoJumpEnabled = false
        local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
        animator.Parent = humanoid
        local idle = Instance.new("Animation")
        idle.AnimationId = requiredAssetUri(post.idle_animation, "quartermaster.idle_animation")
        local ok, track = pcall(function()
            return animator:LoadAnimation(idle)
        end)
        if ok and track then
            track.Looped = true
            track:Play()
        end
    end
    self:_groundEngineerOnFloor(model, stand)
    local root = model:FindFirstChild("HumanoidRootPart")
    if root then
        root.Anchored = true
        pcall(function()
            root:SetNetworkOwner(nil)
        end)
    end
    self:_setVendorPosted(model, false)
    model.Parent = folder
    self:_setEngineerPassthrough(model)
    local promptHost = root or firstBasePart(model)
    local prompt = self:_attachPrompt(
        promptHost,
        QUARTERMASTER_PROMPT_NAME,
        post.action_text or "Talk",
        post.object_text or post.display_name or "Quartermaster",
        function(player)
            self:_openQuartermasterTalk(player)
        end
    )
    if prompt then
        prompt.HoldDuration = 0
        prompt.MaxActivationDistance =
            math.max(4, requiredConfigNumber(post.max_distance, "quartermaster.max_distance"))
    end
    self:_setVendorPosted(model, self:_tutorialVendorsReady(record, "quartermaster"))
end

function MergeEggPrototypeService:_ensureBayQuartermaster(record)
    local world = record and record.world
    if not world then
        return
    end
    self:_syncMergePotionShops(record)
    local post = self:_quartermasterConfig()
    if post.enabled ~= true then
        return
    end
    local folder = self:_towerFolder(world, "MergeEggQuartermaster")
    local shop = self:_findPotionShop(world)
    if not shop then
        return
    end
    local live = self:_findQuartermaster(folder)
    if not live then
        task.spawn(function()
            self:_spawnQuartermaster(record, folder, shop)
        end)
        return
    end
    local stand = self:_quartermasterStandCFrame(world, shop)
    if stand then
        self:_groundEngineerOnFloor(live, stand)
    end
    self:_setVendorPosted(live, self:_tutorialVendorsReady(record, "quartermaster"))
end

function MergeEggPrototypeService:_findBulwarkEngineer(folder, slot)
    if not folder then
        return nil
    end
    slot = MergeBulwarkProgression.normalizeSlot(slot)
    local named = folder:FindFirstChild(self:_engineerModelName(slot))
    if named then
        return named
    end
    for _, child in ipairs(folder:GetChildren()) do
        if
            (
                child.Name == BULWARK_ENGINEER_NAME
                or child:GetAttribute("MergeBulwarkEngineer") == true
            ) and child:GetAttribute("MergeBulwarkSlot") == slot
        then
            return child
        end
    end
    return nil
end

function MergeEggPrototypeService:_ensureBulwarkEngineer(record, folder)
    if not (record and folder) then
        return
    end
    for _, post in ipairs(self:_engineerPosts()) do
        self:_clearSlotMenuHosts(folder, post.slot)
        local live = self:_findBulwarkEngineer(folder, post.slot)
        if not live then
            local captured = post
            task.spawn(function()
                self:_spawnBulwarkEngineer(record, folder, captured)
            end)
        else
            self:_setVendorPosted(live, self:_tutorialVendorsReady(record, "bulwark", post.slot))
        end
    end
end

function MergeEggPrototypeService:_spawnBulwarkEngineer(record, folder, post)
    if not (record and folder and folder.Parent and post) then
        return
    end
    local slot = MergeBulwarkProgression.normalizeSlot(post.slot)
    if self:_findBulwarkEngineer(folder, slot) then
        return
    end
    local stand = self:_engineerStandCFrame(record.world, slot, post.along)
    if not stand then
        self:_log("Warn", "Merge Egg bulwark engineer has no stand pose", {
            player = record.player and record.player.Name,
            slot = slot,
            along = post.along,
        })
        return
    end
    local userId = tonumber(post.user_id)
    local model
    if userId then
        local ok, desc = pcall(function()
            return Players:GetHumanoidDescriptionFromUserId(userId)
        end)
        if ok and desc then
            local ok2, rig = pcall(function()
                return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
            end)
            if ok2 then
                model = rig
            end
        end
    end
    if not model then
        self:_log("Warn", "Merge Egg bulwark engineer avatar failed", {
            userId = userId,
            slot = slot,
        })
        return
    end
    model.Name = self:_engineerModelName(slot)
    model:SetAttribute("MergeBulwarkEngineer", true)
    model:SetAttribute("MergeBulwarkSlot", slot)
    local humanoid = model:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid.DisplayName = post.display_name or "Bulwark Engineer"
        humanoid.WalkSpeed = 0
        humanoid.JumpPower = 0
        humanoid.AutoJumpEnabled = false
        local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
        animator.Parent = humanoid
        local idle = Instance.new("Animation")
        idle.AnimationId =
            requiredAssetUri(post.idle_animation, "team.edge_bulwarks.engineer.idle_animation")
        local ok, track = pcall(function()
            return animator:LoadAnimation(idle)
        end)
        if ok and track then
            track.Looped = true
            track:Play()
        end
    end
    self:_groundEngineerOnFloor(model, stand)
    local root = model:FindFirstChild("HumanoidRootPart")
    if root then
        root.Anchored = true
        pcall(function()
            root:SetNetworkOwner(nil)
        end)
    end
    self:_setVendorPosted(model, false)
    model.Parent = folder
    self:_setEngineerPassthrough(model)
    self:_clearSlotMenuHosts(folder, slot)
    local promptHost = root or firstBasePart(model)
    local prompt = self:_attachPrompt(
        promptHost,
        BULWARK_MENU_PROMPT_NAME,
        post.action_text or "Talk",
        post.object_text or post.display_name or "Bulwark Engineer",
        function(player)
            self:_openBulwarkMenu(player, slot)
        end
    )
    if prompt then
        prompt.HoldDuration = 0
        prompt.MaxActivationDistance = math.max(4, tonumber(post.max_distance) or 16)
    end
    self:_setVendorPosted(model, self:_tutorialVendorsReady(record, "bulwark", slot))
end

function MergeEggPrototypeService:_commanderConfig()
    local towers = self:_edgeTowerConfig()
    return type(towers.commander) == "table" and towers.commander or {}
end

function MergeEggPrototypeService:_commanderModelName(slot)
    return ARTILLERY_COMMANDER_NAME .. "_" .. MergeTowerProgression.normalizeSlot(slot)
end

function MergeEggPrototypeService:_findArtilleryCommander(folder, slot)
    if not folder then
        return nil
    end
    slot = MergeTowerProgression.normalizeSlot(slot)
    local named = folder:FindFirstChild(self:_commanderModelName(slot))
    if named then
        return named
    end
    for _, child in ipairs(folder:GetChildren()) do
        if
            (
                child.Name == ARTILLERY_COMMANDER_NAME
                or child:GetAttribute("MergeArtilleryCommander") == true
            ) and child:GetAttribute("MergeTowerSlot") == slot
        then
            return child
        end
    end
    return nil
end

function MergeEggPrototypeService:_cannonForSlot(folder, slot)
    if not folder then
        return nil
    end
    slot = MergeTowerProgression.normalizeSlot(slot)
    for _, child in ipairs(folder:GetChildren()) do
        if
            child:IsA("Model")
            and child:GetAttribute("MergeTowerSpawned") == true
            and MergeTowerSlots.fromPad(child) == slot
        then
            return child
        end
    end
    return nil
end

function MergeEggPrototypeService:_padForSlot(world, slot)
    local pads = self:_authoredBayArtifact(world, "TowerStations", "TowerPads")
    if not pads then
        return nil
    end
    slot = MergeTowerProgression.normalizeSlot(slot)
    for _, pad in ipairs(pads:GetChildren()) do
        if pad:IsA("Model") and MergeTowerSlots.fromPad(pad) == slot then
            return pad
        end
    end
    return nil
end

function MergeEggPrototypeService:_commanderStandCFrame(world, anchor)
    if not (world and anchor) then
        return nil
    end
    local commander = self:_commanderConfig()
    local landStrip = world:FindFirstChild("LandStrip")
    local box, size = anchor:GetBoundingBox()
    local floorTop = landStrip and landStrip.Position.Y + landStrip.Size.Y * 0.5
        or (box.Position.Y - size.Y * 0.5)
    local look = self:_towerGateLook(world, box.Position)
    if not look or look.Magnitude < 0.001 then
        look = Vector3.new(1, 0, 0)
    end
    local extra = tonumber(commander.stand_behind_studs) or 7
    local footprint = tonumber(anchor:GetAttribute("MergeTowerPadFootprint"))
    local extent = footprint and footprint * 0.5 or math.max(size.X, size.Z) * 0.5
    local stand = Vector3.new(box.Position.X, floorTop, box.Position.Z) - look * (extent + extra)
    return CFrame.lookAt(stand, stand + look, Vector3.yAxis), floorTop
end

function MergeEggPrototypeService:_clearArtilleryCommanders(folder)
    if not folder then
        return
    end
    for _, child in ipairs(folder:GetChildren()) do
        if
            child:GetAttribute("MergeArtilleryCommander") == true
            or child.Name == ARTILLERY_COMMANDER_NAME
            or string.sub(child.Name, 1, #ARTILLERY_COMMANDER_NAME) == ARTILLERY_COMMANDER_NAME
        then
            child:Destroy()
        end
    end
end

function MergeEggPrototypeService:_ensureArtilleryCommanders(record, folder)
    if not (record and folder) then
        return
    end
    local commander = self:_commanderConfig()
    if commander.enabled ~= true then
        return
    end
    for _, def in ipairs(MergeTowerSlots.all()) do
        local cannon = self:_cannonForSlot(folder, def.id)
        local pad = self:_padForSlot(record.world, def.id)
        local anchor = cannon or pad
        local live = self:_findArtilleryCommander(folder, def.id)
        if anchor and not live then
            local captured = { slot = def.id, cannon = cannon, pad = pad }
            task.spawn(function()
                self:_spawnArtilleryCommander(record, folder, captured)
            end)
        elseif live then
            if anchor then
                local stand = self:_commanderStandCFrame(record.world, anchor)
                if stand then
                    self:_groundEngineerOnFloor(live, stand)
                end
            end
            self:_setVendorPosted(live, self:_tutorialVendorsReady(record, "artillery", def.id))
        end
    end
end

function MergeEggPrototypeService:_spawnArtilleryCommander(record, folder, post)
    if not (record and folder and folder.Parent and post) then
        return
    end
    local slot = MergeTowerProgression.normalizeSlot(post.slot)
    if self:_findArtilleryCommander(folder, slot) then
        return
    end
    local cannon = post.cannon or self:_cannonForSlot(folder, slot)
    local pad = post.pad or self:_padForSlot(record.world, slot)
    local stand = self:_commanderStandCFrame(record.world, cannon or pad)
    if not stand then
        self:_log("Warn", "Merge Egg artillery commander has no stand pose", {
            player = record.player and record.player.Name,
            slot = slot,
        })
        return
    end
    local commander = self:_commanderConfig()
    local userId = tonumber(commander.user_id)
    local model
    if userId then
        local ok, desc = pcall(function()
            return Players:GetHumanoidDescriptionFromUserId(userId)
        end)
        if ok and desc then
            local ok2, rig = pcall(function()
                return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
            end)
            if ok2 then
                model = rig
            end
        end
    end
    if not model then
        self:_log("Warn", "Merge Egg artillery commander avatar failed", {
            userId = userId,
            slot = slot,
        })
        return
    end
    model.Name = self:_commanderModelName(slot)
    model:SetAttribute("MergeArtilleryCommander", true)
    model:SetAttribute("MergeTowerSlot", slot)
    if cannon then
        model:SetAttribute("MergeTowerCannonName", cannon.Name)
    elseif pad then
        model:SetAttribute("MergeTowerPadName", pad.Name)
    end
    local humanoid = model:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid.DisplayName = commander.display_name or "Artillery Commander"
        humanoid.WalkSpeed = 0
        humanoid.JumpPower = 0
        humanoid.AutoJumpEnabled = false
        local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
        animator.Parent = humanoid
        local idle = Instance.new("Animation")
        idle.AnimationId =
            requiredAssetUri(commander.idle_animation, "team.edge_towers.commander.idle_animation")
        local ok, track = pcall(function()
            return animator:LoadAnimation(idle)
        end)
        if ok and track then
            track.Looped = true
            track:Play()
        end
    end
    self:_groundEngineerOnFloor(model, stand)
    local root = model:FindFirstChild("HumanoidRootPart")
    if root then
        root.Anchored = true
        pcall(function()
            root:SetNetworkOwner(nil)
        end)
    end
    self:_setVendorPosted(model, false)
    model.Parent = folder
    self:_setEngineerPassthrough(model)
    local promptHost = root or firstBasePart(model)
    local prompt = self:_attachPrompt(
        promptHost,
        ARTILLERY_COMMANDER_PROMPT_NAME,
        commander.action_text or "Talk",
        commander.object_text or commander.display_name or "Artillery Commander",
        function(player)
            self:_openCannonMenu(player, slot)
        end
    )
    if prompt then
        prompt.HoldDuration = 0
        prompt.MaxActivationDistance = math.max(4, tonumber(commander.max_distance) or 16)
    end
    self:_setVendorPosted(model, self:_tutorialVendorsReady(record, "artillery", slot))
end

function MergeEggPrototypeService:_cannonMenuState(record, slot)
    local cfg = self:_edgeTowerConfig()
    local state = self:_normalizeTowerState(record)
    slot = MergeTowerProgression.normalizeSlot(slot)
    local family, tier = MergeTowerProgression.slotFamily(state, slot)
    local price = MergeTowerProgression.actionCost(cfg)
    local currentWave = record and math.max(1, math.floor(tonumber(record.waveIndex) or 0)) or 1
    local wallet = record
            and self._economyService
            and self._economyService:GetCurrency(record.player, price.currency)
        or 0
    return {
        slot = slot,
        family = family,
        tier = tier,
        owned = MergeTowerProgression.menuOwned(state, slot),
        installed = family ~= nil,
        maximumTier = math.max(1, math.floor(tonumber(cfg.maximum_tier) or 4)),
        families = MergeTowerProgression.familiesForSlot(slot, self._config.tier_art),
        unlocked = MergeTowerProgression.isUnlocked(MergeTowerProgression.unlockWave(cfg), cfg),
        unlockWave = MergeTowerProgression.unlockWave(cfg),
        productionUnlockWave = math.max(1, math.floor(tonumber(cfg.unlock_wave) or 10)),
        tutorialIntermissionWave = math.max(
            1,
            math.floor(tonumber(cfg.tutorial_intermission_wave) or 10)
        ),
        playtestUnlock = cfg.playtest_unlock_enabled == true,
        currentWave = currentWave,
        actionCost = price.amount,
        currency = price.currency,
        wallet = math.max(0, math.floor(tonumber(wallet) or 0)),
        unlockCosts = self:_unlockCostMap(cfg),
        gemWallet = self:_tutorialGemWallet(record),
    }
end

function MergeEggPrototypeService:_canUseCannonMenu(player, slot)
    local record = self:_recordFor(player)
    local root = characterRoot(player)
    local folder = record and record.world and record.world:FindFirstChild("MergeEggTowers")
    if not (record and root and folder) then
        return false, "cannon_station_unavailable"
    end
    local wanted = slot and MergeTowerProgression.normalizeSlot(slot) or nil
    local commander = self:_findArtilleryCommander(folder, wanted)
    if not commander or commander:GetAttribute("MergeVendorPosted") ~= true then
        return false, "cannon_station_unavailable"
    end
    local part = firstBasePart(commander)
    if not part then
        return false, "cannon_station_unavailable"
    end
    local closest = (root.Position - part.Position).Magnitude
    local maximum = math.max(4, tonumber(self:_commanderConfig().max_distance) or 16) + 4
    if closest > maximum then
        return false, "cannon_station_too_far"
    end
    return true, nil, closest
end

function MergeEggPrototypeService:_openCannonMenu(player, slot)
    local record = self:_recordFor(player)
    if not (record and record.player == player and record.terminal ~= true) then
        return false, "not_active_encounter"
    end
    slot = MergeTowerProgression.normalizeSlot(slot)
    if not self:_tutorialVendorsReady(record, "artillery", slot) then
        return false, "vendor_not_ready"
    end
    local accessOk, accessReason = self:_canUseCannonMenu(player, slot)
    if not accessOk then
        return false, accessReason
    end
    if
        record.tutorialActive == true
        and record.tutorialStep == "talk_commander"
        and slot == self:_tutorialWorkshopCannonSlot()
    then
        record.tutorialTalkedCommander = true
        self:_updateTutorial(record, os.clock(), true)
    end
    Signals.MergeEggPrototypeBoardResult:FireClient(player, {
        ok = true,
        action = "open_cannon_menu",
        value = self:_cannonMenuState(record, slot),
    })
    return true
end

function MergeEggPrototypeService:_clearTowerTestPrompts(cannon)
    if not cannon then
        return
    end
    local staleNames = {
        TOWER_SIZE_PROMPT_NAME,
        TOWER_FIRE_PROMPT_NAME,
        TOWER_SIZE_LABEL_NAME,
    }
    for _, descendant in ipairs(cannon:GetDescendants()) do
        for _, name in ipairs(staleNames) do
            if descendant.Name == name then
                descendant:Destroy()
            end
        end
    end
    local host = cannon.Parent and cannon.Parent:FindFirstChild(cannon.Name .. "_Preview")
    if host then
        host:Destroy()
    end
end

function MergeEggPrototypeService:_towerRecoilSpec()
    local _, shot = self:_edgeTowerConfig()
    local recoil = type(shot.recoil) == "table" and shot.recoil or {}
    return {
        duration = requiredConfigNumber(recoil.duration, "team.edge_towers.shot.recoil.duration"),
        height = requiredConfigNumber(recoil.height, "team.edge_towers.shot.recoil.height"),
        peakAt = requiredConfigNumber(recoil.peak_at, "team.edge_towers.shot.recoil.peak_at"),
        shake = requiredConfigNumber(recoil.shake, "team.edge_towers.shot.recoil.shake"),
    }
end

function MergeEggPrototypeService:_towerRecoilUntil(cannon)
    return tonumber(cannon and cannon:GetAttribute("MergeTowerRecoilUntil"))
end

function MergeEggPrototypeService:_towerRecoilActive(cannon, now)
    local untilAt = self:_towerRecoilUntil(cannon)
    return untilAt ~= nil and now < untilAt
end

function MergeEggPrototypeService:_beginTowerRecoil(cannon, now)
    if not cannon then
        return
    end
    local recoil = self:_towerRecoilSpec()
    if recoil.duration <= 0 then
        return
    end
    cannon:SetAttribute("MergeTowerRecoilRestCFrame", cannon:GetPivot())
    cannon:SetAttribute("MergeTowerRecoilStartedAt", now)
    cannon:SetAttribute("MergeTowerRecoilUntil", now + recoil.duration)
end

function MergeEggPrototypeService:_clearTowerRecoil(cannon)
    if not cannon then
        return
    end
    local rest = cannon:GetAttribute("MergeTowerRecoilRestCFrame")
    if typeof(rest) == "CFrame" then
        cannon:PivotTo(rest)
    end
    cannon:SetAttribute("MergeTowerRecoilRestCFrame", nil)
    cannon:SetAttribute("MergeTowerRecoilStartedAt", nil)
    cannon:SetAttribute("MergeTowerRecoilUntil", nil)
end

function MergeEggPrototypeService:_stepOneTowerRecoil(cannon, now)
    if not (cannon and cannon:IsA("Model")) then
        return
    end
    local untilAt = self:_towerRecoilUntil(cannon)
    if untilAt == nil then
        return
    end
    local rest = cannon:GetAttribute("MergeTowerRecoilRestCFrame")
    if typeof(rest) ~= "CFrame" or now >= untilAt then
        self:_clearTowerRecoil(cannon)
        return
    end
    local started = tonumber(cannon:GetAttribute("MergeTowerRecoilStartedAt")) or now
    local recoil = self:_towerRecoilSpec()
    local alpha = 0
    if recoil.duration > 0 then
        alpha = (now - started) / recoil.duration
    end
    local lift =
        MergeTowerBallistics.recoilHeight(alpha, recoil.height, recoil.peakAt, recoil.shake)
    cannon:PivotTo(rest + Vector3.new(0, lift, 0))
end

function MergeEggPrototypeService:_stepTowerRecoil(record, now)
    local world = record and record.world
    local folder = world and world:FindFirstChild("MergeEggTowers")
    if not folder then
        return
    end
    for _, cannon in ipairs(folder:GetChildren()) do
        if cannon:IsA("Model") and cannon:GetAttribute("MergeTowerSpawned") == true then
            self:_stepOneTowerRecoil(cannon, now)
        end
    end
end

function MergeEggPrototypeService:_aimCannonAtLaneTarget(record, cannon)
    local world = (record and record.world) or self:_worldForCannon(cannon)
    if not (world and cannon) then
        return nil
    end
    local _, shot = self:_edgeTowerConfig()
    local look = self:_towerGateLook(world, cannon:GetPivot().Position)
    local origin = self:_towerMuzzle(cannon, look)
    if not origin then
        return nil
    end
    look = self:_towerGateLook(world, origin) or look
    local role = string.lower(tostring(cannon:GetAttribute("MergeTowerRole") or ""))
    local target = self:_towerAimTarget(record, origin, look, role)
    local apex = requiredConfigNumber(shot.apex_height, "team.edge_towers.shot.apex_height")
    if target then
        local fire = self:_towerPlanarAim(origin, target) or look
        self:_aimTowerCannon(cannon, origin, target, apex)
        origin = self:_towerMuzzle(cannon, fire) or origin
    else
        self:_faceCannonDownLane(cannon, world)
    end
    return world, origin, target, apex
end

function MergeEggPrototypeService:_stepTowerAim(record, now)
    local world = record and record.world
    local folder = world and world:FindFirstChild("MergeEggTowers")
    if not folder then
        return
    end
    now = tonumber(now) or os.clock()
    for _, cannon in ipairs(folder:GetChildren()) do
        if
            cannon:IsA("Model")
            and cannon:GetAttribute("MergeTowerSpawned") == true
            and not self:_towerRecoilActive(cannon, now)
        then
            self:_aimCannonAtLaneTarget(record, cannon)
        end
    end
end

function MergeEggPrototypeService:_attachHealFire(host, color, opts)
    opts = type(opts) == "table" and opts or {}
    local emitter = Instance.new("ParticleEmitter")
    emitter.Name = opts.name or "HealFlame"
    emitter.Color = ColorSequence.new(color, Color3.fromRGB(210, 255, 180))
    emitter.LightEmission = 0.9
    emitter.LightInfluence = 0
    local _, shot = self:_edgeTowerConfig()
    emitter.Texture =
        requiredAssetUri(shot.heal_fire_texture, "team.edge_towers.shot.heal_fire_texture")
    emitter.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, opts.size0 or 1.1),
        NumberSequenceKeypoint.new(0.3, opts.size1 or 1.7),
        NumberSequenceKeypoint.new(1, 0),
    })
    emitter.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.1),
        NumberSequenceKeypoint.new(0.65, 0.35),
        NumberSequenceKeypoint.new(1, 1),
    })
    emitter.Lifetime = NumberRange.new(opts.life0 or 0.22, opts.life1 or 0.48)
    emitter.Rate = opts.rate or 52
    emitter.Speed = NumberRange.new(opts.speed0 or 3, opts.speed1 or 8)
    emitter.SpreadAngle = Vector2.new(opts.spread or 22, opts.spread or 22)
    emitter.Acceleration = opts.acceleration or Vector3.new(0, 12, 0)
    emitter.EmissionDirection = opts.direction or Enum.NormalId.Top
    emitter.Rotation = NumberRange.new(-20, 20)
    emitter.RotSpeed = NumberRange.new(-40, 40)
    emitter.Parent = host
    return emitter
end

function MergeEggPrototypeService:_playHealMuzzleFlame(cannon, origin, look, color)
    if not (cannon and typeof(origin) == "Vector3") then
        return
    end
    local host = Instance.new("Part")
    host.Name = "MergeEggHealMuzzleFlame"
    host.Anchored = true
    host.CanCollide = false
    host.CanQuery = false
    host.CanTouch = false
    host.CastShadow = false
    host.Transparency = 1
    host.Size = Vector3.new(0.35, 0.35, 0.35)
    local aim = look
    if not aim or aim.Magnitude < 0.001 then
        aim = Vector3.new(1, 0, 0)
    else
        aim = Vector3.new(aim.X, 0, aim.Z)
        if aim.Magnitude < 0.001 then
            aim = Vector3.new(1, 0, 0)
        else
            aim = aim.Unit
        end
    end
    host.CFrame = CFrame.lookAt(origin, origin + aim)
    host.Parent = cannon
    local emitter = self:_attachHealFire(host, color, {
        name = "MuzzleFlame",
        rate = 0,
        size0 = 1.4,
        size1 = 2.2,
        speed0 = 10,
        speed1 = 18,
        spread = 16,
        life0 = 0.18,
        life1 = 0.36,
        acceleration = Vector3.new(0, 16, 0),
        direction = Enum.NormalId.Front,
    })
    emitter:Emit(22)
    Debris:AddItem(host, 0.7)
end

function MergeEggPrototypeService:_dressTowerShotFlame(part, role, color)
    if string.lower(tostring(role or "")) == "heal" then
        self:_attachHealFire(part, color, {
            name = "FireballFlame",
            rate = 56,
            size0 = 1.2,
            size1 = 1.9,
        })
        return
    end
    local fire = Instance.new("Fire")
    fire.Name = "FireballFlame"
    fire.Size = math.max(4, part.Size.X * 4)
    fire.Heat = 10
    fire.Parent = part
end

function MergeEggPrototypeService:_fireTowerShot(record, cannon, now)
    local world = (record and record.world) or self:_worldForCannon(cannon)
    if not (world and cannon) then
        return false
    end
    local _, shot = self:_edgeTowerConfig()
    local look = self:_towerGateLook(world, cannon:GetPivot().Position)
    local origin = self:_towerMuzzle(cannon, look)
    if not origin then
        return false
    end
    look = self:_towerGateLook(world, origin) or look
    local role = string.lower(tostring(cannon:GetAttribute("MergeTowerRole") or ""))
    local target = self:_towerShotTarget(record, origin, look, role)
    if not target then
        local skip = "no_lane_target"
        if role == "heal" then
            skip = "no_injured_pet"
        elseif role == "rage" then
            skip = "no_combat_pet"
        end
        cannon:SetAttribute("MergeTowerSkipReason", skip)
        return false
    end
    cannon:SetAttribute("MergeTowerSkipReason", "")
    local apex = requiredConfigNumber(shot.apex_height, "team.edge_towers.shot.apex_height")
    local fire = self:_towerPlanarAim(origin, target) or look
    self:_aimTowerCannon(cannon, origin, target, apex)
    origin = self:_towerMuzzle(cannon, fire) or origin
    local folder = self:_towerFolder(world, "MergeEggTowerShots")
    local diameter = requiredConfigNumber(shot.diameter, "team.edge_towers.shot.diameter")
    local part = Instance.new("Part")
    part.Name = "MergeEggTowerFireball"
    part.Shape = Enum.PartType.Ball
    part.Anchored = true
    part.CanCollide = false
    part.CanTouch = false
    part.CanQuery = false
    part.CastShadow = false
    part.Material = Enum.Material.Neon
    part.Size = Vector3.new(diameter, diameter, diameter)
    part.Color = self:_towerShotColor(world, role)
    part.CFrame = CFrame.new(origin)
    local light = Instance.new("PointLight")
    light.Name = "FireballLight"
    light.Brightness = 2.8
    light.Range = 18
    light.Color = part.Color
    light.Parent = part
    self:_dressTowerShotFlame(part, role, part.Color)
    part.Parent = folder
    if role == "heal" then
        self:_playHealMuzzleFlame(cannon, origin, look, part.Color)
    end
    local flight = {
        part = part,
        origin = origin,
        target = target,
        apex = apex,
        role = role,
        record = record,
        cannon = cannon,
        startedAt = now,
        duration = requiredConfigNumber(
            shot.flight_seconds,
            "team.edge_towers.shot.flight_seconds"
        ),
        landSeconds = requiredConfigNumber(shot.land_seconds, "team.edge_towers.shot.land_seconds"),
        impact = self:_towerImpactKind(role),
        bloomScale = requiredConfigNumber(shot.bloom_scale, "team.edge_towers.shot.bloom_scale"),
        startDiameter = diameter,
    }
    self._towerShots = self._towerShots or {}
    self._towerShots[#self._towerShots + 1] = flight
    if record then
        record.towerShots = record.towerShots or {}
        record.towerShots[#record.towerShots + 1] = flight
    end
    self:_playCannonFire(cannon)
    self:_beginTowerRecoil(cannon, now)
    return true
end

function MergeEggPrototypeService:_stepTowerFire(record, now)
    local world = record and record.world
    local folder = world and world:FindFirstChild("MergeEggTowers")
    if not folder then
        return
    end
    local _, shot = self:_edgeTowerConfig()
    local jitter =
        requiredConfigNumber(shot.interval_jitter, "team.edge_towers.shot.interval_jitter")
    local rng = record.random or Random.new()
    local function fireDelay(cannon)
        local interval = self:_towerFireInterval(record, cannon, shot)
        if jitter <= 0 then
            return interval
        end
        return math.max(0, interval + rng:NextNumber(-jitter, jitter))
    end
    local index = 0
    for _, cannon in ipairs(folder:GetChildren()) do
        if cannon:IsA("Model") and cannon:GetAttribute("MergeTowerSpawned") == true then
            index += 1
            local interval = self:_towerFireInterval(record, cannon, shot)
            local nextAt = tonumber(cannon:GetAttribute("MergeTowerNextFireAt"))
            -- Spawn stamps 0 on both pads, which used to skip the stagger and fire in lockstep.
            if nextAt == nil or nextAt <= 0 then
                nextAt = now + (index - 1) * (interval * 0.5) + rng:NextNumber(0, jitter)
                cannon:SetAttribute("MergeTowerNextFireAt", nextAt)
            end
            if now >= nextAt then
                if self:_fireTowerShot(record, cannon, now) then
                    cannon:SetAttribute("MergeTowerNextFireAt", now + fireDelay(cannon))
                end
            end
        end
    end
end

function MergeEggPrototypeService:_stripTowerShotFlame(part)
    if not part then
        return
    end
    for _, child in ipairs(part:GetChildren()) do
        if child.Name == "FireballFlame" or child:IsA("Fire") or child:IsA("ParticleEmitter") then
            child:Destroy()
        end
    end
end

function MergeEggPrototypeService:_beginTowerShotImpact(flight, now)
    local part = flight and flight.part
    if not (part and part.Parent) then
        return false
    end
    local kind = tostring(flight.impact or "linger")
    if kind == "vanish" then
        part:Destroy()
        flight.part = nil
        return false
    end
    if kind == "bloom" then
        local _, shot = self:_edgeTowerConfig()
        flight.landSeconds =
            requiredConfigNumber(shot.bloom_seconds, "team.edge_towers.shot.bloom_seconds")
        flight.startDiameter = tonumber(flight.startDiameter) or part.Size.X
        self:_stripTowerShotFlame(part)
        if flight.landSeconds <= 0 then
            part:Destroy()
            flight.part = nil
            return false
        end
        self:_stepTowerShotBloom(flight, now)
        return true
    end
    return true
end

function MergeEggPrototypeService:_stepTowerShotBloom(flight, now)
    local part = flight and flight.part
    if not (part and part.Parent and flight.landedAt) then
        return
    end
    -- Luau assert returns every argument it receives. Resolve first so the diagnostic string is
    -- never forwarded to variadic math.max as an accidental third value.
    local landSeconds =
        assert(tonumber(flight.landSeconds), "tower shot state requires landSeconds")
    local duration = math.max(1e-3, landSeconds)
    local alpha = (now - flight.landedAt) / duration
    local diameter = MergeTowerBallistics.bloomScale(alpha, flight.startDiameter, flight.bloomScale)
    local fade = MergeTowerBallistics.bloomFade(alpha)
    part.Size = Vector3.new(diameter, diameter, diameter)
    part.Transparency = fade
    local light = part:FindFirstChild("FireballLight")
    if light and light:IsA("PointLight") then
        light.Brightness = 2.8 * (1 - fade)
        light.Range = 18 * (1 - fade * 0.45)
    end
end

function MergeEggPrototypeService:_stepTowerShots(now)
    local remaining = {}
    for _, flight in ipairs(self._towerShots or {}) do
        local part = flight.part
        if part and part.Parent then
            if flight.landedAt then
                if flight.impact == "bloom" then
                    self:_stepTowerShotBloom(flight, now)
                end
                if now < flight.landedAt + flight.landSeconds then
                    remaining[#remaining + 1] = flight
                else
                    part:Destroy()
                end
            else
                local duration = flight.duration
                local alpha = (now - flight.startedAt) / duration
                local origin = flight.origin
                local target = flight.target
                if alpha >= 1 then
                    part.CFrame = CFrame.new(target)
                    flight.landedAt = now
                    self:_playCannonImpact(target, part.Parent)
                    self:_playTowerLandingVisual(flight, target)
                    if self:_beginTowerShotImpact(flight, now) then
                        remaining[#remaining + 1] = flight
                    end
                else
                    local x, y, z = MergeTowerBallistics.point(
                        origin.X,
                        origin.Y,
                        origin.Z,
                        target.X,
                        target.Y,
                        target.Z,
                        flight.apex,
                        alpha
                    )
                    part.CFrame = CFrame.new(x, y, z)
                    remaining[#remaining + 1] = flight
                end
            end
        end
    end
    self._towerShots = remaining
end

function MergeEggPrototypeService:_placeCaptainAtStation(model, world, spawn, slot)
    if not (model and spawn) then
        return
    end
    local layout = type(self._config.station_layout) == "table" and self._config.station_layout
        or {}
    local padCFrame = self:_stationPadCFrame(world, slot, spawn)
    local look = Vector3.new(spawn.CFrame.LookVector.X, 0, spawn.CFrame.LookVector.Z)
    if look.Magnitude < 0.001 then
        look = Vector3.new(1, 0, 0)
    else
        look = look.Unit
    end
    -- Spawn looks at the gate. Stand on that side so the board/work area
    -- can read the egg without the captain in front of it.
    local front = look * (tonumber(layout.captain_front_offset) or 4.5)
    local standPoint = padCFrame.Position + front
    local lookAt = CFrame.lookAt(standPoint, standPoint + look)
    model:PivotTo(lookAt)
    local box, size = model:GetBoundingBox()
    local bottom = box.Position.Y - size.Y * 0.5
    local floorTop = padCFrame.Position.Y
    local pads = world and world:FindFirstChild("MergeEggDeploymentPads")
    local pad = pads and pads:FindFirstChild(string.format("DeploymentPad%02d", slot))
    if pad and pad:IsA("BasePart") then
        floorTop = pad.Position.Y + pad.Size.Y * 0.5
    end
    model:PivotTo(model:GetPivot() + Vector3.new(0, floorTop - bottom, 0))
    local root = model:FindFirstChild("HumanoidRootPart")
    if root then
        root.Anchored = true
    end
end

function MergeEggPrototypeService:_ensureEggBoardControls(world)
    local worldCfg = self._config.world or {}
    local playerSpawn = findNamedPart(world, worldCfg.player_spawn or "PlayerSpawn")
    if not playerSpawn then
        return
    end
    local controlWall = self:_findControlWall(world)

    local function ensureControl(name, position, lookAt, color, title, subtitle)
        local existing = findNamedPart(world, name)
        if existing then
            existing.CFrame = CFrame.lookAt(position, lookAt)
            return existing
        end
        local control = Instance.new("Part")
        control.Name = name
        control.Anchored = true
        control.CanCollide = false
        control.CanTouch = false
        control.CanQuery = true
        control.Size = Vector3.new(22, 8, 1)
        control.CFrame = CFrame.lookAt(position, lookAt)
        control.Color = color
        control.Material = Enum.Material.Neon
        control.TopSurface = Enum.SurfaceType.Smooth
        control.BottomSurface = Enum.SurfaceType.Smooth
        control:SetAttribute("MergeEggRuntimeBoardControl", true)
        control.Parent = world

        local surface = Instance.new("SurfaceGui")
        surface.Name = name .. "Surface"
        surface.Face = Enum.NormalId.Front
        surface.CanvasSize = Vector2.new(720, 280)
        surface.LightInfluence = 0
        surface.Parent = control
        local heading = Instance.new("TextLabel")
        heading.BackgroundTransparency = 1
        heading.Position = UDim2.fromScale(0.04, 0.08)
        heading.Size = UDim2.fromScale(0.92, 0.52)
        heading.Font = Enum.Font.GothamBlack
        heading.Text = title
        heading.TextColor3 = Color3.new(1, 1, 1)
        heading.TextScaled = true
        heading.Parent = surface
        local detail = Instance.new("TextLabel")
        detail.BackgroundTransparency = 1
        detail.Position = UDim2.fromScale(0.04, 0.62)
        detail.Size = UDim2.fromScale(0.92, 0.24)
        detail.Font = Enum.Font.GothamBold
        detail.Text = subtitle
        detail.TextColor3 = Color3.fromRGB(28, 35, 45)
        detail.TextScaled = true
        detail.Parent = surface
        return control
    end

    local base = playerSpawn.Position
    local createPos, createLook, upgradePos, upgradeLook, managePos, manageLook
    if controlWall then
        local land = findNamedPart(world, "LandStrip")
        local bayZ = land and land.Position.Z or 0
        local inward = Vector3.new(0, 0, bayZ >= controlWall.Position.Z and 1 or -1)
        local along = Vector3.new(1, 0, 0)
        local mid = controlWall.Position + inward * 1.6
        local y = controlWall.Position.Y
        createPos = mid - along * 13
        createPos = Vector3.new(createPos.X, y, createPos.Z)
        createLook = createPos + inward
        upgradePos = mid + along * 13
        upgradePos = Vector3.new(upgradePos.X, y, upgradePos.Z)
        upgradeLook = upgradePos + inward
        managePos = Vector3.new(mid.X, y, mid.Z)
        manageLook = managePos + inward
    else
        createPos = Vector3.new(base.X - 20, base.Y + 4, base.Z - 31.4)
        createLook = Vector3.new(base.X - 20, base.Y + 4, base.Z + 8)
        upgradePos = Vector3.new(base.X + 20, base.Y + 4, base.Z - 31.4)
        upgradeLook = Vector3.new(base.X + 20, base.Y + 4, base.Z + 8)
        managePos = Vector3.new(base.X - 48.4, base.Y + 10, base.Z + 18)
        manageLook = Vector3.new(base.X - 10, base.Y + 10, base.Z + 18)
    end

    local createControl = ensureControl(
        tostring(worldCfg.egg_create_control or "EggCreateControl"),
        createPos,
        createLook,
        Color3.fromRGB(104, 205, 94),
        "CREATE EARTH EGG",
        "100 WAYCOINS"
    )
    local baseUpgradeControl = ensureControl(
        tostring(worldCfg.egg_base_upgrade_control or "EggBaseUpgradeControl"),
        upgradePos,
        upgradeLook,
        Color3.fromRGB(238, 158, 58),
        "UPGRADE BASE EGG",
        "GRASS → ICE • 1,000 WAYCOINS"
    )
    local managementControl = ensureControl(
        tostring(worldCfg.egg_merge_control or "EggMergeControl"),
        managePos,
        manageLook,
        Color3.fromRGB(35, 42, 58),
        "MANAGEMENT",
        "COMBAT • HATCHERS • EGGS"
    )
    if controlWall then
        -- BUY EGG and SPAWN LEVEL already live inside the central management panel. Retain these
        -- two parts as invisible server-side proximity anchors, but never render duplicate wall
        -- buttons beside the real menu.
        for _, redundantControl in ipairs({ createControl, baseUpgradeControl }) do
            redundantControl.Transparency = 1
            redundantControl.CanCollide = false
            redundantControl.CanTouch = false
            redundantControl.CanQuery = false
            for _, child in ipairs(redundantControl:GetChildren()) do
                if child:IsA("SurfaceGui") then
                    child.Enabled = false
                end
            end
        end
        managementControl.Size = Vector3.new(14, 8, 0.6)
        managementControl.Material = Enum.Material.Neon
        for _, child in ipairs(managementControl:GetChildren()) do
            if child:IsA("SurfaceGui") then
                child.Enabled = true
            end
        end
    else
        for _, oldControl in ipairs({ createControl, baseUpgradeControl }) do
            oldControl.Transparency = 1
            oldControl.CanQuery = false
            for _, child in ipairs(oldControl:GetChildren()) do
                if child:IsA("SurfaceGui") then
                    child.Enabled = false
                end
            end
        end
        managementControl.Size = Vector3.new(38, 18, 1)
        managementControl.CFrame = CFrame.lookAt(managePos, manageLook)
        managementControl.Color = Color3.fromRGB(35, 42, 58)
        managementControl.Material = Enum.Material.Slate
    end
end

function MergeEggPrototypeService:_mergeBoardCapacity()
    local cfg = (self._config.team or {}).merge_board or {}
    local rows = math.max(1, math.floor(tonumber(cfg.rows) or 4))
    local columns = math.max(1, math.floor(tonumber(cfg.columns) or 4))
    return rows * columns
end

function MergeEggPrototypeService:_ensureDeploymentPads(world, record)
    local worldCfg = self._config.world or {}
    local spawn = findNamedPart(world, worldCfg.hatcher_spawn or "HatcherSpawn")
    if not spawn then
        return nil
    end
    local layout = type(self._config.station_layout) == "table" and self._config.station_layout
        or {}
    local padCfg = type(layout.deployment_pads) == "table" and layout.deployment_pads or {}
    local total = math.max(1, math.floor(tonumber(layout.total_positions) or 9))
    local size = math.max(2, tonumber(padCfg.size) or 6.6)
    local eggOffset = tonumber(padCfg.egg_offset) or 3
    local availableColor = rgbTriplet(padCfg.available_color, { 82, 145, 190 })
    local availableTransparency = math.clamp(tonumber(padCfg.available_transparency) or 0.3, 0, 1)
    local teamsBySlot = {}
    for order, teamCfg in ipairs(self:_activeTeamConfigs(record)) do
        local _, slot = stationXOffset(self._config, teamCfg, order)
        teamsBySlot[slot] = math.max(1, math.floor(tonumber(teamCfg.id) or order))
    end

    local pads = world:FindFirstChild("MergeEggDeploymentPads")
    if pads and not pads:IsA("Model") then
        pads:Destroy()
        pads = nil
    end
    if not pads then
        pads = Instance.new("Model")
        pads.Name = "MergeEggDeploymentPads"
        pads.Parent = world
    end
    pads:SetAttribute("MergeEggDeploymentPadCount", total)
    for slot = 1, total do
        local name = string.format("DeploymentPad%02d", slot)
        local pad = pads:FindFirstChild(name)
        if pad and not pad:IsA("BasePart") then
            pad:Destroy()
            pad = nil
        end
        if not pad then
            pad = Instance.new("Part")
            pad.Name = name
            pad.Parent = pads
        end
        local stationX = stationXOffset(self._config, { position_slot = slot }, slot)
        local teamId = teamsBySlot[slot]
        local expectedCFrame = spawn.CFrame * CFrame.new(stationX, 0.06, eggOffset)
        local authoredPad = self:_authoredHatcherPad(world, slot, expectedCFrame.Position)
        pad.Anchored = true
        pad.CanCollide = false
        pad.CanTouch = false
        pad.CanQuery = teamId ~= nil
        pad.Size = Vector3.new(size, 0.12, size)
        pad.CFrame = authoredPad and (authoredPad.CFrame * CFrame.new(0, 0.07, 0)) or expectedCFrame
        pad.Color = availableColor
        pad.Material = Enum.Material.Neon
        pad.Transparency = teamId and availableTransparency or 1
        pad:SetAttribute("MergeEggDeploymentPad", true)
        pad:SetAttribute("MergeEggPositionSlot", slot)
        pad:SetAttribute("MergeEggDeploymentTeamId", teamId)
        pad:SetAttribute("MergeEggDeploymentAvailable", teamId ~= nil)
        pad:SetAttribute("MergeEggDeploymentOccupied", false)
        pad:SetAttribute("MergeEggDeploymentTier", 0)
        pad:SetAttribute("MergeEggAuthoredStand", authoredPad and authoredPad:GetFullName() or nil)
    end
    for _, child in ipairs(pads:GetChildren()) do
        local slot = tonumber(child:GetAttribute("MergeEggPositionSlot"))
        if child:IsA("BasePart") and (not slot or slot < 1 or slot > total) then
            child:Destroy()
        end
    end
    return pads
end

function MergeEggPrototypeService:_syncDeploymentPad(team)
    local world = self:_worldFor(team and team.record)
    local pads = world and world:FindFirstChild("MergeEggDeploymentPads")
    if not (pads and team) then
        return
    end
    local _, slot = stationXOffset(self._config, team.config, team.id)
    local pad = pads:FindFirstChild(string.format("DeploymentPad%02d", slot))
    if not (pad and pad:IsA("BasePart")) then
        return
    end
    local layout = type(self._config.station_layout) == "table" and self._config.station_layout
        or {}
    local padCfg = type(layout.deployment_pads) == "table" and layout.deployment_pads or {}
    local tier = math.max(0, math.floor(tonumber(team.eggTier) or 0))
    local colors = type(((self._config.team or {}).merge_board or {}).slot_colors) == "table"
            and ((self._config.team or {}).merge_board or {}).slot_colors
        or {}
    local colorIndex = tier > 0 and ((tier - 1) % math.max(1, #colors) + 1) or nil
    pad.Color = colorIndex and rgbTriplet(colors[colorIndex], { 82, 145, 190 })
        or rgbTriplet(padCfg.available_color, { 82, 145, 190 })
    pad.Transparency = tier > 0 and math.clamp(tonumber(padCfg.occupied_transparency) or 0.14, 0, 1)
        or math.clamp(tonumber(padCfg.available_transparency) or 0.3, 0, 1)
    pad:SetAttribute("MergeEggDeploymentOccupied", tier > 0)
    pad:SetAttribute("MergeEggDeploymentTier", tier)
    pad:SetAttribute("MergeEggSlotColorIndex", colorIndex)
end

function MergeEggPrototypeService:_eggInventoryTotal(record)
    local total = 0
    for tier = 1, #self:_eggProgression(record) do
        total += self:_eggInventoryCount(record, tier)
    end
    return total
end

-- Build the same one-pass assignment that Equip Best will attempt, without mutating the board.
-- The client must not infer availability from "there is an egg somewhere on the board": an egg
-- below every deployed tier cannot be used, and advertising that state as green is a false promise.
function MergeEggPrototypeService:_equipBestPlan(record)
    if not record then
        return {}
    end

    local progression = self:_eggProgression(record)
    local inventory = {}
    for tier = 1, #progression do
        inventory[tier] = self:_eggInventoryCount(record, tier)
    end
    local teams = {}
    for _, team in ipairs(record.teams or {}) do
        teams[#teams + 1] = {
            id = team.id,
            tier = team.eggTier,
            available = team.id ~= nil
                and team.eggAdvanceInProgress ~= true
                and team.folder ~= nil
                and team.folder.Parent ~= nil,
        }
    end
    return MergeEggEquipBest.plan({
        maximumTier = #progression,
        inventory = inventory,
        teams = teams,
    })
end

function MergeEggPrototypeService:_ensureEquipBestControl(world, board, toward)
    local worldCfg = self._config.world or {}
    local cfg = (self._config.team or {}).merge_board or {}
    local boardRoot = board and board.PrimaryPart
    if not (world and boardRoot) then
        return nil
    end

    local resolvedToward = toward
    if not resolvedToward or resolvedToward.Magnitude < 0.001 then
        local hatcherSpawn = findNamedPart(world, worldCfg.hatcher_spawn or "HatcherSpawn")
        resolvedToward = hatcherSpawn
                and Vector3.new(
                    hatcherSpawn.Position.X - boardRoot.Position.X,
                    0,
                    hatcherSpawn.Position.Z - boardRoot.Position.Z
                )
            or Vector3.new(boardRoot.CFrame.LookVector.X, 0, boardRoot.CFrame.LookVector.Z)
    end
    resolvedToward = resolvedToward.Magnitude > 0.001 and resolvedToward.Unit
        or Vector3.new(0, 0, 1)

    local sizeCfg = type(cfg.equip_best_size) == "table" and cfg.equip_best_size or {}
    local width = math.max(6, tonumber(sizeCfg.x) or 14)
    local depth = math.max(3, tonumber(sizeCfg.z) or 5)
    local gap = math.max(0, tonumber(cfg.equip_best_gap) or 1.5)
    local rotationRadians = math.rad(tonumber(cfg.equip_best_rotation_degrees) or 90)
    local forwardHalfExtent = math.abs(math.sin(rotationRadians)) * width * 0.5
        + math.abs(math.cos(rotationRadians)) * depth * 0.5
    local center = boardRoot.Position
        + resolvedToward * (boardRoot.Size.Z * 0.5 + gap + forwardHalfExtent)
    center = Vector3.new(center.X, boardRoot.Position.Y + 0.11, center.Z)

    local name = tostring(worldCfg.equip_best_control or "EquipBestControl")
    local control = world:FindFirstChild(name)
    if control and not control:IsA("BasePart") then
        control:Destroy()
        control = nil
    end
    if not control then
        control = Instance.new("Part")
        control.Name = name
        control.Parent = world
    end
    control.Anchored = true
    control.CanCollide = false
    control.CanTouch = false
    control.CanQuery = true
    control.CastShadow = false
    control.Size = Vector3.new(width, 0.16, depth)
    control.CFrame = CFrame.lookAt(center, center + resolvedToward)
        * CFrame.Angles(0, rotationRadians, 0)
    control.Color = Color3.fromRGB(75, 190, 105)
    control.Material = Enum.Material.Neon
    control.Transparency = 0.04
    control:SetAttribute("MergeEggEquipBestControl", true)
    return control
end

function MergeEggPrototypeService:_ensureMergeBoard(world)
    local worldCfg = self._config.world or {}
    local boardName = tostring(worldCfg.merge_board or "MergeBoard")
    local cfg = (self._config.team or {}).merge_board or {}
    local rows = math.max(1, math.floor(tonumber(cfg.rows) or 4))
    local columns = math.max(1, math.floor(tonumber(cfg.columns) or 4))
    local playerSpawn = findNamedPart(world, worldCfg.player_spawn or "PlayerSpawn")
    if not playerSpawn then
        return nil
    end
    local slotSize = math.max(2, tonumber(cfg.slot_size) or 6.6)
    local gap = math.max(0, tonumber(cfg.slot_gap) or 0.6)
    local spacing = slotSize + gap
    local forward = tonumber(cfg.forward_offset) or 16
    local towardPart = findNamedPart(world, worldCfg.bulwark_line or "BulwarkLine")
    local toward = towardPart
            and Vector3.new(
                towardPart.Position.X - playerSpawn.Position.X,
                0,
                towardPart.Position.Z - playerSpawn.Position.Z
            )
        or Vector3.zero
    if toward.Magnitude < 0.001 then
        toward = Vector3.new(playerSpawn.CFrame.LookVector.X, 0, playerSpawn.CFrame.LookVector.Z)
    end
    toward = toward.Magnitude > 0.001 and toward.Unit or Vector3.new(0, 0, 1)
    local centerPosition = playerSpawn.Position + toward * forward
    local startPlatform = findNamedPart(world, worldCfg.start_platform or "StartPlatform")
    if cfg.anchor_to_start_platform_back_edge == true and startPlatform then
        local localToward = startPlatform.CFrame:VectorToObjectSpace(toward)
        local platformHalfDepth = math.abs(localToward.X) * startPlatform.Size.X * 0.5
            + math.abs(localToward.Z) * startPlatform.Size.Z * 0.5
        local boardDepth = rows * spacing + 1
        local platformBackEdge = startPlatform.Position - toward * platformHalfDepth
        centerPosition = platformBackEdge + toward * boardDepth * 0.5
    end
    centerPosition = Vector3.new(centerPosition.X, playerSpawn.Position.Y + 0.02, centerPosition.Z)
    local center = CFrame.lookAt(centerPosition, centerPosition + toward)
    local neutralColor = rgbTriplet(cfg.empty_slot_color, { 45, 52, 64 })

    local worldBoard = world:FindFirstChild(boardName)
    local authoredBoard = worldBoard
            and worldBoard:IsA("Model")
            and worldBoard:GetAttribute("MergeEggAuthoredBoard") == true
            and worldBoard
        or self:_authoredBayArtifact(world, "MergeBoards", "MergeBoard")
    if authoredBoard and worldBoard and worldBoard ~= authoredBoard then
        -- The portable bay carries a gameplay-hook board, while the dedicated place carries the
        -- finished visible board. Only one board may exist at runtime: the observer, drag/drop,
        -- inventory sync, and Equip Best all resolve world.MergeBoard.
        worldBoard:Destroy()
        worldBoard = nil
    end
    if authoredBoard and authoredBoard.Parent ~= world then
        authoredBoard.Name = boardName
        authoredBoard.Parent = world
    end
    local board = authoredBoard or worldBoard
    if board and not board:IsA("Model") then
        board:Destroy()
        board = nil
    end
    if not board then
        board = Instance.new("Model")
        board.Name = boardName
        board.Parent = world
    end
    local layoutChanged = board:GetAttribute("MergeEggBoardLayoutVersion") ~= 2
    board:SetAttribute("MergeEggRuntimeBoard", authoredBoard == nil)
    board:SetAttribute("MergeEggAuthoredBoard", authoredBoard ~= nil)
    board:SetAttribute("MergeEggBoardLayoutVersion", 2)
    board:SetAttribute("Rows", rows)
    board:SetAttribute("Columns", columns)
    local base = board:FindFirstChild("Base")
    if base and not base:IsA("BasePart") then
        base:Destroy()
        base = nil
    end
    if not base then
        base = Instance.new("Part")
        base.Name = "Base"
        base.Parent = board
    end
    base.Anchored = true
    base.CanCollide = false
    base.CanTouch = false
    base.CanQuery = false
    if not authoredBoard then
        base.Size = Vector3.new(columns * spacing + 1, 0.14, rows * spacing + 1)
        base.CFrame = center
    end
    base.Color = Color3.fromRGB(32, 38, 48)
    base.Material = Enum.Material.Slate
    base.Transparency = 0.08
    board.PrimaryPart = base
    -- Authored boards are map geometry. Adoption may rename/reparent one, but its saved Studio
    -- transform is authoritative and must not be replaced with a runtime-derived position.

    local slots = board:FindFirstChild("Slots")
    if slots and not slots:IsA("Folder") then
        slots:Destroy()
        slots = nil
    end
    if not slots then
        slots = Instance.new("Folder")
        slots.Name = "Slots"
        slots.Parent = board
        if authoredBoard then
            for index = 1, rows * columns do
                local authoredSlot = board:FindFirstChild(string.format("Slot%02d", index))
                if authoredSlot and authoredSlot:IsA("BasePart") then
                    authoredSlot.Parent = slots
                end
            end
        end
    end
    if #slots:GetChildren() ~= rows * columns then
        slots:ClearAllChildren()
        layoutChanged = true
    end
    for row = 1, rows do
        for column = 1, columns do
            local index = (row - 1) * columns + column
            local x = (column - (columns + 1) * 0.5) * spacing
            local z = (row - (rows + 1) * 0.5) * spacing
            local slotName = string.format("Slot%02d", index)
            local slot = slots:FindFirstChild(slotName)
            if slot and not slot:IsA("BasePart") then
                slot:Destroy()
                slot = nil
            end
            if not slot then
                slot = Instance.new("Part")
                slot.Name = slotName
                slot.Parent = slots
            end
            slot.Anchored = true
            slot.CanCollide = false
            slot.CanTouch = false
            slot.CanQuery = false
            if not authoredBoard then
                slot.Size = Vector3.new(slotSize, 0.12, slotSize)
                slot.CFrame = center * CFrame.new(x, 0.13, z)
            end
            slot.Color = neutralColor
            slot.Material = Enum.Material.Slate
            slot.Transparency = math.clamp(tonumber(cfg.empty_slot_transparency) or 0.08, 0, 1)
            slot:SetAttribute("MergeEggSlotIndex", index)
            slot:SetAttribute("MergeEggSlotColorIndex", nil)
        end
    end

    if not board:FindFirstChild("EggSigns") then
        local signs = Instance.new("Folder")
        signs.Name = "EggSigns"
        signs.Parent = board
    end
    if not board:FindFirstChild("Eggs") then
        local eggs = Instance.new("Folder")
        eggs.Name = "Eggs"
        eggs.Parent = board
    end
    if layoutChanged then
        board:SetAttribute("InventorySignature", nil)
    end
    self:_ensureEquipBestControl(world, board, toward)
    return board
end

function MergeEggPrototypeService:_syncMergeBoardEggs(record)
    local world = self:_worldFor(record)
    local board = world and self:_ensureMergeBoard(world)
    if not board then
        return
    end
    local progression = self:_eggProgression(record)
    local counts = {}
    local signatureParts = { record and record.runId or "idle" }
    local total = 0
    for tier = 1, #progression do
        counts[tier] = self:_eggInventoryCount(record, tier)
        total += counts[tier]
        signatureParts[#signatureParts + 1] = tostring(counts[tier])
    end
    local signature = table.concat(signatureParts, ":")
    if board:GetAttribute("InventorySignature") == signature then
        return
    end
    board:SetAttribute("InventorySignature", signature)

    local eggs = board:FindFirstChild("Eggs")
    if not eggs then
        eggs = Instance.new("Folder")
        eggs.Name = "Eggs"
        eggs.Parent = board
    end
    eggs:ClearAllChildren()
    local signs = board:FindFirstChild("EggSigns")
    if not signs then
        signs = Instance.new("Folder")
        signs.Name = "EggSigns"
        signs.Parent = board
    end
    signs:ClearAllChildren()
    local slotFolder = board:FindFirstChild("Slots")
    local slots = slotFolder and slotFolder:GetChildren() or {}
    table.sort(slots, function(a, b)
        return (tonumber(a:GetAttribute("MergeEggSlotIndex")) or 0)
            < (tonumber(b:GetAttribute("MergeEggSlotIndex")) or 0)
    end)

    local cfg = (self._config.team or {}).merge_board or {}
    local height = math.max(1, tonumber(cfg.egg_height) or 4.8)
    local signSize = math.max(1, tonumber(cfg.egg_sign_size) or 4.8)
    local signTransparency = math.clamp(tonumber(cfg.egg_sign_transparency) or 0.12, 0, 1)
    local colors = type(cfg.slot_colors) == "table" and cfg.slot_colors or {}
    local slotIndex = 0
    for tier, eggId in ipairs(progression) do
        for _ = 1, counts[tier] do
            slotIndex += 1
            local slot = slots[slotIndex]
            if not slot then
                break
            end
            local colorIndex = (tier - 1) % math.max(1, #colors) + 1
            local signColor = rgbTriplet(colors[colorIndex], { 100, 180, 255 })
            local sign = Instance.new("Part")
            sign.Name = string.format("EggSign%02d", slotIndex)
            sign.Shape = Enum.PartType.Cylinder
            sign.Size = Vector3.new(0.1, signSize, signSize)
            sign.CFrame = slot.CFrame
                * CFrame.new(0, slot.Size.Y * 0.5 + 0.06, 0)
                * CFrame.Angles(0, 0, math.pi * 0.5)
            sign.Color = signColor
            sign.Material = Enum.Material.Neon
            sign.Transparency = signTransparency
            sign.Anchored = true
            sign.CanCollide = false
            sign.CanTouch = false
            sign.CanQuery = false
            sign:SetAttribute("MergeEggBoardSlot", slotIndex)
            sign:SetAttribute("MergeEggSourceTier", tier)
            sign:SetAttribute("MergeEggSlotColorIndex", colorIndex)
            sign.Parent = signs
            slot:SetAttribute("MergeEggSlotColorIndex", colorIndex)

            local visual = cloneEggVisual(eggId, signColor, height, true)
            if visual then
                visual.Name = string.format("BoardEgg%02d", slotIndex)
                visual:SetAttribute("MergeEggBoardEgg", true)
                visual:SetAttribute("MergeEggBoardSlot", slotIndex)
                visual:SetAttribute("MergeEggSourceTier", tier)
                visual:SetAttribute("MergeEggSourceId", eggId)
                visual.Parent = eggs
                visual:PivotTo(
                    slot.CFrame
                        * CFrame.new(0, slot.Size.Y * 0.5 + height * 0.5, 0)
                        * CFrame.Angles(0, math.rad((slotIndex - 1) * 37), 0)
                )
            end
        end
    end
    local capacity = #slots
    board:SetAttribute("OccupiedSlots", math.min(total, capacity))
    board:SetAttribute("Capacity", capacity)
    board:SetAttribute("OverflowEggs", math.max(0, total - capacity))
    if world then
        world:SetAttribute("MergeBoardOccupiedSlots", math.min(total, capacity))
        world:SetAttribute("MergeBoardCapacity", capacity)
        world:SetAttribute("MergeBoardOverflowEggs", math.max(0, total - capacity))
    end
end

function MergeEggPrototypeService:_resolveWorld(bayId)
    local cfg = self._config.world or {}
    local maps = Workspace:FindFirstChild(tostring(cfg.maps_root or "Maps"))
    local template = maps and maps:FindFirstChild(tostring(cfg.model_name or "MergeEggPrototype"))
    local realmConfig = type(self._config.realm_layout) == "table" and self._config.realm_layout
        or {}
    if self._realm and realmConfig.enabled ~= false then
        local prepared, prepareReason = self._realm:Ensure(maps)
        if not prepared then
            self:_log("Warn", "Merge Egg realm preparation failed", { reason = prepareReason })
        end
    end
    local world = bayId and self._realm and self._realm:GetBay(bayId) or nil
    if not world and self._realm and realmConfig.enabled ~= false then
        local fallbackBayId = configuredAuthoringBayId(realmConfig)
            or tostring(realmConfig.primary_bay_id or "heaven_01")
        world = self._realm:GetBay(fallbackBayId)
    end
    if realmConfig.enabled == false then
        world = world or template
    end
    if world and world:IsA("Model") then
        self._world = world
        local hatcherControl = findNamedPart(world, cfg.hatcher_control)
        local controlPosition = cfg.hatcher_control_local_position
        local floor = findNamedPart(world, "LandStrip")
        if hatcherControl and floor and type(controlPosition) == "table" then
            local position = floor.CFrame:PointToWorldSpace(
                Vector3.new(
                    tonumber(controlPosition.x) or 0,
                    (tonumber(controlPosition.y) or hatcherControl.Position.Y) - floor.Position.Y,
                    tonumber(controlPosition.z) or -80
                )
            )
            hatcherControl.CFrame = CFrame.new(position) * hatcherControl.CFrame.Rotation
        end
        self:_ensureBreachLine(world)
        self:_ensureContainmentWalls(world)
        self:_ensureEggBoardControls(world)
        self:_ensureMergeBoard(world)
        self:_ensureDeploymentPads(world)
        return world
    end
    self:_log("Warn", "Merge Egg authored realm is missing or invalid", {
        expected = "Workspace." .. tostring(cfg.maps_root or "Maps") .. "." .. tostring(
            realmConfig.root_name or "MergeEggRealm"
        ),
        bay = bayId,
    })
    return nil
end

function MergeEggPrototypeService:_replacementQueueDepth(record)
    local depth = 0
    for _, team in ipairs(record and record.teams or {}) do
        depth += #(team.replacementQueue or {})
    end
    return depth
end

function MergeEggPrototypeService:_setWorldState(state, record)
    local world = self:_worldFor(record)
    if not world then
        return
    end
    world:SetAttribute("PrototypeState", state)
    world:SetAttribute(
        "CombatCadenceMultiplier",
        combatCadenceMultiplier(self._config)
            * self:_managementUpgradeMultiplier(record, "fire_rate")
    )
    world:SetAttribute(
        "UpgradeExperimentChannel",
        record and record.upgradeExperimentChannel or nil
    )
    world:SetAttribute(
        "UpgradeExperimentMultiplier",
        record and record.upgradeExperimentMultiplier or 1
    )
    world:SetAttribute(
        "UpgradeExperimentPercent",
        record
                and math.floor(
                    (math.max(1, tonumber(record.upgradeExperimentMultiplier) or 1) - 1) * 100 + 0.5
                )
            or 0
    )
    world:SetAttribute("UpgradeExperimentAttempt", record and record.upgradeExperimentAttempt or 0)
    world:SetAttribute("UpgradeSweepRunning", self._upgradeSweepRunning == true)
    world:SetAttribute("UpgradeSweepPhase", self._upgradeSweepPhase)
    world:SetAttribute(
        "UpgradeSweepResults",
        HttpService:JSONEncode(self._upgradeSweepResults or {})
    )
    world:SetAttribute("ActivePlayer", record and record.player.Name or nil)
    world:SetAttribute("ActiveRunId", record and record.runId or nil)
    local progress = record and self:_mergeDefenseProgress(record.player)
    world:SetAttribute("MergeEggTutorialRequired", self:_tutorialRequired(record))
    world:SetAttribute(
        "MergeEggTutorialCompleted",
        progress and progress.tutorial_completed == true or false
    )
    world:SetAttribute("MergeEggTutorialActive", record and record.tutorialActive == true)
    world:SetAttribute("MergeEggTutorialStep", record and record.tutorialStep or nil)
    world:SetAttribute(
        "MergeEggTutorialUsesAutoCollector",
        record and record.tutorialUsesAutoCollector == true
    )
    world:SetAttribute("MergeEggTutorialPaused", record and record.tutorialActive == true or false)
    world:SetAttribute("MergeEggTutorialRequiredEggs", self:_tutorialRequiredEggs())
    world:SetAttribute("MergeEggTutorialEggsCreated", record and record.eggsCreated or 0)
    world:SetAttribute("MergeEggTutorialUpgradeCoinTarget", self:_tutorialUpgradeCoinTarget())
    world:SetAttribute(
        "MergeEggTutorialUpgradeWallet",
        record and self:_tutorialWallet(record) or 0
    )
    world:SetAttribute("MergeEggTutorialUpgradeCreateNeed", self:_tutorialUpgradeCreateCount())
    world:SetAttribute(
        "MergeEggTutorialUpgradeCreated",
        record and math.max(0, (record.eggsCreated or 0) - (record.upgradeBeatEggsCreated or 0))
            or 0
    )
    world:SetAttribute(
        "MergeEggTutorialPositionsFilled",
        record and self:_initializedHatcherCount(record) or 0
    )
    world:SetAttribute("MergeEggTutorialCombinationComplete", self:_tutorialHasCombination(record))
    local engineerAt
    if record and self:_tutorialVendorsReady(record, "bulwark") then
        local wanted = self:_tutorialWorkshopSlot()
        local along = "right"
        for _, post in ipairs(self:_engineerPosts()) do
            if post.slot == wanted then
                along = post.along
                break
            end
        end
        local stand = self:_engineerStandCFrame(world, wanted, along)
        if stand then
            engineerAt = stand.Position
        end
    end
    world:SetAttribute("MergeEggTutorialEngineerAt", engineerAt)
    local commanderAt
    if record and self:_tutorialVendorsReady(record, "artillery") then
        local pad = self:_padForSlot(world, self:_tutorialWorkshopCannonSlot())
        local stand = pad and self:_commanderStandCFrame(world, pad)
        if stand then
            commanderAt = stand.Position
        end
    end
    world:SetAttribute("MergeEggTutorialCommanderAt", commanderAt)
    local quartermasterAt
    if record and self:_tutorialVendorsReady(record, "quartermaster") then
        local shop = self:_findPotionShop(world)
        local stand = shop and self:_quartermasterStandCFrame(world, shop)
        if stand then
            quartermasterAt = stand.Position
        end
    end
    world:SetAttribute("MergeEggTutorialQuartermasterAt", quartermasterAt)
    local rebirth = self:_rebirthStatus(record)
    local managementDamage = self:_managementUpgradeMultiplier(record, "damage")
    local alliedDamage =
        MergeEggDamageScope.additiveUpgradeMultiplier(managementDamage, rebirth.damageMultiplier)
    local nextRebirthDamage =
        MergeEggRebirth.damageMultiplier(self._config.rebirth, rebirth.count + 1)
    local nextAlliedDamage =
        MergeEggDamageScope.additiveUpgradeMultiplier(managementDamage, nextRebirthDamage)
    world:SetAttribute("MergeDefenseRebirthCount", rebirth.count)
    world:SetAttribute("MergeDefenseRebirthRank", rebirth.rank)
    world:SetAttribute("MergeDefenseRebirthDamageMultiplier", rebirth.damageMultiplier)
    world:SetAttribute("MergeDefenseManagementDamageMultiplier", managementDamage)
    world:SetAttribute("MergeDefenseAlliedDamageMultiplier", alliedDamage)
    world:SetAttribute("MergeDefenseNextRebirthDamageMultiplier", nextRebirthDamage)
    world:SetAttribute("MergeDefenseNextAlliedDamageMultiplier", nextAlliedDamage)
    world:SetAttribute("MergeDefenseRebirthCannonPowerMultiplier", rebirth.scaling.cannonPower)
    world:SetAttribute("MergeDefenseRebirthCannonRadiusMultiplier", rebirth.scaling.cannonRadius)
    world:SetAttribute("MergeDefenseRebirthBulwarkPowerMultiplier", rebirth.scaling.bulwarkPower)
    world:SetAttribute("MergeDefenseRebirthBulwarkRadiusMultiplier", rebirth.scaling.bulwarkRadius)
    world:SetAttribute("MergeDefenseRebirthCoinMultiplier", rebirth.scaling.coinAmount)
    world:SetAttribute("MergeDefenseRebirthGemMultiplier", rebirth.scaling.gemAmount)
    world:SetAttribute("MergeDefenseRebirthGemChanceMultiplier", rebirth.scaling.gemChance)
    world:SetAttribute("MergeDefenseRebirthMaxed", rebirth.maxed)
    world:SetAttribute("MergeDefenseRebirthCost", rebirth.price and rebirth.price.amount or nil)
    world:SetAttribute(
        "MergeDefenseRebirthCurrency",
        rebirth.price and rebirth.price.currency or nil
    )
    world:SetAttribute("MergeDefenseRebirthRequirementMet", rebirth.requirementMet)
    world:SetAttribute("MergeDefenseRebirthMinimumEggTier", rebirth.minimumDeployedTier)
    local personalProgression = self:_personalHatchProgression(record)
    local personalRules = self:_personalHatchRules()
    local personalTier = MergeEggPlayerCombat.highestPersonalHatchTier(
        personalProgression,
        rebirth.count,
        personalRules
    )
    local nextPersonalTier = MergeEggPlayerCombat.highestPersonalHatchTier(
        personalProgression,
        rebirth.count + 1,
        personalRules
    )
    local personalEggId = personalProgression[personalTier]
    local nextPersonalEggId = personalProgression[nextPersonalTier]
    world:SetAttribute("MergeDefensePersonalEggTier", personalTier)
    world:SetAttribute("MergeDefensePersonalEggId", personalEggId)
    world:SetAttribute("MergeDefensePersonalEggName", self:_eggDisplayName(personalEggId))
    world:SetAttribute("MergeDefenseNextPersonalEggTier", nextPersonalTier)
    world:SetAttribute("MergeDefenseNextPersonalEggId", nextPersonalEggId)
    world:SetAttribute("MergeDefenseNextPersonalEggName", self:_eggDisplayName(nextPersonalEggId))
    if record and record.player then
        record.personalHatchTier = personalTier
        record.personalHatchEggId = personalEggId
        record.player:SetAttribute("MergeDefenseRebirths", rebirth.count)
        record.player:SetAttribute("MergeDefenseRebirthDamageMultiplier", rebirth.damageMultiplier)
        record.player:SetAttribute("MergeDefenseManagementDamageMultiplier", managementDamage)
        record.player:SetAttribute("MergeDefenseAlliedDamageMultiplier", alliedDamage)
        record.player:SetAttribute("MergeDefensePersonalEggTier", personalTier)
        record.player:SetAttribute("MergeDefensePersonalEggId", personalEggId)
    end
    local upgradeAttributeNames = {
        coin_value = "CoinValue",
        damage = "Damage",
        fire_rate = "FireRate",
        active_slots = "ActiveSlots",
        egg_health = "EggHealth",
    }
    for upgradeId, attributeName in pairs(upgradeAttributeNames) do
        local level = self:_managementUpgradeLevel(record, upgradeId)
        local price = self:_managementUpgradeCost(record, upgradeId)
        local definition = self:_managementUpgradeDefinition(upgradeId) or {}
        local step = math.max(0, tonumber(definition.step) or 0)
        world:SetAttribute("Management" .. attributeName .. "Level", level)
        world:SetAttribute("Management" .. attributeName .. "Cost", price and price.amount or nil)
        world:SetAttribute("Management" .. attributeName .. "Step", step)
        world:SetAttribute(
            "Management" .. attributeName .. "Percent",
            math.floor((1 + level * step) * 100 + 0.5)
        )
        world:SetAttribute(
            "Management" .. attributeName .. "NextPercent",
            math.floor((1 + (level + 1) * step) * 100 + 0.5)
        )
        world:SetAttribute("Management" .. attributeName .. "Maxed", price == nil)
    end
    local totalStationPositions =
        math.max(1, math.floor(tonumber((self._config.station_layout or {}).total_positions) or 9))
    local activeSlotCount = self:_activeSlotCount(record)
    world:SetAttribute("ManagementUpgradeCurrency", "gems")
    world:SetAttribute(
        "ManagementUpgradeGemsSpent",
        record and record.managementUpgradeGemsSpent or 0
    )
    world:SetAttribute("OwnedHatcherSlots", activeSlotCount)
    world:SetAttribute("MaximumHatcherSlots", totalStationPositions)
    world:SetAttribute("DeployedHatcherSlots", record and #(record.teams or {}) or 0)
    world:SetAttribute(
        "ActiveSlotDeploymentPending",
        record ~= nil
            and record.encounterSpawned == true
            and #(record.teams or {}) < activeSlotCount
    )
    world:SetAttribute("HatcherEggMaximumHealth", self:_hatcherEggMaxHealth(record))
    world:SetAttribute(
        "PrototypeBaseCombatLevel",
        record and self:_prototypeBaseLevel(record) or nil
    )
    world:SetAttribute("ActiveEnemies", record and record.aliveEnemies or 0)
    world:SetAttribute("CurrentWave", record and record.waveIndex or 0)
    local stageId, stage = self:_progressionStage(record)
    local stageIndex, stageCount = self:_progressionStageIndex(record)
    world:SetAttribute("ProgressionStageId", stageId)
    world:SetAttribute("ProgressionStageName", tostring(stage.display_name or stageId))
    world:SetAttribute("ProgressionStageIndex", stageIndex)
    world:SetAttribute("ProgressionStageCount", stageCount)
    world:SetAttribute(
        "ProgressionStageTeamPositions",
        self:_positionsForEggTier(record and record.maximumEggTier or 1, record)
    )
    local combatLayerId, combatLayer = self:_combatLayerForWave(record)
    world:SetAttribute("CombatLayerId", combatLayerId)
    world:SetAttribute("CombatLayerName", tostring(combatLayer.display_name or combatLayerId))
    world:SetAttribute(
        "CombatLayerCheckpointWave",
        math.max(1, math.floor(tonumber(combatLayer.through_wave) or self:_waveCount(record)))
    )
    world:SetAttribute("WaveCount", self:_waveCount(record))
    world:SetAttribute("WavesEndless", self:_wavesAreEndless(record))
    local currentWave = record and self:_waveFor(record, record.waveIndex) or nil
    world:SetAttribute("WaveConfigId", currentWave and tostring(currentWave.id or "") or nil)
    world:SetAttribute(
        "WaveDefenderRealm",
        currentWave and tostring(currentWave.defender_realm or "neutral") or nil
    )
    world:SetAttribute(
        "WaveAttackerRealm",
        currentWave and tostring(currentWave.attacker_realm or "neutral") or nil
    )
    world:SetAttribute("WaveFocusTeamId", record and record.waveFocusTeamId or nil)
    world:SetAttribute("CoinRunnerStartWave", record and record.coinRunnerStartWave or 1)
    world:SetAttribute("EnemiesDefeated", record and record.defeated or 0)
    world:SetAttribute("EnemiesEscaped", record and record.escaped or 0)
    world:SetAttribute("EnemiesAlerted", record and record.alerted or 0)
    world:SetAttribute("EnemiesBreachedBulwark", record and record.bulwarkCrossed or 0)
    world:SetAttribute("EnemiesCrossedBreachLine", record and record.breached or 0)
    world:SetAttribute("EnemiesPastBulwark", record and record.enemiesPastBulwark or 0)
    world:SetAttribute("PeakEnemiesPastBulwark", record and record.peakEnemiesPastBulwark or 0)
    local bulwarkState = self:_normalizeBulwarkState(record)
    local laneMenu = self:_bulwarkMenuState(record, MergeBulwarkSlots.defaultId())
    world:SetAttribute("MergeBulwarkInstalled", laneMenu.installed)
    world:SetAttribute("MergeBulwarkFamily", laneMenu.family)
    world:SetAttribute("MergeBulwarkTier", laneMenu.tier)
    world:SetAttribute("MergeBulwarkUnlocked", laneMenu.unlocked)
    for _, def in ipairs(MergeBulwarkSlots.all()) do
        local family, tier = MergeBulwarkProgression.slotFamily(bulwarkState, def.id)
        world:SetAttribute("MergeBulwark_" .. def.id .. "_Installed", family ~= nil)
        world:SetAttribute("MergeBulwark_" .. def.id .. "_Family", family)
        world:SetAttribute("MergeBulwark_" .. def.id .. "_Tier", tier)
        if def.id == "egg" then
            world:SetAttribute("MergeEggBulwarkInstalled", family ~= nil)
            world:SetAttribute("MergeEggBulwarkFamily", family)
            world:SetAttribute("MergeEggBulwarkTier", tier)
        end
    end
    world:SetAttribute("MergeBulwarkUnlockWave", laneMenu.unlockWave)
    world:SetAttribute("MergeBulwarkProductionUnlockWave", laneMenu.productionUnlockWave)
    world:SetAttribute("MergeBulwarkActionCost", laneMenu.actionCost)
    world:SetAttribute("MergeBulwarkCurrency", laneMenu.currency)
    world:SetAttribute("EnemiesPastBreachLine", record and record.enemiesPastBreachLine or 0)
    world:SetAttribute(
        "PeakEnemiesPastBreachLine",
        record and record.peakEnemiesPastBreachLine or 0
    )
    world:SetAttribute("BreachOverrunThreshold", record and record.breachOverrunThreshold or 0)
    world:SetAttribute("BreachOverrun", record and record.breachOverrun == true or false)
    world:SetAttribute("BreachPressureHits", record and record.breachPressureHits or 0)
    world:SetAttribute("BreachDamageActive", false)
    world:SetAttribute("FirstBreachWave", record and record.firstBreachWave or nil)
    world:SetAttribute("FirstOverrunWave", record and record.firstOverrunWave or nil)
    world:SetAttribute("HatcherEggsDestroyed", record and record.hatcherEggsDestroyed or 0)
    world:SetAttribute("HatcherEggsRebuilt", record and record.hatcherEggsRebuilt or 0)
    world:SetAttribute("EggProductionDamageHits", record and record.eggProductionDamageHits or 0)
    world:SetAttribute("EggProductionLockouts", record and record.eggProductionLockouts or 0)
    world:SetAttribute("HealDenialFieldsActive", record and record.healDenialActiveFields or 0)
    world:SetAttribute("HealDenialFieldActivations", record and record.healDenialActivations or 0)
    world:SetAttribute(
        "HealDenialEnemiesSuppressed",
        record and record.healDenialSuppressedEnemies or 0
    )
    world:SetAttribute("PeakActiveEnemies", record and record.peakActiveEnemies or 0)
    world:SetAttribute("EnemyPortalVisible", record and record.portalVisible == true or false)
    world:SetAttribute("WaveEnemiesPending", record and record.pendingEnemySpawns or 0)
    world:SetAttribute("WaveAttackGroups", record and record.waveGroupCount or 0)
    world:SetAttribute("WaveActiveAttackGroups", record and record.waveActiveAttackGroups or 0)
    world:SetAttribute("WaveReserveTeamId", record and record.waveReserveTeamId or nil)
    world:SetAttribute(
        "WaveReserveReleased",
        record and record.waveReserveReleased == true or false
    )
    world:SetAttribute(
        "WaveReinforcementsCommitted",
        record and record.waveReinforcementsCommitted or 0
    )
    world:SetAttribute("PrototypeEggId", record and record.eggId or nil)
    world:SetAttribute("PrototypeEggRolls", record and record.eggRolls or 0)
    world:SetAttribute("PrototypeGoldenRolls", record and record.eggGoldenRolls or 0)
    world:SetAttribute("PrototypeRainbowRolls", record and record.eggRainbowRolls or 0)
    world:SetAttribute("PrototypeHugeRolls", record and record.eggHugeRolls or 0)
    world:SetAttribute("PrototypeForcedHugeRolls", record and record.prototypeHugeRolls or 0)
    world:SetAttribute("PrototypeDraftCandidateRolls", record and record.draftCandidateRolls or 0)
    world:SetAttribute("PrototypeDraftRejectedRolls", record and record.draftRejectedRolls or 0)
    world:SetAttribute("PlayerReserveRosterCapacity", record and record.playerEscortCapacity or 0)
    world:SetAttribute("PlayerReserveRosterActive", record and record.playerEscortActive or 0)
    world:SetAttribute("PlayerReserveRosterBench", record and #(record.playerReserve or {}) or 0)
    world:SetAttribute(
        "PlayerReserveRosterPending",
        record and #(record.playerReplacementQueue or {}) or 0
    )
    world:SetAttribute("PlayerReserveCastoffsAwarded", record and record.playerCastoffsAwarded or 0)
    world:SetAttribute(
        "PlayerReserveReplacementsEquipped",
        record and record.playerReplacementsEquipped or 0
    )
    world:SetAttribute("PlayerReservePeakBench", record and record.peakPlayerReserveDepth or 0)
    world:SetAttribute(
        "PlayerReservePeakQueue",
        record and record.peakPlayerReplacementQueueDepth or 0
    )
    world:SetAttribute(
        "PrototypeDraftRollsPerHatch",
        record and self:_draftRollsForEggTier(record.maximumEggTier or 1, record) or 1
    )
    world:SetAttribute("HatcherEggAdvances", record and record.hatcherEggAdvances or 0)
    world:SetAttribute("HatcherUpgrades", record and record.hatcherEggAdvances or 0) -- legacy
    world:SetAttribute("PrototypeCoinsDropped", record and record.coinsDropped or 0)
    world:SetAttribute("PrototypeGemsDropped", record and record.gemsDropped or 0)
    local pricing = self:_earthEggPricing(record)
    local nextEarthCost = self:_nextEarthEggCost(record)
    local baseTier = self:_baseEggTier(record)
    local progression = self:_eggProgression(record)
    local sources = self._petsConfig and self._petsConfig.egg_sources or {}
    local baseEggId = progression[baseTier]
    local baseEggData = baseEggId and sources[baseEggId]
    local baseUpgrade = self:_baseEggUpgradeCost(record)
    local baseUpgradeReady, baseUpgradeReason = self:_canUpgradeBaseEgg(record)
    local nextBaseEggId = baseUpgrade and progression[baseUpgrade.tier]
    local nextBaseEggData = nextBaseEggId and sources[nextBaseEggId]
    local accessCfg = (self._config.team or {}).build_access or {}
    world:SetAttribute("EarthEggCurrency", pricing.currency)
    world:SetAttribute("EarthEggBaseCost", pricing.baseAmount)
    world:SetAttribute("EarthEggPriceGrowth", pricing.growth)
    world:SetAttribute("NextEarthEggCost", nextEarthCost.amount)
    world:SetAttribute("BaseEggTier", baseTier)
    world:SetAttribute("BaseEggSourceId", baseEggId)
    world:SetAttribute("BaseEggSourceName", baseEggData and baseEggData.name or baseEggId)
    world:SetAttribute("BaseEggCreationCost", nextEarthCost.amount)
    world:SetAttribute("BaseEggCanUpgrade", baseUpgrade ~= nil)
    world:SetAttribute("BaseEggUpgradeReady", baseUpgradeReady)
    world:SetAttribute("BaseEggUpgradeBlockedReason", baseUpgradeReason)
    world:SetAttribute("BaseEggUpgradeCost", baseUpgrade and baseUpgrade.amount or nil)
    world:SetAttribute("BaseEggNextTier", baseUpgrade and baseUpgrade.tier or nil)
    world:SetAttribute("BaseEggNextSourceId", nextBaseEggId)
    world:SetAttribute(
        "BaseEggNextSourceName",
        nextBaseEggData and nextBaseEggData.name or nextBaseEggId
    )
    world:SetAttribute("BaseEggUpgradesPurchased", record and record.baseEggUpgradesPurchased or 0)
    world:SetAttribute("BaseEggBoardPromotions", record and record.baseEggBoardPromotions or 0)
    world:SetAttribute("BaseEggHatcherPromotions", record and record.baseEggHatcherPromotions or 0)
    world:SetAttribute("BaseEggUpgradeCoinsSpent", record and record.baseEggUpgradeCoinsSpent or 0)
    world:SetAttribute(
        "BaseEggCreationCoinsSpent",
        record and record.baseEggCreationCoinsSpent or 0
    )
    local experimentId, experiment = self:_balanceExperiment(record)
    world:SetAttribute("BalanceExperiment", experimentId)
    world:SetAttribute(
        "EggOriginPowerPerTier",
        math.max(0, tonumber(experiment.origin_power_per_tier) or 0)
    )
    world:SetAttribute(
        "EggBuildMinimumBulwarkDepth",
        math.max(0, tonumber(accessCfg.minimum_bulwark_depth) or 4)
    )
    world:SetAttribute(
        "EggBuildMaximumHatcherDistance",
        math.max(1, tonumber(accessCfg.maximum_hatcher_distance) or 18)
    )
    world:SetAttribute("EarthEggCoinsSpent", record and record.earthEggCoinsSpent or 0)
    world:SetAttribute("CoreEggCoinsSpent", record and record.coreEggCoinsSpent or 0)
    self:_publishEggInventory(record)
    local equipBestPlan = self:_equipBestPlan(record)
    local equipBestAvailable = record ~= nil
        and record.encounterSpawned == true
        and record.terminal ~= true
        and record.coinRunnerRunning ~= true
        and #equipBestPlan > 0
    world:SetAttribute("EquipBestAvailable", equipBestAvailable)
    world:SetAttribute("EquipBestActionCount", equipBestAvailable and #equipBestPlan or 0)
    world:SetAttribute(
        "EquipBestBlockedReason",
        equipBestAvailable and nil
            or (record and record.coinRunnerRunning == true and "automation_owns_hatchers")
            or "no_equip_best_action"
    )
    local sandHatchers = 0
    local installedHatcherEggs = 0
    local totalPositions = 0
    local maximumTier = #self:_eggProgression(record)
    for _, team in ipairs(record and record.teams or {}) do
        if math.floor(tonumber(team.eggTier) or 0) >= maximumTier then
            sandHatchers += 1
        end
        if math.floor(tonumber(team.eggTier) or 0) > 0 then
            installedHatcherEggs += 1
        end
        totalPositions += math.max(0, math.floor(tonumber(team.expectedPets) or 0))
    end
    world:SetAttribute("SandEggHatcherCount", sandHatchers)
    world:SetAttribute("InstalledHatcherEggCount", installedHatcherEggs)
    world:SetAttribute("TotalTeamPositions", totalPositions)
    world:SetAttribute("CoinRunnerRunning", record and record.coinRunnerRunning == true or false)
    world:SetAttribute("CoinRunnerState", record and record.coinRunnerState or "Off")
    world:SetAttribute("CoinRunnerResult", record and record.coinRunnerResult or nil)
    world:SetAttribute("CoinRunnerStopReason", record and record.coinRunnerStopReason or nil)
    world:SetAttribute(
        "CoinRunnerNavigationRecoveries",
        record and record.coinRunnerNavigationRecoveries or 0
    )
    world:SetAttribute(
        "CoinRunnerLastNavigationFailure",
        record and record.coinRunnerLastNavigationFailure or nil
    )
    world:SetAttribute("CoinRunnerTarget", record and record.coinRunnerTarget or nil)
    world:SetAttribute("CoinRunnerStartingCoins", record and record.coinRunnerStartingCoins or nil)
    world:SetAttribute("CoinRunnerSeed", record and record.coinRunnerSeed or nil)
    world:SetAttribute("CoinRunnerEndingCoins", record and record.coinRunnerEndingCoins or nil)
    world:SetAttribute("CoinRunnerCoinsEarned", record and record.coinRunnerCoinsEarned or nil)
    world:SetAttribute("CoinRunnerCoinsSpent", record and record.coinRunnerCoinsSpent or 0)
    world:SetAttribute("CoinRunnerCoinsDropped", record and record.coinRunnerCoinsDropped or nil)
    world:SetAttribute("CoinRunnerWaveReached", record and record.coinRunnerWaveReached or nil)
    world:SetAttribute(
        "CoinRunnerElapsedSeconds",
        record and record.coinRunnerElapsedSeconds or nil
    )
    world:SetAttribute(
        "CoinRunnerFirstEscapeHatchers",
        record and record.coinRunnerFirstEscapeHatchers or nil
    )
    world:SetAttribute(
        "CoinRunnerFirstEscapeWave",
        record and record.coinRunnerFirstEscapeWave or nil
    )
    world:SetAttribute(
        "CoinRunnerFourHatcherWave",
        record and record.coinRunnerFourHatcherWave or nil
    )
    world:SetAttribute("CoinRunnerAllSandWave", record and record.coinRunnerAllSandWave or nil)
    world:SetAttribute(
        "CoinRunnerFourHatchersBeforeEscape",
        record
                and record.coinRunnerFourHatcherAt ~= nil
                and (record.coinRunnerFirstEscapeAt == nil or record.coinRunnerFourHatcherAt <= record.coinRunnerFirstEscapeAt)
            or false
    )
    world:SetAttribute(
        "CoinRunnerAllSandBeforeEscape",
        record
                and record.coinRunnerAllSandAt ~= nil
                and (record.coinRunnerFirstEscapeAt == nil or record.coinRunnerAllSandAt <= record.coinRunnerFirstEscapeAt)
            or false
    )
    world:SetAttribute(
        "CoinRunnerSucceeded",
        record and record.progressionLoopComplete == true or false
    )
    world:SetAttribute("HomeStageComplete", record and record.homeStageComplete == true or false)
    world:SetAttribute("HomeCompletionCoins", record and record.homeCompletionCoins or nil)
    world:SetAttribute(
        "HomeEntryReserveRequired",
        record and record.homeEntryReserveRequired or nil
    )
    world:SetAttribute(
        "HomeEntryReserveMet",
        record and record.homeEntryReserveMet == true or false
    )
    world:SetAttribute("HomeCompletionWave", record and record.homeCompletionWave or nil)
    world:SetAttribute(
        "Heaven1StageComplete",
        record and record.heaven1StageComplete == true or false
    )
    world:SetAttribute("Heaven1CompletionCoins", record and record.heaven1CompletionCoins or nil)
    local checkpointCfg = self._config.checkpoints or {}
    local checkpointInterval = math.max(1, math.floor(tonumber(checkpointCfg.interval) or 10))
    local checkpointWave = record and record.checkpointSnapshot and record.checkpointSnapshot.wave
        or 0
    local nextCheckpointWave = math.min(
        self:_waveCount(record),
        (math.floor((record and record.waveIndex or 0) / checkpointInterval) + 1)
            * checkpointInterval
    )
    world:SetAttribute("CheckpointInterval", checkpointInterval)
    world:SetAttribute("CheckpointWave", checkpointWave)
    world:SetAttribute("CheckpointPendingWave", record and record.pendingCheckpointWave or nil)
    world:SetAttribute("CheckpointRestarts", record and record.checkpointRestarts or 0)
    world:SetAttribute(
        "CheckpointLastFailedWave",
        record and record.checkpointLastFailedWave or nil
    )
    world:SetAttribute("CheckpointNextWave", nextCheckpointWave)
    world:SetAttribute(
        "CheckpointRecoveryWaveCount",
        math.max(0, math.floor(tonumber(checkpointCfg.recovery_wave_count) or 3))
    )
    world:SetAttribute(
        "PrototypeMagnetRadius",
        record and record.player:GetAttribute("CollectRadius") or 0
    )
    world:SetAttribute("FirstPetLossWave", record and record.firstPetLossWave or nil)
    world:SetAttribute(
        "FirstPetLossActiveEnemies",
        record and record.firstPetLossActiveEnemies or nil
    )
    local objectiveCfg = self._config.objective or {}
    local startingEggs = math.max(1, math.floor(tonumber(objectiveCfg.starting_eggs) or 5))
    world:SetAttribute(
        "ObjectiveEggsStarting",
        record and record.objectiveEggsStarting or startingEggs
    )
    world:SetAttribute(
        "ObjectiveEggsRemaining",
        record and record.objectiveEggsRemaining or startingEggs
    )
    world:SetAttribute("ObjectiveHits", record and record.objectiveHits or 0)
    world:SetAttribute("ReplacementQueueDepth", self:_replacementQueueDepth(record))
    world:SetAttribute(
        "PeakReplacementQueueDepth",
        record and record.peakReplacementQueueDepth or 0
    )
    world:SetAttribute("ReplacementsHatched", record and record.replacementsHatched or 0)
    world:SetAttribute(
        "LongestReplacementWaitSeconds",
        record and record.longestReplacementWaitSeconds or 0
    )
    local activeTeams = 0
    local readyTeams = 0
    local engagedTeams = 0
    local reinforcingTeams = 0
    local suppressedTeams = 0
    local productionLockedEggs = 0
    local defeatedTeams = 0
    local initializedHatchers = 0
    local activePets = 0
    local defeatedPets = 0
    for _, team in ipairs(record and record.teams or {}) do
        if team.folder and team.folder.Parent then
            activeTeams += 1
        end
        if team.initialized == true then
            initializedHatchers += 1
        end
        if team.state == "Ready" then
            readyTeams += 1
        elseif team.state == "Engaged" then
            engagedTeams += 1
        elseif team.state == "Reinforcing" then
            reinforcingTeams += 1
        elseif team.state == "Suppressed" then
            suppressedTeams += 1
        elseif team.state == "Defeated" then
            defeatedTeams += 1
        end
        if (tonumber(team.eggProductionLockedUntil) or 0) > os.clock() then
            productionLockedEggs += 1
        end
        activePets += team.activePets or 0
        defeatedPets += team.defeatedPets or 0
    end
    world:SetAttribute("ActiveTeamCount", activeTeams)
    world:SetAttribute("InitializedHatcherCount", initializedHatchers)
    world:SetAttribute("ReadyTeamCount", readyTeams)
    world:SetAttribute("EngagedTeamCount", engagedTeams)
    world:SetAttribute("ReinforcingTeamCount", reinforcingTeams)
    world:SetAttribute("SuppressedTeamCount", suppressedTeams)
    world:SetAttribute("ProductionLockedEggCount", productionLockedEggs)
    world:SetAttribute("DefeatedTeamCount", defeatedTeams)
    world:SetAttribute("ActiveTeamPets", activePets)
    world:SetAttribute("DefeatedTeamPets", defeatedPets)
end

function MergeEggPrototypeService:_setTeamState(record, team, state)
    if not (record and team) then
        return
    end
    state = tostring(state or "Ready")
    team.state = state
    if team.folder and team.folder.Parent then
        team.folder:SetAttribute("MergeEggTeamState", state)
    end
    local world = self:_worldFor(record)
    local worldState = world and world:GetAttribute("PrototypeState") or "ReadyToHatch"
    self:_setWorldState(worldState, record)
end

function MergeEggPrototypeService:_queueMissingPets(record, team, occupiedSlots, expected, now)
    local cfg = self._config.reinforcement or {}
    if
        cfg.enabled ~= true
        or not record.encounterSpawned
        or record.terminal == true
        or team.initialized ~= true
        or not (team.folder and team.folder.Parent)
    then
        return
    end
    team.replacementQueue = team.replacementQueue or {}
    team.pendingReplacementSlots = team.pendingReplacementSlots or {}
    for slot = 1, expected do
        if not occupiedSlots[slot] and not team.pendingReplacementSlots[slot] then
            team.pendingReplacementSlots[slot] = true
            team.replacementQueue[#team.replacementQueue + 1] = {
                slot = slot,
                queuedAt = now,
            }
            team.replacementsQueued = (team.replacementsQueued or 0) + 1
        end
    end
    if #team.replacementQueue > 0 and team.nextReplacementAt == nil then
        team.nextReplacementAt = now + math.max(0.25, tonumber(cfg.hatch_seconds) or 4)
    end
    record.peakReplacementQueueDepth =
        math.max(record.peakReplacementQueueDepth or 0, self:_replacementQueueDepth(record))
end

function MergeEggPrototypeService:_syncTeamState(record, team)
    local folder = team and team.folder
    if not (folder and folder.Parent) then
        return
    end
    local active = 0
    local targeted = 0
    local returned = 0
    local occupiedSlots = {}
    local anchorRoot = team.principalModel
        and team.principalModel:FindFirstChild("HumanoidRootPart")
    local anchorPosition = anchorRoot and anchorRoot.Position
    local readyDistance =
        math.max(1, tonumber((self._config.team or {}).return_ready_distance) or 20)

    for _, pet in ipairs(folder:GetChildren()) do
        if pet:IsA("Model") and pet:GetAttribute("MergeEggObjective") ~= true then
            active += 1
            local positionNumber = pet:FindFirstChild("PositionNumber")
            local slot =
                math.max(1, math.floor(tonumber(positionNumber and positionNumber.Value) or active))
            occupiedSlots[slot] = true
            local targetId = pet:FindFirstChild("TargetID")
            if targetId and tonumber(targetId.Value) and targetId.Value ~= 0 then
                targeted += 1
            end
            local position = pet:GetAttribute("NpcCombatPosition")
            if typeof(position) ~= "Vector3" then
                position = pet:GetPivot().Position
            end
            if anchorPosition then
                local horizontal =
                    Vector3.new(position.X - anchorPosition.X, 0, position.Z - anchorPosition.Z)
                if horizontal.Magnitude <= readyDistance then
                    returned += 1
                end
            end
        end
    end

    local expected = math.max(1, math.floor(tonumber(team.expectedPets) or 5))
    local now = os.clock()
    self:_queueMissingPets(record, team, occupiedSlots, expected, now)
    local replacementSlots = {}
    for _, queued in ipairs(team.replacementQueue or {}) do
        replacementSlots[#replacementSlots + 1] = tostring(queued.slot)
    end
    team.activePets = active
    team.defeatedPets = team.initialized == true and math.max(0, expected - active) or 0
    team.peakAssignedEnemies = math.max(team.peakAssignedEnemies or 0, team.assignedAlive or 0)
    if
        record.encounterSpawned
        and team.initialized == true
        and team.defeatedPets > 0
        and team.firstLossWave == nil
    then
        team.firstLossWave = record.waveIndex
        team.firstLossAssignedEnemies = team.assignedAlive or 0
        if record.firstPetLossWave == nil then
            record.firstPetLossWave = record.waveIndex
            record.firstPetLossActiveEnemies = record.aliveEnemies
        end
        self:_log("Info", "Merge Egg prototype team took its first loss", {
            player = record.player.Name,
            team = team.id,
            wave = team.firstLossWave,
            assignedEnemies = team.firstLossAssignedEnemies,
            activeEnemies = record.aliveEnemies,
        })
    end
    folder:SetAttribute("MergeEggActivePets", active)
    folder:SetAttribute("MergeEggDefeatedPets", team.defeatedPets)
    folder:SetAttribute("MergeEggTargetedPets", targeted)
    folder:SetAttribute("MergeEggReturnedPets", returned)
    folder:SetAttribute("MergeEggWave", record.waveIndex)
    folder:SetAttribute("MergeEggAssignedEnemies", team.assignedAlive or 0)
    folder:SetAttribute("MergeEggPeakAssignedEnemies", team.peakAssignedEnemies)
    folder:SetAttribute("MergeEggReserveTeam", team.isReserve == true)
    folder:SetAttribute("MergeEggReinforcementCommitted", team.reinforcementCommitted == true)
    folder:SetAttribute("MergeEggReinforcementReason", team.reinforcementReason)
    folder:SetAttribute("MergeEggReinforcementTargetId", team.reinforcementTargetId)
    folder:SetAttribute("MergeEggFirstLossWave", team.firstLossWave)
    folder:SetAttribute("MergeEggFirstLossAssignedEnemies", team.firstLossAssignedEnemies)
    folder:SetAttribute("MergeEggReplacementQueueDepth", #(team.replacementQueue or {}))
    folder:SetAttribute("MergeEggReplacementSlots", table.concat(replacementSlots, ","))
    folder:SetAttribute("MergeEggReplacementsQueued", team.replacementsQueued or 0)
    folder:SetAttribute("MergeEggReplacementsHatched", team.replacementsHatched or 0)
    folder:SetAttribute("MergeEggNextReplacementAt", team.nextReplacementAt)
    self:_publishTeamEggSource(team)
    folder:SetAttribute("MergeEggRolls", team.eggRolls or 0)
    folder:SetAttribute("MergeEggGoldenRolls", team.eggGoldenRolls or 0)
    folder:SetAttribute("MergeEggRainbowRolls", team.eggRainbowRolls or 0)
    folder:SetAttribute("MergeEggHugeRolls", team.eggHugeRolls or 0)
    folder:SetAttribute("MergeEggForcedHugeRolls", team.prototypeHugeRolls or 0)

    local state = "Ready"
    if team.initialized ~= true then
        state = "NoEgg"
    elseif record.encounterSpawned and active == 0 then
        state = #(team.replacementQueue or {}) > 0 and "Reinforcing" or "Defeated"
    elseif targeted > 0 then
        state = "Engaged"
    elseif (team.assignedAlive or 0) > 0 then
        state = (team.engaged == true or targeted > 0) and "Engaged" or "Deploying"
    elseif team.isReserve == true then
        state = "Reserve"
    elseif record.encounterSpawned and returned < active then
        state = "Returning"
    elseif
        #(team.replacementQueue or {}) > 0
        and (tonumber(team.eggProductionLockedUntil) or 0) > now
    then
        state = "Suppressed"
    elseif #(team.replacementQueue or {}) > 0 then
        state = "Reinforcing"
    end
    self:_setTeamState(record, team, state)
end

function MergeEggPrototypeService:_syncAllTeams(record)
    for _, team in ipairs(record and record.teams or {}) do
        self:_syncTeamState(record, team)
    end
end

function MergeEggPrototypeService:_captureCheckpoint(record, wave, options)
    options = type(options) == "table" and options or {}
    if
        not self:_isRecordActive(record)
        or (record.terminal == true and options.allowTerminal ~= true)
    then
        return false, "checkpoint_encounter_unavailable"
    end
    local checkpointWave = math.max(0, math.floor(tonumber(wave) or record.waveIndex or 0))
    if checkpointWave <= 0 and options.allowWaveZero ~= true then
        return false, "checkpoint_wave_invalid"
    end
    local pricing = self:_earthEggPricing(record)
    local coins = self._economyService
        and self._economyService:GetCurrency(record.player, pricing.currency)
    if coins == nil then
        return false, "checkpoint_currency_unavailable"
    end

    self:_syncAllTeams(record)
    local teams = {}
    for _, team in ipairs(record.teams or {}) do
        local expected = math.max(1, math.floor(tonumber(team.expectedPets) or 1))
        teams[team.id] = {
            initialized = team.initialized == true,
            eggTier = math.max(0, math.floor(tonumber(team.eggTier) or 0)),
            eggId = team.eggId,
            eggName = team.eggName,
            expectedPets = expected,
            squad = cloneSquadDefinitions(team.config and team.config.squad, expected),
            eggsDestroyed = team.eggsDestroyed or 0,
            eggsRebuilt = team.eggsRebuilt or 0,
            eggRolls = team.eggRolls or 0,
            eggGoldenRolls = team.eggGoldenRolls or 0,
            eggRainbowRolls = team.eggRainbowRolls or 0,
            eggHugeRolls = team.eggHugeRolls or 0,
            prototypeHugeRolls = team.prototypeHugeRolls or 0,
            draftCandidateRolls = team.draftCandidateRolls or 0,
            draftRejectedRolls = team.draftRejectedRolls or 0,
            replacementsQueued = team.replacementsQueued or 0,
            replacementsHatched = team.replacementsHatched or 0,
            eggProductionDamageHits = team.eggProductionDamageHits or 0,
            eggProductionLockouts = team.eggProductionLockouts or 0,
            firstLossWave = team.firstLossWave,
            firstLossAssignedEnemies = team.firstLossAssignedEnemies,
        }
    end

    record.checkpointSnapshot = {
        wave = checkpointWave,
        currency = pricing.currency,
        coins = math.max(0, math.floor(tonumber(coins) or 0)),
        objectiveEggsRemaining = record.objectiveEggsRemaining,
        objectiveHits = record.objectiveHits,
        eggInventory = table.clone(record.eggInventory or {}),
        teams = teams,
        playerEscort = {
            capacity = record.playerEscortCapacity,
            squad = cloneSquadDefinitions(
                record.playerSquad,
                math.max(0, math.floor(tonumber(record.playerEscortCapacity) or 0))
            ),
            reserve = cloneSquadDefinitions(record.playerReserve, #(record.playerReserve or {})),
            castoffsAwarded = record.playerCastoffsAwarded,
            replacementsQueued = record.playerReplacementsQueued,
            replacementsEquipped = record.playerReplacementsEquipped,
            peakReserveDepth = record.peakPlayerReserveDepth,
            peakQueueDepth = record.peakPlayerReplacementQueueDepth,
            longestReplacementWaitSeconds = record.longestPlayerReplacementWaitSeconds,
        },
        recordState = {
            baseEggTier = record.baseEggTier,
            baseEggUpgradesPurchased = record.baseEggUpgradesPurchased,
            baseEggBoardPromotions = record.baseEggBoardPromotions,
            baseEggHatcherPromotions = record.baseEggHatcherPromotions,
            baseEggUpgradeCoinsSpent = record.baseEggUpgradeCoinsSpent,
            baseEggCreationCoinsSpent = record.baseEggCreationCoinsSpent,
            maximumEggTier = record.maximumEggTier,
            hatcherEggAdvances = record.hatcherEggAdvances,
            hatcherEggsDestroyed = record.hatcherEggsDestroyed,
            hatcherEggsRebuilt = record.hatcherEggsRebuilt,
            coinsDropped = record.coinsDropped,
            earthEggCoinsSpent = record.earthEggCoinsSpent,
            coreEggCoinsSpent = record.coreEggCoinsSpent,
            eggsCreated = record.eggsCreated,
            eggsMerged = record.eggsMerged,
            eggsPlaced = record.eggsPlaced,
            eggRolls = record.eggRolls,
            eggGoldenRolls = record.eggGoldenRolls,
            eggRainbowRolls = record.eggRainbowRolls,
            eggHugeRolls = record.eggHugeRolls,
            prototypeHugeRolls = record.prototypeHugeRolls,
            draftCandidateRolls = record.draftCandidateRolls,
            draftRejectedRolls = record.draftRejectedRolls,
            draftGoldenCandidates = record.draftGoldenCandidates,
            draftRainbowCandidates = record.draftRainbowCandidates,
            draftHugeCandidates = record.draftHugeCandidates,
            replacementsHatched = record.replacementsHatched,
            eggProductionDamageHits = record.eggProductionDamageHits,
            eggProductionLockouts = record.eggProductionLockouts,
        },
    }
    record.pendingCheckpointWave = nil
    if checkpointWave > 0 then
        self:_persistCheckpoint(record)
        self:_setWorldState("CheckpointBanked", record)
    end
    self:_log("Info", "Merge Egg prototype checkpoint banked", {
        player = record.player.Name,
        wave = checkpointWave,
        coins = coins,
        eggs = record.objectiveEggsRemaining,
        hatchers = self:_initializedHatcherCount(record),
    })
    return true
end

-- Restore only reconstructable progression. Temporary NPC rolls are rerolled so the profile never
-- contains Instances or runtime combat definitions. A logout playstate may resume at Wave 0;
-- a combat checkpoint still requires a completed ten-wave boundary.
function MergeEggPrototypeService:_restoreDurableProgress(record, saved, restoreSource)
    if not (record and saved and record.encounterSpawned == true) then
        return false, "durable_progress_unavailable"
    end
    if not (self._economyService and self._economyService.SetCurrency) then
        return false, "currency_unavailable"
    end
    if
        not self._economyService:SetCurrency(
            record.player,
            saved.currency,
            saved.coins,
            "merge_defense_" .. tostring(restoreSource or "progress") .. "_resume"
        )
    then
        return false, "durable_currency_restore_failed"
    end

    record.restoringDurableCheckpoint = true
    record.baseEggTier = saved.base_egg_tier
    record.baseEggUpgradesPurchased = math.max(0, saved.base_egg_tier - 1)
    record.eggInventory = table.clone(saved.egg_inventory)
    record.objectiveEggsRemaining = math.max(
        1,
        saved.objective_eggs > 0 and saved.objective_eggs or record.objectiveEggsStarting
    )
    local restoredTeams = 0
    local highestTier = saved.base_egg_tier
    for teamId, tier in pairs(saved.deployed_egg_tiers) do
        local team = record.teamById[tonumber(teamId)]
        local eggId = self:_eggProgression(record)[tier]
        local source = eggId and self:_buildHatchSource(record, eggId)
        if team and source then
            local spawned, reason = self:_spawnInitialTeam(record, team, source, tier)
            if not spawned then
                record.restoringDurableCheckpoint = false
                return false, reason
            end
            team.eggTier = tier
            team.eggId = source.eggId
            team.eggName = source.eggName
            team.hatchPlayerData = source.hatchPlayerData
            team.eggMaxHealth = self:_hatcherEggMaxHealth(record)
            team.eggHealth = team.eggMaxHealth
            team.eggDamageTaken = 0
            team.needsEggRebuild = false
            self:_applyTeamEggTierModifiers(team, tier)
            self:_spawnHatcherEggObjective(record, team)
            self:_publishTeamEggSource(team)
            restoredTeams += 1
            highestTier = math.max(highestTier, tier)
        end
    end
    record.restoringDurableCheckpoint = false
    record.maximumEggTier = highestTier
    record.eggsPlaced = restoredTeams
    self:_restoreEggTierMilestones(record)
    record.waveIndex = saved.wave
    record.pendingCheckpointWave = nil
    record.checkpointSnapshot = nil
    -- A saved wallet or board-only layout is valid, but combat cannot start until at least one
    -- hatcher has an egg. Scheduling here with zero deployments let Wave 1/2 run after a clean
    -- Stop -> Play even though the field was empty.
    if restoredTeams > 0 then
        record.nextWaveAt = os.clock()
            + math.max(0, tonumber((self._config.checkpoints or {}).restart_delay_seconds) or 3)
    else
        record.nextWaveAt = nil
    end
    if saved.wave > 0 then
        local captured, reason = self:_captureCheckpoint(record, saved.wave)
        if not captured then
            return false, reason
        end
    end
    self:_syncAllTeams(record)
    local restoredState = restoredTeams > 0
            and (saved.wave > 0 and "CheckpointRestarting" or "WaveIntermission")
        or "AwaitingFirstEgg"
    self:_setWorldState(restoredState, record)
    self:_log("Info", "Merge Egg durable progress resumed", {
        player = record.player.Name,
        source = restoreSource,
        wave = saved.wave,
        coins = saved.coins,
        deployed = restoredTeams,
        boardEggs = self:_eggInventoryTotal(record),
    })
    return true
end

function MergeEggPrototypeService:_restoreDurablePlaystate(record)
    local playstate = record
        and MergeEggPlaystate.normalize(record.durablePlaystate, self:_checkpointOptions())
    if not (playstate and playstate.saved == true) then
        return false, "durable_playstate_unavailable"
    end
    return self:_restoreDurableProgress(record, playstate, "playstate")
end

function MergeEggPrototypeService:_restoreDurableCheckpoint(record)
    local checkpoint = record
        and MergeEggCheckpoint.normalize(record.durableCheckpoint, self:_checkpointOptions())
    if not (checkpoint and checkpoint.wave > 0) then
        return false, "durable_checkpoint_unavailable"
    end
    return self:_restoreDurableProgress(record, checkpoint, "checkpoint")
end

function MergeEggPrototypeService:_canRestartCheckpoint(record)
    return self:_isRecordActive(record)
        and record ~= nil
        and (record.terminalState == "ObjectiveLost" or record.terminalState == "DefenseOverrun")
end

function MergeEggPrototypeService:_scheduleGameplayCheckpointRestart(record)
    local cfg = self._config.checkpoints or {}
    if
        record
        and cfg.auto_restart_gameplay == true
        and tostring(cfg.gameplay_restore_mode or "retain_progress") == "retain_progress"
    then
        record.checkpointAutoRestartAt = os.clock()
            + math.max(0, tonumber(cfg.restart_delay_seconds) or 3)
    end
end

function MergeEggPrototypeService:_restoreCheckpoint(record, cause, options)
    if not self:_canRestartCheckpoint(record) then
        return false, "checkpoint_restart_unavailable"
    end
    options = type(options) == "table" and options or {}
    local snapshot = record.checkpointSnapshot
    local preparedSources = {}
    for teamId, saved in pairs(snapshot.teams or {}) do
        if math.floor(tonumber(saved.eggTier) or 0) > 0 then
            local source, reason = self:_buildHatchSource(record, saved.eggId)
            if not source then
                return false, reason
            end
            preparedSources[teamId] = source
        end
    end

    -- Purchased-style experiment modifiers live outside the checkpoint snapshot. Each failed
    -- post-checkpoint attempt therefore returns to the same battle/economy state with exactly one
    -- additional 5% step (or the configured step), which is the progression behavior being tested.
    if options.advanceUpgradeExperiment ~= false then
        self:_advanceUpgradeExperiment(record)
    end

    local failedWave = record.waveIndex
    if options.preserveDrops ~= true and self._dropService and self._dropService.DiscardDrops then
        self._dropService:DiscardDrops(record.player, "merge_egg_prototype")
    end
    for _, enemy in ipairs(record.enemies or {}) do
        if enemy.model and enemy.model.Parent then
            self._enemyService:DespawnModel(enemy.model)
        end
    end
    record.enemies = {}
    record.enemyByTargetId = {}
    record.resolvedTargets = {}
    record.units = {}
    self:_clearTowerShots(record)
    self:_clearPlayerEscortModels(record)

    for _, team in ipairs(record.teams or {}) do
        local saved = snapshot.teams and snapshot.teams[team.id]
        if not saved then
            return false, "checkpoint_team_missing"
        end
        self:_removeHatcherEggObjective(team)
        for _, child in ipairs(team.folder and team.folder:GetChildren() or {}) do
            if child:IsA("Model") then
                child:Destroy()
            end
        end

        local expected = math.max(1, math.floor(tonumber(saved.expectedPets) or 1))
        local squad = cloneSquadDefinitions(saved.squad, expected)
        team.config.squad = squad
        team.units = {}
        team.initialized = saved.initialized == true
        team.expectedPets = expected
        team.eggTier = math.max(0, math.floor(tonumber(saved.eggTier) or 0))
        team.eggId = saved.eggId
        team.eggName = saved.eggName
        team.hatchPlayerData = preparedSources[team.id] and preparedSources[team.id].hatchPlayerData
            or nil
        team.eggMaxHealth = self:_hatcherEggMaxHealth(record)
        team.eggHealth = team.eggTier > 0 and team.eggMaxHealth or 0
        team.eggDamageTaken = 0
        team.needsEggRebuild = team.initialized and team.eggTier <= 0
        team.eggsDestroyed = saved.eggsDestroyed or 0
        team.eggsRebuilt = saved.eggsRebuilt or 0
        team.eggRolls = saved.eggRolls or 0
        team.eggGoldenRolls = saved.eggGoldenRolls or 0
        team.eggRainbowRolls = saved.eggRainbowRolls or 0
        team.eggHugeRolls = saved.eggHugeRolls or 0
        team.prototypeHugeRolls = saved.prototypeHugeRolls or 0
        team.draftCandidateRolls = saved.draftCandidateRolls or 0
        team.draftRejectedRolls = saved.draftRejectedRolls or 0
        team.replacementQueue = {}
        team.pendingReplacementSlots = {}
        team.nextReplacementAt = nil
        team.replacementsQueued = saved.replacementsQueued or 0
        team.replacementsHatched = saved.replacementsHatched or 0
        team.eggProductionLockedUntil = nil
        team.resetEggTier = nil
        team.resetEggId = nil
        team.resetEggName = nil
        team.resetHatchPlayerData = nil
        team.eggProductionDamageHits = saved.eggProductionDamageHits or 0
        team.eggProductionLockouts = saved.eggProductionLockouts or 0
        team.firstLossWave = saved.firstLossWave
        team.firstLossAssignedEnemies = saved.firstLossAssignedEnemies
        team.assignedAlive = 0
        team.engaged = false
        team.activePets = 0
        team.defeatedPets = 0
        team.folder:SetAttribute("MergeEggExpectedPets", expected)

        if team.initialized then
            if #squad ~= expected then
                return false, "checkpoint_squad_incomplete"
            end
            local root = team.principalModel
                and team.principalModel:FindFirstChild("HumanoidRootPart")
            if not root then
                return false, "checkpoint_hatcher_unavailable"
            end
            local spawned, models =
                self._npcPrincipalService:SpawnGhostSquad(team.folder, squad, root.CFrame, {
                    attributes = {
                        MergeEggUnit = true,
                        MergeEggRunId = record.runId,
                        MergeEggTeamId = team.id,
                        CombatTargetGroup = team.targetGroup,
                        CombatCadenceMultiplier = combatCadenceMultiplier(self._config),
                        EphemeralDownPolicy = "destroy",
                        PrincipalLevel = self:_prototypeBaseLevel(record),
                        Level = self:_prototypeBaseLevel(record),
                        OriginProgressionMultiplier = self:_originPowerForEggTier(
                            math.max(1, team.eggTier),
                            team
                        ),
                    },
                })
            if spawned ~= expected then
                for _, model in ipairs(models or {}) do
                    model:Destroy()
                end
                return false, "checkpoint_unit_assets_missing"
            end
            for slot, model in ipairs(models) do
                team.units[#team.units + 1] = model
                record.units[#record.units + 1] = model
                self:_publishTeamSlot(team, slot, squad[slot])
            end
            team.activePets = spawned
        end
        self:_applyTeamEggTierModifiers(team, team.eggTier)
        if team.eggTier > 0 then
            self:_spawnHatcherEggObjective(record, team)
        end
    end

    for field, value in pairs(snapshot.recordState or {}) do
        record[field] = value
    end
    record.baseEggUpgradeInProgress = false
    local savedEscort = snapshot.playerEscort or {}
    local escortCapacity =
        math.max(0, math.floor(tonumber(savedEscort.capacity) or self:_playerReserveSlots(record)))
    record.playerSquad = cloneSquadDefinitions(savedEscort.squad, escortCapacity)
    record.playerReserve = cloneSquadDefinitions(savedEscort.reserve, #(savedEscort.reserve or {}))
    record.playerReplacementQueue = {}
    record.playerPendingReplacementSlots = {}
    record.playerCastoffsAwarded = savedEscort.castoffsAwarded or 0
    record.playerReplacementsQueued = savedEscort.replacementsQueued or 0
    record.playerReplacementsEquipped = savedEscort.replacementsEquipped or 0
    record.peakPlayerReserveDepth = savedEscort.peakReserveDepth or #record.playerReserve
    record.peakPlayerReplacementQueueDepth = savedEscort.peakQueueDepth or 0
    record.longestPlayerReplacementWaitSeconds = savedEscort.longestReplacementWaitSeconds or 0
    record.playerEscortInitialized = squadDefinitionCount(record.playerSquad, escortCapacity) > 0
    if record.playerEscortInitialized then
        if not self:_spawnPlayerEscortSquad(record, record.playerSquad, escortCapacity) then
            return false, "checkpoint_player_escort_assets_missing"
        end
    else
        record.playerEscortActive = 0
    end
    self:_publishPlayerReserve(record)
    record.eggInventory = table.clone(snapshot.eggInventory or {})
    self:_restoreEggTierMilestones(record)
    if
        not self._economyService:SetCurrency(
            record.player,
            snapshot.currency,
            snapshot.coins,
            "merge_egg_checkpoint_restore"
        )
    then
        return false, "checkpoint_currency_restore_failed"
    end

    record.waveIndex = snapshot.wave
    record.aliveEnemies = 0
    record.pendingWaveSpawns = {}
    record.pendingEnemySpawns = 0
    record.waveGroupCount = 0
    record.waveActiveAttackGroups = 0
    record.waveFullyDeployedAt = nil
    record.waveReinforcementEligibleAt = nil
    record.waveReserveTeamId = nil
    record.waveReserveReleased = false
    record.waveReinforcementsCommitted = 0
    record.nextEnemySpawnAt = nil
    record.pendingCheckpointWave = nil
    record.nextWaveOverride = nil
    record.waveFocusTeamId = nil
    record.objectiveEggsRemaining = snapshot.objectiveEggsRemaining
    record.objectiveHits = snapshot.objectiveHits
    record.enemiesPastBulwark = 0
    record.enemiesPastBreachLine = 0
    record.breachOverrun = false
    record.breachOverrunStartedAt = nil
    record.terminal = false
    record.terminalState = nil
    record.checkpointAutoRestartAt = nil
    record.checkpointRestarts = (record.checkpointRestarts or 0) + 1
    record.checkpointLastFailedWave = failedWave
    record.coinRunnerNoDropSince = nil
    record.stageReportCaptured = false
    local checkpointCfg = self._config.checkpoints or {}
    record.nextWaveAt = os.clock() + math.max(0, tonumber(checkpointCfg.restart_delay_seconds) or 3)
    record.player:SetAttribute("MergeEggWaveComplete", nil)
    self:_setPortalVisible(record, false)
    self:_syncAllTeams(record)
    self:_setWorldState("CheckpointRestarting", record)
    self:_log("Info", "Merge Egg prototype checkpoint restored", {
        player = record.player.Name,
        checkpoint = snapshot.wave,
        failedWave = failedWave,
        restart = record.checkpointRestarts,
        coins = snapshot.coins,
        cause = tostring(cause or "unknown"),
    })
    return true
end

-- Gameplay defeat recovery follows the merge-defense genre contract: the checkpoint contributes
-- only its wave number. Everything the player has earned or arranged since then remains live.
-- Build a temporary snapshot from the CURRENT board/economy/rosters, restore combat objects from
-- that state at full health, then put the original banked snapshot back so deterministic automation
-- can still replay the exact old checkpoint when explicitly requested.
function MergeEggPrototypeService:_restartCheckpointKeepingProgress(record, cause)
    if not self:_canRestartCheckpoint(record) then
        return false, "checkpoint_restart_unavailable"
    end
    local bankedSnapshot = record.checkpointSnapshot
    -- No Wave-10 bank yet: Wave 0 is the opening boundary. Overrun/loss before the first
    -- checkpoint must rewind to Wave 1 and keep the live egg/board/wallet.
    local checkpointWave = bankedSnapshot
            and math.max(0, math.floor(tonumber(bankedSnapshot.wave) or 0))
        or 0

    -- A destroyed installed egg is inactive for the remainder of the failed attempt, but its
    -- deployment is permanent. Rehydrate that identity before capturing the live gameplay state.
    for _, team in ipairs(record.teams or {}) do
        if
            math.floor(tonumber(team.eggTier) or 0) <= 0
            and math.floor(tonumber(team.resetEggTier) or 0) > 0
        then
            team.eggTier = math.floor(tonumber(team.resetEggTier) or 0)
            team.eggId = team.resetEggId
            team.eggName = team.resetEggName
            team.hatchPlayerData = team.resetHatchPlayerData
            team.needsEggRebuild = false
        end
    end

    -- Defeat durability is refilled, not banked. Retained placements will each receive their own
    -- full-health objective below, and the abstract reserve returns to its full attempt capacity.
    record.objectiveEggsRemaining =
        math.max(1, math.floor(tonumber(record.objectiveEggsStarting) or 1))
    record.objectiveHits = 0

    local captured, captureReason = self:_captureCheckpoint(record, checkpointWave, {
        allowTerminal = true,
        allowWaveZero = checkpointWave <= 0,
    })
    if not captured then
        record.checkpointSnapshot = bankedSnapshot
        return false, captureReason
    end

    local restored, restoreReason = self:_restoreCheckpoint(record, cause, {
        advanceUpgradeExperiment = false,
        preserveDrops = true,
    })
    record.checkpointSnapshot = bankedSnapshot
    if not restored then
        return false, restoreReason
    end

    self:_setWorldState("CheckpointRestarting", record)
    self:_log("Info", "Merge Egg prototype gameplay checkpoint retained progress", {
        player = record.player.Name,
        checkpoint = checkpointWave,
        failedWave = record.checkpointLastFailedWave,
        coins = self._economyService:GetCurrency(
            record.player,
            self:_earthEggPricing(record).currency
        ) or 0,
        boardEggs = self:_eggInventoryTotal(record),
        cause = tostring(cause or "unknown"),
    })
    return true
end

function MergeEggPrototypeService:_spawnReplacement(record, team, queued, now)
    local squad = team.config.squad or {}
    local definition = queued.definition
        or self:_rollDraftedPrototypePet(
            record,
            team,
            team,
            math.max(1, math.floor(tonumber(team.eggTier) or 1)),
            queued.slot
        )
    queued.definition = definition
    local root = team.principalModel and team.principalModel:FindFirstChild("HumanoidRootPart")
    if not (definition and root and team.folder and team.folder.Parent) then
        return false
    end
    local attributes = {
        MergeEggUnit = true,
        MergeEggRunId = record.runId,
        MergeEggTeamId = team.id,
        CombatTargetGroup = team.targetGroup,
        CombatCadenceMultiplier = combatCadenceMultiplier(self._config),
        EphemeralDownPolicy = "destroy",
        PrincipalLevel = self:_prototypeBaseLevel(record),
        Level = self:_prototypeBaseLevel(record),
        OriginProgressionMultiplier = tonumber(team.originPowerMultiplier) or 1,
    }
    if definition.role then
        attributes.PetRole = definition.role
    end
    local spawned, models = self._npcPrincipalService:SpawnGhostSquad(
        team.folder,
        { definition },
        root.CFrame,
        {
            attributes = attributes,
            positionOffset = queued.slot - 1,
        }
    )
    if spawned ~= 1 or not models[1] then
        return false
    end
    local model = models[1]
    squad[queued.slot] = definition
    team.units[#team.units + 1] = model
    record.units[#record.units + 1] = model
    self:_recordEggRoll(record, team, definition)
    self:_publishTeamSlot(team, queued.slot, definition)
    self:_ensurePlayerEscort(record)
    team.replacementsHatched = (team.replacementsHatched or 0) + 1
    record.replacementsHatched = (record.replacementsHatched or 0) + 1
    local waitSeconds = math.max(0, now - (tonumber(queued.queuedAt) or now))
    record.longestReplacementWaitSeconds =
        math.max(record.longestReplacementWaitSeconds or 0, waitSeconds)
    self:_log("Info", "Merge Egg prototype replacement hatched", {
        player = record.player.Name,
        team = team.id,
        slot = queued.slot,
        pet = definition.pet,
        variant = definition.variant,
        huge = definition.huge == true,
        waitSeconds = waitSeconds,
        queueDepth = self:_replacementQueueDepth(record) - 1,
    })
    return true
end

function MergeEggPrototypeService:_processReplacementQueues(record, now)
    local cfg = self._config.reinforcement or {}
    if cfg.enabled ~= true or record.terminal == true then
        return
    end
    local hatchSeconds = math.max(0.25, tonumber(cfg.hatch_seconds) or 4)
    for _, team in ipairs(record.teams or {}) do
        local queue = team.replacementQueue or {}
        local queued = queue[1]
        local eggInstalled = math.floor(tonumber(team.eggTier) or 0) > 0
            and team.eggObjective ~= nil
            and team.eggObjective.Parent ~= nil
            and math.max(0, tonumber(team.eggHealth) or 0) > 0
        local productionReadyAt = math.max(
            tonumber(team.nextReplacementAt) or math.huge,
            tonumber(team.eggProductionLockedUntil) or 0
        )
        if queued and eggInstalled and now >= productionReadyAt then
            if self:_spawnReplacement(record, team, queued, now) then
                table.remove(queue, 1)
                team.pendingReplacementSlots[queued.slot] = nil
                team.nextReplacementAt = queue[1] and (now + hatchSeconds) or nil
                self:_syncTeamState(record, team)
            else
                team.nextReplacementAt = now + hatchSeconds
            end
        end
    end
end

function MergeEggPrototypeService:_syncPlayerEscort(record, now)
    if
        record.playerCombatMode == "full"
        or (self._config.player_reserve or {}).enabled ~= true
        or record.playerEscortInitialized ~= true
    then
        return
    end
    local folder = record.petFolder or self:_playerPetFolder(record.player, false)
    if not folder then
        return
    end
    local occupied = {}
    local active = 0
    for _, pet in ipairs(folder:GetChildren()) do
        if pet:IsA("Model") and pet:GetAttribute("MergeEggPlayerReserveUnit") == true then
            active += 1
            local positionNumber = pet:FindFirstChild("PositionNumber")
            local slot =
                math.max(1, math.floor(tonumber(positionNumber and positionNumber.Value) or active))
            occupied[slot] = true
        end
    end

    record.playerEscortActive = active
    record.playerReplacementQueue = record.playerReplacementQueue or {}
    record.playerPendingReplacementSlots = record.playerPendingReplacementSlots or {}
    local delay =
        math.max(0.25, tonumber((self._config.player_reserve or {}).replacement_seconds) or 30)
    local capacity = self:_playerReserveSlots(record)
    local roles = (self._config.player_reserve or {}).roles
        or { "tank", "ranged", "melee", "support" }
    for slot = 1, capacity do
        if
            record.playerSquad[slot] ~= nil
            and not occupied[slot]
            and not record.playerPendingReplacementSlots[slot]
        then
            record.playerPendingReplacementSlots[slot] = true
            record.playerReplacementQueue[#record.playerReplacementQueue + 1] = {
                slot = slot,
                role = roles[slot],
                queuedAt = now,
                readyAt = now + delay,
            }
            record.playerReplacementsQueued = (record.playerReplacementsQueued or 0) + 1
        end
    end
    record.peakPlayerReplacementQueueDepth =
        math.max(record.peakPlayerReplacementQueueDepth or 0, #record.playerReplacementQueue)
    self:_publishPlayerReserve(record)
end

function MergeEggPrototypeService:_processPlayerReplacementQueue(record, now)
    if record.playerCombatMode == "full" then
        return
    end
    local queue = record.playerReplacementQueue or {}
    for index = #queue, 1, -1 do
        local queued = queue[index]
        if now >= (tonumber(queued.readyAt) or math.huge) then
            local definition, reserveIndex = MergeEggDraft.selectPlayerReplacement(
                record.playerReserve,
                queued.role,
                queued.slot <= 3 and "non_support" or "none"
            )
            if definition and reserveIndex then
                local model = self:_spawnPlayerEscortSlot(record, queued.slot, definition)
                if model then
                    table.remove(record.playerReserve, reserveIndex)
                    record.playerSquad[queued.slot] = definition
                    record.playerPendingReplacementSlots[queued.slot] = nil
                    table.remove(queue, index)
                    record.playerEscortActive = (record.playerEscortActive or 0) + 1
                    record.playerReplacementsEquipped = (record.playerReplacementsEquipped or 0) + 1
                    local waitSeconds = math.max(0, now - (tonumber(queued.queuedAt) or now))
                    record.longestPlayerReplacementWaitSeconds =
                        math.max(record.longestPlayerReplacementWaitSeconds or 0, waitSeconds)
                    self:_log("Info", "Merge Egg player reserve replacement equipped", {
                        player = record.player.Name,
                        slot = queued.slot,
                        role = definition.role,
                        pet = definition.pet,
                        variant = definition.variant,
                        waitSeconds = waitSeconds,
                        reserveDepth = #record.playerReserve,
                    })
                end
            end
        end
    end
    self:_publishPlayerReserve(record)
end

function MergeEggPrototypeService:_allTeamsDefeated(record)
    if not (record and record.encounterSpawned and #(record.teams or {}) > 0) then
        return false
    end
    for _, team in ipairs(record.teams) do
        if (team.activePets or 0) > 0 then
            return false
        end
    end
    return true
end

function MergeEggPrototypeService:_finishDefenseOverrun(record)
    if not self:_isRecordActive(record) or record.terminal == true then
        return
    end
    record.terminal = true
    record.terminalState = "DefenseOverrun"
    record.nextWaveAt = nil
    record.pendingWaveSpawns = {}
    record.pendingEnemySpawns = 0
    record.waveGroupCount = 0
    record.nextEnemySpawnAt = nil
    self:_setPortalVisible(record, false)
    local survivingEnemies = 0
    for _, enemy in ipairs(record.enemies or {}) do
        if
            enemy.targetId ~= nil
            and not record.resolvedTargets[enemy.targetId]
            and enemy.model
            and enemy.model.Parent
        then
            record.resolvedTargets[enemy.targetId] = true
            record.enemyByTargetId[enemy.targetId] = nil
            survivingEnemies += 1
            self._enemyService:DespawnModel(enemy.model)
        end
    end
    record.escaped += survivingEnemies
    record.aliveEnemies = 0
    for _, team in ipairs(record.teams or {}) do
        team.assignedAlive = 0
        team.engaged = false
        self:_syncTeamState(record, team)
    end
    record.player:SetAttribute("MergeEggWaveComplete", true)
    self:_setWorldState("DefenseOverrun", record)
    self:_scheduleGameplayCheckpointRestart(record)
    self:_log("Info", "Merge Egg prototype defense overrun", {
        player = record.player.Name,
        wave = record.waveIndex,
        firstLossWave = record.firstPetLossWave,
        peakActiveEnemies = record.peakActiveEnemies,
        defeated = record.defeated,
        escaped = record.escaped,
    })
end

function MergeEggPrototypeService:_finishObjectiveLost(record)
    if not self:_isRecordActive(record) or record.terminal == true then
        return
    end
    record.terminal = true
    record.terminalState = "ObjectiveLost"
    record.nextWaveAt = nil
    record.pendingWaveSpawns = {}
    record.pendingEnemySpawns = 0
    record.nextEnemySpawnAt = nil
    self:_setPortalVisible(record, false)
    local survivingEnemies = 0
    for _, enemy in ipairs(record.enemies or {}) do
        if
            enemy.targetId ~= nil
            and not record.resolvedTargets[enemy.targetId]
            and enemy.model
            and enemy.model.Parent
        then
            record.resolvedTargets[enemy.targetId] = true
            record.enemyByTargetId[enemy.targetId] = nil
            survivingEnemies += 1
            self._enemyService:DespawnModel(enemy.model)
        end
    end
    record.enemiesRemainingAtDefeat = survivingEnemies
    record.aliveEnemies = 0
    for _, team in ipairs(record.teams or {}) do
        team.assignedAlive = 0
        team.engaged = false
        self:_syncTeamState(record, team)
    end
    record.player:SetAttribute("MergeEggWaveComplete", true)
    self:_setWorldState("ObjectiveLost", record)
    self:_scheduleGameplayCheckpointRestart(record)
    self:_log("Info", "Merge Egg prototype egg reserve lost", {
        player = record.player.Name,
        wave = record.waveIndex,
        objectiveHits = record.objectiveHits,
        escaped = record.escaped,
        enemiesRemaining = survivingEnemies,
        replacementsHatched = record.replacementsHatched,
        peakQueueDepth = record.peakReplacementQueueDepth,
    })
end

function MergeEggPrototypeService:_damageObjective(record)
    local cfg = self._config.objective or {}
    local damage = math.max(1, math.floor(tonumber(cfg.damage_per_escape) or 1))
    record.objectiveHits = (record.objectiveHits or 0) + 1
    record.objectiveEggsRemaining = math.max(0, (record.objectiveEggsRemaining or 0) - damage)
    if record.objectiveEggsRemaining <= 0 then
        self:_finishObjectiveLost(record)
        return true
    end
    self:_setWorldState(self:_activeWaveState(record), record)
    return false
end

function MergeEggPrototypeService:_installedHatcherEggTeam(record, enemy)
    local assigned = enemy and record.teamById[enemy.teamId]
    local team = assigned
    if not (team and math.floor(tonumber(team.eggTier) or 0) > 0) then
        team = nil
        for _, candidate in ipairs(record.teams or {}) do
            if math.floor(tonumber(candidate.eggTier) or 0) > 0 then
                team = candidate
                break
            end
        end
    end
    if not team then
        return nil
    end
    return team
end

function MergeEggPrototypeService:_destroyInstalledHatcherEgg(record, team, cause)
    if not (team and math.floor(tonumber(team.eggTier) or 0) > 0) then
        return false
    end

    local destroyedTier = math.floor(tonumber(team.eggTier) or 0)
    local destroyedEgg = team.eggId
    -- The egg is disabled for this failed attempt, not sold or consumed. Preserve its permanent
    -- deployment identity so gameplay recovery can rebuild it in the same position at full health.
    team.resetEggTier = destroyedTier
    team.resetEggId = destroyedEgg
    team.resetEggName = team.eggName
    team.resetHatchPlayerData = team.hatchPlayerData
    self:_removeHatcherEggObjective(team)
    team.eggTier = 0
    team.eggId = nil
    team.eggName = nil
    team.hatchPlayerData = nil
    team.eggHealth = 0
    team.eggDamageTaken = math.max(0, tonumber(team.eggMaxHealth) or 0)
    team.eggProductionLockedUntil = nil
    team.needsEggRebuild = true
    team.eggsDestroyed = (team.eggsDestroyed or 0) + 1
    record.hatcherEggsDestroyed = (record.hatcherEggsDestroyed or 0) + 1
    self:_applyTeamEggTierModifiers(team, 0)
    for _, queued in ipairs(team.replacementQueue or {}) do
        queued.definition = nil
    end
    for _, candidate in ipairs(record.teams or {}) do
        self:_publishTeamEggSource(candidate)
    end
    self:_syncTeamState(record, team)
    self:_log("Info", "Merge Egg prototype installed egg destroyed", {
        player = record.player.Name,
        wave = record.waveIndex,
        team = team.id,
        egg = destroyedEgg,
        tier = destroyedTier,
        cause = tostring(cause or "unknown"),
        rebuildCost = self:_eggTierCost(1, record).amount,
    })
    self:_retargetBreachMarchers(record, team)
    return true
end

function MergeEggPrototypeService:_damageInstalledHatcherEgg(record, enemy)
    local team = self:_installedHatcherEggTeam(record, enemy)
    return self:_destroyInstalledHatcherEgg(record, team, "finish_line")
end

function MergeEggPrototypeService:_attachPrompt(host, name, actionText, objectText, callback)
    if not host then
        return nil
    end
    local existing = host:FindFirstChild(name)
    if existing then
        existing:Destroy()
    end
    local prompt = Instance.new("ProximityPrompt")
    prompt.Name = name
    prompt.ActionText = actionText
    prompt.ObjectText = objectText
    prompt.KeyboardKeyCode = Enum.KeyCode.E
    prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
    prompt.HoldDuration = 0.15
    prompt.MaxActivationDistance = 14
    prompt.RequiresLineOfSight = false
    prompt.Parent = host
    prompt.Triggered:Connect(callback)
    return prompt
end

function MergeEggPrototypeService:_teleportToRole(player, role)
    local placeId = PlaceRuntime.placeIdForRole(self._placesConfig, role)
    if not placeId then
        return false, "place_role_unconfigured"
    end
    local options = Instance.new("TeleportOptions")
    options:SetTeleportData({
        sourcePlaceId = game.PlaceId,
        destinationRole = tostring(role),
    })
    local ok, result = pcall(function()
        return TeleportService:TeleportAsync(placeId, { player }, options)
    end)
    if not ok then
        self:_log("Warn", "Merge place teleport failed", {
            player = player.Name,
            destinationRole = tostring(role),
            destinationPlaceId = placeId,
            error = tostring(result),
        })
        return false, "teleport_failed"
    end
    return true, result
end

function MergeEggPrototypeService:_enterFromHall(player)
    if not self:_hasPreviewAccess(player) then
        self:_log("Warn", "Merge place preview access refused", {
            player = player and player.Name or "unknown",
            userId = player and player.UserId or 0,
            reason = "coming_soon",
        })
        return false, "coming_soon"
    end
    -- Keep one route in every environment. TeleportService rejects cross-place travel from a
    -- Studio playtest, but entering the obsolete embedded prototype would conceal a broken
    -- published route and make the gate appear to target the wrong experience.
    return self:_teleportToRole(player, "merge")
end

function MergeEggPrototypeService:_returnToFarmAndFight(player)
    if not self:_isDedicatedMergePlace() then
        return self:_exit(player)
    end
    local returnCfg = ((self._config.gate or {}).return_route or {})
    return self:_teleportToRole(player, tostring(returnCfg.destination_role or "main"))
end

function MergeEggPrototypeService:_bindPublicReturnGate()
    if not self:_isDedicatedMergePlace() then
        return nil
    end

    local gateCfg = self._config.gate or {}
    local returnCfg = gateCfg.return_route or {}
    if returnCfg.public ~= true then
        return nil
    end
    local hookName = tostring(returnCfg.hook_name or gateCfg.hook_name or "HallOfWorldsPortal")
    local hook = Workspace:FindFirstChild(hookName, true)
    if not (hook and hook:IsA("BasePart")) then
        self:_log("Warn", "Merge return-door hook unavailable", {
            hook = hookName,
        })
        return nil
    end

    -- This authored hook is the common-area door, not a combat-bay control. Styling it at runtime
    -- keeps the permanent map responsible for placement while making the route unmistakable.
    hook:SetAttribute("MergeEggPublicReturnDoor", true)
    hook.Material = Enum.Material.Neon
    hook.Color = rgbTriplet(returnCfg.color, { 82, 216, 255 })
    hook.Transparency = 0.2
    hook.CanCollide = false
    hook.CanTouch = false
    hook.CanQuery = true

    local billboard = hook:FindFirstChild("MergeEggReturnDoorBillboard")
    if billboard then
        billboard:Destroy()
    end
    billboard = Instance.new("BillboardGui")
    billboard.Name = "MergeEggReturnDoorBillboard"
    billboard.Adornee = hook
    billboard.AlwaysOnTop = true
    billboard.LightInfluence = 0
    billboard.MaxDistance = 140
    billboard.Size = UDim2.fromOffset(420, 86)
    billboard.StudsOffsetWorldSpace = Vector3.new(0, hook.Size.Y * 0.5 + 2.5, 0)
    billboard.Parent = hook

    local label = Instance.new("TextLabel")
    label.Name = "Label"
    label.BackgroundTransparency = 1
    label.Size = UDim2.fromScale(1, 1)
    label.Font = Enum.Font.GothamBlack
    label.Text = tostring(returnCfg.label or "RETURN TO FARM & FIGHT")
    label.TextColor3 = Color3.new(1, 1, 1)
    label.TextScaled = true
    label.TextStrokeColor3 = Color3.fromRGB(18, 28, 48)
    label.TextStrokeTransparency = 0
    label.Parent = billboard

    self._returnPrompt = self:_attachPrompt(
        hook,
        tostring(returnCfg.prompt_name or EXIT_PROMPT_NAME),
        tostring(returnCfg.action_text or "Return"),
        tostring(returnCfg.object_text or "Farm & Fight"),
        function(player)
            self:_returnToFarmAndFight(player)
        end
    )
    return hook
end

function MergeEggPrototypeService:_bindRestrictedHallGate()
    local gateCfg = self._config.gate or {}
    local hook = Workspace:FindFirstChild(tostring(gateCfg.hook_name or "HallOfWorldsPortal"), true)
    if not (hook and hook:IsA("BasePart")) then
        self:_log("Warn", "Merge Egg prototype Hall gate hook is missing", {
            hook = gateCfg.hook_name,
        })
        return nil
    end

    -- ZoneService owns the frosted Coming Soon barrier. Leave that presentation and collision
    -- intact; approved preview accounts activate the prompt from the Farm and Fight side and
    -- teleport across places instead of physically crossing this wall.
    local travelPrompt = hook:FindFirstChild("ZoneTravelPrompt", true)
    if travelPrompt and travelPrompt:IsA("ProximityPrompt") then
        travelPrompt:Destroy()
    end
    if CollectionService:HasTag(hook, "MissionDoor") then
        CollectionService:RemoveTag(hook, "MissionDoor")
    end
    hook:SetAttribute("MissionId", nil)
    hook.CanTouch = false
    hook.CanQuery = true

    local title = hook.Parent and hook.Parent:FindFirstChild("HallOfWorldsGateTitle")
    if title then
        for _, descendant in ipairs(title:GetDescendants()) do
            if descendant:IsA("TextLabel") or descendant:IsA("TextButton") then
                descendant.Text = tostring(gateCfg.title or "COMING SOON")
            end
        end
    end

    self._gatePrompt = self:_attachPrompt(
        hook,
        tostring(gateCfg.prompt_name or "MergeEggPrototypeEnterPrompt"),
        tostring(gateCfg.action_text or "Enter"),
        tostring(gateCfg.object_text or "Coming Soon"),
        function(player)
            self:_enterFromHall(player)
        end
    )
    return hook
end

function MergeEggPrototypeService:_bindWorldControls(world)
    local cfg = self._config.world or {}
    -- Entry now arms the encounter. Keep the authored pillar and the service `_hatch` method as a
    -- Studio scripting seam, but remove the obsolete player-facing hold prompt.
    local hatcherControl = findNamedPart(world, cfg.hatcher_control)
    local staleHatchPrompt = hatcherControl
        and hatcherControl:FindFirstChild("MergeEggPrototypeHatchPrompt")
    if staleHatchPrompt then
        staleHatchPrompt:Destroy()
    end
    if hatcherControl then
        hatcherControl:SetAttribute("MergeEggScriptArmOnly", true)
    end
    -- Egg creation and auto-combine are single-click wall SurfaceGuis. Remove stale hold prompts
    -- from older Studio runs; the server still validates distance and session ownership per click.
    for _, row in ipairs({
        {
            host = findNamedPart(world, cfg.egg_create_control or "EggCreateControl"),
            name = CREATE_EGG_PROMPT_NAME,
        },
        {
            host = findNamedPart(world, cfg.egg_merge_control or "EggMergeControl"),
            name = MERGE_EGG_PROMPT_NAME,
        },
    }) do
        local stale = row.host and row.host:FindFirstChild(row.name)
        if stale then
            stale:Destroy()
        end
    end
    self:_attachPrompt(
        findNamedPart(world, cfg.reset_control),
        RESET_PROMPT_NAME,
        "Reset Encounter",
        "Merge an Egg — Phase 6",
        function(player)
            self:_reset(player)
        end
    )
    -- The original in-place Studio prototype retains its local ExitControl. The published Merge
    -- place instead binds one public common-area return door in `_bindPublicReturnGate`.
    if not self:_isDedicatedMergePlace() then
        self:_attachPrompt(
            findNamedPart(world, cfg.exit_control),
            EXIT_PROMPT_NAME,
            "Return Home",
            "Hall Gate",
            function(player)
                self:_exit(player)
            end
        )
    end
end

function MergeEggPrototypeService:_playerPetFolder(player, create)
    local root = Workspace:FindFirstChild("PlayerPets")
    if not root and create then
        root = Instance.new("Folder")
        root.Name = "PlayerPets"
        root.Parent = Workspace
    end
    local folder = root and root:FindFirstChild(player.Name)
    if not folder and root and create then
        folder = Instance.new("Folder")
        folder.Name = player.Name
        folder.Parent = root
    end
    return folder
end

function MergeEggPrototypeService:_prototypeAreaId()
    return tostring((self._config.world or {}).area_id or "MergeEggPrototype")
end

function MergeEggPrototypeService:_setPlayerArea(player, areaId, currentWorldValue)
    if not (player and player.Parent and type(areaId) == "string" and areaId ~= "") then
        return
    end
    if self._worldBindingService then
        self._worldBindingService:SetActiveArea(player, areaId)
    end
    player:SetAttribute("CurrentArea", areaId)
    local currentWorld = player:FindFirstChild("CurrentWorld")
    if currentWorld and currentWorld:IsA("StringValue") then
        currentWorld.Value = tostring(currentWorldValue or areaId)
    end
end

function MergeEggPrototypeService:_reconcileStaleSession(player)
    local record = self:_recordFor(player)
    if not record then
        return false
    end
    local areaId = record.player and record.player:GetAttribute("CurrentArea")
    if areaId == self:_prototypeAreaId() then
        return false
    end
    if self._worldBindingService and record.player and record.player.Parent then
        self._worldBindingService:SetActiveArea(record.player, areaId)
    end
    self:_log("Warn", "Merge Egg prototype repaired stale session from CurrentArea", {
        player = record.player and record.player.Name,
        currentArea = areaId,
    })
    self:_end(record, false, false)
    return true
end

function MergeEggPrototypeService:_canBegin(player)
    if not (player and player.Parent) then
        return false, "player_left"
    end
    self:_reconcileStaleSession(player)
    if self:_recordFor(player) or self._enteringByPlayer[player] then
        return false, "already_inside"
    end
    if
        player:GetAttribute("InMission") ~= nil
        or player:GetAttribute("InPrologue") == true
        or player:GetAttribute("InCombatTutorial") == true
        or player:GetAttribute("GauntletMode") ~= nil
    then
        return false, "temporary_mode_active"
    end
    local folder = self:_playerPetFolder(player, false)
    for _, child in ipairs(folder and folder:GetChildren() or {}) do
        if child:IsA("Model") and child:GetAttribute("GhostPet") == true then
            return false, "temporary_squad_active"
        end
    end
    return true
end

function MergeEggPrototypeService:_parkOwnedPets(record)
    local folder = self:_playerPetFolder(record.player, true)
    if not folder then
        return false
    end
    local parked = Instance.new("Folder")
    parked.Name = "MergeEggPrototypeParked_"
        .. tostring(record.player.UserId)
        .. "_"
        .. record.runId
    parked.Parent = ServerStorage
    for _, model in ipairs(folder:GetChildren()) do
        if model:IsA("Model") and model:GetAttribute("GhostPet") ~= true then
            model.Parent = parked
        end
    end
    record.petFolder = folder
    record.parked = parked
    return true
end

-- Full mode fields the player's durable squad against lane-partitioned prototype enemies. The
-- Simple-mode escort already opts into open targeting per model; publish the equivalent transient
-- contract on the real player's folder so current and newly hatched pets can acquire any nearby
-- lane through ordinary distance/threat rules. Preserve the pre-session value exactly on mode exit.
function MergeEggPrototypeService:_setFullModeTargetOpen(record, enabled)
    if not record then
        return false
    end
    local folder = record.petFolder or self:_playerPetFolder(record.player, false)
    if not folder then
        return false
    end
    if record.playerPetFolderTargetOpenCaptured ~= true then
        record.playerPetFolderTargetOpenCaptured = true
        record.playerPetFolderTargetOpenOriginal = folder:GetAttribute("CombatTargetOpen")
    end
    folder:SetAttribute(
        "CombatTargetOpen",
        enabled == true and true or record.playerPetFolderTargetOpenOriginal
    )
    return true
end

function MergeEggPrototypeService:_preparePlayerPets(record)
    if record.playerCombatMode == "full" then
        local folder = self:_playerPetFolder(record.player, true)
        if not folder then
            return false
        end
        record.petFolder = folder
        self:_setFullModeTargetOpen(record, true)
        return true
    end
    return self:_parkOwnedPets(record)
end

function MergeEggPrototypeService:_switchPlayerCombatMode(record, requestedMode)
    if not self:_isRecordActive(record) then
        return false
    end
    local mode = tostring(requestedMode or "")
    if mode ~= "simple" and mode ~= "full" then
        return false
    end
    if mode == record.playerCombatMode then
        return true
    end
    if mode == "full" then
        self:_clearPlayerEscortModels(record)
        self:_restoreOwnedPets(record)
        record.petFolder = self:_playerPetFolder(record.player, true)
        self:_setFullModeTargetOpen(record, true)
    else
        -- Moving to Simple is an explicit exit from owned-squad combat. Park every durable pet and
        -- let the existing automatic reserve roster resume as later drafts supply cast-offs.
        self:_setFullModeTargetOpen(record, false)
        if not self:_parkOwnedPets(record) then
            return false
        end
    end
    record.playerCombatMode = mode
    record.playerSquad = mode == "full" and {} or record.playerSquad
    record.playerReplacementQueue = mode == "full" and {} or record.playerReplacementQueue
    record.playerPendingReplacementSlots = mode == "full" and {}
        or record.playerPendingReplacementSlots
    if mode == "simple" then
        self:_ensurePlayerEscort(record)
    end
    self:_publishPlayerReserve(record)
    return true
end

function MergeEggPrototypeService:_restoreOwnedPets(record)
    local parked = record.parked
    if not parked then
        return
    end
    local folder = self:_playerPetFolder(record.player, true)
    if folder then
        for _, model in ipairs(parked:GetChildren()) do
            model.Parent = folder
        end
    end
    parked:Destroy()
    record.parked = nil
end

function MergeEggPrototypeService:_cancelPendingEntry(record, departing)
    local player = record and record.player
    if not player or self._enteringRecordByPlayer[player] ~= record then
        return
    end
    self._enteringRecordByPlayer[player] = nil
    self._enteringByPlayer[player] = nil
    self:_setFullModeTargetOpen(record, false)
    if departing then
        if record.parked then
            record.parked:Destroy()
            record.parked = nil
        end
    else
        self:_restoreOwnedPets(record)
    end
    if self._realm then
        self._realm:Release(record.player)
    end
end

function MergeEggPrototypeService:_clearEncounter(record)
    if not record then
        return
    end
    record.coinRunnerGeneration = (record.coinRunnerGeneration or 0) + 1
    record.coinRunnerRunning = false
    if self._automationService and self._automationService.SetPlayerControlsEnabled then
        self._automationService:SetPlayerControlsEnabled(record.player, true)
    end
    if self._dropService and self._dropService.DiscardDrops then
        self._dropService:DiscardDrops(record.player, "merge_egg_prototype")
    end
    if record.coinRunnerOriginalCoins ~= nil and self._economyService then
        local currency = self:_earthEggPricing().currency
        local restored = self._economyService:SetCurrency(
            record.player,
            currency,
            record.coinRunnerOriginalCoins,
            "merge_egg_coin_runner_restore"
        )
        if not restored then
            self:_log("Warn", "Merge Egg coin runner could not restore tester currency", {
                player = record.player.Name,
                currency = currency,
                amount = record.coinRunnerOriginalCoins,
            })
        end
    end
    for _, enemy in ipairs(record.enemies or {}) do
        if enemy.model then
            self._enemyService:DespawnModel(enemy.model)
        end
    end
    self:_clearTowerShots(record)
    self:_clearPlayerEscortModels(record)
    record.enemies = {}
    record.aliveEnemies = 0
    record.hatching = false
    record.waveIndex = 0
    record.defeated = 0
    record.escaped = 0
    record.alerted = 0
    record.breached = 0
    record.bulwarkCrossed = 0
    record.enemiesPastBulwark = 0
    record.peakEnemiesPastBulwark = 0
    record.enemiesPastBreachLine = 0
    record.peakEnemiesPastBreachLine = 0
    record.breachOverrunThreshold = 0
    record.breachOverrun = false
    record.breachOverrunStartedAt = nil
    record.nextBreachDamageAt = nil
    record.breachPressureHits = 0
    record.firstBreachWave = nil
    record.firstOverrunWave = nil
    record.hatcherEggsDestroyed = 0
    record.hatcherEggsRebuilt = 0
    record.eggProductionDamageHits = 0
    record.eggProductionLockouts = 0
    record.healDenialActiveFields = 0
    record.healDenialActivations = 0
    record.healDenialSuppressedEnemies = 0
    record.nextHealDenialTickAt = nil
    record.peakActiveEnemies = 0
    record.firstPetLossWave = nil
    record.firstPetLossActiveEnemies = nil
    record.nextWaveAt = nil
    record.nextWaveOverride = nil
    record.waveFocusTeamId = nil
    record.coinRunnerStartWave = nil
    record.pendingWaveSpawns = {}
    record.pendingEnemySpawns = 0
    record.waveGroupCount = 0
    record.nextEnemySpawnAt = nil
    record.resolvedTargets = {}
    record.enemyByTargetId = {}
    record.nextTeamSyncAt = nil
    local startingEggs =
        math.max(1, math.floor(tonumber((self._config.objective or {}).starting_eggs) or 5))
    record.objectiveEggsStarting = startingEggs
    record.objectiveEggsRemaining = startingEggs
    record.objectiveHits = 0
    record.replacementsHatched = 0
    record.peakReplacementQueueDepth = 0
    record.longestReplacementWaitSeconds = 0
    record.enemiesRemainingAtDefeat = 0
    record.terminal = false
    record.eggId = nil
    record.eggName = nil
    record.hatchPlayerData = nil
    record.eggRolls = 0
    record.eggGoldenRolls = 0
    record.eggRainbowRolls = 0
    record.eggHugeRolls = 0
    record.prototypeHugeRolls = 0
    record.draftCandidateRolls = 0
    record.draftRejectedRolls = 0
    record.draftGoldenCandidates = 0
    record.draftRainbowCandidates = 0
    record.draftHugeCandidates = 0
    record.playerReserve = {}
    record.playerSquad = {}
    record.playerUnits = {}
    record.playerEscortInitialized = false
    record.playerEscortActive = 0
    record.playerEscortCapacity = 0
    record.playerReplacementQueue = {}
    record.playerPendingReplacementSlots = {}
    record.playerCastoffsAwarded = 0
    record.playerReplacementsQueued = 0
    record.playerReplacementsEquipped = 0
    record.peakPlayerReserveDepth = 0
    record.peakPlayerReplacementQueueDepth = 0
    record.longestPlayerReplacementWaitSeconds = 0
    record.maximumEggTier = 0
    record.hatcherEggAdvances = 0
    record.baseEggTier = self:_baseEggTier(nil)
    record.baseEggUpgradesPurchased = 0
    record.baseEggBoardPromotions = 0
    record.baseEggHatcherPromotions = 0
    record.baseEggUpgradeCoinsSpent = 0
    record.baseEggCreationCoinsSpent = 0
    record.baseEggUpgradeInProgress = false
    record.eggInventory = {}
    record.activityEggTierMilestones = {}
    record.activityMaximumPetSlots = nil
    record.eggsCreated = 0
    record.eggsMerged = 0
    record.eggsPlaced = 0
    record.lastEggCreateAt = nil
    record.lastEggMergeAt = nil
    record.eggCreateInProgress = false
    record.autoCombineEnabled = false
    record.coinsDropped = 0
    record.gemsDropped = 0
    record.earthEggCoinsSpent = 0
    record.coreEggCoinsSpent = 0
    record.coinRunnerOriginalCoins = nil
    record.coinRunnerState = "Off"
    record.coinRunnerResult = nil
    record.coinRunnerStopReason = nil
    record.coinRunnerNavigationRecoveries = 0
    record.coinRunnerLastNavigationFailure = nil
    record.coinRunnerTarget = nil
    record.coinRunnerStartingCoins = nil
    record.coinRunnerSeed = nil
    record.coinRunnerEndingCoins = nil
    record.coinRunnerCoinsEarned = nil
    record.coinRunnerCoinsSpent = 0
    record.coinRunnerCoinsDropped = nil
    record.coinRunnerWaveReached = nil
    record.coinRunnerElapsedSeconds = nil
    record.coinRunnerFirstEscapeAt = nil
    record.coinRunnerFirstEscapeHatchers = nil
    record.coinRunnerFirstEscapeWave = nil
    record.coinRunnerFourHatcherAt = nil
    record.coinRunnerFourHatcherWave = nil
    record.coinRunnerAllSandAt = nil
    record.coinRunnerAllSandWave = nil
    record.upgradeExperimentChannel = nil
    record.upgradeExperimentStep = nil
    record.upgradeExperimentAttempt = 0
    record.upgradeExperimentNextAttempt = 1
    record.upgradeExperimentMultiplier = 1
    record.checkpointSnapshot = nil
    record.pendingCheckpointWave = nil
    record.checkpointRestarts = 0
    record.checkpointLastFailedWave = nil
    record.checkpointAutoRestartAt = nil
    record.progressionSequential = false
    record.progressionLoopComplete = false
    record.progressionStageId =
        tostring((self._config.progression_loop or {}).default_stage or "home")
    record.progressionStageReports = {}
    record.progressionCoinsSpentTotal = 0
    record.progressionCoinsDroppedTotal = 0
    record.homeStageComplete = false
    record.homeCompletionCoins = nil
    record.homeEntryReserveRequired = nil
    record.homeEntryReserveMet = false
    record.homeCompletionWave = nil
    record.heaven1StageComplete = false
    record.heaven1CompletionCoins = nil
    record.terminalState = nil
    self:_setPortalVisible(record, false)

    for _, team in ipairs(record.teams or {}) do
        self:_removeHatcherEggObjective(team)
        if team.principalName then
            self._npcPrincipalService:Despawn(team.principalName, "merge_egg_reset")
        end
    end
    record.teams = {}
    record.teamById = {}
    record.units = {}
    record.encounterSpawned = false
    record.player:SetAttribute("CombatAssistTarget", nil)
    record.player:SetAttribute("CombatAssistUntil", nil)
    record.player:SetAttribute("CombatMusicCue", nil)
    record.player:SetAttribute("MergeEggWaveComplete", nil)
    record.tutorialActive = false
    record.tutorialStep = nil
    record.tutorialStepChangedAt = nil
    record.tutorialStepReadyAt = nil
    record.tutorialUsesAutoCollector = false
    self:_publishPlayerReserve(record)
    self:_syncMergeBoardEggs(record)
    self:_setWorldState("ReadyToHatch", record)
end

function MergeEggPrototypeService:_end(record, teleportHome, departing, discardProgress)
    if not self:_isRecordActive(record) then
        return
    end
    if discardProgress ~= true then
        self:_persistPlaystate(record, "merge_defense_session_end", true)
    end
    self._activeByPlayer[record.player] = nil
    disconnect(record.characterRemoving)
    disconnect(record.areaChanged)
    disconnect(record.playerCombatModeChanged)
    self:_setFullModeTargetOpen(record, false)
    self:_clearEncounter(record)
    record.player:SetAttribute("CombatAssistTarget", record.assistTarget)
    record.player:SetAttribute("CombatAssistUntil", record.assistUntil)
    record.player:SetAttribute("InMergeEggPrototype", nil)
    record.player:SetAttribute("MergeEggRunId", nil)
    record.player:SetAttribute("MergeEggEscortAnchorPosition", nil)
    record.player:SetAttribute("MergeEggEscortAnchorLookVector", nil)
    record.player:SetAttribute("MergeEggReserveRosterCapacity", nil)
    record.player:SetAttribute("MergeEggReserveRosterHasExtraSlot", nil)
    record.player:SetAttribute("MergeEggReserveRosterActive", nil)
    record.player:SetAttribute("MergeEggReserveRosterBench", nil)
    record.player:SetAttribute("MergeEggReserveRosterPending", nil)
    record.player:SetAttribute("MergeEggReserveRosterCastoffs", nil)
    record.player:SetAttribute("MergeEggReserveRosterReplacements", nil)
    record.player:SetAttribute("MergeEggPlayerCombatMode", nil)
    record.player:SetAttribute("MergeEggRealPlayerHatches", nil)
    record.player:SetAttribute("MergeDefenseRebirths", nil)
    record.player:SetAttribute("MergeDefenseRebirthDamageMultiplier", nil)
    record.player:SetAttribute("MergeDefenseManagementDamageMultiplier", nil)
    record.player:SetAttribute("MergeDefenseAlliedDamageMultiplier", nil)

    if departing then
        if record.parked then
            record.parked:Destroy()
            record.parked = nil
        end
    else
        self:_restoreOwnedPets(record)
    end

    if teleportHome and record.player.Parent and record.returnCFrame then
        pcall(function()
            record.player:RequestStreamAroundAsync(
                record.returnCFrame.Position,
                tonumber(self._config.stream_timeout) or 8
            )
        end)
        local character = record.player.Character
        if character and characterRoot(record.player) then
            character:PivotTo(record.returnCFrame)
            self:_setPlayerArea(
                record.player,
                record.returnArea or "Spawn",
                record.returnCurrentWorld or record.returnArea or "Spawn"
            )
        end
    end
    if self._realm then
        self._realm:Release(record.player)
    end
    self:_setWorldState("Idle", record)
    self:_log("Info", "Merge Egg prototype session ended", {
        player = record.player.Name,
        bay = record.bayId,
        departing = departing == true,
    })
end

function MergeEggPrototypeService:_begin(player, requestedBayId, opts)
    opts = type(opts) == "table" and opts or {}
    local ok, reason = self:_canBegin(player)
    if not ok then
        self:_log("Warn", "Merge Egg prototype entry refused", {
            player = player and player.Name,
            reason = reason,
        })
        return false, reason
    end
    local realmConfig = type(self._config.realm_layout) == "table" and self._config.realm_layout
        or {}
    local world
    local bayId
    if self._realm and realmConfig.enabled ~= false then
        -- Ensure the portable shell exists before assigning a player. An optional authoring
        -- override makes Hall entry reproducible; an in-realm claim pad still requests its own
        -- specific bay. Removing the override restores random empty-bay assignment.
        self:_resolveWorld()
        local claimed, claimedId
        local authoringBayId = configuredAuthoringBayId(realmConfig)
        if requestedBayId then
            claimed, claimedId = self._realm:Claim(player, requestedBayId)
        elseif authoringBayId then
            claimed, claimedId = self._realm:Claim(player, authoringBayId)
            if not claimed and claimedId == "bay_occupied" then
                claimed, claimedId = self._realm:ClaimRandom(player)
            end
        else
            claimed, claimedId = self._realm:ClaimRandom(player)
        end
        if not claimed then
            return false, claimedId
        end
        bayId = claimedId
        world = self:_resolveWorld(bayId)
    else
        world = self._world or self:_resolveWorld()
    end
    if world then
        -- Start binds the authoring/default bay. A dedicated-place claim may resolve a different
        -- authored bay, so bind that bay's controls as part of the claim as well.
        self:_bindWorldControls(world)
        if self:_isDedicatedMergePlace() then
            local baySpawn = world:FindFirstChildWhichIsA("SpawnLocation", true)
            if baySpawn then
                player.RespawnLocation = baySpawn
            end
        end
    end
    local spawn = findNamedPart(world, (self._config.world or {}).player_spawn)
    if not (world and spawn and characterRoot(player)) then
        if self._realm then
            self._realm:Release(player)
        end
        return false, "world_or_character_unavailable"
    end

    self._enteringByPlayer[player] = true
    local modelsReady = BootReadiness.await("models_ready", 20)
    if not self._enteringByPlayer[player] then
        if self._realm then
            self._realm:Release(player)
        end
        return false, "entry_cancelled"
    end
    if not modelsReady then
        self:_log("Warn", "Merge Egg prototype entered before pet models were ready")
    end

    local character = player.Character
    if not (player.Parent and character and characterRoot(player)) then
        self._enteringByPlayer[player] = nil
        if self._realm then
            self._realm:Release(player)
        end
        return false, "character_unavailable"
    end

    local objectiveEggsStarting =
        math.max(1, math.floor(tonumber((self._config.objective or {}).starting_eggs) or 5))
    local defaultExperiment = self:_balanceExperiment(nil)
    local defaultStageId = self:_progressionStage(nil)
    local mergeDefenseProgress = self:_mergeDefenseProgress(player)
        or MergeEggPlayerCombat.normalizeOnboarding(nil)
    local _, personalHatchTier, personalHatchEggId =
        self:_reconcilePersonalHatchAreas(player, mergeDefenseProgress.rebirths)
    local record = {
        player = player,
        world = world,
        bayId = bayId,
        durableCheckpoint = opts.ignoreCheckpoint == true and nil
            or self:_durableCheckpoint(player),
        durablePlaystate = opts.ignoreCheckpoint == true and nil or self:_durablePlaystate(player),
        playerCombatMode = self:_playerCombatMode(player),
        runId = HttpService:GenerateGUID(false),
        baseCombatLevel = playerCombatLevel(player, (self._config.principal or {}).level),
        balanceExperiment = defaultExperiment,
        progressionStageId = defaultStageId,
        progressionSequential = false,
        progressionLoopComplete = false,
        progressionStageReports = {},
        progressionCoinsSpentTotal = 0,
        progressionCoinsDroppedTotal = 0,
        returnCFrame = character:GetPivot(),
        returnArea = player:GetAttribute("CurrentArea"),
        returnCurrentWorld = (player:FindFirstChild("CurrentWorld") and player
            :FindFirstChild("CurrentWorld")
            :IsA("StringValue") and player:FindFirstChild("CurrentWorld").Value) or nil,
        assistTarget = player:GetAttribute("CombatAssistTarget"),
        assistUntil = player:GetAttribute("CombatAssistUntil"),
        enemies = {},
        enemyByTargetId = {},
        units = {},
        towerShots = {},
        towersReady = false,
        bulwarksReady = false,
        teams = {},
        teamById = {},
        aliveEnemies = 0,
        waveIndex = 0,
        defeated = 0,
        escaped = 0,
        alerted = 0,
        breached = 0,
        bulwarkCrossed = 0,
        enemiesPastBulwark = 0,
        peakEnemiesPastBulwark = 0,
        enemiesPastBreachLine = 0,
        peakEnemiesPastBreachLine = 0,
        breachOverrunThreshold = 0,
        breachOverrun = false,
        breachOverrunStartedAt = nil,
        nextBreachDamageAt = nil,
        breachPressureHits = 0,
        firstBreachWave = nil,
        firstOverrunWave = nil,
        hatcherEggsDestroyed = 0,
        hatcherEggsRebuilt = 0,
        eggProductionDamageHits = 0,
        eggProductionLockouts = 0,
        healDenialActiveFields = 0,
        healDenialActivations = 0,
        healDenialSuppressedEnemies = 0,
        nextHealDenialTickAt = 0,
        peakActiveEnemies = 0,
        firstPetLossWave = nil,
        firstPetLossActiveEnemies = nil,
        nextWaveAt = nil,
        nextWaveOverride = nil,
        waveFocusTeamId = nil,
        coinRunnerStartWave = nil,
        pendingWaveSpawns = {},
        pendingEnemySpawns = 0,
        waveGroupCount = 0,
        waveActiveAttackGroups = 0,
        waveFullyDeployedAt = nil,
        waveReinforcementEligibleAt = nil,
        waveReserveTeamId = nil,
        waveReserveReleased = false,
        waveReinforcementsCommitted = 0,
        nextEnemySpawnAt = nil,
        portalVisible = false,
        resolvedTargets = {},
        random = Random.new(),
        -- Roster variation must not perturb movement paths or reward rolls in matched test runs.
        enemyRosterRandom = Random.new(),
        -- Loot must not perturb randomized paths in deterministic balance runs.
        lootRandom = Random.new(),
        encounterSpawned = false,
        nextTeamSyncAt = 0,
        objectiveEggsStarting = objectiveEggsStarting,
        objectiveEggsRemaining = objectiveEggsStarting,
        objectiveHits = 0,
        replacementsHatched = 0,
        peakReplacementQueueDepth = 0,
        longestReplacementWaitSeconds = 0,
        enemiesRemainingAtDefeat = 0,
        eggId = nil,
        eggName = nil,
        hatchPlayerData = nil,
        eggRolls = 0,
        eggGoldenRolls = 0,
        eggRainbowRolls = 0,
        eggHugeRolls = 0,
        prototypeHugeRolls = 0,
        draftCandidateRolls = 0,
        draftRejectedRolls = 0,
        draftGoldenCandidates = 0,
        draftRainbowCandidates = 0,
        draftHugeCandidates = 0,
        playerReserve = {},
        playerSquad = {},
        playerUnits = {},
        playerEscortInitialized = false,
        playerEscortActive = 0,
        playerEscortCapacity = 0,
        playerReplacementQueue = {},
        playerPendingReplacementSlots = {},
        playerCastoffsAwarded = 0,
        playerReplacementsQueued = 0,
        playerReplacementsEquipped = 0,
        playerRealHatchesAwarded = 0,
        peakPlayerReserveDepth = 0,
        peakPlayerReplacementQueueDepth = 0,
        longestPlayerReplacementWaitSeconds = 0,
        maximumEggTier = 0,
        hatcherEggAdvances = 0,
        baseEggTier = self:_baseEggTier(nil),
        baseEggUpgradesPurchased = 0,
        baseEggBoardPromotions = 0,
        baseEggHatcherPromotions = 0,
        baseEggUpgradeCoinsSpent = 0,
        baseEggCreationCoinsSpent = 0,
        baseEggUpgradeInProgress = false,
        eggInventory = {},
        activityEggTierMilestones = {},
        activityMaximumPetSlots = nil,
        eggsCreated = 0,
        eggsMerged = 0,
        eggsPlaced = 0,
        lastEggCreateAt = nil,
        lastEggMergeAt = nil,
        eggCreateInProgress = false,
        autoCombineEnabled = false,
        coinsDropped = 0,
        gemsDropped = 0,
        earthEggCoinsSpent = 0,
        coreEggCoinsSpent = 0,
        coinRunnerGeneration = 0,
        coinRunnerRunning = false,
        coinRunnerState = "Off",
        coinRunnerResult = nil,
        coinRunnerStopReason = nil,
        coinRunnerNavigationRecoveries = 0,
        coinRunnerLastNavigationFailure = nil,
        coinRunnerTarget = nil,
        coinRunnerOriginalCoins = nil,
        coinRunnerStartingCoins = nil,
        coinRunnerSeed = nil,
        coinRunnerEndingCoins = nil,
        coinRunnerCoinsEarned = nil,
        coinRunnerCoinsSpent = 0,
        coinRunnerCoinsDropped = nil,
        coinRunnerWaveReached = nil,
        coinRunnerElapsedSeconds = nil,
        coinRunnerFirstEscapeAt = nil,
        coinRunnerFirstEscapeHatchers = nil,
        coinRunnerFirstEscapeWave = nil,
        coinRunnerFourHatcherAt = nil,
        coinRunnerFourHatcherWave = nil,
        coinRunnerAllSandAt = nil,
        coinRunnerAllSandWave = nil,
        upgradeExperimentChannel = nil,
        upgradeExperimentStep = nil,
        upgradeExperimentAttempt = 0,
        upgradeExperimentNextAttempt = 1,
        upgradeExperimentMultiplier = 1,
        managementUpgradeLevels = table.clone(mergeDefenseProgress.management_upgrades or {}),
        managementUpgradeGemsSpent = math.max(
            0,
            math.floor(tonumber(mergeDefenseProgress.management_gems_spent) or 0)
        ),
        managementUpgradeInProgress = false,
        bulwarkFamily = mergeDefenseProgress.bulwark_family,
        bulwarkTier = mergeDefenseProgress.bulwark_tier,
        eggBulwarkFamily = mergeDefenseProgress.egg_bulwark_family,
        eggBulwarkTier = mergeDefenseProgress.egg_bulwark_tier,
        midBulwarkFamily = mergeDefenseProgress.mid_bulwark_family,
        midBulwarkTier = mergeDefenseProgress.mid_bulwark_tier,
        frontBulwarkFamily = mergeDefenseProgress.front_bulwark_family,
        frontBulwarkTier = mergeDefenseProgress.front_bulwark_tier,
        bulwarkOwned = table.clone(mergeDefenseProgress.bulwark_owned or {}),
        bulwarkSlots = table.clone(mergeDefenseProgress.bulwark_slots or {}),
        bulwarkActionInProgress = false,
        leftTowerFamily = mergeDefenseProgress.left_tower_family,
        leftTowerTier = mergeDefenseProgress.left_tower_tier,
        rightTowerFamily = mergeDefenseProgress.right_tower_family,
        rightTowerTier = mergeDefenseProgress.right_tower_tier,
        towerOwned = table.clone(mergeDefenseProgress.tower_owned or {}),
        towerSlots = table.clone(mergeDefenseProgress.tower_slots or {}),
        towerActionInProgress = false,
        towerWaycoinsSpent = math.max(
            0,
            math.floor(tonumber(mergeDefenseProgress.tower_waycoins_spent) or 0)
        ),
        bulwarkWaycoinsSpent = math.max(
            0,
            math.floor(tonumber(mergeDefenseProgress.bulwark_waycoins_spent) or 0)
        ),
        rebirthCount = MergeEggRebirth.normalizeCount(mergeDefenseProgress.rebirths),
        personalHatchTier = personalHatchTier,
        personalHatchEggId = personalHatchEggId,
        rebirthInProgress = false,
        checkpointSnapshot = nil,
        pendingCheckpointWave = nil,
        checkpointRestarts = 0,
        checkpointLastFailedWave = nil,
        checkpointAutoRestartAt = nil,
        homeStageComplete = false,
        homeCompletionCoins = nil,
        homeEntryReserveRequired = nil,
        homeEntryReserveMet = false,
        homeCompletionWave = nil,
        heaven1StageComplete = false,
        heaven1CompletionCoins = nil,
        terminalState = nil,
        terminal = false,
        sessionCurrency = nil,
        sessionStartingCoins = nil,
        tutorialActive = false,
        tutorialStep = nil,
        tutorialStepChangedAt = nil,
        tutorialStepReadyAt = nil,
        tutorialUsesAutoCollector = false,
    }
    self:_hydrateTowerState(record, mergeDefenseProgress)
    if not self:_preparePlayerPets(record) then
        self._enteringByPlayer[player] = nil
        if self._realm then
            self._realm:Release(player)
        end
        return false, "pet_folder_unavailable"
    end
    self._enteringRecordByPlayer[player] = record

    local target = spawn.CFrame * CFrame.new(0, spawn.Size.Y * 0.5 + 3, 0)
    -- The dedicated Merge place already owns the bay being entered. RequestStreamAroundAsync can
    -- wait indefinitely when Studio is stopped and restarted against the large authored realm,
    -- leaving DataLoaded true but never committing the Merge session. Hall entry still needs the
    -- stream request because it moves the player into a distant map inside Farm & Fight.
    if not self:_isDedicatedMergePlace() then
        pcall(function()
            player:RequestStreamAroundAsync(
                target.Position,
                tonumber(self._config.stream_timeout) or 8
            )
        end)
    end
    if
        self._enteringRecordByPlayer[player] ~= record
        or not self._enteringByPlayer[player]
        or not player.Parent
        or player.Character ~= character
    then
        self:_cancelPendingEntry(record, not player.Parent)
        return false, "left_during_stream"
    end
    if not (character and characterRoot(player)) then
        self:_cancelPendingEntry(record, false)
        return false, "character_unavailable"
    end

    local currencyReady, currencyReason = self:_prepareSessionCurrency(record)
    if not currencyReady then
        self:_cancelPendingEntry(record, false)
        return false, currencyReason
    end

    -- Commit the session only after streaming has returned and the character can be moved. There
    -- must be no yield between the visible pivot and the replicated inside state: otherwise the
    -- Hall gate can reject a second attempt while the player is still standing in Home.
    character:PivotTo(target)
    self:_setPlayerArea(player, self:_prototypeAreaId())
    self._enteringRecordByPlayer[player] = nil
    self._enteringByPlayer[player] = nil
    self._activeByPlayer[player] = record
    self:_ensureBayTowers(record)
    self:_ensureBayBulwarks(record)
    self:_ensureBayQuartermaster(record)
    local escortAnchor = self:_playerEscortAnchorCFrame(record)
    player:SetAttribute(
        "MergeEggEscortAnchorPosition",
        escortAnchor and escortAnchor.Position or nil
    )
    player:SetAttribute(
        "MergeEggEscortAnchorLookVector",
        escortAnchor and escortAnchor.LookVector or nil
    )
    player:SetAttribute("InMergeEggPrototype", true)
    player:SetAttribute("MergeEggRunId", record.runId)
    if self._settingsService and self._settingsService.RecordMergeDefenseEntry then
        self._settingsService:RecordMergeDefenseEntry(player)
    end
    local durableCoins = math.max(
        0,
        math.floor(tonumber(record.durablePlaystate and record.durablePlaystate.coins) or 0)
    )
    -- Old builds could stamp saved=true when the only durable fact was tutorial completion. That
    -- empty record is not a possession and must never suppress the five opening coin piles. Apply
    -- this guard regardless of tutorial status so already-persisted legacy records self-heal.
    local resumePlaystate = opts.ignoreCheckpoint ~= true
        and MergeEggPlaystate.isUsable(record.durablePlaystate, self:_checkpointOptions())
        and (durableCoins > 0 or self:_playstateHasBoard(record.durablePlaystate))
    local resumeCheckpoint = not resumePlaystate
        and opts.ignoreCheckpoint ~= true
        and MergeEggCheckpoint.isUsable(record.durableCheckpoint, self:_checkpointOptions())
    if not resumePlaystate and not resumeCheckpoint then
        self:_resetSessionCurrency(record)
        self:_spawnOpeningCoinDrops(record)
    end
    self:_publishPlayerReserve(record)
    record.characterRemoving = player.CharacterRemoving:Connect(function()
        self:_end(record, false, false)
    end)
    record.areaChanged = player:GetAttributeChangedSignal("CurrentArea"):Connect(function()
        if
            self:_isRecordActive(record)
            and player:GetAttribute("CurrentArea") ~= self:_prototypeAreaId()
        then
            if self._worldBindingService then
                self._worldBindingService:SetActiveArea(player, player:GetAttribute("CurrentArea"))
            end
            self:_end(record, false, false)
        end
    end)
    record.playerCombatModeChanged = player
        :GetAttributeChangedSignal("MergeDefenseMode")
        :Connect(function()
            if self:_isRecordActive(record) then
                self:_switchPlayerCombatMode(record, player:GetAttribute("MergeDefenseMode"))
            end
        end)
    -- Settings may finish applying while the character is streaming into a dedicated place. Catch
    -- that one-time edge so an eligible veteran never keeps the temporary Simple roster alongside
    -- their newly restored Full-mode pets.
    self:_switchPlayerCombatMode(record, player:GetAttribute("MergeDefenseMode"))
    local armed, armReason = self:_hatch(player)
    if not armed then
        self:_log("Warn", "Merge Egg prototype could not arm on entry", {
            player = player.Name,
            reason = armReason,
        })
        self:_end(record, true, false, true)
        return false, armReason
    end
    if resumePlaystate then
        local restored, restoreReason = self:_restoreDurablePlaystate(record)
        if not restored then
            self:_log("Warn", "Merge Egg durable playstate could not resume", {
                player = player.Name,
                bay = bayId,
                reason = restoreReason,
            })
            self:_end(record, true, false, true)
            return false, restoreReason
        end
        self:_startTutorial(record, opts.forceTutorial == true)
    elseif resumeCheckpoint then
        local restored, restoreReason = self:_restoreDurableCheckpoint(record)
        if not restored then
            self:_log("Warn", "Merge Egg durable checkpoint could not resume", {
                player = player.Name,
                bay = bayId,
                reason = restoreReason,
            })
            self:_end(record, true, false, true)
            return false, restoreReason
        end
    else
        self:_startTutorial(record, opts.forceTutorial == true)
    end
    self:_log("Info", "Merge Egg prototype session began", {
        player = player.Name,
        runId = record.runId,
        bay = bayId,
        resumedPlaystate = resumePlaystate,
        resumedCheckpoint = resumeCheckpoint,
    })
    return true
end

function MergeEggPrototypeService:_movementLeash(record, recovery)
    local bounds = (self._config.world or {}).bounds or {}
    local authored = findNamedPart(self:_worldFor(record), "ArenaBounds")
    return {
        shapes = {
            {
                kind = "box",
                cx = authored and authored.Position.X or tonumber(bounds.center_x) or -16000,
                cz = authored and authored.Position.Z or tonumber(bounds.center_z) or 0,
                halfX = authored and authored.Size.X * 0.5
                    or math.max(4, tonumber(bounds.half_x) or 46),
                halfZ = authored and authored.Size.Z * 0.5
                    or math.max(4, tonumber(bounds.half_z) or 296),
            },
        },
        inset = math.max(0, tonumber(bounds.inset) or 3),
        recovery = recovery,
    }
end

function MergeEggPrototypeService:_resolveEnemy(record, outcome, targetId)
    if not self:_isRecordActive(record) or targetId == nil or record.resolvedTargets[targetId] then
        return
    end
    record.resolvedTargets[targetId] = true
    local enemy = record.enemyByTargetId[targetId]
    local team = enemy and record.teamById[enemy.teamId]
    record.enemyByTargetId[targetId] = nil
    if team then
        team.assignedAlive = math.max(0, (team.assignedAlive or 0) - 1)
        if team.assignedAlive == 0 then
            team.engaged = false
        end
        self:_syncTeamState(record, team)
    end
    record.aliveEnemies = math.max(0, record.aliveEnemies - 1)
    if outcome == "escaped" then
        if record.coinRunnerRunning and record.coinRunnerFirstEscapeAt == nil then
            record.coinRunnerFirstEscapeAt = os.clock()
            record.coinRunnerFirstEscapeHatchers = self:_initializedHatcherCount(record)
            record.coinRunnerFirstEscapeWave = record.waveIndex
        end
        record.escaped += 1
        if self:_damageObjective(record) then
            return
        end
    else
        record.defeated += 1
    end

    if record.aliveEnemies > 0 or (record.pendingEnemySpawns or 0) > 0 then
        self:_setWorldState(self:_activeWaveState(record), record)
        return
    end

    for _, assignedTeam in ipairs(record.teams or {}) do
        assignedTeam.engaged = false
    end
    self:_syncAllTeams(record)
    local combatLayerId, combatLayer = self:_combatLayerForWave(record, record.waveIndex)
    local checkpointWave =
        math.max(1, math.floor(tonumber(combatLayer.through_wave) or self:_waveCount(record)))
    if record.waveIndex >= checkpointWave then
        local checkpointCoins = self._economyService:GetCurrency(
            record.player,
            self:_earthEggPricing(record).currency
        ) or 0
        if combatLayerId == "home" and record.homeStageComplete ~= true then
            record.homeStageComplete = true
            record.homeCompletionWave = record.waveIndex
            record.homeCompletionCoins = checkpointCoins
        elseif combatLayerId == "heaven_1" and record.heaven1StageComplete ~= true then
            record.heaven1StageComplete = true
            record.heaven1CompletionCoins = checkpointCoins
        end
    end
    if
        (self._config.endurance or {}).stop_when_all_teams_defeated == true
        and self:_allTeamsDefeated(record)
    then
        self:_finishDefenseOverrun(record)
        return
    end
    local waveCount = self:_waveCount(record)
    if record.waveIndex < waveCount then
        if self:_shouldStartWorkshopTutorial(record) then
            self:_startWorkshopTutorial(record)
            return
        end
        if self:_shouldStartCannonTutorial(record) then
            self:_startCannonTutorial(record)
            return
        end
        if self:_shouldStartUpgradeTutorial(record) then
            self:_startUpgradeTutorial(record)
            return
        end
        if self:_shouldStartQuartermasterTutorial(record) then
            self:_startQuartermasterTutorial(record)
            return
        end
        local resolvedWave = self:_waveFor(record, record.waveIndex) or {}
        local waveGap =
            math.max(0, tonumber(resolvedWave.gap_after) or tonumber(self._config.wave_gap) or 2)
        local checkpointCfg = self._config.checkpoints or {}
        local checkpointInterval = math.max(1, math.floor(tonumber(checkpointCfg.interval) or 10))
        local reachedCheckpoint = record.waveIndex % checkpointInterval == 0
        if reachedCheckpoint then
            record.pendingCheckpointWave = record.waveIndex
            waveGap =
                math.max(waveGap, math.max(0, tonumber(checkpointCfg.intermission_seconds) or 8))
        end
        record.nextWaveAt = os.clock() + waveGap
        self:_setWorldState(
            reachedCheckpoint and "CheckpointIntermission" or "WaveIntermission",
            record
        )
        self:_log("Info", "Merge Egg prototype wave resolved", {
            player = record.player.Name,
            wave = record.waveIndex,
            nextWaveIn = waveGap,
            checkpoint = reachedCheckpoint,
            defeated = record.defeated,
            escaped = record.escaped,
        })
        return
    end

    record.nextWaveAt = nil
    record.terminal = true
    record.terminalState = "EncounterComplete"
    self:_setPortalVisible(record, false)
    record.player:SetAttribute("MergeEggWaveComplete", true)
    self:_setWorldState("EncounterComplete", record)
    self:_log("Info", "Merge Egg prototype encounter complete", {
        player = record.player.Name,
        waves = record.waveIndex,
        defeated = record.defeated,
        escaped = record.escaped,
    })
end

function MergeEggPrototypeService:_dropEnemyCoins(record, defeat)
    if
        not self:_isRecordActive(record) or not (defeat and typeof(defeat.position) == "Vector3")
    then
        return false
    end
    local model = defeat.model
    local amount = math.max(
        0,
        math.floor(
            (tonumber(model and model:GetAttribute("MergeEggCoinReward")) or 0)
                    * self:_managementUpgradeMultiplier(record, "coin_value")
                    * self:_rebirthScalingMultiplier(record, "coins", "amount")
                + 0.5
        )
    )
    if amount <= 0 then
        return false
    end
    local rewardCfg = self._config.rewards or {}
    local currency = tostring(rewardCfg.currency or "hall_coins")
    local carried = false
    if self._dropService and self._dropService.SpawnCoinDrop then
        local ok, result = pcall(function()
            return self._dropService:SpawnCoinDrop(
                record.player,
                currency,
                amount,
                defeat.position,
                self:_prototypeCoinDropOptions(record)
            )
        end)
        carried = ok and result == true
    end
    if not carried and self._economyService and self._economyService.AddCurrency then
        local ok, result = pcall(function()
            return self._economyService:AddCurrency(
                record.player,
                currency,
                amount,
                "merge_egg_enemy_defeat"
            )
        end)
        carried = ok and result == true
    end
    if carried then
        record.coinsDropped = (record.coinsDropped or 0) + amount
        self:_setWorldState(self:_activeWaveState(record), record)
    end
    return carried
end

function MergeEggPrototypeService:_dropEnemyGems(record, defeat)
    if
        not self:_isRecordActive(record) or not (defeat and typeof(defeat.position) == "Vector3")
    then
        return false
    end
    local rewardCfg = self._config.rewards or {}
    local gemCfg = type(rewardCfg.gem_drop) == "table" and rewardCfg.gem_drop or {}
    local model = defeat.model
    local rank = tostring(model and model:GetAttribute("MergeEggRank") or "trash")
    local multipliers = type(gemCfg.rank_chance_multiplier) == "table"
            and gemCfg.rank_chance_multiplier
        or {}
    local chance = math.clamp(
        math.max(0, tonumber(gemCfg.base_chance) or 0.02)
            * math.max(0, tonumber(multipliers[rank]) or 1),
        0,
        1
    )
    chance = math.clamp(chance * self:_rebirthScalingMultiplier(record, "gems", "chance"), 0, 1)
    local roll = record.lootRandom and record.lootRandom:NextNumber() or math.random()
    if roll >= chance then
        return false
    end

    local amount = math.max(
        1,
        math.floor(
            (tonumber(gemCfg.amount) or 1)
                    * self:_rebirthScalingMultiplier(record, "gems", "amount")
                + 0.5
        )
    )
    local currency = tostring(gemCfg.currency or "gems")
    local options = self:_prototypeCoinDropOptions(record)
    options.source = "merge_egg_prototype_gem"
    options.visualScale = math.max(0.1, tonumber(gemCfg.visual_scale) or 1.5)
    local carried = false
    if self._dropService and self._dropService.SpawnCoinDrop then
        local ok, result = pcall(function()
            return self._dropService:SpawnCoinDrop(
                record.player,
                currency,
                amount,
                defeat.position,
                options
            )
        end)
        carried = ok and result == true
    end
    if not carried and self._economyService and self._economyService.AddCurrency then
        local ok, result = pcall(function()
            return self._economyService:AddCurrency(
                record.player,
                currency,
                amount,
                "merge_egg_enemy_gem_defeat"
            )
        end)
        carried = ok and result == true
    end
    if carried then
        record.gemsDropped = (record.gemsDropped or 0) + amount
        self:_setWorldState(self:_activeWaveState(record), record)
    end
    return carried
end

function MergeEggPrototypeService:_onEnemyDefeated(record, defeat)
    self:_dropEnemyCoins(record, defeat)
    self:_dropEnemyGems(record, defeat)
    self:_resolveEnemy(record, "defeated", defeat and defeat.targetId)
end

function MergeEggPrototypeService:_livingHatcherEggs(record)
    local eggs = {}
    for _, team in ipairs(record and record.teams or {}) do
        local model = team.eggObjective
        if
            model
            and model.Parent
            and team.eggObjectiveArmed == true
            and math.floor(tonumber(team.eggTier) or 0) > 0
        then
            eggs[#eggs + 1] = {
                team = team,
                model = model,
                position = model:GetPivot().Position,
            }
        end
    end
    return eggs
end

function MergeEggPrototypeService:_pickHatcherEggForEnemy(record, enemy, fromPos, eggs)
    eggs = eggs or self:_livingHatcherEggs(record)
    if #eggs == 0 then
        return nil
    end
    local assignedId = enemy and enemy.teamId
    if assignedId ~= nil then
        for _, egg in ipairs(eggs) do
            if egg.team and egg.team.id == assignedId then
                return egg
            end
        end
    end
    local origin = fromPos
    if typeof(origin) ~= "Vector3" then
        origin = enemy and enemy.model and enemy.model:GetPivot().Position
    end
    if typeof(origin) ~= "Vector3" then
        return eggs[1]
    end
    table.sort(eggs, function(a, b)
        local da = (a.position - origin).Magnitude
        local db = (b.position - origin).Magnitude
        if da == db then
            return (a.team and a.team.id or 0) < (b.team and b.team.id or 0)
        end
        return da < db
    end)
    return eggs[1]
end

function MergeEggPrototypeService:_resumeEnemyToFinish(record, enemy)
    if not (record and enemy and enemy.model and enemy.model.Parent and self._enemyService) then
        return false
    end
    local dest = enemy.finishDestination
    if typeof(dest) ~= "Vector3" then
        local worldCfg = self._config.world or {}
        local finish = findNamedPart(record.world, worldCfg.enemy_finish_line or "EnemyFinishLine")
        dest = finish and finish.Position
    end
    if typeof(dest) ~= "Vector3" then
        return false
    end
    local cfg = self._config.enemy or {}
    return self._enemyService:RedirectMarchGoal(enemy.targetId, {
        destination = dest,
        speed = math.max(1, tonumber(cfg.march_speed) or 22),
        arriveDistance = math.max(0, tonumber(cfg.finish_distance) or 2),
        onReached = function(arrival)
            self:_onEnemyReachedFinish(record, arrival)
        end,
    })
end

function MergeEggPrototypeService:_retargetEnemyToEggs(record, enemy, fromPos)
    if not (record and enemy and enemy.model and enemy.model.Parent and self._enemyService) then
        return false
    end
    local eggs = self:_livingHatcherEggs(record)
    local origin = fromPos
    if typeof(origin) ~= "Vector3" then
        origin = self:_enemyLivePosition(enemy)
    end
    local pick = self:_pickHatcherEggForEnemy(record, enemy, origin, eggs)
    if not pick then
        return false
    end
    local model = enemy.model
    model:SetAttribute("MergeEggCanAttackObjective", true)
    model:SetAttribute("CombatTargetOpen", true)
    local cfg = self._config.enemy or {}
    local arrive = math.max(3, tonumber(cfg.egg_arrive_distance) or 6)
    -- Always rewrite the march. Skipping "close enough" left killers
    -- standing on a dead pad, and GetPivot() is the portal spawn.
    self._enemyService:RedirectMarchGoal(enemy.targetId, {
        destination = pick.position,
        speed = math.max(1, tonumber(cfg.march_speed) or 22),
        arriveDistance = arrive,
        onReached = function(arrival)
            self:_onEnemyReachedEggObjective(record, arrival)
        end,
    })
    self._enemyService:ForceAttackTarget(enemy.targetId, pick.model, {
        threat = 10000,
        ownerName = record.player and record.player.Name,
    })
    return true
end

function MergeEggPrototypeService:_enemyNeedsEggRetarget(enemy, lostTeam)
    local model = enemy and enemy.model
    if not (model and model.Parent and (tonumber(model:GetAttribute("HP")) or 0) > 0) then
        return false
    end
    if
        model:GetAttribute("MergeEggCanAttackObjective") == true
        or model:GetAttribute("MergeEggBreachLineCrossed") == true
        or model:GetAttribute("MergeEggBulwarkBreached") == true
    then
        return true
    end
    if lostTeam and enemy.teamId == lostTeam.id then
        return true
    end
    return model:GetAttribute("MarchGoalReached") == true
end

function MergeEggPrototypeService:_reopenDefenseAfterEggLoss(record, lostTeam)
    if lostTeam then
        lostTeam.isReserve = false
        if lostTeam.folder and lostTeam.folder.Parent then
            lostTeam.folder:SetAttribute("CombatTargetOpen", true)
        end
    end
    record.waveReserveReleased = true
    record.waveReinforcementEligibleAt = 0
    for _, enemy in ipairs(record.enemies or {}) do
        local model = enemy.model
        if model and model.Parent and (tonumber(model:GetAttribute("HP")) or 0) > 0 then
            self:_alertTeamsToBulwarkTarget(record, enemy)
        end
    end
    self:_reinforceIdleTeams(record, os.clock())
end

function MergeEggPrototypeService:_retargetBreachMarchers(record, lostTeam)
    if not record then
        return
    end
    local eggs = self:_livingHatcherEggs(record)
    for _, enemy in ipairs(record.enemies or {}) do
        if self:_enemyNeedsEggRetarget(enemy, lostTeam) then
            if #eggs > 0 then
                self:_retargetEnemyToEggs(record, enemy, self:_enemyLivePosition(enemy))
            else
                self:_resumeEnemyToFinish(record, enemy)
            end
        end
    end
    if #eggs > 0 then
        self:_reopenDefenseAfterEggLoss(record, lostTeam)
    end
end

function MergeEggPrototypeService:_onEnemyReachedEggObjective(record, arrival)
    if not self:_isRecordActive(record) or not arrival then
        return
    end
    local enemy = record.enemyByTargetId[arrival.targetId]
    if not self:_retargetEnemyToEggs(record, enemy, arrival.position) then
        self:_resumeEnemyToFinish(record, enemy)
    end
end

function MergeEggPrototypeService:_onEnemyReachedFinish(record, arrival)
    if not self:_isRecordActive(record) or not arrival then
        return
    end
    local enemy = record.enemyByTargetId[arrival.targetId]
    if self:_retargetEnemyToEggs(record, enemy, arrival.position) then
        return
    end
    self:_damageInstalledHatcherEgg(record, enemy)
    self._enemyService:DespawnModel(arrival.model)
    self:_resolveEnemy(record, "escaped", arrival.targetId)
end

function MergeEggPrototypeService:_spawnWaveEnemy(record, spec)
    local cfg = self._config.enemy or {}
    local spawnInset = math.max(0, tonumber(cfg.spawn_inset) or 5)
    local finishInset = math.max(0, tonumber(cfg.finish_inset) or 5)
    local position = randomPointOnPart(record.random, spec.spawnArea, spawnInset, spawnInset)
        + Vector3.new(0, 3, 0)
    -- Each enemy has only one waypoint: a randomized point across the same finish line. Its
    -- random origin-to-finish vector is its complete path; combat may pull it off that vector.
    local destination =
        randomPointOnPart(record.random, spec.finishLine, finishInset, spec.finishLine.Size.Z * 0.5)
    local result = self._enemyService:SpawnEnemy(record.player, spec.enemyId, {
        def = cloneEnemyDef(
            spec.enemyDef,
            spec.spawnCfg,
            self:_prototypeBaseLevel(record),
            (self._config.combat_level or {}).rank_tiers
        ),
        -- Preserve the canonical Farm & Fight reward definition separately. The combat clone above
        -- still clears its drop table, so autonomous NPC kills remain on Merge's Waycoin/Gem path;
        -- EnemyService may read this only for a trained durable-player-pet final hit.
        combatRewardDef = spec.enemyDef,
        position = position,
        home = position,
        movementLeash = self:_movementLeash(record, position),
        marchGoal = {
            destination = destination,
            speed = math.max(1, tonumber(cfg.march_speed) or 22),
            arriveDistance = math.max(0, tonumber(cfg.finish_distance) or 2),
            onReached = function(arrival)
                self:_onEnemyReachedFinish(record, arrival)
            end,
        },
        rewardPolicy = "none",
        persistent = true,
        dormant = true,
        ungated = true,
        ignoreEnemyLevelOffset = true,
        onDefeated = function(defeat)
            self:_onEnemyDefeated(record, defeat)
        end,
    })
    if not (result and result.ok and result.model) then
        return false, result and result.reason or "enemy_spawn_failed"
    end
    if not self:_isRecordActive(record) then
        self._enemyService:DespawnModel(result.model)
        return false, "session_ended"
    end

    local model = result.model
    local team = spec.team
    model:SetAttribute("MergeEggPrototypeEnemy", true)
    model:SetAttribute("MergeRunId", record.runId)
    model:SetAttribute("MergeEggWave", record.waveIndex)
    model:SetAttribute("MergeEggSpawnIndex", spec.index)
    model:SetAttribute("MergeEggAssignedTeamId", team.id)
    model:SetAttribute("MergeEggAssignedTeamName", team.displayName)
    model:SetAttribute("CombatTargetGroup", team.targetGroup)
    model:SetAttribute("CombatCadenceMultiplier", combatCadenceMultiplier(self._config))
    model:SetAttribute("MergeEggAttackGroup", spec.groupIndex or 1)
    model:SetAttribute("MergeEggAttackGroupKind", spec.groupKind or "legacy")
    model:SetAttribute("MergeEggCompositionRole", spec.compositionRole or "melee")
    model:SetAttribute("MergeEggArchetype", spec.archetype or "legacy")
    model:SetAttribute("MergeEggFaction", spec.faction or "neutral")
    model:SetAttribute("MergeEggRank", spec.rank or "trash")
    model:SetAttribute("MergeEggDamage", tonumber(spec.enemyDef and spec.enemyDef.damage) or 0)
    model:SetAttribute("MergeEggRosterMode", spec.rosterMode or "legacy")
    model:SetAttribute("MergeEggDefenderEgg", spec.defenderEggId)
    model:SetAttribute("MergeEggDefenderEggTier", spec.defenderEggTier)
    model:SetAttribute("MergeEggAttackerEgg", spec.attackerEggId)
    model:SetAttribute("MergeEggEnemyPetId", spec.enemyPetId)
    model:SetAttribute("MergeEggBaseCombatLevel", self:_prototypeBaseLevel(record))
    local rewardCfg = self._config.rewards or {}
    local rewardMultiplier = self:_stageRewardMultiplier(record)
    local rewardKind = tostring(spec.rewardKind or "trash")
    local rewardAmount = tonumber(rewardCfg[rewardKind .. "_amount"])
    if rewardAmount == nil then
        rewardAmount = spec.compositionRole == "tank" and tonumber(rewardCfg.tank_amount)
            or tonumber(rewardCfg.trash_amount)
    end
    model:SetAttribute(
        "MergeEggCoinReward",
        math.floor(
            math.max(0, rewardAmount or 0)
                * rewardMultiplier
                * self:_upgradeExperimentMultiplier(record, "coins")
        )
    )
    result.teamId = team.id
    result.finishDestination = destination
    record.enemies[#record.enemies + 1] = result
    record.enemyByTargetId[result.targetId] = result
    record.aliveEnemies += 1
    team.assignedAlive += 1
    record.peakActiveEnemies = math.max(record.peakActiveEnemies or 0, record.aliveEnemies)
    return true
end

function MergeEggPrototypeService:_processWaveSpawns(record, now)
    if not record or (record.pendingEnemySpawns or 0) <= 0 then
        return true
    end
    if now < (record.nextEnemySpawnAt or 0) then
        return true
    end

    local spec = table.remove(record.pendingWaveSpawns, 1)
    if not spec then
        record.pendingEnemySpawns = 0
        self:_setPortalVisible(record, false)
        return false, "wave_spawn_queue_missing"
    end
    local ok, reason = self:_spawnWaveEnemy(record, spec)
    if not ok then
        record.pendingWaveSpawns = {}
        record.pendingEnemySpawns = 0
        record.nextEnemySpawnAt = nil
        record.nextWaveAt = nil
        record.terminal = true
        record.terminalState = "WaveSpawnFailed"
        self:_setPortalVisible(record, false)
        self:_setWorldState("WaveSpawnFailed", record)
        self:_log("Warn", "Merge Egg prototype wave spawn failed", {
            player = record.player.Name,
            wave = record.waveIndex,
            reason = reason,
        })
        return false, reason
    end

    record.pendingEnemySpawns = #record.pendingWaveSpawns
    if record.pendingEnemySpawns == 0 then
        record.nextEnemySpawnAt = nil
        record.waveFullyDeployedAt = now
        record.waveReinforcementEligibleAt = now
            + math.max(
                0,
                tonumber((self._config.enemy or {}).idle_reinforcement_grace_seconds) or 2
            )
        self:_setPortalVisible(record, false)
        self:_setWorldState("WaveActive", record)
    else
        record.nextEnemySpawnAt = now
            + math.max(0.05, tonumber((self._config.enemy or {}).portal_spawn_interval) or 0.15)
        self:_setWorldState("WaveDeploying", record)
    end
    self:_syncAllTeams(record)
    return true
end

function MergeEggPrototypeService:_enemyRosterRoll(record)
    local random = record and (record.enemyRosterRandom or record.random)
    return random and random:NextNumber() or math.random()
end

function MergeEggPrototypeService:_resolveWaveEnemy(
    record,
    team,
    archetypeKey,
    archetype,
    waveIndex
)
    local enemyCfg = self._config.enemy or {}
    local rosters = type(enemyCfg.rosters) == "table" and enemyCfg.rosters or {}
    local presentationByRank = type(enemyCfg.rank_presentation) == "table"
            and enemyCfg.rank_presentation
        or {}
    local rank = tostring(archetype.rank or "trash")
    local presentation = type(presentationByRank[rank]) == "table" and presentationByRank[rank]
        or {}
    local progression = self:_eggProgression(record)
    local defenderEggId, defenderTier = MergeEggEnemyRoster.defenderEgg(
        progression,
        team and team.eggTier,
        record and record.baseEggTier
    )
    local attackerEggId = MergeEggEnemyRoster.opposingEgg(rosters, defenderEggId)
    local enemyId
    local enemyDef
    local enemyPetId
    local rosterMode

    if attackerEggId then
        local candidate = MergeEggEnemyRoster.eggPet(
            self._petsConfig,
            self._petRolesConfig,
            rosters,
            attackerEggId,
            archetypeKey,
            self:_enemyRosterRoll(record)
        )
        enemyPetId = candidate and candidate.id or nil
        if not enemyPetId then
            return nil, "opposition_egg_roster_empty"
        end
        enemyId = "petinv_" .. enemyPetId
        enemyDef = self._enemyService.SynthesizePetEnemy
                and self._enemyService:SynthesizePetEnemy(
                    enemyPetId,
                    presentation,
                    self:_prototypeBaseLevel(record)
                )
            or nil
        rosterMode = "opposition_egg"
    else
        enemyId = MergeEggEnemyRoster.homeEnemyId(
            rosters,
            archetypeKey,
            self:_enemyRosterRoll(record)
        ) or tostring(archetype.id or "")
        local source = (self._enemiesConfig.enemies or {})[enemyId]
        enemyDef = applyStaticRankPresentation(source, presentation)
        rosterMode = "home_mixed"
    end
    if not enemyDef then
        return nil, "enemy_config_missing"
    end

    -- Ranked positions keep the independently rolled species' durability, then apply the
    -- presentation's HP multiplier. Ordinary minion/tank slots retain the prototype's established
    -- balance values. This makes a Lieutenant/Boss random without rewriting canonical pet stats.
    local spawnSource = archetype
    if tonumber(presentation.hp_mult) or tonumber(presentation.dmg_mult) then
        spawnSource = table.clone(archetype)
        if tonumber(presentation.hp_mult) then
            spawnSource.hp = enemyDef.hp
        end
        if tonumber(presentation.dmg_mult) then
            spawnSource.damage = tonumber(enemyDef.attack and enemyDef.attack.damage)
                or archetype.damage
        end
    end
    local spawnCfg = self:_stageEnemyConfig(record, spawnSource, waveIndex)
    spawnCfg.id = enemyId
    spawnCfg.display_name = enemyDef.display_name
    return {
        enemyId = enemyId,
        enemyDef = enemyDef,
        spawnCfg = spawnCfg,
        defenderEggId = defenderEggId,
        defenderEggTier = defenderTier,
        attackerEggId = attackerEggId,
        enemyPetId = enemyPetId,
        rosterMode = rosterMode,
        faction = tostring(
            enemyPetId and ((self._petsConfig.pets or {})[enemyPetId] or {}).realm
                or (rosters.home or {}).faction
                or archetype.faction
                or "neutral"
        ),
        compositionRole = tostring(enemyDef.role or archetype.composition_role or "melee"),
    }
end

function MergeEggPrototypeService:_spawnNextWave(record)
    if record.terminal == true then
        return false, "encounter_terminal"
    end
    local cfg = self._config.enemy or {}
    local enemyDefs = self._enemiesConfig.enemies or {}
    local archetypes = type(cfg.archetypes) == "table" and cfg.archetypes or {}
    local trashCfg = type(archetypes.whelp) == "table" and archetypes.whelp or cfg
    local tankCfg = type(archetypes.brute) == "table" and archetypes.brute
        or type(cfg.tank) == "table" and cfg.tank
        or nil
    local waveIndex =
        math.max(1, math.floor(tonumber(record.nextWaveOverride) or (record.waveIndex + 1)))
    local wave = self:_waveFor(record, waveIndex)
    if not wave then
        return false, "wave_config_missing"
    end
    local pendingCheckpoint = tonumber(record.pendingCheckpointWave)
    if pendingCheckpoint and waveIndex > pendingCheckpoint then
        local captured, checkpointReason = self:_captureCheckpoint(record, pendingCheckpoint)
        if not captured then
            self:_log("Warn", "Merge Egg prototype checkpoint capture failed", {
                player = record.player.Name,
                wave = pendingCheckpoint,
                reason = checkpointReason,
            })
        end
    end
    local worldCfg = self._config.world or {}
    local spawnArea = findNamedPart(record.world, worldCfg.enemy_spawn_area)
    local finishLine = findNamedPart(record.world, worldCfg.enemy_finish_line)
    if not (spawnArea and finishLine) then
        return false, "enemy_march_anchor_missing"
    end
    if #record.teams == 0 then
        return false, "defense_team_missing"
    end

    local assignmentTeams = {}
    for _, team in ipairs(record.teams) do
        if team.initialized == true then
            assignmentTeams[#assignmentTeams + 1] = team
        end
    end
    for _, team in ipairs(record.teams) do
        if team.initialized ~= true then
            assignmentTeams[#assignmentTeams + 1] = team
        end
    end
    local focusTeamId = tonumber(record.waveFocusTeamId)
    local focusTeam = focusTeamId and record.teamById[focusTeamId]
    if focusTeam then
        assignmentTeams = { focusTeam }
    end

    local pending = {}
    local authoredGroups = type(wave.groups) == "table" and wave.groups or nil
    if authoredGroups and #authoredGroups > 0 then
        for groupIndex, group in ipairs(authoredGroups) do
            local team = assignmentTeams[((groupIndex - 1) % #assignmentTeams) + 1]
            local units = type(group.units) == "table" and group.units or nil
            if units and #units > 0 then
                for _, unit in ipairs(units) do
                    local archetypeKey = tostring(unit.archetype or "")
                    local archetype = archetypes[archetypeKey]
                    if type(archetype) ~= "table" then
                        return false, "wave_archetype_invalid"
                    end
                    if not team then
                        return false, "defense_team_missing"
                    end
                    local unitCount = math.max(1, math.floor(tonumber(unit.count) or 1))
                    for _ = 1, unitCount do
                        local resolved, resolveReason =
                            self:_resolveWaveEnemy(record, team, archetypeKey, archetype, waveIndex)
                        if not resolved then
                            return false, resolveReason
                        end
                        pending[#pending + 1] = {
                            index = #pending + 1,
                            team = team,
                            groupIndex = groupIndex,
                            groupKind = tostring(group.kind or archetype.rank or archetypeKey),
                            compositionRole = resolved.compositionRole,
                            archetype = archetypeKey,
                            faction = tostring(group.faction or resolved.faction),
                            rank = tostring(archetype.rank or "trash"),
                            rewardKind = tostring(archetype.reward_kind or "trash"),
                            spawnCfg = resolved.spawnCfg,
                            enemyId = resolved.enemyId,
                            enemyDef = resolved.enemyDef,
                            defenderEggId = resolved.defenderEggId,
                            defenderEggTier = resolved.defenderEggTier,
                            attackerEggId = resolved.attackerEggId,
                            enemyPetId = resolved.enemyPetId,
                            rosterMode = resolved.rosterMode,
                            spawnArea = spawnArea,
                            finishLine = finishLine,
                        }
                    end
                end
            else
                -- Backward-compatible parser for any saved tuning branch that still uses
                -- `{kind = "tank", count = 4}` (one Brute lead plus three Whelp escorts).
                local groupKind = tostring(group.kind or "trash")
                local groupCount = math.max(1, math.floor(tonumber(group.count) or 1))
                if groupKind ~= "trash" and groupKind ~= "tank" then
                    return false, "wave_group_kind_invalid"
                end
                if groupKind == "tank" and not tankCfg then
                    return false, "enemy_tank_config_missing"
                end
                for groupOrdinal = 1, groupCount do
                    local isTank = groupKind == "tank" and groupOrdinal == 1
                    local archetype = (isTank and tankCfg) or trashCfg
                    local spawnCfg = self:_stageEnemyConfig(record, archetype, waveIndex)
                    local enemyId = tostring(spawnCfg.id or "")
                    local enemyDef = enemyDefs[enemyId]
                    if not (team and enemyDef) then
                        return false, team and "enemy_config_missing" or "defense_team_missing"
                    end
                    pending[#pending + 1] = {
                        index = #pending + 1,
                        team = team,
                        groupIndex = groupIndex,
                        groupKind = groupKind,
                        compositionRole = isTank and "tank" or "melee",
                        archetype = isTank and "brute" or "whelp",
                        faction = tostring(archetype.faction or "neutral"),
                        rank = tostring(archetype.rank or (isTank and "tank" or "trash")),
                        rewardKind = tostring(
                            archetype.reward_kind or (isTank and "tank" or "trash")
                        ),
                        spawnCfg = spawnCfg,
                        enemyId = enemyId,
                        enemyDef = enemyDef,
                        spawnArea = spawnArea,
                        finishLine = finishLine,
                    }
                end
            end
        end
    else
        local count = math.max(1, math.floor(tonumber(wave.count) or 1))
        for index = 1, count do
            local teamIndex = ((index - 1) % #assignmentTeams) + 1
            local teamOrdinal = math.floor((index - 1) / #assignmentTeams) + 1
            local team = assignmentTeams[teamIndex]
            local isTank = teamOrdinal == 1 and tankCfg ~= nil
            local archetype = (isTank and tankCfg) or trashCfg
            local spawnCfg = self:_stageEnemyConfig(record, archetype, waveIndex)
            local enemyId = tostring(spawnCfg.id or "")
            local enemyDef = enemyDefs[enemyId]
            if not (team and enemyDef) then
                return false, team and "enemy_config_missing" or "defense_team_missing"
            end
            pending[#pending + 1] = {
                index = index,
                team = team,
                groupIndex = teamIndex,
                groupKind = tankCfg and "tank" or "trash",
                compositionRole = isTank and "tank" or "melee",
                archetype = isTank and "brute" or "whelp",
                faction = tostring(archetype.faction or "neutral"),
                rank = tostring(archetype.rank or (isTank and "tank" or "trash")),
                rewardKind = tostring(archetype.reward_kind or (isTank and "tank" or "trash")),
                spawnCfg = spawnCfg,
                enemyId = enemyId,
                enemyDef = enemyDef,
                spawnArea = spawnArea,
                finishLine = finishLine,
            }
        end
    end
    if #pending ~= configuredWaveEnemyCount(wave) then
        return false, "wave_group_count_mismatch"
    end
    local maximumWaveEnemies = math.max(1, math.floor(tonumber(cfg.maximum_wave_enemies) or 32))
    if #pending > maximumWaveEnemies then
        return false, "wave_enemy_limit_exceeded"
    end

    record.waveIndex = waveIndex
    record.nextWaveOverride = nil
    -- AreaMusicController treats a changed cue as a request to rotate combat music without
    -- dropping combat state. Including the run id guarantees Wave 1 changes on every new session.
    local stageId = self:_progressionStage(record)
    record.player:SetAttribute(
        "CombatMusicCue",
        record.runId .. ":" .. stageId .. ":wave:" .. waveIndex
    )
    record.nextWaveAt = nil
    record.aliveEnemies = 0
    record.pendingWaveSpawns = pending
    record.pendingEnemySpawns = #pending
    record.waveGroupCount = authoredGroups and #authoredGroups
        or math.min(#assignmentTeams, #pending)
    record.waveActiveAttackGroups = 0
    record.waveFullyDeployedAt = nil
    record.waveReinforcementEligibleAt = nil
    record.waveReserveTeamId = nil
    record.waveReserveReleased = false
    record.waveReinforcementsCommitted = 0
    record.nextEnemySpawnAt = 0
    for _, team in ipairs(record.teams or {}) do
        team.assignedAlive = 0
        team.engaged = false
        team.isReserve = false
        team.reinforcementCommitted = false
        team.reinforcementReason = nil
        team.reinforcementTargetId = nil
        team.nextReinforcementAlertAt = nil
        if team.folder and team.folder.Parent then
            team.folder:SetAttribute("CombatTargetOpen", false)
        end
    end
    self:_setPortalVisible(record, true)
    self:_syncAllTeams(record)
    self:_setWorldState("WaveDeploying", record)
    return true
end

function MergeEggPrototypeService:_teamEngagedWithEnemy(team, enemy)
    local folder = team and team.folder
    if not (folder and folder.Parent and enemy and enemy.model) then
        return false
    end
    local targetRef = enemy.model:FindFirstChild("AggroTargetRef")
    local target = targetRef and targetRef.Value
    if target and target:IsDescendantOf(folder) then
        return true
    end
    for _, pet in ipairs(folder:GetChildren()) do
        if pet:IsA("Model") then
            local targetType = pet:FindFirstChild("TargetType")
            local targetId = pet:FindFirstChild("TargetID")
            if
                targetType
                and tostring(targetType.Value) == "Enemy"
                and targetId
                and tonumber(targetId.Value) == tonumber(enemy.targetId)
            then
                return true
            end
        end
    end
    return false
end

function MergeEggPrototypeService:_teamHasLiveCombatTarget(record, team)
    for _, enemy in ipairs(record.enemies or {}) do
        local model = enemy.model
        if
            model
            and model.Parent
            and (tonumber(model:GetAttribute("HP")) or 0) > 0
            and self:_teamEngagedWithEnemy(team, enemy)
        then
            return true
        end
    end
    return false
end

function MergeEggPrototypeService:_activeAttackGroupCount(record)
    local groups = {}
    for _, enemy in ipairs(record.enemies or {}) do
        local model = enemy.model
        if model and model.Parent and (tonumber(model:GetAttribute("HP")) or 0) > 0 then
            groups[tostring(model:GetAttribute("MergeEggAttackGroup") or enemy.teamId or 1)] = true
        end
    end
    local count = 0
    for _ in pairs(groups) do
        count += 1
    end
    return count
end

function MergeEggPrototypeService:_hardestReinforcementTarget(record)
    local candidates = {}
    for _, enemy in ipairs(record.enemies or {}) do
        local model = enemy.model
        if
            model
            and model.Parent
            and (tonumber(model:GetAttribute("HP")) or 0) > 0
            and model:GetAttribute("MergeEggDefenseAlerted") == true
        then
            candidates[#candidates + 1] = {
                enemy = enemy,
                rank = model:GetAttribute("MergeEggRank"),
                role = model:GetAttribute("MergeEggCompositionRole"),
                maxHealth = model:GetAttribute("MaxHP"),
                currentHealth = model:GetAttribute("HP"),
                damage = model:GetAttribute("MergeEggDamage"),
                spawnIndex = model:GetAttribute("MergeEggSpawnIndex"),
            }
        end
    end
    local hardest = MergeEggDefenseAssignment.pickHardest(candidates)
    return hardest and hardest.enemy or nil
end

function MergeEggPrototypeService:_openReinforcementTeam(record, team, reason, targetId)
    if not (team and team.folder and team.folder.Parent) then
        return false
    end
    local newlyCommitted = team.reinforcementCommitted ~= true
    team.isReserve = false
    team.reinforcementCommitted = true
    team.reinforcementReason = tostring(reason or "idle")
    team.reinforcementTargetId = targetId
    team.folder:SetAttribute("CombatTargetOpen", true)
    if newlyCommitted then
        record.waveReinforcementsCommitted = (record.waveReinforcementsCommitted or 0) + 1
    end
    return newlyCommitted
end

function MergeEggPrototypeService:_commitIdleTeam(record, team, enemy, reason)
    if not (enemy and enemy.model and enemy.model.Parent) then
        return false
    end
    local now = os.clock()
    if
        team.reinforcementTargetId == enemy.targetId
        and now < (tonumber(team.nextReinforcementAlertAt) or 0)
    then
        return false
    end
    self:_openReinforcementTeam(record, team, reason, enemy.targetId)
    local threat = math.max(1, tonumber((self._config.enemy or {}).engagement_threat) or 250)
    local ok, alertedPets =
        self._enemyService:AlertPetFolderToEnemy(team.folder, enemy.targetId, { threat = threat })
    if not ok then
        return false
    end
    team.nextReinforcementAlertAt = now
        + math.max(0.25, tonumber((self._config.enemy or {}).reengage_seconds) or 1)
    team.engaged = true
    self:_setTeamState(record, team, "Engaged")
    self:_log("Info", "Merge Egg idle team committed as reinforcement", {
        player = record.player.Name,
        wave = record.waveIndex,
        team = team.id,
        target = enemy.model.Name,
        targetId = enemy.targetId,
        rank = enemy.model:GetAttribute("MergeEggRank"),
        reason = reason,
        alertedPets = alertedPets,
    })
    return true
end

function MergeEggPrototypeService:_reinforceIdleTeams(record, now)
    if
        now < (tonumber(record.waveReinforcementEligibleAt) or math.huge)
        or (record.aliveEnemies or 0) <= 0
    then
        return
    end

    local activeTeams = {}
    local idleTeams = {}
    for _, team in ipairs(record.teams or {}) do
        if
            team.initialized == true
            and team.folder
            and team.folder.Parent
            and (team.activePets or 0) > 0
        then
            activeTeams[#activeTeams + 1] = team
            if not self:_teamHasLiveCombatTarget(record, team) then
                idleTeams[#idleTeams + 1] = team
            else
                team.isReserve = false
            end
        end
    end
    local activeAttackGroups = self:_activeAttackGroupCount(record)
    record.waveActiveAttackGroups = activeAttackGroups
    local hardest = self:_hardestReinforcementTarget(record)
    if #idleTeams == 0 or not hardest then
        record.waveReserveTeamId = nil
        return
    end

    table.sort(idleTeams, function(left, right)
        return left.id < right.id
    end)
    local cfg = self._config.enemy or {}
    local reserveCount = MergeEggDefenseAssignment.reserveCount(
        #activeTeams,
        activeAttackGroups,
        record.waveReserveReleased,
        tonumber(cfg.maximum_reserve_teams) or 1
    )
    reserveCount = math.min(reserveCount, #idleTeams)
    local commitThrough = #idleTeams - reserveCount
    local previousReserveTeamId = record.waveReserveTeamId
    record.waveReserveTeamId = nil
    local committedAny = false
    for index, team in ipairs(idleTeams) do
        if index <= commitThrough then
            team.isReserve = false
            committedAny = self:_commitIdleTeam(
                record,
                team,
                hardest,
                activeAttackGroups >= #activeTeams and "attack_group_pressure" or "idle_duplicate"
            ) or committedAny
        else
            team.isReserve = true
            record.waveReserveTeamId = team.id
        end
    end
    if previousReserveTeamId ~= record.waveReserveTeamId or committedAny then
        self:_syncAllTeams(record)
        self:_setWorldState(self:_activeWaveState(record), record)
    end
end

function MergeEggPrototypeService:_alertTeamsToBulwarkTarget(record, enemy)
    local reserveTeams = 0
    local alertedPets = 0
    local alertedPlayerPets = 0
    local threat = math.max(
        1,
        tonumber((self._config.enemy or {}).bulwark_threat)
            or tonumber((self._config.enemy or {}).engagement_threat)
            or 250
    )
    for _, team in ipairs(record.teams or {}) do
        if team.folder and team.folder.Parent and (team.activePets or 0) > 0 then
            local ok, count = self._enemyService:AlertPetFolderToEnemy(
                team.folder,
                enemy.targetId,
                { threat = threat }
            )
            if ok then
                reserveTeams += 1
                alertedPets += count
                team.engaged = true
                self:_setTeamState(record, team, "Engaged")
            end
        end
    end

    -- The player's escort holds at the red breach line instead of following the avatar around the
    -- management area. Merely opening its target-group gate is not enough: at that anchor, a real
    -- Full-mode squad can sit outside ambient acquisition range while the four NPC folders receive
    -- explicit Bulwark alerts. Give the player folder the same ordinary threat seed once an enemy
    -- crosses the gold line. This is not a focus/pin; normal aggro, tank taunt, and target switching
    -- remain authoritative after the seed. In Simple mode the same folder contains only the
    -- temporary reserve escort because the durable squad is parked.
    local playerFolder = record.petFolder or self:_playerPetFolder(record.player, false)
    if playerFolder and playerFolder.Parent then
        local ok, count = self._enemyService:AlertPetFolderToEnemy(
            playerFolder,
            enemy.targetId,
            { threat = threat }
        )
        if ok then
            alertedPlayerPets = count
            alertedPets += count
        end
    end

    return reserveTeams, alertedPets, alertedPlayerPets
end

local function planarUnit(value, fallback)
    if typeof(value) ~= "Vector3" then
        return fallback
    end
    local flat = Vector3.new(value.X, 0, value.Z)
    if flat.Magnitude < 0.001 then
        return fallback
    end
    return flat.Unit
end

local function landSharkWander(time, phase, seed)
    local along = math.sin(time * 0.23 + phase * 6.1 + seed) * 0.56
        + math.sin(time * 0.39 + phase * 3.7 + seed * 1.8) * 0.29
        + math.sin(time * 0.61 + phase * 2.2 + seed * 0.7) * 0.15
    local depth = math.sin(time * 0.31 + phase * 5.4 + seed * 1.3) * 0.67
        + math.sin(time * 0.54 + phase * 2.9 + seed * 0.4) * 0.33
    return along, depth
end

local function landSharkWanderPosition(shark, along, depth, center, halfWidth, halfDepth)
    local speed = math.max(1, tonumber(shark:GetAttribute("MergeLandSharkSpeedStuds")) or 10)
    local phase = tonumber(shark:GetAttribute("MergeLandSharkPhase")) or 0
    local seed = tonumber(shark:GetAttribute("MergeLandSharkPatrolIndex")) or 1
    local origin = typeof(center) == "Vector3" and center or shark:GetPivot().Position
    local alongN, depthN = landSharkWander(os.clock() * (speed / 10), phase, seed)
    return Vector3.new(origin.X, origin.Y, origin.Z)
        + along * (alongN * halfWidth)
        + depth * (depthN * halfDepth)
end

local function landSharkPreyRank(item)
    return string.lower(tostring(item.model and item.model:GetAttribute("MergeEggRank") or "trash"))
end

local function landSharkPickPrey(prey, claimed, from, preferBosses)
    local best, bestRank, bestDist = nil, nil, nil
    for _, item in ipairs(prey) do
        local id = tonumber(item.enemy.targetId)
        if id and claimed[id] == nil then
            local offset = item.position - from
            local dist = Vector3.new(offset.X, 0, offset.Z).Magnitude
            local rank = (preferBosses and landSharkPreyRank(item) == "boss") and 0 or 1
            if best == nil or rank < bestRank or (rank == bestRank and dist < bestDist) then
                best = item
                bestRank = rank
                bestDist = dist
            end
        end
    end
    return best
end

function MergeEggPrototypeService:_clearLandSharkHunt(shark)
    if not shark then
        return
    end
    shark:SetAttribute("MergeLandSharkHuntTargetId", nil)
    shark:SetAttribute("MergeLandSharkHuntState", nil)
    shark:SetAttribute("MergeLandSharkHuntAim", nil)
    shark:SetAttribute("MergeLandSharkHuntPos", nil)
    shark:SetAttribute("MergeLandSharkGrabStartedAt", nil)
    shark:SetAttribute("MergeLandSharkHuntTickAt", nil)
end

function MergeEggPrototypeService:_tickLandSharkHunt(record, towardGate, family, tier, slot)
    if not (record and record.world and family == "land_shark") then
        return
    end
    slot = MergeBulwarkProgression.normalizeSlot(slot)
    local suffix = self:_bulwarkSlotSuffix(slot)
    local effect = self:_bulwarkCombatEffect(record, family, tier)
    if not (effect and effect.kind == "hunt_drag") then
        return
    end
    local folder = record.world:FindFirstChild("MergeEggBulwarks")
    if not folder then
        return
    end
    local sharks = {}
    for _, child in ipairs(folder:GetChildren()) do
        local childSlot = child:GetAttribute("MergeBulwarkSlot")
            or MergeBulwarkProgression.SLOT_LANE
        if
            child:IsA("Model")
            and child:GetAttribute("MergeBulwarkFamily") == "land_shark"
            and child:GetAttribute("MergeLandSharkPatrol") == true
            and childSlot == slot
        then
            sharks[#sharks + 1] = child
        end
    end
    if #sharks == 0 then
        return
    end
    local sample = sharks[1]
    local along =
        planarUnit(sample:GetAttribute("MergeLandSharkTrackDirection"), Vector3.new(1, 0, 0))
    local depth = planarUnit(
        sample:GetAttribute("MergeLandSharkDepthDirection"),
        Vector3.new(-along.Z, 0, along.X)
    )
    local center = sample:GetAttribute("MergeLandSharkFieldCenter")
    if typeof(center) ~= "Vector3" then
        center = sample:GetPivot().Position
    end
    local halfWidth =
        math.max(8, (tonumber(sample:GetAttribute("MergeLandSharkFieldWidth")) or 78) * 0.5)
    local halfDepth =
        math.max(1, (tonumber(sample:GetAttribute("MergeLandSharkFieldDepth")) or 7) * 0.5)
    local toward = planarUnit(towardGate, nil)
    local depthSign = 1
    if toward and toward:Dot(depth) < 0 then
        depthSign = -1
    end
    local now = os.clock()
    local claimed = {}
    local prey = {}
    for _, enemy in ipairs(record.enemies or {}) do
        local model = enemy.model
        if
            model
            and model.Parent
            and (tonumber(model:GetAttribute("HP")) or 0) > 0
            and model:GetAttribute("Dying") ~= true
        then
            local position = typeof(model:GetAttribute("MoveTarget")) == "Vector3"
                    and model:GetAttribute("MoveTarget")
                or model:GetPivot().Position
            local rel = position - center
            local alongDot = rel:Dot(along)
            local depthDot = rel:Dot(depth) * depthSign
            if
                math.abs(alongDot) <= halfWidth + 6
                and depthDot >= -halfDepth
                and depthDot <= effect.huntRangeStuds
            then
                prey[#prey + 1] = {
                    enemy = enemy,
                    model = model,
                    position = position,
                    alongDot = alongDot,
                    depthDot = depthDot,
                }
            end
        end
    end
    for _, shark in ipairs(sharks) do
        local targetId = tonumber(shark:GetAttribute("MergeLandSharkHuntTargetId"))
        local still = false
        if targetId then
            for _, item in ipairs(prey) do
                if tonumber(item.enemy.targetId) == targetId then
                    claimed[targetId] = shark
                    still = true
                    break
                end
            end
        end
        if not still then
            self:_clearLandSharkHunt(shark)
        end
    end
    table.sort(sharks, function(a, b)
        return (tonumber(a:GetAttribute("MergeLandSharkPatrolIndex")) or 0)
            < (tonumber(b:GetAttribute("MergeLandSharkPatrolIndex")) or 0)
    end)
    for _, shark in ipairs(sharks) do
        local targetId = tonumber(shark:GetAttribute("MergeLandSharkHuntTargetId"))
        if not targetId then
            local from = shark:GetAttribute("MergeLandSharkHuntPos")
            if typeof(from) ~= "Vector3" then
                from = landSharkWanderPosition(shark, along, depth, center, halfWidth, halfDepth)
            end
            local best = landSharkPickPrey(prey, claimed, from, effect.preferBosses)
            if best then
                targetId = tonumber(best.enemy.targetId)
                claimed[targetId] = shark
                shark:SetAttribute("MergeLandSharkHuntTargetId", targetId)
                shark:SetAttribute("MergeLandSharkHuntState", "chase")
                shark:SetAttribute("MergeLandSharkNextBiteAt", now)
                if typeof(shark:GetAttribute("MergeLandSharkHuntPos")) ~= "Vector3" then
                    shark:SetAttribute(
                        "MergeLandSharkHuntPos",
                        landSharkWanderPosition(shark, along, depth, center, halfWidth, halfDepth)
                    )
                end
            end
        end
        if targetId then
            local item
            for _, candidate in ipairs(prey) do
                if tonumber(candidate.enemy.targetId) == targetId then
                    item = candidate
                    break
                end
            end
            if item then
                local lastTick = tonumber(shark:GetAttribute("MergeLandSharkHuntTickAt"))
                local dt = lastTick and math.clamp(now - lastTick, 0.016, 0.25) or 0.05
                shark:SetAttribute("MergeLandSharkHuntTickAt", now)
                local sharkPos = shark:GetAttribute("MergeLandSharkHuntPos")
                if typeof(sharkPos) ~= "Vector3" then
                    sharkPos =
                        landSharkWanderPosition(shark, along, depth, center, halfWidth, halfDepth)
                end
                local state = tostring(shark:GetAttribute("MergeLandSharkHuntState") or "chase")
                if
                    effect.preferBosses
                    and state ~= "drag"
                    and landSharkPreyRank(item) ~= "boss"
                then
                    local boss = landSharkPickPrey(prey, claimed, sharkPos, true)
                    if boss and landSharkPreyRank(boss) == "boss" then
                        claimed[targetId] = nil
                        targetId = tonumber(boss.enemy.targetId)
                        claimed[targetId] = shark
                        item = boss
                        shark:SetAttribute("MergeLandSharkHuntTargetId", targetId)
                        shark:SetAttribute("MergeLandSharkHuntState", "chase")
                        state = "chase"
                    end
                end
                local planar =
                    Vector3.new(item.position.X - sharkPos.X, 0, item.position.Z - sharkPos.Z)
                if planar.Magnitude <= effect.grabRangeStuds then
                    state = "drag"
                elseif state ~= "drag" then
                    state = "chase"
                end
                shark:SetAttribute("MergeLandSharkHuntState", state)
                local sink = 0
                local startY = tonumber(item.model:GetAttribute("MergeLandSharkGrabStartY"))
                if state == "drag" then
                    if startY == nil then
                        startY = item.position.Y
                        item.model:SetAttribute("MergeLandSharkGrabStartY", startY)
                        shark:SetAttribute("MergeLandSharkGrabStartedAt", now)
                        shark:SetAttribute("MergeLandSharkNextBiteAt", now)
                    end
                    sink = math.min(
                        effect.sinkStuds,
                        (now - (tonumber(shark:GetAttribute("MergeLandSharkGrabStartedAt")) or now))
                            * 3.5
                    )
                    item.model:SetAttribute("DeathStylePreferred", "sink")
                    item.model:SetAttribute(
                        "DeathSinkStuds",
                        math.max(4, effect.sinkStuds - sink + 4)
                    )
                    item.model:SetAttribute("MergeLandSharkGrabbedBy", shark.Name)
                    local pull = item.position
                    if planar.Magnitude > 1 then
                        pull = item.position - planar.Unit * math.min(planar.Magnitude, 4)
                    end
                    pull = Vector3.new(pull.X, startY - sink, pull.Z)
                    if self._enemyService and self._enemyService.SetScriptedMove then
                        self._enemyService:SetScriptedMove(item.model, pull, {
                            face = sharkPos,
                            holdSeconds = 1.25,
                        })
                    end
                    local nextBite = tonumber(shark:GetAttribute("MergeLandSharkNextBiteAt")) or 0
                    if now >= nextBite then
                        CombatApplication.ApplyDamage(item.model, effect.biteDamage, {
                            kind = "land_shark_bite",
                            powerId = "land_shark",
                            source = shark,
                            sourcePlayer = record.player,
                        })
                        shark:SetAttribute("MergeLandSharkNextBiteAt", now + effect.bitePeriod)
                    end
                    item.position = pull
                else
                    shark:SetAttribute("MergeLandSharkGrabStartedAt", nil)
                    item.model:SetAttribute("MergeLandSharkGrabStartY", nil)
                end
                local dest = Vector3.new(item.position.X, item.position.Y, item.position.Z)
                local to = dest - sharkPos
                local speed = if state == "drag" then 16 else 26
                if to.Magnitude > 0.05 then
                    sharkPos = sharkPos + to.Unit * math.min(to.Magnitude, speed * dt)
                end
                shark:SetAttribute("MergeLandSharkHuntPos", sharkPos)
                shark:SetAttribute("MergeLandSharkHuntAim", dest)
            end
        end
    end
    for _, shark in ipairs(sharks) do
        if not tonumber(shark:GetAttribute("MergeLandSharkHuntTargetId")) then
            self:_clearLandSharkHunt(shark)
        end
    end
    if effect.venomDamage > 0 and effect.venomRangeStuds > 0 then
        local positions = {}
        for _, shark in ipairs(sharks) do
            local pos = shark:GetAttribute("MergeLandSharkHuntPos")
            if typeof(pos) ~= "Vector3" then
                pos = landSharkWanderPosition(shark, along, depth, center, halfWidth, halfDepth)
            end
            positions[#positions + 1] = pos
        end
        for _, enemy in ipairs(record.enemies or {}) do
            local model = enemy.model
            if
                model
                and model.Parent
                and (tonumber(model:GetAttribute("HP")) or 0) > 0
                and model:GetAttribute("Dying") ~= true
            then
                local position = typeof(model:GetAttribute("MoveTarget")) == "Vector3"
                        and model:GetAttribute("MoveTarget")
                    or model:GetPivot().Position
                local near = false
                for _, pos in ipairs(positions) do
                    if
                        Vector3.new(position.X - pos.X, 0, position.Z - pos.Z).Magnitude
                        <= effect.venomRangeStuds
                    then
                        near = true
                        break
                    end
                end
                if near then
                    local nextAt = tonumber(
                        model:GetAttribute("MergeLandSharkVenomNextAt" .. suffix)
                    ) or 0
                    if now >= nextAt then
                        CombatApplication.ApplyDamage(model, effect.venomDamage, {
                            kind = "land_shark_venom",
                            powerId = "land_shark",
                            source = sharks[1],
                            sourcePlayer = record.player,
                        })
                        model:SetAttribute(
                            "MergeLandSharkVenomNextAt" .. suffix,
                            now + effect.venomPeriod
                        )
                    end
                end
            end
        end
    end
end

-- Concertina Line is a lane DoT plus a graded slow. T1 is on-strip only; later tiers linger
-- after they walk off. T4 stacks while they stay on the wire and does not wear off this wave.
-- Combat still opens on the gold line — this is bleed, not a stop wall.
function MergeEggPrototypeService:_tickConcertinaBleed(
    record,
    enemy,
    leadingDistance,
    now,
    family,
    tier,
    slot
)
    local model = enemy and enemy.model
    if not (model and model.Parent and (tonumber(model:GetAttribute("HP")) or 0) > 0) then
        return
    end
    local suffix = self:_bulwarkSlotSuffix(slot)
    local effect = self:_bulwarkCombatEffect(record, family, tier)
    if not (effect and effect.kind == "bleed_slow") then
        return
    end
    now = tonumber(now) or os.clock()
    local onStrip = math.abs(tonumber(leadingDistance) or 1e9) <= effect.stripDepthStuds
    if onStrip then
        local linger = effect.bleedPermanent == true and 3600 or effect.lingerSeconds
        model:SetAttribute("MergeConcertinaLingerUntil" .. suffix, now + linger)
        model:SetAttribute("MergeConcertinaOnStrip" .. suffix, true)
    else
        model:SetAttribute("MergeConcertinaOnStrip" .. suffix, false)
    end
    local lingerUntil = tonumber(model:GetAttribute("MergeConcertinaLingerUntil" .. suffix)) or 0
    local active = onStrip or now < lingerUntil
    if not active then
        model:SetAttribute("MergeConcertinaBleedStacks" .. suffix, nil)
        model:SetAttribute("MergeConcertinaNextBleedAt" .. suffix, nil)
        return
    end

    local wallClock = os.time()
    local slowHold = effect.bleedPermanent == true and 30
        or math.max(1, math.ceil(math.max(effect.lingerSeconds, 1.25)))
    local slowUntil = wallClock + slowHold
    local slowLive = (tonumber(model:GetAttribute("SlowUntil")) or 0) > wallClock
    local currentFactor = slowLive and (tonumber(model:GetAttribute("SlowFactor")) or 1) or 1
    model:SetAttribute("SlowFactor", math.min(currentFactor, effect.slowFactor))
    model:SetAttribute(
        "SlowUntil",
        math.max(tonumber(model:GetAttribute("SlowUntil")) or 0, slowUntil)
    )
    model:SetAttribute(
        "DebuffUntil",
        math.max(tonumber(model:GetAttribute("DebuffUntil")) or 0, slowUntil)
    )
    model:SetAttribute("DebuffPowerId", "concertina_line")

    local nextBleed = tonumber(model:GetAttribute("MergeConcertinaNextBleedAt" .. suffix)) or 0
    if now < nextBleed then
        return
    end
    local stacks = 1
    if effect.bleedStacks then
        local held =
            math.max(1, tonumber(model:GetAttribute("MergeConcertinaBleedStacks" .. suffix)) or 1)
        if onStrip then
            local previous = tonumber(model:GetAttribute("MergeConcertinaBleedStacks" .. suffix))
            stacks = math.min(effect.stackCap, (previous or 0) + 1)
        else
            stacks = held
        end
        model:SetAttribute("MergeConcertinaBleedStacks" .. suffix, stacks)
    end
    CombatApplication.ApplyDamage(model, effect.bleedDamage * stacks, {
        kind = "concertina_bleed",
        powerId = "concertina_line",
        sourcePlayer = record.player,
        playerPetKillUserId = nil,
    })
    model:SetAttribute("MergeConcertinaNextBleedAt" .. suffix, now + effect.bleedPeriod)
    model:SetAttribute("BurnElement", "lava")
    model:SetAttribute("BurnFxUntil", wallClock + math.max(2, math.ceil(effect.bleedPeriod + 1)))
end

-- Saw Blade is pure shred: rapid high damage on the deck, no slow, no linger, no stop.
-- Combat still opens on the gold line. Each tick pulses the client cube spray.
function MergeEggPrototypeService:_tickSawBladeShred(
    record,
    enemy,
    leadingDistance,
    now,
    family,
    tier,
    slot
)
    local model = enemy and enemy.model
    if not (model and model.Parent and (tonumber(model:GetAttribute("HP")) or 0) > 0) then
        return
    end
    local suffix = self:_bulwarkSlotSuffix(slot)
    local effect = self:_bulwarkCombatEffect(record, family, tier)
    if not (effect and effect.kind == "shred_line") then
        return
    end
    now = tonumber(now) or os.clock()
    local onStrip = math.abs(tonumber(leadingDistance) or 1e9) <= effect.stripDepthStuds
    if not onStrip then
        model:SetAttribute("MergeSawNextShredAt" .. suffix, nil)
        return
    end
    local nextShred = tonumber(model:GetAttribute("MergeSawNextShredAt" .. suffix)) or 0
    if now < nextShred then
        return
    end
    CombatApplication.ApplyDamage(model, effect.shredDamage, {
        kind = "saw_blade_shred",
        powerId = "saw_blade",
        sourcePlayer = record.player,
        playerPetKillUserId = nil,
    })
    model:SetAttribute("MergeSawNextShredAt" .. suffix, now + effect.shredPeriod)
    model:SetAttribute("MergeSawShredChunks", effect.chunkCount)
    model:SetAttribute(
        "MergeSawShredPulse",
        (tonumber(model:GetAttribute("MergeSawShredPulse")) or 0) + 1
    )
    if now >= (record.nextSawHitSoundAt or 0) then
        local position = model:GetAttribute("MoveTarget")
        if typeof(position) ~= "Vector3" then
            position = model:GetPivot().Position
        end
        self:_playSawBladeImpact(position, record.world)
        record.nextSawHitSoundAt = now + 0.28
    end
end

-- Grasping Hedge roots the front of the wave (feet stuck, hands free) and slows the pile.
-- The root is timed, never refreshed, never HeldUntil. After it expires they must leave
-- the hedge before another grab — walking back in roots them again. Not a lifetime counter.
function MergeEggPrototypeService:_tickGraspingHedge(record, now, family, tier, leadAttr, slot)
    if not (record and family == "grasping_hedge") then
        return
    end
    local suffix = self:_bulwarkSlotSuffix(slot)
    local grabbedAttr = "MergeHedgeGrabbed" .. suffix
    local exitAttr = "MergeHedgeNeedsExit" .. suffix
    local effect = self:_bulwarkCombatEffect(record, family, tier)
    if not (effect and effect.kind == "grab_root") then
        return
    end
    now = tonumber(now) or os.clock()
    local wallClock = os.time()
    local onStrip = {}
    for _, enemy in ipairs(record.enemies or {}) do
        local model = enemy.model
        if model and model.Parent and (tonumber(model:GetAttribute("HP")) or 0) > 0 then
            local lead = tonumber(model:GetAttribute(leadAttr or "MergeEggBulwarkLeadingDistance"))
            local depth = math.abs(lead or 1e9)
            local inside = lead ~= nil and depth <= effect.stripDepthStuds
            -- Exit is march-axis only (leadingDistance). They must clear the strip plus a
            -- buffer so a lateral shuffle or one-stud flicker is not a new grab.
            local trulyOut = lead ~= nil and depth > effect.stripDepthStuds + effect.exitBufferStuds
            if trulyOut then
                model:SetAttribute(exitAttr, nil)
                if
                    model:GetAttribute(grabbedAttr) == true
                    and (tonumber(model:GetAttribute("RootedUntil")) or 0) <= wallClock
                then
                    model:SetAttribute(grabbedAttr, false)
                end
            elseif inside then
                onStrip[#onStrip + 1] = { model = model, lead = lead }
            elseif
                model:GetAttribute(grabbedAttr) == true
                and (tonumber(model:GetAttribute("RootedUntil")) or 0) <= wallClock
            then
                model:SetAttribute(grabbedAttr, false)
                model:SetAttribute(exitAttr, true)
            end
        end
    end
    table.sort(onStrip, function(a, b)
        return a.lead > b.lead
    end)

    local slowUntil = wallClock + math.max(1, math.ceil(effect.slowSeconds))
    for _, item in ipairs(onStrip) do
        local model = item.model
        local slowLive = (tonumber(model:GetAttribute("SlowUntil")) or 0) > wallClock
        local current = slowLive and (tonumber(model:GetAttribute("SlowFactor")) or 1) or 1
        model:SetAttribute("SlowFactor", math.min(current, effect.slowFactor))
        model:SetAttribute(
            "SlowUntil",
            math.max(tonumber(model:GetAttribute("SlowUntil")) or 0, slowUntil)
        )
        if model:GetAttribute("DebuffPowerId") ~= "grasping_hedge" then
            model:SetAttribute("DebuffPowerId", "grasping_hedge")
        end
        model:SetAttribute(
            "DebuffUntil",
            math.max(tonumber(model:GetAttribute("DebuffUntil")) or 0, slowUntil)
        )
    end

    local held = 0
    for _, item in ipairs(onStrip) do
        local model = item.model
        if model:GetAttribute(grabbedAttr) == true then
            if (tonumber(model:GetAttribute("RootedUntil")) or 0) <= wallClock then
                model:SetAttribute(grabbedAttr, false)
                model:SetAttribute(exitAttr, true)
            else
                held += 1
            end
        end
    end

    for _, item in ipairs(onStrip) do
        if held >= effect.grabCount then
            break
        end
        local model = item.model
        if model:GetAttribute(exitAttr) == true or model:GetAttribute(grabbedAttr) == true then
            continue
        end
        local untilTime = wallClock + effect.rootSeconds
        model:SetAttribute("RootedUntil", untilTime)
        model:SetAttribute(grabbedAttr, true)
        model:SetAttribute(exitAttr, nil)
        model:SetAttribute(
            "DebuffUntil",
            math.max(tonumber(model:GetAttribute("DebuffUntil")) or 0, untilTime)
        )
        model:SetAttribute("DebuffPowerId", "grasping_hedge")
        if effect.venomDamage > 0 and effect.venomDuration > 0 then
            local clk = now
            model:SetAttribute(
                "DotPerTick",
                math.max(tonumber(model:GetAttribute("DotPerTick")) or 0, effect.venomDamage)
            )
            model:SetAttribute("DotInterval", effect.venomPeriod)
            model:SetAttribute("DotNextTick", clk + effect.venomPeriod)
            model:SetAttribute("DotPermanent", false)
            model:SetAttribute("DotExpireAt", clk + effect.venomDuration)
            model:SetAttribute("DotDuration", effect.venomDuration)
            model:SetAttribute("BurnFxUntil", wallClock + math.ceil(effect.venomDuration))
            local player = record.player
            if player then
                model:SetAttribute("DotSourceUserId", player.UserId)
            end
            model:SetAttribute("DotPlayerPetKillUserId", nil)
            model:SetAttribute("BurnElement", "grass")
        end
        held += 1
    end
end

-- Impaler Palisade spends one no-damage shove before the marcher may cross. Combat stays closed
-- until the last bounce is used so the wall is a stop, not a damage farm.
function MergeEggPrototypeService:_tryPalisadeStop(record, enemy, towardGate, family, tier, slot)
    local model = enemy and enemy.model
    if not (model and model.Parent and towardGate and towardGate.Magnitude > 0.05) then
        return false
    end
    slot = MergeBulwarkProgression.normalizeSlot(slot)
    local slotDef = MergeBulwarkSlots.get(slot)
    if
        slotDef
        and slotDef.combatPlane == "bulwark"
        and model:GetAttribute("MergeEggBulwarkBreached") == true
    then
        return false
    end
    local suffix = self:_bulwarkSlotSuffix(slot)
    local chargesAttr = "MergeEggPalisadeCharges" .. suffix
    local exitAttr = "MergeEggPalisadeNeedsExit" .. suffix
    local effect = self:_bulwarkCombatEffect(record, family, tier)
    if not (effect and effect.kind == "stop_shove") then
        return false
    end
    -- A successful bounce leaves them overlapping the plane for a few frames. Hold the
    -- breach open until they walk back off the line (cleared in the approach tick).
    if model:GetAttribute(exitAttr) == true then
        return true
    end
    local remaining = tonumber(model:GetAttribute(chargesAttr))
    if remaining == nil then
        remaining = effect.charges
        model:SetAttribute(chargesAttr, remaining)
    end
    if remaining <= 0 then
        return false
    end
    local shoved = false
    if self._enemyService and self._enemyService.ApplyDirectedKnockback then
        shoved = self._enemyService:ApplyDirectedKnockback(model, towardGate, effect.shoveStuds)
            == true
    end
    if not shoved then
        model:SetAttribute(chargesAttr, 0)
        return false
    end
    remaining -= 1
    model:SetAttribute(chargesAttr, remaining)
    model:SetAttribute(exitAttr, true)
    if effect.rootSeconds > 0 then
        local untilTime = os.time() + effect.rootSeconds
        model:SetAttribute("RootedUntil", untilTime)
        model:SetAttribute("DebuffUntil", untilTime)
        model:SetAttribute("DebuffPowerId", "impaler_palisade")
    end
    if effect.venomDamage > 0 then
        local clk = os.clock()
        local permanent = effect.venomPermanent == true
        model:SetAttribute(
            "DotPerTick",
            math.max(tonumber(model:GetAttribute("DotPerTick")) or 0, effect.venomDamage)
        )
        model:SetAttribute("DotInterval", effect.venomPeriod)
        model:SetAttribute("DotNextTick", clk + effect.venomPeriod)
        model:SetAttribute("DotPermanent", permanent)
        if permanent then
            model:SetAttribute("DotExpireAt", 0)
            model:SetAttribute("DotDuration", 0)
            model:SetAttribute("BurnFxUntil", os.time() + 30)
        else
            local duration = math.max(0.5, tonumber(effect.venomDuration) or 4)
            model:SetAttribute("DotExpireAt", clk + duration)
            model:SetAttribute("DotDuration", duration)
            model:SetAttribute("BurnFxUntil", os.time() + math.ceil(duration))
        end
        local player = record and record.player
        if player then
            model:SetAttribute("DotSourceUserId", player.UserId)
        end
        model:SetAttribute("DotPlayerPetKillUserId", nil)
        model:SetAttribute("BurnElement", "grass")
        if
            effect.contagionHops > 0
            and (tonumber(model:GetAttribute("ContagionSpreadAt")) or 0) <= 0
        then
            model:SetAttribute("ContagionSpreadAt", clk + effect.contagionInterval)
            model:SetAttribute("ContagionLeft", effect.contagionHops)
            model:SetAttribute("ContagionRadius", effect.contagionRadius)
            model:SetAttribute("ContagionInterval", effect.contagionInterval)
            model:SetAttribute("ContagionMax", effect.contagionHops)
        end
    end
    -- This contact was spent as a bounce. Combat opens on the next crossing, not this one.
    return true
end

function MergeEggPrototypeService:_openBulwarkTarget(record, enemy, now)
    local model = enemy and enemy.model
    if
        not self:_isRecordActive(record)
        or not (model and model.Parent)
        or model:GetAttribute("MergeEggBulwarkBreached") == true
    then
        return
    end

    model:SetAttribute("MergeEggBulwarkBreached", true)
    model:SetAttribute("CombatTargetOpen", true)
    record.bulwarkCrossed = (record.bulwarkCrossed or 0) + 1
    record.waveReserveReleased = true
    record.waveReserveTeamId = nil
    for _, team in ipairs(record.teams or {}) do
        if team.isReserve == true then
            self:_openReinforcementTeam(record, team, "bulwark", enemy.targetId)
        end
        team.isReserve = false
    end

    now = tonumber(now) or os.clock()
    local reserveTeams, alertedPets, alertedPlayerPets =
        self:_alertTeamsToBulwarkTarget(record, enemy)
    local reengageSeconds =
        math.max(0.25, tonumber((self._config.enemy or {}).bulwark_reengage_seconds) or 0.5)
    model:SetAttribute("MergeEggReserveTeamCount", reserveTeams)
    model:SetAttribute("MergeEggReserveAlertedPets", alertedPets)
    model:SetAttribute("MergeEggPlayerAlertedPets", alertedPlayerPets)
    model:SetAttribute("MergeEggBulwarkAlertCount", 1)
    model:SetAttribute("MergeEggNextBulwarkAlertAt", now + reengageSeconds)
    self:_setWorldState(self:_activeWaveState(record), record)
    self:_log("Info", "Merge Egg prototype bulwark breached", {
        player = record.player.Name,
        wave = record.waveIndex,
        enemy = model.Name,
        assignedTeam = enemy.teamId,
        reserveTeams = reserveTeams,
        alertedPets = alertedPets,
        alertedPlayerPets = alertedPlayerPets,
    })
end

function MergeEggPrototypeService:_sustainBulwarkTarget(record, enemy, now)
    local model = enemy and enemy.model
    if
        not self:_isRecordActive(record)
        or not (model and model.Parent)
        or model:GetAttribute("MergeEggBulwarkBreached") ~= true
        or now < (tonumber(model:GetAttribute("MergeEggNextBulwarkAlertAt")) or 0)
    then
        return
    end

    local reengageSeconds =
        math.max(0.25, tonumber((self._config.enemy or {}).bulwark_reengage_seconds) or 0.5)
    local reserveTeams, alertedPets, alertedPlayerPets =
        self:_alertTeamsToBulwarkTarget(record, enemy)
    model:SetAttribute("MergeEggReserveTeamCount", reserveTeams)
    model:SetAttribute("MergeEggReserveAlertedPets", alertedPets)
    model:SetAttribute("MergeEggPlayerAlertedPets", alertedPlayerPets)
    model:SetAttribute(
        "MergeEggBulwarkAlertCount",
        (tonumber(model:GetAttribute("MergeEggBulwarkAlertCount")) or 1) + 1
    )
    model:SetAttribute("MergeEggNextBulwarkAlertAt", now + reengageSeconds)
    if alertedPets > 0 then
        self:_setWorldState(self:_activeWaveState(record), record)
    end
end

function MergeEggPrototypeService:_traceBulwarkAggro(record, enemy, now)
    local debugCfg = self._config.debug or {}
    local model = enemy and enemy.model
    if
        debugCfg.trace_bulwark_aggro ~= true
        or not (model and model.Parent)
        or model:GetAttribute("MergeEggBulwarkBreached") ~= true
        or now < (tonumber(model:GetAttribute("MergeEggNextBulwarkTraceAt")) or 0)
        or not self._enemyService.TracePetFolderAggro
    then
        return
    end
    local interval = math.max(0.5, tonumber(debugCfg.bulwark_trace_seconds) or 2)
    model:SetAttribute("MergeEggNextBulwarkTraceAt", now + interval)
    local context = string.format(
        "wave=%d lead=%.1f move=%.1f pivot=%.1f alerts=%d",
        record.waveIndex,
        tonumber(model:GetAttribute("MergeEggBulwarkLeadingDistance")) or -1,
        tonumber(model:GetAttribute("MergeEggBulwarkMovementDistance")) or -1,
        tonumber(model:GetAttribute("MergeEggBulwarkPivotDistance")) or -1,
        tonumber(model:GetAttribute("MergeEggBulwarkAlertCount")) or 0
    )
    for _, team in ipairs(record.teams or {}) do
        if team.folder and team.folder.Parent and (team.activePets or 0) > 0 then
            self._enemyService:TracePetFolderAggro(team.folder, enemy.targetId, context)
        end
    end
end

function MergeEggPrototypeService:_alertApproachingEnemies(record)
    local cfg = self._config.enemy or {}
    local finishLine = findNamedPart(
        record.world,
        (self._config.world or {}).enemy_finish_line or "EnemyFinishLine"
    )
    if not finishLine then
        return
    end
    local worldCfg = self._config.world or {}
    local combatPlanes = {}
    local marchLine = nil
    for _, plane in ipairs(MergeBulwarkSlots.combatPlanes()) do
        local line = findNamedPart(record.world, worldCfg[plane.lineConfigKey] or plane.lineDefault)
        combatPlanes[plane.id] = {
            def = plane,
            line = line,
        }
        if plane.id == "bulwark" then
            marchLine = line
        end
    end
    local slotLines = {}
    for _, def in ipairs(MergeBulwarkSlots.all()) do
        local name = MergeBulwarkSlots.stripLineName(def, worldCfg)
        slotLines[def.id] = name and findNamedPart(record.world, name) or nil
    end
    local towardFinish = marchLine
            and Vector3.new(
                finishLine.Position.X - marchLine.Position.X,
                0,
                finishLine.Position.Z - marchLine.Position.Z
            )
        or Vector3.zero
    local bulwarkState = self:_normalizeBulwarkState(record)
    local alertDistance = math.max(1, tonumber(cfg.engagement_distance) or 260)
    local alertThreat = math.max(1, tonumber(cfg.engagement_threat) or 250)
    local reengageSeconds = math.max(0.25, tonumber(cfg.reengage_seconds) or 1)
    local now = os.clock()
    local enemiesPastBulwark = 0
    local enemiesPastBreachLine = 0
    local activePets = 0
    for _, team in ipairs(record.teams or {}) do
        activePets += math.max(0, math.floor(tonumber(team.activePets) or 0))
    end
    for _, enemy in ipairs(record.enemies) do
        local model = enemy.model
        local team = record.teamById[enemy.teamId]
        local position = model and model:GetAttribute("MoveTarget")
        if
            team
            and team.folder
            and team.folder.Parent
            and model
            and model.Parent
            and (tonumber(model:GetAttribute("HP")) or 0) > 0
        then
            if typeof(position) == "Vector3" then
                local localPosition = finishLine.CFrame:PointToObjectSpace(position)
                if math.abs(localPosition.Z) <= alertDistance then
                    local firstAlert = model:GetAttribute("MergeEggDefenseAlerted") ~= true
                    local engaged = self:_teamEngagedWithEnemy(team, enemy)
                    local nextAlertAt = tonumber(model:GetAttribute("MergeEggNextDefenseAlertAt"))
                        or 0
                    -- The first alert is only a normal threat seed, not a forced target. If both sides
                    -- later drop the fight while the marcher is still in the defense lane, seed it
                    -- again; tanks and the ordinary tables remain free to redistribute that threat.
                    if firstAlert or (not engaged and now >= nextAlertAt) then
                        local ok, alertedPets = self._enemyService:AlertPetFolderToEnemy(
                            team.folder,
                            enemy.targetId,
                            { threat = alertThreat }
                        )
                        if ok then
                            local alertCount = (
                                tonumber(model:GetAttribute("MergeEggDefenseAlertCount")) or 0
                            ) + 1
                            model:SetAttribute("MergeEggDefenseAlerted", true)
                            model:SetAttribute("MergeEggDefenseAlertCount", alertCount)
                            model:SetAttribute("MergeEggNextDefenseAlertAt", now + reengageSeconds)
                            model:SetAttribute("MergeEggAlertedPets", alertedPets)
                            model:SetAttribute("MergeEggAlertedTeamId", team.id)
                            if firstAlert then
                                record.alerted += 1
                            end
                            team.engaged = true
                            self:_setTeamState(record, team, "Engaged")
                            self:_setWorldState(self:_activeWaveState(record), record)
                        end
                    end
                end
            end
            if marchLine and towardFinish.Magnitude > 0 then
                local direction = towardFinish.Unit
                local pivotPosition = model:GetPivot().Position
                local movementPosition = typeof(position) == "Vector3" and position or pivotPosition
                local leadingPosition, boundsExtent =
                    leadingBoundsPoint(model, movementPosition, direction)
                leadingPosition = leadingPosition or movementPosition
                local contactPadding = math.max(0, tonumber(cfg.bulwark_contact_padding) or 1)
                local planeDistance = {}
                for _, plane in ipairs(MergeBulwarkSlots.combatPlanes()) do
                    local entry = combatPlanes[plane.id]
                    if entry and entry.line then
                        local distance = Vector3.new(
                            leadingPosition.X - entry.line.Position.X,
                            0,
                            leadingPosition.Z - entry.line.Position.Z
                        ):Dot(direction)
                        planeDistance[plane.id] = distance
                        model:SetAttribute(plane.distanceAttr, distance)
                        if plane.writeApproachDebug == true then
                            model:SetAttribute(
                                "MergeEggBulwarkMovementDistance",
                                Vector3.new(
                                    movementPosition.X - entry.line.Position.X,
                                    0,
                                    movementPosition.Z - entry.line.Position.Z
                                ):Dot(direction)
                            )
                            model:SetAttribute(
                                "MergeEggBulwarkPivotDistance",
                                Vector3.new(
                                    pivotPosition.X - entry.line.Position.X,
                                    0,
                                    pivotPosition.Z - entry.line.Position.Z
                                ):Dot(direction)
                            )
                            model:SetAttribute("MergeEggBulwarkBoundsExtent", boundsExtent)
                        end
                    end
                end
                local stoppedOnPlane = {}
                for _, def in ipairs(MergeBulwarkSlots.all()) do
                    local line = slotLines[def.id]
                    if line then
                        local distance = Vector3.new(
                            leadingPosition.X - line.Position.X,
                            0,
                            leadingPosition.Z - line.Position.Z
                        ):Dot(direction)
                        local stripAttr = MergeBulwarkSlots.stripDistanceAttr(def)
                        if stripAttr and planeDistance[def.combatPlane] == nil then
                            model:SetAttribute(stripAttr, distance)
                        end
                        local family, tier =
                            MergeBulwarkProgression.slotFamily(bulwarkState, def.id)
                        self:_tickConcertinaBleed(
                            record,
                            enemy,
                            distance,
                            now,
                            family,
                            tier,
                            def.id
                        )
                        self:_tickSawBladeShred(record, enemy, distance, now, family, tier, def.id)
                        local past = distance + contactPadding >= 0
                        local exitAttr = "MergeEggPalisadeNeedsExit"
                            .. self:_bulwarkSlotSuffix(def.id)
                        local stopped = false
                        if past then
                            stopped = self:_tryPalisadeStop(
                                record,
                                enemy,
                                -direction,
                                family,
                                tier,
                                def.id
                            ) == true
                        elseif model:GetAttribute(exitAttr) == true then
                            model:SetAttribute(exitAttr, nil)
                        end
                        if stopped and def.combatPlane then
                            stoppedOnPlane[def.combatPlane] = true
                        end
                    end
                end
                local bulwarkDist = planeDistance.bulwark
                if bulwarkDist ~= nil then
                    local pastBulwark = bulwarkDist + contactPadding >= 0
                    if pastBulwark then
                        enemiesPastBulwark += 1
                    end
                    if
                        pastBulwark
                        and not stoppedOnPlane.bulwark
                        and model:GetAttribute("MergeEggBulwarkBreached") ~= true
                    then
                        self:_openBulwarkTarget(record, enemy, now)
                    end
                end
                local breachDist = planeDistance.breach
                if breachDist ~= nil then
                    local pastBreachLine = breachDist + contactPadding >= 0
                        and not stoppedOnPlane.breach
                    if pastBreachLine then
                        enemiesPastBreachLine += 1
                        model:SetAttribute("MergeEggCanAttackObjective", true)
                        if model:GetAttribute("MergeEggBreachLineCrossed") ~= true then
                            model:SetAttribute("MergeEggBreachLineCrossed", true)
                            record.breached = (record.breached or 0) + 1
                            record.firstBreachWave = record.firstBreachWave or record.waveIndex
                            self:_triggerAllEggHealDenial(record, "breach", now)
                            self:_retargetEnemyToEggs(record, enemy)
                            self:_log("Info", "Merge Egg prototype breach line crossed", {
                                player = record.player.Name,
                                wave = record.waveIndex,
                                enemy = model.Name,
                                assignedTeam = enemy.teamId,
                                distance = breachDist,
                            })
                        end
                    end
                end
            end
            self:_sustainBulwarkTarget(record, enemy, now)
            self:_traceBulwarkAggro(record, enemy, now)
        end
    end
    local towardGate = towardFinish.Magnitude > 0 and -towardFinish.Unit or nil
    for _, def in ipairs(MergeBulwarkSlots.all()) do
        local family, tier = MergeBulwarkProgression.slotFamily(bulwarkState, def.id)
        self:_tickLandSharkHunt(record, towardGate, family, tier, def.id)
        self:_tickGraspingHedge(
            record,
            now,
            family,
            tier,
            MergeBulwarkSlots.stripDistanceAttr(def),
            def.id
        )
    end
    self:_reinforceIdleTeams(record, now)
    local overrunMinimum = math.max(1, math.floor(tonumber(cfg.breach_overrun_minimum) or 4))
    local enemiesPerPet = math.max(0, tonumber(cfg.breach_overrun_enemy_per_active_pet) or 1)
    local overrunThreshold = math.max(overrunMinimum, math.ceil(activePets * enemiesPerPet))
    local overrun = enemiesPastBreachLine >= overrunThreshold
    local changed = record.enemiesPastBulwark ~= enemiesPastBulwark
        or record.enemiesPastBreachLine ~= enemiesPastBreachLine
        or record.breachOverrunThreshold ~= overrunThreshold
        or record.breachOverrun ~= overrun
    record.enemiesPastBulwark = enemiesPastBulwark
    record.peakEnemiesPastBulwark = math.max(record.peakEnemiesPastBulwark or 0, enemiesPastBulwark)
    record.enemiesPastBreachLine = enemiesPastBreachLine
    record.peakEnemiesPastBreachLine =
        math.max(record.peakEnemiesPastBreachLine or 0, enemiesPastBreachLine)
    record.breachOverrunThreshold = overrunThreshold
    record.breachOverrun = overrun
    if overrun and record.firstOverrunWave == nil then
        record.firstOverrunWave = record.waveIndex
    end
    if changed then
        self:_setWorldState(self:_activeWaveState(record), record)
    end
end

function MergeEggPrototypeService:_stepRecord(record, now)
    if not self:_isRecordActive(record) then
        return
    end
    self:_updateTutorial(record, now, false)
    self:_ensureBayTowers(record)
    self:_ensureBayBulwarks(record)
    self:_stepTowerAim(record, now)
    if record.terminal ~= true then
        self:_stepTowerFire(record, now)
    end
    self:_stepTowerRecoil(record, now)
    if
        record
        and record.terminal == true
        and record.coinRunnerRunning ~= true
        and record.checkpointAutoRestartAt ~= nil
        and now >= record.checkpointAutoRestartAt
    then
        record.checkpointAutoRestartAt = nil
        local restarted, restartReason =
            self:_restartCheckpointKeepingProgress(record, "gameplay_auto")
        if not restarted then
            self:_log("Warn", "Merge Egg prototype gameplay checkpoint restart failed", {
                player = record.player.Name,
                wave = record.waveIndex,
                reason = restartReason,
            })
        end
        return
    end
    if record and record.encounterSpawned and record.terminal ~= true then
        self:_stampUpgradeExperiment(record)
        local spawnOk = self:_processWaveSpawns(record, now)
        if not spawnOk then
            return
        end
        self:_alertApproachingEnemies(record)
        self:_applyEggHealDenial(record, now)
        if now >= (record.nextTeamSyncAt or 0) then
            record.nextTeamSyncAt = now + 0.1
            self:_syncAllTeams(record)
            self:_processReplacementQueues(record, now)
            self:_syncPlayerEscort(record, now)
            self:_processPlayerReplacementQueue(record, now)
            if
                (self._config.endurance or {}).stop_when_all_teams_defeated == true
                and self:_allTeamsDefeated(record)
            then
                self:_finishDefenseOverrun(record)
                return
            end
        end
    end
    if not (record and record.nextWaveAt and now >= record.nextWaveAt) then
        return
    end
    if record.tutorialActive == true then
        record.nextWaveAt = nil
        self:_setWorldState("TutorialIntermission", record)
        return
    end
    local ok, reason = self:_spawnNextWave(record)
    if not ok and self:_isRecordActive(record) then
        record.nextWaveAt = nil
        self:_setWorldState("WaveSpawnFailed", record)
        self:_log("Warn", "Merge Egg prototype wave spawn failed", {
            player = record.player.Name,
            reason = reason,
        })
    end
end

function MergeEggPrototypeService:_step()
    local now = os.clock()
    self:_stepTowerShots(now)
    for _, record in pairs(self._activeByPlayer) do
        self:_stepRecord(record, now)
    end
end

function MergeEggPrototypeService:_hatch(player, appendOwnedSlots)
    local record = self:_recordFor(player)
    if not record then
        return false, "not_active_player"
    end
    local appending = appendOwnedSlots == true and record.encounterSpawned == true
    if record.encounterSpawned and not appending then
        return false, "reset_required"
    end
    if record.hatching then
        return false, "hatch_in_progress"
    end
    local spawn = findNamedPart(record.world, (self._config.world or {}).hatcher_spawn)
    local principal = self._config.principal
    local activeTeamConfigs = self:_activeTeamConfigs(record)
    local teamConfigs = {}
    for _, teamCfg in ipairs(activeTeamConfigs) do
        local id = math.max(1, math.floor(tonumber(teamCfg.id) or #teamConfigs + 1))
        if not appending or record.teamById[id] == nil then
            teamConfigs[#teamConfigs + 1] = teamCfg
        end
    end
    if appending and #teamConfigs == 0 then
        return true
    end
    if not (spawn and type(principal) == "table" and #teamConfigs > 0) then
        return false, "hatcher_unavailable"
    end

    record.hatching = true
    record.terminal = false
    record.terminalState = nil
    local hatchCount = self:_positionsForEggTier(1, record)
    local progression = self:_eggProgression(record)
    local progressionStageId = self:_progressionStage(record)
    local firstEggData = self._petsConfig
        and self._petsConfig.egg_sources
        and self._petsConfig.egg_sources[progression[1]]
    local totalUnits = 0
    for index, teamCfg in ipairs(teamConfigs) do
        local id = math.max(1, math.floor(tonumber(teamCfg.id) or index))
        if record.teamById[id] then
            self:_clearEncounter(record)
            return false, "duplicate_team_id"
        end
        local definition = table.clone(principal)
        definition.level = self:_prototypeBaseLevel(record)
        definition.name = tostring(teamCfg.principal_name or ("Merge Hatcher Team " .. id))
        definition.display_name =
            tostring(teamCfg.principal_display_name or ("Hatcher Captain " .. id))
        definition.squad = {}
        local expected = hatchCount
        local runtimeTeamConfig = table.clone(teamCfg)
        runtimeTeamConfig.squad = {}
        local targetGroup = record.runId .. ":team:" .. id
        local offset = teamCfg.spawn_offset or {}
        local stationX, positionSlot = stationXOffset(self._config, teamCfg, index)
        local spawnCFrame = spawn.CFrame * CFrame.new(stationX, 0, tonumber(offset.z) or 0)
        local principalOk, info = self._npcPrincipalService:SpawnStationary(
            player,
            "merge_egg_hatcher_" .. tostring(player.UserId) .. "_" .. id,
            spawnCFrame,
            {
                definition = definition,
                folderAttributes = {
                    MergeEggPrototypeTeam = true,
                    MergeEggOwnerUserId = player.UserId,
                    MergeEggRunId = record.runId,
                    MergeEggTeamId = id,
                    MergeEggPositionSlot = positionSlot,
                    MergeEggTeamDisplayName = tostring(teamCfg.display_name or "NPC Team 1"),
                    MergeEggTeamState = "NoEgg",
                    MergeEggExpectedPets = expected,
                    MergeEggSourceTier = 0,
                    MergeEggBalanceExperiment = record.balanceExperiment,
                    MergeEggProgressionStage = progressionStageId,
                    MergeEggBaseCombatLevel = self:_prototypeBaseLevel(record),
                    MergeEggOriginPowerMultiplier = 1,
                    MergeEggCanAdvance = true,
                    MergeEggCanUpgrade = true,
                    MergeEggRequiredTier = 1,
                    MergeEggRequiredSourceId = progression[1],
                    MergeEggRequiredSourceName = firstEggData and firstEggData.name or "Earth Egg",
                    MergeEggNextSourceId = progression[1],
                    MergeEggNextSourceName = firstEggData and firstEggData.name or "Earth Egg",
                    CombatTargetGroup = targetGroup,
                },
                petAttributes = {
                    MergeEggUnit = true,
                    MergeEggRunId = record.runId,
                    MergeEggTeamId = id,
                    CombatTargetGroup = targetGroup,
                    CombatCadenceMultiplier = combatCadenceMultiplier(self._config),
                    PrincipalLevel = self:_prototypeBaseLevel(record),
                    Level = self:_prototypeBaseLevel(record),
                    EphemeralDownPolicy = "destroy",
                },
            }
        )
        if not principalOk or type(info) ~= "table" then
            self:_clearEncounter(record)
            return false, tostring(info or "principal_spawn_failed")
        end
        self:_placeCaptainAtStation(info.model, record.world, spawn, positionSlot)
        if not self:_isRecordActive(record) then
            self._npcPrincipalService:Despawn(info.name, "merge_egg_session_ended")
            return false, "session_ended"
        end
        local team = {
            record = record,
            id = id,
            displayName = tostring(teamCfg.display_name or ("NPC Team " .. id)),
            config = runtimeTeamConfig,
            targetGroup = targetGroup,
            principalName = info.name,
            principalModel = info.model,
            folder = info.folder,
            units = {},
            state = "NoEgg",
            expectedPets = expected,
            initialized = false,
            activePets = 0,
            defeatedPets = 0,
            assignedAlive = 0,
            peakAssignedEnemies = 0,
            firstLossWave = nil,
            firstLossAssignedEnemies = nil,
            engaged = false,
            isReserve = false,
            reinforcementCommitted = false,
            reinforcementReason = nil,
            reinforcementTargetId = nil,
            replacementQueue = {},
            pendingReplacementSlots = {},
            nextReplacementAt = nil,
            replacementsQueued = 0,
            replacementsHatched = 0,
            eggProductionLockedUntil = nil,
            eggProductionDamageHits = 0,
            eggProductionLockouts = 0,
            eggRolls = 0,
            eggGoldenRolls = 0,
            eggRainbowRolls = 0,
            eggHugeRolls = 0,
            prototypeHugeRolls = 0,
            eggTier = 0,
            eggId = nil,
            eggName = nil,
            hatchPlayerData = nil,
            eggHealth = 0,
            eggMaxHealth = self:_hatcherEggMaxHealth(record),
            eggDamageTaken = 0,
            eggObjective = nil,
            eggObjectiveArmed = false,
            healDenialActiveUntil = 0,
            healDenialReadyAt = 0,
            healDenialActivations = 0,
            healDenialLastTrigger = nil,
            healDenialSuppressedEnemies = 0,
            healDenialRune = nil,
            needsEggRebuild = false,
            resetEggTier = nil,
            resetEggId = nil,
            resetEggName = nil,
            resetHatchPlayerData = nil,
            eggsDestroyed = 0,
            eggsRebuilt = 0,
            balanceExperiment = record.balanceExperiment,
            progressionStageId = progressionStageId,
            originPowerMultiplier = 1,
            draftCandidateRolls = 0,
            draftRejectedRolls = 0,
            lastEggAdvanceAt = nil,
        }
        record.teams[#record.teams + 1] = team
        record.teamById[id] = team
        for _, model in ipairs(team.folder and team.folder:GetChildren() or {}) do
            if model:IsA("Model") then
                team.units[#team.units + 1] = model
                record.units[#record.units + 1] = model
            end
        end
        if team.principalModel then
            team.principalModel:SetAttribute("MergeEggPrototypeNpc", true)
            team.principalModel:SetAttribute("MergeEggRunId", record.runId)
            team.principalModel:SetAttribute("MergeEggTeamId", id)
            team.principalModel:SetAttribute("CombatTargetGroup", targetGroup)
        end
        if tonumber(info.pets) ~= 0 then
            self:_clearEncounter(record)
            return false, "empty_hatcher_spawned_units"
        end
        self:_publishTeamEggSource(team)
        totalUnits += tonumber(info.pets) or 0
        self:_setTeamState(record, team, "NoEgg")
    end
    if not appending and self._petFollowService and self._petFollowService.ReleaseMiningTargets then
        self._petFollowService:ReleaseMiningTargets(player)
    end

    record.encounterSpawned = true
    record.hatching = false
    self:_ensureDeploymentPads(record.world, record)
    self:_ensureHatcherStands(record.world)
    self:_ensureBayTowers(record)
    self:_ensureBayBulwarks(record)
    self:_syncAllTeams(record)
    if not appending then
        self:_setPortalVisible(record, false)
        self:_setWorldState("AwaitingFirstEgg", record)
    else
        self:_setWorldState(record.world:GetAttribute("PrototypeState") or "WaveActive", record)
    end
    self:_log(
        "Info",
        appending and "Merge Egg hatcher slot activated" or "Merge Egg prototype setup started",
        {
            player = player.Name,
            egg = "none",
            teams = #record.teams,
            addedTeams = #teamConfigs,
            units = totalUnits,
            golden = record.eggGoldenRolls,
            rainbow = record.eggRainbowRolls,
            huge = record.eggHugeRolls,
            pendingEnemies = record.pendingEnemySpawns,
            waves = self:_waveCount(record),
        }
    )
    return true
end

function MergeEggPrototypeService:_nearestPrototypeCoinDrop(player)
    local folder = Workspace:FindFirstChild("CoinDrops")
    local root = characterRoot(player)
    if not (folder and root) then
        return nil
    end
    local nearest
    local nearestDistance = math.huge
    for _, model in ipairs(folder:GetChildren()) do
        if
            model:IsA("Model")
            and model:GetAttribute("DropOwner") == player.UserId
            and model:GetAttribute("DropSource") == "merge_egg_prototype"
        then
            local part = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
            if part then
                local offset = Vector3.new(
                    part.Position.X - root.Position.X,
                    0,
                    part.Position.Z - root.Position.Z
                )
                if offset.Magnitude < nearestDistance then
                    nearest = model
                    nearestDistance = offset.Magnitude
                end
            end
        end
    end
    return nearest
end

function MergeEggPrototypeService:_stageOpeningReserve(stageId)
    local pricing = self:_earthEggPricing(stageId)
    local targetHatchers = math.max(1, math.floor(tonumber((self._config.team or {}).count) or 4))
    return MergeEggPricing.totalInitialPositionCost(pricing.baseAmount, targetHatchers),
        pricing.currency
end

function MergeEggPrototypeService:_captureProgressionStage(record)
    if record.stageReportCaptured == true then
        return record.progressionStageReports[record.progressionStageId]
    end
    local stageId, stage = self:_progressionStage(record)
    local pricing = self:_earthEggPricing(record)
    local endingCoins = self._economyService:GetCurrency(record.player, pricing.currency) or 0
    local spent = math.max(0, record.coreEggCoinsSpent or 0)
    local startingCoins = math.max(0, record.stageStartingCoins or 0)
    local report = {
        stageId = stageId,
        wave = record.waveIndex,
        completed = record.terminalState == "EncounterComplete",
        endingCoins = endingCoins,
        startingCoins = startingCoins,
        earnedCoins = math.max(0, endingCoins + spent - startingCoins),
        spentCoins = spent,
        droppedCoins = math.max(0, record.coinsDropped or 0),
        elapsedSeconds = math.max(0, os.clock() - (record.stageStartedAt or os.clock())),
        escaped = record.escaped,
        objectiveEggsRemaining = record.objectiveEggsRemaining,
        allEggsComplete = self:_nextCoreEggAction(record) == nil,
        firstEscapeWave = record.coinRunnerFirstEscapeWave,
        firstBreachWave = record.firstBreachWave,
        firstOverrunWave = record.firstOverrunWave,
        peakEnemiesPastBreachLine = record.peakEnemiesPastBreachLine or 0,
        draftCandidateRolls = record.draftCandidateRolls or 0,
        draftRejectedRolls = record.draftRejectedRolls or 0,
    }
    record.progressionStageReports[stageId] = report
    record.progressionCoinsSpentTotal = (record.progressionCoinsSpentTotal or 0) + spent
    record.progressionCoinsDroppedTotal = (record.progressionCoinsDroppedTotal or 0)
        + report.droppedCoins
    record.stageReportCaptured = true
    local completedHeavenPath = stageId == "heaven_1"
        or (stageId == "home" and #(stage.combat_layers or {}) > 1)
    if completedHeavenPath then
        record.heaven1StageComplete = report.completed
        record.heaven1CompletionCoins = endingCoins
    elseif stageId == "home" then
        record.homeStageComplete = report.completed
        record.homeCompletionCoins = endingCoins
        record.homeCompletionWave = report.wave
    end
    return report
end

function MergeEggPrototypeService:_clearProgressionStageActors(record)
    for _, enemy in ipairs(record.enemies or {}) do
        if enemy.model then
            self._enemyService:DespawnModel(enemy.model)
        end
    end
    for _, team in ipairs(record.teams or {}) do
        if team.principalName then
            self._npcPrincipalService:Despawn(team.principalName, "merge_egg_stage_transition")
        end
    end
    record.enemies = {}
    record.enemyByTargetId = {}
    record.units = {}
    self:_clearTowerShots(record)
    record.teams = {}
    record.teamById = {}
    record.aliveEnemies = 0
    record.waveIndex = 0
    record.defeated = 0
    record.escaped = 0
    record.alerted = 0
    record.breached = 0
    record.bulwarkCrossed = 0
    record.enemiesPastBulwark = 0
    record.peakEnemiesPastBulwark = 0
    record.enemiesPastBreachLine = 0
    record.peakEnemiesPastBreachLine = 0
    record.breachOverrunThreshold = 0
    record.breachOverrun = false
    record.breachOverrunStartedAt = nil
    record.nextBreachDamageAt = nil
    record.breachPressureHits = 0
    record.firstBreachWave = nil
    record.firstOverrunWave = nil
    record.hatcherEggsDestroyed = 0
    record.hatcherEggsRebuilt = 0
    record.eggProductionDamageHits = 0
    record.eggProductionLockouts = 0
    record.healDenialActiveFields = 0
    record.healDenialActivations = 0
    record.healDenialSuppressedEnemies = 0
    record.nextHealDenialTickAt = 0
    record.peakActiveEnemies = 0
    record.firstPetLossWave = nil
    record.firstPetLossActiveEnemies = nil
    record.nextWaveAt = nil
    record.nextWaveOverride = nil
    record.waveFocusTeamId = nil
    record.coinRunnerStartWave = nil
    record.pendingWaveSpawns = {}
    record.pendingEnemySpawns = 0
    record.waveGroupCount = 0
    record.nextEnemySpawnAt = nil
    record.resolvedTargets = {}
    record.nextTeamSyncAt = 0
    local startingEggs =
        math.max(1, math.floor(tonumber((self._config.objective or {}).starting_eggs) or 5))
    record.objectiveEggsStarting = startingEggs
    record.objectiveEggsRemaining = startingEggs
    record.objectiveHits = 0
    record.replacementsHatched = 0
    record.peakReplacementQueueDepth = 0
    record.longestReplacementWaitSeconds = 0
    record.enemiesRemainingAtDefeat = 0
    record.eggId = nil
    record.eggName = nil
    record.hatchPlayerData = nil
    record.eggRolls = 0
    record.eggGoldenRolls = 0
    record.eggRainbowRolls = 0
    record.eggHugeRolls = 0
    record.prototypeHugeRolls = 0
    record.draftCandidateRolls = 0
    record.draftRejectedRolls = 0
    record.draftGoldenCandidates = 0
    record.draftRainbowCandidates = 0
    record.draftHugeCandidates = 0
    record.maximumEggTier = 0
    record.hatcherEggAdvances = 0
    record.baseEggTier = self:_baseEggTier(nil)
    record.baseEggUpgradesPurchased = 0
    record.baseEggBoardPromotions = 0
    record.baseEggHatcherPromotions = 0
    record.baseEggUpgradeCoinsSpent = 0
    record.baseEggCreationCoinsSpent = 0
    record.baseEggUpgradeInProgress = false
    record.eggInventory = {}
    record.activityEggTierMilestones = {}
    record.activityMaximumPetSlots = nil
    record.eggsCreated = 0
    record.eggsMerged = 0
    record.eggsPlaced = 0
    record.lastEggCreateAt = nil
    record.lastEggMergeAt = nil
    record.eggCreateInProgress = false
    record.coinsDropped = 0
    record.earthEggCoinsSpent = 0
    record.coreEggCoinsSpent = 0
    record.coinRunnerFirstEscapeAt = nil
    record.coinRunnerFirstEscapeHatchers = nil
    record.coinRunnerFirstEscapeWave = nil
    record.coinRunnerFourHatcherAt = nil
    record.coinRunnerFourHatcherWave = nil
    record.coinRunnerAllSandAt = nil
    record.coinRunnerAllSandWave = nil
    record.checkpointSnapshot = nil
    record.pendingCheckpointWave = nil
    record.checkpointRestarts = 0
    record.checkpointLastFailedWave = nil
    record.checkpointAutoRestartAt = nil
    record.coinRunnerNoDropSince = nil
    record.stageReportCaptured = false
    record.encounterSpawned = false
    record.terminal = false
    record.terminalState = nil
    record.player:SetAttribute("CombatAssistTarget", nil)
    record.player:SetAttribute("CombatAssistUntil", nil)
    record.player:SetAttribute("CombatMusicCue", nil)
    record.player:SetAttribute("MergeEggWaveComplete", nil)
    self:_setPortalVisible(record, false)
end

function MergeEggPrototypeService:_transitionProgressionStage(record, stageId)
    self:_clearProgressionStageActors(record)
    record.progressionStageId = tostring(stageId)
    record.stageStartingCoins = self._economyService:GetCurrency(
        record.player,
        self:_earthEggPricing(record).currency
    ) or 0
    record.stageStartedAt = os.clock()
    local seed = math.floor(
        tonumber(record.coinRunnerSeed)
            or tonumber(((self._config.automation or {}).coin_runner or {}).random_seed)
            or 260826
    )
    local stageIndex = self:_progressionStageIndex(record)
    record.random = Random.new(seed + stageIndex * 100003)
    record.enemyRosterRandom = Random.new(seed + stageIndex * 100003 + 3571)
    record.lootRandom = Random.new(seed + stageIndex * 100003 + 7919)
    self:_setWorldState("StageTransition", record)
    return self:_hatch(record.player)
end

function MergeEggPrototypeService:_nextEmptyHatcher(record)
    for _, team in ipairs(record and record.teams or {}) do
        if team.initialized ~= true and team.principalModel and team.principalModel.Parent then
            return team
        end
    end
    return nil
end

function MergeEggPrototypeService:_setCoinRunnerState(record, state, target)
    if not self:_isRecordActive(record) then
        return
    end
    record.coinRunnerState = tostring(state or "Running")
    record.coinRunnerTarget = target and tostring(target) or nil
    local worldState = record.world and record.world:GetAttribute("PrototypeState")
        or "AwaitingFirstEgg"
    self:_setWorldState(worldState, record)
end

function MergeEggPrototypeService:_waitForCoinRunnerPoll(record, generation, seconds)
    local remaining = math.max(0, tonumber(seconds) or 0)
    while
        remaining > 0
        and self:_isRecordActive(record)
        and record.coinRunnerGeneration == generation
        and record.coinRunnerRunning == true
    do
        remaining -= RunService.Heartbeat:Wait()
    end
end

function MergeEggPrototypeService:_completeCoinRunnerStage(record, generation)
    local report = self:_captureProgressionStage(record)
    local stageId, stage = self:_progressionStage(record)
    local nextStageId = record.progressionSequential == true and stage.next_stage or nil
    if nextStageId then
        local reserve, currency = self:_stageOpeningReserve(nextStageId)
        local balance = self._economyService:GetCurrency(record.player, currency) or 0
        report.nextStageId = tostring(nextStageId)
        report.nextStageReserve = reserve
        report.nextStageReserveMet = balance >= reserve
        if stageId == "home" then
            record.homeEntryReserveRequired = reserve
            record.homeEntryReserveMet = balance >= reserve
        end
        self:_setWorldState("StageComplete", record)
        if balance < reserve then
            self:_finishCoinRunner(record, generation, "InsufficientNextStageReserve")
            return false
        end
        local transitioned, reason = self:_transitionProgressionStage(record, nextStageId)
        if not transitioned then
            self:_finishCoinRunner(record, generation, "StageTransitionFailed:" .. tostring(reason))
            return false
        end
        return true
    end

    record.progressionLoopComplete = report.completed == true
    self:_setWorldState(report.completed and "ProgressionComplete" or "StageFailed", record)
    self:_finishCoinRunner(
        record,
        generation,
        report.completed and "AllProgressionStagesComplete" or tostring(record.terminalState)
    )
    return false
end

function MergeEggPrototypeService:_finishCoinRunner(record, generation, reason)
    if self._automationService and self._automationService.SetPlayerControlsEnabled then
        self._automationService:SetPlayerControlsEnabled(record.player, true)
    end
    if
        not self:_isRecordActive(record)
        or record.coinRunnerGeneration ~= generation
        or record.coinRunnerRunning ~= true
    then
        return
    end

    if record.stageReportCaptured ~= true and record.encounterSpawned == true then
        self:_captureProgressionStage(record)
    end
    local result = record.progressionLoopComplete == true and "ProgressionLoopComplete"
        or tostring(reason or "Stopped")
    local pricing = self:_earthEggPricing(record)
    local endingCoins = self._economyService:GetCurrency(record.player, pricing.currency) or 0
    local spent = math.max(0, record.progressionCoinsSpentTotal or 0)
    local startingCoins = record.coinRunnerStartingCoins or 0

    record.coinRunnerRunning = false
    record.coinRunnerState = record.progressionLoopComplete == true and "Complete" or "Failed"
    record.coinRunnerResult = result
    record.coinRunnerStopReason = tostring(reason or "Stopped")
    record.coinRunnerTarget = nil
    record.coinRunnerEndingCoins = endingCoins
    record.coinRunnerCoinsSpent = spent
    record.coinRunnerCoinsEarned = math.max(0, endingCoins + spent - startingCoins)
    record.coinRunnerCoinsDropped = math.max(0, record.progressionCoinsDroppedTotal or 0)
    record.coinRunnerWaveReached = record.waveIndex
    record.coinRunnerElapsedSeconds = math.max(0, os.clock() - record.coinRunnerStartedAt)
    self:_setWorldState(record.world:GetAttribute("PrototypeState") or "WaveActive", record)
    self:_log("Info", "Merge Egg coin runner finished", {
        player = record.player.Name,
        result = result,
        wave = record.coinRunnerWaveReached,
        hatchers = self:_initializedHatcherCount(record),
        stage = record.progressionStageId,
        homeComplete = record.homeStageComplete == true,
        homeEntryReserveMet = record.homeEntryReserveMet == true,
        heaven1Complete = record.heaven1StageComplete == true,
        startingCoins = startingCoins,
        earnedCoins = record.coinRunnerCoinsEarned,
        droppedCoins = record.coinRunnerCoinsDropped,
        spentCoins = spent,
        endingCoins = endingCoins,
        elapsedSeconds = record.coinRunnerElapsedSeconds,
    })
end

function MergeEggPrototypeService:_runCoinRunner(record, generation)
    local automationCfg = (self._config.automation or {}).coin_runner or {}
    local targetHatchers =
        math.max(1, math.floor(tonumber(automationCfg.target_hatchers) or #(record.teams or {})))
    local timeout = math.max(1, tonumber(automationCfg.navigation_timeout) or 18)
    local hatcherThreshold = math.max(1, tonumber(automationCfg.hatcher_arrival_distance) or 7)
    local stationThreshold = math.max(1, tonumber(automationCfg.station_arrival_distance) or 7)
    local dropThreshold = math.max(1, tonumber(automationCfg.drop_arrival_distance) or 6)
    local idleSeconds = math.max(0.05, tonumber(automationCfg.idle_poll_seconds) or 0.15)
    local maximumFailures =
        math.max(1, math.floor(tonumber(automationCfg.maximum_navigation_failures) or 8))
    local completedDropPollSeconds =
        math.max(0.1, tonumber(automationCfg.completed_drop_poll_seconds) or 0.6)
    local navigationFailures = 0

    local function recordNavigation(result, context)
        if result.ok then
            navigationFailures = 0
            return
        end
        navigationFailures += 1
        record.coinRunnerLastNavigationFailure = string.format(
            "%s:%s",
            tostring(context or "unknown"),
            tostring(result.reason or "unknown")
        )
    end

    local function navigationBudgetExhausted()
        if navigationFailures < maximumFailures then
            return false
        end
        local upgradeCfg = (self._config.automation or {}).upgrade_runner or {}
        local maximumRecoveries =
            math.max(0, math.floor(tonumber(upgradeCfg.maximum_navigation_restarts) or 0))
        if
            record.upgradeExperimentChannel ~= nil
            and (record.coinRunnerNavigationRecoveries or 0) < maximumRecoveries
        then
            record.coinRunnerNavigationRecoveries = (record.coinRunnerNavigationRecoveries or 0) + 1
            navigationFailures = 0
            local humanoid = record.player.Character
                and record.player.Character:FindFirstChildOfClass("Humanoid")
            if humanoid then
                humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            end
            self:_waitForCoinRunnerPoll(record, generation, 0.5)
            return false
        end
        return true
    end

    local function collectDrop(drop, state, target)
        self:_setCoinRunnerState(record, state, target)
        local navigation = self._automationService:NavigateTo(record.player, drop, {
            threshold = dropThreshold,
            timeout = timeout,
            keepControlsDisabled = true,
        })
        recordNavigation(navigation, "drop")
        self:_waitForCoinRunnerPoll(record, generation, idleSeconds)
    end

    while
        self:_isRecordActive(record)
        and record.coinRunnerGeneration == generation
        and record.coinRunnerRunning == true
    do
        if record.terminal == true then
            if record.terminalState ~= "EncounterComplete" then
                if self:_canRestartCheckpoint(record) then
                    self:_setCoinRunnerState(
                        record,
                        "RestartingCheckpoint",
                        string.format(
                            "Wave %d lost • restarting after Checkpoint %d",
                            record.waveIndex,
                            record.checkpointSnapshot.wave
                        )
                    )
                    local restored, restoreReason = self:_restoreCheckpoint(record, "coin_runner")
                    if restored then
                        navigationFailures = 0
                        self:_waitForCoinRunnerPoll(record, generation, idleSeconds)
                        continue
                    end
                    self:_finishCoinRunner(
                        record,
                        generation,
                        "CheckpointRestoreFailed:" .. tostring(restoreReason)
                    )
                    return
                end
                self:_finishCoinRunner(record, generation, record.terminalState or "EncounterEnded")
                return
            end
            local drop = self:_nearestPrototypeCoinDrop(record.player)
            if drop then
                record.coinRunnerNoDropSince = nil
                collectDrop(drop, "SweepingStageDrops", "Collecting every remaining Waycoin")
            else
                record.coinRunnerNoDropSince = record.coinRunnerNoDropSince or os.clock()
                if os.clock() - record.coinRunnerNoDropSince >= completedDropPollSeconds then
                    if not self:_completeCoinRunnerStage(record, generation) then
                        return
                    end
                    navigationFailures = 0
                else
                    self:_setCoinRunnerState(
                        record,
                        "VerifyingStageSweep",
                        "Waiting for the final pickups"
                    )
                    self:_waitForCoinRunnerPoll(record, generation, idleSeconds)
                end
            end
            if navigationBudgetExhausted() then
                self:_finishCoinRunner(record, generation, "NavigationFailed")
                return
            end
            continue
        end

        local hatcherCount = self:_initializedHatcherCount(record)
        if hatcherCount >= targetHatchers and record.coinRunnerFourHatcherAt == nil then
            record.coinRunnerFourHatcherAt = os.clock()
            record.coinRunnerFourHatcherWave = record.waveIndex
        end

        local team, nextCost = self:_nextCoreEggAction(record)
        if not team then
            if record.coinRunnerAllSandAt == nil then
                record.coinRunnerAllSandAt = os.clock()
                record.coinRunnerAllSandWave = record.waveIndex
            end
            local drop = self:_nearestPrototypeCoinDrop(record.player)
            if drop then
                collectDrop(
                    drop,
                    "CollectingStageReserve",
                    "All eggs complete • building reserve"
                )
            else
                self:_setCoinRunnerState(
                    record,
                    "HoldingAllEggs",
                    "All eggs complete • waiting for the next drop"
                )
                self:_waitForCoinRunnerPoll(record, generation, idleSeconds)
            end
            if navigationBudgetExhausted() then
                self:_finishCoinRunner(record, generation, "NavigationFailed")
                return
            end
            continue
        end
        local progression = self:_eggProgression(record)
        local nextEggId = progression[nextCost.tier]
        local nextEgg = nextEggId
            and self._petsConfig.egg_sources
            and self._petsConfig.egg_sources[nextEggId]
        if self:_eggInventoryCount(record, nextCost.tier) > 0 then
            self:_setCoinRunnerState(
                record,
                "PlacingCraftedEgg",
                string.format(
                    "Captain %d • place %s",
                    team.id,
                    nextEgg and nextEgg.name or "Next Egg"
                )
            )
            local navigation =
                self._automationService:NavigateTo(record.player, team.principalModel, {
                    threshold = hatcherThreshold,
                    timeout = timeout,
                    keepControlsDisabled = true,
                })
            recordNavigation(navigation, "hatcher")
            local placed, placeReason = self:AdvanceHatcherEgg(record.player, {
                teamId = team.id,
                coinRunnerGeneration = generation,
            })
            if not placed and placeReason ~= "egg_not_crafted" then
                navigationFailures += 1
                record.coinRunnerLastNavigationFailure = "place:" .. tostring(placeReason)
            end
        else
            local mergeTier = self:_mergeableEggTier(record)
            if mergeTier then
                local mergeStation = findNamedPart(
                    record.world,
                    (self._config.world or {}).egg_merge_control or "EggMergeControl"
                )
                self:_setCoinRunnerState(
                    record,
                    "MergingEggs",
                    string.format("Merge tier %d → tier %d", mergeTier, mergeTier + 1)
                )
                local navigation = self._automationService:NavigateTo(record.player, mergeStation, {
                    threshold = stationThreshold,
                    timeout = timeout,
                    keepControlsDisabled = true,
                })
                recordNavigation(navigation, "merge_station")
                local merged, mergeReason = self:MergeBoardEggs(record.player, {
                    coinRunnerGeneration = generation,
                })
                if
                    not merged
                    and mergeReason ~= "no_merge_available"
                    and mergeReason ~= "egg_merge_throttled"
                then
                    navigationFailures += 1
                    record.coinRunnerLastNavigationFailure = "merge:" .. tostring(mergeReason)
                end
                self:_waitForCoinRunnerPoll(record, generation, 0.22)
            else
                local pricing = self:_baseEggCreationCost(record)
                local balance = self._economyService:GetCurrency(record.player, pricing.currency)
                    or 0
                if balance >= pricing.amount then
                    local createStation = findNamedPart(
                        record.world,
                        (self._config.world or {}).egg_create_control or "EggCreateControl"
                    )
                    self:_setCoinRunnerState(
                        record,
                        "CreatingEarthEgg",
                        string.format("Create base egg • %d Waycoins", pricing.amount)
                    )
                    local navigation =
                        self._automationService:NavigateTo(record.player, createStation, {
                            threshold = stationThreshold,
                            timeout = timeout,
                            keepControlsDisabled = true,
                        })
                    recordNavigation(navigation, "create_station")
                    local created, createReason = self:CreateBaseEgg(record.player, {
                        coinRunnerGeneration = generation,
                    })
                    if
                        not created
                        and createReason ~= "insufficient_currency"
                        and createReason ~= "egg_create_throttled"
                    then
                        navigationFailures += 1
                        record.coinRunnerLastNavigationFailure = "create:" .. tostring(createReason)
                    end
                    self:_waitForCoinRunnerPoll(record, generation, 0.22)
                else
                    local drop = self:_nearestPrototypeCoinDrop(record.player)
                    if drop then
                        collectDrop(
                            drop,
                            "CollectingWaycoins",
                            string.format("%d / %d Waycoins", balance, pricing.amount)
                        )
                    else
                        self:_setCoinRunnerState(
                            record,
                            "WaitingForDrops",
                            string.format("%d / %d Waycoins", balance, pricing.amount)
                        )
                        self:_waitForCoinRunnerPoll(record, generation, idleSeconds)
                    end
                end
            end
        end

        if navigationBudgetExhausted() then
            self:_finishCoinRunner(record, generation, "NavigationFailed")
            return
        end
    end
end

function MergeEggPrototypeService:_captureUpgradeSweepResult(record, phase, outcome)
    local pricing = self:_earthEggPricing(record)
    local endingCoins = self._economyService
            and self._economyService:GetCurrency(record.player, pricing.currency)
        or 0
    local result = {
        phase = phase,
        outcome = outcome,
        multiplier = math.max(1, tonumber(record.upgradeExperimentMultiplier) or 1),
        percent = math.floor(
            (math.max(1, tonumber(record.upgradeExperimentMultiplier) or 1) - 1) * 100 + 0.5
        ),
        attempt = record.upgradeExperimentAttempt or 0,
        wave = record.waveIndex or 0,
        checkpointRestarts = record.checkpointRestarts or 0,
        checkpointLastFailedWave = record.checkpointLastFailedWave,
        objectiveEggsRemaining = record.objectiveEggsRemaining or 0,
        hatcherEggsDestroyed = record.hatcherEggsDestroyed or 0,
        hatcherEggAdvances = record.hatcherEggAdvances or 0,
        eggProductionDamageHits = record.eggProductionDamageHits or 0,
        eggProductionLockouts = record.eggProductionLockouts or 0,
        firstPetLossWave = record.firstPetLossWave,
        firstBreachWave = record.firstBreachWave,
        firstOverrunWave = record.firstOverrunWave,
        peakEnemiesPastBreachLine = record.peakEnemiesPastBreachLine or 0,
        coinsDropped = record.coinsDropped or 0,
        coinsSpent = record.coreEggCoinsSpent or 0,
        coinsEarned = record.coinRunnerCoinsEarned or 0,
        endingCoins = endingCoins,
        elapsedSeconds = record.coinRunnerElapsedSeconds or 0,
        stopReason = record.coinRunnerStopReason,
        navigationRecoveries = record.coinRunnerNavigationRecoveries or 0,
        lastNavigationFailure = record.coinRunnerLastNavigationFailure,
    }
    self._upgradeSweepResults[#self._upgradeSweepResults + 1] = result
    self:_setWorldState(record.world:GetAttribute("PrototypeState") or "ReadyToHatch", record)
    return result
end

-- Read-only Studio audit used by the automated Admin Reset lifecycle test. Keeping this on the
-- service makes the assertions inspect the same active record, authored bay, wallet, and durable
-- profile that gameplay owns; test scripts do not need to infer state from rendered UI.
function MergeEggPrototypeService:GetLifecycleAudit(player)
    if not player then
        return false, "player_required"
    end

    local record = self:_recordFor(player)
    local progress = self:_mergeDefenseProgress(player)
    local pricing = self:_earthEggPricing(record)
    local currency = tostring(record and record.sessionCurrency or pricing.currency)
    local wallet = self._economyService and self._economyService:GetCurrency(player, currency)
        or nil
    local world = record and self:_worldFor(record) or self:_resolveWorld()
    local worldCfg = self._config.world or {}
    local board = world and world:FindFirstChild(tostring(worldCfg.merge_board or "MergeBoard"))
    local eggs = board and board:FindFirstChild("Eggs")
    local signs = board and board:FindFirstChild("EggSigns")

    local deployedEggs = 0
    local initializedHatchers = 0
    local deployedTiers = {}
    for _, team in ipairs(record and record.teams or {}) do
        local tier = math.max(0, math.floor(tonumber(team.eggTier) or 0))
        if team.initialized == true then
            initializedHatchers += 1
        end
        if tier > 0 then
            deployedEggs += 1
        end
        deployedTiers[#deployedTiers + 1] = tier
    end

    local dropCount = 0
    local dropAmount = 0
    local gemDropCount = 0
    local gemDropAmount = 0
    local drops = Workspace:FindFirstChild("CoinDrops")
    for _, drop in ipairs(drops and drops:GetChildren() or {}) do
        if
            drop:GetAttribute("DropOwner") == player.UserId
            and drop:GetAttribute("DropSource") == "merge_egg_prototype"
        then
            local reason = drop:GetAttribute("DropReason")
            local amount = math.max(0, math.floor(tonumber(drop:GetAttribute("DropAmount")) or 0))
            if reason == "opening" then
                dropCount += 1
                dropAmount += amount
            elseif reason == "opening_gem" then
                gemDropCount += 1
                gemDropAmount += amount
            end
        end
    end
    local gemSpec = self:_openingGemSpec()
    local gemWallet = gemSpec
            and self._economyService
            and self._economyService:GetCurrency(player, gemSpec.currency)
        or nil

    local durable = progress
            and MergeEggPlaystate.normalize(progress.playstate, self:_checkpointOptions())
        or nil
    local durableBoardEggs = 0
    local durableDeployedEggs = 0
    for _, count in ipairs(durable and durable.egg_inventory or {}) do
        durableBoardEggs += math.max(0, math.floor(tonumber(count) or 0))
    end
    for _, tier in ipairs(durable and durable.deployed_egg_tiers or {}) do
        if math.max(0, math.floor(tonumber(tier) or 0)) > 0 then
            durableDeployedEggs += 1
        end
    end

    local bulwarkState = self:_normalizeBulwarkState(progress)
    local spawnedBulwarks = 0
    local bulwarkFolder = world and world:FindFirstChild("MergeEggBulwarks")
    for _, child in ipairs(bulwarkFolder and bulwarkFolder:GetChildren() or {}) do
        if child:IsA("Model") and child:GetAttribute("MergeBulwarkSpawned") == true then
            spawnedBulwarks += 1
        end
    end

    return true,
        {
            active = record ~= nil and record.terminal ~= true,
            runId = record and record.runId or nil,
            wave = record and math.max(0, math.floor(tonumber(record.waveIndex) or 0)) or 0,
            encounterSpawned = record and record.encounterSpawned == true or false,
            tutorialActive = record and record.tutorialActive == true or false,
            tutorialStep = record and record.tutorialStep or nil,
            tutorialCompleted = progress and progress.tutorial_completed == true or false,
            currency = currency,
            wallet = wallet,
            eggsCreated = record and math.max(0, math.floor(tonumber(record.eggsCreated) or 0))
                or 0,
            eggsMerged = record and math.max(0, math.floor(tonumber(record.eggsMerged) or 0)) or 0,
            eggsPlaced = record and math.max(0, math.floor(tonumber(record.eggsPlaced) or 0)) or 0,
            boardInventory = record and self:_eggInventoryTotal(record) or 0,
            boardEggVisuals = eggs and #eggs:GetChildren() or 0,
            boardSigns = signs and #signs:GetChildren() or 0,
            initializedHatchers = initializedHatchers,
            deployedEggs = deployedEggs,
            deployedTiers = deployedTiers,
            openingDropCount = dropCount,
            openingDropAmount = dropAmount,
            openingGemCount = gemDropCount,
            openingGemAmount = gemDropAmount,
            gemWallet = gemWallet,
            openingPickupsSpawned = record
                    and math.max(0, math.floor(tonumber(record.openingPickupsSpawned) or 0))
                or 0,
            coinRunnerRunning = record and record.coinRunnerRunning == true or false,
            durablePlaystatePresent = durable ~= nil and durable.saved == true and (math.max(
                0,
                math.floor(tonumber(durable.coins) or 0)
            ) > 0 or self:_playstateHasBoard(durable)),
            durablePlaystateWave = durable and durable.wave or nil,
            durableBoardEggs = durableBoardEggs,
            durableDeployedEggs = durableDeployedEggs,
            bulwarkInstalled = bulwarkState.family ~= nil,
            bulwarkFamily = bulwarkState.family,
            bulwarkTier = bulwarkState.tier,
            eggBulwarkInstalled = bulwarkState.eggFamily ~= nil,
            eggBulwarkFamily = bulwarkState.eggFamily,
            eggBulwarkTier = bulwarkState.eggTier,
            bulwarkVisuals = spawnedBulwarks,
        }
end

function MergeEggPrototypeService:StartUpgradeSweep(player, options)
    if not RunService:IsStudio() then
        return false, "studio_only"
    end
    local record = self:_recordFor(player)
    if not record or record.terminal == true then
        return false, "not_active_encounter"
    end
    if self._upgradeSweepRunning == true or record.coinRunnerRunning == true then
        return false, "automation_running"
    end
    if record.encounterSpawned or record.waveIndex ~= 0 then
        return false, "fresh_encounter_required"
    end

    options = type(options) == "table" and options or {}
    local upgradeCfg = (self._config.automation or {}).upgrade_runner or {}
    local requestedPhases = type(options.phases) == "table" and options.phases
        or upgradeCfg.phases
        or { "speed", "power", "coins" }
    local phases = {}
    for _, requested in ipairs(requestedPhases) do
        local phase = tostring(requested)
        if not UPGRADE_EXPERIMENT_CHANNELS[phase] then
            return false, "unknown_upgrade_experiment"
        end
        phases[#phases + 1] = phase
    end
    if #phases == 0 then
        return false, "upgrade_experiment_required"
    end

    self._upgradeSweepGeneration = (self._upgradeSweepGeneration or 0) + 1
    local sweepGeneration = self._upgradeSweepGeneration
    self._upgradeSweepRunning = true
    self._upgradeSweepPhase = phases[1]
    self._upgradeSweepResults = {}
    self:_setWorldState("UpgradeSweepStarting", record)

    task.spawn(function()
        local phaseIndex = 1
        local firstAttempts = {}
        local navigationRetries = {}
        for _, phase in ipairs(phases) do
            local optionName = phase .. "FirstAttempt"
            firstAttempts[phase] = math.max(1, math.floor(tonumber(options[optionName]) or 1))
            navigationRetries[phase] = 0
        end
        local maximumNavigationRestarts =
            math.max(0, math.floor(tonumber(upgradeCfg.maximum_navigation_restarts) or 2))

        while
            self._upgradeSweepRunning == true
            and self._upgradeSweepGeneration == sweepGeneration
            and self:_isRecordActive(record)
            and phases[phaseIndex] ~= nil
        do
            local phase = phases[phaseIndex]
            self._upgradeSweepPhase = phase
            self:_setWorldState("UpgradeSweepStartingPhase", record)
            local started, startReason = self:StartCoinRunner(player, {
                stage = options.stage or "home",
                seed = options.seed,
                sequential = options.sequential,
                upgradeExperiment = phase,
                upgradeStep = options.upgradeStep,
                firstUpgradeAttempt = firstAttempts[phase],
            })
            if not started then
                self._upgradeSweepResults[#self._upgradeSweepResults + 1] = {
                    phase = phase,
                    outcome = "start_failed",
                    reason = startReason,
                }
                break
            end

            while
                self._upgradeSweepRunning == true
                and self._upgradeSweepGeneration == sweepGeneration
                and self:_isRecordActive(record)
                and record.coinRunnerRunning == true
            do
                RunService.Heartbeat:Wait()
            end
            if
                self._upgradeSweepRunning ~= true
                or self._upgradeSweepGeneration ~= sweepGeneration
                or not self:_isRecordActive(record)
            then
                break
            end

            if record.progressionLoopComplete == true then
                self:_captureUpgradeSweepResult(record, phase, "passed")
                phaseIndex += 1
            elseif
                record.coinRunnerStopReason == "NavigationFailed"
                and navigationRetries[phase] < maximumNavigationRestarts
            then
                self:_captureUpgradeSweepResult(record, phase, "navigation_retry")
                navigationRetries[phase] += 1
                firstAttempts[phase] = math.max(
                    firstAttempts[phase],
                    math.floor(tonumber(record.upgradeExperimentAttempt) or 0) + 1
                )
            else
                self:_captureUpgradeSweepResult(record, phase, "failed")
                break
            end

            if phases[phaseIndex] ~= nil or record.progressionLoopComplete ~= true then
                self:_clearEncounter(record)
                local remaining = 1
                while remaining > 0 and self:_isRecordActive(record) do
                    remaining -= RunService.Heartbeat:Wait()
                end
            end
        end

        if self._upgradeSweepGeneration == sweepGeneration then
            self._upgradeSweepRunning = false
            self._upgradeSweepPhase = phases[phaseIndex] == nil and "complete"
                or self._upgradeSweepPhase
            self:_setWorldState(
                phases[phaseIndex] == nil and "UpgradeSweepComplete" or "UpgradeSweepStopped",
                self:_isRecordActive(record) and record or nil
            )
        end
    end)
    return true
end

function MergeEggPrototypeService:StartCoinRunner(player, options)
    if not RunService:IsStudio() then
        return false, "studio_only"
    end
    local record = self:_recordFor(player)
    if not record or record.terminal == true then
        return false, "not_active_encounter"
    end
    if not (self._automationService and self._economyService) then
        return false, "automation_unavailable"
    end
    if record.coinRunnerRunning == true then
        return false, "automation_running"
    end
    options = type(options) == "table" and options or {}
    local loop = self._config.progression_loop or {}
    local requestedStageId = tostring(options.stage or loop.default_stage or "home")
    local stages = loop.stages or {}
    if type(stages[requestedStageId]) ~= "table" then
        return false, "unknown_progression_stage"
    end
    if record.encounterSpawned and record.progressionStageId ~= requestedStageId then
        return false, "fresh_stage_required"
    end
    record.progressionStageId = requestedStageId
    local requestedExperiment = type(options) == "table" and options.experiment or nil
    if requestedExperiment ~= nil then
        local teamCfg = self._config.team or {}
        local modes = (teamCfg.balance_experiments or {}).modes or {}
        if type(modes[tostring(requestedExperiment)]) ~= "table" then
            return false, "unknown_balance_experiment"
        end
        record.balanceExperiment = tostring(requestedExperiment)
    else
        record.balanceExperiment = self:_balanceExperiment(nil)
    end
    local requestedUpgradeChannel = options.upgradeExperiment
            and tostring(options.upgradeExperiment)
        or nil
    if requestedUpgradeChannel and not UPGRADE_EXPERIMENT_CHANNELS[requestedUpgradeChannel] then
        return false, "unknown_upgrade_experiment"
    end
    local upgradeCfg = (self._config.automation or {}).upgrade_runner or {}
    record.upgradeExperimentChannel = requestedUpgradeChannel
    record.upgradeExperimentStep =
        math.max(0.01, tonumber(options.upgradeStep) or tonumber(upgradeCfg.step) or 0.05)
    record.upgradeExperimentAttempt = 0
    record.upgradeExperimentNextAttempt =
        math.max(1, math.floor(tonumber(options.firstUpgradeAttempt) or 1))
    record.upgradeExperimentMultiplier = 1
    if not record.encounterSpawned then
        local hatched, hatchReason = self:_hatch(player)
        if not hatched then
            return false, hatchReason
        end
    end
    if record.waveIndex ~= 0 or self:_initializedHatcherCount(record) ~= 0 then
        return false, "fresh_encounter_required"
    end
    local requestedStartWave = math.floor(tonumber(options.startWave) or 1)
    if requestedStartWave < 1 or requestedStartWave > self:_waveCount(record) then
        return false, "invalid_start_wave"
    end
    local requestedFocusTeamId = options.focusTeamId and tonumber(options.focusTeamId) or nil
    if
        requestedFocusTeamId ~= nil
        and (requestedFocusTeamId % 1 ~= 0 or record.teamById[requestedFocusTeamId] == nil)
    then
        return false, "invalid_focus_team"
    end

    local automationCfg = (self._config.automation or {}).coin_runner or {}
    local stageIndex = self:_progressionStageIndex(record)
    local requestedSeed =
        math.floor(tonumber(options.seed) or tonumber(automationCfg.random_seed) or 260826)
    record.coinRunnerSeed = requestedSeed
    record.random = Random.new(requestedSeed + stageIndex * 100003)
    record.enemyRosterRandom = Random.new(requestedSeed + stageIndex * 100003 + 3571)
    record.lootRandom = Random.new(requestedSeed + stageIndex * 100003 + 7919)
    local _, stage = self:_progressionStage(record)
    local pricing = self:_earthEggPricing(record)
    local configuredStartingCoins = options.startingCoins
        or (requestedStageId == tostring(loop.default_stage or "home") and stage.starting_coins)
        or stage.independent_starting_coins
        or automationCfg.starting_coins
        or 100
    local startingCoins = math.max(0, math.floor(tonumber(configuredStartingCoins) or 100))
    local originalCoins = self._economyService:GetCurrency(player, pricing.currency)
    if originalCoins == nil then
        return false, "currency_unavailable"
    end
    if self._dropService and self._dropService.DiscardDrops then
        self._dropService:DiscardDrops(player, "merge_egg_prototype")
    end
    if
        not self._economyService:SetCurrency(
            player,
            pricing.currency,
            startingCoins,
            "merge_egg_coin_runner_setup"
        )
    then
        return false, "currency_setup_failed"
    end

    record.coinRunnerOriginalCoins = originalCoins
    record.coinRunnerGeneration = (record.coinRunnerGeneration or 0) + 1
    local generation = record.coinRunnerGeneration
    record.coinRunnerRunning = true
    record.baseEggTier = self:_baseEggTier(nil)
    record.baseEggUpgradesPurchased = 0
    record.baseEggBoardPromotions = 0
    record.baseEggHatcherPromotions = 0
    record.baseEggUpgradeCoinsSpent = 0
    record.baseEggCreationCoinsSpent = 0
    record.baseEggUpgradeInProgress = false
    record.eggInventory = {}
    record.activityEggTierMilestones = {}
    record.activityMaximumPetSlots = nil
    record.eggsCreated = 0
    record.eggsMerged = 0
    record.eggsPlaced = 0
    record.lastEggCreateAt = nil
    record.lastEggMergeAt = nil
    record.eggCreateInProgress = false
    record.coinRunnerState = "Starting"
    record.coinRunnerResult = nil
    record.coinRunnerStopReason = nil
    record.coinRunnerNavigationRecoveries = 0
    record.coinRunnerLastNavigationFailure = nil
    record.coinRunnerTarget = nil
    record.coinRunnerStartingCoins = startingCoins
    record.coinRunnerEndingCoins = nil
    record.coinRunnerCoinsEarned = nil
    record.coinRunnerCoinsSpent = 0
    record.coinRunnerCoinsDropped = nil
    record.coinRunnerWaveReached = nil
    record.coinRunnerElapsedSeconds = nil
    record.coinRunnerFirstEscapeAt = nil
    record.coinRunnerFirstEscapeHatchers = nil
    record.coinRunnerFirstEscapeWave = nil
    record.coinRunnerFourHatcherAt = nil
    record.coinRunnerFourHatcherWave = nil
    record.coinRunnerAllSandAt = nil
    record.coinRunnerAllSandWave = nil
    record.checkpointSnapshot = nil
    record.pendingCheckpointWave = nil
    record.checkpointRestarts = 0
    record.checkpointLastFailedWave = nil
    record.checkpointAutoRestartAt = nil
    record.coinRunnerStartWave = requestedStartWave
    record.nextWaveOverride = requestedStartWave > 1 and requestedStartWave or nil
    record.waveFocusTeamId = requestedFocusTeamId
    record.coinRunnerStartedAt = os.clock()
    record.coinRunnerSpentAtStart = 0
    record.coinRunnerDroppedAtStart = 0
    record.progressionSequential = options.sequential ~= false
        and requestedStageId == tostring(loop.default_stage or "home")
        and automationCfg.sequential_stages ~= false
        and requestedStartWave == 1
        and requestedFocusTeamId == nil
    record.progressionLoopComplete = false
    record.progressionStageReports = {}
    record.progressionCoinsSpentTotal = 0
    record.progressionCoinsDroppedTotal = 0
    record.stageStartingCoins = startingCoins
    record.stageStartedAt = record.coinRunnerStartedAt
    record.stageReportCaptured = false
    record.coinRunnerNoDropSince = nil
    record.homeStageComplete = false
    record.homeCompletionCoins = nil
    record.homeEntryReserveRequired = nil
    record.homeEntryReserveMet = false
    record.homeCompletionWave = nil
    record.heaven1StageComplete = false
    record.heaven1CompletionCoins = nil
    self._automationService:SetPlayerControlsEnabled(player, false)
    self:_setWorldState("AwaitingFirstEgg", record)

    task.spawn(function()
        local ok, err = xpcall(function()
            self:_runCoinRunner(record, generation)
        end, debug.traceback)
        if not ok then
            self:_log("Warn", "Merge Egg coin runner crashed", {
                player = player.Name,
                error = tostring(err),
            })
            self:_finishCoinRunner(record, generation, "AutomationError")
        end
    end)
    return true
end

function MergeEggPrototypeService:CreateBaseEgg(player, request)
    if not self:_allowsGameplayActions() then
        return false, "merge_place_only"
    end
    local record = self:_recordFor(player)
    if
        not record
        or record.player ~= player
        or not record.encounterSpawned
        or record.terminal == true
    then
        return false, "not_active_encounter"
    end
    request = type(request) == "table" and request or {}
    if
        record.coinRunnerRunning == true
        and request.coinRunnerGeneration ~= record.coinRunnerGeneration
    then
        return false, "automation_owns_board"
    end
    local stationName = request.managementBoard == true
            and tostring((self._config.world or {}).egg_merge_control or "EggMergeControl")
        or tostring((self._config.world or {}).egg_create_control or "EggCreateControl")
    local accessOk, accessReason, stationDistance = self:_canUseEggStation(player, stationName)
    if not accessOk then
        return false, accessReason
    end
    local now = os.clock()
    if record.lastEggCreateAt and now - record.lastEggCreateAt < 0.2 then
        return false, "egg_create_throttled"
    end
    if record.eggCreateInProgress == true then
        return false, "egg_create_in_progress"
    end
    if self:_eggInventoryTotal(record) >= self:_mergeBoardCapacity() then
        return false, "merge_board_full"
    end
    if not (self._economyService and self._economyService.Transact) then
        return false, "economy_unavailable"
    end

    local pricing = self:_baseEggCreationCost(record)
    record.eggCreateInProgress = true
    local commitFailure
    local transaction = self._economyService:Transact(player, {
        debits = pricing.amount > 0 and {
            [pricing.currency] = pricing.amount,
        } or {},
        reason = "merge_egg_create_base_egg",
        commit = function()
            if not self:_isRecordActive(record) or record.terminal == true then
                commitFailure = "board_state_changed"
                return false
            end
            record.eggInventory = record.eggInventory or {}
            record.eggInventory[pricing.tier] = self:_eggInventoryCount(record, pricing.tier) + 1
            return true
        end,
    })
    record.eggCreateInProgress = false
    if not transaction.ok then
        if transaction.reason == "precondition_failed" then
            return false, "insufficient_currency"
        end
        return false, commitFailure or transaction.reason
    end

    record.lastEggCreateAt = now
    record.eggsCreated = (record.eggsCreated or 0) + 1
    record.earthEggCoinsSpent = (record.earthEggCoinsSpent or 0) + pricing.amount
    record.baseEggCreationCoinsSpent = (record.baseEggCreationCoinsSpent or 0) + pricing.amount
    record.coreEggCoinsSpent = (record.coreEggCoinsSpent or 0) + pricing.amount
    local eggMilestone = self:_markEggTierMilestone(record, pricing.tier)
    local petSlotMilestone = self:_markPetSlotMilestone(record, pricing.tier)
    local automaticMerges = 0
    local automaticMilestones = {}
    if record.autoCombineEnabled == true then
        automaticMerges, automaticMilestones = self:_autoCombineBoard(record)
    end
    if automaticMerges == 0 then
        self:_publishBoardMutation(record)
    end
    self:_log("Info", "Merge Egg prototype base egg created", {
        player = player.Name,
        cost = pricing.amount,
        currency = pricing.currency,
        tier = pricing.tier,
        baseEggs = self:_eggInventoryCount(record, pricing.tier),
        stationDistance = stationDistance,
        automaticMerges = automaticMerges,
    })
    -- The five-purchase counter belongs only to the opening create_five lesson. Wave 6 also has
    -- an active tutorial while the lifetime eggsCreated counter is already at least five; sending
    -- the opening requirement there made one new board egg read as "five eggs ready."
    local tutorialRequiredEggs = record.tutorialActive == true
            and record.tutorialStep == "create_five"
            and self:_tutorialRequiredEggs()
        or nil
    self:_updateTutorial(record, now, true)
    local progression = self:_eggProgression(record)
    local eggId = progression[pricing.tier]
    return true,
        {
            eggsCreated = record.eggsCreated,
            tutorialRequiredEggs = tutorialRequiredEggs,
            operation = "created",
            eggTier = pricing.tier,
            eggId = eggId,
            eggName = self:_eggDisplayName(eggId),
            milestone = eggMilestone and "egg_created" or nil,
            petSlotMilestone = petSlotMilestone,
            milestones = automaticMilestones,
        }
end

function MergeEggPrototypeService:UpgradeBaseEgg(player, request)
    if not self:_allowsGameplayActions() then
        return false, "merge_place_only"
    end
    local record = self:_recordFor(player)
    if
        not record
        or record.player ~= player
        or not record.encounterSpawned
        or record.terminal == true
    then
        return false, "not_active_encounter"
    end
    if record.coinRunnerRunning == true then
        return false, "automation_owns_board"
    end
    request = type(request) == "table" and request or {}
    local stationName = request.managementBoard == true
            and tostring((self._config.world or {}).egg_merge_control or "EggMergeControl")
        or tostring((self._config.world or {}).egg_base_upgrade_control or "EggBaseUpgradeControl")
    local accessOk, accessReason, stationDistance = self:_canUseEggStation(player, stationName)
    if not accessOk then
        return false, accessReason
    end
    if record.baseEggUpgradeInProgress == true then
        return false, "base_egg_upgrade_in_progress"
    end
    if not (self._economyService and self._economyService.Transact) then
        return false, "economy_unavailable"
    end
    local ready, readyReason = self:_canUpgradeBaseEgg(record)
    if not ready then
        return false, readyReason
    end
    local currentTier = self:_baseEggTier(record)
    local upgrade = self:_baseEggUpgradeCost(record)
    if not upgrade then
        return false, "maximum_base_egg_reached"
    end
    local progression = self:_eggProgression(record)
    local source, sourceReason = self:_buildHatchSource(record, progression[upgrade.tier])
    if not source then
        return false, sourceReason
    end
    record.baseEggUpgradeInProgress = true
    local commitFailure
    local promotedBoardEggs = 0
    local transaction = self._economyService:Transact(player, {
        debits = upgrade.amount > 0 and {
            [upgrade.currency] = upgrade.amount,
        } or {},
        reason = "merge_egg_upgrade_base_egg",
        commit = function()
            if
                not self:_isRecordActive(record)
                or record.terminal == true
                or self:_baseEggTier(record) ~= currentTier
            then
                commitFailure = "base_egg_state_changed"
                return false
            end
            local stillReady, reason = self:_canUpgradeBaseEgg(record)
            if not stillReady then
                commitFailure = reason
                return false
            end
            record.baseEggTier = upgrade.tier
            promotedBoardEggs = self:_raiseBoardToBaseTier(record, upgrade.tier)
            return true
        end,
    })
    record.baseEggUpgradeInProgress = false
    if not transaction.ok then
        if transaction.reason == "precondition_failed" then
            return false, "insufficient_currency"
        end
        return false, commitFailure or transaction.reason
    end

    record.baseEggUpgradesPurchased = (record.baseEggUpgradesPurchased or 0) + 1
    record.baseEggBoardPromotions = (record.baseEggBoardPromotions or 0) + promotedBoardEggs
    local promotedHatchers, addedUnits, expansionFailures =
        self:_raiseHatchersToBaseTier(record, upgrade.tier, source)
    record.baseEggHatcherPromotions = (record.baseEggHatcherPromotions or 0) + promotedHatchers
    record.baseEggUpgradeCoinsSpent = (record.baseEggUpgradeCoinsSpent or 0) + upgrade.amount
    record.coreEggCoinsSpent = (record.coreEggCoinsSpent or 0) + upgrade.amount
    local petSlotMilestone = self:_markPetSlotMilestone(record, upgrade.tier)
    local automaticMerges = 0
    local automaticMilestones = {}
    if record.autoCombineEnabled == true then
        automaticMerges, automaticMilestones = self:_autoCombineBoard(record)
    end
    if automaticMerges == 0 then
        self:_publishBoardMutation(record)
    end
    self:_log("Info", "Merge Egg prototype base egg upgraded", {
        player = player.Name,
        fromTier = currentTier,
        toTier = upgrade.tier,
        cost = upgrade.amount,
        currency = upgrade.currency,
        stationDistance = stationDistance,
        promotedBoardEggs = promotedBoardEggs,
        promotedHatchers = promotedHatchers,
        addedUnits = addedUnits,
        expansionFailures = expansionFailures,
        automaticMerges = automaticMerges,
    })
    self:_updateTutorial(record, os.clock(), true)
    return true,
        {
            operation = "generator_upgraded",
            fromTier = currentTier,
            toTier = upgrade.tier,
            eggId = source.eggId,
            eggName = source.eggName,
            milestone = "generator_unlocked",
            petSlotMilestone = petSlotMilestone,
            milestones = automaticMilestones,
        }
end

function MergeEggPrototypeService:MergeBoardEggs(player, request)
    if not self:_allowsGameplayActions() then
        return false, "merge_place_only"
    end
    local record = self:_recordFor(player)
    if
        not record
        or record.player ~= player
        or not record.encounterSpawned
        or record.terminal == true
    then
        return false, "not_active_encounter"
    end
    request = type(request) == "table" and request or {}
    if
        record.coinRunnerRunning == true
        and request.coinRunnerGeneration ~= record.coinRunnerGeneration
    then
        return false, "automation_owns_board"
    end
    local stationName = tostring((self._config.world or {}).egg_merge_control or "EggMergeControl")
    local accessOk, accessReason, stationDistance = self:_canUseEggStation(player, stationName)
    if not accessOk then
        return false, accessReason
    end
    local now = os.clock()
    if record.lastEggMergeAt and now - record.lastEggMergeAt < 0.2 then
        return false, "egg_merge_throttled"
    end
    local tier = self:_mergeableEggTier(record)
    if not tier then
        return false, "no_merge_available"
    end

    if not self:_applyEggMerge(record, tier) then
        return false, "no_merge_available"
    end
    record.lastEggMergeAt = now
    self:_publishBoardMutation(record)
    local progression = self:_eggProgression(record)
    self:_log("Info", "Merge Egg prototype eggs merged", {
        player = player.Name,
        fromTier = tier,
        fromEgg = progression[tier],
        toTier = tier + 1,
        toEgg = progression[tier + 1],
        stationDistance = stationDistance,
    })
    return true
end

function MergeEggPrototypeService:_canUseMergeBoard(player)
    local root = characterRoot(player)
    local record = self:_recordFor(player)
    local board = record and record.world and self:_ensureMergeBoard(record.world)
    local boardRoot = board and board.PrimaryPart
    if not (root and boardRoot) then
        return false, "merge_board_unavailable"
    end
    local distance = Vector3.new(
        root.Position.X - boardRoot.Position.X,
        0,
        root.Position.Z - boardRoot.Position.Z
    ).Magnitude
    local cfg = (self._config.team or {}).merge_board or {}
    if distance > math.max(1, tonumber(cfg.board_use_distance) or 36) then
        return false, "merge_board_too_far", distance
    end
    return true, nil, distance
end

function MergeEggPrototypeService:MergeBoardSlots(player, request)
    if not self:_allowsGameplayActions() then
        return false, "merge_place_only"
    end
    local record = self:_recordFor(player)
    if
        not record
        or record.player ~= player
        or not record.encounterSpawned
        or record.terminal == true
    then
        return false, "not_active_encounter"
    end
    if record.coinRunnerRunning == true then
        return false, "automation_owns_board"
    end
    local accessOk, accessReason, boardDistance = self:_canUseMergeBoard(player)
    if not accessOk then
        return false, accessReason
    end
    request = type(request) == "table" and request or {}
    local sourceSlot = math.floor(tonumber(request.sourceSlot) or 0)
    local targetSlot = math.floor(tonumber(request.targetSlot) or 0)
    if sourceSlot == targetSlot then
        return false, "same_board_slot"
    end
    local sourceTier = self:_boardTierAtSlot(record, sourceSlot)
    local targetTier = self:_boardTierAtSlot(record, targetSlot)
    if not sourceTier or sourceTier ~= targetTier then
        return false, "egg_tier_mismatch"
    end
    local now = os.clock()
    if record.lastEggMergeAt and now - record.lastEggMergeAt < 0.2 then
        return false, "egg_merge_throttled"
    end
    local merged, eggMilestone, petSlotMilestone = self:_applyEggMerge(record, sourceTier)
    if not merged then
        return false, "no_merge_available"
    end
    record.lastEggMergeAt = now
    self:_publishBoardMutation(record)
    self:_log("Info", "Merge Egg prototype board eggs manually merged", {
        player = player.Name,
        sourceSlot = sourceSlot,
        targetSlot = targetSlot,
        tier = sourceTier,
        boardDistance = boardDistance,
    })
    self:_updateTutorial(record, now, true)
    local resultTier = sourceTier + 1
    local eggId = self:_eggProgression(record)[resultTier]
    return true,
        {
            operation = "merged",
            fromTier = sourceTier,
            toTier = resultTier,
            eggId = eggId,
            eggName = self:_eggDisplayName(eggId),
            milestone = eggMilestone and "egg_created" or nil,
            petSlotMilestone = petSlotMilestone,
        }
end

function MergeEggPrototypeService:ToggleAutoCombine(player)
    if not self:_allowsGameplayActions() then
        return false, "merge_place_only"
    end
    local record = self:_recordFor(player)
    if
        not record
        or record.player ~= player
        or not record.encounterSpawned
        or record.terminal == true
    then
        return false, "not_active_encounter"
    end
    local stationName = tostring((self._config.world or {}).egg_merge_control or "EggMergeControl")
    local accessOk, accessReason = self:_canUseEggStation(player, stationName)
    if not accessOk then
        return false, accessReason
    end
    -- Prototype-only entitlement seam: this toggle becomes Game Pass-gated when the product ships.
    record.autoCombineEnabled = record.autoCombineEnabled ~= true
    local merged = 0
    local milestones = {}
    if record.autoCombineEnabled then
        merged, milestones = self:_autoCombineBoard(record)
    end
    if merged == 0 then
        self:_publishBoardMutation(record)
    end
    return true,
        {
            operation = record.autoCombineEnabled and "auto_enabled" or "auto_disabled",
            enabled = record.autoCombineEnabled,
            milestones = milestones,
        }
end

function MergeEggPrototypeService:PurchaseBulwarkAction(player, request)
    if not self:_allowsGameplayActions() then
        return false, "merge_place_only"
    end
    local record = self:_recordFor(player)
    if
        not record
        or record.player ~= player
        or not record.encounterSpawned
        or record.terminal == true
    then
        return false, "not_active_encounter"
    end
    if record.bulwarkActionInProgress == true then
        return false, "bulwark_action_in_progress"
    end
    local request = type(request) == "table" and request or {}
    local slot = MergeBulwarkProgression.normalizeSlot(request.slot)
    if not self:_tutorialVendorsReady(record, "bulwark", slot) then
        return false, "vendor_not_ready"
    end
    local accessOk, accessReason = self:_canUseBulwarkMenu(player, slot)
    if not accessOk then
        return false, accessReason
    end
    local cfg = self:_edgeBulwarkConfig()
    local requestedAction = tostring(request.bulwarkAction or "")
    if not (self._economyService and self._economyService.Transact) then
        return false, "economy_unavailable"
    end
    if not self:_liveMergeDefense(player) then
        return false, "profile_unavailable"
    end
    local before = MergeBulwarkPersist.read(record, cfg)
    local nextState, progressionReason =
        MergeBulwarkPersist.apply(before, requestedAction, request.family, cfg, slot)
    if not nextState then
        return false, progressionReason
    end

    local price = MergeBulwarkProgression.actionCost(cfg, requestedAction, request.family)
    local charged = nextState.charged == true and price.amount or 0
    record.bulwarkActionInProgress = true
    local commitFailure
    local transaction = self._economyService:Transact(player, {
        debits = charged > 0 and {
            [price.currency] = charged,
        } or {},
        reason = "merge_egg_bulwark_" .. requestedAction,
        commit = function()
            if not self:_isRecordActive(record) or record.terminal == true then
                commitFailure = "not_active_encounter"
                return false
            end
            local live = self:_liveMergeDefense(player)
            if not live then
                commitFailure = "profile_unavailable"
                return false
            end
            MergeBulwarkPersist.write(record, live, nextState)
            if price.currency == "hall_coins" then
                MergeBulwarkPersist.addSpent(record, live, charged)
            end
            return true
        end,
    })
    record.bulwarkActionInProgress = false
    if not transaction.ok then
        if transaction.reason == "precondition_failed" then
            return false, "insufficient_currency"
        end
        return false, commitFailure or transaction.reason
    end

    record.bulwarksReady = false
    self:_ensureBayBulwarks(record)
    self:_setWorldState(record.world:GetAttribute("PrototypeState") or "AwaitingFirstEgg", record)
    self:_updateTutorial(record, os.clock(), true)
    if self._dataService and self._dataService.RequestSave then
        self._dataService:RequestSave(player, "merge_defense_bulwark", {
            debounceSeconds = 10,
            critical = false,
        })
    end
    self:_log("Info", "Merge Egg bulwark changed", {
        player = player.Name,
        operation = nextState.operation,
        slot = slot,
        family = nextState.family,
        eggFamily = nextState.eggFamily,
        tier = nextState.tier,
        cost = charged,
    })
    local menuState = self:_bulwarkMenuState(record, slot)
    menuState.operation = nextState.operation
    menuState.milestone = nextState.operation == "unlocked" and "bulwark_unlocked" or nil
    return true, menuState
end

function MergeEggPrototypeService:PurchaseCannonAction(player, request)
    if not self:_allowsGameplayActions() then
        return false, "merge_place_only"
    end
    local record = self:_recordFor(player)
    if
        not record
        or record.player ~= player
        or not record.encounterSpawned
        or record.terminal == true
    then
        return false, "not_active_encounter"
    end
    if record.towerActionInProgress == true then
        return false, "cannon_action_in_progress"
    end
    request = type(request) == "table" and request or {}
    local slot = MergeTowerProgression.normalizeSlot(request.slot)
    if not self:_tutorialVendorsReady(record, "artillery", slot) then
        return false, "vendor_not_ready"
    end
    local accessOk, accessReason = self:_canUseCannonMenu(player, slot)
    if not accessOk then
        return false, accessReason
    end
    local cfg = self:_edgeTowerConfig()
    local requestedAction = tostring(request.cannonAction or "")
    if not (self._economyService and self._economyService.Transact) then
        return false, "economy_unavailable"
    end
    if not self:_liveMergeDefense(player) then
        return false, "profile_unavailable"
    end
    local before = MergeCannonPersist.read(record, cfg)
    local nextState, progressionReason =
        MergeCannonPersist.apply(before, requestedAction, request.family, cfg, slot)
    if not nextState then
        return false, progressionReason
    end

    local price = MergeTowerProgression.actionCost(cfg, requestedAction, request.family)
    local charged = nextState.charged == true and price.amount or 0
    record.towerActionInProgress = true
    local commitFailure
    local transaction = self._economyService:Transact(player, {
        debits = charged > 0 and {
            [price.currency] = charged,
        } or {},
        reason = "merge_egg_cannon_" .. requestedAction,
        commit = function()
            if not self:_isRecordActive(record) or record.terminal == true then
                commitFailure = "not_active_encounter"
                return false
            end
            local live = self:_liveMergeDefense(player)
            if not live then
                commitFailure = "profile_unavailable"
                return false
            end
            MergeCannonPersist.write(record, live, nextState)
            if price.currency == "hall_coins" then
                MergeCannonPersist.addSpent(record, live, charged)
            end
            return true
        end,
    })
    record.towerActionInProgress = false
    if not transaction.ok then
        if transaction.reason == "precondition_failed" then
            return false, "insufficient_currency"
        end
        return false, commitFailure or transaction.reason
    end

    record.towersReady = false
    self:_ensureBayTowers(record)
    self:_setWorldState(record.world:GetAttribute("PrototypeState") or "AwaitingFirstEgg", record)
    if self._dataService and self._dataService.RequestSave then
        self._dataService:RequestSave(player, "merge_defense_tower", {
            debounceSeconds = 10,
            critical = false,
        })
    end
    self:_log("Info", "Merge Egg cannon changed", {
        player = player.Name,
        operation = nextState.operation,
        slot = slot,
        family = nextState.leftFamily or nextState.family,
        rightFamily = nextState.rightFamily,
        tier = nextState.leftTier or nextState.tier,
        cost = charged,
    })
    local menuState = self:_cannonMenuState(record, slot)
    menuState.operation = nextState.operation
    menuState.milestone = nextState.operation == "unlocked" and "cannon_unlocked" or nil
    return true, menuState
end

function MergeEggPrototypeService:PurchaseManagementUpgrade(player, request)
    if not self:_allowsGameplayActions() then
        return false, "merge_place_only"
    end
    local record = self:_recordFor(player)
    if
        not record
        or record.player ~= player
        or not record.encounterSpawned
        or record.terminal == true
    then
        return false, "not_active_encounter"
    end
    if record.coinRunnerRunning == true then
        return false, "automation_owns_upgrades"
    end
    if record.managementUpgradeInProgress == true then
        return false, "management_upgrade_in_progress"
    end
    request = type(request) == "table" and request or {}
    local upgradeId = tostring(request.upgradeId or "")
    local price = self:_managementUpgradeCost(record, upgradeId)
    local definition = self:_managementUpgradeDefinition(upgradeId)
    if not definition then
        return false, "invalid_management_upgrade"
    end
    if not price then
        return false, "management_upgrade_maxed"
    end
    local stationName = tostring((self._config.world or {}).egg_merge_control or "EggMergeControl")
    local accessOk, accessReason, stationDistance = self:_canUseEggStation(player, stationName)
    if not accessOk then
        return false, accessReason
    end
    if not (self._economyService and self._economyService.Transact) then
        return false, "economy_unavailable"
    end
    local progress = self:_mergeDefenseProgress(player)
    if not progress then
        return false, "profile_unavailable"
    end
    progress.management_upgrades = type(progress.management_upgrades) == "table"
            and progress.management_upgrades
        or {}

    local levelBefore = price.level
    record.managementUpgradeInProgress = true
    local commitFailure
    local transaction = self._economyService:Transact(player, {
        debits = price.amount > 0 and {
            [price.currency] = price.amount,
        } or {},
        reason = "merge_egg_management_upgrade_" .. upgradeId,
        commit = function()
            if
                not self:_isRecordActive(record)
                or record.terminal == true
                or self:_managementUpgradeLevel(record, upgradeId) ~= levelBefore
                or math.max(
                        0,
                        math.floor(tonumber(progress.management_upgrades[upgradeId]) or 0)
                    )
                    ~= levelBefore
            then
                commitFailure = "management_upgrade_state_changed"
                return false
            end
            record.managementUpgradeLevels[upgradeId] = levelBefore + 1
            record.managementUpgradeGemsSpent = (record.managementUpgradeGemsSpent or 0)
                + price.amount
            progress.management_upgrades[upgradeId] = levelBefore + 1
            progress.management_gems_spent = math.max(
                0,
                math.floor(tonumber(progress.management_gems_spent) or 0)
            ) + price.amount
            return true
        end,
    })
    record.managementUpgradeInProgress = false
    if not transaction.ok then
        if transaction.reason == "precondition_failed" then
            return false, "insufficient_currency"
        end
        return false, commitFailure or transaction.reason
    end

    if self._dataService and self._dataService.RequestSave then
        self._dataService:RequestSave(player, "merge_defense_management_upgrade", {
            debounceSeconds = 0,
            critical = true,
        })
    end
    if upgradeId == "egg_health" then
        self:_applyEggHealthUpgrade(record)
    elseif upgradeId == "active_slots" then
        self:_ensureDeploymentPads(record.world, record)
        local activated, activationReason = self:_hatch(player, true)
        if not activated then
            self:_log("Warn", "Merge Egg purchased slot waits for the next deployment", {
                player = player.Name,
                reason = activationReason,
                activeSlots = self:_activeSlotCount(record),
            })
        end
    else
        self:_stampUpgradeExperiment(record)
    end
    self:_setWorldState(record.world:GetAttribute("PrototypeState") or "AwaitingFirstEgg", record)
    self:_log("Info", "Merge Egg management upgrade purchased", {
        player = player.Name,
        upgrade = upgradeId,
        level = levelBefore + 1,
        amount = price.amount,
        currency = price.currency,
        stationDistance = stationDistance,
        activeSlots = self:_activeSlotCount(record),
    })
    return true,
        {
            operation = "purchased",
            upgradeId = upgradeId,
            displayName = tostring(definition.display_name or upgradeId),
            level = levelBefore + 1,
        }
end

function MergeEggPrototypeService:PurchaseRebirth(player, request)
    if not self:_allowsGameplayActions() then
        return false, "merge_place_only"
    end
    local record = self:_recordFor(player)
    if not record then
        return false, "not_active_encounter"
    end
    request = type(request) == "table" and request or {}
    if request.confirm ~= true then
        return false, "rebirth_confirmation_required"
    end
    if record.coinRunnerRunning == true or self._upgradeSweepRunning == true then
        return false, "automation_running"
    end
    if
        record.hatching == true
        or record.eggCreateInProgress == true
        or record.baseEggUpgradeInProgress == true
        or record.managementUpgradeInProgress == true
    then
        return false, "rebirth_action_in_progress"
    end
    if record.rebirthInProgress == true then
        return false, "rebirth_in_progress"
    end

    local status = self:_rebirthStatus(record)
    if status.maxed or not status.price then
        return false, "rebirth_maxed"
    end
    if not status.requirementMet then
        return false, "rebirth_egg_requirement"
    end
    local stationName = tostring((self._config.world or {}).egg_merge_control or "EggMergeControl")
    local accessOk, accessReason, stationDistance = self:_canUseEggStation(player, stationName)
    if not accessOk then
        return false, accessReason
    end
    if not (self._economyService and self._economyService.Transact) then
        return false, "economy_unavailable"
    end
    local progress = self:_mergeDefenseProgress(player)
    if not progress then
        return false, "profile_unavailable"
    end

    local countBefore = status.count
    local price = status.price
    record.rebirthInProgress = true
    local commitFailure
    local transaction = self._economyService:Transact(player, {
        debits = {
            [price.currency] = price.amount,
        },
        reason = "merge_egg_rebirth_" .. tostring(price.rank),
        commit = function()
            if
                not self:_isRecordActive(record)
                or MergeEggRebirth.normalizeCount(record.rebirthCount) ~= countBefore
                or MergeEggRebirth.normalizeCount(progress.rebirths) ~= countBefore
            then
                commitFailure = "rebirth_state_changed"
                return false
            end
            progress.rebirths = countBefore + 1
            progress.checkpoint = MergeEggCheckpoint.normalize(nil, self:_checkpointOptions())
            progress.playstate = MergeEggPlaystate.normalize(nil, self:_checkpointOptions())
            -- Unlocks stay (coin and Robux/game-pass). Placements do not.
            MergeCannonPersist.resetPlacements(nil, progress, self:_edgeTowerConfig())
            MergeBulwarkPersist.resetPlacements(nil, progress, self:_edgeBulwarkConfig())
            record.rebirthCount = progress.rebirths
            record.durableCheckpoint = progress.checkpoint
            record.durablePlaystate = progress.playstate
            return true
        end,
    })
    record.rebirthInProgress = false
    if not transaction.ok then
        if transaction.reason == "precondition_failed" then
            return false, "insufficient_currency"
        end
        return false, commitFailure or transaction.reason
    end

    if self._dataService and self._dataService.RequestSave then
        self._dataService:RequestSave(player, "merge_defense_rebirth", {
            debounceSeconds = 0,
            critical = true,
        })
    end
    local areasReconciled, personalHatchTier, personalHatchEggId, areaReason =
        self:_reconcilePersonalHatchAreas(player, record.rebirthCount)
    record.personalHatchTier = personalHatchTier
    record.personalHatchEggId = personalHatchEggId
    if not areasReconciled then
        self:_log("Warn", "Merge Egg rebirth area entitlement will retry on entry", {
            player = player.Name,
            rebirth = record.rebirthCount,
            eggId = personalHatchEggId,
            reason = areaReason,
        })
    end
    self:_clearEncounter(record)
    if not self:_resetSessionCurrency(record) then
        self:_log("Warn", "Merge Egg rebirth could not reset its session wallet", {
            player = player.Name,
            rebirth = record.rebirthCount,
        })
    end
    self:_spawnOpeningCoinDrops(record)
    local armed, armReason = self:_hatch(player)
    if not armed then
        return false, armReason
    end
    self:_startTutorial(record)
    self:_log("Info", "Merge Egg rebirth purchased", {
        player = player.Name,
        rebirthCount = record.rebirthCount,
        rebirthRank = MergeEggRebirth.rankForCount(record.rebirthCount),
        amount = price.amount,
        currency = price.currency,
        damageMultiplier = MergeEggRebirth.damageMultiplier(
            self._config.rebirth,
            record.rebirthCount
        ),
        cannonPowerMultiplier = self:_rebirthScalingMultiplier(record, "cannons", "power"),
        cannonRadiusMultiplier = self:_rebirthScalingMultiplier(record, "cannons", "radius"),
        bulwarkPowerMultiplier = self:_rebirthScalingMultiplier(record, "bulwarks", "power"),
        bulwarkRadiusMultiplier = self:_rebirthScalingMultiplier(record, "bulwarks", "radius"),
        coinMultiplier = self:_rebirthScalingMultiplier(record, "coins", "amount"),
        gemMultiplier = self:_rebirthScalingMultiplier(record, "gems", "amount"),
        stationDistance = stationDistance,
    })
    return true, MergeEggRebirth.rankForCount(record.rebirthCount)
end

function MergeEggPrototypeService:_boardSourceSlotForTier(record, tier)
    local resolvedTier = math.floor(tonumber(tier) or 0)
    if resolvedTier < 1 then
        return nil
    end
    for slot = 1, self:_mergeBoardCapacity() do
        if self:_boardTierAtSlot(record, slot) == resolvedTier then
            return slot
        end
    end
    return nil
end

-- One click performs one fair board-to-frontline pass. Empty hatchers receive the strongest
-- available board eggs first. Remaining hatchers then receive at most one matching-tier upgrade,
-- weakest deployed tier first. It deliberately does not merge board eggs or repeatedly advance a
-- single hatcher; Auto Combine remains a separate future entitlement.
function MergeEggPrototypeService:EquipBestHatchers(player)
    if not self:_allowsGameplayActions() then
        return false, "merge_place_only"
    end
    local record = self:_recordFor(player)
    if
        not record
        or record.player ~= player
        or not record.encounterSpawned
        or record.terminal == true
    then
        return false, "not_active_encounter"
    end
    if record.coinRunnerRunning == true then
        return false, "automation_owns_hatchers"
    end
    local accessOk, accessReason, boardDistance = self:_canUseMergeBoard(player)
    if not accessOk then
        return false, accessReason
    end
    local now = os.clock()
    if record.lastEquipBestAt and now - record.lastEquipBestAt < 0.35 then
        return false, "equip_best_throttled"
    end

    local plan = self:_equipBestPlan(record)
    if #plan == 0 then
        return false, "no_equip_best_action"
    end
    local equipped = 0
    local function place(team, sourceSlot)
        local ok = self:AdvanceHatcherEgg(player, {
            teamId = team.id,
            boardSourceSlot = sourceSlot,
        })
        if ok then
            equipped += 1
        end
    end
    for _, step in ipairs(plan) do
        local team = record.teamById[step.teamId]
        local sourceSlot = self:_boardSourceSlotForTier(record, step.sourceTier)
        if team and sourceSlot then
            place(team, sourceSlot)
        end
    end

    if equipped <= 0 then
        return false, "no_equip_best_action"
    end
    record.lastEquipBestAt = now
    self:_log("Info", "Merge Egg prototype equipped best board eggs", {
        player = player.Name,
        equipped = equipped,
        boardDistance = boardDistance,
        inventoryRemaining = self:_eggInventoryTotal(record),
    })
    return true, equipped
end

function MergeEggPrototypeService:HandleBoardAction(player, request)
    request = type(request) == "table" and request or {}
    local action = tostring(request.action or "")
    if action == "create" then
        return self:CreateBaseEgg(player, request)
    elseif action == "upgrade_base" then
        return self:UpgradeBaseEgg(player, request)
    elseif action == "purchase_upgrade" then
        return self:PurchaseManagementUpgrade(player, request)
    elseif action == "rebirth" then
        return self:PurchaseRebirth(player, request)
    elseif action == "merge_slots" then
        return self:MergeBoardSlots(player, request)
    elseif action == "deploy_to_hatcher" then
        return self:AdvanceHatcherEgg(player, {
            teamId = request.teamId,
            boardSourceSlot = request.sourceSlot,
        })
    elseif action == "equip_best" then
        return self:EquipBestHatchers(player)
    elseif action == "toggle_auto" then
        return self:ToggleAutoCombine(player)
    elseif action == "bulwark" then
        return self:PurchaseBulwarkAction(player, request)
    elseif action == "cannon" then
        return self:PurchaseCannonAction(player, request)
    elseif action == "quartermaster" then
        return self:UseQuartermasterService(player, request)
    end
    return false, "invalid_board_action"
end

function MergeEggPrototypeService:AdvanceHatcherEgg(player, request)
    if not self:_allowsGameplayActions() then
        return false, "merge_place_only"
    end
    if type(request) == "table" and request.automation == "upgrade_sweep" then
        return self:StartUpgradeSweep(player, request)
    end
    if type(request) == "table" and request.automation == "coin_runner" then
        return self:StartCoinRunner(player, request)
    end
    local record = self:_recordFor(player)
    if
        not record
        or record.player ~= player
        or not record.encounterSpawned
        or record.terminal == true
    then
        return false, "not_active_encounter"
    end
    if type(request) ~= "table" then
        return false, "invalid_request"
    end
    local teamId = tonumber(request.teamId)
    if not teamId or teamId % 1 ~= 0 then
        return false, "invalid_team"
    end
    local team = record.teamById[teamId]
    if not (team and team.folder and team.folder.Parent) then
        return false, "team_unavailable"
    end
    if
        record.coinRunnerRunning == true
        and request.coinRunnerGeneration ~= record.coinRunnerGeneration
    then
        return false, "automation_owns_hatchers"
    end
    if team.eggAdvanceInProgress == true then
        return false, "egg_advance_in_progress"
    end
    local boardSourceSlot = math.floor(tonumber(request.boardSourceSlot) or 0)
    local accessOk, accessReason, bulwarkDepth, hatcherDistance
    if boardSourceSlot > 0 then
        accessOk, accessReason, hatcherDistance = self:_canUseMergeBoard(player)
    else
        accessOk, accessReason, bulwarkDepth, hatcherDistance = self:_canUseHatcher(player, team)
    end
    if not accessOk then
        self:_log("Info", "Merge Egg hatcher use refused outside management zone", {
            player = player.Name,
            team = team.id,
            reason = accessReason,
            boardSourceSlot = boardSourceSlot > 0 and boardSourceSlot or nil,
            bulwarkDepth = bulwarkDepth,
            hatcherDistance = hatcherDistance,
        })
        return false, accessReason
    end
    local now = os.clock()
    if team.lastEggAdvanceAt and now - team.lastEggAdvanceAt < 0.25 then
        return false, "egg_advance_throttled"
    end
    local transaction = self:_deployedEggTransaction(team, record)
    local tierBefore = transaction.currentTier
    local requiredTier = transaction.requiredTier
    local resultTier = transaction.resultTier
    local resultEggId = transaction.resultEggId
    if boardSourceSlot > 0 then
        local boardTier = self:_boardTierAtSlot(record, boardSourceSlot)
        if not boardTier then
            return false, "board_egg_unavailable"
        end
        if tierBefore == 0 then
            -- An empty (or destroyed) deployment position accepts any board egg unchanged.
            requiredTier = boardTier
            resultTier = boardTier
            resultEggId = self:_eggProgression(record)[boardTier]
            transaction.requiredEggId = resultEggId
        elseif boardTier ~= requiredTier then
            return false, "egg_tier_mismatch"
        end
    end
    if not resultEggId then
        return false, "maximum_egg_reached"
    end
    local source, reason = self:_buildHatchSource(record, resultEggId)
    if not source then
        return false, reason
    end
    if team.initialized ~= true and tierBefore ~= 0 then
        return false, "first_egg_required"
    end
    if self:_eggInventoryCount(record, requiredTier) <= 0 then
        return false, "egg_not_crafted"
    end
    local addedUnits = 0
    local wasInitialized = team.initialized == true
    local wasRebuild = team.needsEggRebuild == true
    team.eggAdvanceInProgress = true
    if
        not self:_isRecordActive(record)
        or record.terminal == true
        or (team.initialized == true) ~= wasInitialized
        or math.floor(tonumber(team.eggTier) or 0) ~= tierBefore
    then
        team.eggAdvanceInProgress = false
        return false, "hatcher_state_changed"
    end
    local placedOk, placedOrReason
    if not wasInitialized then
        placedOk, placedOrReason = self:_spawnInitialTeam(record, team, source, resultTier)
    else
        placedOk, placedOrReason = self:_expandTeamForEggTier(record, team, source, resultTier)
    end
    team.eggAdvanceInProgress = false
    if not placedOk then
        return false, placedOrReason
    end
    addedUnits = tonumber(placedOrReason) or 0
    record.eggInventory[requiredTier] = self:_eggInventoryCount(record, requiredTier) - 1
    record.eggsPlaced = (record.eggsPlaced or 0) + 1

    team.lastEggAdvanceAt = now
    team.eggTier = resultTier
    team.eggId = source.eggId
    team.eggName = source.eggName
    team.hatchPlayerData = source.hatchPlayerData
    self:_removeHatcherEggObjective(team)
    team.eggMaxHealth = self:_hatcherEggMaxHealth(record)
    team.eggHealth = team.eggMaxHealth
    team.eggDamageTaken = 0
    team.eggProductionLockedUntil = nil
    team.needsEggRebuild = false
    team.resetEggTier = nil
    team.resetEggId = nil
    team.resetEggName = nil
    team.resetHatchPlayerData = nil
    if wasRebuild then
        team.eggsRebuilt = (team.eggsRebuilt or 0) + 1
        record.hatcherEggsRebuilt = (record.hatcherEggsRebuilt or 0) + 1
    end
    record.maximumEggTier = math.max(record.maximumEggTier or 0, resultTier)
    self:_applyTeamEggTierModifiers(team, resultTier)
    for _, queued in ipairs(team.replacementQueue or {}) do
        queued.definition = nil
    end
    record.hatcherEggAdvances = (record.hatcherEggAdvances or 0) + 1
    self:_spawnHatcherEggObjective(record, team)
    for _, candidate in ipairs(record.teams or {}) do
        self:_publishTeamEggSource(candidate)
    end
    self:_syncTeamState(record, team)
    local automationTarget = math.max(
        1,
        math.floor(
            tonumber(((self._config.automation or {}).coin_runner or {}).target_hatchers)
                or #(record.teams or {})
        )
    )
    if
        record.coinRunnerRunning == true
        and record.coinRunnerFourHatcherAt == nil
        and self:_initializedHatcherCount(record) >= automationTarget
    then
        record.coinRunnerFourHatcherAt = os.clock()
        record.coinRunnerFourHatcherWave = record.waveIndex
    end
    self:_updateTutorial(record, now, true)
    local firstWaveStarted = false
    if
        record.waveIndex == 0
        and addedUnits > 0
        and record.tutorialActive ~= true
        and record.nextWaveAt == nil
    then
        local waveOk, waveReason = self:_spawnNextWave(record)
        if waveOk then
            firstWaveStarted = true
        else
            self:_setWorldState("WaveSpawnFailed", record)
            self:_log("Warn", "Merge Egg prototype first wave spawn failed", {
                player = player.Name,
                team = team.id,
                reason = waveReason,
            })
        end
    end
    self:_log("Info", "Merge Egg prototype crafted egg placed", {
        player = player.Name,
        team = team.id,
        tier = resultTier,
        egg = team.eggId,
        requiredTier = requiredTier,
        requiredEgg = transaction.requiredEggId,
        addedUnits = addedUnits,
        craftedInventoryRemaining = self:_eggInventoryCount(record, requiredTier),
        bulwarkDepth = bulwarkDepth,
        hatcherDistance = hatcherDistance,
        firstWaveStarted = firstWaveStarted,
        replacementQueueDepth = #(team.replacementQueue or {}),
    })
    local state = record.waveIndex == 0 and record.nextWaveAt ~= nil and "WaveIntermission"
        or self:_activeWaveState(record)
    self:_setWorldState(state, record)
    local eggMilestone = wasInitialized and self:_markEggTierMilestone(record, resultTier) or false
    local petSlotMilestone = wasInitialized and self:_markPetSlotMilestone(record, resultTier)
        or nil
    return true,
        {
            operation = wasInitialized and "upgraded" or "deployed",
            fromTier = tierBefore,
            toTier = resultTier,
            eggId = source.eggId,
            eggName = source.eggName,
            milestone = eggMilestone and "egg_created" or nil,
            petSlotMilestone = petSlotMilestone,
        }
end

-- Keep the prototype's existing packet/service seam stable while the UI and gameplay language use
-- "egg progression". Permanent upgrades are a separate future system.
function MergeEggPrototypeService:UpgradeHatcher(player, request)
    return self:AdvanceHatcherEgg(player, request)
end

-- Tear down leftover bay chrome that can survive a session end: board visuals, hatcher
-- teams, and the wave attributes the HUD reads. Passing no record must still zero CurrentWave
-- or Reset to Beginning leaves WAVE FOURTEEN on screen while only the wallet changes.
function MergeEggPrototypeService:_forceClearBay(world, player)
    if world then
        local board = self:_ensureMergeBoard(world)
        if board then
            board:SetAttribute("InventorySignature", nil)
            local eggs = board:FindFirstChild("Eggs")
            if eggs then
                eggs:ClearAllChildren()
            end
            local signs = board:FindFirstChild("EggSigns")
            if signs then
                signs:ClearAllChildren()
            end
            board:SetAttribute("OccupiedSlots", 0)
            board:SetAttribute("OverflowEggs", 0)
            world:SetAttribute("MergeBoardOccupiedSlots", 0)
            world:SetAttribute("MergeBoardOverflowEggs", 0)
        end
        self:_setWorldState("Idle", {
            world = world,
            player = player,
            waveIndex = 0,
            teams = {},
            eggInventory = {},
            tutorialActive = false,
        })
    end
    if player and self._npcPrincipalService and self._npcPrincipalService.Despawn then
        local layout = type(self._config.station_layout) == "table" and self._config.station_layout
            or {}
        local maximumTeams = math.max(1, math.floor(tonumber(layout.total_positions) or 9))
        for id = 1, maximumTeams do
            self._npcPrincipalService:Despawn(
                "merge_egg_hatcher_" .. tostring(player.UserId) .. "_" .. id,
                "merge_egg_beginning_reset"
            )
        end
    end
end

-- Admin Reset to Beginning must unwind ephemeral Merge state before the profile reset writes its
-- new wallet/inventory. This is intentionally broader than the gameplay checkpoint reset: it exits
-- the arena, restores parked durable pets, clears the isolated session, and removes every live
-- rebirth/combat attribute that could make the fresh profile look progressed. It deliberately
-- does not mutate durable profile data; AdminToolsService owns the one authoritative profile
-- transaction after this teardown completes.
function MergeEggPrototypeService:ResetForBeginning(player)
    self._combatTrainingReturns[player] = nil
    local enteringRecord = self._enteringRecordByPlayer[player]
    if enteringRecord then
        self:_cancelPendingEntry(enteringRecord, false)
    elseif self._enteringByPlayer[player] then
        self._enteringByPlayer[player] = nil
    end
    local activeRecord = self:_recordFor(player)
    local world = activeRecord and activeRecord.world
    -- Dedicated Merge has no Home spawn to stream. Yielding on RequestStreamAroundAsync
    -- here blocked the profile wipe and left the live wave/eggs on the bay.
    if activeRecord then
        self:_end(activeRecord, not self:_isDedicatedMergePlace(), false, true)
    end
    if self:_isDedicatedMergePlace() then
        self:_forceClearBay(world or self:_resolveWorld(), player)
    end
    if player then
        player:SetAttribute("InMergeEggPrototype", nil)
        player:SetAttribute("MergeEggRunId", nil)
        player:SetAttribute("MergeDefenseRebirths", 0)
        player:SetAttribute("MergeDefenseRebirthDamageMultiplier", 1)
        player:SetAttribute("MergeDefenseManagementDamageMultiplier", 1)
        player:SetAttribute("MergeDefenseAlliedDamageMultiplier", 1)
    end
    return true
end

-- Admin Reset to Beginning on the dedicated Merge place ends the session without
-- respawning, so CharacterAdded never re-enters. Re-run the same join path so the
-- player sits on the hatcher pad instead of wherever the Farm prologue would warp. The durable
-- beginning state has already been committed by AdminToolsService, so this
-- relaunch must not wipe it again. tutorial_completed is already false, so
-- _begin starts collect_setup and lays the opening piles.
function MergeEggPrototypeService:ResumeDedicatedEntry(player)
    if not self:_isDedicatedMergePlace() then
        return false, "not_merge_place"
    end
    if not (player and player.Parent) then
        return false, "player_unavailable"
    end
    local leftover = self:_recordFor(player)
    if leftover then
        self:_end(leftover, false, false, true)
    end
    self:_forceClearBay(self:_resolveWorld(), player)
    return self:_begin(player, nil, { ignoreCheckpoint = true })
end

function MergeEggPrototypeService:_reset(player)
    local record = self:_recordFor(player)
    if not record then
        return false, "not_active_player"
    end
    if record.hatching then
        return false, "hatch_in_progress"
    end
    if self:_canRestartCheckpoint(record) then
        local checkpointCfg = self._config.checkpoints or {}
        if
            tostring(checkpointCfg.gameplay_restore_mode or "retain_progress")
            == "retain_progress"
        then
            return self:_restartCheckpointKeepingProgress(record, "reset_prompt")
        end
        return self:_restoreCheckpoint(record, "reset_prompt")
    end
    self:_clearEncounter(record)
    if not self:_resetSessionCurrency(record) then
        return false, "currency_reset_failed"
    end
    self:_spawnOpeningCoinDrops(record)
    local armed, armReason = self:_hatch(player)
    if not armed then
        return false, armReason
    end
    self:_startTutorial(record)
    return true
end

-- Explicit deterministic test seam. Gameplay reset intentionally keeps live progress; balance
-- automation may call this old snapshot path to replay a known Wave 10/20 checkpoint exactly.
function MergeEggPrototypeService:RestoreCheckpointSnapshotForTest(player)
    local record = self:_recordFor(player)
    if not record then
        return false, "not_active_player"
    end
    return self:_restoreCheckpoint(record, "test_snapshot")
end

function MergeEggPrototypeService:_exit(player)
    local record = self:_recordFor(player)
    if not record then
        return false, "not_active_player"
    end
    if self:_isDedicatedMergePlace() then
        return self:_teleportToRole(player, "main")
    end
    self:_end(record, true, false)
    return true
end

function MergeEggPrototypeService:_resumeAfterCombatTraining(player, reason)
    local pending = player and self._combatTrainingReturns[player]
    if not pending then
        return
    end
    self._combatTrainingReturns[player] = nil
    task.spawn(function()
        local deadline = os.clock() + 10
        while
            player.Parent
            and (player:GetAttribute("InMission") ~= nil or player:GetAttribute("InCombatTutorial") == true)
            and os.clock() < deadline
        do
            RunService.Heartbeat:Wait()
        end
        if not player.Parent or self:_recordFor(player) then
            return
        end
        local data = self._dataService and self._dataService:GetData(player)
        local completed = data
            and type(data.CombatTutorial) == "table"
            and data.CombatTutorial.done == true
        if completed then
            -- Success keeps the real-pet mode used inside training. Going through Settings both
            -- persists Full and resolves the locked-Simple onboarding choice; the player may still
            -- choose Simple later. An incomplete exit skips this and normal eligibility resolution
            -- restores the pre-training mode (Simple for a fresh Wave-10 player).
            local switched = self._settingsService
                and self._settingsService.SetMergeDefenseMode
                and self._settingsService:SetMergeDefenseMode(player, "full")
            if switched ~= true then
                self:_log("Warn", "Combat Training completion could not retain Full pet mode", {
                    player = player.Name,
                    trigger = reason,
                    previousPetMode = pending.previousPetMode,
                })
            end
        end
        local began, beginReason = self:_begin(player, pending.bayId)
        if not began and beginReason == "bay_occupied" then
            began, beginReason = self:_begin(player)
        end
        if not began then
            self:_log("Warn", "Merge Egg session did not resume after Combat Training", {
                player = player.Name,
                requestedBay = pending.bayId,
                trigger = reason,
                reason = beginReason,
            })
        end
    end)
end

function MergeEggPrototypeService:_watchCombatTrainingReturn(player)
    player:GetAttributeChangedSignal("InMission"):Connect(function()
        if player:GetAttribute("InMission") == nil and self._combatTrainingReturns[player] then
            task.defer(function()
                self:_resumeAfterCombatTraining(player, "mission_closed")
            end)
        end
    end)
end

function MergeEggPrototypeService:_bindMergePlaceJoin()
    if not self:_isDedicatedMergePlace() then
        return
    end
    local function onCharacter(player)
        task.spawn(function()
            local character = player.Character
            if not (player.Parent and character) then
                return
            end
            if not character:WaitForChild("HumanoidRootPart", 10) then
                self:_log("Warn", "Merge place character had no root part", {
                    player = player.Name,
                })
                return
            end
            local dataDeadline = os.clock() + 30
            while
                player.Parent
                and self._dataService
                and not self._dataService:IsDataLoaded(player)
                and os.clock() < dataDeadline
            do
                RunService.Heartbeat:Wait()
            end
            if self._dataService and not self._dataService:IsDataLoaded(player) then
                self:_log("Warn", "Merge place profile was not ready before session entry", {
                    player = player.Name,
                })
                return
            end
            local began, reason = self:_begin(player)
            if not began and reason ~= "already_inside" then
                self:_log("Warn", "Dedicated Merge place could not start player session", {
                    player = player.Name,
                    placeId = game.PlaceId,
                    reason = reason,
                })
            end
        end)
    end
    local function onPlayer(player)
        if not self:_hasPreviewAccess(player) then
            self:_log("Warn", "Unauthorized player entered unreleased Merge place", {
                player = player.Name,
                userId = player.UserId,
            })
            task.defer(function()
                if not player.Parent then
                    return
                end
                local returned = self:_teleportToRole(player, "main")
                if not returned and player.Parent then
                    player:Kick("Coming Soon")
                end
            end)
            return
        end
        player.CharacterAdded:Connect(function()
            onCharacter(player)
        end)
        if player.Character then
            onCharacter(player)
        end
    end
    Players.PlayerAdded:Connect(onPlayer)
    for _, player in ipairs(Players:GetPlayers()) do
        onPlayer(player)
    end
end

function MergeEggPrototypeService:Start()
    if self._config.enabled == false then
        return
    end
    if self._dataService and self._dataService.RegisterBeforeProfileRelease then
        self._dataService:RegisterBeforeProfileRelease(function(player)
            local record = self:_recordFor(player)
            if record then
                -- This hook must not yield. Mutating the loaded profile here guarantees the final
                -- ProfileStore release includes the exact wallet/board/deployments even if the
                -- DataService PlayerRemoving connection runs before this service's connection.
                self:_persistPlaystate(record, "merge_defense_profile_release", false)
            end
        end)
    end
    local world = self:_resolveWorld()
    if world then
        self:_bindWorldControls(world)
        self:_setPortalVisible(nil, false)
        self:_setWorldState("Idle", nil)
    end
    if self._realm then
        self._realm:SetClaimHandler(function(player, bayId)
            self:_begin(player, bayId)
        end)
    end
    if not self:_isDedicatedMergePlace() then
        self:_bindRestrictedHallGate()
    else
        self:_bindPublicReturnGate()
    end
    self:_bindMergePlaceJoin()
    Signals.MergeEggPrototypeUpgrade.OnServerEvent:Connect(function(player, request)
        self:AdvanceHatcherEgg(player, request)
    end)
    Signals.MergeEggPrototypeBoardAction.OnServerEvent:Connect(function(player, request)
        local action = type(request) == "table" and tostring(request.action or "") or ""
        local recordBefore = self:_recordFor(player)
        local tutorialStepBefore = recordBefore
                and recordBefore.tutorialActive == true
                and recordBefore.tutorialStep
            or nil
        local ok, result = self:HandleBoardAction(player, request)
        local operation = type(result) == "table" and tostring(result.operation or "") or ""
        local tutorialEggUpgrade = ok == true
            and tutorialStepBefore == "upgrade_eggs"
            and (
                action == "merge_slots"
                or action == "upgrade_base"
                or (action == "deploy_to_hatcher" and operation == "upgraded")
            )
        Signals.MergeEggPrototypeBoardResult:FireClient(player, {
            ok = ok == true,
            action = action,
            value = ok == true and result or nil,
            reason = ok ~= true and tostring(result or "action_refused") or nil,
            tutorialEggUpgrade = tutorialEggUpgrade,
        })
    end)
    RunService.Heartbeat:Connect(function()
        self:_step()
    end)
    Players.PlayerAdded:Connect(function(player)
        self:_watchCombatTrainingReturn(player)
    end)
    for _, player in ipairs(Players:GetPlayers()) do
        self:_watchCombatTrainingReturn(player)
    end
    Players.PlayerRemoving:Connect(function(player)
        self._combatTrainingReturns[player] = nil
        local enteringRecord = self._enteringRecordByPlayer[player]
        if enteringRecord then
            self:_cancelPendingEntry(enteringRecord, true)
        elseif self._enteringByPlayer[player] then
            self._enteringByPlayer[player] = nil
            if self._realm then
                self._realm:Release(player)
            end
        end
        local activeRecord = self:_recordFor(player)
        if activeRecord then
            self:_end(activeRecord, false, true)
        end
    end)
end

return MergeEggPrototypeService
