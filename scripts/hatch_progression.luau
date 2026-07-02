--!nocheck
--[[
    Hatch-progression simulator (lune — no Studio, no Roblox).

    Runs the REAL configs/pets.lua simulateHatch (loaded fresh from disk) through
    full player journeys so luck/index/variant knobs can be balanced empirically:

      1. Variant-rate spot checks at a fixed state (bunnies on/off).
      2. The index-completion JOURNEY: hatch eggs round-robin across the world
         eggs with the luck multiplier RECOMPUTED from live index completion
         every hatch (the real feedback loop: luck -> rarer species -> faster
         completion -> more luck). Gate checks out to 50k eggs, with wall-clock
         hours derived from HatchTiming at max-batch auto-hatching.
      3. An index_luck.curve_exponent sweep, so "which curve do we want" is a
         table you read, not a guess.

    Run:  mise exec -- lune run scripts/hatch_progression.luau
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")

-- ---- minimal pure-module loader (same approach as tests/headless/run.luau) ----
local moduleCache = {}
local loadModule
local function makeEnv(extra)
    local env = {
        assert = assert,
        error = error,
        ipairs = ipairs,
        next = next,
        pairs = pairs,
        pcall = pcall,
        print = print,
        warn = warn,
        select = select,
        tonumber = tonumber,
        tostring = tostring,
        type = type,
        typeof = typeof,
        table = table,
        string = string,
        math = math,
        os = os,
        setmetatable = setmetatable,
        getmetatable = getmetatable,
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
        Vector3 = {
            new = function(x, y, z)
                return { x = x, y = y, z = z }
            end,
        },
        Vector2 = {
            new = function(x, y)
                return { x = x, y = y }
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
        NumberRange = {
            new = function(min, max)
                return { Min = min, Max = max or min }
            end,
        },
        Enum = setmetatable({}, {
            __index = function()
                return setmetatable({}, {
                    __index = function()
                        return {}
                    end,
                })
            end,
        }),
    }
    for k, v in extra or {} do
        env[k] = v
    end
    return env
end
function loadModule(path)
    if moduleCache[path] ~= nil then
        return moduleCache[path]
    end
    local source = fs.readFile(path)
    local dir = path:match("^(.*)/[^/]+$") or "."
    local env = makeEnv({
        require = function(target)
            if type(target) == "string" then
                return loadModule(target)
            end
            error("non-pure require in " .. path)
        end,
        script = {
            Parent = setmetatable({}, {
                __index = function(_, name)
                    return `{dir}/{name}.lua`
                end,
            }),
        },
    })
    local export = luau.load(source, { debugName = path, environment = env })()
    moduleCache[path] = export
    return export
end

local pets = loadModule("configs/pets.lua")
local hatchCfg = loadModule("configs/egg_hatching.lua")
local eggSystem = loadModule("configs/egg_system.lua")
local HatchTiming = loadModule("src/Shared/Game/HatchTiming.lua")

-- ---- world-egg pool + obtainable index denominator (huges census-gated -> excluded) ----
local VARIANTS = { "basic", "golden", "rainbow" }
local eggs = {}
for eggId, egg in pairs(pets.egg_sources or {}) do
    if egg.world_placeable or eggId == "basic_egg" then
        table.insert(eggs, eggId)
    end
end
table.sort(eggs)
local obtainableTotal = 0
do
    local seen = {}
    for _, eggId in eggs do
        for petId in pairs(pets.egg_sources[eggId].pet_weights or {}) do
            for _, v in VARIANTS do
                local key = petId .. ":" .. v
                if not seen[key] then
                    seen[key] = true
                    obtainableTotal += 1
                end
            end
        end
    end
end

-- ---- hatch cadence: batch wall-clock at max auto-hatch ----
local BATCH = 8
local timing = HatchTiming.resolve(hatchCfg, { fastHatch = false })
local batchSeconds = HatchTiming.expectedSeconds(BATCH, timing)
local cooldownFloor = (eggSystem.cooldowns and eggSystem.cooldowns.purchase_cooldown) or 0
batchSeconds = math.max(batchSeconds, cooldownFloor)
local eggsPerHour = BATCH * 3600 / batchSeconds

local function hours(eggCount)
    return eggCount / eggsPerHour
end

-- ---- sim helpers ----
local function rateSim(eggId, playerData, trials)
    local g, r, hugeN = 0, 0, 0
    local lastLuck = 0
    for _ = 1, trials do
        local res = pets.simulateHatch(eggId, table.clone(playerData))
        if res then
            lastLuck = res.luckMultiplier or 0
            if res.huge then
                hugeN += 1
            end
            if res.variant == "golden" then
                g += 1
            elseif res.variant == "rainbow" then
                r += 1
            end
        end
    end
    return { golden = g / trials, rainbow = r / trials, huge = hugeN, luck = lastLuck }
end

-- Full journey: round-robin world eggs, luck recomputed from LIVE completion each
-- hatch (playerData.indexCompletion feeds the real index_luck fold in simulateHatch).
local function journey(level, luckBoost, maxEggs, gates, exponentOverride)
    local saved = pets.gamepass_modifiers.index_luck.curve_exponent
    if exponentOverride then
        pets.gamepass_modifiers.index_luck.curve_exponent = exponentOverride
    end
    local discovered, found = {}, 0
    local out = {}
    local gi = 1
    local goldenWindow, windowN = 0, 0
    for n = 1, maxEggs do
        local eggId = eggs[(n % #eggs) + 1]
        local res = pets.simulateHatch(eggId, {
            level = level,
            indexCompletion = found / obtainableTotal,
            luckBoost = luckBoost > 0 and luckBoost or nil,
        })
        if res and res.pet and not res.huge then
            local key = res.pet .. ":" .. (res.variant or "basic")
            if not discovered[key] then
                discovered[key] = true
                found += 1
            end
            if res.variant == "golden" then
                goldenWindow += 1
            end
            windowN += 1
        end
        if gates[gi] and n == gates[gi] then
            table.insert(out, {
                eggsHatched = n,
                completion = found / obtainableTotal,
                luck = 1
                    + (pets.gamepass_modifiers.level_luck.per_doubling or 0) * math.log(
                        1 + level / pets.gamepass_modifiers.level_luck.first_bonus_at,
                        2
                    )
                    + pets.gamepass_modifiers.index_luck.max_bonus * (found / obtainableTotal) ^ pets.gamepass_modifiers.index_luck.curve_exponent
                    + luckBoost,
                goldenRate = windowN > 0 and goldenWindow / windowN or 0,
                hours = hours(n),
            })
            goldenWindow, windowN = 0, 0 -- per-gate window, so rates show the drift
            gi += 1
        end
    end
    pets.gamepass_modifiers.index_luck.curve_exponent = saved
    return out
end

-- ---- report ----
local mods = pets.gamepass_modifiers
print(
    string.format(
        "cadence: %d-egg batch = %.2fs (preset %s, cooldown floor %ds) -> %d eggs/hour",
        BATCH,
        batchSeconds,
        tostring(hatchCfg.current_preset),
        cooldownFloor,
        eggsPerHour
    )
)
print(
    string.format(
        "knobs: level_luck %.2f/doubling, index max_bonus %.1f, exponent %.1f, variant weight %.2f",
        mods.level_luck.per_doubling,
        mods.index_luck.max_bonus,
        mods.index_luck.curve_exponent,
        mods.variant_luck_weight
    )
)
print(string.format("obtainable index: %d entries across %d eggs\n", obtainableTotal, #eggs))

-- 1) variant-rate spot checks (ice egg), bunnies off/on
local TRIALS = 20000
for _, state in
    {
        { label = "L7 idx 20%, no bunnies", level = 7, idx = 0.2, boost = 0 },
        { label = "L7 idx 20%, 3 rainbow bunnies", level = 7, idx = 0.2, boost = 0.75 },
        { label = "L7 idx 60%, no bunnies", level = 7, idx = 0.6, boost = 0 },
        { label = "L7 idx 60%, 3 rainbow bunnies", level = 7, idx = 0.6, boost = 0.75 },
        { label = "L7 idx 90%, 3 rainbow bunnies", level = 7, idx = 0.9, boost = 0.75 },
        { label = "L7 idx 90%, 10 rainbow bunnies", level = 7, idx = 0.9, boost = 2.5 },
        -- paid luck: species-only additive — golden/rainbow must match the row above
        {
            label = "L7 idx 90%, 10 bunnies + luck pass",
            level = 7,
            idx = 0.9,
            boost = 2.5,
            pass = true,
        },
    }
do
    local r = rateSim("ice_egg", {
        level = state.level,
        indexCompletion = state.idx,
        luckBoost = state.boost > 0 and state.boost or nil,
        hasLuckGamepass = state.pass or nil,
    }, TRIALS)
    print(
        string.format(
            "rates  %-34s luck %.2fx  golden %5.2f%%  rainbow %4.2f%%",
            state.label,
            r.luck,
            r.golden * 100,
            r.rainbow * 100
        )
    )
end

-- 2) journey gates + 3) exponent sweep
local GATES = { 100, 500, 1000, 2500, 5000, 10000, 15000, 20000, 25000, 35000, 50000 }
for _, sweep in
    {
        { label = "exponent 2.5 (SHIPPED), L7, no bunnies", level = 7, boost = 0, exp = 2.5 },
        { label = "exponent 2.5, L7, 3 rainbow bunnies", level = 7, boost = 0.75, exp = 2.5 },
        { label = "exponent 1.0 (old linear), L7, no bunnies", level = 7, boost = 0, exp = 1.0 },
        { label = "exponent 3.5 (harsher), L7, no bunnies", level = 7, boost = 0, exp = 3.5 },
    }
do
    print(string.format("\njourney: %s", sweep.label))
    print("  eggs     hours   index%   luck    golden% (window)")
    for _, row in journey(sweep.level, sweep.boost, GATES[#GATES], GATES, sweep.exp) do
        print(
            string.format(
                "  %6d  %6.1fh   %5.1f%%  %.2fx   %5.2f%%",
                row.eggsHatched,
                row.hours,
                row.completion * 100,
                row.luck,
                row.goldenRate * 100
            )
        )
    end
end
