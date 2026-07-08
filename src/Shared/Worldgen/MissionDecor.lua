--[[
    MissionDecor — seeded per-room dressing rolls (M5a).

    PURE: no Roblox APIs. Consumes LayoutSolver.mapData rooms and the "decor"
    stream; emits per-room TINTS (color jitter factors so no two rooms read
    identical) and PROP placements (crates/barrels/rubble) that avoid the
    room center (MissionSpawn) and the wall band. The service materializes
    props as primitives; same seed = same dressing.

    roll(rooms, streamSeed, opts) →
        tints:     { [roomIndex] = { wall = f, floor = f } }  (f ≈ 0.85..1.15)
        props:     { { room, kind, x, z, rot }, ... }         (x/z slot-local)
        wallDecor: { { room, x, z, ix, iz }, ... }            (wall-mount spots:
                   position at the wall's inner face, (ix,iz) = inward normal;
                   avoids doorway apertures via opts.doors = mapData doors)
        features:  { { room, x, z, ix, iz }, ... }            (floor SHOWPIECE
                   spots — at most one per chamber, centered on a doorless
                   wall span, facing the room; the service dresses them from
                   the theme's showpiece pool: thrones/fountains/archives)
]]

local MissionSeed = require(script.Parent.MissionSeed)

local MissionDecor = {}

local KINDS = {
    { kind = "crate", weight = 4 },
    { kind = "crate_small", weight = 3 },
    { kind = "barrel", weight = 3 },
    { kind = "rubble", weight = 2 },
}

local DRESSED_CLASS = { room = true, junction = true, objective = true, entrance = true }
local CENTER_CLEAR = 14 -- keep the MissionSpawn / pad / beacon zone open
local WALL_INSET = 8

function MissionDecor.roll(rooms, streamSeed, opts)
    opts = opts or {}
    local minP = opts.props_min or 2
    local maxP = opts.props_max or 5
    local jitter = opts.color_jitter or 0.12
    local rng = MissionSeed.mulberry32(streamSeed)

    -- tints first (fixed draw count per room → prop rolls can't shift them)
    local tints = {}
    for i, room in ipairs(rooms) do
        tints[i] = {
            wall = 1 + (rng() * 2 - 1) * jitter,
            floor = 1 + (rng() * 2 - 1) * jitter,
        }
        local _ = room
    end

    local totalW = 0
    for _, k in ipairs(KINDS) do
        totalW += k.weight
    end

    local props = {}
    for i, room in ipairs(rooms) do
        if DRESSED_CLASS[room.class] then
            local n = minP + math.floor(rng() * (maxP - minP + 1))
            local hx = math.max(room.hx - WALL_INSET, 6)
            local hz = math.max(room.hz - WALL_INSET, 6)
            for _ = 1, n do
                local roll = rng() * totalW
                local acc, kind = 0, KINDS[#KINDS].kind
                for _, k in ipairs(KINDS) do
                    acc += k.weight
                    if roll < acc then
                        kind = k.kind
                        break
                    end
                end
                -- rejection-sample away from the room center (bounded tries
                -- keeps the draw count deterministic-friendly per placement)
                local x, z = 0, 0
                for _ = 1, 8 do
                    x = (rng() * 2 - 1) * hx
                    z = (rng() * 2 - 1) * hz
                    if math.abs(x) > CENTER_CLEAR or math.abs(z) > CENTER_CLEAR then
                        break
                    end
                end
                table.insert(props, {
                    room = i,
                    kind = kind,
                    x = room.x + x,
                    z = room.z + z,
                    rot = rng() * math.pi * 2,
                })
            end
        end
    end

    -- wall-mount decoration spots: banners/weapon racks on room walls, clear
    -- of doorway apertures. Edge convention: px = the wall at room.x + hx.
    local EDGES = { px = { 1, 0 }, nx = { -1, 0 }, pz = { 0, 1 }, nz = { 0, -1 } }
    local EDGE_ORDER = { "px", "nx", "pz", "nz" }
    local WALL_INNER = 2.6 -- wall thickness 2 + a hair of clearance
    local DOOR_CLEAR = 12
    local doors = opts.doors or {}
    local wallDecor = {}
    local wallMin = opts.wall_decor_min or 0
    local wallMax = opts.wall_decor_max or 2
    -- WALL decor goes everywhere walkable — corridors especially (2026-07-08
    -- playtest: 48-wide halls with blank long walls read empty; floor CLUTTER
    -- stays room-only so corridors keep a clear run)
    local WALL_DECOR_CLASS = {
        room = true,
        junction = true,
        objective = true,
        entrance = true,
        corridor = true,
    }
    for i, room in ipairs(rooms) do
        if WALL_DECOR_CLASS[room.class] then
            local n = wallMin + math.floor(rng() * (wallMax - wallMin + 1))
            for _ = 1, n do
                for _ = 1, 6 do -- bounded retries per decoration
                    local edge = EDGE_ORDER[1 + math.floor(rng() * 4)]
                    local dir = EDGES[edge]
                    local alongHalf = (dir[1] ~= 0 and room.hz or room.hx) - 8
                    if alongHalf > 4 then
                        local t = (rng() * 2 - 1) * alongHalf
                        local x, z
                        if dir[1] ~= 0 then
                            x = room.x + dir[1] * (room.hx - WALL_INNER)
                            z = room.z + t
                        else
                            x = room.x + t
                            z = room.z + dir[2] * (room.hz - WALL_INNER)
                        end
                        -- reject spots near a doorway on this wall
                        local blocked = false
                        for _, door in ipairs(doors) do
                            if door.a == i or door.b == i then
                                local d = (dir[1] ~= 0)
                                        and (math.abs(door.x - (room.x + dir[1] * room.hx)) < 2 and math.abs(door.z - z) < DOOR_CLEAR)
                                    or (math.abs(door.z - (room.z + dir[2] * room.hz)) < 2 and math.abs(door.x - x) < DOOR_CLEAR)
                                if d then
                                    blocked = true
                                    break
                                end
                            end
                        end
                        if not blocked then
                            table.insert(wallDecor, {
                                room = i,
                                x = x,
                                z = z,
                                ix = -dir[1], -- inward normal (into the room)
                                iz = -dir[2],
                            })
                            break
                        end
                    end
                end
            end
        end
    end

    -- FEATURE spots: one floor showpiece per chamber (chance-gated), centered
    -- on a wall span that has NO doorway — thrones/fountains/gates read as
    -- the room's identity piece, so they get the center of a clean wall and
    -- face the room. Corridors/entrance never get one (walkways stay clear).
    local FEATURE_CLASS = { room = true, junction = true, objective = true }
    local featureChance = opts.feature_chance or 0.5
    local FEATURE_DOOR_CLEAR = 18 -- showpieces are wide; keep well off doorways
    local features = {}
    for i, room in ipairs(rooms) do
        if FEATURE_CLASS[room.class] and rng() < featureChance then
            for _ = 1, 4 do -- bounded retries: find a doorless wall
                local edge = EDGE_ORDER[1 + math.floor(rng() * 4)]
                local dir = EDGES[edge]
                local x, z
                if dir[1] ~= 0 then
                    x = room.x + dir[1] * (room.hx - WALL_INNER)
                    z = room.z
                else
                    x = room.x
                    z = room.z + dir[2] * (room.hz - WALL_INNER)
                end
                local blocked = false
                for _, door in ipairs(doors) do
                    if door.a == i or door.b == i then
                        local d = (dir[1] ~= 0)
                                and (math.abs(door.x - (room.x + dir[1] * room.hx)) < 2 and math.abs(door.z - z) < FEATURE_DOOR_CLEAR)
                            or (math.abs(door.z - (room.z + dir[2] * room.hz)) < 2 and math.abs(door.x - x) < FEATURE_DOOR_CLEAR)
                        if d then
                            blocked = true
                            break
                        end
                    end
                end
                if not blocked then
                    table.insert(features, {
                        room = i,
                        x = x,
                        z = z,
                        ix = -dir[1],
                        iz = -dir[2],
                    })
                    break
                end
            end
        end
    end

    return tints, props, wallDecor, features
end

return MissionDecor
