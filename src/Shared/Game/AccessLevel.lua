--[[
    AccessLevel (shared) -- resolves the level used for progression-gated travel.

    EffectiveLevel is a temporary COMBAT level. Sidekicking may raise it and intentionally grants
    temporary realm access, but exemplaring (or a stale derived attribute during boot) must never
    revoke access the player's earned Level already grants.
]]

local AccessLevel = {}

local function normalize(value)
    return math.max(1, math.floor(tonumber(value) or 1))
end

function AccessLevel.resolve(earnedLevel, effectiveLevel)
    return math.max(normalize(earnedLevel), normalize(effectiveLevel))
end

return AccessLevel
