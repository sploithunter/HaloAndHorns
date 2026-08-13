local QuestDisplayMode = loadModule("src/Shared/Game/QuestDisplayMode.lua")

return function()
    describe("QuestDisplayMode", function()
        it("defaults missing and unknown preferences to the full bar", function()
            expect(QuestDisplayMode.normalize(nil)).to.equal("full")
            expect(QuestDisplayMode.normalize("auto")).to.equal("full")
        end)

        it("accepts every supported presentation", function()
            expect(QuestDisplayMode.normalize("full")).to.equal("full")
            expect(QuestDisplayMode.normalize("pill")).to.equal("pill")
            expect(QuestDisplayMode.normalize("ring")).to.equal("ring")
        end)
    end)
end
