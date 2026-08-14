-- ConsoleHotbar — pure wraparound selection for bound hotbar slots.

local ConsoleHotbar = {}

function ConsoleHotbar.boundSlots(hotbar, slotCount)
    local result = {}
    slotCount = tonumber(slotCount) or 20
    for slot = 1, slotCount do
        if type(hotbar) == "table" and hotbar[slot] ~= nil then
            result[#result + 1] = slot
        end
    end
    return result
end

function ConsoleHotbar.step(hotbar, current, direction, slotCount)
    local slots = ConsoleHotbar.boundSlots(hotbar, slotCount)
    if #slots == 0 then
        return nil
    end
    local index = nil
    for i, slot in ipairs(slots) do
        if slot == current then
            index = i
            break
        end
    end
    if index == nil then
        return tonumber(direction) and direction < 0 and slots[#slots] or slots[1]
    end
    if tonumber(direction) and direction < 0 then
        index = ((index - 2) % #slots) + 1
    else
        index = (index % #slots) + 1
    end
    return slots[index]
end

return ConsoleHotbar
