--[[
    PetInventoryView — the single pure projection authority for pet inventory.

    SEPARATION OF CONCERNS:
      OWNERSHIP lives in `Inventory.pets.items`. Two entry shapes, keyed differently:
        COMMON STACK (fungible) — keyed by "id:variant":
          items["bear:basic"] = { id, variant, quantity = N, obtained_at }
          One entry per kind regardless of count → O(distinct kinds) storage.
        SPECIAL (unique per instance) — keyed by uid:
          items[uid] = { uid, id, variant, obtained_at, level, huge, serial, ... }

      EQUIP lives SEPARATELY in `Equipped.pets` — a slot → reference restore/preference
      layer, NOT part of ownership:
          Equipped.pets["slot_1"] = "<uid>"            (a special)
          Equipped.pets["slot_2"] = "stack|id:variant" (one copy of a common; several slots
                                                         may reference the same kind)

    THE SAFETY RULE: `Equipped` is a SOFT, VALIDATED reference, never trusted blindly. The
    live equipped set = `Equipped ∩ inventory` (resolveEquipped): a slot is live only if its
    pet is still owned, and a common kind can be equipped at most `quantity` times. A dangling
    ref (traded/deleted pet, or a crash before teardown) is simply IGNORED and swept lazily —
    so it can never become a phantom, and equip/unequip never touches ownership (no dup/loss).

    PURE: no Roblox APIs, no os.time, no globals. Server + client require the same code.

    API:
      isStackEntry(entry, key?)                  -> boolean (common stack vs special)
      isSpecial(record, capability)              -> boolean
      stackKey(record, config, capability)       -> string (display grouping key)
      normalize(items)                           -> items (pure-ownership canonical fixups)
      parseRef(ref)                              -> { kind="special"|"stack", uid?|stackKey? }
      resolveEquipped(items, equipped, maxSlots) -> slotMap {[n]=desc}, equippedByKey {key=n}
      groups(items, config, capability, equippedByKey?) ->
            { {key,total,equippedCount,unequippedCount,isSpecial,sampleRecord,uids} }
      usedSlots(items, config, capability)       -> integer
      categoryCounts(items, config, capability)  -> { display, total }
      isLevelable(record, capability)            -> boolean
      isEnchantable(record, capability)          -> boolean
]]

local PetInventoryView = {}

local DEFAULT_STACK_FIELDS = { "id", "variant" }

