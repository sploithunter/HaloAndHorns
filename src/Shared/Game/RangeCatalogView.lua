--[[
    RangeCatalogView — project the Range catalog into InventoryPanel card records.

    The Range door loans a fixed roster. Players pick from it with the same pet cards
    (role badges, ⚔/❤, ability chips) and Best Pets ranking as owned inventory.
    This module is the pure item-shape adapter; the panel only renders and drafts.
]]

local RangeCatalogView = {}

local VARIANT_ALIAS = {
    gold = "golden",
}

local FALLBACK_RGB = {
    basic = { 150, 150, 150 },
    golden = { 255, 215, 0 },
    rainbow = { 255, 0, 255 },
    exclusive = { 0, 255, 255 },
    secret = { 255, 140, 0 },
    huge = { 255, 90, 210 },
    creator = { 255, 90, 210 },
}

function RangeCatalogView.canonicalVariant(variant)
    local raw = type(variant) == "string" and string.lower(variant) or "basic"
    if raw == "" then
        raw = "basic"
    end
    return VARIANT_ALIAS[raw] or raw
end

function RangeCatalogView.refFor(petId)
    if type(petId) ~= "string" or petId == "" then
        return nil
    end
    return "range|" .. petId
end

local function colorFor(rarityId, variant, pdata)
    local rarity = pdata and pdata.rarity
    if type(rarity) == "table" and rarity.color ~= nil then
        return rarity.color
    end
    local rgb = FALLBACK_RGB[rarityId] or FALLBACK_RGB[variant] or FALLBACK_RGB.basic
    if Color3 and Color3.fromRGB then
        return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
    end
    return rgb
end

local function rarityName(rarityId, pdata)
    local rarity = pdata and pdata.rarity
    if type(rarity) == "table" and type(rarity.name) == "string" then
        return rarity.name
    end
    return tostring(rarityId or "basic"):gsub("^%l", string.upper)
end

function RangeCatalogView.itemFromEntry(entry, petsConfig, progression, petPower)
    if type(entry) ~= "table" or type(entry.pet) ~= "string" then
        return nil
    end
    local petId = entry.pet
    local variant = RangeCatalogView.canonicalVariant(entry.variant)
    local huge = entry.huge == true
    local species = petsConfig and petsConfig.pets and petsConfig.pets[petId]
    local pdata = petsConfig and petsConfig.getPet and petsConfig.getPet(petId, variant)
    if not pdata and petsConfig and petsConfig.getPet then
        pdata = petsConfig.getPet(petId, "basic")
        if pdata then
            variant = "basic"
        end
    end
    local creator = (species and species.category == "creator") or entry.creator == true
    local rarityId = huge and "huge" or (pdata and pdata.rarity_id) or variant
    local power = 1
    if petPower and petPower.basePowerForLevel then
        power = petPower.basePowerForLevel(pdata, huge, 1, progression)
    elseif pdata then
        power = tonumber(pdata.power) or 1
    end
    local display = (
        pdata and (pdata.variant_display_name or pdata.family_display_name or pdata.name)
    ) or petId:gsub("_", " ")
    if huge then
        display = "Huge " .. display
    end
    local ref = RangeCatalogView.refFor(petId)
    return {
        id = ref,
        uid = ref,
        name = display,
        icon = "🐾",
        rarity = rarityName(rarityId, pdata),
        rarityId = rarityId,
        color = colorFor(rarityId, variant, pdata),
        category = "Pets",
        count = 1,
        power = power,
        basePower = power,
        effectivePower = power,
        huge = huge,
        creator = creator,
        special = true,
        folder_source = "pets",
        petType = petId,
        variant = variant,
        use3DModel = true,
        _rangeDefault = entry.default == true,
    }
end

function RangeCatalogView.build(catalog, petsConfig, progression, petPower)
    catalog = type(catalog) == "table" and catalog or {}
    local banned = {}
    for _, petId in ipairs(catalog.disallowed_pets or {}) do
        if type(petId) == "string" then
            banned[petId] = true
        end
    end
    local items = {}
    local byRef = {}
    local defaultRefs = {}
    for _, entry in ipairs(catalog.pets or {}) do
        local petId = type(entry) == "table" and entry.pet or entry
        if type(petId) == "string" and not banned[petId] then
            local item = RangeCatalogView.itemFromEntry(entry, petsConfig, progression, petPower)
            -- Creator-class apex pets are test-only and never loaned.
            if item and item.creator ~= true then
                table.insert(items, item)
                byRef[item.uid] = item
                if item._rangeDefault then
                    table.insert(defaultRefs, item.uid)
                end
            end
        end
    end
    local petSlots = math.max(1, math.floor(tonumber(catalog.pet_slots) or 5))
    if #defaultRefs > petSlots then
        local trimmed = {}
        for i = 1, petSlots do
            trimmed[i] = defaultRefs[i]
        end
        defaultRefs = trimmed
    end
    local listed = type(catalog.powers) == "table" and catalog.powers or {}
    local powers = {}
    for _, powerId in ipairs(catalog.default_powers or listed) do
        if type(powerId) == "string" then
            table.insert(powers, powerId)
        end
        if #powers >= math.max(0, math.floor(tonumber(catalog.power_slots) or 6)) then
            break
        end
    end
    return {
        items = items,
        byRef = byRef,
        defaultRefs = defaultRefs,
        defaultPowers = powers,
        petSlots = petSlots,
        powerSlots = math.max(0, math.floor(tonumber(catalog.power_slots) or 6)),
        catalogPowers = listed,
    }
end

function RangeCatalogView.refsFromPicks(picks)
    local refs = {}
    for _, entry in ipairs(type(picks) == "table" and picks or {}) do
        local petId = type(entry) == "table" and entry.pet or entry
        local ref = RangeCatalogView.refFor(petId)
        if ref then
            table.insert(refs, ref)
        end
    end
    return refs
end

function RangeCatalogView.picksFromRefs(byRef, refs)
    local picks = {}
    for _, ref in ipairs(type(refs) == "table" and refs or {}) do
        local item = type(byRef) == "table" and byRef[ref]
        if item and type(item.petType) == "string" then
            table.insert(picks, {
                pet = item.petType,
                variant = item.variant or "basic",
                huge = item.huge == true,
            })
        end
    end
    return picks
end

return RangeCatalogView
