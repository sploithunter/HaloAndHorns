--[[
    QuestPanel — the client UI for the reward spine's Quest gate (Phase 8).

    Mirrors the ShopPanel structure (.new / Show(parent) / Hide / GetFrame /
    IsVisible / Destroy) so MenuManager opens it when the "Quest" side-menu button
    is clicked. Data comes live from the server through the GameAPICommand bus
    bridge: `quest.list` (rows with progress + claimable) and `quest.claim`.

        local QuestPanel = require(script.QuestPanel)
        menuManager:RegisterPanel("Quest", QuestPanel.new())
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local FillBar = require(script.Parent.Parent.FillBar)
-- THE shared panel exterior (window + outer pill + header + close X + area theming + pill helpers).
local PanelChrome = require(script.Parent.Parent.Components.PanelChrome)

local REMOTE_NAME = "GameAPICommand"

-- Palette (teal card aesthetic matching the side menu).
local COLORS = {
    panel = Color3.fromRGB(20, 20, 25),
    panelGradientTop = Color3.fromRGB(30, 30, 40),
    header = Color3.fromRGB(56, 161, 178),
    headerGradient = Color3.fromRGB(43, 134, 148),
    row = Color3.fromRGB(40, 42, 52),
    rowStroke = Color3.fromRGB(70, 74, 88),
    track = Color3.fromRGB(28, 30, 38),
    fill = Color3.fromRGB(46, 204, 113),
    claimable = Color3.fromRGB(46, 204, 113),
    claimableHover = Color3.fromRGB(39, 174, 96),
    locked = Color3.fromRGB(70, 74, 88),
    claimed = Color3.fromRGB(90, 96, 110),
    close = Color3.fromRGB(231, 76, 60),
    text = Color3.fromRGB(255, 255, 255),
    subtext = Color3.fromRGB(200, 205, 215),
    focus = Color3.fromRGB(241, 196, 15), -- gold accent for the ACTIVE (focused) track
}

local QuestPanel = {}
QuestPanel.__index = QuestPanel

function QuestPanel.new()
    local self = setmetatable({}, QuestPanel)
    self.isVisible = false
    self.frame = nil
    self.listFrame = nil
    self.rows = {}
    -- Branch TABS: quests are grouped into tracks (configs/quests.lua); the tab bar filters the
    -- list to one branch. "all" = the cross-branch overview (claimable surfaced first).
    self.tabBar = nil
    self.tabButtons = {}
    self.viewedTab = "all"
    -- focusTrack = the server's ACTIVE track (the one whose grind quests are counting). Distinct
    -- from viewedTab (which branch you're browsing). Set from quest.list's `activeTrack`.
    self.focusTrack = nil
    self.quests = {}
    return self
end

-- Call a bus command through the shared GameAPICommand RemoteFunction. Returns the
-- handler result table ({ ok = ... }) or nil on transport failure.
function QuestPanel:_callBus(name, args)
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
    return envelope.result
end

function QuestPanel:Show(parent)
    if self.isVisible then
        return
    end
    self:_createUI(parent)
    self.isVisible = true
    self:_refresh()
    -- Opening the Quests menu un-dismisses the HUD tracker (it stays after the menu closes).
    pcall(function()
        require(script.Parent.Parent.Parent.Systems.QuestTrackerStyle).show()
    end)
end

function QuestPanel:Hide()
    if not self.isVisible then
        return
    end
    if self.frame then
        self.frame:Destroy()
        self.frame = nil
    end
    self.listFrame = nil
    self.rows = {}
    self.isVisible = false
end

function QuestPanel:IsVisible()
    return self.isVisible
end

function QuestPanel:GetFrame()
    return self.frame
end

function QuestPanel:Destroy()
    self:Hide()
end

function QuestPanel:_createUI(parent)
    -- Shared window shell (outer area-themed pill + header + close X on top) — same code path as
    -- AchievementsPanel (Jason: quests should be near-identical to achievements).
    local shell = PanelChrome.build(parent, {
        name = "QuestPanel",
        title = "🎯 Quests",
        onClose = function()
            self:Hide()
        end,
    })
    local frame = shell.frame
    self.frame = frame
    self._areaKey = shell.areaKey

    self:_createTabBar()

    -- Scrolling list of quest rows (below header + branch tab bar) — Achievements geometry.
    local list = Instance.new("ScrollingFrame")
    list.Name = "QuestList"
    list.Size = UDim2.new(0.95, 0, 0.8, 0)
    list.Position = UDim2.new(0.03, 0, 0.2, 0)
    list.BackgroundTransparency = 1
    list.BorderSizePixel = 0
    list.ScrollBarThickness = 6
    list.CanvasSize = UDim2.new(0, 0, 0, 0)
    list.AutomaticCanvasSize = Enum.AutomaticSize.Y
    list.ZIndex = 101
    list.Parent = frame
    self.listFrame = list

    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 10)
    layout.Parent = list

    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, 4)
    pad.PaddingBottom = UDim.new(0, 4)
    pad.PaddingRight = UDim.new(0, 4)
    pad.Parent = list

    self:_animateEntrance()
end

-- Sort rank for the cross-branch "All" view: claimable first, then in-progress, then done.
local function claimRank(q)
    if q.claimable then
        return 0
    elseif not q.progress or not q.progress.met then
        return 1
    end
    return 2
end

-- Horizontal branch-tab bar between the header and the list (Achievements geometry: relative, the
-- tabs fill it 1/N). Tabs are filled in by _buildTabs once quest.list reveals which branches exist.
function QuestPanel:_createTabBar()
    local bar = Instance.new("ScrollingFrame")
    bar.Name = "TabBar"
    bar.Size = UDim2.new(0.95, 0, 0.1, 0)
    bar.Position = UDim2.new(0.03, 0, 0.1, 0)
    bar.BackgroundTransparency = 1
    bar.BorderSizePixel = 0
    bar.ScrollBarThickness = 4
    bar.ScrollingDirection = Enum.ScrollingDirection.X
    bar.CanvasSize = UDim2.new(0, 0, 0, 0)
    bar.AutomaticCanvasSize = Enum.AutomaticSize.X
    bar.ZIndex = 101
    bar.Parent = self.frame
    self.tabBar = bar

    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.VerticalAlignment = Enum.VerticalAlignment.Center
    layout.Padding = UDim.new(0, 8)
    layout.Parent = bar
end

-- One tab button, styled exactly like AchievementsPanel: 1/N width fills the bar, game pill chrome
-- (citrine when viewed, area color when idle), label in a CHILD above the pills. `key` = "all" or a
-- track id; the FOCUS (counting) track gets a ▶ prefix; `hasClaimable` adds a green dot.
function QuestPanel:_makeTab(key, label, order, hasClaimable)
    local active = self.viewedTab == key
    local focused = self.focusTrack ~= nil and key == self.focusTrack
    local btn = Instance.new("TextButton")
    btn.Name = "Tab_" .. key
    local n = math.max(self._tabCount or 1, 1)
    local gap = math.floor(8 * (n - 1) / n + 0.5)
    btn.Size = UDim2.new(1 / n, -gap, 1, -6)
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.AutoButtonColor = false
    btn.LayoutOrder = order
    btn.ZIndex = 102
    btn.Parent = self.tabBar

    local pillKey = active and "citrine" or (self._areaKey or "sapphire")
    PanelChrome.pillPanel(btn, pillKey, 100)
    PanelChrome.pillBorder(btn, pillKey, 103, 0)

    local labelText = Instance.new("TextLabel")
    labelText.Name = "Label"
    labelText.Size = UDim2.fromScale(1, 1)
    labelText.BackgroundTransparency = 1
    labelText.Text = (focused and "▶ " or "") .. label
    -- Dark text on a bright citrine (yellow) pill — white was unreadable on the gold; white elsewhere.
    labelText.TextColor3 = (pillKey == "citrine") and Color3.fromRGB(64, 46, 8) or COLORS.text
    labelText.TextScaled = true
    labelText.Font = Enum.Font.GothamBold
    labelText.ZIndex = 110
    labelText.Parent = btn
    local cons = Instance.new("UITextSizeConstraint")
    cons.MaxTextSize = 18
    cons.Parent = labelText

    if hasClaimable then
        local dot = Instance.new("Frame")
        dot.Name = "ClaimDot"
        dot.Size = UDim2.fromOffset(12, 12)
        dot.AnchorPoint = Vector2.new(1, 0)
        dot.Position = UDim2.new(1, -6, 0, -2)
        dot.BackgroundColor3 = COLORS.claimable
        dot.BorderSizePixel = 0
        dot.ZIndex = 111
        dot.Parent = btn
        local dc = Instance.new("UICorner")
        dc.CornerRadius = UDim.new(1, 0)
        dc.Parent = dot
    end

    btn.Activated:Connect(function()
        if self.viewedTab ~= key then
            self.viewedTab = key
            self:_buildTabs(self.quests) -- rebuild tabs (re-pill the active one) from cached data
            self:_renderRows()
        end
    end)
    self.tabButtons[key] = btn
end

-- (Re)build the tab strip from the branches present in the quest list. Keeps the current
-- selection if it still exists, else falls back to "All".
function QuestPanel:_buildTabs(quests)
    for _, btn in pairs(self.tabButtons) do
        btn:Destroy()
    end
    self.tabButtons = {}

    local seen, tracks, claimableByTrack = {}, {}, {}
    for _, q in ipairs(quests) do
        local t = q.track or "misc"
        if not seen[t] then
            seen[t] = true
            table.insert(
                tracks,
                { key = t, title = q.trackTitle or t, order = q.trackOrder or math.huge }
            )
        end
        if q.claimable then
            claimableByTrack[t] = true
        end
    end
    table.sort(tracks, function(a, b)
        if a.order ~= b.order then
            return a.order < b.order
        end
        return a.title < b.title
    end)

    -- Drop a stale selection (e.g. a branch that no longer appears).
    local stillValid = self.viewedTab == "all"
    for _, t in ipairs(tracks) do
        if t.key == self.viewedTab then
            stillValid = true
        end
    end
    if not stillValid then
        self.viewedTab = "all"
    end

    -- count tabs first so each gets 1/N of the bar width (fills it edge-to-edge): "All" + the tracks
    self._tabCount = 1 + #tracks
    self:_makeTab("all", "All", 0, false)
    for i, t in ipairs(tracks) do
        self:_makeTab(t.key, t.title, i, claimableByTrack[t.key] == true)
    end
end

-- Render the quest rows for the active branch. "All" surfaces claimable first (an actionable
-- overview); a single branch shows its ladder in order (head first, then what's coming).
function QuestPanel:_renderRows()
    if not self.listFrame then
        return
    end
    for _, row in ipairs(self.rows) do
        row:Destroy()
    end
    self.rows = {}

    local filtered = {}
    for _, q in ipairs(self.quests or {}) do
        if self.viewedTab == "all" or q.track == self.viewedTab then
            table.insert(filtered, q)
        end
    end
    if #filtered == 0 then
        self:_emptyState("No quests in this branch yet.")
        return
    end

    if self.viewedTab == "all" then
        table.sort(filtered, function(a, b)
            local ra, rb = claimRank(a), claimRank(b)
            if ra ~= rb then
                return ra < rb
            end
            return (a.name or a.id) < (b.name or b.id)
        end)
    else
        table.sort(filtered, function(a, b)
            return (a.order or 0) < (b.order or 0)
        end)
    end

    -- On a single branch, lead with the activation banner (Activate / Active / Always tracked).
    if self.viewedTab ~= "all" then
        local hasGrind = false
        for _, q in ipairs(filtered) do
            if q.activationGated then
                hasGrind = true
                break
            end
        end
        local banner = self:_activationControl(self.viewedTab, hasGrind)
        if banner then
            table.insert(self.rows, banner)
        end
    end

    for i, quest in ipairs(filtered) do
        table.insert(self.rows, self:_createQuestRow(quest, i))
    end
end

-- The per-branch activation control shown atop a single-branch view:
--   • this branch is the focus  -> a green "Active — counting" banner
--   • has grind quests, not focus -> a gold "▶ Activate this branch" button (switches focus here)
--   • only milestones           -> a subtle "Always tracked" note (no activation needed)
function QuestPanel:_activationControl(track, hasGrind)
    local isFocus = self.focusTrack ~= nil and track == self.focusTrack

    -- Game pill ring on the banner too: emerald when this branch is the active/counting focus,
    -- citrine when it CAN be activated, neutral for an always-tracked branch.
    local bannerKey = isFocus and "emerald" or (hasGrind and "citrine" or "neutral")
    local row = PanelChrome.entryRow(self.listFrame, {
        name = "ActivationBanner",
        height = 44,
        corner = 10,
        bg = isFocus and COLORS.fill or (hasGrind and COLORS.row or COLORS.track),
        bgTransparency = isFocus and 0.15 or 0,
        key = bannerKey,
        layoutOrder = 0,
    })

    if isFocus then
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, -24, 1, 0)
        label.Position = UDim2.new(0, 12, 0, 0)
        label.BackgroundTransparency = 1
        label.Text = "▶ Active branch — quests are counting"
        label.TextColor3 = COLORS.text
        label.Font = Enum.Font.GothamBold
        label.TextScaled = true
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.ZIndex = 103
        label.Parent = row
        local c = Instance.new("UITextSizeConstraint")
        c.MaxTextSize = 18
        c.Parent = label
    elseif hasGrind then
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 1, 0)
        btn.BackgroundTransparency = 1
        btn.Text = "▶ Activate this branch (start its quests counting)"
        btn.TextColor3 = COLORS.focus
        btn.Font = Enum.Font.GothamBold
        btn.TextScaled = true
        btn.AutoButtonColor = false
        btn.ZIndex = 103
        btn.Parent = row
        local c = Instance.new("UITextSizeConstraint")
        c.MaxTextSize = 18
        c.Parent = btn
        btn.Activated:Connect(function()
            self:_callBus("quest.setActiveTrack", { track = track })
            self:_refresh()
        end)
    else
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, -24, 1, 0)
        label.Position = UDim2.new(0, 12, 0, 0)
        label.BackgroundTransparency = 1
        label.Text = "Always tracked — no activation needed"
        label.TextColor3 = COLORS.subtext
        label.Font = Enum.Font.Gotham
        label.TextScaled = true
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.ZIndex = 103
        label.Parent = row
        local c = Instance.new("UITextSizeConstraint")
        c.MaxTextSize = 16
        c.Parent = label
    end

    return row
