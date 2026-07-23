--[[
    Temporary Alliance rules — [unit]. Sidekick-UP-only proximity alliance at spawn triggers
    (docs/TEAMING.md). Run: mise run test-headless
]]

local AllianceRules = loadModule("src/Shared/Game/AllianceRules.lua")

local CFG = { enabled = true, min_level_gap = 3, min_engage_level = 5 }

return function()
    describe("AllianceRules.pickHighest", function()
        it("selects the highest player regardless of Roblox iteration order", function()
            local low = { name = "Low", level = 9, userId = 20 }
            local high = { name = "High", level = 29, userId = 30 }
            local mid = { name = "Mid", level = 17, userId = 10 }
            expect(AllianceRules.pickHighest({ low, high, mid })).to.equal(high)
        end)

        it("uses the stable tie key for equal levels", function()
            local later = { level = 29, userId = 200 }
            local earlier = { level = 29, userId = 100 }
            expect(AllianceRules.pickHighest({ later, earlier })).to.equal(earlier)
        end)

        it("returns nil for no candidates", function()
            expect(AllianceRules.pickHighest({})).to.equal(nil)
        end)

        it("is wired into the Home cave spawner", function()
            local source = readFile("src/Server/Services/BaddieSpawnerService.lua")
            expect(source:find("AllianceRules.pickHighest(vetCandidates", 1, true) ~= nil).to.equal(
                true
            )
        end)
    end)

    describe("AllianceRules.shouldAlly", function()
        it("allies a mid player to a much higher triggerer (the retention scenario)", function()
            expect(AllianceRules.shouldAlly(50, 10, CFG)).to.equal(true)
        end)

        it("allies the reported Hell 1 level-9 player to the level-29 anchor", function()
            expect(AllianceRules.shouldAlly(29, 9, CFG)).to.equal(true)
            expect(AllianceRules.effectiveLevel(9, 29, -1)).to.equal(28)
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
