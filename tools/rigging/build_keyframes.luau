--!strict
-- Build a Roblox KeyframeSequence rbxm directly from Blender pose deltas
-- (walk_pose_deltas.json) — bypassing anim2rbx entirely. Pose.CFrame is the
-- bone-local delta (matrix_basis); Roblox applies Pose as Bone.Transform in
-- the bone's own rest frame, which for a same-FBX rig is the same frame.
--
-- Usage: lune run build_keyframes.luau <deltas.json> <out.rbxm> [mode]
--   mode: raw | flip  (flip = conjugate every delta by 180-Y, fallback)

local fs = require("@lune/fs")
local serde = require("@lune/serde")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local inPath = process.args[1]
local outPath = process.args[2]
local mode = process.args[3] or "raw"

local data = serde.decode("json", fs.readFile(inPath))
local hierarchy: { [string]: string } = data.hierarchy
local frames = data.frames

local CFrame = roblox.CFrame :: any
local Vector3 = roblox.Vector3 :: any
local Instance = roblox.Instance :: any
local Enum = roblox.Enum :: any

local FLIP = CFrame.Angles(0, math.pi, 0)
local FLIP_INV = FLIP:Inverse()

local ks = Instance.new("KeyframeSequence")
ks.Name = "quadruped_walking_doggy_direct"
ks.Loop = true
ks.Priority = Enum.AnimationPriority.Core

-- children lists for hierarchy building
local childrenOf: { [string]: { string } } = {}
local roots: { string } = {}
for bone, parent in pairs(hierarchy) do
	if parent == "" then
		table.insert(roots, bone)
	else
		childrenOf[parent] = childrenOf[parent] or {}
		table.insert(childrenOf[parent], bone)
	end
end

local built = 0
for _, frame in ipairs(frames) do
	local kf = Instance.new("Keyframe")
	kf.Name = string.format("%.3f", frame.time)
	kf.Time = frame.time
	kf.Parent = ks

	local function makePose(boneName: string, parentInst: any)
		local b = frame.bones[boneName]
		local pose = Instance.new("Pose")
		pose.Name = boneName
		pose.Weight = 1
		pose.EasingStyle = Enum.PoseEasingStyle.Linear
		if b then
			local q = b.quat -- w,x,y,z
			local cf = CFrame.new(b.pos[1], b.pos[2], b.pos[3], q[2], q[3], q[4], q[1])
			if mode == "flip" then
				local rot = cf - cf.Position
				cf = CFrame.new(FLIP * cf.Position) * (FLIP * rot * FLIP_INV)
			end
			pose.CFrame = cf
			built += 1
		end
		pose.Parent = parentInst
		for _, child in ipairs(childrenOf[boneName] or {}) do
			makePose(child, pose)
		end
	end

	for _, rootBone in ipairs(roots) do
		makePose(rootBone, kf)
	end
end

fs.writeFile(outPath, roblox.serializeModel({ ks }))
print(("mode=%s frames=%d poses=%d -> %s"):format(mode, #frames, built, outPath))