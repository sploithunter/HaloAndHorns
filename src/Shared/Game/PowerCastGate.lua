--[[
    PowerCastGate — pure preflight rules for casts that otherwise have no effect.

    PowerService owns the Roblox queries (living pets, downed pets, nearby enemies/crystals);
    this module owns the decision so every target-dependent family is explicit and headless-tested.
]]

local PowerCastGate = {}

local LIVE_PET_REQUIRED = {
    absorb = true,
    defense_buff = true,
    evade = true,
    fortify = true,
}

function PowerCastGate.validate(kind, state)
    kind = kind or {}
    state = state or {}
    local family = kind.family
    local livePets = tonumber(state.livePetCount) or 0

    if family == "revive" then
        return state.hasDownedPet == true, "no_downed_pets"
    end
    if family == "farm_boost" then
        -- Farming casts have a much more actionable refusal than the generic no-target case.
        -- Keep this reason distinct all the way to the client so Resonance can tell the player to
        -- move toward a crystal instead of only playing the universal failed-cast bonk.
        return (tonumber(state.breakableCount) or 0) > 0, "no_crystals_in_range"
    end
    if family == "heal_blind" then
        local enemies = tonumber(state.enemyCount) or 0
        return livePets > 0 or enemies > 0, "no_pets_or_enemies_in_range"
    end
    if family == "heal" and kind.field ~= true then
        return livePets > 0, "no_pets_deployed"
    end
    if LIVE_PET_REQUIRED[family] then
        return livePets > 0, "no_pets_deployed"
    end
    return true
end

return PowerCastGate
