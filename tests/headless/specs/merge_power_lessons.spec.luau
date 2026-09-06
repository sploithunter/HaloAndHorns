local Lessons = loadModule("src/Shared/Game/MergePowerLessons.lua")
local Flow = loadModule("src/Shared/Game/TutorialFlow.lua")
local cfg = loadModule("configs/merge_egg_prototype.lua").tutorial
local tutorial = loadModule("configs/tutorial.lua")

return function()
    describe("Merge wave power lessons", function()
        it("uses the 6/8/10/12/14 cadence without mandatory combat training", function()
            local stages = cfg.power_lessons.stages
            expect(stages[1].wave).to.equal(6)
            expect(stages[1].level).to.equal(2)
            expect(cfg.pause_after_upgrade_wave).to.equal(8)
            expect(stages[2].wave).to.equal(10)
            expect(stages[2].level).to.equal(3)
            expect(stages[2].slots).to.equal(2)
            expect(stages[3].wave).to.equal(12)
            expect(cfg.pause_after_quartermaster_wave).to.equal(14)
            expect(cfg.quartermaster_introduction_only).to.equal(true)
            expect(cfg.basic_combat_reminder.enabled).to.equal(false)
            expect(cfg.power_lessons.hotbar_reveal_wave).to.equal(6)
        end)
        it("recommends without choosing for the player", function()
            expect(Lessons.recommended(cfg.power_lessons, false)).to.equal("magnet")
            expect(Lessons.recommended(cfg.power_lessons, true)).to.equal("swift")
        end)
        it("skips graduates but never fabricates a graduation", function()
            expect(Lessons.graduate({ Tutorial = { done = true } })).to.equal(true)
            expect(Lessons.graduate({ CombatTutorial = { done = true } })).to.equal(true)
            expect(Lessons.graduate({ GameData = { TutorialCompleted = true } })).to.equal(true)
            local data = { GameData = { MergePowerLessons = { unlocked = true } } }
            expect(Lessons.graduate(data)).to.equal(false)
            expect(
                Flow.ascensionUnlocked(
                    tutorial,
                    { done = false },
                    { done = false },
                    data.GameData,
                    1
                )
            ).to.equal(true)
            expect(data.CombatTutorial).to.equal(nil)
        end)
        it("does not count inherent slots as the two earned placements", function()
            expect(Lessons.allocated({ magnet = { { inherent = true }, {} }, swift = { {} } })).to.equal(
                2
            )
        end)
        it("updates Pick 2 / Pick 1 / Commit in both directions for Undo", function()
            for _, remaining in ipairs({ 2, 1, 0, 1, 2 }) do
                local text, action = Lessons.guide(cfg.power_lessons, "slots", 0, 2, 0, remaining)
                expect(text).to.equal(remaining > 0 and ("PICK " .. remaining) or "COMMIT")
                expect(action).to.equal(remaining > 0 and "slots" or "commit")
            end
        end)
        it("guides power selection, confirmation and the complete enhancement sequence", function()
            local c = cfg.power_lessons
            local _, action = Lessons.guide(c, "power", 1, 0, 1, 0)
            expect(action).to.equal("power")
            _, action = Lessons.guide(c, "power", 1, 0, 0, 0)
            expect(action).to.equal("commit")
            _, action = Lessons.guide(c, "enhance", 0, 0, 0, 0)
            expect(action).to.equal("owned")
            _, action = Lessons.guide(c, "enhance", 0, 0, 0, 0, "magnet")
            expect(action).to.equal("slot")
            _, action = Lessons.guide(c, "enhance", 0, 0, 0, 0, "magnet", 2)
            expect(action).to.equal("enhancement")
            _, action = Lessons.guide(c, "enhance", 0, 0, 0, 0, "magnet", 2, {})
            expect(action).to.equal("apply")
        end)
        it("has localized cue text with equivalent placeholders", function()
            for _, copy in pairs(cfg.power_lessons.translations) do
                for key, value in pairs(cfg.power_lessons.guide) do
                    if type(value) == "string" then
                        expect(type(copy[key])).to.equal("string")
                    end
                end
                expect(copy.pick_slots:find("%d", 1, true)).to.be.ok()
            end
        end)
    end)
end
