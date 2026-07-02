--[[
    PlayerBar (client) — City-of-Heroes-style center status bar, matching
    assets/ui/reference/player_status_bar_reference.jpg:

      • one long grey glossy CAPSULE
      • a circular EMBLEM (area color) + star, overhanging the left end
      • the player NAME across the top
      • a glossy XP bar (fill + visible unfilled track)
      • a circular LEVEL disc overhanging the right end, ringed by 10 glowing SEGMENTS

    Mechanic (Jason's spec): the XP bar fills; each full fill lights ONE segment; 10 lit = ready to
    level up -> segments + number go gold and the number alternates with ▲. Area-themed via UITheme
    (emblem / fill / lit segments take the home-area color). Reads Level/XP/XPForNext/PendingLevels.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local PlayerBar = {}
local started = false

local SEGMENTS = 10
-- "Ready to level up" accent. PURPLE (matches the ASCEND nudge) so it contrasts with EVERY area
-- theme — gold would vanish into the Desert/citrine (yellow) palette.
local READY = Color3.fromRGB(150, 85, 225)
local SEG_DIM = Color3.fromRGB(35, 37, 45)

local function corner(p, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r)
    c.Parent = p
    return c
end
local function stroke(p, col, t)
    local s = Instance.new("UIStroke")
    s.Color = col
    s.Thickness = t
    s.Parent = p
    return s
end
local function grad(p, a, b)
    local g = Instance.new("UIGradient")
    g.Rotation = 90
    g.Color = ColorSequence.new(a, b)
    g.Parent = p
    return g
end
local function lighten(c, amt)
    return Color3.fromRGB(
        math.clamp(c.R * 255 + amt, 0, 255),
        math.clamp(c.G * 255 + amt, 0, 255),
        math.clamp(c.B * 255 + amt, 0, 255)
    )
end

function PlayerBar.start()
    if started then
        return
    end
    started = true
    local player = Players.LocalPlayer
    local pg = player:WaitForChild("PlayerGui")
    local Theme = require(script.Parent.Parent.UI.UITheme)

    local gui = Instance.new("ScreenGui")
    gui.Name = "PlayerBar"
    -- Sibling (modern) z-ordering: children render above their parents. TopHudStack adopts
    -- BaseUI panes into this gui, and under the legacy Global behavior an adopted pane's
    -- BACKGROUND (high ZIndex) painted over its own TEXT (low ZIndex).
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 80
    gui.Parent = pg

    -- Retire the old top-center name/level card (BaseUI player_info_pane) — this bar owns it now.
    task.spawn(function()
        local base = pg:WaitForChild("ProfessionalBaseUI", 15)
        local mc = base and base:WaitForChild("MainContainer", 5)
        for _ = 1, 20 do
            local pane = mc and mc:FindFirstChild("player_info_pane")
            if pane then
                pane.Visible = false
                return
            end
            task.wait(0.5)
        end
    end)

    -- grey glossy capsule
    local cap = Instance.new("Frame")
    cap.Name = "Capsule"
    cap.AnchorPoint = Vector2.new(0.5, 0)
    cap.Position = UDim2.new(0.5, 0, 0, 14)
    cap.Size = UDim2.fromOffset(520, 64) -- name + matched-height XP + Focus bars, compact
    -- pixel-designed: shrink on small viewports (UIViewportScale, anchored — stays docked)
    require(script.Parent.Parent.UI.UIViewportScale).attach(cap)
    cap.BackgroundColor3 = Color3.fromRGB(120, 124, 132)
    corner(cap, 28)
    grad(cap, Color3.fromRGB(150, 154, 162), Color3.fromRGB(78, 82, 90))
    stroke(cap, Color3.fromRGB(28, 30, 36), 2)
    cap.Parent = gui

    -- player name (top)
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, -150, 0, 22)
    nameLabel.Position = UDim2.fromOffset(75, 1)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Font = Enum.Font.GothamBlack
    nameLabel.TextSize = 18
    nameLabel.Text = player.DisplayName or player.Name
    nameLabel.TextColor3 = Color3.fromRGB(245, 248, 255)
    stroke(nameLabel, Color3.fromRGB(0, 0, 0), 2)
    nameLabel.Parent = cap

    -- xp bar (recessed track + glossy fill + unfilled remainder)
    local track = Instance.new("Frame")
    track.Size = UDim2.fromOffset(360, 13) -- match the Focus bar height
    track.Position = UDim2.fromOffset(70, 27)
    track.BackgroundColor3 = Color3.fromRGB(30, 32, 38)
    corner(track, 6) -- match the Focus bar's rounding
    stroke(track, Color3.fromRGB(20, 22, 26), 1.5)
    track.Parent = cap
    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(1, -4, 1, -4)
    holder.Position = UDim2.fromOffset(2, 2)
    holder.BackgroundTransparency = 1
    holder.ClipsDescendants = true
    corner(holder, 7)
    holder.Parent = track
    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(0, 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(70, 150, 255)
    corner(fill, 7)
    local fillGrad = grad(fill, Color3.fromRGB(150, 205, 255), Color3.fromRGB(45, 120, 235))
    fill.Parent = holder
    local xpText = Instance.new("TextLabel")
    xpText.Size = UDim2.fromScale(1, 1)
    xpText.BackgroundTransparency = 1
    xpText.Font = Enum.Font.GothamBold
    xpText.TextSize = 10 -- fit the thinner bar (matches the Focus bar text)
    xpText.Text = ""
    xpText.TextColor3 = Color3.fromRGB(245, 248, 255)
    xpText.ZIndex = 4
    stroke(xpText, Color3.fromRGB(0, 0, 0), 1)
    xpText.Parent = track

    -- FOCUS bar (the mana pool spent to cast; sits just below XP). CYAN — deliberately NOT the
    -- area-themed XP colour, so the two read as different resources at a glance. Driven by the
    -- Focus / FocusMax attributes FocusService replicates.
    local fxTrack = Instance.new("Frame")
    fxTrack.Name = "FocusTrack"
    fxTrack.Size = UDim2.fromOffset(360, 13)
    fxTrack.Position = UDim2.fromOffset(70, 43) -- directly under the XP bar
    fxTrack.BackgroundColor3 = Color3.fromRGB(26, 30, 40)
    corner(fxTrack, 6)
    stroke(fxTrack, Color3.fromRGB(18, 20, 26), 1.5)
    fxTrack.Visible = false -- shown once Focus replicates
    fxTrack.Parent = cap
    local fxHolder = Instance.new("Frame")
    fxHolder.Size = UDim2.new(1, -4, 1, -4)
    fxHolder.Position = UDim2.fromOffset(2, 2)
    fxHolder.BackgroundTransparency = 1
    fxHolder.ClipsDescendants = true
    corner(fxHolder, 5)
    fxHolder.Parent = fxTrack
    local fxFill = Instance.new("Frame")
    fxFill.Size = UDim2.new(1, 0, 1, 0)
    fxFill.BackgroundColor3 = Color3.fromRGB(70, 200, 235)
    corner(fxFill, 5)
    grad(fxFill, Color3.fromRGB(150, 235, 255), Color3.fromRGB(40, 160, 220))
    fxFill.Parent = fxHolder
    local fxText = Instance.new("TextLabel")
    fxText.Size = UDim2.fromScale(1, 1)
    fxText.BackgroundTransparency = 1
    fxText.Font = Enum.Font.GothamBold
    fxText.TextSize = 10
    fxText.Text = ""
    fxText.TextColor3 = Color3.fromRGB(245, 252, 255)
    fxText.ZIndex = 4
    stroke(fxText, Color3.fromRGB(0, 0, 0), 1)
    fxText.Parent = fxTrack

    -- emblem circle (overhangs left)
    local emblem = Instance.new("Frame")
    emblem.Size = UDim2.fromOffset(62, 62)
    emblem.AnchorPoint = Vector2.new(0.5, 0.5)
    emblem.Position = UDim2.new(0, 8, 0.5, 0)
    emblem.BackgroundColor3 = Color3.fromRGB(50, 90, 180)
    corner(emblem, 31)
    local emblemGrad = grad(emblem, Color3.fromRGB(120, 170, 240), Color3.fromRGB(30, 60, 140))
    stroke(emblem, Color3.fromRGB(20, 24, 40), 3)
    emblem.ZIndex = 5
    emblem.Parent = cap
    -- Origin slot (the CoH "origin" badge): shows the player's chosen-origin icon once set, else a
    -- neutral "person" placeholder (origin is picked at level 5). Driven by the OriginIcon attribute
    -- (an "rbxassetid://..." string) — set that when the origin is chosen and the emblem fills in.
    local originIcon = Instance.new("ImageLabel")
    originIcon.Name = "OriginIcon"
    originIcon.Size = UDim2.fromScale(0.74, 0.74)
    originIcon.AnchorPoint = Vector2.new(0.5, 0.5)
    originIcon.Position = UDim2.fromScale(0.5, 0.5)
    originIcon.BackgroundTransparency = 1
    originIcon.ScaleType = Enum.ScaleType.Fit
    originIcon.Visible = false
    originIcon.ZIndex = 6
    originIcon.Parent = emblem
    -- pre-origin: the player's OWN avatar headshot (Jason: "weird player emoji... use
    -- the player's character head"), circle-cropped to the emblem
    local originPlaceholder = Instance.new("ImageLabel")
    originPlaceholder.Name = "OriginPlaceholder"
    originPlaceholder.Size = UDim2.fromScale(1, 1)
    originPlaceholder.BackgroundTransparency = 1
    originPlaceholder.ScaleType = Enum.ScaleType.Fit
    originPlaceholder.ZIndex = 6
    local phCorner = Instance.new("UICorner")
    phCorner.CornerRadius = UDim.new(0.5, 0)
    phCorner.Parent = originPlaceholder
    originPlaceholder.Parent = emblem
    task.spawn(function()
        local ok, img = pcall(function()
            return Players:GetUserThumbnailAsync(
                player.UserId,
                Enum.ThumbnailType.HeadShot,
                Enum.ThumbnailSize.Size100x100
            )
        end)
        if ok and originPlaceholder.Parent then
            originPlaceholder.Image = img
        end
    end)
    local function refreshOrigin()
        local iconId = player:GetAttribute("OriginIcon")
        local has = type(iconId) == "string" and iconId ~= ""
        if has then
            originIcon.Image = iconId
        end
        originIcon.Visible = has
        originPlaceholder.Visible = not has
    end
    refreshOrigin()
    player:GetAttributeChangedSignal("OriginIcon"):Connect(refreshOrigin)

    -- The portrait IS the Active Buffs panel button now: the top-left HUD buff badges became on/off
    -- toggle controls (clicking one toggles its power), so they can't double as the panel opener
    -- anymore (Jason). A transparent button over the emblem toggles BuffStatsHud.
    local buffsBtn = Instance.new("TextButton")
    buffsBtn.Name = "BuffsPanelButton"
    buffsBtn.BackgroundTransparency = 1
    buffsBtn.Text = ""
    buffsBtn.Size = UDim2.fromScale(1, 1)
    buffsBtn.ZIndex = 8
    buffsBtn.Parent = emblem
    buffsBtn.Activated:Connect(function()
        local ok, BuffStatsHud = pcall(function()
            return require(script.Parent.BuffStatsHud)
        end)
        if ok and BuffStatsHud and BuffStatsHud.toggle then
            BuffStatsHud.toggle()
        end
    end)

    -- level disc (overhangs right) + 10 glowing segments + inner + number
    local disc = Instance.new("Frame")
    disc.Size = UDim2.fromOffset(66, 66)
    disc.AnchorPoint = Vector2.new(0.5, 0.5)
    disc.Position = UDim2.new(1, -8, 0.5, 0)
    disc.BackgroundColor3 = Color3.fromRGB(60, 62, 70)
    corner(disc, 33)
    grad(disc, Color3.fromRGB(95, 98, 108), Color3.fromRGB(45, 47, 55))
    stroke(disc, Color3.fromRGB(24, 26, 32), 3)
    disc.ZIndex = 5
    disc.Parent = cap
    local segs = {}
    for i = 1, SEGMENTS do
        local ang = math.rad(-90 + (i - 1) * (360 / SEGMENTS))
        local seg = Instance.new("Frame")
        seg.Name = "Seg" .. i
        seg.Size = UDim2.fromOffset(7, 13)
        seg.AnchorPoint = Vector2.new(0.5, 0.5)
        seg.Position = UDim2.new(0.5, math.cos(ang) * 25, 0.5, math.sin(ang) * 25)
        seg.Rotation = math.deg(ang) + 90
        seg.BackgroundColor3 = SEG_DIM
        seg.BorderSizePixel = 0
        corner(seg, 2)
        seg.ZIndex = 6
        local glow = Instance.new("UIStroke")
        glow.Name = "Glow"
        glow.Thickness = 2
        glow.Transparency = 1
        glow.Parent = seg
        seg.Parent = disc
        segs[i] = seg
    end
    local inner = Instance.new("Frame")
    inner.Size = UDim2.fromOffset(40, 40)
    inner.AnchorPoint = Vector2.new(0.5, 0.5)
    inner.Position = UDim2.fromScale(0.5, 0.5)
    inner.BackgroundColor3 = Color3.fromRGB(40, 42, 50)
    corner(inner, 20)
    inner.ZIndex = 7
    inner.Parent = disc
    local levelText = Instance.new("TextLabel")
    levelText.Name = "Num"
    levelText.Size = UDim2.fromScale(1, 1)
    levelText.BackgroundTransparency = 1
    levelText.Font = Enum.Font.GothamBlack
    levelText.TextSize = 22
    levelText.Text = "1"
    levelText.TextColor3 = Color3.fromRGB(245, 248, 255)
    levelText.ZIndex = 8
    stroke(levelText, Color3.fromRGB(0, 0, 0), 2)
    levelText.Parent = inner

    -- ---- data + render ----------------------------------------------------
    local palette = Theme.palette(player)
    local function applyTheme(p)
        palette = p
        emblem.BackgroundColor3 = p.fill
        emblemGrad.Color = ColorSequence.new(lighten(p.primary, 30), p.fill)
        fill.BackgroundColor3 = p.fill
        fillGrad.Color = ColorSequence.new(lighten(p.fill, 80), p.fill)
    end
    Theme.bind(player, applyTheme)

    local blinkOn = true
    -- Focus bar is smoothed every frame toward these (the server value updates in 1s / +5 steps).
    local fxShown, fxTarget, fxMaxV = 0, 0, 0
    local function refresh()
        local level = tonumber(player:GetAttribute("Level"))
            or tonumber(player:GetAttribute("ClaimedLevel"))
            or 1
        local xp = tonumber(player:GetAttribute("XP")) or 0
        local need = tonumber(player:GetAttribute("XPForNext")) or 0
        -- VETERAN track (docs/VETERAN_LEVELS.md): at the cap the level bar pegs (need=0) — it
        -- becomes the VET bar instead: fills toward the next veteran level and labels VET N,
        -- so max-level XP always reads as progress instead of freezing at "34300 / 34300".
        local vetLevel = 0
        local atCapVet = false
        if need <= 0 then
            local vetNeed = tonumber(player:GetAttribute("VetXPForNext")) or 0
            if vetNeed > 0 then
                vetLevel = tonumber(player:GetAttribute("VetLevel")) or 0
                xp = tonumber(player:GetAttribute("VetXP")) or 0
                need = vetNeed
                atCapVet = true
            end
        end
        local pending = tonumber(player:GetAttribute("PendingLevels")) or 0
        local progress = need > 0 and math.clamp(xp / need, 0, 1) or 0
        local ready = pending > 0 or (progress >= 1 and not atCapVet)
        local lit = ready and SEGMENTS or math.floor(progress * SEGMENTS)
        local within = ready and 1 or (progress * SEGMENTS - lit)
        local segColor = ready and READY or lighten(palette.primary, 25)

        for i = 1, SEGMENTS do
            local on = i <= lit
            segs[i].BackgroundColor3 = on and segColor or SEG_DIM
            local glow = segs[i]:FindFirstChild("Glow")
            if glow then
                glow.Color = segColor
                glow.Transparency = on and 0.35 or 1
            end
        end
        fill.Size = UDim2.new(math.clamp(within, ready and 1 or 0.02, 1), 0, 1, 0)
        if ready then
            fill.BackgroundColor3 = READY
            fillGrad.Color = ColorSequence.new(lighten(READY, 40), READY)
        else
            -- caught up: restore the themed (area-colour) fill — the gold was set with no reset, so
            -- the bar stayed gold after ascending even once PendingLevels hit 0.
            fill.BackgroundColor3 = palette.fill
            fillGrad.Color = ColorSequence.new(lighten(palette.fill, 80), palette.fill)
        end
        if atCapVet then
            xpText.Text = string.format("VET %d · %d / %d XP", vetLevel, math.floor(xp), need)
        else
            xpText.Text = need > 0 and string.format("%d / %d XP", math.floor(xp), need) or ""
        end
        levelText.Text = (ready and not blinkOn) and "▲" or tostring(level)
        levelText.TextColor3 = ready and READY or Color3.fromRGB(245, 248, 255)

        -- Focus pool (mana spent to cast) — replicated by FocusService via Focus / FocusMax.
        -- Stash the server value; the Heartbeat below glides the bar toward it so the +5/sec regen
        -- steps don't jump.
        local fx = tonumber(player:GetAttribute("Focus"))
        local fxMax = tonumber(player:GetAttribute("FocusMax")) or 0
        fxTrack.Visible = fx ~= nil and fxMax > 0
        fxTarget = fx or 0
        fxMaxV = fxMax
    end

    applyTheme(palette)
    refresh()

    local accum, blinkAccum = 0, 0
    RunService.Heartbeat:Connect(function(dt)
        accum += dt
        blinkAccum += dt
        if blinkAccum >= 0.55 then
            blinkAccum = 0
            blinkOn = not blinkOn
        end
        if accum >= 0.2 then
            accum = 0
            refresh()
        end
        -- Glide the Focus bar toward the server value every frame (the server pushes Focus on spend +
        -- once a second on regen), so it animates smoothly instead of stepping in 5s.
        if fxMaxV > 0 then
            fxShown += (fxTarget - fxShown) * math.min(1, dt * 9)
            if math.abs(fxTarget - fxShown) < 0.5 then
                fxShown = fxTarget
            end
            fxFill.Size = UDim2.new(math.clamp(fxShown / fxMaxV, 0, 1), 0, 1, 0)
            fxText.Text = string.format("⚡ %d / %d", math.floor(fxShown + 0.5), fxMaxV)
        end
    end)
end

return PlayerBar
