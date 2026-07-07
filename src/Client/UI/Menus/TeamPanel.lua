--[[
    TeamPanel — form a team (docs/TEAMING.md), modeled on TradePanel's two layers:
      • List view (MenuManager "Team" panel): when SOLO, a pick-a-player invite list
        (mirrors the Trade picker Jason pointed at as the framework); when TEAMED, the
        roster (lead crowned) + a Leave Team button.
      • Live layer (own ScreenGui, built at boot): the incoming-invite popup. No server
        event needed — PartyService stamps the replicated TeamInviteFrom attribute on the
        target, and this watches it. Accept/decline ride the team.* bus commands.

    Team state renders purely from replicated player attributes (TeamId/TeamLead/
    TeamMembers) — the UI-state-from-SSOT rule; no sequence-cached guesses.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CloseButton = require(script.Parent.Parent.Components.CloseButton)
local PanelChrome = require(script.Parent.Parent.Components.PanelChrome)

local REMOTE_NAME = "GameAPICommand"

local COLORS = {
    panel = Color3.fromRGB(20, 20, 25),
    header = Color3.fromRGB(56, 161, 178),
    row = Color3.fromRGB(40, 42, 52),
    accept = Color3.fromRGB(46, 204, 113),
    cancel = Color3.fromRGB(231, 76, 60),
    pending = Color3.fromRGB(120, 124, 138),
    text = Color3.fromRGB(255, 255, 255),
    subtext = Color3.fromRGB(200, 205, 215),
}

local localPlayer = Players.LocalPlayer

local function corner(inst, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r)
    c.Parent = inst
end

local function pillify(btn)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(1, 0)
    c.Parent = btn
end

local function label(parent, text, size, pos, color, font)
    local l = Instance.new("TextLabel")
    l.Size = size
    l.Position = pos
    l.BackgroundTransparency = 1
    l.Text = text
    l.TextColor3 = color
    l.TextScaled = true
    l.Font = font
    l.Parent = parent
    return l
end

local TeamPanel = {}
TeamPanel.__index = TeamPanel

function TeamPanel.new()
    local self = setmetatable({}, TeamPanel)
    self.isVisible = false
    self.frame = nil
    self.liveGui = nil
    self.invitePopup = nil
    -- Live from boot: an invite is a replicated attribute stamp, not an event.
    localPlayer:GetAttributeChangedSignal("TeamInviteFrom"):Connect(function()
        local from = localPlayer:GetAttribute("TeamInviteFrom")
        if type(from) == "string" and from ~= "" then
            self:_showInvitePopup(from)
        else
            self:_closeInvitePopup()
        end
    end)
    -- Roster changes re-render the open panel (join/leave/promotion).
    localPlayer:GetAttributeChangedSignal("TeamMembers"):Connect(function()
        if self.isVisible then
            self:_refresh()
        end
    end)
    return self
end

function TeamPanel:_callBus(name, args)
    local remote = ReplicatedStorage:FindFirstChild(REMOTE_NAME)
    if not remote then
        return nil
    end
    local ok, envelope = pcall(function()
        return remote:InvokeServer(name, args or {})
    end)
    if not ok or type(envelope) ~= "table" then
        return nil
    end
    return envelope.result -- the handler's own { ok, reason } payload
end

function TeamPanel:Show(parent)
    if self.isVisible then
        return
    end
    local frame = Instance.new("Frame")
    frame.Name = "TeamPanel"
    frame.Size = UDim2.new(0.42, 0, 0.6, 0)
    frame.Position = UDim2.new(0.5, 0, 0.5, 0)
    frame.AnchorPoint = Vector2.new(0.5, 0.5)
    frame.BackgroundColor3 = COLORS.panel
    frame.BorderSizePixel = 0
    frame.ZIndex = 100
    frame.Parent = parent
    corner(frame, 20)
    PanelChrome.pillBorder(frame, PanelChrome.areaPill(), 130, 0, 0.07)
    self.frame = frame

    -- header, area-themed like every panel
    local _, areaColor = PanelChrome.areaPill()
    areaColor = areaColor or COLORS.header
    local header = Instance.new("Frame")
    header.Size = UDim2.new(1, 0, 0, 72)
    header.BackgroundColor3 = areaColor
    header.BorderSizePixel = 0
    header.ZIndex = 101
    header.Parent = frame
    corner(header, 20)
    local g = Instance.new("UIGradient")
    g.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, areaColor),
        ColorSequenceKeypoint.new(1, areaColor:Lerp(Color3.fromRGB(0, 0, 0), 0.35)),
    })
    g.Rotation = 90
    g.Parent = header
    local title = label(
        header,
        "👥 Team",
        UDim2.new(1, -150, 1, 0),
        UDim2.new(0, 24, 0, 0),
        COLORS.text,
        Enum.Font.GothamBold
    )
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.ZIndex = 103
    local tc = Instance.new("UITextSizeConstraint")
    tc.MaxTextSize = 30
    tc.Parent = title
    CloseButton.attach(frame, {
        zindex = 146,
        onClick = function()
            self:Hide()
        end,
    })

    local hint = label(
        frame,
        "",
        UDim2.new(1, -48, 0, 24),
        UDim2.new(0, 24, 0, 84),
        COLORS.subtext,
        Enum.Font.Gotham
    )
    hint.TextXAlignment = Enum.TextXAlignment.Left
    hint.ZIndex = 102
    self.hint = hint

    local list = Instance.new("ScrollingFrame")
    list.Size = UDim2.new(1, -24, 1, -180)
    list.Position = UDim2.new(0, 12, 0, 116)
    list.BackgroundTransparency = 1
    list.BorderSizePixel = 0
    list.ScrollBarThickness = 6
    list.AutomaticCanvasSize = Enum.AutomaticSize.Y
    list.CanvasSize = UDim2.new(0, 0, 0, 0)
    list.ZIndex = 101
    list.Parent = frame
    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 8)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = list
    self.list = list

    -- footer: Leave Team when teamed (hidden solo)
    local leave = Instance.new("TextButton")
    leave.Size = UDim2.new(0, 180, 0, 40)
    leave.Position = UDim2.new(0.5, 0, 1, -30)
    leave.AnchorPoint = Vector2.new(0.5, 0.5)
    leave.BackgroundColor3 = COLORS.cancel
    leave.Text = "Leave Team"
    leave.TextColor3 = COLORS.text
    leave.TextScaled = true
    leave.Font = Enum.Font.GothamBold
    leave.ZIndex = 102
    leave.Visible = false
    leave.Parent = frame
    pillify(leave)
    local lc = Instance.new("UITextSizeConstraint")
    lc.MaxTextSize = 18
    lc.Parent = leave
    leave.Activated:Connect(function()
        self:_callBus("team.leave")
        self:_refresh()
    end)
    self.leaveBtn = leave

    self.isVisible = true
    self:_refresh()
