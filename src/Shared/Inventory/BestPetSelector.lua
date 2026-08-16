--[[
    BestPetSelector — deterministic role-aware ranking for Inventory "Best Pets" quick fill.

    The UI supplies normalized candidates:
      { role, damage, health, abilities = {{kind, scope, ...}}, key, available }

    Damage roles use their combat damage, tanks use effective HP, and utility roles use an
    explicit ability hierarchy. Utility scope is intentionally the first discriminator: a team/AOE
    effect beats a single-target effect, then the kind priority applies within that scope.

    Pure Lua (headless-testable; no Roblox globals).
]]

local BestPetSelector = {}

local SUPPORT_KIND_PRIORITY = {
    heal = 100,
    drain = 95,
    defense = 90,
    focus = 86,
    recharge = 84,
    haste = 82,
    offense = 80,
    empower = 78,
    luck = 76,
    huge_luck = 74,
    drop_rate = 72,
    yield = 70,
    xp = 68,
    shred = 64,
    curse = 62,
    buff = 60,
    rage = 55,
}

local CONTROL_KIND_PRIORITY = {
    hold = 100, -- full mez: cannot move or attack
    root = 90,
    slow = 80,
    shred = 70,
    curse = 65,
}

local AREA_SCOPE = {
    aura = true,
    aoe = true,
    targeted_aoe = true,
}

local function number(value)
    return tonumber(value) or 0
end

local function effectMagnitude(ability)
    if type(ability) ~= "table" then
        return 0
    end
    if ability.fraction ~= nil then
        return math.abs(number(ability.fraction))
    end
    if ability.amount ~= nil then
        return math.abs(number(ability.amount))
    end
    if ability.mult ~= nil then
        return math.abs(number(ability.mult) - 1)
    end
    if ability.factor ~= nil then
        return math.abs(1 - number(ability.factor))
    end
    return 0
end

local function abilityKey(ability, kindPriority)
    if type(ability) ~= "table" then
        return { 0, 0, 0, 0, 0 }
    end
    local duration = number(ability.duration)
    local interval = number(ability.interval)
    local uptime = interval > 0 and duration / interval or duration
    return {
        AREA_SCOPE[ability.scope] and 2 or 1,
        kindPriority[ability.kind] or 0,
        effectMagnitude(ability),
        duration,
        uptime,
    }
end

local function lexGreater(a, b)
    for index = 1, math.max(#a, #b) do
        local av = a[index] or 0
        local bv = b[index] or 0
        if av ~= bv then
            return av > bv
        end
    end
    return false
end

local function bestAbilityKey(abilities, kindPriority)
    local best = { 0, 0, 0, 0, 0 }
    for _, ability in ipairs(type(abilities) == "table" and abilities or {}) do
        local key = abilityKey(ability, kindPriority)
        if lexGreater(key, best) then
            best = key
        end
    end
    return best
end

local function candidateKey(candidate, role)
    if role == "ranged" or role == "melee" then
        return { number(candidate.damage), number(candidate.health) }
    elseif role == "tank" then
        return { number(candidate.health), number(candidate.damage) }
    elseif role == "support" then
        local key = bestAbilityKey(candidate.abilities, SUPPORT_KIND_PRIORITY)
        key[#key + 1] = number(candidate.damage)
        key[#key + 1] = number(candidate.health)
        return key
    elseif role == "control" then
        local key = bestAbilityKey(candidate.abilities, CONTROL_KIND_PRIORITY)
        key[#key + 1] = number(candidate.damage)
        key[#key + 1] = number(candidate.health)
        return key
    end
    return { number(candidate.damage), number(candidate.health) }
end

function BestPetSelector.isBetter(candidate, incumbent, role)
    if type(candidate) ~= "table" or candidate.available == false or candidate.role ~= role then
        return false
    end
    if type(incumbent) ~= "table" then
        return true
    end

    local candidateScore = candidateKey(candidate, role)
    local incumbentScore = candidateKey(incumbent, role)
    if lexGreater(candidateScore, incumbentScore) then
        return true
    end
    if lexGreater(incumbentScore, candidateScore) then
        return false
    end

    -- Stable final tie-breaker prevents card/load order from changing the selected pet.
    return tostring(candidate.key or candidate.name or "")
        < tostring(incumbent.key or incumbent.name or "")
end

function BestPetSelector.best(candidates, role)
    local best
    for _, candidate in ipairs(type(candidates) == "table" and candidates or {}) do
        if BestPetSelector.isBetter(candidate, best, role) then
            best = candidate
        end
    end
    return best
end

BestPetSelector.SUPPORT_KIND_PRIORITY = SUPPORT_KIND_PRIORITY
BestPetSelector.CONTROL_KIND_PRIORITY = CONTROL_KIND_PRIORITY

return BestPetSelector
