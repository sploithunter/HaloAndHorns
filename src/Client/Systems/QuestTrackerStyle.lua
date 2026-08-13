--[[
    QuestTrackerStyle (client) — move the Current Quest tracker out of the top-right and dock it
    directly BELOW the center player bar, restyled to match (a dark capsule with a blue progress bar
    on top + the quest name below), per assets/ui/reference/player_status_quest_combo_reference.png.

    Scoped post-process of ProfessionalBaseUI's quest_tracker_pane (BaseUI logic untouched). The
    progress fill is area-themed via UITheme (blue default). Idempotent.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local QuestDisplayMode = require(ReplicatedStorage.Shared.Game.QuestDisplayMode)

local QuestTrackerStyle = {}
local started = false
QuestTrackerStyle._pane = nil
QuestTrackerStyle._dismissed = false
QuestTrackerStyle._tipActive = false
QuestTrackerStyle._tipProgress = nil
QuestTrackerStyle._tipDescription = nil
QuestTrackerStyle._manuallyExpanded = false
QuestTrackerStyle._autoExpandedUntil = 0
QuestTrackerStyle._lastObjectiveKey = nil
QuestTrackerStyle._lastObjectiveFraction = nil

local applyPresentation = function() end
local autoExpandGeneration = 0

-- The tracker's visibility is a pure function of the dismissed flag — set by the X, cleared when the
-- Quest menu opens or a quest becomes claimable (Jason: it's in the way when idle, esp. on mobile).
local function applyVisibility()
    if QuestTrackerStyle._pane then
        QuestTrackerStyle._pane.Visible = not QuestTrackerStyle._dismissed
        applyPresentation()
    end
end

-- Re-show the tracker. Public so BaseUI (new claimable) + QuestPanel (menu opened) can un-dismiss it.
function QuestTrackerStyle.show()
    QuestTrackerStyle._dismissed = false
    applyVisibility()
end

local function autoExpand(seconds)
    autoExpandGeneration += 1
    local generation = autoExpandGeneration
    QuestTrackerStyle._autoExpandedUntil = os.clock() + seconds
    applyPresentation()
    local connection
    connection = RunService.Heartbeat:Connect(function()
        if
            generation ~= autoExpandGeneration
            or os.clock() >= QuestTrackerStyle._autoExpandedUntil
        then
            connection:Disconnect()
            if generation == autoExpandGeneration then
                applyPresentation()
            end
        end
    end)
end

-- Called by BaseUI at the authoritative quest/mission update seams. Compact presentations briefly
-- borrow the readable full bar for a new objective or a real progress gain, then settle back down.
function QuestTrackerStyle.notifyObjective(key, fraction)
    key = tostring(key or "")
    fraction = math.clamp(tonumber(fraction) or 0, 0, 1)
    local previousKey = QuestTrackerStyle._lastObjectiveKey
    local previousFraction = QuestTrackerStyle._lastObjectiveFraction
    QuestTrackerStyle._lastObjectiveKey = key
    QuestTrackerStyle._lastObjectiveFraction = fraction

    if
        QuestDisplayMode.normalize(Players.LocalPlayer:GetAttribute("QuestDisplayMode")) == "full"
    then
        applyPresentation()
        return
    end
    if previousKey ~= key then
        autoExpand(4)
    elseif previousFraction ~= nil and fraction > previousFraction + 0.0001 then
        autoExpand(2.5)
    else
        applyPresentation()
    end
end

local function ensureTipOverlay()
    local pane = QuestTrackerStyle._pane
    if not pane then
        return false
    end
    if QuestTrackerStyle._tipProgress and QuestTrackerStyle._tipDescription then
        return true
    end

    local originalProgress = pane:FindFirstChild("ProgressBackground")
    local originalDescription = pane:FindFirstChild("QuestDescription")
    if not originalProgress or not originalDescription then
        return false
    end

    -- Clone the already-restyled quest layers so tips use the exact same capsule, geometry, font,
    -- outline, and fill treatment. The live quest controls keep updating underneath while hidden.
    local tipProgress = originalProgress:Clone()
    tipProgress.Name = "TipProgressBackground"
    tipProgress.ZIndex = 40
    tipProgress.Visible = false
    local tipFill = tipProgress:FindFirstChild("Fill")
    if tipFill then
        tipFill.Size = UDim2.new(1, 0, 1, 0)
        tipFill.ZIndex = 41
    end
    local tipProgressText = tipProgress:FindFirstChild("ProgressText")
    if tipProgressText then
        tipProgressText.Text = "TIP"
        tipProgressText.ZIndex = 42
    end
    tipProgress.Parent = pane

    local tipDescription = originalDescription:Clone()
    tipDescription.Name = "TipDescription"
    tipDescription.Text = ""
    tipDescription.ZIndex = 42
    tipDescription.Visible = false
    tipDescription.Parent = pane

    QuestTrackerStyle._tipProgress = tipProgress
    QuestTrackerStyle._tipDescription = tipDescription
    return true
end

function QuestTrackerStyle.isTipActive()
    return QuestTrackerStyle._tipActive == true
end

function QuestTrackerStyle.showTip(text)
    if
        QuestTrackerStyle._dismissed
        or type(text) ~= "string"
        or text == ""
        or not ensureTipOverlay()
    then
        return false
    end

    local pane = QuestTrackerStyle._pane
    local originalProgress = pane:FindFirstChild("ProgressBackground")
    local originalDescription = pane:FindFirstChild("QuestDescription")
    if originalProgress then
        originalProgress.Visible = false
    end
    if originalDescription then
        originalDescription.Visible = false
    end
    local hover = pane:FindFirstChild("QuestHoverTip")
    if hover then
        hover.Visible = false
    end
    local claim = pane:FindFirstChild("QuestClaimButton")
    if claim then
        claim.Visible = false
    end

    QuestTrackerStyle._tipDescription.Text = text
    QuestTrackerStyle._tipProgress.Visible = true
    QuestTrackerStyle._tipDescription.Visible = true
    QuestTrackerStyle._tipActive = true
    QuestTrackerStyle.setTipProgress(1)
    applyPresentation()
    return true
end

function QuestTrackerStyle.setTipProgress(fraction)
    local progress = QuestTrackerStyle._tipProgress
    local fill = progress and progress:FindFirstChild("Fill")
    if fill then
        fill.Size = UDim2.new(math.clamp(tonumber(fraction) or 0, 0, 1), 0, 1, 0)
    end
end

function QuestTrackerStyle.hideTip()
    QuestTrackerStyle._tipActive = false
    if QuestTrackerStyle._tipProgress then
        QuestTrackerStyle._tipProgress.Visible = false
    end
    if QuestTrackerStyle._tipDescription then
        QuestTrackerStyle._tipDescription.Visible = false
    end

    local pane = QuestTrackerStyle._pane
    if pane then
        local originalProgress = pane:FindFirstChild("ProgressBackground")
        local originalDescription = pane:FindFirstChild("QuestDescription")
        if originalProgress then
            originalProgress.Visible = true
        end
        if originalDescription then
            originalDescription.Visible = true
        end
    end
    applyPresentation()
end

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
local function outline(label)
    if not label:FindFirstChildOfClass("UIStroke") then
        local s = Instance.new("UIStroke")
        s.Color = Color3.fromRGB(0, 0, 0)
        s.Thickness = 2
        s.Parent = label
    end
end

function QuestTrackerStyle.start()
    if started then
        return
    end
    started = true
    local player = Players.LocalPlayer
    local pg = player:WaitForChild("PlayerGui")

    task.spawn(function()
        local base = pg:WaitForChild("ProfessionalBaseUI", 20)
        local mc = base and base:WaitForChild("MainContainer", 10)
        local pane
        local deadline = os.clock() + 15
        while os.clock() < deadline do
            -- pg-wide recursive: TopHudStack may have adopted the pane into the PlayerBar
            -- capsule's stack before we got here (it is no longer under MainContainer)
            pane = (mc and mc:FindFirstChild("quest_tracker_pane"))
                or pg:FindFirstChild("quest_tracker_pane", true)
            if pane then
                break
            end
            RunService.Heartbeat:Wait()
        end
        if not pane or pane:GetAttribute("Restyled") then
            return
        end
        pane:SetAttribute("Restyled", true)

        -- dock TIGHT below the player bar (Jason: as close as possible) — compact pane.
        pane.AnchorPoint = Vector2.new(0.5, 0)
        pane.Position = UDim2.new(0.5, 0, 0, 68)
        pane.Size = UDim2.fromOffset(360, 40) -- compact strip (Jason: shrink it down)
        -- The PANE (the pill the bar sits in) is the neutral player-bar capsule gray — Jason: the
        -- BLACK pill should go gray, not the (green) bar fill.
        pane.BackgroundColor3 = Color3.fromRGB(120, 124, 132)
        pane.BackgroundTransparency = 0
        corner(pane, 16)
        grad(pane, Color3.fromRGB(150, 154, 162), Color3.fromRGB(78, 82, 90))
        stroke(pane, Color3.fromRGB(28, 30, 36), 2)
        -- Scale in lockstep with the player bar (which is UIViewportScale'd) so the quest bar renders
        -- the SAME size as the Focus bar on every viewport — without this it stays full-size and reads
        -- bigger than the (scaled-down) Focus bar. (Jason: shrink it to match.)
        if not pane:FindFirstChildOfClass("UIScale") then
            require(script.Parent.Parent.UI.UIViewportScale).attach(pane)
        end

        local title = pane:FindFirstChild("QuestTitle")
        if title then
            title.Visible = false -- reference drops the "Current Quest" header
        end

        -- progress bar on TOP (the bar fill is left AS-IS — Jason: the bar color shouldn't change)
        local pbg = pane:FindFirstChild("ProgressBackground")
        local ptext = pbg and pbg:FindFirstChild("ProgressText")
        if pbg then
            pbg.AnchorPoint = Vector2.new(0.5, 0)
            pbg.Position = UDim2.new(0.5, 0, 0, 5)
            pbg.Size = UDim2.fromOffset(300, 10) -- thin strip, a touch under the Focus bar (leaves a left gutter for the dismiss X)
            pbg.BackgroundColor3 = Color3.fromRGB(18, 20, 26)
            pbg.ZIndex = 2
            stroke(pbg, Color3.fromRGB(70, 110, 180), 1.5)
        end

        -- quest name on the BOTTOM
        local desc = pane:FindFirstChild("QuestDescription")
        if desc then
            desc.AnchorPoint = Vector2.new(0.5, 1)
            desc.Position = UDim2.new(0.5, 0, 1, -4)
            desc.Size = UDim2.new(1, -20, 0, 18)
            desc.Font = Enum.Font.GothamBlack
            desc.TextScaled = true
            desc.TextColor3 = Color3.fromRGB(245, 248, 255)
            desc.ZIndex = 2
            outline(desc)
        end
        if ptext then
            ptext.TextColor3 = Color3.fromRGB(245, 248, 255)
            ptext.ZIndex = 4
            outline(ptext)
        end
        -- the FillBar's FILL kept its pre-restyle ZIndex (14) and painted OVER
        -- the count (Jason: "once the bar goes over you can't see how many you
        -- have to do anymore") — drop it under the ptext layer
        local fill = pbg and pbg:FindFirstChild("Fill")
        if fill then
            fill.ZIndex = 3
        end

        -- Dismiss X — top-left gutter (clear of the top-right CLAIM chip). Hides the tracker until
        -- the Quest menu is opened or a quest becomes claimable.
        if not pane:FindFirstChild("DismissX") then
            local x = Instance.new("TextButton")
            x.Name = "DismissX"
            x.AnchorPoint = Vector2.new(0, 0)
            x.Position = UDim2.new(0, 3, 0, 2)
            x.Size = UDim2.fromOffset(16, 16)
            x.BackgroundColor3 = Color3.fromRGB(70, 72, 80)
            x.Text = "✕"
            x.TextColor3 = Color3.fromRGB(235, 238, 245)
            x.TextScaled = true
            x.Font = Enum.Font.GothamBold
            x.ZIndex = 6
            x.Parent = pane
            corner(x, 8)
            stroke(x, Color3.fromRGB(28, 30, 36), 1)
            x.Activated:Connect(function()
                QuestTrackerStyle._dismissed = true
                applyVisibility()
            end)
        end

        -- Alternate compact presentations share the live description/count/fill above. The ring is
        -- deliberately segmented: its lit segments follow the FillBar's tweened Size every frame,
        -- producing a smooth clockwise sweep without a second progress model.
        local compactGlyph = Instance.new("TextLabel")
        compactGlyph.Name = "QuestCompactGlyph"
        compactGlyph.BackgroundTransparency = 1
        compactGlyph.Text = "◆"
        compactGlyph.TextColor3 = Color3.fromRGB(125, 205, 255)
        compactGlyph.Font = Enum.Font.GothamBlack
        compactGlyph.TextSize = 15
        compactGlyph.ZIndex = 12
        compactGlyph.Visible = false
        compactGlyph.Parent = pane

        local compactCount = Instance.new("TextLabel")
        compactCount.Name = "QuestCompactCount"
        compactCount.BackgroundTransparency = 1
        compactCount.TextColor3 = Color3.fromRGB(245, 248, 255)
        compactCount.Font = Enum.Font.GothamBold
        compactCount.TextSize = 11
        compactCount.TextScaled = false
        compactCount.ZIndex = 12
        compactCount.Visible = false
        outline(compactCount)
        compactCount.Parent = pane

        local ringSegments = {}
        local segmentCount = 36
        for index = 1, segmentCount do
            local angle = ((index - 1) / segmentCount) * math.pi * 2 - (math.pi / 2)
            local segment = Instance.new("Frame")
            segment.Name = string.format("RingSegment%02d", index)
            segment.AnchorPoint = Vector2.new(0.5, 0.5)
            segment.Position =
                UDim2.fromOffset(29 + math.cos(angle) * 25, 29 + math.sin(angle) * 25)
            segment.Size = UDim2.fromOffset(3, 6)
            segment.Rotation = math.deg(angle) + 90
            segment.BackgroundColor3 = Color3.fromRGB(36, 42, 54)
            segment.BorderSizePixel = 0
            segment.ZIndex = 11
            segment.Visible = false
            corner(segment, 2)
            segment.Parent = pane
            ringSegments[index] = segment
        end

        local function compactCountText()
            local raw = ptext and ptext.Text or ""
            if raw == "✓ Claim!" then
                return "CLAIM"
            end
            if raw:find("/", 1, true) then
                return raw
            end
            return "★"
        end

        local function updateRing(fraction)
            fraction = math.clamp(tonumber(fraction) or 0, 0, 1)
            local lit = fraction * segmentCount
            local activeColor = fill and fill.BackgroundColor3 or Color3.fromRGB(46, 204, 113)
            for index, segment in ipairs(ringSegments) do
                local coverage = math.clamp(lit - (index - 1), 0, 1)
                segment.BackgroundColor3 =
                    activeColor:Lerp(Color3.fromRGB(36, 42, 54), 1 - coverage)
            end
        end

        local toggle = Instance.new("TextButton")
        toggle.Name = "QuestDisplayToggle"
        toggle.Size = UDim2.fromScale(1, 1)
        toggle.BackgroundTransparency = 1
        toggle.Text = ""
        toggle.AutoButtonColor = false
        toggle.ZIndex = 5
        toggle.Visible = false
        toggle.Parent = pane

        applyPresentation = function()
            if not QuestTrackerStyle._pane then
                return
            end
            local mode = QuestDisplayMode.normalize(player:GetAttribute("QuestDisplayMode"))
            local expanded = mode == "full"
                or QuestTrackerStyle._manuallyExpanded
                or QuestTrackerStyle._tipActive
                or QuestTrackerStyle._autoExpandedUntil > os.clock()
            local collapsedPill = mode == "pill" and not expanded
            local collapsedRing = mode == "ring" and not expanded
            local paneCorner = pane:FindFirstChildOfClass("UICorner")

            compactCount.Text = compactCountText()
            compactGlyph.Visible = collapsedPill or collapsedRing
            compactCount.Visible = collapsedPill or collapsedRing
            toggle.Visible = mode ~= "full"

            for _, segment in ipairs(ringSegments) do
                segment.Visible = collapsedRing
            end

            local tipProgress = QuestTrackerStyle._tipProgress
            local tipDescription = QuestTrackerStyle._tipDescription
            local dismiss = pane:FindFirstChild("DismissX")
            local claim = pane:FindFirstChild("QuestClaimButton")

            if collapsedRing then
                pane.Size = UDim2.fromOffset(58, 58)
                if paneCorner then
                    paneCorner.CornerRadius = UDim.new(1, 0)
                end
                compactGlyph.Position = UDim2.fromOffset(17, 8)
                compactGlyph.Size = UDim2.fromOffset(24, 18)
                compactGlyph.TextSize = 14
                compactCount.Position = UDim2.fromOffset(4, 28)
                compactCount.Size = UDim2.fromOffset(50, 18)
                compactCount.TextSize = 10
                if pbg then
                    pbg.Visible = false
                end
                if desc then
                    desc.Visible = false
                end
            elseif collapsedPill then
                pane.Size = UDim2.fromOffset(220, 34)
                if paneCorner then
                    paneCorner.CornerRadius = UDim.new(1, 0)
                end
                compactGlyph.Position = UDim2.fromOffset(8, 7)
                compactGlyph.Size = UDim2.fromOffset(20, 20)
                compactGlyph.TextSize = 13
                compactCount.Position = UDim2.new(1, -44, 0, 6)
                compactCount.Size = UDim2.fromOffset(38, 18)
                compactCount.TextSize = 10
                if desc then
                    desc.AnchorPoint = Vector2.new(0, 0.5)
                    desc.Position = UDim2.new(0, 31, 0.5, -1)
                    desc.Size = UDim2.new(1, -78, 0, 20)
                    desc.TextXAlignment = Enum.TextXAlignment.Left
                    desc.TextTruncate = Enum.TextTruncate.AtEnd
                    desc.TextWrapped = false
                    desc.TextScaled = false
                    desc.TextSize = 12
                    desc.Visible = true
                end
                if pbg then
                    pbg.AnchorPoint = Vector2.new(0, 1)
                    pbg.Position = UDim2.new(0, 31, 1, -3)
                    pbg.Size = UDim2.new(1, -79, 0, 3)
                    pbg.Visible = true
                end
                if ptext then
                    ptext.Visible = false
                end
            else
                pane.Size = UDim2.fromOffset(360, 40)
                if paneCorner then
                    paneCorner.CornerRadius = UDim.new(0, 16)
                end
                if pbg then
                    pbg.AnchorPoint = Vector2.new(0.5, 0)
                    pbg.Position = UDim2.new(0.5, 0, 0, 5)
                    pbg.Size = UDim2.fromOffset(300, 10)
                    pbg.Visible = not QuestTrackerStyle._tipActive
                end
                if ptext then
                    ptext.Visible = true
                end
                if desc then
                    desc.AnchorPoint = Vector2.new(0.5, 1)
                    desc.Position = UDim2.new(0.5, 0, 1, -4)
                    desc.Size = UDim2.new(1, -20, 0, 18)
                    desc.TextXAlignment = Enum.TextXAlignment.Center
                    desc.TextTruncate = Enum.TextTruncate.None
                    desc.TextWrapped = false
                    desc.TextScaled = true
                    desc.Visible = not QuestTrackerStyle._tipActive
                end
            end

            if tipProgress then
                tipProgress.AnchorPoint = Vector2.new(0.5, 0)
                tipProgress.Position = UDim2.new(0.5, 0, 0, 5)
                tipProgress.Size = UDim2.fromOffset(300, 10)
                tipProgress.Visible = QuestTrackerStyle._tipActive
            end
            if tipDescription then
                tipDescription.AnchorPoint = Vector2.new(0.5, 1)
                tipDescription.Position = UDim2.new(0.5, 0, 1, -4)
                tipDescription.Size = UDim2.new(1, -20, 0, 18)
                tipDescription.TextXAlignment = Enum.TextXAlignment.Center
                tipDescription.TextWrapped = false
                tipDescription.TextScaled = true
                tipDescription.Visible = QuestTrackerStyle._tipActive
            end
            if dismiss then
                dismiss.Visible = expanded
            end
            if claim then
                claim.Visible = expanded
                    and not QuestTrackerStyle._tipActive
                    and claim:GetAttribute("Available") == true
            end
        end

        toggle.Activated:Connect(function()
            local mode = QuestDisplayMode.normalize(player:GetAttribute("QuestDisplayMode"))
            if mode == "full" then
                return
            end
            local expanded = QuestTrackerStyle._manuallyExpanded
                or QuestTrackerStyle._autoExpandedUntil > os.clock()
            autoExpandGeneration += 1
            QuestTrackerStyle._autoExpandedUntil = 0
            QuestTrackerStyle._manuallyExpanded = not expanded
            applyPresentation()
        end)

        if ptext then
            ptext:GetPropertyChangedSignal("Text"):Connect(applyPresentation)
        end
        if fill then
            local function syncRing()
                updateRing(fill.Size.X.Scale)
            end
            fill:GetPropertyChangedSignal("Size"):Connect(syncRing)
            fill:GetPropertyChangedSignal("BackgroundColor3"):Connect(syncRing)
            syncRing()
        end
        player:GetAttributeChangedSignal("QuestDisplayMode"):Connect(function()
            QuestTrackerStyle._manuallyExpanded = false
            QuestTrackerStyle._autoExpandedUntil = 0
            autoExpandGeneration += 1
            applyPresentation()
        end)

        QuestTrackerStyle._pane = pane
        ensureTipOverlay()
        applyVisibility()
    end)
end

return QuestTrackerStyle
