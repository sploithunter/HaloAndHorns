--[[
    Hatch luck progression (configs/pets.lua simulateHatch).
    Two terms, neither can run away (Jason: no hard caps, no volume farming):
      - LEVEL: diminishing-doubling curve (+per_doubling per doubling past
        first_bonus_at; log2, bounded by the level cap anyway).
      - COLLECTION: index completion fraction (0..1, from PetIndexService) x
        index_luck.max_bonus — a natural cap at 100% collection. Replaced the
        raw pets-hatched count, which a parked 24/7 auto-hatcher farmed for free.
    Run: mise run test-headless
]]

local pets = loadModule("configs/pets.lua")

-- simulateHatch rolls randomly but returns the DETERMINISTIC luckMultiplier it used.
local function luckFor(playerData)
    local result = pets.simulateHatch("grass_egg", playerData)
    assert(result, "simulateHatch returned nil")
    return result.luckMultiplier
end

local function near(value, target, tolerance)
    return math.abs(value - target) <= (tolerance or 0.01)
end

return function()
    describe("hatch luck progression", function()
        it("fresh player is ~1x", function()
            expect(near(luckFor({ level = 0, indexCompletion = 0 }), 1.0)).to.equal(true)
        end)

        it("level follows the doubling curve", function()
            -- eased per_doubling 0.5 -> 0.3 (Jason: "scaling player luck really really steeply")
            -- level 10: 1 + 0.3*log2(1 + 10/3) = ~1.63
            expect(near(luckFor({ level = 10, indexCompletion = 0 }), 1.63, 0.02)).to.equal(true)
            -- level 50: 1 + 0.3*log2(1 + 50/3) = ~2.24
            expect(near(luckFor({ level = 50, indexCompletion = 0 }), 2.24, 0.02)).to.equal(true)
        end)

        it("collection completion scales the index bonus linearly to its natural cap", function()
            local base = luckFor({ level = 0, indexCompletion = 0 })
            -- CURVED (exponent 2.5): 50% collection pays 0.5^2.5 = ~17.7% of max_bonus
            -- (the easy half of the index is nearly free; the grind earns the bonus)
            expect(near(luckFor({ level = 0, indexCompletion = 0.5 }) - base, 0.354, 0.01)).to.equal(
                true
            )
            -- full collection = the full configured max_bonus (2.0)
            expect(near(luckFor({ level = 0, indexCompletion = 1 }) - base, 2.0)).to.equal(true)
        end)

        it("completion is clamped — nothing past 100%", function()
            expect(
                near(
                    luckFor({ level = 0, indexCompletion = 5 }),
                    luckFor({ level = 0, indexCompletion = 1 })
                )
            ).to.equal(true)
        end)

        it("raw hatch volume earns NOTHING (the old runaway term is gone)", function()
            local a = luckFor({ level = 10, indexCompletion = 0.25 })
            local b = luckFor({ level = 10, indexCompletion = 0.25, petsHatched = 1000000 })
            expect(near(a, b)).to.equal(true)
        end)

        it("buff fractions still add on top (additive luckBoost)", function()
            local base = luckFor({ level = 10, indexCompletion = 0.5 })
            local buffed = luckFor({ level = 10, indexCompletion = 0.5, luckBoost = 1.5 })
            expect(near(buffed - base, 1.5)).to.equal(true)
        end)

        -- PAID LUCK RULES (Jason, locked 2026-06-12): the gamepass ADDS a flat
        -- bonus ("2x is usually additive... added to your luck, not multiplied
        -- over your current luck") and only the SPECIES channel sees it
        -- ("gamepasses don't apply to variants, just shifts your odds for pets").
        it("the luck gamepass ADDS its flat bonus — never multiplies", function()
            local bonus = pets.gamepass_modifiers.luck_gamepass_bonus
            -- fresh player: 1.0 + bonus = exactly the advertised "2x"
            local fresh = luckFor({ level = 0, indexCompletion = 0, hasLuckGamepass = true })
            expect(near(fresh, 1.0 + bonus)).to.equal(true)
            -- stacked endgame state: SAME flat bonus (no compounding over the grind)
            local base = luckFor({ level = 10, indexCompletion = 0.9, luckBoost = 2.5 })
            local withPass = luckFor({
                level = 10,
                indexCompletion = 0.9,
                luckBoost = 2.5,
                hasLuckGamepass = true,
            })
            expect(near(withPass - base, bonus)).to.equal(true)
        end)

        it("the luck gamepass never moves golden/rainbow chances (species-only)", function()
            local state = { level = 10, indexCompletion = 0.9, luckBoost = 2.5 }
            local without = pets.simulateHatch("grass_egg", table.clone(state))
            state.hasLuckGamepass = true
            local withPass = pets.simulateHatch("grass_egg", state)
            expect(near(withPass.finalGoldenChance, without.finalGoldenChance, 1e-9)).to.equal(true)
            expect(near(withPass.finalRainbowChance, without.finalRainbowChance, 1e-9)).to.equal(
                true
            )
            -- but the species channel DID get the bonus
            expect(withPass.luckMultiplier > without.luckMultiplier).to.equal(true)
        end)
    end)

    -- SECRET LUCK (Jason): a SEPARATE, secret-tier-only reweight (secretLuckBoost), orthogonal to the
    -- general luck axis. Sources: enchant + shop stub + the "Secret Luck Day" event (the event read
    -- was the bug — EggService now folds it in). These lock the CONSUMPTION side in pets.lua so the
    -- reweight can't silently regress. Seeded -> deterministic, not flaky.
    describe("secret luck reweights only the secret tier", function()
        local function secretRate(playerData, n)
            local hits = 0
            for _ = 1, n do
                local r = pets.simulateHatch("infernal_egg", table.clone(playerData))
                if r and r.pet == "abyssal_wyrm" then -- the infernal egg's secret
                    hits += 1
                end
            end
            return hits
        end

        it("a big secretLuckBoost makes the secret far more common", function()
            math.randomseed(20260618)
            local n = 8000
            local base = secretRate({}, n)
            local boosted = secretRate({ secretLuckBoost = 100 }, n) -- ~101x the secret's weight
            expect(boosted > base * 10).to.equal(true)
        end)

        it("secret luck is ORTHOGONAL — it never touches the general luckMultiplier", function()
            local a = pets.simulateHatch("infernal_egg", { secretLuckBoost = 0 }).luckMultiplier
            local b = pets.simulateHatch("infernal_egg", { secretLuckBoost = 100 }).luckMultiplier
            expect(a == b).to.equal(true) -- both = base_luck; secret luck rides its own channel
        end)
    end)
end
