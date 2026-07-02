--[[
    MountainTime — UTC -> America/Denver with US DST.
    Run: mise run test-headless
]]

local MountainTime = loadModule("src/Shared/Game/MountainTime.lua")

return function()
    describe("isDST by month", function()
        it("deep winter is standard time", function()
            expect(MountainTime._isDST({ month = 1, day = 15, wday = 1 })).to.equal(false)
            expect(MountainTime._isDST({ month = 12, day = 25, wday = 1 })).to.equal(false)
        end)
        it("summer is daylight time", function()
            expect(MountainTime._isDST({ month = 6, day = 21, wday = 1 })).to.equal(true)
            expect(MountainTime._isDST({ month = 4, day = 1, wday = 4 })).to.equal(true)
        end)
    end)

    describe("March boundary (DST starts 2nd Sunday)", function()
        -- March 2026: day 1 is a Sunday, so the 2nd Sunday is March 8.
        it("the Saturday before is still MST", function()
            expect(MountainTime._isDST({ month = 3, day = 7, wday = 7 })).to.equal(false)
        end)
        it("the 2nd Sunday flips to MDT", function()
            expect(MountainTime._isDST({ month = 3, day = 8, wday = 1 })).to.equal(true)
        end)
    end)

    describe("November boundary (DST ends 1st Sunday)", function()
        -- A November whose day 1 is a Wednesday -> first Sunday is the 5th.
        it("before the first Sunday is still MDT", function()
            expect(MountainTime._isDST({ month = 11, day = 1, wday = 4 })).to.equal(true)
        end)
        it("the first Sunday falls back to MST", function()
            expect(MountainTime._isDST({ month = 11, day = 5, wday = 1 })).to.equal(false)
        end)
    end)

    describe("firstSundayDate / wdayOfFirst", function()
        it("a month starting on Sunday has its first Sunday on the 1st", function()
            expect(MountainTime._firstSundayDate(1)).to.equal(1)
        end)
        it("a month starting on Monday has its first Sunday on the 7th", function()
            expect(MountainTime._firstSundayDate(2)).to.equal(7)
        end)
        it("derives day-1 weekday from any date", function()
            -- the 8th being a Sunday (wday 1) means the 1st was also a Sunday
            expect(MountainTime._wdayOfFirst(8, 1)).to.equal(1)
        end)
    end)

    describe("fromUtc / weekday on a known timestamp", function()
        -- 1700000000 = 2023-11-14 22:13:20 UTC (a Tuesday). Nov 14 is past the first Sunday
        -- (Nov 5 2023) so Mountain is MST (UTC-7): 15:13 on Tuesday.
        it("converts to MST and the right weekday/hour", function()
            local p = MountainTime.fromUtc(1700000000)
            expect(p.isDST).to.equal(false)
            expect(p.offsetHours).to.equal(-7)
            expect(p.wday).to.equal(3) -- Tuesday
            expect(p.hour).to.equal(15)
        end)
        it("weekday() is the Mountain weekday", function()
            expect(MountainTime.weekday(1700000000)).to.equal(3)
        end)
    end)
end
