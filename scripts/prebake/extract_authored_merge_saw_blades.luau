--!strict

-- Extract the engine-authored final-size Merge Saw Blade templates from a Studio-downloaded place.
--
-- The input models must be authored and validated in Studio Edit mode under:
--   ServerStorage._QA.SawBladeFinalAuthoring.Tier1 .. Tier4
--
-- Do not replace this with a Lune MeshPart builder. MeshSize is engine-authored metadata that Lune
-- cannot synthesize; constructing fresh MeshParts is what caused the raw ~200-stud meshes to appear
-- before runtime repaired and shrank them.
--
-- Usage:
--   lune run scripts/prebake/extract_authored_merge_saw_blades.luau \
--     <Studio-downloaded-place.rbxl> \
--     assets/source/props/merge_bulwarks/roblox_approved/saw_blade

local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local placePath = process.args[1]
local outputRoot = process.args[2]
assert(placePath and outputRoot, "usage: extract_authored_merge_saw_blades.luau <place.rbxl> <output-root>")

local place = roblox.deserializePlace(fs.readFile(placePath))
local serverStorage = place:GetService("ServerStorage")
local qa = assert(serverStorage:FindFirstChild("_QA"), "missing ServerStorage._QA")
local authored = assert(
    qa:FindFirstChild("SawBladeFinalAuthoring"),
    "missing ServerStorage._QA.SawBladeFinalAuthoring"
)

local EXPECTED_SCALE = 0.047
local EXPECTED_WIDTH = 9.4
local EXPECTED_MESH_COUNTS = { 2, 3, 4, 5 }

for tier = 1, 4 do
    local model = assert(authored:FindFirstChild("Tier" .. tostring(tier)), "missing authored tier")
    assert(model:IsA("Model"), "authored tier must be a Model")
    assert(model:GetAttribute("MergeBulwarkPrebakedPlacement") == true, "tier is not marked prebaked")
    assert(
        math.abs((tonumber(model:GetAttribute("MergeBulwarkBakedWidth")) or 0) - EXPECTED_WIDTH)
            < 0.001,
        "tier has the wrong baked width"
    )
    assert(
        math.abs((tonumber(model.Scale) or 0) - EXPECTED_SCALE) < 0.0001,
        "tier has the wrong engine-authored Model.Scale"
    )

    local meshCount = 0
    for _, descendant in ipairs(model:GetDescendants()) do
        if descendant:IsA("MeshPart") then
            meshCount += 1
        end
    end
    assert(meshCount == EXPECTED_MESH_COUNTS[tier], "tier has the wrong MeshPart count")

    local geometry = assert(
        model:FindFirstChild("SawBladeTier" .. tostring(tier)),
        "authored tier is missing its engine-backed geometry model"
    )
    assert(geometry:IsA("Model"), "engine-backed geometry root must be a Model")

    local outputPath = string.format("%s/tier%d/model.rbxm", outputRoot, tier)
    local snapshot = geometry:Clone()
    snapshot.Name = "SawBladeTier" .. tostring(tier)
    for name, value in pairs(model:GetAttributes()) do
        snapshot:SetAttribute(name, value)
    end
    for _, descendant in ipairs(snapshot:GetDescendants()) do
        assert(not descendant:IsA("BaseScript"), "authored geometry must not contain QA scripts")
    end
    fs.writeFile(outputPath, roblox.serializeModel({ snapshot }))
    print(string.format("extracted engine-authored Saw Blade Tier %d to %s", tier, outputPath))
end
