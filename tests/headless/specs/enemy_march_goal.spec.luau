local EnemyMarchGoal = loadModule("src/Shared/Game/EnemyMarchGoal.lua")

return function()
    describe("EnemyMarchGoal", function()
        it("normalizes one authored destination", function()
            local goal = EnemyMarchGoal.new({
                destination = { x = 10, y = 2, z = -4 },
                speed = 5,
                arriveDistance = 0.5,
            })

            expect(goal ~= nil).to.equal(true)
            expect(goal.destination.x).to.equal(10)
            expect(goal.destination.z).to.equal(-4)
            expect(goal.speed).to.equal(5)
        end)

        it("rejects missing destinations and non-moving goals", function()
            expect(EnemyMarchGoal.new(nil)).to.equal(nil)
            expect(EnemyMarchGoal.new({})).to.equal(nil)
            expect(EnemyMarchGoal.new({ destination = { x = 1 } })).to.equal(nil)
            expect(EnemyMarchGoal.new({ destination = { x = 1, z = 2 }, speed = 0 })).to.equal(nil)
        end)

        it("moves directly toward the finish without overshooting", function()
            local goal = EnemyMarchGoal.new({
                destination = { x = 3, z = 4 },
                speed = 5,
                arriveDistance = 0,
            })
            local x, z, reached = EnemyMarchGoal.step(goal, 0, 0, 0.5)
            expect(x).to.equal(1.5)
            expect(z).to.equal(2)
            expect(reached).to.equal(false)

            x, z, reached = EnemyMarchGoal.step(goal, x, z, 1)
            expect(x).to.equal(3)
            expect(z).to.equal(4)
            expect(reached).to.equal(true)
        end)

        it("resumes from the supplied position after combat pulls an enemy off course", function()
            local goal = EnemyMarchGoal.new({
                destination = { x = 10, z = 0 },
                speed = 2,
                arriveDistance = 0,
            })
            local x, z, reached = EnemyMarchGoal.step(goal, 6, 4, 1)

            expect(x > 6).to.equal(true)
            expect(z < 4).to.equal(true)
            expect(reached).to.equal(false)
        end)
    end)
end
