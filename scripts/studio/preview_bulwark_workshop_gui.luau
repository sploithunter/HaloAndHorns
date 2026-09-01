-- Edit-mode mock of the Merge bulwark workshop. Safe to re-run; it replaces
-- StarterGui.MergeBulwarkWorkshopMock only. Not a live gameplay GUI.
-- Layout is scale-first so the same tree holds on phones and desktop.

local Selection = game:GetService("Selection")
local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ROOT_NAME = "MergeBulwarkWorkshopMock"

local FAMILIES = {
	{ folder = "ImpalerPalisade", name = "Impaler Palisade", role = "Stop", color = Color3.fromRGB(210, 145, 55), copy = "Stakes the strip. Marchers that hit the line take a burst and get shoved back toward the gate." },
	{ folder = "ConcertinaLine", name = "Concertina Line", role = "Bleed", color = Color3.fromRGB(125, 135, 155), copy = "Razor wire across the lane. Anything that keeps walking the strip takes damage for as long as it stays on it." },
	{ folder = "LandShark", name = "Land Sharks", role = "Hunt", color = Color3.fromRGB(42, 145, 170), copy = "Sharks travel the strip and bite the nearest marcher. They chase instead of sitting still." },
	{ folder = "SawBlade", name = "Saw Blades", role = "Shred", color = Color3.fromRGB(220, 70, 75), copy = "Spinning blades chew anything on the line. Highest raw damage, no control." },
	{ folder = "GraspingHedge", name = "Grasping Hedge", role = "Hold", color = Color3.fromRGB(70, 170, 90), copy = "Thorns grab the front of the wave and slow it so your pets can finish the pile." },
	{ folder = "WardstoneBarrier", name = "Wardstone Barrier", role = "Ward", color = Color3.fromRGB(125, 90, 205), copy = "Wards the hatcher eggs, not the lane. Cuts damage that gets past the fight and hits an installed egg." },
}

local function corner(parent, radius)
	local value = Instance.new("UICorner")
	value.CornerRadius = UDim.new(0, radius)
	value.Parent = parent
	return value
end

local function stroke(parent, color, thickness)
	local value = Instance.new("UIStroke")
	value.Color = color
	value.Thickness = thickness or 2
	value.Parent = parent
	return value
end

local function padScale(parent, left, right, top, bottom)
	local value = Instance.new("UIPadding")
	value.PaddingLeft = UDim.new(left, 0)
	value.PaddingRight = UDim.new(right, 0)
	value.PaddingTop = UDim.new(top, 0)
	value.PaddingBottom = UDim.new(bottom, 0)
	value.Parent = parent
	return value
end

local function fill(parent)
	local item = Instance.new("UIFlexItem")
	item.FlexMode = Enum.UIFlexMode.Fill
	item.Parent = parent
	return item
end

local function aspect(parent, ratio)
	local value = Instance.new("UIAspectRatioConstraint")
	value.AspectRatio = ratio
	value.Parent = parent
	return value
end

local function textLimit(parent, maxSize)
	local value = Instance.new("UITextSizeConstraint")
	value.MaxTextSize = maxSize
	value.MinTextSize = 10
	value.Parent = parent
	return value
end

local function label(parent, name, text, size, bold)
	local value = Instance.new("TextLabel")
	value.Name = name
	value.Size = size or UDim2.fromScale(1, 1)
	value.BackgroundTransparency = 1
	value.Font = bold and Enum.Font.GothamBlack or Enum.Font.Gotham
	value.Text = text
	value.TextColor3 = Color3.new(1, 1, 1)
	value.TextScaled = true
	value.TextWrapped = true
	value.TextXAlignment = Enum.TextXAlignment.Left
	value.Parent = parent
	return value
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
gui.DisplayOrder = 200
gui.Enabled = true
gui:SetAttribute("MergeWorkshopMock", true)

local overlay = Instance.new("Frame")
overlay.Name = "Overlay"
overlay.Size = UDim2.fromScale(1, 1)
overlay.BackgroundColor3 = Color3.fromRGB(4, 7, 14)
overlay.BackgroundTransparency = 0.35
overlay.BorderSizePixel = 0
overlay.Parent = gui

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromScale(0.86, 0.84)
panel.BackgroundColor3 = Color3.fromRGB(20, 26, 38)
panel.BorderSizePixel = 0
panel.Parent = overlay
corner(panel, 18)
stroke(panel, Color3.fromRGB(245, 190, 65), 4)
padScale(panel, 0.018, 0.018, 0.022, 0.022)
local column = Instance.new("UIListLayout")
column.FillDirection = Enum.FillDirection.Vertical
column.Padding = UDim.new(0.014, 0)
column.SortOrder = Enum.SortOrder.LayoutOrder
column.Parent = panel

