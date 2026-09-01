local Progression = loadModule("src/Shared/Game/MergeBulwarkProgression.lua")

return function()
    describe("Merge bulwark progression", function()
        local config = {
            unlock_wave = 20,
            playtest_unlock_enabled = true,
            playtest_unlock_wave = 1,
            maximum_tier = 4,
            currency = "hall_coins",
            action_cost = 1,
        }

        it(
            "uses the Wave-1 playtest unlock while retaining the Wave-20 production cadence",
            function()
                expect(Progression.unlockWave(config)).to.equal(1)
                expect(Progression.isUnlocked(0, config)).to.equal(true)
                config.playtest_unlock_enabled = false
                expect(Progression.unlockWave(config)).to.equal(20)
                expect(Progression.isUnlocked(19, config)).to.equal(false)
                expect(Progression.isUnlocked(20, config)).to.equal(true)
                config.playtest_unlock_enabled = true
            end
        )

        it("keeps bought families and switches them onto the strip at the owned tier", function()
            local installed = Progression.apply(nil, "select", "impaler_palisade", 0, config)
            expect(installed.family).to.equal("impaler_palisade")
            expect(installed.tier).to.equal(1)
            expect(installed.owned.impaler_palisade).to.equal(1)
            expect(installed.operation).to.equal("installed")
            expect(installed.charged).to.equal(true)

            local upgraded = Progression.apply(installed, "upgrade", "impaler_palisade", 1, config)
            expect(upgraded.family).to.equal("impaler_palisade")
            expect(upgraded.tier).to.equal(2)
            expect(upgraded.owned.impaler_palisade).to.equal(2)

            local switched = Progression.apply(upgraded, "select", "land_shark", 1, config)
            expect(switched.family).to.equal("land_shark")
            expect(switched.tier).to.equal(1)
            expect(switched.owned.impaler_palisade).to.equal(2)
            expect(switched.owned.land_shark).to.equal(1)
            expect(switched.operation).to.equal("installed")

            local restored = Progression.apply(switched, "select", "impaler_palisade", 1, config)
            expect(restored.family).to.equal("impaler_palisade")
            expect(restored.tier).to.equal(2)
            expect(restored.operation).to.equal("equipped")
            expect(restored.charged).to.equal(false)
        end)

        it("upgrades the selected family even when another family is on the strip", function()
            local state = {
                family = "saw_blade",
                tier = 2,
                owned = { saw_blade = 2, concertina_line = 1 },
            }
            local upgraded = Progression.apply(state, "upgrade", "concertina_line", 1, config)
            expect(upgraded.family).to.equal("saw_blade")
            expect(upgraded.tier).to.equal(2)
            expect(upgraded.owned.concertina_line).to.equal(2)
            expect(upgraded.upgradedFamily).to.equal("concertina_line")

            local maxed, reason = Progression.apply({
                family = "saw_blade",
                owned = { saw_blade = 4 },
            }, "upgrade", "saw_blade", 1, config)
            expect(maxed).to.equal(nil)
            expect(reason).to.equal("bulwark_maxed")

            local missing, missingReason =
                Progression.apply(state, "upgrade", "wardstone_barrier", 1, config)
            expect(missing).to.equal(nil)
            expect(missingReason).to.equal("bulwark_not_owned")
        end)

        it("charges one configured Waycoin for every mutation", function()
            local price = Progression.actionCost(config)
            expect(price.currency).to.equal("hall_coins")
            expect(price.amount).to.equal(1)
            local families = Progression.families()
            local modelManifest = readFile("scripts/merge_bulwark_model_ids.json")
            expect(#families).to.equal(6)
            for _, family in ipairs(families) do
                expect(#family.previewAssetIds).to.equal(4)
                expect(tonumber(family.previewAssetIds[1]) ~= nil).to.equal(true)
                for _, previewAssetId in ipairs(family.previewAssetIds) do
                    expect(
                        modelManifest:find(
                            '"modelAssetId": "' .. tostring(previewAssetId) .. '"',
                            1,
                            true
                        )
                    ).to.equal(nil)
                end
                expect(type(family.role) == "string" and family.role ~= "").to.equal(true)
                expect(type(family.description) == "string" and family.description ~= "").to.equal(
                    true
                )
                expect(#family.upgradeNotes).to.equal(4)
                expect(#family.upgradeNotes[1]).to.equal(3)
                expect(#family.upgradeNotes[2]).to.equal(3)
            end
        end)

        it("treats Impaler Palisade as a no-damage stop shove, one bounce on Tier 1", function()
            local families = Progression.families()
            expect(families[1].id).to.equal("impaler_palisade")
            expect(families[1].role).to.equal("Stop")
            expect(families[1].description:find("No damage", 1, true)).to.be.ok()
            expect(families[1].upgradeNotes[1][3]:find("One bounce", 1, true)).to.be.ok()

            expect(Progression.combatEffect("land_shark", 1, config)).to.equal(nil)
            local t1 = Progression.combatEffect("impaler_palisade", 1, config)
            expect(t1.kind).to.equal("stop_shove")
            expect(t1.charges).to.equal(1)
            expect(t1.shoveStuds).to.equal(16)
            expect(t1.rootSeconds).to.equal(0.4)
            local t4 = Progression.combatEffect("impaler_palisade", 4, {
                combat = {
                    impaler_palisade = {
                        charges = { 1, 2, 3, 4 },
                        shove_studs = { 16, 20, 24, 28 },
                        root_seconds = { 0.4, 0.45, 0.55, 0.7 },
                    },
                },
            })
            expect(t4.charges).to.equal(4)
            expect(t4.shoveStuds).to.equal(28)
        end)
    end)
end
