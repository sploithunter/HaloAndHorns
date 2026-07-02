--[[
    HatchTiming — pure hatch-duration SSOT. [unit] scenarios.
    Run: mise run test-headless

    Verifies the shared duration math the server uses to size its post-hatch
    cooldown and the client uses to size its lock watchdog stay in agreement.
]]

local HatchTiming = loadModule("src/Shared/Game/HatchTiming.lua")

-- Deterministic config (binary-exact under *0.5) independent of the real preset values.
local cfg = {
    current_preset = "test",
    speed_presets = { test = { speed_multiplier = 0.5 } },
    timing = {
        shake_wait_duration = 2.0, -- ->1.0
        stagger_delay = 0.25, -- ->0.125
        reveal_duration = 1.0, -- ->0.5
        reveal_completion_wait = 1.5, -- ->0.75
        result_enjoyment_time = 1.0, -- ->0.5 (preset only)
        cleanup_pause_time = 1.0, -- ->0.5 (preset only)
    },
    advanced = { batch_reveal_mode = "staggered" },
}

return function()
    describe("HatchTiming.resolve", function()
        it("scales animation phases by preset, post-holds by preset only", function()
            local t = HatchTiming.resolve(cfg, {})
            expect(t.shakeWaitDuration).to.near(1.0)
            expect(t.staggerDelay).to.near(0.125)
            expect(t.revealDuration).to.near(0.5)
            expect(t.completionWait).to.near(0.75)
            -- enjoyment/cleanup are preset-scaled only (no speedScale) — mirrors the client.
            expect(t.resultEnjoymentTime).to.near(0.5)
            expect(t.cleanupPauseTime).to.near(0.5)
            expect(t.speedScale).to.near(1.0)
        end)

        it("applies the fastHatch speedScale to animation phases but not post-holds", function()
            local t = HatchTiming.resolve(cfg, { fastHatch = true }, { fastHatchSpeedScale = 0.5 })
            expect(t.speedScale).to.near(0.5)
            expect(t.shakeWaitDuration).to.near(0.5) -- 2.0 * 0.5 * 0.5
            expect(t.completionWait).to.near(0.375) -- 1.5 * 0.5 * 0.5
            expect(t.resultEnjoymentTime).to.near(0.5) -- unchanged by speedScale
            expect(t.cleanupPauseTime).to.near(0.5)
        end)

        it("defaults the fast speedScale to 0.5 when extra is absent", function()
            local t = HatchTiming.resolve(cfg, { fastHatch = true })
            expect(t.speedScale).to.near(0.5)
        end)

        it("treats skipHatch and showHatch=false as skip", function()
            expect(HatchTiming.resolve(cfg, { skipHatch = true }).skipHatch).to.equal(true)
            expect(HatchTiming.resolve(cfg, { showHatch = false }).skipHatch).to.equal(true)
            expect(HatchTiming.resolve(cfg, {}).skipHatch).to.equal(false)
        end)

        it("honors simultaneous reveal mode (no stagger)", function()
            local sim = HatchTiming.resolve({
                speed_presets = cfg.speed_presets,
                current_preset = "test",
                timing = cfg.timing,
                advanced = { batch_reveal_mode = "simultaneous" },
            }, {})
            expect(sim.doStagger).to.equal(false)
        end)

        it("is defensive against missing config (no error, zeros)", function()
            local t = HatchTiming.resolve(nil, nil, nil)
            expect(t.shakeWaitDuration).to.near(0)
            expect(HatchTiming.expectedSeconds(1, t)).to.near(0)
        end)
    end)

    describe("HatchTiming.expectedSeconds", function()
        local t = HatchTiming.resolve(cfg, {})

        it("sums a single hatch: shake + revealTail + post", function()
            -- 1.0 + 0 + max(0.75,0.5) + (0.5+0.5)
            expect(HatchTiming.expectedSeconds(1, t)).to.near(2.75)
        end)

        it("adds (count-1) * staggerDelay for a batch", function()
            -- 3 eggs: 1.0 + 2*0.125 + 0.75 + 1.0 = 3.0
            expect(HatchTiming.expectedSeconds(3, t)).to.near(3.0)
            -- 5 eggs: 1.0 + 4*0.125 + 0.75 + 1.0 = 3.25
            expect(HatchTiming.expectedSeconds(5, t)).to.near(3.25)
        end)

        it("is non-decreasing in count", function()
            local prev = -1
            for n = 1, 20 do
                local s = HatchTiming.expectedSeconds(n, t)
                expect(s >= prev).to.equal(true)
                prev = s
            end
        end)

        it("returns 0 when the hatch is skipped", function()
            local skipped = HatchTiming.resolve(cfg, { skipHatch = true })
            expect(HatchTiming.expectedSeconds(50, skipped)).to.near(0)
        end)

        it("drops the stagger term under simultaneous reveal", function()
            local sim = HatchTiming.resolve({
                speed_presets = cfg.speed_presets,
                current_preset = "test",
                timing = cfg.timing,
                advanced = { batch_reveal_mode = "simultaneous" },
            }, {})
            -- no stagger regardless of count: 1.0 + 0 + 0.75 + 1.0 = 2.75
            expect(HatchTiming.expectedSeconds(11, sim)).to.near(2.75)
        end)

        it("clamps count to at least 1", function()
            expect(HatchTiming.expectedSeconds(0, t)).to.near(HatchTiming.expectedSeconds(1, t))
            expect(HatchTiming.expectedSeconds(-3, t)).to.near(HatchTiming.expectedSeconds(1, t))
        end)
    end)

    describe("HatchTiming.watchdogSeconds", function()
        local t = HatchTiming.resolve(cfg, {})

        it("is expected*factor + margin within bounds", function()
            -- expected(1)=2.75 -> 2.75*3 + 5 = 13.25
            expect(HatchTiming.watchdogSeconds(1, t)).to.near(13.25)
        end)

        it("floors at minSeconds", function()
            -- skipped hatch expected 0 -> 0*3+5 = 5 -> floored to 8
            local skipped = HatchTiming.resolve(cfg, { skipHatch = true })
            expect(HatchTiming.watchdogSeconds(1, skipped)).to.near(8)
            expect(HatchTiming.watchdogSeconds(1, t, { minSeconds = 20 })).to.near(20)
        end)

        it("caps at maxSeconds", function()
            expect(HatchTiming.watchdogSeconds(1, t, { maxSeconds = 10 })).to.near(10)
            -- a huge batch is bounded by the cap
            expect(HatchTiming.watchdogSeconds(999, t, { maxSeconds = 60 })).to.near(60)
        end)

        it("respects a custom safety factor and margin", function()
            -- 2.75*2 + 1 = 6.5 -> floored to default minSeconds 8
            expect(HatchTiming.watchdogSeconds(1, t, { safetyFactor = 2, marginSeconds = 1 })).to.near(
                8
            )
            -- 3.25(count5)*4 + 2 = 15 (above floor, below cap)
            expect(HatchTiming.watchdogSeconds(5, t, { safetyFactor = 4, marginSeconds = 2 })).to.near(
                15
            )
        end)
    end)

    describe("HatchTiming with the real egg_hatching config", function()
        local realCfg = loadModule("configs/egg_hatching.lua")

        it("resolves and yields a positive single-hatch duration", function()
            local t = HatchTiming.resolve(realCfg, {})
            local s = HatchTiming.expectedSeconds(1, t)
            expect(type(s)).to.equal("number")
            expect(s > 0).to.equal(true)
        end)

        it("a max hatch takes longer than a single hatch", function()
            local t = HatchTiming.resolve(realCfg, {})
            expect(HatchTiming.expectedSeconds(99, t) > HatchTiming.expectedSeconds(1, t)).to.equal(
                true
            )
        end)
    end)
end
