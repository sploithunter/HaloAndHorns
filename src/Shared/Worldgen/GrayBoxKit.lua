--[[
    GrayBoxKit — the M2 gray-box mission tile kit as PURE DATA.

    Single SSOT for both faces of the kit:
      - definition()  → the TileCatalog kit definition (solver geometry)
      - parts(tile)   → primitive part specs for TileKitBuilder (visual geometry)
    Keeping them in one module means the walls can never disagree with the
    AABBs/doors the solver plans against — and both are headless-testable.

    PURE: no Roblox APIs. Part specs are plain tables the builder turns into
    Parts:
      { name, size = {x,y,z}, pos = {x,y,z}, face = "px|nx|pz|nz"?,
        color = {r,g,b} (0-255), material = "SmoothPlastic"?, transparency?,
        canCollide?, tags = {...}?, attrs = {...}? }

    Conventions (docs/MISSION_WORLDGEN.md §2): pivot at floor-center, floor
    top at y = 0, doors at aperture center with y = 0. Contract parts emitted
    per tile: TileRoot (pivot), Bounds (solver AABB, stripped by the
    stamper), Door_n (tagged TileConnector). Hook parts carry $MISSION
    placeholder attributes for the stamper to rewrite.
]]

local GrayBoxKit = {}

-- SCALE (live-tuned 2026-07-08): first playtest read "vastly too small" —
-- Jason called 5-7× the original footprints to start. Packs + pet trains +
-- the zoomed camera need CoH-scale halls; interiors must also comfortably
-- contain the spawner scatter (enemies.spawners.scatter = 8 studs) or waves
-- clip through walls. At this scale maps sprawl, so production solver params
-- MUST carry max_half_extent (configs/missions.lua) to stay inside a slot.
-- Walls TALL (24 → 48, 2026-07-08 playtest): with free camera zoom you could
-- crane over the maze and spot the glowy from above. Tall walls + the
-- per-mission CameraMaxZoomDistance clamp (configs/missions.lua camera)
-- keep sightlines inside the room you're in.
local WALL_HEIGHT = 48
local WALL_T = 2 -- wall thickness
-- doorways stay DOORWAY-sized at 6x room scale (Jason: chokepoints wanted;
-- wide enough for the character + pet train to funnel, no more): a header
-- strip above each opening makes it read as a door, not a wall gap.
local DOOR_W = 14 -- std aperture width (doorClasses.std)
local DOOR_H = 16 -- aperture height; header fills DOOR_H..WALL_HEIGHT

local CLASS_COLOR = {
    entrance = { 85, 255, 127 },
    corridor = { 163, 162, 165 },
    room = { 99, 128, 160 },
    junction = { 222, 178, 72 },
    objective = { 196, 40, 28 },
    cap = { 40, 40, 45 },
}

local function dim(color, k)
    return {
        math.floor(color[1] * k + 0.5),
        math.floor(color[2] * k + 0.5),
        math.floor(color[3] * k + 0.5),
    }
end

