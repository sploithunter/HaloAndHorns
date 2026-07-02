--[[
    PetPower — single source of truth for configured base power (huge-aware).
    Run: mise run test-headless
]]

local PetPower = loadModule("src/Shared/Game/PetPower.lua")

-- mimic configs/pets.lua getPet() output
local bearBasic = { power = 10, huge_base_power = 100, rarity_id = "huge" }
local bearGolden = { power = 15, huge_base_power = 100 }
local doggy = { power = 12 } -- no huge_base_power configured

-- normalized-cap scaling (Jason): bonus = max_bonus x (level-1)/(maxLevel-1)
local prog = {
    enabled = true,
    default_max_level = 1,
    max_level_by_rarity = { huge = 11 },
    power_scaling = { type = "normalized_cap", max_bonus_percent = 1.0 },
}

return function()
    describe("PetPower.configuredBasePower", function()
        it("uses variant power for a normal pet", function()
            expect(PetPower.configuredBasePower(bearBasic, false)).to.equal(10)
            expect(PetPower.configuredBasePower(bearGolden, false)).to.equal(15)
        end)

        it("uses huge_base_power for a huge pet", function()
            expect(PetPower.configuredBasePower(bearBasic, true)).to.equal(100)
            expect(PetPower.configuredBasePower(bearGolden, true)).to.equal(100)
        end)

        it("falls back to variant power if huge_base_power is unset", function()
            expect(PetPower.configuredBasePower(doggy, true)).to.equal(12)
        end)

        it("is safe with nil config", function()
            expect(PetPower.configuredBasePower(nil, true)).to.equal(1)
        end)
    end)

    describe("PetPower.withLevel (normalized cap)", function()
        it("is the base at level 1", function()
            expect(PetPower.withLevel(100, 1, prog, 11)).to.equal(100)
        end)

        it("scales linearly to the cap at max level (maxLevel 11 -> 10%/level)", function()
            -- level 3 -> 2/10 of +100% -> +20% -> 120
            expect(PetPower.withLevel(100, 3, prog, 11)).to.equal(120)
            -- max level -> the full +100%
            expect(PetPower.withLevel(100, 11, prog, 11)).to.equal(200)
        end)

        it("the per-level step derives from max level (same cap, different arc)", function()
            -- maxLevel 5: level 3 is HALFWAY -> +50% (vs +20% on an 11-level arc)
            expect(PetPower.withLevel(100, 3, prog, 5)).to.equal(150)
        end)

        it("no scaling without a usable max level", function()
            expect(PetPower.withLevel(100, 9, prog, 1)).to.equal(100)
        end)

        it("returns the base unchanged with no progression config", function()
            expect(PetPower.withLevel(100, 9, nil)).to.equal(100)
        end)
    end)

    describe("PetPower.basePowerForLevel", function()
        it("composes huge base + level via rarity max level (huge bear lvl 3 -> 120)", function()
            -- rarity huge -> maxLevel 11 -> level 3 = +20%
            expect(PetPower.basePowerForLevel(bearBasic, true, 3, prog)).to.equal(120)
        end)

        it("normal bear lvl 1 -> 10", function()
            expect(PetPower.basePowerForLevel(bearBasic, false, 1, prog)).to.equal(10)
        end)
    end)
end
