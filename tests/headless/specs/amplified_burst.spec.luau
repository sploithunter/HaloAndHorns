--[[
    AmplifiedBurst: the pet-scaled "player damage" primitive — total = squadAttack x mult,
    radial falloff (centre full -> edgeFraction at the rim), and the floored at-distance burst.
]]

local AmplifiedBurst = loadModule("src/Shared/Game/AmplifiedBurst.lua")

return function()
    describe("AmplifiedBurst.total", function()
        it("scales the squad's attack by the multiplier", function()
            expect(AmplifiedBurst.total(100, 3)).to.equal(300)
            expect(AmplifiedBurst.total(250, 1.5)).to.equal(375)
        end)

        it("is zero for non-positive attack or multiplier", function()
            expect(AmplifiedBurst.total(0, 3)).to.equal(0)
            expect(AmplifiedBurst.total(100, 0)).to.equal(0)
            expect(AmplifiedBurst.total(nil, 3)).to.equal(0)
        end)
    end)

    describe("AmplifiedBurst.falloff", function()
        it("is full at the centre and edgeFraction at the rim", function()
            expect(AmplifiedBurst.falloff(0, 16, 0.5)).to.equal(1)
            expect(AmplifiedBurst.falloff(16, 16, 0.5)).to.equal(0.5)
        end)

        it("interpolates linearly between centre and rim", function()
            expect(AmplifiedBurst.falloff(8, 16, 0.5)).to.equal(0.75)
        end)

        it("holds at edgeFraction beyond the radius and defaults edge to 0.5", function()
            expect(AmplifiedBurst.falloff(40, 16, 0.5)).to.equal(0.5)
            expect(AmplifiedBurst.falloff(16, 16)).to.equal(0.5)
        end)

        it("returns 1 for a non-positive radius", function()
            expect(AmplifiedBurst.falloff(5, 0, 0.5)).to.equal(1)
        end)
    end)

    describe("AmplifiedBurst.atDistance", function()
        it("floors total x falloff", function()
            -- 300 total, centre -> 300
            expect(AmplifiedBurst.atDistance(100, 3, 0, 16, 0.5)).to.equal(300)
            -- 300 total, rim -> 150
            expect(AmplifiedBurst.atDistance(100, 3, 16, 16, 0.5)).to.equal(150)
            -- 300 total, half -> 0.75 -> 225
            expect(AmplifiedBurst.atDistance(100, 3, 8, 16, 0.5)).to.equal(225)
        end)

        it("is zero when there is no burst", function()
            expect(AmplifiedBurst.atDistance(0, 3, 0, 16, 0.5)).to.equal(0)
        end)
    end)
end
