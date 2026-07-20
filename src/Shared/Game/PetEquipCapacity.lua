--[[
    PetEquipCapacity — pure deploy-limit resolver.

    Earned capacity (perks/upgrades/progression) and a replicated compatibility
    value describe the same axis, so the larger one wins. Paid slots are then
    added to the player's CURRENT capacity and to the progression hard cap.
]]

local PetEquipCapacity = {}

local function nonNegative(value)
    return math.max(0, tonumber(value) or 0)
end

function PetEquipCapacity.resolve(args)
    args = args or {}
    local base = math.max(1, tonumber(args.baseSlots) or 1)
    local earned = nonNegative(args.earnedSlots)
    local replicated = nonNegative(args.replicatedSlots)
    local paid = nonNegative(args.paidSlots)
    local progressionCap = math.max(base, tonumber(args.progressionCap) or base)

    local current = base + math.max(earned, replicated) + paid
    local paidCap = progressionCap + paid
    return math.clamp(current, 1, paidCap)
end

return PetEquipCapacity
