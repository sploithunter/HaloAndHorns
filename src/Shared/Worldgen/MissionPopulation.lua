--[[
    MissionPopulation — deterministic static enemy composition for missions.

    PURE: no Roblox APIs. CoH model (docs/MISSION_WORLDGEN.md): a mission's
    enemies are placed ONCE at stamp time — a fixed, seeded population per
    room, no proximity waves, no respawn. The "spawns" phase stream drives the
    rolls, so the same mission seed always fields the same enemies in the
    same rooms (and adding decoration draws can never change the packs).

    roll(packs, pointCount, streamSeed) → { [pointIndex] = { enemyId, ... } }

    `packs` follows the enemies.lua wave shape:
        { { weight = 10, units = { { enemy = "rabid_dog", count = 2 } } }, ... }
    One pack is rolled per spawn point; units expand to a flat enemy list.
]]

local MissionSeed = require(script.Parent.MissionSeed)

local MissionPopulation = {}

function MissionPopulation.roll(packs, pointCount, streamSeed)
    local rng = MissionSeed.mulberry32(streamSeed)
    local total = 0
    for _, pack in ipairs(packs or {}) do
        total += tonumber(pack.weight) or 0
    end

    local out = {}
    for i = 1, pointCount do
        out[i] = {}
        if total > 0 then
            local roll = rng() * total
            local acc, chosen = 0, nil
            for _, pack in ipairs(packs) do
                acc += tonumber(pack.weight) or 0
                if roll < acc then
                    chosen = pack
                    break
                end
            end
            chosen = chosen or packs[#packs]
            for _, unit in ipairs(chosen.units or {}) do
                for _ = 1, unit.count or 1 do
                    table.insert(out[i], unit.enemy)
                end
            end
        end
    end
    return out
end

return MissionPopulation
