--[[
    MissionDecor — seeded per-room dressing rolls (M5a).

    PURE: no Roblox APIs. Consumes LayoutSolver.mapData rooms and the "decor"
    stream; emits per-room TINTS (color jitter factors so no two rooms read
    identical) and PROP placements (crates/barrels/rubble) that avoid the
    room center (MissionSpawn) and the wall band. The service materializes
    props as primitives; same seed = same dressing.

    roll(rooms, streamSeed, opts) →
        tints: { [roomIndex] = { wall = f, floor = f } }   (f ≈ 0.85..1.15)
        props: { { room, kind, x, z, rot }, ... }          (x/z slot-local)
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
    return tints, props
end

return MissionDecor
