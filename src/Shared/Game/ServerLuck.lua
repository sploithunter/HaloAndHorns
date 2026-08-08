-- Pure arbitration for non-stacking server-presence hatch luck.

local ServerLuck = {}

function ServerLuck.resolveForPlayer(state)
    state = type(state) == "table" and state or {}
    local bestMultiplier = 1
    local source = nil

    if state.founderPresent == true then
        local founderMultiplier = math.max(1, tonumber(state.founderMultiplier) or 1)
        if founderMultiplier > bestMultiplier then
            bestMultiplier = founderMultiplier
            source = "founder"
        end
    end

    -- Registered creators keep their balance-testing exclusion from Creator Luck. A creator who
    -- also earned Founder’s Legacy may still receive the weaker founder aura.
    if state.creatorPresent == true and state.playerIsCreator ~= true then
        local creatorMultiplier = math.max(1, tonumber(state.creatorMultiplier) or 1)
        if creatorMultiplier > bestMultiplier then
            bestMultiplier = creatorMultiplier
            source = "creator"
        end
    end

    return bestMultiplier, source
end

return ServerLuck
