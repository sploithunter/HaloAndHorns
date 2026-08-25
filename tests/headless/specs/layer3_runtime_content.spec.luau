local areas = loadModule("configs/areas.lua")
local breakables = loadModule("configs/breakables.lua")
local flora = loadModule("configs/flora.lua")
local pets = loadModule("configs/pets.lua")

local EGGS = {
    heaven3_fire_egg = "Heaven_3_Lava",
    heaven3_ice_egg = "Heaven_3_Ice",
    heaven3_grass_egg = "Heaven_3_Grass",
    heaven3_desert_egg = "Heaven_3_Desert",
    hell3_fire_egg = "Hell_3_Lava",
    hell3_ice_egg = "Hell_3_Ice",
    hell3_grass_egg = "Hell_3_Grass",
    hell3_desert_egg = "Hell_3_Desert",
}

describe("Layer 3 runtime content", function()
    it("ships all eight published eggs and their forty distinct pets", function()
        local seen = {}
        local count = 0
        local dragons = 0
        for eggId in pairs(EGGS) do
            local egg = pets.egg_sources[eggId]
            expect(egg).to.be.ok()
            expect(egg.cost).to.equal(1300)
            expect(egg.mesh_asset:find("rbxassetid://") == 1).to.equal(true)
            expect(egg.texture_asset:find("rbxassetid://") == 1).to.equal(true)
            expect(egg.image_id:find("rbxassetid://") == 1).to.equal(true)

            local eggCount = 0
            for petId in pairs(egg.pet_weights) do
                expect(seen[petId]).never.to.be.ok()
                seen[petId] = true
                eggCount += 1
                count += 1
                if petId:find("dragon", 1, true) then
                    dragons += 1
                end

                local pet = pets.pets[petId]
                expect(pet).to.be.ok()
                expect(pet.variants.basic.mesh_asset:find("rbxassetid://") == 1).to.equal(true)
                expect(pet.variants.golden.texture_asset:find("rbxassetid://") == 1).to.equal(true)
                expect(pet.variants.rainbow.mesh_asset).to.equal(pet.variants.basic.mesh_asset)
            end
            expect(eggCount).to.equal(5)
        end
        expect(count).to.equal(40)
        expect(dragons).to.equal(2)
    end)

    it("unlocks each origin for 1.5M and creates its Layer 3 crystal world", function()
        for _, areaId in pairs(EGGS) do
            local zone = areas.zones[areaId]
            expect(zone).to.be.ok()
            expect(zone.zone_level).to.equal(7)
            expect(zone.unlock.cost).to.equal(1500000)
            expect(zone.unlock.currency).to.equal(zone.element .. "_coins")

            local world = breakables.worlds[areaId]
            expect(world).to.be.ok()
            expect(world.health_mult).to.equal(4)
            expect(#world.spawn_table).to.equal(9)
            if areaId:find("Heaven", 1, true) then
                expect(world.spawn_settings.surface_y).to.equal(6000)
            else
                expect(world.spawn_settings.surface_y).to.equal(-5999)
            end
        end
    end)

    it("preserves the two intentional area-damage discovery hybrids", function()
        expect(pets.pets.light_tortoise.attack_targeting).to.equal("aura")
        expect(pets.pets.empyrean_grovekeeper.attack_targeting).to.equal("aura")
        expect(pets.pets.dreadthorn_grovekeeper.attack_targeting).to.equal("aura")
        expect(pets.pets.oasis_dragon.attack_targeting).to.equal("targeted_aoe")
        expect(pets.pets.dreadglass_dragon.attack_targeting).to.equal("targeted_aoe")
    end)

    it("gives selected Hell 3 flora and fauna emissive accents without shadow lights", function()
        local glow = flora.glow_models
        for _, modelName in ipairs({
            "dreadthorn_tree",
            "dreadspire_thorn_cactus",
            "blood_reed",
            "dreadwing_beetle",
            "obsidian_hornback_lizard",
        }) do
            local spec = glow[modelName]
            expect(spec).to.be.ok()
            expect(spec.neon).to.equal(true)
            expect(spec.brightness > 0).to.equal(true)
            expect(spec.range > 0).to.equal(true)
            expect(spec.shadows).never.to.be.ok()
        end
        expect(glow.violet_hook_bloom.neon).to.equal(true)
        expect(glow.violet_hook_bloom.brightness).never.to.be.ok()
    end)
end)
