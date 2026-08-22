--[[
    RealmTheme (pure) — depth-scaled realm atmosphere blending (World S3, A1).

    The realm skin should INTENSIFY as you descend: layer 1 is a faint wash, layer 5 is the full
    abyss (hell) / radiant peak (heaven). Rather than authoring 10 themes, the client captures the
    map's real base lighting and this module interpolates base -> the realm's `deep` anchor by
    `t = depth / max_depth` (depth 1 -> 0.2 faint, depth 5 -> 1.0 full). Reserves the most dramatic
    look for the deepest layer.

    Pure: standard Lua only; headless-tested. Knobs (the `deep` anchors) live in
    `configs/layers.lua` `atmosphere`.

      depthOf(layerId)            -> number  (base 0, hell_3 -> 3)
      realmOf(layerId)            -> "heaven"|"hell"|nil
      progress(layerId, maxDepth) -> t in [0,1]  (depth / maxDepth)
      interpolate(a, b, t)        -> blended theme table (numbers, numeric arrays, nested tables)
      withDistanceHaze(theme, policy) -> copied theme with the streaming-horizon envelope applied
]]

local RealmTheme = {}

local function lerp(a, b, t)
    return a + (b - a) * t
end

local function lerpArray(a, b, t)
    local out = {}
    local n = math.max(#a, #b)
    for i = 1, n do
        out[i] = lerp(tonumber(a[i]) or 0, tonumber(b[i]) or 0, t)
    end
    return out
end

function RealmTheme.depthOf(layerId)
    if not layerId or layerId == "base" then
        return 0
    end
    return tonumber(tostring(layerId):match("_(%d+)$")) or 0
end

function RealmTheme.realmOf(layerId)
    if not layerId then
        return nil
    end
    return tostring(layerId):match("^(%a+)_")
end

-- t = depth / maxDepth: depth 1 -> a faint wash, the deepest layer -> the full deep look.
function RealmTheme.progress(layerId, maxDepth)
    local depth = RealmTheme.depthOf(layerId)
    if depth <= 0 then
        return 0
    end
    maxDepth = tonumber(maxDepth) or 5
    if maxDepth <= 0 then
        return 1
    end
    return math.min(1, depth / maxDepth)
end

-- Blend two theme tables by t in [0,1]: numbers lerp, numeric arrays (colors) lerp per-component,
-- nested tables (e.g. atmosphere) recurse; non-numeric values take b (or a if b is nil).
function RealmTheme.interpolate(a, b, t)
    a = a or {}
    b = b or {}
    local out = {}
    local keys = {}
    for k in pairs(a) do
        keys[k] = true
    end
    for k in pairs(b) do
        keys[k] = true
    end
    for k in pairs(keys) do
        local av, bv = a[k], b[k]
        if type(av) == "number" and type(bv) == "number" then
            out[k] = lerp(av, bv, t)
        elseif type(av) == "table" and type(bv) == "table" then
            if av[1] ~= nil or bv[1] ~= nil then
                out[k] = lerpArray(av, bv, t)
            else
                out[k] = RealmTheme.interpolate(av, bv, t)
            end
        else
            out[k] = (bv ~= nil) and bv or av
        end
    end
    return out
end

-- Atmosphere replaces Lighting's legacy FogStart/FogEnd rendering, so the streaming horizon must
-- be hidden with a minimum particle density + haze and a low enough offset to blend distant
-- geometry into the sky. Return a copy: the captured authored base theme and configured realm
-- endpoints remain immutable inputs to the per-level interpolation.
function RealmTheme.withDistanceHaze(theme, policy)
    local out = RealmTheme.interpolate(theme, theme, 0)
    policy = type(policy) == "table" and policy or {}
    out.atmosphere = type(out.atmosphere) == "table" and out.atmosphere or {}

    local atmosphere = out.atmosphere
    local minimumDensity = tonumber(policy.minimum_density)
    local minimumHaze = tonumber(policy.minimum_haze)
    local maximumOffset = tonumber(policy.maximum_offset)

    if minimumDensity then
        atmosphere.density = math.max(tonumber(atmosphere.density) or 0, minimumDensity)
    end
    if minimumHaze then
        atmosphere.haze = math.max(tonumber(atmosphere.haze) or 0, minimumHaze)
    end
    if maximumOffset then
        atmosphere.offset = math.min(tonumber(atmosphere.offset) or 0, maximumOffset)
    end

    return out
end

return RealmTheme
