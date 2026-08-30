--[[
    CombatRankController — placeholder crest ceremony + list chip + nametag.

    Pillar grant fires combat_rank_achieved. A neon disc pops on the body,
    then a ViewportFrame crest flies to the PlayerBar portrait and docks as
    the current title. Other clients read CombatRank / CombatRankLabel.
]]

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local CombatRank = require(ReplicatedStorage.Shared.Game.CombatRank)
local StatusBadge = require(ReplicatedStorage.Shared.Game.StatusBadge)
local Signals = require(ReplicatedStorage.Shared.Network.Signals)

local CombatRankController = {}
local started = false
local ranksConfig
local peopleConfig
local gui
local chip
local chipGlyph
local chipIcon
local chipLabel
local picker
local ceremonyGeneration = 0
local nametags = {}

local function rgb(color)
    color = type(color) == "table" and color or {}
    return Color3.fromRGB(
        tonumber(color[1]) or 255,
        tonumber(color[2]) or 200,
        tonumber(color[3]) or 90
    )
end

local function ceremonyKnobs()
    local knobs = ranksConfig and ranksConfig.ceremony
    return type(knobs) == "table" and knobs or {}
end

local function currentRank()
    local player = Players.LocalPlayer
    return CombatRank.rankById(ranksConfig, player and player:GetAttribute("CombatRank"))
end

local function badgeState(player)
    player = player or Players.LocalPlayer
    return {
        earnedCsv = player:GetAttribute("CombatRankEarned"),
        combatRankId = player:GetAttribute("CombatRank"),
        level = player:GetAttribute("Level"),
        hugeHatcher = player:GetAttribute("HasHatchedHuge") == true,
        leaderboardTitle = player:GetAttribute("LeaderboardStatusTitle"),
        leaderboardRank = player:GetAttribute("LeaderboardStatusRank"),
        leaderboardHoverTitle = player:GetAttribute("LeaderboardStatusHoverTitle"),
        leaderboardHoverBoard = player:GetAttribute("LeaderboardStatusHoverBoard"),
        leaderboardBoardId = player:GetAttribute("LeaderboardStatusBoardId"),
    }
end

local function currentBadge(player)
    player = player or Players.LocalPlayer
    local pick = {
        kind = player:GetAttribute("StatusBadgeKind"),
        id = player:GetAttribute("StatusBadgeId"),
    }
    return StatusBadge.resolve(peopleConfig, ranksConfig, badgeState(player), pick)
end

local function applyChip(badge)
    if not chip then
        return
    end
    badge = badge or currentBadge()
    if not badge then
        local rank = currentRank()
        if rank then
            badge = {
                label = rank.label,
                color = rank.color,
                icon = CombatRank.iconAsset(rank),
            }
        end
    end
    if not badge then
        chip.Visible = false
        return
    end
    chip.Visible = true
    chip.UIStroke.Color = rgb(badge.color)
    if type(badge.icon) == "string" and badge.icon ~= "" then
        chipIcon.Image = badge.icon
        chipIcon.Visible = true
        chipIcon.Size = UDim2.fromOffset(28, 28)
        chipGlyph.Visible = false
        chipGlyph.Size = UDim2.fromOffset(0, 0)
    else
        -- Leaderboard titles have no crest yet. Gotham has no ✦, so hide
        -- the glyph slot rather than drawing an empty box.
        chipIcon.Image = ""
        chipIcon.Visible = false
        chipIcon.Size = UDim2.fromOffset(0, 0)
        chipGlyph.Visible = false
        chipGlyph.Size = UDim2.fromOffset(0, 0)
    end
    chipLabel.Text = tostring(badge.label or "")
    chipLabel.TextColor3 = rgb(badge.color)
end

-- PlayerBar emblem: center x=8, 62px disc, so the left lip is at -23.
-- Sit the pill immediately left of that lip (and inherit the capsule scale).
local CHIP_GAP = 6
local EMBLEM_FALLBACK_LEFT = 8 - 31

local function chipHeight()
    return tonumber(ceremonyKnobs().chip_height) or 36
end

local function emblemLeft(cap)
    local emblem = cap and cap:FindFirstChild("Emblem")
    if emblem and emblem:IsA("GuiObject") then
        return emblem.Position.X.Offset - emblem.Size.X.Offset * emblem.AnchorPoint.X
    end
    return EMBLEM_FALLBACK_LEFT
end

