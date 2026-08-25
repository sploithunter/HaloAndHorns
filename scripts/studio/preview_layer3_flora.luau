-- Preview the production Layer 3 flora mappings directly in Edit mode.
--
-- This mirrors FloraTheme's deterministic selection and FloraService's floor/scale
-- placement without starting the game or changing any FloraAnchor. Preview instances
-- live in each layer's _Layer3FloraPreview folder and must be deleted before saving.

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local CollectionService = game:GetService("CollectionService")
local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SPECS = {
    heaven_3 = {
        ["tree/baobab_tree"] = {
            { "luminous_canopy_tree", 129845713867591 },
            { "cherry_heaven_tree_1" },
        },
        ["tree/joshua_tree_7500tris"] = {
            { "luminous_canopy_tree", 129845713867591 },
            { "cloud_sapling" },
        },
        ["tree/oak_tree"] = { { "luminous_canopy_tree", 129845713867591 } },
        ["tree/pine_tree"] = {
            { "luminous_canopy_tree", 129845713867591 },
            { "frosted_pine_1" },
        },
        ["tree/pinetree1"] = {
            { "luminous_canopy_tree", 129845713867591 },
            { "frosted_pine_2" },
        },
        ["tree/scorched_tree"] = {
            { "luminous_canopy_tree", 129845713867591 },
            { "cherry_heaven_tree_1" },
        },
        ["tree/tree1"] = {
            { "luminous_canopy_tree", 129845713867591 },
            { "cloud_sapling" },
            { "cherry_heaven_tree_2" },
        },
        ["tree/tree2"] = {
            { "luminous_canopy_tree", 129845713867591 },
            { "cloud_sapling" },
        },
        ["tree/world_tree_10k"] = {
            { "luminous_canopy_tree", 129845713867591 },
            { "cherry_heaven_tree_1" },
        },
        rock = {
            { "pearlroot_boulder", 128925513562256 },
            { "bloomstone_shelf", 99592016883829 },
        },
        cactus = { { "empyrean_bloom_cactus", 92340308448476 } },
        ["plant/cloudtiplant"] = {
            { "halo_fern", 140606343015242 },
            { "wingleaf_reed", 116514889587243 },
            { "celestial_bellgrass", 109782436587542 },
            { "rootlight_vine", 133661128733556 },
        },
        ["plant/grass_tuft"] = {
            { "wingleaf_reed", 116514889587243 },
            { "lumen_moss_cushion", 87709274141974 },
            { "celestial_bellgrass", 109782436587542 },
            { "petal_spire", 118378199790211 },
        },
        ["plant/field_flower_bush"] = {
            { "celestial_bellgrass", 109782436587542 },
            { "moonpetal_bush", 83522213199002 },
            { "pearlroot_anemone", 95915196623779 },
            { "empyrean_hibiscus", 91944508765077 },
            { "jade_lantern_bloom", 97525548295326 },
        },
        ["plant/meadow_bush"] = {
            { "emerald_ribbon_shrub", 134872168877253 },
            { "moonpetal_bush", 83522213199002 },
            { "halo_fern", 140606343015242 },
            { "rootlight_vine", 133661128733556 },
            { "jade_lantern_bloom", 97525548295326 },
        },
    },
    hell_3 = {
        ["tree/baobab_tree"] = {
            { "dreadthorn_tree", 107359899087561 },
            { "withered_sapling" },
        },
        ["tree/desert_tree"] = {
            { "dreadthorn_tree", 107359899087561 },
            { "withered_sapling" },
        },
        ["tree/oak_tree"] = { { "dreadthorn_tree", 107359899087561 } },
        ["tree/pine_tree"] = {
            { "dreadthorn_tree", 107359899087561 },
            { "coldfire_pine" },
        },
        ["tree/scorched_tree"] = {
            { "dreadthorn_tree", 107359899087561 },
            { "lava_eye_tree" },
        },
        ["tree/tree1"] = {
            { "dreadthorn_tree", 107359899087561 },
            { "withered_sapling" },
            { "scorched_tree" },
        },
        rock = {
            { "dreadspire_faultstone", 127198710217123 },
            { "dreadspire_razorstone", 111270804096202 },
        },
        cactus = { { "dreadspire_thorn_cactus", 115450618548911 } },
        ["plant/grass_tuft"] = {
            { "dreadspire_ribbon_grass", 121438787682125 },
            { "ironroot_crawler", 75981372426650 },
            { "blood_reed", 114822408636080 },
            { "ember_thorn_cluster", 113332495335938 },
        },
        ["plant/field_flower_bush"] = {
            { "crimson_watcher_bloom", 89011734336429 },
            { "violet_hook_bloom", 84019968092033 },
            { "abyss_orchid", 78111910299197 },
            { "blood_reed", 114822408636080 },
        },
        ["plant/meadow_bush"] = {
            { "gloom_pitcher", 111768412199639 },
            { "razorleaf_fan", 82872355582067 },
            { "obsidian_spike_plant", 124834078723373 },
            { "violet_bramble", 122809019311326 },
            { "ember_thorn_cluster", 113332495335938 },
        },
    },
}

local CANONICAL_HEIGHTS = {
    luminous_canopy_tree = 12,
    dreadthorn_tree = 12,
}

local function deterministicIndex(anchor, count)
    local seed = math.floor(anchor.Position.X * 73856093) + math.floor(anchor.Position.Z * 19349663)
    return (seed % count) + 1
end

