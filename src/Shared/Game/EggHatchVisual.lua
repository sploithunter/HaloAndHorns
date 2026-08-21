--[[
    Hatch animation must clone the egg mesh, not a Hall pedestal that shares
    the EggStand tag / EggId for targeting.
]]

local EggHatchVisual = {}

function EggHatchVisual.select(records)
    if type(records) ~= "table" then
        return nil
    end
    for _, record in ipairs(records) do
        local instance = record and (record.instance or record)
        if instance and instance.Name == "PlacedEgg" then
            return instance
        end
    end
    for _, record in ipairs(records) do
        local instance = record and (record.instance or record)
        if instance and instance.FindFirstChild then
            local placed = instance:FindFirstChild("PlacedEgg")
            if placed then
                return placed
            end
        end
    end
    local first = records[1]
    return first and (first.instance or first) or nil
end

return EggHatchVisual
