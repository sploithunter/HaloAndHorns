--[[
    Stamp builder-authored surface parts as RBX-Template SpawnZone hooks.

    Use this for real maps where crystals/coins should spawn only on a playable
    surface such as grass, while avoiding sidewalks, trees, eggs, rocks, portals,
    and other props through runtime clearance checks.
]]

local CollectionService = game:GetService("CollectionService")
local Selection = game:GetService("Selection")

local CONFIG = {
    dry_run = true,
    use_selection = true,
    mappings = {
        -- Current NewWorld cleanup copy mapping:
        {
            path = "Workspace.Maps.Home.Grass",
            area_id = "Spawn",
            spawner_id = "spawn_crystals",
            surface_only = true,
            clearance_mode = "ray_samples",
            clearance_radius = 4,
            clearance_height = 6,
            clearance_y_offset = 3,
            ray_sample_count = 8,
            obstacle_raycast_height = 18,
            obstacle_raycast_depth = 1.5,
            raycast_height = 220,
            normal_min_y = 0.72,
            spawn_area_margin = 10,
            spawn_attempts = 160,
            min_distance = 10,
            balanced_cells = true,
            cell_size = 42,
            max_count_override = 100,
        },
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

local function addTag(instance, tag)
    if not CollectionService:HasTag(instance, tag) then
        CollectionService:AddTag(instance, tag)
    end
end

local function stamp(instance, mapping)
    instance:SetAttribute("AreaId", mapping.area_id)
    instance:SetAttribute("SpawnerId", mapping.spawner_id)
    instance:SetAttribute("SurfaceOnly", mapping.surface_only == true)
    instance:SetAttribute("ClearanceMode", mapping.clearance_mode)
    instance:SetAttribute("ClearanceRadius", mapping.clearance_radius)
    instance:SetAttribute("ClearanceHeight", mapping.clearance_height)
    instance:SetAttribute("ClearanceYOffset", mapping.clearance_y_offset)
    instance:SetAttribute("RaySampleCount", mapping.ray_sample_count)
    instance:SetAttribute("ObstacleRaycastHeight", mapping.obstacle_raycast_height)
    instance:SetAttribute("ObstacleRaycastDepth", mapping.obstacle_raycast_depth)
    instance:SetAttribute("RaycastHeight", mapping.raycast_height)
    instance:SetAttribute("NormalMinY", mapping.normal_min_y)
    instance:SetAttribute("SpawnAreaMargin", mapping.spawn_area_margin)
    instance:SetAttribute("SpawnAttempts", mapping.spawn_attempts)
    instance:SetAttribute("MinDistance", mapping.min_distance)
    instance:SetAttribute("BalancedCells", mapping.balanced_cells == true)
    instance:SetAttribute("CellSize", mapping.cell_size)
    if mapping.max_count_override then
        instance:SetAttribute("MaxCountOverride", mapping.max_count_override)
    end
    addTag(instance, "SpawnZone")
end

local mappings = {}
if CONFIG.use_selection then
    for _, instance in ipairs(Selection:Get()) do
        if instance:IsA("BasePart") then
            local mapping = table.clone(CONFIG.mappings[1])
            mapping.instance = instance
            table.insert(mappings, mapping)
        end
    end
end
if #mappings == 0 then
    mappings = CONFIG.mappings
end

local lines = {}
for index, mapping in ipairs(mappings) do
    local instance = mapping.instance or (mapping.path and resolvePath(mapping.path))
    if not instance then
        table.insert(lines, string.format("[%d] missing spawn surface", index))
    elseif not instance:IsA("BasePart") then
        table.insert(
            lines,
            string.format("[%d] %s is not a BasePart", index, instance:GetFullName())
        )
    elseif CONFIG.dry_run then
        table.insert(
            lines,
            string.format(
                "[%d] would tag %s as SpawnZone area=%s spawner=%s",
                index,
                instance:GetFullName(),
                tostring(mapping.area_id),
                tostring(mapping.spawner_id)
            )
        )
    else
        stamp(instance, mapping)
        table.insert(
            lines,
            string.format(
                "[%d] tagged %s as SpawnZone area=%s spawner=%s",
                index,
                instance:GetFullName(),
                tostring(mapping.area_id),
                tostring(mapping.spawner_id)
            )
        )
    end
end

print(table.concat(lines, "\n"))
