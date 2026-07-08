--[[
    harvest_wall_decor — build the wall-decoration prefabs from the staged
    Synty Dungeon Weapons & Props pack into ReplicatedStorage.MissionProps.
    Run in EDIT mode (command bar / MCP execute_luau). Idempotent: replaces
    existing prefabs of the same names. docs/MISSION_WORLDGEN.md M5.

    Recipes (reference_metal_color_recipes memory):
      BRONZE weapons  = strip TextureID, Color3(58,56,62), Metal (hell)
      GILDED weapons  = strip TextureID, Color3(212,175,90), Metal (heaven)
      Shields/shelves keep their Synty atlas (they read great textured).
]]

local RS = game:GetService("ReplicatedStorage")
local staging = workspace:FindFirstChild("_SyntyStaging")
local pack = staging and staging:FindFirstChildOfClass("Model")
assert(pack, "run requires workspace._SyntyStaging with the Synty pack")
local props = RS:FindFirstChild("MissionProps") or Instance.new("Folder")
props.Name = "MissionProps"
props.Parent = RS

local BRONZE = Color3.fromRGB(58, 56, 62)
local GOLD = Color3.fromRGB(212, 175, 90)

local function grab(suffix)
    local inst = pack:FindFirstChild("Meshes/PolygonDungeon_" .. suffix)
    assert(inst, "missing mesh: " .. suffix)
    local clone = inst:Clone()
    clone.Anchored = true
    clone.CanCollide = false
    clone.CanTouch = false
    return clone
end

local function metalize(part, color)
    part.TextureID = ""
    part.Color = color
    part.Material = Enum.Material.Metal
end

local function finish(model, name, scale, mountY, standOff)
    model.Name = name
    model:ScaleTo(scale)
    model:SetAttribute("MountY", mountY)
    model:SetAttribute("StandOff", standOff)
    local old = props:FindFirstChild(name)
    if old then
        old:Destroy()
    end
    model.Parent = props
    return model
end

-- crossed blades (+ optional shield boss in front)
local function crossedBlades(name, bladeSuffix, color, shieldSuffix, scale)
    local model = Instance.new("Model")
    local a = grab(bladeSuffix)
    metalize(a, color)
    a.CFrame = CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, math.rad(35))
    a.Parent = model
    local b = grab(bladeSuffix)
    metalize(b, color)
    b.CFrame = CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, math.rad(-35))
    b.Parent = model
    if shieldSuffix then
        local s = grab(shieldSuffix) -- keeps atlas
        s.CFrame = CFrame.new(0, -0.4, -0.35)
        s.Parent = model
    end
    model.PrimaryPart = a
    return finish(model, name, scale, 11, 0.6)
end

-- single mesh prefab
local function single(name, suffix, scale, mountY, standOff, color)
    local model = Instance.new("Model")
    local m = grab(suffix)
    if color then
        metalize(m, color)
    end
    m.CFrame = CFrame.new()
    m.Parent = model
    model.PrimaryPart = m
    return finish(model, name, scale, mountY, standOff)
end

-- HELL
crossedBlades("CrossedSwords", "Weapons_SM_Wep_GreatSword_01", BRONZE, "Weapons_SM_Wep_Shield_Heater_01", 1.6)
single("WallAxe", "Weapons_SM_Wep_Ornate_GreatAxe_01", 1.6, 11, 0.6, BRONZE)
single("WallShield", "Weapons_SM_Wep_Shield_Spike_01", 1.6, 11, 0.6, nil)
local shelfD = single("BookshelfDirty", "Props_SM_Prop_Bookcase_02", 1.7, 0, 0, nil)
do -- grime the hell shelf + floor-stand mount metrics
    for _, d in ipairs(shelfD:GetDescendants()) do
        if d:IsA("MeshPart") then
            d.Color = Color3.fromRGB(120, 105, 95) -- aged multiply over atlas
        end
    end
    local _, size = shelfD:GetBoundingBox()
    shelfD:SetAttribute("MountY", size.Y / 2)
    shelfD:SetAttribute("StandOff", size.Z / 2 + 0.1)
end

-- HEAVEN
crossedBlades("CrossedSwordsGold", "Weapons_SM_Wep_Ornate_Sword_01", GOLD, "Weapons_SM_Wep_Shield_Ornate_01", 1.6)
single("WallShieldOrnate", "Weapons_SM_Wep_Shield_Ornate_02", 1.6, 11, 0.6, nil)
local shelfC = single("BookshelfClean", "Props_SM_Prop_Bookcase_01", 1.7, 0, 0, nil)
do
    local _, size = shelfC:GetBoundingBox()
    shelfC:SetAttribute("MountY", size.Y / 2)
    shelfC:SetAttribute("StandOff", size.Z / 2 + 0.1)
end

print("[harvest_wall_decor] built: CrossedSwords, WallAxe, WallShield, BookshelfDirty, CrossedSwordsGold, WallShieldOrnate, BookshelfClean")
