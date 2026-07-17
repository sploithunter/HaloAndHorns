--[[
    PowerRegistry — [unit] unified record composed from the real powers config.
    Verifies the strangler read-model loses nothing and maps fields faithfully.
    Run: mise run test-headless
]]

local PowerRegistry = loadModule("src/Shared/Game/PowerRegistry.lua")
local PowerStats = loadModule("src/Shared/Game/PowerStats.lua")
local cfg = loadModule("configs/powers.lua")

local function approx(a, b)
    return math.abs(a - b) < 1e-6
end

local function contains(list, want)
    for _, v in ipairs(list) do
        if v == want then
            return true
        end
    end
    return false
end

return function()
    describe("PowerRegistry.record — identity + base stats", function()
        it("composes Eternal Winter (full hold + AoE DoT capstone)", function()
            local r = PowerRegistry.record("eternal_winter", cfg)
            expect(r.id).to.equal("eternal_winter")
            expect(r.name).to.equal("Eternal Winter")
            expect(r.effect).to.equal("hold") -- dispatch = family
            expect(r.durationBase).to.equal(12)
            expect(r.damageBase).to.equal(5) -- from dot.per_tick (10x world)
            expect(r.tickBase).to.equal(1)
            expect(r.radiusBase).to.equal(20)
            expect(r.params.area_scope).to.equal("encounter_group")
            expect(r.dot.aoe).to.equal(true)
            expect(r.origin[1]).to.equal("cryomancer")
            expect(contains(r.kind, "hold")).to.equal(true)
            expect(contains(r.kind, "dot")).to.equal(true)
        end)

        it("keeps Deep Freeze single-target while dispatching a full hold", function()
            local r = PowerRegistry.record("deep_freeze", cfg)
            expect(r.effect).to.equal("hold")
            expect(r.durationBase).to.equal(8)
            expect(contains(r.kind, "target")).to.equal(true)
            expect(contains(r.kind, "hold")).to.equal(true)
        end)

        it("dispatches Disarm as a single-target action lock rather than vulnerability", function()
            local r = PowerRegistry.record("disarm", cfg)
            expect(r.effect).to.equal("disarm")
            expect(r.durationBase).to.equal(6)
            expect(r.magnitudeBase).to.equal(0)
            expect(r.accuracyBase).to.equal(cfg.accuracy_family_base.disarm)
            expect(contains(r.kind, "target")).to.equal(true)
            expect(contains(r.kind, "hold")).to.equal(true)
        end)

        it("dispatches Focus Fire as an accuracy mark rather than vulnerability", function()
            local r = PowerRegistry.record("focus_fire", cfg)
            expect(r.effect).to.equal("accuracy_mark")
            expect(r.magnitudeBase).to.near(0.15)
            expect(r.durationBase).to.equal(8)
            expect(r.params.hold_pierce).to.near(0.25)
            expect(r.accuracyBase).to.equal(cfg.accuracy_family_base.accuracy_mark)
            expect(contains(r.kind, "target")).to.equal(true)
            expect(contains(r.kind, "debuff")).to.equal(true)
        end)

        it("gives each Cryomancer area control an explicit spatial contract", function()
            local frostField = PowerRegistry.record("frost_field", cfg)
            expect(frostField.radiusBase).to.equal(20)
            expect(frostField.params.area_scope).to.equal("player")

            local permafrost = PowerRegistry.record("permafrost", cfg)
            expect(permafrost.radiusBase).to.equal(30)
            expect(permafrost.params.area_scope).to.equal("encounter_group")

            local shatter = PowerRegistry.record("shatter", cfg)
            expect(shatter.radiusBase).to.equal(20)
            expect(shatter.params.area_scope).to.equal("targeted")

            local absoluteZero = PowerRegistry.record("absolute_zero", cfg)
            expect(absoluteZero.radiusBase).to.equal(20)
            expect(absoluteZero.params.area_scope).to.equal("targeted")

            local eternalWinter = PowerRegistry.record("eternal_winter", cfg)
            expect(eternalWinter.radiusBase).to.equal(20)
            expect(eternalWinter.params.area_scope).to.equal("encounter_group")
        end)

        it("composes Mark of Flame (vulnerable + targeted DoT)", function()
            local r = PowerRegistry.record("mark_of_flame", cfg)
            expect(r.effect).to.equal("vulnerable")
            expect(r.magnitudeBase).to.equal(1.5)
            expect(r.durationBase).to.equal(6) -- via the damage_over_time effect key
            expect(r.damageBase).to.equal(20) -- dot.per_tick (now on the USED key, 10x world)
            expect(r.dot.aoe).to.equal(false)
            expect(contains(r.kind, "dot")).to.equal(true)
        end)

        it("composes a generic power (Swift) with empty origin (white tier)", function()
            local r = PowerRegistry.record("swift", cfg)
            expect(r.generic).to.equal(true)
            expect(#r.origin).to.equal(0)
            expect(r.effect).to.equal("move_speed")
            expect(r.costBase).to.equal(15)
            expect(r.rechargeBase).to.equal(25)
            expect(contains(r.kind, "self")).to.equal(true)
        end)

        it("flags a single-pet power as ally targeting (Ice Armor)", function()
            local r = PowerRegistry.record("ice_armor", cfg)
            expect(r.target).to.equal("single_pet")
            expect(contains(r.kind, "ally")).to.equal(true)
        end)
    end)

    describe("PowerRegistry — nothing exotic is lost (params passthrough)", function()
        it("preserves Inferno Brand's ramp_to in params", function()
            local r = PowerRegistry.record("inferno_brand", cfg)
            expect(r.params.ramp_to).to.equal(2.6)
        end)
        it("keeps the raw dot spec on params too", function()
            local r = PowerRegistry.record("wildfire", cfg)
            expect(r.params.dot.aoe).to.equal(true)
            expect(r.params.spread_radius).to.equal(14)
        end)
    end)

    describe("PowerRegistry — new fields default safely", function()
        it("accuracyBase defaults to 1 for families with no roll, critBase to 0", function()
            local r = PowerRegistry.record("mountains_strength", cfg) -- buff family: auto-lands
            expect(r.accuracyBase).to.equal(1)
            expect(r.critBase).to.equal(0)
        end)
        it("debuff/control families take the sub-1 accuracy_family_base (can miss)", function()
            local r = PowerRegistry.record("strike", cfg) -- vulnerable family -> 0.9 default
            expect(r.accuracyBase).to.equal(cfg.accuracy_family_base.vulnerable)
            local hold = PowerRegistry.record("deep_freeze", cfg)
            expect(hold.accuracyBase).to.equal(cfg.accuracy_family_base.hold)
        end)
        it("returns nil for an unknown id", function()
            expect(PowerRegistry.record("nope_not_real", cfg)).to.equal(nil)
        end)
    end)

    describe("P3 scaling — the real config curve applies to DoT damage", function()
        local rec = PowerRegistry.record("eternal_winter", cfg)
        it("is flat at level 1 (×1)", function()
            local eff = PowerStats.resolveEffective(rec, { casterLevel = 1, scaling = cfg.scaling })
            expect(approx(eff.damage, 5)).to.equal(true)
        end)
        it("grows by +3%/level (level 50 ≈ 5 × 2.47)", function()
            local eff =
                PowerStats.resolveEffective(rec, { casterLevel = 50, scaling = cfg.scaling })
            expect(approx(eff.damage, 5 * (1 + 0.03 * 49))).to.equal(true) -- 12.35
        end)
        it("leaves duration FLAT (no scaling entry for it)", function()
            local eff =
                PowerStats.resolveEffective(rec, { casterLevel = 50, scaling = cfg.scaling })
            expect(eff.duration).to.equal(12)
        end)
    end)

    describe("PowerRegistry.all — covers the whole roster", function()
        local all = PowerRegistry.all(cfg)
        it("includes known powers", function()
            expect(all.eternal_winter ~= nil).to.equal(true)
            expect(all.swift ~= nil).to.equal(true)
            expect(all.cataclysm ~= nil).to.equal(true)
        end)
    end)
end
