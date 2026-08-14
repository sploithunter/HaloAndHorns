--[[ Sanity-check a pre-baked Assets.Models .rbxm before committing it.
     Prints the folder tree + model counts and flags empty ASSET ROOTS (parts=0), which is the
     tell-tale of a bad save (Edit-mode InsertService content that didn't serialize). Empty nested
     organizational Models are informational only; some uploaded assets legitimately contain one.

     Also rejects runtime-only MissionTiles and reports the rigged pet variants carried by the bake.

     Usage (NO `--` separator; lune passes it through as args[1]):
       lune run scripts/prebake/summarize_prebake.luau <saved.rbxm> [configs_dir]
]]
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local process = require("@lune/process")

local path = process.args[1]
assert(path, "usage: lune run summarize_prebake.luau <saved.rbxm>")
local objs = roblox.deserializeModel(fs.readFile(path))

local total, nestedEmpty = 0, 0
local nestedEmptyNames = {}
local function walk(inst, depth)
    for _, c in ipairs(inst:GetChildren()) do
        if c:IsA("Model") then
            total += 1
            local hasPart = false
            for _, d in ipairs(c:GetDescendants()) do
                if d:IsA("BasePart") then
                    hasPart = true
                    break
                end
            end
            if not hasPart then
                nestedEmpty += 1
                if #nestedEmptyNames < 15 then
                    table.insert(nestedEmptyNames, c:GetFullName())
                end
            end
        end
        if depth < 4 then
            walk(c, depth + 1)
        end
    end
end

local function hasPart(model)
    return model:FindFirstChildWhichIsA("BasePart", true) ~= nil
end

local function addModelChildren(folder, into)
    if not folder then
        return
    end
    for _, child in ipairs(folder:GetChildren()) do
        if child:IsA("Model") then
            table.insert(into, child)
        end
    end
end

local function collectAssetRoots(root)
    local roots = {}
    addModelChildren(root:FindFirstChild("Eggs"), roots)
    addModelChildren(root:FindFirstChild("Flora"), roots)

    local pets = root:FindFirstChild("Pets")
    if pets then
        for _, petType in ipairs(pets:GetChildren()) do
            addModelChildren(petType, roots)
        end
    end

    local breakables = root:FindFirstChild("Breakables")
    if breakables then
        for _, category in ipairs(breakables:GetChildren()) do
            addModelChildren(category, roots)
        end
    end
    return roots
end

local function findDuplicateChildren(parent, into)
    if not parent then
        return
    end
    local counts = {}
    for _, child in ipairs(parent:GetChildren()) do
        counts[child.Name] = (counts[child.Name] or 0) + 1
    end
    for name, count in pairs(counts) do
        if count > 1 then
            table.insert(into, string.format("%s.%s x%d", parent:GetFullName(), name, count))
        end
    end
end

local function collectDuplicateAssetPaths(root)
    local duplicates = {}
    findDuplicateChildren(root:FindFirstChild("Eggs"), duplicates)
    findDuplicateChildren(root:FindFirstChild("Flora"), duplicates)

    local pets = root:FindFirstChild("Pets")
    findDuplicateChildren(pets, duplicates)
    if pets then
        for _, petType in ipairs(pets:GetChildren()) do
            findDuplicateChildren(petType, duplicates)
        end
    end

    local breakables = root:FindFirstChild("Breakables")
    findDuplicateChildren(breakables, duplicates)
    if breakables then
        for _, category in ipairs(breakables:GetChildren()) do
            findDuplicateChildren(category, duplicates)
        end
    end
    return duplicates
end

print("=== pre-bake summary: " .. path .. " ===")
local assetRoots = {}
local runtimeOnly = {}
local duplicateAssetPaths = {}
for _, o in ipairs(objs) do
    print(string.format("root: %s (%s)", o.Name, o.ClassName))
    for _, c in ipairs(o:GetChildren()) do
        print(string.format("  %s (%s) children=%d", c.Name, c.ClassName, #c:GetChildren()))
    end
    walk(o, 0)
    for _, model in ipairs(collectAssetRoots(o)) do
        table.insert(assetRoots, model)
    end
    local missionTiles = o:FindFirstChild("MissionTiles")
    if missionTiles then
        table.insert(runtimeOnly, missionTiles:GetFullName())
    end
    for _, duplicate in ipairs(collectDuplicateAssetPaths(o)) do
        table.insert(duplicateAssetPaths, duplicate)
    end
end

local emptyRoots = {}
local rigged = {}
local badRigs = {}
for _, model in ipairs(assetRoots) do
    if not hasPart(model) then
        table.insert(emptyRoots, model:GetFullName())
    end

    local hasBones = model:FindFirstChildWhichIsA("Bone", true) ~= nil
    local rigClass = model:GetAttribute("RigClass")
    if hasBones or rigClass ~= nil then
        table.insert(rigged, model:GetFullName())
        if not hasBones or not model:FindFirstChildWhichIsA("AnimationController", true) then
            table.insert(badRigs, model:GetFullName())
        end
    end
end

print(string.format("\nMODELS total=%d  nestedEmpty=%d", total, nestedEmpty))
print(
    string.format(
        "ASSET_ROOTS total=%d  withParts=%d  EMPTY=%d",
        #assetRoots,
        #assetRoots - #emptyRoots,
        #emptyRoots
    )
)
print(string.format("RIGGED_ASSET_ROOTS total=%d  invalid=%d", #rigged, #badRigs))

if nestedEmpty > 0 then
    print("ℹ️  empty nested organizational models (not asset roots):")
    for _, n in ipairs(nestedEmptyNames) do
        print("   " .. n)
    end
end
if #rigged > 0 then
    print("✅ rigged pet assets:")
    for _, n in ipairs(rigged) do
        print("   " .. n)
    end
end

if #emptyRoots > 0 then
    print("❌ EMPTY asset roots (bad save — content didn't serialize):")
    for _, n in ipairs(emptyRoots) do
        print("   " .. n)
    end
    print("   → re-save from a FULLY-BOOTED runtime session (not Edit mode).")
end
if #badRigs > 0 then
    print("❌ invalid rigs (every rig needs Bones + AnimationController):")
    for _, n in ipairs(badRigs) do
        print("   " .. n)
    end
end
if #runtimeOnly > 0 then
    print("❌ runtime-only folders must be sanitized before commit:")
    for _, n in ipairs(runtimeOnly) do
        print("   " .. n)
    end
end
if #duplicateAssetPaths > 0 then
    print("❌ duplicate asset paths make FindFirstChild nondeterministic:")
    for _, n in ipairs(duplicateAssetPaths) do
        print("   " .. n)
    end
end

assert(#emptyRoots == 0, "prebake has empty asset roots")
assert(#badRigs == 0, "prebake has invalid rigged assets")
assert(#runtimeOnly == 0, "prebake contains runtime-only caches")
assert(#duplicateAssetPaths == 0, "prebake contains duplicate asset paths")
print("✅ prebake asset roots and rigs are safe to commit.")
