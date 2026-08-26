--[[
    MergeEggPrototypeService — Studio-only Phase 5 vertical slice.

    One player enters through Home's otherwise-disabled Hall gate, is streamed to one authored
    strip under Workspace.Maps, and deploys four empty hatcher positions. Installing each captain's
    first Grass/Earth Egg rolls that hatcher's five-pet team; later egg tiers change its future
    replacements. Each independently addressed squad owns a disjoint share of the same escalating
    reward-free enemy waves, which emerge through a temporary portal and march toward one finish
    line. Reset makes the loop repeatable; Exit restores the player's runtime squad and transform.

    There is intentionally no tile-kit or mission-instance world generation here. The map is a
    persistent Studio-authored Model and this service owns only session routing and cleanup.
]]

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local BootReadiness = require(ReplicatedStorage.Shared.Boot.BootReadiness)
local Signals = require(ReplicatedStorage.Shared.Network.Signals)

local MergeEggPrototypeService = {}
MergeEggPrototypeService.__index = MergeEggPrototypeService

local HATCH_PROMPT_NAME = "MergeEggPrototypeHatchPrompt"
local RESET_PROMPT_NAME = "MergeEggPrototypeResetPrompt"
local EXIT_PROMPT_NAME = "MergeEggPrototypeExitPrompt"

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

local function characterRoot(player)
    local character = player and player.Character
    return character and character:FindFirstChild("HumanoidRootPart") or nil
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

local function cloneEnemyDef(source, config)
    local def = table.clone(source)
    def.attack = table.clone(source.attack or {})
    def.drop_table = {}
    def.display_name = "Prototype " .. tostring(source.display_name or config.id)
    def.hp = math.max(1, math.floor(tonumber(config.hp) or tonumber(source.hp) or 320))
    def.level = math.max(1, math.floor(tonumber(config.level) or 1))
    def.armor = math.max(0, tonumber(config.armor) or tonumber(source.armor) or 0)
    def.attack.damage = math.max(0, tonumber(config.damage) or tonumber(def.attack.damage) or 4)
    def.attack.cadence =
        math.max(0.25, tonumber(config.cadence) or tonumber(def.attack.cadence) or 2)
    def.attack.sundering = math.max(0, tonumber(config.sundering) or 0)
    return def
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
    self._config = (self._configLoader and self._configLoader:LoadConfig("merge_egg_prototype"))
        or require(ReplicatedStorage.Configs:WaitForChild("merge_egg_prototype"))
    self._enemiesConfig = (self._configLoader and self._configLoader:LoadConfig("enemies"))
        or require(ReplicatedStorage.Configs:WaitForChild("enemies"))
    self._petsConfig = (self._configLoader and self._configLoader:LoadConfig("pets"))
        or require(ReplicatedStorage.Configs:WaitForChild("pets"))
    self._active = nil
    self._entering = nil
    self._enteringRecord = nil
    self._world = nil
    self._gatePrompt = nil
end

function MergeEggPrototypeService:_portalVisual()
    local name = (self._config.world or {}).enemy_portal_visual or "EnemyPortalVisual"
    return self._world and self._world:FindFirstChild(tostring(name), true) or nil
end

function MergeEggPrototypeService:_setPortalVisible(record, visible)
    visible = visible == true
    if record then
        record.portalVisible = visible
    end
    local portal = self:_portalVisual()
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
    if self._world then
        self._world:SetAttribute("EnemyPortalVisible", visible)
    end
end

function MergeEggPrototypeService:_activeWaveState(record)
    return record and (record.pendingEnemySpawns or 0) > 0 and "WaveDeploying" or "WaveActive"
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
    local source, reason =
        self:_buildHatchSource(record, (teamCfg.egg_progression or {})[1] or "grass_egg")
    if not source then
        return false, reason
    end
    record.eggId = source.eggId
    record.eggName = source.eggName
    record.hatchPlayerData = source.hatchPlayerData
    return true
end

function MergeEggPrototypeService:_rollPrototypePet(record, source)
    source = source or record
    if not (record and source and source.eggId and source.hatchPlayerData) then
        return nil
    end
    local result = self._petsConfig.simulateHatch(source.eggId, source.hatchPlayerData)
    if not (result and result.pet) then
        return nil
    end
    return {
        pet = tostring(result.pet),
        variant = tostring(result.variant or "basic"),
        huge = result.huge == true,
    }
end

