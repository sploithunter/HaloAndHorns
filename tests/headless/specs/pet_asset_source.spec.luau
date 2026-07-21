local pets = loadModule("configs/pets.lua")

return function()
    describe("pet asset source compatibility", function()
        it("wires every Home/grass replacement and its script-driven rainbow geometry", function()
            local expected = {
                bear = {
                    basic = { "133536425144853", "84442074169129", 3.2 },
                    golden = { "87363912630069", "108884590012437", 3.2 },
                },
                bunny = {
                    basic = { "82125034029803", "71468779539283", 1.6 },
                    golden = { "104487535980339", "70991171666859", 1.6 },
                },
                doggy = {
                    basic = { "112015302170996", "122469325720894", 1.6 },
                    golden = { "75516117278305", "108981069156200", 1.6 },
                },
                dragon = {
                    basic = { "136769550943735", "113540978797107", 3.2 },
                    golden = { "137902863642024", "111720576430272", 3.2 },
                },
                kitty = {
                    basic = { "102876972452299", "107470584206079", 3.2 },
                    golden = { "124827770454459", "111506677857460", 3.2 },
                },
            }

            for petId, variants in pairs(expected) do
                for variant, ids in pairs(variants) do
                    local configured = pets.pets[petId].variants[variant]
                    expect(configured.asset_id).to.equal(nil)
                    expect(configured.mesh_asset).to.equal("rbxassetid://" .. ids[1])
                    expect(configured.texture_asset).to.equal("rbxassetid://" .. ids[2])
                    expect(configured.asset_transform.scale).to.equal(ids[3])
                end

                -- Rainbow is a script-driven treatment over the basic model, so it must use
                -- the same geometry and base texture instead of retaining legacy packaged art.
                local basic = pets.pets[petId].variants.basic
                local rainbow = pets.pets[petId].variants.rainbow
                expect(rainbow.asset_id).to.equal(nil)
                expect(rainbow.mesh_asset).to.equal(basic.mesh_asset)
                expect(rainbow.texture_asset).to.equal(basic.texture_asset)
                expect(rainbow.asset_transform.scale).to.equal(basic.asset_transform.scale)
            end
        end)

        it("keeps the creator Colorado on its packaged model source", function()
            local basic = pets.pets.colorado.variants.basic
            expect(basic.mesh_asset).to.equal(nil)
            expect(type(basic.asset_id)).to.equal("string")
        end)

        it("keeps Meshy families on mesh-plus-texture assembly", function()
            local basic = pets.pets.wyrmling.variants.basic
            expect(type(basic.mesh_asset)).to.equal("string")
            expect(type(basic.texture_asset)).to.equal("string")
            expect(basic.asset_id).to.equal(nil)
        end)
    end)
end
