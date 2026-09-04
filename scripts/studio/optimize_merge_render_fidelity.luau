-- Edit-mode authoring pass: restore Roblox distance LOD on decorative Merge environment meshes.
-- RenderFidelity cannot be changed reliably during Play, so run this against the place and save.
-- It deliberately scopes itself to environment roots and never touches live pet/enemy templates.

local Workspace = game:GetService("Workspace")

local ROOT_PATHS = {
    { "GeneratedMap_MergeEggVoxel" },
    { "Maps", "MergeEggRealm" },
}

local function resolve(path)
    local current = Workspace
    for _, segment in ipairs(path) do
        current = current and current:FindFirstChild(segment)
    end
    return current
end

local changed = 0
local alreadyAutomatic = 0
for _, path in ipairs(ROOT_PATHS) do
    local root = assert(resolve(path), "missing Merge environment root: " .. table.concat(path, "."))
    for _, descendant in ipairs(root:GetDescendants()) do
        if descendant:IsA("MeshPart") then
            if descendant.RenderFidelity == Enum.RenderFidelity.Automatic then
                alreadyAutomatic += 1
            else
                descendant.RenderFidelity = Enum.RenderFidelity.Automatic
                changed += 1
            end
        end
    end
end

print(string.format("[MergeRenderFidelity] changed=%d alreadyAutomatic=%d", changed, alreadyAutomatic))
