local RecallTarget = loadModule("src/Shared/Game/RecallTarget.lua")

return function()
    describe("RecallTarget", function()
        it("records the last successfully hatched egg in durable game data", function()
            local data = {}
            local result = RecallTarget.record(data, "grass_egg")

            expect(result.ok).to.equal(true)
            expect(result.changed).to.equal(true)
            expect(data.GameData.LastHatchedEggId).to.equal("grass_egg")
            expect(RecallTarget.savedEggId(data)).to.equal("grass_egg")
        end)

        it("does not mark repeated hatches at the same egg as a new save", function()
            local data = { GameData = { LastHatchedEggId = "grass_egg" } }
            local result = RecallTarget.record(data, "grass_egg")

            expect(result.ok).to.equal(true)
            expect(result.changed).to.equal(false)
        end)

        it("rejects Recall before the player has successfully hatched an egg", function()
            local result = RecallTarget.resolve({ GameData = {} }, function()
                return "should not run"
            end)

            expect(result.ok).to.equal(false)
            expect(result.reason).to.equal("no_recall_egg")
        end)

        it("resolves the saved id against the live egg instead of a stale position", function()
            local liveAnchor = { position = "new authored location" }
            local result = RecallTarget.resolve(
                { GameData = { LastHatchedEggId = "grass_egg" } },
                function(eggId)
                    expect(eggId).to.equal("grass_egg")
                    return liveAnchor
                end
            )

            expect(result.ok).to.equal(true)
            expect(result.target).to.equal(liveAnchor)
        end)

        it("fails closed when a saved event egg no longer exists", function()
            local result = RecallTarget.resolve(
                { GameData = { LastHatchedEggId = "expired_event_egg" } },
                function()
                    return nil
                end
            )

            expect(result.ok).to.equal(false)
            expect(result.reason).to.equal("recall_egg_missing")
            expect(result.eggId).to.equal("expired_event_egg")
        end)

        it("does not replace a valid saved egg with invalid input", function()
            local data = { GameData = { LastHatchedEggId = "ice_egg" } }
            local result = RecallTarget.record(data, "")

            expect(result.ok).to.equal(false)
            expect(data.GameData.LastHatchedEggId).to.equal("ice_egg")
        end)
    end)
end
