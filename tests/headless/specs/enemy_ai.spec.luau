--[[
    Feature 10 slice 2: EnemyAI — chase movement, perception, threat/aggro.
    Run: mise run test-headless
]]

local EnemyAI = loadModule("src/Shared/Game/EnemyAI.lua")

local function p(x, y, z)
    return { x = x, y = y or 0, z = z or 0 }
end

return function()
    describe("EnemyAI.chaseStep", function()
        it("moves toward the target, capped by speed*dt", function()
            -- from origin toward (10,0): speed 4, dt 1 -> advance 4 studs
            local np, d = EnemyAI.chaseStep(p(0, 5, 0), p(10, 0, 0), 4, 1, 0)
            expect(np.x).to.near(4, 1e-6)
            expect(np.z).to.near(0, 1e-6)
            expect(d).to.near(10, 1e-6)
        end)

        it("preserves the enemy's own Y (no falling)", function()
            local np = EnemyAI.chaseStep(p(0, 12, 0), p(10, 0, 10), 4, 1, 0)
            expect(np.y).to.equal(12)
        end)

        it("stops at stopRange instead of overshooting", function()
            -- 10 away, stopRange 8, plenty of speed -> lands exactly at range 8
            local np = EnemyAI.chaseStep(p(0, 0, 0), p(10, 0, 0), 100, 1, 8)
            expect(np.x).to.near(2, 1e-6) -- moved 2 -> 8 away
        end)

        it("holds position once within stopRange", function()
            local np, d = EnemyAI.chaseStep(p(0, 0, 0), p(5, 0, 0), 100, 1, 8)
            expect(np.x).to.equal(0)
            expect(d).to.near(5, 1e-6)
        end)
    end)

    describe("EnemyAI.noticeProbability", function()
        it("is 1 on top of the target and 0 at/beyond range", function()
            expect(EnemyAI.noticeProbability(0, 50)).to.equal(1)
            expect(EnemyAI.noticeProbability(50, 50)).to.equal(0)
            expect(EnemyAI.noticeProbability(80, 50)).to.equal(0)
        end)

        it("falls off linearly between", function()
            expect(EnemyAI.noticeProbability(25, 50)).to.near(0.5, 1e-6)
        end)

        it("is 0 with no range", function()
            expect(EnemyAI.noticeProbability(10, 0)).to.equal(0)
        end)
    end)

    describe("EnemyAI.shouldNotice", function()
        it("notices when the roll is under the probability", function()
            -- distance 25 of 50 -> prob 0.5
            expect(EnemyAI.shouldNotice(25, 50, 0.4)).to.equal(true)
            expect(EnemyAI.shouldNotice(25, 50, 0.6)).to.equal(false)
        end)
    end)

    describe("EnemyAI threat / tank pull", function()
        it("a high-threat tank out-pulls a closer squishy pet", function()
            -- candidate 1: squishy (threat 10) right next to the enemy
            -- candidate 2: tank (threat 100) a bit farther
            local cands = {
                { threat = 10, distance = 2 },
                { threat = 100, distance = 9 },
            }
            local idx = EnemyAI.selectThreatTarget(cands, 12)
            expect(idx).to.equal(2) -- tank pulls aggro despite being farther
        end)

        it("ignores candidates out of range", function()
            local cands = {
                { threat = 1000, distance = 30 }, -- huge threat but out of range
                { threat = 5, distance = 4 },
            }
            expect(EnemyAI.selectThreatTarget(cands, 12)).to.equal(2)
        end)

        it("returns nil when nothing is in range", function()
            local cands = { { threat = 50, distance = 40 } }
            expect(EnemyAI.selectThreatTarget(cands, 12)).to.equal(nil)
        end)

        it("falls back to proximity when threat is equal", function()
            local cands = {
                { threat = 20, distance = 10 },
                { threat = 20, distance = 3 },
            }
            expect(EnemyAI.selectThreatTarget(cands, 12)).to.equal(2)
        end)
    end)
end
