--[[
    PetCompaction — pure v5 -> v6 transform: collapse the exploded per-uid COMMON records
    (produced by the first SSOT pass) back into compact stacks, so commons cost O(distinct
    kinds) storage instead of O(total pets). Specials (unique per instance) are kept as-is.

    v5 (exploded):  items[uid] = { uid, id, variant, obtained_at, equipped_slot } for EVERY
                    pet, common or special.
    v6 (compact):   items["id:variant"] = { id, variant, quantity, equipped_slots = {n…} }
                    for commons; items[uid] = { uid, …, equipped_slot } for specials.

    Idempotent: running on already-compact data reproduces it (a fresh v4 profile runs the
    v4->v5 explode then this v5->v6 collapse; the net result is compact).

    PURE: no Roblox APIs. The special/common classifier and the stack-key function are
    INJECTED (so the same predicates the live projection uses drive the migration — no drift,
    and no cross-module require that headless can't resolve).

    collapse(items, opts) -> {
        items  = { … },
        report = { ownedBefore, ownedAfter, equippedBefore, equippedAfter, conserved },
    }
      opts.isSpecial(record) -> boolean   (required)
      opts.stackKey(record)  -> string    (required; e.g. "id:variant")
]]

local PetCompaction = {}

-- Sorted, unique, positive-int slot array, clamped to `quantity`.
local function normalizeSlots(slots, quantity)
    local seen, out = {}, {}
    if type(slots) == "table" then
        for k, v in pairs(slots) do
            local n
            if v == true then
                n = tonumber(k)
            else
                n = tonumber(v)
            end
            if n and n >= 1 and n == math.floor(n) and not seen[n] then
                seen[n] = true
                out[#out + 1] = n
            end
        end
    end
    table.sort(out)
    if quantity ~= nil then
        local cap = math.max(0, math.floor(tonumber(quantity) or 0))
        while #out > cap do
            table.remove(out)
        end
    end
    return out
end

function PetCompaction.collapse(items, opts)
    items = items or {}
    opts = opts or {}
    local isSpecial = opts.isSpecial or function()
        return false
    end
    local stackKeyOf = opts.stackKey
        or function(rec)
            return tostring(rec.id) .. ":" .. tostring(rec.variant or "basic")
        end

    local newItems = {}
    local stacks = {}
    local ownedBefore, equippedBefore = 0, 0

    local function getStack(rec)
        local key = stackKeyOf(rec)
        local s = stacks[key]
        if not s then
            s = {
                id = rec.id,
                variant = rec.variant or "basic",
                quantity = 0,
                equipped_slots = {},
                obtained_at = tonumber(rec.obtained_at) or 0,
            }
            stacks[key] = s
        end
        local ts = tonumber(rec.obtained_at)
        if ts and ts > 0 and (s.obtained_at == 0 or ts < s.obtained_at) then
            s.obtained_at = ts
        end
        return s
    end

    for key, entry in pairs(items) do
        if type(entry) == "table" then
            if isSpecial(entry) then
                ownedBefore += 1
                if entry.equipped_slot ~= nil then
                    equippedBefore += 1
                end
                entry.uid = entry.uid or key
                entry.quantity = nil
                entry.equipped_slots = nil
                entry._kind = nil
                newItems[entry.uid] = entry
            else
                local s = getStack(entry)
                local isCompact = type(entry.quantity) == "number" and key == stackKeyOf(entry)
                if isCompact then
                    local q = math.max(0, math.floor(tonumber(entry.quantity) or 0))
                    s.quantity += q
                    ownedBefore += q
                    for _, slot in ipairs(normalizeSlots(entry.equipped_slots)) do
                        s.equipped_slots[#s.equipped_slots + 1] = slot
                        equippedBefore += 1
                    end
                else
                    -- per-uid common: fold one copy
                    s.quantity += 1
                    ownedBefore += 1
                    local slot = tonumber(entry.equipped_slot)
                    if slot and slot >= 1 and slot == math.floor(slot) then
                        s.equipped_slots[#s.equipped_slots + 1] = slot
                        equippedBefore += 1
                    end
                end
            end
        end
    end

    -- Finalize stacks: dedupe/sort/clamp their equipped_slots; place by stack key.
    for key, s in pairs(stacks) do
        s.equipped_slots = normalizeSlots(s.equipped_slots, s.quantity)
        newItems[key] = s
    end

    -- Conservation (ownership is the hard invariant; equipped may legitimately shrink if
    -- invalid/duplicate slots were dropped).
    local ownedAfter, equippedAfter = 0, 0
    for key, entry in pairs(newItems) do
        if type(entry.quantity) == "number" and key == stackKeyOf(entry) then
            ownedAfter += math.max(0, math.floor(entry.quantity))
            equippedAfter += #(entry.equipped_slots or {})
        else
            ownedAfter += 1
            if entry.equipped_slot ~= nil then
                equippedAfter += 1
            end
        end
    end

    return {
        items = newItems,
        report = {
            ownedBefore = ownedBefore,
            ownedAfter = ownedAfter,
            equippedBefore = equippedBefore,
            equippedAfter = equippedAfter,
            conserved = ownedBefore == ownedAfter,
        },
    }
end

return PetCompaction
