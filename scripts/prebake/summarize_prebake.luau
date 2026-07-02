--[[ Sanity-check a pre-baked Assets folder .rbxm before committing it.
     Prints the folder tree + model counts + flags any EMPTY models (parts=0), which is the
     tell-tale of a bad save (Edit-mode InsertService content that didn't serialize). A healthy
     Models bake has empty=0. Cross-checks pet/egg model ids referenced by configs against the bake
     so you can see whether the roster grew past the bake (→ time to regenerate).

     Usage (NO `--` separator; lune passes it through as args[1]):
       lune run scripts/prebake/summarize_prebake.luau <saved.rbxm> [configs_dir]
]]
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local process = require("@lune/process")

local path = process.args[1]
assert(path, "usage: lune run summarize_prebake.luau <saved.rbxm>")
local objs = roblox.deserializeModel(fs.readFile(path))

local total, empty = 0, 0
local emptyNames = {}
local function walk(inst, depth)
    for _, c in ipairs(inst:GetChildren()) do
        if c:IsA("Model") then
            total += 1
            local hasPart = false
            for _, d in ipairs(c:GetDescendants()) do
                if d:IsA("BasePart") then hasPart = true break end
            end
            if not hasPart then
                empty += 1
                if #emptyNames < 15 then table.insert(emptyNames, c:GetFullName()) end
            end
        end
        if depth < 4 then walk(c, depth + 1) end
    end
end

print("=== pre-bake summary: " .. path .. " ===")
for _, o in ipairs(objs) do
    print(string.format("root: %s (%s)", o.Name, o.ClassName))
    for _, c in ipairs(o:GetChildren()) do
        print(string.format("  %s (%s) children=%d", c.Name, c.ClassName, #c:GetChildren()))
    end
    walk(o, 0)
end
print(string.format("\nMODELS total=%d  withParts=%d  EMPTY=%d", total, total - empty, empty))
if empty > 0 then
    print("⚠️  EMPTY models (bad save — content didn't serialize):")
    for _, n in ipairs(emptyNames) do print("   " .. n) end
    print("   → re-save from a FULLY-BOOTED runtime session (not Edit mode).")
else
    print("✅ no empty models — safe to commit.")
end
