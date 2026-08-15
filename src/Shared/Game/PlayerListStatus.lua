--[[
    PlayerListStatus

    Pure formatting for the compact native Roblox People list. The native list only
    accepts leaderstats values, so this module keeps the three short presentation
    fields deterministic and testable without making them persistence fields.
]]

local PlayerListStatus = {}

local ORIGIN_LABELS = {
    grass = "Grass",
    desert = "Desert",
    ice = "Ice",
    lava = "Lava",
    light = "Light",
    shadow = "Shadow",
}

local function lower(value)
    return string.lower(tostring(value or ""))
end

local function originLabel(value)
    local normalized = lower(value)
    for origin, label in pairs(ORIGIN_LABELS) do
        if normalized == origin or string.find(normalized, "_" .. origin .. "$") then
            return label
        end
    end
    return nil
end

function PlayerListStatus.rank(level, veteranLevel)
    local veteran = math.max(0, math.floor(tonumber(veteranLevel) or 0))
    if veteran > 0 then
        return "⚔️ " .. tostring(veteran)
    end
    return tostring(math.max(1, math.floor(tonumber(level) or 1)))
end

function PlayerListStatus.status(state)
    state = state or {}
    local icons = {}
    if state.vip == true then
        table.insert(icons, "👑")
    end
    if state.founder == true then
        table.insert(icons, "⭐")
    end
    return table.concat(icons, " ")
end

function PlayerListStatus.location(state)
    state = state or {}
    local realm = lower(state.realm)
    local layer = lower(state.layer)

    if state.inMission then
        if realm == "heaven" then
            return "😇 Trial"
        elseif realm == "hell" then
            return "😈 Trial"
        end
        return "Trial"
    end

    local origin = originLabel(state.area)
    if layer == "" or layer == "base" then
        return origin and ("Home " .. origin) or "Home"
    end

    local depth = string.match(layer, "_(%d+)$") or ""
    if realm == "heaven" or string.find(layer, "^heaven_") then
        return "😇" .. depth .. (origin and (" " .. origin) or "")
    elseif realm == "hell" or string.find(layer, "^hell_") then
        return "😈" .. depth .. (origin and (" " .. origin) or "")
    end
    return origin or "Home"
end

return PlayerListStatus
