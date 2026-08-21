--[[
    Stamp four AwardPodium hooks at the Hall 1 end-cap exit.

    Idempotent. Parent is Workspace.Maps.FuturePath.AwardPodiums (a Folder,
    not a tile Model) so Explorer search and click-select work. Move the
    pads in Edit; runtime visualization follows the hook CFrame.
]]

local CollectionService = game:GetService("CollectionService")

local TAG = "AwardPodium"
local AREA_ID = "Hall_1"

local HOOKS = {
    {
        name = "AwardPodium_MostDragons",
        podium_id = "hall_most_dragons",
        board_id = "most_dragons",
        color = Color3.fromRGB(83, 214, 105),
        x = 1988,
        z = 72,
    },
    {
        name = "AwardPodium_CrystalCrusher",
        podium_id = "hall_crystal_crusher",
        board_id = "crystal_crusher",
        color = Color3.fromRGB(255, 191, 57),
        x = 1998,
        z = 72,
    },
    {
        name = "AwardPodium_EnemiesDefeated",
        podium_id = "hall_enemies_defeated",
        board_id = "enemies_defeated",
        color = Color3.fromRGB(255, 77, 55),
        x = 2008,
        z = 72,
    },
    {
        name = "AwardPodium_TeamPower",
        podium_id = "hall_team_power",
        board_id = "team_power",
        color = Color3.fromRGB(78, 190, 255),
        x = 2018,
        z = 72,
    },
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

local world = resolve("Workspace.Maps.FuturePath")
assert(world, "missing Workspace.Maps.FuturePath")
local parent = world:FindFirstChild("AwardPodiums")
if not parent then
    parent = Instance.new("Folder")
    parent.Name = "AwardPodiums"
    parent.Parent = world
end

for _, hook in ipairs(CollectionService:GetTagged(TAG)) do
    hook:Destroy()
end

local function attachFront(pad)
    local old = pad:FindFirstChild("Front")
    if old then
        old:Destroy()
    end
    local front = Instance.new("Model")
    front.Name = "Front"

    local shaft = Instance.new("Part")
    shaft.Name = "Shaft"
    shaft.Anchored = true
    shaft.CanCollide = false
    shaft.CanQuery = false
    shaft.Material = Enum.Material.Neon
    shaft.Color = Color3.new(1, 1, 1)
    shaft.Size = Vector3.new(0.7, 0.35, 3.2)
    shaft.CFrame = pad.CFrame * CFrame.new(0, 0.4, -1.6)
    shaft.Parent = front

    local tip = Instance.new("WedgePart")
    tip.Name = "Arrow"
    tip.Anchored = true
    tip.CanCollide = false
    tip.CanQuery = false
    tip.Material = Enum.Material.Neon
    tip.Color = Color3.new(1, 1, 1)
    tip.Size = Vector3.new(2.4, 0.35, 1.8)
    -- Wedge tapers toward -Z, which is the part LookVector / podium front.
    tip.CFrame = pad.CFrame * CFrame.new(0, 0.4, -4.1)
    tip.Parent = front
    front.Parent = pad
end

-- Face +Z (into the corridor / toward a player leaving the cap).
local face = CFrame.Angles(0, math.pi, 0)

for _, spec in ipairs(HOOKS) do
    local pad = Instance.new("Part")
    pad.Name = spec.name
    pad.Anchored = true
    pad.CanCollide = false
    pad.CanQuery = true
    pad.CastShadow = false
    pad.Material = Enum.Material.Neon
    pad.Color = spec.color
    pad.Transparency = 0.35
    pad.Size = Vector3.new(8, 0.4, 8)
    pad.CFrame = CFrame.new(spec.x, 0.4, spec.z) * face
    pad:SetAttribute("BoardId", spec.board_id)
    pad:SetAttribute("PodiumId", spec.podium_id)
    pad:SetAttribute("AreaId", AREA_ID)
    CollectionService:AddTag(pad, TAG)
    attachFront(pad)
    pad.Parent = parent
end

return string.format("stamped %d AwardPodium hooks under %s", #HOOKS, parent:GetFullName())
