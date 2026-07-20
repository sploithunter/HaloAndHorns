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

return MonetizationCatalog
