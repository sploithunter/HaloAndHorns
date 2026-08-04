-- Pure friend-presence boost math. The live service owns Roblox friendship checks;
-- every reward consumer reads the resulting player attributes/provider contribution.
local FriendBoost = {}

local function nonNegative(value)
    return math.max(0, tonumber(value) or 0)
end

function FriendBoost.phase(config)
    config = type(config) == "table" and config or {}
    local phases = type(config.phases) == "table" and config.phases or {}
    local phaseId = tostring(config.active_phase or "launch")
    return phaseId, type(phases[phaseId]) == "table" and phases[phaseId] or {}
end

function FriendBoost.count(config, friendCount)
    config = type(config) == "table" and config or {}
    local maximum = math.max(0, math.floor(tonumber(config.max_friends) or 4))
    return math.clamp(math.floor(nonNegative(friendCount)), 0, maximum)
end

function FriendBoost.bonuses(config, friendCount)
    local phaseId, phase = FriendBoost.phase(config)
    local count = FriendBoost.count(config, friendCount)
    return {
        phase = phaseId,
        friendCount = count,
        hatchLuck = count * nonNegative(phase.hatch_luck_per_friend),
        xp = count * nonNegative(phase.xp_per_friend),
        coins = count * nonNegative(phase.coins_per_friend),
    }
end

function FriendBoost.isCoinCurrency(currency)
    currency = string.lower(tostring(currency or ""))
    return currency == "coins" or currency == "crystals" or string.sub(currency, -6) == "_coins"
end

return FriendBoost
