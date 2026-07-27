return function()
    describe("Quest menu visibility contract", function()
        it(
            "hides completed one-time quests but retains repeatables and unclaimed rewards",
            function()
                local panel = readFile("src/Client/UI/Menus/QuestPanel.lua")

                expect(
                    panel:find(
                        "local completed = (quest.claimedCount or 0) > 0 and quest.repeatable ~= true",
                        1,
                        true
                    )
                ).to.be.ok()
                expect(panel:find("if not completed then", 1, true)).to.be.ok()
                expect(panel:find("self.quests = menuQuests(quests)", 1, true)).to.be.ok()
            end
        )

        it("keeps the complete ledger on the server response", function()
            local service = readFile("src/Server/Services/QuestService.lua")

            expect(service:find("claimedCount = ledger[id] or 0", 1, true)).to.be.ok()
            expect(service:find("quests = out", 1, true)).to.be.ok()
        end)
    end)
end
