--[[
    DailyStreak — pure daily-login streak resolver for the reward spine (Phase 7).

    No Roblox APIs and no clock: the caller passes integer day indices (e.g.
    floor(os.time() / 86400)) so the logic stays deterministic and testable.

      resolve(lastDay, today, streak, config) -> {
        claimable,        -- can the player claim today?
        reason?,          -- "already_claimed_today" when not claimable
        newStreak,        -- streak count after this claim
        claimDay,         -- calendar day to award (1..cycle_length, wrapped)
        reset,            -- true if the streak broke and restarted at 1
      }

    Streak rules (config):
      max_gap_days  -- a gap larger than this resets the streak (default 1 = no misses)
      cycle_length  -- the calendar repeats every N days (default 7)
]]

local DailyStreak = {}

function DailyStreak.resolve(lastDay, today, streak, config)
    config = config or {}
    local maxGap = config.max_gap_days or 1
    local cycle = config.cycle_length or 7
    streak = streak or 0

    if lastDay ~= nil and lastDay == today then
        return {
            claimable = false,
            reason = "already_claimed_today",
            newStreak = streak,
            claimDay = ((streak - 1) % cycle) + 1,
            reset = false,
        }
    end

    local reset = false
    local newStreak
    if lastDay == nil then
        newStreak = 1
    else
        local gap = today - lastDay
        if gap >= 1 and gap <= maxGap then
            newStreak = streak + 1
        else
            newStreak = 1 -- gap too large (or negative clock skew) -> restart
            reset = true
        end
    end

    return {
        claimable = true,
        newStreak = newStreak,
        claimDay = ((newStreak - 1) % cycle) + 1,
        reset = reset,
    }
end

return DailyStreak
