--[[
    SoulMath (pure)

    The alignment core for Feature 2 (Soul Stat). Given a player's soul state, a
    just-conquered biome, the ring topology, and the soul config, compute the new
    state. Directional rule:
      - conquering the CLOCKWISE neighbor of the last-conquered biome  -> +delta
      - conquering the COUNTERCLOCKWISE neighbor                       -> -delta
      - conquering a non-adjacent biome                                -> 0
      - first conquest (no last_conquered)                            -> 0 (just sets last)
      - re-conquering an already-conquered biome                      -> full no-op, no event
    Soul is clamped to the configured range.

    Pure: standard Lua only; unit-tested via `mise run test-headless`.

    state  : { soul = number, last_conquered_biome = string?, conquered_biomes = { [id]=true } }
    config : { delta_per_conquest = number, range = { min, max }, bands = { halo, horns } }
    returns: (newState, result) where result =
             { fired = bool, delta = number, soul = number, reason = string? }
]]

local SoulMath = {}

local function clamp(value, lo, hi)
    if value < lo then
        return lo
    elseif value > hi then
        return hi
    end
    return value
end

local function copySet(set)
    local out = {}
    if set then
        for key, value in pairs(set) do
            out[key] = value
        end
    end
    return out
end

function SoulMath.applyConquest(state, conqueredBiome, topology, config)
    local conquered = state.conquered_biomes or {}

    -- Re-conquest of an already-owned biome is a full no-op (no event fires).
    if conquered[conqueredBiome] then
        return state, { fired = false, delta = 0, soul = state.soul, reason = "already_conquered" }
    end

    local delta = 0
    local last = state.last_conquered_biome
    if last ~= nil then
        if topology:clockwiseNeighbor(last) == conqueredBiome then
            delta = config.delta_per_conquest
        elseif topology:counterclockwiseNeighbor(last) == conqueredBiome then
            delta = -config.delta_per_conquest
        end
        -- non-adjacent leaves delta at 0
    end

    local range = config.range or { min = -100, max = 100 }
    local newSoul = clamp(state.soul + delta, range.min, range.max)

    local newConquered = copySet(conquered)
    newConquered[conqueredBiome] = true

    local newState = {
        soul = newSoul,
        last_conquered_biome = conqueredBiome,
        conquered_biomes = newConquered,
    }
    return newState, { fired = true, delta = delta, soul = newSoul }
end

-- Config-driven alignment label for a soul value: "halo" / "horns" / "neutral".
function SoulMath.alignment(soul, config)
    local bands = (config and config.bands) or { halo = 1, horns = -1 }
    if soul >= bands.halo then
        return "halo"
    elseif soul <= bands.horns then
        return "horns"
    end
    return "neutral"
end

return SoulMath
