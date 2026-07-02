local PetAnimState = loadModule("src/Shared/Game/PetAnimState.lua")

local CFG = { run_speed = 2.0, idle_speed = 0.8, fade = 0.2 }

return function()
    describe("PetAnimState.resolve (idle/run hysteresis)", function()
        it("starts idle and stays idle below the run threshold", function()
            expect(PetAnimState.resolve(nil, 0, CFG)).to.equal("idle")
            expect(PetAnimState.resolve("idle", 1.9, CFG)).to.equal("idle")
        end)

        it("enters run only above run_speed", function()
            expect(PetAnimState.resolve("idle", 2.1, CFG)).to.equal("run")
        end)

        it("keeps running inside the hysteresis band (no flicker)", function()
            -- 1.5 is below run_speed but above idle_speed: idle stays idle, run stays run
            expect(PetAnimState.resolve("idle", 1.5, CFG)).to.equal("idle")
            expect(PetAnimState.resolve("run", 1.5, CFG)).to.equal("run")
        end)

        it("drops to idle only below idle_speed", function()
            expect(PetAnimState.resolve("run", 0.9, CFG)).to.equal("run")
            expect(PetAnimState.resolve("run", 0.7, CFG)).to.equal("idle")
        end)

        it("defaults safely with missing cfg and bad speed", function()
            expect(PetAnimState.resolve(nil, nil, nil)).to.equal("idle")
            expect(PetAnimState.resolve("run", 10, nil)).to.equal("run")
        end)
    end)
end
