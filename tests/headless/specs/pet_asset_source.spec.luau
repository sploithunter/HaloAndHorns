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

        it("keeps developer pets on packaged model sources", function()
            local expected = {
                colorado = {
                    basic = "100466492312776",
                    golden = "121192248833075",
                },
                kade = {
                    basic = "107161152905013",
                    golden = "139643909402590",
                },
            }

            for petId, ids in pairs(expected) do
                local variants = pets.pets[petId].variants
                expect(variants.basic.mesh_asset).to.equal(nil)
                expect(variants.basic.asset_id).to.equal("rbxassetid://" .. ids.basic)
                expect(variants.golden.asset_id).to.equal("rbxassetid://" .. ids.golden)
                expect(variants.rainbow.asset_id).to.equal(variants.basic.asset_id)
            end

            -- Kade's packaged rig is authored with its face perpendicular to Roblox's -Z
            -- movement heading. This must stay declarative so every model consumer can share it.
            expect(pets.pets.kade.asset_transform.orientation.y).to.equal(-90)
        end)

        it("deploys every rigged pet from its animated basic rig", function()
            expect(pets.pets.doggy.deployed_variant_model).to.equal("basic")
            expect(pets.pets.dragon.rig_class).to.equal("quadruped")

            local source = readFile("src/Server/Services/PetHandler.server.lua")
            expect(source:find("rawPetEntry.deployed_variant_model", 1, true) ~= nil).to.equal(true)
            expect(source:find('rawPetEntry.rig_class and "basic"', 1, true) ~= nil).to.equal(true)
            expect(source:find("petTypeFolder:FindFirstChild(modelVariantName)", 1, true) ~= nil).to.equal(
                true
            )

            -- Catalog/static variants and their flat thumbnails remain independent. The
            -- replacement must not broaden AssetPreloadService's rig-prebake exemption.
            local preload = readFile("src/Server/Services/AssetPreloadService.lua")
            expect(preload:find('variant == "basic"', 1, true) ~= nil).to.equal(true)
            expect(preload:find('petType == "doggy"', 1, true)).to.equal(nil)
        end)

        it("applies imported orientation at the final pet render pivot", function()
            local source = readFile("src/Client/Systems/PetFollowController.lua")
            expect(source:find("local function visualOrientation", 1, true) ~= nil).to.equal(true)
            expect(source:find("nextClean * visualOrientation(pet)", 1, true) ~= nil).to.equal(true)
            expect(
                source:find("model:PivotTo(renderedCF * visualOrientation(model))", 1, true) ~= nil
            ).to.equal(true)
        end)

        it("keeps rebuilt local pet projections inside the owner's streaming set", function()
            local source = readFile("src/Server/Services/PetHandler.server.lua")
            local seed = source:find("local projectionSeedCFrame", 1, true)
            local wholeModelSeed = source:find("PetModel:PivotTo(projectionSeedCFrame)", 1, true)
            local persistentMode = source:find(
                "PetModel.ModelStreamingMode = Enum.ModelStreamingMode.PersistentPerPlayer",
                1,
                true
            )
            local persistentOwner = source:find("PetModel:AddPersistentPlayer(Player)", 1, true)
            local parent = source:find("PetModel.Parent = petModelsLocation", 1, true)

            expect(seed ~= nil).to.equal(true)
            expect(wholeModelSeed ~= nil).to.equal(true)
            expect(persistentMode ~= nil).to.equal(true)
            expect(parent ~= nil).to.equal(true)
            expect(persistentOwner ~= nil).to.equal(true)
            expect(seed < wholeModelSeed).to.equal(true)
            expect(wholeModelSeed < persistentMode).to.equal(true)
            expect(persistentMode < parent).to.equal(true)
            expect(parent < persistentOwner).to.equal(true)
        end)

        it("preserves imported orientation in cached and lazy inventory cards", function()
            local preload = readFile("src/Server/Services/AssetPreloadService.lua")
            local inventory = readFile("src/Client/UI/Menus/InventoryPanel.lua")
            local call = "ViewportModelPlacement.centerPreservingOrientation(modelClone)"
            expect(preload:find(call, 1, true) ~= nil).to.equal(true)
            expect(inventory:find(call, 1, true) ~= nil).to.equal(true)
        end)

        it("attaches configured body lights after runtime PrimaryPart repair", function()
            local doveLight = pets.pets.lumen_dove.body_light
            expect(doveLight.brightness).to.equal(2.5)
            expect(doveLight.range).to.equal(40)

            local source = readFile("src/Server/Services/PetHandler.server.lua")
            local primaryRepair = source:find("PetModel.PrimaryPart = candidate", 1, true)
            local bodyLight = source:find(
                "applyConfiguredBodyLight(PetModel, effectiveIdName)",
                primaryRepair,
                true
            )
            local followAttachment =
                source:find("-- Ensure attachmentPet exists on PrimaryPart", primaryRepair, true)
            expect(primaryRepair ~= nil).to.equal(true)
            expect(bodyLight ~= nil).to.equal(true)
            expect(followAttachment ~= nil).to.equal(true)
            expect(primaryRepair < bodyLight).to.equal(true)
            expect(bodyLight < followAttachment).to.equal(true)
        end)

        it("keeps Meshy families on mesh-plus-texture assembly", function()
            local basic = pets.pets.wyrmling.variants.basic
            expect(type(basic.mesh_asset)).to.equal("string")
            expect(type(basic.texture_asset)).to.equal("string")
            expect(basic.asset_id).to.equal(nil)
        end)
    end)
end
