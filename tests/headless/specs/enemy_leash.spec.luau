--[[
    EnemyLeash — [unit] union-of-shapes containment + clamp for the enemy movement leash.
    Run: mise run test-headless
]]

local EnemyLeash = loadModule("src/Shared/Game/EnemyLeash.lua")

-- A grass box (centered -150,265, 356x266) ∪ a spawn circle (91,241, r200) — the starter pen.
local GRASS = { kind = "box", cx = -150, cz = 265, halfX = 178, halfZ = 133 }
local SPAWN = { kind = "circle", cx = 91, cz = 241, r = 200 }
local PEN = { GRASS, SPAWN }

return function()
    describe("EnemyLeash.inside (union)", function()
        it("is inside when within the box", function()
            expect(EnemyLeash.inside(-150, 265, PEN)).to.equal(true)
        end)
        it("is inside when within the circle (but outside the box)", function()
            expect(EnemyLeash.inside(150, 241, PEN)).to.equal(true) -- 59 from circle centre < 200
        end)
        it("is outside when in neither shape", function()
            expect(EnemyLeash.inside(-600, 600, PEN)).to.equal(false)
        end)
    end)

    describe("EnemyLeash.clamp (union)", function()
        it("leaves a point inside the union unchanged", function()
            local x, z = EnemyLeash.clamp(-150, 265, PEN)
            expect(x).to.equal(-150)
            expect(z).to.equal(265)
        end)

        it("clamps a far point to the nearest shape boundary", function()
            -- way off in +X, level with the spawn circle centre -> snaps onto the circle edge
            local x, z = EnemyLeash.clamp(91 + 999, 241, PEN)
            expect(x).to.equal(291) -- cx + r
            expect(math.abs(z - 241) < 1e-6).to.equal(true)
        end)

        it("clamps to the box edge when the box is nearest", function()
            -- far -X past the grass box, away from the circle -> box left edge
            local x = EnemyLeash.clamp(-1000, 265, PEN)
            expect(x).to.equal(-328) -- cx(-150) - halfX(178)
        end)

        it("applies an inset margin", function()
            local x = EnemyLeash.clamp(-1000, 265, PEN, 2)
            expect(x).to.equal(-326) -- left edge + 2 inset
        end)

        it("returns the point unchanged when there are no shapes", function()
            local x, z = EnemyLeash.clamp(5, 6, {})
            expect(x).to.equal(5)
            expect(z).to.equal(6)
        end)
    end)
end
