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

        it("allies a sub-onramp newbie too (team onboarding beats the solo First Fight)", function()
            -- Jason 2026-07-21: "preferably they get to experience a team right off the bat...
            -- right now it feels like I'm being left out" — allied newbies become full
            -- combatants (EnemyService treats AllianceAnchor as combat-engaged), so the
            -- alliance REPLACES the solo pushover whenever higher players are camped.
            expect(AllianceRules.shouldAlly(50, 3, CFG)).to.equal(true)
            expect(AllianceRules.shouldAlly(26, 1, CFG)).to.equal(true)
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
