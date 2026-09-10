-- Pure arena composition; the Trials population and scaling implementations stay authoritative.
local PackScale = require(script.Parent.PackScale)
local Rules = {}

function Rules.plan(cfg, missions, level, rawGroupScale, teamSize, seed, Population)
    local choices = {}
    for _, team in ipairs(cfg.teams) do
        if level >= team.min_level and level <= team.max_level then
            table.insert(choices, team)
        end
    end
    if #choices == 0 then
        return nil
    end
    local team = choices[(seed % #choices) + 1]
    local tuning = missions.player_tuning
    local groupScale = PackScale.sanitizeMultiplier(rawGroupScale, tuning.group_scale)
    local teamScale = PackScale.teamMultiplier(teamSize, missions.team_scaling)
    local villain = tuning.boss_budget.villain
    local composition, meta = Population.roll(team.packs, 1, seed, {
        bossPointIndex = 1,
        countMult = groupScale * teamScale,
        extraBossBudget = math.max(0, groupScale - tuning.boss_budget.offset),
        villainChance = groupScale >= villain.at and villain.chance or 0,
        scalesUnit = function(unit)
            return unit.rank ~= "boss" and unit.rank ~= "titan"
        end,
        upgradeUnit = function(unit)
            return unit.rank == "boss" and { pet = unit.pet, rank = "titan", count = 1 } or nil
        end,
    })
    local units = composition[1]
    -- Preserve all boss slots before trimming density to the physical arena budget.
    table.sort(units, function(a, b)
        local aBoss = a.rank == "boss" or a.rank == "titan"
        local bBoss = b.rank == "boss" or b.rank == "titan"
        return aBoss and not bBoss
    end)
    while #units > cfg.max_enemies do
        table.remove(units)
    end
    return {
        units = units,
        team = team,
        groupScale = groupScale,
        teamScale = teamScale,
        meta = meta,
    }
end

function Rules.egg(missions, team, tier)
    if tier ~= "boss" and tier ~= "archvillain" then
        return nil
    end
    local egg = table.clone(missions.missions[team.egg_mission].boss_egg)
    if tier == "archvillain" then
        egg.chance = egg.villain_chance or missions.player_tuning.boss_budget.villain.egg_chance
    end
    return egg
end

function Rules.onramp(cfg, level)
    local c = cfg.onramp
    local t = math.clamp((level - c.min_level) / (c.max_level - c.min_level), 0, 1)
    return c.min_hp_mult + (1 - c.min_hp_mult) * t, c.min_damage_mult + (1 - c.min_damage_mult) * t
end

return Rules
