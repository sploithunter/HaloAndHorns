--[[
    CrowdControl — shared timing rules for roots, disarms, and full holds.

    Root: movement lock only.
    Disarm: action lock only; movement remains available.
    Hold: full mez; the affected unit cannot move or perform active actions.

    Until values use epoch seconds (os.time) throughout combat. Keeping the comparisons and
    refresh rule here prevents enemy and pet consumers from drifting at the expiry boundary.
]]

local CrowdControl = {}

function CrowdControl.isActive(untilTime, now)
    return (tonumber(untilTime) or 0) > (tonumber(now) or 0)
end

function CrowdControl.isHeld(heldUntil, now)
    return CrowdControl.isActive(heldUntil, now)
end

function CrowdControl.isDisarmed(disarmedUntil, now)
    return CrowdControl.isActive(disarmedUntil, now)
end

function CrowdControl.canAct(heldUntil, now)
    return not CrowdControl.isHeld(heldUntil, now)
end

function CrowdControl.isActionLocked(heldUntil, disarmedUntil, now)
    return CrowdControl.isHeld(heldUntil, now) or CrowdControl.isDisarmed(disarmedUntil, now)
end

function CrowdControl.canTakeAction(heldUntil, disarmedUntil, now)
    return not CrowdControl.isActionLocked(heldUntil, disarmedUntil, now)
end

function CrowdControl.isImmobilized(rootedUntil, heldUntil, now)
    return CrowdControl.isActive(rootedUntil, now) or CrowdControl.isHeld(heldUntil, now)
end

function CrowdControl.extend(currentUntil, now, duration)
    local candidate = (tonumber(now) or 0) + math.max(0, tonumber(duration) or 0)
    return math.max(tonumber(currentUntil) or 0, candidate)
end

return CrowdControl