function MergeEggPrototypeService:_rollPrototypeSquad(record, count, source)
    local squad = {}
    for _ = 1, math.max(1, math.floor(tonumber(count) or 5)) do
        local definition = self:_rollPrototypePet(record, source)
        if not definition then
            return nil
        end
        squad[#squad + 1] = definition
    end
    return squad
end

function MergeEggPrototypeService:_eggProgression()
    local progression = (self._config.team or {}).egg_progression
    if type(progression) == "table" and #progression > 0 then
        return progression
    end
    return { "grass_egg" }
end

function MergeEggPrototypeService:_publishTeamEggSource(team)
    local folder = team and team.folder
    if not (folder and folder.Parent) then
        return
    end
    local progression = self:_eggProgression()
    local tier = math.clamp(math.floor(tonumber(team.eggTier) or 0), 0, #progression)
    local nextId = progression[tier + 1]
    local nextData = nextId
        and self._petsConfig
        and self._petsConfig.egg_sources
        and self._petsConfig.egg_sources[nextId]
    folder:SetAttribute("MergeEggSourceId", team.eggId)
    folder:SetAttribute("MergeEggSourceName", team.eggName)
    folder:SetAttribute("MergeEggSourceTier", tier)
    folder:SetAttribute("MergeEggCanUpgrade", nextId ~= nil)
    folder:SetAttribute("MergeEggNextSourceId", nextId)
    folder:SetAttribute("MergeEggNextSourceName", nextData and nextData.name or nil)
end

function MergeEggPrototypeService:_recordEggRoll(record, team, definition)
    local variant = tostring(definition.variant or "basic")
    record.eggRolls = (record.eggRolls or 0) + 1
    record.eggGoldenRolls = (record.eggGoldenRolls or 0) + (variant == "golden" and 1 or 0)
    record.eggRainbowRolls = (record.eggRainbowRolls or 0) + (variant == "rainbow" and 1 or 0)
    record.eggHugeRolls = (record.eggHugeRolls or 0) + (definition.huge == true and 1 or 0)
    if team then
        team.eggRolls = (team.eggRolls or 0) + 1
        team.eggGoldenRolls = (team.eggGoldenRolls or 0) + (variant == "golden" and 1 or 0)
        team.eggRainbowRolls = (team.eggRainbowRolls or 0) + (variant == "rainbow" and 1 or 0)
        team.eggHugeRolls = (team.eggHugeRolls or 0) + (definition.huge == true and 1 or 0)
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
end

function MergeEggPrototypeService:_spawnInitialTeam(record, team, source)
    if team.initialized == true then
        return true, 0
    end
    local count = math.max(
        1,
        math.floor(
            tonumber(team.expectedPets)
                or tonumber((self._config.team or {}).initial_hatch_count)
                or 5
        )
    )
    local squad = self:_rollPrototypeSquad(record, count, source)
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
                PrincipalLevel = tonumber((self._config.principal or {}).level) or 1,
            },
        })
    if spawned ~= count then
        for _, model in ipairs(models or {}) do
            model:Destroy()
        end
        return false, "unit_assets_missing"
    end

    team.config.squad = squad
    team.initialized = true
    for slot, model in ipairs(models) do
        team.units[#team.units + 1] = model
        record.units[#record.units + 1] = model
        self:_recordEggRoll(record, team, squad[slot])
        self:_publishTeamSlot(team, slot, squad[slot])
    end
    return true, spawned
end

function MergeEggPrototypeService:_log(level, message, data)
    if self._logger and self._logger[level] then
        self._logger[level](self._logger, message, data)
    end
end

function MergeEggPrototypeService:_resolveWorld()
    local cfg = self._config.world or {}
    local maps = Workspace:FindFirstChild(tostring(cfg.maps_root or "Maps"))
    local world = maps and maps:FindFirstChild(tostring(cfg.model_name or "MergeEggPrototype"))
    if world and world:IsA("Model") then
        self._world = world
        return world
    end
    self:_log("Warn", "Merge Egg prototype authored world is missing", {
        expected = "Workspace." .. tostring(cfg.maps_root or "Maps") .. "." .. tostring(
            cfg.model_name or "MergeEggPrototype"
        ),
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
    local world = self._world
    if not world then
        return
    end
    world:SetAttribute("PrototypeState", state)
    world:SetAttribute("CombatCadenceMultiplier", combatCadenceMultiplier(self._config))
    world:SetAttribute("ActivePlayer", record and record.player.Name or nil)
    world:SetAttribute("ActiveRunId", record and record.runId or nil)
    world:SetAttribute("ActiveEnemies", record and record.aliveEnemies or 0)
    world:SetAttribute("CurrentWave", record and record.waveIndex or 0)
    world:SetAttribute("WaveCount", #(self._config.waves or {}))
    world:SetAttribute("EnemiesDefeated", record and record.defeated or 0)
    world:SetAttribute("EnemiesEscaped", record and record.escaped or 0)
    world:SetAttribute("EnemiesAlerted", record and record.alerted or 0)
    world:SetAttribute("EnemiesBreachedBulwark", record and record.breached or 0)
    world:SetAttribute("PeakActiveEnemies", record and record.peakActiveEnemies or 0)
    world:SetAttribute("EnemyPortalVisible", record and record.portalVisible == true or false)
    world:SetAttribute("WaveEnemiesPending", record and record.pendingEnemySpawns or 0)
    world:SetAttribute("WaveAttackGroups", record and record.waveGroupCount or 0)
    world:SetAttribute("PrototypeEggId", record and record.eggId or nil)
    world:SetAttribute("PrototypeEggRolls", record and record.eggRolls or 0)
    world:SetAttribute("PrototypeGoldenRolls", record and record.eggGoldenRolls or 0)
    world:SetAttribute("PrototypeRainbowRolls", record and record.eggRainbowRolls or 0)
    world:SetAttribute("PrototypeHugeRolls", record and record.eggHugeRolls or 0)
    world:SetAttribute("HatcherUpgrades", record and record.hatcherUpgrades or 0)
    world:SetAttribute("PrototypeCoinsDropped", record and record.coinsDropped or 0)
    world:SetAttribute(
        "PrototypeMagnetRadius",
        record and record.player:GetAttribute("MergeEggMagnetRadius") or 0
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
        elseif team.state == "Defeated" then
            defeatedTeams += 1
        end
        activePets += team.activePets or 0
        defeatedPets += team.defeatedPets or 0
    end
    world:SetAttribute("ActiveTeamCount", activeTeams)
    world:SetAttribute("InitializedHatcherCount", initializedHatchers)
    world:SetAttribute("ReadyTeamCount", readyTeams)
    world:SetAttribute("EngagedTeamCount", engagedTeams)
    world:SetAttribute("ReinforcingTeamCount", reinforcingTeams)
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
    local worldState = self._world and self._world:GetAttribute("PrototypeState") or "ReadyToHatch"
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
        if pet:IsA("Model") then
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

    local state = "Ready"
    if team.initialized ~= true then
        state = "NoEgg"
    elseif record.encounterSpawned and active == 0 then
        state = #(team.replacementQueue or {}) > 0 and "Reinforcing" or "Defeated"
    elseif targeted > 0 then
        state = "Engaged"
    elseif (team.assignedAlive or 0) > 0 then
        state = (team.engaged == true or targeted > 0) and "Engaged" or "Deploying"
    elseif record.encounterSpawned and returned < active then
        state = "Returning"
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

function MergeEggPrototypeService:_spawnReplacement(record, team, queued, now)
    local squad = team.config.squad or {}
    local definition = queued.definition or self:_rollPrototypePet(record, team)
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
        PrincipalLevel = tonumber((self._config.principal or {}).level) or 1,
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
        if queued and now >= (team.nextReplacementAt or math.huge) then
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
    if self._active ~= record or record.terminal == true then
        return
    end
    record.terminal = true
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
    record.escaped += survivingEnemies
    record.aliveEnemies = 0
    for _, team in ipairs(record.teams or {}) do
        team.assignedAlive = 0
        team.engaged = false
        self:_syncTeamState(record, team)
    end
    record.player:SetAttribute("MergeEggWaveComplete", true)
    self:_setWorldState("DefenseOverrun", record)
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
    if self._active ~= record or record.terminal == true then
        return
    end
    record.terminal = true
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

function MergeEggPrototypeService:_unsealHallGate()
    local gateCfg = self._config.gate or {}
    local hook = Workspace:FindFirstChild(tostring(gateCfg.hook_name or "HallOfWorldsPortal"), true)
    if not (hook and hook:IsA("BasePart")) then
        self:_log("Warn", "Merge Egg prototype Hall gate hook is missing", {
            hook = gateCfg.hook_name,
        })
        return nil
    end

    -- ZoneService has already converted this exact hook into the disabled Hall's collision wall.
    -- Remove only those generated cap strips and make the hook an invisible prompt host.
    for _, child in ipairs(hook:GetChildren()) do
        if
            child:GetAttribute("HallEntryArchCap") == true
            or string.match(child.Name, "^HallEntryArchCap%d+$")
        then
            child:Destroy()
        end
    end
    local travelPrompt = hook:FindFirstChild("ZoneTravelPrompt", true)
    if travelPrompt and travelPrompt:IsA("ProximityPrompt") then
        travelPrompt:Destroy()
    end
    if CollectionService:HasTag(hook, "MissionDoor") then
        CollectionService:RemoveTag(hook, "MissionDoor")
    end
    hook:SetAttribute("HallEntryDisabled", nil)
    hook:SetAttribute("MissionId", nil)
    hook.Transparency = 1
    hook.CanCollide = false
    hook.CanTouch = false
    hook.CanQuery = true

    local title = hook.Parent and hook.Parent:FindFirstChild("HallOfWorldsGateTitle")
    if title then
        for _, descendant in ipairs(title:GetDescendants()) do
            if descendant:IsA("TextLabel") or descendant:IsA("TextButton") then
                descendant.Text = tostring(gateCfg.title or "MERGE AN EGG\nPROTOTYPE")
            end
        end
    end

    self._gatePrompt = self:_attachPrompt(
        hook,
        tostring(gateCfg.prompt_name or "MergeEggPrototypeEnterPrompt"),
        tostring(gateCfg.action_text or "Enter Prototype"),
        tostring(gateCfg.object_text or "Merge an Egg — Phase 5"),
        function(player)
            self:_begin(player)
        end
    )
    return hook
end

function MergeEggPrototypeService:_bindWorldControls(world)
    local cfg = self._config.world or {}
    self:_attachPrompt(
        findNamedPart(world, cfg.hatcher_control),
        HATCH_PROMPT_NAME,
        "Deploy Four Empty Hatchers",
        "Four Empty Egg Positions",
        function(player)
            self:_hatch(player)
        end
    )
    self:_attachPrompt(
        findNamedPart(world, cfg.reset_control),
        RESET_PROMPT_NAME,
        "Reset Encounter",
        "Merge an Egg — Phase 5",
        function(player)
            self:_reset(player)
        end
    )
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

function MergeEggPrototypeService:_canBegin(player)
    if not (player and player.Parent) then
        return false, "player_left"
    end
    if self._active or self._entering then
        local owner = self._active and self._active.player or self._entering
        return false, owner == player and "already_inside" or "prototype_occupied"
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
    if not record or self._enteringRecord ~= record then
        return
    end
    self._enteringRecord = nil
    if self._entering == record.player then
        self._entering = nil
    end
    if departing then
        if record.parked then
            record.parked:Destroy()
            record.parked = nil
        end
    else
        self:_restoreOwnedPets(record)
    end
end

function MergeEggPrototypeService:_clearEncounter(record)
    if not record then
        return
    end
    for _, enemy in ipairs(record.enemies or {}) do
        if enemy.model then
            self._enemyService:DespawnModel(enemy.model)
        end
    end
    record.enemies = {}
    record.aliveEnemies = 0
    record.hatching = false
    record.waveIndex = 0
    record.defeated = 0
    record.escaped = 0
    record.alerted = 0
    record.breached = 0
    record.peakActiveEnemies = 0
    record.firstPetLossWave = nil
    record.firstPetLossActiveEnemies = nil
    record.nextWaveAt = nil
    record.pendingWaveSpawns = {}
    record.pendingEnemySpawns = 0
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
    record.hatcherUpgrades = 0
    record.coinsDropped = 0
    self:_setPortalVisible(record, false)

    for _, team in ipairs(record.teams or {}) do
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
    self:_setWorldState("ReadyToHatch", record)
end

function MergeEggPrototypeService:_end(record, teleportHome, departing)
    if not record or self._active ~= record then
        return
    end
    self._active = nil
    disconnect(record.characterRemoving)
    self:_clearEncounter(record)
    record.player:SetAttribute("CombatAssistTarget", record.assistTarget)
    record.player:SetAttribute("CombatAssistUntil", record.assistUntil)
    record.player:SetAttribute("InMergeEggPrototype", nil)
    record.player:SetAttribute("MergeEggRunId", nil)
    record.player:SetAttribute("MergeEggMagnetRadius", nil)

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
        end
    end
    self:_setWorldState("Idle", nil)
    self:_log("Info", "Merge Egg prototype session ended", {
        player = record.player.Name,
        departing = departing == true,
    })
end

function MergeEggPrototypeService:_begin(player)
    local ok, reason = self:_canBegin(player)
    if not ok then
        self:_log("Warn", "Merge Egg prototype entry refused", {
            player = player and player.Name,
            reason = reason,
        })
        return false, reason
    end
    local world = self._world or self:_resolveWorld()
    local spawn = findNamedPart(world, (self._config.world or {}).player_spawn)
    if not (world and spawn and characterRoot(player)) then
        return false, "world_or_character_unavailable"
    end

    self._entering = player
    local modelsReady = BootReadiness.await("models_ready", 20)
    if self._entering ~= player then
        return false, "entry_cancelled"
    end
    if not modelsReady then
        self:_log("Warn", "Merge Egg prototype entered before pet models were ready")
    end

    local character = player.Character
    if not (player.Parent and character and characterRoot(player)) then
        self._entering = nil
        return false, "character_unavailable"
    end

    local objectiveEggsStarting =
        math.max(1, math.floor(tonumber((self._config.objective or {}).starting_eggs) or 5))
    local record = {
        player = player,
        runId = HttpService:GenerateGUID(false),
        returnCFrame = character:GetPivot(),
        assistTarget = player:GetAttribute("CombatAssistTarget"),
        assistUntil = player:GetAttribute("CombatAssistUntil"),
        enemies = {},
        enemyByTargetId = {},
        units = {},
        teams = {},
        teamById = {},
        aliveEnemies = 0,
        waveIndex = 0,
        defeated = 0,
        escaped = 0,
        alerted = 0,
        breached = 0,
        peakActiveEnemies = 0,
        firstPetLossWave = nil,
        firstPetLossActiveEnemies = nil,
        nextWaveAt = nil,
        pendingWaveSpawns = {},
        pendingEnemySpawns = 0,
        waveGroupCount = 0,
        nextEnemySpawnAt = nil,
        portalVisible = false,
        resolvedTargets = {},
        random = Random.new(),
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
        hatcherUpgrades = 0,
        coinsDropped = 0,
        terminal = false,
    }
    if not self:_parkOwnedPets(record) then
        self._entering = nil
        return false, "pet_folder_unavailable"
    end
    self._enteringRecord = record

    local target = spawn.CFrame * CFrame.new(0, spawn.Size.Y * 0.5 + 3, 0)
    pcall(function()
        player:RequestStreamAroundAsync(target.Position, tonumber(self._config.stream_timeout) or 8)
    end)
    if
        self._enteringRecord ~= record
        or self._entering ~= player
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

    -- Commit the session only after streaming has returned and the character can be moved. There
    -- must be no yield between the visible pivot and the replicated inside state: otherwise the
    -- Hall gate can reject a second attempt while the player is still standing in Home.
    character:PivotTo(target)
    self._enteringRecord = nil
    self._entering = nil
    self._active = record
    local magnetCfg = ((self._config.rewards or {}).magnet or {})
    player:SetAttribute("MergeEggMagnetRadius", math.max(0, tonumber(magnetCfg.base_radius) or 10))
    player:SetAttribute("InMergeEggPrototype", true)
    player:SetAttribute("MergeEggRunId", record.runId)
    record.characterRemoving = player.CharacterRemoving:Connect(function()
        self:_end(record, false, false)
    end)
    self:_setWorldState("ReadyToHatch", record)
    self:_log("Info", "Merge Egg prototype session began", {
        player = player.Name,
        runId = record.runId,
    })
    return true
end

function MergeEggPrototypeService:_movementLeash(recovery)
    local bounds = (self._config.world or {}).bounds or {}
    return {
        shapes = {
            {
                kind = "box",
                cx = tonumber(bounds.center_x) or -16000,
                cz = tonumber(bounds.center_z) or 0,
                halfX = math.max(4, tonumber(bounds.half_x) or 46),
                halfZ = math.max(4, tonumber(bounds.half_z) or 296),
            },
        },
        inset = math.max(0, tonumber(bounds.inset) or 3),
        recovery = recovery,
    }
end

function MergeEggPrototypeService:_resolveEnemy(record, outcome, targetId)
    if self._active ~= record or targetId == nil or record.resolvedTargets[targetId] then
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
    if
        (self._config.endurance or {}).stop_when_all_teams_defeated == true
        and self:_allTeamsDefeated(record)
    then
        self:_finishDefenseOverrun(record)
        return
    end
    local waves = self._config.waves or {}
    local waveCount = #waves
    if record.waveIndex < waveCount then
        local resolvedWave = waves[record.waveIndex] or {}
        local waveGap =
            math.max(0, tonumber(resolvedWave.gap_after) or tonumber(self._config.wave_gap) or 2)
        record.nextWaveAt = os.clock() + waveGap
        self:_setWorldState("WaveIntermission", record)
        self:_log("Info", "Merge Egg prototype wave resolved", {
            player = record.player.Name,
            wave = record.waveIndex,
            nextWaveIn = waveGap,
            defeated = record.defeated,
            escaped = record.escaped,
        })
        return
    end

    record.nextWaveAt = nil
    record.terminal = true
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
    if self._active ~= record or not (defeat and typeof(defeat.position) == "Vector3") then
        return false
    end
    local model = defeat.model
    local amount =
        math.max(0, math.floor(tonumber(model and model:GetAttribute("MergeEggCoinReward")) or 0))
    if amount <= 0 then
        return false
    end
    local rewardCfg = self._config.rewards or {}
    local magnetCfg = rewardCfg.magnet or {}
    local currency = tostring(rewardCfg.currency or "hall_coins")
    local carried = false
    if self._dropService and self._dropService.SpawnCoinDrop then
        local ok, result = pcall(function()
            return self._dropService:SpawnCoinDrop(
                record.player,
                currency,
                amount,
                defeat.position,
                {
                    baseCollectRadius = math.max(0, tonumber(magnetCfg.base_radius) or 10),
                    collectRadiusAttribute = "MergeEggMagnetRadius",
                    usePlayerModifiers = magnetCfg.use_player_modifiers == true,
                    source = "merge_egg_prototype",
                }
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

function MergeEggPrototypeService:_onEnemyDefeated(record, defeat)
    self:_dropEnemyCoins(record, defeat)
    self:_resolveEnemy(record, "defeated", defeat and defeat.targetId)
end

function MergeEggPrototypeService:_onEnemyReachedFinish(record, arrival)
    if self._active ~= record or not arrival then
        return
    end
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
        def = cloneEnemyDef(spec.enemyDef, spec.spawnCfg),
        position = position,
        home = position,
        movementLeash = self:_movementLeash(position),
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
    if self._active ~= record then
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
    local rewardCfg = self._config.rewards or {}
    model:SetAttribute(
        "MergeEggCoinReward",
        spec.compositionRole == "tank"
                and math.max(0, math.floor(tonumber(rewardCfg.tank_amount) or 30))
            or math.max(0, math.floor(tonumber(rewardCfg.trash_amount) or 8))
    )
    result.teamId = team.id
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

function MergeEggPrototypeService:_spawnNextWave(record)
    if record.terminal == true then
        return false, "encounter_terminal"
    end
    local cfg = self._config.enemy or {}
    local enemyDefs = self._enemiesConfig.enemies or {}
    local tankCfg = type(cfg.tank) == "table" and cfg.tank or nil
    if not enemyDefs[cfg.id] then
        return false, "enemy_config_missing"
    end
    if tankCfg and not enemyDefs[tankCfg.id] then
        return false, "enemy_tank_config_missing"
    end
    local waveIndex = record.waveIndex + 1
    local wave = (self._config.waves or {})[waveIndex]
    if not wave then
        return false, "wave_config_missing"
    end
    local worldCfg = self._config.world or {}
    local spawnArea = findNamedPart(self._world, worldCfg.enemy_spawn_area)
    local finishLine = findNamedPart(self._world, worldCfg.enemy_finish_line)
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

    local pending = {}
    local authoredGroups = type(wave.groups) == "table" and wave.groups or nil
    if authoredGroups and #authoredGroups > 0 then
        for groupIndex, group in ipairs(authoredGroups) do
            local team = assignmentTeams[((groupIndex - 1) % #assignmentTeams) + 1]
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
                local spawnCfg = (isTank and tankCfg) or cfg
                local enemyId = tostring(spawnCfg.id or cfg.id)
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
                    spawnCfg = spawnCfg,
                    enemyId = enemyId,
                    enemyDef = enemyDef,
                    spawnArea = spawnArea,
                    finishLine = finishLine,
                }
            end
        end
    else
        local count = math.max(1, math.floor(tonumber(wave.count) or 1))
        for index = 1, count do
            local teamIndex = ((index - 1) % #assignmentTeams) + 1
            local teamOrdinal = math.floor((index - 1) / #assignmentTeams) + 1
            local team = assignmentTeams[teamIndex]
            local isTank = teamOrdinal == 1 and tankCfg ~= nil
            local spawnCfg = (isTank and tankCfg) or cfg
            local enemyId = tostring(spawnCfg.id or cfg.id)
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
                spawnCfg = spawnCfg,
                enemyId = enemyId,
                enemyDef = enemyDef,
                spawnArea = spawnArea,
                finishLine = finishLine,
            }
        end
    end
    if #pending ~= math.max(1, math.floor(tonumber(wave.count) or 1)) then
        return false, "wave_group_count_mismatch"
    end

    record.waveIndex = waveIndex
    -- AreaMusicController treats a changed cue as a request to rotate combat music without
    -- dropping combat state. Including the run id guarantees Wave 1 changes on every new session.
    record.player:SetAttribute("CombatMusicCue", record.runId .. ":wave:" .. waveIndex)
    record.nextWaveAt = nil
    record.aliveEnemies = 0
    record.pendingWaveSpawns = pending
    record.pendingEnemySpawns = #pending
    record.waveGroupCount = authoredGroups and #authoredGroups
        or math.min(#assignmentTeams, #pending)
    record.nextEnemySpawnAt = 0
    for _, team in ipairs(record.teams or {}) do
        team.assignedAlive = 0
        team.engaged = false
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

function MergeEggPrototypeService:_alertTeamsToBulwarkTarget(record, enemy)
    local reserveTeams = 0
    local alertedPets = 0
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
    return reserveTeams, alertedPets
end

function MergeEggPrototypeService:_openBulwarkTarget(record, enemy, now)
    local model = enemy and enemy.model
    if
        self._active ~= record
        or not (model and model.Parent)
        or model:GetAttribute("MergeEggBulwarkBreached") == true
    then
        return
    end

    model:SetAttribute("MergeEggBulwarkBreached", true)
    model:SetAttribute("CombatTargetOpen", true)
    record.breached += 1

    now = tonumber(now) or os.clock()
    local reserveTeams, alertedPets = self:_alertTeamsToBulwarkTarget(record, enemy)
    local reengageSeconds =
        math.max(0.25, tonumber((self._config.enemy or {}).bulwark_reengage_seconds) or 0.5)
    model:SetAttribute("MergeEggReserveTeamCount", reserveTeams)
    model:SetAttribute("MergeEggReserveAlertedPets", alertedPets)
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
    })
end

function MergeEggPrototypeService:_sustainBulwarkTarget(record, enemy, now)
    local model = enemy and enemy.model
    if
        self._active ~= record
        or not (model and model.Parent)
        or model:GetAttribute("MergeEggBulwarkBreached") ~= true
        or now < (tonumber(model:GetAttribute("MergeEggNextBulwarkAlertAt")) or 0)
    then
        return
    end

    local reengageSeconds =
        math.max(0.25, tonumber((self._config.enemy or {}).bulwark_reengage_seconds) or 0.5)
    local reserveTeams, alertedPets = self:_alertTeamsToBulwarkTarget(record, enemy)
    model:SetAttribute("MergeEggReserveTeamCount", reserveTeams)
    model:SetAttribute("MergeEggReserveAlertedPets", alertedPets)
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
        self._world,
        (self._config.world or {}).enemy_finish_line or "EnemyFinishLine"
    )
    if not finishLine then
        return
    end
    local bulwarkLine =
        findNamedPart(self._world, (self._config.world or {}).bulwark_line or "BulwarkLine")
    local towardFinish = bulwarkLine
            and Vector3.new(
                finishLine.Position.X - bulwarkLine.Position.X,
                0,
                finishLine.Position.Z - bulwarkLine.Position.Z
            )
        or Vector3.zero
    local alertDistance = math.max(1, tonumber(cfg.engagement_distance) or 260)
    local alertThreat = math.max(1, tonumber(cfg.engagement_threat) or 250)
    local reengageSeconds = math.max(0.25, tonumber(cfg.reengage_seconds) or 1)
    local now = os.clock()
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
            if
                bulwarkLine
                and towardFinish.Magnitude > 0
                and model:GetAttribute("MergeEggBulwarkBreached") ~= true
            then
                local direction = towardFinish.Unit
                local pivotPosition = model:GetPivot().Position
                local movementPosition = typeof(position) == "Vector3" and position or pivotPosition
                local leadingPosition, boundsExtent =
                    leadingBoundsPoint(model, movementPosition, direction)
                leadingPosition = leadingPosition or movementPosition
                local fromBulwark = Vector3.new(
                    leadingPosition.X - bulwarkLine.Position.X,
                    0,
                    leadingPosition.Z - bulwarkLine.Position.Z
                )
                local leadingDistance = fromBulwark:Dot(direction)
                local pivotDistance = Vector3.new(
                    pivotPosition.X - bulwarkLine.Position.X,
                    0,
                    pivotPosition.Z - bulwarkLine.Position.Z
                ):Dot(direction)
                local movementDistance = Vector3.new(
                    movementPosition.X - bulwarkLine.Position.X,
                    0,
                    movementPosition.Z - bulwarkLine.Position.Z
                ):Dot(direction)
                model:SetAttribute("MergeEggBulwarkLeadingDistance", leadingDistance)
                model:SetAttribute("MergeEggBulwarkMovementDistance", movementDistance)
                model:SetAttribute("MergeEggBulwarkPivotDistance", pivotDistance)
                model:SetAttribute("MergeEggBulwarkBoundsExtent", boundsExtent)
                local contactPadding = math.max(0, tonumber(cfg.bulwark_contact_padding) or 1)
                if leadingDistance + contactPadding >= 0 then
                    self:_openBulwarkTarget(record, enemy, now)
                end
            end
            self:_sustainBulwarkTarget(record, enemy, now)
            self:_traceBulwarkAggro(record, enemy, now)
        end
    end
end

function MergeEggPrototypeService:_step()
    local record = self._active
    local now = os.clock()
    if record and record.encounterSpawned and record.terminal ~= true then
        local spawnOk = self:_processWaveSpawns(record, now)
        if not spawnOk then
            return
        end
        self:_alertApproachingEnemies(record)
        if now >= (record.nextTeamSyncAt or 0) then
            record.nextTeamSyncAt = now + 0.1
            self:_syncAllTeams(record)
            self:_processReplacementQueues(record, now)
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
    local ok, reason = self:_spawnNextWave(record)
    if not ok and self._active == record then
        record.nextWaveAt = nil
        self:_setWorldState("WaveSpawnFailed", record)
        self:_log("Warn", "Merge Egg prototype wave spawn failed", {
            player = record.player.Name,
            reason = reason,
        })
    end
end

function MergeEggPrototypeService:_hatch(player)
    local record = self._active
    if not record or record.player ~= player then
        return false, "not_active_player"
    end
    if record.encounterSpawned then
        return false, "reset_required"
    end
    if record.hatching then
        return false, "hatch_in_progress"
    end
    local spawn = findNamedPart(self._world, (self._config.world or {}).hatcher_spawn)
    local principal = self._config.principal
    local teamConfigs = self._config.teams or {}
    if not (spawn and type(principal) == "table" and #teamConfigs == 4) then
        return false, "hatcher_unavailable"
    end

    record.hatching = true
    record.terminal = false
    local hatchCount =
        math.max(1, math.floor(tonumber((self._config.team or {}).initial_hatch_count) or 5))
    local progression = self:_eggProgression()
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
        definition.name = tostring(teamCfg.principal_name or ("Merge Hatcher Team " .. id))
        definition.display_name =
            tostring(teamCfg.principal_display_name or ("Hatcher Captain " .. id))
        definition.squad = {}
        local expected = hatchCount
        local runtimeTeamConfig = table.clone(teamCfg)
        runtimeTeamConfig.squad = {}
        local targetGroup = record.runId .. ":team:" .. id
        local offset = teamCfg.spawn_offset or {}
        local spawnCFrame = spawn.CFrame
            * CFrame.new(tonumber(offset.x) or 0, 0, tonumber(offset.z) or 0)
        local principalOk, info = self._npcPrincipalService:SpawnStationary(
            player,
            "merge_egg_hatcher_" .. id,
            spawnCFrame,
            {
                definition = definition,
                folderAttributes = {
                    MergeEggPrototypeTeam = true,
                    MergeEggOwnerUserId = player.UserId,
                    MergeEggRunId = record.runId,
                    MergeEggTeamId = id,
                    MergeEggTeamDisplayName = tostring(teamCfg.display_name or "NPC Team 1"),
                    MergeEggTeamState = "NoEgg",
                    MergeEggExpectedPets = expected,
                    MergeEggSourceTier = 0,
                    MergeEggCanUpgrade = true,
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
                    EphemeralDownPolicy = "destroy",
                },
            }
        )
        if not principalOk or type(info) ~= "table" then
            self:_clearEncounter(record)
            return false, tostring(info or "principal_spawn_failed")
        end
        if self._active ~= record then
            self._npcPrincipalService:Despawn(info.name, "merge_egg_session_ended")
            return false, "session_ended"
        end
        local team = {
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
            replacementQueue = {},
            pendingReplacementSlots = {},
            nextReplacementAt = nil,
            replacementsQueued = 0,
            replacementsHatched = 0,
            eggRolls = 0,
            eggGoldenRolls = 0,
            eggRainbowRolls = 0,
            eggHugeRolls = 0,
            eggTier = 0,
            eggId = nil,
            eggName = nil,
            hatchPlayerData = nil,
            lastUpgradeAt = nil,
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
    if self._petFollowService and self._petFollowService.ReleaseMiningTargets then
        self._petFollowService:ReleaseMiningTargets(player)
    end

    record.encounterSpawned = true
    record.hatching = false
    self:_syncAllTeams(record)
    self:_setPortalVisible(record, false)
    self:_setWorldState("AwaitingFirstEgg", record)
    self:_log("Info", "Merge Egg prototype setup started", {
        player = player.Name,
        egg = "none",
        teams = #record.teams,
        units = totalUnits,
        golden = record.eggGoldenRolls,
        rainbow = record.eggRainbowRolls,
        huge = record.eggHugeRolls,
        pendingEnemies = record.pendingEnemySpawns,
        waves = #(self._config.waves or {}),
    })
    return true
end

function MergeEggPrototypeService:UpgradeHatcher(player, request)
    if not RunService:IsStudio() then
        return false, "studio_only"
    end
    local record = self._active
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
    local now = os.clock()
    if team.lastUpgradeAt and now - team.lastUpgradeAt < 0.25 then
        return false, "upgrade_throttled"
    end
    local progression = self:_eggProgression()
    local nextTier = math.floor(tonumber(team.eggTier) or 0) + 1
    local nextEggId = progression[nextTier]
    if not nextEggId then
        return false, "maximum_egg_reached"
    end
    local source, reason = self:_buildHatchSource(record, nextEggId)
    if not source then
        return false, reason
    end

    local initialUnits = 0
    if team.initialized ~= true then
        if nextTier ~= 1 then
            return false, "first_egg_required"
        end
        local spawnedOk, spawnedOrReason = self:_spawnInitialTeam(record, team, source)
        if not spawnedOk then
            return false, spawnedOrReason
        end
        initialUnits = tonumber(spawnedOrReason) or 0
    end

    team.lastUpgradeAt = now
    team.eggTier = nextTier
    team.eggId = source.eggId
    team.eggName = source.eggName
    team.hatchPlayerData = source.hatchPlayerData
    for _, queued in ipairs(team.replacementQueue or {}) do
        queued.definition = nil
    end
    record.hatcherUpgrades = (record.hatcherUpgrades or 0) + 1
    self:_publishTeamEggSource(team)
    self:_syncTeamState(record, team)
    local firstWaveStarted = false
    if record.waveIndex == 0 and initialUnits > 0 then
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
    self:_log("Info", "Merge Egg prototype hatcher upgraded", {
        player = player.Name,
        team = team.id,
        tier = nextTier,
        egg = team.eggId,
        initialUnits = initialUnits,
        firstWaveStarted = firstWaveStarted,
        replacementQueueDepth = #(team.replacementQueue or {}),
    })
    return true
end

function MergeEggPrototypeService:_reset(player)
    local record = self._active
    if not record or record.player ~= player then
        return false, "not_active_player"
    end
    if record.hatching then
        return false, "hatch_in_progress"
    end
    self:_clearEncounter(record)
    return true
end

function MergeEggPrototypeService:_exit(player)
    local record = self._active
    if not record or record.player ~= player then
        return false, "not_active_player"
    end
    self:_end(record, true, false)
    return true
end

function MergeEggPrototypeService:Start()
    if self._config.enabled == false then
        return
    end
    local world = self:_resolveWorld()
    if world then
        self:_bindWorldControls(world)
        self:_setPortalVisible(nil, false)
        self:_setWorldState("Idle", nil)
    end
    self:_unsealHallGate()
    Signals.MergeEggPrototypeUpgrade.OnServerEvent:Connect(function(player, request)
        self:UpgradeHatcher(player, request)
    end)
    RunService.Heartbeat:Connect(function()
        self:_step()
    end)
    Players.PlayerRemoving:Connect(function(player)
        if self._enteringRecord and self._enteringRecord.player == player then
            self:_cancelPendingEntry(self._enteringRecord, true)
        elseif self._entering == player then
            self._entering = nil
        end
        if self._active and self._active.player == player then
            self:_end(self._active, false, true)
        end
    end)
end

return MergeEggPrototypeService
