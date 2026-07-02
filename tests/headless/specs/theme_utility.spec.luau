--[[
    Feature 6: Theme-utility passives — [unit] scenarios.
    Run: mise run test-headless
]]

local RingTopology = loadModule("src/Shared/Game/RingTopology.lua")
local ThemeUtility = loadModule("src/Shared/Game/ThemeUtility.lua")
local biomeConfig = loadModule("configs/biomes.lua")
local themeUtilityConfig = loadModule("configs/theme_utility.lua")

return function()
    describe("ThemeUtility.activePassive", function()
        local ring
        beforeEach(function()
            ring = RingTopology.new(biomeConfig)
        end)

        local function passive(petTheme, currentBiome)
            return ThemeUtility.activePassive(petTheme, currentBiome, ring, themeUtilityConfig)
        end

        it("earth pet in the desert (its dichotomy) gets Deep Roots", function()
            local p = passive("earth", "desert")
            expect(p).to.be.ok()
            expect(p.id).to.equal("deep_roots")
        end)

        it("earth pet in earth (home theme) gets no passive", function()
            expect(passive("earth", "earth")).to.equal(nil)
        end)

        it("earth pet in an unrelated biome (ice) gets no passive", function()
            expect(passive("earth", "ice")).to.equal(nil)
        end)

        it("ice pet thrives in lava (its dichotomy)", function()
            local p = passive("ice", "lava")
            expect(p).to.be.ok()
            expect(p.id).to.equal("flash_freeze")
        end)

        it("beach pet (no dichotomy) never gets a passive", function()
            expect(passive("beach", "earth")).to.equal(nil)
            expect(passive("beach", "beach")).to.equal(nil)
        end)
    end)
end
