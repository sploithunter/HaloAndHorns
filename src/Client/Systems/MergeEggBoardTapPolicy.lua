--[[
    MergeEggBoardTapPolicy — pure two-tap rules for the Merge playboard.

    The client owns only selection intent. The server remains authoritative for inventory,
    board tiers, deployed tiers, distance, and the resulting merge/deployment transaction.
]]

local MergeEggBoardTapPolicy = {}

local function positiveInteger(value)
    local number = tonumber(value)
    if not number or number < 1 or number % 1 ~= 0 then
        return nil
    end
    return number
end

local function nonNegativeInteger(value)
    local number = tonumber(value)
    if not number or number < 0 or number % 1 ~= 0 then
        return nil
    end
    return number
end

local function cleared()
    return {
        kind = "clear",
        selection = nil,
        request = nil,
    }
end

function MergeEggBoardTapPolicy.resolve(selection, target)
    target = type(target) == "table" and target or {}

    if type(selection) ~= "table" then
        if target.kind ~= "board_egg" then
            return {
                kind = "idle",
                selection = nil,
                request = nil,
            }
        end
        local sourceSlot = positiveInteger(target.slot)
        local sourceTier = positiveInteger(target.tier)
        if not (sourceSlot and sourceTier) then
            return cleared()
        end
        return {
            kind = "select",
            selection = {
                sourceSlot = sourceSlot,
                sourceTier = sourceTier,
            },
            request = nil,
        }
    end

    local sourceSlot = positiveInteger(selection.sourceSlot)
    local sourceTier = positiveInteger(selection.sourceTier)
    if not (sourceSlot and sourceTier) then
        return cleared()
    end

    if target.kind == "board_egg" then
        local targetSlot = positiveInteger(target.slot)
        local targetTier = positiveInteger(target.tier)
        if not targetSlot or targetSlot == sourceSlot or targetTier ~= sourceTier then
            return cleared()
        end
        return {
            kind = "action",
            selection = nil,
            request = {
                action = "merge_slots",
                sourceSlot = sourceSlot,
                targetSlot = targetSlot,
            },
        }
    end

    if target.kind == "deployment" then
        local teamId = positiveInteger(target.teamId)
        local deployedTier = nonNegativeInteger(target.deployedTier)
        if not teamId or deployedTier == nil then
            return cleared()
        end
        if deployedTier ~= 0 and deployedTier ~= sourceTier then
            return cleared()
        end
        return {
            kind = "action",
            selection = nil,
            request = {
                action = "deploy_to_hatcher",
                sourceSlot = sourceSlot,
                teamId = teamId,
            },
        }
    end

    return cleared()
end

return MergeEggBoardTapPolicy
