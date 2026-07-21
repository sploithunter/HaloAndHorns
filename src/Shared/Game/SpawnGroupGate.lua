--!strict

-- Pure invariant for proximity spawners: one group owns a spawner until every member has been
-- destroyed/despawned. Group size is independent (solo onramp = 1; team-scaled waves may be many).
local SpawnGroupGate = {}

function SpawnGroupGate.isActive(aliveCount)
    return math.max(0, math.floor(tonumber(aliveCount) or 0)) > 0
end

function SpawnGroupGate.canSpawn(aliveCount)
    return not SpawnGroupGate.isActive(aliveCount)
end

return SpawnGroupGate