local titleBar = Instance.new("Frame")
titleBar.Name = "TitleBar"
titleBar.Size = UDim2.new(1, 0, 0.07, 0)
titleBar.BackgroundColor3 = Color3.fromRGB(12, 17, 26)
titleBar.BorderSizePixel = 0
titleBar.LayoutOrder = 1
titleBar.Parent = panel
corner(titleBar, 12)
padScale(titleBar, 0.02, 0.012, 0.12, 0.12)
local titleSplit = Instance.new("UIListLayout")
titleSplit.FillDirection = Enum.FillDirection.Horizontal
titleSplit.VerticalAlignment = Enum.VerticalAlignment.Center
titleSplit.Padding = UDim.new(0.012, 0)
titleSplit.SortOrder = Enum.SortOrder.LayoutOrder
titleSplit.Parent = titleBar
local title = label(titleBar, "Title", "BULWARK WORKSHOP", UDim2.new(1, 0, 1, 0), true)
title.LayoutOrder = 1
title.TextColor3 = Color3.fromRGB(255, 211, 95)
fill(title)
textLimit(title, 28)
local close = Instance.new("TextButton")
close.Name = "Close"
close.Size = UDim2.fromScale(0.08, 1)
close.BackgroundColor3 = Color3.fromRGB(105, 50, 60)
close.BorderSizePixel = 0
close.Font = Enum.Font.GothamBlack
close.Text = "X"
close.TextColor3 = Color3.new(1, 1, 1)
close.TextScaled = true
close.LayoutOrder = 2
close.Parent = titleBar
corner(close, 8)
aspect(close, 1)
textLimit(close, 20)

local status = label(panel, "Status", "NO BULWARK INSTALLED  •  WALLET 0", UDim2.new(1, 0, 0.045, 0), true)
status.BackgroundTransparency = 0
status.BackgroundColor3 = Color3.fromRGB(38, 47, 62)
status.TextXAlignment = Enum.TextXAlignment.Center
status.LayoutOrder = 2
corner(status, 8)
textLimit(status, 18)

local hint = label(panel, "Hint", "PLAYTEST: AVAILABLE FROM WAVE 1  •  EVERY CHANGE COSTS 1 WAYCOIN", UDim2.new(1, 0, 0.032, 0), false)
hint.TextColor3 = Color3.fromRGB(175, 190, 208)
hint.LayoutOrder = 3
textLimit(hint, 15)

local top = Instance.new("Frame")
top.Name = "Top"
top.Size = UDim2.new(1, 0, 0.52, 0)
top.BackgroundTransparency = 1
top.LayoutOrder = 4
top.Parent = panel
fill(top)
local topSplit = Instance.new("UIListLayout")
topSplit.FillDirection = Enum.FillDirection.Horizontal
topSplit.Padding = UDim.new(0.016, 0)
topSplit.SortOrder = Enum.SortOrder.LayoutOrder
topSplit.Parent = top

local previewPane = Instance.new("Frame")
previewPane.Name = "PreviewPane"
previewPane.Size = UDim2.new(0.54, 0, 1, 0)
previewPane.BackgroundColor3 = Color3.fromRGB(15, 22, 34)
previewPane.BorderSizePixel = 0
previewPane.ClipsDescendants = true
previewPane.LayoutOrder = 1
previewPane.Parent = top
fill(previewPane)
corner(previewPane, 14)
stroke(previewPane, Color3.fromRGB(61, 75, 98), 2)

local viewport = Instance.new("ViewportFrame")
viewport.Name = "Preview"
viewport.Size = UDim2.fromScale(1, 1)
viewport.BackgroundColor3 = Color3.fromRGB(15, 22, 34)
viewport.BorderSizePixel = 0
viewport.Ambient = Color3.fromRGB(180, 190, 210)
viewport.LightColor = Color3.fromRGB(255, 236, 200)
viewport.LightDirection = Vector3.new(-0.4, -0.7, -0.6)
viewport.Parent = previewPane
local world = Instance.new("WorldModel")
world.Name = "PreviewWorld"
world.Parent = viewport

local list = Instance.new("ScrollingFrame")
list.Name = "Families"
list.Size = UDim2.new(0.46, 0, 1, 0)
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.ClipsDescendants = true
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.CanvasSize = UDim2.fromScale(0, 0)
list.ScrollBarImageColor3 = Color3.fromRGB(255, 211, 95)
list.ScrollBarThickness = 8
list.ScrollingDirection = Enum.ScrollingDirection.Y
list.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
list.LayoutOrder = 2
list.Parent = top
fill(list)
local listLayout = Instance.new("UIListLayout")
listLayout.FillDirection = Enum.FillDirection.Vertical
listLayout.Padding = UDim.new(0.03, 0)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = list

