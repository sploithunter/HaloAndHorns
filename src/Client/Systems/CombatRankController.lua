--[[
    CombatRankController — placeholder crest ceremony + list chip + nametag.

    Pillar grant fires combat_rank_achieved. A neon disc pops on the body,
    then a ViewportFrame crest flies to the People-list corner and docks as
    the current title. Other clients read CombatRank / CombatRankLabel.
]]

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local CombatRank = require(ReplicatedStorage.Shared.Game.CombatRank)
local Signals = require(ReplicatedStorage.Shared.Network.Signals)

local CombatRankController = {}
local started = false
local ranksConfig
local gui
local chip
local chipGlyph
local chipIcon
local chipLabel
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

local function applyChip(rank)
    if not chip then
        return
    end
    if not rank then
        chip.Visible = false
        return
    end
    chip.Visible = true
    chip.UIStroke.Color = rgb(rank.color)
    local icon = CombatRank.iconAsset(rank)
    if icon then
        chipIcon.Image = icon
        chipIcon.Visible = true
        chipGlyph.Visible = false
    else
        chipIcon.Visible = false
        chipGlyph.Visible = true
        chipGlyph.Text = tostring(rank.glyph or "✦")
        chipGlyph.TextColor3 = rgb(rank.color)
    end
    chipLabel.Text = tostring(rank.label or "")
    chipLabel.TextColor3 = rgb(rank.color)
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
    gui.Parent = pg

    -- Sit immediately left of Roblox's People list (397px wide, 4px from the
    -- right, 14px from the rounded-screen top — same measured inset as
    -- QuestTrackerStyle). Scale/anchors cannot express that CoreGui width.
    chip = Instance.new("Frame")
    chip.Name = "Chip"
    chip.AnchorPoint = Vector2.new(1, 0)
    chip.Position = UDim2.new(1, -(397 + 4 + 8), 0, 14)
    chip.Size =
        UDim2.fromOffset(tonumber(knobs.chip_width) or 148, tonumber(knobs.chip_height) or 36)
    chip.BackgroundColor3 = Color3.fromRGB(18, 16, 24)
    chip.BackgroundTransparency = 0.08
    chip.BorderSizePixel = 0
    chip.Visible = false
    chip.Parent = gui
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = chip
    local stroke = Instance.new("UIStroke")
    stroke.Name = "UIStroke"
    stroke.Thickness = 1.5
    stroke.Transparency = 0.15
    stroke.Parent = chip

    chipGlyph = Instance.new("TextLabel")
    chipGlyph.Name = "Glyph"
    chipGlyph.BackgroundTransparency = 1
    chipGlyph.Size = UDim2.fromOffset(28, 28)
    chipGlyph.Position = UDim2.fromOffset(6, 4)
    chipGlyph.Font = Enum.Font.GothamBold
    chipGlyph.TextSize = 18
    chipGlyph.Parent = chip

    chipIcon = Instance.new("ImageLabel")
    chipIcon.Name = "Icon"
    chipIcon.BackgroundTransparency = 1
    chipIcon.Size = UDim2.fromOffset(28, 28)
    chipIcon.Position = UDim2.fromOffset(6, 4)
    chipIcon.ScaleType = Enum.ScaleType.Fit
    chipIcon.Visible = false
    chipIcon.Parent = chip

    chipLabel = Instance.new("TextLabel")
    chipLabel.Name = "Label"
    chipLabel.BackgroundTransparency = 1
    chipLabel.Position = UDim2.fromOffset(32, 0)
    chipLabel.Size = UDim2.new(1, -38, 1, 0)
    chipLabel.Font = Enum.Font.GothamBold
    chipLabel.TextSize = 16
    chipLabel.TextXAlignment = Enum.TextXAlignment.Left
    chipLabel.Parent = chip
end

local function attachNametag(player)
    local existing = nametags[player]
    if existing then
        existing:Destroy()
        nametags[player] = nil
    end
    local rank = CombatRank.rankById(ranksConfig, player:GetAttribute("CombatRank"))
    local label = player:GetAttribute("CombatRankLabel")
    if type(label) ~= "string" or label == "" then
        label = rank and rank.label
    end
    if not (rank and type(label) == "string" and label ~= "") then
        return
    end
    local character = player.Character
    local head = character and character:FindFirstChild("Head")
    if not head then
        return
    end
    local knobs = ceremonyKnobs()
    local bb = Instance.new("BillboardGui")
    bb.Name = "CombatRankTag"
    bb.Adornee = head
    bb.AlwaysOnTop = false
    bb.MaxDistance = tonumber(knobs.nametag_max_distance) or 80
    bb.Size = UDim2.fromOffset(140, 22)
    bb.StudsOffset = Vector3.new(0, tonumber(knobs.nametag_studs) or 2.55, 0)
    bb.ResetOnSpawn = false
    bb.Parent = head
    local icon = CombatRank.iconAsset(rank)
    if icon then
        local image = Instance.new("ImageLabel")
        image.BackgroundTransparency = 1
        image.Size = UDim2.fromOffset(20, 20)
        image.Position = UDim2.fromOffset(4, 1)
        image.ScaleType = Enum.ScaleType.Fit
        image.Image = icon
        image.Parent = bb
    end
    local text = Instance.new("TextLabel")
    text.BackgroundTransparency = 1
    text.Position = icon and UDim2.fromOffset(26, 0) or UDim2.fromOffset(0, 0)
    text.Size = icon and UDim2.new(1, -28, 1, 0) or UDim2.fromScale(1, 1)
    text.Font = Enum.Font.GothamBold
    text.TextSize = 14
    text.Text = icon and label or (tostring(rank.glyph or "✦") .. "  " .. label)
    text.TextColor3 = rgb(rank.color)
    text.TextStrokeTransparency = 0.35
    text.TextXAlignment = Enum.TextXAlignment.Left
    text.Parent = bb
    nametags[player] = bb
end

local function watchPlayer(player)
    local function refresh()
        attachNametag(player)
        if player == Players.LocalPlayer then
            applyChip(currentRank())
        end
    end
    player:GetAttributeChangedSignal("CombatRank"):Connect(refresh)
    player:GetAttributeChangedSignal("CombatRankLabel"):Connect(refresh)
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
        -- Land on the chip dock: left of the 397px People list, 14px from top.
        local land = TweenService:Create(
            cluster,
            TweenInfo.new(fly, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
            {
                AnchorPoint = Vector2.new(1, 0),
                Position = UDim2.new(1, -(397 + 4 + 8), 0, 14),
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
            applyChip(rank)
        end)
    end)
end

function CombatRankController.start()
    if started then
        return CombatRankController
    end
    started = true
    ranksConfig = require(ReplicatedStorage.Configs:WaitForChild("combat_ranks"))
    ensureHud()
    applyChip(currentRank())

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
