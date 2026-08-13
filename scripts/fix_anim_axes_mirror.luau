--!strict
-- EXPERIMENT (2026-08-13): full mirror correction for anim2rbx output — the standard
-- 180°-Y conjugation (fix_anim_axes.luau) PLUS left/right bone-channel swap.
-- Hypothesis: the FBX->Roblox convention error is a true mirror across the X=0 plane;
-- conjugation alone leaves each side playing the OTHER side's motion (subtle wrong
-- footfall pattern on quadrupeds; invisible phase shift on symmetric bipeds).
--
-- Usage: lune run scripts/fix_anim_axes_mirror.luau <in.rbxm> <out.rbxm>

local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local inPath = process.args[1]
local outPath = process.args[2]
if not inPath or not outPath then
	print("usage: lune run scripts/fix_anim_axes_mirror.luau <in.rbxm> <out.rbxm>")
	process.exit(1)
end

local CFrame = roblox.CFrame :: any
local FLIP = CFrame.Angles(0, math.pi, 0)
local FLIP_INV = FLIP:Inverse()

local model = roblox.deserializeModel(fs.readFile(inPath))

-- Meshy skeleton convention: right-side bones carry an "R_" prefix.
local function mirrorName(name: string): string
	if name:sub(1, 2) == "R_" then
		return name:sub(3)
	end
	return "R_" .. name
end

local fixed = 0
local swapped = 0
local function walk(inst: any, siblings: { any }?)
	local children = inst:GetChildren()
	-- collect Pose children by name for pair swapping at this level
	local poseByName: { [string]: any } = {}
	for _, child in ipairs(children) do
		if child.ClassName == "Pose" then
			poseByName[child.Name] = child
		end
	end
	local renamed: { [any]: string } = {}
	for _, child in ipairs(children) do
		if child.ClassName == "Pose" then
			local cf = child.CFrame
			local rot = cf - cf.Position
			child.CFrame = CFrame.new(FLIP * cf.Position) * (FLIP * rot * FLIP_INV)
			fixed += 1
			local paired = mirrorName(child.Name)
			if paired ~= child.Name and poseByName[paired] then
				renamed[child] = paired
			end
		end
		walk(child)
	end
	for child, newName in pairs(renamed) do
		child.Name = newName
		swapped += 1
	end
end

local sequences = 0
for _, root in ipairs(model) do
	if root.ClassName == "KeyframeSequence" then
		sequences += 1
		walk(root)
	end
end

if sequences == 0 then
	print("ERROR: no KeyframeSequence found in " .. inPath)
	process.exit(1)
end

fs.writeFile(outPath, roblox.serializeModel(model))
print(("fixed %d poses, swapped %d L/R channels in %d sequence(s) -> %s"):format(fixed, swapped, sequences, outPath))
