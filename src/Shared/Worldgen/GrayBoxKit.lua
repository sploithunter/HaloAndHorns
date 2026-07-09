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
                -- MEZZANINE HALL (Jason): multi-level FEEL on a single-level
                -- map — a tall room with an upper gallery + walk-up ramps.
                -- The solver only sees XZ doors; all verticality is interior.
                id = "mezzanine_hall",
                class = "room",
                weight = 1,
                minDepth = 2, -- grand halls read better past the entrance
                wallHeight = 64,
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
                -- SEALED doorway covers (Jason: caps must READ as "a door you
                -- can't open" — deliberate visual language for the plugged
                -- procgen openings; openable doors are intentionally NOT a
                -- thing so "door" always means impassable). Thin bounds
                -- (0.4 < overlap_margin) so caps always fit; the dressing
                -- sits recessed in the HOST tile's aperture tunnel (local
                -- z ∈ [-2, -0.2] = guaranteed open air behind a mated
                -- doorway — see parts()).
                id = "cap_door", -- locked plank door + padlock
                class = "cap",
                weight = 3,
                bounds = { sx = DOOR_W + 2, sz = 0.4 },
                doors = { { name = "Door_1", x = 0, z = -0.2, dir = "nz" } },
            },
            {
                id = "cap_boarded", -- planks nailed across the opening
                class = "cap",
                weight = 2,
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
    -- per-tile wall height (mezzanine halls run taller than the kit default)
    local wallH = tile.wallHeight or WALL_HEIGHT
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
        size = { b.sx, wallH, b.sz },
        pos = { cx, wallH / 2, cz },
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
        -- full-height backing slab seals the doorway (the old Plug)
        add({
            name = "Backing",
            size = { b.sx, wallH, b.sz },
            pos = { cx, wallH / 2, cz },
            color = { 30, 28, 32 },
        })
        if tile.id == "cap_boarded" then
            -- rough boards nailed across the recess at drunken angles
            local boards = {
                { y = 4.5, tilt = 9 },
                { y = 8, tilt = -7 },
                { y = 11.5, tilt = 12 },
                { y = 14.5, tilt = -10 },
            }
            for i, board in ipairs(boards) do
                add({
                    name = "Board_" .. i,
                    size = { 15, 2.2, 0.7 },
                    pos = { 0, board.y, -0.9 },
                    tilt = board.tilt,
                    color = { 96, 70, 40 },
                    material = "WoodPlanks",
                })
            end
        else
            -- locked plank door recessed into the frame: jittered planks,
            -- cross braces, knob, padlock — reads "closed and locked"
            local plankX = { -5.6, -2.8, 0, 2.8, 5.6 }
            local plankZ = { -0.95, -1.1, -1.0, -1.15, -0.9 }
            local plankShade = { 112, 104, 118, 98, 108 }
            for i, x in ipairs(plankX) do
                local shade = plankShade[i]
                add({
                    name = "Plank_" .. i,
                    size = { 2.7, 15.2, 0.8 },
                    pos = { x, 7.8, plankZ[i] },
                    color = { shade, math.floor(shade * 0.72), math.floor(shade * 0.4) },
                    material = "WoodPlanks",
                })
            end
            for i, y in ipairs({ 4, 11.5 }) do
                add({
                    name = "Brace_" .. i,
                    size = { 13.6, 1.8, 0.6 },
                    pos = { 0, y, -0.55 },
                    color = { 88, 60, 32 },
                    material = "Wood",
                })
            end
            add({
                name = "Knob",
                shape = "Ball",
                size = { 1.3, 1.3, 1.3 },
                pos = { 5, 7.8, -0.5 },
                color = { 70, 66, 72 },
                material = "Metal",
            })
            add({
                name = "Padlock",
                size = { 1.6, 2.1, 0.7 },
                pos = { 5, 5.6, -0.45 },
                color = { 58, 56, 62 },
                material = "DiamondPlate",
            })
            add({
                name = "Shackle",
                size = { 1.1, 1, 0.5 },
                pos = { 5, 6.9, -0.45 },
                color = { 40, 40, 46 },
                material = "Metal",
            })
        end
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
    local torchIndex = 0
    local headerH = wallH - DOOR_H
    local headerY = DOOR_H + headerH / 2
    -- M5a: a pair of torches flanks every doorway on the room side —
    -- local lights carry the whole mood out at the dark slot band
    local function addTorchPair(edge, center)
        local offsets = { -(DOOR_W / 2 + 3), DOOR_W / 2 + 3 }
        -- inward = opposite the edge's outward dir, pulled 1.6 off the wall
        local inX = edge.dir == "px" and -1.6 or edge.dir == "nx" and 1.6 or 0
        local inZ = edge.dir == "pz" and -1.6 or edge.dir == "nz" and 1.6 or 0
        for _, along in ipairs(offsets) do
            torchIndex += 1
            local tx, tz
            if edge.axis == "z" then
                tx, tz = edge.at + inX, center + along
            else
                tx, tz = center + along, edge.at + inZ
            end
            add({
                name = "TorchBracket_" .. torchIndex,
                size = { 0.6, 3, 0.6 },
                pos = { tx, 8.8, tz },
                color = { 40, 38, 42 },
                material = "Metal",
                canCollide = false,
            })
            add({
                name = "TorchFlame_" .. torchIndex,
                shape = "Ball", -- de-blockified (2026-07-08 playtest feedback)
                size = { 2, 2, 2 },
                pos = { tx, 11, tz },
                color = { 255, 150, 50 },
                material = "Neon",
                canCollide = false,
                light = { color = { 255, 160, 70 }, brightness = 2, range = 34 },
            })
        end
    end
    for _, edge in ipairs(edges) do
        local gaps = {}
        for _, door in ipairs(tile.doors) do
            if door.dir == edge.dir then
                local center = edge.axis == "z" and door.z or door.x
                table.insert(gaps, { center - DOOR_W / 2, center + DOOR_W / 2 })
                addTorchPair(edge, center)
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
                    size = { WALL_T, wallH, len },
                    pos = { edge.at, wallH / 2, mid },
                    color = wallColor,
                })
            else
                add({
                    name = "Wall_" .. wallIndex,
                    size = { len, wallH, WALL_T },
                    pos = { mid, wallH / 2, edge.at },
                    color = wallColor,
                })
            end
        end
    end

    -- M5a: corner pillars break the empty-box silhouette in chamber-class
    -- tiles (corridors stay clear — they're only 48 wide)
    if tile.class ~= "corridor" then
        local pin = 6 -- pillar center inset from the walls
        local px2, pz2 = hx - pin, hz - pin
        local corners = { { -px2, -pz2 }, { px2, -pz2 }, { -px2, pz2 }, { px2, pz2 } }
        for i, corner in ipairs(corners) do
            add({
                name = "Pillar_" .. i,
                size = { 3, wallH, 3 },
                pos = { cx + corner[1], wallH / 2, cz + corner[2] },
                color = dim(color, 0.5),
                material = "Slate",
            })
        end
    end

    -- MEZZANINE interior: an upper U-gallery hugging the px/nx/pz walls with
    -- two walk-up ramps on the nz (entry-door) side. Deck top at y=18 clears
    -- the 16-tall doorways below it; ramps are ~25° pitched slabs (walkable
    -- by humanoid enemies AND the anchored client-driven pets, which just
    -- lerp — no pathfinding dependency). All verticality is interior: the
    -- solver still mates plain XZ doors, so zero solver changes.
    if tile.id == "mezzanine_hall" then
        local DECK_Y = 18 -- deck TOP height
        local DECK_D = 16 -- deck depth off the wall
        local inner = hx - WALL_T -- wall inner face (square tile: hz too)
        local deckCol = dim(color, 0.75)
        local railCol = dim(color, 0.45)
        -- side decks (px/nx): from the ramp landing forward to the back wall
        local landZ = -hz + 44 -- ramp tops out here (deck's nz end)
        local sideLen = (inner - landZ)
        local sideMidZ = (landZ + inner) / 2
        for i, sx in ipairs({ 1, -1 }) do
            add({
                name = "Deck_Side_" .. i,
                size = { DECK_D, 1, sideLen },
                pos = { sx * (inner - DECK_D / 2), DECK_Y - 0.5, sideMidZ },
                color = deckCol,
                material = "WoodPlanks",
            })
            -- inner-edge railing ON the deck; stops short of the back deck
            -- so the corner walk stays open, and the nz end stays open for
            -- the ramp landing
            add({
                name = "Rail_Side_" .. i,
                size = { 0.8, 3, (inner - DECK_D) - landZ },
                pos = {
                    sx * (inner - DECK_D + 0.4),
                    DECK_Y + 1.5,
                    (landZ + inner - DECK_D) / 2,
                },
                color = railCol,
                material = "Metal",
            })
            -- ramp: floor (z=-inner+4) up to the deck end (z=landZ);
            -- negative pitch lifts the +z end (verified convention)
            local rise, run = DECK_Y, (landZ - (-inner + 4))
            add({
                name = "Ramp_" .. i,
                size = { 8, 1, math.sqrt(rise * rise + run * run) + 2 },
                pos = { sx * (inner - DECK_D / 2), rise / 2 - 0.4, (landZ + (-inner + 4)) / 2 },
                pitch = -math.deg(math.atan(rise / run)),
                color = deckCol,
                material = "WoodPlanks",
            })
        end
        -- back deck (pz wall) bridges the side decks into a U
        add({
            name = "Deck_Back",
            size = { 2 * (inner - DECK_D), 1, DECK_D },
            pos = { cx, DECK_Y - 0.5, inner - DECK_D / 2 },
            color = deckCol,
            material = "WoodPlanks",
        })
        add({
            name = "Rail_Back",
            size = { 2 * (inner - DECK_D) - 1.6, 3, 0.8 },
            pos = { cx, DECK_Y + 1.5, inner - DECK_D + 0.4 },
            color = railCol,
            material = "Metal",
        })
        -- support posts ground the gallery visually
        local posts = {
            { inner - DECK_D + 0.75, -10 },
            { inner - DECK_D + 0.75, sideMidZ },
            { -(inner - DECK_D + 0.75), -10 },
            { -(inner - DECK_D + 0.75), sideMidZ },
            { 30, inner - DECK_D + 0.75 },
            { -30, inner - DECK_D + 0.75 },
        }
        for i, post in ipairs(posts) do
            local px3, pz3 = post[1], post[2]
            add({
                name = "DeckPost_" .. i,
                size = { 1.5, DECK_Y - 1, 1.5 },
                pos = { px3, (DECK_Y - 1) / 2, pz3 },
                color = railCol,
                material = "Metal",
            })
        end
        -- an UPSTAIRS pack anchor on the back gallery — the fight worth
        -- climbing for (service fields packs at every MissionSpawn part)
        add({
            name = "MissionSpawn",
            size = { 1, 1, 1 },
            pos = { 0, DECK_Y + 1, inner - DECK_D / 2 },
            transparency = 1,
            canCollide = false,
        })
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
            -- the objective room's pack point: population FORCES a boss-
            -- marked pack here (the boss guards the glowy — CoH rule)
            attrs = tile.class == "objective" and { ObjectiveRoom = true } or nil,
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
