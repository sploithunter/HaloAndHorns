--[[
    ResSickness — the post-revive heal clamp (configs/squad.lua revive block).
    Run: mise run test-headless
]]

local ResSickness = loadModule("src/Shared/Game/ResSickness.lua")

return function()
    local NOW = 1000
    -- revived at 50% of a 400-endurance pool: floor = 200 damage taken, sick for 8s
    local SICK = { ResSicknessFloor = 200, ResSicknessUntil = NOW + 8 }

    describe("ResSickness.clampTaken", function()
        it("blocks heals below the floor while the window is live", function()
            -- a 700 burst tries to take damage from 200 to 0 -> clamped back to the floor
            expect(ResSickness.clampTaken(SICK, 0, NOW + 1)).to.equal(200)
            -- partial heals above the floor pass through untouched
            expect(ResSickness.clampTaken(SICK, 250, NOW + 1)).to.equal(250)
        end)

        it("lets heals through once the window lapses", function()
            expect(ResSickness.clampTaken(SICK, 0, NOW + 9)).to.equal(0)
        end)

        it("is a no-op for never-revived pets (no attributes)", function()
            expect(ResSickness.clampTaken({}, 0, NOW)).to.equal(0)
            expect(ResSickness.clampTaken(nil, 5, NOW)).to.equal(5)
        end)
    end)

    describe("ResSickness.floorFor", function()
        it("reports the live floor and 0 after expiry", function()
            expect(ResSickness.floorFor(SICK, NOW + 1)).to.equal(200)
            expect(ResSickness.floorFor(SICK, NOW + 8)).to.equal(0)
        end)
    end)
end
