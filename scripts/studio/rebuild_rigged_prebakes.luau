--!strict
--[[
    Rebuild every RIGGED pet prebake in ReplicatedStorage.Assets.Models.Pets
    from the uploaded rig assets. Run via MCP execute_luau (Edit mode) or the
    command bar — paste the body, or require-style adapt.

    WHY THIS EXISTS (2026-07-14 post-mortem): assets/place/Models.rbxm was
    committed ONCE (July 2, initial import) — HOURS BEFORE the first rigged
    pet landed. Rojo serves that file at ReplicatedStorage.Assets.Models, so
    every Rojo re-serve silently replaced all hand-dropped rigged prebakes
    with the static July-2 snapshot (bones gone, AnimationController gone →
    "no animation at all", pets fall back to static/code-gait). The fix has
    two halves:
      1. this script — deterministic rebuild from the recorded rig assets
         (scripts/pet_rig_manifest.json + cinder_golemite), and
      2. CAPTURE: after rebuilding, Play until fully booted, right-click
         ReplicatedStorage.Assets.Models in the RUNNING game -> Save to File
         -> assets/place/Models.rbxm, commit. Until that capture is
         committed, every Rojo re-serve clobbers the rigs again and this
         script must be re-run.

    Per pet: LoadAsset(rigAsset) -> the Model inside carries the skinned
    char1 MeshPart + Bones + InitialPoses + AnimationController (textures
    embedded for all but cinder_golemite, which shares its static
    generation's atlas — same Meshy source, identical UVs). Normalize:
    PrimaryPart=char1, ensure Animator, uniform-scale so standing bbox
    height == the static prebake's height, pivot recentered to bbox CENTER
    (the 0.50 convention every working pet follows — PetFollowController
    measures pivot-to-feet from it), then replace <pet>.basic.
    golden/rainbow variants stay static (code gait) until variant rigs are
    minted.

    Rig assets come in UPRIGHT with the front on the pivot look axis — no
    rotation needed (the 2026-07-14 lying-down golemite was a hand-drop
    mishap, not an asset property).
]]

local InsertService = game:GetService("InsertService")
local pets = game:GetService("ReplicatedStorage").Assets.Models.Pets

-- petName -> { rig = assetId, height = standing bbox Y (matches the static
-- prebake so gameplay footprint is unchanged), tex = TextureID override for
-- rigs whose upload is untextured }
local RIGS: { [string]: { rig: number, height: number, tex: string? } } = {
	worldbloom_ent = { rig = 135208930872261, height = 4.49 },
	worldroot_ent = { rig = 107519892318201, height = 4.56 },
	ashmane_lion = { rig = 78366659327055, height = 2.35 },
	rimeguard_bear = { rig = 83903219841691, height = 2.69 },
	frostblight_lamb = { rig = 78432967884838, height = 2.72 },
	frostdust_camel = { rig = 74000437914712, height = 2.80 },
	frostgrave_ent = { rig = 132619230578005, height = 4.57 },
	gloom_hare = { rig = 136066082092506, height = 3.05 },
	rimegloom_hare = { rig = 99931014862135, height = 3.05 },
	rimewraith_dragon = { rig = 91096733870190, height = 6.34 },
	sunwell_camel = { rig = 132933270009914, height = 2.53 },
	cinder_golemite = { rig = 104860498147921, height = 2.40, tex = "rbxassetid://117265727136114" },
	cinderling_imp = { rig = 111624221245800, height = 2.66 },
	camel = { rig = 90279769761323, height = 2.62 },
}

for petName, spec in pairs(RIGS) do
	local ok, asset = pcall(function()
		return InsertService:LoadAsset(spec.rig)
	end)
	if not ok or not asset then
		warn(("[rebuild_rigged_prebakes] %s LOAD FAIL: %s"):format(petName, tostring(asset)))
		continue
	end
	local rigModel: Model?
	for _, c in ipairs(asset:GetChildren()) do
		if c:IsA("Model") and c:FindFirstChildWhichIsA("MeshPart", true) then
			rigModel = c
			break
		end
	end
	if not rigModel then
		warn(("[rebuild_rigged_prebakes] %s: no Model in asset"):format(petName))
		asset:Destroy()
		continue
	end
	rigModel.Parent = nil
	asset:Destroy()

	local mp = rigModel:FindFirstChildWhichIsA("MeshPart", true) :: MeshPart
	rigModel.PrimaryPart = mp
	mp.Anchored = true
	if spec.tex then
		mp.TextureID = spec.tex
	end
	local ac = rigModel:FindFirstChildWhichIsA("AnimationController", true)
	if not ac then
		ac = Instance.new("AnimationController")
		ac.Parent = rigModel
	end
	if not ac:FindFirstChildOfClass("Animator") then
		local animator = Instance.new("Animator")
		animator.Parent = ac
	end

	-- GetBoundingBox is PIVOT-aligned, and some rigs (cinderling_imp) arrive
	-- with a rotated char1 CFrame — normalize the pivot to world-identity
	-- FIRST so the height measurement/scale run in world axes.
	local cf0, _ = rigModel:GetBoundingBox()
	mp.PivotOffset = mp.CFrame:Inverse() * CFrame.new(cf0.Position)
	local _, size = rigModel:GetBoundingBox()
	rigModel:ScaleTo(rigModel:GetScale() * (spec.height / size.Y))
	local cf2, _ = rigModel:GetBoundingBox()
	mp.PivotOffset = mp.CFrame:Inverse() * CFrame.new(cf2.Position)

	local folder = pets:FindFirstChild(petName)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = petName
		folder.Parent = pets
	end
	local old = folder:FindFirstChild("basic")
	rigModel.Name = "basic"
	rigModel.Parent = folder
	if old then
		old:Destroy()
	end

	local bones = 0
	for _, d in ipairs(rigModel:GetDescendants()) do
		if d:IsA("Bone") then
			bones += 1
		end
	end
	print(("[rebuild_rigged_prebakes] %s: bones=%d height=%.2f tex=%s"):format(
		petName,
		bones,
		spec.height,
		mp.TextureID ~= "" and "yes" or "GREY"
	))
end

print("[rebuild_rigged_prebakes] done — now Play until booted and Save Assets.Models -> assets/place/Models.rbxm")
