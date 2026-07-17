--[[
    rebuild_meshy_lineup.luau — Meshy decor QA against a wall.

    Destroys prior Workspace._MeshyLineup only (keeps _PropReview).

    Layout @ x≈20000:
      Wall A + Row A_MissionProps_SHIPPING  — backs to wall, fronts face -Z (open)
      Wall B + Row B_PropReview_TextureID   — same, further +Z

    Billboard labels: "#NN name / SHIP|REVIEW / SA|TEX"
    Camera ends on #01 SHIP front.

    Run in Studio Edit (MCP execute_luau or command bar).
]]

local RS = game:GetService("ReplicatedStorage")

local old = workspace:FindFirstChild("_MeshyLineup")
if old then
    old:Destroy()
end

local function strip(id)
    return (tostring(id or ""):gsub("^rbxassetid://", ""))
end

local function bindTag(inst)
    local mp = inst:FindFirstChildWhichIsA("MeshPart", true)
    if not mp then
        return "NO_MESH"
    end
    if mp:FindFirstChildWhichIsA("SurfaceAppearance") then
        return "SA"
    end
    if strip(mp.TextureID) ~= "" then
        return "TEX"
    end
    return "NONE"
end

local function adornPart(inst)
    if inst:IsA("BasePart") then
        return inst
    end
    local mp = inst:FindFirstChildWhichIsA("MeshPart", true)
    if mp then
        return mp
    end
    if inst:IsA("Model") and inst.PrimaryPart then
        return inst.PrimaryPart
    end
    return inst:FindFirstChildWhichIsA("BasePart", true)
end

local function addLabel(inst, text)
    for _, d in ipairs(inst:GetDescendants()) do
        if d.Name == "_QALabel" then
            d:Destroy()
        end
    end
    local existing = inst:FindFirstChild("_QALabel")
    if existing then
        existing:Destroy()
    end
    local mp = adornPart(inst)
    if not mp then
        return
    end
    local bb = Instance.new("BillboardGui")
    bb.Name = "_QALabel"
    bb.Size = UDim2.fromOffset(240, 56)
    bb.StudsOffset = Vector3.new(0, (mp.Size.Y * 0.5) + 2.2, 0)
    bb.AlwaysOnTop = true
    bb.MaxDistance = 250
    bb.Adornee = mp
    bb.Parent = inst
    local tl = Instance.new("TextLabel")
    tl.Size = UDim2.fromScale(1, 1)
    tl.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
    tl.BackgroundTransparency = 0.2
    tl.TextColor3 = Color3.new(1, 1, 1)
    tl.TextStrokeTransparency = 0.35
    tl.Font = Enum.Font.GothamBold
    tl.TextScaled = true
    tl.Text = text
    tl.Parent = bb
end

-- Face -Z by default (LookVector); bottom on y=0; back against zWallFace.
-- yawDeg 180 for meshes whose authored front is opposite LookVector.
local function placeAgainstWall(model, x, zWallFace, gap, yawDeg)
    yawDeg = yawDeg or 0
    model:PivotTo(CFrame.new(x, 0, 0) * CFrame.Angles(0, math.rad(yawDeg), 0))
    local function nudge()
        local pivot = model:GetPivot()
        local bboxCF, size = model:GetBoundingBox()
        local bottomY = bboxCF.Position.Y - size.Y * 0.5
        local zTowardWall = bboxCF.Position.Z + size.Z * 0.5
        local lift = -bottomY
        local zShift = (zWallFace - gap) - zTowardWall
        model:PivotTo(
            CFrame.new(x, pivot.Position.Y + lift, pivot.Position.Z + zShift)
                * (pivot - pivot.Position)
        )
    end
    nudge()
    nudge()
end

