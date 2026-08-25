--[[
    HealingSuppression — pure timing rules for the enemy anti-heal status.

    Drain and dedicated anti-heal auras stamp ATTRIBUTE on an enemy. Active suppression blocks
    incoming HP heals and passive enemy regeneration, but never deals damage or interferes with
    scripted spawn/phase-reset writes. Reapplication only extends the window.
]]

local HealingSuppression = {}

HealingSuppression.ATTRIBUTE = "HealSuppressedUntil"

function HealingSuppression.isActive(untilValue, now)
    return (tonumber(untilValue) or 0) > (tonumber(now) or 0)
end

function HealingSuppression.extend(untilValue, now, duration)
    local current = tonumber(untilValue) or 0
    local incoming = (tonumber(now) or 0) + math.max(0, tonumber(duration) or 0)
    return math.max(current, incoming)
end

function HealingSuppression.remaining(untilValue, now)
    return math.max(0, (tonumber(untilValue) or 0) - (tonumber(now) or 0))
end

return HealingSuppression
