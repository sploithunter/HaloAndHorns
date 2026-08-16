--[[
    PetAbilityRuntime

    Resolves the legacy `pets.lua` variant ability lists into gameplay-ready
    active and passive effects. The config is intentionally data-only; this
    module is the single interpretation layer used by server combat, rewards,
    hatching, drops, movement, and survival.

    An ability with `cooldown` is an active proc that can fire on a real pet
    swing. Abilities without a cooldown are passive. Boolean fields whose name
    references another configured ability (for example `time_warp = true`) also
    inherit that referenced ability's passive traits.
]]

local PetAbilityRuntime = {}

local ACTIVE_FIELDS = {
    damage_multiplier = true,
    crit_chance = true,
    stun_duration = true,
    area_damage = true,
    damage_over_time = true,
    armor_ignore = true,
    teleport_to_enemies = true,
}

local PASSIVE_FIELDS = {
    all_bonus = true,
    luck_boost = true,
    coin_bonus = true,
    speed_boost = true,
    coin_attraction_range = true,
    rare_drop_pull = true,
    movement_speed = true,
    damage_to_owner_enemies = true,
    rare_drop_chance = true,
    dodge_chance = true,
    party_luck_boost = true,
    attack_speed_multiplier = true,
    cooldown_reduction = true,
    nearby_pet_damage = true,
    never_abandons_owner = true,
    can_fly = true,
    phase_through_walls = true,
    revive_on_death = true,
    max_revives = true,
    teleport_to_enemies = true,
}

local MULTIPLIER_FIELDS = {
    all_bonus = true,
    coin_bonus = true,
    speed_boost = true,
    movement_speed = true,
    damage_to_owner_enemies = true,
    party_luck_boost = true,
    attack_speed_multiplier = true,
    nearby_pet_damage = true,
}

local MAX_FIELDS = {
    luck_boost = true,
    coin_attraction_range = true,
    rare_drop_chance = true,
    dodge_chance = true,
    cooldown_reduction = true,
    max_revives = true,
}

local function mergeField(target, key, value)
    if type(value) == "boolean" then
        target[key] = target[key] == true or value == true
    elseif type(value) == "number" then
        if MULTIPLIER_FIELDS[key] then
            target[key] = (tonumber(target[key]) or 1) * value
        elseif MAX_FIELDS[key] then
            target[key] = math.max(tonumber(target[key]) or 0, value)
        else
            target[key] = (tonumber(target[key]) or 0) + value
        end
    end
end

local function mergeSelected(target, effect, fields)
    for key, value in pairs(effect or {}) do
        if fields[key] then
            mergeField(target, key, value)
        end
    end
end

local function expandReferencedPassives(config, effect, passive, seen)
    local definitions = config.abilities or {}
    for key, value in pairs(effect or {}) do
        if value == true and definitions[key] and not seen[key] then
            seen[key] = true
            local nested = definitions[key]
            mergeSelected(passive, nested, PASSIVE_FIELDS)
            expandReferencedPassives(config, nested, passive, seen)
        end
    end
end

function PetAbilityRuntime.resolve(config, petType, variant)
    config = type(config) == "table" and config or {}
    local pet = config.pets and config.pets[petType]
    local variantDef = pet
        and pet.variants
        and (pet.variants[variant or "basic"] or pet.variants.basic)
    local ids = (variantDef and variantDef.abilities) or {}
    local profile = {
        ids = {},
        active = {},
        passive = {},
    }

    for _, abilityId in ipairs(ids) do
        local effect = config.abilities and config.abilities[abilityId]
        if type(effect) == "table" then
            table.insert(profile.ids, abilityId)
            mergeSelected(profile.passive, effect, PASSIVE_FIELDS)
            expandReferencedPassives(config, effect, profile.passive, { [abilityId] = true })

            if tonumber(effect.cooldown) then
                local active = {
                    id = abilityId,
                    cooldown = math.max(0.05, tonumber(effect.cooldown) or 1),
                }
                mergeSelected(active, effect, ACTIVE_FIELDS)
                -- Referenced traits such as reality_burn and shadow_step contribute
                -- their active on-hit behavior to the parent proc.
                for key, value in pairs(effect) do
                    local nested = value == true and config.abilities and config.abilities[key]
                    if type(nested) == "table" then
                        mergeSelected(active, nested, ACTIVE_FIELDS)
                    end
                end
                table.insert(profile.active, active)
            end
        end
    end

    return profile
end

function PetAbilityRuntime.hasAreaDamage(config, petType, variant)
    local profile = PetAbilityRuntime.resolve(config, petType, variant)
    for _, active in ipairs(profile.active or {}) do
        if active.area_damage == true then
            return true
        end
    end
    return false
end

-- Activates every ready proc (variants currently author at most one damage proc,
-- but this remains deterministic if a future variant combines several).
function PetAbilityRuntime.activate(profile, nextReady, now)
    profile = type(profile) == "table" and profile or {}
    nextReady = type(nextReady) == "table" and nextReady or {}
    now = tonumber(now) or 0
    local proc = {
        ids = {},
        damage_multiplier = 1,
        crit_chance = 0,
        stun_duration = 0,
        armor_ignore = 0,
    }
    local fired = false
    local reduction =
        math.clamp(tonumber(profile.passive and profile.passive.cooldown_reduction) or 0, 0, 0.9)

    for _, active in ipairs(profile.active or {}) do
        if now >= (tonumber(nextReady[active.id]) or 0) then
            fired = true
            table.insert(proc.ids, active.id)
            proc.damage_multiplier *= tonumber(active.damage_multiplier) or 1
            proc.crit_chance += tonumber(active.crit_chance) or 0
            proc.stun_duration = math.max(proc.stun_duration, tonumber(active.stun_duration) or 0)
            proc.armor_ignore = math.max(proc.armor_ignore, tonumber(active.armor_ignore) or 0)
            proc.area_damage = proc.area_damage == true or active.area_damage == true
            proc.damage_over_time = proc.damage_over_time == true or active.damage_over_time == true
            proc.teleport_to_enemies = proc.teleport_to_enemies == true
                or active.teleport_to_enemies == true
            nextReady[active.id] = now + active.cooldown * (1 - reduction)
        end
    end

    return fired and proc or nil, nextReady
end

function PetAbilityRuntime.supportedFields()
    local supported = { cooldown = true }
    for key in pairs(ACTIVE_FIELDS) do
        supported[key] = true
    end
    for key in pairs(PASSIVE_FIELDS) do
        supported[key] = true
    end
    return supported
end

return PetAbilityRuntime
