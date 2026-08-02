return function()
    describe("procedural mission streaming guard", function()
        it("keeps party mission geometry persistent per-player", function()
            local source = readFile("src/Server/Services/MissionInstanceService.lua")
            expect(
                source:find(
                    "container.ModelStreamingMode = Enum.ModelStreamingMode.PersistentPerPlayer",
                    1,
                    true
                ) ~= nil
            ).to.equal(true)
            expect(source:find("container:AddPersistentPlayer(member)", 1, true) ~= nil).to.equal(
                true
            )
        end)

        it("requires a client-observed mission floor before pivoting", function()
            local server = readFile("src/Server/Services/MissionInstanceService.lua")
            local client = readFile("src/Client/Systems/MissionStreamGuard.lua")
            expect(server:find("Signals.MissionStreamRequest:FireClient", 1, true) ~= nil).to.equal(
                true
            )
            expect(server:find("pending.ready", 1, true) ~= nil).to.equal(true)
            expect(client:find("workspace:Raycast", 1, true) ~= nil).to.equal(true)
            expect(client:find("params.RespectCanCollide = true", 1, true) ~= nil).to.equal(true)
            expect(client:find("belongsToMission", 1, true) ~= nil).to.equal(true)
            expect(client:find("MissionStreamReady:FireServer", 1, true) ~= nil).to.equal(true)
        end)

        it("keeps the invisible arrival marker out of readiness raycasts", function()
            local kit = readFile("src/Shared/Worldgen/GrayBoxKit.lua")
            local spawnPad = kit:match('name = "SpawnPad",(.-)tags = { "PlayerSpawn" }') or ""
            expect(spawnPad:find("canCollide = false", 1, true) ~= nil).to.equal(true)
            expect(spawnPad:find("canQuery = false", 1, true) ~= nil).to.equal(true)
        end)

        it("does not convert the streaming timeout into permission to warp", function()
            local server = readFile("src/Server/Services/MissionInstanceService.lua")
            local client = readFile("src/Client/Systems/MissionStreamGuard.lua")
            expect(server:find("RequestStreamAroundAsync", 1, true) ~= nil).to.equal(true)
            expect(client:find("DescendantAdded", 1, true) ~= nil).to.equal(true)
            expect(client:find("destinationFloorIsReady", 1, true) ~= nil).to.equal(true)
        end)
    end)
end
