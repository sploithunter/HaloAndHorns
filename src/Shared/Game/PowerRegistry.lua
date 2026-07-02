--[[
    PowerRegistry (pure) — the unified Power read-model.
    See docs/PET_REALM_POWER_DATA_MODEL.md.

    Strangler step P1: rather than rewrite the authoritative power data, this COMPOSES the unified
    `Power` record (identity / base stats / visuals / dispatch) from the existing config tables
    (`powers` + `effect_kinds`) on read. The raw data stays byte-identical, so behaviour is unchanged;
    consumers (PowerStats, the effect router, the tooltip, the badge) migrate to reading this record
    one at a time. The full original `effect_kind` rides along as `record.params` so nothing exotic
    (ramp_to, spread_radius, frozen_bonus, hot, guardian…) is lost while consumers move over.

    Pure: takes the powers config table as an argument; no Roblox APIs, no requires.

        PowerRegistry.record(id, cfg)  -> unified record (or nil if unknown)
        PowerRegistry.all(cfg)         -> { [id] = record }
]]

local PowerRegistry = {}

-- family (the mechanics dispatch) -> primary descriptive category tag for kind[]. Best-effort; the
-- authoritative ring/symbol still come from power_icons until P6 unifies them.
local FAMILY_CATEGORY = {
    heal = "heal",
    buff = "buff",
    damage_buff = "buff",
    vulnerable = "debuff",
    root = "hold",
    root_guard = "hold",
    absorb = "shield",
    team_shield = "shield",
    shield = "shield",
    armor = "buff",
    fortify = "buff",
    defense_buff = "buff",
    burn_spread = "dot",
    amplified_burst = "damage",
    team_cleave = "damage",
    summon = "summon",
    move_speed = "travel",
    recharge = "utility",
    recall = "travel",
    world_travel = "travel",
    magnet = "utility",
    coin_yield = "yield",
    windfall = "yield",
    luck = "luck",
    luck_huge = "luck",
    xp_boost = "xp",
    revive = "utility",
    sunder = "debuff",
    disarm = "debuff",
    expose = "debuff",
    cripple = "debuff",
    focus_fire = "debuff",
    strike = "damage",
    mining_boost = "yield",
}

-- Enemy effects that hit a SINGLE target (no area). Everything else enemy-facing reads as AoE. Used
-- only to label kind[] (target vs aoe); for accuracy purposes both count as hostile.
local SINGLE_TARGET_ENEMY = {
    strike = true,
    disarm = true,
    expose = true,
    cripple = true,
    sunder = true,
    focus_fire = true,
}

local function titleize(id)
    local out = {}
    for word in tostring(id):gmatch("[^_]+") do
        out[#out + 1] = word:sub(1, 1):upper() .. word:sub(2)
    end
    return table.concat(out, " ")
end

-- kind[] = { <targeting>, <category>[, "dot"] }. Targeting: ally/team/self for friendly, target/aoe
-- for hostile (from the enemy_targeted_families set). category from FAMILY_CATEGORY.
local function deriveKind(power, ek, enemyFamilies)
    local family = ek.family
    local kind = {}

    if enemyFamilies[family] then
        kind[#kind + 1] = (SINGLE_TARGET_ENEMY[power.effect] and "target") or "aoe"
    elseif power.target == "single_pet" then
        kind[#kind + 1] = "ally"
    elseif
        family == "heal"
        or family == "buff"
        or family == "damage_buff"
        or family == "absorb"
        or family == "team_shield"
        or family == "armor"
        or family == "fortify"
        or family == "defense_buff"
        or family == "summon"
    then
        kind[#kind + 1] = "team"
    else
        kind[#kind + 1] = "self" -- move_speed/recharge/recall/magnet/luck/yield/xp/world_travel/revive
    end

    local category = FAMILY_CATEGORY[power.effect] or FAMILY_CATEGORY[family]
    if category then
        kind[#kind + 1] = category
    end
    if ek.dot and category ~= "dot" then
        kind[#kind + 1] = "dot"
    end
    return kind
end

function PowerRegistry.record(id, cfg)
    cfg = cfg or {}
    local power = cfg.powers and cfg.powers[id]
    if not power then
        return nil
    end
    local ek = (cfg.effect_kinds and cfg.effect_kinds[power.effect]) or {}
    local enemyFamilies = cfg.enemy_targeted_families or {}
    local dot = ek.dot

    return {
        -- identity / registry
        id = id,
        name = power.display_name or titleize(id),
        origin = power.generic and {} or { power.archetype },
        kind = deriveKind(power, ek, enemyFamilies),
        effect = ek.family, -- the mechanics dispatch key (_applyEffect branch)
        target = power.target, -- e.g. "single_pet"
        generic = power.generic == true,

        -- base stats (pre-scaling)
        costBase = power.focus_cost,
        rechargeBase = power.cooldown_seconds,
        durationBase = ek.duration,
        magnitudeBase = ek.magnitude,
        damageBase = dot and dot.per_tick or nil,
        tickBase = dot and dot.interval or nil,
        radiusBase = ek.radius,
        -- per-power override, else the family default (debuff/control land <1 so they can miss +
        -- an accuracy enhancement has room), else always-hit.
        accuracyBase = power.accuracy_base or (cfg.accuracy_family_base or {})[ek.family] or 1,
        critBase = power.crit_base or 0,

        -- mechanics passthrough — the raw effect_kind, so the router loses nothing during migration
        dot = dot,
        params = ek,

        -- reference back to the legacy effect-kind key
        effectKey = power.effect,
    }
end

function PowerRegistry.all(cfg)
    local out = {}
    if cfg and cfg.powers then
        for id in pairs(cfg.powers) do
            out[id] = PowerRegistry.record(id, cfg)
        end
    end
    return out
end

return PowerRegistry
