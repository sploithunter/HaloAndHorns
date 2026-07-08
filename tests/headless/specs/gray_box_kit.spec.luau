--[[
    GrayBoxKit — [unit] M2 gray-box kit geometry invariants.
    Pure: the kit is data; these tests prove the VISUAL geometry (walls,
    gaps, contract parts) agrees with the SOLVER geometry (bounds, doors)
    for every tile — so a stamped map can never have a wall across a mated
    doorway. Run: mise run test-headless
]]

local GrayBoxKit = loadModule("src/Shared/Worldgen/GrayBoxKit.lua")
local TileCatalog = loadModule("src/Shared/Worldgen/TileCatalog.lua")

local EPS = 1e-6

local function aabbOf(spec)
    -- face px/nx turns the part 90° about Y in the builder (lookAt), so its
    -- width (size x) runs along z and its depth (size z) along x
    local sx, sz = spec.size[1], spec.size[3]
    if spec.face == "px" or spec.face == "nx" then
        sx, sz = sz, sx
    end
    return {
        minx = spec.pos[1] - sx / 2,
        maxx = spec.pos[1] + sx / 2,
        miny = spec.pos[2] - spec.size[2] / 2,
        maxy = spec.pos[2] + spec.size[2] / 2,
        minz = spec.pos[3] - sz / 2,
        maxz = spec.pos[3] + sz / 2,
    }
end

local function intersectsXZ(a, b)
    return a.minx < b.maxx - EPS
        and a.maxx > b.minx + EPS
        and a.minz < b.maxz - EPS
        and a.maxz > b.minz + EPS
end

