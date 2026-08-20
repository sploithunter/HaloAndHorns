--[[
    MissionInstanceService — door-mission lifecycle (docs/MISSION_WORLDGEN.md §5.2).

    A MissionDoor-tagged authored part (attr MissionId) gets a ProximityPrompt;
    triggering opens a deterministic procedural mission instance for the
    toucher's TEAM (PartyService TeamId attribute; solo = team of one) at a
    same-server slot on the far X-band, and teleports the party in.

    Lifecycle: Open → (play) → Complete/Abandon → teardown. Instances are a
    hard budget: per-team cap, global cap, TTL sweep — an instance can never
    leak (the 32k-crystal lesson: instance count is an invariant, not a hope).

    Determinism: seed = MissionSeed.seed(missionId, contextKey, worldgen_version)
    with contextKey from the mission's seed_policy; the layout runs on
    stream(seed, "layout"). Gauntlet missions ignore player/attempt salt and
    use ChallengeRun.layoutContext(room, mode) so everyone's Room N is the
    same map (Training Ground uses `train#N`); advancing restamps that
    room at the same slot. The resolved seed is
    stamped on the container so any map a player saw can be regenerated exactly.

    Population (CoH model): a seeded STATIC population is fielded at the
    kit's MissionSpawn anchors once at stamp time — no proximity waves, no
    respawn (the homeworld BaddieSpawner system never runs in here).
    Objectives: "clear_then_beacon" keeps the glowy inert until every mission
    enemy is defeated (also the anti-cheese — invulnerable players can walk
    anywhere, but only pets can clear); "reach_beacon" is the ungated
    courier variant. Rewards on completion are M5.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")

local MissionSeed = require(ReplicatedStorage.Shared.Worldgen.MissionSeed)
local MissionPopulation = require(ReplicatedStorage.Shared.Worldgen.MissionPopulation)
local PackScale = require(ReplicatedStorage.Shared.Game.PackScale)
local ChallengeRun = require(ReplicatedStorage.Shared.Game.ChallengeRun)
local PetLockout = require(ReplicatedStorage.Shared.Game.PetLockout)
local MissionDecor = require(ReplicatedStorage.Shared.Worldgen.MissionDecor)
local TileCatalog = require(ReplicatedStorage.Shared.Worldgen.TileCatalog)
local LayoutSolver = require(ReplicatedStorage.Shared.Worldgen.LayoutSolver)
local GrayBoxKit = require(ReplicatedStorage.Shared.Worldgen.GrayBoxKit)
local TileKitBuilder = require(ServerScriptService.Server.World.TileKitBuilder)
local MissionStamper = require(ServerScriptService.Server.World.MissionStamper)

local fireGameEvent = require(ReplicatedStorage.Shared.Network.FireGameEvent)
local Sounds = require(ReplicatedStorage.Configs:WaitForChild("sounds"))
local Signals = require(ReplicatedStorage.Shared.Network.Signals)

local PROMPT_NAME = "MissionDoorPrompt"
-- streaming-safe warp caps (see _safeWarp)
local STREAM_WAIT = 8 -- pre-warp yield cap (seconds)
local SWEEP_INTERVAL = 60

-- Kits addressable by config `kit` id. Data-driven kits (authored Models +
-- extractor) arrive with the first themed kit (M5); until then kits are
-- code-defined modules with definition()/parts().
local KITS = {
    gray_box = GrayBoxKit,
}

local MissionInstanceService = {}
MissionInstanceService.__index = MissionInstanceService

function MissionInstanceService.new()
    local self = setmetatable({}, MissionInstanceService)
    self._logger = nil
    self._config = nil
    self._instances = {} -- [instanceId] = record
    self._byTeam = {} -- [teamKey] = instanceId
    self._slots = {} -- [index] = instanceId or nil
    self._attempts = {} -- [teamKey .. "|" .. missionId] = count
    -- SESSION SALT (2026-07-09: "why am I playing the exact same map?"): the
    -- attempt counter resets with the server, so attempt #1 of every fresh
    -- session seeded identically — the same map every boot. Salt the
    -- per_attempt context per server; determinism WITHIN an instance is
    -- untouched (the resolved seed is stamped on the container).
    self._sessionSalt = math.random(1, 2 ^ 30)
    self._kitFolders = {} -- [kitId] = Folder (built once, cached)
    self._catalogs = {} -- [kitId] = TileCatalog
    self._nextInstance = 0
    self._streamPending = {} -- [Player] = { token, instanceId, ready }
    return self
end

function MissionInstanceService:Init()
    self._logger = self._modules and self._modules.Logger
    local configLoader = self._modules and self._modules.ConfigLoader
    local ok, cfg = pcall(function()
        return configLoader:LoadConfig("missions")
    end)
    self._config = (ok and type(cfg) == "table") and cfg or nil
    if not self._config then
        self:_log("Warn", "missions config unavailable — mission doors disabled")
    end
    -- enemy defs: team scaling reads static units' tier (boss/AV stay singular)
    local okE, enemies = pcall(function()
        return configLoader:LoadConfig("enemies")
    end)
    self._enemiesConfig = (okE and type(enemies) == "table") and enemies or nil
    local okC, challenge = pcall(function()
        return configLoader:LoadConfig("challenge_runs")
    end)
    self._challengeConfig = (okC and type(challenge) == "table") and challenge or nil
end

function MissionInstanceService:BindPeerServices(services)
    self._questService = services.QuestService
    self._dataService = services.DataService
    self._enemyService = services.EnemyService
    self._inventoryService = services.InventoryService
    self._statsService = services.StatsService
    self._layerService = services.LayerService
    self._breakableSpawner = services.BreakableSpawner
    self._dropService = services.DropService
    self._eventService = services.EventService
    self._enhancementService = services.EnhancementService
    self._npcPrincipalService = services.NpcPrincipalService
    self._hotbarService = services.HotbarService
    self._powerService = services.PowerService
    self._playerProgressionService = services.PlayerProgressionService
    self._leaderboardService = services.LeaderboardService
    self._petFollowService = services.PetFollowService
end

function MissionInstanceService:_cancelStream(player)
    local pending = self._streamPending[player]
    if not pending then
        return
    end
    self._streamPending[player] = nil
    pending.done = true
    pending.signal:Fire()
end

function MissionInstanceService:Start()
    if not self._config then
        return
    end
    if Signals.ChallengeRun_Start then
        Signals.ChallengeRun_Start.OnServerEvent:Connect(function(player, request)
            self:StartChallengeRun(player, request)
        end)
    end
    Signals.MissionStreamReady.OnServerEvent:Connect(function(player, response)
        if type(response) ~= "table" or type(response.token) ~= "string" then
            return
        end
        local pending = self._streamPending[player]
        if not pending or pending.token ~= response.token then
            return
        end
        if response.instanceId ~= pending.instanceId then
            return
        end
        pending.ready = true
        pending.done = true
        pending.signal:Fire()
    end)
    Players.PlayerRemoving:Connect(function(player)
        self:_onPlayerLeaving(player)
    end)
    -- CandleStand self-heal: re-assert the flame truth table against
    -- whatever the MissionProps rbxm shipped (see CANDLE_FLAME_POINTS).
    task.spawn(function()
        local ok, err = pcall(function()
            ReplicatedStorage:WaitForChild("MissionProps", 30)
            self:_normalizeCandleStand()
        end)
        if not ok then
            self:_log("Warn", "CandleStand normalization failed", { error = tostring(err) })
        end
    end)
    -- ROT ALARM (Jason 2026-07-15 "save a hash, compare on boot"): Roblox's
    -- delayed re-encode can mangle uploaded meshes hours after they verify
    -- clean. Recompute each blessed decor fingerprint (EditableMesh) and
    -- scream on drift. Studio sessions only — it's a dev tripwire, and
    -- EditableMesh costs memory prod players shouldn't pay.
    if game:GetService("RunService"):IsStudio() then
        task.spawn(function()
            task.wait(15) -- let boot finish; this is background diagnostics
            self:_assetRotCheck()
        end)
    end
    -- BOOT SWEEP: destroy any PERSISTED mission containers (Edit-mode demo
    -- stamps saved/copied into the session). A fresh server has no open
    -- missions by definition — a stale container squatting on a slot means
    -- the next real mission stamps INTO it (two interleaved maps read as
    -- "unsolvable", 2026-07-08 playtest).
    local stale = workspace:FindFirstChild("MissionInstances")
    if stale then
        local n = #stale:GetChildren()
        if n > 0 then
            self:_log("Warn", "boot sweep destroyed stale mission containers", { count = n })
        end
        stale:Destroy()
    end
    -- gate-label attribute: initial publish + follow the quest focus
    -- (QuestService republishes QuestActiveTrack on change and on list)
    local function watchGateLabel(player)
        player:GetAttributeChangedSignal("QuestActiveTrack"):Connect(function()
            self:_refreshGateLabel(player)
        end)
        self:_refreshGateLabel(player)
    end
    Players.PlayerAdded:Connect(watchGateLabel)
    for _, p in ipairs(Players:GetPlayers()) do
        watchGateLabel(p)
    end
    -- bind authored doors, now and as they appear
    for _, part in ipairs(CollectionService:GetTagged("MissionDoor")) do
        self:_bindDoor(part)
    end
    CollectionService:GetInstanceAddedSignal("MissionDoor"):Connect(function(part)
        self:_bindDoor(part)
    end)
    -- TTL sweep: instances can never leak
    task.spawn(function()
        while true do
            task.wait(SWEEP_INTERVAL)
            self:_sweep()
        end
    end)
end

function MissionInstanceService:_log(level, msg, data)
    if self._logger then
        self._logger[level](self._logger, "[MissionInstance] " .. msg, data)
    end
end

-- ---- team helpers --------------------------------------------------------

local function teamKeyFor(player)
    local teamId = player:GetAttribute("TeamId")
    if teamId ~= nil and teamId ~= "" then
        return "team:" .. tostring(teamId)
    end
    return "solo:" .. player.UserId
end

local function isTeamed(player)
    local teamId = player:GetAttribute("TeamId")
    return teamId ~= nil and teamId ~= ""
end

local function membersOf(teamKey)
    local prefix, id = teamKey:match("^(%w+):(.+)$")
    if prefix == "solo" then
        local player = Players:GetPlayerByUserId(tonumber(id))
        return player and { player } or {}
    end
    local members = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if tostring(player:GetAttribute("TeamId")) == id then
            table.insert(members, player)
        end
    end
    return members
end

-- Players still on this server who belong to the instance. `except` is the
-- leaver (PlayerRemoving still lists them in Players).
function MissionInstanceService:_livingMembers(record, except)
    local seen = {}
    local live = {}
    local function add(player)
        if player and player ~= except and player.Parent and not seen[player] then
            seen[player] = true
            table.insert(live, player)
        end
    end
    for _, member in ipairs(membersOf(record.teamKey)) do
        add(member)
    end
    for _, player in ipairs(Players:GetPlayers()) do
        if record.instanceId and player:GetAttribute("InMission") == record.instanceId then
            add(player)
        end
    end
    return live
end

function MissionInstanceService:_clearMemberMissionState(member, record)
    member:SetAttribute("MissionObjectiveText", nil)
    member:SetAttribute("MissionObjectiveCount", nil)
    member:SetAttribute("MissionObjectiveFraction", nil)
    member:SetAttribute("MissionMapData", nil)
    member:SetAttribute("InMission", nil)
    member:SetAttribute("MissionTheme", nil)
    member:SetAttribute("MissionArea", nil)
    member:SetAttribute("MissionAggressionPolicy", nil)
    member:SetAttribute("MissionSequence", nil)
    pcall(function()
        self._layerService:RefreshRealmAttributes(member)
    end)
    member:SetAttribute("MissionEnemyPings", nil)
    if record and record.gauntlet then
        pcall(function()
            local data = self._dataService and self._dataService:GetData(member)
            if data then
                data.PetLockouts = PetLockout.endGauntletSlotLocks(data.PetLockouts, os.time(), 60)
            end
        end)
    end
    member:SetAttribute("GauntletNoRevives", nil)
    member:SetAttribute("GauntletMode", nil)
    member:SetAttribute("GauntletRoom", nil)
    member:SetAttribute("ChallengePowers", nil)
    member:SetAttribute("ChallengeOrigin", nil)
    pcall(function()
        self:_applyChallengeLevel(member, nil)
    end)
    local zoom = record and record.savedZoom and record.savedZoom[member.UserId]
    if zoom then
        member.CameraMaxZoomDistance = zoom
    end
end

-- Free the enter gate immediately so a mid-teardown error cannot stick E.
function MissionInstanceService:_releaseEnterGate(record)
    if record.slotIndex and self._slots[record.slotIndex] == record.instanceId then
        self._slots[record.slotIndex] = nil
    end
    if record.teamKey and self._byTeam[record.teamKey] == record.instanceId then
        self._byTeam[record.teamKey] = nil
    end
end

function MissionInstanceService:_sweepOrphans()
    for instanceId, record in pairs(self._instances) do
        if not record.closing and #self:_livingMembers(record) == 0 then
            self:_log("Warn", "orphan mission abandoned", { instanceId = instanceId })
            self:_close(instanceId, "orphan")
        end
    end
end

function MissionInstanceService:_onPlayerLeaving(player)
    self:_cancelStream(player)
    local instanceId = player:GetAttribute("InMission")
    if type(instanceId) ~= "string" or instanceId == "" then
        instanceId = self._byTeam[teamKeyFor(player)]
    end
    local record = instanceId and self._instances[instanceId]
    if record then
        if #self:_livingMembers(record, player) == 0 then
            self:_close(instanceId, "disconnect")
        else
            self:_clearMemberMissionState(player, record)
        end
    end
    self:_sweepOrphans()
end

-- ---- kit / catalog cache ---------------------------------------------------

function MissionInstanceService:_kit(kitId)
    local kit = KITS[kitId]
    if not kit then
        return nil, nil, "unknown kit " .. tostring(kitId)
    end
    if not self._catalogs[kitId] then
        self._catalogs[kitId] = TileCatalog.build(kit.definition())
    end
    local folder = self._kitFolders[kitId]
    if not folder or not folder.Parent then
        -- runtime store augmentation (AssetPreloadService pattern): the kit
        -- templates live under ReplicatedStorage.Assets.Models.MissionTiles
        local models = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Models")
        local store = models:FindFirstChild("MissionTiles")
        if not store then
            store = Instance.new("Folder")
            store.Name = "MissionTiles"
            store.Parent = models
        end
        -- KITS are code-defined runtime assets. Models.rbxm may accidentally
        -- contain a MissionTiles cache when Assets.Models is saved from a
        -- running Studio session; that snapshot is not authoritative and can
        -- carry stale model pivots/PrimaryParts. Rebuild once per server from
        -- the source kit instead.
        local captured = store:FindFirstChild(kitId)
        if captured then
            captured:Destroy()
        end
        folder = TileKitBuilder.build(kit, store)
        self._kitFolders[kitId] = folder
    end
    return self._catalogs[kitId], folder
end

-- ---- solver params ----------------------------------------------------------

local function mergedParams(defaults, overrides)
    local params = {}
    for k, v in pairs(defaults or {}) do
        params[k] = v
    end
    for k, v in pairs(overrides or {}) do
        params[k] = v
    end
    return params
end

-- ---- lifecycle ---------------------------------------------------------------

-- Open a mission for the player's team. Returns instanceId or nil, err.
-- opts.sequence: REPLAY a shared-sequence mission number you've already
-- reached (Jason: "mission 28 was great" — reshare it). Does NOT advance
-- your index; completion counters tick normally (it's a real run).
function MissionInstanceService:Open(player, missionId, opts)
    opts = opts or {}
    if not self._config then
        return nil, "missions unavailable"
    end
    -- RANDOM MISSIONS (Jason's ladder): "random" is a mission SOURCE, not a
    -- mission — roll a real config from the pool per entry. Gated behind the
    -- quest-granted profile unlock; the attempt counter below already gives
    -- every entry a fresh seed. record.source keeps the ladder counter honest.
    local source = missionId
    if missionId == "auto" then
        -- QUEST-AWARE gate (Jason): the active quest's mission binding
        -- decides the trial; no binding = random. Deactivate the quest and
        -- the gate reverts — per-mission sequence heads keep your place.
        local bound
        pcall(function()
            local quests = self._questService
            bound = quests
                and quests.GetActiveMissionBinding
                and quests:GetActiveMissionBinding(player)
        end)
        if bound and self._config.missions[bound] then
            missionId = bound
            source = "quest"
        else
            missionId = "random"
        end
    end
    if missionId == "random" then
        local rnd = self._config.random
        if not (rnd and rnd.pool and #rnd.pool > 0) then
            return nil, "random missions not configured"
        end
        -- REALM-AFFINE gate: a gate inside a realm deals randoms from ITS
        -- side (random.realm_pools); outside any realm = the full pool
        local pool = (
            opts
            and opts.doorRealm
            and rnd.realm_pools
            and rnd.realm_pools[opts.doorRealm]
        ) or rnd.pool
        -- dedicated RNG instance (Jason: "it's not very random" — every
        -- fresh-server FIRST roll sampled the newly-seeded global VM state;
        -- Random.new() auto-seeds with independent high-quality entropy)
        self._doorRng = self._doorRng or Random.new()
        missionId = pool[self._doorRng:NextInteger(1, #pool)]
    end
    local mission = self._config.missions[missionId]
    if not mission then
        return nil, "unknown mission " .. tostring(missionId)
    end

    local teamKey = teamKeyFor(player)
    if self._byTeam[teamKey] then
        local existing = self._byTeam[teamKey]
        local rec = existing and self._instances[existing]
        if not rec or rec.closing then
            self._byTeam[teamKey] = nil
        elseif #self:_livingMembers(rec) == 0 then
            self:_close(existing, "orphan")
        else
            fireGameEvent(player, "mission_enter_blocked", { reason = "team_busy" })
            return nil, "team already has an active mission"
        end
    end
    if ChallengeRun.soloOnly(self:_challengeModeCfg(mission)) and isTeamed(player) then
        self:_rejectRangeTeam(player)
        return nil, "range_solo_required"
    end
    local live = 0
    for _ in pairs(self._instances) do
        live += 1
    end
    if live >= (self._config.limits.global or 6) then
        fireGameEvent(player, "mission_enter_blocked", { reason = "server_full" })
        return nil, "server mission capacity reached"
    end

    -- slot
    local slotIndex
    for i = 1, self._config.slots.count or 8 do
        if not self._slots[i] then
            slotIndex = i
            break
        end
    end
    if not slotIndex then
        fireGameEvent(player, "mission_enter_blocked", { reason = "no_slot" })
        return nil, "no free mission slot"
    end
    local slots = self._config.slots
    local slotOrigin = CFrame.new(slots.origin_x + (slotIndex - 1) * slots.spacing, slots.y or 0, 0)

    -- seed (docs §3)
    local contextKey
    local sequenceN
    local gauntletInputs
    if mission.gauntlet or mission.seed_policy == "gauntlet_room" then
        -- Fair ranking: Room N is the same map for everyone. No player,
        -- attempt, or session salt. Do not use shared_sequence — that
        -- advances MissionSeq and is the Trials ladder. Early rooms may
        -- override tile_budget to a single chamber.
        gauntletInputs = self:_gauntletSolveInputs(mission, opts.roomIndex or 1)
        contextKey = gauntletInputs.contextKey
    elseif mission.seed_policy == "team_stable" then
        contextKey = teamKey
    elseif mission.seed_policy == "shared_sequence" and opts.sequence then
        -- REPLAY: only numbers you've already reached (no peeking ahead at
        -- maps the sequence hasn't dealt you)
        local n = math.floor(tonumber(opts.sequence) or 0)
        local played = 0
        pcall(function()
            local dataSvc = self._dataService
            local data = dataSvc and dataSvc:GetData(player)
            played = (
                data
                and data.GameData
                and data.GameData.MissionSeq
                and tonumber(data.GameData.MissionSeq[missionId])
            ) or 0
        end)
        if n < 1 or n > played then
            return nil, ("you haven't reached trial #%d yet"):format(n)
        end
        sequenceN = n
        contextKey = "seq#" .. n
    elseif mission.seed_policy == "shared_sequence" then
        -- SHARED SEQUENCE (Jason 2026-07-09): everyone plays the SAME mission
        -- #1, #2, #3... per mission id — a shared experience ("mission 28 was
        -- great"). MissionSeq stores the highest number FINISHED-OR-SKIPPED;
        -- the head (stored+1) only advances at COMPLETE (or mission.skip) —
        -- Jason: "we shouldn't progress unless we finish it or we skip it."
        -- An abandoned/crashed run re-deals the SAME number (same seed =
        -- same map) until you beat it or skip it. Teams ride the opener's
        -- head. contextKey deliberately has NO player/team component.
        local okSeq, n = pcall(function()
            local dataSvc = self._dataService
            local data = dataSvc and dataSvc:GetData(player)
            if not data then
                return nil
            end
            local seq = data.GameData and data.GameData.MissionSeq
            return (seq and tonumber(seq[missionId]) or 0) + 1
        end)
        sequenceN = (okSeq and n) or 1
        contextKey = "seq#" .. sequenceN
    else
        local counterKey = teamKey .. "|" .. missionId
        self._attempts[counterKey] = (self._attempts[counterKey] or 0) + 1
        contextKey = teamKey .. "#" .. self._sessionSalt .. "#" .. self._attempts[counterKey]
    end
    local seed = MissionSeed.seed(missionId, contextKey, self._config.worldgen_version)
    local layoutSeed = MissionSeed.stream(seed, "layout")

    -- solve (pure) + stamp
    local catalog, kitFolder, kitErr = self:_kit(mission.kit)
    if not catalog then
        return nil, kitErr
    end
    local params = gauntletInputs and gauntletInputs.params
        or mergedParams(self._config.solver_defaults, mission.solver_overrides)
    local spec, report = LayoutSolver.solve(catalog, params, layoutSeed)
    if not spec then
        return nil, "layout failed: " .. tostring(report and report.error)
    end

    self._nextInstance += 1
    local instanceId = ("%s_%d"):format(missionId, self._nextInstance)
    local container, hooks = MissionStamper.stamp(spec, {
        kitFolder = kitFolder,
        slotOrigin = slotOrigin,
        instanceId = instanceId,
        yieldEvery = 25,
    })
    -- A procedural mission is private, temporary, and finite. Keep its complete geometry on each
    -- party member's client for the life of this run so individual atomic tiles cannot stream out
    -- at a seam while the player crosses it. Other players still see the model as Atomic.
    container.ModelStreamingMode = Enum.ModelStreamingMode.PersistentPerPlayer
    container:SetAttribute("MissionId", missionId)
    container:SetAttribute("MissionSeed", seed)
    if sequenceN then
        container:SetAttribute("MissionSequence", sequenceN)
    end
    if mission.gauntlet then
        container:SetAttribute("GauntletRoom", 1)
    end

    -- teleport the party in, remembering where each member stood
    local spawnPad = hooks.PlayerSpawn and hooks.PlayerSpawn[1]
    local cameraMaxZoom = self._config.camera and self._config.camera.max_zoom
    -- exit prompt on the entrance pad (CoH: you leave through the door you
    -- came in). Lives inside the container, so teardown removes it. Only the
    -- instance's own team can trigger it.
    self:_attachExitPrompt(spawnPad, mission, teamKey, instanceId)
    local returnCFrames = {}
    local savedZoom = {}
    local missionAggressionPolicy = mission.aggression_policy
        or (self._config.combat and self._config.combat.default_aggression_policy)
        or "realm"
    for _, member in ipairs(membersOf(teamKey)) do
        local character = member.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        if root and spawnPad then
            container:AddPersistentPlayer(member)
            returnCFrames[member.UserId] = root.CFrame
            -- Publish the run marker before its asynchronous stream request begins.
            member:SetAttribute("InMission", instanceId)
            -- async: each member streams the interior in parallel and warps
            -- when THEIR client has the floor (see _safeWarp)
            task.spawn(function()
                self:_safeWarp(
                    member,
                    CFrame.new(spawnPad.Position + Vector3.new(0, 4, 0)),
                    instanceId,
                    spawnPad
                )
            end)
            -- in-mission marker: DropService kills the magnet on it (walk to
            -- your loot); generally useful for any per-mission gating
            member:SetAttribute("MissionTheme", mission.theme or "earth")
            -- pseudo-area key: element trials brand drops + biome RPS via
            -- their own zone (mission.area, default = theme)
            member:SetAttribute("MissionArea", mission.area or mission.theme or "earth")
            -- Target acquisition reads this independently from CurrentRealm. Trials opt into
            -- universal initiation while CurrentRealm continues to drive resonance multipliers.
            member:SetAttribute("MissionAggressionPolicy", missionAggressionPolicy)
            -- THE TRIAL COUNTS AS ITS REALM (Jason 2026-07-09: "alignment
            -- isn't working inside the trials"): resonance keys on
            -- CurrentRealm, which is layer-derived — plaza/base entries read
            -- neutral. Override with the mission THEME for the run; restored
            -- from the layer SSOT at close. (RealmAtmosphere keys on
            -- CurrentLayer, so mission lighting isn't disturbed.)
            -- mission.realm overrides (element trials: theme = dressing
            -- only, realm = "neutral" → biome RPS is their axis, not
            -- light/shadow resonance)
            local themeRealm = mission.realm
                or (mission.theme == "hell" and "hell")
                or (mission.theme == "heaven" and "heaven")
                or "neutral"
            member:SetAttribute("CurrentRealm", themeRealm)
            if sequenceN then
                -- the shared-sequence number — map title + tracker show it
                member:SetAttribute("MissionSequence", sequenceN)
            end
            -- camera clamp: tall walls + capped zoom = no craning over the
            -- maze to scout the glowy; restored on exit
            if cameraMaxZoom then
                savedZoom[member.UserId] = member.CameraMaxZoomDistance
                member.CameraMaxZoomDistance = cameraMaxZoom
            end
            if mission.gauntlet then
                member:SetAttribute("GauntletNoRevives", true)
                member:SetAttribute("GauntletMode", mission.gauntlet.mode or missionId)
                member:SetAttribute("GauntletRoom", 1)
            end
        end
    end

    -- world-space despawn bounds for teardown (generous margin + Y band)
    local slotPos = slotOrigin.Position
    local record = {
        instanceId = instanceId,
        missionId = missionId,
        source = source, -- "random" when opened via the random door (quest ladder)
        sequence = sequenceN, -- shared-sequence number ("Trial #28")
        openerUserId = player.UserId, -- whose sequence head advances at COMPLETE
        teamKey = teamKey,
        seed = seed,
        slotIndex = slotIndex,
        container = container,
        hooks = hooks,
        returnCFrames = returnCFrames,
        savedZoom = savedZoom,
        crates = {}, -- farmable mission debris (die with the mission)
        openerLevel = player:GetAttribute("Level") or 1,
        createdAt = os.clock(),
        catalogPets = type(opts.catalogPets) == "table" and opts.catalogPets or nil,
        catalogPowers = type(opts.catalogPowers) == "table" and opts.catalogPowers or nil,
        catalogOrigin = type(opts.catalogOrigin) == "string" and opts.catalogOrigin or nil,
        boundsMin = Vector3.new(
            slotPos.X + spec.bbox.minx - 20,
            slotPos.Y - 50,
            slotPos.Z + spec.bbox.minz - 20
        ),
        boundsMax = Vector3.new(
            slotPos.X + spec.bbox.maxx + 20,
            slotPos.Y + 60,
            slotPos.Z + spec.bbox.maxz + 20
        ),
    }
    self._instances[instanceId] = record
    self._slots[slotIndex] = instanceId
    self._byTeam[teamKey] = instanceId
    self:_prepareGauntlet(record, mission, player, spawnPad)

    -- Build the shared pure room payload BEFORE population. MissionSpawn anchors, enemy movement
    -- bounds, minimap, dressing, and treasure must all resolve against this one layout result.
    local mapTable = LayoutSolver.mapData(catalog, spec)
    mapTable.ox = slotOrigin.Position.X
    mapTable.oz = slotOrigin.Position.Z
    record.mapTable = mapTable

    -- STATIC population (CoH model): field a seeded, fixed pack at every
    -- MissionSpawn anchor, once. No proximity waves, no respawn — the
    -- homeworld BaddieSpawner system never runs inside missions.
    record.enemies = {}
    do
        local points = self:_missionSpawnPoints(container, record.gauntletCurve)
        local objectivePointIndex
        for i, point in ipairs(points) do
            if point:GetAttribute("ObjectiveRoom") then
                objectivePointIndex = i
                break
            end
        end
        -- PLAYER + TEAM GROUP SCALING: the opener's persistent Settings value owns this
        -- party run, then automatic team scaling composes on top. Both are config-clamped
        -- through the shared PackScale path; pack/layout rolls remain unchanged.
        local ts = self._config.team_scaling or {}
        local teamSize = #membersOf(teamKey)
        local groupCfg = (self._config.player_tuning or {}).group_scale or {}
        -- Gauntlet ranking ignores the Trials density slider: everyone enters at 1.0.
        local groupScale = 1
        if not record.gauntlet then
            groupScale =
                PackScale.sanitizeMultiplier(player:GetAttribute("TrialGroupScale"), groupCfg)
        end
        local teamMult = record.gauntlet and 1 or PackScale.teamMultiplier(teamSize, ts)
        local countMult = groupScale * teamMult
        if record.gauntletCurve then
            countMult = countMult * (tonumber(record.gauntletCurve.count_mult) or 1)
        end
        container:SetAttribute("TrialGroupScale", groupScale)
        container:SetAttribute("TrialTeamScale", teamMult)
        record.groupScale = groupScale
        record.teamScale = teamMult
        local enemyDefs = (self._enemiesConfig and self._enemiesConfig.enemies) or {}
        -- BOSS LADDER (Jason 2026-07-13): the slider's top half buys extra
        -- bosses — budget = max(0, scale - offset). Team scaling deliberately
        -- does NOT feed the budget (a full team at 100% still sees one boss;
        -- only the deliberate difficulty choice does). Gauntlets do not use it.
        local bossBudgetCfg = (self._config.player_tuning or {}).boss_budget
        local extraBossBudget = 0
        local villainChance = 0
        if bossBudgetCfg and not record.gauntlet then
            extraBossBudget = math.max(0, groupScale - (tonumber(bossBudgetCfg.offset) or 0.75))
            local villainCfg = bossBudgetCfg.villain
            if villainCfg and groupScale >= (tonumber(villainCfg.at) or 2) then
                villainChance = tonumber(villainCfg.chance) or 0
            end
        end
        local spawnPhase = record.gauntlet and ("spawns_r" .. tostring(record.room_index or 1))
            or "spawns"
        local packs = mission.packs or {}
        if record.gauntletCurve then
            packs = ChallengeRun.filterPacks(packs, record.gauntletCurve)
        end
        local forceBoss = objectivePointIndex
            and (not record.gauntletCurve or record.gauntletCurve.add_boss == true)
        local comp, popMeta =
            MissionPopulation.roll(packs, #points, MissionSeed.stream(seed, spawnPhase), {
                extraBossBudget = extraBossBudget,
                villainChance = villainChance,
                -- villain tier mapping: pet-model boss rank → titan (the
                -- arch-villain rank); static bosses → the mission's authored
                -- villain_unit. nil = no upgrade authored, boss stays.
                upgradeUnit = function(unit)
                    if unit.pet then
                        if
                            (unit.rank or "minion") == "boss"
                            and (self._config.pet_ranks or {}).titan
                        then
                            return { pet = unit.pet, rank = "titan" }
                        end
                        return nil
                    end
                    local vu = mission.villain_unit
                    local def = unit.enemy and enemyDefs[unit.enemy]
                    if vu and enemyDefs[vu] and def and def.tier == "boss" then
                        return { enemy = vu, count = 1 }
                    end
                    return nil
                end,
                -- CoH rule (Jason's boss-less lava run): the OBJECTIVE room's
                -- point always rolls a boss-marked pack — the boss guards the
                -- glowy; weight-3 luck can no longer produce a boss-less map
                bossPointIndex = forceBoss and objectivePointIndex or nil,
                bossOnlyAtObjective = (self._config.population or {}).boss_only_at_objective,
                countMult = countMult,
                scalesUnit = function(unit)
                    if unit.rank == "boss" or unit.rank == "titan" then
                        return false -- pet-model anchors stay singular
                    end
                    local def = unit.enemy and enemyDefs[unit.enemy]
                    if def and (def.tier == "boss" or def.tier == "archvillain") then
                        return false -- static anchors too
                    end
                    return true
                end,
            })
        if popMeta and (popMeta.extraBosses or 0) > 0 then
            container:SetAttribute("TrialExtraBosses", popMeta.extraBosses)
            container:SetAttribute("TrialVillain", popMeta.villain == true)
            self:_log("Info", "boss ladder rolled", {
                mission = missionId,
                groupScale = groupScale,
                extraBosses = popMeta.extraBosses,
                villain = popMeta.villain,
            })
        end
        local posPhase = record.gauntlet and ("spawnpos_r" .. tostring(record.room_index or 1))
            or "spawnpos"
        local posRng = MissionSeed.mulberry32(MissionSeed.stream(seed, posPhase))
        local SCATTER = 14 -- studs around the anchor (rooms are 96+ wide at 6x scale)
        local enemySvc
        pcall(function()
            enemySvc = self._enemyService
        end)
        if enemySvc then
            for i, point in ipairs(points) do
                local room, roomIndex = LayoutSolver.roomAt(
                    mapTable,
                    point.Position.X,
                    point.Position.Z,
                    mapTable.ox,
                    mapTable.oz
                )
                local movementLeash
                if room then
                    local centerX, centerZ = mapTable.ox + room.x, mapTable.oz + room.z
                    movementLeash = {
                        shapes = {
                            {
                                kind = "box",
                                cx = centerX,
                                cz = centerZ,
                                halfX = room.hx,
                                halfZ = room.hz,
                            },
                        },
                        inset = tonumber((self._config.navigation or {}).room_inset) or 0,
                        -- MissionSpawn is the authored clear point (the objective beacon occupies
                        -- geometric center in boss rooms). Recover there, three studs above its
                        -- floor, and let EnemyService ground-snap for the enemy's own body.
                        recovery = point.Position + Vector3.new(0, 3, 0),
                        roomIndex = roomIndex,
                    }
                else
                    self:_log("Warn", "MissionSpawn is outside every generated room", {
                        mission = missionId,
                        point = point:GetFullName(),
                    })
                end
                for _, entry in ipairs(comp[i] or {}) do
                    local offset =
                        Vector3.new((posRng() * 2 - 1) * SCATTER, 3, (posRng() * 2 - 1) * SCATTER)
                    pcall(function()
                        -- PET-MODEL units ({pet, rank}): synthesize the def
                        -- with the rank ladder (missions.pet_ranks) — boss
                        -- rank wears the pet's own HUGE scale
                        local enemyId, synthDef
                        if type(entry) == "table" and entry.pet then
                            local ladder = self._config.pet_ranks or {}
                            synthDef = enemySvc.SynthesizePetEnemy
                                and enemySvc:SynthesizePetEnemy(
                                    entry.pet,
                                    ladder[entry.rank or "minion"],
                                    record.openerLevel
                                )
                            enemyId = "petinv_" .. entry.pet
                            -- ALL trial bosses roll the mission's egg (Jason:
                            -- pet-model bosses dropped nothing)
                            if
                                synthDef
                                and mission.boss_egg
                                and (synthDef.tier == "boss" or synthDef.tier == "archvillain")
                            then
                                synthDef.exclusive_egg = self:_eggForTier(mission, synthDef.tier)
                            end
                        else
                            enemyId = entry
                            -- MISSION-scoped static scaling: clone the def
                            -- with tier multipliers (homeworld waves use the
                            -- untouched config def)
                            local scaling = self._config.static_scaling
                            if scaling then
                                local okDef, base = pcall(function()
                                    return require(
                                        ReplicatedStorage.Configs:WaitForChild("enemies")
                                    ).enemies[enemyId]
                                end)
                                local mult = okDef and base and scaling[base.tier]
                                if mult then
                                    synthDef = table.clone(base)
                                    synthDef.hp =
                                        math.floor((base.hp or 1) * (tonumber(mult.hp_mult) or 1))
                                    if base.attack then
                                        synthDef.attack = table.clone(base.attack)
                                        synthDef.attack.damage = math.floor(
                                            (base.attack.damage or 0)
                                                * (tonumber(mult.dmg_mult) or 1)
                                        )
                                        -- RANK AXIS (Jason: a +0 LT must beat
                                        -- a +1 minion — rank scales its own
                                        -- way): scaling may inject splash
                                        if
                                            type(mult.splash) == "table"
                                            and not synthDef.attack.splash
                                        then
                                            synthDef.attack.splash = mult.splash
                                        end
                                    end
                                    if type(mult.abilities) == "table" then
                                        synthDef.abilities = synthDef.abilities or {}
                                        for k, v in pairs(mult.abilities) do
                                            if synthDef.abilities[k] == nil then
                                                synthDef.abilities[k] = v
                                            end
                                        end
                                    end
                                end
                            end
                        end
                        -- VILLAIN statics (mission-injected arch-villains, e.g.
                        -- the Infernal Archfiend replacing the Magma Wyrm on a
                        -- 200% roll): the def carries no exclusive_egg of its
                        -- own — attach the mission egg at the villain premium.
                        if type(entry) ~= "table" and mission.boss_egg then
                            local rawDef = enemyDefs[enemyId]
                            if rawDef and rawDef.tier == "archvillain" then
                                synthDef = synthDef or table.clone(rawDef)
                                synthDef.exclusive_egg = self:_eggForTier(mission, "archvillain")
                            end
                        end
                        if synthDef and record.gauntletCurve then
                            synthDef = self:_scaleGauntletDef(synthDef, record.gauntletCurve)
                        elseif record.gauntletCurve and type(entry) ~= "table" then
                            local base = synthDef
                                or (enemyDefs[enemyId] and table.clone(enemyDefs[enemyId]))
                            if base then
                                synthDef = self:_scaleGauntletDef(base, record.gauntletCurve)
                            end
                        end
                        if type(entry) == "table" and not synthDef then
                            -- config gate (MissionSchema) makes this unreachable
                            -- for typos; if it fires, something deeper broke —
                            -- be LOUD, never silently under-populate a mission
                            self:_log("Warn", "pet-model spawn FAILED to synthesize", {
                                pet = entry.pet,
                                mission = missionId,
                            })
                            return
                        end
                        -- NAMED TARGET (defeat_named): the objective anchor's
                        -- boss/arch-villain IS the mission — it wears the
                        -- authored name and the gate tracks only it.
                        local isNamed = false
                        if
                            mission.objective
                            and mission.objective.kind == "defeat_named"
                            and i == objectivePointIndex
                            and record.namedTarget == nil
                        then
                            local tier = (synthDef or enemyDefs[enemyId] or {}).tier
                            if tier == "boss" or tier == "archvillain" then
                                synthDef = synthDef or table.clone(enemyDefs[enemyId])
                                synthDef.display_name = mission.objective.name
                                    or synthDef.display_name
                                isNamed = true
                            end
                        end
                        local r = enemySvc:SpawnEnemy(player, enemyId, {
                            def = synthDef,
                            position = point.Position + offset,
                            home = point.Position,
                            movementLeash = movementLeash,
                            encounterGroup = point,
                            dormant = true, -- no birth aggro: engage when the team arrives
                            persistent = true, -- never idle-despawn: defeat or teardown only
                            ignoreEnemyLevelOffset = record.gauntlet == true,
                        })
                        if r and r.ok and r.model then
                            table.insert(record.enemies, r.model)
                            if isNamed then
                                record.namedTarget = r.model
                                r.model:SetAttribute("MissionNamedTarget", true)
                            end
                        end
                    end)
                end
            end
        end
    end

    -- minimap payload (CoH-style): room rects + walkable doorways from the
    -- SAME spec that stamped the map; the client fog-of-war reveals rooms as
    -- the team walks them. Slot origin included so clients map world→map.
    -- (mapTable is reused below for treasure placement.)
    do
        local okEncode, encoded = pcall(function()
            mapTable.name = mission.display or missionId
            return game:GetService("HttpService"):JSONEncode(mapTable)
        end)
        if okEncode then
            for _, member in ipairs(membersOf(teamKey)) do
                member:SetAttribute("MissionMapData", encoded)
            end
        end
    end

    -- DRESSING (M5a): per-room tint jitter + seeded clutter on the own
    -- "dressing" stream — no two rooms read identical, same seed = same look
    if not mission.decor or mission.decor.enabled ~= false then
        self:_applyDressing(
            mission.decor or {},
            mapTable,
            spec,
            container,
            slotOrigin,
            seed,
            mission.theme,
            record,
            mission.realm
        )
    end

    -- TREASURE (CoH glowie-lite, M5): seeded chests in a few rooms; opening
    -- one pays GUARANTEED enhancement drops to the opener (DropService
    -- source "treasure"). Placement rides the decor stream (deterministic);
    -- chest contents stay loot-random. Chests die with the container.
    if mission.treasure then
        self:_placeTreasures(
            mission.treasure,
            mapTable,
            container,
            slotOrigin,
            seed,
            teamKey,
            record
        )
    end

    -- Objective monitor. Kinds:
    --   reach_beacon       — touch the glowy, done (courier style)
    --   clear_then_beacon  — the glowy is INERT until every mission enemy is
    --                        defeated (CoH clear-gate; also the anti-cheese:
    --                        invulnerable players can walk anywhere, but only
    --                        pets can clear, so pets are mandatory)
    --   defeat_named       — the glowy is INERT until the NAMED objective
    --                        anchor dies (Jason: "go defeat the Duke of
    --                        Bastion... you don't have to defeat everything");
    --                        the rest of the map is optional speed-bumps
    local kind = mission.objective and mission.objective.kind
    if kind == "reach_beacon" or kind == "clear_then_beacon" or kind == "defeat_named" then
        local beacons = hooks.MissionObjective or {}
        local gated = kind ~= "reach_beacon"
        -- the gate's watch list: everything for clear, ONE model for named.
        -- A defeat_named mission with no tracked target is an authoring/spawn
        -- failure — be LOUD and fall back to the full clear gate rather than
        -- ship an unopenable beacon.
        local watched = record.enemies
        local clearText = "Defeat all enemies!"
        if kind == "defeat_named" then
            if record.namedTarget then
                watched = { record.namedTarget }
                clearText = ("Defeat %s!"):format(mission.objective.name or "the target")
            else
                self:_log(
                    "Warn",
                    "defeat_named mission spawned NO named target — falling back to clear gate",
                    { mission = missionId }
                )
            end
        end
        local INERT_COLOR = Color3.fromRGB(70, 70, 78)
        if gated then
            for _, beacon in ipairs(beacons) do
                beacon:SetAttribute("ObjectiveActive", false)
                beacon:SetAttribute("ActiveColor", beacon.Color)
                beacon.Color = INERT_COLOR
                beacon.Transparency = 0.5
            end
        end
        -- objective published as PLAYER ATTRIBUTES — the QUEST TRACKER HUD
        -- takes them over while in-mission (Jason: reuse that pop-up, no
        -- parallel banner). Text = instruction line, Count = "3/9" chip,
        -- Fraction = the tracker's fill bar. UI renders them verbatim.
        local total = #watched
        local function publish(text, count, fraction)
            for _, member in ipairs(membersOf(teamKey)) do
                member:SetAttribute("MissionObjectiveText", text)
                member:SetAttribute("MissionObjectiveCount", count)
                member:SetAttribute("MissionObjectiveFraction", fraction)
            end
        end
        -- the shared-sequence number IS the shared experience — put it in
        -- the tracker so players can talk about "Trial #28"
        local seqTag = record.sequence and ("Trial #" .. record.sequence .. " — ") or ""
        if record.gauntlet then
            seqTag = ("Room %d — "):format(record.room_index or 1)
        end
        if gated and total > 0 then
            publish(seqTag .. clearText, ("0/%d"):format(total), 0)
        else
            publish(seqTag .. "Reach the glowing beacon!", "★", 1)
        end

        -- COMPLETE = press/hold E at the ACTIVE beacon (Jason: "instead of
        -- just passing out... same E functionality — works on mobile"). The
        -- prompt exists disabled; the monitor enables it at activation.
        local beaconPrompts = self:_attachBeaconPrompts(record, mission, beacons, gated)

        record.monitor = task.spawn(function()
            local cleared = not gated or #watched == 0
            local lastDown = -1
            local lastRoom = record.room_index
            while self._instances[instanceId] do
                if record.layoutSwap then
                    task.wait(0.5)
                    continue
                end
                if record.gauntlet and record.room_index ~= lastRoom then
                    lastRoom = record.room_index
                    beacons = (record.hooks and record.hooks.MissionObjective) or {}
                    beaconPrompts = {}
                    for _, beacon in ipairs(beacons) do
                        local bp = beacon:FindFirstChild("MissionCompletePrompt")
                        if bp then
                            table.insert(beaconPrompts, bp)
                        end
                    end
                    watched = record.enemies
                    total = #watched
                    cleared = not gated or total == 0
                    lastDown = -1
                    seqTag = ("Room %d — "):format(record.room_index or 1)
                    if gated then
                        for _, beacon in ipairs(beacons) do
                            if beacon.Parent then
                                beacon:SetAttribute("ObjectiveActive", false)
                                beacon.Color = INERT_COLOR
                                beacon.Transparency = 0.5
                            end
                        end
                        for _, bp in ipairs(beaconPrompts) do
                            if bp.Parent then
                                bp.Enabled = false
                                if record.room_index >= (record.gauntletRooms or 99) then
                                    bp.ActionText = "Finish Run"
                                else
                                    bp.ActionText = "Next Room"
                                end
                            end
                        end
                        if total > 0 then
                            publish(seqTag .. clearText, ("0/%d"):format(total), 0)
                        end
                    end
                end
                if not cleared then
                    local alive = 0
                    for _, model in ipairs(watched) do
                        if model.Parent then
                            alive += 1
                        end
                    end
                    local down = total - alive
                    if down ~= lastDown then
                        lastDown = down
                        publish(clearText, ("%d/%d"):format(down, total), down / total)
                    end
                    -- CoH straggler pings: with only a few enemies left, the
                    -- map shows them (hunting the last crow in the dark is
                    -- frustration, not gameplay — 2026-07-08 hell playtest)
                    local pings = nil
                    if alive > 0 and alive <= 3 then
                        local list = {}
                        for _, model in ipairs(watched) do
                            if model.Parent then
                                local okP, pos = pcall(function()
                                    return model:GetPivot().Position
                                end)
                                if okP and pos then
                                    table.insert(list, { x = pos.X, z = pos.Z })
                                end
                            end
                        end
                        if #list > 0 then
                            pings = game:GetService("HttpService"):JSONEncode(list)
                        end
                    end
                    for _, member in ipairs(membersOf(teamKey)) do
                        member:SetAttribute("MissionEnemyPings", pings)
                    end
                    if alive == 0 then
                        cleared = true
                        for _, beacon in ipairs(beacons) do
                            if beacon.Parent then
                                beacon:SetAttribute("ObjectiveActive", true)
                                beacon.Color = beacon:GetAttribute("ActiveColor") or beacon.Color
                                beacon.Transparency = 0
                            end
                        end
                        for _, bp in ipairs(beaconPrompts) do
                            if bp.Parent then
                                bp.Enabled = true
                            end
                        end
                        publish("Objective active — activate the glowing beacon!", "★", 1)
                        -- activation FANFARE (Jason: the moment the glowy
                        -- lights is the celebration beat)
                        for _, member in ipairs(membersOf(teamKey)) do
                            fireGameEvent(member, "objective_active", {
                                mission = missionId,
                                name = "Objective clear — the beacon awakens!",
                            })
                        end
                        self:_log("Info", "objective activated — mission cleared", {
                            instanceId = instanceId,
                        })
                    end
                else
                    -- completion is the beacon PROMPT's job now (press E);
                    -- the monitor just idles until close
                end
                task.wait(0.5)
            end
        end)
        if record.gauntlet then
            self:_watchGauntletWipe(record)
        end
    end

    self:_log("Info", "opened", {
        instanceId = instanceId,
        teamKey = teamKey,
        seed = seed,
        tiles = #spec.tiles,
        attempts = report.attempts,
        slot = slotIndex,
    })
    return instanceId
end

-- The mission's exclusive-egg entry for a spawned tier: boss pays the stated
-- boss_egg.chance; archvillain (the 200% villain roll) pays the PREMIUM —
-- per-mission boss_egg.villain_chance, else the global
-- player_tuning.boss_budget.villain.egg_chance, else 4x the boss rate.
function MissionInstanceService:_eggForTier(mission, tier)
    local egg = mission.boss_egg
    if not egg or tier ~= "archvillain" then
        return egg
    end
    local villainCfg = ((self._config.player_tuning or {}).boss_budget or {}).villain
    local premium = tonumber(egg.villain_chance)
        or (villainCfg and tonumber(villainCfg.egg_chance))
        or (tonumber(egg.chance) or 0) * 4
    local out = table.clone(egg)
    out.chance = premium
    return out
end

-- Quest-granted persistent unlocks (GameData.Unlocks.<id>, written by
-- QuestService:Claim). Server-authoritative: reads the profile, never attrs.
function MissionInstanceService:_hasUnlock(player, unlockId)
    local ok, has = pcall(function()
        local dataSvc = self._dataService
        local data = dataSvc and dataSvc:GetData(player)
        local unlocks = data and data.GameData and data.GameData.Unlocks
        return unlocks and unlocks[unlockId] == true
    end)
    return ok and has == true
end

-- SKIP the current head number (Jason: "if they find a bug... yeah I'm
-- skipping this mission"): marks it consumed WITHOUT completion credit
-- (no counters, no ladder). If the player's team is inside that mission,
-- it's abandoned first.
function MissionInstanceService:SkipCurrent(player, missionId)
    if not (self._config and self._config.missions[missionId]) then
        return { ok = false, reason = "unknown_mission" }
    end
    if self._config.missions[missionId].seed_policy ~= "shared_sequence" then
        return { ok = false, reason = "not_sequenced" }
    end
    local active = self._byTeam[teamKeyFor(player)]
    if active and self._instances[active] and self._instances[active].missionId == missionId then
        self:Abandon(active)
    end
    local okSkip, newHead = pcall(function()
        local dataSvc = self._dataService
        local data = dataSvc:GetData(player)
        data.GameData = data.GameData or {}
        data.GameData.MissionSeq = data.GameData.MissionSeq or {}
        local cur = tonumber(data.GameData.MissionSeq[missionId]) or 0
        data.GameData.MissionSeq[missionId] = cur + 1
        dataSvc:RequestSave(player, "mission_skip") -- non-critical: see mission_sequence
        return cur + 2 -- the new head they'll face next
    end)
    if not okSkip then
        return { ok = false, reason = "data_not_loaded" }
    end
    self:_log("Warn", "trial number SKIPPED", { player = player.Name, mission = missionId })
    self:_refreshGateLabel(player)
    return { ok = true, nextTrial = newHead }
end

function MissionInstanceService:Complete(instanceId)
    return self:_close(instanceId, "complete")
end

function MissionInstanceService:Abandon(instanceId)
    return self:_close(instanceId, "abandon")
end

function MissionInstanceService:_close(instanceId, reason)
    local record = self._instances[instanceId]
    if not record then
        return false, "unknown instance " .. tostring(instanceId)
    end
    if record.closing then
        return true
    end
    record.closing = true
    -- Leave = leave. Drop the enter gate before teardown so a restore error
    -- or a crash mid-warp cannot keep E dead on the next door.
    self:_releaseEnterGate(record)

    -- stop the objective monitor (unless we're being called FROM it)
    if record.monitor and record.monitor ~= coroutine.running() then
        pcall(task.cancel, record.monitor)
    end
    if record.wipeWatch and record.wipeWatch ~= coroutine.running() then
        pcall(task.cancel, record.wipeWatch)
    end
    if record.gauntlet then
        pcall(function()
            self:_persistChallengeBest(record)
        end)
        pcall(function()
            self:_restoreGauntletLoadouts(record)
        end)
    end

    -- COMPLETION counters (quest ladder substrate): every team member's
    -- career totals tick; random-sourced runs also tick the random ladder
    if reason == "complete" then
        -- SEQUENCE ADVANCE (finish-or-skip rule): EVERY team member's head
        -- moves past this number — the whole team finished trial #N together
        -- (Jason, duo: opener-only credit re-dealt #1 to the other account
        -- every session). Never regresses (replays of old numbers).
        -- EITHER-OR completion rewards (Jason: the first-clear egg must not
        -- stack with the completion spoils — jackpot REPLACES paycheck)
        local eggWinners = {}
        if record.sequence then
            for _, member in ipairs(membersOf(record.teamKey)) do
                pcall(function()
                    local dataSvc = self._dataService
                    local data = dataSvc:GetData(member)
                    if data then
                        data.GameData = data.GameData or {}
                        data.GameData.MissionSeq = data.GameData.MissionSeq or {}
                        local cur = tonumber(data.GameData.MissionSeq[record.missionId]) or 0
                        if record.sequence > cur then
                            data.GameData.MissionSeq[record.missionId] = record.sequence
                            -- NOT critical (DataStore budget, 2026-07-09 Studio
                            -- throttle): worst-case crash loss = re-facing a trial
                            -- you already beat. Coalesces on the 15s debounce.
                            dataSvc:RequestSave(member, "mission_sequence")
                            self:_refreshGateLabel(member)
                            -- FIRST-TIME CLEAR egg roll (0.5%): per member, tied
                            -- to THEIR advance moment — replays can't farm it
                            local eggCfg = self._config.missions[record.missionId]
                                and self._config.missions[record.missionId].boss_egg
                            -- Wyrm Weekend (exclusive_egg_chance event axis):
                            -- doubles the ROLL, never the stated hatch odds
                            local fcChance = tonumber(eggCfg and eggCfg.chance) or 0
                            local eventService = self._eventService
                            if eventService then
                                local okModifier, modifier = pcall(function()
                                    return eventService:GetModifier("exclusive_egg_chance", 0)
                                end)
                                if okModifier then
                                    fcChance = fcChance * (1 + (tonumber(modifier) or 0))
                                end
                            end
                            if eggCfg and math.random() < fcChance then
                                local inv = self._inventoryService
                                local granted = inv
                                    and inv:AddItem(member, "eggs", {
                                        id = eggCfg.egg,
                                        name = eggCfg.name or eggCfg.egg,
                                        source = "first_clear:"
                                            .. record.missionId
                                            .. "#"
                                            .. record.sequence,
                                    })
                                if granted then
                                    eggWinners[member] = true -- either-or: egg replaces the spoils single
                                    fireGameEvent(member, "exclusive_egg_pickup", {
                                        egg = eggCfg.egg,
                                        name = ("%s found in the beacon's light!"):format(
                                            eggCfg.name or "A mysterious egg"
                                        ),
                                    })
                                end
                            end
                        end
                    end
                end)
            end
        end
        pcall(function()
            local statsSvc = self._statsService
            for _, member in ipairs(membersOf(record.teamKey)) do
                -- COMPLETION SPOILS (Jason): one guaranteed SINGLE of the
                -- member's OWN origin at their level — the always-slottable
                -- payday; chests/kills stay the gamble. EITHER-OR with the
                -- first-clear egg: a jackpot winner skips the paycheck.
                if
                    not eggWinners[member]
                    and self._enhancementService
                    and self._enhancementService.GrantOriginSingle
                then
                    pcall(function()
                        self._enhancementService:GrantOriginSingle(member)
                    end)
                end
                statsSvc:Increment(member, "missions_completed", 1)
                if record.source == "random" then
                    statsSvc:Increment(member, "random_missions_completed", 1)
                end
                -- per-trial counter (<missionId>s_completed): declared-ness
                -- is enforced at config load (MissionSchema) — a failure here
                -- is a real bug, so it WARNS instead of no-opping (Jason:
                -- soft bugs are hard to track)
                local okCount, cErr = pcall(function()
                    statsSvc:Increment(member, record.missionId .. "s_completed", 1)
                end)
                if not okCount then
                    self:_log("Warn", "per-trial counter increment FAILED", {
                        mission = record.missionId,
                        err = tostring(cErr),
                    })
                end
            end
        end)
    end

    -- return surviving members to where they entered from; clear mission
    -- HUD state and restore their camera zoom
    local warping = 0
    for _, member in ipairs(membersOf(record.teamKey)) do
        -- Cancel an entry request that is still waiting before replacing it with the return warp.
        self:_cancelStream(member)
        local back = record.returnCFrames[member.UserId]
        local character = member.Character
        if back and character and character:FindFirstChild("HumanoidRootPart") then
            -- the homeworld may have streamed OUT during a long mission —
            -- same fall-through risk as entry, so same streaming-safe warp
            warping += 1
            task.spawn(function()
                self:_safeWarp(member, back)
                warping -= 1
            end)
        end
        self:_clearMemberMissionState(member, record)
    end

    -- enemies born inside the mission die with it — never loiter at the slot
    if record.boundsMin then
        pcall(function()
            local enemySvc = self._enemyService
            if enemySvc and enemySvc.DespawnEnemiesInBounds then
                local removed = enemySvc:DespawnEnemiesInBounds(record.boundsMin, record.boundsMax)
                if removed > 0 then
                    self:_log("Info", "despawned mission enemies", { count = removed })
                end
            end
        end)
    end

    -- farmable debris dies with the mission (direct Destroy: no award, and
    -- the Dead-attr guard means no double-handling)
    for _, crate in ipairs(record.crates or {}) do
        if crate.Parent then
            crate:Destroy()
        end
    end

    -- don't yank the floor out from under anyone still mid-warp home
    local deadline = os.clock() + STREAM_WAIT + 1
    while warping > 0 and os.clock() < deadline do
        task.wait(0.1)
    end

    pcall(function()
        if record.container then
            record.container:Destroy()
        end
    end)
    self._instances[instanceId] = nil
    self:_log("Info", "closed", { instanceId = instanceId, reason = reason })
    return true
end

function MissionInstanceService:_challengeModeCfg(mission)
    local mode = mission and mission.gauntlet and mission.gauntlet.mode
    return mode
        and self._challengeConfig
        and self._challengeConfig.modes
        and self._challengeConfig.modes[mode]
end

function MissionInstanceService:_rejectRangeTeam(player)
    fireGameEvent(player, "range_solo_required", { reason = "teamed" })
end

function MissionInstanceService:_rangeDefaults(player, catalog)
    local raw
    pcall(function()
        local data = self._dataService and self._dataService:GetData(player)
        raw = data and data.GameData and data.GameData.RangeDefaults
    end)
    return ChallengeRun.readRangeDefaults(raw, catalog)
end

function MissionInstanceService:_persistRangeDefaults(player, catalog, draft)
    local dataSvc = self._dataService
    local data = dataSvc and dataSvc:GetData(player)
    if not data then
        return
    end
    data.GameData = data.GameData or {}
    -- Written only when a kit exists — never a ProfileStore template field.
    data.GameData.RangeDefaults =
        ChallengeRun.writeRangeDefaults(data.GameData.RangeDefaults, catalog, draft)
    dataSvc:RequestSave(player, "range_defaults")
end

function MissionInstanceService:StartChallengeRun(player, request)
    if type(request) ~= "table" then
        return nil, "invalid request"
    end
    local missionId = request.missionId or request.mission
    local mission = missionId and self._config and self._config.missions[missionId]
    if not (mission and mission.gauntlet) then
        return nil, "unknown challenge"
    end
    local mode = mission.gauntlet.mode or missionId
    local modeCfg = self._challengeConfig
        and self._challengeConfig.modes
        and self._challengeConfig.modes[mode]
    if ChallengeRun.soloOnly(modeCfg) and isTeamed(player) then
        self:_rejectRangeTeam(player)
        return nil, "range_solo_required"
    end
    local origin = ChallengeRun.canonicalOrigin(
        request.origin,
        ChallengeRun.knownOrigins(modeCfg and modeCfg.catalog)
    )
    if modeCfg and modeCfg.loadout == "catalog" and not origin then
        return nil, "range_origin_required"
    end
    local loadout =
        ChallengeRun.sanitizeLoadout(modeCfg and modeCfg.catalog, request.pets, request.powers)
    if modeCfg and modeCfg.loadout == "catalog" then
        self:_persistRangeDefaults(player, modeCfg.catalog, {
            origin = origin,
            pets = loadout.pets,
            powers = loadout.powers,
        })
    end
    local instanceId, err = self:Open(player, missionId, {
        catalogPets = loadout.pets,
        catalogPowers = loadout.powers,
        catalogOrigin = origin,
    })
    if not instanceId then
        self:_log("Info", "challenge start rejected", { player = player.Name, err = err })
    end
    return instanceId, err
end

function MissionInstanceService:_applyChallengeLevel(player, pin)
    if type(pin) == "number" and pin >= 1 then
        player:SetAttribute("ChallengeLevel", pin)
    else
        player:SetAttribute("ChallengeLevel", nil)
    end
    local prog = self._playerProgressionService
    if prog and prog.RefreshPublishedState then
        prog:RefreshPublishedState(player)
    elseif type(pin) == "number" and pin >= 1 then
        player:SetAttribute("EffectiveLevel", pin)
    end
end

function MissionInstanceService:_gauntletSolveInputs(mission, roomIndex)
    local mode = (mission.gauntlet and mission.gauntlet.mode) or mission.id
    local modeCfg = self._challengeConfig
        and self._challengeConfig.modes
        and self._challengeConfig.modes[mode]
    local pack = ChallengeRun.packForRoom(modeCfg and modeCfg.curve, roomIndex)
    local params = mergedParams(self._config.solver_defaults, mission.solver_overrides)
    params = mergedParams(params, ChallengeRun.solverOverrides(pack))
    return {
        mode = mode,
        pack = pack,
        params = params,
        contextKey = ChallengeRun.layoutContext(roomIndex, mode),
    }
end

function MissionInstanceService:_prepareGauntlet(record, mission, player, spawnPad)
    if not (mission and mission.gauntlet) then
        return
    end
    local mode = mission.gauntlet.mode or record.missionId
    local modeCfg = self._challengeConfig
        and self._challengeConfig.modes
        and self._challengeConfig.modes[mode]
    record.gauntlet = true
    record.gauntletMode = mode
    record.gauntletRooms = tonumber(mission.gauntlet.rooms)
        or tonumber(modeCfg and modeCfg.curve and modeCfg.curve.rooms)
        or 99
    record.room_index = 1
    record.cleared_room = 0
    record.gauntletCurve = ChallengeRun.packForRoom(modeCfg and modeCfg.curve, 1)
    record.gauntletLoadout = modeCfg and modeCfg.loadout or "own"
    -- Pin combat level before catalog ghosts / ReapplyPassives so Accuracy,
    -- pet realization, and loaned-power stamps all see the rank level.
    local pin = ChallengeRun.effectiveLevel(modeCfg)
    record.challengeLevel = pin
    for _, member in ipairs(membersOf(record.teamKey)) do
        self:_applyChallengeLevel(member, pin)
    end
    if record.gauntletLoadout == "catalog" then
        local loadout = ChallengeRun.sanitizeLoadout(
            modeCfg and modeCfg.catalog,
            record.catalogPets,
            record.catalogPowers
        )
        record.catalogPets = loadout.pets
        record.catalogPowers = loadout.powers
        record.catalogOrigin = ChallengeRun.canonicalOrigin(
            record.catalogOrigin,
            ChallengeRun.knownOrigins(modeCfg.catalog)
        )
        for _, member in ipairs(membersOf(record.teamKey)) do
            self:_applyCatalogLoadout(member, record, spawnPad)
        end
    end
    for _, member in ipairs(membersOf(record.teamKey)) do
        member:SetAttribute("GauntletRoom", 1)
        member:SetAttribute("GauntletNoRevives", true)
        member:SetAttribute("GauntletMode", mode)
    end
end

function MissionInstanceService:_scaleGauntletDef(def, curve)
    if type(def) ~= "table" or type(curve) ~= "table" then
        return def
    end
    local out = table.clone(def)
    out.hp = math.max(1, math.floor((tonumber(def.hp) or 1) * (tonumber(curve.hp_mult) or 1)))
    if type(def.attack) == "table" then
        out.attack = table.clone(def.attack)
        out.attack.damage = math.max(
            1,
            math.floor((tonumber(def.attack.damage) or 0) * (tonumber(curve.dmg_mult) or 1))
        )
    end
    return out
end

function MissionInstanceService:_challengeBestRoom(player, mode)
    local best = 0
    pcall(function()
        local data = self._dataService and self._dataService:GetData(player)
        local runs = data and data.GameData and data.GameData.ChallengeRuns
        local rec = runs and runs[mode]
        best = tonumber(rec and rec.best_room) or 0
    end)
    return best
end

function MissionInstanceService:_persistChallengeBest(record)
    if not record.gauntlet then
        return
    end
    local cleared = math.max(0, math.floor(tonumber(record.cleared_room) or 0))
    for _, member in ipairs(membersOf(record.teamKey)) do
        pcall(function()
            local dataSvc = self._dataService
            local data = dataSvc and dataSvc:GetData(member)
            if not data then
                return
            end
            data.GameData = data.GameData or {}
            -- Written only when a run exists — never a ProfileStore template field.
            data.GameData.ChallengeRuns = data.GameData.ChallengeRuns or {}
            local prev = data.GameData.ChallengeRuns[record.gauntletMode]
            if type(prev) ~= "table" then
                prev = {}
            end
            local window, cap = ChallengeRun.leaderboardWindow(self._challengeConfig)
            local nextRec = ChallengeRun.writeWindowAttempt(prev, cleared, os.time(), {
                window_seconds = window,
                recent_cap = cap,
            })
            data.GameData.ChallengeRuns[record.gauntletMode] = nextRec
            if nextRec.best_room ~= (tonumber(prev.best_room) or 0) or cleared > 0 then
                dataSvc:RequestSave(member, "challenge_run")
            end
            local lbSvc = self._leaderboardService
            if lbSvc and lbSvc.RefreshChallengeBoards and cleared > 0 then
                lbSvc:RefreshChallengeBoards(member, true)
            end
        end)
    end
end

function MissionInstanceService:_squadPets(record)
    local pets = {}
    local root = workspace:FindFirstChild("PlayerPets")
    if not root then
        return pets
    end
    for _, member in ipairs(membersOf(record.teamKey)) do
        local folder = root:FindFirstChild(member.Name)
        if folder then
            for _, model in ipairs(folder:GetChildren()) do
                if model:IsA("Model") and model.PrimaryPart then
                    table.insert(pets, {
                        downed = model:GetAttribute("CombatDowned") == true,
                    })
                end
            end
        end
    end
    return pets
end

function MissionInstanceService:_watchGauntletWipe(record)
    record.wipeWatch = task.spawn(function()
        task.wait(2)
        while self._instances[record.instanceId] and not record.closing do
            if ChallengeRun.squadWiped(self:_squadPets(record)) then
                for _, member in ipairs(membersOf(record.teamKey)) do
                    fireGameEvent(member, "gauntlet_wipe", {
                        mission = record.missionId,
                        room = record.room_index,
                        name = ("Wiped at room %d"):format(record.room_index or 1),
                    })
                end
                self:_close(record.instanceId, "wipe")
                return
            end
            task.wait(0.4)
        end
    end)
end

function MissionInstanceService:_attachExitPrompt(spawnPad, mission, teamKey, instanceId)
    if not spawnPad then
        return
    end
    local exitPrompt = Instance.new("ProximityPrompt")
    exitPrompt.GamepadKeyCode = Enum.KeyCode.ButtonX
    exitPrompt.Name = "MissionExitPrompt"
    exitPrompt.ActionText = "Leave Mission"
    exitPrompt.ObjectText = mission.display or instanceId
    exitPrompt.HoldDuration = 0.25
    exitPrompt.MaxActivationDistance = 10
    exitPrompt.RequiresLineOfSight = false
    exitPrompt.Parent = spawnPad
    exitPrompt.Triggered:Connect(function(who)
        if teamKeyFor(who) == teamKey or who:GetAttribute("InMission") == instanceId then
            self:Abandon(instanceId)
        end
    end)
end

function MissionInstanceService:_attachBeaconPrompts(record, mission, beacons, gated)
    local teamKey = record.teamKey
    local instanceId = record.instanceId
    local missionId = record.missionId
    local prompts = {}
    for _, beacon in ipairs(beacons) do
        local existing = beacon:FindFirstChild("MissionCompletePrompt")
        if existing then
            existing:Destroy()
        end
        local bp = Instance.new("ProximityPrompt")
        bp.GamepadKeyCode = Enum.KeyCode.ButtonX
        bp.Name = "MissionCompletePrompt"
        bp.ActionText = record.gauntlet and "Next Room" or "Complete Mission"
        bp.ObjectText = mission.display or missionId
        bp.HoldDuration = 0.5
        bp.MaxActivationDistance = 12
        bp.RequiresLineOfSight = false
        bp.Enabled = not gated
        bp.Parent = beacon
        table.insert(prompts, bp)
        bp.Triggered:Connect(function(who)
            if teamKeyFor(who) ~= teamKey then
                return
            end
            if gated and beacon:GetAttribute("ObjectiveActive") ~= true then
                return
            end
            if record.gauntlet then
                self:_advanceGauntlet(instanceId)
                return
            end
            for _, member in ipairs(membersOf(teamKey)) do
                fireGameEvent(member, "mission_complete", {
                    mission = missionId,
                    sequence = record.sequence,
                    name = ("%s complete!"):format(mission.display or missionId),
                })
            end
            self:Complete(instanceId)
        end)
    end
    return prompts
end

function MissionInstanceService:_restampGauntlet(record, roomIndex)
    local mission = self._config.missions[record.missionId]
    if not (mission and mission.gauntlet) then
        return false
    end
    local slots = self._config.slots
    local slotOrigin =
        CFrame.new(slots.origin_x + (record.slotIndex - 1) * slots.spacing, slots.y or 0, 0)
    local gauntletInputs = self:_gauntletSolveInputs(mission, roomIndex)
    local contextKey = gauntletInputs.contextKey
    local seed = MissionSeed.seed(record.missionId, contextKey, self._config.worldgen_version)
    local layoutSeed = MissionSeed.stream(seed, "layout")
    local catalog, kitFolder, kitErr = self:_kit(mission.kit)
    if not catalog then
        self:_log("Warn", "gauntlet restamp kit failed", { err = kitErr })
        return false
    end
    local params = gauntletInputs.params
    local spec, report = LayoutSolver.solve(catalog, params, layoutSeed)
    if not spec then
        self:_log("Warn", "gauntlet restamp layout failed", {
            room = roomIndex,
            err = report and report.error,
        })
        return false
    end

    local members = membersOf(record.teamKey)
    local old = record.container
    for _, member in ipairs(members) do
        if old then
            pcall(function()
                old:RemovePersistentPlayer(member)
            end)
        end
        local holdCf = slotOrigin * CFrame.new(0, 24, 0)
        local root = member.Character and member.Character:FindFirstChild("HumanoidRootPart")
        if root then
            root.CFrame = holdCf
        end
        self:_bringSquadWithPlayer(member, holdCf)
    end

    if record.boundsMin then
        local enemySvc = self._enemyService
        if enemySvc and enemySvc.DespawnEnemiesInBounds then
            pcall(function()
                enemySvc:DespawnEnemiesInBounds(record.boundsMin, record.boundsMax)
            end)
        end
    end
    record.enemies = {}
    for _, crate in ipairs(record.crates or {}) do
        if crate.Parent then
            crate:Destroy()
        end
    end
    record.crates = {}

    if old then
        old:Destroy()
    end

    local container, hooks = MissionStamper.stamp(spec, {
        kitFolder = kitFolder,
        slotOrigin = slotOrigin,
        instanceId = record.instanceId,
        yieldEvery = 25,
    })
    container.ModelStreamingMode = Enum.ModelStreamingMode.PersistentPerPlayer
    container:SetAttribute("MissionId", record.missionId)
    container:SetAttribute("MissionSeed", seed)
    container:SetAttribute("GauntletRoom", roomIndex)
    if record.groupScale then
        container:SetAttribute("TrialGroupScale", record.groupScale)
    end
    if record.teamScale then
        container:SetAttribute("TrialTeamScale", record.teamScale)
    end

    local spawnPad = hooks.PlayerSpawn and hooks.PlayerSpawn[1]
    self:_attachExitPrompt(spawnPad, mission, record.teamKey, record.instanceId)

    local beacons = hooks.MissionObjective or {}
    local inertColor = Color3.fromRGB(70, 70, 78)
    for _, beacon in ipairs(beacons) do
        beacon:SetAttribute("ObjectiveActive", false)
        beacon:SetAttribute("ActiveColor", beacon.Color)
        beacon.Color = inertColor
        beacon.Transparency = 0.5
    end
    self:_attachBeaconPrompts(record, mission, beacons, true)

    local slotPos = slotOrigin.Position
    record.seed = seed
    record.container = container
    record.hooks = hooks
    record.boundsMin = Vector3.new(
        slotPos.X + spec.bbox.minx - 20,
        slotPos.Y - 50,
        slotPos.Z + spec.bbox.minz - 20
    )
    record.boundsMax = Vector3.new(
        slotPos.X + spec.bbox.maxx + 20,
        slotPos.Y + 60,
        slotPos.Z + spec.bbox.maxz + 20
    )
    local mapTable = LayoutSolver.mapData(catalog, spec)
    mapTable.ox = slotPos.X
    mapTable.oz = slotPos.Z
    mapTable.name = mission.display or record.missionId
    record.mapTable = mapTable

    local okEncode, encoded = pcall(function()
        return HttpService:JSONEncode(mapTable)
    end)
    for _, member in ipairs(members) do
        container:AddPersistentPlayer(member)
        if okEncode then
            member:SetAttribute("MissionMapData", encoded)
        end
        member:SetAttribute("GauntletRoom", roomIndex)
    end

    if not mission.decor or mission.decor.enabled ~= false then
        self:_applyDressing(
            mission.decor or {},
            mapTable,
            spec,
            container,
            slotOrigin,
            seed,
            mission.theme,
            record,
            mission.realm
        )
    end

    self:_log("Info", "gauntlet restamped", {
        instanceId = record.instanceId,
        room = roomIndex,
        seed = seed,
        tiles = #spec.tiles,
    })
    return true
end

function MissionInstanceService:_advanceGauntlet(instanceId)
    local record = self._instances[instanceId]
    if not record or not record.gauntlet then
        return
    end
    record.cleared_room = record.room_index
    local rooms = record.gauntletRooms or 99
    if record.room_index >= rooms then
        for _, member in ipairs(membersOf(record.teamKey)) do
            fireGameEvent(member, "mission_complete", {
                mission = record.missionId,
                name = ("%s complete!"):format(record.missionId),
            })
        end
        return self:Complete(instanceId)
    end
    local nextRoom = record.room_index + 1
    record.layoutSwap = true
    local restamped = self:_restampGauntlet(record, nextRoom)
    record.room_index = nextRoom
    local modeCfg = self._challengeConfig
        and self._challengeConfig.modes
        and self._challengeConfig.modes[record.gauntletMode]
    record.gauntletCurve = ChallengeRun.packForRoom(modeCfg and modeCfg.curve, nextRoom)
    for _, member in ipairs(membersOf(record.teamKey)) do
        member:SetAttribute("GauntletRoom", nextRoom)
        member:SetAttribute(
            "MissionObjectiveText",
            ("Room %d — Defeat all enemies!"):format(nextRoom)
        )
        fireGameEvent(member, "gauntlet_next_room", {
            mission = record.missionId,
            room = nextRoom,
            name = ("Room %d"):format(nextRoom),
        })
    end
    if not restamped then
        self:_log("Warn", "gauntlet kept previous layout", { room = nextRoom })
    end
    self:_restockGauntlet(record)
    self:_warpToGauntletEntrance(record)
    record.layoutSwap = nil
end

-- Teaching rooms field one pack at the objective even if the map has
-- extra chambers, so growing the layout does not multiply the two whelps.
function MissionInstanceService:_missionSpawnPoints(container, curve)
    local points = {}
    local objective
    for _, desc in ipairs(container:GetDescendants()) do
        if desc.Name == "MissionSpawn" and desc:IsA("BasePart") then
            points[#points + 1] = desc
            if desc:GetAttribute("ObjectiveRoom") then
                objective = desc
            end
        end
    end
    if curve and curve.intro_only == true then
        if objective then
            return { objective }
        end
        if #points > 0 then
            return { points[#points] }
        end
    end
    return points
end

function MissionInstanceService:_entranceCFrame(record)
    local spawnPad = record.hooks and record.hooks.PlayerSpawn and record.hooks.PlayerSpawn[1]
    if not (spawnPad and spawnPad.Parent) then
        return nil
    end
    return spawnPad.CFrame * CFrame.new(0, 4, 0), spawnPad
end

function MissionInstanceService:_petFolder(player)
    local root = workspace:FindFirstChild("PlayerPets")
    return root and root:FindFirstChild(player.Name)
end

-- Pets are client-moved. A restamp leaves them in the last chamber, where
-- they auto-acquire the new pack. RallyUntil + cleared reports keeps them
-- on the owner until both land at the entrance.
function MissionInstanceService:_bringSquadWithPlayer(player, originCf)
    local folder = self:_petFolder(player)
    if not folder then
        return
    end
    player:SetAttribute("RallyUntil", os.clock() + STREAM_WAIT)
    local pfs = self._petFollowService
    if pfs and pfs.ClearReportedPositions then
        pfs:ClearReportedPositions(player)
    end
    local i = 0
    for _, model in ipairs(folder:GetChildren()) do
        if model:IsA("Model") then
            local tid = model:FindFirstChild("TargetID")
            if tid then
                tid.Value = 0
            end
            i += 1
            if originCf then
                pcall(function()
                    model:PivotTo(originCf * CFrame.new((i - 3) * 4, 0, 5))
                end)
            end
        end
    end
end

function MissionInstanceService:_warpToGauntletEntrance(record)
    local targetCF, spawnPad = self:_entranceCFrame(record)
    if not targetCF then
        return
    end
    for _, member in ipairs(membersOf(record.teamKey)) do
        self:_bringSquadWithPlayer(member, targetCF)
        self:_cancelStream(member)
        task.spawn(function()
            local ok = self:_safeWarp(member, targetCF, record.instanceId, spawnPad, 4)
            if not ok then
                local character = member.Character
                if character then
                    pcall(function()
                        character:PivotTo(targetCF)
                    end)
                end
            end
            self:_bringSquadWithPlayer(member, targetCF)
        end)
    end
end

function MissionInstanceService:_restockGauntlet(record)
    local enemySvc = self._enemyService
    if enemySvc and enemySvc.DespawnEnemiesInBounds and record.boundsMin then
        pcall(function()
            enemySvc:DespawnEnemiesInBounds(record.boundsMin, record.boundsMax)
        end)
    else
        for _, model in ipairs(record.enemies or {}) do
            if model and model.Parent then
                model:Destroy()
            end
        end
    end
    record.enemies = {}
    local mission = self._config.missions[record.missionId]
    local container = record.container
    if not (mission and container) then
        return
    end
    local points = self:_missionSpawnPoints(container, record.gauntletCurve)
    if #points == 0 then
        return
    end
    local opener
    for _, member in ipairs(membersOf(record.teamKey)) do
        opener = member
        break
    end
    if not opener then
        return
    end
    local objectivePointIndex
    for i, point in ipairs(points) do
        if point:GetAttribute("ObjectiveRoom") then
            objectivePointIndex = i
            break
        end
    end
    local groupScale = 1
    local teamMult = 1
    local countMult = groupScale
        * teamMult
        * (tonumber(record.gauntletCurve and record.gauntletCurve.count_mult) or 1)
    local enemyDefs = (self._enemiesConfig and self._enemiesConfig.enemies) or {}
    local packs = ChallengeRun.filterPacks(mission.packs or {}, record.gauntletCurve)
    local forceBoss = objectivePointIndex
        and record.gauntletCurve
        and record.gauntletCurve.add_boss == true
    local comp = MissionPopulation.roll(
        packs,
        #points,
        MissionSeed.stream(record.seed, "spawns_r" .. tostring(record.room_index)),
        {
            extraBossBudget = 0,
            villainChance = 0,
            bossPointIndex = forceBoss and objectivePointIndex or nil,
            bossOnlyAtObjective = (self._config.population or {}).boss_only_at_objective,
            countMult = countMult,
            scalesUnit = function(unit)
                if unit.rank == "boss" or unit.rank == "titan" then
                    return false
                end
                local def = unit.enemy and enemyDefs[unit.enemy]
                if def and (def.tier == "boss" or def.tier == "archvillain") then
                    return false
                end
                return true
            end,
        }
    )
    local mapTable = record.mapTable
    local posRng = MissionSeed.mulberry32(
        MissionSeed.stream(record.seed, "spawnpos_r" .. tostring(record.room_index))
    )
    if not enemySvc then
        return
    end
    for i, point in ipairs(points) do
        local movementLeash
        if mapTable then
            local room, roomIndex = LayoutSolver.roomAt(
                mapTable,
                point.Position.X,
                point.Position.Z,
                mapTable.ox,
                mapTable.oz
            )
            if room then
                movementLeash = {
                    shapes = {
                        {
                            kind = "box",
                            cx = mapTable.ox + room.x,
                            cz = mapTable.oz + room.z,
                            halfX = room.hx,
                            halfZ = room.hz,
                        },
                    },
                    inset = tonumber((self._config.navigation or {}).room_inset) or 0,
                    recovery = point.Position + Vector3.new(0, 3, 0),
                    roomIndex = roomIndex,
                }
            end
        end
        for _, entry in ipairs(comp[i] or {}) do
            local offset = Vector3.new((posRng() * 2 - 1) * 14, 3, (posRng() * 2 - 1) * 14)
            pcall(function()
                local enemyId, synthDef
                if type(entry) == "table" and entry.pet then
                    local ladder = self._config.pet_ranks or {}
                    synthDef = enemySvc.SynthesizePetEnemy
                        and enemySvc:SynthesizePetEnemy(
                            entry.pet,
                            ladder[entry.rank or "minion"],
                            record.openerLevel
                        )
                    enemyId = "petinv_" .. entry.pet
                else
                    enemyId = entry
                    local base = enemyDefs[enemyId]
                    if base then
                        synthDef = table.clone(base)
                    end
                end
                if synthDef and record.gauntletCurve then
                    synthDef = self:_scaleGauntletDef(synthDef, record.gauntletCurve)
                end
                local r = enemySvc:SpawnEnemy(opener, enemyId, {
                    def = synthDef,
                    position = point.Position + offset,
                    home = point.Position,
                    movementLeash = movementLeash,
                    encounterGroup = point,
                    dormant = true,
                    persistent = true,
                    ignoreEnemyLevelOffset = true,
                })
                if r and r.ok and r.model then
                    table.insert(record.enemies, r.model)
                end
            end)
        end
    end
end

function MissionInstanceService:_applyCatalogLoadout(player, record, spawnPad)
    local npc = self._npcPrincipalService
    local root = workspace:FindFirstChild("PlayerPets")
    local folder = root and root:FindFirstChild(player.Name)
    if not folder then
        folder = Instance.new("Folder")
        folder.Name = player.Name
        folder.Parent = root or workspace
    end
    local parked = Instance.new("Folder")
    parked.Name = "GauntletParked_" .. player.UserId
    parked.Parent = game:GetService("ServerStorage")
    for _, model in ipairs(folder:GetChildren()) do
        if model:IsA("Model") and not model:GetAttribute("GhostPet") then
            model.Parent = parked
        end
    end
    record.parkedFolders = record.parkedFolders or {}
    record.parkedFolders[player.UserId] = parked
    local origin = spawnPad and spawnPad.CFrame or CFrame.new()
    if npc and npc.SpawnGhostSquad then
        npc:SpawnGhostSquad(folder, record.catalogPets or {}, origin)
    end
    -- Exclusive allowlist even when empty: unselected owned powers (Swift/Magnet/…) stay off.
    player:SetAttribute("ChallengePowers", HttpService:JSONEncode(record.catalogPowers or {}))
    if type(record.catalogOrigin) == "string" and record.catalogOrigin ~= "" then
        player:SetAttribute("ChallengeOrigin", record.catalogOrigin)
    else
        player:SetAttribute("ChallengeOrigin", nil)
    end
    local hotbar = self._hotbarService
    if hotbar and hotbar.SetChallengeBinds then
        hotbar:SetChallengeBinds(player, record.catalogPowers or {})
    end
    local powerSvc = self._powerService
    if powerSvc and powerSvc.ReapplyPassives then
        powerSvc:ReapplyPassives(player)
    end
end

function MissionInstanceService:_restoreGauntletLoadouts(record)
    if not record.parkedFolders then
        return
    end
    local root = workspace:FindFirstChild("PlayerPets")
    for _, member in ipairs(membersOf(record.teamKey)) do
        local folder = root and root:FindFirstChild(member.Name)
        if folder then
            for _, model in ipairs(folder:GetChildren()) do
                if model:GetAttribute("GhostPet") then
                    model:Destroy()
                end
            end
        end
        local parked = record.parkedFolders[member.UserId]
        if parked then
            if folder then
                for _, model in ipairs(parked:GetChildren()) do
                    model.Parent = folder
                end
            end
            parked:Destroy()
        end
        member:SetAttribute("ChallengePowers", nil)
        member:SetAttribute("ChallengeOrigin", nil)
        self:_applyChallengeLevel(member, nil)
        local hotbar = self._hotbarService
        if hotbar and hotbar.ClearChallengeBinds then
            hotbar:ClearChallengeBinds(member)
        end
        local powerSvc = self._powerService
        if powerSvc and powerSvc.ReapplyPassives then
            powerSvc:ReapplyPassives(member)
        end
    end
    record.parkedFolders = nil
end

function MissionInstanceService:GetActiveInstance(player)
    return self._byTeam[teamKeyFor(player)]
end

function MissionInstanceService:_sweep()
    local maxLifetime = self._config.limits.max_lifetime or 1800
    local now = os.clock()
    for instanceId, record in pairs(self._instances) do
        if now - record.createdAt > maxLifetime then
            self:_log("Warn", "TTL sweep abandoning instance", { instanceId = instanceId })
            self:_close(instanceId, "ttl")
        end
    end
    self:_sweepOrphans()
end

-- ---- dressing (M5a) --------------------------------------------------------------

-- Synty prop prefabs by clutter kind (variant picked deterministically from
-- the placement's own coordinates — same seed, same look)
local PROP_PREFABS = {
    crate = { "CrateWood", "CrateWoodB", "CrateOrnate" },
    crate_small = { "CrateOrnate", "CrateWood" },
    barrel = { "Barrel", "BarrelBroken" },
}

-- Ground a Model prefab so its bounding-box bottom sits on the floor at cf.
local function groundModel(model, cf)
    local boxCf, size = model:GetBoundingBox()
    local pivotToBottom = model:GetPivot().Position.Y - (boxCf.Position.Y - size.Y / 2)
    model:PivotTo(cf * CFrame.new(0, pivotToBottom, 0))
end

local function prefabFor(kind, pick)
    local names = PROP_PREFABS[kind]
    if not names then
        return nil
    end
    local store = ReplicatedStorage:FindFirstChild("MissionProps")
    local prefab = store and store:FindFirstChild(names[1 + pick % #names])
    return prefab and prefab:Clone()
end

local PROP_BUILDERS = {
    crate = function(cf)
        local p = Instance.new("Part")
        p.Size = Vector3.new(4, 4, 4)
        p.Color = Color3.fromRGB(120, 85, 46)
        p.Material = Enum.Material.WoodPlanks
        p.CFrame = cf * CFrame.new(0, 2, 0)
        return { p }
    end,
    crate_small = function(cf)
        local p = Instance.new("Part")
        p.Size = Vector3.new(2.5, 2.5, 2.5)
        p.Color = Color3.fromRGB(134, 96, 54)
        p.Material = Enum.Material.WoodPlanks
        p.CFrame = cf * CFrame.new(0, 1.25, 0)
        return { p }
    end,
    barrel = function(cf)
        local p = Instance.new("Part")
        p.Shape = Enum.PartType.Cylinder
        p.Size = Vector3.new(4.5, 3.2, 3.2) -- cylinder axis = X; stood upright below
        p.Color = Color3.fromRGB(96, 68, 40)
        p.Material = Enum.Material.Wood
        p.CFrame = cf * CFrame.new(0, 2.25, 0) * CFrame.Angles(0, 0, math.rad(90))
        return { p }
    end,
    rubble = function(cf)
        local parts = {}
        for i = 1, 3 do
            local p = Instance.new("Part")
            local s = 1.4 + i * 0.5
            p.Size = Vector3.new(s, s * 0.8, s)
            p.Color = Color3.fromRGB(105, 102, 110)
            p.Material = Enum.Material.Slate
            p.CFrame = cf
                * CFrame.new((i - 2) * 1.6, s * 0.4, (i % 2 == 0) and 1.2 or -0.8)
                * CFrame.Angles(0, i * 0.9, 0)
            table.insert(parts, p)
        end
        return parts
    end,
}

-- Realm-split palettes (Jason): hell = dark ember-lit, heaven = bright
-- marble + gold. Applied over the kit's base colors before the tint jitter;
-- torches recolor too (flame part + its PointLight). nil theme = kit as-is.
local THEME_PALETTES = {
    hell = {
        banner = Color3.fromRGB(115, 30, 28), -- WallBanner cloth tint (Jason 2026-07-15: theme-appropriate hangings)
        -- rough NATURAL surfaces (Jason: walls too "finished" for a hell
        -- dungeon) — Basalt/Slate breaks the smooth-plastic read for free
        wall = Color3.fromRGB(52, 40, 44),
        wallMaterial = "Basalt",
        floor = Color3.fromRGB(72, 52, 50),
        floorMaterial = "Slate",
        pillar = Color3.fromRGB(38, 30, 34),
        pillarMaterial = "Basalt",
        beacon = Color3.fromRGB(255, 60, 30),
        torchFlame = Color3.fromRGB(255, 110, 40),
        torchLight = Color3.fromRGB(255, 120, 60),
        -- the altar's ember colorway (Maps.Home.AscensionAltar NativeFX)
        fire = {
            color = Color3.fromRGB(255, 60, 10),
            secondary = Color3.fromRGB(120, 10, 5),
            size = 4,
            heat = 6,
        },
    },
    lava = {
        banner = Color3.fromRGB(140, 48, 22), -- WallBanner cloth tint (Jason 2026-07-15: theme-appropriate hangings)
        -- molten variant of hell: cracked-lava floors, ember-veined basalt
        wall = Color3.fromRGB(58, 36, 32),
        wallMaterial = "Basalt",
        floor = Color3.fromRGB(96, 44, 30),
        floorMaterial = "CrackedLava",
        pillar = Color3.fromRGB(40, 26, 24),
        pillarMaterial = "Basalt",
        beacon = Color3.fromRGB(255, 90, 20),
        torchFlame = Color3.fromRGB(255, 130, 30),
        torchLight = Color3.fromRGB(255, 140, 60),
        fire = {
            color = Color3.fromRGB(255, 80, 10),
            secondary = Color3.fromRGB(140, 20, 5),
            size = 4,
            heat = 7,
        },
    },
    ice = {
        banner = Color3.fromRGB(38, 62, 130), -- WallBanner cloth tint (Jason 2026-07-15: theme-appropriate hangings)
        -- glacial: pale blue ice walls, frosted light — cold mirror of lava
        wall = Color3.fromRGB(168, 196, 214),
        wallMaterial = "Ice",
        floor = Color3.fromRGB(196, 218, 232),
        floorMaterial = "Glacier",
        pillar = Color3.fromRGB(140, 176, 200),
        pillarMaterial = "Ice",
        beacon = Color3.fromRGB(90, 200, 255),
        torchFlame = Color3.fromRGB(150, 210, 255),
        torchLight = Color3.fromRGB(170, 220, 255),
        torchMaterial = "Glass",
        torchBrightness = 0.8,
        torchRange = 18,
        fire = {
            color = Color3.fromRGB(140, 200, 255),
            secondary = Color3.fromRGB(60, 110, 180),
            size = 3,
            heat = 4,
        },
    },
    grass = {
        banner = Color3.fromRGB(48, 92, 52), -- WallBanner cloth tint (Jason 2026-07-15: theme-appropriate hangings)
        -- overgrown ruin: mossy stone, leafy light
        wall = Color3.fromRGB(96, 118, 82),
        wallMaterial = "Slate",
        floor = Color3.fromRGB(88, 124, 74),
        floorMaterial = "Grass",
        pillar = Color3.fromRGB(76, 96, 66),
        pillarMaterial = "Slate",
        beacon = Color3.fromRGB(120, 255, 120),
        torchFlame = Color3.fromRGB(180, 255, 140),
        torchLight = Color3.fromRGB(190, 255, 170),
        fire = {
            color = Color3.fromRGB(160, 255, 120),
            secondary = Color3.fromRGB(60, 140, 60),
            size = 3,
            heat = 4,
        },
    },
    desert = {
        banner = Color3.fromRGB(152, 104, 42), -- WallBanner cloth tint (Jason 2026-07-15: theme-appropriate hangings)
        -- sun-baked sandstone: warm grit
        wall = Color3.fromRGB(194, 156, 108),
        wallMaterial = "Sandstone",
        floor = Color3.fromRGB(210, 178, 128),
        floorMaterial = "Sand",
        pillar = Color3.fromRGB(168, 132, 88),
        pillarMaterial = "Sandstone",
        beacon = Color3.fromRGB(255, 190, 60),
        torchFlame = Color3.fromRGB(255, 170, 60),
        torchLight = Color3.fromRGB(255, 190, 110),
        fire = {
            color = Color3.fromRGB(255, 160, 40),
            secondary = Color3.fromRGB(150, 80, 20),
            size = 4,
            heat = 6,
        },
    },
    heaven = {
        banner = Color3.fromRGB(228, 204, 148), -- WallBanner cloth tint (Jason 2026-07-15: theme-appropriate hangings)
        -- v3 (playtest: "it's the torches" — near-white NEON orbs bloomed the
        -- whole scene): heaven torches are decorative gilded GLASS orbs with
        -- a whisper of light; the bright ambient does the illuminating.
        wall = Color3.fromRGB(206, 198, 182),
        wallMaterial = "Marble", -- Jason: heaven = marble
        floor = Color3.fromRGB(224, 217, 202),
        floorMaterial = "Marble",
        pillar = Color3.fromRGB(206, 176, 110),
        pillarMaterial = "Marble",
        beacon = Color3.fromRGB(255, 210, 80),
        torchFlame = Color3.fromRGB(240, 205, 120),
        torchLight = Color3.fromRGB(255, 230, 170),
        torchMaterial = "Glass",
        torchBrightness = 0.35,
        torchRange = 12,
        -- the altar's golden colorway, candle-small (Fire renders soft — no
        -- neon bloom, unlike the v1 whiteout)
        fire = {
            color = Color3.fromRGB(255, 200, 100),
            secondary = Color3.fromRGB(255, 240, 200),
            size = 2.5,
            heat = 5,
        },
    },
}

-- One-time (lazy): swap the preloaded MissionCrate placeholder visual for
-- the Synty crate prefab when the place carries it. Runtime store
-- augmentation, AssetPreloadService pattern; retried until the store exists.
-- Recompute every blessed decor mesh fingerprint and WARN on drift. The
-- hash must match DecorFingerprints' bless-time computation EXACTLY
-- (FNV-1a over 0.01-quantized vertex positions).
function MissionInstanceService:_assetRotCheck()
    local okReq, DecorFingerprints = pcall(function()
        return require(ReplicatedStorage.Shared.Assets.DecorFingerprints)
    end)
    if not okReq or type(DecorFingerprints) ~= "table" then
        return
    end
    local AssetService = game:GetService("AssetService")
    local drifted, checked = 0, 0
    for name, fp in pairs(DecorFingerprints) do
        local ok, err = pcall(function()
            -- selene: allow(undefined_variable)
            local em = AssetService:CreateEditableMeshAsync(Content.fromUri(fp.mesh))
            local verts = em:GetVertices()
            local h = 2166136261
            local function mix(n)
                n = math.floor(n * 100 + 0.5) % 4294967296
                h = (h + n) % 4294967296
                h = (h * 16777619) % 4294967296
            end
            for _, vid in ipairs(verts) do
                local p = em:GetPosition(vid)
                mix(p.X)
                mix(p.Y)
                mix(p.Z)
            end
            local nv, nf = #verts, #em:GetFaces()
            em:Destroy()
            if h ~= fp.hash or nv ~= fp.verts or nf ~= fp.faces then
                drifted += 1
                self:_log("Warn", "[ROT ALARM] decor mesh drifted from its blessed fingerprint", {
                    prop = name,
                    mesh = fp.mesh,
                    hash = h .. " vs " .. fp.hash,
                    verts = nv .. " vs " .. fp.verts,
                    faces = nf .. " vs " .. fp.faces,
                })
            end
        end)
        if ok then
            checked += 1
        elseif tostring(err):find("not accessible") then
            -- EditableMesh gated by Game Settings -> Security -> Allow Mesh
            -- & Image APIs. One pointer, not twenty.
            self:_log(
                "Warn",
                "[ROT ALARM] SKIPPED — enable 'Allow Mesh & Image APIs' in Game Settings > Security"
            )
            return
        else
            drifted += 1
            self:_log("Warn", "[ROT ALARM] decor mesh UNLOADABLE", {
                prop = name,
                mesh = fp.mesh,
                error = tostring(err),
            })
        end
        task.wait(0.2) -- spread the memory/network cost
    end
    if drifted == 0 then
        self:_log("Info", "asset rot check clean", { checked = checked })
    else
        self:_log("Warn", "[ROT ALARM] SUMMARY: decor assets drifted", {
            drifted = drifted,
            checked = checked,
        })
    end
end

function MissionInstanceService:_ensureMissionCrateVisual()
    -- SELF-HEALING, NO SESSION LATCH (2026-07-15): the truth is the STORE
    -- MODEL's CrateVisual attribute, not a service flag. A `_crateVisualDone`
    -- latch let one early return (or a boot-time store rebuild / prebake
    -- adoption of the crystal placeholder) leave crates crystal-skinned for
    -- the whole session. Now every crate spawn re-checks the actual store
    -- state and re-swaps when anything clobbered it.
    local store = ReplicatedStorage:FindFirstChild("Assets")
    store = store and store:FindFirstChild("Models")
    store = store and store:FindFirstChild("Breakables")
    store = store and store:FindFirstChild("Crystals")
    if not store then
        return -- preload not done yet; retry on the next spawn
    end
    local existing = store:FindFirstChild("MissionCrate")
    if existing and existing:GetAttribute("CrateVisual") then
        return -- the real crate is in place
    end
    local props = ReplicatedStorage:FindFirstChild("MissionProps")
    local crate = props and props:FindFirstChild("CrateWood")
    if not crate then
        self:_log("Warn", "MissionCrate visual swap deferred (CrateWood not replicated yet)", {
            missionProps = tostring(props ~= nil),
        })
        return
    end
    local fresh = crate:Clone()
    fresh.Name = "MissionCrate"
    -- break SFX (Jason's crate-smash upload): the death handler plays a
    -- Sound named bigBreakSound from the child container named after the
    -- model — name the mesh accordingly so the sound is 3D-positional
    local mesh = fresh:FindFirstChildWhichIsA("MeshPart")
    if mesh then
        mesh.Name = "MissionCrate"
        local def = Sounds.crate_smash
        if type(def) == "table" and type(def.id) == "string" and def.id ~= "" then
            local smash = Instance.new("Sound")
            smash.Name = "bigBreakSound"
            smash.SoundId = def.id
            smash.Volume = tonumber(def.volume) or 0.4
            smash.PlaybackSpeed = tonumber(def.playback_speed) or 1
            smash.RollOffMaxDistance = 60
            -- route through the effects bus or the Settings sliders can't touch it
            local SoundGroups = require(ReplicatedStorage.Shared.Effects.SoundGroups)
            SoundGroups.assign(smash, "effects")
            smash.Parent = mesh
        end
    end
    fresh:SetAttribute("CrateVisual", true) -- the self-heal marker (see top)
    if existing then
        existing:Destroy()
    end
    fresh.Parent = store
    -- loud so the 2026-07-15 placeholder-forever incident (crates spawning
    -- as sideways crystals) can never hide again
    self:_log("Warn", "MissionCrate visual swapped to CrateWood prefab (store was the placeholder)")
end

-- Per-room tint jitter + seeded primitive clutter (pure rolls from
-- MissionDecor; this just materializes them).
-- element themes borrow the realm prefab pools (wall decor / features /
-- fixtures / caps) until they get bespoke sets: lava = hell's, ice = heaven's
local THEME_POOL_ALIAS = { lava = "hell", ice = "heaven", grass = "heaven", desert = "hell" }

-- CANDLE FLAME TRUTH TABLE (Jason 2026-07-14, captured live from his
-- hand-fixed CandleStand after the flames drifted TWICE — once from the
-- gen-1 harvest, once when a stale MissionProps.rbxm clobbered an unsaved
-- in-place fix): pivot-relative offsets of the nine flame points, plus the
-- Fire/light dressing each carries. _normalizeCandleStand() re-asserts this
-- at boot, so no matter what state the rbxm ships, every candelabra lights
-- correctly. If art changes the stand, update THIS table (it wins).
local CANDLE_FLAME_POINTS = {
    C1 = Vector3.new(1.7856, 3.15, 1.0),
    C2 = Vector3.new(0, 3.55, 1.8),
    C3 = Vector3.new(-1.5856, 3.15, 0.8),
    C4 = Vector3.new(-1.5856, 3.15, -0.9269),
    C5 = Vector3.new(0, 3.6, -1.8),
    C6 = Vector3.new(1.5856, 3.55, -1.0),
    C7 = Vector3.new(-1.2936, 4.55, 0.1035),
    C8 = Vector3.new(0.5643, 4.75, -1.106),
    C9 = Vector3.new(0.6081, 4.95, 1.0025),
}
local CANDLE_FIRE = { size = 2, heat = 2.5 }
local CANDLE_FIRE_COLOR = Color3.new(1, 0.784314, 0.392157)
local CANDLE_FIRE_SECONDARY = Color3.new(1, 0.941176, 0.784314)
local CANDLE_LIGHT = { key = "C1", brightness = 0.4, range = 12 }
local CANDLE_LIGHT_COLOR = Color3.new(1, 0.901961, 0.666667)

-- Re-assert the CandleStand flame layout against the truth table above.
-- Runs at Start (and is safe to call any time): repositions drifted flame
-- parts, recreates missing ones (transparent anchored cubes + Fire),
-- prunes unknown TorchFlame_C* extras, and guarantees the C1 point light.
-- WARNs whenever it corrects anything — silent drift is how we got here.
function MissionInstanceService:_normalizeCandleStand()
    local store = ReplicatedStorage:FindFirstChild("MissionProps")
    local stand = store and store:FindFirstChild("CandleStand")
    if not (stand and stand:IsA("Model")) then
        return
    end
    local pivot = stand:GetPivot()
    local fixed, created, pruned = 0, 0, 0
    local wanted = {}
    for key, rel in pairs(CANDLE_FLAME_POINTS) do
        local name = "TorchFlame_" .. key
        wanted[name] = true
        local part = stand:FindFirstChild(name)
        if not part then
            part = Instance.new("Part")
            part.Name = name
            part.Size = Vector3.new(0.4, 0.4, 0.4)
            part.Transparency = 1
            part.Anchored = true
            part.CanCollide = false
            part.CanQuery = false
            part.CanTouch = false
            part.Parent = stand
            created += 1
        elseif (pivot:PointToObjectSpace(part.Position) - rel).Magnitude > 0.05 then
            fixed += 1
        end
        part.CFrame = pivot * CFrame.new(rel)
        local fire = part:FindFirstChildOfClass("Fire")
        if not fire then
            fire = Instance.new("Fire")
            fire.Parent = part
        end
        fire.Size = CANDLE_FIRE.size
        fire.Heat = CANDLE_FIRE.heat
        fire.Color = CANDLE_FIRE_COLOR
        fire.SecondaryColor = CANDLE_FIRE_SECONDARY
        if key == CANDLE_LIGHT.key and not part:FindFirstChildOfClass("PointLight") then
            local light = Instance.new("PointLight")
            light.Brightness = CANDLE_LIGHT.brightness
            light.Range = CANDLE_LIGHT.range
            light.Color = CANDLE_LIGHT_COLOR
            light.Parent = part
        end
    end
    for _, child in ipairs(stand:GetChildren()) do
        if child.Name:match("^TorchFlame_C%d+$") and not wanted[child.Name] then
            child:Destroy()
            pruned += 1
        end
    end
    if fixed + created + pruned > 0 then
        self:_log("Warn", "CandleStand flames NORMALIZED (rbxm drifted from the truth table)", {
            repositioned = fixed,
            created = created,
            pruned = pruned,
        })
    end
end

function MissionInstanceService:_applyDressing(
    decorCfg,
    mapTable,
    spec,
    container,
    slotOrigin,
    seed,
    theme,
    record,
    realm
)
    local rollOpts = {}
    for k, v in pairs(decorCfg) do
        rollOpts[k] = v
    end
    -- ICONOGRAPHY FOLLOWS ALLEGIANCE (Jason 2026-07-14: demon skull banners
    -- hung in Heaven Lava — "seems inappropriate, don't you think?"): decor
    -- POOLS key off the mission's REALM when it has one (banners, crests,
    -- features, doorway fixtures are faction art), while THEME keeps owning
    -- the palette/tints/atmosphere (lava still glows ember in heaven). The
    -- element alias remains the fallback for realm-less AND neutral missions
    -- (neutral element trials have no faction — their decor reads the biome).
    local poolRealm = (realm == "heaven" or realm == "hell") and realm or nil
    local poolTheme = poolRealm or THEME_POOL_ALIAS[theme] or theme
    rollOpts.doors = mapTable.doors -- wall decor avoids doorway apertures
    local tints, props, wallDecor, features =
        MissionDecor.roll(mapTable.rooms, MissionSeed.stream(seed, "dressing"), rollOpts)
    local palette = THEME_PALETTES[theme]

    -- doorway FIXTURE variety v2 (playtest: primitive stick torches read
    -- "dumb" even with fire — retire them entirely when prefabs exist):
    --   hell   — ~45% of pairs BrazierFire (floor), the rest TorchOrnateFire
    --   heaven — CandleStand everywhere (Jason: "the candelabras look great")
    -- Pair-coherent + deterministic (hash of tile name + pair index); the
    -- primitive torches remain only as the no-prefab fallback.
    do
        local store = ReplicatedStorage:FindFirstChild("MissionProps")
        local function fixtureFor(hash)
            if not store then
                return nil
            end
            if poolTheme == "hell" then
                local primary = hash % 100 < 45 and "BrazierFire" or "TorchOrnateFire"
                return store:FindFirstChild(primary) or store:FindFirstChild("BrazierFire")
            elseif poolTheme == "heaven" then
                return store:FindFirstChild("CandleStand")
            end
            return nil
        end
        local slotY = slotOrigin.Position.Y
        for _, tileModel in ipairs(container:GetChildren()) do
            if tileModel:IsA("Model") then
                local nameHash = 0
                for i = 1, #tileModel.Name do
                    nameHash = (nameHash * 31 + tileModel.Name:byte(i)) % 997
                end
                for _, ch in ipairs(tileModel:GetChildren()) do
                    local idx = tonumber(ch.Name:match("^TorchBracket_(%d+)$"))
                    if idx then
                        local pairIdx = math.ceil(idx / 2)
                        local fixture = fixtureFor(nameHash + pairIdx * 131)
                        if fixture then
                            local flame = tileModel:FindFirstChild("TorchFlame_" .. idx)
                            local clone = fixture:Clone()
                            -- MountY attr (prefab-authored): wall fixtures
                            -- hang above the floor (ornate torches at 5)
                            local mountY = clone:GetAttribute("MountY") or 0
                            groundModel(
                                clone,
                                CFrame.new(ch.Position.X, slotY + mountY, ch.Position.Z)
                            )
                            clone.Parent = tileModel
                            if flame then
                                flame:Destroy()
                            end
                            ch:Destroy()
                        end
                    end
                end
            end
        end
    end

    -- SEALED-CAP dressing v2 (Jason: "get rid of the planks and put like a
    -- bookcase in front" — dark boards clash in heaven): heaven seals its
    -- doorways with FURNITURE. Strip the plank/board/padlock dressing, retint
    -- the backing slab to the marble palette, and park one of the nice
    -- bookcases centered in the alcove. Hell keeps its boards — they belong.
    if poolTheme == "heaven" then
        local store = ReplicatedStorage:FindFirstChild("MissionProps")
        local shelves = { "heaven_gilded_bookcase", "heaven_archive" }
        for _, tileModel in ipairs(container:GetChildren()) do
            if tileModel:IsA("Model") and tileModel.Name:match("^cap_") then
                for _, ch in ipairs(tileModel:GetChildren()) do
                    if
                        ch.Name:match("^Board_")
                        or ch.Name:match("^Plank_")
                        or ch.Name:match("^Brace_")
                        or ch.Name == "Knob"
                        or ch.Name == "Padlock"
                        or ch.Name == "Shackle"
                    then
                        ch:Destroy()
                    elseif ch.Name == "Backing" and ch:IsA("BasePart") and palette then
                        ch.Color = palette.wall
                        ch.Material = Enum.Material[palette.wallMaterial or "SmoothPlastic"]
                    end
                end
                local capHash = 0
                for i = 1, #tileModel.Name do
                    capHash = (capHash * 31 + tileModel.Name:byte(i)) % 997
                end
                local prefab = store
                    and (
                        store:FindFirstChild(shelves[1 + capHash % #shelves])
                        or store:FindFirstChild(shelves[1])
                    )
                if prefab then
                    local clone = prefab:Clone()
                    local mountY = clone:GetAttribute("MountY") or 4.5
                    local standOff = clone:GetAttribute("StandOff") or 1.2
                    -- cap pivot sits ON the aperture plane with -Z facing the
                    -- open room; the shelf fronts the room a shelf-depth out
                    clone:PivotTo(tileModel:GetPivot() * CFrame.new(0, mountY, -standOff))
                    clone.Parent = tileModel
                end
            end
        end
    end

    -- theme base coat first: walls/floors/pillars/torches across EVERY tile
    -- (caps + corridors included), so the realm identity is total
    if palette then
        for _, inst in ipairs(container:GetDescendants()) do
            if inst:IsA("BasePart") then
                local n = inst.Name
                if n == "Floor" then
                    inst.Color = palette.floor
                    if palette.floorMaterial then
                        inst.Material = Enum.Material[palette.floorMaterial]
                    end
                elseif n:sub(1, 5) == "Wall_" or n:sub(1, 7) == "Header_" or n == "Backing" then
                    inst.Color = palette.wall
                    if palette.wallMaterial then
                        inst.Material = Enum.Material[palette.wallMaterial]
                    end
                elseif n:sub(1, 7) == "Pillar_" then
                    inst.Color = palette.pillar
                    if palette.pillarMaterial then
                        inst.Material = Enum.Material[palette.pillarMaterial]
                    end
                elseif n == "ObjectiveBeacon" then
                    inst.Color = palette.beacon
                elseif n:sub(1, 11) == "TorchFlame_" then
                    inst.Color = palette.torchFlame
                    if palette.torchMaterial then
                        inst.Material = Enum.Material[palette.torchMaterial]
                    end
                    local light = inst:FindFirstChildOfClass("PointLight")
                    if light then
                        light.Color = palette.torchLight
                        if palette.torchBrightness then
                            light.Brightness = palette.torchBrightness
                        end
                        if palette.torchRange then
                            light.Range = palette.torchRange
                        end
                    end
                    -- the altar's REAL fire on every remaining torch (soft
                    -- render, themed colorway — kills the placeholder read)
                    if palette.fire and not inst:FindFirstChildOfClass("Fire") then
                        local fire = Instance.new("Fire")
                        fire.Color = palette.fire.color
                        fire.SecondaryColor = palette.fire.secondary
                        fire.Size = palette.fire.size
                        fire.Heat = palette.fire.heat
                        fire.Parent = inst
                    end
                end
            end
        end
    end

    -- tint: walls/headers/pillars one factor, floor another — rooms stop
    -- reading as copies of each other
    for i, room in ipairs(mapTable.rooms) do
        local t = tints[i]
        local model = container:FindFirstChild(spec.tiles[room.tile].tileId .. "_" .. room.tile)
        if t and model then
            for _, part in ipairs(model:GetChildren()) do
                if part:IsA("BasePart") then
                    local f
                    if part.Name == "Floor" then
                        f = t.floor
                    elseif
                        part.Name:sub(1, 5) == "Wall_"
                        or part.Name:sub(1, 7) == "Header_"
                        or part.Name:sub(1, 7) == "Pillar_"
                    then
                        f = t.wall
                    end
                    if f then
                        local c = part.Color
                        part.Color = Color3.new(
                            math.clamp(c.R * f, 0, 1),
                            math.clamp(c.G * f, 0, 1),
                            math.clamp(c.B * f, 0, 1)
                        )
                    end
                end
            end
        end
    end

    -- clutter props: harvested Synty prefabs when the place carries them
    -- (ReplicatedStorage.MissionProps — free Roblox-published dungeon packs),
    -- primitive builders otherwise so fresh checkouts/tests never break
    local folder = Instance.new("Folder")
    folder.Name = "Dressing"
    -- FARMABLE debris (Jason): crates/barrels spawn as REAL breakables via
    -- BreakableSpawner mission pseudo-worlds — clickable, auto-farmable,
    -- pet-cleared (doorway blockage becomes gameplay). Falls back to inert
    -- prefab/primitive props when the spawner or config is unavailable.
    local breakableSvc = nil
    if decorCfg.farmable_props ~= false then
        pcall(function()
            local svc = self._breakableSpawner
            if svc and svc.SpawnMissionBreakable then
                breakableSvc = svc
            end
        end)
    end
    local FARMABLE_KIND = { crate = true, crate_small = true, barrel = true }
    local pseudoWorld = "mission_" .. (theme or "earth")
    for _, prop in ipairs(props) do
        local cf = slotOrigin * CFrame.new(prop.x, 0, prop.z) * CFrame.Angles(0, prop.rot, 0)
        local spawned = nil
        -- CRYSTAL NODES (Jason 2026-07-15, born from the crate-placeholder
        -- accident he liked): rubble slots spawn REAL farmable crystals —
        -- upright + sunk via SmallBlueCrystal's own placement config —
        -- instead of inert primitive rubble. Same level-scaling as crates.
        if breakableSvc and prop.kind == "rubble" and decorCfg.crystal_nodes ~= false then
            -- THEMED node families (Jason 2026-07-15: "a lava trial should
            -- have red crystals"): the zone ore families already exist —
            -- pick by theme, deterministic variant per slot. SmallBlueCrystal
            -- stays the fallback for unthemed missions.
            local NODE_FAMILY = {
                lava = "Emberstone",
                hell = "Emberstone",
                ice = "Frostshard",
                heaven = "Frostshard",
                grass = "Bloomstone",
                desert = "Sunglass",
            }
            local fam = NODE_FAMILY[theme or ""]
            local nodeId = "SmallBlueCrystal"
            if fam then
                nodeId = fam .. "SmallV" .. (1 + math.floor(math.abs(prop.x) * 13) % 3)
            end
            local okSpawn, model = pcall(function()
                return breakableSvc:SpawnMissionBreakable(
                    pseudoWorld,
                    nodeId,
                    cf.Position + Vector3.new(0, 1, 0),
                    cf.Position.Y -- TRUE floor: the family's sink knobs align to this
                )
            end)
            if okSpawn and model then
                spawned = model
                -- UPRIGHT ENFORCER (2026-07-15): the SmallBlueCrystal store
                -- model ships sideways in stale Models.rbxm captures and the
                -- preload adopt path keeps whatever the bake carries. Align
                -- the spawned node's bounding-box up-axis to world Y here so
                -- nodes stand regardless of store state (yaw preserved).
                local bcf = model:GetBoundingBox()
                if bcf.UpVector.Y < 0.95 then
                    local axis = bcf.UpVector:Cross(Vector3.yAxis)
                    if axis.Magnitude > 1e-4 then
                        local angle = math.acos(math.clamp(bcf.UpVector.Y, -1, 1))
                        local pivot = model:GetPivot()
                        model:PivotTo(
                            CFrame.new(pivot.Position)
                                * CFrame.fromAxisAngle(axis.Unit, angle)
                                * (pivot - pivot.Position)
                        )
                    end
                end
                local lvl = (record and record.openerLevel) or 1
                model:SetAttribute("MiningLevel", lvl)
                local hpScaled = (decorCfg.crystal_health_base or 90)
                    + lvl * (decorCfg.crystal_health_per_level or 15)
                model:SetAttribute("MaxHP", hpScaled)
                model:SetAttribute("HP", hpScaled)
                model:SetAttribute(
                    "Value",
                    (decorCfg.crystal_value_base or 8)
                        + math.floor(lvl * (decorCfg.crystal_value_per_level or 1))
                )
                if record and record.crates then
                    table.insert(record.crates, model)
                end
            else
                self:_log("Warn", "mission crystal node spawn failed", {
                    err = not okSpawn and tostring(model) or "returned nil",
                })
            end
        end
        if breakableSvc and FARMABLE_KIND[prop.kind] then
            self:_ensureMissionCrateVisual()
            -- Never present the SmallBlueCrystal placeholder as a crate.
            -- If CrateWood has not swapped in, fall through to wood prefab
            -- / primitive so Trials and Range cannot spawn sideways crystals.
            local crystals = ReplicatedStorage:FindFirstChild("Assets")
            crystals = crystals and crystals:FindFirstChild("Models")
            crystals = crystals and crystals:FindFirstChild("Breakables")
            crystals = crystals and crystals:FindFirstChild("Crystals")
            local missionCrate = crystals and crystals:FindFirstChild("MissionCrate")
            local crateReady = missionCrate and missionCrate:GetAttribute("CrateVisual") == true
            local okSpawn, model = false, nil
            if crateReady then
                okSpawn, model = pcall(function()
                    return breakableSvc:SpawnMissionBreakable(
                        pseudoWorld,
                        "MissionCrate",
                        cf.Position + Vector3.new(0, 2, 0),
                        cf.Position.Y -- TRUE floor for the bbox aligner
                    )
                end)
            else
                self:_log("Warn", "mission crate using wood fallback (CrateVisual not ready)")
            end
            if crateReady then
                if okSpawn and model then
                    spawned = model
                    -- crates track the OPENER's level, not the pseudo-zone's
                    -- default 1 — else the over-leveled yield gate starves the
                    -- payout ("up the damage compared to my level", 2026-07-08)
                    local lvl = (record and record.openerLevel) or 1
                    model:SetAttribute("MiningLevel", lvl)
                    -- LEVEL-SCALED durability + payout (playtest: flat 60 HP =
                    -- one-shot for an endgame squad). Knobs in mission decor cfg.
                    local hpScaled = (decorCfg.crate_health_base or 60)
                        + lvl * (decorCfg.crate_health_per_level or 12)
                    model:SetAttribute("MaxHP", hpScaled)
                    model:SetAttribute("HP", hpScaled)
                    model:SetAttribute(
                        "Value",
                        (decorCfg.crate_value_base or 15)
                            + math.floor(lvl * (decorCfg.crate_value_per_level or 1))
                    )
                    if record and record.crates then
                        table.insert(record.crates, model)
                    end
                else
                    -- surface the real failure (a silent pcall here cost a debug
                    -- round on 2026-07-08 — don't repeat it)
                    self:_log("Warn", "mission crate spawn failed", {
                        err = not okSpawn and tostring(model) or "returned nil",
                    })
                end
            end
        end
        local prefab = not spawned and prefabFor(prop.kind, math.floor(math.abs(prop.x) * 10))
        if prefab then
            prefab.Name = "Prop_" .. prop.kind
            groundModel(prefab, cf)
            prefab.Parent = folder
        elseif not spawned then
            local builder = PROP_BUILDERS[prop.kind]
            if builder then
                for _, part in ipairs(builder(cf)) do
                    part.Name = "Prop_" .. prop.kind
                    part.Anchored = true
                    part.CanTouch = false
                    part.TopSurface = Enum.SurfaceType.Smooth
                    part.BottomSurface = Enum.SurfaceType.Smooth
                    part.Parent = folder
                end
            end
        end
    end
    -- WALL DECORATIONS (Jason): banners / bronze weapon mounts on room
    -- walls, doorway-aware spots from MissionDecor. Prefabs are harvested
    -- into MissionProps (WallBanner now; CrossedSwords/WallAxe when built) —
    -- missing prefabs skip silently so this never blocks a fresh checkout.
    local WALL_DECOR_PREFABS = {
        -- hell: bronze arms + grim shields + dirty shelves (Jason's set)
        -- + Meshy batch 2026-07-08 (skull banner/crest/sconce)
        hell = {
            "WallBanner",
            "CrossedSwords",
            "WallAxe",
            "WallShield",
            "hell_infernal_archive",
            "hell_skull_banner",
            "hell_infernal_crest",
            "hell_skull_sconce",
        },
        -- heaven: gilded arms + ornate shields + clean shelves
        heaven = {
            "WallBanner",
            "CrossedSwordsGold",
            "WallShieldOrnate",
            "heaven_gilded_bookcase",
            "heaven_archive",
            "heaven_compass_banner",
            "heaven_flamecrest_shield",
        },
        earth = { "WallBanner", "WallShield" },
    }
    do
        local store = ReplicatedStorage:FindFirstChild("MissionProps")
        local names = WALL_DECOR_PREFABS[poolTheme or "earth"]
        local slotPos2 = slotOrigin.Position
        if store and names and wallDecor then
            for _, wd in ipairs(wallDecor or {}) do
                local prefab
                local base = math.floor(math.abs(wd.x) * 7)
                for attempt = 0, #names - 1 do
                    prefab = store:FindFirstChild(names[1 + (base + attempt) % #names])
                    if prefab then
                        break
                    end
                end
                if prefab then
                    local clone = prefab:Clone()
                    -- THEME-TINTED HANGINGS (Jason 2026-07-15): the plain
                    -- Synty WallBanner shows up in every mission — tint its
                    -- cloth to the room's theme (palette.banner). Legacy
                    -- Synty props are Part+SpecialMesh: textured SpecialMesh
                    -- tints via VertexColor, MeshParts via Color.
                    if clone.Name == "WallBanner" then
                        local pal = THEME_PALETTES[theme or ""]
                        local tint = pal and pal.banner
                        if tint then
                            for _, dd in ipairs(clone:GetDescendants()) do
                                if dd:IsA("SpecialMesh") then
                                    dd.VertexColor = Vector3.new(tint.R, tint.G, tint.B)
                                elseif dd:IsA("MeshPart") then
                                    -- MeshPart.Color does NOT composite over
                                    -- TextureID (verified live 2026-07-15:
                                    -- navy Color, still-salmon render) —
                                    -- strip the atlas and go flat. Synty is
                                    -- flat-shaded; the pole tints too, reads
                                    -- as painted wood.
                                    dd.TextureID = ""
                                    dd.Color = tint
                                end
                            end
                        end
                    end
                    -- MountY = hang height (blades/banners) or half-height
                    -- (floor-standers like bookshelves); StandOff pushes the
                    -- piece off the wall plane by its own depth
                    local mountY = clone:GetAttribute("MountY") or 10
                    local standOff = clone:GetAttribute("StandOff") or 0.4
                    local pos =
                        Vector3.new(slotPos2.X + wd.x, slotPos2.Y + mountY, slotPos2.Z + wd.z)
                    clone:PivotTo(
                        CFrame.lookAt(pos, pos + Vector3.new(wd.ix, 0, wd.iz))
                            * CFrame.new(0, 0, -standOff)
                    )
                    clone.Parent = folder
                end
            end
        end
    end

    -- FEATURE showpieces (Meshy batches): one themed floor piece per rolled
    -- chamber spot — thrones/fountains/archives/gates give rooms an identity
    -- beyond scatter clutter. Same silent-skip contract as wall decor: a
    -- missing prefab (fresh checkout, unbuilt batch) never blocks dressing.
    local FEATURE_PREFABS = {
        hell = {
            "hell_infernal_throne",
            "hell_infernal_fountain",
            "hell_gate_of_damned",
            "hell_skull_lantern",
        },
        heaven = {
            "heaven_marble_throne",
            "heaven_ivory_throne",
            "heaven_golden_throne",
            "heaven_star_fountain",
            "heaven_diamond_altar",
            "heaven_golden_codex",
            "heaven_golden_guardian",
        },
        earth = {},
    }
    do
        local store = ReplicatedStorage:FindFirstChild("MissionProps")
        local names = FEATURE_PREFABS[poolTheme or "earth"]
        local slotPos3 = slotOrigin.Position
        if store and names and #names > 0 and features then
            for _, ft in ipairs(features) do
                local prefab
                local base = math.floor(math.abs(ft.z) * 7)
                for attempt = 0, #names - 1 do
                    prefab = store:FindFirstChild(names[1 + (base + attempt) % #names])
                    if prefab then
                        break
                    end
                end
                if prefab then
                    local clone = prefab:Clone()
                    -- floor-stander: MountY = half height (base on the floor),
                    -- StandOff pushes the piece its own depth off the wall
                    local mountY = clone:GetAttribute("MountY") or 5
                    local standOff = clone:GetAttribute("StandOff") or 2
                    local pos =
                        Vector3.new(slotPos3.X + ft.x, slotPos3.Y + mountY, slotPos3.Z + ft.z)
                    clone:PivotTo(
                        CFrame.lookAt(pos, pos + Vector3.new(ft.ix, 0, ft.iz))
                            * CFrame.new(0, 0, -standOff)
                    )
                    clone.Parent = folder
                end
            end
        end
    end

    folder.Parent = container
    self:_log("Info", "dressing applied", {
        props = #props,
        wallDecor = wallDecor and #wallDecor or 0,
        features = features and #features or 0,
    })
end

-- ---- treasure ------------------------------------------------------------------

local function buildChest(cf)
    -- Synty chest prefab when harvested into the place (real treasure-chest
    -- mesh, Jason ask); primitive fallback below keeps fresh checkouts alive
    local store = ReplicatedStorage:FindFirstChild("MissionProps")
    local prefab = store
        and (store:FindFirstChild("TreasureChestOrnate") or store:FindFirstChild("TreasureChest"))
    if prefab then
        local chest = prefab:Clone()
        chest.Name = "TreasureChest"
        -- the Synty prefab ships WITHOUT a PrimaryPart — parenting the
        -- prompt/glow to nil was SILENT (2026-07-15: unopenable, glowless
        -- chests). Anchor one before anything parents to it.
        if not chest.PrimaryPart then
            chest.PrimaryPart = chest:FindFirstChildWhichIsA("BasePart", true)
        end
        groundModel(chest, cf)
        local glow = Instance.new("PointLight")
        glow.Color = Color3.fromRGB(255, 200, 80)
        glow.Brightness = 0.8
        glow.Range = 12
        glow.Parent = chest.PrimaryPart
        local lid = chest:FindFirstChild("Lid") or chest.PrimaryPart
        return chest, lid, glow
    end

    local chest = Instance.new("Model")
    chest.Name = "TreasureChest"
    local function slab(name, size, offset, color, material)
        local p = Instance.new("Part")
        p.Name = name
        p.Size = size
        p.Color = color
        p.Material = material
        p.Anchored = true
        p.CanCollide = true
        p.CFrame = cf * offset
        p.Parent = chest
        return p
    end
    local base = slab(
        "Base",
        Vector3.new(6, 3.5, 4),
        CFrame.new(0, 1.75, 0),
        Color3.fromRGB(96, 62, 32),
        Enum.Material.Wood
    )
    slab(
        "Band",
        Vector3.new(6.2, 0.6, 4.2),
        CFrame.new(0, 3.2, 0),
        Color3.fromRGB(255, 200, 80),
        Enum.Material.Metal
    )
    local lid = slab(
        "Lid",
        Vector3.new(6, 1.4, 4),
        CFrame.new(0, 4.2, 0),
        Color3.fromRGB(116, 76, 40),
        Enum.Material.Wood
    )
    local glow = Instance.new("PointLight")
    glow.Color = Color3.fromRGB(255, 200, 80)
    glow.Brightness = 0.8
    glow.Range = 12
    glow.Parent = base
    chest.PrimaryPart = base
    return chest, lid, glow
end

-- Seeded chest placement in "room"-class rects; prompt-gated guaranteed
-- enhancement payouts via DropService source "treasure".
function MissionInstanceService:_placeTreasures(
    tCfg,
    mapTable,
    container,
    slotOrigin,
    seed,
    teamKey,
    record
)
    local rooms = {}
    for _, room in ipairs(mapTable.rooms) do
        if room.class == "room" then
            table.insert(rooms, room)
        end
    end
    if #rooms == 0 then
        return
    end
    local rng = MissionSeed.mulberry32(MissionSeed.stream(seed, "decor"))
    -- deterministic shuffle, then take the first N rooms
    for i = #rooms, 2, -1 do
        local j = math.floor(rng() * i) + 1
        rooms[i], rooms[j] = rooms[j], rooms[i]
    end
    local count = math.clamp(
        math.floor(#rooms * (tCfg.room_fraction or 0.4) + 0.5),
        tCfg.min_chests or 1,
        #rooms
    )

    local chests = {}
    local slotPos = slotOrigin.Position
    for i = 1, count do
        local room = rooms[i]
        local ox = (rng() * 2 - 1) * math.max(room.hx - 10, 0)
        local oz = (rng() * 2 - 1) * math.max(room.hz - 10, 0)
        local cf = slotOrigin
            * CFrame.new(room.x + ox, 0, room.z + oz)
            * CFrame.Angles(0, rng() * math.pi * 2, 0)
        local chest, lid, glow = buildChest(cf)
        chest.Parent = container

        local prompt = Instance.new("ProximityPrompt")
        prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
        prompt.Name = "TreasurePrompt"
        prompt.ActionText = "Open Treasure"
        prompt.ObjectText = "Chest"
        -- deliberate 3s stand-and-hold (Jason): no drive-by looting
        prompt.HoldDuration = tCfg.open_hold or 3
        prompt.MaxActivationDistance = 10
        prompt.RequiresLineOfSight = false
        prompt.Enabled = false -- locked until the gate loop below clears it
        prompt.Parent = chest.PrimaryPart

        local state = { opened = false }
        table.insert(chests, {
            state = state,
            prompt = prompt,
            light = glow,
            -- the chest's ROOM rect in world coords (+margin), for the
            -- room-clear lock below
            rect = {
                minx = slotPos.X + room.x - room.hx - 6,
                maxx = slotPos.X + room.x + room.hx + 6,
                minz = slotPos.Z + room.z - room.hz - 6,
                maxz = slotPos.Z + room.z + room.hz + 6,
            },
        })

        prompt.Triggered:Connect(function(who)
            if state.opened or teamKeyFor(who) ~= teamKey then
                return
            end
            state.opened = true
            prompt.Enabled = false
            -- SHARED LOOT (Jason: "if one player opens a chest, all the
            -- teammates should get a roll") — same philosophy as kill credit
            -- (TM5) and completion counters: everyone IN the mission rolls
            -- their own payout and ticks the treasure-hunter counter. A team
            -- has at most one open mission, so InMission = this one.
            local sharers = {}
            for _, member in ipairs(membersOf(teamKey)) do
                if member:GetAttribute("InMission") then
                    table.insert(sharers, member)
                end
            end
            if #sharers == 0 then
                sharers = { who }
            end
            pcall(function() -- treasure-hunter quest substrate
                local statsSvc = self._statsService
                for _, member in ipairs(sharers) do
                    statsSvc:Increment(member, "mission_chests_opened", 1)
                end
            end)
            -- pop the lid; payout rolls are loot-random (placement was the
            -- deterministic part)
            lid.CFrame = lid.CFrame * CFrame.new(0, 0.6, -1.4) * CFrame.Angles(math.rad(-55), 0, 0)
            local dropSvc
            pcall(function()
                dropSvc = self._dropService
            end)
            if dropSvc and dropSvc.TrySpawnEnhancementDrop then
                local forward = chest.PrimaryPart.CFrame.LookVector
                for m, member in ipairs(sharers) do
                    local rolls = math.random(tCfg.rolls_min or 1, tCfg.rolls_max or 2)
                    for r = 1, rolls do
                        pcall(function()
                            dropSvc:TrySpawnEnhancementDrop(
                                member,
                                "treasure",
                                chest.PrimaryPart.Position
                                    + forward * 5
                                    + Vector3.new((m - 1) * 2.5, 2, (r - 1.5) * 2)
                            )
                        end)
                    end
                end
            end
            self:_log("Info", "treasure opened", { by = who.Name, sharers = #sharers })
        end)
    end

    -- CLEAR-GATED chests (Jason): a chest stays locked until ITS ROOM's
    -- enemies are down — pets do the clearing, so an invulnerable pet-less
    -- runner can't loot either (same logic as the glowy gate). Locked =
    -- prompt hidden + red glow; cleared = prompt live + gold glow. The loop
    -- dies with the container.
    task.spawn(function()
        while container.Parent do
            for _, c in ipairs(chests) do
                if not c.state.opened then
                    local locked = false
                    for _, model in ipairs(record.enemies or {}) do
                        if model.Parent then
                            local okP, pos = pcall(function()
                                return model:GetPivot().Position
                            end)
                            if
                                okP
                                and pos
                                and pos.X >= c.rect.minx
                                and pos.X <= c.rect.maxx
                                and pos.Z >= c.rect.minz
                                and pos.Z <= c.rect.maxz
                            then
                                locked = true
                                break
                            end
                        end
                    end
                    c.prompt.Enabled = not locked
                    if c.light then
                        c.light.Color = locked and Color3.fromRGB(255, 80, 60)
                            or Color3.fromRGB(255, 200, 80)
                    end
                end
            end
            task.wait(0.5)
        end
    end)

    self:_log("Info", "treasures placed", { count = count })
end

-- ---- door binding --------------------------------------------------------------

-- Streaming-safe warp (2026-07-08: fell through the heaven-trial floor;
-- hardened 2026-08-02 after a production Hell Ice Trial #2 fall-through).
-- With StreamingEnabled the freshly-stamped interior hasn't reached the
-- client when we pivot, and the CLIENT owns character physics — so it falls
-- through geometry only the server has. The place-level integrity setting remains defense in
-- depth; the actual release gate is now a client-observed collidable floor from the expected map.
function MissionInstanceService:_safeWarp(
    member,
    targetCF,
    expectedInstanceId,
    focusPart,
    fallbackSeconds
)
    local character = member.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root then
        return false
    end

    -- RequestStreamAroundAsync has no success result: returning after its timeout is not proof
    -- that a production client owns the floor. Keep an additional replication focus on the
    -- destination and wait for MissionStreamGuard's client-side floor raycast instead.
    if focusPart and focusPart.Parent then
        pcall(function()
            member:AddReplicationFocus(focusPart)
        end)
    end

    local pending = {
        token = HttpService:GenerateGUID(false),
        instanceId = expectedInstanceId,
        ready = false,
        done = false,
        signal = Instance.new("BindableEvent"),
    }
    self._streamPending[member] = pending
    Signals.MissionStreamRequest:FireClient(member, {
        token = pending.token,
        instanceId = expectedInstanceId,
        x = targetCF.Position.X,
        y = targetCF.Position.Y,
        z = targetCF.Position.Z,
    })

    -- Same-slot gauntlet restamps already have PersistentPerPlayer geometry nearby.
    -- Don't wait forever for a stream ack — land in the entryway anyway.
    if type(fallbackSeconds) == "number" and fallbackSeconds > 0 then
        task.delay(fallbackSeconds, function()
            if not pending.done then
                pending.ready = true
                pending.done = true
                pending.signal:Fire()
            end
        end)
    end

    -- Server-side prefetch remains useful, but it is not the readiness gate. Run it in parallel;
    -- the BindableEvent below is fired only by the client floor acknowledgement or cancellation.
    task.spawn(function()
        pcall(function()
            member:RequestStreamAroundAsync(targetCF.Position, STREAM_WAIT)
        end)
    end)

    if not pending.done then
        pending.signal.Event:Wait()
    end

    if self._streamPending[member] == pending then
        self._streamPending[member] = nil
    end
    pending.signal:Destroy()
    if focusPart then
        pcall(function()
            member:RemoveReplicationFocus(focusPart)
        end)
    end
    if not pending.ready or not member.Parent then
        return false
    end

    -- Re-resolve after the yield: a respawn may have replaced the character while streaming.
    character = member.Character
    root = character and character:FindFirstChild("HumanoidRootPart")
    if not root then
        return false
    end
    character:PivotTo(targetCF)
    return true
end

-- The realm gates are quest-aware, so WHICH trial the E-prompt opens is
-- per-player state (active binding + your own sequence head). Publish it as
-- the NextTrialLabel attribute; MissionGatePrompt stamps it onto the door
-- prompt locally (a shared ProximityPrompt can't show per-player text).
function MissionInstanceService:_refreshGateLabel(player)
    local label = "Random Trial"
    local bound
    pcall(function()
        local quests = self._questService
        bound = quests and quests.GetActiveMissionBinding and quests:GetActiveMissionBinding(player)
    end)
    local def = bound and self._config.missions[bound]
    if def then
        local played = 0
        pcall(function()
            local dataSvc = self._dataService
            local data = dataSvc:GetData(player)
            played = (
                data
                and data.GameData
                and data.GameData.MissionSeq
                and tonumber(data.GameData.MissionSeq[bound])
            ) or 0
        end)
        label = (def.display or bound) .. " #" .. (played + 1)
    end
    player:SetAttribute("NextTrialLabel", label)
end

function MissionInstanceService:_bindDoor(part)
    if not part:IsA("BasePart") or part:FindFirstChild(PROMPT_NAME) then
        return
    end
    -- StudioOnly doors (the spawn-plaza dev gates): boot-and-go shortcuts in
    -- Studio; silent in production — the REAL entries live inside the realm
    -- layers (Maps.Heaven_2 / Hell_2 mission gates).
    if part:GetAttribute("StudioOnly") and not game:GetService("RunService"):IsStudio() then
        return
    end
    local missionId = part:GetAttribute("MissionId")
    -- "random" is a mission SOURCE (rolls from config.random.pool at entry);
    -- Open() handles the roll + the quest-unlock gate per trigger
    local mission
    if missionId == "random" or missionId == "auto" then
        mission = self._config.random
        if not mission then
            return
        end
    else
        mission = missionId and self._config.missions[missionId]
    end
    if not mission then
        self:_log("Warn", "MissionDoor with unknown MissionId", {
            part = part:GetFullName(),
            missionId = tostring(missionId),
        })
        return
    end

    local prompt = Instance.new("ProximityPrompt")
    prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
    prompt.Name = PROMPT_NAME
    prompt.ActionText = "Enter " .. (mission.display or missionId)
    prompt.ObjectText = "Mission"
    prompt.HoldDuration = 0.25
    prompt.MaxActivationDistance = 12
    prompt.RequiresLineOfSight = false
    prompt.Parent = part

    -- which realm this door stands in ("hell"/"heaven"/nil): Maps.<Realm>_n
    -- ancestry — realm gates deal their own side's randoms when unbound
    local doorRealm
    do
        local node = part
        while node and node ~= workspace do
            if node.Name:match("^Hell_%d+$") then
                doorRealm = "hell"
                break
            elseif node.Name:match("^Heaven_%d+$") then
                doorRealm = "heaven"
                break
            end
            node = node.Parent
        end
    end

    prompt.Triggered:Connect(function(player)
        local mode = mission.gauntlet and mission.gauntlet.mode
        local modeCfg = mode
            and self._challengeConfig
            and self._challengeConfig.modes
            and self._challengeConfig.modes[mode]
        if modeCfg and modeCfg.loadout == "catalog" then
            if ChallengeRun.soloOnly(modeCfg) and isTeamed(player) then
                self:_rejectRangeTeam(player)
                return
            end
            fireGameEvent(player, "range_picker", {
                mission = missionId,
                display = mission.display or missionId,
                catalog = modeCfg.catalog,
                best_room = self:_challengeBestRoom(player, mode),
                defaults = self:_rangeDefaults(player, modeCfg.catalog),
            })
            return
        end
        local instanceId, err = self:Open(player, missionId, { doorRealm = doorRealm })
        if not instanceId then
            self:_log("Info", "door open rejected", { player = player.Name, err = err })
        end
    end)
end

return MissionInstanceService
