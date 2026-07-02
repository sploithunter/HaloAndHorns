--[[
    Accuracy.toHit — [unit] level-diff to-hit curve + mining exemption.
    Run: mise run test-headless
]]

local Accuracy = loadModule("src/Shared/Game/Accuracy.lua")

-- Mirrors configs/combat.lua `accuracy`.
local cfg = {
    base_to_hit = 0.92,
    per_level_step = 0.04,
    floor = 0.05,
    cap = 0.95,
    mining_hit_chance = 1.0,
}

local function approx(a, b)
    return math.abs(a - b) < 1e-9
end

return function()
    describe("Accuracy.toHit — the 4-cell matrix (attacker level 10)", function()
        -- A boss's published level already includes rank_offset (+2), so we pass it directly.
        it("even base (trash, even level) = base to-hit", function()
            expect(approx(Accuracy.toHit(10, 10, cfg), 0.92)).to.equal(true) -- 8% miss
        end)
        it("even boss (reads +2) loses 2 steps", function()
            expect(approx(Accuracy.toHit(10, 12, cfg), 0.84)).to.equal(true) -- 16% miss
        end)
        it("+2 base (target 2 levels up) loses 2 steps", function()
            expect(approx(Accuracy.toHit(10, 12, cfg), 0.84)).to.equal(true)
        end)
        it("+2 boss (reads +4) loses 4 steps", function()
            expect(approx(Accuracy.toHit(10, 14, cfg), 0.76)).to.equal(true) -- 24% miss
        end)
    end)

    describe("Accuracy.toHit — clamps", function()
        it("out-levelling the target caps at `cap`", function()
            expect(Accuracy.toHit(50, 10, cfg)).to.equal(0.95)
        end)
        it("badly under-levelled bottoms at `floor`", function()
            expect(Accuracy.toHit(1, 50, cfg)).to.equal(0.05)
        end)
        it("defaults safely with no config", function()
            expect(Accuracy.toHit(10, 10, nil)).to.equal(0.92)
        end)
    end)

    describe("Accuracy.miningHitChance — crystals never dodge", function()
        it("returns the configured mining hit chance (1.0)", function()
            expect(Accuracy.miningHitChance(cfg)).to.equal(1.0)
        end)
        it("defaults to 1.0", function()
            expect(Accuracy.miningHitChance(nil)).to.equal(1.0)
        end)
    end)
end
