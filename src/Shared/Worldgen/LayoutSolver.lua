--[[
    LayoutSolver — pure seeded mission-map layout (docs/MISSION_WORLDGEN.md §4).

    PURE: no Roblox APIs, no Instances, no CFrames. Every door direction is
    axis-aligned in tile-local space (TileCatalog contract), so all placements
    are yaw multiples of 90° — a placement is { x, z, rot } with rot ∈ 0..3
    quarter turns. The M2 stamper converts to CFrames via
    `slotOrigin * CFrame.new(x, 0, z) * CFrame.Angles(0, rot * math.pi/2, 0)`.

    solve(catalog, params, layoutSeed) -> spec, report   (spec nil on failure)

    Algorithm: frontier growth from the entrance. While the objective is
    pending, only frontier doors with tile-depth <= target_depth.max may grow
    (deeper doors wait), and a door AT target_depth.max forces an objective —
    so a placed objective always lands within [target_depth.min, max] of the
    growth tree. Attempts that can't satisfy that restart with a fresh rng
    stream derived deterministically from the seed, so the final map is still
    a pure function of (catalog, params, layoutSeed).

    Facing-door rule: two open doors left exactly coincident and opposed MUST
    connect (their caps would occupy each other's tile volume) — this is also
    how loops emerge. Depth recorded per tile is GROWTH-TREE depth, not
    shortest-path (loop shortcuts don't retroactively shrink objective depth).
]]

local MissionSeed = require(script.Parent.MissionSeed)

local LayoutSolver = {}

local EPS = 1e-6

local DIR_VEC = {
    px = { 1, 0 },
    nx = { -1, 0 },
    pz = { 0, 1 },
    nz = { 0, -1 },
}

-- Rotate a tile-local XZ vector by rot quarter turns (matches CFrame +Y yaw:
-- one turn maps (x, z) -> (z, -x), i.e. px -> nz).
local function rotXZ(x, z, rot)
    for _ = 1, rot % 4 do
        x, z = z, -x
    end
    return x, z
end

local function defaults(params)
    params = params or {}
    local target = params.target_depth or {}
    return {
        tile_budget = params.tile_budget or 40,
        target_min = target.min or 6,
        target_max = target.max or 10,
        objective_count = params.objective_count or 1,
        objective_weight = params.objective_weight or 3,
        class_weights_by_band = params.class_weights_by_band
            or { { upto = 1, corridor = 2, room = 2, junction = 1 } },
        door_tile_attempts = params.door_tile_attempts or 8,
        max_attempts = params.max_attempts or 8,
        overlap_margin = params.overlap_margin or 0.5,
        max_half_extent = params.max_half_extent, -- optional slot envelope (studs from origin)
    }
end

-- ---- geometry ----------------------------------------------------------

local function tileAABB(tile, px, pz, rot)
    local b = tile.bounds
    local cx, cz = rotXZ(b.ox, b.oz, rot)
    cx, cz = px + cx, pz + cz
    local hx, hz = b.hx, b.hz
    if rot % 2 == 1 then
        hx, hz = hz, hx
    end
    return { minx = cx - hx, minz = cz - hz, maxx = cx + hx, maxz = cz + hz }
end

-- Penetration deeper than `tol` on both axes = overlap. Exactly-touching
-- neighbours (mated tiles share the aperture plane) have penetration 0.
local function overlaps(a, b, tol)
    local ox = math.min(a.maxx, b.maxx) - math.max(a.minx, b.minx)
    local oz = math.min(a.maxz, b.maxz) - math.max(a.minz, b.minz)
    return ox > tol and oz > tol
end

local function fitsEnvelope(aabb, maxHalf)
    if not maxHalf then
        return true
    end
    return aabb.minx >= -maxHalf
        and aabb.maxx <= maxHalf
        and aabb.minz >= -maxHalf
        and aabb.maxz <= maxHalf
end

-- World-space doors of a placed tile.
local function placedDoors(tile, px, pz, rot)
    local out = {}
    for _, d in ipairs(tile.doors) do
        local wx, wz = rotXZ(d.x, d.z, rot)
        local dv = DIR_VEC[d.dir]
        local dx, dz = rotXZ(dv[1], dv[2], rot)
        out[#out + 1] =
            { name = d.name, x = px + wx, z = pz + wz, dx = dx, dz = dz, class = d.class }
    end
    return out
end

-- Rotation that mates a candidate door (local dir) onto a frontier door
-- (world dir): rotated local dir must OPPOSE the frontier dir.
local function matingRot(localDir, frontierDx, frontierDz)
    local dv = DIR_VEC[localDir]
    for rot = 0, 3 do
        local dx, dz = rotXZ(dv[1], dv[2], rot)
        if dx == -frontierDx and dz == -frontierDz then
            return rot
        end
    end
    return nil -- unreachable for axis-aligned dirs
end

-- ---- rng helpers -------------------------------------------------------

local function pickWeighted(list, weightOf, rng)
    local total = 0
    for _, item in ipairs(list) do
        total += weightOf(item)
    end
    if total <= 0 then
        return nil
    end
    local roll = rng() * total
    local acc = 0
    for _, item in ipairs(list) do
        acc += weightOf(item)
        if roll < acc then
            return item
        end
    end
    return list[#list]
end

local function popRandom(list, indices, rng)
    local pick = indices[math.floor(rng() * #indices) + 1] or indices[#indices]
    local item = list[pick]
    list[pick] = list[#list]
    list[#list] = nil
    return item
end

-- ---- single attempt ----------------------------------------------------

local function bandWeights(p, depth)
    local frac = p.target_max > 0 and math.min(depth / p.target_max, 1) or 1
    for _, band in ipairs(p.class_weights_by_band) do
        if frac <= band.upto + EPS then
            return band
        end
    end
    return p.class_weights_by_band[#p.class_weights_by_band]
end

local function tryOnce(catalog, p, rng)
    local placed = {} -- { tile, x, z, rot, depth, viaDoor? }
    local aabbs = {}
    local counts = {}
    local frontier = {} -- { x, z, dx, dz, class, depth (of the tile a mate would get), fromIndex, fromDoor }
    local deferred = {}
    local connections = {}
    local objectivesPlaced = 0
    local growth = 0 -- non-cap tiles placed (counts toward tile_budget)

    local function eligible(tile, depth)
        if tile.maxPerMap > 0 and (counts[tile.id] or 0) >= tile.maxPerMap then
            return false
        end
        if tile.minDepth and depth < tile.minDepth then
            return false
        end
        if tile.maxDepth and depth > tile.maxDepth then
            return false
        end
        return true
    end

    local function place(tile, x, z, rot, depth, viaDoor, consumedDoorName)
        local aabb = tileAABB(tile, x, z, rot)
        table.insert(
            placed,
            { tile = tile, x = x, z = z, rot = rot, depth = depth, viaDoor = viaDoor }
        )
        table.insert(aabbs, aabb)
        counts[tile.id] = (counts[tile.id] or 0) + 1
        local index = #placed
        for _, wd in ipairs(placedDoors(tile, x, z, rot)) do
            if wd.name ~= consumedDoorName then
                table.insert(frontier, {
                    x = wd.x,
                    z = wd.z,
                    dx = wd.dx,
                    dz = wd.dz,
                    class = wd.class,
                    depth = depth + 1,
                    fromIndex = index,
                    fromDoor = wd.name,
                })
            end
        end
        return index
    end

    -- Try to mate `tile` onto frontier door `fd`; returns true if placed.
    local function tryPlaceAt(tile, fd)
        for _, door in ipairs(tile.doors) do
            if door.class == fd.class then
                local rot = matingRot(door.dir, fd.dx, fd.dz)
                if rot then
                    -- pivot = doorWorld - rotate(doorLocal)
                    local lx, lz = rotXZ(door.x, door.z, rot)
                    local px, pz = fd.x - lx, fd.z - lz
                    local aabb = tileAABB(tile, px, pz, rot)
                    if fitsEnvelope(aabb, p.max_half_extent) then
                        local clear = true
                        for _, other in ipairs(aabbs) do
                            if overlaps(aabb, other, p.overlap_margin) then
                                clear = false
                                break
                            end
                        end
                        if clear then
                            local index = place(
                                tile,
                                px,
                                pz,
                                rot,
                                fd.depth,
                                {
                                    parent = fd.fromIndex,
                                    parentDoor = fd.fromDoor,
                                    door = door.name,
                                },
                                door.name
                            )
                            table.insert(connections, {
                                a = { tile = fd.fromIndex, door = fd.fromDoor },
                                b = { tile = index, door = door.name },
                            })
                            return true
                        end
                    end
                end
            end
        end
        return false
    end

    -- 1. entrance at the origin
    local entrance = pickWeighted(catalog.byClass.entrance, function(t)
        return t.weight
    end, rng)
    place(entrance, 0, 0, 0, 0, nil, nil)
    growth = 1

    -- 2. frontier growth
    while #frontier > 0 and growth < p.tile_budget do
        local objectivePending = objectivesPlaced < p.objective_count

        -- While the objective is pending, only doors that can still host it in
        -- band (depth <= target_max) may grow; deeper doors wait their turn.
        local poolIndices = {}
        for i, fd in ipairs(frontier) do
            if not objectivePending or fd.depth <= p.target_max then
                table.insert(poolIndices, i)
            end
        end
        if #poolIndices == 0 then
            return nil, "objective pending but no frontier door within target_depth.max"
        end

        local fd = popRandom(frontier, poolIndices, rng)

        local success = false
        if objectivePending and fd.depth >= p.target_max then
            -- forced: this door is the last chance to stay in band on this branch
            local tile = pickWeighted(catalog.byClass.objective, function(t)
                return eligible(t, fd.depth) and t.weight or 0
            end, rng)
            if tile and tryPlaceAt(tile, fd) then
                objectivesPlaced += 1
                growth += 1
                success = true
            end
        else
            local band = bandWeights(p, fd.depth)
            local classPool = {
                { class = "corridor", weight = band.corridor or 0 },
                { class = "room", weight = band.room or 0 },
                { class = "junction", weight = band.junction or 0 },
            }
            if objectivePending and fd.depth >= p.target_min then
                table.insert(classPool, { class = "objective", weight = p.objective_weight })
            end

            for _ = 1, p.door_tile_attempts do
                local classPick = pickWeighted(classPool, function(c)
                    return c.weight
                end, rng)
                local tile = classPick
                    and pickWeighted(catalog.byClass[classPick.class], function(t)
                        return eligible(t, fd.depth) and t.weight or 0
                    end, rng)
                if tile and tryPlaceAt(tile, fd) then
                    if tile.class == "objective" then
                        objectivesPlaced += 1
                    end
                    growth += 1
                    success = true
                    break
                end
            end
        end

        if not success then
            table.insert(deferred, fd)
        end
    end

    if objectivesPlaced < p.objective_count then
        return nil, "budget exhausted before objective placement"
    end

    -- 3. leftover doors: exactly-coincident opposed pairs MUST connect
    local leftovers = {}
    for _, fd in ipairs(frontier) do
        table.insert(leftovers, fd)
    end
    for _, fd in ipairs(deferred) do
        table.insert(leftovers, fd)
    end

    local mated = {}
    local loopMates = 0
    for i = 1, #leftovers do
        if not mated[i] then
            for j = i + 1, #leftovers do
                if not mated[j] then
                    local a, b = leftovers[i], leftovers[j]
                    if
                        math.abs(a.x - b.x) < EPS
                        and math.abs(a.z - b.z) < EPS
                        and a.dx == -b.dx
                        and a.dz == -b.dz
                    then
                        if a.class ~= b.class then
                            return nil, "coincident facing doors of mismatched class"
                        end
                        table.insert(connections, {
                            a = { tile = a.fromIndex, door = a.fromDoor },
                            b = { tile = b.fromIndex, door = b.fromDoor },
                        })
                        mated[i], mated[j] = true, true
                        loopMates += 1
                        break
                    end
                end
            end
        end
    end

    -- 4. cap everything still open
    local caps = 0
    for i, fd in ipairs(leftovers) do
        if not mated[i] then
            local cap = pickWeighted(catalog.byClass.cap, function(t)
                return (t.doors[1].class == fd.class and eligible(t, fd.depth)) and t.weight or 0
            end, rng)
            if not (cap and tryPlaceAt(cap, fd)) then
                return nil, "open door could not be capped"
            end
            -- tryPlaceAt pushed nothing new to frontier (cap has exactly one
            -- door, which was consumed) so leftovers stays complete.
            caps += 1
        end
    end

    -- 5. spec
    local bbox = { minx = math.huge, minz = math.huge, maxx = -math.huge, maxz = -math.huge }
    for _, aabb in ipairs(aabbs) do
        bbox.minx = math.min(bbox.minx, aabb.minx)
        bbox.minz = math.min(bbox.minz, aabb.minz)
        bbox.maxx = math.max(bbox.maxx, aabb.maxx)
        bbox.maxz = math.max(bbox.maxz, aabb.maxz)
    end

    local tiles = {}
    local objectiveTileIndices = {}
    for i, pl in ipairs(placed) do
        tiles[i] = {
            tileId = pl.tile.id,
            x = pl.x,
            z = pl.z,
            rot = pl.rot,
            depth = pl.depth,
            viaDoor = pl.viaDoor,
        }
        if pl.tile.class == "objective" then
            table.insert(objectiveTileIndices, i)
        end
    end

    local spec = {
        version = 1,
        kitId = catalog.kitId,
        tiles = tiles,
        connections = connections,
        objectiveTileIndices = objectiveTileIndices,
        bbox = bbox,
    }
    local report = {
        growthTiles = growth,
        caps = caps,
        loopMates = loopMates,
        deferred = #deferred,
    }
    return spec, report
end

-- ---- public API ---------------------------------------------------------

-- Pure: the same (catalog, params, layoutSeed) always yields the same spec.
-- Failed attempts restart with a deterministically derived rng stream.
function LayoutSolver.solve(catalog, params, layoutSeed)
    local p = defaults(params)
    local failures = {}
    for attempt = 1, p.max_attempts do
        local rng = MissionSeed.mulberry32(
            MissionSeed.fnv1a32(tostring(layoutSeed) .. "|attempt|" .. attempt)
        )
        local spec, reportOrErr = tryOnce(catalog, p, rng)
        if spec then
            spec.seed = layoutSeed
            reportOrErr.attempts = attempt
            return spec, reportOrErr
        end
        table.insert(failures, reportOrErr)
    end
    return nil, { attempts = p.max_attempts, error = table.concat(failures, "; ") }
end

-- Pure: the payload a client mission minimap renders (CoH-style). One rect
-- per non-cap tile (slot-local, axis-aligned), one entry per WALKABLE
-- doorway (mated pairs from spec.connections where both sides are rooms —
-- cap-plugged doorways are sealed walls and never appear), plus the bbox.
--   rooms: { class, x, z, hx, hz }          (rect center + half extents)
--   doors: { x, z, ax = "x"|"z", a, b }     (ax = the wall axis the tick
--                                            runs along; a/b = room indices)
function LayoutSolver.mapData(catalog, spec)
    local rooms = {}
    local roomIndexByTile = {}
    for i, t in ipairs(spec.tiles) do
        local tile = catalog.byId[t.tileId]
        if tile and tile.class ~= "cap" then
            local aabb = tileAABB(tile, t.x, t.z, t.rot)
            table.insert(rooms, {
                class = tile.class,
                tile = i, -- spec.tiles index (dressing pass maps room → stamped Model)
                x = (aabb.minx + aabb.maxx) / 2,
                z = (aabb.minz + aabb.maxz) / 2,
                hx = (aabb.maxx - aabb.minx) / 2,
                hz = (aabb.maxz - aabb.minz) / 2,
            })
            roomIndexByTile[i] = #rooms
        end
    end

    local doors = {}
    for _, c in ipairs(spec.connections or {}) do
        local ra, rb = roomIndexByTile[c.a.tile], roomIndexByTile[c.b.tile]
        if ra and rb then
            local t = spec.tiles[c.a.tile]
            local tile = catalog.byId[t.tileId]
            for _, d in ipairs(tile.doors) do
                if d.name == c.a.door then
                    local wx, wz = rotXZ(d.x, d.z, t.rot)
                    local dv = DIR_VEC[d.dir]
                    local dx, _dz = rotXZ(dv[1], dv[2], t.rot)
                    table.insert(doors, {
                        x = t.x + wx,
                        z = t.z + wz,
                        ax = dx ~= 0 and "z" or "x",
                        a = ra,
                        b = rb,
                    })
                end
            end
        end
    end

    return { rooms = rooms, doors = doors, bbox = spec.bbox }
end

-- Recompute-and-check every invariant from the spec alone (never trusts the
-- solver's bookkeeping). Returns ok, problems (array of strings).
function LayoutSolver.validate(catalog, spec, params)
    local p = defaults(params)
    local problems = {}
    local function problem(fmt, ...)
        table.insert(problems, fmt:format(...))
    end

    if type(spec) ~= "table" or type(spec.tiles) ~= "table" or #spec.tiles == 0 then
        return false, { "spec has no tiles" }
    end

    -- resolve tiles, rebuild AABBs + world doors
    local aabbs = {}
    local allDoors = {} -- { tileIndex, name, x, z, dx, dz, class }
    local counts = {}
    local entranceCount, objectiveCount = 0, 0

    for i, t in ipairs(spec.tiles) do
        local tile = catalog.byId[t.tileId]
        if not tile then
            problem("tiles[%d]: unknown tileId %q", i, tostring(t.tileId))
        else
            counts[tile.id] = (counts[tile.id] or 0) + 1
            if tile.class == "entrance" then
                entranceCount += 1
                if i ~= 1 then
                    problem("entrance tile at index %d (must be index 1)", i)
                end
            elseif tile.class == "objective" then
                objectiveCount += 1
                if t.depth < p.target_min or t.depth > p.target_max then
                    problem(
                        "objective %q depth %d outside band [%d, %d]",
                        tile.id,
                        t.depth,
                        p.target_min,
                        p.target_max
                    )
                end
            end
            if tile.maxPerMap > 0 and counts[tile.id] > tile.maxPerMap then
                problem("tile %q exceeds maxPerMap %d", tile.id, tile.maxPerMap)
            end
            aabbs[i] = tileAABB(tile, t.x, t.z, t.rot)
            for _, wd in ipairs(placedDoors(tile, t.x, t.z, t.rot)) do
                table.insert(allDoors, {
                    tileIndex = i,
                    name = wd.name,
                    x = wd.x,
                    z = wd.z,
                    dx = wd.dx,
                    dz = wd.dz,
                    class = wd.class,
                })
            end
        end
    end

    if entranceCount ~= 1 then
        problem("expected exactly 1 entrance, found %d", entranceCount)
    end
    if objectiveCount < 1 then
        problem("no objective tile placed")
    end

    -- pairwise AABB overlap
    for i = 1, #aabbs do
        for j = i + 1, #aabbs do
            if aabbs[i] and aabbs[j] and overlaps(aabbs[i], aabbs[j], p.overlap_margin) then
                problem("tiles %d and %d overlap beyond margin", i, j)
            end
        end
    end

    -- every door has exactly one geometric partner (opposed, coincident, same class)
    for i = 1, #allDoors do
        local a = allDoors[i]
        local partners = 0
        for j = 1, #allDoors do
            if i ~= j then
                local b = allDoors[j]
                if
                    math.abs(a.x - b.x) < EPS
                    and math.abs(a.z - b.z) < EPS
                    and a.dx == -b.dx
                    and a.dz == -b.dz
                    and a.class == b.class
                then
                    partners += 1
                end
            end
        end
        if partners ~= 1 then
            problem(
                "door %s on tile %d has %d partners (expected 1 — open or over-shared doorway)",
                a.name,
                a.tileIndex,
                partners
            )
        end
    end

    -- connectivity: BFS over connections must reach every tile
    local adj = {}
    for _, c in ipairs(spec.connections or {}) do
        adj[c.a.tile] = adj[c.a.tile] or {}
        adj[c.b.tile] = adj[c.b.tile] or {}
        table.insert(adj[c.a.tile], c.b.tile)
        table.insert(adj[c.b.tile], c.a.tile)
    end
    local visited = { [1] = true }
    local queue = { 1 }
    local reached = 1
    while #queue > 0 do
        local node = table.remove(queue)
        for _, nxt in ipairs(adj[node] or {}) do
            if not visited[nxt] then
                visited[nxt] = true
                reached += 1
                table.insert(queue, nxt)
            end
        end
    end
    if reached ~= #spec.tiles then
        problem("connectivity: reached %d of %d tiles from entrance", reached, #spec.tiles)
    end

    -- bbox: recompute and compare, plus envelope
    for i, aabb in ipairs(aabbs) do
        if spec.bbox then
            if
                aabb.minx < spec.bbox.minx - EPS
                or aabb.minz < spec.bbox.minz - EPS
                or aabb.maxx > spec.bbox.maxx + EPS
                or aabb.maxz > spec.bbox.maxz + EPS
            then
                problem("tile %d escapes spec.bbox", i)
            end
        end
        if not fitsEnvelope(aabb, p.max_half_extent) then
            problem(
                "tile %d escapes slot envelope (max_half_extent %s)",
                i,
                tostring(p.max_half_extent)
            )
        end
    end

    return #problems == 0, problems
end

return LayoutSolver
