-- Edit-mode orientation board for Land Shark and Wardstone. Safe to re-run; it
-- replaces StarterGui.MergeBulwarkOrientPreview only. Not a live gameplay GUI.
-- Locked pair from the orbit board: shark CAM 225, wardstone CAM 180.

local Selection = game:GetService("Selection")
local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ROOT_NAME = "MergeBulwarkOrientPreview"

local SHOTS = {
	{ folder = "LandShark", label = "LAND SHARK  CAM 225", yaw = 225, elev = 22 },
	{ folder = "WardstoneBarrier", label = "WARDSTONE  CAM 180", yaw = 180, elev = 16 },
}

local function corner(parent, radius)
	local value = Instance.new("UICorner")
	value.CornerRadius = UDim.new(0, radius)
	value.Parent = parent
	return value
end

local function standModel(model)
	if model.PrimaryPart then
		model.PrimaryPart.PivotOffset = CFrame.new(model.PrimaryPart.PivotOffset.Position)
	end
	local boxCf, size = model:GetBoundingBox()
	model:PivotTo(CFrame.new() * boxCf:ToObjectSpace(model:GetPivot()))
	boxCf, size = model:GetBoundingBox()
	model:PivotTo(
		model:GetPivot()
			+ Vector3.new(-boxCf.Position.X, -(boxCf.Position.Y - size.Y * 0.5), -boxCf.Position.Z)
	)
	return select(2, model:GetBoundingBox())
end

local function placeCam(camera, size, yawDeg, elevDeg)
	local radius = math.max(size.X, size.Y, size.Z) * 1.35
	local elev = math.rad(elevDeg)
	local yaw = math.rad(yawDeg)
	local height = math.max(size.Y * 0.42, radius * math.sin(elev))
	local dist = radius * math.cos(elev)
	camera.FieldOfView = 32
	camera.CFrame = CFrame.lookAt(
		Vector3.new(math.sin(yaw) * dist, height, math.cos(yaw) * dist),
		Vector3.new(0, size.Y * 0.38, 0)
	)
end

local existing = StarterGui:FindFirstChild(ROOT_NAME)
if existing then
	existing:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = ROOT_NAME
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 210
gui.Enabled = true
gui:SetAttribute("MergeOrientPreview", true)

local overlay = Instance.new("Frame")
overlay.Name = "Overlay"
overlay.Size = UDim2.fromScale(1, 1)
overlay.BackgroundColor3 = Color3.fromRGB(8, 12, 20)
overlay.BorderSizePixel = 0
overlay.Parent = gui

local title = Instance.new("TextLabel")
title.Name = "Title"
title.Size = UDim2.new(1, 0, 0.06, 0)
title.Position = UDim2.fromScale(0.03, 0.02)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBlack
title.Text = "LOCKED  SHARK CAM 225   WARDSTONE CAM 180"
title.TextColor3 = Color3.fromRGB(255, 211, 95)
title.TextScaled = true
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = overlay

local row = Instance.new("Frame")
row.Name = "Row"
row.Position = UDim2.fromScale(0.04, 0.11)
row.Size = UDim2.fromScale(0.92, 0.82)
row.BackgroundTransparency = 1
row.Parent = overlay
local split = Instance.new("UIListLayout")
split.FillDirection = Enum.FillDirection.Horizontal
split.Padding = UDim.new(0.03, 0)
split.SortOrder = Enum.SortOrder.LayoutOrder
split.Parent = row

local templates = ReplicatedStorage:FindFirstChild("Assets")
templates = templates and templates:FindFirstChild("Models")
templates = templates and templates:FindFirstChild("MergeBulwarks")

for index, shot in ipairs(SHOTS) do
	local cell = Instance.new("Frame")
	cell.Name = shot.folder
	cell.Size = UDim2.fromScale(0.48, 1)
	cell.BackgroundColor3 = Color3.fromRGB(15, 22, 34)
	cell.BorderSizePixel = 0
	cell.LayoutOrder = index
	cell.Parent = row
	corner(cell, 14)

	local caption = Instance.new("TextLabel")
	caption.Name = "Caption"
	caption.Size = UDim2.new(0.94, 0, 0.08, 0)
	caption.Position = UDim2.fromScale(0.03, 0.02)
	caption.BackgroundTransparency = 1
	caption.Font = Enum.Font.GothamBlack
	caption.Text = shot.label
	caption.TextColor3 = Color3.new(1, 1, 1)
	caption.TextScaled = true
	caption.TextXAlignment = Enum.TextXAlignment.Left
	caption.Parent = cell

	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "Preview"
	viewport.Position = UDim2.fromScale(0.04, 0.12)
	viewport.Size = UDim2.fromScale(0.92, 0.84)
	viewport.BackgroundColor3 = Color3.fromRGB(10, 14, 22)
	viewport.BorderSizePixel = 0
	viewport.Ambient = Color3.fromRGB(180, 190, 210)
	viewport.LightColor = Color3.fromRGB(255, 236, 200)
	viewport.LightDirection = Vector3.new(-0.4, -0.7, -0.6)
	viewport.Parent = cell
	corner(viewport, 10)

	local world = Instance.new("WorldModel")
	world.Name = "PreviewWorld"
	world.Parent = viewport

	local folder = templates and templates:FindFirstChild(shot.folder)
	local source = folder and folder:FindFirstChild("Tier1")
	if source then
		local clone = source:Clone()
		clone.Name = "PreviewModel"
		clone.Parent = world
		local size = standModel(clone)
		local camera = Instance.new("Camera")
		camera.Name = "PreviewCamera"
		placeCam(camera, size, shot.yaw, shot.elev)
		camera.Parent = viewport
		viewport.CurrentCamera = camera
	end
end

gui.Parent = StarterGui
Selection:Set({ gui })
return gui:GetFullName()
