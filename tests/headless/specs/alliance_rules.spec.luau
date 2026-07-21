--[[
    Temporary Alliance rules — [unit]. Sidekick-UP-only proximity alliance at spawn triggers
    (docs/TEAMING.md). Run: mise run test-headless
]]

local AllianceRules = loadModule("src/Shared/Game/AllianceRules.lua")

local CFG = { enabled = true, min_level_gap = 3, min_engage_level = 5 }

return function()
    describe("AllianceRules.shouldAlly", function()
        it("allies a mid player to a much higher triggerer (the retention scenario)", function()
            expect(AllianceRules.shouldAlly(50, 10, CFG)).to.equal(true)
        end)

        it("never allies a combat-invisible newbie (onramp protects them instead)", function()
            expect(AllianceRules.shouldAlly(50, 3, CFG)).to.equal(false)
        end)

        it("skips near-equals below the gap (banner would be noise)", function()
            expect(AllianceRules.shouldAlly(12, 10, CFG)).to.equal(false)
            expect(AllianceRules.shouldAlly(13, 10, CFG)).to.equal(true)
        end)

        it("a LOWER triggerer never allies a higher bystander (sidekick up only)", function()
            expect(AllianceRules.shouldAlly(10, 50, CFG)).to.equal(false)
        end)

        it("disabled config kills the feature", function()
            expect(AllianceRules.shouldAlly(50, 10, { enabled = false })).to.equal(false)
        end)
    end)

    describe("AllianceRules.effectiveLevel", function()
        it("lifts the low player to anchor + offset", function()
            expect(AllianceRules.effectiveLevel(10, 50, -1)).to.equal(49)
        end)

        it("never pulls an equal-or-higher player down (no imposed exemplar)", function()
            expect(AllianceRules.effectiveLevel(50, 30, -1)).to.equal(50)
            expect(AllianceRules.effectiveLevel(49, 50, -1)).to.equal(49)
        end)

        it("floors at level 1", function()
            expect(AllianceRules.effectiveLevel(1, 1, -1)).to.equal(1)
        end)
    end)
end
