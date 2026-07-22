--[[
    RecallTarget — pure durable-target rules for the Natural Recall power.

    The profile stores the egg SOURCE id, never a world position. At cast time the server resolves
    that id against the live EggStand registry, so moved eggs remain valid and removed event eggs
    fail closed.
]]

local RecallTarget = {}

local PROFILE_KEY = "LastHatchedEggId"
local OFFSET_KEY = "LastHatchedEggOffset"
local OFFSET_STEP = 0.25

local function validEggId(value)
    return type(value) == "string" and value ~= ""
end

local function roundOffset(value)
    local scaled = value / OFFSET_STEP
    if scaled >= 0 then
        return math.floor(scaled + 0.5) * OFFSET_STEP
    end
    return math.ceil(scaled - 0.5) * OFFSET_STEP
end

local function normalizeOffset(offset)
    if type(offset) ~= "table" then
        return nil
    end
    local x, y, z = tonumber(offset.x), tonumber(offset.y), tonumber(offset.z)
    if not (x and y and z) then
        return nil
    end
    return {
        x = roundOffset(x),
        y = roundOffset(y),
        z = roundOffset(z),
    }
end

local function sameOffset(a, b)
    return type(a) == "table" and type(b) == "table" and a.x == b.x and a.y == b.y and a.z == b.z
end

function RecallTarget.record(data, eggId, localOffset)
    if type(data) ~= "table" or not validEggId(eggId) then
        return { ok = false, reason = "invalid_recall_egg" }
    end

    data.GameData = type(data.GameData) == "table" and data.GameData or {}
    local offset = normalizeOffset(localOffset)
    local changed = data.GameData[PROFILE_KEY] ~= eggId
        or (offset ~= nil and not sameOffset(data.GameData[OFFSET_KEY], offset))
    data.GameData[PROFILE_KEY] = eggId
    if offset then
        data.GameData[OFFSET_KEY] = offset
    elseif changed then
        -- Never carry an offset from a different egg onto this one.
        data.GameData[OFFSET_KEY] = {}
    end
    return { ok = true, eggId = eggId, changed = changed }
end

function RecallTarget.savedEggId(data)
    local gameData = type(data) == "table" and data.GameData or nil
    local eggId = type(gameData) == "table" and gameData[PROFILE_KEY] or nil
    return validEggId(eggId) and eggId or nil
end

function RecallTarget.savedOffset(data)
    local gameData = type(data) == "table" and data.GameData or nil
    return type(gameData) == "table" and normalizeOffset(gameData[OFFSET_KEY]) or nil
end

function RecallTarget.resolve(data, findLiveEgg)
    local eggId = RecallTarget.savedEggId(data)
    if not eggId then
        return { ok = false, reason = "no_recall_egg" }
    end
    if type(findLiveEgg) ~= "function" then
        return { ok = false, reason = "recall_unavailable", eggId = eggId }
    end

    local target = findLiveEgg(eggId)
    if target == nil then
        return { ok = false, reason = "recall_egg_missing", eggId = eggId }
    end

    return {
        ok = true,
        eggId = eggId,
        target = target,
        localOffset = RecallTarget.savedOffset(data),
    }
end

return RecallTarget
