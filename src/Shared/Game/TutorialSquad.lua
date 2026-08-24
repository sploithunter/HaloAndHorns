--[[
    TutorialSquad — combat-training inventory overlay (pure).

    Unlike Range GhostPets, combat training temp-grants real commons so the
    player can mix a 3-slot squad (three bunnies, three kitties, …). Callers
    snapshot Equipped.pets, add the grant quantities, then subtract those
    same quantities on exit. Ownership and XP outside the grant delta stay.
]]

local TutorialSquad = {}

-- Used when config is missing or the allow-list would otherwise be empty.
-- An empty set hid every pet (Pets 0) while the loaned stacks were present.
TutorialSquad.STARTER_IDS = { "bunny", "doggy", "bear", "kitty" }

function TutorialSquad.stackKey(petId, variant, enchant)
    return table.concat({
        tostring(petId or ""),
        tostring(variant or "basic"),
        tostring(enchant or ""),
    }, ":")
end

function TutorialSquad.copyEquipped(equipped)
    local out = {}
    if type(equipped) ~= "table" then
        return out
    end
    for slot, ref in pairs(equipped) do
        if type(slot) == "string" and type(ref) == "string" and ref ~= "" then
            out[slot] = ref
        end
    end
    return out
end

function TutorialSquad.grantRows(config)
    local spec = type(config) == "table" and config.loaned_squad or nil
    if type(spec) ~= "table" then
        spec = { count = 3, pets = {} }
        for _, petId in ipairs(TutorialSquad.STARTER_IDS) do
            spec.pets[#spec.pets + 1] = { pet = petId, variant = "basic" }
        end
    end
    local defaultCount = math.max(1, math.floor(tonumber(spec.count) or 1))
    local listed = type(spec.pets) == "table" and spec.pets or spec
    local rows = {}
    for _, entry in ipairs(listed) do
        if type(entry) == "table" and type(entry.pet) == "string" and entry.pet ~= "" then
            local variant = type(entry.variant) == "string" and entry.variant or "basic"
            if variant == "" then
                variant = "basic"
            end
            local count = math.max(1, math.floor(tonumber(entry.count) or defaultCount))
            rows[#rows + 1] = {
                pet = entry.pet,
                variant = variant,
                count = count,
                stackKey = TutorialSquad.stackKey(entry.pet, variant, entry.enchant),
            }
        end
    end
    return rows
end

function TutorialSquad.allowedKeySet(rows)
    local set = {}
    for _, row in ipairs(type(rows) == "table" and rows or {}) do
        if type(row) == "table" and type(row.stackKey) == "string" then
            set[row.stackKey] = true
        end
    end
    return set
end

-- Inventory hide-list: any variant of the loaned species (golden bunny is
-- fine). They need at least three of each; the exact grant copies do not
-- have to be the only visible cards.
function TutorialSquad.allowedPetSet(rows)
    local set = {}
    for _, row in ipairs(type(rows) == "table" and rows or {}) do
        if type(row) == "table" and type(row.pet) == "string" and row.pet ~= "" then
            set[row.pet] = true
        end
    end
    if next(set) == nil then
        for _, petId in ipairs(TutorialSquad.STARTER_IDS) do
            set[petId] = true
        end
    end
    return set
end

local function petIdFromStackKey(key)
    if type(key) ~= "string" or key == "" then
        return nil
    end
    local petId = string.match(key, "^([^:]+)")
    if type(petId) == "string" and petId ~= "" then
        return petId
    end
    return nil
end

function TutorialSquad.itemStackKey(item)
    if type(item) ~= "table" then
        return nil
    end
    if type(item.petType) == "string" and item.petType ~= "" then
        return TutorialSquad.stackKey(item.petType, item.variant, item.enchant)
    end
    local uid = item.uid
    if type(uid) == "string" and string.find(uid, ":", 1, true) then
        if string.sub(uid, 1, 6) == "stack|" then
            uid = string.sub(uid, 7)
        end
        local pipe = string.find(uid, "|", 1, true)
        if pipe then
            uid = string.sub(uid, 1, pipe - 1)
        end
        return uid
    end
    return nil
end

function TutorialSquad.refStackKey(ref)
    if type(ref) ~= "string" or ref == "" then
        return nil
    end
    if string.sub(ref, 1, 6) == "stack|" then
        local rest = string.sub(ref, 7)
        local pipe = string.find(rest, "|", 1, true)
        if pipe then
            rest = string.sub(rest, 1, pipe - 1)
        end
        return rest
    end
    return nil
end

function TutorialSquad.isAllowedItem(item, rows)
    if type(item) ~= "table" then
        return false
    end
    local allowed = TutorialSquad.allowedPetSet(rows)
    local petId = item.petType
    if type(petId) ~= "string" or petId == "" then
        petId = petIdFromStackKey(TutorialSquad.itemStackKey(item))
    end
    return type(petId) == "string" and allowed[petId] == true
end

function TutorialSquad.refAllowed(ref, rows)
    local petId = petIdFromStackKey(TutorialSquad.refStackKey(ref))
    return petId ~= nil and TutorialSquad.allowedPetSet(rows)[petId] == true
end

function TutorialSquad.defaultRefs(rows, maxSlots)
    local refs = {}
    local cap = math.max(0, math.floor(tonumber(maxSlots) or 0))
    for _, row in ipairs(type(rows) == "table" and rows or {}) do
        if #refs >= cap then
            break
        end
        if type(row) == "table" and type(row.stackKey) == "string" then
            refs[#refs + 1] = "stack|" .. row.stackKey
        end
    end
    return refs
end

-- Authored starting squad. `loaned_squad.equip` may repeat a species (three
-- doggies). Falls back to one of each grant row when equip is omitted.
function TutorialSquad.equipRefs(config, maxSlots)
    local spec = type(config) == "table" and config.loaned_squad or nil
    local cap = math.max(0, math.floor(tonumber(maxSlots) or 0))
    local listed = spec and spec.equip
    if type(listed) ~= "table" then
        return TutorialSquad.defaultRefs(TutorialSquad.grantRows(config), cap)
    end
    local refs = {}
    for _, entry in ipairs(listed) do
        if #refs >= cap then
            break
        end
        local petId, variant
        if type(entry) == "string" then
            petId = entry
            variant = "basic"
        elseif type(entry) == "table" and type(entry.pet) == "string" then
            petId = entry.pet
            variant = type(entry.variant) == "string" and entry.variant or "basic"
        end
        if type(petId) == "string" and petId ~= "" then
            if variant == "" then
                variant = "basic"
            end
            refs[#refs + 1] = "stack|" .. TutorialSquad.stackKey(petId, variant)
        end
    end
    return refs
end

function TutorialSquad.addGrants(items, rows)
    items = type(items) == "table" and items or {}
    local ledger = {}
    for _, row in ipairs(type(rows) == "table" and rows or {}) do
        local key = row.stackKey or TutorialSquad.stackKey(row.pet, row.variant, row.enchant)
        local add = math.max(0, math.floor(tonumber(row.count) or 0))
        if key ~= "::" and add > 0 then
            local stack = items[key]
            if type(stack) ~= "table" then
                stack = {
                    id = row.pet,
                    variant = row.variant or "basic",
                    quantity = 0,
                }
                items[key] = stack
            end
            stack.quantity = math.max(0, math.floor(tonumber(stack.quantity) or 0)) + add
            ledger[key] = (ledger[key] or 0) + add
        end
    end
    return ledger, items
end

function TutorialSquad.removeGrants(items, ledger)
    items = type(items) == "table" and items or {}
    ledger = type(ledger) == "table" and ledger or {}
    for key, granted in pairs(ledger) do
        local take = math.max(0, math.floor(tonumber(granted) or 0))
        local stack = items[key]
        if take > 0 and type(stack) == "table" then
            local have = math.max(0, math.floor(tonumber(stack.quantity) or 0))
            local nextQty = math.max(0, have - take)
            if nextQty <= 0 then
                items[key] = nil
            else
                stack.quantity = nextQty
            end
        end
    end
    return items
end

return TutorialSquad
