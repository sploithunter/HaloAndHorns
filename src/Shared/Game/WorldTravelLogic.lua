--[[
    WorldTravelLogic — pure realm/origin destination naming and unlocked catalog filtering.

    Config order controls presentation. Runtime services provide three permission sets:
    usable layers (LayerService), built layers (map geometry), and unlocked zones (ZoneService).
    A destination appears only in the intersection, and the server rebuilds the same catalog when
    a client selects it. Pure so the security/filter contract is headless-testable.
]]

local WorldTravelLogic = {}

local function titleCaseFirst(value)
    return tostring(value or ""):gsub("^%l", string.upper)
end

function WorldTravelLogic.layerLabel(layerId)
    if layerId == "base" then
        return "Home"
    end
    local realm, depth = tostring(layerId or ""):match("^(heaven)_(%d+)$")
    if not realm then
        realm, depth = tostring(layerId or ""):match("^(hell)_(%d+)$")
    end
    if realm and depth then
        return titleCaseFirst(realm) .. " " .. depth
    end
    return tostring(layerId or "Unknown")
end

function WorldTravelLogic.mapFolder(layerId)
    if layerId == "base" then
        return "Home"
    end
    return titleCaseFirst(layerId)
end

function WorldTravelLogic.zoneId(layerId, origin)
    if type(origin) ~= "table" then
        return nil
    end
    if layerId == "base" then
        return origin.base_zone
    end
    local prefix = WorldTravelLogic.mapFolder(layerId)
    if type(origin.suffix) ~= "string" or origin.suffix == "" then
        return nil
    end
    return prefix .. "_" .. origin.suffix
end

local function asSet(values)
    local set = {}
    for key, value in pairs(values or {}) do
        if type(key) == "number" then
            set[tostring(value)] = true
        elseif value == true then
            set[tostring(key)] = true
        end
    end
    return set
end

-- opts = { usableLayers, builtLayers, unlockedZones, quotes, currentLayer, currentArea }
function WorldTravelLogic.catalog(travelConfig, areasConfig, opts)
    opts = opts or {}
    local usable = asSet(opts.usableLayers)
    local built = asSet(opts.builtLayers)
    local unlocked = asSet(opts.unlockedZones)
    local zones = (areasConfig and areasConfig.zones) or {}
    local out = {}

    for _, layerId in ipairs((travelConfig and travelConfig.layer_order) or {}) do
        if usable[layerId] and built[layerId] then
            local origins = {}
            for order, origin in ipairs((travelConfig and travelConfig.origins) or {}) do
                local zoneId = WorldTravelLogic.zoneId(layerId, origin)
                if zoneId and zones[zoneId] and unlocked[zoneId] then
                    origins[#origins + 1] = {
                        id = origin.id,
                        label = origin.display_name or titleCaseFirst(origin.id),
                        zoneId = zoneId,
                        order = order,
                        current = zoneId == opts.currentArea,
                    }
                end
            end
            if #origins > 0 then
                local quote = (opts.quotes and opts.quotes[layerId]) or {}
                out[#out + 1] = {
                    id = layerId,
                    label = WorldTravelLogic.layerLabel(layerId),
                    current = layerId == opts.currentLayer,
                    cost = tonumber(quote.cost) or 0,
                    currency = quote.currency,
                    origins = origins,
                }
            end
        end
    end
    return out
end

function WorldTravelLogic.find(catalog, layerId, originId)
    for _, layer in ipairs(catalog or {}) do
        if layer.id == layerId then
            for _, origin in ipairs(layer.origins or {}) do
                if origin.id == originId then
                    return layer, origin
                end
            end
        end
    end
    return nil, nil
end

return WorldTravelLogic
