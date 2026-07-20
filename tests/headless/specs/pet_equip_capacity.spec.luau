local PetEquipCapacity = loadModule("src/Shared/Game/PetEquipCapacity.lua")

return function()
    describe("PetEquipCapacity", function()
        it("adds the paid pet to a new player's current limit", function()
            local capacity = PetEquipCapacity.resolve({
                baseSlots = 3,
                progressionCap = 10,
                paidSlots = 1,
            })
            expect(capacity).to.equal(4)
        end)

        it("keeps the paid pet above the progression cap", function()
            local capacity = PetEquipCapacity.resolve({
                baseSlots = 3,
                progressionCap = 10,
                earnedSlots = 7,
                paidSlots = 1,
            })
            expect(capacity).to.equal(11)
        end)

        it("does not count replicated compatibility capacity twice", function()
            local capacity = PetEquipCapacity.resolve({
                baseSlots = 3,
                progressionCap = 10,
                earnedSlots = 2,
                replicatedSlots = 4,
                paidSlots = 1,
            })
            expect(capacity).to.equal(8)
        end)
    end)
end
