--[[
    TradeLogic — pure functional core for trading (Feature 19).

    No Roblox APIs. The service supplies item descriptors; these rules decide what
    can be offered and whether a trade may execute.

      canAddItem(category, item, config)        -> { ok, reason? }
      canExecute(offerA, offerB)                -> { ok, reason? }
      auditRecord(playerA, playerB, offerA, offerB, timestamp) -> table
      invitePrivacy(value, config)              -> "everyone"|"friends"|"off"
      invitePrivacyLabel(value, config)         -> string
      canSendInvite(ctx)                        -> boolean, reason?

    An `offer` is { items = {...}, confirmed = boolean }. An `item` is
    { category = "pets"|"currencies"|"cosmetics", id, locked? }.
]]

local TradeLogic = {}

function TradeLogic.newInvite(fromUserId, requestedAt, timeoutSeconds)
    local startedAt = tonumber(requestedAt) or 0
    local duration = math.max(1, tonumber(timeoutSeconds) or 30)
    return {
        from = fromUserId,
        requestedAt = startedAt,
        expiresAt = startedAt + duration,
    }
end

function TradeLogic.inviteExpired(invite, now)
    return type(invite) ~= "table" or (tonumber(now) or 0) >= (tonumber(invite.expiresAt) or 0)
end

local function privacyModes(config)
    return type(config) == "table"
            and type(config.invite_privacy) == "table"
            and config.invite_privacy
        or nil
end

function TradeLogic.invitePrivacy(value, config)
    local privacy = privacyModes(config)
    local default = (privacy and type(privacy.default) == "string" and privacy.default)
        or "everyone"
    if
        type(value) == "string"
        and privacy
        and type(privacy.modes) == "table"
        and privacy.modes[value]
    then
        return value
    end
    if value == "everyone" or value == "friends" or value == "off" then
        return value
    end
    if privacy and type(privacy.modes) == "table" and privacy.modes[default] then
        return default
    end
    return "everyone"
end

function TradeLogic.invitePrivacyLabel(value, config)
    local id = TradeLogic.invitePrivacy(value, config)
    local privacy = privacyModes(config)
    local mode = privacy and type(privacy.modes) == "table" and privacy.modes[id]
    if type(mode) == "table" and type(mode.list_label) == "string" then
        return mode.list_label
    end
    if type(mode) == "table" and type(mode.display) == "string" then
        return mode.display
    end
    if id == "everyone" then
        return "Everyone"
    elseif id == "off" then
        return "Requests off"
    end
    return "Friends only"
end

-- ctx: targetPrivacy, areFriends, config
function TradeLogic.canSendInvite(ctx)
    ctx = type(ctx) == "table" and ctx or {}
    local privacy = TradeLogic.invitePrivacy(ctx.targetPrivacy, ctx.config)
    if privacy == "off" then
        return false, "invites_off"
    end
    if privacy == "friends" and ctx.areFriends ~= true then
        return false, "friends_only"
    end
    return true
end

function TradeLogic.canAddItem(category, item, config)
    local tradeable = config and config.tradeable or {}
    -- Currencies are non-tradeable EXCEPT an explicit per-currency allowlist
    -- (config.tradeable_currencies = { gems = true }). Pet Realm design: the four
    -- biome coins are soulbound; gems are the only trade currency.
    if category == "currencies" then
        local allow = config and config.tradeable_currencies or {}
        local id = item and item.id
        if id and allow[id] == true then
            return { ok = true }
        end
        return { ok = false, reason = "currencies_not_tradeable" }
    end
    if tradeable[category] == false then
        return { ok = false, reason = "not_tradeable" }
    end
    if tradeable[category] ~= true then
        return { ok = false, reason = "not_tradeable" }
    end
    if category == "pets" and item and item.locked == true then
        return { ok = false, reason = "pet_locked" }
    end
    return { ok = true }
end

-- A trade executes only when BOTH sides have confirmed.
function TradeLogic.canExecute(offerA, offerB)
    if not (offerA and offerB) then
        return { ok = false, reason = "incomplete_trade" }
    end
    if offerA.confirmed ~= true or offerB.confirmed ~= true then
        return { ok = false, reason = "not_both_confirmed" }
    end
    return { ok = true }
end

-- Build a trade-history audit record (both players, items, timestamp).
function TradeLogic.auditRecord(playerA, playerB, offerA, offerB, timestamp)
    return {
        a = playerA,
        b = playerB,
        a_items = (offerA and offerA.items) or {},
        b_items = (offerB and offerB.items) or {},
        timestamp = timestamp,
    }
end

return TradeLogic
