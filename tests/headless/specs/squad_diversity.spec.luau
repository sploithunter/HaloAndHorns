--[[
    SquadDiversity — [unit] team-composition bonus (distinct archetypes + origins).
    Run: mise run test-headless
]]

local SquadDiversity = loadModule("src/Shared/Game/SquadDiversity.lua")

-- Test config: 4 archetypes, 4 origins, +5% per distinct, +10% full set, cap 2.0.
local CFG = {
    enabled = true,
    archetype = {
        categories = { "tank", "melee", "ranged", "support" },
        per_distinct = 0.05,
        full_set_bonus = 0.10,
    },
    origin = {
        categories = { "lava", "ice", "grass", "desert" },
        per_distinct = 0.05,
        full_set_bonus = 0.10,
    },
    max_mult = 2.0,
}

local function approx(a, b)
    return math.abs(a - b) < 1e-9
end

return function()
    describe("SquadDiversity.evaluate", function()
        it("counts DISTINCT categories, not pet count", function()
            local r = SquadDiversity.evaluate({
                { archetype = "tank", origin = "lava" },
                { archetype = "melee", origin = "ice" },
            }, CFG)
            expect(r.archetype.distinct).to.equal(2)
            expect(r.origin.distinct).to.equal(2)
            -- 2*0.05 (arch) + 2*0.05 (origin) = 0.20
            expect(approx(r.mult, 1.20)).to.equal(true)
        end)

        it("duplicates earn nothing (two Blasters = one distinct archetype)", function()
            local r = SquadDiversity.evaluate({
                { archetype = "ranged", origin = "lava" },
                { archetype = "ranged", origin = "lava" },
            }, CFG)
            expect(r.archetype.distinct).to.equal(1)
            expect(r.origin.distinct).to.equal(1)
            expect(approx(r.mult, 1.10)).to.equal(true) -- 0.05 + 0.05
        end)

        it("awards the full-set kicker when every category is covered", function()
            local full = SquadDiversity.evaluate({
                { archetype = "tank", origin = "lava" },
                { archetype = "melee", origin = "ice" },
                { archetype = "ranged", origin = "grass" },
                { archetype = "support", origin = "desert" },
            }, CFG)
            expect(full.archetype.full).to.equal(true)
            expect(full.origin.full).to.equal(true)
            -- per axis: 4*0.05 + 0.10 = 0.30; mult = 1 + 0.30 + 0.30 = 1.60
            expect(approx(full.archetype.bonus, 0.30)).to.equal(true)
            expect(approx(full.mult, 1.60)).to.equal(true)
        end)

        it("reports the MISSING categories (for the HUD nudge)", function()
            local r = SquadDiversity.evaluate({
                { archetype = "tank", origin = "lava" },
                { archetype = "melee", origin = "ice" },
            }, CFG)
            expect(#r.archetype.missing).to.equal(2) -- ranged, support
            expect(#r.origin.missing).to.equal(2) -- grass, desert
        end)

        it("ignores unknown/origin-less tags (never a free distinct)", function()
            local r = SquadDiversity.evaluate({
                { archetype = "tank", origin = nil }, -- origin-less (e.g. exclusive)
                { archetype = "bogus", origin = "lava" }, -- unknown archetype
            }, CFG)
            expect(r.archetype.distinct).to.equal(1) -- only tank counts
            expect(r.origin.distinct).to.equal(1) -- only lava counts
        end)

        it("clamps the combined multiplier to max_mult", function()
            local capped =
                { enabled = true, max_mult = 1.25, archetype = CFG.archetype, origin = CFG.origin }
            local full = SquadDiversity.evaluate({
                { archetype = "tank", origin = "lava" },
                { archetype = "melee", origin = "ice" },
                { archetype = "ranged", origin = "grass" },
                { archetype = "support", origin = "desert" },
            }, capped)
            expect(approx(full.mult, 1.25)).to.equal(true) -- would be 1.60, clamped
        end)

        it("is a no-op (1.0) when disabled or empty", function()
            expect(SquadDiversity.evaluate({}, CFG).mult).to.equal(1)
            expect(
                SquadDiversity.evaluate(
                    { { archetype = "tank", origin = "lava" } },
                    { enabled = false }
                ).mult
            ).to.equal(1)
        end)
    end)
end
