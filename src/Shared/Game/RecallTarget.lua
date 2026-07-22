--[[
    RecallTarget — pure durable-target rules for the Natural Recall power.

    The profile stores the egg SOURCE id, never a world position. At cast time the server resolves
    that id against the live EggStand registry, so moved eggs remain valid and removed event eggs
    fail closed.
]]

local RecallTarget = {}

local PROFILE_KEY = "LastHatchedEggId"

local function validEggId(value)
    return type(value) == "string" and value ~= ""
end

function RecallTarget.record(data, eggId)
    if type(data) ~= "table" or not validEggId(eggId) then
        return { ok = false, reason = "invalid_recall_egg" }
    end

    data.GameData = type(data.GameData) == "table" and data.GameData or {}
    local changed = data.GameData[PROFILE_KEY] ~= eggId
    data.GameData[PROFILE_KEY] = eggId
    return { ok = true, eggId = eggId, changed = changed }
end

function RecallTarget.savedEggId(data)
    local gameData = type(data) == "table" and data.GameData or nil
    local eggId = type(gameData) == "table" and gameData[PROFILE_KEY] or nil
    return validEggId(eggId) and eggId or nil
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

    return { ok = true, eggId = eggId, target = target }
end

return RecallTarget
