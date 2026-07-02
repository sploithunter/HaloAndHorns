--[[
    Stamp builder-authored egg models with the RBX-Template EggStand contract.

    Run in Studio edit mode after a map is imported/saved. This helper is meant
    to be edited per map by a designer or AI assistant: configure which authored
    models represent which configured egg ids, run it, then save the place.

    It does not create visual egg models. It tags existing models/parts so the
    template can attach proximity UI, hatching, pricing, and server validation.
    Prefer tagging the actual interaction anchor, such as the egg/rock part
    inside a decorative hatcher, instead of a large container model.
]]

local CollectionService = game:GetService("CollectionService")

local CONFIG = {
    root_path = "Workspace.Maps.Home",
    dry_run = true,
    clear_existing_for_egg_ids = true,
    candidate_names = {
        "EggStand",
        "Egg Stand",
        "Egg",
        "Egg hatcher",
    },
    mappings = {
        -- Current NewWorld cleanup copy mapping:
        {
            path = "Workspace.Maps.Home.LegacyEggHatchers.BasicEarth.EggModel",
            egg_id = "basic_egg",
            area_id = "Spawn",
            spawn_id = "BasicEarth",
        },

        -- Nearest-position example for duplicate model names:
        -- {
        --     name = "Egg hatcher",
        --     near = Vector3.new(-146.7, 9.7, 47.4),
        --     egg_id = "golden_egg",
        --     area_id = "Spawn",
        --     spawn_id = "GoldenEgg",
        -- },
    },
}

local function splitPath(path)
    local parts = {}
    for part in string.gmatch(path, "[^%.]+") do
        table.insert(parts, part)
    end
    return parts
end

local function resolvePath(path)
    local current = game
    for _, part in ipairs(splitPath(path)) do
        if part ~= "game" then
            current = current:FindFirstChild(part)
            if not current then
                return nil
            end
        end
    end
    return current
end

local function getPosition(instance)
    if instance:IsA("BasePart") then
        return instance.Position
    end
    if instance:IsA("Model") then
        return instance:GetPivot().Position
    end
    local part = instance:FindFirstChildWhichIsA("BasePart", true)
    return part and part.Position or nil
end

local function isCandidate(instance, mapping)
    if mapping.name and instance.Name ~= mapping.name then
        return false
    end
    if not mapping.name then
        for _, name in ipairs(CONFIG.candidate_names) do
            if instance.Name == name then
                return true
            end
        end
        return false
    end
    return true
end

local function findNearestCandidate(mapping)
    local root = resolvePath(CONFIG.root_path) or workspace
    local best = nil
    local bestDistance = math.huge

    for _, instance in ipairs(root:GetDescendants()) do
        if
            (instance:IsA("Model") or instance:IsA("BasePart")) and isCandidate(instance, mapping)
        then
            local position = getPosition(instance)
            if position and mapping.near then
                local distance = (position - mapping.near).Magnitude
                if distance < bestDistance then
                    best = instance
                    bestDistance = distance
                end
            end
        end
    end

    return best, bestDistance
end

local function addTag(instance, tag)
    if not CollectionService:HasTag(instance, tag) then
        CollectionService:AddTag(instance, tag)
    end
end

local function getEggId(instance)
    local eggId = instance:GetAttribute("EggId") or instance:GetAttribute("EggType")
    if type(eggId) == "string" and eggId ~= "" then
        return eggId
    end
    return nil
end

local function clearEggStand(instance)
    if CollectionService:HasTag(instance, "EggStand") then
        CollectionService:RemoveTag(instance, "EggStand")
    end
    instance:SetAttribute("EggId", nil)
    instance:SetAttribute("EggType", nil)
    instance:SetAttribute("AuthoredVisual", nil)
    instance:SetAttribute("SpawnMode", nil)
    instance:SetAttribute("AreaId", nil)
    instance:SetAttribute("SpawnId", nil)
end

local function clearExistingEggStandHooks(target, mapping)
    if not CONFIG.clear_existing_for_egg_ids then
        return {}
    end

    local cleared = {}
    local seen = {}
    local eggId = mapping.egg_id

    local function maybeClear(instance)
        if not instance or instance == target or seen[instance] then
            return
        end
        seen[instance] = true
        local existingEggId = getEggId(instance)
        if
            existingEggId == eggId
            or (existingEggId == nil and CollectionService:HasTag(instance, "EggStand"))
        then
            clearEggStand(instance)
            table.insert(cleared, instance:GetFullName())
        end
    end

    for _, instance in ipairs(CollectionService:GetTagged("EggStand")) do
        maybeClear(instance)
    end

    local root = resolvePath(CONFIG.root_path) or workspace
    for _, instance in ipairs(root:GetDescendants()) do
        if instance:IsA("Model") or instance:IsA("BasePart") then
            maybeClear(instance)
        end
    end

    return cleared
end

local function stamp(instance, mapping)
    clearExistingEggStandHooks(instance, mapping)
    instance:SetAttribute("EggId", mapping.egg_id)
    instance:SetAttribute("EggType", mapping.egg_id)
    instance:SetAttribute("AuthoredVisual", true)
    instance:SetAttribute("SpawnMode", "authored")
    if mapping.area_id then
        instance:SetAttribute("AreaId", mapping.area_id)
    end
    if mapping.spawn_id then
        instance:SetAttribute("SpawnId", mapping.spawn_id)
    end
    addTag(instance, "EggStand")
end

local lines = {}
for index, mapping in ipairs(CONFIG.mappings) do
    local instance = mapping.path and resolvePath(mapping.path) or nil
    local distance = nil
    if not instance then
        instance, distance = findNearestCandidate(mapping)
    end

    if not instance then
        table.insert(
            lines,
            string.format("[%d] missing egg stand for %s", index, tostring(mapping.egg_id))
        )
    elseif CONFIG.dry_run then
        table.insert(
            lines,
            string.format(
                "[%d] would tag %s as %s distance=%s",
                index,
                instance:GetFullName(),
                tostring(mapping.egg_id),
                distance and string.format("%.2f", distance) or "path"
            )
        )
    else
        stamp(instance, mapping)
        table.insert(
            lines,
            string.format(
                "[%d] tagged %s as %s",
                index,
                instance:GetFullName(),
                tostring(mapping.egg_id)
            )
        )
    end
end

print(table.concat(lines, "\n"))