for index, family in ipairs(FAMILIES) do
	local row = Instance.new("TextButton")
	row.Name = "Family" .. index
	-- Fixed fraction of the visible list, not flex-fill, so extra families scroll.
	row.Size = UDim2.new(1, 0, 0.2, 0)
	row.BackgroundColor3 = index == 1 and Color3.fromRGB(42, 36, 20) or Color3.fromRGB(28, 36, 51)
	row.BorderSizePixel = 0
	row.AutoButtonColor = false
	row.Text = ""
	row.LayoutOrder = index
	row.Parent = list
	corner(row, 10)
	stroke(row, index == 1 and Color3.fromRGB(255, 229, 110) or Color3.fromRGB(61, 75, 98), 2)
	-- Inset chrome from the row rim so swatch + cost never sit on the stroke.
	padScale(row, 0.035, 0.035, 0.16, 0.16)
	local rowSplit = Instance.new("UIListLayout")
	rowSplit.FillDirection = Enum.FillDirection.Horizontal
	rowSplit.VerticalAlignment = Enum.VerticalAlignment.Center
	rowSplit.Padding = UDim.new(0.03, 0)
	rowSplit.SortOrder = Enum.SortOrder.LayoutOrder
	rowSplit.Parent = row

	local swatch = Instance.new("Frame")
	swatch.Name = "Swatch"
	swatch.Size = UDim2.fromScale(0.12, 1)
	swatch.BackgroundColor3 = family.color
	swatch.BorderSizePixel = 0
	swatch.LayoutOrder = 1
	swatch.Parent = row
	corner(swatch, 8)
	aspect(swatch, 1)

	local copy = Instance.new("Frame")
	copy.Name = "Copy"
	copy.Size = UDim2.fromScale(0.7, 1)
	copy.BackgroundTransparency = 1
	copy.LayoutOrder = 2
	copy.Parent = row
	fill(copy)
	local copySplit = Instance.new("UIListLayout")
	copySplit.FillDirection = Enum.FillDirection.Vertical
	copySplit.VerticalAlignment = Enum.VerticalAlignment.Center
	copySplit.Padding = UDim.new(0.06, 0)
	copySplit.Parent = copy
	local name = label(copy, "FamilyName", string.upper(family.name), UDim2.new(1, 0, 0.56, 0), true)
	name.LayoutOrder = 1
	textLimit(name, 16)
	local role = label(copy, "Role", string.upper(family.role), UDim2.new(1, 0, 0.38, 0), false)
	role.LayoutOrder = 2
	role.TextColor3 = Color3.fromRGB(175, 190, 208)
	textLimit(role, 13)

	local cost = label(row, "Cost", "1", UDim2.fromScale(0.14, 0.82), true)
	cost.BackgroundTransparency = 0
	cost.BackgroundColor3 = Color3.fromRGB(225, 151, 22)
	cost.TextColor3 = Color3.fromRGB(26, 18, 4)
	cost.TextXAlignment = Enum.TextXAlignment.Center
	cost.LayoutOrder = 3
	corner(cost, 13)
	aspect(cost, 1)
	textLimit(cost, 16)
end

local bottom = Instance.new("Frame")
bottom.Name = "Bottom"
bottom.Size = UDim2.new(1, 0, 0.175, 0)
bottom.BackgroundTransparency = 1
bottom.LayoutOrder = 5
bottom.Parent = panel
local bottomSplit = Instance.new("UIListLayout")
bottomSplit.FillDirection = Enum.FillDirection.Horizontal
bottomSplit.Padding = UDim.new(0.016, 0)
bottomSplit.SortOrder = Enum.SortOrder.LayoutOrder
bottomSplit.Parent = bottom

