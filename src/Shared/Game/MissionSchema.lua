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

    validate(missionsCfg, deps) -> ok, err
      deps = { enemies = <enemies cfg>, pets = <pets cfg>,
               stats = <stats cfg>, areas = <areas cfg> }
    Consumers: ConfigLoader._validateMissionsConfig (boot) + CI spec.
]]

local MissionSchema = {}

local SEED_POLICIES = { team_stable = true, per_attempt = true, shared_sequence = true }

function MissionSchema.validate(cfg, deps)
    deps = deps or {}
    local enemies = (deps.enemies and deps.enemies.enemies) or {}
    local pets = (deps.pets and deps.pets.pets) or {}
    local counters = (deps.stats and deps.stats.counters) or {}
    local zones = (deps.areas and deps.areas.zones) or {}
    local ranks = cfg.pet_ranks or {}

    for missionId, def in pairs(cfg.missions or {}) do
        local path = "missions." .. tostring(missionId)
        if def.seed_policy ~= nil and not SEED_POLICIES[def.seed_policy] then
            return false,
                path .. ".seed_policy: unknown policy '" .. tostring(def.seed_policy) .. "'"
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
        if def.boss_egg ~= nil then
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
        for pi, pack in ipairs(def.packs or {}) do
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
