-- Pure published-place role lookup. Coordinates and map contents are deliberately absent.

local PlaceRuntime = {}

local function normalizedPlaceId(placeId)
    local numeric = tonumber(placeId)
    if not numeric then
        return nil
    end
    return math.floor(numeric)
end

function PlaceRuntime.roleFor(placeId, config)
    config = type(config) == "table" and config or {}
    local target = normalizedPlaceId(placeId)
    if target then
        for role, definition in pairs(config.roles or {}) do
            for _, configuredId in
                ipairs(type(definition) == "table" and definition.place_ids or {})
            do
                if normalizedPlaceId(configuredId) == target then
                    return tostring(role)
                end
            end
        end
    end
    return tostring(config.default_role or "main")
end

function PlaceRuntime.isRole(placeId, config, role)
    return PlaceRuntime.roleFor(placeId, config) == tostring(role)
end

function PlaceRuntime.isMerge(placeId, config)
    return PlaceRuntime.isRole(placeId, config, "merge")
end

function PlaceRuntime.definitionFor(placeId, config)
    config = type(config) == "table" and config or {}
    return (config.roles or {})[PlaceRuntime.roleFor(placeId, config)]
end

function PlaceRuntime.placeIdForRole(config, role)
    config = type(config) == "table" and config or {}
    local definition = (config.roles or {})[tostring(role)]
    local placeId = type(definition) == "table" and definition.place_ids and definition.place_ids[1]
    return normalizedPlaceId(placeId)
end

-- Base movement belongs to the published place; temporary bonuses remain separate.
function PlaceRuntime.walkSpeedFor(placeId, places, gameConfig, multiplier)
    local definition = PlaceRuntime.definitionFor(placeId, places)
    local override = definition and tonumber(definition.walk_speed)
    local base = assert(tonumber(gameConfig.WorldSettings.WalkSpeed), "Base WalkSpeed missing")
    if override and override > 0 then
        base = override
    end
    return type(multiplier) == "number" and base * math.max(0, multiplier) or base
end

return PlaceRuntime
