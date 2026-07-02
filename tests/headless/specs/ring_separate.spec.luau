--[[
    RingSeparate — tangential de-overlap on a fixed target ring [unit] tests.
    Run: mise run test-headless  (or mise run ci)
]]

local RingSeparate = loadModule("src/Shared/Game/RingSeparate.lua")

local function dist(a, b)
    local dx, dz = a.x - b.x, a.z - b.z
    return math.sqrt(dx * dx + dz * dz)
end

local TARGET = { x = 0, z = 0 }
local R = 10
local GAP = 6

return function()
    describe("RingSeparate.point — radius is preserved", function()
        it("places the attacker exactly `radius` from the target (no crowding)", function()
            local p = RingSeparate.point({ x = 3, z = 0 }, TARGET, {}, R, GAP)
            expect(dist(p, TARGET)).to.near(R, 1e-6)
        end)

        it("preserves radius even while being pushed off a neighbour", function()
            local p = RingSeparate.point({ x = 10, z = 0 }, TARGET, { { x = 10, z = 1 } }, R, GAP)
            expect(dist(p, TARGET)).to.near(R, 1e-6) -- slid sideways, same distance
        end)

        it("never NaNs when the attacker sits on the target", function()
            local p = RingSeparate.point({ x = 0, z = 0 }, TARGET, {}, R, GAP)
            expect(dist(p, TARGET)).to.near(R, 1e-6)
        end)
    end)

    describe("RingSeparate.point — holds angle when uncrowded", function()
        it("keeps the current approach angle with no others", function()
            local p = RingSeparate.point({ x = 5, z = 0 }, TARGET, {}, R, GAP)
            -- self is on the +x axis → ring point should be (R, 0)
            expect(p.x).to.near(R, 1e-6)
            expect(p.z).to.near(0, 1e-6)
        end)

        it("ignores a neighbour farther than minGap", function()
            local far = { x = -10, z = 0 } -- opposite side, well beyond GAP from the +x ring point
            local p = RingSeparate.point({ x = 5, z = 0 }, TARGET, { far }, R, GAP)
            expect(p.x).to.near(R, 1e-6)
            expect(p.z).to.near(0, 1e-6)
        end)
    end)

    describe("RingSeparate.point — crowding fans attackers apart", function()
        it("pushes two near-coincident attackers to a wider gap in one step", function()
            local a0 = { x = 10, z = 0.2 }
            local b0 = { x = 10, z = -0.2 }
            local before = dist(a0, b0)
            local a1 = RingSeparate.point(a0, TARGET, { b0 }, R, GAP)
            local b1 = RingSeparate.point(b0, TARGET, { a0 }, R, GAP)
            expect(dist(a1, b1) > before).to.equal(true)
        end)

        it("relaxes toward minGap separation over several iterations (and settles)", function()
            local a = { x = 10, z = 0.1 }
            local b = { x = 10, z = -0.1 }
            for _ = 1, 40 do
                local na = RingSeparate.point(a, TARGET, { b }, R, GAP)
                local nb = RingSeparate.point(b, TARGET, { a }, R, GAP)
                a, b = na, nb
            end
            -- both still on the ring, and now comfortably separated (no longer overlapping)
            expect(dist(a, TARGET)).to.near(R, 1e-6)
            expect(dist(b, TARGET)).to.near(R, 1e-6)
            expect(dist(a, b) >= GAP * 0.8).to.equal(true)
        end)
    end)
end