local function layoutChipDock(cap)
    if not (chip and picker) then
        return
    end
    -- Hug the portrait from the left. The capsule's ViewportScale keeps
    -- this cluster together on phone-width bars.
    local rightEdge = emblemLeft(cap) - CHIP_GAP
    chip.AnchorPoint = Vector2.new(1, 0.5)
    chip.Position = UDim2.new(0, rightEdge, 0.5, 0)
    picker.AnchorPoint = Vector2.new(1, 0)
    picker.Position = UDim2.new(0, rightEdge, 0.5, chipHeight() / 2 + 6)
end

local function dockChipToPlayerBar()
    local player = Players.LocalPlayer
    local pg = player:FindFirstChild("PlayerGui") or player:WaitForChild("PlayerGui")
    local barGui = pg:WaitForChild("PlayerBar", 20)
    local cap = barGui and barGui:WaitForChild("Capsule", 10)
    if not (chip and picker and cap) then
        return
    end
    chip.Parent = cap
    picker.Parent = cap
    layoutChipDock(cap)
    if not chip:GetAttribute("DockBound") then
        chip:SetAttribute("DockBound", true)
        local function relayout()
            layoutChipDock(cap)
        end
        player:GetAttributeChangedSignal("DisplayClass"):Connect(relayout)
        player:GetAttributeChangedSignal("HudLayoutResolved"):Connect(relayout)
    end
end

local function chipLandTarget()
    if chip and chip.Parent and chip.AbsoluteSize.X > 0 then
        local pos = chip.AbsolutePosition
        local size = chip.AbsoluteSize
        return Vector2.new(1, 0), UDim2.fromOffset(pos.X + size.X, pos.Y)
    end
    local top = tonumber(ceremonyKnobs().chip_top) or 14
    return Vector2.new(0.5, 0), UDim2.new(0.5, -270, 0, top)
end

local function hidePicker()
    if picker then
        picker.Visible = false
        for _, child in ipairs(picker:GetChildren()) do
            if child:IsA("TextButton") or child:IsA("TextLabel") then
                child:Destroy()
            end
        end
    end
end

local function openPicker()
    if not picker then
        return
    end
    local options = StatusBadge.options(peopleConfig, ranksConfig, badgeState())
    if #options == 0 then
        return
    end
    hidePicker()
    picker.Visible = true
    local rowZ = picker.ZIndex + 1
    local y = 4
    local lastGroup = nil
    for _, option in ipairs(options) do
        if option.group ~= lastGroup then
            lastGroup = option.group
            local heading = Instance.new("TextLabel")
            heading.BackgroundTransparency = 1
            heading.Size = UDim2.new(1, -10, 0, 16)
            heading.Position = UDim2.fromOffset(6, y)
            heading.Font = Enum.Font.GothamBold
            heading.TextSize = 11
            heading.TextXAlignment = Enum.TextXAlignment.Left
            heading.TextColor3 = Color3.fromRGB(200, 206, 218)
            heading.Text = option.group
            heading.ZIndex = rowZ
            heading.Parent = picker
            y += 16
        end
        local btn = Instance.new("TextButton")
        btn.AutoButtonColor = true
        btn.BackgroundColor3 = Color3.fromRGB(36, 40, 52)
        btn.BackgroundTransparency = 0.05
        btn.BorderSizePixel = 0
        btn.Size = UDim2.new(1, -10, 0, 24)
        btn.Position = UDim2.fromOffset(5, y)
        btn.Text = ""
        btn.ZIndex = rowZ
        btn.Parent = picker
        local pad = Instance.new("UIPadding")
        pad.PaddingLeft = UDim.new(0, 6)
        pad.PaddingRight = UDim.new(0, 6)
        pad.Parent = btn
        local row = Instance.new("UIListLayout")
        row.FillDirection = Enum.FillDirection.Horizontal
        row.HorizontalAlignment = Enum.HorizontalAlignment.Left
        row.VerticalAlignment = Enum.VerticalAlignment.Center
        row.Padding = UDim.new(0, 6)
        row.SortOrder = Enum.SortOrder.LayoutOrder
        row.Parent = btn
        if type(option.icon) == "string" and option.icon ~= "" then
            local crest = Instance.new("ImageLabel")
            crest.BackgroundTransparency = 1
            crest.LayoutOrder = 1
            crest.Size = UDim2.fromOffset(18, 18)
            crest.ScaleType = Enum.ScaleType.Fit
            crest.Image = option.icon
            crest.ZIndex = rowZ + 1
            crest.Parent = btn
        end
        local name = Instance.new("TextLabel")
        name.BackgroundTransparency = 1
        name.LayoutOrder = 2
        name.Size = UDim2.new(1, -28, 1, 0)
        name.Font = Enum.Font.GothamBold
        name.TextSize = 13
        name.TextXAlignment = Enum.TextXAlignment.Left
        name.TextColor3 = rgb(option.color)
        name.Text = tostring(option.label)
        name.ZIndex = rowZ + 1
        name.Parent = btn
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 4)
        corner.Parent = btn
        local kind, id = option.kind, option.id
        btn.Activated:Connect(function()
            hidePicker()
            if Signals.SetStatusBadge then
                Signals.SetStatusBadge:FireServer({ kind = kind, id = id })
            end
        end)
        y += 26
    end
    picker.Size = UDim2.fromOffset(tonumber(ceremonyKnobs().chip_width) or 160, y + 6)
