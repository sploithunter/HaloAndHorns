--[[
    Headless unit tests for Navigation (pure movement core).

    Run: mise run test-headless
]]

local Navigation = loadModule("src/Shared/API/Navigation.lua")

return function()
    describe("Navigation", function()
        it("planarDistance ignores the Y axis", function()
            -- 3-4-5 triangle on the XZ plane
            expect(Navigation.planarDistance(0, 0, 3, 4)).to.near(5)
            -- identical XZ, different (implicit) height → zero
            expect(Navigation.planarDistance(10, -7, 10, -7)).to.near(0)
        end)

        it("distance3 measures full 3D distance", function()
            expect(Navigation.distance3(0, 0, 0, 2, 3, 6)).to.near(7) -- 2-3-6 → 7
        end)

        it("hasArrived honors the threshold inclusively", function()
            expect(Navigation.hasArrived(3.9, 4)).to.equal(true)
            expect(Navigation.hasArrived(4.0, 4)).to.equal(true)
            expect(Navigation.hasArrived(4.1, 4)).to.equal(false)
        end)

        describe("advanceWaypoint", function()
            it("keeps the current index while still far", function()
                local nextIndex, done = Navigation.advanceWaypoint(2, 12, 4, 5)
                expect(nextIndex).to.equal(2)
                expect(done).to.equal(false)
            end)

            it("advances when within threshold and waypoints remain", function()
                local nextIndex, done = Navigation.advanceWaypoint(2, 3, 4, 5)
                expect(nextIndex).to.equal(3)
                expect(done).to.equal(false)
            end)

            it("reports done when arriving at the final waypoint", function()
                local nextIndex, done = Navigation.advanceWaypoint(5, 1, 4, 5)
                expect(nextIndex).to.equal(5)
                expect(done).to.equal(true)
            end)
        end)

        it("madeProgress flags stalls below epsilon", function()
            expect(Navigation.madeProgress(0.5, 0.1)).to.equal(true)
            expect(Navigation.madeProgress(0.05, 0.1)).to.equal(false)
        end)
    end)
end
