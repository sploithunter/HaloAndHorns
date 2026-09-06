return function()
    describe("Player pet position reporting integration", function()
        it("advances the shared clock only for the local squad", function()
            local source = readFile("src/Client/Systems/PetFollowController.lua")
            expect(source:find("if isLocal then%s+reportAccum %+%= dt%s+end") ~= nil).to.equal(true)
            local _, increments = source:gsub("reportAccum%s*%+%=", "")
            expect(increments).to.equal(1)
            expect(source:find("if isLocal and reportAccum >= reportInterval then", 1, true) ~= nil).to.equal(
                true
            )
        end)

        it("keeps the report interval below the authoritative position expiry", function()
            local config = loadModule("configs/pet_follow.lua")
            expect(config.replication.interval > 0).to.equal(true)
            expect(config.replication.interval < config.replication.stale_seconds).to.equal(true)
        end)
    end)
end