end

-- Rebuild from a fresh quest.list call: cache the data, refresh the tabs, render the branch.
function QuestPanel:_refresh()
    if not self.listFrame then
        return
    end
    local result = self:_callBus("quest.list", {})
    local quests = result and result.quests
    if type(quests) ~= "table" then
        for _, row in ipairs(self.rows) do
            row:Destroy()
        end
        self.rows = {}
        self:_emptyState("Couldn't load quests.")
        return
    end
    self.quests = quests
    self.focusTrack = result.activeTrack -- which branch is currently counting (may be nil)
    self:_buildTabs(quests)
    self:_renderRows()
end

function QuestPanel:_emptyState(text)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 0, 60)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = COLORS.subtext
    label.TextScaled = true
    label.Font = Enum.Font.Gotham
    label.ZIndex = 102
    label.Parent = self.listFrame

    local constraint = Instance.new("UITextSizeConstraint")
    constraint.MaxTextSize = 20
    constraint.Parent = label

    table.insert(self.rows, label)
end

local function rewardSummary(reward)
    -- reward = { currencies = { coins = 100 }, items = {...}, pets = {...} }
    local parts = {}
    for currency, amount in pairs((reward and reward.currencies) or {}) do
        table.insert(parts, string.format("%d %s", amount, currency))
    end
    for _, item in ipairs((reward and reward.items) or {}) do
        table.insert(parts, string.format("%dx %s", item.qty or 1, item.id))
    end
    for _, pet in ipairs((reward and reward.pets) or {}) do
        table.insert(parts, "pet: " .. tostring(pet.id))
    end
    if #parts == 0 then
        return ""
    end
    return "Reward: " .. table.concat(parts, ", ")
