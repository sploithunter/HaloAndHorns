local AccessLevel = loadModule("src/Shared/Game/AccessLevel.lua")

return function()
    describe("AccessLevel.resolve", function()
        it("uses the player's earned level while their derived level is stale", function()
            expect(AccessLevel.resolve(15, 1)).to.equal(15)
        end)

        it("preserves a sidekick guest-pass increase", function()
            expect(AccessLevel.resolve(15, 49)).to.equal(49)
        end)

        it("does not let exemplaring revoke earned access", function()
            expect(AccessLevel.resolve(15, 5)).to.equal(15)
        end)

        it("normalizes missing and fractional values", function()
            expect(AccessLevel.resolve(nil, nil)).to.equal(1)
            expect(AccessLevel.resolve(14.9, 7.8)).to.equal(14)
        end)
    end)
end
