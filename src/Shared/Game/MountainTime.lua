--[[
    MountainTime — pure UTC -> America/Denver (Mountain) conversion with US DST.

    Roblox servers run in UTC (os.date("!*t")). Pet Realm's recurring events are scheduled
    in MOUNTAIN time ("ColoradoPlays" — Mineral Monday at midnight Mountain, not UTC), so any
    weekday/hour decision must convert first.

    US Mountain DST (since 2007):
      • MDT (UTC-6) from 02:00 on the 2nd Sunday of March
      • MST (UTC-7) from 02:00 on the 1st Sunday of November
    The transition instants are resolved exactly in UTC, while all date construction stays
    independent of the host machine's timezone. That keeps midnight round boundaries correct
    on 23-hour and 25-hour DST days and keeps the headless specs deterministic.

    wday convention matches os.date: 1 = Sunday .. 7 = Saturday.
]]

local MountainTime = {}

local STANDARD_OFFSET = -7 -- MST
local DST_OFFSET = -6 -- MDT

-- Days since 1970-01-01 for a Gregorian civil date. Keeping this conversion pure avoids
-- os.time(table), whose result depends on the developer machine's local timezone.
local function daysFromCivil(year, month, day)
    year -= if month <= 2 then 1 else 0
    local era = math.floor(year / 400)
    local yearOfEra = year - era * 400
    local shiftedMonth = month + if month > 2 then -3 else 9
    local dayOfYear = math.floor((153 * shiftedMonth + 2) / 5) + day - 1
    local dayOfEra = yearOfEra * 365
        + math.floor(yearOfEra / 4)
        - math.floor(yearOfEra / 100)
        + dayOfYear
    return era * 146097 + dayOfEra - 719468
end

local function utcTimestamp(year, month, day, hour, minute, second)
    return daysFromCivil(year, month, day) * 86400
        + (hour or 0) * 3600
        + (minute or 0) * 60
        + (second or 0)
end

local function civilWday(year, month, day)
    -- 1970-01-01 was Thursday (os.date wday 5).
    return ((daysFromCivil(year, month, day) + 4) % 7) + 1
end

-- Day-of-month of the first Sunday, for a month whose day 1 falls on wdayFirst (1=Sun).
local function firstSundayDate(wdayFirst)
    return 1 + ((8 - wdayFirst) % 7)
end

-- Compatibility helpers for callers/tests that reason about a whole Mountain-local date.
-- Runtime timestamp conversion below uses the exact UTC transition instant instead.
local function wdayOfFirst(day, wday)
    local w = ((wday - 1 - (day - 1)) % 7 + 7) % 7 -- 0=Sun..6=Sat
    return w + 1
end

local function isDST(localDate)
    local month = localDate.month
    if month < 3 or month > 11 then
        return false
    end
    if month > 3 and month < 11 then
        return true
    end
    local firstSunday = firstSundayDate(wdayOfFirst(localDate.day, localDate.wday))
    if month == 3 then
        return localDate.day >= firstSunday + 7
    end
    return localDate.day < firstSunday
end

local function transitionUtc(year, month, sundayIndex, utcHour)
    local firstSunday = firstSundayDate(civilWday(year, month, 1))
    return utcTimestamp(year, month, firstSunday + (sundayIndex - 1) * 7, utcHour, 0, 0)
end

local function isDSTUtc(utcTime)
    local year = os.date("!*t", utcTime).year
    -- 02:00 MST = 09:00 UTC on the second Sunday in March.
    local startsAt = transitionUtc(year, 3, 2, 9)
    -- 02:00 MDT = 08:00 UTC on the first Sunday in November.
    local endsAt = transitionUtc(year, 11, 1, 8)
    return utcTime >= startsAt and utcTime < endsAt
end

-- UTC unix time -> Mountain date/time table (os.date("*t") shape) plus isDST / offsetHours.
function MountainTime.fromUtc(utcTime)
    utcTime = tonumber(utcTime) or os.time()
    local dst = isDSTUtc(utcTime)
    local offset = dst and DST_OFFSET or STANDARD_OFFSET
    local p = os.date("!*t", utcTime + offset * 3600)
    p.isDST = dst
    p.offsetHours = offset
    return p
end

-- UTC timestamp for 00:00 at the start of the containing America/Denver calendar day.
-- Trying both legal offsets is deliberate: midnight is still MST on spring-forward day
-- and still MDT on fall-back day, so a date-only DST approximation is not precise enough.
function MountainTime.startOfDayUtc(utcTime)
    local localTime = MountainTime.fromUtc(utcTime)
    local localMidnight = utcTimestamp(localTime.year, localTime.month, localTime.day, 0, 0, 0)
    for _, offset in ipairs({ STANDARD_OFFSET, DST_OFFSET }) do
        local candidate = localMidnight - offset * 3600
        local resolved = MountainTime.fromUtc(candidate)
        if
            resolved.year == localTime.year
            and resolved.month == localTime.month
            and resolved.day == localTime.day
            and resolved.hour == 0
            and resolved.min == 0
        then
            return candidate
        end
    end
    return localMidnight - localTime.offsetHours * 3600
end

function MountainTime.nextStartOfDayUtc(utcTime)
    local startedAt = MountainTime.startOfDayUtc(utcTime)
    -- Thirty-six absolute hours always lands inside the following Mountain calendar day,
    -- including the 23-hour spring and 25-hour fall transition days.
    return MountainTime.startOfDayUtc(startedAt + 36 * 60 * 60)
end

function MountainTime.weekday(utcTime)
    return MountainTime.fromUtc(utcTime).wday
end

function MountainTime.hour(utcTime)
    return MountainTime.fromUtc(utcTime).hour
end

-- exposed for the headless spec (pure helpers)
MountainTime._isDST = isDST
MountainTime._isDSTUtc = isDSTUtc
MountainTime._firstSundayDate = firstSundayDate
MountainTime._wdayOfFirst = wdayOfFirst
MountainTime._utcTimestamp = utcTimestamp

return MountainTime
