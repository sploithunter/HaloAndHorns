-- Edit-mode six-family orientation board. Safe to re-run; it replaces only
-- StarterGui.MergeBulwarkOrientPreview. Every preview uses the production Spawn path and camera-only
-- framing, so this board catches top-down imports, close-up crops, and accidental preview transforms.

local Selection = game:GetService("Selection")
local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MergeBulwarkModels = require(ReplicatedStorage.Shared.Game.MergeBulwarkModels)
local ROOT_NAME = "MergeBulwarkOrientPreview"
local SHOTS = {
    { family = "impaler_palisade", label = "IMPALER PALISADE", yaw = 210, elev = 18 },
    { family = "concertina_line", label = "CONCERTINA LINE", yaw = 210, elev = 24 },
    { family = "land_shark", label = "LAND SHARK", yaw = 225, elev = 22 },
    { family = "saw_blade", label = "SAW BLADE", yaw = 210, elev = 20 },
    { family = "grasping_hedge", label = "GRASPING HEDGE", yaw = 210, elev = 18 },
    { family = "wardstone_barrier", label = "WARDSTONE BARRIER", yaw = 180, elev = 16 },
}

local function corner(parent, radius)
    local value = Instance.new("UICorner")
    value.CornerRadius = UDim.new(0, radius)
    value.Parent = parent
end

local function centerModel(model)
    local boxCf = model:GetBoundingBox()
    model:PivotTo(model:GetPivot() - boxCf.Position)
end

local function boxCorners(boxCf, size)
    local half = size * 0.5
    local result = {}
    for _, x in ipairs({ -1, 1 }) do
        for _, y in ipairs({ -1, 1 }) do
            for _, z in ipairs({ -1, 1 }) do
                result[#result + 1] =
                    boxCf:PointToWorldSpace(Vector3.new(half.X * x, half.Y * y, half.Z * z))
            end
        end
    end
    return result
end

local function fitCamera(camera, viewport, model, yawDeg, elevDeg)
    local boxCf, size = model:GetBoundingBox()
    local absolute = viewport.AbsoluteSize
    local ratio = if absolute.Y > 1 then math.max(0.5, absolute.X / absolute.Y) else 1.5
    local tangentV = math.tan(math.rad(16)) * 0.82
    local tangentH = tangentV * ratio
    local yaw = math.rad(yawDeg)
    local elev = math.rad(elevDeg)
    local direction = Vector3.new(
        math.sin(yaw) * math.cos(elev),
        math.sin(elev),
        math.cos(yaw) * math.cos(elev)
    ).Unit
    local distance = math.max(size.X, size.Y, size.Z) * 0.65
    local corners = boxCorners(boxCf, size)
    local cameraCf = CFrame.lookAt(direction * distance, Vector3.zero)
    for _ = 1, 32 do
        cameraCf = CFrame.lookAt(direction * distance, Vector3.zero)
        local fits = true
        for _, point in ipairs(corners) do
            local localPoint = cameraCf:PointToObjectSpace(point)
            local depth = -localPoint.Z
            if
                depth <= 0.01
                or math.abs(localPoint.X) > depth * tangentH
                or math.abs(localPoint.Y) > depth * tangentV
            then
                fits = false
                break
            end
        end
        if fits then
            break
        end
        distance *= 1.16
    end
    camera.FieldOfView = 32
    camera.CFrame = cameraCf
end

local existing = StarterGui:FindFirstChild(ROOT_NAME)
if existing then
    existing:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = ROOT_NAME
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 210
gui:SetAttribute("MergeOrientPreview", true)

local overlay = Instance.new("Frame")
overlay.Size = UDim2.fromScale(1, 1)
overlay.BackgroundColor3 = Color3.fromRGB(8, 12, 20)
overlay.BorderSizePixel = 0
overlay.Parent = gui

local grid = Instance.new("UIGridLayout")
grid.CellSize = UDim2.fromScale(0.31, 0.42)
grid.CellPadding = UDim2.fromScale(0.02, 0.04)
grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
grid.VerticalAlignment = Enum.VerticalAlignment.Center
grid.SortOrder = Enum.SortOrder.LayoutOrder
grid.Parent = overlay

for index, shot in ipairs(SHOTS) do
    local cell = Instance.new("Frame")
    cell.Name = shot.family
    cell.BackgroundColor3 = Color3.fromRGB(15, 22, 34)
    cell.BorderSizePixel = 0
    cell.LayoutOrder = index
    cell.Parent = overlay
    corner(cell, 14)

    local caption = Instance.new("TextLabel")
    caption.Size = UDim2.new(0.94, 0, 0.12, 0)
    caption.Position = UDim2.fromScale(0.03, 0.02)
    caption.BackgroundTransparency = 1
    caption.Font = Enum.Font.GothamBlack
    caption.Text = shot.label
    caption.TextColor3 = Color3.new(1, 1, 1)
    caption.TextScaled = true
    caption.Parent = cell

    local viewport = Instance.new("ViewportFrame")
    viewport.Position = UDim2.fromScale(0.04, 0.16)
    viewport.Size = UDim2.fromScale(0.92, 0.80)
    viewport.BackgroundColor3 = Color3.fromRGB(10, 14, 22)
    viewport.BorderSizePixel = 0
    viewport.Ambient = Color3.fromRGB(180, 190, 210)
    viewport.LightColor = Color3.fromRGB(255, 236, 200)
    viewport.LightDirection = Vector3.new(-0.4, -0.7, -0.6)
    viewport.Parent = cell
    corner(viewport, 10)

    local world = Instance.new("WorldModel")
    world.Parent = viewport
    local model, reason = MergeBulwarkModels.Spawn(shot.family, 1, CFrame.new(), world, nil, 1)
    assert(model, string.format("%s preview failed: %s", shot.family, tostring(reason)))
    centerModel(model)

    local camera = Instance.new("Camera")
    camera.Parent = viewport
    viewport.CurrentCamera = camera
    fitCamera(camera, viewport, model, shot.yaw, shot.elev)
end

gui.Parent = StarterGui
Selection:Set({ gui })
return gui:GetFullName()
