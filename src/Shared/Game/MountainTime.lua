--[[
    MountainTime — pure UTC -> America/Denver (Mountain) conversion with US DST.

    Roblox servers run in UTC (os.date("!*t")). Pet Realm's recurring events are scheduled
    in MOUNTAIN time ("ColoradoPlays" — Mineral Monday at midnight Mountain, not UTC), so any
    weekday/hour decision must convert first.

    US Mountain DST (since 2007):
      • MDT (UTC-6) from 02:00 on the 2nd Sunday of March
      • MST (UTC-7) from 02:00 on the 1st Sunday of November
    DST membership is decided from the calendar date (the 1-hour transition window doesn't
    matter for day-long events), so this stays a pure function of a UTC time — no reliance on
    os.time() / the host machine's timezone, which keeps the headless spec deterministic.

    wday convention matches os.date: 1 = Sunday .. 7 = Saturday.
]]

local MountainTime = {}

local STANDARD_OFFSET = -7 -- MST
local DST_OFFSET = -6 -- MDT

-- wday (1=Sun..7=Sat) of day 1 of a month, given any day-of-month and its wday.
local function wdayOfFirst(day, wday)
    local w = ((wday - 1 - (day - 1)) % 7 + 7) % 7 -- 0=Sun..6=Sat
    return w + 1
end

-- Day-of-month of the first Sunday, for a month whose day 1 falls on wdayFirst (1=Sun).
local function firstSundayDate(wdayFirst)
    return 1 + ((8 - wdayFirst) % 7)
end

-- Is the given Mountain-local date in DST? `p` is an os.date("*t")-shaped table with valid
-- month / day / wday.
local function isDST(p)
    local m = p.month
    if m < 3 or m > 11 then
        return false
    end
    if m > 3 and m < 11 then
        return true
    end
    local firstSunday = firstSundayDate(wdayOfFirst(p.day, p.wday))
    if m == 3 then
        return p.day >= firstSunday + 7 -- on/after the 2nd Sunday
    else -- November: DST only BEFORE the first Sunday
        return p.day < firstSunday
    end
end

-- UTC unix time -> Mountain date/time table (os.date("*t") shape) plus isDST / offsetHours.
function MountainTime.fromUtc(utcTime)
    utcTime = tonumber(utcTime) or os.time()
    -- Pin the calendar date with the standard offset first (the DST transition is at 02:00,
    -- nowhere near midnight, so this never picks the wrong day), then refine the offset.
    local approx = os.date("!*t", utcTime + STANDARD_OFFSET * 3600)
    local dst = isDST(approx)
    local offset = dst and DST_OFFSET or STANDARD_OFFSET
    local p = os.date("!*t", utcTime + offset * 3600)
    p.isDST = dst
    p.offsetHours = offset
    return p
end

function MountainTime.weekday(utcTime)
    return MountainTime.fromUtc(utcTime).wday
end

function MountainTime.hour(utcTime)
    return MountainTime.fromUtc(utcTime).hour
end

-- exposed for the headless spec (pure helpers)
MountainTime._isDST = isDST
MountainTime._firstSundayDate = firstSundayDate
MountainTime._wdayOfFirst = wdayOfFirst

return MountainTime
