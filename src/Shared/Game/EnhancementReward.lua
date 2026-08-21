--[[
    EnhancementReward — pure descriptor roll for RewardService enhancement items.

    Durable rewards cannot insert a generic inventory row into the enhancements bucket:
    enhancement identity, origin usability, level banding, discovery, and replication all
    belong to EnhancementService. This helper selects a valid record without Roblox APIs so
    both the service and headless tests use the same single/dual-origin rules.
]]

local EnhancementReward = {}

local function sortedTypeIds(types)
    local ids = {}
    for typeId in pairs(types or {}) do
        table.insert(ids, typeId)
    end
    table.sort(ids)
    return ids
end

local function randomUnit(nextNumber)
    local value = tonumber(nextNumber()) or 0
    return math.clamp(value, 0, 0.999999999)
end

function EnhancementReward.roll(config, playerOrigin, playerLevel, grade, nextNumber)
    config = config or {}
    nextNumber = nextNumber or math.random
    if type(playerOrigin) ~= "string" or playerOrigin == "" then
        return nil, "no_origin"
    end
    if grade ~= "single" and grade ~= "dual" then
        return nil, "invalid_grade"
    end

    local knownOrigin = false
    local alternateOrigins = {}
    for _, origin in ipairs(config.origins or {}) do
        if origin == playerOrigin then
            knownOrigin = true
        else
            table.insert(alternateOrigins, origin)
        end
    end
    if not knownOrigin then
        return nil, "unknown_origin"
    end
    if grade == "dual" and #alternateOrigins == 0 then
        return nil, "no_dual_origin"
    end

    local typeIds = sortedTypeIds(config.types)
    if #typeIds == 0 then
        return nil, "no_enhancement_types"
    end
    local weights = (config.drops or {}).type_weights or {}
    local totalWeight = 0
    for _, typeId in ipairs(typeIds) do
        totalWeight += math.max(0, tonumber(weights[typeId]) or 1)
    end
    if totalWeight <= 0 then
        return nil, "no_enhancement_weight"
    end

    local cursor = randomUnit(nextNumber) * totalWeight
    local pickedType = typeIds[#typeIds]
    for _, typeId in ipairs(typeIds) do
        cursor -= math.max(0, tonumber(weights[typeId]) or 1)
        if cursor < 0 then
            pickedType = typeId
            break
        end
    end

    local levels = (config.drops or {}).levels or {}
    local level = math.clamp(
        math.floor(tonumber(playerLevel) or 1),
        tonumber(levels.min) or 1,
        tonumber(levels.max) or 55
    )
    local origins = { playerOrigin }
    if grade == "dual" then
        local index = math.floor(randomUnit(nextNumber) * #alternateOrigins) + 1
        table.insert(origins, alternateOrigins[index])
    end

    return {
        type = pickedType,
        origins = origins,
        level = level,
    }
end

return EnhancementReward
