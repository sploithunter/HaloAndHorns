--[[
    RosterLogic — pure functional core for the roster system (Feature 17).

    No Roblox APIs. The service supplies pet states (ready / recovery) from Spirit
    Form. Injury rules decide which roster pets deploy (and their order):
      "ready_only"     — only ready pets, in roster order (no substitution)
      "best_available" — ready pets (roster order) first, then injured by recovery desc
      "deploy_anyway"  — roster order as-is, including spirit-form pets

      clampMaxToDeploy(requested, capacity)                  -> integer
      removeRef(orderedPets, petRef)                         -> new array without petRef
      resolveDeploy(orderedPets, petStates, maxToDeploy, injuryRule) -> array of refs
]]

local RosterLogic = {}

function RosterLogic.clampMaxToDeploy(requested, capacity)
    local req = math.max(0, math.floor(tonumber(requested) or 0))
    local cap = math.max(0, math.floor(tonumber(capacity) or 0))
    return math.min(req, cap)
end

-- Remove every occurrence of petRef (e.g. on delete/trade); preserves order.
function RosterLogic.removeRef(orderedPets, petRef)
    local out = {}
    for _, ref in ipairs(orderedPets or {}) do
        if ref ~= petRef then
            table.insert(out, ref)
        end
    end
    return out
end

local function isReady(petStates, ref)
    local s = petStates and petStates[ref]
    -- Unknown pets are treated as ready (no spirit-form record).
    return s == nil or s.ready == true
end

local function recovery(petStates, ref)
    local s = petStates and petStates[ref]
    return (s and tonumber(s.recovery)) or 0
end

-- Resolve the ordered list of pet refs to deploy for a roster invocation.
function RosterLogic.resolveDeploy(orderedPets, petStates, maxToDeploy, injuryRule)
    orderedPets = orderedPets or {}
    local rule = injuryRule or "ready_only"
    local max = math.max(0, math.floor(tonumber(maxToDeploy) or 0))

    local candidates = {}
    if rule == "deploy_anyway" then
        for _, ref in ipairs(orderedPets) do
            table.insert(candidates, ref)
        end
    elseif rule == "best_available" then
        -- ready pets first (roster order), then injured by recovery desc (stable)
        local injured = {}
        for index, ref in ipairs(orderedPets) do
            if isReady(petStates, ref) then
                table.insert(candidates, ref)
            else
                table.insert(
                    injured,
                    { ref = ref, index = index, recovery = recovery(petStates, ref) }
                )
            end
        end
        table.sort(injured, function(a, b)
            if a.recovery ~= b.recovery then
                return a.recovery > b.recovery
            end
            return a.index < b.index -- stable for ties
        end)
        for _, entry in ipairs(injured) do
            table.insert(candidates, entry.ref)
        end
    else -- "ready_only"
        for _, ref in ipairs(orderedPets) do
            if isReady(petStates, ref) then
                table.insert(candidates, ref)
            end
        end
    end

    local deploy = {}
    for _, ref in ipairs(candidates) do
        if #deploy >= max then
            break
        end
        table.insert(deploy, ref)
    end
    return deploy
end

return RosterLogic
