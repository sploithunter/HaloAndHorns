--[[
    ChallengeRun — Range / Training Ground gauntlet math (pure).

    Room 1–99 is a difficulty index, not a tile count. packForRoom is
    deterministic so the same curve + room always fields the same fight.
    layoutContext(room, mode) is the worldgen contextKey: Range Room N is
    `room#N`, Training Ground is `train#N` so the maps differ. Catalog
    runs exclusive-allow the picked powers and
    auto-slot them (Hasten = 6 recharge; others = 3 recharge + 3 focus).
    Persist helpers never invent ProfileStore template fields; callers
    write GameData.ChallengeRuns / GameData.RangeDefaults only when a
    run or Range kit exists.
]]

local ChallengeRun = {}

local function clampRoom(n, rooms)
    local maxRoom = math.max(1, math.floor(tonumber(rooms) or 99))
    local room = math.floor(tonumber(n) or 1)
    if room < 1 then
        room = 1
    elseif room > maxRoom then
        room = maxRoom
    end
    return room, maxRoom
end

local function num(value, fallback)
    local n = tonumber(value)
    if n == nil then
        return fallback
    end
    return n
end

local DEFAULT_SLOTS = { "recharge", "recharge", "recharge", "focus", "focus", "focus" }
local HASTEN_SLOTS = { "recharge", "recharge", "recharge", "recharge", "recharge", "recharge" }

function ChallengeRun.allowsPower(allowlist, powerId)
    if type(allowlist) ~= "table" then
        return true
    end
    local want = tostring(powerId)
    for _, id in ipairs(allowlist) do
        if tostring(id) == want then
            return true
        end
    end
    return false
end

