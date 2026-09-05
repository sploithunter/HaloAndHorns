--[[
    EnemyRewardPolicy — pure normalization for per-spawn enemy reward behavior.

    Ordinary enemies keep the legacy "normal" policy. Isolated encounters may opt into
    "none" so defeat still runs the enemy lifecycle and a server-only completion callback,
    but skips every normal player reward/progression side effect.
]]

local EnemyRewardPolicy = {}

EnemyRewardPolicy.NORMAL = "normal"
EnemyRewardPolicy.NONE = "none"

function EnemyRewardPolicy.normalize(value)
    if value == nil or value == EnemyRewardPolicy.NORMAL then
        return EnemyRewardPolicy.NORMAL
    end
    if value == EnemyRewardPolicy.NONE then
        return EnemyRewardPolicy.NONE
    end
    return nil
end

function EnemyRewardPolicy.awardsNormalRewards(value)
    return EnemyRewardPolicy.normalize(value) == EnemyRewardPolicy.NORMAL
end

-- Participation is a floor, not an additional award on top of a personal killing blow.
function EnemyRewardPolicy.mergeXpShare(personalPets, totalPets, killingBlow)
    if killingBlow then
        return 1
    end
    local total = math.max(0, tonumber(totalPets) or 0)
    return total > 0 and math.clamp((tonumber(personalPets) or 0) / total, 0, 1) or 0
end

return EnemyRewardPolicy
