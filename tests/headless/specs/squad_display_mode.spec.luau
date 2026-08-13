local SquadDisplayMode = loadModule("src/Shared/Game/SquadDisplayMode.lua")

return function()
    describe("SquadDisplayMode", function()
        it("defaults missing and unknown preferences to classic", function()
            expect(SquadDisplayMode.normalize(nil)).to.equal("classic")
            expect(SquadDisplayMode.normalize("auto")).to.equal("classic")
        end)

        it("accepts every supported presentation", function()
            expect(SquadDisplayMode.normalize("classic")).to.equal("classic")
            expect(SquadDisplayMode.normalize("bar")).to.equal("bar")
            expect(SquadDisplayMode.normalize("circle")).to.equal("circle")
        end)
    end)
end