function ChallengeRun.defaultSlots(powerId, slotting, origin)
    slotting = type(slotting) == "table" and slotting or {}
    local recipes = type(slotting.recipes) == "table" and slotting.recipes or {}
    local recipe = recipes[tostring(powerId)]
    if type(recipe) ~= "table" or #recipe == 0 then
        if tostring(powerId) == "hasten" then
            recipe = HASTEN_SLOTS
        else
            recipe = type(slotting.default) == "table" and slotting.default or DEFAULT_SLOTS
        end
    end
    local origins = {}
    local originId = type(origin) == "string" and origin or slotting.origin
    if type(originId) == "string" and originId ~= "" then
        origins[1] = originId
    end
    local maxSlots = math.max(1, math.floor(num(slotting.max_slots, 6)))
    local slots = {}
    for i = 1, math.min(#recipe, maxSlots) do
        local typ = recipe[i]
        if type(typ) == "string" and typ ~= "" then
            local copy = {}
            for _, o in ipairs(origins) do
                copy[#copy + 1] = o
            end
            slots[#slots + 1] = { enh = { type = typ, origins = copy } }
        end
    end
    return slots
end

function ChallengeRun.layoutContext(room, mode)
    local n = math.max(1, math.floor(tonumber(room) or 1))
    if mode == "training_ground" then
        return "train#" .. n
    end
    return "room#" .. n
end

function ChallengeRun.beatForRoom(curve, room)
    curve = type(curve) == "table" and curve or {}
    local beats = curve.beats
    if type(beats) ~= "table" then
        return nil
    end
    for _, beat in ipairs(beats) do
        if type(beat) == "table" and room <= num(beat.upto, 99) then
            return beat
        end
    end
    local last = beats[#beats]
    if type(last) == "table" then
        return last
    end
    return nil
end

function ChallengeRun.solverOverrides(pack)
    pack = type(pack) == "table" and pack or {}
    local out = {}
    if pack.tile_budget ~= nil then
        out.tile_budget = math.max(1, math.floor(num(pack.tile_budget, 2)))
    end
    if type(pack.target_depth) == "table" then
        out.target_depth = pack.target_depth
    end
    return out
end

function ChallengeRun.packForRoom(curve, n)
    curve = type(curve) == "table" and curve or {}
    local rooms = num(curve.rooms, 99)
    local room = clampRoom(n, rooms)
    local hpGrowth = num(curve.hp_growth, 1.07)
    local dmgGrowth = num(curve.dmg_growth, 1.045)
    local countEvery = math.max(1, math.floor(num(curve.count_every, 6)))
    local countCap = math.max(1, math.floor(num(curve.count_cap, 8)))
    local step = room - 1
    local beat = ChallengeRun.beatForRoom(curve, room)
    local countMult = math.min(countCap, 1 + math.floor(step / countEvery))
    local addLieutenant = room >= (num(curve.lieutenant_at, 10))
    local addBoss = room >= (num(curve.boss_at, 25))
    local extraLieutenants = 0
    local introOnly = false
    local tileBudget
    local targetDepth
    if beat then
        if beat.count_mult ~= nil then
            countMult = math.max(1, math.floor(num(beat.count_mult, 1)))
        end
        if beat.add_lieutenant ~= nil then
            addLieutenant = beat.add_lieutenant == true
        end
        if beat.add_boss ~= nil then
            addBoss = beat.add_boss == true
        end
        extraLieutenants = math.max(0, math.floor(num(beat.extra_lieutenants, 0)))
        introOnly = beat.intro_only == true
        if beat.tile_budget ~= nil then
            tileBudget = math.max(1, math.floor(num(beat.tile_budget, 2)))
        end
        if type(beat.target_depth) == "table" then
            targetDepth = beat.target_depth
        end
    end
    if extraLieutenants > 0 then
        addLieutenant = true
    end
    return {
        room = room,
        rooms = rooms,
        hp_mult = hpGrowth ^ step,
        dmg_mult = dmgGrowth ^ step,
        count_mult = countMult,
        add_lieutenant = addLieutenant,
        add_boss = addBoss,
        extra_lieutenants = extraLieutenants,
        intro_only = introOnly,
        tile_budget = tileBudget,
        target_depth = targetDepth,
    }
end

-- Fair ranking: intro packs only while teaching; lieutenant/boss packs
-- wait for the curve. Magma Wyrm must not appear in Room 1.
function ChallengeRun.filterPacks(packs, curve)
    curve = type(curve) == "table" and curve or {}
    local introOnly = curve.intro_only == true
    local extraNeed = math.max(0, math.floor(num(curve.extra_lieutenants, 0)))
    local out = {}
    local fallback
    for _, pack in ipairs(type(packs) == "table" and packs or {}) do
        if type(pack) == "table" then
            if not pack.boss and not pack.lieutenant and not pack.intro and not fallback then
                fallback = pack
            end
            if pack.intro then
                if introOnly then
                    out[#out + 1] = pack
                end
            elseif introOnly then
                -- teaching rooms keep only the intro pack
            elseif pack.boss and curve.add_boss ~= true then
                -- later rooms only
            elseif pack.lieutenant then
                local extra = math.max(0, math.floor(num(pack.extra, 0)))
                if curve.add_lieutenant == true and extra == extraNeed then
                    out[#out + 1] = pack
                end
            else
                out[#out + 1] = pack
            end
        end
    end
    if introOnly and #out == 0 and fallback then
        out[1] = fallback
    end
    return out
end

function ChallengeRun.bestRoom(previous, cleared)
    local prev = math.max(0, math.floor(num(previous, 0)))
    local room = math.max(0, math.floor(num(cleared, 0)))
    if room > prev then
        return room
    end
    return prev
end

local DEFAULT_WINDOW_SECONDS = 48 * 60 * 60
local DEFAULT_RECENT_CAP = 48
local DEFAULT_SWEEP_SECONDS = 5 * 60

function ChallengeRun.leaderboardWindow(cfg)
    local lb = type(cfg) == "table" and cfg.leaderboard or {}
    local window = math.floor(num(lb.window_seconds, DEFAULT_WINDOW_SECONDS))
    if window < 1 then
        window = DEFAULT_WINDOW_SECONDS
    end
    local cap = math.floor(num(lb.recent_cap, DEFAULT_RECENT_CAP))
    if cap < 1 then
        cap = DEFAULT_RECENT_CAP
    end
    local sweep = math.floor(num(lb.sweep_seconds, DEFAULT_SWEEP_SECONDS))
    if sweep < 1 then
        sweep = DEFAULT_SWEEP_SECONDS
    end
    return window, cap, sweep
end

function ChallengeRun.recentChanged(before, after)
    before = type(before) == "table" and before or {}
    after = type(after) == "table" and after or {}
    if #before ~= #after then
        return true
    end
    for index = 1, #before do
        local a, b = before[index], after[index]
        if
            math.floor(num(a and a.room, 0)) ~= math.floor(num(b and b.room, 0))
            or math.floor(num(a and a.at, 0)) ~= math.floor(num(b and b.at, 0))
        then
            return true
        end
    end
    return false
end

function ChallengeRun.windowBest(recent, now, windowSeconds)
    now = math.floor(num(now, 0))
    windowSeconds = math.max(1, math.floor(num(windowSeconds, DEFAULT_WINDOW_SECONDS)))
    local cutoff = now - windowSeconds
    local best = 0
    for _, entry in ipairs(type(recent) == "table" and recent or {}) do
        if type(entry) == "table" then
            local room = math.max(0, math.floor(num(entry.room, 0)))
            local at = math.floor(num(entry.at, 0))
            if room > best and at > cutoff then
                best = room
            end
        end
    end
    return best
end

-- Keep only in-window attempts that can still be the unique max after a
-- better older run expires. Cap drops the lowest rooms, never the current max.
function ChallengeRun.pruneWindow(recent, now, windowSeconds, cap)
    windowSeconds = math.max(1, math.floor(num(windowSeconds, DEFAULT_WINDOW_SECONDS)))
    cap = math.max(1, math.floor(num(cap, DEFAULT_RECENT_CAP)))
    now = math.floor(num(now, 0))
    local cutoff = now - windowSeconds
    local alive = {}
    for _, entry in ipairs(type(recent) == "table" and recent or {}) do
        if type(entry) == "table" then
            local room = math.max(0, math.floor(num(entry.room, 0)))
            local at = math.floor(num(entry.at, 0))
            if room > 0 and at > cutoff then
                alive[#alive + 1] = { room = room, at = at }
            end
        end
    end
    table.sort(alive, function(a, b)
        if a.at == b.at then
            return a.room > b.room
        end
        return a.at < b.at
    end)
    local kept = {}
    local maxNewer = 0
    for index = #alive, 1, -1 do
        local entry = alive[index]
        if entry.room > maxNewer then
            table.insert(kept, 1, entry)
            maxNewer = entry.room
        end
    end
    if #kept > cap then
        table.sort(kept, function(a, b)
            if a.room == b.room then
                return a.at > b.at
            end
            return a.room > b.room
        end)
        while #kept > cap do
            table.remove(kept)
        end
        table.sort(kept, function(a, b)
            return a.at < b.at
        end)
    end
    return kept
end

function ChallengeRun.writeWindowAttempt(previous, cleared, now, opts)
    previous = type(previous) == "table" and previous or {}
    opts = type(opts) == "table" and opts or {}
    now = math.floor(num(now, 0))
    local room = math.max(0, math.floor(num(cleared, 0)))
    local recent = {}
    for _, entry in ipairs(type(previous.recent) == "table" and previous.recent or {}) do
        recent[#recent + 1] = entry
    end
    if room > 0 and now > 0 then
        recent[#recent + 1] = { room = room, at = now }
    end
    local nextRec = {}
    for key, value in pairs(previous) do
        nextRec[key] = value
    end
    nextRec.best_room = ChallengeRun.bestRoom(previous.best_room, room)
    nextRec.recent = ChallengeRun.pruneWindow(recent, now, opts.window_seconds, opts.recent_cap)
    return nextRec
end

function ChallengeRun.squadWiped(pets)
    if type(pets) ~= "table" or #pets == 0 then
        return false
    end
    for _, pet in ipairs(pets) do
        if type(pet) == "table" and pet.downed ~= true then
            return false
        end
    end
    return true
end

function ChallengeRun.canRevive(flags)
    if type(flags) ~= "table" then
        return true
    end
    return flags.no_pet_revives ~= true
end

-- Same flag: no Ready/Summon after a down. Roster swap is a separate check
-- (`gauntletRosterLocked`) so the entry tile can still kit-up.
function ChallengeRun.canResummon(flags)
    return ChallengeRun.canRevive(flags)
end

-- Slot-local map rooms + world origin (`ox`/`oz` from MissionMapData).
-- Missing layout or missing position treats as entry so first-spawn kit-up works.
function ChallengeRun.inEntryRoom(mapTable, worldX, worldZ)
    if type(mapTable) ~= "table" or type(mapTable.rooms) ~= "table" then
        return true
    end
    local x = tonumber(worldX)
    local z = tonumber(worldZ)
    if x == nil or z == nil then
        return true
    end
    local ox = tonumber(mapTable.ox) or 0
    local oz = tonumber(mapTable.oz) or 0
    local sawEntrance = false
    for _, room in ipairs(mapTable.rooms) do
        if type(room) == "table" and room.class == "entrance" then
            sawEntrance = true
            local cx = ox + (tonumber(room.x) or 0)
            local cz = oz + (tonumber(room.z) or 0)
            local hx = tonumber(room.hx) or 0
            local hz = tonumber(room.hz) or 0
            if math.abs(x - cx) <= hx and math.abs(z - cz) <= hz then
                return true
            end
        end
    end
    return not sawEntrance
end

function ChallengeRun.gauntletRosterLocked(noRevives, mapTable, worldX, worldZ)
    if noRevives ~= true then
        return false
    end
    return ChallengeRun.inEntryRoom(mapTable, worldX, worldZ) ~= true
end

local VARIANT_ALIAS = {
    gold = "golden",
}

local function canonicalVariant(variant)
    local raw = type(variant) == "string" and string.lower(variant) or "basic"
    if raw == "" then
        raw = "basic"
    end
    return VARIANT_ALIAS[raw] or raw
end

function ChallengeRun.sanitizeLoadout(catalog, pets, powers)
    catalog = type(catalog) == "table" and catalog or {}
    local bannedPets = {}
    for _, petId in ipairs(catalog.disallowed_pets or {}) do
        if type(petId) == "string" then
            bannedPets[petId] = true
        end
    end
    -- Catalog row is the loaned form. Saved kits only choose which pets;
    -- variant/huge always come from the current catalog so a roster change
    -- cannot leave rainbow-huge Creator Colorado in a Range save.
    local rows = {}
    for _, entry in ipairs(catalog.pets or {}) do
        local petId, row
        if type(entry) == "table" and type(entry.pet) == "string" then
            petId = entry.pet
            row = {
                pet = petId,
                variant = canonicalVariant(entry.variant),
                huge = entry.huge == true,
                default = entry.default == true,
            }
        elseif type(entry) == "string" then
            petId = entry
            row = { pet = petId, variant = "basic", huge = false, default = false }
        end
        if petId and not bannedPets[petId] then
            rows[#rows + 1] = row
        end
    end
    local listedPowers = catalog.powers
    local allowAllPowers = listedPowers == "all" or listedPowers == true
    local allowedPowers = {}
    if type(listedPowers) == "table" then
        for _, powerId in ipairs(listedPowers) do
            if type(powerId) == "string" then
                allowedPowers[powerId] = true
            end
        end
    end
    local bannedPowers = {}
    for _, powerId in ipairs(catalog.disallowed_powers or {}) do
        if type(powerId) == "string" then
            bannedPowers[powerId] = true
        end
    end
    local petSlots = math.max(1, math.floor(num(catalog.pet_slots, 5)))
    local powerSlots = math.max(0, math.floor(num(catalog.power_slots, 4)))
    local outPets = {}
    local usedRow = {}
    local function takeRow(petId)
        for index, row in ipairs(rows) do
            if not usedRow[index] and row.pet == petId then
                usedRow[index] = true
                return row
            end
        end
        return nil
    end
    local function addRow(row)
        outPets[#outPets + 1] = {
            pet = row.pet,
            variant = row.variant,
            huge = row.huge == true,
        }
    end
    for _, entry in ipairs(type(pets) == "table" and pets or {}) do
        local petId = type(entry) == "table" and entry.pet or entry
        if type(petId) == "string" and not bannedPets[petId] then
            local row = takeRow(petId)
            if row then
                addRow(row)
                if #outPets >= petSlots then
                    break
                end
            end
        end
    end
    if #outPets < petSlots then
        for index, row in ipairs(rows) do
            if not usedRow[index] and row.default then
                usedRow[index] = true
                addRow(row)
                if #outPets >= petSlots then
                    break
                end
            end
        end
    end
    local outPowers = {}
    local seenPower = {}
    local function acceptPower(powerId)
        return type(powerId) == "string"
            and not bannedPowers[powerId]
            and (allowAllPowers or allowedPowers[powerId])
            and not seenPower[powerId]
    end
    for _, powerId in ipairs(type(powers) == "table" and powers or {}) do
        if acceptPower(powerId) then
            seenPower[powerId] = true
            table.insert(outPowers, powerId)
            if #outPowers >= powerSlots then
                break
            end
        end
    end
    if #outPowers == 0 then
        local fallback = catalog.default_powers
        if type(fallback) ~= "table" then
            fallback = type(listedPowers) == "table" and listedPowers or {}
        end
        for _, powerId in ipairs(fallback) do
            if acceptPower(powerId) then
                seenPower[powerId] = true
                table.insert(outPowers, powerId)
                if #outPowers >= powerSlots then
                    break
                end
            end
        end
    end
    return { pets = outPets, powers = outPowers }
end

local FALLBACK_ORIGINS = { "geomancer", "sandwalker", "cryomancer", "pyromancer" }

function ChallengeRun.knownOrigins(catalog)
    local listed = type(catalog) == "table" and catalog.origins or nil
    local out = {}
    if type(listed) == "table" then
        for _, origin in ipairs(listed) do
            if type(origin) == "string" and origin ~= "" then
                out[#out + 1] = origin
            end
        end
    end
    if #out == 0 then
        for _, origin in ipairs(FALLBACK_ORIGINS) do
            out[#out + 1] = origin
        end
    end
    return out
end

function ChallengeRun.canonicalOrigin(origin, origins)
    if type(origin) ~= "string" or origin == "" then
        return nil
    end
    origins = type(origins) == "table" and origins or FALLBACK_ORIGINS
    for _, id in ipairs(origins) do
        if id == origin then
            return origin
        end
    end
    return nil
end

function ChallengeRun.soloOnly(modeCfg)
    return type(modeCfg) == "table" and modeCfg.solo_only == true
end

-- Temporary combat pin for a catalog rank run. Nil means "use the real
-- EffectiveLevel pipe" (Training Ground, or a mode that omitted the field).
function ChallengeRun.effectiveLevel(modeCfg)
    if type(modeCfg) ~= "table" then
        return nil
    end
    local n = math.floor(tonumber(modeCfg.effective_level) or 0)
    if n < 1 then
        return nil
    end
    return n
end

-- Combat pin (50) is the fight. XP yield can stay on earned Level so
-- Range is not a leveling machine. Unknown / omitted xp_from keeps the
-- enemy's combat level (Training Ground, overworld).
function ChallengeRun.xpYieldLevel(modeCfg, earnedLevel, enemyLevel)
    local enemy = math.max(1, math.floor(tonumber(enemyLevel) or 1))
    if type(modeCfg) == "table" and modeCfg.xp_from == "earned_level" then
        return math.max(1, math.floor(tonumber(earnedLevel) or 1))
    end
    return enemy
end

function ChallengeRun.xpYieldMult(modeCfg)
    if type(modeCfg) ~= "table" then
        return 1
    end
    local n = tonumber(modeCfg.xp_mult)
    if n == nil or n < 0 then
        return 1
    end
    return n
end

-- Training Ground skips the overworld onramp: you came to fight with your
-- real pets, at whatever earned level can reach the door.
function ChallengeRun.skipsEngageGate(modeCfg)
    return type(modeCfg) == "table" and modeCfg.skip_engage_gate == true
end

-- Combat onramp (configs/combat.lua engagement.min_engage_level) must
-- read the Range pin, not earned Level. A level-3 player in The Range
-- fights at 50; treating earned Level as the gate leaves the room peaceful.
-- Training Ground sets skip_engage_gate and always passes.
function ChallengeRun.passesEngageGate(effectiveLevel, earnedLevel, minEngageLevel, modeCfg)
    if ChallengeRun.skipsEngageGate(modeCfg) then
        return true
    end
    local minLvl = tonumber(minEngageLevel)
    if not minLvl or minLvl <= 1 then
        return true
    end
    local combat = tonumber(effectiveLevel) or tonumber(earnedLevel) or 1
    return combat >= minLvl
end

function ChallengeRun.powersForOrigin(defaults, origin, catalog)
    catalog = type(catalog) == "table" and catalog or {}
    defaults = type(defaults) == "table" and defaults or {}
    local byOrigin = type(defaults.by_origin) == "table" and defaults.by_origin or {}
    local kit = type(origin) == "string" and byOrigin[origin] or nil
    local powers = type(kit) == "table" and kit.powers or nil
    return ChallengeRun.sanitizeLoadout(catalog, nil, powers).powers
end

function ChallengeRun.readRangeDefaults(raw, catalog)
    catalog = type(catalog) == "table" and catalog or {}
    local origins = ChallengeRun.knownOrigins(catalog)
    raw = type(raw) == "table" and raw or {}
    local pets = ChallengeRun.sanitizeLoadout(catalog, raw.pets, {}).pets
    local byOrigin = {}
    local src = type(raw.by_origin) == "table" and raw.by_origin or {}
    for _, origin in ipairs(origins) do
        local kit = src[origin]
        if type(kit) == "table" then
            byOrigin[origin] = {
                powers = ChallengeRun.sanitizeLoadout(catalog, nil, kit.powers).powers,
            }
        end
    end
    return {
        last_origin = ChallengeRun.canonicalOrigin(raw.last_origin, origins),
        pets = pets,
        by_origin = byOrigin,
    }
end

function ChallengeRun.writeRangeDefaults(previous, catalog, draft)
    catalog = type(catalog) == "table" and catalog or {}
    local origins = ChallengeRun.knownOrigins(catalog)
    local nextDefaults = ChallengeRun.readRangeDefaults(previous, catalog)
    draft = type(draft) == "table" and draft or {}
    local sanitized = ChallengeRun.sanitizeLoadout(catalog, draft.pets, draft.powers)
    if #sanitized.pets > 0 then
        nextDefaults.pets = sanitized.pets
    end
    local origin = ChallengeRun.canonicalOrigin(draft.origin, origins)
    if origin then
        nextDefaults.last_origin = origin
        nextDefaults.by_origin[origin] = { powers = sanitized.powers }
    end
    return nextDefaults
end

return ChallengeRun
