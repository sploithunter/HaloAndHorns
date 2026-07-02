--[[
    AchievementsPanel — client UI for the PASSIVE-milestone achievements (Jason 2026-06-29).

    The counterpart to QuestPanel: achievements are lifetime totals that just HAPPEN. Each shows its
    current tier as a progress bar; once a tier's goal is reached the row gets a CLAIM button (Jason:
    "if you've reached it, a Claim button; if not, a bar showing how close you are"). Grouped by
    CATEGORY via a tab bar. Data is live over the GameAPICommand bus: `achievement.list` (value +
    tiers + claimed + categories) and `achievement.claim`.

        menuManager:RegisterPanel("Achievements", AchievementsPanel.new())
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
-- THE shared panel exterior (window + outer pill + header + close X + area theming + scroll pane).
local PanelChrome = require(script.Parent.Parent.Components.PanelChrome)

local REMOTE_NAME = "GameAPICommand"

local COLORS = {
    panel = Color3.fromRGB(20, 20, 25),
    panelGradientTop = Color3.fromRGB(30, 30, 40),
    header = Color3.fromRGB(180, 140, 50), -- amber (achievements = trophies)
    headerGradient = Color3.fromRGB(150, 115, 40),
    row = Color3.fromRGB(40, 42, 52),
    rowStroke = Color3.fromRGB(70, 74, 88),
    track = Color3.fromRGB(28, 30, 38),
    fill = Color3.fromRGB(241, 196, 15),
    claimable = Color3.fromRGB(46, 204, 113),
    claimableHover = Color3.fromRGB(39, 174, 96),
    claimed = Color3.fromRGB(90, 96, 110),
    text = Color3.fromRGB(255, 255, 255),
    subtext = Color3.fromRGB(200, 205, 215),
    tabActive = Color3.fromRGB(241, 196, 15),
    tabIdle = Color3.fromRGB(50, 52, 62),
}

local AchievementsPanel = {}
AchievementsPanel.__index = AchievementsPanel

function AchievementsPanel.new()
    local self = setmetatable({}, AchievementsPanel)
    self.isVisible = false
    self.frame = nil
    self.listFrame = nil
    self.tabBar = nil
    self.tabButtons = {}
    self.viewedCategory = nil
    return self
end

function AchievementsPanel:_callBus(name, args)
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

function AchievementsPanel:Show(parent)
    if self.isVisible then
        return
    end
    self:_createUI(parent)
    self.isVisible = true
    self:_refresh()
end

function AchievementsPanel:Hide()
    if not self.isVisible then
        return
    end
    if self.frame then
        self.frame:Destroy()
        self.frame = nil
    end
    self.listFrame = nil
    self.tabBar = nil
    self.tabButtons = {}
    self.isVisible = false
end

function AchievementsPanel:IsVisible()
    return self.isVisible
end

function AchievementsPanel:GetFrame()
    return self.frame
end

function AchievementsPanel:Destroy()
    self:Hide()
end

function AchievementsPanel:_createUI(parent)
    -- Shared window shell (outer pill + area-themed header + close X) — one code path for every panel.
    local shell = PanelChrome.build(parent, {
        name = "AchievementsPanel",
        title = "🏆 Achievements",
        onClose = function()
            self:Hide()
        end,
    })
    local frame = shell.frame
    self.frame = frame
    self._areaKey = shell.areaKey

    -- Category tab bar
    local bar = Instance.new("ScrollingFrame")
    bar.Name = "TabBar"
    bar.Size = UDim2.new(0.95, 0, 0.1, 0) -- RELATIVE (Jason live-tuned: scales with the panel)
    bar.Position = UDim2.new(0.03, 0, 0.1, 0)
    bar.BackgroundTransparency = 1
    bar.BorderSizePixel = 0
    bar.ScrollBarThickness = 4
    bar.ScrollingDirection = Enum.ScrollingDirection.X
    bar.CanvasSize = UDim2.new(0, 0, 0, 0)
    bar.AutomaticCanvasSize = Enum.AutomaticSize.X
    bar.ZIndex = 101
    bar.Parent = frame
    local barLayout = Instance.new("UIListLayout")
    barLayout.FillDirection = Enum.FillDirection.Horizontal
    barLayout.SortOrder = Enum.SortOrder.LayoutOrder
    barLayout.Padding = UDim.new(0, 8)
    barLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    barLayout.Parent = bar
    self.tabBar = bar

    -- Scrolling list of achievement rows
    local list = Instance.new("ScrollingFrame")
    list.Name = "AchievementList"
    list.Size = UDim2.new(0.95, 0, 0.8, 0) -- RELATIVE (Jason live-tuned: scales with the panel)
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

    frame.Size = UDim2.new(0.7, 0, 0, 0)
    TweenService
        :Create(frame, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Size = UDim2.new(0.7, 0, 0.85, 0),
        })
        :Play()
