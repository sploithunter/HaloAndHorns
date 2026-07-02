--[[
    Feature 7: Spirit Form & cooldowns — [unit] scenarios.
    Run: mise run test-headless
]]

local SpiritForm = loadModule("src/Shared/Game/SpiritForm.lua")
local config = loadModule("configs/spirit_form.lua")

return function()
    describe("SpiritForm", function()
        it("a healthy pet (no lastDownedAt) is deployable", function()
            local s = SpiritForm.status({ lastDownedAt = nil }, 10000, false, config)
            expect(s.state).to.equal("Healthy")
            expect(s.deployable).to.equal(true)
        end)

        it("a recently-downed pet is in Spirit Form during cooldown", function()
            -- downed 100s ago, mid-tier 300s cooldown -> still 200s left
            local s = SpiritForm.status(
                { lastDownedAt = 10000 - 100, cooldown_seconds = 300 },
                10000,
                false,
                config
            )
            expect(s.state).to.equal("Spirit Form")
            expect(s.deployable).to.equal(false)
            expect(s.remaining).to.equal(200)
        end)

        it("becomes deployable once the cooldown elapses", function()
            -- downed 400s ago, cooldown 300 -> ready
            local s = SpiritForm.status(
                { lastDownedAt = 10000 - 400, cooldown_seconds = 300 },
                10000,
                false,
                config
            )
            expect(s.deployable).to.equal(true)
            expect(s.state).to.equal("Healthy")
        end)

        it("Heaven biomes halve the effective cooldown", function()
            expect(SpiritForm.effectiveCooldown(300, true, config)).to.equal(150)
            expect(SpiritForm.effectiveCooldown(300, false, config)).to.equal(300)
        end)

        it("cooldown matches the content tier where downed", function()
            expect(SpiritForm.cooldownForTier("boss", config)).to.equal(1800)
            expect(SpiritForm.cooldownForTier("trash_mob", config)).to.equal(60)
            local downed = SpiritForm.down({ id = "x" }, "boss", 5000, config)
            expect(downed.lastDownedAt).to.equal(5000)
            expect(downed.cooldown_seconds).to.equal(1800)
        end)

        it("instant recharge clears the cooldown -> deployable", function()
            local downed = SpiritForm.down({ id = "x" }, "mid_tier", 10000, config)
            expect(SpiritForm.status(downed, 10000, false, config).deployable).to.equal(false)
            local healed = SpiritForm.instantRecharge(downed)
            expect(healed.lastDownedAt).to.equal(nil)
            expect(SpiritForm.status(healed, 10000, false, config).deployable).to.equal(true)
        end)

        it("does not mutate the input pet", function()
            local pet = { id = "x" }
            SpiritForm.down(pet, "boss", 5000, config)
            expect(pet.lastDownedAt).to.equal(nil)
        end)
    end)
end
