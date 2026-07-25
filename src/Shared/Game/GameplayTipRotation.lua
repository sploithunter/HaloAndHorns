--[[
    GameplayTipRotation — pure helpers for the quest-tracker tip carousel.

    Runtime timing and rendering stay client-owned. This module keeps selection and config
    validation headless-testable so the compact UI cannot silently receive unusable copy.
]]

local GameplayTipRotation = {}

function GameplayTipRotation.nextIndex(currentIndex, tipCount)
    tipCount = math.max(0, math.floor(tonumber(tipCount) or 0))
    if tipCount == 0 then
        return nil
    end
    currentIndex = math.floor(tonumber(currentIndex) or 0)
    return (currentIndex % tipCount) + 1
end

-- Fisher-Yates shuffled deck. `nextInteger(min, max)` is injected so the permutation stays
-- deterministic in headless tests while the client supplies a session-local Random instance.
function GameplayTipRotation.shuffledIndices(tipCount, nextInteger)
    tipCount = math.max(0, math.floor(tonumber(tipCount) or 0))
    local order = {}
    for index = 1, tipCount do
        order[index] = index
    end

    nextInteger = nextInteger or math.random
    for index = tipCount, 2, -1 do
        local swapIndex = math.clamp(math.floor(tonumber(nextInteger(1, index)) or index), 1, index)
        order[index], order[swapIndex] = order[swapIndex], order[index]
    end
    return order
end

function GameplayTipRotation.validate(config)
    if type(config) ~= "table" then
        return false, "config must be a table"
    end

    local interval = tonumber(config.interval_seconds)
    local display = tonumber(config.display_seconds)
    local maxCharacters = math.floor(tonumber(config.max_characters) or 0)
    if not interval or interval <= 0 then
        return false, "interval_seconds must be positive"
    end
    if not display or display <= 0 or display >= interval then
        return false, "display_seconds must be positive and shorter than interval_seconds"
    end
    if maxCharacters <= 0 then
        return false, "max_characters must be positive"
    end
    if type(config.tips) ~= "table" or #config.tips == 0 then
        return false, "tips must be a non-empty array"
    end

    local seen = {}
    for index, tip in ipairs(config.tips) do
        if type(tip) ~= "string" or tip == "" then
            return false, ("tip %d must be a non-empty string"):format(index)
        end
        if #tip > maxCharacters then
            return false, ("tip %d exceeds max_characters"):format(index)
        end
        if seen[tip] then
            return false, ("tip %d duplicates an earlier tip"):format(index)
        end
        seen[tip] = true
    end

    return true
end

return GameplayTipRotation
