local PrologueSpawnGate = loadModule("src/Shared/Game/PrologueSpawnGate.lua")

return function()
    describe("PrologueSpawnGate", function()
        it("places normally when the prologue service is absent", function()
            expect(PrologueSpawnGate.action(false, false, nil)).to.equal("place")
        end)

        it("waits while a first-run prologue decision is unresolved", function()
            expect(PrologueSpawnGate.action(true, false, nil)).to.equal("wait")
        end)

        it("never lets zone spawn safety override an active prologue", function()
            expect(PrologueSpawnGate.action(true, true, nil)).to.equal("skip")
            expect(PrologueSpawnGate.action(true, true, "eligible")).to.equal("skip")
        end)

        it("places normally after a non-active decision resolves", function()
            expect(PrologueSpawnGate.action(true, false, "already_seen")).to.equal("place")
            expect(PrologueSpawnGate.action(true, false, "room_unavailable")).to.equal("place")
        end)
    end)
end
