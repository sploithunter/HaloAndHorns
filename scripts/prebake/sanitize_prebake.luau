--[[ Remove runtime-generated caches from a captured Assets.Models RBXM.

     MissionTiles is rebuilt from source on demand and must never become authoritative through
     Models.rbxm. Keeping this cleanup deterministic avoids hand-editing a binary Studio export.

     Usage:
       lune run scripts/prebake/sanitize_prebake.luau <captured.rbxm> <clean.rbxm>
]]
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local inputPath = process.args[1]
local outputPath = process.args[2]
assert(
    inputPath and outputPath,
    "usage: lune run sanitize_prebake.luau <captured.rbxm> <clean.rbxm>"
)

local roots = roblox.deserializeModel(fs.readFile(inputPath))
local removed = {}
local deduplicated = {}

local function deduplicateChildren(parent)
    if not parent then
        return
    end

    local seen = {}
    local children = parent:GetChildren()
    -- Studio appends a freshly rebuilt asset after older children. Walk backward so the newest
    -- valid capture wins, then remove every older sibling with the same asset key.
    for index = #children, 1, -1 do
        local child = children[index]
        local keeper = seen[child.Name]
        if keeper then
            -- Asset preload folders from an older capture can coexist with a newer folder of the
            -- same pet/category name. Preserve any unique variants from the older folder before
            -- deleting it; same-name children deliberately remain with the newer folder.
            if child:IsA("Folder") and keeper:IsA("Folder") then
                for _, grandchild in ipairs(child:GetChildren()) do
                    if not keeper:FindFirstChild(grandchild.Name) then
                        grandchild.Parent = keeper
                    end
                end
            end
            table.insert(deduplicated, child:GetFullName())
            child:Destroy()
        else
            seen[child.Name] = child
        end
    end
end

for _, root in ipairs(roots) do
    local missionTiles = root:FindFirstChild("MissionTiles")
    if missionTiles then
        table.insert(removed, missionTiles:GetFullName())
        missionTiles:Destroy()
    end

    deduplicateChildren(root:FindFirstChild("Eggs"))
    deduplicateChildren(root:FindFirstChild("Flora"))

    local pets = root:FindFirstChild("Pets")
    if pets then
        deduplicateChildren(pets)
        for _, petType in ipairs(pets:GetChildren()) do
            deduplicateChildren(petType)
        end
    end

    local breakables = root:FindFirstChild("Breakables")
    if breakables then
        deduplicateChildren(breakables)
        for _, category in ipairs(breakables:GetChildren()) do
            deduplicateChildren(category)
        end
    end
end

fs.writeFile(outputPath, roblox.serializeModel(roots))
print(string.format("sanitized %s -> %s", inputPath, outputPath))
if #removed == 0 then
    print("no runtime-only caches were present")
else
    for _, name in ipairs(removed) do
        print("removed " .. name)
    end
end
if #deduplicated > 0 then
    for _, name in ipairs(deduplicated) do
        print("removed older duplicate " .. name)
    end
end
