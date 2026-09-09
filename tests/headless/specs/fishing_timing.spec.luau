local Timing = loadModule("src/Shared/Game/FishingTiming.lua")
local cfg = loadModule("configs/crossroads_fishing.lua")
return function()
    describe("client-owned fishing luck", function()
        it("never offers 100 on an ordinary cast", function()
            local profile = { cap = cfg.timing.cap_max, period = 1.9, phase = 0.4, surge = false }
            for frame = 0, 960 do
                local score = Timing.score(cfg.timing, profile, frame / 120)
                expect(score >= 0 and score <= cfg.timing.cap_max).to.equal(true)
            end
        end)
        it("limits the rare 100 opportunity to a brief local window", function()
            local p = { cap = 82, period = 2, phase = 0, surge = true, surgeAt = 3 }
            expect(Timing.score(cfg.timing, p, 3)).to.equal(100)
            expect(Timing.score(cfg.timing, p, 3 - cfg.timing.surge_duration) < 100).to.equal(true)
            expect(Timing.score(cfg.timing, p, 3 + cfg.timing.surge_duration) < 100).to.equal(true)
            expect(cfg.timing.surge_chance <= 0.02).to.equal(true)
        end)
        it("samples the same luck from elapsed time regardless of frame count", function()
            local p = { cap = 85, period = 2, phase = 0, surge = true, surgeAt = 3 }
            local elapsed = 0
            for _ = 1, 60 do
                elapsed += 1 / 60
            end
            expect(Timing.score(cfg.timing, p, elapsed)).to.equal(Timing.score(cfg.timing, p, 1))
        end)
        it("improves escape odds without making a perfect hit an automatic catch", function()
            local previous = 1
            for score = 0, 100 do
                local chance = Timing.escapeChance(cfg.timing, score)
                expect(chance <= previous and chance > 0 and chance < 1).to.equal(true)
                previous = chance
            end
        end)
        it("maps stopped luck to configured reward tiers and finite payouts", function()
            for score = 0, 100 do
                for _, roll in ipairs({ 0, 0.2, 0.5, 0.99, 1 }) do
                    local reward, index = Timing.reward(cfg, score, roll)
                    expect(cfg.tiers[index].minimum <= score).to.equal(true)
                    expect(reward.weight > 0).to.equal(true)
                    for _, amount in pairs(reward.bundle.currencies or {}) do
                        expect(amount > 0 and amount < math.huge).to.equal(true)
                    end
                end
            end
        end)
    end)
end