end

local function ensureHud()
    local player = Players.LocalPlayer
    local pg = player:WaitForChild("PlayerGui")
    if gui and gui.Parent then
        return
    end
    local knobs = ceremonyKnobs()
    gui = Instance.new("ScreenGui")
    gui.Name = "CombatRankHud"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 91
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = pg

    pcall(function()
        local Locations = require(ReplicatedStorage.Shared.Locations)
        local people = require(Locations.ConfigLoader):LoadConfig("people_list")
        peopleConfig = people or peopleConfig
    end)
    chip = Instance.new("TextButton")
    chip.Name = "Chip"
    chip.AutoButtonColor = false
    chip.AnchorPoint = Vector2.new(1, 0.5)
    -- Temporary screen-space seat until PlayerBar.Capsule exists; dockChipToPlayerBar
    -- then parents this onto the capsule, left of the portrait.
    chip.Position = UDim2.new(0.5, -270, 0, tonumber(knobs.chip_top) or 14)
    chip.Size =
        UDim2.fromOffset(tonumber(knobs.chip_width) or 148, tonumber(knobs.chip_height) or 36)
    chip.AutomaticSize = Enum.AutomaticSize.X
    chip.BackgroundColor3 = Color3.fromRGB(18, 16, 24)
    chip.BackgroundTransparency = 0.08
    chip.BorderSizePixel = 0
    chip.Visible = false
    chip.ZIndex = 9
    chip.Text = ""
    chip.Parent = gui
    local chipMax = Instance.new("UISizeConstraint")
    chipMax.MaxSize = Vector2.new(tonumber(knobs.chip_width) or 160, chipHeight())
    chipMax.Parent = chip
    chip.Activated:Connect(function()
        if picker and picker.Visible then
            hidePicker()
        else
            openPicker()
        end
    end)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = chip
    local stroke = Instance.new("UIStroke")
    stroke.Name = "UIStroke"
    stroke.Thickness = 1.5
    stroke.Transparency = 0.15
    stroke.Parent = chip

    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, 8)
    pad.PaddingRight = UDim.new(0, 10)
    pad.Parent = chip
    local row = Instance.new("UIListLayout")
    row.FillDirection = Enum.FillDirection.Horizontal
    row.HorizontalAlignment = Enum.HorizontalAlignment.Left
    row.VerticalAlignment = Enum.VerticalAlignment.Center
    row.Padding = UDim.new(0, tonumber(knobs.icon_text_gap) or 8)
    row.SortOrder = Enum.SortOrder.LayoutOrder
    row.Parent = chip

    chipGlyph = Instance.new("TextLabel")
    chipGlyph.Name = "Glyph"
    chipGlyph.BackgroundTransparency = 1
    chipGlyph.LayoutOrder = 1
    chipGlyph.Size = UDim2.fromOffset(28, 28)
    chipGlyph.Font = Enum.Font.GothamBold
    chipGlyph.TextSize = 18
    chipGlyph.Parent = chip

    chipIcon = Instance.new("ImageLabel")
    chipIcon.Name = "Icon"
    chipIcon.BackgroundTransparency = 1
    chipIcon.LayoutOrder = 1
    chipIcon.Size = UDim2.fromOffset(28, 28)
    chipIcon.ScaleType = Enum.ScaleType.Fit
    chipIcon.Visible = false
    chipIcon.Parent = chip

    chipLabel = Instance.new("TextLabel")
    chipLabel.Name = "Label"
    chipLabel.BackgroundTransparency = 1
    chipLabel.LayoutOrder = 2
    chipLabel.AutomaticSize = Enum.AutomaticSize.X
    chipLabel.Size = UDim2.new(0, 0, 1, 0)
    chipLabel.Font = Enum.Font.GothamBold
    chipLabel.TextSize = 16
    chipLabel.TextXAlignment = Enum.TextXAlignment.Left
    chipLabel.TextTruncate = Enum.TextTruncate.AtEnd
    chipLabel.Parent = chip

    picker = Instance.new("Frame")
    picker.Name = "Picker"
    picker.Visible = false
    picker.AnchorPoint = Vector2.new(1, 0)
    picker.Position = UDim2.new(0.5, -270, 0, (tonumber(knobs.chip_top) or 14) + chipHeight() + 6)
    picker.Size = UDim2.fromOffset(tonumber(knobs.chip_width) or 160, 0)
    picker.BackgroundColor3 = Color3.fromRGB(16, 18, 26)
    picker.BackgroundTransparency = 0.04
    picker.BorderSizePixel = 0
    picker.ZIndex = 10
    picker.Active = true
    picker.Parent = gui
    local pickCorner = Instance.new("UICorner")
    pickCorner.CornerRadius = UDim.new(0, 8)
    pickCorner.Parent = picker
    local pickStroke = Instance.new("UIStroke")
    pickStroke.Color = Color3.fromRGB(220, 224, 236)
    pickStroke.Transparency = 0.4
    pickStroke.Parent = picker

    task.spawn(dockChipToPlayerBar)
