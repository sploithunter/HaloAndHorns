--[[
    SquadDiversity — pure team-composition bonus (no Roblox APIs; headlessly tested).

    Given the active squad's members (each tagged with an `archetype` and an `origin`) and the
    configs/squad_diversity.lua knobs, returns the team multiplier plus a per-axis breakdown the
    HUD can render ("Archetypes 3/4 → +15%, missing: Support").

    The rule (Jason): bonus scales with DISTINCT categories present — duplicates earn nothing, so a
    second Blaster adds 0 to the archetype axis (opportunity cost, not a penalty). A full-set kicker
    rewards covering every category. The two axis bonuses ADD into one multiplier (1 + arch + origin),
    clamped to max_mult.
]]

local SquadDiversity = {}

local function num(v, d)
    v = tonumber(v)
    if v == nil then
        return d
    end
    return v
end

-- Evaluate one axis (archetype or origin): how many DISTINCT categories the squad covers, the
-- resulting bonus, and which configured categories are still missing (for the HUD nudge).
local function evalAxis(members, key, axisCfg)
    axisCfg = axisCfg or {}
    local cats = axisCfg.categories or {}
    local catSet = {}
    for _, c in ipairs(cats) do
        catSet[c] = true
    end

    local present, distinct = {}, 0
    for _, m in ipairs(members) do
        local v = m and m[key]
        -- Only categories that are CONFIGURED count (an unknown/origin-less tag is ignored, never
        -- a free distinct). Duplicates don't re-count.
        if v ~= nil and v ~= "" and catSet[v] and not present[v] then
            present[v] = true
            distinct = distinct + 1
        end
    end

    local total = #cats
    local bonus = num(axisCfg.per_distinct, 0) * distinct
    local full = total > 0 and distinct >= total
    if full then
        bonus = bonus + num(axisCfg.full_set_bonus, 0)
    end

    local missing = {}
    for _, c in ipairs(cats) do
        if not present[c] then
            missing[#missing + 1] = c
        end
    end

    return {
        distinct = distinct,
        total = total,
        bonus = bonus,
        full = full,
        present = present,
        missing = missing,
    }
end

-- members: array of { archetype = "tank"|..., origin = "lava"|... }. Tags may be nil (origin-less
-- pets simply don't contribute to the origin axis). Returns { mult, archetype = {...}, origin = {...} }.
function SquadDiversity.evaluate(members, config)
    members = members or {}
    config = config or {}

    if config.enabled == false then
        return {
            mult = 1,
            archetype = { distinct = 0, total = 0, bonus = 0, full = false, missing = {} },
            origin = { distinct = 0, total = 0, bonus = 0, full = false, missing = {} },
        }
    end

    local archetype = evalAxis(members, "archetype", config.archetype)
    local origin = evalAxis(members, "origin", config.origin)

    local mult = 1 + archetype.bonus + origin.bonus
    local maxMult = tonumber(config.max_mult)
    if maxMult and mult > maxMult then
        mult = maxMult
    end

    return {
        mult = mult,
        archetype = archetype,
        origin = origin,
    }
end

return SquadDiversity
