--[[
    #179 Down-lockout — pure PetLockout scenarios (the two mechanisms + slot lock).
    Run: mise run test-headless
]]

local PetLockout = loadModule("src/Shared/Game/PetLockout.lua")
local squadConfig = loadModule("configs/squad.lua")

return function()
    local cfg = {
        pet_lockout_seconds = squadConfig.down_lockout.pet_lockout_seconds,
        slot_lock_seconds = squadConfig.slot_recovery.down_cooldown_seconds,
    }
    local NOW = 1000

    describe("PetLockout special pets (unique uid)", function()
        it("locks the exact downed uid until its lockout elapses", function()
            local s = PetLockout.recordDown(
                PetLockout.empty(),
                { kind = "special", uid = "huge_a" },
                NOW,
                cfg
            )
            expect(PetLockout.isPetLocked(s, "huge_a", NOW + 10)).to.equal(true)
            expect(PetLockout.isPetLocked(s, "huge_a", NOW + cfg.pet_lockout_seconds + 1)).to.equal(
                false
            )
        end)

        it("a DIFFERENT huge of the same type is still deployable", function()
            local s = PetLockout.recordDown(
                PetLockout.empty(),
                { kind = "special", uid = "huge_a" },
                NOW,
                cfg
            )
            expect(PetLockout.canDeploy(s, { kind = "special", uid = "huge_a" }, NOW + 1).ok).to.equal(
                false
            )
            expect(PetLockout.canDeploy(s, { kind = "special", uid = "huge_b" }, NOW + 1).ok).to.equal(
                true
            )
        end)
    end)

    describe("PetLockout stacked pets (quantity, no per-unit id)", function()
        it("each down removes one unit from the deployable count", function()
            local s = PetLockout.empty()
            s = PetLockout.recordDown(s, { kind = "stack", stackKey = "bear:basic" }, NOW, cfg)
            s = PetLockout.recordDown(s, { kind = "stack", stackKey = "bear:basic" }, NOW, cfg)
            s = PetLockout.recordDown(s, { kind = "stack", stackKey = "bear:basic" }, NOW, cfg)
            -- 15 owned, 3 recovering -> 12 deployable
            expect(PetLockout.availableQuantity(s, "bear:basic", 15, NOW + 1)).to.equal(12)
            expect(
                PetLockout.canDeploy(
                    s,
                    { kind = "stack", stackKey = "bear:basic", quantity = 15 },
                    NOW + 1
                ).ok
            ).to.equal(true)
        end)

        it("rejects deploy only when the WHOLE stack is recovering", function()
            local s = PetLockout.empty()
            s = PetLockout.recordDown(s, { kind = "stack", stackKey = "bear:basic" }, NOW, cfg)
            s = PetLockout.recordDown(s, { kind = "stack", stackKey = "bear:basic" }, NOW, cfg)
            -- own exactly 2, both down -> none deployable
            local r = PetLockout.canDeploy(
                s,
                { kind = "stack", stackKey = "bear:basic", quantity = 2 },
                NOW + 1
            )
            expect(r.ok).to.equal(false)
            expect(r.reason).to.equal("stack_recovering")
        end)

        it(
            "recovered units come back after the SLOT timer (stacks ride the slot, not the 5-min lockout)",
            function()
                local s = PetLockout.recordDown(
                    PetLockout.empty(),
                    { kind = "stack", stackKey = "bear:basic" },
                    NOW,
                    cfg
                )
                -- still out a tick before the slot frees
                expect(
                    PetLockout.availableQuantity(
                        s,
                        "bear:basic",
                        1,
                        NOW + cfg.slot_lock_seconds - 1
                    )
                ).to.equal(0)
                -- back as soon as the SLOT frees (1 min) — NOT held for the 5-min pet lockout
                expect(
                    PetLockout.availableQuantity(
                        s,
                        "bear:basic",
                        1,
                        NOW + cfg.slot_lock_seconds + 1
                    )
                ).to.equal(1)
            end
        )
    end)

    describe("PetLockout slot lock", function()
        it("locks the slot for the shorter slot timer", function()
            local s = PetLockout.recordDown(
                PetLockout.empty(),
                { kind = "stack", stackKey = "bear:basic", slot = "slot_1" },
                NOW,
                cfg
            )
            expect(PetLockout.canUseSlot(s, "slot_1", NOW + 1).ok).to.equal(false)
            -- slot frees BEFORE the pet lockout (so a sibling can refill it while the downed one recovers)
            expect(PetLockout.canUseSlot(s, "slot_1", NOW + cfg.slot_lock_seconds + 1).ok).to.equal(
                true
            )
            expect(cfg.slot_lock_seconds < cfg.pet_lockout_seconds).to.equal(true)
        end)
    end)

    describe("PetLockout.prune", function()
        it("drops expired pet/stack/slot entries", function()
            local s = PetLockout.empty()
            s = PetLockout.recordDown(
                s,
                { kind = "special", uid = "huge_a", slot = "slot_1" },
                NOW,
                cfg
            )
            s = PetLockout.recordDown(s, { kind = "stack", stackKey = "bear:basic" }, NOW, cfg)
            local pruned = PetLockout.prune(s, NOW + cfg.pet_lockout_seconds + 1)
            expect(next(pruned.pets)).to.equal(nil)
            expect(next(pruned.stacks)).to.equal(nil)
            expect(next(pruned.slots)).to.equal(nil)
        end)
    end)

    describe(
        "PetLockout.release (powered revives — Revive power / Genie of the Dunes)",
        function()
            it("frees a special pet's uid + slot lock", function()
                local s = PetLockout.recordDown(
                    PetLockout.empty(),
                    { kind = "special", uid = "huge_a", slot = "slot_1" },
                    NOW,
                    cfg
                )
                s = PetLockout.release(s, { kind = "special", uid = "huge_a", slot = "slot_1" })
                expect(PetLockout.isPetLocked(s, "huge_a", NOW + 1)).to.equal(false)
                expect(PetLockout.isSlotLocked(s, "slot_1", NOW + 1)).to.equal(false)
            end)

            it("frees ONE stack lock (the latest), leaving siblings recovering", function()
                local s = PetLockout.empty()
                s = PetLockout.recordDown(s, { kind = "stack", stackKey = "bear:basic" }, NOW, cfg)
                s = PetLockout.recordDown(
                    s,
                    { kind = "stack", stackKey = "bear:basic" },
                    NOW + 5,
                    cfg
                )
                expect(PetLockout.activeStackLocks(s, "bear:basic", NOW + 6)).to.equal(2)
                s = PetLockout.release(s, { kind = "stack", stackKey = "bear:basic" })
                expect(PetLockout.activeStackLocks(s, "bear:basic", NOW + 6)).to.equal(1)
            end)

            it("is safe on an empty/unlocked state (idempotent)", function()
                local s = PetLockout.release(PetLockout.empty(), {
                    kind = "special",
                    uid = "nobody",
                    slot = "slot_9",
                })
                expect(next(s.pets)).to.equal(nil)
                expect(next(s.slots)).to.equal(nil)
            end)
        end
    )

    describe("PetLockout.accelerate (Second Wind pass)", function()
        local CFG = { pet_lockout_seconds = 300, slot_lock_seconds = 60 }

        it("burns extra seconds off every lock family", function()
            local now = 1000
            local state = PetLockout.recordDown(
                PetLockout.empty(),
                { kind = "special", uid = "huge-1", slot = "slot_3" },
                now,
                CFG
            )
            state =
                PetLockout.recordDown(state, { kind = "stack", stackKey = "bear:basic" }, now, CFG)
            -- 30 real seconds out of combat at 3x => 60 EXTRA seconds burned
            local fast = PetLockout.accelerate(state, 60)
            expect(fast.pets["huge-1"]).to.equal(now + 300 - 60)
            expect(fast.slots["slot_3"]).to.equal(now + 60 - 60)
            expect(fast.stacks["bear:basic"][1]).to.equal(now + 60 - 60)
            -- original state untouched (pure contract)
            expect(state.pets["huge-1"]).to.equal(now + 300)
        end)

        it("zero or negative extra time is a no-op", function()
            local now = 1000
            local state = PetLockout.recordDown(
                PetLockout.empty(),
                { kind = "special", uid = "huge-2" },
                now,
                CFG
            )
            expect(PetLockout.accelerate(state, 0).pets["huge-2"]).to.equal(now + 300)
            expect(PetLockout.accelerate(state, -5).pets["huge-2"]).to.equal(now + 300)
        end)

        it("accelerated locks expire through the normal prune path", function()
            local now = 1000
            local state = PetLockout.recordDown(
                PetLockout.empty(),
                { kind = "special", uid = "huge-3", slot = "slot_1" },
                now,
                CFG
            )
            -- 5-min lock, 100s elapsed at 3x = 100 real + 200 extra => done
            local fast = PetLockout.accelerate(state, 200)
            local pruned = PetLockout.prune(fast, now + 100)
            expect(pruned.pets["huge-3"]).to.equal(nil)
            expect(pruned.slots["slot_1"]).to.equal(nil)
        end)
    end)
end
