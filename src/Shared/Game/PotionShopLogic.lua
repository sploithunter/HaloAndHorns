--[[
    PotionShopLogic — pure catalog/pricing rules for the authored potion tents.

    Runtime services own inventory/currency mutation. This module owns the stable
    interpretation of configs/potions.lua `shop`: which potions are stocked, their
    unit prices, and quantity-safe buy/sell quotes.
]]

local PotionShopLogic = {}

local function positiveInt(value)
    return math.max(0, math.floor(tonumber(value) or 0))
end

local function exactQuantity(value)
    if value == nil then
        return 1
    end
    local quantity = positiveInt(value)
    if quantity == 1 or quantity == 10 or quantity == 100 then
        return quantity
    end
    return nil
end

local function shopConfig(config)
    local shop = config and config.shop
    if type(shop) ~= "table" or shop.enabled == false then
        return nil
    end
    return shop
end

local function stockedIds(config)
    local shop = shopConfig(config)
    if not shop then
        return {}
    end

    local ids = {}
    local seen = {}
    if type(shop.stock) == "table" then
        for _, potionId in ipairs(shop.stock) do
            if
                type(potionId) == "string"
                and not seen[potionId]
                and config.potions
                and config.potions[potionId]
            then
                seen[potionId] = true
                ids[#ids + 1] = potionId
            end
        end
    else
        for potionId, potion in pairs(config.potions or {}) do
            if potion.tradeable ~= false then
                ids[#ids + 1] = potionId
            end
        end
        table.sort(ids)
    end
    return ids
end

function PotionShopLogic.settings(config)
    local shop = shopConfig(config)
    if not shop then
        return nil
    end
    return {
        currency = shop.currency or "gems",
        buyPrice = positiveInt(shop.buy_price),
        sellPrice = positiveInt(shop.sell_price),
    }
end

function PotionShopLogic.isStocked(config, potionId)
    for _, id in ipairs(stockedIds(config)) do
        if id == potionId then
            local potion = config.potions[id]
            return potion and potion.tradeable ~= false
        end
    end
    return false
end

function PotionShopLogic.catalog(config, counts)
    local settings = PotionShopLogic.settings(config)
    if not settings then
        return { ok = false, reason = "shop_disabled", offers = {} }
    end

    local offers = {}
    for _, potionId in ipairs(stockedIds(config)) do
        local potion = config.potions[potionId]
        if potion and potion.tradeable ~= false then
            offers[#offers + 1] = {
                id = potionId,
                name = potion.display_name or potionId,
                icon = potion.icon,
                meter = potion.meter,
                owned = positiveInt(counts and counts[potionId]),
                buyPrice = settings.buyPrice,
                sellPrice = settings.sellPrice,
            }
        end
    end

    return {
        ok = true,
        currency = settings.currency,
        buyPrice = settings.buyPrice,
        sellPrice = settings.sellPrice,
        offers = offers,
    }
end

function PotionShopLogic.buyQuote(config, potionId, balance, quantity)
    local settings = PotionShopLogic.settings(config)
    if not settings then
        return { ok = false, reason = "shop_disabled" }
    end
    if not PotionShopLogic.isStocked(config, potionId) then
        return { ok = false, reason = "not_sold" }
    end

    local qty = exactQuantity(quantity)
    if not qty then
        return { ok = false, reason = "invalid_quantity" }
    end
    local total = settings.buyPrice * qty
    if total <= 0 then
        return { ok = false, reason = "no_price" }
    end
    if positiveInt(balance) < total then
        return { ok = false, reason = "insufficient_funds", needed = total }
    end
    return { ok = true, quantity = qty, unit = settings.buyPrice, total = total }
end

function PotionShopLogic.sellQuote(config, potionId, owned, quantity)
    local settings = PotionShopLogic.settings(config)
    if not settings then
        return { ok = false, reason = "shop_disabled" }
    end
    if not PotionShopLogic.isStocked(config, potionId) then
        return { ok = false, reason = "not_bought" }
    end

    local have = positiveInt(owned)
    if have < 1 then
        return { ok = false, reason = "none_to_sell" }
    end
    local qty = exactQuantity(quantity)
    if not qty then
        return { ok = false, reason = "invalid_quantity" }
    end
    if have < qty then
        return { ok = false, reason = "insufficient_inventory", needed = qty, owned = have }
    end
    local total = settings.sellPrice * qty
    if total <= 0 then
        return { ok = false, reason = "no_value" }
    end
    return { ok = true, quantity = qty, unit = settings.sellPrice, total = total }
end

return PotionShopLogic
