--[[
    Enchant type-multiplier curve (Jason: "base * type multiplier — no shift, no cap").
    Pins the agreed Coin Finder curve so the config numbers can't silently drift.
    coin% = strength * coin_finder.amount_per_strength * type_multipliers[tier]
    Run: mise run test-headless
]]

local enchants = loadModule("configs/enchants.lua")
local pets = loadModule("configs/pets.lua")

local function coinPct(strength, tier)
    local base = enchants.effects.coin_finder.modifier.amount_per_strength
    local mult = enchants.type_multipliers[tier]
    -- round to 4 decimals — 0.06 isn't exact in binary, so 5*0.06*1.5 lands at 0.4499999…
    return math.floor(strength * base * mult * 10000 + 0.5) / 10000
end

return function()
    describe("enchant type_multipliers (coin curve)", function()
        it("base is 6% per strength (legendary tier)", function()
            expect(enchants.effects.coin_finder.modifier.amount_per_strength).to.equal(0.06)
            expect(enchants.type_multipliers.legendary).to.equal(1.0)
        end)

        it("exclusive +5 = 60% (the anchor)", function()
            expect(coinPct(5, "exclusive")).to.equal(0.6)
            expect(coinPct(1, "exclusive")).to.equal(0.12)
        end)

        it("scales up by tier — colossal +5 = 120%", function()
            expect(coinPct(5, "legendary")).to.equal(0.30)
            expect(coinPct(5, "mythic")).to.equal(0.45)
            expect(coinPct(5, "huge")).to.equal(0.75)
            expect(coinPct(5, "titanic")).to.equal(0.90)
            expect(coinPct(5, "colossal")).to.equal(1.20)
        end)

        it("is uncapped — strength past +5 keeps climbing", function()
            expect(coinPct(7, "colossal")).to.equal(1.68) -- 7 * 0.06 * 4.0
            expect(coinPct(10, "colossal")).to.equal(2.40)
        end)

        it("every enchantable tier has a multiplier", function()
            for _, tier in ipairs({
                "legendary",
                "mythic",
                "secret",
                "exclusive",
                "huge",
                "titanic",
                "colossal",
            }) do
                expect(type(enchants.type_multipliers[tier])).to.equal("number")
            end
        end)
    end)

    describe("enchant strength roll (+5 hard cap, per-effect, rarity-independent)", function()
        it("every effect rolls +1..+5 (high == 5, no 6+)", function()
            for id, effect in pairs(enchants.effects) do
                expect(type(effect.roll)).to.equal("table")
                expect(effect.roll.low).to.equal(1)
                expect(effect.roll.high).to.equal(5) -- HARD cap for all (was 6/7 on titanic/colossal)
                expect(type(effect.roll.scale)).to.equal("number")
                if id == "coin_finder" then
                    expect(effect.roll.scale).to.equal(2)
                end
            end
        end)

        it("rarity profiles carry no strength (effect+weight only)", function()
            for _, profile in pairs(enchants.roll_profiles) do
                for _, entry in ipairs(profile.chances or {}) do
                    expect(entry.strength).to.equal(nil)
                end
            end
        end)
    end)

    -- These mirror ConfigLoader's runtime validation (which mise-run-ci does NOT execute) — the gap
    -- that let two boot crashes through. Keys in the rarity-keyed maps MUST be real pets.rarities.
    describe("enchant config matches ConfigLoader invariants (boot-crash guard)", function()
        it("rarity_profiles keys are all real pets.rarities", function()
            for rarityId in pairs(enchants.rarity_profiles) do
                expect(pets.rarities[rarityId]).never.to.equal(nil)
            end
        end)

        it("pets.enchanting.max_enchantments_by_rarity keys are all real pets.rarities", function()
            for rarityId in pairs(pets.enchanting.max_enchantments_by_rarity) do
                expect(pets.rarities[rarityId]).never.to.equal(nil)
            end
        end)

        it("every chances entry references a defined effect", function()
            for _, profile in pairs(enchants.roll_profiles) do
                for _, entry in ipairs(profile.chances or {}) do
                    expect(enchants.effects[entry.effect]).never.to.equal(nil)
                end
            end
        end)
    end)
end
