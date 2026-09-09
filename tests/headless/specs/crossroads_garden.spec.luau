local garden = loadModule("configs/crossroads_garden.lua")
local pets = loadModule("configs/pets.lua")
local currencies = loadModule("configs/currencies.lua")
local drops = loadModule("configs/drops.lua")
local breakables = loadModule("configs/breakables.lua")
local World = loadModule("src/Shared/Game/BreakableWorld.lua")
return function()
    describe("Crossroads featured egg economy", function()
        it("has a separate offer without changing the source egg's currency", function()
            local source = pets.egg_sources[garden.egg.source]
            local offer = pets.egg_sources[garden.egg.id]
            expect(offer ~= source).to.equal(true)
            expect(source.currency ~= garden.currency.id).to.equal(true)
            expect(offer.currency).to.equal(garden.currency.id)
            expect(pets.getEggCost(garden.egg.id)).to.equal(garden.egg.cost)
            expect(offer.mesh_asset).to.equal(source.mesh_asset)
            expect(offer.pet_weights).to.equal(source.pet_weights)
            for pet in pairs(offer.pet_weights) do
                expect(pets.pets[pet] ~= nil).to.equal(true)
            end
        end)
        it("registers a zero-start wallet and a physical coin for its canonical key", function()
            local found = 0
            for _, currency in ipairs(currencies) do
                if currency.id == garden.currency.id then
                    found += 1
                    expect(currency.defaultAmount).to.equal(0)
                    expect(currency.tradeable).to.equal(false)
                end
            end
            expect(found).to.equal(1)
            expect(drops.currency_pickups[garden.currency.id].mesh).to.equal(garden.pickup.mesh)
            for _, target in ipairs(garden.targets) do
                local def = breakables.crystals[target.id]
                expect(def.health > 0).to.equal(true)
                expect(def.value >= drops.min_coins_for_drop).to.equal(true)
                expect(def.currency).to.equal(garden.currency.id)
                expect(def.spawn.method).to.equal("drop")
            end
        end)
        it("keeps activity targets in their own folder with the configured mining gate", function()
            expect(World.isManaged(breakables, garden.world)).to.equal(true)
            expect(World.area(breakables, garden.world)).to.equal(garden.mining_area)
            expect(World.area(breakables, "Ice")).to.equal("Ice")
            expect(World.isManaged(breakables, "Ice")).to.equal(false)
            expect(World.isManaged(breakables, "mission_hell")).to.equal(true)
            expect(World.area(breakables, "mission_hell")).to.equal("mission_hell")
        end)
    end)
end
