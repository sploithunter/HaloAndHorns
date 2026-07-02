--[[
    OverheadBar — the ONE over-the-head fill bar widget for the world (enemy HP, pet endurance, and
    any future over-head meter). Pets and enemies are modelled the same, so their bars are too: a
    pill-rounded billboard with a dark backing + a coloured fill, identical except for the FILL COLOUR
    (red for enemies, green for pets) and per-entity placement. One builder, one updater — never two.

        local bb = OverheadBar.create({ adornee = part, name = "HealthBar", studsOffset = v3, fillColor = c })
        OverheadBar.setFraction(OverheadBar.fillOf(part, "HealthBar"), hp / maxHp, optionalColor)

    Structure is fixed so any caller's updater can find the fill: <adornee>.<name>.BG.Fill.
]]

local OverheadBar = {}

local DEFAULT_WIDTH = 4.5 -- studs (billboard X)
local DEFAULT_HEIGHT = 0.5 -- studs (billboard Y) — slim
local DEFAULT_BG = Color3.fromRGB(30, 30, 30)
local DEFAULT_FILL = Color3.fromRGB(220, 70, 70)

-- Build the bar over `opts.adornee` (a BasePart) and return the BillboardGui. The widget is
-- identical for every caller; only opts.name / studsOffset / fillColor (and rarely size/bgColor)
-- vary. Parents itself to the adornee.
function OverheadBar.create(opts)
    opts = opts or {}
    local adornee = opts.adornee

    local bb = Instance.new("BillboardGui")
    bb.Name = opts.name or "OverheadBar"
    bb.Size = UDim2.new(opts.width or DEFAULT_WIDTH, 0, opts.height or DEFAULT_HEIGHT, 0)
    bb.StudsOffset = opts.studsOffset or Vector3.new(0, 3.5, 0)
    bb.AlwaysOnTop = true
    -- Distance cull: stop rendering past MaxDistance so enemy HP bars don't show across the whole map
    -- (Jason: "why can I see enemy health bars at any distance?"). Pets cluster on the player so their
    -- endurance bars stay well within this; callers can override via opts.maxDistance (0 = unlimited).
    bb.MaxDistance = opts.maxDistance ~= nil and tonumber(opts.maxDistance) or 150
    bb.Adornee = adornee

    local bg = Instance.new("Frame")
    bg.Name = "BG"
    bg.Size = UDim2.fromScale(1, 1)
    bg.BackgroundColor3 = opts.bgColor or DEFAULT_BG
    bg.BorderSizePixel = 0
    bg.Parent = bb
    local bgCorner = Instance.new("UICorner")
    bgCorner.CornerRadius = UDim.new(1, 0) -- pill
    bgCorner.Parent = bg

    local fill = Instance.new("Frame")
    fill.Name = "Fill"
    fill.Size = UDim2.fromScale(1, 1)
    fill.BackgroundColor3 = opts.fillColor or DEFAULT_FILL
    fill.BorderSizePixel = 0
    fill.Parent = bg
    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(1, 0)
    fillCorner.Parent = fill

    bb.Parent = adornee
    return bb
end

-- The fill Frame for a named bar on a part (or nil). Lets any updater reach it the same way.
function OverheadBar.fillOf(part, name)
    local bb = part and part:FindFirstChild(name)
    local bg = bb and bb:FindFirstChild("BG")
    return bg and bg:FindFirstChild("Fill")
end

-- Set the fill to a 0..1 fraction; optional colour override (e.g. pet endurance green->red ramp).
function OverheadBar.setFraction(fill, frac, color)
    if not fill then
        return
    end
    fill.Size = UDim2.fromScale(math.clamp(frac, 0, 1), 1)
    if color then
        fill.BackgroundColor3 = color
    end
end

return OverheadBar
