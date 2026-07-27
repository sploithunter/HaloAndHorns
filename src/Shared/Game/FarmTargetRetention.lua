--[[
    FarmTargetRetention — pure decision for automatic mining reassignment.

    Farm Near/High poll frequently so newly spawned targets can be discovered. That poll must
    not become a movement command every time: a pet already working a live crystal finishes it.
    Manual crystal clicks deliberately bypass this rule, so the player can always redirect a pet
    that would otherwise spend too long on a large node.
]]

local FarmTargetRetention = {}

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
