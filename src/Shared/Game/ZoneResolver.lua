--[[
    ZoneResolver — pure point-in-area resolution (no Roblox APIs).

    Given a position and a list of area bounding boxes (built from configs/areas.lua), decide
    which authored area a player is standing in. Detection is FOOTPRINT-based: it tests the X/Z
    rectangle and a generous vertical band (area boxes are thin floor slabs, see
    configs/zone_tracker.lua). When several areas overlap, the most specific (smallest
    footprint) wins, so a small area nested inside a larger island resolves to the small one.

    Shapes:
      bounds entry = { id = "Lava", center = {x,y,z}, size = {x,y,z} }
      pos          = { x, y, z }

    Pure + deterministic so it is exercised headlessly (tests/headless/specs/zone_resolver).
]]

local ZoneResolver = {}

-- Is `pos` within `area`'s X/Z footprint (expanded by `margin`) and vertical band?
-- `verticalBand` is a half-height added around the box centre on Y; pass a large value to make
-- the thin floor slab effectively cover the whole play volume above it. `margin` expands the
-- X/Z rectangle (used for hysteresis).
function ZoneResolver.contains(pos, area, verticalBand, margin)
    margin = margin or 0
    verticalBand = verticalBand or 0
    local c, s = area.center, area.size
    local halfX = (s.x or 0) / 2 + margin
    local halfZ = (s.z or 0) / 2 + margin
    local halfY = (s.y or 0) / 2 + verticalBand
    return math.abs(pos.x - c.x) <= halfX
        and math.abs(pos.z - c.z) <= halfZ
        and math.abs(pos.y - c.y) <= halfY
end

-- Clamp `pos` into `area`'s X/Z footprint, optionally inset by `margin` so a mover stops just
-- inside the edge instead of straddling it. Y is left untouched (areas are thin floor slabs).
-- Returns the clamped x, z. Used to LEASH enemies to the area they spawned in (hard wall).
function ZoneResolver.clampToFootprint(pos, area, margin)
    margin = margin or 0
    local c, s = area.center, area.size
    local halfX = math.max(0, (s.x or 0) / 2 - margin)
    local halfZ = math.max(0, (s.z or 0) / 2 - margin)
    local x = math.clamp(pos.x, c.x - halfX, c.x + halfX)
    local z = math.clamp(pos.z, c.z - halfZ, c.z + halfZ)
    return x, z
end

-- Footprint area (X*Z) — the specificity tiebreak. Smaller footprint = more specific.
local function footprint(area)
    return (area.size.x or 0) * (area.size.z or 0)
end

-- Resolve the most-specific area id containing `pos`, or nil if none match.
-- opts = { verticalBand, margin }
function ZoneResolver.resolve(pos, bounds, opts)
    opts = opts or {}
    local vb, margin = opts.verticalBand, opts.margin
    local bestId, bestFoot
    for _, area in ipairs(bounds) do
        if ZoneResolver.contains(pos, area, vb, margin) then
            local foot = footprint(area)
            if not bestFoot or foot < bestFoot then
                bestId, bestFoot = area.id, foot
            end
        end
    end
    return bestId
end

-- Sticky resolution for per-frame use: prefer keeping `currentId` to avoid edge flicker.
-- A player stays in their current area until they leave its footprint expanded by `margin`;
-- only then do we re-resolve against the unexpanded boxes. Returns the resolved id (which may
-- be `currentId`, a new id, or `default` when outside everything).
function ZoneResolver.resolveSticky(pos, bounds, currentId, opts)
    opts = opts or {}
    local vb = opts.verticalBand
    local margin = opts.margin or 0
    local default = opts.default

    -- If still inside the current area (with hysteresis margin), keep it.
    if currentId then
        for _, area in ipairs(bounds) do
            if area.id == currentId and ZoneResolver.contains(pos, area, vb, margin) then
                return currentId
            end
        end
    end

    -- Otherwise re-resolve against the tight boxes (no margin) and fall back to default.
    local resolved = ZoneResolver.resolve(pos, bounds, { verticalBand = vb, margin = 0 })
    return resolved or default
end

-- Build the bounds list ZoneResolver expects from a configs/areas.lua table. Only kind="area"
-- zones with a synthetic center+size are included (worlds/islands are organisational, not
-- standable footprints).
function ZoneResolver.boundsFromAreas(areasConfig)
    local bounds = {}
    local zones = areasConfig and areasConfig.zones or {}
    for id, zone in pairs(zones) do
        if zone.kind == "area" and type(zone.synthetic) == "table" then
            local syn = zone.synthetic
            if type(syn.center) == "table" and type(syn.size) == "table" then
                table.insert(bounds, { id = id, center = syn.center, size = syn.size })
            end
        end
    end
    return bounds
end

return ZoneResolver
