--!strict

-- Rebuild the four approved Merge Saw Blade templates exactly as they were visually accepted in
-- Studio. These are deliberately assembled from the already-uploaded split MeshParts: no FBX/GLB
-- preprocessing and no per-axis resizing is allowed here. That keeps the accepted proportions,
-- rotor pivots, repaired hubs, materials, and counter-rotation metadata reproducible.
--
-- Lune cannot bake MeshSize. The split MeshIds are 200-stud Roblox assets; Studio QA previews
-- use Model.Scale 0.04 (T1/T3) or 0.05 (T2/T4) to reach the 8–10 stud tile. Runtime spawn must
-- recreate those MeshParts through AssetService:CreateMeshPartAsync so Size stays authoritative.
--
-- Usage:
--   lune run scripts/prebake/build_approved_merge_saw_blades.luau

local fs = require("@lune/fs")
local roblox = require("@lune/roblox")

local CFrame = roblox.CFrame :: any
local Color3 = roblox.Color3 :: any
local Enum = roblox.Enum :: any
local Instance = roblox.Instance :: any
local Vector3 = roblox.Vector3 :: any

type PartSpec = {
    name: string,
    className: string?,
    shape: string?,
    meshId: string?,
    textureId: string?,
    size: { number },
    position: { number },
    yawDegrees: number?,
    material: string?,
    color: { number }?,
    reflectance: number?,
    rotationAxis: string?,
    rotationDirection: number?,
}

type TierSpec = {
    tier: number,
    speedDegrees: number,
    rotationAxis: string,
    parts: { PartSpec },
}

local TIERS: { TierSpec } = {
    {
        tier = 1,
        speedDegrees = 180,
        rotationAxis = "Z",
        parts = {
            {
                name = "Base",
                meshId = "123192799345544",
                textureId = "84458906695568",
                size = { 8, 2.2792959213256836, 3.1093761920928955 },
                position = { 0, -0.6650397777557373, 0 },
            },
            {
                name = "Blade01",
                meshId = "139976908053088",
                size = { 3.310762882232666, 3.310762882232666, 1.285384178161621 },
                position = { -0.1199951171875, 0.2199997901916504, 0 },
                material = "CorrodedMetal",
                color = { 112, 61, 32 },
                reflectance = 0.03,
                rotationAxis = "Z",
                rotationDirection = 1,
            },
            {
                name = "WoodHub",
                className = "Part",
                shape = "Cylinder",
                size = { 1.46, 0.94, 0.94 },
                position = { -0.1199951171875, 0.2199997901916504, 0 },
                yawDegrees = 90,
                material = "Wood",
                color = { 91, 51, 27 },
            },
        },
    },
    {
        tier = 2,
        speedDegrees = 360,
        rotationAxis = "Z",
        parts = {
            {
                name = "Base",
                meshId = "133515286627459",
                textureId = "140701611784496",
                size = { 10, 2.407400131225586, 4.1375603675842285 },
                position = { 0, -0.4280247688293457, 0 },
            },
            {
                name = "Blade01",
                meshId = "72296448414135",
                textureId = "140701611784496",
                size = { 3.260319948196411, 3.2246251106262207, 0.857335090637207 },
                position = { 2.6717529296875, -0.019412517547607422, -0.23270416259765625 },
                rotationAxis = "Z",
                rotationDirection = 1,
            },
            {
                name = "Blade02",
                meshId = "70638687852627",
                textureId = "140701611784496",
                size = { 3.300095319747925, 3.165525197982788, 0.8825550079345703 },
                position = { -2.6531982421875, 0.04896259307861328, -0.23553466796875 },
                rotationAxis = "Z",
                rotationDirection = 1,
            },
        },
    },
    {
        tier = 3,
        speedDegrees = 180,
        rotationAxis = "Z",
        parts = {
            {
                name = "Base",
                meshId = "79042985007070",
                textureId = "98100761815658",
                size = { 8, 1.4879196882247925, 4.108015537261963 },
                position = { 0, -0.6814916133880615, 0 },
            },
            {
                name = "Blade01",
                meshId = "71163060981054",
                size = { 2.5108437538146973, 2.495650053024292, 1.1445200443267822 },
                position = { 2.20001220703125, -0.4499998092651367, -0.44000244140625 },
                material = "Metal",
                color = { 35, 37, 42 },
                reflectance = 0.06,
                rotationAxis = "Z",
                rotationDirection = 1,
            },
            {
                name = "Blade02",
                meshId = "100921571895614",
                size = { 2.9517643451690674, 2.9517643451690674, 1.1445200443267822 },
                position = { 0, -0.35000038146972656, -0.44000244140625 },
                material = "Metal",
                color = { 35, 37, 42 },
                reflectance = 0.06,
                rotationAxis = "Z",
                rotationDirection = -1,
            },
            {
                name = "Blade03",
                meshId = "99297229740651",
                size = { 2.5108437538146973, 2.495650053024292, 1.1445200443267822 },
                position = { -2.20001220703125, -0.4499998092651367, -0.43999481201171875 },
                material = "Metal",
                color = { 35, 37, 42 },
                reflectance = 0.06,
                rotationAxis = "Z",
                rotationDirection = 1,
            },
        },
    },
    {
        tier = 4,
        speedDegrees = 360,
        rotationAxis = "X",
        parts = {
            {
                name = "Base",
                meshId = "109639417360586",
                textureId = "131957368405481",
                size = { 10, 2.2314445972442627, 5.195310115814209 },
                position = { 0, -0.4760723114013672, 0 },
            },
            {
                name = "Blade01",
                meshId = "139314545281931",
                textureId = "131957368405481",
                size = { 0.6054698824882507, 3.515625, 3.7792954444885254 },
                position = { 3.583984375, -0.000002384185791015625, -0.1513671875 },
                rotationAxis = "X",
                rotationDirection = 1,
            },
            {
                name = "Blade02",
                meshId = "113775649108971",
                textureId = "131957368405481",
                size = { 0.4101600646972656, 3.486330032348633, 3.7402350902557373 },
                position = { 1.171875, -0.01464986801147461, -0.1513671875 },
                rotationAxis = "X",
                rotationDirection = 1,
            },
            {
                name = "Blade03",
                meshId = "111369797849589",
                textureId = "131957368405481",
                size = { 0.36132508516311646, 3.4667999744415283, 3.6523454189300537 },
                position = { -1.1669921875, -0.024415016174316406, -0.09765625 },
                rotationAxis = "X",
                rotationDirection = 1,
            },
            {
                name = "Blade04",
                meshId = "95881342812112",
                textureId = "131957368405481",
                size = { 0.3710949122905731, 3.5351600646972656, 3.8476550579071045 },
                position = { -3.701171875, 0, -0.12696075439453125 },
                rotationAxis = "X",
                rotationDirection = 1,
            },
        },
    },
}

