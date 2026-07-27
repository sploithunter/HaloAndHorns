--[[
    QuestReward — pure quest-claim XP policy.

    Activities remain the primary XP source. A quest claim adds a moderate completion bump based
    on the player's current level-bar step and the quest's position in its track. Explicit
    `reward.experience` always wins (First Steps uses that to preserve its authored total).
]]

local QuestReward = {}

local function copyBundle(bundle)
    local out = {}
    for key, value in pairs(bundle or {}) do
        out[key] = value
    end
    return out
end

function QuestReward.resolve(bundle, def, policy, xpForNext)
    local out = copyBundle(bundle)
    if
        (tonumber(out.experience) or 0) > 0
        or type(policy) ~= "table"
        or policy.enabled == false
    then
        return out
    end

    local order = math.max(1, math.floor(tonumber(def and def.order) or 1))
    local fraction = (tonumber(policy.base_step_fraction) or 0.08)
        + (order - 1) * (tonumber(policy.per_order_fraction) or 0.02)
    fraction = math.clamp(fraction, 0, math.max(0, tonumber(policy.max_step_fraction) or 0.18))

    local step = math.max(0, tonumber(xpForNext) or 0)
    local raw = step > 0 and step * fraction or (tonumber(policy.fallback_xp) or 100)
    local minimum = math.max(0, tonumber(policy.minimum_xp) or 50)
    local roundTo = math.max(1, math.floor(tonumber(policy.round_to) or 10))
    local xp = math.max(minimum, math.floor(raw / roundTo + 0.5) * roundTo)
    out.experience = xp
    return out
end

return QuestReward
