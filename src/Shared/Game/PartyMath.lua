--[[
    PartyMath — pure functional core for group play (Feature 18).

    No Roblox APIs. Difficulty scaling reuses the combat group-scaling curve
    (CombatMath.groupScaledHp) — exposed here too for convenience.

      canJoin(currentSize, maxSize)        -> boolean
      scaledHp(baseHp, partySize, perExtra)-> integer
      splitLoot(loot, partySize)           -> { [currency] = perPlayerAmount }
      attribution(contributions)           -> { fractions = {id=frac}, mvp, total }
      inviteExpired(invite, now, timeout)  -> boolean
      invitePrivacy(value, cfg)            -> "everyone"|"friends"|"off"
      invitePrivacyLabel(value, cfg)       -> string
      canSendInvite(ctx)                   -> ok, reason
      canAcceptInvite(ctx)                 -> ok, reason
]]

local PartyMath = {}

function PartyMath.canJoin(currentSize, maxSize)
    return (tonumber(currentSize) or 0) < (tonumber(maxSize) or 0)
end

-- Keep invitation lifetime testable without Roblox scheduling. PartyService supplies os.clock().
function PartyMath.inviteExpired(invite, now, timeoutSeconds)
    if type(invite) ~= "table" or type(invite.at) ~= "number" then
        return true
    end
    local timeout = math.max(1, tonumber(timeoutSeconds) or 30)
    return ((tonumber(now) or invite.at) - invite.at) >= timeout
end

local function privacyModes(cfg)
    return type(cfg) == "table" and type(cfg.invite_privacy) == "table" and cfg.invite_privacy
        or nil
end

function PartyMath.invitePrivacy(value, cfg)
    local privacy = privacyModes(cfg)
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
    if type(privacy) == "table" and type(privacy.modes) == "table" and privacy.modes[default] then
        return default
    end
    return "everyone"
end

function PartyMath.invitePrivacyLabel(value, cfg)
    local id = PartyMath.invitePrivacy(value, cfg)
    local privacy = privacyModes(cfg)
    local mode = privacy and type(privacy.modes) == "table" and privacy.modes[id]
    if type(mode) == "table" and type(mode.list_label) == "string" then
        return mode.list_label
    end
    if type(mode) == "table" and type(mode.display) == "string" then
        return mode.display
    end
    if id == "friends" then
        return "Friends only"
    elseif id == "off" then
        return "Invites off"
    end
    return "Everyone"
end

-- ctx: fromInRange, targetInRange, targetPrivacy, areFriends, cfg
function PartyMath.canSendInvite(ctx)
    ctx = type(ctx) == "table" and ctx or {}
    if ctx.fromInRange == true then
        return false, "in_range"
    end
    if ctx.targetInRange == true then
        return false, "target_in_range"
    end
    local privacy = PartyMath.invitePrivacy(ctx.targetPrivacy, ctx.cfg)
    if privacy == "off" then
        return false, "invites_off"
    end
    if privacy == "friends" and ctx.areFriends ~= true then
        return false, "friends_only"
    end
    return true
end

function PartyMath.canAcceptInvite(ctx)
    ctx = type(ctx) == "table" and ctx or {}
    if ctx.fromInRange == true or ctx.targetInRange == true then
        return false, "in_range"
    end
    return true
end

-- Enemy HP scaling with party size (solo = unscaled). Mirrors CombatMath.
function PartyMath.scaledHp(baseHp, partySize, perExtra)
    local size = math.max(1, tonumber(partySize) or 1)
    return math.floor((tonumber(baseHp) or 0) * (1 + (tonumber(perExtra) or 0) * (size - 1)) + 0.5)
end

-- Split a loot table equally among the party (floor per player).
function PartyMath.splitLoot(loot, partySize)
    local n = math.max(1, tonumber(partySize) or 1)
    local out = {}
    for currency, amount in pairs(loot or {}) do
        out[currency] = math.floor((tonumber(amount) or 0) / n)
    end
    return out
end

-- Damage attribution: proportional fractions per player + the MVP (top contributor).
function PartyMath.attribution(contributions)
    local total = 0
    for _, dmg in pairs(contributions or {}) do
        total += math.max(0, tonumber(dmg) or 0)
    end
    local fractions = {}
    local mvp, mvpDmg = nil, -1
    for id, dmg in pairs(contributions or {}) do
        local d = math.max(0, tonumber(dmg) or 0)
        fractions[id] = total > 0 and (d / total) or 0
        if d > mvpDmg then
            mvp, mvpDmg = id, d
        end
    end
    return { fractions = fractions, mvp = mvp, total = total }
end

return PartyMath
