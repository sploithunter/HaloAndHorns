--[[ analyze_pet_origins.luau — derive each pet's area from the egg SSOT (egg.pet_weights +
     realm_area_eggs) and compare to the static `origin` field. Read-only: prints missing + mismatched.
     Run: mise exec -- lune run scripts/analyze_pet_origins.luau ]]

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
local pets = cfg.pets or {}
local eggs = cfg.egg_sources or cfg.eggs or {}
local rae = cfg.realm_area_eggs or {}

-- canonical area vocabulary (matches the static origin field)
local CANON = { grass = true, lava = true, ice = true, desert = true }

-- egg -> { realm, area } : for each realm, find the canonical area key that maps to the egg
local eggToArea = {}
for realm, areas in pairs(rae) do
    for areaKey, eggName in pairs(areas) do
        if CANON[areaKey] then
            eggToArea[eggName] = { realm = realm, area = areaKey }
        end
    end
end

-- pet -> egg (via pet_weights membership)
local petToEgg = {}
for eggName, egg in pairs(eggs) do
    if type(egg) == "table" and type(egg.pet_weights) == "table" then
        for petKey in pairs(egg.pet_weights) do
            petToEgg[petKey] = eggName
        end
    end
end

local missing, mismatch, ok, noEgg = {}, {}, 0, {}
local keys = {}
for k in pairs(pets) do
    keys[#keys + 1] = k
end
table.sort(keys)
for _, k in ipairs(keys) do
    local pet = pets[k]
    if type(pet) ~= "table" then
        continue
    end
    local egg = petToEgg[k]
    local derived = egg and eggToArea[egg]
    local staticOrigin = pet.origin
    if not derived then
        -- pet not in any egg's pet_weights (Creator/template/non-hatch); only flag if it also lacks origin
        if not staticOrigin then
            noEgg[#noEgg + 1] =
                `{k} (realm={tostring(pet.realm)}, category={tostring(pet.category)})`
        end
    elseif not staticOrigin then
        missing[#missing + 1] =
            `{k}  ->  origin="{derived.area}"  (egg={egg}, realm={derived.realm})`
    elseif staticOrigin ~= derived.area then
        mismatch[#mismatch + 1] =
            `{k}  static="{staticOrigin}" but egg-derived="{derived.area}" (egg={egg})`
    else
        ok += 1
    end
end

print(`\n=== MATCH (static origin == egg-derived): {ok} ===`)
print(`\n=== MISSING origin (in an egg, no static field): {#missing} ===`)
for _, l in ipairs(missing) do
    print("  " .. l)
end
print(`\n=== MISMATCH (static != egg-derived): {#mismatch} ===`)
for _, l in ipairs(mismatch) do
    print("  " .. l)
end
print(`\n=== NOT IN ANY EGG and no origin (Creator/template/non-hatch): {#noEgg} ===`)
for _, l in ipairs(noEgg) do
    print("  " .. l)
end
