--[[
    Feature 9: Active squad hierarchy — [unit] scenarios.
    Run: mise run test-headless
]]

local ActiveSquad = loadModule("src/Shared/Game/ActiveSquad.lua")
local squadConfig = loadModule("configs/squad.lua")

return function()
    describe("ActiveSquad.canDeploy", function()
        local max = squadConfig.limits.active_squad

        it("allows deploy when below max", function()
            expect(ActiveSquad.canDeploy(2, max).ok).to.equal(true)
        end)

        it("rejects deploy when at max (active_squad_full)", function()
            local r = ActiveSquad.canDeploy(max, max)
            expect(r.ok).to.equal(false)
            expect(r.reason).to.equal("active_squad_full")
        end)

        it("a stacked pet occupies one slot (size counts entries, not pet counts)", function()
            -- 4 entries (one of them a 30-pet stack) -> a 5th still fits
            expect(ActiveSquad.canDeploy(4, max).ok).to.equal(true)
        end)
    end)

    describe("ActiveSquad.canSwap", function()
        local cooldown = squadConfig.swap_cooldown_seconds

        it("is instant out of combat", function()
            expect(ActiveSquad.canSwap(false, 10000, 10001, cooldown).ok).to.equal(true)
        end)

        it("is allowed in combat when no prior swap", function()
            expect(ActiveSquad.canSwap(true, nil, 10000, cooldown).ok).to.equal(true)
        end)

        it("is blocked in combat within the cooldown window", function()
            local r = ActiveSquad.canSwap(true, 10000 - 2, 10000, cooldown) -- 2s ago, 5s cd
            expect(r.ok).to.equal(false)
            expect(r.reason).to.equal("swap_cooldown_active")
            expect(r.remaining).to.equal(3)
        end)

        it("is allowed in combat after the cooldown elapses", function()
            expect(ActiveSquad.canSwap(true, 10000 - 6, 10000, cooldown).ok).to.equal(true) -- 6s ago
        end)
    end)

    describe("ActiveSquad slot recovery", function()
        local cfg = { slot_recovery = { recall_cooldown_seconds = 4, down_cooldown_seconds = 20 } }

        it("recall leaves a short cooldown, a forced down a long one", function()
            expect(ActiveSquad.slotCooldownSeconds("recall", cfg)).to.equal(4)
            expect(ActiveSquad.slotCooldownSeconds("down", cfg)).to.equal(20)
        end)

        it("defaults the down cooldown for any non-recall reason", function()
            expect(ActiveSquad.slotCooldownSeconds("anything", cfg)).to.equal(20)
        end)

        it("slotReady is true with no cooldown and once the time passes", function()
            expect(ActiveSquad.slotReady(nil, 100)).to.equal(true)
            expect(ActiveSquad.slotReady(120, 100)).to.equal(false)
            expect(ActiveSquad.slotReady(120, 120)).to.equal(true)
        end)

        it("canSummon needs both the slot ready AND a ready instance", function()
            expect(ActiveSquad.canSummon(true, true).ok).to.equal(true)
            expect(ActiveSquad.canSummon(false, true).reason).to.equal("slot_recharging")
            expect(ActiveSquad.canSummon(true, false).reason).to.equal("no_ready_instance")
        end)
    end)
end
