local SpawnGroupGate = loadModule("src/Shared/Game/SpawnGroupGate.lua")

return function()
    describe("proximity spawner group gate", function()
        it("allows the first group", function()
            expect(SpawnGroupGate.canSpawn(0)).to.equal(true)
            expect(SpawnGroupGate.canSpawn(nil)).to.equal(true)
        end)

        it("blocks another group while even one member remains", function()
            expect(SpawnGroupGate.isActive(1)).to.equal(true)
            expect(SpawnGroupGate.canSpawn(1)).to.equal(false)
            expect(SpawnGroupGate.canSpawn(7)).to.equal(false)
        end)

        it("re-arms only after the entire prior group is gone", function()
            expect(SpawnGroupGate.canSpawn(4)).to.equal(false)
            expect(SpawnGroupGate.canSpawn(1)).to.equal(false)
            expect(SpawnGroupGate.canSpawn(0)).to.equal(true)
        end)
    end)
end
