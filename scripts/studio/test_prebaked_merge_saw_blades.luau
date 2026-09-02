-- Studio Edit-mode regression test for the four production Saw Blade templates.
-- Paste this file into the Command Bar while not playing. It uses the production spawn path,
-- leaves all four results in Workspace for visual inspection, and proves spawn never resizes them.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

assert(not RunService:IsRunning(), "run test_prebaked_merge_saw_blades.luau in Studio Edit mode")

local MergeBulwarkModels = require(ReplicatedStorage.Shared.Game.MergeBulwarkModels)
local tierArt = require(ReplicatedStorage.Configs.merge_tier_art)
local templates = assert(
    ReplicatedStorage.Assets.Models.MergeBulwarks:FindFirstChild("SawBlade"),
    "missing Models.rbxm SawBlade templates"
)

local previous = workspace:FindFirstChild("SawBladeModelsRbxmEditQA")
if previous then
    previous:Destroy()
end

local folder = Instance.new("Folder")
folder.Name = "SawBladeModelsRbxmEditQA"
folder.Parent = workspace

local ORIGIN = Vector3.new(0, 150, 0)
local EXPECTED_WIDTH = 9.4
local EXPECTED_SCALE = 0.047
local MAX_HEIGHT_OR_DEPTH = 6

for tier = 1, 4 do
    local template = assert(templates:FindFirstChild("Tier" .. tostring(tier)), "missing tier")
    assert(template:IsA("Model"), "tier template must be a Model")
    assert(
        template:GetAttribute("MergeBulwarkPrebakedPlacement") == true,
        "tier is not marked as final-size"
    )
    assert(math.abs(template:GetScale() - EXPECTED_SCALE) < 0.0001, "wrong template scale")

    local templateScale = template:GetScale()
    local authoredSizes = {}
    for _, descendant in ipairs(template:GetDescendants()) do
        if descendant:IsA("BaseScript") then
            error("QA script leaked into the production template")
        elseif descendant:IsA("MeshPart") then
            assert(descendant.MeshSize.Magnitude > 0.01, "MeshPart is missing baked MeshSize")
        end
        if descendant:IsA("BasePart") then
            authoredSizes[descendant.Name] = descendant.Size
        end
    end

    local anchor = Instance.new("Part")
    anchor.Name = "Tier" .. tostring(tier) .. "_9_4_Stud_Tile"
    anchor.Size = Vector3.new(EXPECTED_WIDTH, 0.1, EXPECTED_WIDTH)
    anchor.CFrame = CFrame.new(ORIGIN + Vector3.new((tier - 2.5) * 12, 0, 0))
    anchor.Anchored = true
    anchor.CanCollide = false
    anchor.CanTouch = false
    anchor.CanQuery = false
    anchor.Material = Enum.Material.Neon
    anchor.Color = Color3.fromRGB(38, 185, 255)
    anchor.Transparency = 0.7
    anchor:SetAttribute("MergeBulwarkScale", 0.94)
    anchor.Parent = folder

    local started = os.clock()
    local model, reason = MergeBulwarkModels.Spawn(
        "saw_blade",
        tier,
        anchor,
        folder,
        nil,
        nil,
        tierArt
    )
    local elapsedMilliseconds = (os.clock() - started) * 1000
    assert(model, tostring(reason))
    model.Name = "Tier" .. tostring(tier) .. "_ProductionSpawn"

    assert(math.abs(model:GetScale() - templateScale) < 0.000001, "spawn changed Model.Scale")
    assert(math.abs(template:GetScale() - templateScale) < 0.000001, "spawn changed template")
    for _, descendant in ipairs(model:GetDescendants()) do
        if descendant:IsA("MeshPart") then
            assert(descendant.MeshSize.Magnitude > 0.01, "spawn lost baked MeshSize")
        end
        if descendant:IsA("BasePart") then
            assert(
                authoredSizes[descendant.Name] == descendant.Size,
                "spawn resized " .. descendant.Name
            )
        end
    end

    local boundsCFrame, boundsSize = model:GetBoundingBox()
    local bottomY = boundsCFrame.Position.Y - boundsSize.Y * 0.5
    assert(math.abs(boundsSize.X - EXPECTED_WIDTH) < 0.002, "wrong final width")
    assert(
        boundsSize.Y <= MAX_HEIGHT_OR_DEPTH and boundsSize.Z <= MAX_HEIGHT_OR_DEPTH,
        "tier exceeds map clearance"
    )
    assert(math.abs(bottomY - anchor.Position.Y) < 0.002, "tier is not grounded on its anchor")
    assert(model:GetAttribute("MergeBulwarkImportScaled") == nil, "runtime import repair ran")
    assert(model:GetAttribute("MergeBulwarkMeshesBaked") == nil, "runtime mesh bake ran")

    print(string.format(
        "[SawBlade Edit QA] Tier %d PASS — %.3f × %.3f × %.3f, scale %.3f, clone %.3f ms",
        tier,
        boundsSize.X,
        boundsSize.Y,
        boundsSize.Z,
        model:GetScale(),
        elapsedMilliseconds
    ))
end

print("[SawBlade Edit QA] PASS — inspect Workspace.SawBladeModelsRbxmEditQA")
