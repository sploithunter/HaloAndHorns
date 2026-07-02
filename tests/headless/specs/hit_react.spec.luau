--[[
    HitReact — [unit] decaying got-hit flinch (combat juice).
    Run: mise run test-headless
]]

local HitReact = loadModule("src/Shared/Game/HitReact.lua")

local function near(a, b)
    return math.abs(a - b) <= 1e-6
end

return function()
    describe("HitReact", function()
        it("an un-armed state samples to zero", function()
            local ox, oz, yaw = HitReact.sample({}, 0)
            expect(ox).to.equal(0)
            expect(oz).to.equal(0)
            expect(yaw).to.equal(0)
        end)

        it("recoil is max at impact and decays to zero over DURATION", function()
            local st = {}
            HitReact.start(st, 100, 1, 0, 1) -- shove +X, +yaw, at t=100
            -- at impact (k=1): full recoil + full yaw
            local ox0, oz0, yaw0 = HitReact.sample(st, 100)
            expect(near(ox0, HitReact.RECOIL)).to.equal(true)
            expect(near(oz0, 0)).to.equal(true)
            expect(near(yaw0, HitReact.YAW)).to.equal(true)
            -- halfway (k=0.5): half of each
            local oxh = HitReact.sample(st, 100 + HitReact.DURATION / 2)
            expect(near(oxh, HitReact.RECOIL / 2)).to.equal(true)
            -- spent (k<=0): zero
            local oxe = HitReact.sample(st, 100 + HitReact.DURATION)
            expect(oxe).to.equal(0)
        end)

        it("normalizes the recoil direction (any input scale)", function()
            local st = {}
            HitReact.start(st, 0, 0, 5, 1) -- shove +Z, scale 5
            local ox, oz = HitReact.sample(st, 0)
            expect(near(ox, 0)).to.equal(true)
            expect(near(oz, HitReact.RECOIL)).to.equal(true) -- normalized to unit, then * RECOIL
        end)

        it("yawSign flips the twist direction", function()
            local pos, neg = {}, {}
            HitReact.start(pos, 0, 1, 0, 1)
            HitReact.start(neg, 0, 1, 0, -1)
            local _, _, yp = HitReact.sample(pos, 0)
            local _, _, yn = HitReact.sample(neg, 0)
            expect(yp > 0 and yn < 0).to.equal(true)
            expect(near(yp, -yn)).to.equal(true)
        end)
    end)
end
