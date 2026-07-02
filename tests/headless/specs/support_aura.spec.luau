--[[
    SupportAura.forPet / isBuffer — [unit] per-zone buffer aura lookup.
    Run: mise run test-headless
]]

local SupportAura = loadModule("src/Shared/Game/SupportAura.lua")

local ROLES = {
    by_type = { bunny = "support", penguin = "support", doggy = "melee" },
    support_auras = {
        bunny = { kind = "heal", interval = 1.5, fraction = 0.3 },
        penguin = { kind = "defense", interval = 2.0, amount = 80, duration = 3 },
        emberimp = { kind = "offense", interval = 2.0, mult = 1.25, duration = 3 },
        meerkat = { kind = "yield", interval = 2.0, mult = 1.25, duration = 3 },
    },
}

return function()
    describe("SupportAura.forPet", function()
        it("returns the themed aura for each zone's buffer", function()
            expect(SupportAura.forPet("bunny", ROLES).kind).to.equal("heal")
            expect(SupportAura.forPet("penguin", ROLES).kind).to.equal("defense")
            expect(SupportAura.forPet("emberimp", ROLES).kind).to.equal("offense")
            expect(SupportAura.forPet("meerkat", ROLES).kind).to.equal("yield")
        end)

        it("carries the tuning knobs through", function()
            local d = SupportAura.forPet("penguin", ROLES)
            expect(d.amount).to.equal(80)
            expect(d.duration).to.equal(3)
        end)

        it("returns nil for a non-buffer pet", function()
            expect(SupportAura.forPet("doggy", ROLES)).to.equal(nil)
        end)

        it("defaults safely on missing/garbage input", function()
            expect(SupportAura.forPet("bunny", nil)).to.equal(nil)
            expect(SupportAura.forPet(nil, ROLES)).to.equal(nil)
            expect(SupportAura.forPet("bunny", {})).to.equal(nil)
        end)
    end)

    describe("SupportAura.isBuffer", function()
        it("is true only for pets with an aura", function()
            expect(SupportAura.isBuffer("bunny", ROLES)).to.equal(true)
            expect(SupportAura.isBuffer("meerkat", ROLES)).to.equal(true)
            expect(SupportAura.isBuffer("doggy", ROLES)).to.equal(false)
        end)
    end)

    -- The ONE implementation of the rage rules — EnemyService (live stamp) and
    -- BattleSim (simulated swings) both route through these.
    describe("SupportAura rage rules", function()
        local RAGE = { kind = "rage", enrage_below = 0.5, mult = 1.5 }

        it("gates on the enrage threshold (at-or-below rages)", function()
            expect(SupportAura.isEnraged(RAGE, 0.51)).to.equal(false)
            expect(SupportAura.isEnraged(RAGE, 0.5)).to.equal(true)
            expect(SupportAura.isEnraged(RAGE, 0)).to.equal(true)
        end)

        it("is never enraged for non-rage auras or garbage", function()
            expect(SupportAura.isEnraged({ kind = "offense" }, 0)).to.equal(false)
            expect(SupportAura.isEnraged(nil, 0)).to.equal(false)
        end)

        it("scales the fraction (not the multiplier) by variant", function()
            expect(SupportAura.rageMultiplier(RAGE, 0.4, 1)).to.equal(1.5) -- basic +50%
            expect(SupportAura.rageMultiplier(RAGE, 0.4, 1.5)).to.equal(1.75) -- rainbow +75%
            expect(SupportAura.rageMultiplier(RAGE, 0.6, 1)).to.equal(nil) -- calm
        end)

        it("sums rage fractions additively across an aura list", function()
            local auras = { RAGE, { kind = "offense", mult = 1.2 }, RAGE }
            expect(SupportAura.rageFraction(auras, 0.3, 1)).to.equal(1.0) -- 0.5 + 0.5
            expect(SupportAura.rageFraction(auras, 0.9, 1)).to.equal(0) -- calm
            expect(SupportAura.rageFraction(nil, 0.3, 1)).to.equal(0)
        end)

        it("defaults enrage_below to 0.5 and clamps it to [0, 1]", function()
            expect(SupportAura.isEnraged({ kind = "rage" }, 0.5)).to.equal(true)
            expect(SupportAura.isEnraged({ kind = "rage", enrage_below = 7 }, 1)).to.equal(true)
        end)
    end)

    describe(
        "SupportAura.rageRampFraction (cast Rage power: base + GROWING critical, no cap)",
        function()
            -- base 0.15, rate 0.5, threshold 50%: bonus = base + rate*((below-hp)/hp) below the threshold.
            it("returns only the base at or above the enrage threshold", function()
                expect(SupportAura.rageRampFraction(0.15, 0.5, 0.5, 1.0)).to.equal(0.15) -- full HP
                expect(SupportAura.rageRampFraction(0.15, 0.5, 0.5, 0.5)).to.equal(0.15) -- exactly at threshold
                expect(SupportAura.rageRampFraction(0.15, 0.5, 0.5, 0.75)).to.equal(0.15) -- above
            end)

            it("GROWS as HP drops, with no ceiling (accelerating toward 0)", function()
                -- hp=0.25: 0.15 + 0.5*((0.5-0.25)/0.25) = 0.15 + 0.5*1 = 0.65
                expect(SupportAura.rageRampFraction(0.15, 0.5, 0.5, 0.25)).to.equal(0.65)
                -- hp=0.10: 0.15 + 0.5*((0.4)/0.10) = 0.15 + 0.5*4 = 2.15 (well past any old cap)
                expect(SupportAura.rageRampFraction(0.15, 0.5, 0.5, 0.10)).to.equal(2.15)
                -- hp=0.05: 0.15 + 0.5*((0.45)/0.05) = 0.15 + 0.5*9 = 4.65
                expect(SupportAura.rageRampFraction(0.15, 0.5, 0.5, 0.05)).to.equal(4.65)
            end)

            it(
                "clamps HP fraction to [0,1]; hp==0 falls back to base (pet is down, not attacking)",
                function()
                    expect(SupportAura.rageRampFraction(0.15, 0.5, 0.5, 0)).to.equal(0.15) -- exactly 0 → base only
                    expect(SupportAura.rageRampFraction(0.15, 0.5, 0.5, -3)).to.equal(0.15) -- <0 clamps to 0
                    expect(SupportAura.rageRampFraction(0.15, 0.5, 0.5, 9)).to.equal(0.15) -- >1 clamps to 1
                end
            )

            it("defaults/guards garbage args to 0 base + 0 crit", function()
                expect(SupportAura.rageRampFraction(nil, nil, nil, nil)).to.equal(0)
                expect(SupportAura.rageRampFraction(-1, -1, 0.5, 0)).to.equal(0) -- negatives floored
            end)
        end
    )

    describe("SupportAura.rankTargets (single-target empower selection)", function()
        it("ranks highest_power first (the default carry rule)", function()
            local ranked = SupportAura.rankTargets({
                { key = "a", power = 10 },
                { key = "b", power = 42 },
                { key = "c", power = 25 },
            })
            expect(ranked[1]).to.equal("b")
            expect(ranked[2]).to.equal("c")
            expect(ranked[3]).to.equal("a")
        end)

        it("lowest_power reverses the order (mercy buff)", function()
            local ranked = SupportAura.rankTargets({
                { key = "a", power = 10 },
                { key = "b", power = 42 },
            }, "lowest_power")
            expect(ranked[1]).to.equal("a")
            expect(ranked[2]).to.equal("b")
        end)

        it("breaks power ties by insertion order (deterministic, no flicker)", function()
            local ranked = SupportAura.rankTargets({
                { key = "first", power = 30 },
                { key = "second", power = 30 },
            })
            expect(ranked[1]).to.equal("first")
            expect(ranked[2]).to.equal("second")
        end)

        it("returns an empty list for no candidates", function()
            expect(#SupportAura.rankTargets({})).to.equal(0)
            expect(#SupportAura.rankTargets(nil)).to.equal(0)
        end)
    end)
end
