local PetProjectionPolicy = loadModule("src/Shared/Inventory/PetProjectionPolicy.lua")

return function()
    describe("PetProjectionPolicy", function()
        it("keeps ordinary XP progress data-only", function()
            expect(PetProjectionPolicy.forProgression(false, false)).to.equal("data_only")
        end)

        it("renders when progression changes level/power or enchants", function()
            expect(PetProjectionPolicy.forProgression(true, false)).to.equal("visual")
            expect(PetProjectionPolicy.forProgression(false, true)).to.equal("visual")
        end)

        it("renders a squad batch if any mutation changed visible state", function()
            expect(PetProjectionPolicy.forMutationResults({
                a = { visualChanged = false },
                b = { visualChanged = true },
            })).to.equal("visual")
        end)

        it("does not render a squad batch containing only XP progress", function()
            expect(PetProjectionPolicy.forMutationResults({
                a = { visualChanged = false },
                b = { visualChanged = false },
            })).to.equal("data_only")
        end)

        it("fails safe for unknown mutation results", function()
            expect(PetProjectionPolicy.forMutationResults({ a = "unknown" })).to.equal("visual")
        end)
    end)
end
