--!strict

-- Pure decision for ZoneService's character spawn safety. The prologue owns placement while its
-- first-run decision is unresolved or active; otherwise the normal zone spawn may place the player.
local PrologueSpawnGate = {}

function PrologueSpawnGate.action(prologueServiceRuns, inPrologue, prologueGate)
    if prologueServiceRuns ~= true then
        return "place"
    end
    if inPrologue == true then
        return "skip"
    end
    if prologueGate == nil then
        return "wait"
    end
    return "place"
end

return PrologueSpawnGate
