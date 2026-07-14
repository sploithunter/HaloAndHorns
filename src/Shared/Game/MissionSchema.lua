--[[
    MissionSchema — mission config CROSS-validation, pure (no Roblox APIs).

    Jason (2026-07-09): "catch them rather than defaulting and letting them
    pull through — it makes a soft bug that's hard to track." The soft bugs
    this kills at CONFIG LOAD (and in CI via config_validation.spec):
      - a packs unit naming an enemy/pet id that doesn't exist (was: spawn
        silently skipped → the mission is mysteriously under-populated)
      - a unit rank missing from missions.pet_ranks (was: minion fallback)
      - mission.area without its mission_<area> pseudo-zone (was: branding
        silently absent — neutral drops, no biome RPS)
      - a mission id without its <id>s_completed stats counter (was: the
        per-trial achievement counter silently never ticks)
      - random.pool naming a mission that doesn't exist
      - an unknown seed_policy (was: silently treated as per_attempt)
      - missing or invalid player Trial group-size bounds
      - missing or invalid generated-room movement inset
      - missing boss-only objective population policy
      - invalid pet-rank level curves

    validate(missionsCfg, deps) -> ok, err
      deps = { enemies = <enemies cfg>, pets = <pets cfg>,
               stats = <stats cfg>, areas = <areas cfg> }
    Consumers: ConfigLoader._validateMissionsConfig (boot) + CI spec.
]]

local MissionSchema = {}

local SEED_POLICIES = { team_stable = true, per_attempt = true, shared_sequence = true }
local AGGRESSION_POLICIES = { realm = true, universal = true }
local OBJECTIVE_KINDS = { reach_beacon = true, clear_then_beacon = true, defeat_named = true }

