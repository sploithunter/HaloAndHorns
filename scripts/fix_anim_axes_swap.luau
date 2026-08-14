--!strict
-- EXPERIMENT (2026-08-13): axis fix + configurable channel swap for anim2rbx output.
-- Applies the standard 180°-Y conjugation, then exchanges pose CFRAME VALUES between
-- paired bones per keyframe (values, not names — front/back pairs live at different
-- hierarchy depths, so renaming would corrupt the Pose tree).
--
-- Usage: lune run scripts/fix_anim_axes_swap.luau <in.rbxm> <out.rbxm> <lr|fb|both|none>

local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local inPath = process.args[1]
local outPath = process.args[2]
local mode = process.args[3] or "none"
local base = process.args[4] or "fix" -- "fix" applies the 180-Y conjugation; "nofix" skips it
if not inPath or not outPath then
	print("usage: lune run scripts/fix_anim_axes_swap.luau <in.rbxm> <out.rbxm> <lr|fb|both|none> [fix|nofix]")
	process.exit(1)
end

local CFrame = roblox.CFrame :: any
local FLIP = CFrame.Angles(0, math.pi, 0)
local FLIP_INV = FLIP:Inverse()

local model = roblox.deserializeModel(fs.readFile(inPath))

local function lrName(name: string): string
	if name:sub(1, 2) == "R_" then
		return name:sub(3)
	end
	return "R_" .. name
end

local function fbName(name: string): string?
	local prefix = ""
	local core = name
	if name:sub(1, 2) == "R_" then
		prefix = "R_"
		core = name:sub(3)
	end
	if core:sub(1, 8) == "frontleg" then
		return prefix .. "backleg" .. core:sub(9)
	end
	if core:sub(1, 7) == "backleg" then
		return prefix .. "frontleg" .. core:sub(8)
	end
	return nil
end

local function pairName(name: string): string?
	if mode == "lr" then
		return lrName(name)
	elseif mode == "fb" then
		return fbName(name)
	elseif mode == "both" then
		local n = fbName(name) or name
		return lrName(n)
	end
	return nil
end

local fixed = 0
local swapped = 0

local function collectPoses(inst: any, acc: { [string]: any })
	for _, child in ipairs(inst:GetChildren()) do
		if child.ClassName == "Pose" then
			acc[child.Name] = child
			if base == "fix" then
				local cf = child.CFrame
				local rot = cf - cf.Position
				child.CFrame = CFrame.new(FLIP * cf.Position) * (FLIP * rot * FLIP_INV)
				fixed += 1
			end
		end
		collectPoses(child, acc)
	end
end

local sequences = 0
for _, root in ipairs(model) do
	if root.ClassName == "KeyframeSequence" then
		sequences += 1
		-- each child of the sequence is one keyframe scope (don't trust ClassName
		-- across serializer versions); swap pose values WITHIN one keyframe only
		for _, kf in ipairs(root:GetChildren()) do
			local poses: { [string]: any } = {}
			collectPoses(kf, poses)
			if mode ~= "none" then
				local done: { [string]: boolean } = {}
				for name, pose in pairs(poses) do
					local mate = pairName(name)
					if mate and mate ~= name and poses[mate] and not done[name] and not done[mate] then
						local a, b = pose, poses[mate]
						a.CFrame, b.CFrame = b.CFrame, a.CFrame
						done[name] = true
						done[mate] = true
						swapped += 1
					end
				end
			end
		end
	end
end

if sequences == 0 then
	print("ERROR: no KeyframeSequence found in " .. inPath)
	process.exit(1)
end

fs.writeFile(outPath, roblox.serializeModel(model))
print(("mode=%s fixed=%d swapped-pairs=%d sequences=%d -> %s"):format(mode, fixed, swapped, sequences, outPath))
