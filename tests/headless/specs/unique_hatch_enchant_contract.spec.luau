local EnchantRuntime = loadModule("src/Shared/Game/EnchantRuntime.lua")

return function()
    describe("unique hatch enchant contract", function()
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
    end)
end
