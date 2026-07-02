--[[
    PetMeander — [unit] idle wander state machine (frozen-statue fix).
    Run: mise run test-headless
]]

local PetMeander = loadModule("src/Shared/Game/PetMeander.lua")

local CFG = { radius = 6, speed = 4, pause_min = 1, pause_max = 2 }

-- Scripted "random": returns queued values in order (repeats the last one).
local function randSeq(values)
    local i = 0
    return function()
        i = math.min(i + 1, #values)
        return values[i]
    end
end

return function()
    describe("PetMeander", function()
        it("pauses on the slot before its first stroll", function()
            local rand = randSeq({ 0.5 }) -- initial wait = 1 + 0.5*1 = 1.5s
            local state = PetMeander.newState(CFG, rand)
            local x, z = PetMeander.step(state, 1.0, CFG, rand)
            expect(x).to.equal(0)
            expect(z).to.equal(0)
        end)

        it("strolls toward a goal inside the radius at the configured speed", function()
            -- waits 0 (rand 0 -> pause_min 1... step dt 1 consumes it), then picks
            -- angle 0 (rand 0) and dist = 6 * (0.3 + 0.7*1) = 6 (rand 1) -> goal (6, 0)
            local rand = randSeq({ 0, 0, 1, 0.5 })
            local state = PetMeander.newState(CFG, rand)
            state.wait = 0 -- start ready to stroll
            PetMeander.step(state, 0.01, CFG, rand) -- picks the goal
            local x = 0
            for _ = 1, 100 do -- 6 studs at speed 4 -> arrives in 1.5s (30 steps)
                x = PetMeander.step(state, 0.05, CFG, rand)
                if state.gx == nil then
                    break -- arrived: stop before the pause elapses + a new stroll starts
                end
            end
            expect(math.abs(x - 6) < 1e-6).to.equal(true)
            expect(math.sqrt(state.x ^ 2 + state.z ^ 2) <= CFG.radius + 1e-6).to.equal(true)
            expect(state.gx).to.equal(nil) -- arrived -> pausing again
            expect(state.wait > 0).to.equal(true)
        end)

        it("never steps farther than speed * dt", function()
            local rand = randSeq({ 0, 0, 1, 0.5 })
            local state = PetMeander.newState(CFG, rand)
            state.wait = 0
            PetMeander.step(state, 0.01, CFG, rand) -- pick goal (6, 0)
            local px, pz = state.x, state.z
            local x, z = PetMeander.step(state, 0.1, CFG, rand)
            local stepLen = math.sqrt((x - px) ^ 2 + (z - pz) ^ 2)
            expect(stepLen <= CFG.speed * 0.1 + 1e-6).to.equal(true)
        end)

        it("reset snaps the offset home and re-pauses", function()
            local rand = randSeq({ 0, 0, 1, 0.5 })
            local state = PetMeander.newState(CFG, rand)
            state.wait = 0
            PetMeander.step(state, 0.01, CFG, rand)
            PetMeander.step(state, 0.5, CFG, rand) -- mid-stroll, offset ~2
            expect(state.x > 0).to.equal(true)
            PetMeander.reset(state, CFG, rand)
            expect(state.x).to.equal(0)
            expect(state.z).to.equal(0)
            expect(state.gx).to.equal(nil)
            expect(state.wait >= CFG.pause_min).to.equal(true)
        end)

        it("separate() pushes overlapping targets apart to minDist, half each", function()
            local push = PetMeander.separate({ { x = 0, z = 0 }, { x = 1, z = 0 } }, 3)
            expect(math.abs(push[1].x - -1) < 1e-6).to.equal(true) -- 2 short, 1 each way
            expect(math.abs(push[2].x - 1) < 1e-6).to.equal(true)
            expect(push[1].z).to.equal(0)
        end)

        it("separate() leaves well-spaced targets alone", function()
            local push = PetMeander.separate({ { x = 0, z = 0 }, { x = 10, z = 0 } }, 3)
            expect(push[1].x).to.equal(0)
            expect(push[2].x).to.equal(0)
        end)

        it("separate() breaks coincident-point ties instead of dividing by zero", function()
            local push = PetMeander.separate({ { x = 5, z = 5 }, { x = 5, z = 5 } }, 3)
            local len1 = math.sqrt(push[1].x ^ 2 + push[1].z ^ 2)
            expect(math.abs(len1 - 1.5) < 1e-4).to.equal(true) -- half of minDist each
            expect(push[1].x == -push[2].x and push[1].z == -push[2].z).to.equal(true)
        end)

        it("randomized pauses desync a squad (different rand, different waits)", function()
            local early = PetMeander.newState(CFG, randSeq({ 0 }))
            local late = PetMeander.newState(CFG, randSeq({ 1 }))
            expect(early.wait < late.wait).to.equal(true)
        end)
    end)
end
