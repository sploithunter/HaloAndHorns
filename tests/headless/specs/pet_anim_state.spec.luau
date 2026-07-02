local PetAnimState = loadModule("src/Shared/Game/PetAnimState.lua")

-- walk enters at 1.0 (exits 0.7), run enters at 8.0 (exits 5.6)
local CFG = { walk_speed = 1.0, run_speed = 8.0, hysteresis = 0.7, fade = 0.2 }

return function()
    describe("PetAnimState.resolve (idle/walk/run hysteresis)", function()
        it("starts idle and stays idle below the walk threshold", function()
            expect(PetAnimState.resolve(nil, 0, CFG)).to.equal("idle")
            expect(PetAnimState.resolve("idle", 0.9, CFG)).to.equal("idle")
        end)

        it("enters walk above walk_speed (the meander stroll band)", function()
            expect(PetAnimState.resolve("idle", 1.2, CFG)).to.equal("walk")
            expect(PetAnimState.resolve("idle", 4, CFG)).to.equal("walk")
        end)

        it("enters run above run_speed, from idle or walk", function()
            expect(PetAnimState.resolve("idle", 9, CFG)).to.equal("run")
            expect(PetAnimState.resolve("walk", 8.5, CFG)).to.equal("run")
        end)

        it("holds each state inside its hysteresis band (no flicker)", function()
            -- 6.5 is below run-enter (8) but above run-exit (5.6): run holds, walk holds
            expect(PetAnimState.resolve("run", 6.5, CFG)).to.equal("run")
            expect(PetAnimState.resolve("walk", 6.5, CFG)).to.equal("walk")
            -- 0.8 is below walk-enter (1.0) but above walk-exit (0.7): walk holds, idle holds
            expect(PetAnimState.resolve("walk", 0.8, CFG)).to.equal("walk")
            expect(PetAnimState.resolve("idle", 0.8, CFG)).to.equal("idle")
        end)

        it("steps down run -> walk -> idle as speed decays", function()
            expect(PetAnimState.resolve("run", 4, CFG)).to.equal("walk")
            expect(PetAnimState.resolve("walk", 0.5, CFG)).to.equal("idle")
            -- a hard stop from run goes straight to idle
            expect(PetAnimState.resolve("run", 0.1, CFG)).to.equal("idle")
        end)

        it("defaults safely with missing cfg and bad speed", function()
            expect(PetAnimState.resolve(nil, nil, nil)).to.equal("idle")
            expect(PetAnimState.resolve("run", 10, nil)).to.equal("run")
        end)
    end)

    describe("PetAnimState.pick (stable pool selection)", function()
        local POOL = { "rbxassetid://1", "rbxassetid://2", "rbxassetid://3" }

        it("passes single ids through", function()
            expect(PetAnimState.pick("rbxassetid://9", "seed")).to.equal("rbxassetid://9")
        end)

        it("is deterministic for the same seed", function()
            expect(PetAnimState.pick(POOL, "pet-a#1")).to.equal(PetAnimState.pick(POOL, "pet-a#1"))
        end)

        it("varies across seeds (some pair differs)", function()
            local seen = {}
            for i = 1, 12 do
                seen[PetAnimState.pick(POOL, "pet#" .. i)] = true
            end
            local distinct = 0
            for _ in pairs(seen) do
                distinct += 1
            end
            expect(distinct > 1).to.equal(true)
        end)

        it("returns nil for empty/invalid entries", function()
            expect(PetAnimState.pick(nil, "s")).to.equal(nil)
            expect(PetAnimState.pick({}, "s")).to.equal(nil)
        end)
    end)
end
