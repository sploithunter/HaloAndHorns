--[[
    PotionDescribe — pure, config-derived player-facing potion copy.

    The hotbar, inventory, and any future potion surface should describe the same live definition
    instead of maintaining UI-owned strings. All numbers come from configs/potions.lua.
]]

local PotionDescribe = {}

local function percent(value)
    local n = math.max(0, (tonumber(value) or 0) * 100)
    local rounded = math.floor(n + 0.5)
    if math.abs(n - rounded) < 0.001 then
        return tostring(rounded) .. "%"
    end
    return string.format("%.1f%%", n)
end

local function seconds(value)
    local n = math.max(0, tonumber(value) or 0)
    local rounded = math.floor(n + 0.5)
    if math.abs(n - rounded) < 0.001 then
        return tostring(rounded) .. "s"
    end
    return string.format("%.1fs", n)
end

local function typeLabel(potion, meter)
    if potion.throw == true or meter.target == "enemy" then
        return "Thrown Enemy Debuff"
    end
    local badge = meter.badge or {}
    if badge.target == "team_aoe" then
        return "Team Buff Potion"
    end
    if meter.target == "player" then
        return "Player Buff Potion"
    end
    return "Potion"
end

function PotionDescribe.describe(config, potionId)
    local potion = config and config.potions and config.potions[potionId]
    local meter = potion and config.meters and config.meters[potion.meter]
    if not (potion and meter) then
        return nil
    end

    local lines = {
        string.format(
            "%s: up to +%s at full charge",
            tostring(meter.display_name or potion.meter or "Effect"),
            percent(meter.cap)
        ),
        "Full meter drains in " .. seconds(meter.drain_seconds),
        "One use refills " .. percent(potion.sip_fraction) .. " of missing charge",
    }
    if meter.maintain_at ~= nil then
        lines[#lines + 1] = "LOCK auto-uses below " .. percent(meter.maintain_at) .. " charge"
    end

    return {
        name = potion.display_name or tostring(potionId):gsub("_", " "),
        type = typeLabel(potion, meter),
        summary = potion.description or "",
        lines = lines,
        meter = potion.meter,
    }
end

return PotionDescribe
