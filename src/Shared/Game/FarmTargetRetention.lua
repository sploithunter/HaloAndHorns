--[[
    FarmTargetRetention — pure decision for automatic mining reassignment.

    Farm Near/High poll frequently so newly spawned targets can be discovered. That poll must
    not become a movement command every time: a pet already working a live crystal finishes it.
    Manual crystal clicks deliberately bypass this rule, so the player can always redirect a pet
    that would otherwise spend too long on a large node.
]]

local FarmTargetRetention = {}

-- The acquisition radius is also the retention leash: a pet may finish its current crystal
-- until the owner moves beyond the same distance at which auto-farm could have selected it.
-- Missing position data fails open so a respawn/streaming gap cannot discard valid work.
function FarmTargetRetention.withinLeash(distance, maxDistance)
    distance = tonumber(distance)
    maxDistance = tonumber(maxDistance)
    if distance == nil or maxDistance == nil or maxDistance <= 0 then
        return true
    end
    return distance <= maxDistance
end

function FarmTargetRetention.shouldRelease(args)
    args = type(args) == "table" and args or {}
    if args.inCombat == true then
        return true
    end
    return not FarmTargetRetention.withinLeash(args.distance, args.maxDistance)
end

function FarmTargetRetention.shouldKeep(args)
    args = type(args) == "table" and args or {}
    if args.automatic ~= true then
        return false
    end
    if string.lower(tostring(args.targetType or "")) ~= "crystals" then
        return false
    end
    if (tonumber(args.targetId) or 0) == 0 then
        return false
    end
    return (tonumber(args.targetHp) or 0) > 0
end

return FarmTargetRetention