function GrayBoxKit.definition()
    return {
        kitId = "gray_box",
        doorClasses = { std = { width = DOOR_W, height = DOOR_H } },
        tiles = {
            {
                id = "entry",
                class = "entrance",
                maxPerMap = 1,
                bounds = { sx = 96, sz = 96 },
                doors = { { name = "Door_1", x = 0, z = 48, dir = "pz" } },
            },
            {
                id = "corr_straight",
                class = "corridor",
                weight = 3,
                bounds = { sx = 48, sz = 96 },
                doors = {
                    { name = "Door_1", x = 0, z = -48, dir = "nz" },
                    { name = "Door_2", x = 0, z = 48, dir = "pz" },
                },
            },
            {
                id = "corr_corner",
                class = "corridor",
                weight = 2,
                bounds = { sx = 48, sz = 48 },
                doors = {
                    { name = "Door_1", x = 0, z = -24, dir = "nz" },
                    { name = "Door_2", x = 24, z = 0, dir = "px" },
                },
            },
            {
                id = "room_small",
                class = "room",
                weight = 2,
                bounds = { sx = 96, sz = 96 },
                doors = {
                    { name = "Door_1", x = 0, z = -48, dir = "nz" },
                    { name = "Door_2", x = 48, z = 0, dir = "px" },
                    { name = "Door_3", x = -48, z = 0, dir = "nx" },
                },
            },
            {
                id = "room_big",
                class = "room",
                weight = 1,
                bounds = { sx = 144, sz = 144 },
                doors = {
                    { name = "Door_1", x = 0, z = -72, dir = "nz" },
                    { name = "Door_2", x = 72, z = 0, dir = "px" },
                    { name = "Door_3", x = -72, z = 0, dir = "nx" },
                },
            },
            {
                id = "junction_cross",
                class = "junction",
                weight = 1,
                bounds = { sx = 96, sz = 96 },
                doors = {
                    { name = "Door_1", x = 0, z = -48, dir = "nz" },
                    { name = "Door_2", x = 0, z = 48, dir = "pz" },
                    { name = "Door_3", x = 48, z = 0, dir = "px" },
                    { name = "Door_4", x = -48, z = 0, dir = "nx" },
                },
            },
            {
                id = "objective_room",
                class = "objective",
                bounds = { sx = 144, sz = 144 },
                doors = { { name = "Door_1", x = 0, z = -72, dir = "nz" } },
            },
            {
                -- thin plug: 0.4 deep < overlap_margin 0.5, so a cap always
                -- fits even flush against neighbouring geometry (§4)
                id = "cap_std",
                class = "cap",
                bounds = { sx = DOOR_W + 2, sz = 0.4 },
                doors = { { name = "Door_1", x = 0, z = -0.2, dir = "nz" } },
            },
        },
    }
end

-- Sorted wall segments for one edge span with door gaps punched out.
local function segments(spanMin, spanMax, gaps)
    table.sort(gaps, function(a, b)
        return a[1] < b[1]
    end)
    local segs = {}
    local cursor = spanMin
    for _, g in ipairs(gaps) do
        local gmin = math.max(g[1], spanMin)
        local gmax = math.min(g[2], spanMax)
        if gmax > cursor then
            if gmin > cursor + 0.05 then
                table.insert(segs, { cursor, gmin })
            end
            cursor = math.max(cursor, gmax)
        end
    end
    if spanMax > cursor + 0.05 then
        table.insert(segs, { cursor, spanMax })
    end
    return segs
end

