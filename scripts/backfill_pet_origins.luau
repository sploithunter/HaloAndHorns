--[[ backfill_pet_origins.luau — add the static `origin` field to every HATCH pet missing it,
     deriving the value from the egg SSOT (egg_sources[*].pet_weights + realm_area_eggs). Pets not in
     any egg (Creator Colorado + OG template animals) are left untouched. Idempotent.
     Run: mise exec -- lune run scripts/backfill_pet_origins.luau ]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function makeEnv(extra)
    local env = {
        table = table,
        string = string,
        math = math,
        os = os,
        coroutine = coroutine,
        utf8 = utf8,
        bit32 = bit32,
        buffer = buffer,
        tostring = tostring,
        tonumber = tonumber,
        type = type,
        typeof = type,
        pairs = pairs,
        ipairs = ipairs,
        next = next,
        select = select,
        error = error,
        assert = assert,
        setmetatable = setmetatable,
        getmetatable = getmetatable,
        rawget = rawget,
        rawset = rawset,
        print = print,
        _VERSION = _VERSION,
        Color3 = {
            new = function()
                return {}
            end,
            fromRGB = function()
                return {}
            end,
            fromHSV = function()
                return {}
            end,
        },
        UDim = {
            new = function()
                return {}
            end,
        },
        UDim2 = {
            new = function()
                return {}
            end,
            fromScale = function()
                return {}
            end,
            fromOffset = function()
                return {}
            end,
        },
        Vector2 = {
            new = function()
                return {}
            end,
        },
        Vector3 = {
            new = function()
                return {}
            end,
        },
        NumberRange = {
            new = function()
                return {}
            end,
        },
        Enum = setmetatable({}, {
            __index = function()
                return setmetatable({}, {
                    __index = function(_, m)
                        return { Name = m }
                    end,
                })
            end,
        }),
    }
    if extra then
        for k, v in extra do
            env[k] = v
        end
    end
    return env
end
local cache = {}
local loadModule
function loadModule(path)
    if cache[path] then
        return cache[path]
    end
    local dir = path:match("^(.*)/[^/]+$") or "."
    local env = makeEnv({
        loadModule = loadModule,
        script = {
            Parent = setmetatable({
                WaitForChild = function(_, n)
                    return `{dir}/{n}.lua`
                end,
                FindFirstChild = function(_, n)
                    local s = `{dir}/{n}.lua`
                    return fs.isFile(s) and s or nil
                end,
            }, {
                __index = function(_, n)
                    return `{dir}/{n}.lua`
                end,
            }),
        },
        require = function(t)
            return loadModule(t)
        end,
    })
    local export = luau.load(fs.readFile(path), { debugName = path, environment = env })()
    cache[path] = export
    return export
end

local cfg = loadModule("configs/pets.lua")
local pets, eggs, rae = cfg.pets or {}, cfg.egg_sources or {}, cfg.realm_area_eggs or {}
-- Normalize every realm_area_eggs area key (incl. base earth/ember/sand + heaven/hell egg-named
-- aliases) to the canonical origin vocabulary (grass/lava/ice/desert).
local AREA_ALIAS = {
    grass = "grass",
    earth = "grass",
    bloom = "grass",
    blight = "grass",
    lava = "lava",
    ember = "lava",
    fire = "lava",
    solar = "lava",
    infernal = "lava",
    ice = "ice",
    aurora = "ice",
    black_ice = "ice",
    desert = "desert",
    sand = "desert",
    gilded = "desert",
    guilded = "desert",
    ash = "desert",
}

local eggToArea = {}
for _, areas in pairs(rae) do
    for areaKey, eggName in pairs(areas) do
        local canon = AREA_ALIAS[areaKey]
        if canon then
            eggToArea[eggName] = canon
        end
    end
end
local petToArea = {}
for eggName, egg in pairs(eggs) do
    if type(egg) == "table" and type(egg.pet_weights) == "table" then
        local area = eggToArea[eggName]
        if area then
            for petKey in pairs(egg.pet_weights) do
                petToArea[petKey] = area
            end
        end
    end
end

-- which pets need the field added (in an egg, currently no static origin)
local toAdd = {}
for key, area in pairs(petToArea) do
    local pet = pets[key]
    if type(pet) == "table" and pet.origin == nil then
        toAdd[key] = area
    end
end

-- text insert: after each `        <key> = {` line, add `            origin = "<area>",`
local src = fs.readFile("configs/pets.lua")
local out, inserted = {}, {}
for line in (src .. "\n"):gmatch("([^\n]*)\n") do
    out[#out + 1] = line
    local key = line:match("^        ([%w_]+) = {%s*$")
    if key and toAdd[key] and not inserted[key] then
        out[#out + 1] =
            `            origin = "{toAdd[key]}", -- backfilled from egg SSOT (egg_sources.pet_weights + realm_area_eggs)`
        inserted[key] = true
    end
end

local count = 0
for _ in pairs(inserted) do
    count += 1
end
fs.writeFile("configs/pets.lua", table.concat(out, "\n"))

local missed = {}
for key in pairs(toAdd) do
    if not inserted[key] then
        missed[#missed + 1] = key
    end
end
print(`Backfilled origin on {count} hatch pets.`)
if #missed > 0 then
    print(`WARNING — could not locate block for: {table.concat(missed, ", ")}`)
end
