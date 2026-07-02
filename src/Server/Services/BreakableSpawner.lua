--[[
    BreakableSpawner - Spawns breakable crystals into worlds

    Responsibilities:
    - Reads breakable config (configs/breakables.lua)
    - Uses preloaded assets in ReplicatedStorage.Assets.Models.Breakables.Crystals
    - Spawns crystals at world spawners up to world Max, tracks CurrentItems
    - Respawns when items are removed

    Notes:
    - Does NOT modify scripts inside the crystal models; spawns with parts anchored
    - Uses WorldBindingService map hooks when available, with legacy folder fallback
]]

local BreakableSpawner = {}
BreakableSpawner.__index = BreakableSpawner

-- Silence verbose debug prints (mining / health-bar chatter that fired on every click).
-- Warnings and errors still surface via warn(). Toggle for local debugging.
local __RAW_PRINT = print
local __PRINT_ENABLED = false
local function print(...)
    if __PRINT_ENABLED then
        __RAW_PRINT(...)
    end
end

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local XpReward = require(ReplicatedStorage.Shared.Game.XpReward)
local LevelDiffYield = require(ReplicatedStorage.Shared.Game.LevelDiffYield)
local BuffStack = require(ReplicatedStorage.Shared.Game.BuffStack)
local fireGameEvent = require(ReplicatedStorage.Shared.Network.FireGameEvent)
local buffsConfig = require(ReplicatedStorage.Configs:WaitForChild("buffs"))
local SpawnSlots = require(ReplicatedStorage.Shared.Game.SpawnSlots)
local OverheadBar = require(ReplicatedStorage.Shared.UI.OverheadBar)
local BootReadiness = require(ReplicatedStorage.Shared.Boot.BootReadiness)

-- Injected services
local logger
local configLoader
local eventService
local worldBindingService
local petProgressionService

-- Local state
local breakablesConfig
local xpRewardsConfig = {} -- configs/leveling.lua xp_rewards (mining grants XP — see _onBreak)
local xpLevelScaleCfg -- configs/leveling.lua xp_level_scale (diminishing XP vs out-leveled crystals)
local payoutLevelScaleCfg -- configs/leveling.lua payout_level_scale (NEUTRAL x1 seam today)
local zonesConfig = {} -- configs/areas.lua zones (zone_level -> crystal MiningLevel)
-- Legacy "ring mining": the invisible Star align-ring (unanchored physics boxes + AlignPosition/
-- Orientation constraints per mined node) that made pets ORBIT a node while mining. The current
-- pet system (PetFollowService) uses its own mining animation and never touches this ring, so it
-- is OFF by default — building it spawns server-simulated rigid bodies (the spin loop + constraints
-- run on the SERVER) that collapse FPS. Re-enable per configs/pet_follow.lua ring_mining only if
-- bringing ring-mining back (ideally as a player-selectable attack style).
local ringMiningEnabled = false
local ringMiningPoints = 12

-- Geometry helpers for crystal star ring
local function getPointOnCircle(radius, degrees)
    return Vector3.new(
        math.cos(math.rad(degrees)) * radius,
        2,
        math.sin(math.rad(degrees)) * radius
    )
end

local function updateStarScale(starPart, factor)
    if not starPart or not starPart:IsA("BasePart") then
        return
    end
    local baseRadius = starPart:GetAttribute("BaseRadius") or 10
    local pointCount = starPart:GetAttribute("PointCount") or 108
    local increment = 360 / pointCount
    -- Ease the shrink so it never collapses too small; keeps pets from interweaving
    local eased = math.pow(math.clamp(factor, 0, 1), 0.6)
    local minScale = 0.35
    local scale = math.max(minScale, eased)
    local radius = baseRadius * scale
    for i = 1, pointCount do
        local name = "StarPos" .. tostring(i)
        local attach = starPart:FindFirstChild(name)
        if attach and attach:IsA("Attachment") then
            attach.Position = getPointOnCircle(radius, increment * i)
        end
    end
end

local function createStarRing(parentModel, radius, pointCount)
    -- Create a simple anchor part above the crystal with attachments where pets can align
    if not parentModel or not parentModel.PrimaryPart then
        return
    end
    local star = Instance.new("Part")
    star.Name = "Star"
    star.Size = Vector3.new(1, 1, 1)
    star.Anchored = true
    star.CanCollide = false
    star.Transparency = 1
    star.CFrame = CFrame.new(
        parentModel.PrimaryPart.Position + Vector3.new(0, parentModel:GetExtentsSize().Y / 4, 0)
    )
    star.Parent = parentModel

    local count = tonumber(pointCount) or 108
    local increment = 360 / count
    star:SetAttribute("BaseRadius", radius)
    star:SetAttribute("PointCount", count)
    for i = 1, count do
        local attach = Instance.new("Attachment")
        attach.Name = "StarPos" .. tostring(i)
        attach.Position = getPointOnCircle(radius, increment * i)
        attach.Parent = star

        -- Create a small invisible box with an attachment named "Pet" for pets to align to
        local box = Instance.new("Part")
        box.Name = "StarBox" .. tostring(i)
        box.Size = Vector3.new(1, 1, 1)
        box.Anchored = false
        box.CanCollide = false
        box.Massless = true
        box.Transparency = 1
        box.Position = star.Position
        box.Parent = star

        local centerAttachment = Instance.new("Attachment")
        centerAttachment.Name = "Center"
        centerAttachment.Parent = box

        local petAttachment = Instance.new("Attachment")
        petAttachment.Name = "Pet"
        petAttachment.Parent = box

        local alignP = Instance.new("AlignPosition")
        alignP.Name = "AlignPosition"
        alignP.Attachment0 = centerAttachment
        alignP.Attachment1 = attach
        alignP.Responsiveness = 100
        alignP.RigidityEnabled = true
        alignP.MaxForce = 1e12
        alignP.Parent = box

        local alignO = Instance.new("AlignOrientation")
        alignO.Name = "AlignOrientation"
        alignO.Attachment0 = centerAttachment
        alignO.Attachment1 = attach
        alignO.Responsiveness = 100
        alignO.RigidityEnabled = true
        alignO.MaxTorque = 1e12
        alignO.Parent = box
    end

    -- Spin the ring smoothly around world Y-axis (ignore model tilt),
    -- accelerate and shrink continuously as HP drops with visual smoothing
    task.spawn(function()
        local angle = 0
        local baseSpeed = math.rad(120) -- faster base spin
        local hpVisual = 1 -- smoothed HP fraction [0..1]
        while star.Parent == parentModel and parentModel.Parent do
            local dt = RunService.Heartbeat:Wait()
            local pp = parentModel.PrimaryPart
            if not pp then
                break
            end
            local maxHp = tonumber(parentModel:GetAttribute("MaxHP")) or 0
            local hp = tonumber(parentModel:GetAttribute("HP")) or 0
            local fracTarget = (maxHp > 0) and math.clamp(hp / maxHp, 0, 1) or 1
            -- Exponential smoothing to avoid steps
            local response = math.clamp(12 * dt, 0, 1) -- faster response
            hpVisual = hpVisual + (fracTarget - hpVisual) * response
            -- Spin scale ramps up aggressively near death (easeOut)
            local speedScale = 1 + math.pow(1 - hpVisual, 1.5) * 6 -- up to 7x
            angle += baseSpeed * speedScale * dt
            -- Smooth upward rise toward the end
            local rise = 10 * (1 - hpVisual) * (1 - hpVisual)
            local yBase = parentModel:GetExtentsSize().Y / 4
            local base = CFrame.new(pp.Position + Vector3.new(0, yBase + rise, 0))
            star.CFrame = base * CFrame.Angles(0, angle, 0)
            -- Resize ring every frame for smoothness
            updateStarScale(star, hpVisual)
        end
    end)
    return star
end

local function getWorldConfig(worldName)
    return (breakablesConfig.worlds and breakablesConfig.worlds[worldName]) or {}
end

local function getSpawnSettings(worldName)
    local defaults = (breakablesConfig.defaults and breakablesConfig.defaults.spawn_settings) or {}
    local worldCfg = getWorldConfig(worldName)
    local worldSettings = worldCfg.spawn_settings or {}
    local settings = table.clone(defaults)
    for key, value in pairs(worldSettings) do
        settings[key] = value
    end
    return settings
end

local function getConfiguredPosition(value, fallback, surfaceY)
    if type(value) ~= "table" then
        return fallback
    end

    local x = tonumber(value.x or value.X) or fallback.X
    local y = tonumber(value.y or value.Y) or surfaceY or fallback.Y
    local z = tonumber(value.z or value.Z) or fallback.Z
    return Vector3.new(x, y, z)
end

local function horizontalDistance(a, b)
    local dx = a.X - b.X
    local dz = a.Z - b.Z
    return math.sqrt((dx * dx) + (dz * dz))
end

local function randomPointInCircle(center, radius)
    if radius <= 0 then
        return center
    end

    local angle = math.random() * math.pi * 2
    local distance = math.sqrt(math.random()) * radius
    return center + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
end

local function randomPointInSpawnerBounds(spawner, margin)
    local halfX = math.max(0, (spawner.Size.X * 0.5) - margin)
    local halfZ = math.max(0, (spawner.Size.Z * 0.5) - margin)
    local localX = (math.random() * 2 - 1) * halfX
    local localZ = (math.random() * 2 - 1) * halfZ
    return spawner.CFrame:PointToWorldSpace(Vector3.new(localX, 0, localZ))
end

