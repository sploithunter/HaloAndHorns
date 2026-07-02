--[[
    Feature 5: Pet element assignment — [unit] scenarios.
    Run: mise run test-headless
]]

local PetElement = loadModule("src/Shared/Game/PetElement.lua")
local layersConfig = loadModule("configs/layers.lua")

return function()
    describe("PetElement", function()
        it("hatch element by layer: base->neutral, Heaven->light, Hell->shadow", function()
            expect(PetElement.elementForLayer("base", layersConfig)).to.equal("neutral")
            expect(PetElement.elementForLayer("heaven_1", layersConfig)).to.equal("light")
            expect(PetElement.elementForLayer("heaven_2", layersConfig)).to.equal("light")
            expect(PetElement.elementForLayer("hell_1", layersConfig)).to.equal("shadow")
            expect(PetElement.elementForLayer("hell_2", layersConfig)).to.equal("shadow")
        end)

        it("unknown layer defaults to neutral", function()
            expect(PetElement.elementForLayer("void", layersConfig)).to.equal("neutral")
            expect(PetElement.elementForLayer(nil, layersConfig)).to.equal("neutral")
        end)

        it("chaotic is never assigned at hatch (no layer maps to it)", function()
            for layer in pairs(layersConfig.hatch_element) do
                expect(PetElement.elementForLayer(layer, layersConfig)).never.to.equal("chaotic")
            end
        end)

        it("realm alignment by layer: base->neutral, Heaven->heaven, Hell->hell", function()
            expect(PetElement.realmAlignmentForLayer("base", layersConfig)).to.equal("neutral")
            expect(PetElement.realmAlignmentForLayer("heaven_1", layersConfig)).to.equal("heaven")
            expect(PetElement.realmAlignmentForLayer("hell_2", layersConfig)).to.equal("hell")
        end)

        it("element is metadata, not a stack identity axis", function()
            local lightKey = PetElement.stackKey("frost_drake", "basic", "light")
            local shadowKey = PetElement.stackKey("frost_drake", "basic", "shadow")
            expect(lightKey).to.equal(shadowKey)
        end)

        it("variant remains part of the species key", function()
            local basicLight = PetElement.stackKey("frost_drake", "basic", "light")
            local goldLight = PetElement.stackKey("frost_drake", "gold", "light")
            expect(basicLight).never.to.equal(goldLight)
        end)
    end)
end
