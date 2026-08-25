-- Stamp the authored Layer 3 ambient-fauna anchors.
--
-- Safe to rerun: only the dedicated AmbientFaunaAnchors folders are rebuilt.
-- Runtime visuals are owned by AmbientFaunaService and are never saved here.

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local CollectionService = game:GetService("CollectionService")

local SPECS = {
    Heaven_3 = {
        {
            name = "BloomwingButterfly_1",
            model = "bloomwing_butterfly",
            position = Vector3.new(-75, 6001.358, 315),
            motion = "hover",
            radius = 3.2,
            hover = 2.6,
            bob = 0.45,
            speed = 0.72,
            size = 3.6,
            phase = 0.2,
        },
        {
            name = "BloomwingButterfly_2",
            model = "bloomwing_butterfly",
            position = Vector3.new(-120, 6001.358, 335),
            motion = "hover",
            radius = 2.7,
            hover = 2.2,
            bob = 0.38,
            speed = 0.58,
            size = 3.2,
            phase = 2.3,
        },
        {
            name = "BloomwingButterfly_3",
            model = "bloomwing_butterfly",
            position = Vector3.new(-200, 6001.358, 500),
            motion = "hover",
            radius = 3.5,
            hover = 2.8,
            bob = 0.5,
            speed = 0.64,
            size = 3.8,
            phase = 4.4,
        },
        {
            name = "PearlbackSnail_1",
            model = "pearlback_snail",
            position = Vector3.new(-440, 6000.801, 420),
            motion = "ground",
            radius = 1.8,
            hover = 0,
            bob = 0.04,
            speed = 0.13,
            size = 2.5,
            phase = 0.8,
        },
        {
            name = "PearlbackSnail_2",
            model = "pearlback_snail",
            position = Vector3.new(-350, 6000.801, 450),
            motion = "ground",
            radius = 2.2,
            hover = 0,
            bob = 0.04,
            speed = 0.11,
            size = 2.7,
            phase = 3.1,
        },
        {
            name = "PearlbackSnail_3",
            model = "pearlback_snail",
            position = Vector3.new(-150, 6001.358, 500),
            motion = "ground",
            radius = 1.6,
            hover = 0,
            bob = 0.04,
            speed = 0.14,
            size = 2.4,
            phase = 5.2,
        },
    },
    Hell_3 = {
        {
            name = "DreadwingBeetle_1",
            model = "dreadwing_beetle",
            position = Vector3.new(-60, -5998.642, 340),
            motion = "hover",
            radius = 2.6,
            hover = 1.5,
            bob = 0.28,
            speed = 0.75,
            size = 2.8,
            phase = 0.5,
        },
        {
            name = "DreadwingBeetle_2",
            model = "dreadwing_beetle",
            position = Vector3.new(-400, -5999.199, 220),
            motion = "hover",
            radius = 2.2,
            hover = 1.2,
            bob = 0.24,
            speed = 0.68,
            size = 2.6,
            phase = 2.6,
        },
        {
            name = "DreadwingBeetle_3",
            model = "dreadwing_beetle",
            position = Vector3.new(-300, -5999.180, 100),
            motion = "hover",
            radius = 3.0,
            hover = 1.7,
            bob = 0.3,
            speed = 0.8,
            size = 3.0,
            phase = 4.7,
        },
        {
            name = "ObsidianHornbackLizard_1",
            model = "obsidian_hornback_lizard",
            position = Vector3.new(-120, -5998.642, 370),
            motion = "ground",
            radius = 2.4,
            hover = 0,
            bob = 0.06,
            speed = 0.2,
            size = 3.8,
            phase = 1.0,
        },
        {
            name = "ObsidianHornbackLizard_2",
            model = "obsidian_hornback_lizard",
            position = Vector3.new(-420, -5999.199, 480),
            motion = "ground",
            radius = 2.1,
            hover = 0,
            bob = 0.06,
            speed = 0.18,
            size = 3.6,
            phase = 3.3,
        },
        {
            name = "ObsidianHornbackLizard_3",
            model = "obsidian_hornback_lizard",
            position = Vector3.new(-200, -5998.642, 500),
            motion = "ground",
            radius = 2.8,
            hover = 0,
            bob = 0.06,
            speed = 0.22,
            size = 4.0,
            phase = 5.4,
        },
    },
}

local maps = workspace:FindFirstChild("Maps")
assert(maps, "Workspace.Maps missing")
ChangeHistoryService:SetWaypoint("Before Layer 3 ambient fauna anchors")

local report = {}
for layerName, specs in pairs(SPECS) do
    local layer = maps:FindFirstChild(layerName)
    assert(layer, layerName .. " missing")
    local old = layer:FindFirstChild("AmbientFaunaAnchors")
    if old then
        old:Destroy()
    end
    local folder = Instance.new("Folder")
    folder.Name = "AmbientFaunaAnchors"
    folder.Parent = layer

    for _, spec in ipairs(specs) do
        local anchor = Instance.new("Part")
        anchor.Name = "AmbientFaunaAnchor_" .. spec.name
        anchor.Size = Vector3.new(0.5, 0.4, 0.5)
        anchor.Position = spec.position
        anchor.Transparency = 1
        anchor.Anchored = true
        anchor.CanCollide = false
        anchor.CanTouch = false
        anchor.CanQuery = false
        anchor:SetAttribute("ModelName", spec.model)
        anchor:SetAttribute("Motion", spec.motion)
        anchor:SetAttribute("MoveRadius", spec.radius)
        anchor:SetAttribute("HoverHeight", spec.hover)
        anchor:SetAttribute("BobHeight", spec.bob)
        anchor:SetAttribute("Speed", spec.speed)
        anchor:SetAttribute("VisualSize", spec.size)
        anchor:SetAttribute("Phase", spec.phase)
        anchor.Parent = folder
        CollectionService:AddTag(anchor, "AmbientFaunaAnchor")
    end
    table.insert(report, ("%s anchors=%d"):format(layerName, #specs))
end

ChangeHistoryService:SetWaypoint("After Layer 3 ambient fauna anchors")
return table.concat(report, "\n")
