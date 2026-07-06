--[[
    TeamCast — pure resolver for cast-through-player support (docs/TEAMING.md).

    With 20–40 pets on screen nobody micro-targets a teammate's squad: the caster targets
    the PLAYER, and the server picks the actual pet(s) here. Input is a plain array of pet
    states (built by the caller from replicated attributes), so this stays headless-testable:
        { key = <anything>, enduranceFrac = 0..1, downed = bool, hasAggro = bool, isTank = bool }

    Family semantics:
      heal / heal_over_time -> the ONE lowest-enduranceFrac live pet (most hurt first)
      revive                -> ALL downed pets
      absorb (shield)       -> the aggro holder, else the tank, else lowest endurance
      defense_buff / damage_buff -> ALL live pets (squad scope, like self-cast)
      anything else         -> nil (not a supported cross-player family)
]]

local TeamCast = {}

local function liveOnly(pets)
    local out = {}
    for _, p in ipairs(pets) do
        if not p.downed then
            out[#out + 1] = p
        end
    end
    return out
end

local function lowest(pets)
    local best
    for _, p in ipairs(pets) do
        if not best or (p.enduranceFrac or 1) < (best.enduranceFrac or 1) then
            best = p
        end
    end
    return best
end

--- family: string; pets: array of pet states. Returns an ARRAY of chosen states ({} if none).
function TeamCast.pick(family, pets)
    pets = pets or {}
    if family == "heal" or family == "heal_over_time" then
        local target = lowest(liveOnly(pets))
        return target and { target } or {}
    end
    if family == "revive" then
        local out = {}
        for _, p in ipairs(pets) do
            if p.downed then
                out[#out + 1] = p
            end
        end
        return out
    end
    if family == "absorb" then
        local live = liveOnly(pets)
        for _, p in ipairs(live) do
            if p.hasAggro then
                return { p }
            end
        end
        for _, p in ipairs(live) do
            if p.isTank then
                return { p }
            end
        end
        local target = lowest(live)
        return target and { target } or {}
    end
    if family == "defense_buff" or family == "damage_buff" then
        return liveOnly(pets)
    end
    return {}
end

return TeamCast