local function addPart(model, spec: PartSpec)
    local part = Instance.new(spec.className or "MeshPart")
    part.Name = spec.name
    part.Size = Vector3.new(spec.size[1], spec.size[2], spec.size[3])
    part.CFrame = CFrame.new(spec.position[1], spec.position[2], spec.position[3])
        * CFrame.Angles(0, math.rad(spec.yawDegrees or 0), 0)
    part.Anchored = true
    part.CanCollide = false
    part.CanTouch = false
    part.CanQuery = false
    part.CastShadow = true
    part.Massless = true
    if part:IsA("Part") and spec.shape then
        part.Shape = Enum.PartType[spec.shape]
    end
    if part:IsA("MeshPart") then
        part.MeshId = "rbxassetid://" .. tostring(spec.meshId)
        part.TextureID = if spec.textureId then "rbxassetid://" .. spec.textureId else ""
    end
    if spec.material then
        part.Material = Enum.Material[spec.material]
    end
    if spec.color then
        part.Color = Color3.fromRGB(spec.color[1], spec.color[2], spec.color[3])
    end
    part.Reflectance = spec.reflectance or 0
    if spec.rotationAxis then
        part:SetAttribute("RotationAxis", spec.rotationAxis)
    end
    if spec.rotationDirection then
        part:SetAttribute("RotationDirection", spec.rotationDirection)
    end
    part.Parent = model
end

for _, tier in ipairs(TIERS) do
    local model = Instance.new("Model")
    model.Name = "SawBladeTier" .. tostring(tier.tier)
    model.WorldPivot = CFrame.new()
    model:SetAttribute("MergeBulwarkFamily", "saw_blade")
    model:SetAttribute("MergeBulwarkTier", tier.tier)
    model:SetAttribute("MergeBulwarkAnimationClass", "mechanism")
    model:SetAttribute("SawBladeSpeedDegrees", tier.speedDegrees)
    model:SetAttribute("PreviewSpeedDegrees", tier.speedDegrees)
    model:SetAttribute("RotationAxis", tier.rotationAxis)
    model:SetAttribute("MergeBulwarkIdleSoundKey", "merge_saw_idle")
    model:SetAttribute("MergeBulwarkImpactSoundKey", "merge_saw_hit")
    for _, part in ipairs(tier.parts) do
        addPart(model, part)
    end

    local outputPath = string.format(
        "assets/source/props/merge_bulwarks/roblox_approved/saw_blade/tier%d/model.rbxm",
        tier.tier
    )
    fs.writeFile(outputPath, roblox.serializeModel({ model }))
    print(string.format("wrote approved Saw Blade Tier %d to %s", tier.tier, outputPath))
end