-- PropReview TextureID gens whose mesh LookVector is opposite art front
-- (Jason 2026-07-15 wall lineup: #7,8,9,15,16,17 REVIEW were backwards).
local REVIEW_YAW_DEG = {
    heaven_golden_guardian = 180,
    heaven_golden_throne = 180,
    heaven_ivory_throne = 180,
    hell_infernal_fountain = 180,
    hell_infernal_throne = 180,
    hell_infernal_throne_flat = 180,
}
assert(store, "MissionProps missing")
local names = {}
for _, c in ipairs(store:GetChildren()) do
    if string.find(c.Name, "^heaven_") or string.find(c.Name, "^hell_") then
        table.insert(names, c.Name)
    end
end
table.sort(names)

local root = Instance.new("Folder")
root.Name = "_MeshyLineup"
root.Parent = workspace

local rowA = Instance.new("Folder")
rowA.Name = "A_MissionProps_SHIPPING"
rowA.Parent = root
local rowB = Instance.new("Folder")
rowB.Name = "B_PropReview_TextureID"
rowB.Parent = root

local originX = 20000
local spacing = 14
local wallZ = 8
local gap = 0.15
local rowB_zWall = wallZ + 40
local n = #names
local wallWidth = spacing * (n - 1) + 20
local wallHeight = 18

local function makeWall(name, z, color)
    local wall = Instance.new("Part")
    wall.Name = name
    wall.Anchored = true
    wall.CanCollide = false
    wall.Size = Vector3.new(wallWidth, wallHeight, 1)
    wall.Color = color
    wall.Material = Enum.Material.SmoothPlastic
    wall.CFrame = CFrame.new(originX + spacing * (n - 1) * 0.5, wallHeight * 0.5, z)
    wall.Parent = root
    local floor = Instance.new("Part")
    floor.Name = name .. "_Floor"
    floor.Anchored = true
    floor.CanCollide = false
    floor.Size = Vector3.new(wallWidth, 0.2, 24)
    floor.Color = Color3.fromRGB(40, 44, 52)
    floor.Material = Enum.Material.SmoothPlastic
    floor.CFrame = CFrame.new(originX + spacing * (n - 1) * 0.5, 0.1, z - 12)
    floor.Parent = root
end

makeWall("Wall_A_SHIP", wallZ, Color3.fromRGB(55, 62, 78))
makeWall("Wall_B_REVIEW", rowB_zWall, Color3.fromRGB(78, 62, 45))

local prFolder = workspace:FindFirstChild("_PropReview")
    and workspace._PropReview:FindFirstChild("MeshyDecor")

for i, name in ipairs(names) do
    local x = originX + (i - 1) * spacing
    local srcA = store:FindFirstChild(name)
    if srcA then
        local clone = srcA:Clone()
        clone.Name = string.format("%02d_%s", i, name)
        placeAgainstWall(clone, x, wallZ, gap, 0)
        clone.Parent = rowA
        addLabel(clone, string.format("#%02d  %s\nSHIP  %s", i, name, bindTag(clone)))
    end
    local srcB = prFolder and prFolder:FindFirstChild(name)
    if srcB then
        local clone = srcB:Clone()
        clone.Name = string.format("%02d_%s", i, name)
        placeAgainstWall(clone, x, rowB_zWall, gap, REVIEW_YAW_DEG[name] or 0)
        clone.Parent = rowB
        addLabel(clone, string.format("#%02d  %s\nREVIEW  %s", i, name, bindTag(clone)))
    end
end

local first = rowA:FindFirstChild("01_heaven_archive")
if first then
    local pivot = first:GetPivot()
    local _, size = first:GetBoundingBox()
    local frontDir = pivot.LookVector
    local dist = math.max(size.Z, size.X) * 1.6 + 8
    local target = pivot.Position + Vector3.new(0, size.Y * 0.15, 0)
    local camPos = target + frontDir * dist
    local cam = workspace.CurrentCamera
    cam.CameraType = Enum.CameraType.Fixed
    cam.CFrame = CFrame.lookAt(camPos, target)
    game:GetService("Selection"):Set({ first })
end

return string.format("OK wall lineup: %d props × 2 rows (backs to wall, fronts -Z)", #names)
