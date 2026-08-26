-- Optional combat partitions for independently commanded squads.
--
-- Ungrouped actors retain the normal global combat behavior. Once either side opts into a group,
-- both sides must publish the same non-empty group value before they may acquire one another.

local CombatTargetGroup = {}

local function normalize(value)
    if type(value) == "string" then
        return value ~= "" and value or nil
    end
    if type(value) == "number" then
        return tostring(value)
    end
    return nil
end

function CombatTargetGroup.compatible(left, right)
    left = normalize(left)
    right = normalize(right)
    if left == nil and right == nil then
        return true
    end
    return left ~= nil and left == right
end

return CombatTargetGroup
