local ServerLuck = loadModule("src/Shared/Game/ServerLuck.lua")

return function()
    describe("ServerLuck", function()
        it("uses Founder’s Legacy as a 1.5x whole-server aura", function()
            local multiplier, source = ServerLuck.resolveForPlayer({
                founderPresent = true,
                founderMultiplier = 1.5,
            })
            expect(multiplier).to.equal(1.5)
            expect(source).to.equal("founder")
        end)

        it("uses the stronger creator aura instead of multiplying presence sources", function()
            local multiplier, source = ServerLuck.resolveForPlayer({
                creatorPresent = true,
                founderPresent = true,
                creatorMultiplier = 2,
                founderMultiplier = 1.5,
            })
            expect(multiplier).to.equal(2)
            expect(source).to.equal("creator")
        end)

        it("keeps creators out of Creator Luck but lets them receive Founder’s Legacy", function()
            local multiplier, source = ServerLuck.resolveForPlayer({
                creatorPresent = true,
                founderPresent = true,
                playerIsCreator = true,
                creatorMultiplier = 2,
                founderMultiplier = 1.5,
            })
            expect(multiplier).to.equal(1.5)
            expect(source).to.equal("founder")
        end)
    end)
end
