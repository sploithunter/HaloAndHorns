--!strict
-- Fix the FBX->Roblox axis convention in anim2rbx output: every Pose rotation comes out
-- mirrored 180° about the vertical axis (X and Z euler components negated, Y intact —
-- measured bone-by-bone against a known-good Animation Editor import of the same clip).
-- The correction is a conjugation by a 180° Y-rotation, applied to every Pose CFrame.
--
-- Usage: lune run scripts/fix_anim_axes.luau <in.rbxm> <out.rbxm>

local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local inPath = process.args[1]
local outPath = process.args[2]
if not inPath or not outPath then
	print("usage: lune run scripts/fix_anim_axes.luau <in.rbxm> <out.rbxm>")
	process.exit(1)
end

local CFrame = roblox.CFrame :: any
local FLIP = CFrame.Angles(0, math.pi, 0)
local FLIP_INV = FLIP:Inverse()

local model = roblox.deserializeModel(fs.readFile(inPath))

local fixed = 0
local function walk(inst: any)
	for _, child in ipairs(inst:GetChildren()) do
		if child.ClassName == "Pose" then
			local cf = child.CFrame
			local rot = cf - cf.Position
			child.CFrame = CFrame.new(FLIP * cf.Position) * (FLIP * rot * FLIP_INV)
			fixed += 1
		end
		walk(child)
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
print(("fixed %d poses in %d sequence(s) -> %s"):format(fixed, sequences, outPath))
