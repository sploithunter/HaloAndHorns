--[[
    PowerStats.resolveEffective — [unit] base→effective resolution.
    Identity by default; level scaling per axis; accuracy via the REAL Accuracy curve (injected).
    Run: mise run test-headless
]]

local PowerStats = loadModule("src/Shared/Game/PowerStats.lua")
local Accuracy = loadModule("src/Shared/Game/Accuracy.lua")

-- mirrors configs/combat.lua `accuracy`
local accCfg = { base_to_hit = 0.92, per_level_step = 0.04, floor = 0.05, cap = 0.95 }

local function approx(a, b)
    return math.abs(a - b) < 1e-9
end

return function()
    describe("PowerStats — identity by default (no scaling ⇒ effective == base)", function()
        local eternal = {
            kind = { "aoe", "hold", "dot" },
            costBase = 0,
            rechargeBase = 40,
            durationBase = 12,
            damageBase = 0.5,
            tickBase = 1,
            radiusBase = 16,
            magnitudeBase = 0,
            accuracyBase = 1.0,
            critBase = 0,
        }
        local eff = PowerStats.resolveEffective(eternal, { casterLevel = 25 })

        it("passes base stats straight through", function()
            expect(eff.recharge).to.equal(40)
            expect(eff.duration).to.equal(12)
            expect(approx(eff.damage, 0.5)).to.equal(true)
            expect(eff.tick).to.equal(1)
            expect(eff.radius).to.equal(16)
        end)
        it("auto-lands when no target level is supplied (accuracy = base)", function()
            expect(eff.accuracy).to.equal(1.0)
        end)
        it("no crit by default", function()
            expect(eff.crit).to.equal(0)
        end)
        it("missing fields default to 0 / nil targets", function()
            local bare = PowerStats.resolveEffective({ kind = { "self" } }, {})
            expect(bare.damage).to.equal(0)
            expect(bare.heal).to.equal(0)
            expect(bare.targets).to.equal(nil)
            expect(bare.accuracy).to.equal(1) -- accuracyBase defaults to 1
        end)
    end)

    describe("PowerStats.levelScale — per-axis curve", function()
        local cfg = { per_level = 0.1, base_level = 1, min = 1, max = 3 } -- +10%/level over L1, capped ×3
        it("is identity with no config", function()
            expect(PowerStats.levelScale(50, nil)).to.equal(1)
        end)
        it("scales linearly from the base level", function()
            expect(approx(PowerStats.levelScale(1, cfg), 1.0)).to.equal(true)
            expect(approx(PowerStats.levelScale(11, cfg), 2.0)).to.equal(true) -- 1 + 0.1*10
        end)
        it("clamps to max", function()
            expect(PowerStats.levelScale(100, cfg)).to.equal(3)
        end)
    end)

    describe("PowerStats — damage scales when a scaling axis is configured", function()
        local power = { kind = { "aoe", "dot" }, damageBase = 2 }
        it("doubles damage at the curve's ×2 level", function()
            local eff = PowerStats.resolveEffective(power, {
                casterLevel = 11,
                scaling = { damage = { per_level = 0.1, base_level = 1, min = 1, max = 3 } },
            })
            expect(approx(eff.damage, 4)).to.equal(true) -- 2 × 2.0
        end)
    end)

    describe("PowerStats — accuracy via the injected Accuracy curve", function()
        local hostile = { kind = { "target", "dot" }, accuracyBase = 1.0 }
        it("hostile + target level ⇒ accuracyBase × toHit (even level = 0.92)", function()
            local eff = PowerStats.resolveEffective(hostile, {
                casterLevel = 10,
                targetLevel = 10,
                toHit = Accuracy.toHit,
                accuracy = accCfg,
            })
            expect(approx(eff.accuracy, 0.92)).to.equal(true)
        end)
        it("a boss (reads +2) is harder to hit", function()
            local eff = PowerStats.resolveEffective(hostile, {
                casterLevel = 10,
                targetLevel = 12,
                toHit = Accuracy.toHit,
                accuracy = accCfg,
            })
            expect(approx(eff.accuracy, 0.84)).to.equal(true)
        end)
        it("accuracyBase scales the rolled chance (a swingy nuke at 0.8 base)", function()
            local nuke = { kind = { "aoe" }, accuracyBase = 0.8 }
            local eff = PowerStats.resolveEffective(nuke, {
                casterLevel = 10,
                targetLevel = 10,
                toHit = Accuracy.toHit,
                accuracy = accCfg,
            })
            expect(approx(eff.accuracy, 0.736)).to.equal(true) -- 0.8 × 0.92
        end)
        it("a SELF/ally power never rolls even with a target level (auto-lands)", function()
            local buff = { kind = { "team", "buff" }, accuracyBase = 1.0 }
            local eff = PowerStats.resolveEffective(buff, {
                casterLevel = 10,
                targetLevel = 10,
                toHit = Accuracy.toHit,
                accuracy = accCfg,
            })
            expect(eff.accuracy).to.equal(1.0)
        end)
        it("crystals (no target level) auto-land for a farm power", function()
            local farm = { kind = { "farm", "debuff" }, accuracyBase = 1.0 }
            local eff = PowerStats.resolveEffective(
                farm,
                { casterLevel = 10, toHit = Accuracy.toHit, accuracy = accCfg }
            )
            expect(eff.accuracy).to.equal(1.0)
        end)
    end)

    describe("PowerStats — accuracy enhancement lifts a sub-1 base (debuff to-hit)", function()
        it("a +accuracy enhancement raises the pre-toHit accuracy (clamped at 1)", function()
            local mark = { kind = { "target" }, accuracyBase = 0.9 } -- a vulnerable mark, lands <1
            local eff = PowerStats.resolveEffective(
                mark,
                { casterLevel = 9, enhancements = { accuracy = 0.2 } }
            )
            expect(approx(eff.accuracy, 1.0)).to.equal(true) -- 0.9 × 1.2 = 1.08 → clamp 1
        end)
        it("the lift is visible below the clamp with a lower base", function()
            local low = { kind = { "target" }, accuracyBase = 0.6 }
            local eff = PowerStats.resolveEffective(
                low,
                { casterLevel = 9, enhancements = { accuracy = 0.2 } }
            )
            expect(approx(eff.accuracy, 0.72)).to.equal(true) -- 0.6 × 1.2
        end)
        it("no accuracy enhancement leaves the base unchanged", function()
            local mark = { kind = { "target" }, accuracyBase = 0.9 }
            local eff = PowerStats.resolveEffective(mark, { casterLevel = 9 })
            expect(approx(eff.accuracy, 0.9)).to.equal(true)
        end)
    end)

    describe("PowerStats — radius-magnitude fold (Magnet: range == reach)", function()
        -- a Magnet-like passive: reach lives on magnitudeBase, no radiusBase
        local magnet = { kind = { "self" }, magnitudeBase = 30 }
        it("folds a range (radius) enhancement INTO magnitude when flagged", function()
            local eff = PowerStats.resolveEffective(magnet, {
                casterLevel = 7,
                enhancements = { radius = 0.2 },
                radiusMagnitude = true,
            })
            expect(approx(eff.magnitude, 36)).to.equal(true) -- 30 × (1 + 0.2)
        end)
        it("adds magnitude + radius boosts together when both axes are slotted", function()
            local eff = PowerStats.resolveEffective(magnet, {
                casterLevel = 7,
                enhancements = { magnitude = 0.15, radius = 0.2 },
                radiusMagnitude = true,
            })
            expect(approx(eff.magnitude, 40.5)).to.equal(true) -- 30 × (1 + 0.35)
        end)
        it("WITHOUT the flag, a radius boost does nothing to magnitude (default)", function()
            local eff = PowerStats.resolveEffective(magnet, {
                casterLevel = 7,
                enhancements = { radius = 0.2 },
            })
            expect(eff.magnitude).to.equal(30) -- radius lands on radiusBase (0), not the reach
        end)
    end)

    describe(
        "PowerStats — damage-magnitude fold (Sandstorm: damage == vulnerability mag)",
        function()
            -- a vulnerability debuff: its potency lives on magnitudeBase, no damageBase
            local sandstorm = { kind = { "targeted_aoe" }, magnitudeBase = 1.5 }
            it("folds a damage enhancement INTO magnitude when flagged", function()
                local eff = PowerStats.resolveEffective(sandstorm, {
                    casterLevel = 9,
                    enhancements = { damage = 0.33 },
                    damageIsMagnitude = true,
                })
                expect(approx(eff.magnitude, 1.995)).to.equal(true) -- 1.5 × (1 + 0.33)
            end)
            it(
                "folds a healing enhancement INTO magnitude when flagged (heal == magnitude)",
                function()
                    -- heal powers store the heal amount in magnitude (no healBase), so `healing` folds
                    local heal = { kind = { "team" }, magnitudeBase = 600 }
                    local eff = PowerStats.resolveEffective(heal, {
                        casterLevel = 9,
                        enhancements = { heal = 0.2 },
                        healIsMagnitude = true,
                    })
                    expect(approx(eff.magnitude, 720)).to.equal(true) -- 600 × (1 + 0.2)
                end
            )
            it(
                "WITHOUT the flag, a damage boost does nothing to magnitude (no damageBase)",
                function()
                    local eff = PowerStats.resolveEffective(sandstorm, {
                        casterLevel = 9,
                        enhancements = { damage = 0.33 },
                    })
                    expect(eff.magnitude).to.equal(1.5) -- damage lands on damageBase (0) = no change
                end
            )
        end
    )

    describe("PowerStats — crit is additive (power + buff/aura)", function()
        it("sums critBase and the injected critBonus", function()
            local power = { kind = { "target" }, critBase = 0.1 }
            local eff = PowerStats.resolveEffective(power, { critBonus = 0.25 })
            expect(approx(eff.crit, 0.35)).to.equal(true)
        end)
    end)
end