end

-- Render from the replicated attributes: solo -> invite picker; teamed -> roster.
function TeamPanel:_refresh()
    if not self.list then
        return
    end
    for _, ch in ipairs(self.list:GetChildren()) do
        if ch:IsA("GuiObject") then -- rows + the empty-state label (keeps the UIListLayout)
            ch:Destroy()
        end
    end
    local members = localPlayer:GetAttribute("TeamMembers")
    local teamed = type(members) == "string" and members ~= ""
    self.leaveBtn.Visible = teamed
    if teamed then
        self.hint.Text = "Your team — support casts can target these players:"
        local lead = localPlayer:GetAttribute("TeamLead")
        local order = 0
        for name in members:gmatch("[^,]+") do
            order += 1
            self:_row(name, order, {
                tag = (name == lead) and "⭐ Lead" or nil,
            })
        end
    else
        self.hint.Text = "Pick a player to invite to your team:"
        local order, others = 0, 0
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= localPlayer then
                order += 1
                others += 1
                self:_row(p.Name, order, { invite = true })
            end
        end
        if others == 0 then
            local empty = label(
                self.list,
                "No other players online to team with.",
                UDim2.new(1, 0, 0, 50),
                UDim2.new(0, 0, 0, 0),
                COLORS.subtext,
                Enum.Font.Gotham
            )
            empty.ZIndex = 102
            local ec = Instance.new("UITextSizeConstraint")
            ec.MaxTextSize = 18
            ec.Parent = empty
        end
    end
end

