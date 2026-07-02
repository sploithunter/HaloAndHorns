--[[
    PetMigrationV5 — the pure one-time transform from the legacy MIXED pet storage to
    the SSOT model.

    LEGACY (schema v4 and earlier):
      Inventory.pets.items[<id:variant>] = { id, variant, quantity, _kind="stack", obtained_at }
      Inventory.pets.items[<uid>]        = { id, variant, _kind="special", level, huge, serial, ... }
      Equipped.pets[slot_N]              = "<uid>"  |  "special|<uid>"  |  "stack|<id:variant>|<eph>"
        (equipping a common DECREMENTED its stack quantity — the equipped copy lives only
         as the slot reference, not in `quantity`.)

    SSOT (schema v5):
      Inventory.pets.items[<uid>] = { uid, id, variant, obtained_at, equipped_slot = nil|1..N, ... }
        — one record per pet instance, equip held in equipped_slot, no quantity, no _kind.
      Equipped.pets is cleared (equip now lives on the record; the equipped folder is a
       pure projection rebuilt from records).

    CONSERVATION is the safety net. True legacy ownership =
        Σ stack.quantity  +  #special records  +  #equipped-common slots (decremented-out copies).
    The migration re-mints each equipped common so nothing is lost, and DROPS equipped
    uid-slots whose backing record is gone (the trade-orphaned "phantom" — there is nothing
    to equip, so the dangling slot simply disappears). It asserts owned/equipped counts are
    preserved before the caller commits.

    PURE: no Roblox APIs, no os.time, no randomness. Minted uids are DERIVED from the source
    (deterministic → testable and reproducible on retry). DataService calls migrate() inside
    SchemaMigrations[4]; the headless spec calls it with fixtures.

    migrate(oldItems, equippedPets, opts) -> {
        items  = { [uid] = record },
        report = { legacyOwned, migratedOwned, legacyEquipped, migratedEquipped,
                   conserved = boolean, orphanSlots = {...}, remintedStackSlots = {...} },
    }
]]

local PetMigrationV5 = {}

local function sanitize(value)
    return (tostring(value):gsub("[^%w]", "_"))
end

local function stackKeyOf(id, variant)
    return tostring(id) .. ":" .. tostring(variant or "basic")
end