end

function QuestPanel:_createQuestRow(quest, order)
    local progress = quest.progress or { current = 0, target = 1, fraction = 0, met = false }

    -- Game pill ring per row (Achievements style): emerald = claimable (pops like the green Claim
    -- button), neutral = locked, area color = in progress.
    local rowKey = self._areaKey or "sapphire"
    if quest.claimable then
        rowKey = "emerald"
    elseif quest.locked then
        rowKey = "neutral"
    end
    local row = PanelChrome.entryRow(self.listFrame, {
        name = "Quest_" .. tostring(quest.id),
        height = 96,
        bg = COLORS.row,
        key = rowKey,
        layoutOrder = order,
    })

    -- Title
    local name = Instance.new("TextLabel")
    name.Size = UDim2.new(1, -150, 0, 26)
    name.Position = UDim2.new(0, 16, 0, 10)
    name.BackgroundTransparency = 1
    name.Text = (quest.locked and "🔒 " or "") .. (quest.name or quest.id)
    name.TextColor3 = quest.locked and COLORS.subtext or COLORS.text
    name.TextScaled = true
    name.Font = Enum.Font.GothamBold
    name.TextXAlignment = Enum.TextXAlignment.Left
    name.ZIndex = 103
    name.Parent = row

    local nameConstraint = Instance.new("UITextSizeConstraint")
    nameConstraint.MaxTextSize = 20
    nameConstraint.Parent = name

    -- Description / reward line
    local desc = Instance.new("TextLabel")
    desc.Size = UDim2.new(1, -150, 0, 18)
    desc.Position = UDim2.new(0, 16, 0, 36)
    desc.BackgroundTransparency = 1
    local rewardText = rewardSummary(quest.reward)
    local trackTag = quest.trackTitle and ("[" .. quest.trackTitle .. "]  ") or ""
    desc.Text = trackTag
        .. (quest.description or "")
        .. (rewardText ~= "" and ("   •   " .. rewardText) or "")
    desc.TextColor3 = COLORS.subtext
    desc.TextScaled = true
    desc.Font = Enum.Font.Gotham
    desc.TextXAlignment = Enum.TextXAlignment.Left
    desc.ZIndex = 103
    desc.Parent = row

    local descConstraint = Instance.new("UITextSizeConstraint")
    descConstraint.MaxTextSize = 14
    descConstraint.Parent = desc

    -- Progress bar track (shared FillBar). A paused grind quest (its branch isn't the focus) shows
    -- a muted fill so it reads as "not currently counting".
    local fraction = math.clamp(progress.fraction or 0, 0, 1)
    local track = FillBar.create({
        parent = row,
        size = UDim2.new(1, -150, 0, 14),
        position = UDim2.new(0, 16, 1, -26),
        bgColor = COLORS.track,
        fillColor = quest.paused and COLORS.locked or COLORS.fill,
        fraction = fraction,
        zIndex = 103,
    })

    local progressText = Instance.new("TextLabel")
    progressText.Size = UDim2.new(1, 0, 1, 0)
    progressText.BackgroundTransparency = 1
    progressText.Text = string.format("%d / %d", progress.current or 0, progress.target or 0)
        .. (quest.paused and "  ⏸" or "")
    progressText.TextColor3 = COLORS.text
    progressText.TextScaled = true
    progressText.Font = Enum.Font.GothamMedium
    progressText.ZIndex = 105
    progressText.Parent = track

    local progressConstraint = Instance.new("UITextSizeConstraint")
    progressConstraint.MaxTextSize = 11
    progressConstraint.Parent = progressText

    -- Claim button
    local claim = Instance.new("TextButton")
    claim.Name = "ClaimButton"
    claim.Size = UDim2.new(0, 116, 0, 64)
    claim.Position = UDim2.new(1, -130, 0.5, -32)
    claim.BorderSizePixel = 0
    claim.TextColor3 = COLORS.text
    claim.TextScaled = true
    claim.Font = Enum.Font.GothamBold
    claim.ZIndex = 104
    claim.Parent = row

    local claimCorner = Instance.new("UICorner")
    claimCorner.CornerRadius = UDim.new(0, 10)
    claimCorner.Parent = claim

    local claimConstraint = Instance.new("UITextSizeConstraint")
    claimConstraint.MaxTextSize = 18
    claimConstraint.Parent = claim

    local claimedOnce = (quest.claimedCount or 0) > 0
    if quest.claimable then
        claim.Text = "Claim"
        claim.BackgroundColor3 = COLORS.claimable
        claim.AutoButtonColor = true
        claim.Active = true
        claim.Activated:Connect(function()
            self:_claim(quest.id, claim)
        end)
    elseif claimedOnce and not quest.repeatable then
        claim.Text = "Claimed ✓"
        claim.BackgroundColor3 = COLORS.claimed
        claim.AutoButtonColor = false
        claim.Active = false
    else
        claim.Text = "Locked"
        claim.BackgroundColor3 = COLORS.locked
        claim.AutoButtonColor = false
        claim.Active = false
    end

    return row
end

function QuestPanel:_claim(questId, button)
    if button then
        button.Text = "…"
        button.Active = false
    end
    local result = self:_callBus("quest.claim", { questId = questId })
    if result and result.ok then
        self:_refresh() -- counters/claimable state changed
    elseif button then
        button.Text = "Claim"
        button.Active = true
    end
end

function QuestPanel:_animateEntrance()
    if not self.frame then
        return
    end
    self.frame.Size = UDim2.new(0.6, 0, 0.75, 0)
    local tween = TweenService:Create(
        self.frame,
        TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        { Size = UDim2.new(0.7, 0, 0.85, 0) }
    )
    tween:Play()
end

return QuestPanel
