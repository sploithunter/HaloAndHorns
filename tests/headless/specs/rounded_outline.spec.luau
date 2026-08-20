local RoundedOutline = loadModule("src/Shared/Game/RoundedOutline.lua")
local SpawnSlots = loadModule("src/Shared/Game/SpawnSlots.lua")

return function()
    describe("RoundedOutline", function()
        it("walks a rounded rect by arc length instead of cutting the corner", function()
            local path = RoundedOutline.roundedRectPath(0, 0, 42.5, 58.5, 13.78)
            expect(path.total).to.be.near(4 * (42.5 + 58.5 - 2 * 13.78) + 2 * math.pi * 13.78, 0.01)

            local start = RoundedOutline.at(path, 0)
            expect(start.x).to.be.near(42.5, 0.01)
            expect(start.z).to.be.near(-44.72, 0.01)

            local intoArc = RoundedOutline.at(path, 89.44 + 13.78 * math.pi * 0.25)
            -- Midway through the +x/+z quarter arc: not the AABB corner (42.5, 58.5).
            expect(intoArc.x).to.be.near(42.5 - 13.78 + 13.78 * math.cos(math.pi * 0.25), 0.05)
            expect(intoArc.z).to.be.near(58.5 - 13.78 + 13.78 * math.sin(math.pi * 0.25), 0.05)
            expect(intoArc.x < 42.5).to.equal(true)
            expect(intoArc.z < 58.5).to.equal(true)
        end)

        it("rebuilds the playfield loop from authored FieldCorner centers", function()
            local corners = {
                { x = 28.72, z = 44.72 },
                { x = -28.72, z = 44.72 },
                { x = -28.72, z = -44.72 },
                { x = 28.72, z = -44.72 },
            }
            local fromCenters = RoundedOutline.pathFromCenters(corners, 13.78)
            local fromRect = RoundedOutline.roundedRectPath(0, 0, 42.5, 58.5, 13.78)
            expect(fromCenters.total).to.be.near(fromRect.total, 0.05)
        end)

        it("keeps the corner-tile diagonal as a fifth rounded vertex", function()
            local corners = {
                { x = -68, z = -103 },
                { x = 7.4, z = -103 },
                { x = 68, z = -42.4 },
                { x = 68, z = 33 },
                { x = -68, z = 33 },
            }
            local path = RoundedOutline.pathFromCenters(corners, 12.5)
            expect(#path.segs).to.equal(10)
            local arcCount = 0
            for _, seg in ipairs(path.segs) do
                if seg.kind == "arc" then
                    arcCount += 1
                    expect(seg.sweep > 0.2).to.equal(true)
                end
            end
            expect(arcCount).to.equal(5)
            expect(path.total > 400).to.equal(true)

            local encoded = RoundedOutline.encodePath(path, 3)
            local parsed = SpawnSlots.parseOutline(encoded)
            expect(#parsed >= 24).to.equal(true)
            expect(SpawnSlots.containsPoint(parsed, 0, -20)).to.equal(true)
            expect(SpawnSlots.containsPoint(parsed, 200, 200)).to.equal(false)
        end)

        it("follows kerb-corner radius instead of shrinking toward the spawn zone", function()
            local encoded = RoundedOutline.forPlayArea({
                corners = {
                    { x = 28.7, z = 44.7, r = 18.9 },
                    { x = -28.7, z = 44.7, r = 18.9 },
                    { x = -28.7, z = -44.7, r = 18.9 },
                    { x = 28.7, z = -44.7, r = 18.9 },
                },
            })
            local parsed = SpawnSlots.parseOutline(encoded)
            expect(#parsed >= 24).to.equal(true)
            local maxX, maxZ = 0, 0
            for _, point in ipairs(parsed) do
                maxX = math.max(maxX, math.abs(point.x))
                maxZ = math.max(maxZ, math.abs(point.z))
            end
            -- Kerb centers + r sit on the white outline, not the 39.5 x 55.5 zone.
            expect(maxX).to.be.near(47.6, 1.5)
            expect(maxZ).to.be.near(63.6, 1.5)
        end)

        it("follows a cap Field AABB when no corner cylinders exist", function()
            local encoded = RoundedOutline.forPlayArea({ width = 304, depth = 304 })
            local parsed = SpawnSlots.parseOutline(encoded)
            expect(#parsed >= 24).to.equal(true)
            local sample = parsed[1]
            expect(math.max(math.abs(sample.x), math.abs(sample.z))).to.be.near(152, 2)
        end)
    end)
end