local function asModel(instance)
    if instance:IsA("Model") then
        return instance
    end
    local model = Instance.new("Model")
    instance.Parent = model
    return model
end

local function sourceModel(name, assetId)
    local model
    if assetId then
        local container = InsertService:LoadAsset(assetId)
        local mesh = container:FindFirstChildWhichIsA("MeshPart", true)
        assert(mesh, ("model %d has no MeshPart"):format(assetId))
        model = asModel(mesh:Clone())
        container:Destroy()
    else
        local assets = ReplicatedStorage:FindFirstChild("Assets")
        local models = assets and assets:FindFirstChild("Models")
        local flora = models and models:FindFirstChild("Flora")
        local template = flora and flora:FindFirstChild(name)
        assert(template, "existing flora model missing: " .. name)
        model = asModel(template:Clone())
    end

    local canonicalHeight = CANONICAL_HEIGHTS[name]
    if canonicalHeight then
        local _, size = model:GetBoundingBox()
        local factor = canonicalHeight / size.Y
        -- These uploaded props are single MeshParts. Resize the part directly so
        -- the preview template keeps Model:GetScale() == 1, matching the prebake;
        -- Model:ScaleTo here would make FloraService's later ScaleTo absolute.
        for _, descendant in ipairs(model:GetDescendants()) do
            if descendant:IsA("BasePart") then
                descendant.Size *= factor
            end
        end
    end
    return model
end

local function placeAt(model, anchor, kind)
    for _, descendant in ipairs(model:GetDescendants()) do
        if descendant:IsA("MeshPart") then
            descendant.Color = Color3.new(1, 1, 1)
            descendant.Anchored = true
            descendant.CanCollide = false
            descendant.CanTouch = false
            descendant.CanQuery = false
        end
    end

    local bboxCf, size = model:GetBoundingBox()
    model.WorldPivot = CFrame.new(bboxCf.Position)
    local targetHeight = tonumber(anchor:GetAttribute("Scale"))
    if targetHeight and size.Y > 0.001 then
        model:ScaleTo(math.clamp(targetHeight / size.Y, 0.2, 5))
        local newCf, newSize = model:GetBoundingBox()
        model.WorldPivot = CFrame.new(newCf.Position)
        size = newSize
    end

    local floor = anchor.Position - Vector3.new(0, 0.2, 0)
    local sink = kind == "rock" and 0.18 * size.Y or 0
    local yaw = select(2, anchor.CFrame:ToEulerAnglesYXZ())
    if kind == "rock" or kind == "cactus" or kind == "plant" then
        local seed = math.floor(anchor.Position.X * 73856093)
            + math.floor(anchor.Position.Z * 19349663)
        yaw = (seed % 6283) / 1000
    end
    model:PivotTo(CFrame.new(floor + Vector3.new(0, size.Y / 2, 0)) * CFrame.Angles(0, yaw, 0))

    local placedCf, placedSize = model:GetBoundingBox()
    local bottom = placedCf.Position.Y - placedSize.Y / 2
    local drop = bottom - (floor.Y - sink)
    if math.abs(drop) > 0.01 then
        model:PivotTo(model:GetPivot() - Vector3.new(0, drop, 0))
    end
end

local maps = workspace:FindFirstChild("Maps")
assert(maps, "Workspace.Maps missing")
ChangeHistoryService:SetWaypoint("Before Layer 3 flora preview")

local cached = {}
local report = {}
for layerId, mappings in pairs(SPECS) do
    local layerName = layerId == "heaven_3" and "Heaven_3" or "Hell_3"
    local layer = maps:FindFirstChild(layerName)
    assert(layer, layerName .. " missing")
    local old = layer:FindFirstChild("_Layer3FloraPreview")
    if old then
        old:Destroy()
    end
    local preview = Instance.new("Folder")
    preview.Name = "_Layer3FloraPreview"
    preview:SetAttribute("StudioPreviewOnly", true)
    preview.Parent = layer

    local counts = {}
    local spawned = 0
    for _, anchor in ipairs(CollectionService:GetTagged("FloraAnchor")) do
        if anchor:IsA("BasePart") and anchor:IsDescendantOf(layer) then
            local kind = anchor:GetAttribute("Kind")
            local variant = anchor:GetAttribute("Variant")
            local choices = mappings[kind .. "/" .. variant] or mappings[kind]
            if choices then
                local selected = choices[deterministicIndex(anchor, #choices)]
                local name, assetId = selected[1], selected[2]
                if not cached[name] then
                    cached[name] = sourceModel(name, assetId)
                end
                local visual = cached[name]:Clone()
                visual.Name = "Flora_" .. name
                placeAt(visual, anchor, kind)
                visual:SetAttribute("SourceModelAsset", assetId and tostring(assetId) or "prebaked")
                visual:SetAttribute("SourceAnchor", anchor:GetFullName())
                visual.Parent = preview
                counts[name] = (counts[name] or 0) + 1
                spawned += 1
            end
        end
    end
    table.insert(report, ("%s spawned=%d"):format(layerName, spawned))
    local names = {}
    for name in pairs(counts) do
        table.insert(names, name)
    end
    table.sort(names)
    for _, name in ipairs(names) do
        table.insert(report, ("  %s=%d"):format(name, counts[name]))
    end
end

for _, model in pairs(cached) do
    model:Destroy()
end
ChangeHistoryService:SetWaypoint("After Layer 3 flora preview")
return table.concat(report, "\n")
