--[[
    Rename generic duplicate map parts so AI-assisted map cleanup can refer to
    them deterministically in Explorer and follow-up scripts.

    This intentionally renames only BaseParts whose current name is exactly
    "Part" under the configured root. Meaningful names such as Grass,
    EggModel, SpawnLocation, and tagged gameplay hooks are preserved.
]]

local CollectionService = game:GetService("CollectionService")

local CONFIG = {
    root_path = "Workspace.Maps.Home",
    dry_run = true,
    prefix = "Part_",
    start_index = 1,
    rename_only_exact_part = true,
    skip_tagged_hooks = true,
}

local GAMEPLAY_TAGS = {
    "Zone",
    "AreaZone",
    "PlayerSpawn",
    "SpawnZone",
    "TeleportPad",
    "Portal",
    "EggStand",
    "EnchanterStation",
    "PODPodium",
    "ChaseableRegion",
    "ShopAnchor",
    "NPCAnchor",
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

local function hasGameplayTag(instance)
    for _, tagName in ipairs(GAMEPLAY_TAGS) do
        if CollectionService:HasTag(instance, tagName) then
            return true
        end
    end
    return false
end

local root = resolvePath(CONFIG.root_path)
assert(root, "root_path not found: " .. CONFIG.root_path)

local parts = {}
for _, instance in ipairs(root:GetDescendants()) do
    if instance:IsA("BasePart") then
        local shouldRename = true
        if CONFIG.rename_only_exact_part and instance.Name ~= "Part" then
            shouldRename = false
        end
        if CONFIG.skip_tagged_hooks and hasGameplayTag(instance) then
            shouldRename = false
        end
        if shouldRename then
            table.insert(parts, instance)
        end
    end
end

table.sort(parts, function(left, right)
    if left.Position.X ~= right.Position.X then
        return left.Position.X < right.Position.X
    end
    if left.Position.Z ~= right.Position.Z then
        return left.Position.Z < right.Position.Z
    end
    return left:GetFullName() < right:GetFullName()
end)

local lines = {}
for offset, part in ipairs(parts) do
    local newName = string.format("%s%03d", CONFIG.prefix, CONFIG.start_index + offset - 1)
    table.insert(lines, string.format("%s -> %s", part:GetFullName(), newName))
    if not CONFIG.dry_run then
        part.Name = newName
        part:SetAttribute("NormalizedGenericName", true)
    end
end

print(
    string.format(
        "%s %d generic parts under %s\n%s",
        CONFIG.dry_run and "Would rename" or "Renamed",
        #parts,
        root:GetFullName(),
        table.concat(lines, "\n")
    )
)
