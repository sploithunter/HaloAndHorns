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
        contextKey = teamKey .. "#" .. self._attempts[counterKey]
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
            pcall(function()
                member:RequestStreamAroundAsync(slotOrigin.Position)
            end)
            character:PivotTo(CFrame.new(spawnPad.Position + Vector3.new(0, 4, 0)))
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
        teamKey = teamKey,
        seed = seed,
        slotIndex = slotIndex,
        container = container,
        hooks = hooks,
        returnCFrames = returnCFrames,
        savedZoom = savedZoom,
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
            mission.theme
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

    -- return surviving members to where they entered from; clear mission
    -- HUD state and restore their camera zoom
    for _, member in ipairs(membersOf(record.teamKey)) do
        local back = record.returnCFrames[member.UserId]
        local character = member.Character
        if back and character and character:FindFirstChild("HumanoidRootPart") then
            character:PivotTo(back)
        end
        member:SetAttribute("MissionObjectiveText", nil)
        member:SetAttribute("MissionObjectiveCount", nil)
        member:SetAttribute("MissionObjectiveFraction", nil)
        member:SetAttribute("MissionMapData", nil)
        member:SetAttribute("InMission", nil)
        member:SetAttribute("MissionTheme", nil)
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
        wall = Color3.fromRGB(52, 40, 44),
        floor = Color3.fromRGB(72, 52, 50),
        pillar = Color3.fromRGB(38, 30, 34),
        beacon = Color3.fromRGB(255, 60, 30),
        torchFlame = Color3.fromRGB(255, 110, 40),
        torchLight = Color3.fromRGB(255, 120, 60),
    },
    heaven = {
        wall = Color3.fromRGB(232, 226, 210),
        floor = Color3.fromRGB(245, 241, 230),
        pillar = Color3.fromRGB(216, 188, 122),
        beacon = Color3.fromRGB(255, 216, 92),
        torchFlame = Color3.fromRGB(255, 244, 200),
        torchLight = Color3.fromRGB(255, 236, 185),
    },
}

-- Per-room tint jitter + seeded primitive clutter (pure rolls from
-- MissionDecor; this just materializes them).
function MissionInstanceService:_applyDressing(decorCfg, mapTable, spec, container, slotOrigin, seed, theme)
    local tints, props = MissionDecor.roll(
        mapTable.rooms,
        MissionSeed.stream(seed, "dressing"),
        decorCfg
    )
    local palette = THEME_PALETTES[theme]

    -- theme base coat first: walls/floors/pillars/torches across EVERY tile
    -- (caps + corridors included), so the realm identity is total
    if palette then
        for _, inst in ipairs(container:GetDescendants()) do
            if inst:IsA("BasePart") then
                local n = inst.Name
                if n == "Floor" then
                    inst.Color = palette.floor
                elseif n:sub(1, 5) == "Wall_" or n:sub(1, 7) == "Header_" or n == "Backing" then
                    inst.Color = palette.wall
                elseif n:sub(1, 7) == "Pillar_" then
                    inst.Color = palette.pillar
                elseif n == "ObjectiveBeacon" then
                    inst.Color = palette.beacon
                elseif n:sub(1, 11) == "TorchFlame_" then
                    inst.Color = palette.torchFlame
                    local light = inst:FindFirstChildOfClass("PointLight")
                    if light then
                        light.Color = palette.torchLight
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
    for _, prop in ipairs(props) do
        local cf = slotOrigin
            * CFrame.new(prop.x, 0, prop.z)
            * CFrame.Angles(0, prop.rot, 0)
        local prefab = prefabFor(prop.kind, math.floor(math.abs(prop.x) * 10))
        if prefab then
            prefab.Name = "Prop_" .. prop.kind
            groundModel(prefab, cf)
            prefab.Parent = folder
        else
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
    folder.Parent = container
    self:_log("Info", "dressing applied", { props = #props })
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

function MissionInstanceService:_bindDoor(part)
    if not part:IsA("BasePart") or part:FindFirstChild(PROMPT_NAME) then
        return
    end
    local missionId = part:GetAttribute("MissionId")
    local mission = missionId and self._config.missions[missionId]
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
