return function()
    describe("Hall gate and hatch regression contract", function()
        it("uses fixed wall-face controls instead of a camera-facing unlock prompt", function()
            local client = readFile("src/Client/Systems/HallRouteGates.lua")
            expect(client:find('Instance.new("SurfaceGui")', 1, true)).to.be.ok()
            expect(client:find('Instance.new("BillboardGui")', 1, true)).never.to.be.ok()
            expect(client:find("Enum.ProximityPromptStyle.Custom", 1, true)).to.be.ok()
            expect(client:find("Signals.UnlockZoneRequest:FireServer", 1, true)).to.be.ok()
        end)

        it("seats full-span frosted walls and keeps unlocks in place", function()
            local server = readFile("src/Server/Services/ZoneService.lua")
            expect(server:find("self:_seatHallGate(hook)", 1, true)).to.be.ok()
            expect(server:find("self:_seatHallAreaZones()", 1, true)).to.be.ok()
            expect(server:find("self:_seatComingSoonWalls()", 1, true)).to.be.ok()
            expect(server:find("self:_isPressingLockedHallGate(player, areaId)", 1, true)).to.be.ok()
            expect(
                server:find(
                    "-- Hall walls drop in place. Walking through is the travel; do not snap",
                    1,
                    true
                )
            ).to.be.ok()
        end)

        it("wobbles an authored ViewportFrame egg without rotating it blank", function()
            local hatch = readFile("src/Shared/Services/EggHatchingService.lua")
            expect(hatch:find("EggWorldQuery.FindEggVisual", 1, true)).to.be.ok()
            expect(hatch:find("camera.CFrame = baseCFrame * CFrame.Angles", 1, true)).to.be.ok()
            expect(hatch:find("EggHatchFront.cameraCFrame", 1, true)).to.be.ok()
        end)
    end)
end
