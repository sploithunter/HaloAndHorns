-- Pure selection policy. Owned/live actors are never destroyed by cache eviction.
local FarmAssetPlan = {}

function FarmAssetPlan.validate(config)
    if
        type(config) ~= "table"
        or type(config.enabled) ~= "boolean"
        or type(config.cache_folder) ~= "string"
        or config.cache_folder == ""
    then
        return false, "farm_asset_warmup requires enabled and cache_folder"
    end
    if type(config.boot_egg_sources) ~= "table" or #config.boot_egg_sources == 0 then
        return false, "farm_asset_warmup requires boot_egg_sources"
    end
    for _, key in ipairs({
        "nearby_egg_count",
        "maximum_predictive_pet_types",
        "recent_owned_models",
        "nearby_pet_radius",
        "retention_seconds",
        "maximum_retained_unused_entries",
        "requested_retention_seconds",
        "maximum_requested_models",
        "request_interval_seconds",
        "template_wait_seconds",
        "reconcile_interval",
        "preload_batch_size",
        "preload_debounce_seconds",
        "preload_max_attempts",
        "preload_retry_seconds",
    }) do
        if
            type(config[key]) ~= "number"
            or config[key] <= 0
            or config[key] ~= config[key]
            or config[key] == math.huge
        then
            return false, "farm_asset_warmup." .. key .. " must be finite and positive"
        end
    end
    return true
end

function FarmAssetPlan.build(config, petsConfig, input)
    local desired, eggs = {}, {}
    local function add(id, variant)
        local pet = petsConfig.pets[id]
        if not pet or not pet.variants[variant] then
            return
        end
        desired[id] = desired[id] or {}
        desired[id][variant] = true
        -- Animated variants deploy using their base rig; warm that geometry as well.
        if pet.variants.basic then
            desired[id].basic = true
        end
    end
    for _, pet in ipairs(input.active or {}) do
        add(pet.id, pet.variant or "basic")
    end
    for _, pet in pairs(input.equipped or {}) do
        add(pet.id, pet.variant or "basic")
    end
    for _, pet in pairs(input.requested or {}) do
        if pet.expiresAt > input.now then
            add(pet.id, pet.variant)
        end
    end

    local owned = {}
    for _, pet in pairs(input.owned or {}) do
        if type(pet) == "table" and (pet.quantity == nil or pet.quantity > 0) then
            owned[#owned + 1] = pet
        end
    end
    table.sort(owned, function(a, b)
        local at, bt = tonumber(a.obtained_at) or 0, tonumber(b.obtained_at) or 0
        if at ~= bt then
            return at > bt
        end
        return tostring(a.id) .. ":" .. tostring(a.variant)
            < tostring(b.id) .. ":" .. tostring(b.variant)
    end)
    local recent, seen = 0, {}
    for _, pet in ipairs(owned) do
        local key = tostring(pet.id) .. ":" .. tostring(pet.variant or "basic")
        if not seen[key] and recent < config.recent_owned_models then
            seen[key] = true
            recent += 1
            add(pet.id, pet.variant or "basic")
        end
    end

    local candidates = table.clone(input.eggs or {})
    table.sort(candidates, function(a, b)
        if a.distance ~= b.distance then
            return a.distance < b.distance
        end
        return a.id < b.id
    end)
    local selected = 0
    for _, egg in ipairs(candidates) do
        if
            not eggs[egg.id]
            and petsConfig.egg_sources[egg.id]
            and selected < config.nearby_egg_count
        then
            eggs[egg.id] = true
            selected += 1
        end
    end
    if selected == 0 then
        for _, id in ipairs(config.boot_egg_sources) do
            eggs[id] = true
        end
    end
    local predictive, count = {}, 0
    local sortedEggs = {}
    for id in pairs(eggs) do
        sortedEggs[#sortedEggs + 1] = id
    end
    table.sort(sortedEggs)
    for _, id in ipairs(sortedEggs) do
        local source = petsConfig.egg_sources[id]
        local names = {}
        for petId in pairs(source and source.pet_weights or {}) do
            names[#names + 1] = petId
        end
        table.sort(names)
        for _, petId in ipairs(names) do
            if not predictive[petId] and count < config.maximum_predictive_pet_types then
                predictive[petId] = true
                count += 1
                for variant in pairs((petsConfig.pets[petId] or {}).variants or {}) do
                    add(petId, variant)
                end
            end
        end
    end
    return desired, eggs
end

function FarmAssetPlan.owns(items, id, variant)
    for _, item in pairs(items or {}) do
        if
            item.id == id
            and (item.variant or "basic") == variant
            and (item.quantity == nil or item.quantity > 0)
        then
            return true
        end
    end
    return false
end

return FarmAssetPlan
