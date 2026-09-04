local Resolver = loadModule("src/Shared/Game/ZoneResolver.lua")
local PlaceRuntime = loadModule("src/Shared/Game/PlaceRuntime.lua")
local places = loadModule("configs/places.lua")
local areas = loadModule("configs/areas.lua")
local cfg = loadModule("configs/zone_tracker.lua")

return function()
    describe("Dedicated Merge entry location regression", function()
        it("reproduces Home bounds overlapping actual Heaven/Hell bay coordinates", function()
            local bounds = Resolver.boundsFromAreas(areas)
            local opts = {
                verticalBand = cfg.vertical_band,
                margin = cfg.boundary_margin,
                default = places.roles.merge.initial_area,
            }
            -- Authored center bays measured in Studio: this is why generic tracking ended entry.
            expect(Resolver.resolveSticky({ x = -171, y = 8, z = 0 }, bounds, opts.default, opts)).to.equal(
                "Lava"
            )
            expect(Resolver.resolveSticky({ x = 171, y = 8, z = 0 }, bounds, opts.default, opts)).to.equal(
                "Meadow"
            )
        end)
        it(
            "uses the configured dedicated-place area instead of coordinate-derived biomes",
            function()
                for _, placeId in ipairs(places.roles.merge.place_ids) do
                    expect(PlaceRuntime.isMerge(placeId, places)).to.equal(true)
                    expect(PlaceRuntime.definitionFor(placeId, places).initial_area).to.equal(
                        "MergeEggPrototype"
                    )
                end
                local source = readFile("src/Server/Services/ZoneTrackerService.lua")
                local start =
                    assert(source:find("function ZoneTrackerService:_resolveFor", 1, true))
                local resolver = source:sub(start)
                local mission = assert(resolver:find('player:GetAttribute("InMission")', 1, true))
                local place = assert(resolver:find("if self._placeArea then", 1, true))
                local position = assert(resolver:find("local pos = rootPosition(player)", 1, true))
                expect(mission < place and place < position).to.equal(true)
                expect(source:find("PlaceRuntime.isMerge(game.PlaceId, places)", 1, true)).to.be.ok()
            end
        )
        it("guards both save entry points until the complete session has been restored", function()
            local source = readFile("src/Server/Services/MergeEggPrototypeService.lua")
            for _, method in ipairs({ "_persistPlaystate", "_persistCheckpoint" }) do
                local start =
                    assert(source:find("function MergeEggPrototypeService:" .. method, 1, true))
                local body = source:sub(start)
                local guard = assert(body:find("record.entryInitializing == true", 1, true))
                local profile = assert(body:find("self:_mergeDefenseProgress", 1, true))
                expect(guard < profile).to.equal(true)
            end
            expect(source:find("entryInitializing = true", 1, true)).to.be.ok()
            expect(source:find("record.entryInitializing = false", 1, true)).to.be.ok()
        end)
    end)
end