end

-- The tier the row should DISPLAY: the lowest tier the player hasn't claimed yet, else nil (maxed).
local function currentTier(entry)
    local claimed = entry.completed or {}
    for _, t in ipairs(entry.tiers or {}) do
        if not claimed[t.id] then
            return t
        end
    end
    return nil
end

function AchievementsPanel:_makeTab(catId, meta, hasClaimable)
    local active = self.viewedCategory == catId
    local btn = Instance.new("TextButton")
    btn.Name = "Tab_" .. catId
    -- Relative width = 1/N so the tabs fill the bar edge-to-edge (Jason). The -gap offset reclaims
    -- the (N-1) inter-tab gaps from the 8px UIListLayout padding so the row sums to ~full width.
    local n = math.max(self._tabCount or 1, 1)
    local gap = math.floor(8 * (n - 1) / n + 0.5)
    btn.Size = UDim2.new(1 / n, -gap, 1, -6)
    btn.BackgroundTransparency = 1 -- the pill panel is the background now
    btn.Text = "" -- label lives in a CHILD (below) so the pill children can't cover it
    btn.AutoButtonColor = false
    btn.LayoutOrder = tonumber(meta.order) or 99
    btn.ZIndex = 102
    btn.Parent = self.tabBar
    -- Game pill chrome: citrine (gold) panel+frame when active, sapphire when idle.
    local key = active and "citrine" or (self._areaKey or "sapphire")
    PanelChrome.pillPanel(btn, key, 100)
    PanelChrome.pillBorder(btn, key, 103, 0)
    -- LABEL as a TOP child (ZIndex above the pills). The real MenuOverlay uses Sibling ZIndexBehavior,
    -- where child images render ABOVE the button's own text — so the solid pill fill hid the label
    -- ("text-less tabs" in the real panel, which my isolated preview's behavior hid from me). A child
    -- label above the pills fixes it under any ZIndexBehavior.
    local label = Instance.new("TextLabel")
    label.Name = "Label"
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1
    label.Text = (meta.icon and (meta.icon .. " ") or "") .. (meta.title or catId)
    -- Dark text on a bright citrine (yellow) pill — white was unreadable on the gold; white elsewhere.
    label.TextColor3 = (key == "citrine") and Color3.fromRGB(64, 46, 8) or COLORS.text
    label.TextScaled = true
    label.Font = Enum.Font.GothamBold
    label.ZIndex = 110
    label.Parent = btn
    local cons = Instance.new("UITextSizeConstraint")
    cons.MaxTextSize = 18
    cons.Parent = label
    if hasClaimable then
        local dot = Instance.new("Frame")
        dot.Size = UDim2.fromOffset(12, 12)
        dot.Position = UDim2.new(1, -6, 0, -2)
        dot.AnchorPoint = Vector2.new(1, 0)
        dot.BackgroundColor3 = COLORS.claimable
        dot.ZIndex = 111
        dot.Parent = btn
        local dc = Instance.new("UICorner")
        dc.CornerRadius = UDim.new(1, 0)
        dc.Parent = dot
    end
    btn.Activated:Connect(function()
        self.viewedCategory = catId
        self:_refresh()
    end)
    self.tabButtons[catId] = btn
    return btn
end

function AchievementsPanel:_makeRow(entry, order)
    local tier = currentTier(entry)
    -- Pill-frame border per row: emerald = claimable (pops like the green Claim button), neutral =
    -- maxed/done, area color = in progress (matches the game's pill chrome).
    local rowKey = self._areaKey or "sapphire"
    if not tier then
        rowKey = "neutral"
    elseif entry.value >= tier.goal then
        rowKey = "emerald"
    end
    local row = PanelChrome.entryRow(self.listFrame, {
        name = "Ach_" .. tostring(entry.id),
        height = 84,
        bg = COLORS.row,
        key = rowKey,
        layoutOrder = order,
    })

    local name = Instance.new("TextLabel")
    name.Size = UDim2.new(1, -150, 0, 26)
    name.Position = UDim2.new(0, 14, 0, 10)
    name.BackgroundTransparency = 1
    name.Text = tostring(entry.display_name or entry.id)
    name.TextColor3 = COLORS.text
    name.TextScaled = true
    name.Font = Enum.Font.GothamBold
    name.TextXAlignment = Enum.TextXAlignment.Left
    name.ZIndex = 103
    name.Parent = row
    local nc = Instance.new("UITextSizeConstraint")
    nc.MaxTextSize = 20
    nc.Parent = name

    local value = entry.value or 0
    local goal = tier and tier.goal
        or (entry.tiers[#entry.tiers] and entry.tiers[#entry.tiers].goal)
    local reached = tier and value >= tier.goal

    -- progress text
    local prog = Instance.new("TextLabel")
    prog.Size = UDim2.new(1, -150, 0, 18)
    prog.Position = UDim2.new(0, 14, 0, 38)
    prog.BackgroundTransparency = 1
    prog.Text = tier and string.format("%s / %s", self:_short(value), self:_short(goal))
        or "MAXED ✓"
    prog.TextColor3 = COLORS.subtext
    prog.TextScaled = true
    prog.Font = Enum.Font.Gotham
    prog.TextXAlignment = Enum.TextXAlignment.Left
    prog.ZIndex = 103
    prog.Parent = row
    local pc = Instance.new("UITextSizeConstraint")
    pc.MaxTextSize = 15
    pc.Parent = prog

    -- progress bar track + fill
    local track = Instance.new("Frame")
    track.Size = UDim2.new(1, -150, 0, 12)
    track.Position = UDim2.new(0, 14, 1, -22)
    track.BackgroundColor3 = COLORS.track
    track.BorderSizePixel = 0
    track.ZIndex = 103
    track.Parent = row
    local tcn = Instance.new("UICorner")
    tcn.CornerRadius = UDim.new(1, 0)
    tcn.Parent = track
    local frac = (tier and goal and goal > 0) and math.clamp(value / goal, 0, 1) or 1
    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(frac, 0, 1, 0)
    fill.BackgroundColor3 = reached and COLORS.claimable or COLORS.fill
    fill.BorderSizePixel = 0
    fill.ZIndex = 104
    fill.Parent = track
    local fcn = Instance.new("UICorner")
    fcn.CornerRadius = UDim.new(1, 0)
    fcn.Parent = fill

    -- right side: Claim button (reached) / "✓ Claimed" (maxed) / reward hint
    local rewardAmt = tier and tier.reward and tier.reward.amount
    if reached then
        local claim = Instance.new("TextButton")
        claim.Size = UDim2.new(0, 120, 0, 56)
        claim.Position = UDim2.new(1, -132, 0.5, 0)
        claim.AnchorPoint = Vector2.new(0, 0.5)
        claim.BackgroundColor3 = COLORS.claimable
        claim.Text = rewardAmt and ("Claim\n💎 " .. rewardAmt) or "Claim"
        claim.TextColor3 = COLORS.text
        claim.TextScaled = true
        claim.Font = Enum.Font.GothamBold
        claim.AutoButtonColor = true
        claim.ZIndex = 103
        claim.Parent = row
        local cc = Instance.new("UICorner")
        cc.CornerRadius = UDim.new(0, 10)
        cc.Parent = claim
        local clc = Instance.new("UITextSizeConstraint")
        clc.MaxTextSize = 18
        clc.Parent = claim
        claim.Activated:Connect(function()
            claim.Active = false
            claim.Text = "..."
            self:_callBus("achievement.claim", { achievementId = entry.id, tierId = tier.id })
            self:_refresh()
        end)
    else
        local side = Instance.new("TextLabel")
        side.Size = UDim2.new(0, 120, 0, 56)
        side.Position = UDim2.new(1, -132, 0.5, 0)
        side.AnchorPoint = Vector2.new(0, 0.5)
        side.BackgroundTransparency = 1
        side.Text = tier and (rewardAmt and ("Reward\n💎 " .. rewardAmt) or "") or "✓ Done"
        side.TextColor3 = tier and COLORS.subtext or COLORS.claimed
        side.TextScaled = true
        side.Font = Enum.Font.GothamBold
        side.TextXAlignment = Enum.TextXAlignment.Center
        side.ZIndex = 103
        side.Parent = row
        local sc = Instance.new("UITextSizeConstraint")
        sc.MaxTextSize = 16
        sc.Parent = side
    end
end

-- Compact big-number formatting for progress (12500 -> 12.5K).
function AchievementsPanel:_short(n)
    n = tonumber(n) or 0
    if n >= 1000000 then
        return string.format("%.1fM", n / 1000000):gsub("%.0M", "M")
    elseif n >= 1000 then
        return string.format("%.1fK", n / 1000):gsub("%.0K", "K")
    end
    return tostring(math.floor(n))
end

function AchievementsPanel:_refresh()
    if not self.isVisible or not self.listFrame then
        return
    end
    local res = self:_callBus("achievement.list", {})
    local achievements = (type(res) == "table" and res.achievements) or {}
    local categories = (type(res) == "table" and res.categories) or {}

    -- which categories have a CLAIMABLE achievement (for the tab dot)
    local claimableByCat = {}
    for _, entry in pairs(achievements) do
        local tier = currentTier(entry)
        if tier and (entry.value or 0) >= tier.goal then
            claimableByCat[entry.category or "other"] = true
        end
    end

    -- default the viewed category to the lowest-order one
    if not self.viewedCategory or not categories[self.viewedCategory] then
        local best, bestOrder = nil, math.huge
        for id, meta in pairs(categories) do
            local o = tonumber(meta.order) or 99
            if o < bestOrder then
                best, bestOrder = id, o
            end
        end
        self.viewedCategory = best
    end

    -- rebuild tabs — count first so each tab gets 1/N of the bar width (fills it edge-to-edge)
    for _, b in pairs(self.tabButtons) do
        b:Destroy()
    end
    self.tabButtons = {}
    local tabCount = 0
    for _ in pairs(categories) do
        tabCount += 1
    end
    self._tabCount = tabCount
    for id, meta in pairs(categories) do
        self:_makeTab(id, meta, claimableByCat[id])
    end

    -- rebuild rows for the viewed category (claimable first, then closest-to-done)
    for _, child in ipairs(self.listFrame:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end
    local rows = {}
    for _, entry in pairs(achievements) do
        if entry.category == self.viewedCategory then
            table.insert(rows, entry)
        end
    end
    table.sort(rows, function(a, b)
        local at, bt = currentTier(a), currentTier(b)
        local aClaim = at and (a.value or 0) >= at.goal
        local bClaim = bt and (b.value or 0) >= bt.goal
        if aClaim ~= bClaim then
            return aClaim
        end
        return tostring(a.display_name) < tostring(b.display_name)
    end)
    for i, entry in ipairs(rows) do
        self:_makeRow(entry, i)
    end
end

return AchievementsPanel
