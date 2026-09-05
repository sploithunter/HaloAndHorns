--[[
    HoverboardLogic — pure eligibility, speed, and suppress rules.

    Server owns mount state; this module decides whether that state is allowed
    and how fast the rider should move. Presentation stays on the client.
]]

local HallOfWorldsLogic = require(script.Parent.HallOfWorldsLogic)

local HoverboardLogic = {}

function HoverboardLogic.isEligible(claimedLevel, tutorialCompleted, unlock, highestMergeWave)
    if
        unlock
        and tonumber(unlock.merge_wave)
        and (tonumber(highestMergeWave) or 0) >= unlock.merge_wave
    then
        return true
    end
    local ok = HallOfWorldsLogic.meetsUnlock(claimedLevel, tutorialCompleted, unlock)
    return ok == true
end

function HoverboardLogic.clampSpeedScale(scale, knobs)
    knobs = type(knobs) == "table" and knobs or {}
    local lo = tonumber(knobs.min_scale) or 0.2
    local hi = tonumber(knobs.max_scale) or 1
    if hi < lo then
        hi = lo
    end
    local fallback = tonumber(knobs.default_scale) or 1
    local n = tonumber(scale)
    if not n then
        n = fallback
    end
    if n < lo then
        return lo
    end
    if n > hi then
        return hi
    end
    return n
end

function HoverboardLogic.mountedSpeed(baseWalkSpeed, speedMultiplier, cruiseSpeed, speedScale)
    local normal = math.max(0, tonumber(baseWalkSpeed) or 0)
        * math.max(0, tonumber(speedMultiplier) or 1)
    local scale = tonumber(speedScale)
    if not scale or scale <= 0 then
        scale = 1
    end
    local cruise = math.max(0, tonumber(cruiseSpeed) or 0) * scale
    return math.max(normal, cruise)
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

-- Resolve planar riding input without mixing coordinate spaces. Raw ControlModule input is
-- camera-relative, but Humanoid.MoveDirection is already world-relative. Some place/controller
-- combinations do not expose a Vector3 from GetMoveVector; in that case the world fallback must
-- be used directly or W/A are rotated through the camera a second time.
function HoverboardLogic.planarMoveDirection(
    rawX,
    rawZ,
    rightX,
    rightZ,
    lookX,
    lookZ,
    fallbackX,
    fallbackZ
)
    local worldX
    local worldZ
    local rawMagnitude = math.sqrt((tonumber(rawX) or 0) ^ 2 + (tonumber(rawZ) or 0) ^ 2)
    if tonumber(rawX) and tonumber(rawZ) and rawMagnitude >= 0.05 then
        local rightMagnitude = math.sqrt((tonumber(rightX) or 0) ^ 2 + (tonumber(rightZ) or 0) ^ 2)
        local lookMagnitude = math.sqrt((tonumber(lookX) or 0) ^ 2 + (tonumber(lookZ) or 0) ^ 2)
        if rightMagnitude >= 0.05 and lookMagnitude >= 0.05 then
            local normalizedRightX = rightX / rightMagnitude
            local normalizedRightZ = rightZ / rightMagnitude
            local normalizedLookX = lookX / lookMagnitude
            local normalizedLookZ = lookZ / lookMagnitude
            worldX = normalizedRightX * rawX - normalizedLookX * rawZ
            worldZ = normalizedRightZ * rawX - normalizedLookZ * rawZ
        end
    end

    if worldX == nil or worldZ == nil then
        worldX = tonumber(fallbackX) or 0
        worldZ = tonumber(fallbackZ) or 0
    end
    local magnitude = math.sqrt(worldX ^ 2 + worldZ ^ 2)
    if magnitude < 0.08 then
        return 0, 0
    end
    return worldX / magnitude, worldZ / magnitude
end

function HoverboardLogic.shouldSuppress(flags)
    flags = type(flags) == "table" and flags or {}
    return flags.in_mission == true
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

-- Auto-grant used to stamp every free catalog skate. If a save owns the
-- complete free set, keep only the starter plus paid boards.
function HoverboardLogic.stripCompleteFreeSet(owned, catalog, defaultSkin)
    owned = type(owned) == "table" and owned or {}
    catalog = type(catalog) == "table" and catalog or {}
    local freeIds = {}
    local freeCount = 0
    local ownedFree = 0
    for skinId, offer in pairs(catalog) do
        if type(skinId) == "string" and HoverboardLogic.offerKind(offer) == "free" then
            freeIds[skinId] = true
            freeCount += 1
            if owned[skinId] == true then
                ownedFree += 1
            end
        end
    end
    if freeCount < 2 or ownedFree < freeCount then
        return owned
    end
    local nextOwned = {}
    for skinId, value in pairs(owned) do
        if value == true and freeIds[skinId] ~= true then
            nextOwned[skinId] = true
        end
    end
    if type(defaultSkin) == "string" and defaultSkin ~= "" then
        nextOwned[defaultSkin] = true
    end
    return nextOwned
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
    local speedScale = tonumber(save.speed_scale)
    return {
        owned = owned,
        equipped = equipped,
        speed_scale = speedScale,
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

-- Client buy gate. Gem cards always confirm the spend first; funds are
-- checked after that confirm so a broke click still sees the price.
function HoverboardLogic.gemBuyStep(offer, gems, confirmed)
    local kind = HoverboardLogic.offerKind(offer)
    if kind == "robux" then
        return "robux", 0
    end
    if kind ~= "gems" then
        return "take", 0
    end
    local price = math.max(0, math.floor(tonumber(offer and offer.price) or 0))
    if confirmed ~= true then
        return "confirm", price
    end
    local have = tonumber(gems) or 0
    if price > 0 and have < price then
        return "insufficient_funds", price
    end
    return "buy", price
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
                -- Kade's Robux boards are permanent game passes. Preserve the
                -- pass config key so the server can resolve the live Roblox ID
                -- and the client can request its managed/regional price.
                pass = type(offer.pass) == "string" and offer.pass or nil,
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
