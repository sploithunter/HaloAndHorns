--[[
    PowerAvailability — hide innate powers during combat training.
]]

local PowerAvailability = loadModule("src/Shared/Game/PowerAvailability.lua")
local powers = loadModule("configs/powers.lua")

return function()
    describe("PowerAvailability", function()
        it("hides Resonance only while the player is in combat training", function()
            local resonance = powers.powers.resonance
            expect(resonance.innate).to.equal(true)
            expect(resonance.hidden_while.in_combat_tutorial).to.equal(true)
            expect(PowerAvailability.isAvailable(resonance, { inCombatTutorial = true })).to.equal(
                false
            )
            expect(PowerAvailability.isAvailable(resonance, { inCombatTutorial = false })).to.equal(
                true
            )
        end)

        it("withholds Heal until the first combat-training enter", function()
            local heal = powers.powers.heal
            expect(heal.innate).to.equal(true)
            expect(heal.hidden_while.until_combat_tutorial).to.equal(true)
            expect(PowerAvailability.isAvailable(heal, {})).to.equal(false)
            expect(PowerAvailability.isAvailable(heal, { inCombatTutorial = false })).to.equal(
                false
            )
            expect(PowerAvailability.isAvailable(heal, { inCombatTutorial = true })).to.equal(true)
            expect(PowerAvailability.isAvailable(heal, { combatTutorialHealUnlocked = true })).to.equal(
                true
            )
        end)

        it("filters a catalog in order using the same contextual rules", function()
            local ids = { "resonance", "heal", "magnet" }
            local definitions = powers.powers

            local fresh = PowerAvailability.filterAvailableIds(ids, definitions, {})
            expect(#fresh).to.equal(2)
            expect(fresh[1]).to.equal("resonance")
            expect(fresh[2]).to.equal("magnet")

            local training =
                PowerAvailability.filterAvailableIds(ids, definitions, { inCombatTutorial = true })
            expect(#training).to.equal(2)
            expect(training[1]).to.equal("heal")
            expect(training[2]).to.equal("magnet")

            local graduated = PowerAvailability.filterAvailableIds(
                ids,
                definitions,
                { combatTutorialHealUnlocked = true }
            )
            expect(#graduated).to.equal(3)
            expect(graduated[1]).to.equal("resonance")
            expect(graduated[2]).to.equal("heal")
            expect(graduated[3]).to.equal("magnet")
        end)
    end)
end
