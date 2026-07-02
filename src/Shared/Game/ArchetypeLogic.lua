--[[
    ArchetypeLogic — pure functional core for the archetype system (Feature 13).

    No Roblox APIs; config-driven (configs/archetypes.lua). The service wraps these
    over profile state.

      isValid(archetype, config)            -> boolean
      list(config)                          -> array of archetype keys (sorted)
      availablePowers(archetype, config)    -> array of power ids (origin pool + generic; just the
                                               GENERIC pool when origin is nil/invalid — NATURAL
                                               powers are pickable before the L5 origin choice)
      hasPower(archetype, powerId, config)  -> boolean (in the origin pool OR the generic pool)
]]

local ArchetypeLogic = {}

local function archetypeEntry(archetype, config)
    if not archetype or not config or type(config.archetypes) ~= "table" then
        return nil
    end
    return config.archetypes[archetype]
end

function ArchetypeLogic.isValid(archetype, config)
    return archetypeEntry(archetype, config) ~= nil
end

function ArchetypeLogic.list(config)
    local keys = {}
    if config and type(config.archetypes) == "table" then
        for key in pairs(config.archetypes) do
            table.insert(keys, key)
        end
    end
    table.sort(keys)
    return keys
end

function ArchetypeLogic.availablePowers(archetype, config)
    local out = {}
    local entry = archetypeEntry(archetype, config)
    if entry and type(entry.power_pool) == "table" then
        for _, powerId in ipairs(entry.power_pool) do
            table.insert(out, powerId)
        end
    end
    -- The GENERIC pool (universal NATURAL powers) is ALWAYS available — including before an origin
    -- is chosen (nil/invalid archetype), so L2/L4 NATURAL picks work pre-origin (L5 choice).
    if type(config) == "table" and type(config.generic_pool) == "table" then
        for _, powerId in ipairs(config.generic_pool) do
            table.insert(out, powerId)
        end
    end
    return out
end

function ArchetypeLogic.hasPower(archetype, powerId, config)
    local entry = archetypeEntry(archetype, config)
    if entry and type(entry.power_pool) == "table" then
        for _, id in ipairs(entry.power_pool) do
            if id == powerId then
                return true
            end
        end
    end
    -- generic powers are available to every archetype (and before any origin is chosen)
    if type(config) == "table" and type(config.generic_pool) == "table" then
        for _, id in ipairs(config.generic_pool) do
            if id == powerId then
                return true
            end
        end
    end
    return false
end

return ArchetypeLogic
