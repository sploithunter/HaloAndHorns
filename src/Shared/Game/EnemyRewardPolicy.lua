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

return EnemyRewardPolicy
