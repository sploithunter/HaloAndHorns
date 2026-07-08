--[[
    Mission worldgen — [unit] MissionSeed + TileCatalog + LayoutSolver (M1/M2).
    Pure: deterministic via seeded mulberry32 streams. Run: mise run test-headless
    Design SSOT: docs/MISSION_WORLDGEN.md
    Kit geometry SSOT: src/Shared/Worldgen/GrayBoxKit.lua (M2) — the solver
    sweep runs against the SAME definition the in-game builder consumes.
]]

local MissionSeed = loadModule("src/Shared/Worldgen/MissionSeed.lua")
local TileCatalog = loadModule("src/Shared/Worldgen/TileCatalog.lua")
local LayoutSolver = loadModule("src/Shared/Worldgen/LayoutSolver.lua")
local GrayBoxKit = loadModule("src/Shared/Worldgen/GrayBoxKit.lua")
local MissionPopulation = loadModule("src/Shared/Worldgen/MissionPopulation.lua")
local MissionDecor = loadModule("src/Shared/Worldgen/MissionDecor.lua")

local grayBoxDef = GrayBoxKit.definition

-- keep in lockstep with configs/missions.lua solver_defaults — the sweep
-- must prove solvability under the PRODUCTION envelope at the 6x tile scale
local SOLVER_PARAMS = {
    tile_budget = 30,
    target_depth = { min = 4, max = 8 },
    class_weights_by_band = {
        { upto = 0.5, corridor = 3, room = 1, junction = 1 },
        { upto = 1.0, corridor = 1, room = 3, junction = 1 },
    },
    max_half_extent = 1200,
}

local function deepEquals(a, b)
    if a == b then
        return true
    end
    if type(a) ~= "table" or type(b) ~= "table" then
        return false
    end
    for k, v in pairs(a) do
        if not deepEquals(v, b[k]) then
            return false
        end
    end
    for k in pairs(b) do
        if a[k] == nil then
            return false
        end
    end
    return true
end

local function expectBuildError(mutate, needle)
    local def = grayBoxDef()
    mutate(def)
    local ok, err = pcall(TileCatalog.build, def)
    expect(ok).to.equal(false)
    expect(string.find(tostring(err), needle, 1, true) ~= nil).to.equal(true)
end