end

local function attachNametag(player)
    local existing = nametags[player]
    if existing then
        existing:Destroy()
        nametags[player] = nil
    end
    local badge = currentBadge(player)
    local label = badge and badge.label
    if type(label) ~= "string" or label == "" then
        return
    end
    local character = player.Character
    local head = character and character:FindFirstChild("Head")
    if not head then
        return
    end
    local knobs = ceremonyKnobs()
    local gap = tonumber(knobs.icon_text_gap) or 8
    local bb = Instance.new("BillboardGui")
    bb.Name = "CombatRankTag"
    bb.Adornee = head
    bb.AlwaysOnTop = false
    bb.MaxDistance = tonumber(knobs.nametag_max_distance) or 80
    bb.Size = UDim2.fromOffset(140, 22)
    bb.StudsOffset = Vector3.new(0, tonumber(knobs.nametag_studs) or 2.55, 0)
    bb.ResetOnSpawn = false
    bb.Parent = head

    local row = Instance.new("Frame")
    row.Name = "Row"
    row.BackgroundTransparency = 1
    row.Size = UDim2.fromScale(1, 1)
    row.Parent = bb
    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.VerticalAlignment = Enum.VerticalAlignment.Center
    layout.Padding = UDim.new(0, gap)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = row

    local icon = type(badge.icon) == "string" and badge.icon ~= "" and badge.icon or nil
    if icon then
        local image = Instance.new("ImageLabel")
        image.BackgroundTransparency = 1
        image.LayoutOrder = 1
        image.Size = UDim2.fromOffset(20, 20)
        image.ScaleType = Enum.ScaleType.Fit
        image.Image = icon
        image.Parent = row
    end
    local text = Instance.new("TextLabel")
    text.BackgroundTransparency = 1
    text.LayoutOrder = 2
    text.Size = UDim2.fromOffset(80, 22)
    text.Font = Enum.Font.GothamBold
    text.TextSize = 14
    text.Text = label
    text.TextColor3 = rgb(badge.color)
    text.TextStrokeTransparency = 0.35
    text.TextXAlignment = Enum.TextXAlignment.Left
    text.Parent = row
    nametags[player] = bb
end

local function watchPlayer(player)
    local function refresh()
        attachNametag(player)
        if player == Players.LocalPlayer then
            applyChip(currentBadge(player))
        end
    end
    player:GetAttributeChangedSignal("CombatRank"):Connect(refresh)
    player:GetAttributeChangedSignal("CombatRankLabel"):Connect(refresh)
    player:GetAttributeChangedSignal("CombatRankEarned"):Connect(refresh)
    player:GetAttributeChangedSignal("StatusBadgeLabel"):Connect(refresh)
    player:GetAttributeChangedSignal("StatusBadgeKind"):Connect(refresh)
    player:GetAttributeChangedSignal("StatusBadgeId"):Connect(refresh)
    player:GetAttributeChangedSignal("Level"):Connect(refresh)
    player:GetAttributeChangedSignal("HasHatchedHuge"):Connect(refresh)
    player:GetAttributeChangedSignal("LeaderboardStatusTitle"):Connect(refresh)
    player.CharacterAdded:Connect(function()
        task.defer(refresh)
    end)
    refresh()
