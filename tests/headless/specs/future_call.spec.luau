--[[
    Future Call — one-time Level-5 entitlement rules.
]]

local FutureCallLogic = loadModule("src/Shared/Game/FutureCallLogic.lua")
local config = loadModule("configs/future_call.lua")

return function()
    describe("FutureCallLogic entitlement", function()
        it("waits until claimed level 5", function()
            expect(FutureCallLogic.shouldGrant({}, 4, config)).to.equal(false)
            expect(FutureCallLogic.shouldGrant({}, 5, config)).to.equal(true)
        end)

        it("reconciles an existing higher-level profile exactly once", function()
            local gameData = {}
            expect(FutureCallLogic.shouldGrant(gameData, 29, config)).to.equal(true)
            FutureCallLogic.markGranted(gameData, config)
            expect(FutureCallLogic.shouldGrant(gameData, 29, config)).to.equal(false)
        end)

        it("derives a unique, username-impossible NPC principal name", function()
            expect(FutureCallLogic.principalName("ColoradoPlays", config)).to.equal(
                "ColoradoPlays's Future Self"
            )
        end)
    end)
end
