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
            slot_unlock_rebirth_ranks = {
                left = 1,
                right = 1,
                rear_left = 20,
                rear_right = 20,
            },
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

        it("unlocks the rear cannon pair at Rebirth Rank 20", function()
            expect(Progression.requiredRebirthRank("rear_left", config)).to.equal(20)
            expect(Progression.isSlotUnlocked("rear_right", 19, config)).to.equal(false)
            expect(Progression.isSlotUnlocked("rear_right", 20, config)).to.equal(true)

            local owned = Progression.apply(nil, "unlock", "heal", 1, config, "left", 1)
            local locked, reason =
                Progression.apply(owned, "select", "heal", 1, config, "rear_left", 19)
            expect(locked).to.equal(nil)
            expect(reason).to.equal("cannon_slot_rebirth_locked")

            local installed = Progression.apply(owned, "select", "heal", 1, config, "rear_left", 20)
            expect(installed.rearLeftFamily).to.equal("heal")
            expect(installed.rearLeftTier).to.equal(1)
        end)

        it("unlocks a role once, then places and upgrades each pad on its own", function()
            local unlocked = Progression.apply(nil, "unlock", "repulsor", 0, config, "left")
            expect(unlocked.owned.repulsor).to.equal(1)
            expect(unlocked.leftFamily).to.equal(nil)
            expect(unlocked.operation).to.equal("unlocked")
            expect(unlocked.charged).to.equal(true)

            local placed, placeReason =
                Progression.apply(nil, "select", "repulsor", 0, config, "left")
            expect(placed).to.equal(nil)
            expect(placeReason).to.equal("cannon_not_owned")

            local installed = Progression.apply(unlocked, "select", "repulsor", 0, config, "left")
            expect(installed.leftFamily).to.equal("repulsor")
            expect(installed.leftTier).to.equal(1)
            expect(installed.rightFamily).to.equal(nil)
            expect(installed.owned.repulsor).to.equal(1)
            expect(installed.operation).to.equal("installed")
            expect(installed.charged).to.equal(true)

            local upgraded = Progression.apply(installed, "upgrade", "repulsor", 1, config, "left")
            expect(upgraded.leftFamily).to.equal("repulsor")
            expect(upgraded.leftTier).to.equal(2)
            expect(upgraded.owned.repulsor).to.equal(1)
            expect(upgraded.rightTier).to.equal(0)

            local healUnlock = Progression.apply(upgraded, "unlock", "heal", 1, config, "left")
            local switched = Progression.apply(healUnlock, "select", "heal", 1, config, "left")
            expect(switched.leftFamily).to.equal("heal")
            expect(switched.leftTier).to.equal(1)
            expect(switched.owned.repulsor).to.equal(1)
            expect(switched.owned.heal).to.equal(1)
            expect(switched.operation).to.equal("replaced")
            expect(switched.charged).to.equal(true)

            local otherPad = Progression.apply(switched, "select", "repulsor", 1, config, "right")
            expect(otherPad.leftFamily).to.equal("heal")
            expect(otherPad.leftTier).to.equal(1)
            expect(otherPad.rightFamily).to.equal("repulsor")
            expect(otherPad.rightTier).to.equal(1)
            expect(otherPad.operation).to.equal("installed")
            expect(otherPad.charged).to.equal(true)

            local leftAgain = Progression.apply(otherPad, "upgrade", "heal", 1, config, "left")
            expect(leftAgain.leftTier).to.equal(2)
            expect(leftAgain.rightFamily).to.equal("repulsor")
            expect(leftAgain.rightTier).to.equal(1)

            local menuLeft = Progression.menuOwned(leftAgain, "left")
            expect(menuLeft.heal).to.equal(2)
            expect(menuLeft.repulsor).to.equal(1)
            local menuRight = Progression.menuOwned(leftAgain, "right")
            expect(menuRight.repulsor).to.equal(1)
            expect(menuRight.heal).to.equal(1)

            local cleared = Progression.clearInstalls(leftAgain, 4)
            expect(cleared.owned.heal).to.equal(1)
            expect(cleared.owned.repulsor).to.equal(1)
            expect(cleared.leftFamily).to.equal(nil)
            expect(cleared.rightFamily).to.equal(nil)
            expect(cleared.leftTier).to.equal(0)
        end)

        it("upgrades only the chassis sitting on that pad", function()
            local state = {
                leftFamily = "heal",
                leftTier = 2,
                owned = { heal = 1, rage = 1 },
            }
            local refused, reason = Progression.apply(state, "upgrade", "rage", 1, config, "left")
            expect(refused).to.equal(nil)
            expect(reason).to.equal("cannon_not_installed")

            local upgraded = Progression.apply(state, "upgrade", "heal", 1, config, "left")
            expect(upgraded.leftFamily).to.equal("heal")
            expect(upgraded.leftTier).to.equal(3)
            expect(upgraded.owned.heal).to.equal(1)
            expect(upgraded.owned.rage).to.equal(1)

            local maxed, maxReason = Progression.apply({
                leftFamily = "heal",
                leftTier = 4,
                owned = { heal = 1 },
            }, "upgrade", "heal", 1, config, "left")
            expect(maxed).to.equal(nil)
            expect(maxReason).to.equal("cannon_maxed")

            local missing, missingReason =
                Progression.apply(state, "upgrade", "nullifier", 1, config, "left")
            expect(missing).to.equal(nil)
            expect(missingReason).to.equal("cannon_not_installed")
        end)

        it("does not treat an empty save as owning every cannon", function()
            local empty = Progression.normalize({}, 4)
            expect(empty.owned.heal).to.equal(nil)
            expect(empty.leftFamily).to.equal(nil)
            local menu = Progression.menuOwned(empty, "left")
            expect(menu.heal).to.equal(nil)
            expect(menu.repulsor).to.equal(nil)
        end)

        it("quotes every configured unlock and target-tier price", function()
            local expected = {
                heal = { unlock = 1, tiers = { 1, 1000, 10000, 100000 } },
                rage = { unlock = 10, tiers = { 1000, 10000, 100000, 1000000 } },
                debuff = { unlock = 100, tiers = { 5000, 50000, 500000, 5000000 } },
                gravity = { unlock = 1000, tiers = { 10000, 100000, 1000000, 10000000 } },
                repulsor = { unlock = 10000, tiers = { 25000, 250000, 2500000, 25000000 } },
                nullifier = { unlock = 100000, tiers = { 50000, 500000, 5000000, 50000000 } },
            }
            for family, prices in pairs(expected) do
                local unlock =
                    Progression.actionCost(mergeConfig.team.edge_towers, "unlock", family)
                expect(unlock.currency).to.equal("gems")
                expect(unlock.amount).to.equal(prices.unlock)
                for tier, amount in ipairs(prices.tiers) do
                    local install =
                        Progression.actionCost(mergeConfig.team.edge_towers, "select", family, tier)
                    local upgrade = Progression.actionCost(
                        mergeConfig.team.edge_towers,
                        "upgrade",
                        family,
                        tier
                    )
                    expect(install.currency).to.equal("hall_coins")
                    expect(install.amount).to.equal(amount)
                    expect(upgrade.amount).to.equal(amount)
                end
            end
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
            expect(#Slots.ids()).to.equal(4)
            expect(Slots.normalizeId("Right")).to.equal("right")
            expect(Slots.normalizeId(2)).to.equal("right")
            expect(Slots.normalizeId("Rear Left")).to.equal("rear_left")
            expect(Slots.normalizeId(4)).to.equal("rear_right")
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
                rearLeftFamily = "rage",
                rearLeftTier = 3,
                owned = { repulsor = 2, heal = 1 },
            })
            expect(persisted.left_tower_family).to.equal("repulsor")
            expect(persisted.left_tower_tier).to.equal(2)
            expect(persisted.right_tower_family).to.equal("heal")
            expect(persisted.tower_owned.repulsor).to.equal(2)
            expect(persisted.tower_slots.right.family).to.equal("heal")
            expect(persisted.rear_left_tower_family).to.equal("rage")
            expect(persisted.tower_slots.rear_left.tier).to.equal(3)
        end)
    end)
end
