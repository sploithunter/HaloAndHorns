--[[
    Feature 17: Roster System — [unit] scenarios.
    Run: mise run test-headless
]]

local RosterLogic = loadModule("src/Shared/Game/RosterLogic.lua")

-- pet states: ready pets omitted/ready=true; spirit-form pets ready=false + recovery
local states = {
    pet_A = { ready = true },
    pet_B = { ready = false, recovery = 0.5 },
    pet_C = { ready = false, recovery = 0.8 },
}

return function()
    describe("RosterLogic.clampMaxToDeploy", function()
        it("clamps max_to_deploy to active-squad capacity (10 -> 5)", function()
            expect(RosterLogic.clampMaxToDeploy(10, 5)).to.equal(5)
        end)
        it("leaves a within-capacity value unchanged", function()
            expect(RosterLogic.clampMaxToDeploy(3, 5)).to.equal(3)
        end)
    end)

    describe("RosterLogic.resolveDeploy order + max", function()
        it("deploys ordered pets up to max (4 ordered, max 3 -> first 3)", function()
            local r = RosterLogic.resolveDeploy(
                { "pet_A", "pet_B", "pet_C", "pet_D" },
                {},
                3,
                "deploy_anyway"
            )
            expect(#r).to.equal(3)
            expect(r[1]).to.equal("pet_A")
            expect(r[3]).to.equal("pet_C")
        end)

        it("preserves roster order (not sorted/randomized)", function()
            local r = RosterLogic.resolveDeploy(
                { "pet_A", "pet_B", "pet_C" },
                {},
                3,
                "deploy_anyway"
            )
            expect(r[1]).to.equal("pet_A")
            expect(r[2]).to.equal("pet_B")
            expect(r[3]).to.equal("pet_C")
        end)
    end)

    describe("injury_rule ready_only", function()
        it("skips spirit-form pets, no outside substitution", function()
            -- [A(ready), B(spirit), C(spirit)], max 3 -> only A (B,C skipped)
            local r =
                RosterLogic.resolveDeploy({ "pet_A", "pet_B", "pet_C" }, states, 3, "ready_only")
            expect(#r).to.equal(1)
            expect(r[1]).to.equal("pet_A")
        end)
    end)

    describe("injury_rule best_available", function()
        it("ready first, then most-recovered injured (A, C@0.8, B@0.5)", function()
            local r = RosterLogic.resolveDeploy(
                { "pet_A", "pet_B", "pet_C" },
                states,
                3,
                "best_available"
            )
            expect(r[1]).to.equal("pet_A")
            expect(r[2]).to.equal("pet_C")
            expect(r[3]).to.equal("pet_B")
        end)
    end)

    describe("injury_rule deploy_anyway", function()
        it("uses original order regardless of spirit form", function()
            local r =
                RosterLogic.resolveDeploy({ "pet_A", "pet_B", "pet_C" }, states, 3, "deploy_anyway")
            expect(r[1]).to.equal("pet_A")
            expect(r[2]).to.equal("pet_B")
            expect(r[3]).to.equal("pet_C")
        end)
    end)

    describe("RosterLogic.removeRef", function()
        it("removes a deleted/traded pet from the ordered list", function()
            local r = RosterLogic.removeRef({ "pet_A", "pet_B", "pet_C" }, "pet_B")
            expect(#r).to.equal(2)
            expect(r[1]).to.equal("pet_A")
            expect(r[2]).to.equal("pet_C")
        end)
    end)
end
