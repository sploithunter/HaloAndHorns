--[[
    BrewJuice — charge ramps for brew HUD / body juice.
    Run: mise run test-headless
]]

local BrewJuice = loadModule("src/Shared/Game/BrewJuice.lua")
local BrewMeter = loadModule("src/Shared/Game/BrewMeter.lua")

local function approx(a, b)
    return math.abs(a - b) < 1e-6
end

return function()
    describe("BrewJuice.ramp", function()
        it("is zero at or below the start", function()
            expect(BrewJuice.ramp(0.4, 0.5, 0.9)).to.equal(0)
            expect(BrewJuice.ramp(0.5, 0.5, 0.9)).to.equal(0)
        end)

        it("is one at or past full", function()
            expect(BrewJuice.ramp(0.9, 0.5, 0.9)).to.equal(1)
            expect(BrewJuice.ramp(1, 0.5, 0.9)).to.equal(1)
        end)

        it("is linear between start and full", function()
            expect(approx(BrewJuice.ramp(0.7, 0.5, 0.9), 0.5)).to.equal(true)
        end)
    end)

    describe("BrewJuice.sample (sip ladder: 0.5 → 0.75 → 0.875)", function()
        local knobs = {
            glow_at = 0.05,
            glow_full = 0.55,
            shake_at = 0.62,
            shake_full = 0.92,
            leak_at = 0.74,
            leak_full = 0.98,
        }

        it("first sip glows and does not shake", function()
            local one = BrewJuice.sample(BrewMeter.sip(0, 0.5), knobs)
            expect(approx(one.charge, 0.5)).to.equal(true)
            expect(one.glow > 0.8).to.equal(true)
            expect(one.shake).to.equal(0)
            expect(one.leak).to.equal(0)
        end)

        it("second sip starts the shake and a hint of leak", function()
            local two = BrewJuice.sample(BrewMeter.sip(0.5, 0.5), knobs)
            expect(approx(two.charge, 0.75)).to.equal(true)
            expect(two.shake > 0).to.equal(true)
            expect(two.leak > 0).to.equal(true)
        end)

        it("five sips are almost full leak", function()
            local c = 0
            for _ = 1, 5 do
                c = BrewMeter.sip(c, 0.5)
            end
            local five = BrewJuice.sample(c, knobs)
            expect(five.shake > 0.9).to.equal(true)
            expect(five.leak > 0.8).to.equal(true)
        end)

        it("empty charge is dark and still", function()
            local empty = BrewJuice.sample(0, knobs)
            expect(empty.glow).to.equal(0)
            expect(empty.shake).to.equal(0)
            expect(empty.leak).to.equal(0)
        end)
    end)
end
