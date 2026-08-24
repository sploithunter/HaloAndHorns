--[[
    TutorialPack — combat-training spawn caps.

    Teaching rooms must stay readable at any player level: one healer and a
    small pack of others. Repeat testers must not stack leftover rooms.
]]

local TutorialPack = {}

local function isHealer(unit)
    return type(unit) == "table" and type(unit.auto_heal) == "table"
end

function TutorialPack.clamp(units, cap)
    if type(units) ~= "table" then
        return {}
    end
    cap = type(cap) == "table" and cap or {}
    local maxHealers = math.max(0, math.floor(tonumber(cap.max_healers) or 1))
    local maxOthers = math.max(0, math.floor(tonumber(cap.max_others) or 3))
    local out = {}
    local healers, others = 0, 0
    for _, unit in ipairs(units) do
        if isHealer(unit) then
            if healers < maxHealers then
                out[#out + 1] = unit
                healers += 1
            end
        elseif others < maxOthers then
            out[#out + 1] = unit
            others += 1
        end
    end
    return out
end

-- Models already on the field: keep the first healer and the first N others,
-- return the extras so the caller can despawn them. Repeat testers and admin
-- resets must not stack a leftover pack on the authored one.
function TutorialPack.surplus(models, cap, isHealerFn)
    if type(models) ~= "table" then
        return {}
    end
    cap = type(cap) == "table" and cap or {}
    local maxHealers = math.max(0, math.floor(tonumber(cap.max_healers) or 1))
    local maxOthers = math.max(0, math.floor(tonumber(cap.max_others) or 3))
    local extra = {}
    local healers, others = 0, 0
    for _, model in ipairs(models) do
        local healer = false
        if type(isHealerFn) == "function" then
            healer = isHealerFn(model) == true
        elseif type(model) == "table" then
            healer = isHealer(model)
        end
        if healer then
            healers += 1
            if healers > maxHealers then
                extra[#extra + 1] = model
            end
        else
            others += 1
            if others > maxOthers then
                extra[#extra + 1] = model
            end
        end
    end
    return extra
end

return TutorialPack
