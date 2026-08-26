local EnemyRewardPolicy = loadModule("src/Shared/Game/EnemyRewardPolicy.lua")

return function()
    describe("EnemyRewardPolicy", function()
        it("preserves normal rewards by default", function()
            expect(EnemyRewardPolicy.normalize(nil)).to.equal("normal")
            expect(EnemyRewardPolicy.awardsNormalRewards(nil)).to.equal(true)
            expect(EnemyRewardPolicy.awardsNormalRewards("normal")).to.equal(true)
        end)

        it("supports reward-free isolated encounters", function()
            expect(EnemyRewardPolicy.normalize("none")).to.equal("none")
            expect(EnemyRewardPolicy.awardsNormalRewards("none")).to.equal(false)
        end)

        it("rejects unknown policies", function()
            expect(EnemyRewardPolicy.normalize("prototype_magic")).to.equal(nil)
            expect(EnemyRewardPolicy.awardsNormalRewards("prototype_magic")).to.equal(false)
        end)
    end)
end
