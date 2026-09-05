--[[
    CombatTutorialService — isolated combat-training step machine (configs/combat_tutorial.lua).

    Owns Signals.TutorialState only while the player is inside the combat_tutorial
    mission (InCombatTutorial). Homeworld TutorialService is gated off for that
    window and restored on leave. Progress lives on profile.CombatTutorial — never
    a ProfileStore template field (same Reconcile trap as Tutorial / ChallengeRuns).

    The last pillar marks the track done and grants the authored completion
    reward. Level 2 top-up stays off until this lesson is the live tutorial.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CombatRank = require(ReplicatedStorage.Shared.Game.CombatRank)
local CombatCourses = require(ReplicatedStorage.Shared.Game.CombatCourses)
local StatusBadge = require(ReplicatedStorage.Shared.Game.StatusBadge)
local TutorialFlow = require(ReplicatedStorage.Shared.Game.TutorialFlow)
local TutorialPack = require(ReplicatedStorage.Shared.Game.TutorialPack)
local TutorialSquad = require(ReplicatedStorage.Shared.Game.TutorialSquad)
local TutorialUnlock = require(ReplicatedStorage.Shared.Game.TutorialUnlock)
local HealerFocus = require(ReplicatedStorage.Shared.Game.HealerFocus)
local PetEndurance = require(ReplicatedStorage.Shared.Game.PetEndurance)
local PetInventoryView = require(ReplicatedStorage.Shared.Inventory.PetInventoryView)
local PetLockout = require(ReplicatedStorage.Shared.Game.PetLockout)
local PetRevive = require(script.Parent.Parent.PetRevive)
local Signals = require(ReplicatedStorage.Shared.Network.Signals)
local fireGameEvent = require(ReplicatedStorage.Shared.Network.FireGameEvent)
local Readiness = require(ReplicatedStorage.Shared.Utils.Readiness)

local CombatTutorialService = {}
CombatTutorialService.__index = CombatTutorialService

local DOOR_SEAL_NAME = "CombatTutorialDoorSeal"
local DOOR_ACTION_TAG = "CombatTutorialDoorAction"
local BEACON_PROMPT_NAME = "CombatTutorialAdvancePrompt"
local CAVE_ENTER_PROMPT_NAME = "CombatTutorialCaveEnter"
local LOBBY_LEAVE_PROMPT_NAME = "CombatTutorialLobbyLeave"

local function venueOffset(list)
    if type(list) ~= "table" then
        return Vector3.zero
    end
    return Vector3.new(tonumber(list[1]) or 0, tonumber(list[2]) or 0, tonumber(list[3]) or 0)
end

local function resolveWorkspacePath(path)
    local node = workspace
    if type(path) ~= "string" or path == "" then
        return node
    end
    for segment in string.gmatch(path, "[^.]+") do
        node = node and node:FindFirstChild(segment)
    end
    return node
end
local ARENA_ENTER_STUDS = 40
local MODE_ID = "combat_tutorial"

local function cloneDef(source)
    local def = table.clone(source)
    if type(source.attack) == "table" then
        def.attack = table.clone(source.attack)
    end
    if type(source.auto_heal) == "table" then
        def.auto_heal = table.clone(source.auto_heal)
    end
    return def
end

local function expandSpawnUnits(spec)
    local units = {}
    if type(spec.units) == "table" and #spec.units > 0 then
        for _, unit in ipairs(spec.units) do
            local n = math.max(1, math.floor(tonumber(unit.count) or 1))
            for _ = 1, n do
                units[#units + 1] = unit
            end
        end
        return units
    end
    local n = math.max(1, math.floor(tonumber(spec.count) or 1))
    for _ = 1, n do
        units[#units + 1] = spec
    end
    return units
end

local function spawnPadOf(record)
    local pads = record and record.hooks and record.hooks.PlayerSpawn
    return pads and pads[1]
end

-- Stamper hooks are CollectionService tags (PlayerSpawn / MissionObjective).
-- Training Ground rooms author a MissionSpawn part by name instead.
local function missionSpawnOf(record)
    local container = record and record.container
    if not container then
        return nil
    end
    local fallback
    for _, desc in ipairs(container:GetDescendants()) do
        if desc.Name == "MissionSpawn" and desc:IsA("BasePart") then
            if desc:GetAttribute("ObjectiveRoom") then
                return desc
            end
            fallback = fallback or desc
        end
    end
    return fallback
end

local function petFolder(player)
    local root = workspace:FindFirstChild("PlayerPets")
    return root and root:FindFirstChild(player.Name)
end

local function petForSlot(player, slot)
    local folder = petFolder(player)
    if not folder then
        return nil
    end
    for _, pet in ipairs(folder:GetChildren()) do
        if pet:IsA("Model") then
            local pn = pet:FindFirstChild("PositionNumber")
            if pn and tonumber(pn.Value) == slot then
                return pet
            end
        end
    end
    return nil
end

local function petPowerOf(pet)
    local nv = pet:FindFirstChild("Power")
    local p = (nv and tonumber(nv.Value))
        or pet:GetAttribute("EffectivePower")
        or pet:GetAttribute("BasePower")
        or 1
    if p < 1 then
        p = 1
    end
    return p
end

local function enemyFolders()
    local folders = {}
    local game = workspace:FindFirstChild("Game")
    if game then
        local nested = game:FindFirstChild("Enemies")
        if nested then
            folders[#folders + 1] = nested
        end
    end
    local root = workspace:FindFirstChild("Enemies")
    if root then
        folders[#folders + 1] = root
    end
    return folders
end

local function tutorialEnemies()
    local found = {}
    local seen = {}
    for _, folder in ipairs(enemyFolders()) do
        for _, model in ipairs(folder:GetDescendants()) do
            if
                model:IsA("Model")
                and model:GetAttribute("CombatTutorialEnemy")
                and not seen[model]
            then
                seen[model] = true
                found[#found + 1] = model
            end
        end
    end
    return found
end

local function enemyBreakableId(model)
    local bid = model and model:FindFirstChild("BreakableID")
    return bid and tonumber(bid.Value) or nil
end

local function stepWantsHealerFocus(step)
    return type(step) == "table"
        and type(step.target) == "table"
        and step.target.cue == "healer_focus"
end

local function tutorialEnemyAlive(bid)
    if not bid then
        return false
    end
    for _, model in ipairs(tutorialEnemies()) do
        if enemyBreakableId(model) == bid and (tonumber(model:GetAttribute("HP")) or 0) > 0 then
            return true
        end
    end
    return false
end

-- Pets currently swinging that bid (TargetID), not HUD assist. Assist expires
-- in a few seconds even while the squad stays on the healer.
local function petsAttackingBid(player, bid)
    if not bid then
        return 0
    end
    local folder = petFolder(player)
    if not folder then
        return 0
    end
    local n = 0
    for _, pet in ipairs(folder:GetChildren()) do
        if pet:IsA("Model") and pet:GetAttribute("CombatDowned") ~= true then
            local tt = pet:FindFirstChild("TargetType")
            local tid = pet:FindFirstChild("TargetID")
            if tt and tt.Value == "Enemy" and tid and tonumber(tid.Value) == bid then
                n += 1
            end
        end
    end
    return n
end

local function firstLivePet(player)
    local folder = petFolder(player)
    if not folder then
        return nil
    end
    local best, bestSlot
    for _, pet in ipairs(folder:GetChildren()) do
        if pet:IsA("Model") and pet:GetAttribute("CombatDowned") ~= true then
            local pn = pet:FindFirstChild("PositionNumber")
            local slot = pn and tonumber(pn.Value)
            if slot and (not bestSlot or slot < bestSlot) then
                best = pet
                bestSlot = slot
            end
        end
    end
    return best, bestSlot
end

function CombatTutorialService:Init()
    self._logger = self._modules and self._modules.Logger
    self._configLoader = self._modules and self._modules.ConfigLoader
    self._dataService = self._modules and self._modules.DataService
    self._potionService = self._modules and self._modules.PotionService
    self._enhancementService = self._modules and self._modules.EnhancementService
    self._enemyService = self._modules and self._modules.EnemyService
    self._missionInstanceService = self._modules and self._modules.MissionInstanceService
    self._tutorialService = self._modules and self._modules.TutorialService
    self._inventoryService = self._modules and self._modules.InventoryService
    self._hotbarService = self._modules and self._modules.HotbarService
    self._powerService = self._modules and self._modules.PowerService
    self._focusService = self._modules and self._modules.FocusService
    self._petGrantService = self._modules and self._modules.PetGrantService
    self._rewardService = self._modules and self._modules.RewardService
    self._playerProgressionService = self._modules and self._modules.PlayerProgressionService
    self._config = self._configLoader:LoadConfig("combat_tutorial")
    self._courses = self._configLoader:LoadConfig("combat_courses")
    self._courseConfigs = {}
    self._courseDefinitions = {}
    self._activeCourses = setmetatable({}, { __mode = "k" })
    self._opening = setmetatable({}, { __mode = "k" })
    self._rewardInFlight = setmetatable({}, { __mode = "k" })
    for _, definition in ipairs(self._courses.courses) do
        self._courseConfigs[definition.id] = CombatCourses.project(self._config, definition)
        local last =
            self._courseConfigs[definition.id].steps[#self._courseConfigs[definition.id].steps]
        last.title = self._courses.finish_pillar.title
        last.body = self._courses.finish_pillar.body
        last.body_gamepad = self._courses.finish_pillar.body
        last.localization_key = "combat_courses." .. definition.id .. ".finish"
        self._courseConfigs[definition.id].completion.localization_key = "combat_courses."
            .. definition.id
            .. ".completion"
        self._courseDefinitions[definition.id] = definition
    end
    self._ranksConfig = self._configLoader:LoadConfig("combat_ranks")
    self._homeTutorial = self._configLoader:LoadConfig("tutorial")
    self._enemiesConfig = self._configLoader:LoadConfig("enemies")
    self._petRoles = self._configLoader:LoadConfig("pet_roles")
    self._combatConfig = self._configLoader:LoadConfig("combat")
    self._sessions = setmetatable({}, { __mode = "k" })
    self._pendingConfirm = setmetatable({}, { __mode = "k" })

    fireGameEvent.tap(function(player, name, ctx)
        self:_onEvent(player, name, ctx)
    end)
end

function CombatTutorialService:_courseId(player)
    local active = self._activeCourses and self._activeCourses[player]
    return active and active.id or "basic"
end

function CombatTutorialService:_courseConfig(player, courseId)
    return self._courseConfigs and self._courseConfigs[courseId or self:_courseId(player)]
        or self._config
end

function CombatTutorialService:_progressKey(player, courseId)
    local active = self._activeCourses and self._activeCourses[player]
    if not courseId and active and active.replay then
        return "CombatTutorialReplay"
    end
    local definition = self._courseDefinitions
        and self._courseDefinitions[courseId or self:_courseId(player)]
    return definition and definition.key or "CombatTutorial"
end

function CombatTutorialService:Start()
    Signals.TutorialStateRequest.OnServerEvent:Connect(function(player)
        if player:GetAttribute("InCombatTutorial") == true then
            self:_push(player)
        end
    end)
    Signals.TutorialHotbarDone.OnServerEvent:Connect(function(player)
        self:_onHotbarDone(player)
    end)
    Signals.CombatTutorialDoorAction.OnServerEvent:Connect(function(player, action)
        self:_onDoorAction(player, action)
    end)
    Signals.CombatTutorialRedoAnswer.OnServerEvent:Connect(function(player, accepted)
        local pending = self._pendingConfirm[player]
        self._pendingConfirm[player] = nil
        if not pending or self._opening[player] then
            return
        end
        local kind = type(pending) == "table" and pending.kind or pending
        if kind == "courses" then
            local definition = type(accepted) == "string" and self._courseDefinitions[accepted]
            local data = self:_ensureProgress(player)
            if
                not definition
                or not data
                or not self:_canEnterCave(player)
                or not CombatCourses.allowed(data, definition)
            then
                return
            end
            local replay = data[definition.key].done == true
            self._activeCourses[player] = { id = definition.id, replay = replay }
            local instanceId = self:_openRequestedMission(player, {
                redo = replay,
                beforeOpen = pending.beforeOpen,
                onOpenFailed = pending.onOpenFailed,
            })
            if not instanceId then
                self._activeCourses[player] = nil
            end
            return
        end
        if accepted ~= true then
            return
        end
        if kind == "leave" then
            self:_leaveCaveMission(player)
            return
        end
        if self:_needsRedoConfirm(player) then
            self:_openRequestedMission(player, {
                redo = true,
                beforeOpen = type(pending) == "table" and pending.beforeOpen or nil,
                onOpenFailed = type(pending) == "table" and pending.onOpenFailed or nil,
            })
            return
        end
        self:_openRequestedMission(player, {
            beforeOpen = type(pending) == "table" and pending.beforeOpen or nil,
            onOpenFailed = type(pending) == "table" and pending.onOpenFailed or nil,
        })
    end)

    local function watch(player)
        task.spawn(function()
            self:_watchPlayer(player)
        end)
    end
    Players.PlayerAdded:Connect(watch)
    Players.PlayerRemoving:Connect(function(player)
        self:_restoreLoanedSquad(player)
    end)
    for _, player in ipairs(Players:GetPlayers()) do
        watch(player)
    end
end

function CombatTutorialService:_watchPlayer(player)
    local function sync()
        if not player.Parent then
            return
        end
        if self:_isCaveDoor() then
            self:_offerCaveEnter(player)
        end
        if self:_isInside(player) then
            self:_enter(player)
            self:_syncLobbyLeavePrompt(player)
        else
            self:_leave(player)
        end
    end
    player:GetAttributeChangedSignal("InMission"):Connect(sync)
    player:GetAttributeChangedSignal("GauntletMode"):Connect(sync)
    if Readiness.awaitAttribute(player, "DataLoaded", true, 20) and player.Parent then
        self:_restoreHealUnlock(player)
        local data = self:_ensureProgress(player)
        if data then
            self:_syncCombatRank(player, data, nil)
        end
        if not self:_isInside(player) then
            self:_restoreLoanedSquad(player)
        end
        sync()
        if self:_isCaveDoor() then
            task.spawn(function()
                while player.Parent do
                    sync()
                    task.wait(0.4)
                end
            end)
        end
    end
end

function CombatTutorialService:_isHomeworldVenue()
    local venue = self._config and self._config.venue
    return type(venue) == "table" and venue.mode == "homeworld_cave"
end

function CombatTutorialService:_isCaveDoor()
    local venue = self._config and self._config.venue
    if type(venue) ~= "table" then
        return false
    end
    return venue.door == "homeworld_cave"
        or venue.mode == "homeworld_cave"
        or venue.mode == "mission_slot"
end

function CombatTutorialService:_caveMissionId()
    local venue = self._config and self._config.venue
    if type(venue) == "table" and type(venue.mission_id) == "string" then
        return venue.mission_id
    end
    local entry = self._config and self._config.entry
    if type(entry) == "table" and type(entry.mission_id) == "string" then
        return entry.mission_id
    end
    return MODE_ID
end

function CombatTutorialService:_openCaveMission(player, opts)
    if not self:_canEnterCave(player) then
        return nil, "combat_tutorial_unavailable"
    end
    if self:_needsRedoConfirm(player) and not (opts and opts.redo == true) then
        return nil, "redo_confirmation_required"
    end
    self:_prepareLiveTrack(player, opts and opts.redo == true)
    local svc = self._missionInstanceService
    if not (svc and svc.Open) then
        return nil, "mission_service_unavailable"
    end
    local instanceId, err = svc:Open(player, self:_caveMissionId())
    if err and self._logger then
        self._logger:Warn("combat tutorial open failed", { err = tostring(err) })
    end
    return instanceId, err
end

function CombatTutorialService:_openRequestedMission(player, opts)
    opts = type(opts) == "table" and opts or {}
    if self._opening[player] then
        return nil, "combat_tutorial_opening"
    end
    self._opening[player] = true
    if type(opts.beforeOpen) == "function" then
        local ok, prepared = pcall(opts.beforeOpen)
        if not ok or prepared == false then
            self._opening[player] = nil
            if type(opts.onOpenFailed) == "function" then
                pcall(opts.onOpenFailed, "entry_prepare_failed")
            end
            return nil, "entry_prepare_failed"
        end
    end
    local ok, instanceId, err =
        pcall(self._openCaveMission, self, player, { redo = opts.redo == true })
    self._opening[player] = nil
    if not ok then
        err, instanceId = tostring(instanceId), nil
    end
    if not instanceId and type(opts.onOpenFailed) == "function" then
        pcall(opts.onOpenFailed, err)
    end
    return instanceId, err
end

-- Public entry boundary used by alternate authored vendors. It deliberately reuses the exact cave
-- mission, redo confirmation, save track, rewards, and loaned-squad lifecycle instead of creating a
-- Merge-specific tutorial fork.
function CombatTutorialService:OpenForPlayer(player, opts)
    if not self:_canEnterCave(player) or self._opening[player] then
        return false, "combat_tutorial_unavailable"
    end
    opts = type(opts) == "table" and opts or {}
    local profile = self:_ensureProgress(player)
    if profile and profile.CombatTutorial.done == true then
        local copy = self._courses.menu
        local choices = {}
        for _, definition in ipairs(self._courses.courses) do
            local progress = profile[definition.key]
            local allowed = CombatCourses.allowed(profile, definition)
            local action = progress.done and copy.replay
                or (progress.step > 1 and copy.resume or copy.start)
            table.insert(choices, {
                id = definition.id,
                enabled = allowed,
                label = definition.title .. " — " .. (allowed and action or copy.locked),
            })
        end
        self._pendingConfirm[player] =
            { kind = "courses", beforeOpen = opts.beforeOpen, onOpenFailed = opts.onOpenFailed }
        Signals.CombatTutorialRedoOffer:FireClient(player, {
            kind = "courses",
            title = copy.title,
            body = copy.body,
            no_text = copy.cancel,
            choices = choices,
        })
        return true, { operation = "combat_training_confirmation", combatTutorialDone = true }
    end
    self._activeCourses[player] = nil
    local data = self._dataService and self._dataService:GetData(player)
    local progress = data and data[self:_progressKey(player)]
    local done = type(progress) == "table" and progress.done == true
    local started = type(progress) == "table"
        and done ~= true
        and math.max(1, math.floor(tonumber(progress.step) or 1)) > 1
    if self:_needsRedoConfirm(player) then
        self:_offerConfirm(
            player,
            "redo",
            (self._config.venue and self._config.venue.redo_confirm) or {},
            {
                beforeOpen = opts.beforeOpen,
                onOpenFailed = opts.onOpenFailed,
            }
        )
        return true,
            {
                operation = "combat_training_confirmation",
                combatTutorialDone = done,
            }
    end
    local instanceId, err = self:_openRequestedMission(player, {
        beforeOpen = opts.beforeOpen,
        onOpenFailed = opts.onOpenFailed,
    })
    if not instanceId then
        return false, err or "combat_tutorial_open_failed"
    end
    return true,
        {
            operation = "combat_training_opened",
            resumed = started,
            instanceId = instanceId,
        }
end

local function asPromptHost(inst)
    if inst and inst:IsA("BasePart") then
        return inst
    end
    if inst and inst:IsA("Model") then
        return inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart", true)
    end
    return nil
end

function CombatTutorialService:_venueAnchor()
    local venue = self._config.venue or {}
    local name = venue.anchor_name or "EarthLair"
    local root = resolveWorkspacePath(venue.anchor_root or "Maps.Home")
    if root then
        local host = asPromptHost(root:FindFirstChild(name, true))
        if host then
            return host
        end
    end
    local maps = workspace:FindFirstChild("Maps")
    local home = maps and maps:FindFirstChild("Home")
    if home then
        local host = asPromptHost(home:FindFirstChild(name, true))
            or asPromptHost(home:FindFirstChild("BaddieSpawnerEarth", true))
        if host then
            return host
        end
    end
    return nil
end

function CombatTutorialService:_caveEnterPromptName()
    local look = self._config.venue and self._config.venue.enter_prompt
    return (look and look.prompt_name) or CAVE_ENTER_PROMPT_NAME
end

function CombatTutorialService:_unbindCaveEnter()
    local leftover = workspace:FindFirstChild("CombatTutorialCaveMouth", true)
    if leftover then
        leftover:Destroy()
    end
end

function CombatTutorialService:_offerCaveEnter(_player)
    if not self:_isCaveDoor() then
        return
    end
    local host = self:_venueAnchor()
    if not host then
        return
    end
    local promptName = self:_caveEnterPromptName()
    if host:FindFirstChild(promptName) then
        return
    end
    -- Same billboard as the Hall MissionDoor: default E prompt, not a frost slab.
    -- Always on — finished players get a redo confirm; everyone else walks in.
    local look = (self._config.venue and self._config.venue.enter_prompt) or {}
    local prompt = Instance.new("ProximityPrompt")
    prompt.Name = promptName
    prompt.ActionText = tostring(look.action_text or "Enter")
    prompt.ObjectText = tostring(look.object_text or "Combat Training")
    prompt.HoldDuration = math.max(0, tonumber(look.hold_duration) or 0.25)
    prompt.MaxActivationDistance = math.max(8, tonumber(look.max_distance) or 14)
    prompt.RequiresLineOfSight = false
    prompt.KeyboardKeyCode = Enum.KeyCode.E
    prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
    prompt.Parent = host
    prompt.Triggered:Connect(function(who)
        self:_onCaveEnterTriggered(who)
    end)
end

function CombatTutorialService:_onCaveEnterTriggered(player)
    self:OpenForPlayer(player)
end

function CombatTutorialService:_canEnterCave(player)
    if not (player and player.Parent) then
        return false
    end
    if not self._dataService or not self._dataService:IsDataLoaded(player) then
        return false
    end
    if player:GetAttribute("InCombatTutorial") == true or player:GetAttribute("InMission") then
        return false
    end
    return self._dataService:GetData(player) ~= nil
end

function CombatTutorialService:_offerConfirm(player, kind, copy, context)
    if not (player and player.Parent) then
        return
    end
    copy = type(copy) == "table" and copy or {}
    self._pendingConfirm[player] = type(context) == "table"
            and {
                kind = kind,
                beforeOpen = context.beforeOpen,
                onOpenFailed = context.onOpenFailed,
            }
        or kind
    local defaults = {
        redo = {
            title = "Combat Training",
            body = "You've already finished this. Redo the training?",
            yes_text = "Redo",
            no_text = "Not now",
        },
        leave = {
            title = "Continue later?",
            body = "Your progress is saved. Come back anytime.",
            yes_text = "Leave",
            no_text = "Stay",
        },
    }
    local fallback = defaults[kind] or defaults.redo
    Signals.CombatTutorialRedoOffer:FireClient(player, {
        kind = kind,
        title = tostring(copy.title or fallback.title),
        body = tostring(copy.body or fallback.body),
        yes_text = tostring(copy.yes_text or fallback.yes_text),
        no_text = tostring(copy.no_text or fallback.no_text),
    })
end

function CombatTutorialService:_isInLobby(player)
    if not (player and player:GetAttribute("InCombatTutorial") == true) then
        return false
    end
    if not self._dataService or not self._dataService:IsDataLoaded(player) then
        return false
    end
    local data = self._dataService:GetData(player)
    local step = data
        and TutorialFlow.current(self:_courseConfig(player), data[self:_progressKey(player)])
    return TutorialFlow.isCombatLobbyStep(step)
end

function CombatTutorialService:_lobbyLeavePad(player)
    local mis = self._missionInstanceService
    local record = mis and mis.GetRecordForPlayer and mis:GetRecordForPlayer(player)
    local pad = spawnPadOf(record)
    if pad and pad:IsA("BasePart") then
        return pad
    end
    local _, container = self:_missionContainer(player)
    pad = container and container:FindFirstChild("SpawnPad", true)
    if pad and pad:IsA("BasePart") then
        return pad
    end
    return nil
end

function CombatTutorialService:_lobbyLeaveHost(player)
    local _, container = self:_missionContainer(player)
    if container then
        local seal = container:FindFirstChild(DOOR_SEAL_NAME, true)
        if seal and seal:IsA("BasePart") then
            return seal
        end
    end
    return self:_lobbyLeavePad(player)
end

function CombatTutorialService:_lobbyLeavePromptName()
    local look = self._config.venue and self._config.venue.leave_prompt
    return (look and look.prompt_name) or LOBBY_LEAVE_PROMPT_NAME
end

function CombatTutorialService:_setLeavePromptEnabled(part, enabled)
    if not part then
        return
    end
    local prompt = part:FindFirstChild(self:_lobbyLeavePromptName())
    if prompt then
        prompt.Enabled = enabled == true
    end
end

function CombatTutorialService:_syncLobbyLeavePrompt(player)
    local host = self:_lobbyLeaveHost(player)
    local pad = self:_lobbyLeavePad(player)
    if pad then
        self:_setLeavePromptEnabled(pad, false)
        local leftover = pad:FindFirstChild(self:_lobbyLeavePromptName())
        if leftover then
            leftover:Destroy()
        end
    end
    if host then
        self:_setLeavePromptEnabled(host, false)
        local leftover = host:FindFirstChild(self:_lobbyLeavePromptName())
        if leftover then
            leftover:Destroy()
        end
        local billboard = host:FindFirstChild("CombatTutorialDoorBillboard")
        if billboard then
            billboard:Destroy()
        end
    end
    local inLobby = self:_isInLobby(player)
    local session = self._sessions[player]
    local readyAt = session and tonumber(session.lobbyLeaveReadyAt)
    local leaveOn = inLobby and (not readyAt or os.clock() >= readyAt)
    self:_forEachLeaveGui(player, function(gui)
        gui.Enabled = leaveOn
        local click = gui.Parent and gui.Parent:FindFirstChildOfClass("ClickDetector")
        if click then
            click.MaxActivationDistance = leaveOn and 24 or 0
        end
    end)
end

function CombatTutorialService:_requestLeave(player)
    if not self:_isInLobby(player) then
        return
    end
    local session = self._sessions[player]
    local readyAt = session and tonumber(session.lobbyLeaveReadyAt)
    if readyAt and os.clock() < readyAt then
        return
    end
    self:_offerConfirm(
        player,
        "leave",
        (self._config.venue and self._config.venue.leave_confirm) or {}
    )
end

function CombatTutorialService:_onDoorLesson(player)
    if player:GetAttribute("InCombatTutorial") ~= true then
        return
    end
    if self:_stepAcceptsEnter(player) then
        self:_unsealDoors(player)
        fireGameEvent(player, "combat_tutorial_entered_arena", { source = "door_button" })
        return
    end
    local spec = self:_doorPlateForPlayer(player)
    fireGameEvent(player, "combat_tutorial_door_blocked", {
        name = spec.nudge or "Finish this first!",
        source = "door_button",
    })
end

function CombatTutorialService:_onDoorAction(player, action)
    if action == "leave" then
        self:_requestLeave(player)
        return
    end
    if action == "lesson" then
        self:_onDoorLesson(player)
    end
end

function CombatTutorialService:_leaveButtonText()
    local look = (self._config.venue and self._config.venue.leave_prompt) or {}
    return tostring(look.action_text or "Continue later")
end

function CombatTutorialService:_leaveCaveMission(player)
    if not self:_isInLobby(player) then
        return
    end
    local instanceId = player:GetAttribute("InMission")
    local mis = self._missionInstanceService
    if type(instanceId) == "string" and instanceId ~= "" and mis and mis.Abandon then
        mis:Abandon(instanceId)
        return
    end
    self:_leave(player)
end

function CombatTutorialService:_needsRedoConfirm(player)
    local data = self._dataService and self._dataService:GetData(player)
    if not data then
        return false
    end
    return TutorialFlow.caveEnterNeedsConfirm(
        data.Tutorial,
        data[self:_progressKey(player)],
        data.GameData
    )
end

function CombatTutorialService:_prepareLiveTrack(player, redo)
    local data = self._dataService and self._dataService:GetData(player)
    if not data then
        return
    end
    local combat = data[self:_progressKey(player)]
    if redo == true or (combat and combat.done == true) then
        data[self:_progressKey(player)] = TutorialFlow.fresh(self:_courseConfig(player))
        self._dataService:RequestSave(player, "combat_tutorial_reopen")
    end
end

function CombatTutorialService:_homeworldWantsTraining(player)
    if not self._dataService or not self._dataService:IsDataLoaded(player) then
        return false
    end
    local data = self._dataService:GetData(player)
    if not (data and data.Tutorial) or data.Tutorial.done == true then
        return false
    end
    local step = TutorialFlow.current(self._homeTutorial, data.Tutorial)
    local want = (self._config.venue and self._config.venue.homeworld_step) or "first_fight"
    return step and step.id == want
end

function CombatTutorialService:_isInside(player)
    if self:_isHomeworldVenue() then
        if not self._dataService or not self._dataService:IsDataLoaded(player) then
            return false
        end
        local data = self._dataService:GetData(player)
        local combat = data and data[self:_progressKey(player)]
        if combat and combat.done == true then
            -- Finished this visit: leave. Isolated Hall leftovers can reopen
            -- while Homeworld is still on first_fight.
            if player:GetAttribute("InCombatTutorial") == true then
                return false
            end
            if not self:_homeworldWantsTraining(player) then
                return false
            end
        end
        if player:GetAttribute("InCombatTutorial") == true then
            return true
        end
        local session = self._sessions[player]
        return session and session.caveEnterAccepted == true
    end
    if player:GetAttribute("GauntletMode") == MODE_ID then
        return true
    end
    local record = self._missionInstanceService
        and self._missionInstanceService.GetRecordForPlayer
        and self._missionInstanceService:GetRecordForPlayer(player)
    return record and record.missionId == MODE_ID
end

function CombatTutorialService:_session(player)
    local session = self._sessions[player]
    if not session then
        session = { spawned = {} }
        self._sessions[player] = session
    end
    return session
end

function CombatTutorialService:_clearSessionLoops(session)
    session.spawnToken = (session.spawnToken or 0) + 1
    session.sealToken = (session.sealToken or 0) + 1
    session.beaconToken = (session.beaconToken or 0) + 1
    session.bindHealToken = (session.bindHealToken or 0) + 1
    session.woundToken = (session.woundToken or 0) + 1
    session.woundedSlot = nil
    session.woundSelectionCleared = nil
    session.targetEnemyToken = (session.targetEnemyToken or 0) + 1
    session.targetEnemyBid = nil
    session.enemySelectionCleared = nil
    session.healerCommitted = nil
    session.healerEngaged = nil
    session.healerLost = nil
    session.roomClearToken = (session.roomClearToken or 0) + 1
    if session.heartbeat then
        session.heartbeat:Disconnect()
        session.heartbeat = nil
    end
    if session.targetConn then
        session.targetConn:Disconnect()
        session.targetConn = nil
    end
    if session.unlockAttr then
        session.unlockAttr:Disconnect()
        session.unlockAttr = nil
    end
end

function CombatTutorialService:_hotbarHasHeal(data)
    local hotbar = data and data.Hotbar
    if type(hotbar) ~= "table" then
        return false
    end
    for _, bind in pairs(hotbar) do
        if type(bind) == "table" and bind.type == "power" and bind.target == "heal" then
            return true
        end
    end
    return false
end

-- Heal stays hidden on Homeworld until the first combat-training enter so
-- bind_power only offers Resonance. The flag is NOT on profile.CombatTutorial
-- because restart_on_enter wipes that table; once unlocked it stays.
function CombatTutorialService:_unlockHeal(player)
    local data = self._dataService:GetData(player)
    if data and data.CombatTutorialHealUnlocked ~= true then
        data.CombatTutorialHealUnlocked = true
        self._dataService:RequestSave(player, "combat_tutorial_heal_unlock")
    end
    player:SetAttribute("CombatTutorialHealUnlocked", true)
end

function CombatTutorialService:_restoreHealUnlock(player)
    local data = self._dataService:GetData(player)
    if not data then
        return
    end
    if data.CombatTutorialHealUnlocked == true or self:_hotbarHasHeal(data) then
        if data.CombatTutorialHealUnlocked ~= true then
            data.CombatTutorialHealUnlocked = true
            self._dataService:RequestSave(player, "combat_tutorial_heal_unlock")
        end
        player:SetAttribute("CombatTutorialHealUnlocked", true)
        if self._hotbarService and self._hotbarService.PushState then
            self._hotbarService:PushState(player)
        end
    end
end

function CombatTutorialService:_shouldRestartOnEnter()
    return self._config and self._config.restart_on_enter == true
end

function CombatTutorialService:_rewindLeaveResume(player)
    local data = self:_ensureProgress(player)
    if
        not (data and data[self:_progressKey(player)])
        or data[self:_progressKey(player)].done == true
    then
        return false
    end
    local step = TutorialFlow.current(self:_courseConfig(player), data[self:_progressKey(player)])
    local resumeId = step and step.leave_resume
    if type(resumeId) ~= "string" or resumeId == "" then
        return false
    end
    local progress, changed =
        TutorialFlow.rewindTo(self:_courseConfig(player), data[self:_progressKey(player)], resumeId)
    if not changed then
        return false
    end
    data[self:_progressKey(player)] = progress
    local session = self._sessions[player]
    if session then
        session.spawned = {}
        session.shielded = {}
        session.packSpawned = false
        session.packRemaining = 0
        session.squadReset = nil
    end
    self:_refreshLobbyReady(player)
    self._dataService:RequestSave(player, "combat_tutorial_leave_resume")
    return true
end

function CombatTutorialService:_restartTrack(player)
    local data = self._dataService:GetData(player)
    if not data then
        return
    end
    data[self:_progressKey(player)] = TutorialFlow.fresh(self:_courseConfig(player))
    local session = self:_session(player)
    session.spawned = {}
    session.shielded = {}
    session.packSpawned = false
    session.packRemaining = 0
    session.squadReset = nil
    self:_despawnTutorialEnemies(player)
    self:_resetDoorState(player)
    self:_setBeaconActive(player, false)
end

-- Admin "reset to beginning": wipe the combat-training profile, leave the
-- instance, and restore the loaned squad. Must not rewind to leave_resume
-- or testers stay on Kill the healer (26/32) after a full-account reset.
function CombatTutorialService:ResetForBeginning(player)
    if not (player and self._dataService and self._dataService:IsDataLoaded(player)) then
        return { ok = false, reason = "data_not_loaded" }
    end
    local session = self:_session(player)
    session.skipRewind = true
    self:_despawnTutorialEnemies(player)
    local instanceId = player:GetAttribute("InMission")
    local mis = self._missionInstanceService
    if type(instanceId) == "string" and instanceId ~= "" and mis and mis.Abandon then
        pcall(function()
            mis:Abandon(instanceId)
        end)
    end
    if player:GetAttribute("InCombatTutorial") == true then
        self:_leave(player)
    else
        self:_restoreLoanedSquad(player)
    end
    local data = self._dataService:GetData(player)
    if data then
        data[self:_progressKey(player)] = TutorialFlow.fresh(self:_courseConfig(player))
        self._activeCourses[player] = nil
        for _, definition in ipairs(self._courses.courses) do
            data[definition.key] = TutorialFlow.fresh(self._courseConfigs[definition.id])
            data[definition.key .. "RewardGranted"] = nil
        end
        data.CombatCoursesVersion = self._courses.version
        data.CombatTutorialReplay = nil
        data.CombatTutorialLoadout = nil
        data.CombatTutorialHealUnlocked = nil
        data.CombatTutorialRewardGranted = nil
        if type(data.GameData) == "table" then
            data.GameData.CombatRank = nil
            data.GameData.StatusBadge = {}
            data.GameData.StatusBadgeSeen = {}
        end
    end
    player:SetAttribute("CombatTutorialHealUnlocked", nil)
    -- Picker reads CombatRankEarned; nilling only CombatRank left every
    -- Training title still wearable after admin reset.
    self:_publishCombatRank(player, nil)
    player:SetAttribute("InCombatTutorial", nil)
    player:SetAttribute("CombatTutorialWoundSlot", nil)
    player:SetAttribute("CombatTutorialTargetEnemy", nil)
    player:SetAttribute("CombatTutorialHealerCue", nil)
    self._sessions[player] = nil
    self._dataService:RequestSave(player, "combat_tutorial_reset")
    if self._tutorialService and self._tutorialService._push then
        self._tutorialService:_push(player)
    end
    return { ok = true }
end

function CombatTutorialService:_despawnTutorialEnemies(player)
    local userId = player and player.UserId
    local enemySvc = self._enemyService
    if enemySvc and enemySvc.DespawnForCombatTutorial then
        enemySvc:DespawnForCombatTutorial(userId)
    end
    local record = self._missionInstanceService
        and self._missionInstanceService.GetRecordForPlayer
        and player
        and self._missionInstanceService:GetRecordForPlayer(player)
    if record and record.boundsMin and enemySvc and enemySvc.DespawnEnemiesInBounds then
        enemySvc:DespawnEnemiesInBounds(record.boundsMin, record.boundsMax)
    end
    for _, model in ipairs(tutorialEnemies()) do
        local owner = model:GetAttribute("CombatTutorialOwner")
        if userId == nil or owner == nil or owner == userId then
            if enemySvc and enemySvc.DespawnModel then
                enemySvc:DespawnModel(model)
            else
                model:Destroy()
            end
        end
    end
end

function CombatTutorialService:_liveTutorialEnemies(player)
    local userId = player and player.UserId
    local live = {}
    for _, model in ipairs(tutorialEnemies()) do
        local owner = model:GetAttribute("CombatTutorialOwner")
        if
            (userId == nil or owner == nil or owner == userId)
            and (tonumber(model:GetAttribute("HP")) or 0) > 0
        then
            live[#live + 1] = model
        end
    end
    return live
end

function CombatTutorialService:_enforceLivePackCap(player)
    local extra = TutorialPack.surplus(
        self:_liveTutorialEnemies(player),
        self._config and self._config.pack_cap,
        function(model)
            if model:GetAttribute("CombatTutorialRole") == "healer" then
                return true
            end
            local name = model:GetAttribute("DisplayName") or model.Name
            return type(name) == "string"
                and string.find(string.lower(name), "healer", 1, true) ~= nil
        end
    )
    local enemySvc = self._enemyService
    for _, model in ipairs(extra) do
        if enemySvc and enemySvc.DespawnModel then
            enemySvc:DespawnModel(model)
        elseif model then
            model:Destroy()
        end
    end
end

function CombatTutorialService:_enter(player)
    if self._sessions[player] and self._sessions[player].leaving then
        return
    end
    if not self._dataService:IsDataLoaded(player) then
        return
    end
    local already = player:GetAttribute("InCombatTutorial") == true
    if already then
        -- Stay on the current lesson while they remain inside. Seal retry lives
        -- on the watcher so a late-stamped mission instance still gets a door.
        self:_ensureWatchers(player)
        return
    end
    player:SetAttribute("InCombatTutorial", true)
    fireGameEvent(
        player,
        "combat_tutorial_started",
        { source = "cave", courseId = self:_courseId(player) }
    )
    local session = self:_session(player)
    if not session.enteredFrom then
        local character = player.Character
        if character then
            session.enteredFrom = character:GetPivot()
        end
    end
    if self:_isHomeworldVenue() then
        self:_prepareLiveTrack(player)
        self:_ensureHomeworldVenue(player)
        session.caveEnterAccepted = nil
        self:_unbindCaveEnter()
        if self._config.venue and self._config.venue.warp_on_enter == true then
            self:_warpToLobby(player, self:_lobbyCFrame(player))
        end
    end
    self:_unlockHeal(player)
    if self._hotbarService and self._hotbarService.PushState then
        self._hotbarService:PushState(player)
    end
    self:_applyLoanedSquad(player)
    if self:_shouldRestartOnEnter() then
        self:_restartTrack(player)
    end
    self:_rewindLeaveResume(player)
    local data = self:_ensureProgress(player)
    -- Normal first-entry grant: one low-level Healing enhancement is waiting by the time the player
    -- reaches the Heal lesson. `_applyGrant` records `entry` in the tutorial ledger, so reconnects
    -- and repeat visits do not mint duplicates.
    if self:_progressKey(player) == "CombatTutorial" then
        self:_applyGrant(player, data, { id = "entry", grant = self._config.entry_grant })
    end
    self:_applyStepSideEffects(player, data, true)
    local look = (self._config.venue and self._config.venue.leave_prompt) or {}
    session.lobbyLeaveReadyAt = os.clock() + math.max(0, tonumber(look.enable_after) or 0.8)
    self:_syncLobbyLeavePrompt(player)
    self:_push(player)
    self:_ensureWatchers(player)
end

function CombatTutorialService:_leave(player)
    if player:GetAttribute("InCombatTutorial") ~= true then
        return
    end
    local session = self._sessions[player]
    if session and session.leaving then
        return
    end
    if session then
        session.leaving = true
        self:_clearSessionLoops(session)
    end
    if not (session and session.skipRewind) then
        self:_rewindLeaveResume(player)
    end
    self:_despawnTutorialEnemies(player)
    player:SetAttribute("CombatTutorialWoundSlot", nil)
    player:SetAttribute("CombatTutorialTargetEnemy", nil)
    player:SetAttribute("CombatTutorialHealerCue", nil)
    self:_destroyHomeworldVenue(player)
    self:_restoreLoanedSquad(player)
    if self._hotbarService and self._hotbarService.PushState then
        self._hotbarService:PushState(player)
    end
    session = self._sessions[player]
    if session then
        self:_clearSessionLoops(session)
        self._sessions[player] = nil
    end
    -- This is the return-to-game readiness signal. Squad restoration can yield; publishing it
    -- earlier lets Merge reclaim a bay while the tutorial still owns/rebuilds the player's pets.
    player:SetAttribute("InCombatTutorial", nil)
    if self._tutorialService and self._tutorialService._push then
        self._tutorialService:_push(player)
    end
end

function CombatTutorialService:_loanedLoadout(player)
    local data = self._dataService and self._dataService:GetData(player)
    local loadout = data and data.CombatTutorialLoadout
    if type(loadout) == "table" and loadout.active == true then
        return data, loadout
    end
    return data, nil
end

function CombatTutorialService:_applyLoanedSquad(player)
    if not self._dataService or not self._dataService:IsDataLoaded(player) then
        return
    end
    local data, existing = self:_loanedLoadout(player)
    if not data or existing then
        return
    end
    local rows = TutorialSquad.grantRows(self._config)
    if #rows == 0 then
        return
    end
    data.Equipped = data.Equipped or {}
    local saved = TutorialSquad.copyEquipped(data.Equipped.pets)
    local ledger = {}
    local grant = self._petGrantService
    if grant and grant.GrantPet then
        for _, row in ipairs(rows) do
            local result = grant:GrantPet(player, {
                petType = row.pet,
                variant = row.variant,
                quantity = row.count,
                source = "combat_tutorial_loan",
                deferFlush = true,
            })
            if result and result.ok then
                ledger[row.stackKey] = row.count
            end
        end
    end
    local maxSlots = 0
    if self._inventoryService and self._inventoryService.GetPetEquipMaxSlots then
        maxSlots = self._inventoryService:GetPetEquipMaxSlots(player)
    end
    maxSlots = math.max(0, math.floor(tonumber(maxSlots) or 0))
    if self._inventoryService and self._inventoryService.ReplaceEquippedPets then
        self._inventoryService:ReplaceEquippedPets(
            player,
            TutorialSquad.equipRefs(self._config, maxSlots),
            {
                force = true,
                ignoreLocks = true,
                deferFlush = true,
            }
        )
    end
    data.CombatTutorialLoadout = {
        active = true,
        savedEquipped = saved,
        grants = ledger,
    }
    if self._inventoryService and self._inventoryService.FlushBucket then
        self._inventoryService:FlushBucket(player, "pets", "combat_tutorial_loan")
    end
end

function CombatTutorialService:_restoreLoanedSquad(player)
    if not (player and self._dataService and self._dataService:IsDataLoaded(player)) then
        return
    end
    local data, loadout = self:_loanedLoadout(player)
    if not data or not loadout then
        return
    end
    data.Equipped = data.Equipped or {}
    data.Equipped.pets = TutorialSquad.copyEquipped(loadout.savedEquipped)
    data.PetLockouts = PetLockout.clearAll()
    player:SetAttribute("PetLockouts", nil)
    local items = data.Inventory and data.Inventory.pets and data.Inventory.pets.items
    if type(items) == "table" then
        TutorialSquad.removeGrants(items, loadout.grants)
    end
    data.CombatTutorialLoadout = nil
    if self._inventoryService and self._inventoryService.FlushBucket then
        self._inventoryService:FlushBucket(player, "pets", "combat_tutorial_restore")
    elseif self._inventoryService and self._inventoryService.RebuildPetProjections then
        self._inventoryService:RebuildPetProjections(player)
    end
    self:_recoverOwnedSquad(player)
end

function CombatTutorialService:_recoverOwnedSquad(player)
    local folder = petFolder(player)
    if not folder then
        return
    end
    for _, model in ipairs(folder:GetChildren()) do
        if model:IsA("Model") and not model:GetAttribute("GhostPet") then
            PetRevive.revive(model, player)
            model:SetAttribute("CombatDamageTaken", 0)
            model:SetAttribute("ResSicknessFloor", nil)
            model:SetAttribute("ResSicknessUntil", nil)
        end
    end
end

function CombatTutorialService:_ensureProgress(player)
    local data = self._dataService:GetData(player)
    if not data then
        return nil
    end
    if CombatCourses.migrate(self._config, self._courses, data, TutorialFlow) then
        self._dataService:RequestSave(player, "combat_courses_migration", { critical = true })
    end
    player:SetAttribute("CombatTutorialDone", data.CombatTutorial.done == true)
    for _, definition in ipairs(self._courses.courses) do
        if data[definition.key].done == true then
            self:_applyCompletionReward(player, data, definition.id)
        end
    end
    return data
end

function CombatTutorialService:_onEvent(player, name, ctx)
    if not (player and player.Parent) or player:GetAttribute("InCombatTutorial") ~= true then
        return
    end
    if not self._dataService:IsDataLoaded(player) then
        return
    end
    if name == "enemy_defeated" then
        local session = self:_session(player)
        if session.packSpawned == true then
            session.packRemaining = math.max(0, (tonumber(session.packRemaining) or 0) - 1)
        end
        -- Drop KILL THIS immediately so a dead healer never waits for the 0.5s
        -- mark loop (pets can auto-finish it without a click).
        self:_updateHealerFocus(player, false)
    end
    if name == "pet_healed" then
        -- Real mend only: a no-op heal (already full) must not clear the lesson.
        if not (type(ctx) == "table" and (tonumber(ctx.before) or 0) > 0) then
            return
        end
    end
    if name == "power_bound" or name == "pet_equipped" then
        self:_onUnlockStateChanged(player, name)
    end
    local data = self:_ensureProgress(player)
    if not data or data[self:_progressKey(player)].done then
        return
    end
    local completedIndex = data[self:_progressKey(player)].step
    local completedStep = self:_courseConfig(player).steps[completedIndex]
    local progress, changed =
        TutorialFlow.advance(self:_courseConfig(player), data[self:_progressKey(player)], name, ctx)
    if not changed then
        if name == "enemy_defeated" then
            self:_maybeClearRoom(player)
        end
        return
    end
    data[self:_progressKey(player)] = progress
    if progress.done then
        local completion = self:_courseConfig(player).completion or {}
        local earned = self._playerProgressionService
                and self._playerProgressionService:GetEarnedLevel(player)
            or player:GetAttribute("Level")
            or 1
        local target = CombatCourses.levelTarget(completion, earned, self._courses.level_cap)
        if completion.apply_level_grant == true and target > 1 then
            -- Persist the target reached by this genuine completion. The independent grant
            -- receipt can safely retry later without depending on future config changes.
            data[self:_progressKey(player)].completionLevelTarget = target
        end
    end
    self._dataService:RequestSave(
        player,
        progress.done and "combat_tutorial_complete" or "combat_tutorial_step",
        {
            critical = progress.done,
        }
    )
    if progress.done then
        player:SetAttribute("CombatTutorialDone", data.CombatTutorial.done == true)
        local active = self._activeCourses[player]
        if not (active and active.replay) then
            self:_applyCompletionReward(player, data)
        end
    end
    if completedStep and (progress.done or progress.step ~= completedIndex) then
        fireGameEvent(player, "tutorial_step_completed", {
            stepId = "combat_" .. tostring(completedStep.id),
            stepIndex = completedIndex,
            track = "combat_tutorial",
            courseId = self:_courseId(player),
        })
        if completedStep.drop_shields then
            self:_dropShields(player)
        end
        -- Rank pops at the pillar; warp after the crest flies so the next door
        -- is the continue path, not a mid-ceremony yank.
        local granted = self:_syncCombatRank(player, data, completedStep.id)
        local function afterRank()
            if not player.Parent or player:GetAttribute("InCombatTutorial") ~= true then
                return
            end
            if completedStep.return_to_exit then
                self:_returnToExit(player)
            elseif completedStep.return_to_lobby then
                self:_returnToLobby(player)
            end
        end
        if granted then
            local knobs = self._ranksConfig.ceremony
            local delay = (tonumber(knobs and knobs.hold_seconds) or 0.7)
                + (tonumber(knobs and knobs.fly_seconds) or 0.85)
            task.delay(delay, afterRank)
        else
            afterRank()
        end
    end
    self:_applyStepSideEffects(player, data, false)
    self:_push(player)
    self:_ensureWatchers(player)
    if name == "enemy_defeated" then
        self:_maybeClearRoom(player)
    end
end

function CombatTutorialService:_anyLiveTutorialEnemy()
    for _, model in ipairs(tutorialEnemies()) do
        if (tonumber(model:GetAttribute("HP")) or 0) > 0 then
            return true
        end
    end
    return false
end

function CombatTutorialService:_maybeClearRoom(player)
    local data = self:_ensureProgress(player)
    local step = data
        and TutorialFlow.current(self:_courseConfig(player), data[self:_progressKey(player)])
    if
        not (step and step.complete_on and step.complete_on.event == "combat_tutorial_room_cleared")
    then
        return
    end
    local session = self:_session(player)
    -- Do not treat "I cannot see a dog" as a clear while this step still has to
    -- spawn. Finish rooms inherit the previous pack; a leftover despawn or a
    -- Stop/Play rejoin can leave the field empty with no spawn table.
    if self:_anyLiveTutorialEnemy() then
        return
    end
    if session.packSpawned ~= true and type(step.spawn) == "table" then
        return
    end
    session.packSpawned = false
    session.packRemaining = 0
    fireGameEvent(player, "combat_tutorial_room_cleared", { source = "arena" })
end

function CombatTutorialService:_unlockSnapshot(player, data)
    local items = data and data.Inventory and data.Inventory.pets and data.Inventory.pets.items
    local equipped = data and data.Equipped and data.Equipped.pets
    local maxSlots = tonumber(player:GetAttribute("PetEquipSlots"))
    if not maxSlots and self._inventoryService and self._inventoryService.GetPetEquipMaxSlots then
        maxSlots = self._inventoryService:GetPetEquipMaxSlots(player)
    end
    maxSlots = math.max(0, math.floor(tonumber(maxSlots) or 0))
    local roles = self._petRoles or {}
    return {
        hotbar = data and data.Hotbar,
        hotbarEditing = player:GetAttribute("HotbarEditing") == true,
        equippedSlots = PetInventoryView.resolveEquipped(items, equipped, maxSlots),
        maxSlots = maxSlots,
        rolesByType = roles.by_type or {},
        defaultRole = roles.default or "melee",
    }
end

function CombatTutorialService:_enterUnlockList(step)
    local door = self._config and self._config.door
    return TutorialUnlock.concat(door and door.unlock_when, step and step.unlock_when)
end

function CombatTutorialService:_firstUnlockFailure(player, conditions)
    if not self._dataService:IsDataLoaded(player) then
        return { fail_nudge = "Finish this first!", fail_plate = "WAIT" }
    end
    local data = self:_ensureProgress(player)
    return TutorialUnlock.firstFailure(conditions, self:_unlockSnapshot(player, data))
end

function CombatTutorialService:_tryFinishUnlockWhen(player, source)
    if player:GetAttribute("InCombatTutorial") ~= true then
        return
    end
    if not self._dataService:IsDataLoaded(player) then
        return
    end
    local data = self:_ensureProgress(player)
    local step = data
        and TutorialFlow.current(self:_courseConfig(player), data[self:_progressKey(player)])
    if not (step and type(step.unlock_when) == "table") then
        return
    end
    if not TutorialUnlock.allMet(step.unlock_when, self:_unlockSnapshot(player, data)) then
        return
    end
    local eventName = step.complete_on and step.complete_on.event
    if type(eventName) ~= "string" then
        return
    end
    local session = self:_session(player)
    if session.unlockFired == step.id then
        return
    end
    session.unlockFired = step.id
    fireGameEvent(player, eventName, {
        source = source or "unlock_when",
        power = "heal",
    })
end

function CombatTutorialService:_tryFinishBindHeal(player, source)
    self:_tryFinishUnlockWhen(player, source)
end

function CombatTutorialService:_onUnlockStateChanged(player, source)
    if player:GetAttribute("InCombatTutorial") ~= true then
        return
    end
    self:_applyDoorPlate(player)
    self:_tryFinishUnlockWhen(player, source)
end

function CombatTutorialService:_onHotbarDone(player)
    self:_onUnlockStateChanged(player, "hotbar_done")
end

function CombatTutorialService:_applyStepSideEffects(player, data, isEnter)
    if not (data and data[self:_progressKey(player)]) then
        return
    end
    local step = TutorialFlow.current(self:_courseConfig(player), data[self:_progressKey(player)])
    if not step then
        return
    end
    self:_applyGrant(player, data, step)
    if type(step.theme) == "string" and step.theme ~= "" then
        local missions = self._missionInstanceService
        if missions and missions.RepaintTheme then
            missions:RepaintTheme(player, step.theme)
        end
    end
    if step.reset_squad == true then
        self:_resetAuthoredSquad(player, step)
    end
    if type(step.ensure_meter) == "table" then
        self:_ensureMeter(player, step.ensure_meter)
    end
    if type(step.unlock_when) == "table" then
        self:_tryFinishUnlockWhen(player, "already_met")
    end
    if isEnter or type(step.spawn) == "table" then
        self:_spawnForStep(player, step)
    end
    if step.complete_on and step.complete_on.event == "combat_tutorial_room_cleared" then
        self:_maybeClearRoom(player)
    end
    if self:_doorShouldLock(player, data[self:_progressKey(player)]) then
        self:_sealDoors(player)
    else
        self:_unsealDoors(player)
    end
    self:_setBeaconActive(player, step.activate_beacon == true)
    self:_applyDoorPlate(player)
    self:_syncLobbyLeavePrompt(player)
end

function CombatTutorialService:_doorShouldLock(player, progress)
    local step = TutorialFlow.current(self:_courseConfig(player), progress)
    if step and step.lock_door == true then
        return true
    end
    local index = tonumber(progress and progress.step) or 1
    for i, authored in ipairs(self:_courseConfig(player).steps or {}) do
        if authored.unlock_door then
            return index <= i
        end
    end
    return false
end

function CombatTutorialService:_applyGrant(player, data, step)
    local grant = step and step.grant
    if type(grant) ~= "table" then
        return
    end
    local id = step.id or tostring(data[self:_progressKey(player)].step)
    data[self:_progressKey(player)].granted = data[self:_progressKey(player)].granted or {}
    if data[self:_progressKey(player)].granted[id] then
        return
    end
    data[self:_progressKey(player)].granted[id] = true
    local grantFailed = false
    if type(grant.potions) == "table" then
        local potions = self._potionService
        if potions and potions.Grant then
            for _, g in ipairs(grant.potions) do
                pcall(function()
                    potions:Grant(player, g.id, g.count or 1)
                end)
            end
        elseif self._logger then
            self._logger:Warn(
                "combat tutorial potion grant SKIPPED — PotionService not injected",
                {
                    step = tostring(step.id),
                }
            )
        end
    end
    if type(grant.enhancements) == "table" then
        local enhancements = self._enhancementService
        if enhancements and enhancements.Grant then
            for _, enhancement in ipairs(grant.enhancements) do
                for _ = 1, math.max(1, math.floor(tonumber(enhancement.count) or 1)) do
                    local ok, result = pcall(function()
                        return enhancements:Grant(player, {
                            type = enhancement.type,
                            origins = enhancement.origins or {},
                            level = enhancement.level or 1,
                        })
                    end)
                    if not ok or (type(result) == "table" and result.ok == false) then
                        grantFailed = true
                        if self._logger then
                            self._logger:Warn("combat tutorial enhancement grant FAILED", {
                                player = player.Name,
                                enhancement = tostring(enhancement.type),
                                err = not ok and tostring(result)
                                    or tostring(result and result.reason),
                            })
                        end
                    end
                end
            end
        else
            grantFailed = true
            if self._logger then
                self._logger:Warn(
                    "combat tutorial enhancement grant SKIPPED — EnhancementService not injected",
                    { step = tostring(step.id) }
                )
            end
        end
    end
    if type(grant.ensure_slot) == "string" then
        data.Slots = type(data.Slots) == "table" and data.Slots or {}
        local slots = data.Slots[grant.ensure_slot]
        if type(slots) ~= "table" or #slots == 0 then
            data.Slots[grant.ensure_slot] = { { inherent = true } }
        end
    end
    if grantFailed then
        data[self:_progressKey(player)].granted[id] = nil
    end
    self._dataService:RequestSave(player, "combat_tutorial_grant", { critical = true })
end

function CombatTutorialService:_grantPotions(player, potions)
    if type(potions) ~= "table" then
        return
    end
    local service = self._potionService
    if not (service and service.Grant) then
        return
    end
    for _, g in ipairs(potions) do
        pcall(function()
            service:Grant(player, g.id, g.count or 1)
        end)
    end
end

-- Combat Training owns its own earned-level floor. Keep this receipt separate from the
-- currencies/potions receipt below: if progression is temporarily unavailable, a completed
-- track must retry the exact, monotonic top-up on the next state pull or join instead of losing
-- Level 2 because the other rewards were already marked delivered.
function CombatTutorialService:_applyCompletionLevelGrant(player, data, courseId)
    local tutorial = data and data[self:_progressKey(player, courseId)]
    if not (tutorial and tutorial.done) or tutorial.completionLevelGranted == true then
        return
    end

    local completion = self:_courseConfig(player, courseId).completion or {}
    local configuredTarget
    if completion.apply_level_grant == true then
        configuredTarget = tonumber(completion.grant_earned_level)
    end
    local target = math.floor(tonumber(tutorial.completionLevelTarget) or configuredTarget or 0)
    if target <= 1 then
        return
    end

    local progression = self._playerProgressionService
    if not (progression and progression.EnsureEarnedLevel) then
        if self._logger then
            self._logger:Warn("combat tutorial completion level grant deferred", {
                player = player.Name,
                targetLevel = target,
                reason = "PlayerProgressionService unavailable",
            })
        end
        return
    end

    local ok, result = pcall(function()
        return progression:EnsureEarnedLevel(player, target)
    end)
    if not ok or type(result) ~= "table" then
        if self._logger then
            self._logger:Warn("combat tutorial completion level grant failed", {
                player = player.Name,
                targetLevel = target,
                error = tostring(result),
            })
        end
        return
    end

    if progression.GetEarnedLevel then
        local verified, earned = pcall(function()
            return progression:GetEarnedLevel(player)
        end)
        if not verified or (tonumber(earned) or 0) < target then
            if self._logger then
                self._logger:Warn("combat tutorial completion level grant not yet visible", {
                    player = player.Name,
                    targetLevel = target,
                    earnedLevel = tonumber(earned) or 0,
                })
            end
            return
        end
    end

    tutorial.completionLevelGranted = true
    self._dataService:RequestSave(player, "combat_tutorial_completion_level", { critical = true })
end

function CombatTutorialService:_applyCompletionReward(player, data, courseId)
    local completion = self:_courseConfig(player, courseId).completion
    if type(completion) ~= "table" or not data then
        return
    end

    -- This remains callable after the one-time item reward is delivered so a transient
    -- progression failure cannot strand a completed player below earned Level 2.
    local key = self:_progressKey(player, courseId)
    local rewardKey = key .. "RewardGranted"
    self._rewardInFlight = self._rewardInFlight or setmetatable({}, { __mode = "k" })
    local inflight = self._rewardInFlight[player] or {}
    self._rewardInFlight[player] = inflight
    if inflight[key] then
        return
    end
    inflight[key] = true
    self:_applyCompletionLevelGrant(player, data, courseId)
    if data[rewardKey] == true then
        inflight[key] = nil
        return
    end

    local grant = completion.grant
    if type(grant) == "table" then
        if not (self._rewardService and self._rewardService.Grant) then
            inflight[key] = nil
            return
        end
        local ok = pcall(function()
            local result = self._rewardService:Grant(
                player,
                grant,
                "combat_course_" .. (courseId or self:_courseId(player))
            )
            -- A successful call can still contain an inventory rejection (e.g. no space).
            -- Advanced rewards contain one token, so retry only until its UID is confirmed.
            if type(grant.items) == "table" then
                assert(result and result.ok and result.granted, "Course reward failed")
                for index in ipairs(grant.items) do
                    assert(
                        result.granted.items[index] and result.granted.items[index].uid,
                        "Course token not delivered"
                    )
                end
            end
            self:_grantPotions(player, grant.potions)
        end)
        if not ok then
            inflight[key] = nil
            return
        end
    end
    data[rewardKey] = true
    inflight[key] = nil
    fireGameEvent(
        player,
        key == "CombatTutorial" and "combat_tutorial_complete" or "combat_advanced_complete",
        {
            name = completion.banner or "Combat training complete!",
            courseId = courseId or self:_courseId(player),
        }
    )
    self._dataService:RequestSave(player, "combat_tutorial_reward", { critical = true })
end

function CombatTutorialService:_resetAuthoredSquad(player, step)
    local session = self:_session(player)
    local key = step and step.id
    if type(key) ~= "string" or key == "" then
        return
    end
    if session.squadReset == key then
        return
    end
    session.squadReset = key
    self:_applyAuthoredSquad(player)
end

function CombatTutorialService:_applyAuthoredSquad(player)
    if not (self._inventoryService and self._inventoryService.ReplaceEquippedPets) then
        return
    end
    local maxSlots = 0
    if self._inventoryService.GetPetEquipMaxSlots then
        maxSlots = self._inventoryService:GetPetEquipMaxSlots(player)
    end
    maxSlots = math.max(0, math.floor(tonumber(maxSlots) or 0))
    self._inventoryService:ReplaceEquippedPets(
        player,
        TutorialSquad.equipRefs(self._config, maxSlots),
        {
            force = true,
            ignoreLocks = true,
        }
    )
end

function CombatTutorialService:_ensureMeter(player, spec)
    if type(spec) ~= "table" or type(spec.id) ~= "string" then
        return
    end
    local potions = self._potionService
    if not (potions and potions.EnsureCharge) then
        return
    end
    potions:EnsureCharge(player, spec.id, spec.min_charge)
end

function CombatTutorialService:_enemyDef(unit)
    local authored = (self._config and self._config.enemy) or {}
    local enemyId = (unit and unit.id) or authored.id or "lava_imp"
    local catalog = self._enemiesConfig and self._enemiesConfig.enemies or {}
    local base = catalog[enemyId] or catalog.lava_imp or {}
    local def = cloneDef(base)
    if not (unit and unit.id) then
        def.display_name = authored.display_name or def.display_name
        if authored.hp then
            def.hp = authored.hp
        end
        if authored.move_speed then
            def.move_speed = authored.move_speed
        end
        if authored.armor ~= nil then
            def.armor = authored.armor
        end
        if type(authored.attack) == "table" then
            def.attack = table.clone(authored.attack)
        end
    end
    if type(unit) == "table" then
        if unit.display_name then
            def.display_name = unit.display_name
        end
        if unit.hp then
            def.hp = unit.hp
        end
        if unit.level then
            def.level = unit.level
        end
        if type(unit.auto_heal) == "table" then
            def.auto_heal = table.clone(unit.auto_heal)
        end
        if type(unit.attack) == "table" then
            def.attack = table.clone(unit.attack)
        end
    end
    local cap = (self._config and self._config.pack_cap) or {}
    def.level = math.max(1, math.floor(tonumber(unit and unit.level or cap.enemy_level) or 1))
    return def, enemyId
end

function CombatTutorialService:_spawnPosition(player, where)
    local record, container = self:_missionContainer(player)
    if where == "arena" then
        local pad = missionSpawnOf(record)
        if not pad and container then
            for _, desc in ipairs(container:GetDescendants()) do
                if desc.Name == "MissionSpawn" and desc:IsA("BasePart") then
                    if desc:GetAttribute("ObjectiveRoom") then
                        pad = desc
                        break
                    end
                    pad = pad or desc
                end
            end
        end
        if pad then
            return pad.Position + Vector3.new(0, 3, 0)
        end
    end
    local spawn = spawnPadOf(record)
    if not spawn and container then
        local named = container:FindFirstChild("SpawnPad", true)
        if named and named:IsA("BasePart") then
            spawn = named
        end
    end
    if spawn then
        return spawn.Position + Vector3.new(8, 3, 0)
    end
    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    return root and (root.Position + root.CFrame.LookVector * 10 + Vector3.new(0, 3, 0))
end

function CombatTutorialService:_applyShield(model)
    local shield = self._config.shield or {}
    local pool = tonumber(shield.pool) or 0
    if pool <= 0 then
        return
    end
    model:SetAttribute("CombatShield", pool)
    model:SetAttribute(
        "CombatShieldUntil",
        os.time() + math.max(1, tonumber(shield.duration) or 1800)
    )
    model:SetAttribute("CombatShieldPowerId", shield.power_id or "dune_shield")
end

-- One-shot Dune Shield: same 400 / 12s as a pet cast. Not CombatTutorialShielded,
-- so the mark loop cannot refresh it into invulnerability.
function CombatTutorialService:_applyCombatAbsorb(model)
    local look = self._config.combat_shield or {}
    local pool = tonumber(look.pool) or 400
    if pool <= 0 then
        return
    end
    model:SetAttribute("CombatShield", pool)
    local duration = tonumber(look.duration) or 12
    if duration > 0 then
        model:SetAttribute("CombatShieldUntil", os.time() + math.max(1, duration))
    else
        model:SetAttribute("CombatShieldUntil", 0)
    end
    model:SetAttribute("CombatShieldPowerId", look.power_id or "dune_shield")
end

function CombatTutorialService:_woundForStep(player, step)
    local spec = step and step.wound
    if type(spec) ~= "table" then
        return nil
    end
    local session = self:_session(player)
    local pet, slot
    if session.woundedSlot then
        pet = petForSlot(player, session.woundedSlot)
        slot = session.woundedSlot
        if not (pet and pet.Parent) or pet:GetAttribute("CombatDowned") == true then
            pet, slot = firstLivePet(player)
        end
    else
        pet, slot = firstLivePet(player)
    end
    if not (pet and slot) then
        return nil
    end
    local factor = (self._combatConfig and self._combatConfig.pet_down_threshold_factor) or 10
    local remaining = tonumber(spec.remaining_fraction) or 0.45
    local taken = PetEndurance.takenForHealthFraction(petPowerOf(pet), factor, remaining)
    local current = tonumber(pet:GetAttribute("CombatDamageTaken")) or 0
    if current < taken then
        pet:SetAttribute("CombatDamageTaken", taken)
    end
    if self._enemyService and self._enemyService.NotePetHit then
        self._enemyService:NotePetHit(pet)
    end
    session.woundedSlot = slot
    player:SetAttribute("CombatTutorialWoundSlot", slot)
    if not session.woundSelectionCleared then
        -- Same-value SetAttribute does not fire Changed; drop a stale pick so they must click.
        player:SetAttribute("CombatBuffTarget", 0)
        session.woundSelectionCleared = true
    end
    return slot
end

function CombatTutorialService:_spawnForStep(player, step)
    local spec = step and step.spawn
    if type(spec) ~= "table" then
        return
    end
    local session = self:_session(player)
    local key = step.id
    if session.spawned[key] then
        return
    end
    local enemySvc = self._enemyService
    if not (enemySvc and enemySvc.SpawnEnemy) then
        return
    end
    self:_despawnTutorialEnemies(player)
    session.shielded = {}
    session.packSpawned = false
    session.packRemaining = 0
    local units = TutorialPack.clamp(expandSpawnUnits(spec), self._config and self._config.pack_cap)
    local where = spec.where or "entry"
    for i, unit in ipairs(units) do
        local def, enemyId = self:_enemyDef(unit)
        local position = self:_spawnPosition(player, where)
        if not position then
            break
        end
        if i > 1 then
            position = position + Vector3.new((i - 1) * 6, 0, 0)
        end
        local result = enemySvc:SpawnEnemy(player, enemyId, {
            def = def,
            position = position,
            home = position,
            ungated = true,
            persistent = true,
            ignoreEnemyLevelOffset = true,
        })
        if result and result.ok and result.model then
            result.model:SetAttribute("CombatTutorialEnemy", true)
            result.model:SetAttribute("CombatTutorialOwner", player.UserId)
            result.model:SetAttribute(
                "CombatTutorialRole",
                type(unit.auto_heal) == "table" and "healer" or "other"
            )
            if unit.shield then
                result.model:SetAttribute("CombatTutorialShielded", true)
                self:_applyShield(result.model)
                session.shielded = session.shielded or {}
                table.insert(session.shielded, result.model)
            elseif unit.absorb then
                self:_applyCombatAbsorb(result.model)
            end
            if unit.mark then
                result.model:SetAttribute("CombatTutorialMark", true)
            end
            session.packSpawned = true
            session.packRemaining = (tonumber(session.packRemaining) or 0) + 1
        else
            return
        end
    end
    session.spawned[key] = true
    self:_enforceLivePackCap(player)
end

function CombatTutorialService:_dropShields(player)
    local session = self._sessions[player]
    local models = session and session.shielded or {}
    for _, model in ipairs(models) do
        if model and model.Parent then
            model:SetAttribute("CombatShield", 0)
            model:SetAttribute("CombatShieldUntil", 0)
            model:SetAttribute("CombatShieldPowerId", nil)
        end
    end
    if session then
        session.shielded = {}
    end
    for _, model in ipairs(tutorialEnemies()) do
        model:SetAttribute("CombatShield", 0)
        model:SetAttribute("CombatShieldUntil", 0)
        model:SetAttribute("CombatShieldPowerId", nil)
    end
end

function CombatTutorialService:_markTargetEnemy(player)
    local session = self:_session(player)
    local chosen
    if session.targetEnemyBid then
        for _, model in ipairs(tutorialEnemies()) do
            if enemyBreakableId(model) == session.targetEnemyBid then
                if (tonumber(model:GetAttribute("HP")) or 0) > 0 then
                    chosen = model
                end
                break
            end
        end
    end
    if not chosen then
        for _, model in ipairs(tutorialEnemies()) do
            if
                (tonumber(model:GetAttribute("HP")) or 0) > 0
                and model:GetAttribute("CombatTutorialMark") == true
            then
                chosen = model
                break
            end
        end
    end
    local data = self._dataService:GetData(player)
    local step = data
        and TutorialFlow.current(self:_courseConfig(player), data[self:_progressKey(player)])
    -- Healer hunt: never retarget a leftover dog after the marked healer dies.
    -- That would leave KILL THIS on a card that is not the healer (Jason).
    if not chosen and not stepWantsHealerFocus(step) then
        for _, model in ipairs(tutorialEnemies()) do
            if (tonumber(model:GetAttribute("HP")) or 0) > 0 then
                chosen = model
                break
            end
        end
    end
    if not chosen then
        if stepWantsHealerFocus(step) then
            player:SetAttribute("CombatTutorialTargetEnemy", nil)
            self:_setHealerCue(player, false)
        end
        return nil
    end
    local bid = enemyBreakableId(chosen)
    if not bid then
        return nil
    end
    local function keepShield(model)
        return model:GetAttribute("CombatTutorialShielded") == true
    end
    session.shielded = session.shielded or {}
    if keepShield(chosen) then
        self:_applyShield(chosen)
        local already
        for _, model in ipairs(session.shielded) do
            if model == chosen then
                already = true
                break
            end
        end
        if not already then
            table.insert(session.shielded, chosen)
        end
    end
    -- Re-stamp only dogs that spawned shielded so a healer hunt stays killable.
    for _, model in ipairs(tutorialEnemies()) do
        if
            model ~= chosen
            and (tonumber(model:GetAttribute("HP")) or 0) > 0
            and keepShield(model)
        then
            self:_applyShield(model)
            local listed
            for _, tracked in ipairs(session.shielded) do
                if tracked == model then
                    listed = true
                    break
                end
            end
            if not listed then
                table.insert(session.shielded, model)
            end
        end
    end
    session.targetEnemyBid = bid
    player:SetAttribute("CombatTutorialTargetEnemy", bid)
    if not session.enemySelectionCleared then
        player:SetAttribute("CombatAssistTarget", 0)
        session.enemySelectionCleared = true
    end
    return bid
end

function CombatTutorialService:_setHealerCue(player, show)
    if not player.Parent then
        return
    end
    local value = show == true
    if player:GetAttribute("CombatTutorialHealerCue") == value then
        return
    end
    player:SetAttribute("CombatTutorialHealerCue", value)
end

-- Click hides KILL THIS. Pets already swinging the healer also hide it (they
-- can auto-pick). A dead healer never asks for another click — the card is gone.
function CombatTutorialService:_updateHealerFocus(player, justClicked)
    local data = self._dataService:GetData(player)
    local step = data
        and TutorialFlow.current(self:_courseConfig(player), data[self:_progressKey(player)])
    if not stepWantsHealerFocus(step) then
        return
    end
    local session = self:_session(player)
    local bid = session.targetEnemyBid
    local focus, actions = HealerFocus.tick({
        committed = session.healerCommitted,
        engaged = session.healerEngaged,
        lost = session.healerLost,
        cue = player:GetAttribute("CombatTutorialHealerCue") == true,
    }, {
        alive = bid ~= nil and tutorialEnemyAlive(bid),
        attacking = bid ~= nil and petsAttackingBid(player, bid) > 0,
        justClicked = justClicked == true,
    })
    session.healerCommitted = focus.committed
    session.healerEngaged = focus.engaged
    session.healerLost = focus.lost
    if justClicked == true and bid and tutorialEnemyAlive(bid) then
        local pin = type(step.healer_focus) == "table" and step.healer_focus or {}
        local enemySvc = self._enemyService
        if enemySvc and enemySvc.FocusSquadOnEnemy then
            enemySvc:FocusSquadOnEnemy(player, bid, {
                pinSeconds = tonumber(pin.pin_seconds) or 600,
                threat = tonumber(pin.threat) or 10000,
            })
        end
    end
    self:_setHealerCue(player, focus.cue)
    if not focus.cue and bid and not tutorialEnemyAlive(bid) then
        player:SetAttribute("CombatTutorialTargetEnemy", nil)
        if (tonumber(player:GetAttribute("CombatAssistTarget")) or 0) == bid then
            player:SetAttribute("CombatAssistTarget", 0)
        end
    end
    if actions.lost_banner then
        fireGameEvent(player, "combat_tutorial_healer_lost", {
            name = step.lost_banner or "Your pets left the healer! Click it again.",
        })
    end
end

function CombatTutorialService:_doorLook()
    local look = (self._config.door and self._config.door.look) or {}
    return {
        material = Enum.Material[look.material or "Ice"] or Enum.Material.Ice,
        color = look.color or { 198, 220, 236 },
        transparency = tonumber(look.transparency) or 0.08,
        reflectance = tonumber(look.reflectance) or 0.12,
    }
end

function CombatTutorialService:_decorateDoorButton(button, action, look)
    look = look or {}
    button.BackgroundTransparency = 0.05
    button.BorderSizePixel = 0
    button.AutoButtonColor = true
    button.Font = Enum.Font.GothamBlack
    button.TextScaled = true
    button.BackgroundColor3 = look.color or Color3.fromRGB(232, 176, 48)
    button.TextColor3 = look.text_color or Color3.fromRGB(64, 46, 8)
    button:SetAttribute("DoorAction", action)
    CollectionService:AddTag(button, DOOR_ACTION_TAG)

    if not button:FindFirstChildOfClass("UICorner") then
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0.5, 0)
        corner.Parent = button
    end
    if not button:FindFirstChildOfClass("UIStroke") then
        local stroke = Instance.new("UIStroke")
        stroke.Thickness = 3
        stroke.Color = look.stroke or Color3.fromRGB(120, 78, 8)
        stroke.Parent = button
    end
    if not button:FindFirstChildOfClass("UIPadding") then
        local pad = Instance.new("UIPadding")
        pad.PaddingLeft = UDim.new(0.08, 0)
        pad.PaddingRight = UDim.new(0.08, 0)
        pad.PaddingTop = UDim.new(0.16, 0)
        pad.PaddingBottom = UDim.new(0.16, 0)
        pad.Parent = button
    end
    return button
end

function CombatTutorialService:_stampDoorSurface(slab, face, kind, yScale, height, look)
    local buttonCfg = (self._config.door and self._config.door.button) or {}
    local name = "CombatTutorial" .. kind .. "_" .. face.Name
    local existing = slab:FindFirstChild(name)
    if existing then
        existing:Destroy()
    end
    local legacy = slab:FindFirstChild("CombatTutorialEnter_" .. face.Name)
    if legacy then
        legacy:Destroy()
    end

    local pps = tonumber(buttonCfg.pixels_per_stud) or 40
    local widthStuds = (tonumber(buttonCfg.width) or 420) / pps
    local heightStuds = height / pps
    local normal = Vector3.FromNormalId(face)
    local extent = math.abs(normal.X) * slab.Size.X * 0.5
        + math.abs(normal.Y) * slab.Size.Y * 0.5
        + math.abs(normal.Z) * slab.Size.Z * 0.5
    local y = (0.5 - yScale) * slab.Size.Y
    local plate = Instance.new("Part")
    plate.Name = name
    plate.Size = Vector3.new(widthStuds, heightStuds, 0.2)
    plate.CFrame = CFrame.lookAt(
        slab.CFrame * (normal * (extent + 0.12) + Vector3.new(0, y, 0)),
        slab.CFrame * (normal * (extent + 1.12) + Vector3.new(0, y, 0)),
        slab.CFrame.UpVector
    )
    plate.Anchored = true
    plate.CanCollide = false
    plate.CanQuery = true
    plate.CanTouch = false
    plate.CastShadow = false
    plate.Transparency = 1
    plate.Parent = slab

    -- Visual only. Active SurfaceGuis on the full door ate READY clicks.
    local gui = Instance.new("SurfaceGui")
    gui.Name = name
    gui.Face = Enum.NormalId.Front
    gui.AlwaysOnTop = false
    gui.LightInfluence = 0
    gui.Active = false
    gui.ResetOnSpawn = false
    gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    gui.PixelsPerStud = pps
    gui.Parent = plate

    local button = Instance.new("TextButton")
    button.Name = kind
    button.Size = UDim2.fromScale(1, 1)
    button.Text = look.text
    button.Parent = gui
    self:_decorateDoorButton(button, look.action, look)

    local click = Instance.new("ClickDetector")
    click.Name = "CombatTutorialDoorClick"
    click.MaxActivationDistance = 24
    click.Parent = plate
    click.MouseClick:Connect(function(player)
        self:_onDoorAction(player, look.action)
    end)
end

function CombatTutorialService:_stampEnterButton(slab, face)
    local buttonCfg = (self._config.door and self._config.door.button) or {}
    local lessonH = tonumber(buttonCfg.height) or 110
    local leaveH = tonumber(buttonCfg.leave_height) or 72
    local gap = tonumber(buttonCfg.leave_gap) or 18
    -- SurfaceGui Y=0 is the top of the face. Lesson pill at chest height;
    -- Continue later is its own SurfaceGui just below.
    local fromFloor = tonumber(buttonCfg.height_from_floor) or 5
    local y = 1 - math.clamp(fromFloor / math.max(slab.Size.Y, 1), 0.18, 0.72)
    local facePx = math.max(slab.Size.Y, 1) * (tonumber(buttonCfg.pixels_per_stud) or 40)
    local leaveY = math.clamp(y + (lessonH * 0.5 + gap + leaveH * 0.5) / facePx, 0.2, 0.94)

    self:_stampDoorSurface(slab, face, "Lesson", y, lessonH, {
        action = "lesson",
        text = tostring(buttonCfg.text or "ENTER"),
        color = Color3.fromRGB(232, 176, 48),
        text_color = Color3.fromRGB(64, 46, 8),
        stroke = Color3.fromRGB(120, 78, 8),
    })
    self:_stampDoorSurface(slab, face, "Leave", leaveY, leaveH, {
        action = "leave",
        text = self:_leaveButtonText(),
        color = Color3.fromRGB(48, 52, 68),
        text_color = Color3.fromRGB(230, 230, 236),
        stroke = Color3.fromRGB(18, 20, 28),
    })
end

function CombatTutorialService:_dressSeal(slab)
    local look = self:_doorLook()
    local color = look.color
    slab.Material = look.material
    slab.Color = Color3.fromRGB(color[1] or 198, color[2] or 220, color[3] or 236)
    slab.Transparency = look.transparency
    slab.Reflectance = look.reflectance
    slab.Anchored = true
    slab.CanCollide = true
    slab.CanTouch = true
    slab.CanQuery = true
    slab.CastShadow = false

    self:_stampEnterButton(slab, Enum.NormalId.Front)
    self:_stampEnterButton(slab, Enum.NormalId.Back)
    local leftoverBillboard = slab:FindFirstChild("CombatTutorialDoorBillboard")
    if leftoverBillboard then
        leftoverBillboard:Destroy()
    end
    local click = slab:FindFirstChildOfClass("ClickDetector")
    if click then
        click:Destroy()
    end
end

function CombatTutorialService:_currentStep(player)
    if not self._dataService:IsDataLoaded(player) then
        return nil
    end
    local data = self:_ensureProgress(player)
    return data
        and TutorialFlow.current(self:_courseConfig(player), data[self:_progressKey(player)])
end

function CombatTutorialService:_stepAcceptsEnter(player)
    local step = self:_currentStep(player)
    if
        not (
            step
            and step.complete_on
            and step.complete_on.event == "combat_tutorial_entered_arena"
        )
    then
        return false
    end
    return self:_firstUnlockFailure(player, self:_enterUnlockList(step)) == nil
end

function CombatTutorialService:_doorPlateForPlayer(player)
    local step = self:_currentStep(player)
    local buttonCfg = (self._config.door and self._config.door.button) or {}
    local data = self._dataService and self._dataService:GetData(player)
    local remainingText, remainingNudge =
        TutorialFlow.doorButtonCopy(step, data and data[self:_progressKey(player)])
    if self:_stepAcceptsEnter(player) then
        return {
            pulse = true,
            enter_text = tostring(buttonCfg.text or "ENTER"),
            ready_text = tostring(buttonCfg.ready_text or "READY"),
            pulse_seconds = math.max(0.35, tonumber(buttonCfg.pulse_seconds) or 0.7),
            color = Color3.fromRGB(232, 176, 48),
            text_color = Color3.fromRGB(64, 46, 8),
        }
    end
    local failed = self:_firstUnlockFailure(player, self:_enterUnlockList(step))
    return {
        pulse = false,
        text = tostring(
            (failed and failed.fail_plate) or remainingText or buttonCfg.text or "ENTER"
        ),
        nudge = (failed and failed.fail_nudge) or remainingNudge or "Finish this first!",
        color = Color3.fromRGB(176, 86, 42),
        text_color = Color3.fromRGB(255, 236, 210),
    }
end

function CombatTutorialService:_forEachDoorDescendant(player, fn)
    local _, container = self:_missionContainer(player)
    if not container then
        return
    end
    for _, desc in ipairs(container:GetDescendants()) do
        if desc.Name == DOOR_SEAL_NAME then
            for _, child in ipairs(desc:GetDescendants()) do
                fn(child)
            end
        end
    end
end

function CombatTutorialService:_forEachDoorButton(player, fn)
    self:_forEachDoorDescendant(player, function(child)
        if child:IsA("TextButton") and child.Name == "Lesson" then
            fn(child)
        end
    end)
end

function CombatTutorialService:_forEachLeaveGui(player, fn)
    self:_forEachDoorDescendant(player, function(child)
        if child:IsA("SurfaceGui") and string.find(child.Name, "^CombatTutorialLeave_") then
            fn(child)
        end
    end)
end

function CombatTutorialService:_paintDoorButtons(player, spec, text)
    self:_forEachDoorButton(player, function(button)
        button.Text = text
        button.BackgroundColor3 = spec.color
        button.TextColor3 = spec.text_color
    end)
end

function CombatTutorialService:_applyDoorPlate(player)
    local spec = self:_doorPlateForPlayer(player)
    local key = spec.pulse and "pulse" or ("text:" .. tostring(spec.text))
    local session = self:_session(player)
    if session.doorPlateKey == key then
        if not spec.pulse then
            self:_paintDoorButtons(player, spec, spec.text)
        end
        return
    end
    session.doorPlateKey = key
    session.doorPulseToken = (session.doorPulseToken or 0) + 1
    if spec.pulse then
        local token = session.doorPulseToken
        task.spawn(function()
            local showReady = true
            while token == session.doorPulseToken and player.Parent do
                self:_paintDoorButtons(
                    player,
                    spec,
                    showReady and spec.ready_text or spec.enter_text
                )
                showReady = not showReady
                task.wait(spec.pulse_seconds)
            end
        end)
        return
    end
    self:_paintDoorButtons(player, spec, spec.text)
end

function CombatTutorialService:_lobbyCFrame(player)
    local record = self._missionInstanceService
        and self._missionInstanceService:GetRecordForPlayer(player)
    local pad = spawnPadOf(record)
    if not (pad and pad.Parent) then
        local _, container = self:_missionContainer(player)
        pad = container and container:FindFirstChild("SpawnPad", true)
    end
    if pad and pad:IsA("BasePart") then
        return pad.CFrame * CFrame.new(0, 4, 0)
    end
    return nil
end

function CombatTutorialService:_warpToLobby(player, originCf)
    if not originCf then
        return
    end
    player:SetAttribute("RallyUntil", os.clock() + 8)
    local character = player.Character
    if character then
        pcall(function()
            character:PivotTo(originCf)
        end)
    end
    local folder = petFolder(player)
    if not folder then
        return
    end
    local i = 0
    for _, model in ipairs(folder:GetChildren()) do
        if model:IsA("Model") then
            i += 1
            pcall(function()
                model:PivotTo(originCf * CFrame.new((i - 3) * 4, 0, 5))
            end)
        end
    end
end

function CombatTutorialService:_refreshLobbyReady(player)
    if not player or self._config.refresh_on_lobby == false then
        return
    end
    if self._powerService and self._powerService.ClearCooldowns then
        self._powerService:ClearCooldowns(player)
    end
    if self._focusService and self._focusService.Restore then
        local maxFocus = tonumber(player:GetAttribute("FocusMax")) or 100
        self._focusService:Restore(player, maxFocus)
    end
    if self._potionService and self._potionService.ClearSipLocks then
        self._potionService:ClearSipLocks(player)
    end
    local data = self._dataService and self._dataService:GetData(player)
    if data then
        data.PetLockouts = PetLockout.clearAll()
        player:SetAttribute("PetLockouts", nil)
    end
    local folder = petFolder(player)
    if not folder then
        return
    end
    for _, model in ipairs(folder:GetChildren()) do
        if model:IsA("Model") and not model:GetAttribute("GhostPet") then
            PetRevive.revive(model, player)
            model:SetAttribute("CombatDamageTaken", 0)
            model:SetAttribute("ResSicknessFloor", nil)
            model:SetAttribute("ResSicknessUntil", nil)
            model:SetAttribute("CooldownUntil", 0)
            model:SetAttribute("ReviveGraceUntil", nil)
        end
    end
end

function CombatTutorialService:_returnToLobby(player)
    local session = self:_session(player)
    session.spawned = {}
    session.shielded = {}
    session.packSpawned = false
    session.packRemaining = 0
    session.squadReset = nil
    self:_despawnTutorialEnemies(player)
    self:_setBeaconActive(player, false)
    self:_resetDoorState(player)
    self:_refreshLobbyReady(player)
    self:_warpToLobby(player, self:_lobbyCFrame(player))
end

function CombatTutorialService:_returnToExit(player)
    local session = self:_session(player)
    session.spawned = {}
    session.shielded = {}
    session.packSpawned = false
    session.packRemaining = 0
    self:_despawnTutorialEnemies(player)
    self:_setBeaconActive(player, false)
    local record = self._missionInstanceService
        and self._missionInstanceService.GetRecordForPlayer
        and self._missionInstanceService:GetRecordForPlayer(player)
    if record and self._missionInstanceService.Complete then
        self._missionInstanceService:Complete(record.instanceId)
        return
    end
    local origin = session.enteredFrom or self:_lobbyCFrame(player)
    self:_warpToLobby(player, origin)
end

function CombatTutorialService:_ensureHomeworldVenue(player)
    local session = self:_session(player)
    if session.venue and session.venue.Parent then
        return session.venue
    end
    local anchor = self:_venueAnchor()
    if not (anchor and anchor:IsA("BasePart")) then
        return nil
    end
    local venueCfg = self._config.venue or {}
    local folder = Instance.new("Folder")
    folder.Name = "CombatTutorialVenue_" .. player.UserId
    local root = workspace:FindFirstChild("Game")
    folder.Parent = root or workspace

    local function stamp(name, offset, size, attrs)
        local part = Instance.new("Part")
        part.Name = name
        part.Anchored = true
        part.CanCollide = false
        part.Transparency = (attrs and attrs.transparency) or 1
        part.Size = size
        part.CFrame = anchor.CFrame * CFrame.new(offset)
        if attrs then
            for key, value in pairs(attrs) do
                if key ~= "transparency" and key ~= "color" then
                    part:SetAttribute(key, value)
                end
            end
            if attrs.color then
                part.Color = attrs.color
            end
        end
        part.Parent = folder
        return part
    end

    stamp("SpawnPad", venueOffset(venueCfg.lobby_offset), Vector3.new(12, 1, 12))
    local doorSize = venueCfg.door_size or { 18, 16, 2 }
    stamp(
        "CombatTutorialDoor",
        venueOffset(venueCfg.door_offset),
        Vector3.new(
            tonumber(doorSize[1]) or 18,
            tonumber(doorSize[2]) or 16,
            tonumber(doorSize[3]) or 2
        ),
        { DoorClass = "frost" }
    )
    stamp(
        "MissionSpawn",
        venueOffset(venueCfg.arena_offset),
        Vector3.new(8, 1, 8),
        { ObjectiveRoom = true }
    )
    local beacon = stamp(
        "ObjectiveBeacon",
        venueOffset(venueCfg.beacon_offset),
        Vector3.new(4, 14, 4),
        { transparency = 0.45, color = Color3.fromRGB(70, 70, 78) }
    )
    beacon.Material = Enum.Material.Neon
    session.venue = folder
    return folder
end

function CombatTutorialService:_destroyHomeworldVenue(player)
    local session = self._sessions[player]
    if session and session.venue then
        session.venue:Destroy()
        session.venue = nil
    end
end

function CombatTutorialService:_missionContainer(player)
    if self:_isHomeworldVenue() then
        local session = self._sessions[player]
        if session and session.venue and session.venue.Parent then
            return nil, session.venue
        end
        if player:GetAttribute("InCombatTutorial") == true then
            return nil, self:_ensureHomeworldVenue(player)
        end
        return nil, nil
    end
    local record = self._missionInstanceService
        and self._missionInstanceService:GetRecordForPlayer(player)
    return record, record and record.container
end

function CombatTutorialService:_objectiveBeacon(player)
    local _, container = self:_missionContainer(player)
    if not container then
        return nil
    end
    local authored = (self._config and self._config.beacon) or {}
    local name = authored.part_name or "ObjectiveBeacon"
    local named = container:FindFirstChild(name, true)
    if named and named:IsA("BasePart") then
        return named
    end
    for _, desc in ipairs(container:GetDescendants()) do
        if desc:IsA("BasePart") and desc:GetAttribute("ObjectiveId") ~= nil then
            return desc
        end
    end
    return nil
end

function CombatTutorialService:_bindAdvancePrompt(player, beacon)
    if not (player and beacon) then
        return
    end
    -- Range / Training Ground keep one MissionCompletePrompt. Destroying
    -- this every cave-door poll rebuilds the default prompt UI and the
    -- COMBAT TRAINING / Advance labels bounce.
    local leftover = beacon:FindFirstChild("MissionCompletePrompt")
    if leftover then
        leftover:Destroy()
    end
    local authored = (self._config and self._config.beacon) or {}
    local prompt = beacon:FindFirstChild(BEACON_PROMPT_NAME)
    if not (prompt and prompt:IsA("ProximityPrompt")) then
        if prompt then
            prompt:Destroy()
        end
        prompt = Instance.new("ProximityPrompt")
        prompt.Name = BEACON_PROMPT_NAME
        prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
        prompt.RequiresLineOfSight = false
        prompt.Triggered:Connect(function(who)
            if who ~= player or player:GetAttribute("InCombatTutorial") ~= true then
                return
            end
            if not self._dataService:IsDataLoaded(player) then
                return
            end
            local data = self:_ensureProgress(player)
            local step = data
                and TutorialFlow.current(
                    self:_courseConfig(player),
                    data[self:_progressKey(player)]
                )
            if not (step and step.activate_beacon) then
                return
            end
            fireGameEvent(player, "combat_tutorial_advance", { source = "objective_beacon" })
        end)
        prompt.Parent = beacon
    end
    prompt.ActionText = tostring(authored.action_text or "Advance")
    prompt.ObjectText = tostring(
        authored.object_text
            or (self._config.entry and self._config.entry.title)
            or "Combat Training"
    )
    prompt.HoldDuration = math.max(0, tonumber(authored.hold_duration) or 0)
    prompt.MaxActivationDistance = math.max(6, tonumber(authored.max_distance) or 12)
    prompt.Enabled = beacon:GetAttribute("ObjectiveActive") == true
    prompt.Parent = beacon
end

function CombatTutorialService:_setBeaconActive(player, active)
    local beacon = self:_objectiveBeacon(player)
    if not beacon then
        return
    end
    if beacon:GetAttribute("ActiveColor") == nil then
        beacon:SetAttribute("ActiveColor", beacon.Color)
    end
    if active then
        beacon:SetAttribute("ObjectiveActive", true)
        local saved = beacon:GetAttribute("ActiveColor")
        if typeof(saved) == "Color3" then
            beacon.Color = saved
        end
        beacon.Transparency = 0
        self:_bindAdvancePrompt(player, beacon)
    else
        beacon:SetAttribute("ObjectiveActive", false)
        beacon.Color = Color3.fromRGB(70, 70, 78)
        beacon.Transparency = 0.5
        local prompt = beacon:FindFirstChild(BEACON_PROMPT_NAME)
        if prompt then
            prompt:Destroy()
        end
    end
end

function CombatTutorialService:_hasDoorSeal(player)
    local _, container = self:_missionContainer(player)
    if not container then
        return false
    end
    return container:FindFirstChild(DOOR_SEAL_NAME, true) ~= nil
end

function CombatTutorialService:_innerDoorParts(container, spawnPos)
    local candidates = {}
    for _, part in ipairs(container:GetDescendants()) do
        if part:IsA("BasePart") and part:GetAttribute("DoorClass") ~= nil then
            table.insert(candidates, part)
        end
    end
    if #candidates == 0 then
        return candidates
    end
    if not spawnPos then
        return { candidates[1] }
    end
    local farthest = candidates[1]
    local bestDist = (farthest.Position - spawnPos).Magnitude
    for i = 2, #candidates do
        local dist = (candidates[i].Position - spawnPos).Magnitude
        if dist > bestDist then
            farthest = candidates[i]
            bestDist = dist
        end
    end
    -- One slab per opening. Training Ground Room 1 stamps the same doorway
    -- on both the entry tile and the objective tile.
    return { farthest }
end

function CombatTutorialService:_resetDoorState(player)
    local _, container = self:_missionContainer(player)
    if not container then
        return
    end
    container:SetAttribute("CombatTutorialDoorsSealed", nil)
    container:SetAttribute("CombatTutorialDoorOpened", nil)
    for _, child in ipairs(container:GetDescendants()) do
        if child.Name == DOOR_SEAL_NAME then
            child:Destroy()
        end
    end
end

function CombatTutorialService:_sealDoors(player)
    local record, container = self:_missionContainer(player)
    if not container then
        return
    end
    if container:GetAttribute("CombatTutorialDoorOpened") then
        return
    end
    if self:_hasDoorSeal(player) then
        container:SetAttribute("CombatTutorialDoorsSealed", true)
        return
    end
    local spawn = spawnPadOf(record)
    local doors = self:_innerDoorParts(container, spawn and spawn.Position)
    if #doors == 0 then
        return
    end
    local created = 0
    for _, part in ipairs(doors) do
        local height = math.max(12, part.Size.Y)
        local width = math.max(8, part.Size.X)
        local slab = Instance.new("Part")
        slab.Name = DOOR_SEAL_NAME
        -- Grow upward from the door's local bottom so extra height does not
        -- punch through the tile floor (centering on DoorClass buried the ENTER plate).
        local doorBottom = part.CFrame * CFrame.new(0, -part.Size.Y / 2, 0)
        slab.Size = Vector3.new(width, height, 2)
        slab.CFrame = doorBottom * CFrame.new(0, height / 2, 0)
        slab.Parent = container
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        -- Floor tiles live in the mission container. Ignore the invisible
        -- DoorClass volume or the slab sits on top of the opening.
        local ignore = { slab }
        if player.Character then
            table.insert(ignore, player.Character)
        end
        for _, descendant in ipairs(container:GetDescendants()) do
            if
                descendant:IsA("BasePart")
                and (
                    descendant:GetAttribute("DoorClass") ~= nil
                    or descendant.Name == DOOR_SEAL_NAME
                )
            then
                table.insert(ignore, descendant)
            end
        end
        params.FilterDescendantsInstances = ignore
        local bottomPos = (slab.CFrame * CFrame.new(0, -height / 2, 0)).Position
        -- DoorClass parts sit centered on Y=0, so the slab bottom is underground.
        -- Probe from well above the opening or the ray starts below the floor.
        local probeY = math.max(bottomPos.Y, part.Position.Y) + 20
        local hit = workspace:Raycast(
            Vector3.new(bottomPos.X, probeY, bottomPos.Z),
            Vector3.new(0, -48, 0),
            params
        )
        if hit then
            slab.CFrame += Vector3.new(0, hit.Position.Y - bottomPos.Y, 0)
        end
        self:_dressSeal(slab)
        created += 1
    end
    if created > 0 then
        container:SetAttribute("CombatTutorialDoorsSealed", true)
    end
end

function CombatTutorialService:_unsealDoors(player)
    local record = self._missionInstanceService
        and self._missionInstanceService:GetRecordForPlayer(player)
    local container = record and record.container
    if not container then
        return
    end
    container:SetAttribute("CombatTutorialDoorsSealed", nil)
    container:SetAttribute("CombatTutorialDoorOpened", true)
    for _, child in ipairs(container:GetDescendants()) do
        if child.Name == DOOR_SEAL_NAME then
            child:Destroy()
        end
    end
end

function CombatTutorialService:_ensureWatchers(player)
    local data = self._dataService:GetData(player)
    local step = data
        and TutorialFlow.current(self:_courseConfig(player), data[self:_progressKey(player)])
    local session = self:_session(player)
    local stepId = step and step.id or nil
    -- Cave-door poll calls _enter every 0.4s while inside. Restarting these
    -- loops would rebuild the pillar prompt like Range never does.
    if stepId and session.watchStepId == stepId then
        if step.activate_beacon == true then
            local beacon = self:_objectiveBeacon(player)
            if beacon and not beacon:FindFirstChild(BEACON_PROMPT_NAME) then
                self:_setBeaconActive(player, true)
            end
        end
        if step.lock_door == true and not self:_hasDoorSeal(player) then
            self:_sealDoors(player)
            self:_applyDoorPlate(player)
        end
        return
    end
    session.watchStepId = stepId
    self:_clearSessionLoops(session)
    if player.Parent then
        player:SetAttribute("CombatTutorialWoundSlot", nil)
        player:SetAttribute("CombatTutorialTargetEnemy", nil)
        player:SetAttribute("CombatTutorialHealerCue", nil)
    end
    session.doorPlateKey = nil
    session.unlockFired = nil
    if session.unlockAttr then
        session.unlockAttr:Disconnect()
        session.unlockAttr = nil
    end
    if player.Parent then
        session.unlockAttr = player:GetAttributeChangedSignal("HotbarEditing"):Connect(function()
            self:_onUnlockStateChanged(player, "hotbar_editing")
        end)
    end
    if not step then
        return
    end
    if step.lock_door == true then
        session.sealToken = (session.sealToken or 0) + 1
        local token = session.sealToken
        task.spawn(function()
            for _ = 1, 20 do
                if token ~= session.sealToken or not player.Parent then
                    return
                end
                if self:_hasDoorSeal(player) then
                    self:_applyDoorPlate(player)
                    return
                end
                local _, container = self:_missionContainer(player)
                if container and container:GetAttribute("CombatTutorialDoorOpened") then
                    return
                end
                self:_sealDoors(player)
                if self:_hasDoorSeal(player) then
                    self:_applyDoorPlate(player)
                    return
                end
                task.wait(0.5)
            end
        end)
    end
    if step.activate_beacon == true then
        session.beaconToken = (session.beaconToken or 0) + 1
        local token = session.beaconToken
        task.spawn(function()
            for _ = 1, 20 do
                if token ~= session.beaconToken or not player.Parent then
                    return
                end
                if self:_objectiveBeacon(player) then
                    self:_setBeaconActive(player, true)
                    return
                end
                task.wait(0.5)
            end
        end)
    end
    if type(step.unlock_when) == "table" or step.lock_door == true then
        session.bindHealToken = (session.bindHealToken or 0) + 1
        local token = session.bindHealToken
        task.spawn(function()
            for _ = 1, 40 do
                if token ~= session.bindHealToken or not player.Parent then
                    return
                end
                self:_onUnlockStateChanged(player, "unlock_watch")
                local data = self._dataService:GetData(player)
                local current = data
                    and TutorialFlow.current(
                        self:_courseConfig(player),
                        data[self:_progressKey(player)]
                    )
                if not current then
                    return
                end
                task.wait(0.5)
            end
        end)
    end
    if type(step.spawn) == "table" then
        session.spawnToken = (session.spawnToken or 0) + 1
        local token = session.spawnToken
        task.spawn(function()
            for _ = 1, 20 do
                if token ~= session.spawnToken or not player.Parent then
                    return
                end
                if session.spawned[step.id] then
                    return
                end
                self:_spawnForStep(player, step)
                task.wait(0.5)
            end
        end)
    end
    if step.complete_on and step.complete_on.event == "combat_tutorial_room_cleared" then
        session.roomClearToken = (session.roomClearToken or 0) + 1
        local token = session.roomClearToken
        task.spawn(function()
            while token == session.roomClearToken and player.Parent do
                self:_maybeClearRoom(player)
                task.wait(0.5)
            end
        end)
    end
    if step.id == "enter_arena" then
        session.heartbeat = RunService.Heartbeat:Connect(function()
            if player:GetAttribute("InCombatTutorial") ~= true then
                return
            end
            local record = self._missionInstanceService
                and self._missionInstanceService:GetRecordForPlayer(player)
            local arena = missionSpawnOf(record)
            local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
            if not (arena and root) then
                return
            end
            if (root.Position - arena.Position).Magnitude <= ARENA_ENTER_STUDS then
                fireGameEvent(player, "combat_tutorial_entered_arena", { source = "arena" })
            end
        end)
    elseif step.id == "select_pet" then
        session.woundToken = (session.woundToken or 0) + 1
        local woundToken = session.woundToken
        task.spawn(function()
            while woundToken == session.woundToken and player.Parent do
                self:_woundForStep(player, step)
                task.wait(0.5)
            end
        end)
        session.targetConn = player:GetAttributeChangedSignal("CombatBuffTarget"):Connect(function()
            local slot = tonumber(player:GetAttribute("CombatBuffTarget")) or 0
            local wounded = session.woundedSlot
            if not wounded or slot ~= wounded then
                return
            end
            local pet = petForSlot(player, slot)
            if pet and (tonumber(pet:GetAttribute("CombatDamageTaken")) or 0) > 0 then
                fireGameEvent(player, "pet_target_selected", {
                    slot = slot,
                    taken = pet:GetAttribute("CombatDamageTaken"),
                })
            end
        end)
    elseif step.mark_enemy == true then
        session.targetEnemyToken = (session.targetEnemyToken or 0) + 1
        local enemyToken = session.targetEnemyToken
        if stepWantsHealerFocus(step) then
            self:_setHealerCue(player, true)
        end
        task.spawn(function()
            while enemyToken == session.targetEnemyToken and player.Parent do
                self:_markTargetEnemy(player)
                self:_updateHealerFocus(player, false)
                task.wait(0.5)
            end
        end)
        session.targetConn = player
            :GetAttributeChangedSignal("CombatAssistTarget")
            :Connect(function()
                local assist = tonumber(player:GetAttribute("CombatAssistTarget")) or 0
                local marked = session.targetEnemyBid
                if marked and assist == marked then
                    fireGameEvent(player, "enemy_target_selected", {
                        targetId = assist,
                    })
                    self:_updateHealerFocus(player, true)
                end
            end)
    end
    if step.lock_door == true then
        self:_applyDoorPlate(player)
    end
end

function CombatTutorialService:_publishCombatRank(player, state)
    local earned = StatusBadge.earnedCsv(state)
    if earned ~= "" then
        player:SetAttribute("CombatRankEarned", earned)
    else
        player:SetAttribute("CombatRankEarned", nil)
    end
    local rank = CombatRank.rankById(self._ranksConfig, state and state.current)
    if rank then
        player:SetAttribute("CombatRank", rank.id)
        player:SetAttribute("CombatRankLabel", rank.label)
        return
    end
    player:SetAttribute("CombatRank", nil)
    player:SetAttribute("CombatRankLabel", nil)
end

function CombatTutorialService:_syncCombatRank(player, data, ceremonyStepId)
    if not (player and data and self._ranksConfig) then
        return false
    end
    data.GameData = type(data.GameData) == "table" and data.GameData or {}
    local state = CombatRank.normalize(data.GameData.CombatRank)
    local rank = ceremonyStepId and CombatRank.rankForStep(self._ranksConfig, ceremonyStepId)
    if rank then
        local nextState, isNew = CombatRank.grant(state, self._ranksConfig, rank.id)
        if isNew then
            data.GameData.CombatRank = nextState
            self._dataService:RequestSave(player, "combat_rank")
            self:_publishCombatRank(player, nextState)
            fireGameEvent(player, "combat_rank_achieved", {
                name = tostring(rank.label) .. " achieved.",
                rankId = rank.id,
                label = rank.label,
            })
            return true
        end
    end
    local synced, changed = state, false
    for _, definition in ipairs(self._courses.courses) do
        local courseChanged
        synced, courseChanged = CombatRank.syncFromTutorial(
            synced,
            self._ranksConfig,
            self._courseConfigs[definition.id],
            data[definition.key]
        )
        changed = courseChanged or changed
    end
    if changed then
        data.GameData.CombatRank = synced
        self._dataService:RequestSave(player, "combat_rank_sync")
        state = synced
    else
        data.GameData.CombatRank = state
    end
    self:_publishCombatRank(player, state)
    return false
end

function CombatTutorialService:_push(player)
    if player:GetAttribute("InCombatTutorial") ~= true then
        return
    end
    local data = self._dataService:GetData(player)
    if not (data and data[self:_progressKey(player)]) then
        return
    end
    pcall(function()
        local config = self:_courseConfig(player)
        local state = TutorialFlow.stateFor(config, data[self:_progressKey(player)])
        local active = self._activeCourses[player]
        state.courseId = self:_courseId(player)
        local definition = self._courseDefinitions[state.courseId]
        state.courseTitle = definition.title
        if state.done then
            state.completion = active and active.replay and self._courses.replay_completion
                or config.completion
        else
            local step = TutorialFlow.current(config, data[self:_progressKey(player)])
            state.body_gamepad = step and step.body_gamepad
        end
        Signals.TutorialState:FireClient(player, state)
    end)
end

return CombatTutorialService
