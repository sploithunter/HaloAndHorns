--[[
    ZoneSchema — THE zone-shape rules, pure (no Roblox APIs).

    Born from the 2026-07-09 double boot-crash: ConfigLoader and
    WorldBindingService each kept their OWN zone validation (separate kind
    allowlists!), so a new zone kind passed one gate and died at the other —
    and neither ran in CI (headless only require-loaded configs). One module,
    three consumers:
      - ConfigLoader._validateAreasConfig  (boot, config-level)
      - WorldBindingService._validateZoneTree (boot, service-level)
      - tests/headless/specs/config_validation.spec (CI, pre-Studio)

    validateZones(zones) -> ok, err  — the shared shape rules. Consumers keep
    their EXTRA checks (ConfigLoader's field types, WorldBinding's parent
    cycles) but the kind allowlist and key/id agreement live only here.
]]

local ZoneSchema = {}

-- THE kind allowlist. Add new kinds HERE and nowhere else.
ZoneSchema.VALID_KINDS = {
    world = true,
    island = true,
    area = true,
    mission = true, -- trial-interior pseudo-zones (element/origin branding; no geometry)
}

function ZoneSchema.validateZones(zones)
    if type(zones) ~= "table" then
        return false, "zones: expected table"
    end
    local seen = {}
    for zoneId, zone in pairs(zones) do
        local path = "zones." .. tostring(zoneId)
        if type(zone) ~= "table" then
            return false, path .. ": expected table"
        end
        if type(zone.id) ~= "string" or zone.id == "" then
            return false, path .. ".id: expected non-empty string"
        end
        if zone.id ~= zoneId then
            return false, path .. ".id: must match table key"
        end
        if seen[zone.id] then
            return false, path .. ".id: duplicate zone id"
        end
        seen[zone.id] = true
        if not ZoneSchema.VALID_KINDS[zone.kind] then
            return false, path .. ".kind: invalid (see ZoneSchema.VALID_KINDS)"
        end
        if zone.parent ~= nil and type(zone.parent) ~= "string" then
            return false, path .. ".parent: expected string"
        end
        if zone.parent ~= nil and zones[zone.parent] == nil then
            return false, path .. ".parent: references missing zone"
        end
    end
    return true
end

return ZoneSchema
