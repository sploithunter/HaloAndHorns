--[[
    VulnMark — [unit] additive vulnerability marks (the pyro clobber fix).
    Run: mise run test-headless
]]

local VulnMark = loadModule("src/Shared/Game/VulnMark.lua")

return function()
    describe("VulnMark.liveFraction", function()
        it("returns the fraction while unexpired", function()
            expect(VulnMark.liveFraction(0.5, 100, 50)).to.equal(0.5)
        end)
        it("returns 0 once expired (or exactly at expiry)", function()
            expect(VulnMark.liveFraction(0.5, 100, 100)).to.equal(0)
            expect(VulnMark.liveFraction(0.5, 100, 150)).to.equal(0)
        end)
        it("floors negative/garbage fractions at 0", function()
            expect(VulnMark.liveFraction(-0.5, 100, 50)).to.equal(0)
            expect(VulnMark.liveFraction("junk", 100, 50)).to.equal(0)
            expect(VulnMark.liveFraction(0.5, nil, 50)).to.equal(0)
        end)
    end)

    describe("VulnMark.multiplier (ADDITIVE stack — the clobber fix)", function()
        it("is x1 with no marks / junk input", function()
            expect(VulnMark.multiplier({}, 50)).to.equal(1)
            expect(VulnMark.multiplier(nil, 50)).to.equal(1)
            expect(VulnMark.multiplier({ HP = 500, EnemyId = "x" }, 50)).to.equal(1)
        end)

        it("a single x2.0 mark reads x2.0", function()
            local attrs = { VulnMark_eruption = 1.0, VulnMark_eruption_Until = 100 }
            expect(VulnMark.multiplier(attrs, 50)).to.equal(2.0)
        end)

        it("marks ADD across sources (eruption x2.0 + strike x1.5 -> x2.5, NOT x1.5)", function()
            -- THE fix: casting strike after eruption used to overwrite the x2.0 down to x1.5.
            local attrs = {
                VulnMark_eruption = 1.0,
                VulnMark_eruption_Until = 100,
                VulnMark_strike = 0.5,
                VulnMark_strike_Until = 100,
            }
            expect(VulnMark.multiplier(attrs, 50)).to.equal(2.5)
        end)

        it("an expired mark drops out of the sum (independent expiries)", function()
            local attrs = {
                VulnMark_eruption = 1.0,
                VulnMark_eruption_Until = 60, -- expired at now=80
                VulnMark_strike = 0.5,
                VulnMark_strike_Until = 100, -- still live
            }
            expect(VulnMark.multiplier(attrs, 80)).to.equal(1.5)
        end)

        it(
            "has NO cap — the full kit stacks (bounded by focus/cooldowns, not a clamp)",
            function()
                local attrs = {}
                for _, key in ipairs({ "a", "b", "c", "d", "e" }) do
                    attrs["VulnMark_" .. key] = 1.0 -- five x2.0 marks
                    attrs["VulnMark_" .. key .. "_Until"] = 100
                end
                expect(VulnMark.multiplier(attrs, 50)).to.equal(6.0)
            end
        )

        it("ignores the _Until keys themselves and unrelated attributes", function()
            local attrs = {
                VulnMark_pit = 0.5,
                VulnMark_pit_Until = 100,
                VulnerableUntil = 100, -- the client VFX channel, not a mark
                RootedUntil = 100,
            }
            expect(VulnMark.multiplier(attrs, 50)).to.equal(1.5)
        end)
    end)

    describe("VulnMark channel names", function()
        it("builds the attr + until names from a key", function()
            expect(VulnMark.attr("eruption")).to.equal("VulnMark_eruption")
            expect(VulnMark.untilAttr("eruption")).to.equal("VulnMark_eruption_Until")
        end)
    end)
end
