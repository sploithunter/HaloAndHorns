--[[
    QuestActivation — [unit] pause/resume math for activation-gated (since_start) quests.
    Run: mise run test-headless
]]

local QA = loadModule("src/Shared/Game/QuestActivation.lua")

return function()
    describe("QuestActivation.forward", function()
        it("is zero before activation (no banked, no open window)", function()
            expect(QA.forward(nil, nil, 100)).to.equal(0)
        end)

        it("counts the open window forward from the baseline", function()
            -- activated at counter=10, now at 15 -> 5 forward
            expect(QA.forward(0, 10, 15)).to.equal(5)
        end)

        it("adds the open window on top of previously banked progress", function()
            -- banked 30 from earlier windows, current window 10->15 -> 35
            expect(QA.forward(30, 10, 15)).to.equal(35)
        end)

        it("shows only banked progress while paused (no open window)", function()
            expect(QA.forward(30, nil, 999)).to.equal(30)
        end)

        it("never goes negative if the counter somehow drops below the baseline", function()
            expect(QA.forward(5, 20, 12)).to.equal(5)
        end)
    end)

    describe("QuestActivation.bank", function()
        it("folds the open window into banked", function()
            expect(QA.bank(30, 10, 15)).to.equal(35)
        end)

        it("is a no-op when already paused", function()
            expect(QA.bank(30, nil, 15)).to.equal(30)
        end)

        it("treats a counter below baseline as zero gain", function()
            expect(QA.bank(7, 20, 12)).to.equal(7)
        end)

        it("defaults missing banked to zero", function()
            expect(QA.bank(nil, 0, 9)).to.equal(9)
        end)
    end)
end
