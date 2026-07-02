--[[
    FocusMath — pure functional core for the player Focus pool (Feature 12).

    No Roblox APIs, no os.time — caller passes elapsed seconds. All values are
    config-driven (see configs/focus.lua). The player has NO health; Focus is the
    only spendable/disruptable player resource.

      canCast(focus, cost)            -> boolean
      cast(focus, cost)               -> { ok, focus, reason? }
      regen(focus, elapsed, config)   -> focus (clamped to [0, focus_max])
      sunder(focus, amount, config)   -> focus (never below 0, never above max)
      clampFocus(focus, config)       -> focus in [0, focus_max]
]]

local FocusMath = {}

local function clamp(value, min, max)
    if value < min then
        return min
    elseif value > max then
        return max
    end
    return value
end

function FocusMath.clampFocus(focus, config)
    return clamp(focus, 0, config.focus_max)
end

-- A power can be cast only if the current Focus covers its full cost.
function FocusMath.canCast(focus, cost)
    return focus >= cost
end

-- Spend `cost` Focus. Rejects with "insufficient_focus" (no partial spend, and
-- the caller must NOT incur a cooldown on rejection — that is the service's job).
function FocusMath.cast(focus, cost)
    if not FocusMath.canCast(focus, cost) then
        return { ok = false, focus = focus, reason = "insufficient_focus" }
    end
    return { ok = true, focus = focus - cost }
end

-- Regenerate over `elapsed` seconds. Clamped to focus_max. If
-- regen_pauses_at_zero is set and Focus is at 0, it stays 0 for this tick.
function FocusMath.regen(focus, elapsed, config)
    if config.regen_pauses_at_zero and focus <= 0 then
        return 0
    end
    local gained = config.regen_per_second * elapsed
    return clamp(focus + gained, 0, config.focus_max)
end

-- A Sundering enemy attack drains Focus. Never drops below 0 (no negative Focus).
function FocusMath.sunder(focus, amount, config)
    return clamp(focus - amount, 0, config.focus_max)
end

return FocusMath
