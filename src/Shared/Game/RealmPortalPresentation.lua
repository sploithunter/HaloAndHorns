--!strict

-- Pure portal-copy rules. Testing access may remove a player's lock, but it must never rewrite
-- the destination signage: every built layer keeps the same "Realm N / Lv N" format.

local RealmPortalPresentation = {}

function RealmPortalPresentation.displayName(layerId: string): string
    local realm, depth = tostring(layerId):match("^(%a+)_(%d+)$")
    if realm then
        return realm:sub(1, 1):upper() .. realm:sub(2) .. " " .. depth
    end
    return tostring(layerId)
end

function RealmPortalPresentation.caption(layerId: string, layersConfig: any): string
    local label = RealmPortalPresentation.displayName(layerId)
    local access = type(layersConfig) == "table" and layersConfig.access
    local requirement = type(access) == "table" and access[layerId]
    local requiredLevel = type(requirement) == "table" and tonumber(requirement.requires_level)
    if requiredLevel and requiredLevel > 1 then
        return label .. "\nLv " .. requiredLevel
    end
    return label
end

return RealmPortalPresentation