local function findAll(specs, prefix)
    local out = {}
    for _, s in ipairs(specs) do
        if s.name:sub(1, #prefix) == prefix then
            table.insert(out, s)
        end
    end
    return out
end

local function findOne(specs, name)
    for _, s in ipairs(specs) do
        if s.name == name then
            return s
        end
    end
    return nil
end

return function()
    describe("GrayBoxKit", function()
        local def = GrayBoxKit.definition()

        it("definition passes the TileCatalog contract", function()
            local catalog = TileCatalog.build(def)
            expect(catalog.kitId).to.equal("gray_box")
        end)

        it(
            "every tile emits the contract parts (TileRoot at pivot, Bounds == solver AABB, all doors)",
            function()
                for _, tile in ipairs(def.tiles) do
                    local specs = GrayBoxKit.parts(tile)
                    local root = findOne(specs, "TileRoot")
                    expect(root ~= nil).to.equal(true)
                    expect(root.pos[1]).to.equal(0)
                    expect(root.pos[3]).to.equal(0)

                    local bounds = findOne(specs, "Bounds")
                    expect(bounds ~= nil).to.equal(true)
                    expect(bounds.size[1]).to.equal(tile.bounds.sx)
                    expect(bounds.size[3]).to.equal(tile.bounds.sz)

                    for _, door in ipairs(tile.doors) do
                        local part = findOne(specs, door.name)
                        expect(part ~= nil).to.equal(true)
                        expect(part.pos[1]).to.equal(door.x)
                        expect(part.pos[2]).to.equal(0) -- aperture center at floor level
                        expect(part.pos[3]).to.equal(door.z)
                        expect(part.face).to.equal(door.dir)
                        expect(part.tags[1]).to.equal("TileConnector")
                    end
                end
            end
        )

        it(
            "every part stays inside the tile's solver AABB (nothing pokes into a neighbour)",
            function()
                for _, tile in ipairs(def.tiles) do
                    local hx, hz = tile.bounds.sx / 2, tile.bounds.sz / 2
                    local cx, cz = tile.bounds.ox or 0, tile.bounds.oz or 0
                    for _, spec in ipairs(GrayBoxKit.parts(tile)) do
                        local a = aabbOf(spec)
                        -- door marker parts are thin markers ON the boundary plane;
                        -- they may straddle it by half their 0.4 depth
                        local slack = spec.tags and spec.tags[1] == "TileConnector" and 0.2 or EPS
                        -- cap dressing (sealed doors/boards) sits recessed in
                        -- the HOST tile's aperture tunnel: -z only, and that
                        -- space is guaranteed open air behind a mated doorway
                        local negZSlack = tile.class == "cap" and 2.0 or slack
                        expect(a.minx >= cx - hx - slack).to.equal(true)
                        expect(a.maxx <= cx + hx + slack).to.equal(true)
                        expect(a.minz >= cz - hz - negZSlack).to.equal(true)
                        expect(a.maxz <= cz + hz + slack).to.equal(true)
                    end
                end
            end
        )

        it("no wall crosses a door aperture", function()
            for _, tile in ipairs(def.tiles) do
                local specs = GrayBoxKit.parts(tile)
                local walls = findAll(specs, "Wall_")
                for _, door in ipairs(tile.doors) do
                    -- aperture rect: DOOR width along the edge, thin along the
                    -- door normal, centred on the door position
                    local w = def.doorClasses[door.class or "std"].width
                    local alongX = (door.dir == "pz" or door.dir == "nz")
                    local rect = {
                        minx = door.x - (alongX and w / 2 or 1.5),
                        maxx = door.x + (alongX and w / 2 or 1.5),
                        minz = door.z - (alongX and 1.5 or w / 2),
                        maxz = door.z + (alongX and 1.5 or w / 2),
                    }
                    for _, wall in ipairs(walls) do
                        expect(intersectsXZ(aabbOf(wall), rect)).to.equal(false)
                    end
                end
            end
        end)

        it("non-cap tiles have a floor; caps read as SEALED doorways", function()
            for _, tile in ipairs(def.tiles) do
                local specs = GrayBoxKit.parts(tile)
                if tile.class == "cap" then
                    expect(findOne(specs, "Floor") == nil).to.equal(true)
                    expect(findOne(specs, "Backing") ~= nil).to.equal(true)
                    if tile.id == "cap_door" then
                        expect(#findAll(specs, "Plank_")).to.equal(5)
                        expect(findOne(specs, "Padlock") ~= nil).to.equal(true)
                        expect(findOne(specs, "Knob") ~= nil).to.equal(true)
                    elseif tile.id == "cap_boarded" then
                        expect(#findAll(specs, "Board_")).to.equal(4)
                    end
                else
                    local floor = findOne(specs, "Floor")
                    expect(floor ~= nil).to.equal(true)
                    expect(floor.size[1]).to.equal(tile.bounds.sx)
                    expect(floor.size[3]).to.equal(tile.bounds.sz)
                end
            end
        end)

        it("rooms and objective carry a MissionSpawn anchor; corridors and caps don't", function()
            for _, tile in ipairs(def.tiles) do
                local specs = GrayBoxKit.parts(tile)
                local anchor = findOne(specs, "MissionSpawn")
                local shouldHave = tile.class == "room" or tile.class == "objective"
                expect(anchor ~= nil).to.equal(shouldHave)
                -- never BaddieSpawner-prefixed: the homeworld proximity-wave
                -- system must not arm mission interiors
                for _, s in ipairs(specs) do
                    expect(s.name:sub(1, 13) == "BaddieSpawner").to.equal(false)
                end
            end
        end)

        it("every doorway gets a flanking torch pair with a light (M5a)", function()
            for _, tile in ipairs(def.tiles) do
                if tile.class ~= "cap" then
                    local specs = GrayBoxKit.parts(tile)
                    local flames = findAll(specs, "TorchFlame_")
                    expect(#flames).to.equal(#tile.doors * 2)
                    for _, flame in ipairs(flames) do
                        expect(flame.light ~= nil).to.equal(true)
                    end
                end
            end
        end)

        it("chamber tiles get corner pillars; corridors stay clear (M5a)", function()
            for _, tile in ipairs(def.tiles) do
                if tile.class ~= "cap" then
                    local pillars = findAll(GrayBoxKit.parts(tile), "Pillar_")
                    if tile.class == "corridor" then
                        expect(#pillars).to.equal(0)
                    else
                        expect(#pillars).to.equal(4)
                    end
                end
            end
        end)

        it("hook parts carry $MISSION placeholder attributes", function()
            local entry, objective
            for _, tile in ipairs(def.tiles) do
                if tile.class == "entrance" then
                    entry = findOne(GrayBoxKit.parts(tile), "SpawnPad")
                elseif tile.class == "objective" then
                    objective = findOne(GrayBoxKit.parts(tile), "ObjectiveBeacon")
                end
            end
            expect(entry ~= nil).to.equal(true)
            expect(entry.tags[1]).to.equal("PlayerSpawn")
            expect(entry.attrs.AreaId).to.equal("$MISSION")
            expect(objective ~= nil).to.equal(true)
            expect(objective.tags[1]).to.equal("MissionObjective")
            expect(objective.attrs.ObjectiveId).to.equal("$MISSION_objective")
        end)
    end)
end