local function randomPointInBalancedSpawnerCell(spawner, margin, cellSize, itemsFolder)
    local halfX = math.max(0, (spawner.Size.X * 0.5) - margin)
    local halfZ = math.max(0, (spawner.Size.Z * 0.5) - margin)
    if halfX <= 0 or halfZ <= 0 then
        return spawner.Position
    end

    local resolvedCellSize = math.max(8, tonumber(cellSize) or 36)
    local columns = math.max(1, math.floor((halfX * 2) / resolvedCellSize))
    local rows = math.max(1, math.floor((halfZ * 2) / resolvedCellSize))
    local cellWidth = (halfX * 2) / columns
    local cellDepth = (halfZ * 2) / rows

    local counts = {}
    for column = 1, columns do
        counts[column] = {}
        for row = 1, rows do
            counts[column][row] = 0
        end
    end

    if itemsFolder then
        for _, child in ipairs(itemsFolder:GetChildren()) do
            if child:IsA("Model") and child.PrimaryPart then
                local localPosition = spawner.CFrame:PointToObjectSpace(child.PrimaryPart.Position)
                if
                    localPosition.X >= -halfX
                    and localPosition.X <= halfX
                    and localPosition.Z >= -halfZ
                    and localPosition.Z <= halfZ
                then
                    local column = math.clamp(
                        math.floor((localPosition.X + halfX) / cellWidth) + 1,
                        1,
                        columns
                    )
                    local row =
                        math.clamp(math.floor((localPosition.Z + halfZ) / cellDepth) + 1, 1, rows)
                    counts[column][row] += 1
                end
            end
        end
    end

    local lowestCount = math.huge
    local cells = {}
    for column = 1, columns do
        for row = 1, rows do
            local count = counts[column][row]
            if count < lowestCount then
                lowestCount = count
                table.clear(cells)
            end
            if count == lowestCount then
                table.insert(cells, { column = column, row = row })
            end
        end
    end

    local cell = cells[math.random(1, #cells)]
    local minX = -halfX + ((cell.column - 1) * cellWidth)
    local maxX = minX + cellWidth
    local minZ = -halfZ + ((cell.row - 1) * cellDepth)
    local maxZ = minZ + cellDepth
    local localX = minX + (math.random() * (maxX - minX))
    local localZ = minZ + (math.random() * (maxZ - minZ))

    return spawner.CFrame:PointToWorldSpace(Vector3.new(localX, 0, localZ))
end

local function numberFromAttributeOrConfig(instance, attributeName, configValue, fallback)
    local attributeValue = instance:GetAttribute(attributeName)
    if attributeValue ~= nil then
        return tonumber(attributeValue) or fallback
    end
    return tonumber(configValue) or fallback
end

local function shouldSampleSpawnerSurface(spawner, placeCfg)
    local surfaceOnly = spawner:GetAttribute("SurfaceOnly")
    if surfaceOnly ~= nil then
        return surfaceOnly == true
    end

    local mode = placeCfg.surface_mode or placeCfg.spawn_surface_mode
    return mode == "surface" or mode == "spawner_surface" or mode == "raycast"
end

local function shouldBalanceSpawnerCells(spawner, placeCfg)
    local balanced = spawner:GetAttribute("BalancedCells")
    if balanced ~= nil then
        return balanced == true
    end

    local mode = placeCfg.distribution_mode or placeCfg.spawn_distribution
    return mode == "balanced_cells" or mode == "grid"
end

local function raycastSpawnerSurface(spawner, candidate, placeCfg)
    if not shouldSampleSpawnerSurface(spawner, placeCfg) then
        return candidate
    end

    local raycastHeight = numberFromAttributeOrConfig(
        spawner,
        "RaycastHeight",
        placeCfg.surface_raycast_height,
        math.max(80, spawner.Size.Y + 40)
    )
    local normalMinY =
        numberFromAttributeOrConfig(spawner, "NormalMinY", placeCfg.surface_normal_min_y, 0.75)
    local origin = Vector3.new(
        candidate.X,
        spawner.Position.Y + (spawner.Size.Y * 0.5) + raycastHeight,
        candidate.Z
    )

    -- Biome-terrain match: raycast down onto the WORLD and only accept the candidate when the
    -- hit surface is the zone's terrain (by part name, e.g. "Lava", or by Material). This keeps
    -- ore on the actual biome texture (and off rocks/gaps) on uneven authored maps.
    local matchName = placeCfg.surface_match_name
    local matchMaterial = placeCfg.surface_match_material
    if matchName or matchMaterial then
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.IgnoreWater = true
        local excludes = { spawner }
        local worldFolder = spawner.Parent
        local items = worldFolder and worldFolder:FindFirstChild("Items")
        if items then
            table.insert(excludes, items)
        end
        local pets = workspace:FindFirstChild("PlayerPets")
        if pets then
            table.insert(excludes, pets)
        end
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr.Character then
                table.insert(excludes, plr.Character)
            end
        end
        params.FilterDescendantsInstances = excludes
        local result = workspace:Raycast(origin, Vector3.new(0, -raycastHeight * 2, 0), params)
        if not result then
            return nil
        end
        if matchName and result.Instance.Name ~= matchName then
            return nil
        end
        if matchMaterial and tostring(result.Material) ~= ("Enum.Material." .. matchMaterial) then
            return nil
        end
        if result.Normal.Y < normalMinY then
            return nil
        end
        return result.Position
    end

    -- Default: spawn onto the spawner part's own surface.
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Include
    params.FilterDescendantsInstances = { spawner }
    params.IgnoreWater = true

    local result = workspace:Raycast(origin, Vector3.new(0, -raycastHeight * 2, 0), params)
    if not result or result.Instance ~= spawner then
        return nil
    end
    if result.Normal.Y < normalMinY then
        return nil
    end

    return result.Position
end

local function isIgnoredSpawnObstacle(part, spawner)
    if not part or part == spawner then
        return true
    end
    if part:IsDescendantOf(spawner) then
        return true
    end
    if not part.CanQuery then
        return true
    end
    if part.Transparency >= 0.95 and not part.CanCollide then
        return true
    end
    if CollectionService:HasTag(part, "SpawnZone") and part.Transparency >= 0.95 then
        return true
    end
    local gameFolder = workspace:FindFirstChild("Game")
    if gameFolder and part:IsDescendantOf(gameFolder) then
        return true
    end
    for _, player in ipairs(Players:GetPlayers()) do
        local character = player.Character
        if character and part:IsDescendantOf(character) then
            return true
        end
    end
    return false
end

local function getSpawnClearanceMode(spawner, placeCfg)
    local mode = spawner:GetAttribute("ClearanceMode") or spawner:GetAttribute("ObstacleMode")
    if type(mode) == "string" and mode ~= "" then
        return string.lower(mode)
    end

    mode = placeCfg.clearance_mode or placeCfg.obstacle_mode
    if type(mode) == "string" and mode ~= "" then
        return string.lower(mode)
    end

    return "box"
end

local function hasBoxSpawnClearance(spawner, candidate, placeCfg, clearanceRadius)
    local clearanceHeight = numberFromAttributeOrConfig(
        spawner,
        "ClearanceHeight",
        placeCfg.spawn_clearance_height or placeCfg.clearance_height,
        10
    )
    local yOffset = numberFromAttributeOrConfig(
        spawner,
        "ClearanceYOffset",
        placeCfg.spawn_clearance_y_offset,
        clearanceHeight * 0.5
    )

    local params = OverlapParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { spawner }
    params.MaxParts = 40

    local parts = workspace:GetPartBoundsInBox(
        CFrame.new(candidate + Vector3.new(0, yOffset, 0)),
        Vector3.new(clearanceRadius * 2, clearanceHeight, clearanceRadius * 2),
        params
    )

    for _, part in ipairs(parts) do
        if not isIgnoredSpawnObstacle(part, spawner) then
            return false
        end
    end

    return true
end

local function hasRaySampleSpawnClearance(spawner, candidate, placeCfg, clearanceRadius)
    local sampleCount = math.max(
        0,
        numberFromAttributeOrConfig(spawner, "RaySampleCount", placeCfg.ray_sample_count, 8)
    )
    local rayHeight = numberFromAttributeOrConfig(
        spawner,
        "ObstacleRaycastHeight",
        placeCfg.obstacle_raycast_height or placeCfg.clearance_raycast_height,
        18
    )
    local rayDepth = numberFromAttributeOrConfig(
        spawner,
        "ObstacleRaycastDepth",
        placeCfg.obstacle_raycast_depth or placeCfg.clearance_raycast_depth,
        1.5
    )
    local offsets = { Vector3.new(0, 0, 0) }
    if sampleCount > 0 and clearanceRadius > 0 then
        for i = 1, sampleCount do
            local angle = ((i - 1) / sampleCount) * math.pi * 2
            table.insert(
                offsets,
                Vector3.new(math.cos(angle) * clearanceRadius, 0, math.sin(angle) * clearanceRadius)
            )
        end
    end

    local filterDescendants = {}
    local gameFolder = workspace:FindFirstChild("Game")
    if gameFolder then
        table.insert(filterDescendants, gameFolder)
    end
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Character then
            table.insert(filterDescendants, player.Character)
        end
    end

    for _, offset in ipairs(offsets) do
        local origin = candidate + offset + Vector3.new(0, rayHeight, 0)
        local direction = Vector3.new(0, -(rayHeight + rayDepth), 0)
        local exclusions = table.clone(filterDescendants)
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = exclusions
        params.IgnoreWater = true

        local foundSurface = false
        for _ = 1, 8 do
            local result = workspace:Raycast(origin, direction, params)
            if not result then
                break
            end

            local part = result.Instance
            if part == spawner or part:IsDescendantOf(spawner) then
                foundSurface = true
                break
            end

            if not isIgnoredSpawnObstacle(part, spawner) then
                return false
            end

            table.insert(exclusions, part)
            params.FilterDescendantsInstances = exclusions
        end

        if not foundSurface then
            return false
        end
    end

    return true
end

local function hasSpawnClearance(spawner, candidate, placeCfg)
    local clearanceRadius = numberFromAttributeOrConfig(
        spawner,
        "ClearanceRadius",
        placeCfg.spawn_clearance_radius or placeCfg.clearance_radius,
        0
    )
    if clearanceRadius <= 0 then
        return true
    end

    local mode = getSpawnClearanceMode(spawner, placeCfg)
    if mode == "ray_samples" or mode == "raycasts" or mode == "rays" then
        return hasRaySampleSpawnClearance(spawner, candidate, placeCfg, clearanceRadius)
    end

    return hasBoxSpawnClearance(spawner, candidate, placeCfg, clearanceRadius)
end

local function selectSpawnZone(zones)
    if type(zones) ~= "table" or #zones == 0 then
        return nil
    end

    local totalWeight = 0
    for _, zone in ipairs(zones) do
        totalWeight += tonumber(zone.weight or 1)
    end

    local roll = math.random() * totalWeight
    local cumulative = 0
    for _, zone in ipairs(zones) do
        cumulative += tonumber(zone.weight or 1)
        if roll <= cumulative then
            return zone
        end
    end

    return zones[#zones]
end

local function ensureConfiguredFolderTree(gameFolder)
    local structure = breakablesConfig.structure or {}
    for sectionName, sectionConfig in pairs(structure.folders or {}) do
        local sectionFolder = gameFolder:FindFirstChild(sectionName)
        if not sectionFolder then
            sectionFolder = Instance.new("Folder")
            sectionFolder.Name = sectionName
            sectionFolder.Parent = gameFolder
        end

        for groupName in pairs(sectionConfig) do
            if not sectionFolder:FindFirstChild(groupName) then
                local groupFolder = Instance.new("Folder")
                groupFolder.Name = groupName
                groupFolder.Parent = sectionFolder
            end
        end
    end

    local breakablesFolder = gameFolder:FindFirstChild("Breakables")
    local crystalsFolder = breakablesFolder and breakablesFolder:FindFirstChild("Crystals")
    if crystalsFolder then
        for areaId in pairs(breakablesConfig.worlds or {}) do
            if not crystalsFolder:FindFirstChild(areaId) then
                local worldFolder = Instance.new("Folder")
                worldFolder.Name = areaId
                worldFolder.Parent = crystalsFolder
            end
        end
    end
end

function BreakableSpawner:Init()
    logger = self._modules.Logger
    configLoader = self._modules.ConfigLoader
    eventService = self._modules.EventService
    worldBindingService = self._modules.WorldBindingService
    petProgressionService = self._modules.PetProgressionService

    -- Load config (safe)
    local ok, cfg = pcall(function()
        return configLoader:LoadConfig("breakables")
    end)
    if not ok then
        logger:Warn("BreakableSpawner: No breakables config found", { error = tostring(cfg) })
        breakablesConfig = { crystals = {} }
    else
        breakablesConfig = cfg or { crystals = {} }
    end

    -- Mining XP: "everything you do grants XP". Load the rate knobs (configs/leveling.lua).
    local okLvl, lvlCfg = pcall(function()
        return configLoader:LoadConfig("leveling")
    end)
    xpRewardsConfig = (okLvl and type(lvlCfg) == "table" and lvlCfg.xp_rewards) or {}
    xpLevelScaleCfg = okLvl and type(lvlCfg) == "table" and lvlCfg.xp_level_scale or nil
    payoutLevelScaleCfg = okLvl and type(lvlCfg) == "table" and lvlCfg.payout_level_scale or nil
    local okAreas, areasCfg = pcall(function()
        return configLoader:LoadConfig("areas")
    end)
    zonesConfig = (okAreas and type(areasCfg) == "table" and areasCfg.zones) or {}

    -- Legacy ring-mining toggle (OFF by default — see decl above). The current pet system uses
    -- its own mining animation, so the Star align-ring is not built unless ring_mining is enabled.
    local okPF, petFollow = pcall(function()
        return configLoader:LoadConfig("pet_follow")
    end)
    if okPF and type(petFollow) == "table" and type(petFollow.ring_mining) == "table" then
        ringMiningEnabled = petFollow.ring_mining.enabled == true
        ringMiningPoints = tonumber(petFollow.ring_mining.point_count) or ringMiningPoints
    end

    logger:Info("BreakableSpawner initialized", {
        crystalsDefined = (breakablesConfig.crystals and #breakablesConfig.crystals) or 0,
        ringMiningEnabled = ringMiningEnabled,
    })
end

function BreakableSpawner:Start()
    if worldBindingService and worldBindingService.AreaEntered then
        worldBindingService.AreaEntered:Connect(function(_, areaId)
            self:_fillAreaWorld(areaId)
        end)
    end

    -- When a player unlocks a biome (ZoneService publishes UnlockedAreasJson), top up the worlds
    -- immediately so the freshly-unlocked ore appears at once instead of on the next 5s sweep.
    local function watchUnlocks(player)
        player:GetAttributeChangedSignal("UnlockedAreasJson"):Connect(function()
            -- Re-lock: clear ore from any biome that is now inactive (e.g. after an admin reset),
            -- then top up the ones that are unlocked.
            self:_despawnInactiveWorlds()
            local crystalsAssets = self._crystalsAssets
            if crystalsAssets then
                self:_fillAllWorlds(crystalsAssets)
            end
        end)
    end
    for _, player in ipairs(Players:GetPlayers()) do
        watchUnlocks(player)
    end
    Players.PlayerAdded:Connect(watchUnlocks)

    -- Fill an area the MOMENT a player enters it. CurrentArea is the ZoneTracker SSOT and matches the
    -- crystal world-folder name exactly (e.g. "Hell_2_Ice" — verified live). The old
    -- WorldBindingService.AreaEntered hook does NOT fire for realm areas (and CurrentWorld goes stale
    -- there), so without this realms only filled on the 30s top-up tick — the walk-in delay. Slots
    -- are pre-warmed at boot, so this fill is instant (and amortized in _fillWorld).
    local function watchArea(player)
        player:GetAttributeChangedSignal("CurrentArea"):Connect(function()
            local area = player:GetAttribute("CurrentArea")
            if area and area ~= "" then
                self:_fillAreaWorld(area)
            end
        end)
        local now = player:GetAttribute("CurrentArea")
        if now and now ~= "" then
            self:_fillAreaWorld(now)
        end
    end
    for _, player in ipairs(Players:GetPlayers()) do
        watchArea(player)
    end
    Players.PlayerAdded:Connect(watchArea)

    task.spawn(function()
        self:_spawnLoop()
    end)

    -- SAFETY-NET reconciler (not the primary fill — respawns are event-driven per-crystal with a
    -- random delay). Runs slowly (topup_interval_seconds, default 30) so it catches missed removals /
    -- late assets without masking the random respawn gap. The old 5s cadence is what made respawns
    -- feel instant + uniform; the slot path also makes each sweep cheap (claim-or-skip, no raycasts).
    task.spawn(function()
        while true do
            local interval = tonumber(breakablesConfig and breakablesConfig.topup_interval_seconds)
                or 30
            task.wait(math.max(5, interval))
            -- Despawn worlds that went inactive BEFORE topping up — a player leaving a realm area
            -- (presence-gated) must drop its idle crystals, or they linger forever (the 32k-instance
            -- leak). The unlock-watch handler already despawns on unlock changes; this catches
            -- PRESENCE changes (no unlock event fires when you simply walk out of a realm).
            self:_despawnInactiveWorlds()
            local crystalsAssets = self._crystalsAssets
            if crystalsAssets then
                self:_fillAllWorlds(crystalsAssets)
            end
        end
    end)
end

-- Resolve ZoneService lazily via the locator (ZoneService may load after BreakableSpawner).
function BreakableSpawner:_zoneService()
    local locator = _G.RBXTemplateServices
    if not locator then
        return nil
    end
    local ok, svc = pcall(function()
        return locator:Get("ZoneService")
    end)
    return ok and svc or nil
end

function BreakableSpawner:_isWorldActive(worldName)
    -- Spawn (grass) is the free starter zone — always active.
    if worldName == "Spawn" or worldName == "SpawnWorld" then
        return true
    end

    -- Realm areas (Heaven_n* / Hell_n*) are far-off worlds (Home ±2000 Y). Pre-filling ALL of them
    -- for any player who'd merely UNLOCKED them spawned ~1600 idle crystals (~32k instances) the
    -- player never visits — the server-perf / memory leak. Gate realm areas on actual PRESENCE: a
    -- player must be IN the area (the same active-area signal that drives music/unlock). Multiple
    -- signals OR'd so it's robust to which one is populated; despawn of now-empty realms is handled
    -- by the top-up loop's _despawnInactiveWorlds pass.
    if worldName:match("^Heaven_%d") or worldName:match("^Hell_%d") then
        if
            worldBindingService
            and worldBindingService.IsAreaActive
            and worldBindingService:IsAreaActive(worldName)
        then
            return true
        end
        for _, player in ipairs(Players:GetPlayers()) do
            if player:GetAttribute("CurrentArea") == worldName then
                return true
            end
            local cw = player:FindFirstChild("CurrentWorld")
            if cw and cw.Value == worldName then
                return true
            end
        end
        return false
    end

    -- A biome spawns ore only if at least one CURRENTLY-PRESENT player has it unlocked. This is
    -- the authoritative lockout / anti-cheat layer: a player who C-frame-teleports into a locked
    -- biome finds nothing to mine because the server never spawned ore there. (Per-player MINING
    -- gating — so an un-unlocked player can't mine a node another player lit up — lives in
    -- PetFollowService:_mine + AutoTargetService:_collectCandidates (zoneUnlockedFor), added after
    -- Jason's alt walked into another player's lit Ice Fields and mined it.)
    local zone = self:_zoneService()
    if zone and zone.IsZoneUnlocked then
        for _, player in ipairs(Players:GetPlayers()) do
            local ok, unlocked = pcall(function()
                return zone:IsZoneUnlocked(player, worldName)
            end)
            if ok and unlocked then
                return true
            end
        end
        return false -- zone system present + nobody unlocked => asleep
    end

    -- Fallback (ZoneService not up yet): legacy area-entry activation.
    if worldBindingService and worldBindingService.IsAreaActive then
        return worldBindingService:IsAreaActive(worldName)
    end
    return false
end

function BreakableSpawner:_fillAreaWorld(areaId)
    if not self._crystalsAssets then
        return
    end

    local gameFolder = workspace:FindFirstChild("Game")
    local breakablesWorlds = gameFolder and gameFolder:FindFirstChild("Breakables")
    local crystalsWorlds = breakablesWorlds and breakablesWorlds:FindFirstChild("Crystals")
    local worldFolder = crystalsWorlds and crystalsWorlds:FindFirstChild(areaId)
    if worldFolder and worldFolder:IsA("Folder") then
        self:_fillWorld(worldFolder, self._crystalsAssets)
    end
end

function BreakableSpawner:_spawnLoop()
    -- Await the model TEMPLATES milestone, then the world structure. Both are race-free (return
    -- instantly if already signalled). This REPLACES the old WaitForChild + poll dance and the
    -- FindFirstChild-then-abort that, on a fast boot, ran before GameStructureService created
    -- workspace.Game.Breakables — aborting _spawnLoop entirely so the primary fill + ChildAdded
    -- listener never installed and worlds only filled on the 30s safety-net (the walk-in delay).
    -- See docs/BOOT_ORCHESTRATION.md.
    BootReadiness.await("models_ready")
    local crystalsAssets = ReplicatedStorage:WaitForChild("Assets")
        :WaitForChild("Models")
        :WaitForChild("Breakables")
        :WaitForChild("Crystals")
    self._crystalsAssets = crystalsAssets
    do
        local names = {}
        for _, child in ipairs(crystalsAssets:GetChildren()) do
            table.insert(names, child.Name)
        end
        logger:Info("BreakableSpawner: Crystal assets ready", { count = #names, names = names })
    end

    BootReadiness.await("world_structure")
    local gameFolder = workspace:WaitForChild("Game")
    -- Idempotently ensure the per-world Crystals subtree from config exists (authored-map worlds also
    -- arrive via the ChildAdded watcher below) before locating it.
    ensureConfiguredFolderTree(gameFolder)

    local breakablesWorlds = gameFolder:FindFirstChild("Breakables")
    if not breakablesWorlds then
        logger:Error(
            "BreakableSpawner: workspace.Game.Breakables missing after world_structure; cannot spawn"
        )
        return
    end

    local crystalsWorlds = breakablesWorlds:FindFirstChild("Crystals")
    if not crystalsWorlds then
        logger:Error("BreakableSpawner: workspace.Game.Breakables.Crystals missing; cannot spawn")
        return
    end

    -- Boot stage start: the initial fill (every active world's slot-gen + time-budgeted spawn)
    -- begins now and ends at the crystals_ready signal — the (took Xs) shows how long that takes.
    BootReadiness.begin("crystals_ready")

    -- Attach listeners and do initial fill for each world
    for _, worldFolder in ipairs(crystalsWorlds:GetChildren()) do
        if worldFolder:IsA("Folder") then
            self:_setupWorld(worldFolder)
            if self:_isWorldActive(worldFolder.Name) then
                self:_fillWorld(worldFolder)
            end
        end
    end

    -- Pre-build EVERY world's spawn-slot table ONCE at boot — the static "where could a crystal go"
    -- lookup (Jason's design). The heavy scan (_ensureSlots: grid + surface raycasts + O(n²) spacing)
    -- is cached per world and shared across all players, so a player walking into a presence-gated
    -- realm gets an INSTANT fill from the table instead of waiting on the scan. Background + amortized;
    -- only builds the worlds the active-fill above didn't already cache. Spawns NO crystals.
    task.spawn(function()
        for _, worldFolder in ipairs(crystalsWorlds:GetChildren()) do
            if
                worldFolder:IsA("Folder")
                and not (self._worldSlots and self._worldSlots[worldFolder])
            then
                pcall(function()
                    self:_ensureSlots(worldFolder)
                end)
                task.wait() -- breathe between worlds (the scan also yields internally)
            end
        end
        logger:Info("BreakableSpawner: slot-table pre-warm complete (all worlds cached)")
    end)

    -- Watch for new worlds added dynamically
    crystalsWorlds.ChildAdded:Connect(function(child)
        if child:IsA("Folder") then
            self:_setupWorld(child)
            -- Pre-warm a dynamically-added world's slot table too, so its first fill is instant.
            task.spawn(function()
                pcall(function()
                    self:_ensureSlots(child)
                end)
            end)
            if self:_isWorldActive(child.Name) then
                self:_fillWorld(child)
            end
        end
    end)

    -- Initial fill done + event-driven machinery (per-crystal respawn, ChildAdded) installed.
    BootReadiness.signal("crystals_ready")
end

-- Clear ore from worlds that are no longer active (locked again). Used when unlock state changes
-- so a re-locked biome empties out instead of leaving its old nodes minable.
function BreakableSpawner:_despawnInactiveWorlds()
    local gameFolder = workspace:FindFirstChild("Game")
    local breakablesWorlds = gameFolder and gameFolder:FindFirstChild("Breakables")
    local crystalsWorlds = breakablesWorlds and breakablesWorlds:FindFirstChild("Crystals")
    if not crystalsWorlds then
        return
    end
    for _, worldFolder in ipairs(crystalsWorlds:GetChildren()) do
        if worldFolder:IsA("Folder") and not self:_isWorldActive(worldFolder.Name) then
            local items = worldFolder:FindFirstChild("Items")
            if items then
                for _, model in ipairs(items:GetChildren()) do
                    model:Destroy()
                end
            end
            local current = worldFolder:FindFirstChild("CurrentItems")
            if current then
                current.Value = 0 -- after the ChildRemoved handlers settle
            end
        end
    end
end

function BreakableSpawner:_fillAllWorlds(crystalsAssets)
    local gameFolder = workspace:FindFirstChild("Game")
    if not gameFolder then
        return
    end
    local breakablesWorlds = gameFolder:FindFirstChild("Breakables")
    if not breakablesWorlds then
        return
    end
    local crystalsWorlds = breakablesWorlds:FindFirstChild("Crystals")
    if not crystalsWorlds then
        return
    end
    self._crystalsAssets = crystalsAssets
    for _, worldFolder in ipairs(crystalsWorlds:GetChildren()) do
        if worldFolder:IsA("Folder") and self:_isWorldActive(worldFolder.Name) then
            -- Ensure Items/Max/CurrentItems exist (idempotent) so a world that was added after
            -- the initial setup pass (or missed the ChildAdded window) still self-heals + fills.
            self:_setupWorld(worldFolder)
            self:_fillWorld(worldFolder)
        end
    end
end

function BreakableSpawner:_setupWorld(worldFolder)
    local items = worldFolder:FindFirstChild("Items")
    if not items then
        items = Instance.new("Folder")
        items.Name = "Items"
        items.Parent = worldFolder
    end

    local current = worldFolder:FindFirstChild("CurrentItems")
    if not current then
        current = Instance.new("NumberValue")
        current.Name = "CurrentItems"
        current.Value = 0
        current.Parent = worldFolder
    end

    local max = worldFolder:FindFirstChild("Max")
    local worldConfig = getWorldConfig(worldFolder.Name)
    local defaultMax = (breakablesConfig.defaults and breakablesConfig.defaults.max_per_world) or 25
    local configuredMax = tonumber(worldConfig.max or defaultMax) or defaultMax
    if worldBindingService and worldBindingService.GetSpawnZonesForSpawner then
        local boundSpawners =
            worldBindingService:GetSpawnZonesForSpawner(worldFolder.Name, "spawn_crystals")
        for _, spawner in ipairs(boundSpawners or {}) do
            local override = tonumber(spawner:GetAttribute("MaxCountOverride"))
            if override then
                configuredMax = override
                break
            end
        end
    end
    if not max then
        max = Instance.new("NumberValue")
        max.Name = "Max"
        max.Parent = worldFolder
    end

    -- Ensure this world has a spawner part (synthesize from config.spawn_area if missing).
    self:_ensureSpawnArea(worldFolder, worldConfig)

    -- Slot mode: build the pool now (at activation, off the spawn hot path). Floor-guard the max so a
    -- world never asks for more crystals than it has slots (with oversample the pool is ~3× max, so
    -- this normally leaves max untouched and ~2/3 of slots free for scattered respawns).
    if self:_useSlots() then
        local reg = self:_ensureSlots(worldFolder)
        if reg then
            local cap = reg:capacity(nil)
            if cap > 0 and cap < configuredMax then
                configuredMax = cap
            end
        end
    end
    max.Value = configuredMax

    -- Maintain count when items removed. CRITICAL: connect this listener exactly ONCE per world.
    -- _setupWorld is called repeatedly (initial pass, ChildAdded, and every 5s by _fillAllWorlds),
    -- and re-connecting here each time leaked a new listener per cycle — after a few minutes a
    -- single removal fired dozens of callbacks (over-decrementing CurrentItems + scheduling dozens
    -- of respawn attempts), which spammed the log and degraded server performance.
    self._removalWired = self._removalWired or {}
    if not self._removalWired[worldFolder] then
        self._removalWired[worldFolder] = true
        items.ChildRemoved:Connect(function(child)
            -- Free the slot this crystal held (read the id NOW; the child may be destroyed by defer).
            local sid = child and child:GetAttribute("SlotId")
            if sid ~= nil then
                local reg = self._worldSlots and self._worldSlots[worldFolder]
                if reg then
                    reg:release(sid)
                end
            end
            task.defer(function()
                local c = current.Value
                if c > 0 then
                    current.Value = c - 1
                end
                local placeCfg = getSpawnSettings(worldFolder.Name)
                local minDelay = tonumber(placeCfg.respawn_min_seconds or 5)
                local maxDelay = tonumber(placeCfg.respawn_max_seconds or 60)
                local delaySec = math.random(minDelay, maxDelay)
                task.delay(delaySec, function()
                    self:_trySpawnOne(worldFolder)
                end)
            end)
        end)
    end
end

-- Synthesize an invisible SpawnArea part from config.spawn_area when a world has no spawner part.
-- Authored maps / WorldBindingService provide spawners for built-in zones, but if that binding is
-- absent (or disappears mid-session, as Spawn's did), _findSpawnPoint would return nil forever.
-- Idempotent: only creates a part when none exists. Returns true if the world now has a spawner.
function BreakableSpawner:_ensureSpawnArea(worldFolder, worldConfig)
    if #self:_getSpawnerParts(worldFolder) > 0 then
        return true
    end
    worldConfig = worldConfig or getWorldConfig(worldFolder.Name)
    local area = worldConfig.spawn_area
    if type(area) ~= "table" or type(area.position) ~= "table" then
        return false
    end
    local sz = type(area.size) == "table" and area.size or {}
    local part = Instance.new("Part")
    part.Name = area.name or "SpawnArea"
    part.Anchored = true
    part.CanCollide = false
    part.CanQuery = false
    part.CanTouch = false
    part.Transparency = 1
    part.Size = Vector3.new(tonumber(sz.x) or 100, tonumber(sz.y) or 1, tonumber(sz.z) or 100)
    part.Position = Vector3.new(area.position.x or 0, area.position.y or 0, area.position.z or 0)
    part.Parent = worldFolder
    return true
end

function BreakableSpawner:_fillWorld(worldFolder)
    if not self:_isWorldActive(worldFolder.Name) then
        return
    end

    -- Re-entrancy guard: a freshly-entered world fills its whole Max amortized (yields below), and the
    -- top-up loop / unlock-watch may also call _fillWorld for it meanwhile. Skip if one's in flight so
    -- two concurrent fills can't over-spawn past Max.
    self._fillInProgress = self._fillInProgress or {}
    if self._fillInProgress[worldFolder] then
        return
    end

    local current = worldFolder:FindFirstChild("CurrentItems")
    local max = worldFolder:FindFirstChild("Max")
    if not (current and max) then
        return
    end

    -- Resolve the spawner ONCE (self-healing a SpawnArea if needed). If a world still has no
    -- spawner, don't loop `deficit` times calling _trySpawnOne — that's what produced the
    -- per-frame "No spawner parts" warn storm + wasted work. Warn at most once per world here.
    self:_ensureSpawnArea(worldFolder)
    if #self:_getSpawnerParts(worldFolder) == 0 then
        self:_warnNoSpawnerOnce(worldFolder.Name)
        return
    end

    local deficit = math.max(0, (max.Value or 0) - (current.Value or 0))
    if deficit <= 0 then
        return
    end

    self._fillInProgress[worldFolder] = true
    local ok = pcall(function()
        -- Amortize by TIME, not count. The old "yield every 10" hitched ~0.9s on entry because a single
        -- crystal's setup (clone + weld + OreGlow light + 2 billboards + placement) is not free, so 10 in
        -- one frame blew the budget. Yield the moment this frame's spawn work crosses ~6ms (a third of a
        -- 60fps frame) — that adapts to whatever a crystal costs and never lets a fill stall the frame.
        local frameStart = os.clock()
        for _ = 1, deficit do
            self:_trySpawnOne(worldFolder)
            if os.clock() - frameStart > 0.006 then
                task.wait()
                frameStart = os.clock()
                -- Re-check active each chunk so a player leaving mid-fill stops it cleanly.
                if not self:_isWorldActive(worldFolder.Name) then
                    break
                end
            end
        end
    end)
    self._fillInProgress[worldFolder] = false
    if not ok then
        self._fillInProgress[worldFolder] = nil
    end
end

-- Rate-limited "no spawner" warning: at most once per world per 30s, so a misconfigured world
-- surfaces in the log without spamming it (and without the per-call logging cost).
function BreakableSpawner:_warnNoSpawnerOnce(worldName)
    self._lastNoSpawnerWarn = self._lastNoSpawnerWarn or {}
    local now = os.clock()
    local last = self._lastNoSpawnerWarn[worldName]
    if last and (now - last) < 30 then
        return
    end
    self._lastNoSpawnerWarn[worldName] = now
    logger:Warn("BreakableSpawner: No spawner parts in world", { world = worldName })
end

function BreakableSpawner:_selectCrystalSpawn(worldName)
    -- Prefer per-world weighted spawn table if provided
    local worldCfg = breakablesConfig.worlds and breakablesConfig.worlds[worldName]
    local tableCfg = worldCfg and worldCfg.spawn_table
    if type(tableCfg) == "table" and #tableCfg > 0 then
        local total = 0
        for _, e in ipairs(tableCfg) do
            total += tonumber(e.weight or 1)
        end
        local roll = math.random() * total
        local acc = 0
        for _, e in ipairs(tableCfg) do
            acc += tonumber(e.weight or 1)
            if roll <= acc then
                return e.name, e
            end
        end
    end

    -- Fallback: uniform selection across defined crystals
    local names = {}
    for name, data in pairs(breakablesConfig.crystals or {}) do
        if type(data) == "table" and data.asset_id then
            table.insert(names, name)
        end
    end
    if #names == 0 then
        return nil
    end
    local idx = math.random(1, #names)
    return names[idx], nil
end

function BreakableSpawner:_getSpawnerParts(worldFolder)
    if worldBindingService and worldBindingService.GetSpawnZonesForSpawner then
        local boundSpawners =
            worldBindingService:GetSpawnZonesForSpawner(worldFolder.Name, "spawn_crystals")
        if type(boundSpawners) == "table" and #boundSpawners > 0 then
            return boundSpawners
        end
    end

    local spawners = {}
    for _, child in ipairs(worldFolder:GetChildren()) do
        if
            child:IsA("BasePart")
            and (
                child.Name == "SpawnArea"
                or child.Name == "CrystalSpawnArea"
                or child.Name == "Spawner"
                or child.Name == "DarkSpawner"
                or child.Name:find("Spawner")
            )
        then
            table.insert(spawners, child)
        end
    end
    return spawners
end

-- Find a placement point inside a spawner's configured area.
function BreakableSpawner:_findSpawnPoint(worldFolder)
    local itemsFolder = worldFolder:FindFirstChild("Items")
    local spawners = self:_getSpawnerParts(worldFolder)
    if #spawners == 0 then
        return nil, nil
    end

    -- Shuffle spawners to distribute load
    for i = #spawners, 2, -1 do
        local j = math.random(1, i)
        spawners[i], spawners[j] = spawners[j], spawners[i]
    end

    local placeCfg = getSpawnSettings(worldFolder.Name)
    local defaultMinDistance = tonumber(placeCfg.min_distance or 12)
    local spawnRadius = tonumber(placeCfg.spawn_radius or 0)
    local spawnAttempts = math.max(1, tonumber(placeCfg.spawn_attempts or 12))
    local surfaceY = tonumber(placeCfg.surface_y)
    local exclusionRadius = tonumber(placeCfg.spawn_exclusion_radius or 0)
    local zones = type(placeCfg.spawn_zones) == "table" and placeCfg.spawn_zones or nil
    local useSpawnerBounds = placeCfg.use_spawner_bounds ~= false
    local spawnerMargin = tonumber(placeCfg.spawn_area_margin or 0)

    for _, spawner in ipairs(spawners) do
        local currentSpawnerMargin = numberFromAttributeOrConfig(
            spawner,
            "SpawnAreaMargin",
            placeCfg.spawn_area_margin,
            spawnerMargin
        )
        local currentSpawnAttempts = math.max(
            1,
            numberFromAttributeOrConfig(
                spawner,
                "SpawnAttempts",
                placeCfg.spawn_attempts,
                spawnAttempts
            )
        )
        local currentMinDistance = numberFromAttributeOrConfig(
            spawner,
            "MinDistance",
            placeCfg.min_distance,
            defaultMinDistance
        )
        local spawnerPosition = spawner.Position
        if surfaceY then
            spawnerPosition = Vector3.new(spawner.Position.X, surfaceY, spawner.Position.Z)
        end

        local spawnCenter = getConfiguredPosition(placeCfg.spawn_center, spawnerPosition, surfaceY)
        local exclusionCenter =
            getConfiguredPosition(placeCfg.spawn_exclusion_center, spawnCenter, surfaceY)

        for _ = 1, currentSpawnAttempts do
            local zone = selectSpawnZone(zones)
            local zoneCenter = spawnCenter
            local zoneRadius = spawnRadius
            if zone then
                zoneCenter = getConfiguredPosition(zone.center, spawnCenter, surfaceY)
                zoneRadius = tonumber(zone.radius or spawnRadius)
            end

            local hasAreaBounds = useSpawnerBounds
                and not zone
                and (spawner.Size.X > 1 or spawner.Size.Z > 1)
            local candidate
            if hasAreaBounds and shouldBalanceSpawnerCells(spawner, placeCfg) then
                local cellSize =
                    numberFromAttributeOrConfig(spawner, "CellSize", placeCfg.cell_size, 36)
                candidate = randomPointInBalancedSpawnerCell(
                    spawner,
                    currentSpawnerMargin,
                    cellSize,
                    itemsFolder
                )
            elseif hasAreaBounds then
                candidate = randomPointInSpawnerBounds(spawner, currentSpawnerMargin)
            else
                candidate = randomPointInCircle(zoneCenter, zoneRadius)
            end
            if shouldSampleSpawnerSurface(spawner, placeCfg) then
                candidate = raycastSpawnerSurface(spawner, candidate, placeCfg)
                if not candidate then
                    continue
                end
            elseif surfaceY then
                candidate = Vector3.new(candidate.X, surfaceY, candidate.Z)
            end

            local insideExclusion = exclusionRadius > 0
                and horizontalDistance(candidate, exclusionCenter) < exclusionRadius
            local tooClose = insideExclusion

            if not tooClose and itemsFolder then
                for _, child in ipairs(itemsFolder:GetChildren()) do
                    if child:IsA("Model") and child.PrimaryPart then
                        if
                            horizontalDistance(child.PrimaryPart.Position, candidate)
                            < currentMinDistance
                        then
                            tooClose = true
                            break
                        end
                    end
                end
            end

            if not tooClose and not hasSpawnClearance(spawner, candidate, placeCfg) then
                tooClose = true
            end

            if not tooClose then
                return spawner, candidate
            end
        end
    end
    return nil, nil
end

-- Generate the world's spawn-slot registry ONCE (the expensive raycast + clearance pass moves here,
-- off the per-spawn / per-5s hot path). Common slots = a jitter-light grid over each spawner's area,
-- surface-raycast + clearance-validated a single time; spacing = min_distance so neighbours never
-- overlap (no runtime distance check needed). Fixed anchors = child BaseParts tagged with a
-- `SlotKind` attribute (giant crystal / chest spots), added as typed slots at their exact position.
-- Amortised with task.wait so even this one-time scan doesn't hitch. Cached per world.
function BreakableSpawner:_ensureSlots(worldFolder)
    self._worldSlots = self._worldSlots or {}
    if self._worldSlots[worldFolder] then
        return self._worldSlots[worldFolder]
    end

    local spawners = self:_getSpawnerParts(worldFolder)
    if #spawners == 0 then
        return nil
    end

    local placeCfg = getSpawnSettings(worldFolder.Name)
    local minDist = math.max(4, tonumber(placeCfg.min_distance or 12))
    local margin = tonumber(placeCfg.spawn_area_margin or 0)
    local surfaceY = tonumber(placeCfg.surface_y)
    local jitter = math.clamp(tonumber(placeCfg.slot_jitter or 0.15), 0, 0.45)
    -- OVERSAMPLE: generate ~`oversample`× as many candidate points as min_distance alone would fit
    -- (denser grid), so at steady state only ~1/oversample are filled. A mined crystal then respawns
    -- in a RANDOM free slot somewhere else — the field drifts, so you can't idle-farm one spot. The
    -- avoidNeighbors claim keeps two crystals from landing within min_distance (no overlap).
    local oversample = math.max(1, tonumber(breakablesConfig.slot_oversample) or 3)
    local spacing = math.max(2, minDist / math.sqrt(oversample))
    local commonPos = {}
    local processed = 0

    for _, spawner in ipairs(spawners) do
        local sampleSurface = shouldSampleSpawnerSurface(spawner, placeCfg)
        local width = math.max(spacing, spawner.Size.X - margin * 2)
        local depth = math.max(spacing, spawner.Size.Z - margin * 2)
        local offsets = SpawnSlots.layoutGrid({
            width = width,
            depth = depth,
            spacing = spacing,
            jitter = jitter,
            rng = math.random,
        })
        for _, off in ipairs(offsets) do
            local candidate = Vector3.new(
                spawner.Position.X + off.x,
                spawner.Position.Y,
                spawner.Position.Z + off.z
            )
            if sampleSurface then
                candidate = raycastSpawnerSurface(spawner, candidate, placeCfg)
            elseif surfaceY then
                candidate = Vector3.new(candidate.X, surfaceY, candidate.Z)
            end
            if candidate and hasSpawnClearance(spawner, candidate, placeCfg) then
                commonPos[#commonPos + 1] = candidate
            end
            processed += 1
            if processed % 24 == 0 then
                task.wait() -- spread the one-time scan across frames
            end
        end
    end

    -- Precompute each common slot's neighbours (other commons within min_distance) so the claim can
    -- avoid placing two crystals close enough to overlap. One-time O(n²), amortised with task.wait.
    local slots = {}
    local minDistSq = minDist * minDist
    for i, p in ipairs(commonPos) do
        local neighbors = {}
        for j, q in ipairs(commonPos) do
            if i ~= j then
                local dx, dz = p.X - q.X, p.Z - q.Z
                if dx * dx + dz * dz < minDistSq then
                    neighbors[#neighbors + 1] = j -- ids are the array index (auto-numbered in .new)
                end
            end
        end
        slots[#slots + 1] = { id = i, kind = nil, pos = p, neighbors = neighbors }
        if i % 32 == 0 then
            task.wait()
        end
    end

    -- Fixed/special anchors authored in the map (no neighbours: typed slots aren't claimed by
    -- common spawns, and authored placement is the designer's responsibility).
    for _, child in ipairs(worldFolder:GetChildren()) do
        if child:IsA("BasePart") and child:GetAttribute("SlotKind") then
            slots[#slots + 1] =
                { kind = tostring(child:GetAttribute("SlotKind")), pos = child.Position }
        end
    end

    local registry = SpawnSlots.new(slots)
    self._worldSlots[worldFolder] = registry
    logger:Info("BreakableSpawner: generated spawn slots", {
        world = worldFolder.Name,
        common = registry:capacity(nil),
        special = registry:capacity("special"),
    })
    return registry
end

-- The slot path is on unless explicitly disabled in config (escape hatch).
function BreakableSpawner:_useSlots()
    return breakablesConfig and breakablesConfig.use_spawn_slots ~= false
end

function BreakableSpawner:_trySpawnOne(
    worldFolder,
    forcedCrystalName,
    forcedSpawnOverrides,
    ignoreMax
)
    if not self:_isWorldActive(worldFolder.Name) then
        return
    end

    local current = worldFolder:FindFirstChild("CurrentItems")
    local max = worldFolder:FindFirstChild("Max")
    if not (current and max) then
        return
    end
    if not ignoreMax and current.Value >= max.Value then
        return
    end

    local crystalsAssets = self._crystalsAssets
    if not crystalsAssets then
        -- As a fallback, attempt to locate now
        local assetsRoot = ReplicatedStorage:FindFirstChild("Assets")
        local modelsRoot = assetsRoot and assetsRoot:FindFirstChild("Models")
        local breakablesRoot = modelsRoot and modelsRoot:FindFirstChild("Breakables")
        crystalsAssets = breakablesRoot and breakablesRoot:FindFirstChild("Crystals")
        if crystalsAssets then
            self._crystalsAssets = crystalsAssets
            -- Wait until children exist
            local start = tick()
            while #crystalsAssets:GetChildren() == 0 and tick() - start < 30 do
                task.wait(0.5)
            end
        else
            return
        end
    end

    if #crystalsAssets:GetChildren() == 0 then
        return
    end

    local crystalName, spawnOverrides = forcedCrystalName, forcedSpawnOverrides
    if not crystalName then
        crystalName, spawnOverrides = self:_selectCrystalSpawn(worldFolder.Name)
    end
    if not crystalName then
        logger:Warn("BreakableSpawner: No crystals available to spawn")
        return
    end

    local assetModel = crystalsAssets:FindFirstChild(crystalName)
    if not assetModel or not assetModel:IsA("Model") then
        -- Cosmetic variant meshes (…V1/V2/V3) are imported only partially, so the picked
        -- variant is often absent. Fall back to ANY present variant of the same family+size
        -- (strip the trailing Vn) instead of skipping the spawn + spamming a warning.
        local base = tostring(crystalName):gsub("V%d+$", "")
        for _, child in ipairs(crystalsAssets:GetChildren()) do
            if child:IsA("Model") and (child.Name:gsub("V%d+$", "")) == base then
                assetModel = child
                crystalName = child.Name
                break
            end
        end
        if not assetModel or not assetModel:IsA("Model") then
            -- No mesh at all for this family+size: warn once per base, not per spawn attempt.
            self._warnedMissingCrystal = self._warnedMissingCrystal or {}
            if not self._warnedMissingCrystal[base] then
                self._warnedMissingCrystal[base] = true
                local present = {}
                for _, child in ipairs(crystalsAssets:GetChildren()) do
                    table.insert(present, child.Name)
                end
                logger:Warn(
                    "BreakableSpawner: Crystal asset missing (no variant for family/size)",
                    { name = crystalName, base = base, available = present }
                )
            end
            return
        end
    end

    -- Placement. SLOT PATH (default): claim a precomputed free slot — O(free), no raycasts. A
    -- forced spawn may target a fixed-anchor kind (forcedSpawnOverrides.slot_kind). LEGACY PATH
    -- (flag off / no slots): the original per-spawn raycast + clearance search.
    local spawner, spawnPosition, claimedSlot
    if self:_useSlots() then
        self:_ensureSpawnArea(worldFolder)
        local registry = self:_ensureSlots(worldFolder)
        -- total()==0 ⇒ generation found no valid points for this world; fall through to the legacy
        -- raycast search rather than leaving the world permanently empty.
        if registry and registry:total() > 0 then
            local slotKind = type(forcedSpawnOverrides) == "table"
                    and forcedSpawnOverrides.slot_kind
                or nil
            claimedSlot = registry:claim(slotKind, math.random, nil, true) -- avoidNeighbors
            if not claimedSlot then
                return -- no free slot of this kind ⇒ world is full by geometry
            end
            spawnPosition = claimedSlot.pos
            spawner = self:_getSpawnerParts(worldFolder)[1]
        end
    end
    if not spawnPosition then
        spawner, spawnPosition = self:_findSpawnPoint(worldFolder)
        if not spawner then
            -- Try to self-heal a SpawnArea from config, then retry the lookup once.
            self:_ensureSpawnArea(worldFolder)
            spawner, spawnPosition = self:_findSpawnPoint(worldFolder)
            if not spawner then
                self:_warnNoSpawnerOnce(worldFolder.Name) -- rate-limited (no per-call spam)
                return
            end
        end
    end

    -- Clone and prepare model
    local model = assetModel:Clone()
    model.Name = crystalName

    local crystalCfg = breakablesConfig.crystals and breakablesConfig.crystals[crystalName]
    local crystalPlacement = (type(crystalCfg) == "table" and type(crystalCfg.placement) == "table")
            and table.clone(crystalCfg.placement)
        or {}
    if type(spawnOverrides) == "table" and type(spawnOverrides.placement) == "table" then
        for key, value in pairs(spawnOverrides.placement) do
            crystalPlacement[key] = value
        end
    end

    local function resolveStat(key, fallback)
        if type(spawnOverrides) == "table" and spawnOverrides[key] ~= nil then
            return spawnOverrides[key]
        end
        if type(crystalCfg) == "table" and crystalCfg[key] ~= nil then
            return crystalCfg[key]
        end
        return fallback
    end

    local scale = tonumber(resolveStat("scale", 1)) or 1
    if scale > 0 and scale ~= 1 then
        pcall(function()
            model:ScaleTo(scale)
        end)
    end

    local physicsCfg = (type(crystalCfg) == "table" and type(crystalCfg.physics) == "table")
            and crystalCfg.physics
        or {}

    -- Anchor all parts so breakables stay in place; per-breakable config can tune collision/query.
    for _, d in ipairs(model:GetDescendants()) do
        if d:IsA("BasePart") then
            if physicsCfg.anchored ~= nil then
                d.Anchored = physicsCfg.anchored == true
            else
                d.Anchored = true
            end
            if physicsCfg.can_collide ~= nil then
                d.CanCollide = physicsCfg.can_collide == true
            end
            if physicsCfg.can_touch ~= nil then
                d.CanTouch = physicsCfg.can_touch == true
            end
            if physicsCfg.can_query ~= nil then
                d.CanQuery = physicsCfg.can_query == true
            end
        end
    end

    -- Determine placement/orientation settings
    local placeCfg = getSpawnSettings(worldFolder.Name)
    local sinkDepth = tonumber(crystalPlacement.sink_depth or placeCfg.sink_depth or 0)
    local surfaceY = tonumber(placeCfg.surface_y)

    -- Orientation: preserve model's default pitch/roll from assets, add random yaw
    local yaw = math.rad(math.random(0, 359))
    local basePosition = spawnPosition or spawner.Position
    local targetCFrame
    if placeCfg.upright then
        -- Keep the model's asset orientation (pitch/roll), only randomize yaw around world Y
        local pivot = model:GetPivot()
        local orientOnly = pivot - pivot.Position
        targetCFrame = CFrame.new(basePosition) * CFrame.Angles(0, yaw, 0) * orientOnly
    else
        -- Free rotation: yaw only
        targetCFrame = CFrame.new(basePosition) * CFrame.Angles(0, yaw, 0)
    end
    pcall(function()
        model:PivotTo(targetCFrame)
    end)

    -- Align by bounding box so assets with odd pivots still sit/sink consistently.
    local boundsCFrame, boundsSize = model:GetBoundingBox()
    local embed = math.clamp(tonumber(placeCfg.embed_ratio or 0.25), 0, 0.9)
    local totalSink = (boundsSize.Y * embed) + sinkDepth
    local floorY = surfaceY or basePosition.Y
    local currentBottomY = boundsCFrame.Position.Y - (boundsSize.Y * 0.5)
    local targetBottomY = floorY - totalSink
    local yDelta = targetBottomY - currentBottomY
    if math.abs(yDelta) > 0.001 then
        pcall(function()
            model:PivotTo(model:GetPivot() + Vector3.new(0, yDelta, 0))
        end)
    end

    -- Simple de-overlap: if another crystal is too close, nudge sideways (up to few tries)
    local minDist = numberFromAttributeOrConfig(spawner, "MinDistance", placeCfg.min_distance, 12)
    local itemsFolder = worldFolder:FindFirstChild("Items")
    local tries = 0
    while tries < 4 and itemsFolder do
        local tooClose = false
        for _, other in ipairs(itemsFolder:GetChildren()) do
            if
                other:IsA("Model")
                and other ~= model
                and other.PrimaryPart
                and model.PrimaryPart
            then
                local d = (other.PrimaryPart.Position - model.PrimaryPart.Position).Magnitude
                if d < minDist then
                    tooClose = true
                    break
                end
            end
        end
        if tooClose then
            tries += 1
            local angle = math.rad(math.random(0, 359))
            local step = minDist * 0.75
            pcall(function()
                model:PivotTo(
                    model:GetPivot() * CFrame.new(math.cos(angle) * step, 0, math.sin(angle) * step)
                )
            end)
        else
            break
        end
    end

    local finalPivot = model:GetPivot()
    local dropFromHeight = tonumber(
        crystalPlacement.drop_from_height or placeCfg.drop_from_height or 0
    ) or 0
    local dropDuration = tonumber(crystalPlacement.drop_duration or placeCfg.drop_duration or 0.6)
        or 0.6
    if dropFromHeight > 0 then
        model:PivotTo(finalPivot + Vector3.new(0, dropFromHeight, 0))
    end

    -- Optional attributes for downstream logic (mirrors MCP fields)
    model:SetAttribute("BreakableType", "Crystal")
    model:SetAttribute("CrystalName", crystalName)
    model:SetAttribute("World", worldFolder.Name)
    -- CRYSTAL LEVEL (Jason): zone_level + size tier offset (S/M/L = minion/lieutenant/
    -- boss = +0/+1/+2, mirroring enemy rank_offset). Drives the diminishing-XP gate in
    -- _onBreak. Deliberately NOT the "Level" attribute — mining never enters the to-hit
    -- math (crystals can't dodge) and must not start.
    local zoneDef = zonesConfig[worldFolder.Name]
    local zoneLevel = (type(zoneDef) == "table" and tonumber(zoneDef.zone_level)) or 1
    local sizeOffset = type(crystalCfg) == "table" and tonumber(crystalCfg.level_offset)
    if not sizeOffset then -- legacy/placeholder names carry the tier in the name
        sizeOffset = (crystalName:find("Large") and 2) or (crystalName:find("Medium") and 1) or 0
    end
    model:SetAttribute("MiningLevel", zoneLevel + sizeOffset)
    -- Slot path: tag which slot this crystal occupies, so ChildRemoved frees exactly that slot.
    if claimedSlot then
        model:SetAttribute("SlotId", claimedSlot.id)
    end

    -- Set gameplay attributes if present in config
    if type(crystalCfg) == "table" then
        -- Per-world balance multipliers (default 1): scale a whole world's crystal toughness
        -- (health) and payout (value) without touching the shared per-family stats — e.g.
        -- Heaven_2/Hell_2 run tougher, higher-paying ore than the layer-1 worlds they clone.
        local worldDef = breakablesConfig.worlds and breakablesConfig.worlds[worldFolder.Name]
        local healthMult = (type(worldDef) == "table" and tonumber(worldDef.health_mult)) or 1
        local valueMult = (type(worldDef) == "table" and tonumber(worldDef.value_mult)) or 1
        local maxhp = math.floor((tonumber(resolveStat("health", 0)) or 0) * healthMult)
        local value = math.floor((tonumber(resolveStat("value", 0)) or 0) * valueMult)
        model:SetAttribute("MaxHP", maxhp)
        model:SetAttribute("HP", maxhp)
        model:SetAttribute("Value", value)
        model:SetAttribute("Currency", tostring(resolveStat("currency", "crystals")))
        model:SetAttribute("Scale", scale)
        model:SetAttribute("Boost", 0)
        model:SetAttribute(
            "MaxBoost",
            (breakablesConfig.boost and breakablesConfig.boost.max) or 100
        )
        -- Pet-damage amplification at full Boost (read by PetFollowService on each hit).
        model:SetAttribute(
            "BoostDamageBonus",
            (breakablesConfig.boost and breakablesConfig.boost.max_damage_bonus) or 1.0
        )

        -- Optional self-glow (Pet Realm zone ore). config: crystalCfg.glow =
        -- { color = {r,g,b}, brightness = 0.75, range = 16 }. Shadows off (cheap; a colored
        -- gem glow doesn't need dynamic shadows, and Roblox culls distant lights). Replicates
        -- from the server. A pulse can be layered later via ONE shared client loop, not per-node.
        local glow = type(crystalCfg) == "table" and crystalCfg.glow
        local glowHost = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
        if type(glow) == "table" and glowHost and not glowHost:FindFirstChild("OreGlow") then
            local c = glow.color or { 255, 255, 255 }
            local light = Instance.new("PointLight")
            light.Name = "OreGlow"
            light.Color = Color3.fromRGB(c[1] or 255, c[2] or 255, c[3] or 255)
            light.Brightness = tonumber(glow.brightness) or 0.75
            light.Range = tonumber(glow.range) or 16
            light.Shadows = false
            light.Parent = glowHost
        end
    end

    -- Unique breakable ID (for targeting). Using random large int similar to MCP
    local idValue = Instance.new("NumberValue")
    idValue.Name = "BreakableID"
    idValue.Value = math.random(2, 2 ^ 30) + math.random(2, 2 ^ 30)
    idValue.Parent = model

    -- Contribution tracking (per-player damage)
    local contribFolder = Instance.new("Folder")
    contribFolder.Name = "Contrib"
    contribFolder.Parent = model

    -- Pet Realm ore meshes are bare MeshParts with no baked Health/Boost UI. Build simple
    -- billboards so the bars below have something to drive. Skipped if the model already has a
    -- baked Health bar (template blue crystals). Starts hidden; shown only while being attacked.
    do
        local pp = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
        if pp then
            -- Normalization: EVERY breakable's HP/boost meters use the ONE shared OverheadBar widget
            -- (same as pets + enemies) — no per-crystal hand-rolled bars. Strip any authored
            -- Health/Boost meter billboards first so there's exactly one of each, built the standard way.
            for _, d in ipairs(model:GetDescendants()) do
                if d:IsA("BillboardGui") then
                    local c = d:FindFirstChildWhichIsA("Frame")
                    if
                        d:FindFirstChild("Health")
                        or d:FindFirstChild("Boost")
                        or (c and (c:FindFirstChild("Health") or c:FindFirstChild("Boost")))
                    then
                        d:Destroy()
                    end
                end
            end
            local _, bsize = model:GetBoundingBox()
            local topY = (bsize.Y * 0.5) + 1.2
            -- Billboard NAMES kept (HealthBillboardGui/BoostBillboardGui) so existing MaxDistance
            -- tuning still finds them; internals are the standard OverheadBar (pill BG + scale fill).
            local healthBar = OverheadBar.create({
                adornee = pp,
                name = "HealthBillboardGui",
                studsOffset = Vector3.new(0, topY + 0.45, 0),
                fillColor = Color3.fromRGB(80, 220, 90),
            })
            healthBar.Enabled = false -- hidden until attacked
            healthBar.MaxDistance = 75
            local boostBar = OverheadBar.create({
                adornee = pp,
                name = "BoostBillboardGui",
                studsOffset = Vector3.new(0, topY, 0),
                fillColor = Color3.fromRGB(255, 205, 70),
            })
            boostBar.Enabled = false
            boostBar.MaxDistance = 75
        end
    end

    -- Health + boost meters drive the shared OverheadBar (fillOf/setFraction) off model attributes.
    local function setOverheadBar(name, value, maxValue)
        local pp = model.PrimaryPart
        local bb = pp and pp:FindFirstChild(name)
        local fill = pp and OverheadBar.fillOf(pp, name)
        if not (bb and fill) then
            return nil
        end
        local maxV = tonumber(maxValue) or 0
        local v = tonumber(value) or 0
        local frac = (maxV > 0) and math.clamp(v / maxV, 0, 1) or 0
        OverheadBar.setFraction(fill, frac)
        return bb, v, maxV
    end

    local function updateHealthBar()
        local bb, hp, maxHp = setOverheadBar(
            "HealthBillboardGui",
            model:GetAttribute("HP"),
            model:GetAttribute("MaxHP")
        )
        if not bb then
            return
        end
        -- Show bars ONLY while a node is being attacked (HP below max, not destroyed). Toggle the
        -- health + boost billboards together.
        local engaged = maxHp > 0 and hp < maxHp and hp > 0
        bb.Enabled = engaged
        local ppNow = model.PrimaryPart
        local boostBB = ppNow and ppNow:FindFirstChild("BoostBillboardGui")
        if boostBB then
            -- Boost bar also shows whenever there's Boost (Resonance pulses raise Boost without
            -- attacking the node), not just while mining; decay back to 0 hides it again.
            local boost = tonumber(model:GetAttribute("Boost")) or 0
            boostBB.Enabled = engaged or boost > 0
        end
    end
    updateHealthBar()
    model:GetAttributeChangedSignal("HP"):Connect(function()
        updateHealthBar()
        local star = model:FindFirstChild("Star")
        if star then
            local maxHp = tonumber(model:GetAttribute("MaxHP")) or 0
            local hp = tonumber(model:GetAttribute("HP")) or 0
            if maxHp > 0 then
                local frac = math.clamp(hp / maxHp, 0, 1)
                updateStarScale(star, frac)
                star:SetAttribute("SpinSpeedScale", 1 + (1 - frac) * 1.5)
            end
        end
    end)

    -- Boost bar hookup (shared OverheadBar fill).
    local function updateBoostBar()
        local bb = setOverheadBar(
            "BoostBillboardGui",
            model:GetAttribute("Boost"),
            model:GetAttribute("MaxBoost") or 100
        )
        -- Toggle visibility off Boost too (the HP path only fires on HP change). A Resonance pulse
        -- raises Boost with HP untouched, so show the bar while Boost > 0; decay to 0 hides it.
        if bb then
            local boost = tonumber(model:GetAttribute("Boost")) or 0
            local hp = tonumber(model:GetAttribute("HP")) or 0
            local maxHp = tonumber(model:GetAttribute("MaxHP")) or 0
            local engaged = maxHp > 0 and hp < maxHp and hp > 0
            bb.Enabled = engaged or boost > 0
        end
    end
    updateBoostBar()
    model:GetAttributeChangedSignal("Boost"):Connect(updateBoostBar)

    -- Decay boost over time so sustained clicking is required to hold it up (config-driven).
    local boostDecay = (breakablesConfig.boost and tonumber(breakablesConfig.boost.decay_per_sec))
        or 1
    task.spawn(function()
        -- Wait FIRST, then check parent: task.spawn runs synchronously up to the first yield, and
        -- the model isn't parented into Items until later in this function — so checking
        -- model.Parent before the wait would exit the loop immediately (decay never runs).
        while true do
            task.wait(1)
            if not model.Parent then
                break
            end
            local b = tonumber(model:GetAttribute("Boost")) or 0
            if b > 0 then
                model:SetAttribute("Boost", math.max(0, b - boostDecay))
            end
        end
    end)

    -- Add star ring for pet attack alignment when first pet arrives
    do
        local petsFolder = model:FindFirstChild("Pets")
        if not petsFolder then
            petsFolder = Instance.new("Folder")
            petsFolder.Name = "Pets"
            petsFolder.Parent = model
        end
        local teamBoost = model:FindFirstChild("TeamBoost")
        if not teamBoost then
            teamBoost = Instance.new("NumberValue")
            teamBoost.Name = "TeamBoost"
            teamBoost.Value = 0
            teamBoost.Parent = model
        end
        local efficiency = model:FindFirstChild("Efficiency")
        if not efficiency then
            efficiency = Instance.new("NumberValue")
            efficiency.Name = "Efficiency"
            efficiency.Value = 1
            efficiency.Parent = model
        end
        petsFolder.ChildAdded:Connect(function(child)
            -- Expect child is a NumberValue carrying PetID, with sub-values Leadership/Efficiency, mirroring MCP
            -- Legacy ring-mining only (OFF by default): build the orbit ring on first pet. The
            -- current pet system has its own mining animation and never uses this, so it stays
            -- absent — which also means it's torn down whenever nobody is mining (never built).
            if ringMiningEnabled and not model:FindFirstChild("Star") then
                local radius = model:GetExtentsSize().X + 12
                createStarRing(model, radius, ringMiningPoints)
            end
            local lead = child:FindFirstChild("Leadership")
            if lead and typeof(lead.Value) == "number" then
                teamBoost.Value = teamBoost.Value + lead.Value
            end
            local eff = child:FindFirstChild("Efficiency")
            if eff and typeof(eff.Value) == "number" then
                efficiency.Value = efficiency.Value + eff.Value
            end
            -- Enable crystal SFX/UI when pets engage
            local pp = model.PrimaryPart
            if pp then
                local bb = pp:FindFirstChild("BillboardGui")
                if bb then
                    bb.MaxDistance = 75
                end
                local bbb = pp:FindFirstChild("BoostBillboardGui")
                if bbb then
                    bbb.MaxDistance = 75
                end
                local hum = pp:FindFirstChild("EngineHumSound")
                if hum and hum:IsA("Sound") then
                    hum:Play()
                end
                -- Play a soft engage sound if present
                local soft = pp:FindFirstChild("littleBreakSound")
                if soft and soft:IsA("Sound") then
                    if math.random(1, 3) == 1 then
                        soft:Play()
                    end
                end
            end
        end)
        petsFolder.ChildRemoved:Connect(function(child)
            local lead = child:FindFirstChild("Leadership")
            if lead and typeof(lead.Value) == "number" then
                teamBoost.Value = math.max(0, teamBoost.Value - lead.Value)
            end
            local eff = child:FindFirstChild("Efficiency")
            if eff and typeof(eff.Value) == "number" then
                efficiency.Value = math.max(1, efficiency.Value - eff.Value)
            end
            if #petsFolder:GetChildren() == 0 then
                local star = model:FindFirstChild("Star")
                if star then
                    star:Destroy()
                end
                local pp = model.PrimaryPart
                if pp then
                    local bb = pp:FindFirstChild("BillboardGui")
                    if bb then
                        bb.MaxDistance = 25
                    end
                    local bbb = pp:FindFirstChild("BoostBillboardGui")
                    if bbb then
                        bbb.MaxDistance = 1
                    end
                    local hum = pp:FindFirstChild("EngineHumSound")
                    if hum and hum:IsA("Sound") then
                        hum:Stop()
                    end
                    -- Optional soft stop cue
                    local soft = pp:FindFirstChild("littleBreakSound")
                    if soft and soft:IsA("Sound") then
                        if math.random(1, 5) == 1 then
                            soft:Play()
                        end
                    end
                end
            end
        end)
    end

    -- Award/destroy handler when HP reaches 0 from any source
    local function handleDeath()
        if not model.Parent then
            return
        end
        if model:GetAttribute("Dead") then
            return
        end
        model:SetAttribute("Dead", true)
        local stats = self._moduleLoader and self._moduleLoader:Get("StatsService")
        -- Compute awards based on contributions
        local currencyType = tostring(model:GetAttribute("Currency") or "coins")
        local valueAmount = tonumber(model:GetAttribute("Value") or 0)
        local economy = (self._moduleLoader and self._moduleLoader:Get("EconomyService"))
            or (self._modules and self._modules.EconomyService)
        local progression = self._moduleLoader
            and self._moduleLoader:Get("PlayerProgressionService")
        -- World S3: a cut of mining income becomes realm tokens while in a realm layer (no-op at base).
        local layerService = self._moduleLoader and self._moduleLoader:Get("LayerService")
        -- #167: when drops are enabled, the COIN award pops out as a physical pickup instead of
        -- crediting instantly (XP / pet-xp / realm cut below stay instant). DropService.SpawnCoinDrop
        -- returns true when it took the coins; false => credit instantly (drops off / dust / no pos).
        local dropService = self._moduleLoader and self._moduleLoader:Get("DropService")
        local dropPos
        do
            local bp = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
            dropPos = bp and bp.Position
        end
        -- Rare ENHANCEMENT drop alongside the coins (identity revealed at pickup). Goes to the
        -- first contributor (same Contrib folder the coin split reads).
        if dropService and dropService.TrySpawnEnhancementDrop and dropPos then
            local contribFolder = model:FindFirstChild("Contrib")
            local first = contribFolder and contribFolder:GetChildren()[1]
            local plr = first
                and game:GetService("Players"):GetPlayerByUserId(tonumber(first.Name) or 0)
            if plr then
                pcall(function()
                    dropService:TrySpawnEnhancementDrop(plr, "breakable", dropPos)
                end)
                -- POTION drop (same odds as enhancements; independent roll alongside it)
                if dropService.TrySpawnPotionDrop then
                    pcall(function()
                        dropService:TrySpawnPotionDrop(plr, "breakable", dropPos)
                    end)
                end
            end
        end
        -- PREMIUM GEM bonus (configs/drops.lua gem_bonus): rare extra roll per
        -- contributor per break — a gems pickup pops from the node via the same
        -- drop pipeline (owner-only visible, magnet, auto-collect on timeout).
        local function rollGemBonus(plr)
            local cfg = dropService and dropService._config and dropService._config.gem_bonus
            if not (cfg and cfg.enabled == true and plr) then
                return
            end
            -- Windfall (drop_rate axis): an active drop-rate buff multiplies the premium-
            -- gem chance too (the same loot burst as enhancement drops).
            local gemChance = tonumber(cfg.chance) or 0
            if (plr:GetAttribute("DropRateBuffUntil") or 0) > os.time() then
                gemChance = gemChance * (1 + (tonumber(plr:GetAttribute("DropRateBuff")) or 0))
            end
            if math.random() >= gemChance then
                return
            end
            local amount = math.random(tonumber(cfg.min) or 1, tonumber(cfg.max) or 1)
            if
                not (
                    dropService.SpawnCoinDrop
                    and dropService:SpawnCoinDrop(plr, "gems", amount, dropPos)
                )
            then
                economy:AddCurrency(plr, "gems", amount, "breakable_gem_bonus")
            end
        end

        -- Credit `amount` of the node currency to `plr`, as a drop when possible, else instantly.
        local function creditCoins(plr, amount, reason)
            if
                dropService
                and dropService.SpawnCoinDrop
                and dropService:SpawnCoinDrop(plr, currencyType, amount, dropPos)
            then
                return -- a pickup now carries the coins
            end
            economy:AddCurrency(plr, currencyType, amount, reason)
        end

        local function resolvePlayerAward(player, baseAmount)
            baseAmount = tonumber(baseAmount) or 0
            local amount = baseAmount
            if economy and economy.ResolveRewardAmount and baseAmount > 0 then
                amount = economy:ResolveRewardAmount(baseAmount, {
                    player = player,
                    kind = "breakable_reward",
                    currency = currencyType,
                    breakableId = model:GetAttribute("BreakableId"),
                    source = "BreakableSpawner",
                })
            elseif eventService and baseAmount > 0 then
                local rewardMultiplier = eventService:GetModifier("breakable_reward_multiplier", 1)
                    or 1
                local currencyMultiplier = eventService:GetModifier(
                    currencyType .. "_reward_multiplier",
                    1
                ) or 1
                amount = math.max(0, math.floor(baseAmount * rewardMultiplier * currencyMultiplier))
            end
            -- Desert buffer's team YIELD aura (meerkat): a short-lived coin multiplier on the
            -- player (set by EnemyService:_supportPass on a channel separate from event
            -- modifiers, so it stacks). Applies to the mined-coin payout only.
            -- coin_yield axis: the meerkat aura (CoinYieldBuff, a multiplier) and the Prospector/
            -- Windfall power (CoinYieldPower, a fraction) are the SAME axis -> they ADD via BuffStack
            -- (never compound), clamped to the axis cap.
            if player and (tonumber(amount) or 0) > 0 then
                local nowT = os.time()
                local sources = {
                    {
                        fraction = (player:GetAttribute("CoinYieldBuff") or 1) - 1, -- aura (mult)
                        expiry = player:GetAttribute("CoinYieldBuffUntil") or 0,
                    },
                    {
                        fraction = player:GetAttribute("CoinYieldPower") or 0, -- power (fraction)
                        expiry = player:GetAttribute("CoinYieldPowerUntil") or 0,
                    },
                }
                local mult = BuffStack.multiplier(
                    sources,
                    nowT,
                    buffsConfig.axes and buffsConfig.axes.coin_yield
                )
                if mult ~= 1 then
                    amount = math.floor(amount * mult)
                end
            end
            -- World S3: deeper realm layers scale income (layers.multipliers; 1.0 at base).
            -- This is the carrot for the soul/level/token investment to descend.
            if player and layerService and layerService.GetRewardMultiplier and amount > 0 then
                local realmMult = layerService:GetRewardMultiplier(player)
                if realmMult and realmMult ~= 1 then
                    amount = math.floor(amount * realmMult)
                end
            end
            return amount
        end

        if economy and valueAmount > 0 then
            local total = 0
            for _, v in ipairs(contribFolder:GetChildren()) do
                if v:IsA("NumberValue") then
                    total += v.Value
                end
            end
            if total > 0 then
                local remainder = valueAmount
                local topUserId, topAmount = nil, -math.huge
                for _, v in ipairs(contribFolder:GetChildren()) do
                    if v:IsA("NumberValue") and v.Value > 0 then
                        local share = math.floor(valueAmount * (v.Value / total))
                        remainder -= share
                        local plr = Players:GetPlayerByUserId(tonumber(v.Name))
                        if plr and share > 0 then
                            local resolvedShare = resolvePlayerAward(plr, share)
                            -- level-vs-payout seam — NEUTRAL today (x1; Jason: coins fund
                            -- hatching), the lever lives in leveling.payout_level_scale
                            resolvedShare = math.floor(
                                resolvedShare
                                        * LevelDiffYield.payout(
                                            plr:GetAttribute("Level"),
                                            model:GetAttribute("MiningLevel"),
                                            payoutLevelScaleCfg
                                        )
                                    + 0.5
                            )
                            pcall(function()
                                creditCoins(plr, resolvedShare, "crystal_break_split")
                                rollGemBonus(plr) -- premium gem bonus per contributor
                                -- #172: payout float above the broken crystal (config-driven
                                -- via the GameEvents bus; float kind anchors at ctx.position)
                                if dropPos and resolvedShare > 0 then
                                    local label = resolvedShare >= 1000
                                            and string.format("+%.1fK", resolvedShare / 1000)
                                        or ("+" .. tostring(resolvedShare))
                                    fireGameEvent(plr, "coin_payout", {
                                        name = label,
                                        position = dropPos,
                                        amount = resolvedShare, -- tutorial coin-gate sums this
                                    })
                                end
                                if stats then
                                    stats:Increment(plr, "breakables_broken", 1)
                                    -- (coins_earned_lifetime increments in DataService:
                                    -- AddCurrency — the choke point ALL earnings cross)
                                end
                                -- Mining grants XP (split by contribution share, same as the
                                -- currency above). AddExperience publishes the XP attribute -> the
                                -- HUD level bar ticks live.
                                if progression and progression.AddExperience then
                                    local xp = XpReward.fromValue(share, xpRewardsConfig.mining)
                                    -- DIMINISHING XP vs out-leveled crystals (Jason: no
                                    -- overnight auto-click leveling; -3 levels ~ not worth it).
                                    -- REALM RESCALE: the player's current realm depth lifts the
                                    -- crystal's effective level (layers.level_offsets) so heaven_1/
                                    -- hell_1 keep paying real XP instead of flooring a high-level
                                    -- player the moment they arrive (home is the only floor zone).
                                    local realmLevelOffset = (
                                        layerService
                                        and layerService.GetLevelOffset
                                        and layerService:GetLevelOffset(plr)
                                    ) or 0
                                    xp = math.floor(
                                        xp
                                            * LevelDiffYield.xp(
                                                plr:GetAttribute("Level"),
                                                (model:GetAttribute("MiningLevel") or 1)
                                                    + realmLevelOffset,
                                                xpLevelScaleCfg
                                            )
                                    )
                                    if xp > 0 then
                                        progression:AddExperience(plr, xp)
                                    end
                                end
                                if
                                    petProgressionService
                                    and petProgressionService.AwardBreakableDestroyed
                                then
                                    petProgressionService:AwardBreakableDestroyed(plr, {
                                        world = model:GetAttribute("World"),
                                        breakableId = model:GetAttribute("BreakableId"),
                                        crystalName = model:GetAttribute("CrystalName"),
                                        currency = currencyType,
                                        source = "BreakableSpawner",
                                    })
                                end
                                -- World S3: realm token cut on the same income share (no-op at base).
                                if layerService and layerService.GrantIncomeCut then
                                    layerService:GrantIncomeCut(plr, resolvedShare)
                                end
                            end)
                        end
                        if v.Value > topAmount then
                            topAmount = v.Value
                            topUserId = tonumber(v.Name)
                        end
                    end
                end
                if remainder > 0 and topUserId then
                    local topPlayer = Players:GetPlayerByUserId(topUserId)
                    if topPlayer then
                        local resolvedRemainder = resolvePlayerAward(topPlayer, remainder)
                        pcall(function()
                            creditCoins(topPlayer, resolvedRemainder, "crystal_break_remainder")
                        end)
                    end
                end
            end
        end
        -- Play break sound and destroy
        local container = model:FindFirstChild(model.Name) or model
        local sound = container:FindFirstChild("bigBreakSound")
        if sound and sound:IsA("Sound") then
            sound:Play()
            task.delay(sound.TimeLength or 0.2, function()
                if model and model.Parent then
                    model:Destroy()
                end
            end)
        else
            if model and model.Parent then
                model:Destroy()
            end
        end
    end

    model:GetAttributeChangedSignal("HP"):Connect(function()
        local hp = tonumber(model:GetAttribute("HP")) or 0
        if hp <= 0 then
            handleDeath()
        end
    end)

    -- Tag with spawner for diagnostics
    model:SetAttribute("Spawner", spawner.Name)
    -- Helpers for pet assignment
    local function removePetIdFromBreakables(petId)
        local breakablesRoot = workspace:FindFirstChild("Game")
            and workspace.Game:FindFirstChild("Breakables")
        if not breakablesRoot then
            return
        end
        local function scan(folder)
            for _, child in ipairs(folder:GetChildren()) do
                if child:IsA("Folder") and child.Name == "Pets" then
                    for _, y in ipairs(child:GetChildren()) do
                        if y:IsA("NumberValue") and y.Value == petId then
                            y:Destroy()
                        end
                    end
                end
                if #child:GetChildren() > 0 then
                    scan(child)
                end
            end
        end
        scan(breakablesRoot)
    end

    local function assignPlayerPetsToTarget(player)
        local petInstancesFolder = workspace:FindFirstChild("PlayerPets")
        if not petInstancesFolder then
            return
        end
        local playerPets = petInstancesFolder:FindFirstChild(player.Name)
        if not playerPets then
            return
        end
        local targetId = model:FindFirstChild("BreakableID") and model.BreakableID.Value or 0
        for _, petInst in ipairs(playerPets:GetChildren()) do
            local petIdVal = petInst:FindFirstChild("PetID")
            local targetIdVal = petInst:FindFirstChild("TargetID")
            local targetTypeVal = petInst:FindFirstChild("TargetType")
            local targetWorldVal = petInst:FindFirstChild("TargetWorld")
            if petIdVal and targetIdVal and targetTypeVal and targetWorldVal then
                -- Combat outranks auto-mine: never yank a pet off a LIVE enemy
                -- onto a crystal (otherwise pets scatter mid-fight).
                local lockedOnEnemy = false
                if targetTypeVal.Value == "Enemy" and targetIdVal.Value ~= 0 then
                    local enemiesFolder = workspace:FindFirstChild("Game")
                        and workspace.Game:FindFirstChild("Enemies")
                    if enemiesFolder then
                        for _, em in ipairs(enemiesFolder:GetChildren()) do
                            local bid = em:FindFirstChild("BreakableID")
                            if
                                bid
                                and bid.Value == targetIdVal.Value
                                and (em:GetAttribute("HP") or 0) > 0
                            then
                                lockedOnEnemy = true
                                break
                            end
                        end
                    end
                end
                if
                    targetIdVal.Value ~= targetId
                    and not lockedOnEnemy
                    and not petInst:GetAttribute("CombatDowned")
                then
                    removePetIdFromBreakables(petIdVal.Value)
                    -- Add entry to this crystal's Pets folder
                    local petsFolder = model:FindFirstChild("Pets") or Instance.new("Folder")
                    petsFolder.Name = "Pets"
                    petsFolder.Parent = model
                    local numInstance = Instance.new("NumberValue")
                    numInstance.Name = "Pet"
                    numInstance.Value = petIdVal.Value
                    local leadership = Instance.new("NumberValue")
                    leadership.Name = "Leadership"
                    leadership.Value = 0
                    leadership.Parent = numInstance
                    local tactics = Instance.new("NumberValue")
                    tactics.Name = "Tactics"
                    tactics.Value = 0
                    tactics.Parent = numInstance
                    local eff = Instance.new("NumberValue")
                    eff.Name = "Efficiency"
                    eff.Value = 1
                    eff.Parent = numInstance
                    numInstance.Parent = petsFolder

                    targetTypeVal.Value = "Crystals"
                    targetWorldVal.Value = worldFolder.Name
                    targetIdVal.Value = targetId
                end
            end
        end
        -- Visual/audio feedback
        local pp = model.PrimaryPart
        if pp then
            local bb = pp:FindFirstChild("BillboardGui")
            if bb then
                bb.MaxDistance = 75
            end
            local bbb = pp:FindFirstChild("BoostBillboardGui")
            if bbb then
                bbb.MaxDistance = 75
            end
            local hum = pp:FindFirstChild("EngineHumSound")
            if hum and hum:IsA("Sound") then
                hum:Play()
            end
        end
        -- (Boost is built by player CLICKS, not auto-assignment — see the ClickDetector handler.)
    end

    -- Add click-to-assign-pets and damage (server-side)
    local breakableIdForLogs = (model:FindFirstChild("BreakableID") and model.BreakableID.Value)
        or 0
    local function attachClick(part)
        local cd = Instance.new("ClickDetector")
        cd.MaxActivationDistance = 50
        cd.Parent = part
        cd.MouseClick:Connect(function(player)
            -- Active-mining: clicking the node you're mining ASSIGNS your pets to it and BUILDS
            -- its Boost, which amplifies your pets' damage on it (PetFollowService). The click
            -- itself deals NO damage — firewall-clean: the player amplifies, the pets deal.
            local hp = tonumber(model:GetAttribute("HP")) or 0
            if hp <= 0 then
                return
            end
            assignPlayerPetsToTarget(player)
            local cfg = breakablesConfig.boost or {}
            local per = tonumber(cfg.per_click) or 10
            local maxB = tonumber(model:GetAttribute("MaxBoost")) or 100
            local b = math.min(maxB, (tonumber(model:GetAttribute("Boost")) or 0) + per)
            model:SetAttribute("Boost", b)
        end)
    end
    if model.PrimaryPart then
        attachClick(model.PrimaryPart)
    end
    for _, d in ipairs(model:GetDescendants()) do
        if d:IsA("BasePart") and d ~= model.PrimaryPart then
            attachClick(d)
        end
    end
    -- Parent to Items and update count
    model.Parent = worldFolder:FindFirstChild("Items")
    current.Value = current.Value + 1

    if dropFromHeight > 0 then
        task.spawn(function()
            local startPivot = model:GetPivot()
            local elapsed = 0
            local duration = math.max(0.05, dropDuration)

            while model.Parent and elapsed < duration do
                local dt = RunService.Heartbeat:Wait()
                elapsed += dt
                local alpha = math.clamp(elapsed / duration, 0, 1)
                local eased = 1 - math.pow(1 - alpha, 3)
                model:PivotTo(startPivot:Lerp(finalPivot, eased))
            end

            if model.Parent then
                model:PivotTo(finalPivot)
            end
        end)
    end

    return model
end

function BreakableSpawner:SpawnBreakableForStudioSmoke(areaId, breakableId)
    if not RunService:IsStudio() then
        return nil, "studio_only"
    end

    if type(areaId) ~= "string" or areaId == "" then
        return nil, "invalid_area"
    end
    if type(breakableId) ~= "string" or breakableId == "" then
        return nil, "invalid_breakable"
    end
    if not (breakablesConfig.crystals and breakablesConfig.crystals[breakableId]) then
        return nil, "unknown_breakable"
    end

    local crystalsRoot = workspace:FindFirstChild("Game")
        and workspace.Game:FindFirstChild("Breakables")
        and workspace.Game.Breakables:FindFirstChild("Crystals")
    local worldFolder = crystalsRoot and crystalsRoot:FindFirstChild(areaId)
    if not worldFolder then
        return nil, "missing_area_folder"
    end

    self:_setupWorld(worldFolder)

    local model = self:_trySpawnOne(worldFolder, breakableId, nil, true)
    if not model then
        return nil, "spawn_failed"
    end

    return model
end

return BreakableSpawner
