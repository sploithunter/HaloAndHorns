--[[
    SpawnSlots — [unit] layout generation + occupancy registry.
    Pure: deterministic via injected rng. Run: mise run test-headless
]]

local SpawnSlots = loadModule("src/Shared/Game/SpawnSlots.lua")

local function dist2d(a, b)
    local dx, dz = a.x - b.x, a.z - b.z
    return math.sqrt(dx * dx + dz * dz)
end

-- rng that returns a fixed value (for deterministic claims)
local function constRng(v)
    return function()
        return v
    end
end

return function()
    describe("SpawnSlots.layoutGrid", function()
        it("fills the area on a spacing grid (cols*rows points)", function()
            local pts = SpawnSlots.layoutGrid({ width = 30, depth = 30, spacing = 10 })
            expect(#pts).to.equal(9) -- floor(30/10)=3 each axis
        end)

        it("guarantees >= spacing between neighbours with no jitter", function()
            local pts = SpawnSlots.layoutGrid({ width = 30, depth = 30, spacing = 10 })
            local minD = math.huge
            for i = 1, #pts do
                for j = i + 1, #pts do
                    minD = math.min(minD, dist2d(pts[i], pts[j]))
                end
            end
            -- closest pair = orthogonal neighbours = exactly `spacing`
            expect(minD >= 10 - 1e-6).to.equal(true)
        end)

        it("centres the grid symmetrically about the origin", function()
            local pts = SpawnSlots.layoutGrid({ width = 30, depth = 30, spacing = 10 })
            local minX, maxX = math.huge, -math.huge
            for _, p in ipairs(pts) do
                minX, maxX = math.min(minX, p.x), math.max(maxX, p.x)
            end
            expect(math.abs(minX + maxX) < 1e-6).to.equal(true) -- symmetric ⇒ min == -max
        end)

        it("keeps jitter within bounds (still inside jitter*spacing of the grid point)", function()
            local pts = SpawnSlots.layoutGrid({
                width = 20,
                depth = 10,
                spacing = 10,
                jitter = 0.5,
                rng = constRng(1.0), -- max positive displacement
            })
            -- jitter 0.5 * spacing 10 = up to 5 studs; a 2x1 grid → 2 points
            expect(#pts).to.equal(2)
        end)

        it("always yields at least one point even for a tiny area", function()
            local pts = SpawnSlots.layoutGrid({ width = 1, depth = 1, spacing = 10 })
            expect(#pts).to.equal(1)
        end)
    end)

    describe("SpawnSlots registry — claim / release", function()
        local function makeReg()
            return SpawnSlots.new({
                { id = "a" },
                { id = "b" },
                { id = "c" },
            })
        end

        it("starts all free", function()
            local r = makeReg()
            expect(r:total()).to.equal(3)
            expect(r:freeCount()).to.equal(3)
            expect(r:occupiedCount()).to.equal(0)
            expect(r:isFull()).to.equal(false)
        end)

        it("claim takes a free slot and marks it occupied", function()
            local r = makeReg()
            local slot = r:claim(nil, constRng(0)) -- first free
            expect(slot.id).to.equal("a")
            expect(r:freeCount()).to.equal(2)
            expect(r:isOccupied("a")).to.equal(true)
        end)

        it("returns nil when the pool is exhausted", function()
            local r = makeReg()
            r:claim(nil, constRng(0))
            r:claim(nil, constRng(0))
            r:claim(nil, constRng(0))
            expect(r:isFull()).to.equal(true)
            expect(r:claim(nil, constRng(0))).to.equal(nil)
        end)

        it("release frees a slot by id", function()
            local r = makeReg()
            r:claim(nil, constRng(0)) -- claims "a"
            expect(r:release("a")).to.equal(true)
            expect(r:freeCount()).to.equal(3)
            expect(r:release("a")).to.equal(false) -- already free ⇒ no-op
        end)

        it("releaseByRef frees the slot holding a model ref", function()
            local r = makeReg()
            local model = { fake = "crystal" }
            local slot = r:claim(nil, constRng(0), model)
            expect(r:isOccupied(slot.id)).to.equal(true)
            local freedId = r:releaseByRef(model)
            expect(freedId).to.equal(slot.id)
            expect(r:isOccupied(slot.id)).to.equal(false)
        end)

        it("occupy re-hydrates a specific slot (existing models on activation)", function()
            local r = makeReg()
            expect(r:occupy("b")).to.equal(true)
            expect(r:isOccupied("b")).to.equal(true)
            expect(r:occupy("b")).to.equal(false) -- already occupied
        end)
    end)

    describe("SpawnSlots registry — kinds (common vs fixed special anchors)", function()
        local function makeMixed()
            return SpawnSlots.new({
                { id = 1 }, -- common
                { id = 2 }, -- common
                { id = 3, kind = "special" }, -- fixed chest/giant anchor
            })
        end

        it("counts per kind separately", function()
            local r = makeMixed()
            expect(r:freeCount()).to.equal(2) -- common
            expect(r:freeCount("special")).to.equal(1)
        end)

        it("a common claim never consumes a special anchor", function()
            local r = makeMixed()
            r:claim(nil, constRng(0))
            r:claim(nil, constRng(0))
            expect(r:isFull()).to.equal(true) -- common pool exhausted
            expect(r:freeCount("special")).to.equal(1) -- special untouched
            expect(r:claim(nil, constRng(0))).to.equal(nil) -- can't borrow the special slot
        end)

        it("a special claim lands only on the special slot", function()
            local r = makeMixed()
            local slot = r:claim("special", constRng(0))
            expect(slot.id).to.equal(3)
            expect(r:freeCount("special")).to.equal(0)
            expect(r:freeCount()).to.equal(2) -- common pool intact
        end)

        it("capacity counts all slots of a kind regardless of occupancy", function()
            local r = makeMixed()
            r:claim(nil, constRng(0))
            expect(r:capacity()).to.equal(2) -- still 2 common (one now occupied)
            expect(r:capacity("special")).to.equal(1)
        end)
    end)

    describe("SpawnSlots registry — avoidNeighbors (oversampled, no-overlap)", function()
        -- 1—2—3 line: slot 2 neighbours both 1 and 3 (i.e. close enough to overlap).
        local function makeLine()
            return SpawnSlots.new({
                { id = 1, neighbors = { 2 } },
                { id = 2, neighbors = { 1, 3 } },
                { id = 3, neighbors = { 2 } },
            })
        end

        it("a neighbour-avoiding claim skips slots adjacent to an occupied one", function()
            local r = makeLine()
            r:claim(nil, constRng(0), nil, true) -- claims slot 1
            -- free = {2,3}; slot 2 touches occupied 1 ⇒ blocked; only slot 3 is clear
            local slot = r:claim(nil, constRng(0), nil, true)
            expect(slot.id).to.equal(3)
        end)

        it("falls back to a blocked slot only when nothing else is free", function()
            local r = makeLine()
            r:claim(nil, constRng(0), nil, true) -- slot 1
            r:claim(nil, constRng(0), nil, true) -- slot 3
            -- only slot 2 left, and it touches both occupied ⇒ fallback still places it
            local slot = r:claim(nil, constRng(0), nil, true)
            expect(slot.id).to.equal(2)
        end)
    end)
end
