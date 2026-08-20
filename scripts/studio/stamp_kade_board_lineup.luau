--[[
    Stamp five display boards beside Kade's shack for shop-edge posing.

    Idempotent. Parent is Workspace.Maps.FuturePath.KadeBoardLineup (a Folder,
    not a tile Model). Move the models in Edit; they are anchored props only.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MeshAssembly = require(ReplicatedStorage.Shared.Assets.MeshAssembly)
local hoverboard = require(ReplicatedStorage.Configs.hoverboard)

local FOLDER_NAME = "KadeBoardLineup"
local SKINS = {
    "orange_black",
    "green_white",
    "surf_blue",
    "rocket_blue",
    "surf_orange",
}

-- Arc in front of Kade (1814, 3, -202), along the shack edge.
local POSES = {
    { x = 1822, y = 4.2, z = -214 },
    { x = 1826, y = 4.2, z = -208 },
    { x = 1828, y = 4.2, z = -202 },
    { x = 1826, y = 4.2, z = -196 },
    { x = 1822, y = 4.2, z = -190 },
}

local function resolve(path)
    local current = game
    for name in string.gmatch(path, "[^%.]+") do
        current = current:FindFirstChild(name)
        if not current then
            return nil
        end
    end
    return current
end

local function deckOrient(skin, flatten)
    flatten = type(flatten) == "table" and flatten or {}
    local yaw = math.rad(tonumber(skin.deck_yaw_degrees) or 0)
    local pitch = math.rad(tonumber(skin.pitch_degrees) or tonumber(flatten.pitch_degrees) or 0)
    local roll = math.rad(tonumber(skin.roll_degrees) or tonumber(flatten.roll_degrees) or 0)
    local laid = CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch, 0, 0)
    if math.abs(roll) < 1e-5 then
        return laid
    end
    return laid * CFrame.Angles(0, 0, roll)
end

local world = resolve("Workspace.Maps.FuturePath")
if not world then
    error("Workspace.Maps.FuturePath was not found")
end

local folder = world:FindFirstChild(FOLDER_NAME)
if folder then
    folder:Destroy()
end
folder = Instance.new("Folder")
folder.Name = FOLDER_NAME
folder.Parent = world

local flatten = hoverboard.flatten
local placed = {}
for index, skinId in ipairs(SKINS) do
    local skin = hoverboard.skins[skinId]
    local pose = POSES[index]
    local model, err = MeshAssembly.build(skin.mesh_asset, skin.texture_asset, {
        modelName = skinId,
        partName = "Deck",
        anchored = true,
        canCollide = false,
    })
    if not model then
        error("Kade lineup failed for " .. skinId .. ": " .. tostring(err))
    end
    local deck = model.PrimaryPart
    local target = tonumber(skin.length) or 5.4
    local longest = math.max(deck.Size.X, deck.Size.Y, deck.Size.Z)
    if longest > 0 then
        deck.Size = deck.Size * (target / longest)
    end
    deck.CanQuery = true
    deck.CastShadow = true
    model:PivotTo(CFrame.new(pose.x, pose.y, pose.z) * deckOrient(skin, flatten))
    model.Parent = folder
    table.insert(placed, skinId)
end

return { folder = folder:GetFullName(), skins = placed }
