--[[
    MissionPopulation — deterministic static enemy composition for missions.

    PURE: no Roblox APIs. CoH model (docs/MISSION_WORLDGEN.md): a mission's
    enemies are placed ONCE at stamp time — a fixed, seeded population per
    room, no proximity waves, no respawn. The "spawns" phase stream drives the
    rolls, so the same mission seed always fields the same enemies in the
    same rooms (and adding decoration draws can never change the packs).

    roll(packs, pointCount, streamSeed, opts) → { [pointIndex] = { enemyId, ... } }

    `packs` follows the enemies.lua wave shape:
        { { weight = 10, units = { { enemy = "rabid_dog", count = 2 } } }, ... }
    One pack is rolled per spawn point; units expand to a flat enemy list.

    GROUP SCALING (opts.countMult ≥ 0, opts.scalesUnit(unit) → bool): unit
    counts multiply AFTER the seeded pack/boss rolls and draw no rng, so the
    player setting and team size preserve trial #N's layout and pack picks.
    Every authored role keeps at least one unit; scalesUnit excludes bosses/
    titans so anchors stay singular. When omitted every unit scales.

    BOSS PLACEMENT (opts.bossOnlyAtObjective): boss-marked packs are excluded
    from every ordinary point. bossPointIndex still guarantees one at the
    objective point. The behavior is configured by missions.population.
]]

local MissionSeed = require(script.Parent.MissionSeed)

local MissionPopulation = {}

function MissionPopulation.roll(packs, pointCount, streamSeed, opts)
    local rng = MissionSeed.mulberry32(streamSeed)
    local total = 0
    local regularTotal = 0
    local regularPacks = {}
    local bossPacks = {}
    for _, pack in ipairs(packs or {}) do
        total += tonumber(pack.weight) or 0
        if pack.boss then
            table.insert(bossPacks, pack)
        else
            regularTotal += tonumber(pack.weight) or 0
            table.insert(regularPacks, pack)
        end
    end
    local bossPoint = opts and opts.bossPointIndex
    local bossOnlyAtObjective = opts and opts.bossOnlyAtObjective == true
    local countMult = math.max(0, (opts and tonumber(opts.countMult)) or 1)
    local scalesUnit = opts and opts.scalesUnit

    local function choosePack(candidates, weightTotal, rollUnit)
        if weightTotal <= 0 then
            return nil
        end
        local roll = rollUnit * weightTotal
        local acc, chosen = 0, nil
        for _, pack in ipairs(candidates) do
            acc += tonumber(pack.weight) or 0
            if roll < acc then
                chosen = pack
                break
            end
        end
        return chosen or candidates[#candidates]
    end

    local out = {}
    for i = 1, pointCount do
        out[i] = {}
        if total > 0 then
            -- Preserve one seeded base draw per point whether boss filtering is enabled or not.
            local rollUnit = rng()
            local chosen
            if bossOnlyAtObjective and i ~= bossPoint then
                chosen = choosePack(regularPacks, regularTotal, rollUnit)
            else
                chosen = choosePack(packs, total, rollUnit)
            end
            -- BOSS GUARDS THE GLOWY: the objective room's point always draws
            -- a boss-marked pack (deterministic pick when several) — random
            -- weights can't produce a boss-less map anymore
            if i == bossPoint and #bossPacks > 0 then
                chosen = bossPacks[1 + math.floor(rng() * #bossPacks)]
            end
            for _, unit in ipairs((chosen and chosen.units) or {}) do
                local n = unit.count or 1
                if countMult ~= 1 and (scalesUnit == nil or scalesUnit(unit)) then
                    -- Keep every authored role represented; callers exclude boss/titan anchors.
                    n = math.max(1, math.floor(n * countMult + 0.5))
                end
                for _ = 1, n do
                    if unit.pet then
                        -- PET-MODEL enemy (Jason: trials field the realm's own
                        -- pets as enemies — huge-scaled for bosses); the
                        -- service synthesizes the def at spawn (rank ladder)
                        table.insert(out[i], { pet = unit.pet, rank = unit.rank })
                    else
                        table.insert(out[i], unit.enemy)
                    end
                end
            end
        end
    end
    return out
end

return MissionPopulation
