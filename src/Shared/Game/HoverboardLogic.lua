--[[
    HoverboardLogic — pure eligibility, speed, and suppress rules.

    Server owns mount state; this module decides whether that state is allowed
    and how fast the rider should move. Presentation stays on the client.
]]

local HallOfWorldsLogic = require(script.Parent.HallOfWorldsLogic)

local HoverboardLogic = {}

function HoverboardLogic.isEligible(claimedLevel, tutorialCompleted, unlock)
    local ok = HallOfWorldsLogic.meetsUnlock(claimedLevel, tutorialCompleted, unlock)
    return ok == true
end

function HoverboardLogic.mountedSpeed(baseWalkSpeed, speedMultiplier, cruiseSpeed)
    local normal = math.max(0, tonumber(baseWalkSpeed) or 0)
        * math.max(0, tonumber(speedMultiplier) or 1)
    return math.max(normal, math.max(0, tonumber(cruiseSpeed) or 0))
end

function HoverboardLogic.skinCruiseSpeed(skin, defaultCruise)
    local base = tonumber(defaultCruise) or 64
    local explicit = tonumber(skin and skin.cruise_speed)
    if explicit and explicit > 0 then
        return explicit
    end
    local mult = tonumber(skin and skin.cruise_multiplier)
    if mult and mult > 0 then
        return base * mult
    end
    return base
end

function HoverboardLogic.shouldSuppress(flags)
    flags = type(flags) == "table" and flags or {}
    return flags.in_combat == true
        or flags.in_mission == true
        or flags.dead == true
        or flags.teleporting == true
        or flags.precision_interact == true
end

function HoverboardLogic.canMount(eligible, suppressed)
    return eligible == true and suppressed ~= true
end

function HoverboardLogic.emptySave()
    return {
        owned = {},
        equipped = nil,
    }
end

function HoverboardLogic.normalizeSave(save, defaultSkin)
    save = type(save) == "table" and save or {}
    local owned = {}
    if type(save.owned) == "table" then
        for key, value in pairs(save.owned) do
            if type(key) == "string" and value == true then
                owned[key] = true
            end
        end
    end
    if type(defaultSkin) == "string" and defaultSkin ~= "" then
        owned[defaultSkin] = true
    end
    local equipped = save.equipped
    if type(equipped) ~= "string" or owned[equipped] ~= true then
        equipped = defaultSkin
    end
    return {
        owned = owned,
        equipped = equipped,
    }
end

function HoverboardLogic.isOwned(owned, skinId)
    return type(skinId) == "string" and type(owned) == "table" and owned[skinId] == true
end

function HoverboardLogic.offerKind(offer)
    if type(offer) ~= "table" then
        return "free"
    end
    local kind = offer.kind
    if kind == "gems" or kind == "robux" or kind == "free" then
        return kind
    end
    if (tonumber(offer.price) or 0) <= 0 then
        return "free"
    end
    return "free"
end

function HoverboardLogic.canBuy(owned, skinId, offer, balances)
    if type(skinId) ~= "string" or skinId == "" then
        return false, "invalid_skin"
    end
    if HoverboardLogic.isOwned(owned, skinId) then
        return false, "already_owned"
    end
    offer = type(offer) == "table" and offer or {}
    local kind = HoverboardLogic.offerKind(offer)
    if kind == "free" then
        return true, 0
    end
    if kind == "robux" then
        return true, "robux"
    end
    if kind == "gems" then
        local cost = math.max(0, math.floor(tonumber(offer.price) or 0))
        local gems = tonumber(balances and balances.gems) or 0
        if cost > 0 and gems < cost then
            return false, "insufficient_gems"
        end
        return true, cost
    end
    return false, "invalid_offer"
end

function HoverboardLogic.canEquip(owned, skinId)
    if not HoverboardLogic.isOwned(owned, skinId) then
        return false, "not_owned"
    end
    return true
end

function HoverboardLogic.catalogEntries(skins, shopCatalog)
    local entries = {}
    if type(skins) ~= "table" or type(shopCatalog) ~= "table" then
        return entries
    end
    for skinId, offer in pairs(shopCatalog) do
        local skin = skins[skinId]
        if type(skin) == "table" and type(offer) == "table" then
            table.insert(entries, {
                id = skinId,
                display_name = skin.display_name or skinId,
                icon = skin.icon,
                kind = HoverboardLogic.offerKind(offer),
                price = math.max(0, math.floor(tonumber(offer.price) or 0)),
                price_robux = math.max(0, math.floor(tonumber(offer.price_robux) or 0)),
                product = type(offer.product) == "string" and offer.product or nil,
                on_sale = offer.on_sale == true,
                order = tonumber(offer.order) or 99,
            })
        end
    end
    table.sort(entries, function(a, b)
        if a.order == b.order then
            return a.id < b.id
        end
        return a.order < b.order
    end)
    return entries
end

return HoverboardLogic
