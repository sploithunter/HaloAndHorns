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

        it("keeps the authored two-minute Level-10 four-pet squad", function()
            expect(config.token.duration).to.equal(120)
            expect(config.principal.level).to.equal(10)
            expect(#config.principal.squad).to.equal(4)
            expect(config.principal.squad[1].pet).to.equal("polarbear")
            expect(config.principal.squad[1].variant).to.equal("rainbow")
            expect(config.principal.squad[2].pet).to.equal("dragon")
            expect(config.principal.squad[2].variant).to.equal("golden")
            expect(config.principal.squad[3].pet).to.equal("penguin")
            expect(config.principal.squad[3].variant).to.equal("rainbow")
            expect(config.principal.squad[4].pet).to.equal("snowleopard")
            expect(config.principal.squad[4].variant).to.equal("rainbow")
        end)
    end)
end
