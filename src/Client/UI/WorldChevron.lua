-- Shared world-space chevron used by tutorial breadcrumbs and direct-manipulation drop targets.

local WorldChevron = {}

function WorldChevron.create(parent, options)
    options = type(options) == "table" and options or {}

    local marker = Instance.new("Model")
    marker.Name = tostring(options.name or "WorldChevron")
    if options.trailIndex ~= nil then
        marker:SetAttribute("TrailIndex", options.trailIndex)
    end

    local root = Instance.new("Part")
    root.Name = "Root"
    root.Size = Vector3.new(0.1, 0.1, 0.1)
    root.CFrame = CFrame.identity
    root.Anchored = true
    root.CanCollide = false
    root.CanTouch = false
    root.CanQuery = false
    root.CastShadow = false
    root.Transparency = 1
    root.Parent = marker
    marker.PrimaryPart = root

    local tip = Vector3.new(0, 0, -0.82)
    local leftTail = Vector3.new(-0.72, 0, 0.24)
    local rightTail = Vector3.new(0.72, 0, 0.24)

    local function arm(name, tail)
        local midpoint = (tail + tip) * 0.5
        local part = Instance.new("Part")
        part.Name = name
        part.Size = Vector3.new(0.32, 0.24, (tip - tail).Magnitude)
        part.CFrame = CFrame.lookAt(midpoint, tip)
        part.Anchored = true
        part.CanCollide = false
        part.CanTouch = false
        part.CanQuery = false
        part.CastShadow = false
        part.Material = Enum.Material.Neon
        part.Color = options.color or Color3.fromRGB(255, 249, 224)
        part.Transparency = 0.08
        part.Parent = marker
    end

    arm("LeftArm", leftTail)
    arm("RightArm", rightTail)

    local outline = Instance.new("Highlight")
    outline.Name = "Outline"
    outline.DepthMode = Enum.HighlightDepthMode.Occluded
    outline.FillColor = options.fillColor or Color3.fromRGB(255, 247, 210)
    outline.FillTransparency = 0.62
    outline.OutlineColor = options.outlineColor or Color3.fromRGB(35, 43, 61)
    outline.OutlineTransparency = 0.08
    outline.Adornee = marker
    outline.Parent = marker

    marker.Parent = parent
    return marker
end

return WorldChevron
