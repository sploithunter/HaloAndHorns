--[[
    Groups lightning markers into an ArchLightning model and parents a copy
    into every Hall gate visual, the Crystal World Hall arch, and HellFaceGateTest.

    Run in Studio Edit. Save the place after it succeeds.
]]

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Logic = require(
    ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("ArchLightning")
)
local hall = require(ReplicatedStorage:WaitForChild("Configs"):WaitForChild("hall_of_worlds"))
local cfg = hall.arch_lightning or {}

local GROUP = Logic.GROUP_NAME
local PREFIX = cfg.part_prefix or "lightning"
local ROWS = cfg.sample_rows or 9

local function findByName(name)
    local hits = {}
    for _, desc in ipairs(workspace:GetDescendants()) do
        if desc.Name == name and (desc:IsA("Model") or desc:IsA("BasePart")) then
            table.insert(hits, desc)
        end
    end
    return hits
end

local function stampHost(host)
    local old = host:FindFirstChild(GROUP)
    if old then
        old:Destroy()
    end

    local cf, size
    if host:IsA("Model") then
        cf, size = host:GetBoundingBox()
    else
        cf, size = host.CFrame, host.Size
    end

    local group = Instance.new("Model")
    group.Name = GROUP
    local localPoints = Logic.sampleArchPoints(Logic.openingWidth(size), size.Y, ROWS)
    for index, localPos in ipairs(localPoints) do
        local part = Instance.new("Part")
        part.Name = PREFIX .. tostring(index)
        part.Size = Vector3.new(0.4, 0.4, 0.4)
        part.Anchored = true
        part.CanCollide = false
        part.CanTouch = false
        part.CanQuery = false
        part.CastShadow = false
        part.Transparency = 0.35
        part.Material = Enum.Material.Neon
        part.Color = Color3.fromRGB(120, 150, 255)
        part.CFrame = CFrame.new(Logic.worldFromLocal(cf, size, localPos))
        part:SetAttribute("ArchLightningSite", host.Name)
        part.Parent = group
    end
    group.Parent = host
    if not CollectionService:HasTag(host, "ArchLightning") then
        CollectionService:AddTag(host, "ArchLightning")
    end
    return #group:GetChildren()
end

ChangeHistoryService:SetWaypoint("Before ArchLightning stamp")

for _, child in ipairs(workspace:GetChildren()) do
    if child:IsA("BasePart") and Logic.isMarkerName(child.Name, PREFIX) then
        child:Destroy()
    end
end
local leftover = workspace:FindFirstChild("ArchLightningRuntime")
if leftover then
    leftover:Destroy()
end

local stamped = {}
for _, name in ipairs(cfg.host_names or {}) do
    for _, host in ipairs(findByName(name)) do
        table.insert(stamped, string.format("%s %d", host:GetFullName(), stampHost(host)))
    end
end

ChangeHistoryService:SetWaypoint("Stamp ArchLightning groups")
print("[stamp_arch_lightning] " .. table.concat(stamped, " | "))
