return function()
    describe("Player progression load handoff", function()
        it("publishes when DataLoaded arrives instead of publishing after a timeout", function()
            local source = readFile("src/Server/Services/PlayerProgressionService.lua")

            expect(source:find('GetAttributeChangedSignal("DataLoaded")', 1, true) ~= nil).to.equal(
                true
            )
            expect(
                source:find('Readiness.awaitAttribute(player, "DataLoaded", true, 15)', 1, true)
                    == nil
            ).to.equal(true)
        end)

        it("routes every realm gate through the shared access-level resolver", function()
            for _, path in ipairs({
                "src/Server/Services/RealmPortalService.lua",
                "src/Server/Services/LayerService.lua",
                "src/Server/Services/PartyService.lua",
                "src/Client/Systems/RealmPortalLock.lua",
            }) do
                local source = readFile(path)
                expect(source:find("AccessLevel.resolve(", 1, true) ~= nil).to.equal(true)
            end
        end)
    end)
end
