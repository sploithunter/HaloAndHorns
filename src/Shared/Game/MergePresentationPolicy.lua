local Policy = {}

function Policy.nearest(bays, x, z, previousId, hysteresis)
    local closest, distance, previous, previousDistance
    for _, bay in ipairs(bays) do
        local d = math.sqrt((bay.x - x) ^ 2 + (bay.z - z) ^ 2)
        if not distance or d < distance then
            closest, distance = bay, d
        end
        if bay.id == previousId then
            previous, previousDistance = bay, d
        end
    end
    if previous and previousDistance <= distance + hysteresis then
        return previous
    end
    return closest
end

function Policy.detailed(focus, bay, neighboringColumns)
    -- Missing/streaming metadata must not make a fight disappear.
    if not focus or not bay then
        return true
    end
    return focus.side == bay.side and math.abs(focus.column - bay.column) <= neighboringColumns
end

return Policy