end

local function buildMedal(parent, rank, size)
    local vp = Instance.new("ViewportFrame")
    vp.Name = "Medal"
    vp.Size = UDim2.fromOffset(size, size)
    vp.BackgroundTransparency = 1
    vp.Ambient = Color3.fromRGB(40, 36, 48)
    vp.LightColor = rgb(rank.color)
    vp.LightDirection = Vector3.new(-0.4, -1, -0.6)
    vp.Parent = parent

    local world = Instance.new("WorldModel")
    world.Parent = vp
    local camera = Instance.new("Camera")
    camera.CFrame = CFrame.new(Vector3.new(0, 0.12, 3.05), Vector3.zero)
    camera.Parent = vp
    vp.CurrentCamera = camera

    local disc = Instance.new("Part")
    disc.Name = "Disc"
    disc.Shape = Enum.PartType.Cylinder
    disc.Size = Vector3.new(0.16, 1.65, 1.65)
    disc.CFrame = CFrame.Angles(0, 0, math.rad(90))
    disc.Color = rgb(rank.color)
    disc.Material = Enum.Material.Neon
    disc.Anchored = true
    disc.CanCollide = false
    disc.CastShadow = false
    disc.Parent = world

    local ring = Instance.new("Part")
    ring.Name = "Ring"
    ring.Shape = Enum.PartType.Cylinder
    ring.Size = Vector3.new(0.1, 2.12, 2.12)
    ring.CFrame = CFrame.Angles(0, 0, math.rad(90))
    ring.Color = Color3.fromRGB(255, 255, 255)
    ring.Material = Enum.Material.Neon
    ring.Transparency = 0.28
    ring.Anchored = true
    ring.CanCollide = false
    ring.CastShadow = false
    ring.Parent = world

    local spin = 0
    local conn = RunService.RenderStepped:Connect(function(dt)
        if not vp.Parent then
            conn:Disconnect()
            return
        end
        spin += dt * 1.6
        local yaw = CFrame.Angles(0, spin, 0)
        disc.CFrame = yaw * CFrame.Angles(0, 0, math.rad(90))
        ring.CFrame = yaw * CFrame.Angles(0, 0, math.rad(90))
    end)
    return vp
end

local function worldPop(rank)
    local character = Players.LocalPlayer.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root then
        return
    end
    local knobs = ceremonyKnobs()
    local seconds = tonumber(knobs.world_pop_seconds) or 0.75
    local part = Instance.new("Part")
    part.Name = "CombatRankBurst"
    part.Shape = Enum.PartType.Ball
    part.Size = Vector3.new(1.15, 1.15, 1.15)
    part.CFrame = root.CFrame * CFrame.new(0, 3.1, 0)
    part.Color = rgb(rank.color)
    part.Material = Enum.Material.Neon
    part.Anchored = true
    part.CanCollide = false
    part.CanQuery = false
    part.CanTouch = false
    part.CastShadow = false
    part.Parent = workspace
    TweenService
        :Create(part, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Transparency = 1,
            Size = Vector3.new(3.2, 3.2, 3.2),
            CFrame = root.CFrame * CFrame.new(0, 5.2, 0),
        })
        :Play()
    Debris:AddItem(part, seconds + 0.1)
end

