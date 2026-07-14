--[[
    EffectiveStats — [unit] the SSOT per-axis buff registry (doctrine
    2026-07-14: one formula per derived stat, publisher + gameplay + HUD all
    read it). Run: mise run test-headless
]]

local EffectiveStats = loadModule("src/Shared/Game/EffectiveStats.lua")

return function()
    local NOW = 1000
    local function getter(attrs)
        return function(name)
            return attrs[name]
        end
    end

    describe("EffectiveStats.multiplier", function()
        it("folds multiplier-attrs as (v-1) and fraction-attrs as v, additively", function()
            local get = getter({
                CoinYieldBuff = 1.5, -- multiplier attr -> +0.5
                CoinYieldBuffUntil = NOW + 60,
                CoinYieldPower = 0.25, -- fraction attr -> +0.25
                CoinYieldPowerUntil = NOW + 60,
            })
            local m = EffectiveStats.multiplier("coin_yield", get, NOW, { cap = 5 })
            expect(math.abs(m - 1.75) < 1e-9).to.equal(true)
        end)

        it("ignores expired sources", function()
            local get = getter({
                MiningBuff = 0.8,
                MiningBuffUntil = NOW - 1, -- dead
            })
            expect(EffectiveStats.multiplier("mining", get, NOW, { cap = 5 })).to.equal(1)
        end)

        it("appends extraSources under the SAME cap (per-entity terms can't escape it)", function()
            local get = getter({
                PetDamageBuff = 2.0, -- +1.0
                PetDamageBuffUntil = NOW + 60,
            })
            local m = EffectiveStats.multiplier("pet_damage", get, NOW, { cap = 1.5 }, {
                { fraction = 1.0, expiry = NOW + 60 }, -- rage-like per-pet term
            })
            -- 1.0 + 1.0 = 2.0 capped at 1.5 -> x2.5
            expect(math.abs(m - 2.5) < 1e-9).to.equal(true)
        end)

        it("unknown axis is a neutral x1", function()
            expect(EffectiveStats.multiplier("nope", getter({}), NOW, nil)).to.equal(1)
        end)
    end)

    describe("EffectiveStats.rechargeFraction", function()
        it("sums the power AND the Ashwing aura channel under the 0.9 clamp", function()
            local get = getter({
                RechargeBuff = 0.5,
                RechargeBuffUntil = NOW + 60,
                RechargeAura = 0.6,
                RechargeAuraUntil = NOW + 60,
            })
            -- 0.5 + 0.6 = 1.1 -> clamped 0.9 (a cooldown never hits zero)
            expect(EffectiveStats.rechargeFraction(get, NOW)).to.equal(0.9)
        end)

        it("aura-only counts (the drift the old HUD mirror missed)", function()
            local get = getter({
                RechargeAura = 0.3,
                RechargeAuraUntil = NOW + 60,
            })
            expect(math.abs(EffectiveStats.rechargeFraction(get, NOW) - 0.3) < 1e-9).to.equal(true)
        end)

        it("expired channels contribute nothing", function()
            local get = getter({
                RechargeBuff = 0.5,
                RechargeBuffUntil = NOW - 1,
            })
            expect(EffectiveStats.rechargeFraction(get, NOW)).to.equal(0)
        end)
    end)

    describe("EffectiveStats.nextExpiry", function()
        it("returns the soonest FUTURE deadline across the axis's timers", function()
            local get = getter({
                LuckBuffUntil = NOW + 30,
                LuckBuffPotionUntil = NOW + 10,
                HatchLuckBuffUntil = NOW - 5, -- past: ignored
            })
            expect(EffectiveStats.nextExpiry("luck", get, NOW)).to.equal(NOW + 10)
        end)

        it("nil when nothing is pending", function()
            expect(EffectiveStats.nextExpiry("xp", getter({}), NOW)).to.equal(nil)
        end)
    end)

    describe("registry shape", function()
        it("every axis publishes a distinct Eff_ attribute and watches its inputs", function()
            local seen = {}
            for axisId, def in pairs(EffectiveStats.AXES) do
                expect(type(def.attr)).to.equal("string")
                expect(seen[def.attr]).to.equal(nil)
                seen[def.attr] = axisId
                expect(#def.watch > 0).to.equal(true)
                expect(type(def.sources)).to.equal("function")
            end
        end)
    end)
end