function MissionSchema.validate(cfg, deps)
    deps = deps or {}
    local enemies = (deps.enemies and deps.enemies.enemies) or {}
    local pets = (deps.pets and deps.pets.pets) or {}
    local counters = (deps.stats and deps.stats.counters) or {}
    local zones = (deps.areas and deps.areas.zones) or {}
    local ranks = cfg.pet_ranks or {}

    local playerTuning = cfg.player_tuning
    if type(playerTuning) ~= "table" then
        return false, "player_tuning: expected table"
    end
    local groupScale = playerTuning.group_scale
    if type(groupScale) ~= "table" then
        return false, "player_tuning.group_scale: expected table"
    end
    for _, key in ipairs({ "min", "max", "default", "step" }) do
        if type(groupScale[key]) ~= "number" then
            return false, "player_tuning.group_scale." .. key .. ": expected number"
        end
    end
    if groupScale.min <= 0 or groupScale.max < groupScale.min then
        return false, "player_tuning.group_scale: expected 0 < min <= max"
    end
    if groupScale.default < groupScale.min or groupScale.default > groupScale.max then
        return false, "player_tuning.group_scale.default: expected value within min/max"
    end
    if groupScale.step <= 0 or groupScale.step > (groupScale.max - groupScale.min) then
        return false, "player_tuning.group_scale.step: expected positive value within range"
    end
    -- boss ladder (slider top half buys extra bosses; villain roll at max)
    local bossBudget = playerTuning.boss_budget
    if bossBudget ~= nil then
        if type(bossBudget) ~= "table" then
            return false, "player_tuning.boss_budget: expected table"
        end
        if type(bossBudget.offset) ~= "number" or bossBudget.offset < 0 then
            return false, "player_tuning.boss_budget.offset: expected non-negative number"
        end
        local villain = bossBudget.villain
        if villain ~= nil then
            if type(villain) ~= "table" then
                return false, "player_tuning.boss_budget.villain: expected table"
            end
            if type(villain.at) ~= "number" then
                return false, "player_tuning.boss_budget.villain.at: expected number"
            end
            for _, key in ipairs({ "chance", "egg_chance" }) do
                local v = villain[key]
                if type(v) ~= "number" or v < 0 or v > 1 then
                    return false,
                        "player_tuning.boss_budget.villain." .. key .. ": expected number in [0,1]"
                end
            end
        end
    end

    if cfg.combat ~= nil and type(cfg.combat) ~= "table" then
        return false, "combat: expected table"
    end
    local defaultAggression = cfg.combat and cfg.combat.default_aggression_policy
    if defaultAggression ~= nil and not AGGRESSION_POLICIES[defaultAggression] then
        return false,
            "combat.default_aggression_policy: unknown policy '"
                .. tostring(defaultAggression)
                .. "'"
    end

    if type(cfg.navigation) ~= "table" then
        return false, "navigation: expected table"
    end
    if type(cfg.navigation.room_inset) ~= "number" or cfg.navigation.room_inset < 0 then
        return false, "navigation.room_inset: expected non-negative number"
    end

    if type(cfg.population) ~= "table" then
        return false, "population: expected table"
    end
    if type(cfg.population.boss_only_at_objective) ~= "boolean" then
        return false, "population.boss_only_at_objective: expected boolean"
    end

    for rankId, rank in pairs(ranks) do
        if type(rank) ~= "table" then
            return false, "pet_ranks." .. tostring(rankId) .. ": expected table"
        end
        local scaling = rank.level_scaling
        if scaling ~= nil then
            local path = "pet_ranks." .. tostring(rankId) .. ".level_scaling"
            if type(scaling) ~= "table" then
                return false, path .. ": expected table"
            end
            if type(scaling.min_level) ~= "number" or scaling.min_level < 1 then
                return false, path .. ".min_level: expected positive number"
            end
            if type(scaling.max_level) ~= "number" or scaling.max_level <= scaling.min_level then
                return false, path .. ".max_level: expected number greater than min_level"
            end
            if scaling.curve ~= "linear" then
                return false, path .. ".curve: expected 'linear'"
            end
            if type(scaling.at_min) ~= "table" then
                return false, path .. ".at_min: expected table"
            end
            local foundField = false
            for _, field in ipairs({ "hp_mult", "dmg_mult", "armor" }) do
                local low = scaling.at_min[field]
                if low ~= nil then
                    foundField = true
                    if type(low) ~= "number" or low < 0 or type(rank[field]) ~= "number" then
                        return false, path .. ".at_min." .. field .. ": invalid rank endpoint"
                    end
                end
            end
            local abilityMult = scaling.at_min.ability_damage_mult
            if abilityMult ~= nil then
                foundField = true
                if type(abilityMult) ~= "number" or abilityMult < 0 then
                    return false,
                        path .. ".at_min.ability_damage_mult: expected non-negative number"
                end
            end
            if not foundField then
                return false, path .. ".at_min: expected at least one scaling field"
            end
        end
    end

    for missionId, def in pairs(cfg.missions or {}) do
        local path = "missions." .. tostring(missionId)
        if def.seed_policy ~= nil and not SEED_POLICIES[def.seed_policy] then
            return false,
                path .. ".seed_policy: unknown policy '" .. tostring(def.seed_policy) .. "'"
        end
        -- realm drives decor-pool allegiance + resonance; neutral = element
        -- trials whose pet-choice axis is the biome RPS (decor falls back to
        -- the element alias)
        if
            def.realm ~= nil
            and def.realm ~= "heaven"
            and def.realm ~= "hell"
            and def.realm ~= "neutral"
        then
            return false, path .. ".realm: expected 'heaven', 'hell', or 'neutral'"
        end
        if def.aggression_policy ~= nil and not AGGRESSION_POLICIES[def.aggression_policy] then
            return false,
                path
                    .. ".aggression_policy: unknown policy '"
                    .. tostring(def.aggression_policy)
                    .. "'"
        end
        if def.area ~= nil then
            local zoneKey = "mission_" .. tostring(def.area)
            if zones[zoneKey] == nil then
                return false,
                    path
                        .. ".area: no zones entry '"
                        .. zoneKey
                        .. "' (branding contract: biome RPS + origin drops need the pseudo-zone)"
            end
        end
        if def.objective ~= nil then
            if type(def.objective) ~= "table" or not OBJECTIVE_KINDS[def.objective.kind] then
                return false,
                    path .. ".objective.kind: unknown kind '" .. tostring(
                        type(def.objective) == "table" and def.objective.kind
                    ) .. "'"
            end
            -- defeat_named needs its display name (HUD says "Defeat <name>!")
            if def.objective.kind == "defeat_named" and type(def.objective.name) ~= "string" then
                return false, path .. ".objective.name: defeat_named requires a name string"
            end
        end
        -- villain_unit (the 200% static upgrade) must be a real arch-villain
        if def.villain_unit ~= nil then
            local vdef = enemies[def.villain_unit]
            if vdef == nil then
                return false,
                    path .. ".villain_unit: unknown enemy id '" .. tostring(def.villain_unit) .. "'"
            end
            if vdef.tier ~= "archvillain" then
                return false,
                    path
                        .. ".villain_unit: '"
                        .. tostring(def.villain_unit)
                        .. "' is not tier 'archvillain' (the villain roll upgrades a boss UP)"
            end
        end
        if def.boss_egg ~= nil then
            local villainChance = def.boss_egg.villain_chance
            if
                villainChance ~= nil
                and (type(villainChance) ~= "number" or villainChance < 0 or villainChance > 1)
            then
                return false, path .. ".boss_egg.villain_chance: expected number in [0,1]"
            end
            local eggs = (deps.pets and deps.pets.egg_sources) or {}
            local eggDef = eggs[def.boss_egg.egg]
            if eggDef == nil then
                return false,
                    path .. ".boss_egg.egg: unknown egg '" .. tostring(def.boss_egg.egg) .. "'"
            end
            if eggDef.fixed_odds ~= true then
                return false,
                    path
                        .. ".boss_egg.egg: '"
                        .. tostring(def.boss_egg.egg)
                        .. "' is not fixed_odds (inventory eggs must state exact odds)"
            end
        end
        if counters[missionId .. "s_completed"] == nil then
            return false,
                path
                    .. ": stats counter '"
                    .. missionId
                    .. "s_completed' not declared (per-trial achievements would silently never tick)"
        end
        local hasRegularPack = false
        for pi, pack in ipairs(def.packs or {}) do
            if not pack.boss and (tonumber(pack.weight) or 0) > 0 then
                hasRegularPack = true
            end
            for ui, unit in ipairs(pack.units or {}) do
                local upath = path .. ".packs[" .. pi .. "].units[" .. ui .. "]"
                if unit.enemy ~= nil and enemies[unit.enemy] == nil then
                    return false,
                        upath .. ".enemy: unknown enemy id '" .. tostring(unit.enemy) .. "'"
                end
                if unit.pet ~= nil and pets[unit.pet] == nil then
                    return false, upath .. ".pet: unknown pet id '" .. tostring(unit.pet) .. "'"
                end
                if unit.enemy == nil and unit.pet == nil then
                    return false, upath .. ": needs enemy or pet"
                end
                if unit.rank ~= nil and ranks[unit.rank] == nil then
                    return false,
                        upath
                            .. ".rank: unknown rank '"
                            .. tostring(unit.rank)
                            .. "' (missions.pet_ranks)"
                end
            end
        end
        if cfg.population.boss_only_at_objective and not hasRegularPack then
            return false, path .. ".packs: boss-only objective policy needs a weighted regular pack"
        end
    end

    -- quest MISSION BINDINGS (deps.quests): a quest def naming a mission
    -- that doesn't exist would silently break quest-aware gates
    if deps.quests then
        local eggs = (deps.pets and deps.pets.egg_sources) or {}
        for questId, qdef in pairs(deps.quests.defs or {}) do
            if qdef.mission ~= nil and (cfg.missions or {})[qdef.mission] == nil then
                return false,
                    "quests.defs."
                        .. tostring(questId)
                        .. ".mission: unknown mission '"
                        .. tostring(qdef.mission)
                        .. "'"
            end
            -- egg-bucket rewards must reference real fixed-odds eggs (the
            -- Platinum grant path — a typo would silently grant a dead item)
            local items = qdef.reward and qdef.reward.items
            for _, item in ipairs(items or {}) do
                if item.bucket == "eggs" then
                    local eggDef = eggs[item.id]
                    if eggDef == nil then
                        return false,
                            "quests.defs."
                                .. tostring(questId)
                                .. ".reward: unknown egg '"
                                .. tostring(item.id)
                                .. "'"
                    end
                    if eggDef.fixed_odds ~= true then
                        return false,
                            "quests.defs." .. tostring(questId) .. ".reward: egg '" .. tostring(
                                item.id
                            ) .. "' is not fixed_odds"
                    end
                end
            end
        end
    end

    local rnd = cfg.random
    if rnd and rnd.pool then
        for _, id in ipairs(rnd.pool) do
            if (cfg.missions or {})[id] == nil then
                return false, "random.pool: unknown mission '" .. tostring(id) .. "'"
            end
        end
    end
    -- realm-affine gate pools: sides must be heaven/hell, missions must exist
    if rnd and rnd.realm_pools then
        for side, pool in pairs(rnd.realm_pools) do
            if side ~= "heaven" and side ~= "hell" then
                return false, "random.realm_pools: unknown side '" .. tostring(side) .. "'"
            end
            for _, id in ipairs(pool) do
                if (cfg.missions or {})[id] == nil then
                    return false,
                        "random.realm_pools."
                            .. side
                            .. ": unknown mission '"
                            .. tostring(id)
                            .. "'"
                end
            end
        end
    end

    return true
end

return MissionSchema
