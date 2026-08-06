local EnchantRuntime = loadModule("src/Shared/Game/EnchantRuntime.lua")

return function()
    describe("unique hatch enchant contract", function()
        it("keeps Huge pets unique, enchantable, and fated regardless of source", function()
            local pets = loadModule("configs/pets.lua")
            local enchants = loadModule("configs/enchants.lua")
            local progression = loadModule("configs/pet_progression.lua")
            expect(pets.enchanting.max_enchantments_by_rarity.huge).to.equal(3)
            expect(enchants.permanent.huge).to.equal(true)

            local hugeUnlocks = progression.enchant_slots.unlocks_by_rarity.huge
            expect(#hugeUnlocks).to.equal(3)
            expect(hugeUnlocks[1].level).to.equal(1)
            expect(hugeUnlocks[1].slots).to.equal(1)
            expect(hugeUnlocks[2].level).to.equal(50)
            expect(hugeUnlocks[2].slots).to.equal(2)
            expect(hugeUnlocks[3].level).to.equal(100)
            expect(hugeUnlocks[3].slots).to.equal(3)

            local grantSource = readFile("src/Server/Services/PetGrantService.lua")
            expect(
                grantSource:find(
                    'petData.rarity_id = grant.creator and "creator" or "huge"',
                    1,
                    true
                )
            ).never.to.equal(nil)
            expect(grantSource:find("RollInitialEnchantments", 1, true)).never.to.equal(nil)

            local progressionSource = readFile("src/Server/Services/PetProgressionService.lua")
            expect(progressionSource:find("self:ApplyProgression(petData, petConfig)", 1, true)).never.to.equal(
                nil
            )
            expect(
                progressionSource:find(
                    "enchantService:FillPermanentSlots(player, petData)",
                    1,
                    true
                )
            ).never.to.equal(nil)
            expect(progressionSource:find('RequestSave(player, "pet_progression_"', 1, true)).never.to.equal(
                nil
            )
        end)

        it("guarantees a first enchant after chance-based rolls miss", function()
            local source = readFile("src/Server/Services/EnchantService.lua")
            expect(source:find("UNIQUE HATCH CONTRACT", 1, true)).never.to.equal(nil)
            expect(
                source:find("if added == 0 and existing == 0 and availableSlots > 0 then", 1, true)
            ).never.to.equal(nil)
            expect(source:find("local enchant = self:RollEnchant", 1, true)).never.to.equal(nil)
        end)

        it("keeps every enchant effect on a consumed runtime modifier kind", function()
            local enchants = loadModule("configs/enchants.lua")
            local liveKinds = {
                breakable_reward = true,
                pet_xp = true,
                hatch_luck = true,
                secret_hatch_luck = true,
                pet_damage = true,
                team_power = true,
                pet_efficiency = true,
            }
            for _, effect in pairs(enchants.effects) do
                expect(liveKinds[effect.modifier.kind]).to.equal(true)
            end
        end)

        it("routes Coin Finder into every live biome coin payout", function()
            local modifier = {
                kind = "breakable_reward",
                currency = "coins",
            }
            for _, currency in ipairs({
                "grass_coins",
                "desert_coins",
                "ice_coins",
                "lava_coins",
            }) do
                expect(EnchantRuntime.matchesModifierContext(modifier, {
                    kind = "breakable_reward",
                    currency = currency,
                })).to.equal(true)
            end
            expect(EnchantRuntime.matchesModifierContext(modifier, {
                kind = "pet_damage",
                currency = "grass_coins",
            })).to.equal(false)
            expect(EnchantRuntime.matchesModifierContext(modifier, {
                kind = "breakable_reward",
                currency = "crystals",
            })).to.equal(false)
        end)

        it("uses one type-scaled magnitude for gameplay and enchant descriptions", function()
            local enchants = loadModule("configs/enchants.lua")
            local silverTactics = { id = "tactics", strength = 3 }
            local exclusiveMagnitude = EnchantRuntime.magnitude(silverTactics, {
                rarity_id = "exclusive",
            }, enchants)
            expect(math.abs(exclusiveMagnitude - 0.15) < 1e-9).to.equal(true)
            local hugeMagnitude = EnchantRuntime.magnitude(silverTactics, {
                huge = true,
                rarity_id = "exclusive",
            }, enchants)
            expect(math.abs(hugeMagnitude - 0.1875) < 1e-9).to.equal(true)
            expect(EnchantRuntime.effectAttribute("home_world")).to.equal(
                "EnchantEffect_home_world"
            )
        end)

        it("publishes every configured enchant as its own player HUD badge", function()
            local badgeSource = readFile("src/Client/Systems/PlayerPowerBadges.lua")
            local serviceSource = readFile("src/Server/Services/EnchantService.lua")
            expect(
                badgeSource:find("for effectId in pairs(ENCHANTS_CONFIG.effects or {}) do", 1, true)
            ).never.to.equal(nil)
            expect(serviceSource:find("EnchantRuntime.effectAttribute(effectId)", 1, true)).never.to.equal(
                nil
            )
        end)
    end)
end
