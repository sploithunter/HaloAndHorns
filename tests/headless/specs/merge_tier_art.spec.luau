local MergeTierArt = loadModule("src/Shared/Game/MergeTierArt.lua")
local tierArtConfig = loadModule("configs/merge_tier_art.lua")

return function()
    describe("Merge tier art registry", function()
        it("maps every cannon and bulwark tier back to its committed manifest", function()
            local runtimeProof = readFile("scripts/merge_tier_runtime_manifest.json")
            local manifests = {
                cannon = readFile("scripts/merge_cannon_model_ids.json"),
                bulwark = readFile("scripts/merge_bulwark_model_ids.json"),
            }
            local families = {
                cannon = { "heal", "rage", "debuff", "gravity", "repulsor", "nullifier" },
                bulwark = {
                    "impaler_palisade",
                    "concertina_line",
                    "land_shark",
                    "saw_blade",
                    "grasping_hedge",
                    "wardstone_barrier",
                },
            }
            local seen = {
                modelAssetId = {},
                meshId = {},
                textureId = {},
            }
            local variantCount = 0

            for kind, familyIds in pairs(families) do
                for _, family in ipairs(familyIds) do
                    for tier = 1, 4 do
                        local art = MergeTierArt.entry(tierArtConfig, kind, family, tier)
                        expect(art.tier).to.equal(tier)
                        for _, field in ipairs({ "modelAssetId", "meshId", "textureId" }) do
                            local id = art[field]
                            expect(type(id)).to.equal("string")
                            expect(seen[field][id]).to.equal(nil)
                            seen[field][id] = true
                            expect(
                                manifests[kind]:find(
                                    '"' .. field .. '": "' .. tostring(id) .. '"',
                                    1,
                                    true
                                )
                            ).to.be.ok()
                            expect(
                                runtimeProof:find(
                                    '"' .. field .. '": "' .. tostring(id) .. '"',
                                    1,
                                    true
                                )
                            ).to.be.ok()
                        end
                        variantCount += 1
                    end
                end
            end

            expect(variantCount).to.equal(48)
            expect(runtimeProof:find('"status": "COMPLETE"', 1, true)).to.be.ok()
            expect(runtimeProof:find('"runtimeConfig": "configs/merge_tier_art.lua"', 1, true)).to.be.ok()
            expect(runtimeProof:find('"cannonTierMappings": 24', 1, true)).to.be.ok()
            expect(runtimeProof:find('"bulwarkTierMappings": 24', 1, true)).to.be.ok()
            expect(runtimeProof:find('"distinctModelAssets": 48', 1, true)).to.be.ok()
        end)

        it("maps all 24 bulwark menu previews to distinct committed decals", function()
            local previewManifest = readFile("scripts/merge_bulwark_preview_ids.json")
            local families = {
                "impaler_palisade",
                "concertina_line",
                "land_shark",
                "saw_blade",
                "grasping_hedge",
                "wardstone_barrier",
            }
            local seen = {}
            local previewCount = 0

            for _, family in ipairs(families) do
                local ids = MergeTierArt.previewAssetIds(tierArtConfig, "bulwark", family)
                expect(#ids).to.equal(4)
                for _, id in ipairs(ids) do
                    expect(seen[id]).to.equal(nil)
                    seen[id] = true
                    expect(previewManifest:find('"decalId": "' .. tostring(id) .. '"', 1, true)).to.be.ok()
                    previewCount += 1
                end
            end

            expect(previewCount).to.equal(24)
        end)
    end)
end
