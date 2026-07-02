--[[
    LevelTrack — [unit] claim math + per-level reward lookup.
    Uses a LOCAL fixture config so retuning configs/level_track.lua never breaks these tests.
    Run: mise run test-headless
]]

local LevelTrack = loadModule("src/Shared/Game/LevelTrack.lua")

-- Stable fixture (decoupled from the shipped cadence).
local cfg = {
    max_level = 50,
    egg_hatch = { base = 3, per_level = 1 },
    power_levels = { 5, 9 },
    slot_levels = { 8, 12 },
    slots_per_grant = 2,
    milestones = { 10, 20 },
    altar_kinds = { power = true, slot = true, milestone = true, reward = false },
    rewards = { default = { items = { { id = "level_fixture_reward", qty = 1 } } } },
    milestone_rewards = { [10] = { items = { { id = "milestone_fixture_reward", qty = 1 } } } },
}

return function()
    describe("LevelTrack.resolve (claim gate)", function()
        it("can claim when earned is ahead of claimed", function()
            local r = LevelTrack.resolve(3, 5, cfg)
            expect(r.canClaim).to.equal(true)
            expect(r.pendingLevels).to.equal(2)
            expect(r.nextLevel).to.equal(4)
            expect(r.atMax).to.equal(false)
        end)

        it("cannot claim when claimed has caught up to earned", function()
            local r = LevelTrack.resolve(5, 5, cfg)
            expect(r.canClaim).to.equal(false)
            expect(r.pendingLevels).to.equal(0)
            expect(r.nextLevel).to.equal(nil)
        end)

        it("saturates at the level cap (50)", function()
            local r = LevelTrack.resolve(50, 60, cfg)
            expect(r.atMax).to.equal(true)
            expect(r.canClaim).to.equal(false)
            expect(r.pendingLevels).to.equal(0)
            expect(r.maxLevel).to.equal(50)
        end)

        it("claimed below max with earned at max can still claim", function()
            local r = LevelTrack.resolve(48, 50, cfg)
            expect(r.canClaim).to.equal(true)
            expect(r.pendingLevels).to.equal(2)
            expect(r.nextLevel).to.equal(49)
        end)
    end)

    describe("LevelTrack.entryForLevel (what a level grants)", function()
        it("power-pick levels open the picker", function()
            local e = LevelTrack.entryForLevel(5, cfg)
            expect(e.kind).to.equal("power")
            expect(e.powerPick).to.equal(true)
        end)

        it("slot levels grant enhancement slots", function()
            local e = LevelTrack.entryForLevel(8, cfg)
            expect(e.kind).to.equal("slot")
            expect(e.slots).to.equal(2)
            expect(e.powerPick).to.equal(false)
        end)

        it("milestone levels are flagged", function()
            local e = LevelTrack.entryForLevel(10, cfg)
            expect(e.milestone).to.equal(true)
            expect(e.kind).to.equal("milestone")
            expect(e.milestoneRewards).never.to.equal(nil)
        end)

        it("plain levels fall back to the default reward bundle", function()
            local e = LevelTrack.entryForLevel(3, cfg)
            expect(e.kind).to.equal("reward")
            expect(e.powerPick).to.equal(false)
            expect(e.slots).to.equal(0)
            expect(e.rewards).never.to.equal(nil)
        end)

        it("every level carries the +1 egg-hatch bonus", function()
            expect(LevelTrack.entryForLevel(2, cfg).eggHatchBonus).to.equal(1)
        end)
    end)

    describe("LevelTrack hybrid altar gate (requiresAltar)", function()
        it("power, slot and milestone levels require the altar", function()
            expect(LevelTrack.entryForLevel(5, cfg).requiresAltar).to.equal(true) -- power
            expect(LevelTrack.entryForLevel(8, cfg).requiresAltar).to.equal(true) -- slot
            expect(LevelTrack.entryForLevel(10, cfg).requiresAltar).to.equal(true) -- milestone
        end)
        it("pure-reward filler levels auto-claim (no altar)", function()
            expect(LevelTrack.entryForLevel(3, cfg).requiresAltar).to.equal(false)
            expect(LevelTrack.entryForLevel(6, cfg).requiresAltar).to.equal(false)
        end)
        it("altar_kinds knob can flip a kind to auto", function()
            local autoCfg = {
                power_levels = { 5 },
                slot_levels = {},
                milestones = {},
                altar_kinds = { power = false },
            }
            expect(LevelTrack.entryForLevel(5, autoCfg).requiresAltar).to.equal(false)
        end)
    end)

    describe("LevelTrack.eggHatchForLevel (climbs ~3 -> ~52)", function()
        it("is base at level 1", function()
            expect(LevelTrack.eggHatchForLevel(1, cfg)).to.equal(3)
        end)
        it("adds one per level toward the cap", function()
            expect(LevelTrack.eggHatchForLevel(2, cfg)).to.equal(4)
            expect(LevelTrack.eggHatchForLevel(50, cfg)).to.equal(52)
        end)
    end)
end