local copyFrame = Instance.new("Frame")
copyFrame.Name = "CopyFrame"
copyFrame.Size = UDim2.new(0.54, 0, 1, 0)
copyFrame.BackgroundColor3 = Color3.fromRGB(15, 22, 34)
copyFrame.BorderSizePixel = 0
copyFrame.LayoutOrder = 1
copyFrame.Parent = bottom
fill(copyFrame)
corner(copyFrame, 14)
stroke(copyFrame, Color3.fromRGB(61, 75, 98), 2)
padScale(copyFrame, 0.04, 0.04, 0.1, 0.1)
local copyCol = Instance.new("UIListLayout")
copyCol.FillDirection = Enum.FillDirection.Vertical
copyCol.Padding = UDim.new(0.06, 0)
copyCol.SortOrder = Enum.SortOrder.LayoutOrder
copyCol.Parent = copyFrame
local selectedName = label(copyFrame, "SelectedName", "IMPALER PALISADE", UDim2.new(1, 0, 0.22, 0), true)
selectedName.LayoutOrder = 1
textLimit(selectedName, 20)
local selectedRole = label(copyFrame, "SelectedRole", "STOP", UDim2.new(0.22, 0, 0.2, 0), true)
selectedRole.LayoutOrder = 2
selectedRole.BackgroundTransparency = 0
selectedRole.BackgroundColor3 = Color3.fromRGB(42, 51, 68)
selectedRole.TextColor3 = Color3.fromRGB(255, 211, 95)
selectedRole.TextXAlignment = Enum.TextXAlignment.Center
corner(selectedRole, 10)
textLimit(selectedRole, 13)
local selectedCopy = label(copyFrame, "SelectedDescription", FAMILIES[1].copy, UDim2.new(1, 0, 0.46, 0), false)
selectedCopy.LayoutOrder = 3
selectedCopy.TextColor3 = Color3.fromRGB(197, 208, 222)
selectedCopy.TextYAlignment = Enum.TextYAlignment.Top
fill(selectedCopy)
textLimit(selectedCopy, 15)

local upgradeFrame = Instance.new("Frame")
upgradeFrame.Name = "UpgradeFrame"
upgradeFrame.Size = UDim2.new(0.46, 0, 1, 0)
upgradeFrame.BackgroundColor3 = Color3.fromRGB(15, 22, 34)
upgradeFrame.BorderSizePixel = 0
upgradeFrame.LayoutOrder = 2
upgradeFrame.Parent = bottom
fill(upgradeFrame)
corner(upgradeFrame, 14)
stroke(upgradeFrame, Color3.fromRGB(61, 75, 98), 2)
padScale(upgradeFrame, 0.045, 0.045, 0.1, 0.1)
local upgrade = Instance.new("TextButton")
upgrade.Name = "Upgrade"
upgrade.Size = UDim2.fromScale(1, 1)
upgrade.BackgroundColor3 = Color3.fromRGB(68, 74, 86)
upgrade.BorderSizePixel = 0
upgrade.Font = Enum.Font.GothamBlack
upgrade.Text = "INSTALL A BULWARK FIRST"
upgrade.TextColor3 = Color3.fromRGB(213, 219, 227)
upgrade.TextScaled = true
upgrade.TextWrapped = true
upgrade.AutoButtonColor = false
upgrade.Parent = upgradeFrame
corner(upgrade, 12)
stroke(upgrade, Color3.fromRGB(110, 118, 132), 2)
textLimit(upgrade, 18)

local install = Instance.new("TextButton")
install.Name = "Install"
install.Size = UDim2.new(1, 0, 0.078, 0)
install.BackgroundColor3 = Color3.fromRGB(225, 151, 22)
install.BorderSizePixel = 0
install.Font = Enum.Font.GothamBlack
install.Text = "INSTALL TIER 1  •  1"
install.TextColor3 = Color3.fromRGB(26, 18, 4)
install.TextScaled = true
install.LayoutOrder = 6
install.Parent = panel
corner(install, 14)
stroke(install, Color3.fromRGB(255, 229, 110), 3)
textLimit(install, 22)

local templates = ReplicatedStorage:FindFirstChild("Assets")
templates = templates and templates:FindFirstChild("Models")
templates = templates and templates:FindFirstChild("MergeBulwarks")
local source = templates and templates:FindFirstChild("ImpalerPalisade")
source = source and source:FindFirstChild("Tier1")
if source then
	local clone = source:Clone()
	clone.Name = "PreviewModel"
	clone.Parent = world
	local cf = clone:GetBoundingBox()
	clone:PivotTo(CFrame.new() * cf:ToObjectSpace(clone:GetPivot()))
	-- Underside faces +Z after align; pitch 90 so the side faces the camera.
	clone:PivotTo(CFrame.Angles(math.rad(90), 0, 0) * clone:GetPivot())
	cf = clone:GetBoundingBox()
	clone:PivotTo(CFrame.new(-cf.Position) * clone:GetPivot())
	local _, size = clone:GetBoundingBox()
	local camera = Instance.new("Camera")
	camera.Name = "PreviewCamera"
	local fov = 30
	local worldHeight = math.max(size.Y, size.Z)
	local fit = math.max(size.X, worldHeight) * 1.22
	local distance = (fit * 0.5) / math.tan(math.rad(fov * 0.5))
	camera.FieldOfView = fov
	camera.CFrame = CFrame.lookAt(
		Vector3.new(0, worldHeight * 0.08, distance),
		Vector3.new(0, 0, 0)
	)
	camera.Parent = viewport
	viewport.CurrentCamera = camera
end

gui.Parent = StarterGui
Selection:Set({ gui })
return gui:GetFullName()
