local CombatTargetGroup = loadModule("src/Shared/Game/CombatTargetGroup.lua")

return function()
    describe("CombatTargetGroup", function()
        it("preserves ordinary combat when neither actor opts in", function()
            expect(CombatTargetGroup.compatible(nil, nil)).to.equal(true)
            expect(CombatTargetGroup.compatible("", "")).to.equal(true)
        end)

        it("requires both opted-in actors to publish the same group", function()
            expect(CombatTargetGroup.compatible("team-1", "team-1")).to.equal(true)
            expect(CombatTargetGroup.compatible("team-1", "team-2")).to.equal(false)
            expect(CombatTargetGroup.compatible("team-1", nil)).to.equal(false)
            expect(CombatTargetGroup.compatible(nil, "team-1")).to.equal(false)
        end)

        it("normalizes numeric attribute values without conflating groups", function()
            expect(CombatTargetGroup.compatible(4, "4")).to.equal(true)
            expect(CombatTargetGroup.compatible(4, 3)).to.equal(false)
        end)

        it("allows either actor to opt into emergency cross-group combat", function()
            expect(CombatTargetGroup.compatible("team-1", "team-2", true, false)).to.equal(true)
            expect(CombatTargetGroup.compatible("team-1", "team-2", false, true)).to.equal(true)
            expect(CombatTargetGroup.compatible("team-1", nil, true, false)).to.equal(true)
            expect(CombatTargetGroup.compatible("team-1", "team-2", false, false)).to.equal(false)
        end)
    end)
end