function TeamPanel:_row(name, order, opts)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -8, 0, 56)
    row.BackgroundColor3 = COLORS.row
    row.BorderSizePixel = 0
    row.LayoutOrder = order
    row.ZIndex = 102
    row.Parent = self.list
    corner(row, 10)

    local p = Players:FindFirstChild(name)
    local lvl = p and p:GetAttribute("Level")
    local text = (lvl and ("Lv %d   "):format(lvl) or "") .. name
    if opts.tag then
        text = text .. "   " .. opts.tag
    end
    local nameLabel = label(
        row,
        text,
        UDim2.new(1, -140, 1, 0),
        UDim2.new(0, 14, 0, 0),
        COLORS.text,
        Enum.Font.GothamBold
    )
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.ZIndex = 103
    local nc = Instance.new("UITextSizeConstraint")
    nc.MaxTextSize = 18
    nc.Parent = nameLabel

    if opts.invite then
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, 110, 0, 40)
        btn.Position = UDim2.new(1, -122, 0.5, -20)
        btn.BackgroundColor3 = COLORS.accept
        btn.Text = "Invite"
        btn.TextColor3 = COLORS.text
        btn.TextScaled = true
        btn.Font = Enum.Font.GothamBold
        btn.ZIndex = 103
        btn.Parent = row
        pillify(btn)
        local bc = Instance.new("UITextSizeConstraint")
        bc.MaxTextSize = 16
        bc.Parent = btn
        btn.Activated:Connect(function()
            local res = self:_callBus("team.invite", { target = name })
            btn.Text = (res and res.ok) and "Invited ✓" or "Failed"
            btn.Active = false
            btn.AutoButtonColor = false
        end)
    end
end

----------------------------------------------------------------------
-- Live layer: the incoming-invite popup (works even with the panel closed)
----------------------------------------------------------------------

function TeamPanel:_ensureLiveGui()
    if self.liveGui and self.liveGui.Parent then
        return self.liveGui
    end
    local gui = Instance.new("ScreenGui")
    gui.Name = "TeamLive"
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = localPlayer:WaitForChild("PlayerGui")
    self.liveGui = gui
    return gui
end

function TeamPanel:_closeInvitePopup()
    if self.invitePopup then
        self.invitePopup:Destroy()
        self.invitePopup = nil
    end
end

function TeamPanel:_showInvitePopup(fromName)
    self:_closeInvitePopup()
    local gui = self:_ensureLiveGui()
    local pop = Instance.new("Frame")
    pop.Name = "TeamInvitePopup"
    pop.Size = UDim2.new(0, 360, 0, 150)
    pop.Position = UDim2.new(0.5, 0, 0, 200)
    pop.AnchorPoint = Vector2.new(0.5, 0)
    pop.BackgroundColor3 = COLORS.panel
    pop.ZIndex = 200
    pop.Parent = gui
    corner(pop, 14)
    local s = Instance.new("UIStroke")
    s.Color = COLORS.header
    s.Thickness = 2
    s.Parent = pop
    self.invitePopup = pop

    local msg = label(
        pop,
        "👥 " .. fromName .. " invited you to team up",
        UDim2.new(1, -20, 0, 50),
        UDim2.new(0, 10, 0, 16),
        COLORS.text,
        Enum.Font.GothamBold
    )
    msg.ZIndex = 202
    msg.TextWrapped = true
    local mc = Instance.new("UITextSizeConstraint")
    mc.MaxTextSize = 20
    mc.Parent = msg

    local function actionButton(text, color, x, cmd)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(0.42, 0, 0, 48)
        b.Position = UDim2.new(x, 0, 1, -60)
        b.BackgroundColor3 = color
        b.Text = text
        b.TextColor3 = COLORS.text
        b.TextScaled = true
        b.Font = Enum.Font.GothamBold
        b.ZIndex = 201
        b.Parent = pop
        pillify(b)
        local c = Instance.new("UITextSizeConstraint")
        c.MaxTextSize = 18
        c.Parent = b
        b.Activated:Connect(function()
            self:_callBus(cmd)
            self:_closeInvitePopup()
        end)
    end
    actionButton("Accept", COLORS.accept, 0.06, "team.accept")
    actionButton("Decline", COLORS.cancel, 0.52, "team.decline")
end

function TeamPanel:Hide()
    if not self.isVisible then
        return
    end
    if self.frame then
        self.frame:Destroy()
        self.frame = nil
    end
    self.list = nil
    self.hint = nil
    self.leaveBtn = nil
    self.isVisible = false
end

function TeamPanel:IsVisible()
    return self.isVisible
end

function TeamPanel:GetFrame()
    return self.frame
end

function TeamPanel:Destroy()
    self:Hide()
    self:_closeInvitePopup()
    if self.liveGui then
        self.liveGui:Destroy()
        self.liveGui = nil
    end
end

return TeamPanel
