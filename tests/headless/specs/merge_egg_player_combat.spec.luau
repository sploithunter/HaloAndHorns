local PlayerCombat = loadModule("src/Shared/Game/MergeEggPlayerCombat.lua")

return function()
    describe("Merge Egg player combat policy", function()
        it("gates Full mode by earned level or combat tutorial completion", function()
            expect(PlayerCombat.isFullEligible(9, false, 10)).to.equal(false)
            expect(PlayerCombat.isFullEligible(10, false, 10)).to.equal(true)
            expect(PlayerCombat.isFullEligible(1, true, 10)).to.equal(true)
            expect(PlayerCombat.resolveMode("full", false, "full")).to.equal("simple")
            expect(PlayerCombat.resolveMode("full", true, "full")).to.equal("full")
            expect(PlayerCombat.resolveMode("simple", true, "full")).to.equal("simple")
            expect(PlayerCombat.resolveMode("full", true, "full", true)).to.equal("simple")
        end)

        it("keeps ineligible first visits silent and asks at the later Full unlock", function()
            local state, notice = PlayerCombat.recordEntry(nil, false)
            expect(notice).to.equal(nil)
            expect(state.visited).to.equal(true)
            expect(state.played_locked_simple).to.equal(true)

            expect(PlayerCombat.noticeFor(state, true)).to.equal("full_unlock_choice")
            expect(PlayerCombat.isUnlockChoicePending(state, true)).to.equal(true)

            local stayed, mode, accepted = PlayerCombat.applyNoticeResponse(state, "stay_simple")
            expect(accepted).to.equal(true)
            expect(mode).to.equal("simple")
            expect(stayed.unlock_choice_resolved).to.equal(true)
            expect(PlayerCombat.noticeFor(stayed, true)).to.equal(nil)
        end)

        it("informs an eligible player on their first Merge defense visit", function()
            local state, notice = PlayerCombat.recordEntry(nil, true)
            expect(notice).to.equal("full_intro")
            expect(state.full_intro_pending).to.equal(true)

            local acknowledged, mode, accepted =
                PlayerCombat.applyNoticeResponse(state, "acknowledge_full_intro")
            expect(accepted).to.equal(true)
            expect(mode).to.equal(nil)
            expect(acknowledged.full_intro_acknowledged).to.equal(true)
            expect(PlayerCombat.noticeFor(acknowledged, true)).to.equal(nil)
        end)

        it("preserves and sanitizes durable rebirth progress during mode normalization", function()
            local state = PlayerCombat.normalizeOnboarding({
                visited = true,
                rebirths = 2.9,
                management_upgrades = {
                    damage = 3.8,
                    fire_rate = -2,
                },
                management_gems_spent = 175.9,
                tutorial_completed = true,
                checkpoint = {
                    wave = 27,
                    coins = 4321,
                    deployed_egg_tiers = { 3, 4, 0, 6 },
                },
            })
            expect(state.version).to.equal(5)
            expect(state.visited).to.equal(true)
            expect(state.rebirths).to.equal(2)
            expect(state.management_upgrades.damage).to.equal(3)
            expect(state.management_upgrades.fire_rate).to.equal(0)
            expect(state.management_gems_spent).to.equal(175)
            expect(state.tutorial_completed).to.equal(true)
            expect(state.checkpoint.wave).to.equal(20)
            expect(state.checkpoint.coins).to.equal(4321)
            expect(state.checkpoint.deployed_egg_tiers[2]).to.equal(4)
            expect(PlayerCombat.normalizeOnboarding({ rebirths = -4 }).rebirths).to.equal(0)
        end)

        it("preserves and sanitizes the durable Merge bulwark selection", function()
            local state = PlayerCombat.normalizeOnboarding({
                bulwark_family = "concertina_line",
                bulwark_tier = 3.8,
            })
            expect(state.bulwark_family).to.equal("concertina_line")
            expect(state.bulwark_tier).to.equal(3)

            local invalid = PlayerCombat.normalizeOnboarding({
                bulwark_family = "not_a_defense",
                bulwark_tier = 4,
            })
            expect(invalid.bulwark_family).to.equal(nil)
            expect(invalid.bulwark_tier).to.equal(0)
        end)

        it("lets a formerly locked player switch to Full exactly once", function()
            local state = PlayerCombat.recordEntry(nil, false)
            local switched, mode, accepted = PlayerCombat.applyNoticeResponse(state, "switch_full")
            expect(accepted).to.equal(true)
            expect(mode).to.equal("full")
            expect(switched.unlock_choice_resolved).to.equal(true)

            local _, duplicateMode, duplicateAccepted =
                PlayerCombat.applyNoticeResponse(switched, "stay_simple")
            expect(duplicateAccepted).to.equal(false)
            expect(duplicateMode).to.equal(nil)
        end)

        it("caps a durable hatch by both the player's unlock and deployed egg", function()
            local progression = {
                "grass_egg",
                "ice_egg",
                "lava_egg",
                "desert_egg",
                "bloom_egg",
                "aurora_egg",
            }
            local gates = {
                ice_egg = "Ice",
                lava_egg = "Lava",
                desert_egg = "Desert",
                bloom_egg = "Heaven_1_Grass",
                aurora_egg = "Heaven_1_Ice",
            }

            local freshTier, freshEgg =
                PlayerCombat.resolveHatchTier(progression, { "Spawn" }, gates, 6)
            expect(freshTier).to.equal(1)
            expect(freshEgg).to.equal("grass_egg")

            local veteranAreas = { "Spawn", "Ice", "Lava", "Heaven_1_Ice" }
            local cappedTier, cappedEgg =
                PlayerCombat.resolveHatchTier(progression, veteranAreas, gates, 3)
            expect(cappedTier).to.equal(3)
            expect(cappedEgg).to.equal("lava_egg")

            local unlockedTier, unlockedEgg =
                PlayerCombat.resolveHatchTier(progression, veteranAreas, gates, 6)
            expect(unlockedTier).to.equal(6)
            expect(unlockedEgg).to.equal("aurora_egg")
        end)
    end)
end
