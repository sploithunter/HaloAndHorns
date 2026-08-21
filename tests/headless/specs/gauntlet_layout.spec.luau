--[[
    Gauntlet layout contract — Range / Training Ground Room N is a fixed map.
    Same inputs ⇒ same LayoutSpec. Never more than entry + 3 growth rooms.
]]

local MissionSeed = loadModule("src/Shared/Worldgen/MissionSeed.lua")
local TileCatalog = loadModule("src/Shared/Worldgen/TileCatalog.lua")
local LayoutSolver = loadModule("src/Shared/Worldgen/LayoutSolver.lua")
local GrayBoxKit = loadModule("src/Shared/Worldgen/GrayBoxKit.lua")
local ChallengeRun = loadModule("src/Shared/Game/ChallengeRun.lua")

local WORLDGEN_VERSION = 2

-- Keep in lockstep with configs/missions.lua range / training_ground overrides.
local GAUNTLET_PARAMS = {
    tile_budget = 4,
    target_depth = { min = 2, max = 3 },
    class_weights_by_band = {
        { upto = 1.0, corridor = 0, room = 1, junction = 0 },
    },
    max_half_extent = 400,
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

local function fingerprint(spec)
    local parts = { tostring(#spec.tiles) }
    for _, tile in ipairs(spec.tiles) do
        table.insert(parts, string.format("%s:%s:%s:%s", tile.tileId, tile.x, tile.z, tile.rot))
    end
    return table.concat(parts, "|")
end

return function()
    describe("gauntlet layout contract", function()
        it("seeds Room N from room#N only", function()
            local a = MissionSeed.seed("range", ChallengeRun.layoutContext(1), WORLDGEN_VERSION)
            local b = MissionSeed.seed("range", ChallengeRun.layoutContext(1), WORLDGEN_VERSION)
            local c = MissionSeed.seed("range", ChallengeRun.layoutContext(2), WORLDGEN_VERSION)
            local salted = MissionSeed.seed("range", "team42#salt#1", WORLDGEN_VERSION)
            expect(a).to.equal(b)
            expect(a).never.to.equal(c)
            expect(a).never.to.equal(salted)
            local train = MissionSeed.seed(
                "training_ground",
                ChallengeRun.layoutContext(1, "training_ground"),
                WORLDGEN_VERSION
            )
            expect(a).never.to.equal(train)
        end)

        it("solves the same Room 1 map twice and stays within entry + 3 rooms", function()
            local catalog = TileCatalog.build(GrayBoxKit.definition())
            local seed = MissionSeed.seed("range", ChallengeRun.layoutContext(1), WORLDGEN_VERSION)
            local layoutSeed = MissionSeed.stream(seed, "layout")
            local first, report = LayoutSolver.solve(catalog, GAUNTLET_PARAMS, layoutSeed)
            local second = LayoutSolver.solve(catalog, GAUNTLET_PARAMS, layoutSeed)
            expect(first ~= nil).to.equal(true)
            expect(deepEquals(first, second)).to.equal(true)
            expect(report.growthTiles <= 4).to.equal(true)
            expect(#first.tiles >= 3).to.equal(true)
        end)

        it("gives each room index a stable map and more than one distinct layout", function()
            local catalog = TileCatalog.build(GrayBoxKit.definition())
            local seen = {}
            local distinct = 0
            for room = 1, 8 do
                local seed =
                    MissionSeed.seed("range", ChallengeRun.layoutContext(room), WORLDGEN_VERSION)
                local stream = MissionSeed.stream(seed, "layout")
                local a, reportA = LayoutSolver.solve(catalog, GAUNTLET_PARAMS, stream)
                local b = LayoutSolver.solve(catalog, GAUNTLET_PARAMS, stream)
                expect(a ~= nil).to.equal(true)
                expect(deepEquals(a, b)).to.equal(true)
                expect((reportA and reportA.growthTiles or #a.tiles) <= 8).to.equal(true)
                local fp = fingerprint(a)
                if not seen[fp] then
                    seen[fp] = true
                    distinct += 1
                end
            end
            expect(distinct >= 2).to.equal(true)
        end)
    end)
end
