--[[
    PotionDescribe — config-derived tooltip copy for hotbar/inventory potion surfaces.
]]

local PotionDescribe = loadModule("src/Shared/Game/PotionDescribe.lua")
local potions = loadModule("configs/potions.lua")

return function()
    describe("PotionDescribe.describe", function()
        it("describes every shipped potion from its live potion and meter definitions", function()
            for id, potion in pairs(potions.potions) do
                local d = PotionDescribe.describe(potions, id)
                expect(d ~= nil).to.equal(true)
                expect(d.name).to.equal(potion.display_name)
                expect(d.summary).to.equal(potion.description)
                expect(#d.lines >= 3).to.equal(true)
            end
        end)

        it("explains team buffs, charge size, drain, sip, and lock behavior", function()
            local d = PotionDescribe.describe(potions, "berserk_brew")
            expect(d.type).to.equal("Team Buff Potion")
            expect(d.lines[1]).to.equal("Berserk: up to +150% at full charge")
            expect(d.lines[2]).to.equal("Full meter drains in 60s")
            expect(d.lines[3]).to.equal("One use refills 50% of missing charge")
            expect(d.lines[4]).to.equal("LOCK auto-uses below 60% charge")
        end)

        it("labels player buffs and thrown enemy debuffs distinctly", function()
            expect(PotionDescribe.describe(potions, "fortune_flask").type).to.equal(
                "Player Buff Potion"
            )
            expect(PotionDescribe.describe(potions, "weakening_vial").type).to.equal(
                "Thrown Enemy Debuff"
            )
        end)

        it("configures enemy-target throws without a bespoke code branch", function()
            local vial = potions.potions.weakening_vial
            expect(type(vial.throw)).to.equal("table")
            expect(vial.throw.range).to.equal(100)
            expect(vial.throw.primitive).to.equal("ranged_bolt")
            expect(vial.throw.element).to.equal("lava")
            expect(potions.meters[vial.meter].target).to.equal("enemy")
        end)

        it("returns nil for an unknown or incomplete definition", function()
            expect(PotionDescribe.describe(potions, "missing")).to.equal(nil)
            expect(PotionDescribe.describe({ potions = { broken = { meter = "none" } } }, "broken")).to.equal(
                nil
            )
        end)
    end)
end
