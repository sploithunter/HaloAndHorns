--[[
    FloraTheme (pure) — resolve which themed model replaces a tagged flora
    anchor in a given layer context (Jason 2026-07-16: "a part on the floor
    of every tree, every cactus... then we can quickly replace things to
    change styles for heaven and hell").

    Contract: authored flora models are tagged `FloraAnchor` with attributes
    Kind (semantic family: tree/cactus/rock/plant) and Variant (source slug,
    e.g. "pine_tree", "desert_tree"). configs/flora.lua maps context ->
    kind/variant -> replacement model name (in Assets.Models.Flora).
    Resolution precedence, most specific first:

        layers.<layer_id>.<kind>/<variant>   e.g. heaven_2["tree/desert_tree"]
        layers.<layer_id>.<kind>             e.g. heaven_2.tree
        realms.<realm>.<kind>/<variant>      e.g. heaven["tree/desert_tree"]
        realms.<realm>.<kind>                e.g. heaven.tree
        nil -> keep the authored original (no replacement)

    Pure: no Roblox APIs; headless-tested.
]]

local FloraTheme = {}

-- realm from a layer id ("heaven_2" -> "heaven"; "base"/unknown -> nil)
function FloraTheme.realmOf(layerId)
    local realm = tostring(layerId or ""):match("^(heaven)_%d+$")
        or tostring(layerId or ""):match("^(hell)_%d+$")
    return realm
end

-- Pick one model name from a resolved value. Strings pass through; an
-- ARRAY value means "any of these" — chosen deterministically from the
-- anchor's XZ position so the world is stable across boots (same scheme
-- as FloraService's random yaw).
function FloraTheme.pick(value, x, z)
    if type(value) ~= "table" then
        return value
    end
    if #value == 0 then
        return nil
    end
    local seed = math.floor((tonumber(x) or 0) * 73856093)
        + math.floor((tonumber(z) or 0) * 19349663)
    return value[(seed % #value) + 1]
end

-- Resolve the replacement model NAME for (layerId, kind, variant) against
-- the configs/flora.lua table. nil = keep the authored original. The value
-- may be a string or an array of names (see FloraTheme.pick).
function FloraTheme.resolve(config, layerId, kind, variant)
    if type(config) ~= "table" then
        return nil
    end
    local keyed = kind .. "/" .. tostring(variant or "")
    local layers = config.layers or {}
    local realms = config.realms or {}
    local layer = layers[layerId]
    if type(layer) == "table" then
        if layer[keyed] ~= nil then
            return layer[keyed]
        end
        if layer[kind] ~= nil then
            return layer[kind]
        end
    end
    local realm = FloraTheme.realmOf(layerId)
    local realmCfg = realm and realms[realm]
    if type(realmCfg) == "table" then
        if realmCfg[keyed] ~= nil then
            return realmCfg[keyed]
        end
        if realmCfg[kind] ~= nil then
            return realmCfg[kind]
        end
    end
    return nil
end

return FloraTheme
