--[[
    MergeEggPrototypeService — Studio-only Phase 3 vertical slice.

    One player enters through Home's otherwise-disabled Hall gate, is streamed to one authored
    strip under Workspace.Maps, and hatches four stationary NPC principals with five manifested
    Wayfinder pets apiece. Each independently addressed squad owns a disjoint share of the same
    escalating reward-free enemy waves marching toward one finish line. Reset makes the loop
    repeatable; Exit restores the player's runtime squad and exact entry transform.

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

function MergeEggPrototypeService:Init()
    self._logger = self._modules and self._modules.Logger
    self._configLoader = self._modules and self._modules.ConfigLoader
    self._npcPrincipalService = self._modules and self._modules.NpcPrincipalService
    self._enemyService = self._modules and self._modules.EnemyService
    self._petFollowService = self._modules and self._modules.PetFollowService
    self._config = (self._configLoader and self._configLoader:LoadConfig("merge_egg_prototype"))
        or require(ReplicatedStorage.Configs:WaitForChild("merge_egg_prototype"))
    self._enemiesConfig = (self._configLoader and self._configLoader:LoadConfig("enemies"))
        or require(ReplicatedStorage.Configs:WaitForChild("enemies"))
    self._active = nil
    self._entering = nil
    self._world = nil
    self._gatePrompt = nil
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
    world:SetAttribute("FirstPetLossWave", record and record.firstPetLossWave or nil)
    world:SetAttribute(
        "FirstPetLossActiveEnemies",
        record and record.firstPetLossActiveEnemies or nil
    )
    local activeTeams = 0
    local readyTeams = 0
    local engagedTeams = 0
    local defeatedTeams = 0
    local activePets = 0
    local defeatedPets = 0
    for _, team in ipairs(record and record.teams or {}) do
        if team.folder and team.folder.Parent then
            activeTeams += 1
        end
        if team.state == "Ready" then
            readyTeams += 1
        elseif team.state == "Engaged" then
            engagedTeams += 1
        elseif team.state == "Defeated" then
            defeatedTeams += 1
        end
        activePets += team.activePets or 0
        defeatedPets += team.defeatedPets or 0
    end
    world:SetAttribute("ActiveTeamCount", activeTeams)
    world:SetAttribute("ReadyTeamCount", readyTeams)
    world:SetAttribute("EngagedTeamCount", engagedTeams)
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

function MergeEggPrototypeService:_syncTeamState(record, team)
    local folder = team and team.folder
    if not (folder and folder.Parent) then
        return
    end
    local active = 0
    local targeted = 0
    local returned = 0
    local anchorRoot = team.principalModel
        and team.principalModel:FindFirstChild("HumanoidRootPart")
    local anchorPosition = anchorRoot and anchorRoot.Position
    local readyDistance =
        math.max(1, tonumber((self._config.team or {}).return_ready_distance) or 20)

    for _, pet in ipairs(folder:GetChildren()) do
        if pet:IsA("Model") then
            active += 1
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

    local expected = #(team.config.squad or self._config.squad or {})
    team.activePets = active
    team.defeatedPets = math.max(0, expected - active)
    team.peakAssignedEnemies = math.max(team.peakAssignedEnemies or 0, team.assignedAlive or 0)
    if record.encounterSpawned and team.defeatedPets > 0 and team.firstLossWave == nil then
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

    local state = "Ready"
    if record.encounterSpawned and active == 0 then
        state = "Defeated"
    elseif targeted > 0 then
        state = "Engaged"
    elseif (team.assignedAlive or 0) > 0 then
        state = (team.engaged == true or targeted > 0) and "Engaged" or "Deploying"
    elseif record.encounterSpawned and returned < active then
        state = "Returning"
    end
    self:_setTeamState(record, team, state)
end

function MergeEggPrototypeService:_syncAllTeams(record)
    for _, team in ipairs(record and record.teams or {}) do
        self:_syncTeamState(record, team)
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
    if self._active ~= record then
        return
    end
    record.nextWaveAt = nil
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
        tostring(gateCfg.object_text or "Merge an Egg — Phase 3"),
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
        "Deploy Four NPC Teams",
        "Phase 3 Test Egg",
        function(player)
            self:_hatch(player)
        end
    )
    self:_attachPrompt(
        findNamedPart(world, cfg.reset_control),
        RESET_PROMPT_NAME,
        "Reset Encounter",
        "Merge an Egg — Phase 3",
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
    record.resolvedTargets = {}
    record.enemyByTargetId = {}
    record.nextTeamSyncAt = nil

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
    self._entering = nil
    if not modelsReady then
        self:_log("Warn", "Merge Egg prototype entered before pet models were ready")
    end

    local character = player.Character
    if not (player.Parent and character and characterRoot(player)) then
        return false, "character_unavailable"
    end

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
        resolvedTargets = {},
        random = Random.new(),
        encounterSpawned = false,
        nextTeamSyncAt = 0,
    }
    if not self:_parkOwnedPets(record) then
        return false, "pet_folder_unavailable"
    end
    self._active = record
    player:SetAttribute("InMergeEggPrototype", true)
    player:SetAttribute("MergeEggRunId", record.runId)
    record.characterRemoving = player.CharacterRemoving:Connect(function()
        self:_end(record, false, false)
    end)
    self:_setWorldState("ReadyToHatch", record)

    local target = spawn.CFrame * CFrame.new(0, spawn.Size.Y * 0.5 + 3, 0)
    pcall(function()
        player:RequestStreamAroundAsync(target.Position, tonumber(self._config.stream_timeout) or 8)
    end)
    if self._active ~= record or not player.Parent then
        return false, "left_during_stream"
    end
    local character = player.Character
    if not (character and characterRoot(player)) then
        self:_end(record, false, false)
        return false, "character_unavailable"
    end
    character:PivotTo(target)
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
    else
        record.defeated += 1
    end

    if record.aliveEnemies > 0 then
        self:_setWorldState("WaveActive", record)
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
    local waveCount = #(self._config.waves or {})
    if record.waveIndex < waveCount then
        record.nextWaveAt = os.clock() + math.max(0, tonumber(self._config.wave_gap) or 2)
        self:_setWorldState("WaveIntermission", record)
        self:_log("Info", "Merge Egg prototype wave resolved", {
            player = record.player.Name,
            wave = record.waveIndex,
            defeated = record.defeated,
            escaped = record.escaped,
        })
        return
    end

    record.nextWaveAt = nil
    record.player:SetAttribute("MergeEggWaveComplete", true)
    self:_setWorldState("EncounterComplete", record)
    self:_log("Info", "Merge Egg prototype encounter complete", {
        player = record.player.Name,
        waves = record.waveIndex,
        defeated = record.defeated,
        escaped = record.escaped,
    })
end

function MergeEggPrototypeService:_onEnemyDefeated(record, defeat)
    self:_resolveEnemy(record, "defeated", defeat and defeat.targetId)
end

function MergeEggPrototypeService:_onEnemyReachedFinish(record, arrival)
    if self._active ~= record or not arrival then
        return
    end
    self._enemyService:DespawnModel(arrival.model)
    self:_resolveEnemy(record, "escaped", arrival.targetId)
end

function MergeEggPrototypeService:_spawnNextWave(record)
    local cfg = self._config.enemy or {}
    local enemyDefs = self._enemiesConfig.enemies or {}
    local base = enemyDefs[cfg.id]
    local tankCfg = type(cfg.tank) == "table" and cfg.tank or nil
    if not base then
        return false, "enemy_config_missing"
    end
    if tankCfg and not enemyDefs[tankCfg.id] then
        return false, "enemy_tank_config_missing"
    end
    local waves = self._config.waves or {}
    local waveIndex = record.waveIndex + 1
    local wave = waves[waveIndex]
    if not wave then
        return false, "wave_config_missing"
    end
    local worldCfg = self._config.world or {}
    local spawnArea = findNamedPart(self._world, worldCfg.enemy_spawn_area)
    local finishLine = findNamedPart(self._world, worldCfg.enemy_finish_line)
    if not (spawnArea and finishLine) then
        return false, "enemy_march_anchor_missing"
    end

    record.waveIndex = waveIndex
    record.nextWaveAt = nil
    record.aliveEnemies = 0
    for _, team in ipairs(record.teams or {}) do
        team.assignedAlive = 0
        team.engaged = false
    end
    local count = math.max(1, math.floor(tonumber(wave.count) or 1))
    if #record.teams == 0 then
        return false, "defense_team_missing"
    end
    local spawnInset = math.max(0, tonumber(cfg.spawn_inset) or 5)
    local finishInset = math.max(0, tonumber(cfg.finish_inset) or 5)

    for index = 1, count do
        local teamIndex = ((index - 1) % #record.teams) + 1
        local teamOrdinal = math.floor((index - 1) / #record.teams) + 1
        local team = record.teams[teamIndex]
        if not team then
            return false, "defense_team_missing"
        end
        local spawnCfg = teamOrdinal == 1 and tankCfg or cfg
        spawnCfg = spawnCfg or cfg
        local enemyId = tostring(spawnCfg.id or cfg.id)
        local enemyDef = enemyDefs[enemyId]
        if not enemyDef then
            return false, "enemy_config_missing"
        end
        local position = randomPointOnPart(record.random, spawnArea, spawnInset, spawnInset)
            + Vector3.new(0, 3, 0)
        -- Each enemy has only one waypoint: a randomized point across the same finish line. Its
        -- random origin-to-finish vector is its complete path; combat may pull it off that vector.
        local destination =
            randomPointOnPart(record.random, finishLine, finishInset, finishLine.Size.Z * 0.5)
        local result = self._enemyService:SpawnEnemy(record.player, enemyId, {
            def = cloneEnemyDef(enemyDef, spawnCfg),
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
        result.model:SetAttribute("MergeEggPrototypeEnemy", true)
        result.model:SetAttribute("MergeRunId", record.runId)
        result.model:SetAttribute("MergeEggWave", waveIndex)
        result.model:SetAttribute("MergeEggSpawnIndex", index)
        result.model:SetAttribute("MergeEggAssignedTeamId", team.id)
        result.model:SetAttribute("MergeEggAssignedTeamName", team.displayName)
        result.model:SetAttribute("CombatTargetGroup", team.targetGroup)
        result.model:SetAttribute("CombatCadenceMultiplier", combatCadenceMultiplier(self._config))
        result.model:SetAttribute(
            "MergeEggCompositionRole",
            teamOrdinal == 1 and tankCfg and "tank" or "melee"
        )
        result.teamId = team.id
        record.enemies[#record.enemies + 1] = result
        record.enemyByTargetId[result.targetId] = result
        record.aliveEnemies += 1
        team.assignedAlive += 1
    end
    record.peakActiveEnemies = math.max(record.peakActiveEnemies or 0, record.aliveEnemies)
    self:_syncAllTeams(record)
    self:_setWorldState("WaveActive", record)
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
    self:_setWorldState("WaveActive", record)
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
        self:_setWorldState("WaveActive", record)
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
                            self:_setWorldState("WaveActive", record)
                        end
                    end
                end
            end
            if
                bulwarkLine
                and towardFinish.Magnitude > 0
                and model:GetAttribute("MergeEggBulwarkBreached") ~= true
            then
                local actualPosition = model:GetPivot().Position
                local fromBulwark = Vector3.new(
                    actualPosition.X - bulwarkLine.Position.X,
                    0,
                    actualPosition.Z - bulwarkLine.Position.Z
                )
                if fromBulwark:Dot(towardFinish.Unit) >= 0 then
                    self:_openBulwarkTarget(record, enemy, now)
                end
            end
            self:_sustainBulwarkTarget(record, enemy, now)
        end
    end
end

function MergeEggPrototypeService:_step()
    local record = self._active
    local now = os.clock()
    if record and record.encounterSpawned then
        self:_alertApproachingEnemies(record)
        if now >= (record.nextTeamSyncAt or 0) then
            record.nextTeamSyncAt = now + 0.1
            self:_syncAllTeams(record)
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
        definition.squad = teamCfg.squad or principal.squad or self._config.squad or {}
        local expected = #definition.squad
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
                    MergeEggTeamState = "Ready",
                    MergeEggExpectedPets = expected,
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
            config = teamCfg,
            targetGroup = targetGroup,
            principalName = info.name,
            principalModel = info.model,
            folder = info.folder,
            units = {},
            state = "Ready",
            activePets = 0,
            defeatedPets = 0,
            assignedAlive = 0,
            peakAssignedEnemies = 0,
            firstLossWave = nil,
            firstLossAssignedEnemies = nil,
            engaged = false,
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
        if tonumber(info.pets) ~= expected then
            self:_clearEncounter(record)
            return false, "unit_assets_missing"
        end
        totalUnits += tonumber(info.pets) or 0
        self:_setTeamState(record, team, "Ready")
    end
    if self._petFollowService and self._petFollowService.ReleaseMiningTargets then
        self._petFollowService:ReleaseMiningTargets(player)
    end

    local waveOk, reason = self:_spawnNextWave(record)
    if not waveOk then
        self:_clearEncounter(record)
        return false, reason
    end
    record.encounterSpawned = true
    record.hatching = false
    self:_syncAllTeams(record)
    self:_setWorldState("WaveActive", record)
    self:_log("Info", "Merge Egg prototype hatch started", {
        player = player.Name,
        teams = #record.teams,
        units = totalUnits,
        enemies = record.aliveEnemies,
        waves = #(self._config.waves or {}),
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
        self:_setWorldState("Idle", nil)
    end
    self:_unsealHallGate()
    RunService.Heartbeat:Connect(function()
        self:_step()
    end)
    Players.PlayerRemoving:Connect(function(player)
        if self._entering == player then
            self._entering = nil
        end
        if self._active and self._active.player == player then
            self:_end(self._active, false, true)
        end
    end)
end

return MergeEggPrototypeService