return function()
    describe("MissionSeed", function()
        it("fnv1a32 matches published test vectors", function()
            expect(MissionSeed.fnv1a32("")).to.equal(2166136261)
            expect(MissionSeed.fnv1a32("a")).to.equal(3826002220)
        end)

        it("seed folds version, mission and context (any change → new seed)", function()
            local base = MissionSeed.seed("rescue", "team42", 1)
            expect(MissionSeed.seed("rescue", "team42", 1)).to.equal(base)
            expect(MissionSeed.seed("rescue", "team42", 2)).never.to.equal(base)
            expect(MissionSeed.seed("rescue", "team43", 1)).never.to.equal(base)
            expect(MissionSeed.seed("escort", "team42", 1)).never.to.equal(base)
        end)

        it("phase streams are isolated", function()
            local seed = MissionSeed.seed("rescue", "team42", 1)
            expect(MissionSeed.stream(seed, "layout")).never.to.equal(
                MissionSeed.stream(seed, "decor")
            )
            expect(MissionSeed.stream(seed, "layout")).to.equal(MissionSeed.stream(seed, "layout"))
        end)

        it("mulberry32 is deterministic and in [0, 1)", function()
            local a = MissionSeed.mulberry32(1234)
            local b = MissionSeed.mulberry32(1234)
            local c = MissionSeed.mulberry32(5678)
            local diverged = false
            for _ = 1, 20 do
                local va, vb, vc = a(), b(), c()
                expect(va).to.equal(vb)
                expect(va >= 0 and va < 1).to.equal(true)
                if va ~= vc then
                    diverged = true
                end
            end
            expect(diverged).to.equal(true)
        end)
    end)

    describe("TileCatalog", function()
        it("builds the gray-box kit and indexes by class", function()
            local catalog = TileCatalog.build(grayBoxDef())
            expect(catalog.kitId).to.equal("gray_box")
            expect(#catalog.byClass.entrance).to.equal(1)
            expect(#catalog.byClass.corridor).to.equal(2)
            expect(#catalog.byClass.room).to.equal(3) -- small, big, mezzanine hall
            expect(#catalog.byClass.objective).to.equal(1)
            expect(#catalog.byClass.cap).to.equal(2) -- sealed-door + boarded variants
            expect(catalog.byId.corr_straight.bounds.hx).to.equal(24)
        end)

        it("rejects duplicate tile ids", function()
            expectBuildError(function(def)
                def.tiles[2].id = "entry"
            end, "duplicate tile id")
        end)

        it("rejects a kit with no entrance", function()
            expectBuildError(function(def)
                def.tiles[1].class = "room"
            end, "at least one entrance")
        end)

        it("rejects a cap with more than one door", function()
            expectBuildError(function(def)
                table.insert(
                    def.tiles[#def.tiles].doors,
                    { name = "Door_2", x = 0, z = 0.2, dir = "pz" }
                )
            end, "exactly one door")
        end)

        it("rejects a used door class with no cap plug", function()
            expectBuildError(function(def)
                def.doorClasses.wide = { width = 20, height = 14 }
                def.tiles[4].doors[2].class = "wide"
            end, "no cap tile plugs door class")
        end)

        it("rejects a non-axis-aligned door dir", function()
            expectBuildError(function(def)
                def.tiles[2].doors[1].dir = "up"
            end, "dir must be")
        end)
    end)

    describe("LayoutSolver.solve", function()
        local catalog = TileCatalog.build(grayBoxDef())

        it("produces a valid spec for a fixed seed", function()
            local spec, report = LayoutSolver.solve(catalog, SOLVER_PARAMS, 12345)
            expect(spec).to.be.ok()
            expect(report.attempts >= 1).to.equal(true)
            expect(spec.tiles[1].tileId).to.equal("entry")
            expect(#spec.objectiveTileIndices >= 1).to.equal(true)
            local ok, problems = LayoutSolver.validate(catalog, spec, SOLVER_PARAMS)
            expect(table.concat(problems, " / ")).to.equal("")
            expect(ok).to.equal(true)
        end)

        it("is deterministic: same seed → deep-equal spec", function()
            local a = LayoutSolver.solve(catalog, SOLVER_PARAMS, 987654)
            local b = LayoutSolver.solve(catalog, SOLVER_PARAMS, 987654)
            expect(a).to.be.ok()
            expect(deepEquals(a, b)).to.equal(true)
        end)

        it("varies with the seed", function()
            local shapes = {}
            for seed = 1, 12 do
                local spec = LayoutSolver.solve(catalog, SOLVER_PARAMS, seed)
                expect(spec).to.be.ok()
                shapes[#spec.tiles .. ":" .. spec.bbox.minx .. ":" .. spec.bbox.maxz] = true
            end
            local distinct = 0
            for _ in pairs(shapes) do
                distinct += 1
            end
            expect(distinct >= 2).to.equal(true)
        end)

        it("respects maxPerMap and the growth budget", function()
            local spec = LayoutSolver.solve(catalog, SOLVER_PARAMS, 424242)
            expect(spec).to.be.ok()
            local entries, growth = 0, 0
            for _, t in ipairs(spec.tiles) do
                local class = catalog.byId[t.tileId].class
                if t.tileId == "entry" then
                    entries += 1
                end
                if class ~= "cap" then
                    growth += 1
                end
            end
            expect(entries).to.equal(1)
            expect(growth <= SOLVER_PARAMS.tile_budget).to.equal(true)
        end)

        it("places the objective within the target depth band", function()
            local spec = LayoutSolver.solve(catalog, SOLVER_PARAMS, 777)
            expect(spec).to.be.ok()
            for _, idx in ipairs(spec.objectiveTileIndices) do
                local depth = spec.tiles[idx].depth
                expect(depth >= SOLVER_PARAMS.target_depth.min).to.equal(true)
                expect(depth <= SOLVER_PARAMS.target_depth.max).to.equal(true)
            end
        end)

        it("survives a 300-seed sweep with every invariant intact", function()
            local failures = {}
            for seed = 1, 300 do
                local spec, report = LayoutSolver.solve(catalog, SOLVER_PARAMS, seed)
                if not spec then
                    table.insert(
                        failures,
                        ("seed %d: unsolved (%s)"):format(seed, tostring(report.error))
                    )
                else
                    local ok, problems = LayoutSolver.validate(catalog, spec, SOLVER_PARAMS)
                    if not ok then
                        table.insert(
                            failures,
                            ("seed %d: %s"):format(seed, table.concat(problems, " / "))
                        )
                    end
                end
            end
            expect(table.concat(failures, " | ")).to.equal("")
        end)
    end)

    describe("LayoutSolver.mapData", function()
        local catalog = TileCatalog.build(grayBoxDef())

        it("emits one rect per non-cap tile and only walkable doorways", function()
            local spec = LayoutSolver.solve(catalog, SOLVER_PARAMS, 12345)
            expect(spec).to.be.ok()
            local map = LayoutSolver.mapData(catalog, spec)

            local nonCap, capConnections = 0, 0
            for _, t in ipairs(spec.tiles) do
                if catalog.byId[t.tileId].class ~= "cap" then
                    nonCap += 1
                end
            end
            for _, c in ipairs(spec.connections) do
                if
                    catalog.byId[spec.tiles[c.a.tile].tileId].class == "cap"
                    or catalog.byId[spec.tiles[c.b.tile].tileId].class == "cap"
                then
                    capConnections += 1
                end
            end
            expect(#map.rooms).to.equal(nonCap)
            expect(#map.doors).to.equal(#spec.connections - capConnections)

            -- every door references valid rooms and sits inside the bbox
            for _, door in ipairs(map.doors) do
                expect(map.rooms[door.a] ~= nil).to.equal(true)
                expect(map.rooms[door.b] ~= nil).to.equal(true)
                expect(door.ax == "x" or door.ax == "z").to.equal(true)
                expect(door.x >= map.bbox.minx - 1e-6 and door.x <= map.bbox.maxx + 1e-6).to.equal(
                    true
                )
                expect(door.z >= map.bbox.minz - 1e-6 and door.z <= map.bbox.maxz + 1e-6).to.equal(
                    true
                )
            end

            -- exactly one entrance rect; at least one objective rect
            local entrances, objectives = 0, 0
            for _, room in ipairs(map.rooms) do
                if room.class == "entrance" then
                    entrances += 1
                elseif room.class == "objective" then
                    objectives += 1
                end
            end
            expect(entrances).to.equal(1)
            expect(objectives >= 1).to.equal(true)
        end)

        it("door ticks sit on the shared edge of their two rooms", function()
            local spec = LayoutSolver.solve(catalog, SOLVER_PARAMS, 777)
            local map = LayoutSolver.mapData(catalog, spec)
            for _, door in ipairs(map.doors) do
                for _, idx in ipairs({ door.a, door.b }) do
                    local room = map.rooms[idx]
                    local dx = math.abs(door.x - room.x)
                    local dz = math.abs(door.z - room.z)
                    -- on or inside the room's boundary (doors sit on the wall plane)
                    expect(dx <= room.hx + 1e-6 and dz <= room.hz + 1e-6).to.equal(true)
                end
            end
        end)
    end)

    describe("MissionPopulation.roll", function()
        local PACKS = {
            { weight = 10, units = { { enemy = "rabid_dog", count = 2 } } },
            { weight = 5, units = { { enemy = "raging_bear", count = 1 } } },
            { weight = 0, units = { { enemy = "never_me", count = 1 } } },
        }

        it("is deterministic for a stream seed and varies across seeds", function()
            local a = MissionPopulation.roll(PACKS, 6, 777)
            local b = MissionPopulation.roll(PACKS, 6, 777)
            local c = MissionPopulation.roll(PACKS, 6, 778)
            expect(#a).to.equal(6)
            local same, diff = true, false
            for i = 1, 6 do
                if table.concat(a[i], ",") ~= table.concat(b[i], ",") then
                    same = false
                end
                if table.concat(a[i], ",") ~= table.concat(c[i], ",") then
                    diff = true
                end
            end
            expect(same).to.equal(true)
            expect(diff).to.equal(true)
        end)

        it("expands unit counts and never rolls zero-weight packs", function()
            for seed = 1, 40 do
                local rolls = MissionPopulation.roll(PACKS, 4, seed)
                for _, list in ipairs(rolls) do
                    expect(#list == 2 or #list == 1).to.equal(true) -- 2 dogs or 1 bear
                    for _, id in ipairs(list) do
                        expect(id ~= "never_me").to.equal(true)
                    end
                end
            end
        end)

        it("yields empty lists when no packs are configured", function()
            local rolls = MissionPopulation.roll({}, 3, 42)
            expect(#rolls).to.equal(3)
            expect(#rolls[1]).to.equal(0)
        end)
    end)

    describe("MissionDecor.roll", function()
        local catalog = TileCatalog.build(grayBoxDef())

        local function mapFor(seed)
            local spec = LayoutSolver.solve(catalog, SOLVER_PARAMS, seed)
            return LayoutSolver.mapData(catalog, spec)
        end

        it("is deterministic and stays inside rooms, clear of the center", function()
            local map = mapFor(12345)
            local tintsA, propsA = MissionDecor.roll(map.rooms, 999)
            local tintsB, propsB = MissionDecor.roll(map.rooms, 999)
            expect(#propsA).to.equal(#propsB)
            for i, p in ipairs(propsA) do
                expect(p.x).to.equal(propsB[i].x)
                expect(p.kind).to.equal(propsB[i].kind)
                local room = map.rooms[p.room]
                -- inside the wall-inset band
                expect(math.abs(p.x - room.x) <= room.hx - 8 + 1e-6).to.equal(true)
                expect(math.abs(p.z - room.z) <= room.hz - 8 + 1e-6).to.equal(true)
            end
            for i in ipairs(map.rooms) do
                expect(tintsA[i].wall).to.equal(tintsB[i].wall)
                expect(math.abs(tintsA[i].wall - 1) <= 0.12 + 1e-6).to.equal(true)
                expect(math.abs(tintsA[i].floor - 1) <= 0.12 + 1e-6).to.equal(true)
            end
        end)

        it("never dresses corridors", function()
            local map = mapFor(777)
            local _, props = MissionDecor.roll(map.rooms, 42)
            for _, p in ipairs(props) do
                expect(map.rooms[p.room].class == "corridor").to.equal(false)
            end
        end)

        it("wall decor hugs walls and stays clear of doorways", function()
            local map = mapFor(12345)
            local _, _, wallDecor = MissionDecor.roll(map.rooms, 99, {
                doors = map.doors,
                wall_decor_min = 1,
                wall_decor_max = 2,
            })
            expect(#wallDecor > 0).to.equal(true)
            for _, wd in ipairs(wallDecor) do
                local room = map.rooms[wd.room]
                -- on exactly one axis it sits at the wall inner face
                local dxEdge = math.abs(math.abs(wd.x - room.x) - (room.hx - 2.6))
                local dzEdge = math.abs(math.abs(wd.z - room.z) - (room.hz - 2.6))
                expect(math.min(dxEdge, dzEdge) < 1e-6).to.equal(true)
                -- inward normal points into the room
                expect(wd.ix ~= 0 or wd.iz ~= 0).to.equal(true)
                -- clear of every doorway on that room by the placement rule
                for _, door in ipairs(map.doors) do
                    if door.a == wd.room or door.b == wd.room then
                        local sameWallX = wd.ix ~= 0
                            and math.abs(door.x - (room.x - wd.ix * room.hx)) < 2
                        local sameWallZ = wd.iz ~= 0
                            and math.abs(door.z - (room.z - wd.iz * room.hz)) < 2
                        if sameWallX then
                            expect(math.abs(door.z - wd.z) >= 12 - 1e-6).to.equal(true)
                        elseif sameWallZ then
                            expect(math.abs(door.x - wd.x) >= 12 - 1e-6).to.equal(true)
                        end
                    end
                end
            end
        end)
        it("feature spots are deterministic, chamber-only, wall-centered, door-clear", function()
            local map = mapFor(12345)
            local opts = { doors = map.doors, feature_chance = 1 }
            local _, _, _, featA = MissionDecor.roll(map.rooms, 4242, opts)
            local _, _, _, featB = MissionDecor.roll(map.rooms, 4242, opts)
            expect(#featA > 0).to.equal(true)
            expect(#featA).to.equal(#featB)
            local perRoom = {}
            for i, ft in ipairs(featA) do
                expect(ft.x).to.equal(featB[i].x)
                expect(ft.z).to.equal(featB[i].z)
                local room = map.rooms[ft.room]
                -- chambers only, at most one each
                expect(room.class == "corridor" or room.class == "entrance").to.equal(false)
                expect(perRoom[ft.room]).to.equal(nil)
                perRoom[ft.room] = true
                -- at a wall's inner face on one axis; on the other axis it is
                -- inside the room span (center preferred, off-center fallback)
                local onX = math.abs(math.abs(ft.x - room.x) - (room.hx - 2.6)) < 1e-6
                local onZ = math.abs(math.abs(ft.z - room.z) - (room.hz - 2.6)) < 1e-6
                expect(onX or onZ).to.equal(true)
                if onX then
                    expect(math.abs(ft.z - room.z) <= room.hz - 12 + 1e-6).to.equal(true)
                else
                    expect(math.abs(ft.x - room.x) <= room.hx - 12 + 1e-6).to.equal(true)
                end
                -- clear of doorways on that wall by the wide feature margin
                for _, door in ipairs(map.doors) do
                    if door.a == ft.room or door.b == ft.room then
                        local sameWallX = ft.ix ~= 0
                            and math.abs(door.x - (room.x - ft.ix * room.hx)) < 2
                        local sameWallZ = ft.iz ~= 0
                            and math.abs(door.z - (room.z - ft.iz * room.hz)) < 2
                        if sameWallX then
                            expect(math.abs(door.z - ft.z) >= 18 - 1e-6).to.equal(true)
                        elseif sameWallZ then
                            expect(math.abs(door.x - ft.x) >= 18 - 1e-6).to.equal(true)
                        end
                    end
                end
            end
        end)
    end)

    describe("LayoutSolver.validate", function()
        local catalog = TileCatalog.build(grayBoxDef())

        it("catches a corrupted spec (shifted tile)", function()
            local spec = LayoutSolver.solve(catalog, SOLVER_PARAMS, 555)
            expect(spec).to.be.ok()
            spec.tiles[2].x += 1 -- unmoors tile 2: doors no longer pair up
            local ok = LayoutSolver.validate(catalog, spec, SOLVER_PARAMS)
            expect(ok).to.equal(false)
        end)
    end)
end
