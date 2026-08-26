local EnemyPatrolRoute = loadModule("src/Shared/Game/EnemyPatrolRoute.lua")

return function()
    describe("EnemyPatrolRoute", function()
        it("normalizes an ordered authored route", function()
            local route = EnemyPatrolRoute.new({
                waypoints = {
                    { x = 5, y = 2, z = 0 },
                    { x = 10, y = 2, z = 0 },
                },
                speed = 5,
                arriveDistance = 0.5,
            })

            expect(route ~= nil).to.equal(true)
            expect(#route.points).to.equal(2)
            expect(route.speed).to.equal(5)
            expect(route.arriveDistance).to.equal(0.5)
        end)

        it("rejects empty, malformed, or non-moving routes", function()
            expect(EnemyPatrolRoute.new(nil)).to.equal(nil)
            expect(EnemyPatrolRoute.new({ waypoints = {} })).to.equal(nil)
            expect(EnemyPatrolRoute.new({ waypoints = { { x = 1 } } })).to.equal(nil)
            expect(EnemyPatrolRoute.new({ waypoints = { { x = 1, z = 2 } }, speed = 0 })).to.equal(
                nil
            )
        end)

        it("spends one movement budget across successive waypoints", function()
            local route = EnemyPatrolRoute.new({
                waypoints = {
                    { x = 3, z = 0 },
                    { x = 3, z = 4 },
                },
                speed = 5,
                arriveDistance = 0,
            })

            local x, z, index, completed = EnemyPatrolRoute.step(route, 0, 0, 1)
            expect(x).to.equal(3)
            expect(z).to.equal(2)
            expect(index).to.equal(2)
            expect(completed).to.equal(false)

            route.index = index
            x, z, index, completed = EnemyPatrolRoute.step(route, x, z, 1)
            expect(x).to.equal(3)
            expect(z).to.equal(4)
            expect(index).to.equal(2)
            expect(completed).to.equal(true)
        end)

        it("resumes from the supplied authoritative position after an interruption", function()
            local route = EnemyPatrolRoute.new({
                waypoints = { { x = 10, z = 0 } },
                speed = 2,
                arriveDistance = 0,
            })
            local x, z, index, completed = EnemyPatrolRoute.step(route, 6, 0, 1)

            expect(x).to.equal(8)
            expect(z).to.equal(0)
            expect(index).to.equal(1)
            expect(completed).to.equal(false)
        end)
    end)
end