-- Part specs for one tile definition (an entry of definition().tiles).
function GrayBoxKit.parts(tile)
    local b = tile.bounds
    local hx, hz = b.sx / 2, b.sz / 2
    local cx, cz = b.ox or 0, b.oz or 0
    local color = CLASS_COLOR[tile.class] or CLASS_COLOR.corridor
    local wallColor = dim(color, 0.6)
    local specs = {}

    local function add(spec)
        spec.color = spec.color or color
        table.insert(specs, spec)
        return spec
    end

    -- contract parts -------------------------------------------------------
    add({
        name = "TileRoot",
        size = { 0.2, 0.2, 0.2 }, -- tiny: must fit even the 0.4-deep cap bounds
        pos = { 0, 0, 0 },
        transparency = 1,
        canCollide = false,
    })
    add({
        name = "Bounds",
        size = { b.sx, WALL_HEIGHT, b.sz },
        pos = { cx, WALL_HEIGHT / 2, cz },
        transparency = 1,
        canCollide = false,
    })
    for _, door in ipairs(tile.doors) do
        add({
            name = door.name,
            size = { DOOR_W, DOOR_H, 0.4 },
            pos = { door.x, 0, door.z },
            face = door.dir,
            transparency = 1,
            canCollide = false,
            tags = { "TileConnector" },
            attrs = { DoorClass = door.class or "std" },
        })
    end

    -- cap = a single plug slab, nothing else --------------------------------
    if tile.class == "cap" then
        add({
            name = "Plug",
            size = { b.sx, WALL_HEIGHT, b.sz },
            pos = { cx, WALL_HEIGHT / 2, cz },
            color = CLASS_COLOR.cap,
        })
        return specs
    end

    -- floor ------------------------------------------------------------------
    add({
        name = "Floor",
        size = { b.sx, 1, b.sz },
        pos = { cx, -0.5, cz },
    })

    -- walls with door gaps ----------------------------------------------------
    -- x-edges (px/nx) run the full z span; z-edges are inset by WALL_T at both
    -- ends so corners aren't double-thick.
    local edges = {
        { dir = "px", axis = "z", span = { cz - hz, cz + hz }, at = cx + hx - WALL_T / 2 },
        { dir = "nx", axis = "z", span = { cz - hz, cz + hz }, at = cx - hx + WALL_T / 2 },
        {
            dir = "pz",
            axis = "x",
            span = { cx - hx + WALL_T, cx + hx - WALL_T },
            at = cz + hz - WALL_T / 2,
        },
        {
            dir = "nz",
            axis = "x",
            span = { cx - hx + WALL_T, cx + hx - WALL_T },
            at = cz - hz + WALL_T / 2,
        },
    }
    local wallIndex = 0
    local headerIndex = 0
    local headerH = WALL_HEIGHT - DOOR_H
    local headerY = DOOR_H + headerH / 2
    for _, edge in ipairs(edges) do
        local gaps = {}
        for _, door in ipairs(tile.doors) do
            if door.dir == edge.dir then
                local center = edge.axis == "z" and door.z or door.x
                table.insert(gaps, { center - DOOR_W / 2, center + DOOR_W / 2 })
                -- header strip over the opening: makes it a DOORWAY, not a gap
                headerIndex += 1
                if edge.axis == "z" then
                    add({
                        name = "Header_" .. headerIndex,
                        size = { WALL_T, headerH, DOOR_W },
                        pos = { edge.at, headerY, center },
                        color = wallColor,
                    })
                else
                    add({
                        name = "Header_" .. headerIndex,
                        size = { DOOR_W, headerH, WALL_T },
                        pos = { center, headerY, edge.at },
                        color = wallColor,
                    })
                end
            end
        end
        for _, seg in ipairs(segments(edge.span[1], edge.span[2], gaps)) do
            wallIndex += 1
            local mid = (seg[1] + seg[2]) / 2
            local len = seg[2] - seg[1]
            if edge.axis == "z" then
                add({
                    name = "Wall_" .. wallIndex,
                    size = { WALL_T, WALL_HEIGHT, len },
                    pos = { edge.at, WALL_HEIGHT / 2, mid },
                    color = wallColor,
                })
            else
                add({
                    name = "Wall_" .. wallIndex,
                    size = { len, WALL_HEIGHT, WALL_T },
                    pos = { mid, WALL_HEIGHT / 2, edge.at },
                    color = wallColor,
                })
            end
        end
    end

    -- STATIC population anchors (CoH model): rooms and the objective chamber
    -- carry a MissionSpawn point — MissionInstanceService fields a seeded,
    -- fixed pack here ONCE at stamp time (no proximity waves, no respawn;
    -- deliberately NOT named BaddieSpawner* so the homeworld wave system
    -- never arms these). Corridors stay clean.
    if tile.class == "room" or tile.class == "objective" then
        add({
            name = "MissionSpawn",
            size = { 1, 1, 1 },
            pos = {
                tile.class == "objective" and 24 or 0,
                1,
                tile.class == "objective" and 24 or 0,
            },
            transparency = 1,
            canCollide = false,
        })
    end

    -- class hooks --------------------------------------------------------------
    if tile.class == "entrance" then
        add({
            name = "SpawnPad",
            size = { 10, 0.4, 10 },
            pos = { 0, 0.2, 0 },
            color = { 255, 255, 255 },
            canCollide = false,
            tags = { "PlayerSpawn" },
            attrs = { AreaId = "$MISSION" },
        })
    elseif tile.class == "objective" then
        add({
            name = "ObjectiveBeacon",
            size = { 4, 14, 4 },
            pos = { 0, 7, 0 },
            material = "Neon",
            canCollide = false,
            tags = { "MissionObjective" },
            attrs = { ObjectiveId = "$MISSION_objective", AreaId = "$MISSION" },
        })
    end

    return specs
end

return GrayBoxKit
