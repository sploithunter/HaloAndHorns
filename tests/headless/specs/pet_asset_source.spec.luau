local pets = loadModule("configs/pets.lua")

return function()
    describe("pet asset source compatibility", function()
        it("keeps the original six on packaged model sources", function()
            for _, petId in ipairs({ "bear", "bunny", "doggy", "dragon", "kitty", "colorado" }) do
                local basic = pets.pets[petId].variants.basic
                expect(basic.mesh_asset).to.equal(nil)
                expect(type(basic.asset_id)).to.equal("string")
            end
        end)

        it("keeps Meshy families on mesh-plus-texture assembly", function()
            local basic = pets.pets.wyrmling.variants.basic
            expect(type(basic.mesh_asset)).to.equal("string")
            expect(type(basic.texture_asset)).to.equal("string")
            expect(basic.asset_id).to.equal(nil)
        end)
    end)
end
