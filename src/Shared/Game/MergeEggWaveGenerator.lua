--[[
    MergeEggWaveGenerator -- pure post-opening wave generation for Merge Defense.

    Authored waves remain untouched so balance tests can always replay the same opening. Once the
    authored list ends, a short configuration-owned cycle repeats. Later cycles promote existing
    bodies into lieutenants and bosses and apply additive stat multipliers; they never add bodies.
]]

local MergeEggWaveGenerator = {}

local function copy(value)
    if type(value) ~= "table" then
        return value
    end
    local result = {}
    for key, child in pairs(value) do
        result[copy(key)] = copy(child)
    end
    return result
end

local function whole(value, fallback, minimum)
    return math.max(minimum or 0, math.floor(tonumber(value) or fallback or 0))
end

function MergeEggWaveGenerator.count(wave)
    local total = 0
    for _, group in ipairs(type(wave) == "table" and wave.groups or {}) do
        local units = type(group.units) == "table" and group.units or nil
        if units and #units > 0 then
            for _, unit in ipairs(units) do
                total += whole(unit.count, 1, 1)
            end
        else
            total += whole(group.count, 1, 1)
        end
    end
    if total > 0 then
        return total
    end
    return whole(type(wave) == "table" and wave.count, 1, 1)
end

function MergeEggWaveGenerator.waveCount(authoredWaves, config)
    local authoredCount = type(authoredWaves) == "table" and #authoredWaves or 0
    if type(config) ~= "table" or config.enabled ~= true or #(config.cycle or {}) == 0 then
        return authoredCount
    end
    return math.max(authoredCount, whole(config.maximum_wave, authoredCount, authoredCount))
end

function MergeEggWaveGenerator.isGenerated(authoredWaves, config, waveIndex)
    local authoredCount = type(authoredWaves) == "table" and #authoredWaves or 0
    local startWave =
        whole(type(config) == "table" and config.start_wave, authoredCount + 1, authoredCount + 1)
    return type(config) == "table"
        and config.enabled == true
        and #(config.cycle or {}) > 0
        and whole(waveIndex, 0, 0) >= startWave
        and whole(waveIndex, 0, 0) <= MergeEggWaveGenerator.waveCount(authoredWaves, config)
end

local function unitFor(group, archetype)
    for _, unit in ipairs(group.units or {}) do
        if tostring(unit.archetype) == archetype then
            return unit
        end
    end
    local unit = { archetype = archetype, count = 0 }
    group.units = group.units or {}
    group.units[#group.units + 1] = unit
    return unit
end

local function promote(group, fromArchetype, toArchetype, requested, maximum)
    local source = unitFor(group, fromArchetype)
    local destination = unitFor(group, toArchetype)
    local available = whole(source.count, 0, 0)
    local capacity = math.max(0, whole(maximum, available, 0) - whole(destination.count, 0, 0))
    local moved = math.min(available, capacity, whole(requested, 0, 0))
    source.count = available - moved
    destination.count = whole(destination.count, 0, 0) + moved
    return moved
end

local function compactUnits(wave)
    for _, group in ipairs(wave.groups or {}) do
        local compact = {}
        for _, unit in ipairs(group.units or {}) do
            if whole(unit.count, 0, 0) > 0 then
                compact[#compact + 1] = unit
            end
        end
        group.units = compact
    end
end

local function applyPromotions(wave, config, generation)
    local promotion = type(config.promotions) == "table" and config.promotions or {}
    local laterCycles = math.max(0, generation - 1)
    local lieutenantRequested = laterCycles * whole(promotion.lieutenants_per_group_per_cycle, 1, 0)
    local lieutenantMaximum = whole(promotion.maximum_lieutenants_per_group, 4, 0)
    for _, group in ipairs(wave.groups or {}) do
        promote(group, "whelp", "lieutenant", lieutenantRequested, lieutenantMaximum)
    end

    local bossEvery = whole(promotion.boss_every_cycles, 2, 1)
    local bossRequested = math.floor(laterCycles / bossEvery)
    local bossMaximum = whole(promotion.maximum_bosses_per_wave, 2, 0)
    local bossesMoved = 0
    for _, group in ipairs(wave.groups or {}) do
        if bossesMoved >= math.min(bossRequested, bossMaximum) then
            break
        end
        bossesMoved += promote(
            group,
            "brute",
            "boss",
            math.min(bossRequested, bossMaximum) - bossesMoved,
            bossMaximum
        )
    end
    compactUnits(wave)
end

function MergeEggWaveGenerator.wave(authoredWaves, config, waveIndex)
    local index = whole(waveIndex, 0, 0)
    if type(authoredWaves) == "table" and authoredWaves[index] ~= nil then
        return authoredWaves[index]
    end
    if not MergeEggWaveGenerator.isGenerated(authoredWaves, config, index) then
        return nil
    end

    local authoredCount = #authoredWaves
    local startWave = whole(config.start_wave, authoredCount + 1, authoredCount + 1)
    local cycle = config.cycle
    local offset = index - startWave
    local generation = math.floor(offset / #cycle) + 1
    local cyclePosition = (offset % #cycle) + 1
    local wave = copy(cycle[cyclePosition])
    wave.id = string.format("endless_%06d_c%04d_p%02d", index, generation, cyclePosition)
    wave.generated = true
    wave.generation = generation
    wave.cycle_position = cyclePosition
    wave.defender_realm = tostring(wave.defender_realm or config.defender_realm or "heaven")
    wave.attacker_realm = tostring(wave.attacker_realm or config.attacker_realm or "hell")

    applyPromotions(wave, config, generation)
    local scaling = type(config.scaling) == "table" and config.scaling or {}
    local laterCycles = generation - 1
    wave.enemy = {
        hp_multiplier = 1 + laterCycles * math.max(0, tonumber(scaling.hp_per_cycle) or 0),
        damage_multiplier = 1 + laterCycles * math.max(0, tonumber(scaling.damage_per_cycle) or 0),
        reward_multiplier = 1 + laterCycles * math.max(0, tonumber(scaling.reward_per_cycle) or 0),
    }
    return wave
end

return MergeEggWaveGenerator
