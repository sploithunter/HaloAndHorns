--[[
    UIPalette — area -> HUD palette mapping (the home-area theming SoT).
    Run: mise run test-headless
]]

local UIPalette = loadModule("src/Shared/Game/UIPalette.lua")
local themeConfig = loadModule("configs/ui_theme.lua")

return function()
    describe("UIPalette.colorKeyForArea", function()
        it("maps each elemental area to its gem color", function()
            expect(UIPalette.colorKeyForArea("Lava", themeConfig)).to.equal("ruby")
            expect(UIPalette.colorKeyForArea("Ice", themeConfig)).to.equal("sapphire")
            expect(UIPalette.colorKeyForArea("Grass", themeConfig)).to.equal("emerald")
            expect(UIPalette.colorKeyForArea("Desert", themeConfig)).to.equal("citrine")
            expect(UIPalette.colorKeyForArea("Spawn", themeConfig)).to.equal("neutral")
        end)

        it("falls back to the default color for unknown / nil areas", function()
            expect(UIPalette.colorKeyForArea("Nowhere", themeConfig)).to.equal("neutral")
            expect(UIPalette.colorKeyForArea(nil, themeConfig)).to.equal("neutral")
        end)
    end)

    describe("UIPalette.resolve", function()
        it("returns the full palette + metrics for an area", function()
            local p = UIPalette.resolve("Lava", themeConfig)
            expect(p.color).to.equal("ruby")
            expect(type(p.primary)).to.equal("table")
            expect(p.primary[1]).to.equal(235) -- ruby primary R
            expect(type(p.metrics)).to.equal("table")
            expect(p.metrics.corner).to.equal(8)
        end)

        it("an unknown area resolves to the neutral palette (never nil)", function()
            local p = UIPalette.resolve("???", themeConfig)
            expect(p.color).to.equal("neutral")
            expect(type(p.fill)).to.equal("table")
        end)
    end)
end