local function playCeremony(rank)
    if not rank then
        return
    end
    ensureHud()
    chip.Visible = false
    worldPop(rank)
    ceremonyGeneration += 1
    local generation = ceremonyGeneration
    local knobs = ceremonyKnobs()
    local hold = tonumber(knobs.hold_seconds) or 0.7
    local fly = tonumber(knobs.fly_seconds) or 0.85

    local overlay = Instance.new("Frame")
    overlay.Name = "Ceremony"
    overlay.BackgroundTransparency = 1
    overlay.Size = UDim2.fromScale(1, 1)
    overlay.Parent = gui

    local cluster = Instance.new("Frame")
    cluster.Name = "Cluster"
    cluster.AnchorPoint = Vector2.new(0.5, 0.5)
    cluster.Position = UDim2.new(0.5, 0, 0.42, 0)
    cluster.Size = UDim2.fromOffset(220, 220)
    cluster.BackgroundTransparency = 1
    cluster.Parent = overlay

    local icon = CombatRank.iconAsset(rank)
    local medal
    if not icon then
        medal = buildMedal(cluster, rank, 180)
        medal.AnchorPoint = Vector2.new(0.5, 0.5)
        medal.Position = UDim2.new(0.5, 0, 0.42, 0)
    end

    local crest = Instance.new("ImageLabel")
    crest.Name = "Crest"
    crest.BackgroundTransparency = 1
    crest.AnchorPoint = Vector2.new(0.5, 0.5)
    crest.Position = UDim2.new(0.5, 0, 0.42, 0)
    crest.Size = UDim2.fromOffset(160, 160)
    crest.ScaleType = Enum.ScaleType.Fit
    crest.Image = icon or ""
    crest.Visible = icon ~= nil
    crest.ZIndex = 2
    crest.Parent = cluster

    local glyph = Instance.new("TextLabel")
    glyph.BackgroundTransparency = 1
    glyph.AnchorPoint = Vector2.new(0.5, 0.5)
    glyph.Position = UDim2.new(0.5, 0, 0.42, 0)
    glyph.Size = UDim2.fromOffset(80, 80)
    glyph.Font = Enum.Font.GothamBold
    glyph.TextSize = 42
    glyph.Text = tostring(rank.glyph or "✦")
    glyph.TextColor3 = Color3.fromRGB(255, 255, 255)
    glyph.Visible = icon == nil
    glyph.ZIndex = 2
    glyph.Parent = cluster

    local title = Instance.new("TextLabel")
    title.BackgroundTransparency = 1
    title.AnchorPoint = Vector2.new(0.5, 0)
    title.Position = UDim2.new(0.5, 0, 0.86, 0)
    title.Size = UDim2.new(1, 0, 0, 28)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 22
    title.Text = tostring(rank.label or "") .. " achieved."
    title.TextColor3 = rgb(rank.color)
    title.Parent = cluster

    task.delay(hold, function()
        if generation ~= ceremonyGeneration or not cluster.Parent then
            return
        end
        -- Land on the chip dock: left of the PlayerBar portrait.
        local landAnchor, landPos = chipLandTarget()
        local land = TweenService:Create(
            cluster,
            TweenInfo.new(fly, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
            {
                AnchorPoint = landAnchor,
                Position = landPos,
                Size = UDim2.fromOffset(
                    tonumber(knobs.chip_width) or 148,
                    tonumber(knobs.chip_height) or 36
                ),
            }
        )
        if medal then
            TweenService
                :Create(
                    medal,
                    TweenInfo.new(fly, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
                    {
                        Size = UDim2.fromOffset(28, 28),
                        Position = UDim2.new(0, 20, 0.5, 0),
                    }
                )
                :Play()
        end
        TweenService
            :Create(crest, TweenInfo.new(fly, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {
                Size = UDim2.fromOffset(28, 28),
                Position = UDim2.new(0, 20, 0.5, 0),
            })
            :Play()
        TweenService
            :Create(glyph, TweenInfo.new(fly, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {
                Size = UDim2.fromOffset(22, 22),
                Position = UDim2.new(0, 20, 0.5, 0),
                TextSize = 16,
            })
            :Play()
        TweenService
            :Create(
                title,
                TweenInfo.new(fly * 0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                {
                    TextTransparency = 1,
                }
            )
            :Play()
        land:Play()
        land.Completed:Connect(function()
            if generation ~= ceremonyGeneration then
                return
            end
            overlay:Destroy()
            applyChip(currentBadge())
        end)
    end)
end

function CombatRankController.start()
    if started then
        return CombatRankController
    end
    started = true
    ranksConfig = require(ReplicatedStorage.Configs:WaitForChild("combat_ranks"))
    pcall(function()
        peopleConfig = require(ReplicatedStorage.Configs:WaitForChild("people_list"))
    end)
    ensureHud()
    applyChip(currentBadge())

    for _, player in ipairs(Players:GetPlayers()) do
        watchPlayer(player)
    end
    Players.PlayerAdded:Connect(watchPlayer)
    Players.PlayerRemoving:Connect(function(player)
        local tag = nametags[player]
        if tag then
            tag:Destroy()
        end
        nametags[player] = nil
    end)

    if Signals.GameEvent then
        Signals.GameEvent.OnClientEvent:Connect(function(name, ctx)
            if name ~= "combat_rank_achieved" then
                return
            end
            local rankId = ctx and ctx.rankId
            local rank = CombatRank.rankById(ranksConfig, rankId) or currentRank()
            playCeremony(rank)
        end)
    end
    return CombatRankController
end

return CombatRankController
