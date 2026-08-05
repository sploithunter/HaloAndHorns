--[[
    MonetizationCatalog — pure projection helpers for the Robux shop.

    The config intentionally contains future developer products before their
    Creator Dashboard IDs and reward handlers are ready. The live shop must
    never render a Buy button for one of those placeholders, so visibility is
    derived from a positive product_id_mapping entry.
]]

local MonetizationCatalog = {}

local function project(config, source, kind)
    local mapped = (config and config.product_id_mapping) or {}
    local result = {}
    for order, item in ipairs(source or {}) do
        local robloxId = tonumber(mapped[item.id]) or 0
        if robloxId > 0 then
            result[#result + 1] = {
                config = item,
                id = item.id,
                kind = kind,
                order = order,
                robloxId = robloxId,
            }
        end
    end
    return result
end

function MonetizationCatalog.livePasses(config)
    return project(config, config and config.passes, "gamepass")
end

function MonetizationCatalog.liveProducts(config)
    return project(config, config and config.products, "product")
end

function MonetizationCatalog.ownedSet(snapshot)
    local owned = {}
    for _, entry in ipairs((snapshot and snapshot.passes) or {}) do
        local id = type(entry) == "table" and entry.id or entry
        if type(id) == "string" then
            owned[id] = true
        end
    end
    return owned
end

function MonetizationCatalog.sourceSet(snapshot, sourceName)
    local result = {}
    for _, entry in ipairs((snapshot and snapshot.passes) or {}) do
        if
            type(entry) == "table"
            and type(entry.id) == "string"
            and type(entry.sources) == "table"
            and entry.sources[sourceName] == true
        then
            result[entry.id] = true
        end
    end
    return result
end

-- Server-authoritative creator entitlement. This deliberately lives in the monetization config,
-- not the Meet-The-Creator registry: a creator account may need owner benefits without authoring a
-- public meet egg/species. Numeric/string IDs compare identically so config serialization is safe.
function MonetizationCatalog.creatorOwnsAllPasses(config, userId)
    local entitlement = config and config.creator_entitlements
    if not (entitlement and entitlement.grant_all_passes == true) then
        return false
    end
    for _, configuredId in ipairs(entitlement.user_ids or {}) do
        if tostring(configuredId) == tostring(userId) then
            return true
        end
    end
    return false
end

-- Creator-only production balance gate. Non-creators are not eligible for this override; their
-- real Marketplace ownership is always authoritative. Legacy creator profiles default ON.
function MonetizationCatalog.creatorPassGateState(config, userId, settings)
    local eligible = MonetizationCatalog.creatorOwnsAllPasses(config, userId)
    return {
        eligible = eligible,
        enabled = eligible and not (settings and settings.CreatorGamePassesEnabled == false),
    }
end

return MonetizationCatalog