-- A common stack is keyed by exactly "id:variant"; a special by its uid (no ":"). With the
-- key we classify robustly even if a legacy special carries a vestigial quantity=1; without
-- it we fall back to the self-describing form (stack = quantity + no uid).
local function isStackEntry(entry, key)
    if type(entry) ~= "table" then
        return false
    end
    if key ~= nil then
        -- A stack's storage key starts with "id:variant"; Storage v2 appends the
        -- enchant component ("id:variant:<effect-or-empty>"). Accept BOTH the legacy
        -- 2-field key (pre-migration data passing through) and the 3-field form.
        -- uid record keys never contain ":" (GenerateUID format), so no collision.
        local base = tostring(entry.id) .. ":" .. tostring(entry.variant or "basic")
        if key == base then
            return true
        end
        return string.sub(tostring(key), 1, #base + 1) == (base .. ":")
    end
    return type(entry.quantity) == "number" and entry.uid == nil
end
PetInventoryView.isStackEntry = isStackEntry

-- Split on "|" without relying on Roblox's string.split.
local function splitPipe(value)
    local out = {}
    for part in string.gmatch(value, "([^|]+)") do
        out[#out + 1] = part
    end
    return out
end

function PetInventoryView.isSpecial(record, capability)
    if type(record) ~= "table" then
        return false
    end
    capability = capability or {}
    if capability.allowAll == true then
        return true
    end
    if record.huge == true then
        return true
    end
    local rarity = record.rarity_id or record.variant
    local special = capability.specialRarities
    return special ~= nil and rarity ~= nil and special[rarity] == true
end

-- The HUGE GUARD: a record that must NEVER be removed by a pet RESET (huges/exclusives/uniques).
-- Belt-and-suspenders — protected if it's a structural per-uid special (has a uid, not a quantity
-- stack) OR isSpecial says so (huge flag / special rarity). Only pure COMMON stacks fall through.
function PetInventoryView.isProtectedFromReset(record, capability)
    if type(record) ~= "table" then
        return false
    end
    if record.uid ~= nil and record.quantity == nil then
        return true -- self-describing unique instance (a special / huge)
    end
    return PetInventoryView.isSpecial(record, capability)
end

-- Reset filter: drop COMMON stacks, ALWAYS keep protected (huge/special) records. Pure. Returns
-- (keptItems, removedCount). Used by Admin reset so a huge can never be wiped.
function PetInventoryView.keepProtected(items, capability)
    local kept, removed = {}, 0
    for k, rec in pairs(items or {}) do
        if PetInventoryView.isProtectedFromReset(rec, capability) then
            kept[k] = rec
        else
            removed = removed + 1
        end
    end
    return kept, removed
end

-- Display grouping key. Specials key uniquely by uid; commons by the configured fields.
function PetInventoryView.stackKey(record, config, capability)
    if capability ~= nil and PetInventoryView.isSpecial(record, capability) then
        return "uid:" .. tostring(record.uid)
    end
    local fields = (config and config.stack_key_fields) or DEFAULT_STACK_FIELDS
    local parts = {}
    for _, field in ipairs(fields) do
        parts[#parts + 1] = tostring(record[field] ~= nil and record[field] or "")
    end
    return table.concat(parts, ":")
end

-- Decode an Equipped.pets slot value into a reference.
function PetInventoryView.parseRef(ref)
    if type(ref) ~= "string" or ref == "" then
        return nil
    end
    local parts = splitPipe(ref)
    if parts[1] == "stack" and parts[2] then
        return { kind = "stack", stackKey = parts[2] }
    end
    if parts[1] == "special" and parts[2] then
        return { kind = "special", uid = parts[2] }
    end
    return { kind = "special", uid = ref } -- bare uid
end

-- Idempotent canonical fixups. Records hold ONLY ownership now (equip lives in Equipped.pets).
function PetInventoryView.normalize(items)
    items = items or {}
    for key, entry in pairs(items) do
        if type(entry) == "table" then
            if isStackEntry(entry, key) then
                entry.quantity = math.max(0, math.floor(tonumber(entry.quantity) or 0))
                entry.variant = entry.variant or "basic"
                entry.uid = nil
            else
                if entry.uid ~= key then
                    entry.uid = key
                end
                entry.quantity = nil
            end
            entry._kind = nil
            entry.equipped_slot = nil
            entry.equipped_slots = nil
        end
    end
    return items
end

-- Resolve the live equipped set: `Equipped ∩ inventory`, validated. A slot is live only if its
-- pet is still owned (special uid present; common stack present), each special claims one slot,
-- and a common kind is capped at its `quantity`. Slots outside [1..maxSlots] are ignored.
-- Returns slotMap {[slot] = {slot, kind, uid?|stackKey?, id, variant}} and equippedByKey
-- {groupKey = count} (groupKey = "uid:<uid>" for specials, "id:variant" for commons).
function PetInventoryView.resolveEquipped(items, equipped, maxSlots)
    maxSlots = tonumber(maxSlots) or 0
    items = items or {}

    local slots = {}
    for slotName, ref in pairs(equipped or {}) do
        local n = tonumber(tostring(slotName):match("^slot_(%d+)$"))
        if n and n >= 1 and n <= maxSlots and ref ~= nil and ref ~= "" then
            slots[#slots + 1] = { n = n, ref = ref }
        end
    end
    table.sort(slots, function(a, b)
        return a.n < b.n
    end)

    local slotMap, equippedByKey = {}, {}
    local claimedUid, commonClaimed = {}, {}
    for _, slot in ipairs(slots) do
        local desc = PetInventoryView.parseRef(slot.ref)
        if desc and desc.kind == "special" then
            local rec = items[desc.uid]
            if rec and not isStackEntry(rec, desc.uid) and not claimedUid[desc.uid] then
                claimedUid[desc.uid] = true
                slotMap[slot.n] = {
                    slot = slot.n,
                    kind = "special",
                    uid = desc.uid,
                    id = rec.id,
                    variant = rec.variant,
                }
                local gk = "uid:" .. desc.uid
                equippedByKey[gk] = (equippedByKey[gk] or 0) + 1
            end
        elseif desc and desc.kind == "stack" then
            local stack = items[desc.stackKey]
            if stack and isStackEntry(stack, desc.stackKey) then
                local used = commonClaimed[desc.stackKey] or 0
                local qty = math.max(0, math.floor(tonumber(stack.quantity) or 0))
                if used < qty then
                    commonClaimed[desc.stackKey] = used + 1
                    slotMap[slot.n] = {
                        slot = slot.n,
                        kind = "stack",
                        stackKey = desc.stackKey,
                        id = stack.id,
                        variant = stack.variant or "basic",
                    }
                    equippedByKey[desc.stackKey] = (equippedByKey[desc.stackKey] or 0) + 1
                end
            end
        end
    end
    return slotMap, equippedByKey
end

-- Ordered display groups (deterministic by obtained_at then key). Ownership only; pass
-- `equippedByKey` (from resolveEquipped) to overlay equipped/unequipped counts.
function PetInventoryView.groups(items, config, capability, equippedByKey)
    local entries = {}
    for key, entry in pairs(items or {}) do
        if type(entry) == "table" then
            entries[#entries + 1] = { key = key, entry = entry }
        end
    end
    table.sort(entries, function(a, b)
        local ao = tonumber(a.entry.obtained_at) or 0
        local bo = tonumber(b.entry.obtained_at) or 0
        if ao ~= bo then
            return ao < bo
        end
        return tostring(a.key) < tostring(b.key)
    end)

    local order, byKey = {}, {}
    for _, item in ipairs(entries) do
        local entry, key = item.entry, item.key
        local gkey = PetInventoryView.stackKey(entry, config, capability)
        local group = byKey[gkey]
        if not group then
            group = {
                key = gkey,
                total = 0,
                equippedCount = 0,
                unequippedCount = 0,
                isSpecial = capability ~= nil and PetInventoryView.isSpecial(entry, capability)
                    or false,
                sampleRecord = entry,
                uids = {},
            }
            byKey[gkey] = group
            order[#order + 1] = group
        end
        if isStackEntry(entry, key) then
            group.total += math.max(0, math.floor(tonumber(entry.quantity) or 0))
        else
            group.total += 1
            group.uids[#group.uids + 1] = entry.uid or key
        end
    end

    for _, group in ipairs(order) do
        local equipped = equippedByKey and equippedByKey[group.key] or 0
        if equipped > group.total then
            equipped = group.total
        end
        group.equippedCount = equipped
        group.unequippedCount = group.total - equipped
    end
    return order
end

-- One slot per common kind + per special.
function PetInventoryView.usedSlots(items, config, capability)
    -- STORAGE V2: stacks are SELF-BOUNDING (a kind exists once; the catalog is their
    -- cap), so when stacks_count_toward_limit == false only UNIQUE records (specials)
    -- consume slots. Legacy non-special uid records (pre-migration mythics) are free too.
    if config and config.stacks_count_toward_limit == false then
        local n = 0
        for key, entry in pairs(items or {}) do
            if
                type(entry) == "table"
                and not isStackEntry(entry, key)
                and PetInventoryView.isSpecial(entry, capability)
            then
                n += 1
            end
        end
        return n
    end
    if not config or config.count_stacks_as_single ~= false then
        return #PetInventoryView.groups(items, config, capability)
    end
    local n = 0
    for key, entry in pairs(items or {}) do
        if isStackEntry(entry, key) then
            n += math.max(0, math.floor(tonumber(entry.quantity) or 0))
        elseif type(entry) == "table" then
            n += 1
        end
    end
    return n
end

function PetInventoryView.categoryCounts(items, config, capability)
    local total = 0
    for key, entry in pairs(items or {}) do
        if isStackEntry(entry, key) then
            total += math.max(0, math.floor(tonumber(entry.quantity) or 0))
        elseif type(entry) == "table" then
            total += 1
        end
    end
    return {
        display = #PetInventoryView.groups(items, config, capability),
        total = total,
    }
end

-- Config-driven capability checks (replacing the deleted `_kind == "special"` guard).
function PetInventoryView.isLevelable(record, capability)
    return PetInventoryView.isSpecial(record, capability)
end

function PetInventoryView.isEnchantable(record, capability)
    return PetInventoryView.isSpecial(record, capability)
end

return PetInventoryView
