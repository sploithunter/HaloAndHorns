--[[
    EnhancementPricing — store buy/sell math (band selection + grade-scaled value + per-level buyback).
    Run: mise run test-headless
]]

local EnhancementPricing = loadModule("src/Shared/Game/EnhancementPricing.lua")

local CFG = {
    level_step = 5,
    min_level = 5,
    max_level = 50,
    grade_mult = { natural = 1.0, dual = 1.54, single = 2.86 },
    buy = { base = 20, per_level = 10 },
    sell = { fraction = 0.30 },
}

return function()
    describe("EnhancementPricing.bandFor (slottable multiple-of-5 band)", function()
        it("rounds to the nearest multiple of the step", function()
            expect(EnhancementPricing.bandFor(17, CFG)).to.equal(15) -- L17 sees L15
            expect(EnhancementPricing.bandFor(18, CFG)).to.equal(20) -- L18 sees L20
            expect(EnhancementPricing.bandFor(16, CFG)).to.equal(15)
            expect(EnhancementPricing.bandFor(22, CFG)).to.equal(20)
            expect(EnhancementPricing.bandFor(23, CFG)).to.equal(25)
        end)

        it("the shown band is always within the ±2 slot window", function()
            for lvl = 5, 50 do
                local band = EnhancementPricing.bandFor(lvl, CFG)
                expect(math.abs(band - lvl) <= 2).to.equal(true)
            end
        end)

        it("clamps to [min_level, max_level]", function()
            expect(EnhancementPricing.bandFor(1, CFG)).to.equal(5)
            expect(EnhancementPricing.bandFor(2, CFG)).to.equal(5)
            expect(EnhancementPricing.bandFor(55, CFG)).to.equal(50)
            expect(EnhancementPricing.bandFor(999, CFG)).to.equal(50)
        end)
    end)

    describe("EnhancementPricing.buyPrice (value = (base + per*level) * grade_mult)", function()
        it("scales with band level for naturals", function()
            expect(EnhancementPricing.buyPrice("natural", 5, CFG)).to.equal(70)
            expect(EnhancementPricing.buyPrice("natural", 10, CFG)).to.equal(120)
            expect(EnhancementPricing.buyPrice("natural", 20, CFG)).to.equal(220)
        end)

        it("scales by grade (single > dual > natural, rarity-derived)", function()
            expect(EnhancementPricing.buyPrice("natural", 10, CFG)).to.equal(120) -- 120 * 1.0
            expect(EnhancementPricing.buyPrice("dual", 10, CFG)).to.equal(184) -- floor(120 * 1.54)
            expect(EnhancementPricing.buyPrice("single", 10, CFG)).to.equal(343) -- floor(120 * 2.86)
        end)

        it("defaults grade multiplier to 1 for unknown grades", function()
            expect(EnhancementPricing.buyPrice("mystery", 10, CFG)).to.equal(120)
        end)

        it("is defensive against missing config", function()
            expect(EnhancementPricing.buyPrice("natural", 10, nil)).to.equal(0)
        end)
    end)

    describe("EnhancementPricing.sellPrice (smooth per-level buyback, any grade)", function()
        it("scales EVERY level, not just bands (L14 worth more than L13)", function()
            local l13 = EnhancementPricing.sellPrice("natural", 13, CFG)
            local l14 = EnhancementPricing.sellPrice("natural", 14, CFG)
            expect(l13).to.equal(45) -- floor((20+130) * 1.0 * 0.30)
            expect(l14).to.equal(48) -- floor((20+140) * 1.0 * 0.30)
            expect(l14 > l13).to.equal(true)
        end)

        it("buys back single/dual too, grade-scaled", function()
            expect(EnhancementPricing.sellPrice("natural", 13, CFG)).to.equal(45)
            expect(EnhancementPricing.sellPrice("dual", 13, CFG)).to.equal(69) -- floor(150 * 1.54 * 0.30)
            expect(EnhancementPricing.sellPrice("single", 13, CFG)).to.equal(128) -- floor(150 * 2.86 * 0.30)
        end)

        it("never pays more than buy (fraction clamped to [0,1])", function()
            local cfg = {
                grade_mult = { natural = 1 },
                buy = { base = 100, per_level = 0 },
                sell = { fraction = 1.5 },
            }
            expect(EnhancementPricing.sellPrice("natural", 10, cfg)).to.equal(100)
        end)

        it("is zero with no sell config", function()
            local cfg = { grade_mult = { natural = 1 }, buy = { base = 100, per_level = 0 } }
            expect(EnhancementPricing.sellPrice("natural", 10, cfg)).to.equal(0)
        end)
    end)

    describe("EnhancementPricing.gradeFromOrigins", function()
        it("maps origin count to grade", function()
            expect(EnhancementPricing.gradeFromOrigins({})).to.equal("natural")
            expect(EnhancementPricing.gradeFromOrigins({ "geomancer" })).to.equal("single")
            expect(EnhancementPricing.gradeFromOrigins({ "geomancer", "pyromancer" })).to.equal(
                "dual"
            )
        end)

        it("treats nil/garbage as natural", function()
            expect(EnhancementPricing.gradeFromOrigins(nil)).to.equal("natural")
            expect(EnhancementPricing.gradeFromOrigins("nope")).to.equal("natural")
        end)
    end)

    describe("EnhancementPricing.junkSweep (dual-aware bulk buckets)", function()
        local BCFG = {
            grade_mult = { natural = 1.0, dual = 1.54, single = 2.86 },
            buy = { base = 20, per_level = 10 },
            sell = { fraction = 0.30 },
            bulk = { grades = { natural = true, dual = true }, dead_window = 2 },
        }
        -- Player: geomancer, L17 -> dead = level < 15.
        local stacks = {
            { uid = "a", origins = {}, level = 10, quantity = 3 }, -- dead natural -> naturals
            { uid = "b", origins = {}, level = 16, quantity = 9 }, -- alive natural -> skip
            { uid = "c", origins = { "geomancer", "pyromancer" }, level = 12, quantity = 2 }, -- dead dual -> duals
            { uid = "d", origins = { "geomancer", "pyromancer" }, level = 16, quantity = 1 }, -- alive + usable -> KEEP
            { uid = "e", origins = { "pyromancer", "cryomancer" }, level = 16, quantity = 4 }, -- alive but WRONG-origin -> duals
            { uid = "f", origins = { "geomancer" }, level = 5, quantity = 1 }, -- single -> protected
        }
        local plan =
            EnhancementPricing.junkSweep(stacks, 17, BCFG, { playerArchetype = "geomancer" })

        it("naturals bucket = dead naturals only", function()
            expect(plan.naturals.count).to.equal(3)
            expect(plan.naturals.gems).to.equal(108) -- natural L10 sell 36 ×3
            expect(#plan.naturals.items).to.equal(1)
        end)
        it("duals bucket = dead OR wrong-origin duals; keeps usable+alive", function()
            -- c: dual L12 sell floor(140*1.54*0.3)=64 ×2 = 128 ; e: dual L16 sell floor(180*1.54*0.3)=83 ×4 = 332
            expect(plan.duals.count).to.equal(6) -- 2 + 4
            expect(plan.duals.gems).to.equal(128 + 332)
            expect(#plan.duals.items).to.equal(2)
        end)
        it("never sweeps singles (protected)", function()
            for _, b in ipairs({ plan.naturals.items, plan.duals.items }) do
                for _, it in ipairs(b) do
                    expect(it.grade ~= "single").to.equal(true)
                end
            end
        end)
    end)

    describe("EnhancementPricing.catalog", function()
        local TYPES = { "damage", "accuracy", "spark", "healing" }

        it("offers buyable grades x non-excluded types at the player's band", function()
            local cfg = {
                level_step = 5,
                min_level = 5,
                max_level = 50,
                buyable_grades = { "natural" },
                exclude_types = { spark = true },
                grade_mult = { natural = 1.0 },
                buy = { base = 20, per_level = 10 },
            }
            local cat = EnhancementPricing.catalog(17, TYPES, cfg)
            expect(cat.band).to.equal(15) -- L17 -> L15
            expect(#cat.offers).to.equal(3) -- damage/accuracy/healing (spark excluded)
            for _, o in ipairs(cat.offers) do
                expect(o.level).to.equal(15)
                expect(o.grade).to.equal("natural")
                expect(o.price).to.equal(170) -- (20 + 10*15) * 1.0
                expect(o.type ~= "spark").to.equal(true)
            end
        end)
    end)
end
