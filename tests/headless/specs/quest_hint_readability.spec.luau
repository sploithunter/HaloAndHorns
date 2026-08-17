return function()
    describe("quest hint readability contract", function()
        it("keeps quest details readable after touch or mouse release", function()
            local tracker = readFile("src/Client/Systems/QuestTrackerStyle.lua")
            local baseUI = readFile("src/Client/UI/BaseUI.lua")

            expect(tracker:find("local DETAIL_READ_GRACE_SECONDS = 10", 1, true) ~= nil).to.equal(
                true
            )
            expect(tracker:find("toggle.InputBegan:Connect", 1, true) ~= nil).to.equal(true)
            expect(tracker:find("UserInputService.InputEnded:Connect", 1, true) ~= nil).to.equal(
                true
            )
            expect(tracker:find("hideQuestDetailAfterGrace()", 1, true) ~= nil).to.equal(true)
            expect(baseUI:find('SetAttribute("QuestDetailText"', 1, true) ~= nil).to.equal(true)
        end)
    end)
end
