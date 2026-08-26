--[[
    MergeEggPrototypeService — Studio-only Phase 1 vertical slice.

    One player enters through Home's otherwise-disabled Hall gate, is streamed to one authored
    strip under Workspace.Maps, hatches exactly five manifested Wayfinder pets, and fights one
    reward-free test wave. Reset makes the loop repeatable; Exit restores the player's runtime
    squad and exact entry transform.

    There is intentionally no tile-kit or mission-instance world generation here. The map is a
    persistent Studio-authored Model and this service owns only session routing and cleanup.
]]

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
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

local function cloneEnemyDef(source, config)
    local def = table.clone(source)
    def.attack = table.clone(source.attack or {})
    def.drop_table = {}
    def.display_name = "Prototype " .. tostring(source.display_name or config.id)
    def.hp = math.max(1, math.floor(tonumber(config.hp) or 320))
    def.level = math.max(1, math.floor(tonumber(config.level) or 1))
    def.armor = 0
    def.attack.damage = math.max(0, tonumber(config.damage) or 4)
    def.attack.cadence = math.max(0.25, tonumber(config.cadence) or 2)
    def.attack.sundering = 0
    return def
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
    world:SetAttribute("ActivePlayer", record and record.player.Name or nil)
    world:SetAttribute("ActiveRunId", record and record.runId or nil)
    world:SetAttribute("ActiveEnemies", record and record.aliveEnemies or 0)
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
        tostring(gateCfg.object_text or "Merge an Egg — Phase 1"),
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
        "Hatch 5 Units",
        "Phase 1 Test Egg",
        function(player)
            self:_hatch(player)
        end
    )
    self:_attachPrompt(
        findNamedPart(world, cfg.reset_control),
        RESET_PROMPT_NAME,
        "Reset Encounter",
        "Merge an Egg — Phase 1",
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

    local folder = self:_playerPetFolder(record.player, false)
    for _, model in ipairs(folder and folder:GetChildren() or {}) do
        if
            model:IsA("Model")
            and model:GetAttribute("MergeEggUnit") == true
            and model:GetAttribute("MergeRunId") == record.runId
        then
            model:Destroy()
        end
    end
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
        units = {},
        aliveEnemies = 0,
        encounterSpawned = false,
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

function MergeEggPrototypeService:_focusNextEnemy(record)
    if self._active ~= record then
        return false
    end
    for _, enemy in ipairs(record.enemies) do
        if
            enemy.model
            and enemy.model.Parent
            and (tonumber(enemy.model:GetAttribute("HP")) or 0) > 0
        then
            return self._enemyService:FocusSquadOnEnemy(record.player, enemy.targetId, {
                pinSeconds = 600,
                threat = 10000,
            })
        end
    end
    record.player:SetAttribute("CombatAssistTarget", nil)
    record.player:SetAttribute("CombatAssistUntil", nil)
    return false
end

function MergeEggPrototypeService:_onEnemyDefeated(record, defeat)
    if self._active ~= record then
        return
    end
    record.aliveEnemies = math.max(0, record.aliveEnemies - 1)
    self:_setWorldState(record.aliveEnemies > 0 and "WaveActive" or "WaveComplete", record)
    if record.aliveEnemies == 0 then
        record.player:SetAttribute("MergeEggWaveComplete", true)
        record.player:SetAttribute("CombatAssistTarget", nil)
        record.player:SetAttribute("CombatAssistUntil", nil)
        self:_log("Info", "Merge Egg prototype wave complete", {
            player = record.player.Name,
            finalTargetId = defeat and defeat.targetId,
        })
        return
    end
    self:_focusNextEnemy(record)
end

function MergeEggPrototypeService:_spawnWave(record)
    local cfg = self._config.enemy or {}
    local base = self._enemiesConfig.enemies and self._enemiesConfig.enemies[cfg.id]
    if not base then
        return false, "enemy_config_missing"
    end
    local spawnNames = (self._config.world or {}).enemy_spawns or {}
    local count = math.max(1, math.floor(tonumber(cfg.count) or #spawnNames))
    if count > #spawnNames then
        return false, "enemy_spawn_anchor_missing"
    end

    for index = 1, count do
        local anchor = findNamedPart(self._world, spawnNames[index])
        if not anchor then
            return false, "enemy_spawn_anchor_missing"
        end
        local position = anchor.Position + Vector3.new(0, 3, 0)
        local result = self._enemyService:SpawnEnemy(record.player, cfg.id, {
            def = cloneEnemyDef(base, cfg),
            position = position,
            home = position,
            movementLeash = self:_movementLeash(position),
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
        record.enemies[#record.enemies + 1] = result
    end
    record.aliveEnemies = #record.enemies
    return true
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
    local folder = self:_playerPetFolder(player, true)
    if not (spawn and folder) then
        return false, "hatcher_unavailable"
    end

    record.hatching = true
    local expected = #(self._config.squad or {})
    local count, models =
        self._npcPrincipalService:SpawnGhostSquad(folder, self._config.squad, spawn.CFrame, {
            attributes = {
                MergeEggUnit = true,
                MergeRunId = record.runId,
                EphemeralDownPolicy = "destroy",
            },
        })
    record.units = models
    if self._active ~= record then
        for _, model in ipairs(models) do
            if model.Parent then
                model:Destroy()
            end
        end
        return false, "session_ended"
    end
    if count ~= expected then
        self:_clearEncounter(record)
        return false, "unit_assets_missing"
    end
    if self._petFollowService and self._petFollowService.ReleaseMiningTargets then
        self._petFollowService:ReleaseMiningTargets(player)
    end

    local ok, reason = self:_spawnWave(record)
    if not ok then
        self:_clearEncounter(record)
        return false, reason
    end
    record.encounterSpawned = true
    record.hatching = false
    self:_setWorldState("WaveActive", record)
    self:_focusNextEnemy(record)
    self:_log("Info", "Merge Egg prototype hatch started", {
        player = player.Name,
        units = count,
        enemies = record.aliveEnemies,
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
