local creators = loadModule("configs/creators.lua")
local enchants = loadModule("configs/enchants.lua")
local pets = loadModule("configs/pets.lua")
local combatFx = loadModule("configs/combat_fx.lua")

return function()
    describe("pet class contract", function()
        it("keeps Meet-the-Creator rewards normal-class Exclusive pets", function()
            for _, creator in pairs(creators.creators or {}) do
                local pet = pets.pets[creator.pet]
                expect(pet).to.be.ok()
                expect(pet.rarity).to.equal("exclusive")
                expect(pet.category).to.equal("exclusive")
                expect(creator.pet).never.to.equal("colorado_creator")
            end
        end)

        it("reserves the creator species category for the explicit apex", function()
            local creatorSpecies = {}
            for petType, pet in pairs(pets.pets or {}) do
                if pet.category == "creator" then
                    table.insert(creatorSpecies, petType)
                end
            end
            table.sort(creatorSpecies)
            expect(table.concat(creatorSpecies, ",")).to.equal("colorado_creator")
        end)

        it("keeps Colorado's meet pet on its Lava badge and the apex on Creator", function()
            local badgeElements = (combatFx.origin or {}).badge_element or {}
            local combatElements = (combatFx.origin or {}).pettype_element or {}
            expect(badgeElements.colorado).never.to.be.ok()
            expect(combatElements.colorado).to.equal("lava")
            expect(badgeElements.colorado_creator).to.equal("creator")
        end)

        it(
            "makes Huge and Creator record traits permanent without using species category",
            function()
                local permanent = enchants.permanent or {}
                expect(permanent.huge).to.equal(true)
                expect(permanent.creator).to.equal(true)
                expect(permanent.categories).never.to.be.ok()
                expect(pets.enchanting.max_enchantments_by_rarity.huge).to.equal(3)
                expect(pets.enchanting.max_enchantments_by_rarity.exclusive).to.equal(2)
            end
        )
    end)
end
