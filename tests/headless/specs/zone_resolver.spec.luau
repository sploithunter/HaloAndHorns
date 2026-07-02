--[[
    ZoneResolver — [unit] point-in-area footprint resolution.
    Run: mise run test-headless
]]

local ZoneResolver = loadModule("src/Shared/Game/ZoneResolver.lua")
local areasConfig = loadModule("configs/areas.lua")
local zoneCfg = loadModule("configs/zone_tracker.lua")

local bounds = ZoneResolver.boundsFromAreas(areasConfig)
local VB = zoneCfg.vertical_band
local MARGIN = zoneCfg.boundary_margin

-- Pull a couple of known area centres straight from config so the test tracks the real map.
local function center(id)
    return areasConfig.zones[id].synthetic.center
end

return function()
    describe("ZoneResolver.boundsFromAreas", function()
        it(
            "includes only kind=area zones (Spawn/Lava/Ice/Desert/Meadow), not worlds/islands",
            function()
                local ids = {}
                for _, b in ipairs(bounds) do
                    ids[b.id] = true
                end
                expect(ids.Spawn).to.equal(true)
                expect(ids.Lava).to.equal(true)
                expect(ids.Ice).to.equal(true)
                expect(ids.Desert).to.equal(true)
                -- worlds/islands are organisational, never standable footprints
                expect(ids.spawn_world).never.to.be.ok()
                expect(ids.lava_island).never.to.be.ok()
            end
        )
    end)

    describe("ZoneResolver.resolve (footprint + vertical band)", function()
        it("resolves a player standing at an area centre to that area", function()
            local c = center("Lava")
            -- HRP sits ~5 studs above the thin floor slab; the vertical band must still match.
            local pos = { x = c.x, y = c.y + 5, z = c.z }
            expect(ZoneResolver.resolve(pos, bounds, { verticalBand = VB })).to.equal("Lava")
        end)

        it("resolves the Ice centre to Ice, not a neighbouring biome", function()
            local c = center("Ice")
            local pos = { x = c.x, y = c.y + 5, z = c.z }
            expect(ZoneResolver.resolve(pos, bounds, { verticalBand = VB })).to.equal("Ice")
        end)

        it("returns nil when far outside every area footprint", function()
            local pos = { x = 99999, y = 0, z = 99999 }
            expect(ZoneResolver.resolve(pos, bounds, { verticalBand = VB })).never.to.be.ok()
        end)

        it("rejects a position directly above an area but beyond the vertical band", function()
            local c = center("Desert")
            local pos = { x = c.x, y = c.y + VB + 500, z = c.z }
            expect(ZoneResolver.resolve(pos, bounds, { verticalBand = VB })).never.to.be.ok()
        end)
    end)

    describe("ZoneResolver.resolveSticky (hysteresis)", function()
        it("keeps the current area while still inside its footprint", function()
            local c = center("Lava")
            local pos = { x = c.x, y = c.y + 5, z = c.z }
            expect(
                ZoneResolver.resolveSticky(
                    pos,
                    bounds,
                    "Lava",
                    { verticalBand = VB, margin = MARGIN }
                )
            ).to.equal("Lava")
        end)

        it("falls back to default when outside everything", function()
            local pos = { x = 99999, y = 0, z = 99999 }
            expect(ZoneResolver.resolveSticky(pos, bounds, "Lava", {
                verticalBand = VB,
                margin = MARGIN,
                default = "Spawn",
            })).to.equal("Spawn")
        end)

        it("switches to a new area once genuinely inside it", function()
            local c = center("Ice")
            local pos = { x = c.x, y = c.y + 5, z = c.z }
            -- coming from Lava, but now standing on the Ice footprint -> Ice
            expect(
                ZoneResolver.resolveSticky(
                    pos,
                    bounds,
                    "Lava",
                    { verticalBand = VB, margin = MARGIN }
                )
            ).to.equal("Ice")
        end)
    end)

    describe("ZoneResolver.clampToFootprint (enemy leash)", function()
        local area =
            { id = "Box", center = { x = 0, y = 0, z = 0 }, size = { x = 100, y = 4, z = 60 } }

        it("leaves a point already inside the footprint unchanged", function()
            local x, z = ZoneResolver.clampToFootprint({ x = 10, y = 50, z = -5 }, area)
            expect(x).to.equal(10)
            expect(z).to.equal(-5)
        end)

        it("clamps a point past the edge back onto the boundary", function()
            local x, z = ZoneResolver.clampToFootprint({ x = 999, y = 0, z = -999 }, area)
            expect(x).to.equal(50) -- +halfX
            expect(z).to.equal(-30) -- -halfZ
        end)

        it("insets by margin so the mover stops just inside the edge", function()
            local x = ZoneResolver.clampToFootprint({ x = 999, y = 0, z = 0 }, area, 2)
            expect(x).to.equal(48) -- halfX(50) - margin(2)
        end)
    end)
end
