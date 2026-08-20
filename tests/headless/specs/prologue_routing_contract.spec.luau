local prologueConfig = loadModule("configs/prologue.lua")

return function()
    describe("Prologue routing contract", function()
        it("keeps the generated mezzanine out of the vertical realm stack", function()
            expect(prologueConfig.room.origin.x).to.equal(-12000)
            expect(prologueConfig.room.origin.y).to.equal(0)
        end)

        it("injects ZoneService for the authored post-prologue destination", function()
            local bootstrap = readFile("src/Server/init.server.lua")
            local startAt = bootstrap:find('loader:RegisterModule("PrologueService"', 1, true)
            expect(startAt ~= nil).to.equal(true)

            local nextModule = bootstrap:find("loader:RegisterModule(", startAt + 1, true)
            local registration = bootstrap:sub(startAt, nextModule and nextModule - 1 or -1)
            expect(registration:find('"ZoneService"', 1, true) ~= nil).to.equal(true)
        end)

        it("never falls through to an arbitrary Roblox SpawnLocation", function()
            local service = readFile("src/Server/Services/PrologueService.lua")
            expect(service:find('FindFirstChildWhichIsA("SpawnLocation"', 1, true)).to.equal(nil)
            expect(service:find('GetTagged("PlayerSpawn")', 1, true) ~= nil).to.equal(true)
        end)
    end)
end