-- Split on "|" without relying on Roblox's string.split (not in vanilla Luau/lune).
local function splitPipe(value)
    local out = {}
    for part in string.gmatch(value, "([^|]+)") do
        out[#out + 1] = part
    end
    return out
end

-- Classify a legacy items entry. `_kind` is authoritative when present; the fallbacks
-- handle pre-_kind data by treating any per-instance identity as a unique/special pet.
local function classify(entry)
    if entry._kind == "special" then
        return "special"
    end
    if entry._kind == "stack" then
        return "stack"
    end
    if entry.huge == true or entry.serial ~= nil then
        return "special"
    end
    if (tonumber(entry.level) or 1) > 1 or (tonumber(entry.exp) or 0) > 0 then
        return "special"
    end
    if type(entry.enchantments) == "table" and next(entry.enchantments) ~= nil then
        return "special"
    end
    return "stack"
end

-- Decode a legacy equipped slot value -> { kind = "uid"|"stack", uid? , stackKey? }.
local function parseSlotValue(value)
    if type(value) ~= "string" or value == "" then
        return nil
    end
    local parts = splitPipe(value)
    if parts[1] == "special" and parts[2] then
        return { kind = "uid", uid = parts[2] }
    elseif parts[1] == "stack" and parts[2] then
        return { kind = "stack", stackKey = parts[2] }
    elseif #parts == 1 then
        local single = parts[1]
        -- A bare stack key is "id:variant" (has ':' and no uid-style '_'); a bare uid is
        -- "id_timestamp_suffix" (has '_').
        if string.find(single, ":") and not string.find(single, "_") then
            return { kind = "stack", stackKey = single }
        end
        return { kind = "uid", uid = single }
    end
    return { kind = "uid", uid = parts[1] }
end

function PetMigrationV5.migrate(oldItems, equippedPets, opts)
    oldItems = oldItems or {}
    equippedPets = equippedPets or {}
    opts = opts or {}
    local mintUid = opts.mintUid or function(seed)
        return seed
    end

    local newItems = {}
    local legacyStackQuantity = 0
    local specialCount = 0
    local mintCounter = {}

    -- Preserve a stack's obtained_at on its exploded/re-minted copies when available.
    local function obtainedAtFor(stackKey)
        local entry = oldItems[stackKey]
        return (entry and tonumber(entry.obtained_at)) or 0
    end

    local function mintCommon(id, variant, obtainedAt, seed)
        local sk = stackKeyOf(id, variant)
        mintCounter[sk] = (mintCounter[sk] or 0) + 1
        local uid = mintUid("m5_" .. sanitize(sk) .. "_" .. (seed or tostring(mintCounter[sk])))
        newItems[uid] = {
            uid = uid,
            id = id,
            variant = variant or "basic",
            obtained_at = obtainedAt or 0,
        }
        return uid
    end

    -- 1) Explode common stacks into one record per copy; keep special records as-is.
    for key, entry in pairs(oldItems) do
        if type(entry) == "table" then
            if classify(entry) == "special" then
                specialCount += 1
                local copy = {}
                for k, v in pairs(entry) do
                    if k ~= "quantity" and k ~= "_kind" then
                        copy[k] = v
                    end
                end
                copy.uid = key
                copy.equipped_slot = nil
                newItems[key] = copy
            else
                local qty = math.max(0, math.floor(tonumber(entry.quantity) or 0))
                legacyStackQuantity += qty
                for _ = 1, qty do
                    mintCommon(entry.id, entry.variant, tonumber(entry.obtained_at) or 0)
                end
            end
        end
    end

    -- 2) Resolve equipped slots in deterministic slot order.
    local report = { orphanSlots = {}, remintedStackSlots = {} }
    local equippedUidSlots = 0
    local equippedStackSlots = 0

    local slotList = {}
    for slotName, value in pairs(equippedPets) do
        local n = tonumber(tostring(slotName):match("^slot_(%d+)$"))
        if n then
            slotList[#slotList + 1] = { n = n, value = value }
        end
    end
    table.sort(slotList, function(a, b)
        return a.n < b.n
    end)

    local claimedUid = {}
    for _, slot in ipairs(slotList) do
        local desc = parseSlotValue(slot.value)
        if desc and desc.kind == "uid" then
            local rec = newItems[desc.uid]
            if rec and not claimedUid[desc.uid] and rec.equipped_slot == nil then
                rec.equipped_slot = slot.n
                claimedUid[desc.uid] = true
                equippedUidSlots += 1
            else
                -- No backing record (traded-away phantom) or duplicate slot → drop it.
                report.orphanSlots[#report.orphanSlots + 1] = { slot = slot.n, value = slot.value }
            end
        elseif desc and desc.kind == "stack" then
            local id, variant = string.match(desc.stackKey, "^([^:]+):(.+)$")
            if not id then
                id, variant = desc.stackKey, "basic"
            end
            -- Re-mint the decremented-out equipped copy as an equipped record.
            local sk = stackKeyOf(id, variant)
            local uid = mintUid("m5eq_" .. sanitize(sk) .. "_" .. slot.n)
            newItems[uid] = {
                uid = uid,
                id = id,
                variant = variant or "basic",
                obtained_at = obtainedAtFor(sk),
                equipped_slot = slot.n,
            }
            equippedStackSlots += 1
            report.remintedStackSlots[#report.remintedStackSlots + 1] =
                { slot = slot.n, stackKey = sk, uid = uid }
        elseif slot.value ~= nil and slot.value ~= "" then
            report.orphanSlots[#report.orphanSlots + 1] = { slot = slot.n, value = slot.value }
        end
    end

    -- 3) Conservation check (the caller asserts on report.conserved before committing).
    local migratedOwned = 0
    local migratedEquipped = 0
    for _, rec in pairs(newItems) do
        migratedOwned += 1
        if rec.equipped_slot ~= nil then
            migratedEquipped += 1
        end
    end

    report.legacyOwned = legacyStackQuantity + specialCount + equippedStackSlots
    report.migratedOwned = migratedOwned
    report.legacyEquipped = equippedUidSlots + equippedStackSlots
    report.migratedEquipped = migratedEquipped
    report.conserved = (report.migratedOwned == report.legacyOwned)
        and (report.migratedEquipped == report.legacyEquipped)

    return { items = newItems, report = report }
end

return PetMigrationV5
