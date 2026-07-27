local creators = loadModule("configs/creators.lua")
local pets = loadModule("configs/pets.lua")

local function assertCreatorEgg(userId, expected)
    local creator = creators.creators[userId]
    expect(creator).to.be.ok()
    expect(creator.pet).to.equal(expected.pet)
    expect(creator.egg_id).to.equal(expected.eggId)

    local egg = pets.egg_sources[expected.eggId]
    expect(egg).to.be.ok()
    expect(egg.purchasable).to.equal(false)
    expect(egg.fixed_odds).to.equal(true)
    expect(egg.asset_id).to.equal(expected.assetId)
    expect(egg.image_id).to.equal(expected.imageId)
    if expected.meshAsset then
        expect(egg.mesh_asset).to.equal(expected.meshAsset)
        expect(egg.texture_asset).to.equal(expected.textureAsset)
    end
    expect(egg.pet_weights[expected.pet]).to.equal(1)
    expect(egg.huge.chance).to.equal(0.01)
    expect(egg.huge.pets[expected.pet]).to.equal(1)
    expect(egg.rarity_rates.golden_chance).to.equal(0.05)
    expect(egg.rarity_rates.rainbow_chance).to.equal(0.005)
end

return function()
    describe("meet-the-creator egg contract", function()
        it("keeps Colorado on the canonical creator-egg path", function()
            assertCreatorEgg("3200870803", {
                pet = "colorado",
                eggId = "colorado_egg",
                assetId = "rbxassetid://94487781424433",
                imageId = "rbxassetid://120328710003120",
            })
        end)

        it("wires Kade through the same creator-egg mechanics", function()
            assertCreatorEgg("536245038", {
                pet = "kade",
                eggId = "kade_egg",
                assetId = "rbxassetid://121017090267088",
                imageId = "rbxassetid://75293308801530",
                meshAsset = "rbxassetid://103492246635387",
                textureAsset = "rbxassetid://137761201042755",
            })
        end)
    end)
end
