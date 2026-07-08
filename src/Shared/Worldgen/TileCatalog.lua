--[[
    TileCatalog — pure construction + validation of a mission tile kit.

    PURE: no Roblox APIs, no Instances. The catalog is plain data describing
    tile geometry (bounds AABB + door connectors) extracted either from a
    config/test table (M1, this path) or — in M2 — from the authored kit
    Models by a Studio-side extractor that emits this same table shape.

    Contract enforced here (docs/MISSION_WORLDGEN.md §2): a kit that builds a
    catalog without erroring is a kit the solver can always close (every open
    doorway cappable, entrance + objective present, doors axis-aligned by
    construction via the dir enum).

    Kit definition shape:
    {
        kitId = "gray_box",
        doorClasses = { std = { width = 12, height = 14 } },
        tiles = {
            {
                id = "entry",
                class = "entrance",       -- entrance|room|corridor|junction|objective|cap
                weight = 1,               -- selection weight within class (default 1)
                maxPerMap = 1,            -- 0/absent = unlimited
                minDepth = nil,           -- optional graph-depth gating
                maxDepth = nil,
                bounds = { sx = 16, sz = 16, ox = 0, oz = 0 }, -- size + center offset from pivot (XZ)
                doors = {
                    -- pivot-local aperture center + outward axis + door class
                    { name = "Door_1", x = 0, z = 8, dir = "pz", class = "std" },
                },
            },
            ...
        },
    }
]]

local TileCatalog = {}

local VALID_CLASS = {
    entrance = true,
    room = true,
    corridor = true,
    junction = true,
    objective = true,
    cap = true,
}

local VALID_DIR = { px = true, nx = true, pz = true, nz = true }

local function fail(kitId, fmt, ...)
    error(("TileCatalog[%s]: %s"):format(tostring(kitId), fmt:format(...)), 0)
end

function TileCatalog.build(def)
    assert(type(def) == "table", "TileCatalog.build: kit definition table required")
    local kitId = def.kitId or "?"
    if type(def.kitId) ~= "string" or def.kitId == "" then
        fail(kitId, "kitId (string) is required")
    end
    if type(def.doorClasses) ~= "table" or next(def.doorClasses) == nil then
        fail(kitId, "doorClasses table with at least one class is required")
    end
    if type(def.tiles) ~= "table" or #def.tiles == 0 then
        fail(kitId, "tiles array is required")
    end

    local catalog = {
        kitId = def.kitId,
        doorClasses = def.doorClasses,
        tiles = {},
        byId = {},
        byClass = {
            entrance = {},
            room = {},
            corridor = {},
            junction = {},
            objective = {},
            cap = {},
        },
    }

    -- door classes referenced by any non-cap tile → each needs a cap plug
    local usedDoorClasses = {}
    -- door classes pluggable by some cap tile
    local cappedDoorClasses = {}

    for i, raw in ipairs(def.tiles) do
        if type(raw.id) ~= "string" or raw.id == "" then
            fail(kitId, "tiles[%d]: id (string) is required", i)
        end
        if catalog.byId[raw.id] then
            fail(kitId, "duplicate tile id %q", raw.id)
        end
        if not VALID_CLASS[raw.class] then
            fail(kitId, "tile %q: invalid class %q", raw.id, tostring(raw.class))
        end

        local b = raw.bounds
        if type(b) ~= "table" or type(b.sx) ~= "number" or type(b.sz) ~= "number" then
            fail(kitId, "tile %q: bounds { sx, sz } required", raw.id)
        end
        if b.sx <= 0 or b.sz <= 0 then
            fail(kitId, "tile %q: bounds must be positive (sx=%s, sz=%s)", raw.id, b.sx, b.sz)
        end

        if type(raw.doors) ~= "table" or #raw.doors == 0 then
            fail(kitId, "tile %q: at least one door is required", raw.id)
        end
        if raw.class == "cap" and #raw.doors ~= 1 then
            fail(kitId, "cap tile %q must have exactly one door (has %d)", raw.id, #raw.doors)
        end

        local doors = {}
        local doorNames = {}
        for j, d in ipairs(raw.doors) do
            local name = d.name or ("Door_" .. j)
            if doorNames[name] then
                fail(kitId, "tile %q: duplicate door name %q", raw.id, name)
            end
            doorNames[name] = true
            if type(d.x) ~= "number" or type(d.z) ~= "number" then
                fail(kitId, "tile %q door %q: x/z (numbers) required", raw.id, name)
            end
            if not VALID_DIR[d.dir] then
                fail(
                    kitId,
                    "tile %q door %q: dir must be px|nx|pz|nz (got %q)",
                    raw.id,
                    name,
                    tostring(d.dir)
                )
            end
            local doorClass = d.class or "std"
            if not def.doorClasses[doorClass] then
                fail(kitId, "tile %q door %q: unknown door class %q", raw.id, name, doorClass)
            end
            doors[j] = { name = name, x = d.x, z = d.z, dir = d.dir, class = doorClass }
            if raw.class == "cap" then
                cappedDoorClasses[doorClass] = true
            else
                usedDoorClasses[doorClass] = true
            end
        end

        local weight = raw.weight or 1
        if type(weight) ~= "number" or weight <= 0 then
            fail(kitId, "tile %q: weight must be a positive number", raw.id)
        end

        local tile = {
            id = raw.id,
            class = raw.class,
            weight = weight,
            maxPerMap = raw.maxPerMap or 0,
            minDepth = raw.minDepth,
            maxDepth = raw.maxDepth,
            bounds = {
                sx = b.sx,
                sz = b.sz,
                ox = b.ox or 0,
                oz = b.oz or 0,
                hx = b.sx / 2,
                hz = b.sz / 2,
            },
            doors = doors,
        }
        table.insert(catalog.tiles, tile)
        catalog.byId[tile.id] = tile
        table.insert(catalog.byClass[tile.class], tile)
    end

    if #catalog.byClass.entrance == 0 then
        fail(kitId, "kit needs at least one entrance tile")
    end
    if #catalog.byClass.objective == 0 then
        fail(kitId, "kit needs at least one objective tile")
    end
    for doorClass in pairs(usedDoorClasses) do
        if not cappedDoorClasses[doorClass] then
            fail(
                kitId,
                "no cap tile plugs door class %q — every open doorway must be cappable",
                doorClass
            )
        end
    end

    return catalog
end

return TileCatalog
