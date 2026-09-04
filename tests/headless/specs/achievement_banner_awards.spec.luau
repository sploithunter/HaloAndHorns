local Awards = loadModule("src/Shared/Game/AchievementBannerAwards.lua")
local config = loadModule("configs/achievement_banners.lua")

return function()
    describe("achievement banner awards", function()
        it("derives configured awards from authoritative facts", function()
            local ids = Awards.eligible(config.awards, {
                level = 50,
                veteran_level = 99,
                merge_wave = 250,
                merge_egg_tier = 21,
            })
            expect(table.find(ids, "level_50")).to.be.ok()
            expect(table.find(ids, "wave_100")).to.be.ok()
            expect(table.find(ids, "wave_250")).to.be.ok()
            expect(table.find(ids, "heaven_3_egg")).to.be.ok()
            expect(table.find(ids, "veteran_100")).never.to.be.ok()
            expect(table.find(ids, "hell_3_egg")).never.to.be.ok()
        end)

        it("awards the first Merge century at Wave 100 without replacing Level 50", function()
            local before = Awards.eligible(config.awards, {
                level = 50,
                merge_wave = 99,
            })
            expect(table.find(before, "level_50")).to.be.ok()
            expect(table.find(before, "wave_100")).never.to.be.ok()

            local atCentury = Awards.eligible(config.awards, {
                level = 50,
                merge_wave = 100,
            })
            expect(table.find(atCentury, "level_50")).to.be.ok()
            expect(table.find(atCentury, "wave_100")).to.be.ok()
            expect(table.find(atCentury, "wave_250")).never.to.be.ok()
        end)

        it("grants once and keeps the award pending until a checkpoint presentation", function()
            local state = Awards.normalize(nil)
            local granted = Awards.grant(state, "level_50", {
                source = "checkpoint",
                value = 50,
            }, 100)
            expect(granted).to.equal(true)
            expect(state.pending.level_50).to.equal(true)
            expect(state.owned.level_50.earned_at).to.equal(100)
            expect(Awards.grant(state, "level_50", {}, 200)).to.equal(false)
            expect(state.owned.level_50.earned_at).to.equal(100)
        end)

        it("mounts newly presented awards and respects the requested display cap", function()
            local state = Awards.normalize(nil)
            local ids = {
                "level_50",
                "heaven_2_egg",
                "hell_2_egg",
                "heaven_3_egg",
                "hell_3_egg",
            }
            for index, awardId in ipairs(ids) do
                Awards.grant(state, awardId, {}, index)
            end
            local pending = Awards.pendingIds(state, config.awards)
            local presented = Awards.present(state, pending, 4, 20)
            expect(#presented).to.equal(5)
            expect(#state.displayed).to.equal(4)
            expect(state.displayed[1]).to.equal("heaven_2_egg")
            expect(state.displayed[4]).to.equal("hell_3_egg")
            expect(next(state.pending)).never.to.be.ok()
        end)

        it("restores previously presented cloth when the wall gains more slots", function()
            local state = Awards.normalize(nil)
            local ids = {
                "level_50",
                "heaven_2_egg",
                "hell_2_egg",
                "heaven_3_egg",
                "hell_3_egg",
            }
            for index, awardId in ipairs(ids) do
                Awards.grant(state, awardId, {}, index)
            end
            Awards.present(state, Awards.pendingIds(state, config.awards), 4, 20)
            expect(#state.displayed).to.equal(4)

            local displayed, changed =
                Awards.reconcileDisplayed(state, config.awards, config.display.maximum)
            expect(changed).to.equal(true)
            expect(#displayed).to.equal(5)
            expect(displayed[1]).to.equal("level_50")
            expect(displayed[5]).to.equal("hell_3_egg")
        end)

        it("repairs stale and duplicate display entries", function()
            local state = Awards.normalize({
                owned = { level_50 = { earned_at = 1 } },
                pending = {},
                displayed = { "missing", "level_50", "level_50" },
            })
            expect(#state.displayed).to.equal(1)
            expect(state.displayed[1]).to.equal("level_50")
        end)
    end)
end
