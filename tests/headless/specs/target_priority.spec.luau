--[[
    TargetPriority: per-mode enemy selection (closest/furthest/strongest/weakest/team_threat/aggro),
    aggro's closest fallback, and empty/unknown-mode handling.
]]

local TargetPriority = loadModule("src/Shared/Game/TargetPriority.lua")

-- id, distance, strength, hp, aggro, teamDamage
local function candidates()
    return {
        { id = 1, distance = 30, strength = 5, hp = 100, aggro = 0, teamDamage = 50 },
        { id = 2, distance = 10, strength = 9, hp = 400, aggro = 0, teamDamage = 0 },
        { id = 3, distance = 55, strength = 2, hp = 40, aggro = 0, teamDamage = 200 },
    }
end

return function()
    describe("TargetPriority.pick — geometry", function()
        it("closest picks the nearest", function()
            expect(TargetPriority.pick(candidates(), "closest")).to.equal(2)
        end)
        it("furthest picks the farthest", function()
            expect(TargetPriority.pick(candidates(), "furthest")).to.equal(3)
        end)
    end)

    describe("TargetPriority.pick — strength", function()
        it("strongest picks the highest strength", function()
            expect(TargetPriority.pick(candidates(), "strongest")).to.equal(2)
        end)
        it("weakest picks the lowest strength", function()
            expect(TargetPriority.pick(candidates(), "weakest")).to.equal(3)
        end)
    end)

    describe("TargetPriority.pick — team_threat", function()
        it("picks the enemy dealing the most damage to the team", function()
            expect(TargetPriority.pick(candidates(), "team_threat")).to.equal(3)
        end)
    end)

    describe("TargetPriority.pick — aggro", function()
        it("picks the highest-aggro enemy", function()
            local c = candidates()
            c[1].aggro = 80
            c[3].aggro = 120
            expect(TargetPriority.pick(c, "aggro")).to.equal(3)
        end)
        it("falls back to closest when no one has aggro", function()
            expect(TargetPriority.pick(candidates(), "aggro")).to.equal(2) -- nearest
        end)
    end)

    describe("TargetPriority.pick — edge cases", function()
        it("returns nil for no candidates", function()
            expect(TargetPriority.pick({}, "closest")).to.equal(nil)
            expect(TargetPriority.pick(nil, "closest")).to.equal(nil)
        end)
        it("unknown mode falls back to the default (aggro -> closest here)", function()
            expect(TargetPriority.pick(candidates(), "banana")).to.equal(2)
        end)
        it("isMode validates the known modes", function()
            expect(TargetPriority.isMode("strongest")).to.equal(true)
            expect(TargetPriority.isMode("banana")).to.equal(false)
        end)
    end)
end
