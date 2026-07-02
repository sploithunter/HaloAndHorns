--[[
    BrewMeter — potion brew-charge math (diminishing sip, taper magnitude, drain).
    Run: mise run test-headless
]]

local BrewMeter = loadModule("src/Shared/Game/BrewMeter.lua")

local function approx(a, b)
    return math.abs(a - b) < 1e-9
end

return function()
    describe("BrewMeter.sip (diminishing — closes a fraction of the gap to full)", function()
        it("a sip closes sipFraction of the remaining gap", function()
            expect(approx(BrewMeter.sip(0, 0.5), 0.5)).to.equal(true)
            expect(approx(BrewMeter.sip(0.5, 0.5), 0.75)).to.equal(true)
            expect(approx(BrewMeter.sip(0.75, 0.5), 0.875)).to.equal(true)
        end)

        it("asymptotes to full — 1000 sips never exceed 1 (no 1000x)", function()
            local c = 0
            for _ = 1, 1000 do
                c = BrewMeter.sip(c, 0.5)
            end
            expect(c <= 1).to.equal(true)
            expect(c > 0.999).to.equal(true) -- close to full but never over
        end)

        it("clamps inputs", function()
            expect(BrewMeter.sip(2, 0.5)).to.equal(1)
            expect(BrewMeter.sip(-1, 0.5)).to.equal(0.5)
        end)
    end)

    describe("BrewMeter.magnitude (taper — fades with the charge, capped)", function()
        it("is linear in charge and capped", function()
            expect(approx(BrewMeter.magnitude(1, 1.5), 1.5)).to.equal(true)
            expect(approx(BrewMeter.magnitude(0.5, 1.5), 0.75)).to.equal(true)
            expect(BrewMeter.magnitude(0, 1.5)).to.equal(0)
        end)

        it("front-loading 1000 sips still maxes at the cap, not 1000x", function()
            local c = 0
            for _ = 1, 1000 do
                c = BrewMeter.sip(c, 0.5)
            end
            expect(BrewMeter.magnitude(c, 1.5) <= 1.5).to.equal(true)
        end)
    end)

    describe("BrewMeter.isFull (a sip at/near full is wasted — don't consume)", function()
        it("true at/above the threshold", function()
            expect(BrewMeter.isFull(0.99, 0.98)).to.equal(true)
            expect(BrewMeter.isFull(0.5, 0.98)).to.equal(false)
        end)
    end)

    describe("BrewMeter.drain / remainingSeconds / isEmpty (duration)", function()
        it("drains toward empty over drainSeconds", function()
            expect(approx(BrewMeter.drain(1, 30, 60), 0.5)).to.equal(true)
            expect(BrewMeter.drain(0.1, 30, 60)).to.equal(0) -- floors at 0
        end)

        it("remainingSeconds = charge × drainSeconds", function()
            expect(approx(BrewMeter.remainingSeconds(0.5, 60), 30)).to.equal(true)
        end)

        it("isEmpty when fully drained (icon goes away)", function()
            expect(BrewMeter.isEmpty(0)).to.equal(true)
            expect(BrewMeter.isEmpty(0.01)).to.equal(false)
        end)

        it("zero drainSeconds never drains (guard)", function()
            expect(BrewMeter.drain(0.5, 10, 0)).to.equal(0.5)
        end)
    end)
end
