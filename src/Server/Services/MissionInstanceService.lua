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
    stream(seed, "layout"). The resolved seed is stamped on the container so
    any map a player saw can be regenerated exactly.

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

local MissionSeed = require(ReplicatedStorage.Shared.Worldgen.MissionSeed)
local MissionPopulation = require(ReplicatedStorage.Shared.Worldgen.MissionPopulation)
local MissionDecor = require(ReplicatedStorage.Shared.Worldgen.MissionDecor)
local TileCatalog = require(ReplicatedStorage.Shared.Worldgen.TileCatalog)
local LayoutSolver = require(ReplicatedStorage.Shared.Worldgen.LayoutSolver)
local GrayBoxKit = require(ReplicatedStorage.Shared.Worldgen.GrayBoxKit)
local TileKitBuilder = require(ServerScriptService.Server.World.TileKitBuilder)
local MissionStamper = require(ServerScriptService.Server.World.MissionStamper)

local PROMPT_NAME = "MissionDoorPrompt"
-- streaming-safe warp caps (see _safeWarp)
local STREAM_WAIT = 8 -- pre-warp yield cap (seconds)
local ANCHOR_CAP = 2 -- post-warp safety-anchor cap (seconds)
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
end

function MissionInstanceService:Start()
    if not self._config then
        return
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
        folder = store:FindFirstChild(kitId) or TileKitBuilder.build(kit, store)
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
function MissionInstanceService:Open(player, missionId)
    if not self._config then
        return nil, "missions unavailable"
    end
    -- RANDOM MISSIONS (Jason's ladder): "random" is a mission SOURCE, not a
    -- mission — roll a real config from the pool per entry. Gated behind the
    -- quest-granted profile unlock; the attempt counter below already gives
    -- every entry a fresh seed. record.source keeps the ladder counter honest.
    local source = missionId
    if missionId == "random" then
        local rnd = self._config.random
        if not (rnd and rnd.pool and #rnd.pool > 0) then
            return nil, "random missions not configured"
        end
        if rnd.unlock and not self:_hasUnlock(player, rnd.unlock) then
            return nil, "locked: complete the mission quest to unlock random trials"
        end
        missionId = rnd.pool[math.random(#rnd.pool)]
    end
    local mission = self._config.missions[missionId]
    if not mission then
        return nil, "unknown mission " .. tostring(missionId)
    end

    local teamKey = teamKeyFor(player)
    if self._byTeam[teamKey] then
        return nil, "team already has an active mission"
    end
    local live = 0
    for _ in pairs(self._instances) do
        live += 1
    end
    if live >= (self._config.limits.global or 6) then
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
        return nil, "no free mission slot"
    end
    local slots = self._config.slots
    local slotOrigin = CFrame.new(slots.origin_x + (slotIndex - 1) * slots.spacing, slots.y or 0, 0)

    -- seed (docs §3)
    local contextKey
    if mission.seed_policy == "team_stable" then
        contextKey = teamKey
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
    local params = mergedParams(self._config.solver_defaults, mission.solver_overrides)
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
    container:SetAttribute("MissionId", missionId)
    container:SetAttribute("MissionSeed", seed)

    -- teleport the party in, remembering where each member stood
    local spawnPad = hooks.PlayerSpawn and hooks.PlayerSpawn[1]
    local cameraMaxZoom = self._config.camera and self._config.camera.max_zoom
    -- exit prompt on the entrance pad (CoH: you leave through the door you
    -- came in). Lives inside the container, so teardown removes it. Only the
    -- instance's own team can trigger it.
    if spawnPad then
        local exitPrompt = Instance.new("ProximityPrompt")
        exitPrompt.Name = "MissionExitPrompt"
        exitPrompt.ActionText = "Leave Mission"
        exitPrompt.ObjectText = mission.display or missionId
        exitPrompt.HoldDuration = 0.25
        exitPrompt.MaxActivationDistance = 10
        exitPrompt.RequiresLineOfSight = false
        exitPrompt.Parent = spawnPad
        exitPrompt.Triggered:Connect(function(who)
            if teamKeyFor(who) == teamKey then
                self:Abandon(instanceId)
            end
        end)
    end
    local returnCFrames = {}
    local savedZoom = {}
    for _, member in ipairs(membersOf(teamKey)) do
        local character = member.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        if root and spawnPad then
            returnCFrames[member.UserId] = root.CFrame
            -- async: each member streams the interior in parallel and warps
            -- when THEIR client has the floor (see _safeWarp)
            task.spawn(function()
                self:_safeWarp(member, CFrame.new(spawnPad.Position + Vector3.new(0, 4, 0)))
            end)
            -- in-mission marker: DropService kills the magnet on it (walk to
            -- your loot); generally useful for any per-mission gating
            member:SetAttribute("InMission", instanceId)
            member:SetAttribute("MissionTheme", mission.theme or "earth")
            -- camera clamp: tall walls + capped zoom = no craning over the
            -- maze to scout the glowy; restored on exit
            if cameraMaxZoom then
                savedZoom[member.UserId] = member.CameraMaxZoomDistance
                member.CameraMaxZoomDistance = cameraMaxZoom
            end
        end
    end

    -- world-space despawn bounds for teardown (generous margin + Y band)
    local slotPos = slotOrigin.Position
    local record = {
        instanceId = instanceId,
        missionId = missionId,
        source = source, -- "random" when opened via the random door (quest ladder)
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

    -- STATIC population (CoH model): field a seeded, fixed pack at every
    -- MissionSpawn anchor, once. No proximity waves, no respawn — the
    -- homeworld BaddieSpawner system never runs inside missions.
    record.enemies = {}
    do
        local points = {}
        for _, desc in ipairs(container:GetDescendants()) do
            if desc.Name == "MissionSpawn" and desc:IsA("BasePart") then
                table.insert(points, desc)
            end
        end
        local comp =
            MissionPopulation.roll(mission.packs or {}, #points, MissionSeed.stream(seed, "spawns"))
        local posRng = MissionSeed.mulberry32(MissionSeed.stream(seed, "spawnpos"))
        local SCATTER = 14 -- studs around the anchor (rooms are 96+ wide at 6x scale)
        local enemySvc
        pcall(function()
            local locator = _G.RBXTemplateServices
            enemySvc = locator and locator:Get("EnemyService")
        end)
        if enemySvc then
            for i, point in ipairs(points) do
                for _, enemyId in ipairs(comp[i] or {}) do
                    local offset =
                        Vector3.new((posRng() * 2 - 1) * SCATTER, 3, (posRng() * 2 - 1) * SCATTER)
                    pcall(function()
                        local r = enemySvc:SpawnEnemy(player, enemyId, {
                            position = point.Position + offset,
                            home = point.Position,
                            dormant = true, -- no birth aggro: engage when the team arrives
                            persistent = true, -- never idle-despawn: defeat or teardown only
                        })
                        if r and r.ok and r.model then
                            table.insert(record.enemies, r.model)
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
    local mapTable = LayoutSolver.mapData(catalog, spec)
    do
        local okEncode, encoded = pcall(function()
            mapTable.name = mission.display or missionId
            mapTable.ox = slotOrigin.Position.X
            mapTable.oz = slotOrigin.Position.Z
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
            record
        )
    end

    -- TREASURE (CoH glowie-lite, M5): seeded chests in a few rooms; opening
    -- one pays GUARANTEED enhancement drops to the opener (DropService
    -- source "treasure"). Placement rides the decor stream (deterministic);
    -- chest contents stay loot-random. Chests die with the container.
    if mission.treasure then
        self:_placeTreasures(mission.treasure, mapTable, container, slotOrigin, seed, teamKey, record)
    end

    -- Objective monitor. Kinds:
    --   reach_beacon       — touch the glowy, done (courier style)
    --   clear_then_beacon  — the glowy is INERT until every mission enemy is
    --                        defeated (CoH clear-gate; also the anti-cheese:
    --                        invulnerable players can walk anywhere, but only
    --                        pets can clear, so pets are mandatory)
    local kind = mission.objective and mission.objective.kind
    if kind == "reach_beacon" or kind == "clear_then_beacon" then
        local beacons = hooks.MissionObjective or {}
        local gated = kind == "clear_then_beacon"
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
        local total = #record.enemies
        local function publish(text, count, fraction)
            for _, member in ipairs(membersOf(teamKey)) do
                member:SetAttribute("MissionObjectiveText", text)
                member:SetAttribute("MissionObjectiveCount", count)
                member:SetAttribute("MissionObjectiveFraction", fraction)
            end
        end
        if gated and total > 0 then
            publish("Defeat all enemies!", ("0/%d"):format(total), 0)
        else
            publish("Reach the glowing beacon!", "★", 1)
        end

        record.monitor = task.spawn(function()
            local cleared = not gated or #record.enemies == 0
            local lastDown = -1
            while self._instances[instanceId] do
                if not cleared then
                    local alive = 0
                    for _, model in ipairs(record.enemies) do
                        if model.Parent then
                            alive += 1
                        end
                    end
                    local down = total - alive
                    if down ~= lastDown then
                        lastDown = down
                        publish("Defeat all enemies!", ("%d/%d"):format(down, total), down / total)
                    end
                    -- CoH straggler pings: with only a few enemies left, the
                    -- map shows them (hunting the last crow in the dark is
                    -- frustration, not gameplay — 2026-07-08 hell playtest)
                    local pings = nil
                    if alive > 0 and alive <= 3 then
                        local list = {}
                        for _, model in ipairs(record.enemies) do
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
                        publish("Objective active — reach the glowing beacon!", "★", 1)
                        self:_log("Info", "objective activated — mission cleared", {
                            instanceId = instanceId,
                        })
                    end
                else
                    for _, member in ipairs(membersOf(teamKey)) do
                        local mroot = member.Character
                            and member.Character:FindFirstChild("HumanoidRootPart")
                        if mroot then
                            for _, beacon in ipairs(beacons) do
                                if
                                    beacon.Parent
                                    and (mroot.Position - beacon.Position).Magnitude <= 12
                                then
                                    self:Complete(instanceId)
                                    return
                                end
                            end
                        end
                    end
                end
                task.wait(0.5)
            end
        end)
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

-- Quest-granted persistent unlocks (GameData.Unlocks.<id>, written by
-- QuestService:Claim). Server-authoritative: reads the profile, never attrs.
function MissionInstanceService:_hasUnlock(player, unlockId)
    local ok, has = pcall(function()
        local locator = _G.RBXTemplateServices
        local dataSvc = locator and locator:Get("DataService")
        local data = dataSvc and dataSvc:GetData(player)
        local unlocks = data and data.GameData and data.GameData.Unlocks
        return unlocks and unlocks[unlockId] == true
    end)
    return ok and has == true
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

    -- stop the objective monitor (unless we're being called FROM it)
    if record.monitor and record.monitor ~= coroutine.running() then
        pcall(task.cancel, record.monitor)
    end

    -- COMPLETION counters (quest ladder substrate): every team member's
    -- career totals tick; random-sourced runs also tick the random ladder
    if reason == "complete" then
        pcall(function()
            local statsSvc = _G.RBXTemplateServices:Get("StatsService")
            for _, member in ipairs(membersOf(record.teamKey)) do
                statsSvc:Increment(member, "missions_completed", 1)
                if record.source == "random" then
                    statsSvc:Increment(member, "random_missions_completed", 1)
                end
            end
        end)
    end

    -- return surviving members to where they entered from; clear mission
    -- HUD state and restore their camera zoom
    local warping = 0
    for _, member in ipairs(membersOf(record.teamKey)) do
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
        member:SetAttribute("MissionObjectiveText", nil)
        member:SetAttribute("MissionObjectiveCount", nil)
        member:SetAttribute("MissionObjectiveFraction", nil)
        member:SetAttribute("MissionMapData", nil)
        member:SetAttribute("InMission", nil)
        member:SetAttribute("MissionTheme", nil)
        member:SetAttribute("MissionEnemyPings", nil)
        local zoom = record.savedZoom and record.savedZoom[member.UserId]
        if zoom then
            member.CameraMaxZoomDistance = zoom
        end
    end

    -- enemies born inside the mission die with it — never loiter at the slot
    if record.boundsMin then
        pcall(function()
            local locator = _G.RBXTemplateServices
            local enemySvc = locator and locator:Get("EnemyService")
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
    local deadline = os.clock() + STREAM_WAIT + ANCHOR_CAP + 1
    while warping > 0 and os.clock() < deadline do
        task.wait(0.1)
    end

    record.container:Destroy()
    self._slots[record.slotIndex] = nil
    self._byTeam[record.teamKey] = nil
    self._instances[instanceId] = nil
    self:_log("Info", "closed", { instanceId = instanceId, reason = reason })
    return true
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
    heaven = {
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
function MissionInstanceService:_ensureMissionCrateVisual()
    if self._crateVisualDone then
        return
    end
    local store = ReplicatedStorage:FindFirstChild("Assets")
    store = store and store:FindFirstChild("Models")
    store = store and store:FindFirstChild("Breakables")
    store = store and store:FindFirstChild("Crystals")
    local props = ReplicatedStorage:FindFirstChild("MissionProps")
    local crate = props and props:FindFirstChild("CrateWood")
    if not store then
        return -- preload not done yet; retry on the next spawn
    end
    self._crateVisualDone = true
    if not crate then
        return -- no prefab in this place: placeholder crystal visual stands
    end
    local fresh = crate:Clone()
    fresh.Name = "MissionCrate"
    -- break SFX (Jason's crate-smash upload): the death handler plays a
    -- Sound named bigBreakSound from the child container named after the
    -- model — name the mesh accordingly so the sound is 3D-positional
    local mesh = fresh:FindFirstChildWhichIsA("MeshPart")
    if mesh then
        mesh.Name = "MissionCrate"
        local smash = Instance.new("Sound")
        smash.Name = "bigBreakSound"
        -- group-owned upload (scripts/audio_ids.json crate_smash)
        smash.SoundId = "rbxassetid://119529368267127"
        smash.Volume = 0.4 -- playtest: raw 0.8 was blasting
        smash.RollOffMaxDistance = 60
        -- route through the effects bus or the Settings sliders can't touch it
        local SoundGroups = require(ReplicatedStorage.Shared.Effects.SoundGroups)
        SoundGroups.assign(smash, "effects")
        smash.Parent = mesh
    end
    local old = store:FindFirstChild("MissionCrate")
    if old then
        old:Destroy()
    end
    fresh.Parent = store
end

-- Per-room tint jitter + seeded primitive clutter (pure rolls from
-- MissionDecor; this just materializes them).
function MissionInstanceService:_applyDressing(decorCfg, mapTable, spec, container, slotOrigin, seed, theme, record)
    local rollOpts = {}
    for k, v in pairs(decorCfg) do
        rollOpts[k] = v
    end
    rollOpts.doors = mapTable.doors -- wall decor avoids doorway apertures
    local tints, props, wallDecor, features = MissionDecor.roll(
        mapTable.rooms,
        MissionSeed.stream(seed, "dressing"),
        rollOpts
    )
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
            if theme == "hell" then
                local primary = hash % 100 < 45 and "BrazierFire" or "TorchOrnateFire"
                return store:FindFirstChild(primary)
                    or store:FindFirstChild("BrazierFire")
            elseif theme == "heaven" then
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
    if theme == "heaven" then
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
                    and (store:FindFirstChild(shelves[1 + capHash % #shelves]) or store:FindFirstChild(shelves[1]))
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
        local model = container:FindFirstChild(
            spec.tiles[room.tile].tileId .. "_" .. room.tile
        )
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
            local locator = _G.RBXTemplateServices
            local svc = locator and locator:Get("BreakableSpawner")
            if svc and svc.SpawnMissionBreakable then
                breakableSvc = svc
            end
        end)
    end
    local FARMABLE_KIND = { crate = true, crate_small = true, barrel = true }
    local pseudoWorld = "mission_" .. (theme or "earth")
    for _, prop in ipairs(props) do
        local cf = slotOrigin
            * CFrame.new(prop.x, 0, prop.z)
            * CFrame.Angles(0, prop.rot, 0)
        local spawned = nil
        if breakableSvc and FARMABLE_KIND[prop.kind] then
            self:_ensureMissionCrateVisual()
            local okSpawn, model = pcall(function()
                return breakableSvc:SpawnMissionBreakable(
                    pseudoWorld,
                    "MissionCrate",
                    cf.Position + Vector3.new(0, 2, 0)
                )
            end)
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
        local names = WALL_DECOR_PREFABS[theme or "earth"]
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
                    -- MountY = hang height (blades/banners) or half-height
                    -- (floor-standers like bookshelves); StandOff pushes the
                    -- piece off the wall plane by its own depth
                    local mountY = clone:GetAttribute("MountY") or 10
                    local standOff = clone:GetAttribute("StandOff") or 0.4
                    local pos = Vector3.new(
                        slotPos2.X + wd.x,
                        slotPos2.Y + mountY,
                        slotPos2.Z + wd.z
                    )
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
        local names = FEATURE_PREFABS[theme or "earth"]
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
                    local pos = Vector3.new(
                        slotPos3.X + ft.x,
                        slotPos3.Y + mountY,
                        slotPos3.Z + ft.z
                    )
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
            pcall(function() -- treasure-hunter quest substrate
                _G.RBXTemplateServices:Get("StatsService"):Increment(who, "mission_chests_opened", 1)
            end)
            -- pop the lid; payout rolls are loot-random (placement was the
            -- deterministic part)
            lid.CFrame = lid.CFrame * CFrame.new(0, 0.6, -1.4) * CFrame.Angles(math.rad(-55), 0, 0)
            local dropSvc
            pcall(function()
                local locator = _G.RBXTemplateServices
                dropSvc = locator and locator:Get("DropService")
            end)
            if dropSvc and dropSvc.TrySpawnEnhancementDrop then
                local rolls = math.random(tCfg.rolls_min or 1, tCfg.rolls_max or 2)
                local forward = chest.PrimaryPart.CFrame.LookVector
                for r = 1, rolls do
                    pcall(function()
                        dropSvc:TrySpawnEnhancementDrop(
                            who,
                            "treasure",
                            chest.PrimaryPart.Position
                                + forward * 5
                                + Vector3.new(0, 2, (r - 1.5) * 2)
                        )
                    end)
                end
            end
            self:_log("Info", "treasure opened", { by = who.Name })
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

-- Streaming-safe warp (2026-07-08: fell through the heaven-trial floor).
-- With StreamingEnabled the freshly-stamped interior hasn't reached the
-- client when we pivot, and the CLIENT owns character physics — so it falls
-- through geometry only the server has. Order of operations:
--   1. yield until the destination region has been SENT to this client
--      (the wait happens while they still stand on solid ground at the
--      portal — reads as the portal charging, not a hang)
--   2. pivot
--   3. brief anchored tail as the safety net for any remaining content;
--      the second stream request returns ~instantly when step 1 already
--      delivered everything, so the anchor is usually imperceptible.
function MissionInstanceService:_safeWarp(member, targetCF)
    local character = member.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root then
        return
    end
    pcall(function()
        member:RequestStreamAroundAsync(targetCF.Position, STREAM_WAIT)
    end)
    if not root.Parent then
        return -- died/left while streaming
    end
    character:PivotTo(targetCF)
    root.Anchored = true
    pcall(function()
        member:RequestStreamAroundAsync(targetCF.Position, ANCHOR_CAP)
    end)
    if root.Parent then
        root.Anchored = false
    end
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
    if missionId == "random" then
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
    prompt.Name = PROMPT_NAME
    prompt.ActionText = "Enter " .. (mission.display or missionId)
    prompt.ObjectText = "Mission"
    prompt.HoldDuration = 0.25
    prompt.MaxActivationDistance = 12
    prompt.RequiresLineOfSight = false
    prompt.Parent = part

    prompt.Triggered:Connect(function(player)
        local instanceId, err = self:Open(player, missionId)
        if not instanceId then
            self:_log("Info", "door open rejected", { player = player.Name, err = err })
        end
    end)
end

return MissionInstanceService
