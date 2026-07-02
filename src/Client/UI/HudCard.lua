--[[
    HudCard — the shared CoH-style combatant card used by BOTH the squad strip (SquadHud,
    your pets, right edge) and the enemy strip (EnemyHud, the foes you're fighting, left edge).

    One builder so the two strips are visually identical and stay in lockstep: a rounded dark
    bar with an overhanging element/threat CHIP on the inner edge (PetBadge disc + ring, or a
    coloured letter/number glyph when there's no disc art), a health bar that drains
    green→yellow→red with a NAME inside and a right-aligned NOTE, and an (optional) status-badge
    row anchored toward screen centre.

    createCard(parent, opts) -> refs { frame, stroke, roleChip, roleGlyph, roleIcon, roleRing,
                                       barBg, fill, name, note, status }
        opts.name        — Instance name (e.g. "Slot_2" / "Enemy_57")
        opts.layoutOrder — UIListLayout order
        opts.width/height — card size (default 186 × 44)

    The card is a TextButton so each strip wires its own click. Pure visualisation — no services,
    no remotes; the strips own the data + behaviour, HudCard owns the look.
]]

local HudCard = {}

-- Continuous health-bar colour: green (full) -> yellow (half) -> red (empty), so the fill itself
-- reads condition (no separate state label needed). Shared so pet + enemy bars match exactly.
HudCard.HP_GREEN = Color3.fromRGB(70, 205, 95)
HudCard.HP_YELLOW = Color3.fromRGB(235, 200, 60)
HudCard.HP_RED = Color3.fromRGB(220, 70, 70)

-- Selection / target border colours (the established combat colour language):
--   blue  = "this is MY selected pet" (SquadHud)
--   amber = "this is the thing being targeted" (the selected pet's foe — matches the world
--           SquadTargetHighlight, so the chain player→pet→enemy reads in one colour)
HudCard.SELECT_BLUE = Color3.fromRGB(120, 200, 255)
HudCard.TARGET_AMBER = Color3.fromRGB(255, 180, 70)
HudCard.STROKE_IDLE = Color3.fromRGB(70, 76, 96)

-- How far the chip pokes off the card's inner edge (the "gems-pill" look): anchor-X fraction.
HudCard.BADGE_OVERHANG = 0.35

function HudCard.healthColor(f)
    f = math.clamp(f, 0, 1)
    if f >= 0.5 then
        return HudCard.HP_YELLOW:Lerp(HudCard.HP_GREEN, (f - 0.5) * 2)
    end
    return HudCard.HP_RED:Lerp(HudCard.HP_YELLOW, f * 2)
end

-- "Ns" under a minute, "M:SS" above (a 5-min lockout shouldn't read "284s").
function HudCard.formatTime(sec)
    sec = math.max(0, math.ceil(sec))
    if sec >= 60 then
        return string.format("%d:%02d", math.floor(sec / 60), sec % 60)
    end
    return sec .. "s"
end

-- Selection/target border styling, shared so both strips highlight identically.
--   mode: nil/false = idle outline, "select" = blue border, "target" = amber border.
function HudCard.applyHighlight(card, mode)
    if mode == "select" then
        card.stroke.Color = HudCard.SELECT_BLUE
        card.stroke.Transparency = 0
        card.stroke.Thickness = 3
        card.frame.BackgroundTransparency = 0
    elseif mode == "target" then
        card.stroke.Color = HudCard.TARGET_AMBER
        card.stroke.Transparency = 0
        card.stroke.Thickness = 3
        card.frame.BackgroundTransparency = 0
    else
        card.stroke.Color = HudCard.STROKE_IDLE
        card.stroke.Transparency = 0.5
        card.stroke.Thickness = 1.5
        card.frame.BackgroundTransparency = 0.1
    end
end

function HudCard.createCard(parent, opts)
    opts = opts or {}
    local width = opts.width or 186
    local height = opts.height or 44

    local frame = Instance.new("TextButton")
    frame.Name = opts.name or "Card"
    frame.AutoButtonColor = false
    frame.Text = ""
    frame.Size = UDim2.fromOffset(width, height)
    frame.BackgroundColor3 = Color3.fromRGB(28, 30, 40)
    frame.BackgroundTransparency = 0.1
    frame.BorderSizePixel = 0
    frame.LayoutOrder = opts.layoutOrder or 0
    frame.Parent = parent
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = frame
    -- Always-on subtle outline (so the chip poking off its edge reads); brightens to the
    -- selection/target colour via applyHighlight.
    local stroke = Instance.new("UIStroke")
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Color = HudCard.STROKE_IDLE
    stroke.Thickness = 1.5
    stroke.Transparency = 0.4
    stroke.Parent = frame

    -- Element/threat chip on the inner edge: a coloured square holding either a PetBadge disc+ring
    -- or a fallback letter/number glyph. Anchored so it pokes off the card edge (gems look).
    local roleChip = Instance.new("Frame")
    roleChip.Name = "Role"
    roleChip.AnchorPoint = Vector2.new(HudCard.BADGE_OVERHANG, 0.5)
    roleChip.Position = UDim2.new(0, 0, 0.5, 0)
    -- Fill the card height, then a 1:1 aspect constraint squares it to the smaller axis (height).
    roleChip.Size = UDim2.new(1, 0, 1, 0)
    roleChip.BorderSizePixel = 0
    roleChip.ClipsDescendants = false
    roleChip.Parent = frame
    local roleAspect = Instance.new("UIAspectRatioConstraint")
    roleAspect.AspectRatio = 1
    roleAspect.AspectType = Enum.AspectType.FitWithinMaxSize
    roleAspect.Parent = roleChip
    local roleCorner = Instance.new("UICorner")
    roleCorner.CornerRadius = UDim.new(0, 6)
    roleCorner.Parent = roleChip
    local roleGlyph = Instance.new("TextLabel")
    roleGlyph.Name = "Glyph"
    roleGlyph.BackgroundTransparency = 1
    roleGlyph.Size = UDim2.fromScale(1, 1)
    roleGlyph.Font = Enum.Font.GothamBold
    roleGlyph.TextSize = 14
    roleGlyph.TextColor3 = Color3.fromRGB(255, 255, 255)
    roleGlyph.TextStrokeTransparency = 0.5
    roleGlyph.Parent = roleChip
    local roleIcon = Instance.new("ImageLabel")
    roleIcon.Name = "Icon"
    roleIcon.BackgroundTransparency = 1
    roleIcon.AnchorPoint = Vector2.new(0.5, 0.5)
    roleIcon.Position = UDim2.fromScale(0.5, 0.5)
    roleIcon.Size = UDim2.fromScale(0.82, 0.82)
    roleIcon.ScaleType = Enum.ScaleType.Fit
    roleIcon.ZIndex = 2
    roleIcon.Image = ""
    roleIcon.Parent = roleChip
    local roleRing = Instance.new("ImageLabel")
    roleRing.Name = "Ring"
    roleRing.BackgroundTransparency = 1
    roleRing.AnchorPoint = Vector2.new(0.5, 0.5)
    roleRing.Position = UDim2.fromScale(0.5, 0.5)
    roleRing.Size = UDim2.fromScale(1, 1)
    roleRing.ScaleType = Enum.ScaleType.Fit
    roleRing.ZIndex = 3
    roleRing.Image = ""
    roleRing.Parent = roleChip

    -- Compact health bar: near-black backing (keeps white text legible as the fill drains), a
    -- green→yellow→red fill, the NAME inside it, and a right-aligned NOTE.
    local barBg = Instance.new("Frame")
    barBg.Name = "BarBg"
    barBg.Position = UDim2.fromOffset(40, 9)
    barBg.Size = UDim2.new(1, -48, 0, 20)
    barBg.BackgroundColor3 = Color3.fromRGB(12, 13, 18)
    barBg.BorderSizePixel = 0
    barBg.ClipsDescendants = true
    barBg.Parent = frame
    local barCorner = Instance.new("UICorner")
    barCorner.CornerRadius = UDim.new(0, 6)
    barCorner.Parent = barBg

    local fill = Instance.new("Frame")
    fill.Name = "Fill"
    fill.Size = UDim2.fromScale(1, 1)
    fill.BorderSizePixel = 0
    fill.ZIndex = 2
    fill.Parent = barBg
    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(0, 6)
    fillCorner.Parent = fill

    local nameLbl = Instance.new("TextLabel")
    nameLbl.Name = "Name"
    nameLbl.BackgroundTransparency = 1
    nameLbl.Position = UDim2.fromOffset(8, 0)
    nameLbl.Size = UDim2.new(1, -16, 1, 0)
    nameLbl.Font = Enum.Font.GothamBold
    nameLbl.TextSize = 13
    nameLbl.TextXAlignment = Enum.TextXAlignment.Left
    nameLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameLbl.TextStrokeTransparency = 0.4
    nameLbl.ZIndex = 3
    nameLbl.Parent = barBg

    local noteLbl = Instance.new("TextLabel")
    noteLbl.Name = "Note"
    noteLbl.BackgroundTransparency = 1
    noteLbl.Position = UDim2.fromOffset(8, 0)
    noteLbl.Size = UDim2.new(1, -16, 1, 0)
    noteLbl.Font = Enum.Font.GothamBold
    noteLbl.TextSize = 11
    noteLbl.TextXAlignment = Enum.TextXAlignment.Right
    noteLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    noteLbl.TextStrokeTransparency = 0.4
    noteLbl.ZIndex = 3
    noteLbl.Parent = barBg

    -- Status-badge row: anchored at the card's INNER edge, growing toward screen centre as
    -- buffs/debuffs stack. Default (right-rail cards) hangs off the LEFT edge and grows left; pass
    -- opts.badgeSide="right" (LEFT-rail cards, e.g. enemies on the left) to hang off the RIGHT edge
    -- and grow right — so the badges still point toward screen centre, not off-screen (Jason).
    local badgeSide = opts.badgeSide == "right" and "right" or "left"
    local status = Instance.new("Frame")
    status.Name = "Status"
    if badgeSide == "right" then
        status.AnchorPoint = Vector2.new(0, 0.5)
        status.Position = UDim2.new(1, 20, 0.5, 0)
    else
        status.AnchorPoint = Vector2.new(1, 0.5)
        status.Position = UDim2.new(0, -20, 0.5, 0)
    end
    status.Size = UDim2.fromOffset(0, 30)
    status.AutomaticSize = Enum.AutomaticSize.None
    status.BackgroundTransparency = 1
    status.Parent = frame

    return {
        frame = frame,
        stroke = stroke,
        roleChip = roleChip,
        roleGlyph = roleGlyph,
        roleIcon = roleIcon,
        roleRing = roleRing,
        barBg = barBg,
        fill = fill,
        name = nameLbl,
        note = noteLbl,
        status = status,
        badgeSide = badgeSide, -- StatusBadges.update reads this to grow the row the right way
    }
end

return HudCard
