--[[
    Feature 6: Pet power calculation arithmetic — [unit] scenarios.
    Run: mise run test-headless
]]

local PowerFormula = loadModule("src/Shared/Game/PowerFormula.lua")

return function()
    describe("PowerFormula.compute", function()
        it("uses base from config when there are no modifiers", function()
            expect(PowerFormula.compute({ base = 100 })).to.equal(100)
        end)

        it("applies the variant multiplier", function()
            expect(PowerFormula.compute({ base = 100, variant = 2.0 })).to.equal(200)
        end)

        it("element resonance in the opposing realm (light in Hell, 1.5) -> 150", function()
            expect(PowerFormula.compute({ base = 100, element = 1.5 })).to.equal(150)
        end)

        it("element resonance in the home realm (light in Heaven, 1.2) -> 120", function()
            expect(PowerFormula.compute({ base = 100, element = 1.2 })).to.equal(120)
        end)

        it("element multiplier 1.0 in neutral realm -> 100", function()
            expect(PowerFormula.compute({ base = 100, element = 1.0 })).to.equal(100)
        end)

        it("chaotic flat 1.3 -> 130 in any realm", function()
            expect(PowerFormula.compute({ base = 100, element = 1.3 })).to.equal(130)
        end)

        it("all multipliers stack multiplicatively: 100 x 2.0 x 1.5 x 1.5 = 450", function()
            expect(PowerFormula.compute({
                base = 100,
                variant = 2.0,
                level = 1.5,
                element = 1.5,
            })).to.equal(450)
        end)

        it("missing multipliers default to 1 (no effect)", function()
            expect(PowerFormula.compute({ base = 250 })).to.equal(250)
            expect(PowerFormula.compute({ base = 100, buff = 1.1, stack = 2 })).to.equal(220)
        end)

        it("requires a numeric base", function()
            local ok = pcall(function()
                PowerFormula.compute({ variant = 2 })
            end)
            expect(ok).to.equal(false)
        end)
    end)
end
