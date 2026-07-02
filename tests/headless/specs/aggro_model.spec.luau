--[[
    AggroModel — pure threat magnitude + engage-hysteresis math (configs/aggro.lua).
    Run: mise run test-headless
]]

local AggroModel = loadModule("src/Shared/Game/AggroModel.lua")

-- Fully symmetric cfg (every side mult 1.0).
local CFG = {
    base = {
        threat_per_damage = 1.0,
        splash_frac = 0.25,
        seed_rate = 2,
        engage_floor = 5,
        exit_floor = 1,
        decay = { per_second = 4 },
    },
    pet = { threat_mult = 1.0, decay_mult = 1.0, splash_mult = 1.0, seed_mult = 1.0 },
    enemy = { threat_mult = 1.0, decay_mult = 1.0, splash_mult = 1.0, seed_mult = 1.0 },
}

-- Asymmetric: pets care half as much, enemies twice as much (the artificial difficulty dial).
local ASYM = {
    base = CFG.base,
    pet = { threat_mult = 0.5, decay_mult = 0.5, splash_mult = 0.5, seed_mult = 0.5 },
    enemy = { threat_mult = 2.0, decay_mult = 2.0, splash_mult = 2.0, seed_mult = 2.0 },
}

return function()
    describe("AggroModel.threatFromDamage", function()
        it("equals damage when threat_per_damage and side mult are 1", function()
            expect(AggroModel.threatFromDamage(CFG, "pet", 100)).to.equal(100)
            expect(AggroModel.threatFromDamage(CFG, "enemy", 40)).to.equal(40)
        end)

        it("is symmetric across sides at mult 1.0", function()
            expect(AggroModel.threatFromDamage(CFG, "pet", 73)).to.equal(
                AggroModel.threatFromDamage(CFG, "enemy", 73)
            )
        end)

        it("scales by the per-side mult (the difficulty dial)", function()
            expect(AggroModel.threatFromDamage(ASYM, "pet", 100)).to.equal(50)
            expect(AggroModel.threatFromDamage(ASYM, "enemy", 100)).to.equal(200)
        end)

        it("is zero for non-positive damage", function()
            expect(AggroModel.threatFromDamage(CFG, "pet", 0)).to.equal(0)
            expect(AggroModel.threatFromDamage(CFG, "pet", -5)).to.equal(0)
        end)
    end)

    describe("AggroModel.threatMult", function()
        it("is the side threat_mult (1.0 symmetric, the difficulty dial otherwise)", function()
            expect(AggroModel.threatMult(CFG, "enemy")).to.equal(1)
            expect(AggroModel.threatMult(ASYM, "pet")).to.equal(0.5)
            expect(AggroModel.threatMult(ASYM, "enemy")).to.equal(2)
            expect(AggroModel.threatMult(nil, "enemy")).to.equal(1)
        end)
    end)

    describe("AggroModel.splashThreat", function()
        it("gives teammates the configured fraction of the direct credit", function()
            expect(AggroModel.splashThreat(CFG, "pet", 100)).to.equal(25) -- 0.25 frac
        end)

        it("scales by the side splash mult", function()
            expect(AggroModel.splashThreat(ASYM, "enemy", 100)).to.equal(50) -- 0.25 * 2.0
        end)

        it("is zero for non-positive direct threat", function()
            expect(AggroModel.splashThreat(CFG, "pet", 0)).to.equal(0)
        end)
    end)

    describe("AggroModel.seedThreat", function()
        it("is seed_rate * dt at mult 1", function()
            expect(AggroModel.seedThreat(CFG, "enemy", 0.5)).to.equal(1) -- 2 * 0.5
        end)

        it("scales by the side seed mult", function()
            expect(AggroModel.seedThreat(ASYM, "enemy", 1)).to.equal(4) -- 2 * 2.0
        end)
    end)

    describe("AggroModel.decayRate", function()
        it("is per_second * side mult * distance mult", function()
            expect(AggroModel.decayRate(CFG, "pet", 1)).to.equal(4)
            expect(AggroModel.decayRate(CFG, "pet", 3)).to.equal(12) -- chase
            expect(AggroModel.decayRate(ASYM, "enemy", 3)).to.equal(24) -- 4 * 2.0 * 3
        end)
    end)

    describe("AggroModel.engaged (hysteresis)", function()
        it("does not engage below engage_floor from cold", function()
            expect(AggroModel.engaged(4.9, false, CFG)).to.equal(false)
        end)

        it("engages once threat reaches engage_floor", function()
            expect(AggroModel.engaged(5, false, CFG)).to.equal(true)
        end)

        it("stays engaged in the hysteresis band (exit_floor < t < engage_floor)", function()
            expect(AggroModel.engaged(2, true, CFG)).to.equal(true)
        end)

        it("disengages once threat drops to/below exit_floor", function()
            expect(AggroModel.engaged(1, true, CFG)).to.equal(false)
            expect(AggroModel.engaged(0.5, true, CFG)).to.equal(false)
        end)
    end)

    describe("AggroModel defaults (missing/partial cfg)", function()
        it("falls back to base defaults when cfg is nil", function()
            expect(AggroModel.threatFromDamage(nil, "pet", 10)).to.equal(10) -- 1.0 * 1
            expect(AggroModel.splashThreat(nil, "pet", 100)).to.equal(25) -- 0.25
            expect(AggroModel.engaged(5, false, nil)).to.equal(true) -- default engage_floor 5
            expect(AggroModel.decayRate(nil, "enemy", 1)).to.equal(4) -- default per_second 4
        end)
    end)

    describe("AggroModel.rageLatch (rage tipping point)", function()
        -- per-side knobs (the two sides' tables live on very different scales)
        local RAGE_CFG = {
            rage = {
                amp = 1.5,
                pet = { tip = 200, calm = 80 },
                enemy = { tip = 8000, calm = 3000 },
            },
        }

        it("stays calm below the tip", function()
            expect(AggroModel.rageLatch(RAGE_CFG, "pet", false, 200)).to.equal(false) -- at, not past
            expect(AggroModel.rageLatch(RAGE_CFG, "pet", false, 150)).to.equal(false)
        end)

        it("latches berserk past the tip", function()
            expect(AggroModel.rageLatch(RAGE_CFG, "pet", false, 201)).to.equal(true)
        end)

        it("stays berserk in the hysteresis band (calm < heat < tip)", function()
            expect(AggroModel.rageLatch(RAGE_CFG, "pet", true, 120)).to.equal(true)
        end)

        it("calms once heat cools to/below calm", function()
            expect(AggroModel.rageLatch(RAGE_CFG, "pet", true, 80)).to.equal(false)
            expect(AggroModel.rageLatch(RAGE_CFG, "pet", true, 10)).to.equal(false)
        end)

        it("resolves per-side knobs (enemy tip is on the DPS-credited scale)", function()
            expect(AggroModel.rageLatch(RAGE_CFG, "enemy", false, 201)).to.equal(false) -- pet-scale heat
            expect(AggroModel.rageLatch(RAGE_CFG, "enemy", false, 8001)).to.equal(true)
            expect(AggroModel.rageLatch(RAGE_CFG, "enemy", true, 3000)).to.equal(false)
        end)

        it("never rages when the knobs are missing (safe default)", function()
            expect(AggroModel.rageLatch(nil, "pet", false, 1e9)).to.equal(false)
            expect(AggroModel.rageLatch({}, "enemy", false, 1e9)).to.equal(false)
        end)
    end)
end
