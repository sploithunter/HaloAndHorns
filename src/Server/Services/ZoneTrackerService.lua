--[[
    ZoneTrackerService — server-authoritative "which area is each player standing in".

    Replaces the fragile touch-part area detection with config-bounds resolution: a few times a
    second it tests every player's HiddenRootPart position against the authored area boxes in
    configs/areas.lua (via the pure ZoneResolver) and writes the result to ONE SSOT player
    attribute, `CurrentArea`. Consumers read that attribute (and listen to its change signal):
      - AutoTargetService scopes farming to the current area's footprint;
      - area music (future) swaps on CurrentArea change;
      - per-zone breakable activation (future) can gate spawning on the active area.

    Robust to falls/teleports (no Touched dependency), cheap (a handful of box tests/player),
    and sticky (hysteresis margin) so standing on a shared edge doesn't flicker. Pure math lives
    in ZoneResolver; this service only does the polling + attribute write.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ZoneResolver = require(ReplicatedStorage.Shared.Game.ZoneResolver)
local WorldContext = require(ReplicatedStorage.Shared.Game.WorldContext)
local fireGameEvent = require(ReplicatedStorage.Shared.Network.FireGameEvent)

local ZoneTrackerService = {}
ZoneTrackerService.__index = ZoneTrackerService

local CURRENT_AREA_ATTR = "CurrentArea"

function ZoneTrackerService:Init()
    self._logger = self._modules and self._modules.Logger
    self._configLoader = self._modules and self._modules.ConfigLoader

    local areasConfig = self._configLoader and self._configLoader:LoadConfig("areas") or {}
    self._bounds = ZoneResolver.boundsFromAreas(areasConfig)

    -- Realm worlds (Heaven_1/Hell_1) are copies of Home, so their biome floors reuse Home's part
    -- NAMES ("Lava", "Ice", …). A raycast that maps by name alone would resolve a player standing in
    -- Heaven_1 to the homeworld "Lava" area (already unlocked) — so the realm unlock prompt never
    -- shows. Build the set of area-zone ids whose id is also a world folder name; when the floor we
    -- land on lives inside such a world, the player is in that REALM zone, not the homeworld biome.
    self._areaZoneIds = {}
    for id, z in pairs(areasConfig.zones or {}) do
        if type(z) == "table" and z.kind == "area" then
            self._areaZoneIds[id] = true
        end
    end

    local cfg = (self._configLoader and self._configLoader:LoadConfig("zone_tracker")) or {}
    self._pollInterval = tonumber(cfg.poll_interval) or 0.25
    self._verticalBand = tonumber(cfg.vertical_band) or 80
    self._boundaryMargin = tonumber(cfg.boundary_margin) or 6
    self._defaultArea = cfg.default_area or "Spawn"
    self._baseplateArea = cfg.baseplate_area or {}
    self._raycastDepth = tonumber(cfg.raycast_depth) or 60
    self._baseplateMaxThickness = tonumber(cfg.baseplate_max_thickness) or 5

    if self._logger then
        self._logger:Info("ZoneTrackerService initialized", {
            areas = #self._bounds,
            pollInterval = self._pollInterval,
        })
    end
end

-- Public getter — the SSOT for "where is this player".
function ZoneTrackerService:GetCurrentArea(player)
    if not player then
        return nil
    end
    return player:GetAttribute(CURRENT_AREA_ATTR)
end

local function rootPosition(player)
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then
        return nil
    end
    local p = hrp.Position
    return { x = p.X, y = p.Y, z = p.Z }
end

-- Resolve (and cache) the biome baseplate parts to raycast against: any workspace BasePart whose
-- name is a key in baseplate_area (Grass/Lava/Ice/Desert). Cache is reused until a part leaves the
-- world; when empty (map not loaded yet / names mismatch) rescans are throttled so we never do a
-- full-workspace scan every poll.
function ZoneTrackerService:_getBaseplateParts()
    local cache = self._baseplateParts
    if cache and #cache > 0 then
        local valid = true
        for _, p in ipairs(cache) do
            if not p.Parent then
                valid = false
                break
            end
        end
        if valid then
            return cache
        end
    end

    -- Throttle empty rescans (e.g. before the map streams in) to once every few seconds.
    local now = os.clock()
    if
        (not cache or #cache == 0)
        and self._lastBaseplateScan
        and (now - self._lastBaseplateScan) < 5
    then
        return cache or {}
    end
    self._lastBaseplateScan = now

    local parts = {}
    for _, d in ipairs(workspace:GetDescendants()) do
        -- Flat slabs only — a tall biome-named structure (e.g. a 94-stud "Lava" rock) is not a
        -- floor and would mis-detect the area near it.
        if
            d:IsA("BasePart")
            and self._baseplateArea[d.Name]
            and d.Size.Y <= self._baseplateMaxThickness
        then
            table.insert(parts, d)
        end
    end
    self._baseplateParts = parts
    return parts
end

-- PRIMARY area detection: raycast straight down with an INCLUDE filter limited to the biome
-- baseplates, and map the floor we land on (Grass/Lava/Ice/Desert) to an area id. Because only
-- baseplates are in the filter, sidewalks / paths / decorations / ore are ignored and the ray
-- passes through them to the biome floor BENEATH — so standing on a path that crosses the grass
-- still resolves to Spawn. Returns nil when no biome floor is below (off-map / over a gap).
function ZoneTrackerService:_resolveByRaycast(player)
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then
        return nil
    end
    local parts = self:_getBaseplateParts()
    if #parts == 0 then
        return nil
    end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Include
    params.FilterDescendantsInstances = parts
    -- Start slightly above the HRP and cast down a generous depth so elevated structures over a
    -- biome (towers, raised paths) still find the floor below.
    local origin = hrp.Position + Vector3.new(0, 5, 0)
    local hit = workspace:Raycast(origin, Vector3.new(0, -(self._raycastDepth + 5), 0), params)
    if hit and hit.Instance then
        -- Realm worlds split into per-origin zones named "<World>_<FloorName>" (Heaven_1_Lava,
        -- Heaven_1_Ice, …). The floor part name IS the origin biome, so a floor inside a realm world
        -- resolves to that origin's zone — NOT the shared homeworld biome (which the part name alone
        -- would give). Homeworld floors ("Home_Lava" etc.) aren't zones, so they fall through.
        local worldName = self:_worldFolderName(hit.Instance)
        if worldName then
            local perOrigin = worldName .. "_" .. hit.Instance.Name
            if self._areaZoneIds[perOrigin] then
                return perOrigin
            end
        end
        return self._baseplateArea[hit.Instance.Name]
    end
    return nil
end

-- Name of the Workspace.Maps child (world folder) that contains `inst`, or nil if not under Maps.
function ZoneTrackerService:_worldFolderName(inst)
    local maps = workspace:FindFirstChild("Maps")
    if not maps then
        return nil
    end
    local node = inst
    while node and node.Parent and node.Parent ~= maps do
        node = node.Parent
    end
    return (node and node.Parent == maps) and node.Name or nil
end

function ZoneTrackerService:_resolveFor(player)
    local pos = rootPosition(player)
    if not pos then
        return -- character not spawned yet; leave the last known area in place
    end

    local current = player:GetAttribute(CURRENT_AREA_ATTR)

    -- Primary: which baseplate are we physically standing on.
    local resolved = self:_resolveByRaycast(player)
    if not resolved then
        -- Not on a known baseplate (mid-air/bridge): keep the last area rather than risk a
        -- mis-resolve from the overlapping boxes. Use the box fallback only if we have no area yet.
        resolved = current
            or ZoneResolver.resolveSticky(pos, self._bounds, current, {
                verticalBand = self._verticalBand,
                margin = self._boundaryMargin,
                default = self._defaultArea,
            })
    end

    if resolved ~= current then
        player:SetAttribute(CURRENT_AREA_ATTR, resolved)
        if self._logger then
            self._logger:Info("Area changed", {
                player = player.Name,
                from = current or "(none)",
                to = resolved,
            })
        end
        -- Realm ENTRY: when the area change crosses into Heaven/Hell (from a different realm),
        -- fire entered_heaven/entered_hell once. Feeds the event-counter bridge (heaven_visits /
        -- hell_visits) that backs the "Go to Heaven/Hell" quests. Crossing within a realm
        -- (Heaven_1_Lava -> Heaven_1_Ice) doesn't refire — the realm didn't change.
        local fromRealm = WorldContext.realmOfZoneId(current)
        local toRealm = WorldContext.realmOfZoneId(resolved)
        if toRealm ~= fromRealm then
            if toRealm == "heaven" then
                fireGameEvent(player, "entered_heaven", { area = resolved })
            elseif toRealm == "hell" then
                fireGameEvent(player, "entered_hell", { area = resolved })
            end
        end
    end
end

function ZoneTrackerService:Start()
    if #self._bounds == 0 then
        if self._logger then
            self._logger:Warn(
                "ZoneTrackerService: no area bounds in configs/areas.lua; CurrentArea will stay at default"
            )
        end
    end

    -- Seed CurrentArea immediately on spawn so farming/music have a value before the first poll.
    local function onCharacter(player)
        player.CharacterAdded:Connect(function()
            task.wait(0.5) -- let the HRP settle at the spawn location
            self:_resolveFor(player)
        end)
        if player.Character then
            self:_resolveFor(player)
        end
    end
    for _, player in ipairs(Players:GetPlayers()) do
        onCharacter(player)
    end
    Players.PlayerAdded:Connect(onCharacter)

    -- Throttled poll loop.
    local accumulator = 0
    RunService.Heartbeat:Connect(function(dt)
        accumulator += dt
        if accumulator < self._pollInterval then
            return
        end
        accumulator = 0
        for _, player in ipairs(Players:GetPlayers()) do
            self:_resolveFor(player)
        end
    end)
end

return ZoneTrackerService
