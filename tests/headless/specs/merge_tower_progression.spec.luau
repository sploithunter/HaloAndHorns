local Progression = loadModule("src/Shared/Game/MergeTowerProgression.lua")
local mergeConfig = loadModule("configs/merge_egg_prototype.lua")

return function()
    describe("Merge tower progression", function()
        local config = {
            unlock_wave = 10,
            playtest_unlock_enabled = true,
            playtest_unlock_wave = 1,
            maximum_tier = 4,
            currency = "hall_coins",
            action_cost = 1,
        }

        it(
            "uses the Wave-1 playtest unlock while retaining the Wave-10 production cadence",
            function()
                expect(Progression.unlockWave(config)).to.equal(1)
                expect(Progression.isUnlocked(0, config)).to.equal(true)
                config.playtest_unlock_enabled = false
                expect(Progression.unlockWave(config)).to.equal(10)
                expect(Progression.isUnlocked(9, config)).to.equal(false)
                expect(Progression.isUnlocked(10, config)).to.equal(true)
                config.playtest_unlock_enabled = true
            end
        )

        it("keeps bought cannons and switches them onto one pad at the owned tier", function()
            local installed = Progression.apply(nil, "select", "repulsor", 0, config, "left")
            expect(installed.leftFamily).to.equal("repulsor")
            expect(installed.leftTier).to.equal(1)
            expect(installed.rightFamily).to.equal(nil)
            expect(installed.owned.repulsor).to.equal(1)
            expect(installed.operation).to.equal("installed")
            expect(installed.charged).to.equal(true)

            local upgraded = Progression.apply(installed, "upgrade", "repulsor", 1, config, "left")
            expect(upgraded.leftFamily).to.equal("repulsor")
            expect(upgraded.leftTier).to.equal(2)
            expect(upgraded.owned.repulsor).to.equal(2)

            local switched = Progression.apply(upgraded, "select", "heal", 1, config, "left")
            expect(switched.leftFamily).to.equal("heal")
            expect(switched.leftTier).to.equal(1)
            expect(switched.owned.repulsor).to.equal(2)
            expect(switched.owned.heal).to.equal(1)
            expect(switched.operation).to.equal("installed")

            local otherPad = Progression.apply(switched, "select", "repulsor", 1, config, "right")
            expect(otherPad.leftFamily).to.equal("heal")
            expect(otherPad.rightFamily).to.equal("repulsor")
            expect(otherPad.rightTier).to.equal(2)
            expect(otherPad.operation).to.equal("equipped")
            expect(otherPad.charged).to.equal(false)

            local restored = Progression.apply(otherPad, "select", "repulsor", 1, config, "left")
            expect(restored.leftFamily).to.equal("repulsor")
            expect(restored.leftTier).to.equal(2)
            expect(restored.rightFamily).to.equal("repulsor")
            expect(restored.operation).to.equal("equipped")
            expect(restored.charged).to.equal(false)
        end)

        it("upgrades the selected cannon even when another role is on the pad", function()
            local state = {
                leftFamily = "heal",
                leftTier = 2,
                owned = { heal = 2, rage = 1 },
            }
            local upgraded = Progression.apply(state, "upgrade", "rage", 1, config, "left")
            expect(upgraded.leftFamily).to.equal("heal")
            expect(upgraded.leftTier).to.equal(2)
            expect(upgraded.owned.rage).to.equal(2)
            expect(upgraded.upgradedFamily).to.equal("rage")

            local maxed, reason = Progression.apply({
                leftFamily = "heal",
                owned = { heal = 4 },
            }, "upgrade", "heal", 1, config, "left")
            expect(maxed).to.equal(nil)
            expect(reason).to.equal("cannon_maxed")

            local missing, missingReason =
                Progression.apply(state, "upgrade", "nullifier", 1, config, "left")
            expect(missing).to.equal(nil)
            expect(missingReason).to.equal("cannon_not_owned")
        end)

        it("grants the visual catalog so Install does not require a Buy", function()
            local granted = Progression.withCatalogOwned({}, {
                "heal",
                "rage",
                "debuff",
                "gravity",
                "repulsor",
                "nullifier",
            }, 1, 4)
            expect(granted.owned.heal).to.equal(1)
            expect(granted.leftFamily).to.equal(nil)

            local installed = Progression.apply(granted, "select", "heal", 1, config, "left")
            expect(installed.leftFamily).to.equal("heal")
            expect(installed.operation).to.equal("equipped")
            expect(installed.charged).to.equal(false)
        end)

        it("charges one configured Waycoin for every mutation", function()
            local price = Progression.actionCost(config)
            expect(price.currency).to.equal("hall_coins")
            expect(price.amount).to.equal(1)
        end)

        it("lists every authored cannon role and persists per-pad installs", function()
            local families = Progression.families(mergeConfig.tier_art)
            local manifest = readFile("scripts/merge_cannon_preview_ids.json")
            local seenPreviewIds = {}
            expect(#families).to.equal(6)
            expect(families[1].id).to.equal("heal")
            expect(families[5].id).to.equal("repulsor")
            expect(Progression.isFamily("gravity")).to.equal(true)
            expect(Progression.isFamily("impaler_palisade")).to.equal(false)
            for _, family in ipairs(families) do
                expect(#family.previewAssetIds).to.equal(4)
                expect(family.description:find("size-only", 1, true)).to.equal(nil)
                for _, previewAssetId in ipairs(family.previewAssetIds) do
                    expect(seenPreviewIds[previewAssetId]).to.equal(nil)
                    seenPreviewIds[previewAssetId] = true
                    expect(
                        manifest:find('"decalId": "' .. tostring(previewAssetId) .. '"', 1, true)
                    ).to.be.ok()
                end
                for _, upgradeNotes in ipairs(family.upgradeNotes) do
                    expect(table.concat(upgradeNotes, " "):find("Distinct art later", 1, true)).to.equal(
                        nil
                    )
                end
            end

            local Slots = Progression.slots
            expect(#Slots.ids()).to.equal(2)
            expect(Slots.normalizeId("Right")).to.equal("right")
            expect(Slots.normalizeId(2)).to.equal("right")
            expect(Slots.fromPad({
                GetAttribute = function(_, key)
                    if key == "MergeTowerPadRole" then
                        return "Right"
                    end
                    return nil
                end,
                Name = "InitialTowerPad_Right",
            })).to.equal("right")

            local persisted = Progression.persistFields({
                leftFamily = "repulsor",
                leftTier = 2,
                rightFamily = "heal",
                rightTier = 1,
                owned = { repulsor = 2, heal = 1 },
            })
            expect(persisted.left_tower_family).to.equal("repulsor")
            expect(persisted.left_tower_tier).to.equal(2)
            expect(persisted.right_tower_family).to.equal("heal")
            expect(persisted.tower_owned.repulsor).to.equal(2)
            expect(persisted.tower_slots.right.family).to.equal("heal")
        end)
    end)
end
