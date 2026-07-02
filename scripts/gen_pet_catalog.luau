--[[
    gen_pet_catalog.luau — emit a structured catalog of pets by AREA (realm -> sub-area -> pets),
    each pet linked to its source art on disk (assets/source/pets/<key>_<variant>.*) and its Roblox
    asset ids. Executes configs/pets.lua headless (Roblox datatype shims) so the parse is exact.

    Run:  mise exec -- lune run scripts/gen_pet_catalog.luau
    Out:  docs/PET_CATALOG_BY_AREA.json  +  docs/PET_CATALOG_BY_AREA.md
]]

local fs = require("@lune/fs")
local serde = require("@lune/serde")
local luau = require("@lune/luau")

-- ---- headless env (Roblox datatype shims) so the config table can construct ----
local function makeEnv(extra)
    local env
    env = {
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
        rawequal = rawequal,
        print = print,
        _VERSION = _VERSION,
        Color3 = {
            new = function(r, g, b)
                return { __kind = "Color3", r = r or 0, g = g or 0, b = b or 0 }
            end,
            fromRGB = function(r, g, b)
                return {
                    __kind = "Color3",
                    r = (r or 0) / 255,
                    g = (g or 0) / 255,
                    b = (b or 0) / 255,
                }
            end,
            fromHSV = function(h, s, v)
                return { __kind = "Color3", h = h or 0, s = s or 0, v = v or 0 }
            end,
        },
        UDim = {
            new = function(s, o)
                return { __kind = "UDim", scale = s or 0, offset = o or 0 }
            end,
        },
        UDim2 = {
            new = function(...)
                return { __kind = "UDim2" }
            end,
            fromScale = function(x, y)
                return { __kind = "UDim2", x = x or 0, y = y or 0 }
            end,
            fromOffset = function(x, y)
                return { __kind = "UDim2", x = x or 0, y = y or 0 }
            end,
        },
        Vector2 = {
            new = function(x, y)
                return { __kind = "Vector2", x = x or 0, y = y or 0 }
            end,
        },
        Vector3 = {
            new = function(x, y, z)
                return { __kind = "Vector3", x = x or 0, y = y or 0, z = z or 0 }
            end,
        },
        NumberRange = {
            new = function(a, b)
                return { __kind = "NumberRange", Min = a or 0, Max = b or a or 0 }
            end,
        },
        Enum = setmetatable({}, {
            __index = function()
                return setmetatable({}, {
                    __index = function(_, member)
                        return { __kind = "EnumItem", Name = member }
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
    local source = fs.readFile(path)
    local dir = path:match("^(.*)/[^/]+$") or "."
    local env = makeEnv({
        loadModule = loadModule,
        script = {
            Parent = setmetatable({
                WaitForChild = function(_, name)
                    return `{dir}/{name}.lua`
                end,
                FindFirstChild = function(_, name)
                    local s = `{dir}/{name}.lua`
                    return fs.isFile(s) and s or nil
                end,
            }, {
                __index = function(_, name)
                    return `{dir}/{name}.lua`
                end,
            }),
        },
        require = function(target)
            if type(target) == "string" then
                return loadModule(target)
            end
            error("headless require only supports string paths", 2)
        end,
    })
    local chunk = luau.load(source, { debugName = path, environment = env })
    local export = chunk()
    cache[path] = export
    return export
end

-- ---- load the pet config ----
local cfg = loadModule("configs/pets.lua")
local pets = cfg.pets or {}

-- ---- egg SSOT: pet -> {realm, area} via egg_sources.pet_weights + realm_area_eggs ----
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
local eggToRealmArea = {}
for realm, areas in pairs(cfg.realm_area_eggs or {}) do
    for areaKey, eggName in pairs(areas) do
        local canon = AREA_ALIAS[areaKey]
        if canon then
            eggToRealmArea[eggName] = { realm = realm, area = canon }
        end
    end
end
local petRealmArea = {}
for eggName, egg in pairs(cfg.egg_sources or {}) do
    if type(egg) == "table" and type(egg.pet_weights) == "table" then
        local ra = eggToRealmArea[eggName]
        if ra then
            for petKey in pairs(egg.pet_weights) do
                petRealmArea[petKey] = ra
            end
        end
    end
end

-- ---- on-disk art lookup: assets/source/pets/<key>_<suffix>.<ext>; exports/pets/<key>_<suffix>/ ----
local SOURCE_DIR = "assets/source/pets"
local EXPORT_DIR = "assets/exports/pets"
local SUFFIXES = { "basic", "gold" } -- config "golden" maps to file suffix "gold"; rainbow reuses art
local EXTS = { "obj", "mtl", "png", "glb", "fbx" }

local function diskAssets(key)
    local out = {}
    for _, suffix in ipairs(SUFFIXES) do
        local files = {}
        for _, ext in ipairs(EXTS) do
            local p = `{SOURCE_DIR}/{key}_{suffix}.{ext}`
            if fs.isFile(p) then
                files[#files + 1] = p
            end
        end
        local exportDir = `{EXPORT_DIR}/{key}_{suffix}`
        local hasExport = fs.isDir(exportDir)
        if #files > 0 or hasExport then
            out[suffix] = { source_files = files, export_dir = hasExport and exportDir or nil }
        end
    end
    return out
end

local function robloxIds(pet)
    local out = {}
    for variant, vdata in pairs(pet.variants or {}) do
        if type(vdata) == "table" then
            out[variant] = {
                mesh_asset = vdata.mesh_asset,
                texture_asset = vdata.texture_asset,
                asset_id = vdata.asset_id,
            }
        end
    end
    return out
end

-- ---- build the structure: realm -> sub-area (origin) -> [pets]; non-realm -> other[category] ----
local realms = {}
local other = {}
local counts = { realm = 0, other = 0 }

local sortedKeys = {}
for key in pairs(pets) do
    sortedKeys[#sortedKeys + 1] = key
end
table.sort(sortedKeys)

for _, key in ipairs(sortedKeys) do
    local pet = pets[key]
    if type(pet) ~= "table" then
        continue
    end
    local disk = diskAssets(key)
    local entry = {
        key = key,
        display_name = pet.display_name,
        rarity = pet.rarity,
        base_power = pet.base_power,
        base_health = pet.base_health,
        variants = (function()
            local vs = {}
            for v in pairs(pet.variants or {}) do
                vs[#vs + 1] = v
            end
            table.sort(vs)
            return vs
        end)(),
        roblox_assets = robloxIds(pet),
        repo_assets = disk,
        has_repo_art = next(disk) ~= nil,
    }
    -- Prefer the egg SSOT (pet -> realm+area via egg_sources.pet_weights + realm_area_eggs); fall
    -- back to the static realm/origin fields. Pets in no area-mapped egg (Creator) -> other.
    local ra = petRealmArea[key]
    local realm = (ra and ra.realm) or pet.realm
    local areaKey = (ra and ra.area) or pet.origin
    if realm and areaKey then
        realms[realm] = realms[realm] or {}
        local area = realms[realm][areaKey] or {}
        area[#area + 1] = entry
        realms[realm][areaKey] = area
        counts.realm += 1
    else
        local bucket = pet.category or "uncategorized"
        other[bucket] = other[bucket] or {}
        other[bucket][#other[bucket] + 1] = entry
        counts.other += 1
    end
end

local catalog = {
    generated_from = "configs/pets.lua",
    note = "Pets grouped by realm -> sub-area (origin). repo_assets = source art on disk "
        .. "(assets/source/pets, gitignored); roblox_assets = uploaded asset ids. 'golden' variant "
        .. "art uses the '_gold' file suffix; 'rainbow' reuses basic/gold art.",
    totals = { realm_pets = counts.realm, other_pets = counts.other },
    realms = realms,
    other = other,
}

fs.writeFile("docs/PET_CATALOG_BY_AREA.json", serde.encode("json", catalog, true))

-- ---- readable markdown companion ----
local md = {}
local function line(s)
    md[#md + 1] = s
end
line("# Pet Catalog by Area")
line("")
line(
    `_Generated from configs/pets.lua — {counts.realm} realm pets + {counts.other} other. repo art under assets/source/pets/ (gitignored)._`
)
line("")
local realmOrder = { "base", "heaven", "hell" }
local areaOrder = { "grass", "lava", "ice", "desert", "(unassigned)" }
for _, realm in ipairs(realmOrder) do
    if realms[realm] then
        line(`## {realm:gsub("^%l", string.upper)}`)
        line("")
        for _, area in ipairs(areaOrder) do
            local list = realms[realm][area]
            if list then
                table.sort(list, function(a, b)
                    return tostring(a.key) < tostring(b.key)
                end)
                line(`### {area} ({#list})`)
                line("")
                line("| Pet | Rarity | Repo art (basic) | Roblox mesh (basic) |")
                line("| --- | --- | --- | --- |")
                for _, p in ipairs(list) do
                    local basic = p.repo_assets.basic
                    local art = (basic and basic.source_files[1]) or "—"
                    local mesh = (p.roblox_assets.basic and p.roblox_assets.basic.mesh_asset)
                        or (p.roblox_assets.basic and p.roblox_assets.basic.asset_id)
                        or "—"
                    line(
                        `| {p.display_name or p.key} (\`{p.key}\`) | {p.rarity or "—"} | {art} | {mesh} |`
                    )
                end
                line("")
            end
        end
    end
end
if next(other) then
    line("## Other (no realm/area)")
    line("")
    local obkeys = {}
    for k in pairs(other) do
        obkeys[#obkeys + 1] = k
    end
    table.sort(obkeys)
    for _, cat in ipairs(obkeys) do
        line(`### {cat} ({#other[cat]})`)
        for _, p in ipairs(other[cat]) do
            line(
                `- {p.display_name or p.key} (\`{p.key}\`){p.has_repo_art and "" or " — no repo art"}`
            )
        end
        line("")
    end
end
fs.writeFile("docs/PET_CATALOG_BY_AREA.md", table.concat(md, "\n"))

print(
    `Wrote docs/PET_CATALOG_BY_AREA.json + .md — {counts.realm} realm pets, {counts.other} other`
)
