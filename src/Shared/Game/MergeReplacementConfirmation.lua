-- Pure identity for destructive Merge workshop replacements. The client uses the key for its
-- two-click confirmation, while the server remains authoritative about whether an action replaces
-- an installed chassis.

local MergeReplacementConfirmation = {}

local function whole(value, fallback)
    local number = tonumber(value)
    if number == nil then
        number = fallback or 0
    end
    return math.max(0, math.floor(number))
end

local function familyName(families, familyId)
    for _, family in ipairs(type(families) == "table" and families or {}) do
        if type(family) == "table" and tostring(family.id or "") == familyId then
            return tostring(family.name or familyId)
        end
    end
    return familyId
end

function MergeReplacementConfirmation.key(slot, currentFamily, currentTier, targetFamily)
    local currentId = tostring(currentFamily or "")
    local targetId = tostring(targetFamily or "")
    if currentId == "" or targetId == "" or currentId == targetId then
        return nil
    end
    return table.concat({
        tostring(slot or "default"),
        currentId,
        tostring(math.max(1, whole(currentTier, 1))),
        targetId,
    }, ":")
end

function MergeReplacementConfirmation.describe(state, selectedFamily)
    state = type(state) == "table" and state or {}
    selectedFamily = type(selectedFamily) == "table" and selectedFamily or {}
    local currentId = tostring(state.family or "")
    local targetId = tostring(selectedFamily.id or "")
    if state.installed ~= true or currentId == "" or targetId == "" or currentId == targetId then
        return nil
    end

    local currentTier = math.max(1, whole(state.tier, 1))
    local slot = tostring(state.slot or "default")
    return {
        key = MergeReplacementConfirmation.key(slot, currentId, currentTier, targetId),
        currentId = currentId,
        currentName = familyName(state.families, currentId),
        currentTier = currentTier,
        targetId = targetId,
        targetName = tostring(selectedFamily.name or targetId),
    }
end

function MergeReplacementConfirmation.isConfirmed(pendingKey, replacement)
    return type(replacement) == "table"
        and type(replacement.key) == "string"
        and replacement.key ~= ""
        and pendingKey == replacement.key
end

return MergeReplacementConfirmation
