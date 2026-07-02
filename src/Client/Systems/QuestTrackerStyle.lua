--[[
    QuestTrackerStyle (client) — move the Current Quest tracker out of the top-right and dock it
    directly BELOW the center player bar, restyled to match (a dark capsule with a blue progress bar
    on top + the quest name below), per assets/ui/reference/player_status_quest_combo_reference.png.

    Scoped post-process of ProfessionalBaseUI's quest_tracker_pane (BaseUI logic untouched). The
    progress fill is area-themed via UITheme (blue default). Idempotent.
]]

local Players = game:GetService("Players")

local QuestTrackerStyle = {}
local started = false
QuestTrackerStyle._pane = nil
QuestTrackerStyle._dismissed = false

-- The tracker's visibility is a pure function of the dismissed flag — set by the X, cleared when the
-- Quest menu opens or a quest becomes claimable (Jason: it's in the way when idle, esp. on mobile).
local function applyVisibility()
    if QuestTrackerStyle._pane then
        QuestTrackerStyle._pane.Visible = not QuestTrackerStyle._dismissed
    end
end

-- Re-show the tracker. Public so BaseUI (new claimable) + QuestPanel (menu opened) can un-dismiss it.
function QuestTrackerStyle.show()
    QuestTrackerStyle._dismissed = false
    applyVisibility()
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
        for _ = 1, 30 do
            -- pg-wide recursive: TopHudStack may have adopted the pane into the PlayerBar
            -- capsule's stack before we got here (it is no longer under MainContainer)
            pane = (mc and mc:FindFirstChild("quest_tracker_pane"))
                or pg:FindFirstChild("quest_tracker_pane", true)
            if pane then
                break
            end
            task.wait(0.5)
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

        QuestTrackerStyle._pane = pane
        applyVisibility()
    end)
end

return QuestTrackerStyle
