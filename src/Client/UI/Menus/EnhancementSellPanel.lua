--[[
    EnhancementSellPanel — the dedicated "Salvage Enhancements" surface (sell + bulk
    junk-salvage). Opened from the Inventory panel's Enhancements category via a single
    "💎 Sell / Salvage" entry button.

    Mirrors QuestPanel's menu contract (.new / Show(parent) / Hide / IsVisible /
    GetFrame / Destroy + a `_callBus` GameAPICommand helper) so MenuManager opens it the
    same way every other panel is opened:

        local EnhancementSellPanel = require(script.EnhancementSellPanel)
        menuManager:RegisterPanel("EnhancementSell", EnhancementSellPanel.new())
        _G.MenuManager:OpenPanel("EnhancementSell", "bounce_in")

    Server is the SSOT (backend done + tested). Bus contract:
      enhancement.shop.list_owned  {} -> { ok, currency, balance, items=[...] }
      enhancement.shop.sell        { uid, quantity } -> { ok, sold, gems, balance, remaining, reason? }
      enhancement.shop.junk_preview{} -> { ok, currency, naturals={count,gems}, duals={count,gems} }
      enhancement.shop.sell_junk   { includeDuals=bool? } -> { ok, sold, stacks, gems, includedDuals, balance }

    Reuses the SAME shared parts as the rest of the game (project rule — no flat
    parallel primitives): PetBadge.createEnhancementBadge (the element-disc + tinted
    ring used on the inventory enhancement cards), CloseButton (the standard X), and
    QuantitySelector.prompt (the "Sell N" slider, same control as delete/trade).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local CloseButton = require(script.Parent.Parent.Components.CloseButton)
local QuantitySelector = require(script.Parent.Parent.Components.QuantitySelector)
local PanelChrome = require(script.Parent.Parent.Components.PanelChrome)

-- Lay the game pill BORDER ring (area-themed, hollow) over a full-corner button so it reads as a
-- pill while keeping its own fill color + intrinsic text. Same treatment the inventory buttons use.
local function pillify(btn)
    for _, c in ipairs(btn:GetChildren()) do
        if c:IsA("UICorner") or c.Name == "PillBorder" then
            c:Destroy()
        end
    end
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = btn
    PanelChrome.pillBorder(btn, PanelChrome.areaPill(), (btn.ZIndex or 1) + 1, 0, 0.18)
    return btn
end

-- PetBadge is optional-required so a load failure degrades to a text chip rather than
-- erroring the whole panel (same defensive pattern InventoryPanel uses for PetBadge).
local PetBadge
do
    local ok, mod = pcall(function()
        return require(script.Parent.Parent.PetBadge)
    end)
    PetBadge = ok and mod or nil
end

-- PetCardStyle — the SHARED card chrome (rounded frame + rarity/variant rings +
-- background gradient). The inventory enhancement card is assembled from this exact
-- renderer; we reuse it so the sell cards are visually identical (project unification
-- rule: never hand-roll a parallel card).
local PetCardStyle = require(script.Parent.Parent.PetCardStyle)

local REMOTE_NAME = "GameAPICommand"

-- Palette: matches QuestPanel's card aesthetic so the panel reads as part of the same
-- menu family. Gem-green accent (this is the gem economy surface).
local COLORS = {
    panel = Color3.fromRGB(20, 20, 25),
    panelGradientTop = Color3.fromRGB(30, 30, 40),
    header = Color3.fromRGB(56, 161, 178),
    headerGradient = Color3.fromRGB(43, 134, 148),
    toolbar = Color3.fromRGB(28, 30, 38),
    sell = Color3.fromRGB(46, 204, 113),
    sellHover = Color3.fromRGB(39, 174, 96),
    junk = Color3.fromRGB(230, 126, 34), -- "Sell Junk" salvage action (amber)
    junkHover = Color3.fromRGB(202, 105, 24),
    text = Color3.fromRGB(255, 255, 255),
    subtext = Color3.fromRGB(200, 205, 215),
    dim = Color3.fromRGB(150, 156, 168),
    gem = Color3.fromRGB(120, 220, 255),
    danger = Color3.fromRGB(231, 76, 60),
    checkOn = Color3.fromRGB(46, 204, 113),
    checkOff = Color3.fromRGB(60, 62, 72),
}

-- Card chrome accent color, mirroring InventoryPanel:_loadEnhancementsFromFolder so the
-- ring tints identically: single = its origin's color, dual = chaotic purple, natural =
-- neutral grey. The DISC carries the real per-origin color via PetBadge; this only tints
-- the card frame's rarity stroke (applyChrome's colorOverride).
local ORIGIN_COLOR = {
    geomancer = Color3.fromRGB(150, 230, 150),
    pyromancer = Color3.fromRGB(255, 150, 120),
    cryomancer = Color3.fromRGB(140, 200, 255),
    sandwalker = Color3.fromRGB(240, 215, 130),
}
local DUAL_COLOR = Color3.fromRGB(196, 156, 255)
local NATURAL_COLOR = Color3.fromRGB(205, 205, 215)

local function enhancementCardColor(item)
    local origins = type(item.origins) == "table" and item.origins or {}
    if #origins == 0 then
        return NATURAL_COLOR
    elseif #origins == 1 then
        return ORIGIN_COLOR[origins[1]] or NATURAL_COLOR
    end
    return DUAL_COLOR
end

local EnhancementSellPanel = {}
EnhancementSellPanel.__index = EnhancementSellPanel

function EnhancementSellPanel.new()
    local self = setmetatable({}, EnhancementSellPanel)
    self.isVisible = false
    self.frame = nil
    self.listFrame = nil
    self.rows = {}
    self.includeDuals = false -- duals are opt-in (they hold trade value)
    self.balance = 0
    self.preview = nil -- { naturals={count,gems}, duals={count,gems} }
    self.items = {}
    return self
end

-- Call a bus command through the shared GameAPICommand RemoteFunction. Returns the
-- handler result table ({ ok = ... }) or nil on transport failure. The envelope unwraps
-- as `result or envelope` (same pattern as QuestPanel/_hatchEggItem).
function EnhancementSellPanel:_callBus(name, args)
    local remote = ReplicatedStorage:FindFirstChild(REMOTE_NAME)
        or ReplicatedStorage:WaitForChild(REMOTE_NAME, 5)
    if not remote then
        return nil
    end
    local ok, envelope = pcall(function()
        return remote:InvokeServer(name, args or {})
    end)
    if not ok or type(envelope) ~= "table" then
        return nil
    end
    return envelope.result or envelope
end

----------------------------------------------------------------------------------------
-- Lifecycle (MenuManager contract)
----------------------------------------------------------------------------------------

function EnhancementSellPanel:Show(parent)
    if self.isVisible then
        return
    end
    self:_createUI(parent)
    self.isVisible = true
    self:_refresh()
end

function EnhancementSellPanel:Hide()
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

function EnhancementSellPanel:IsVisible()
    return self.isVisible
end

function EnhancementSellPanel:GetFrame()
    return self.frame
end

function EnhancementSellPanel:Destroy()
    self:Hide()
end

----------------------------------------------------------------------------------------
-- UI build
----------------------------------------------------------------------------------------

local HEADER_H = 76
local TOOLBAR_H = 96
local CARD_SIZE = 140 -- square card footprint, in the inventory grid's size range

function EnhancementSellPanel:_createUI(parent)
    local frame = Instance.new("Frame")
    frame.Name = "EnhancementSellPanel"
    frame.Size = UDim2.new(0.7, 0, 0.85, 0)
    frame.Position = UDim2.new(0.5, 0, 0.5, 0)
    frame.AnchorPoint = Vector2.new(0.5, 0.5)
    frame.BackgroundColor3 = COLORS.panel
    frame.BorderSizePixel = 0
    frame.ZIndex = 100
    frame.Parent = parent
    self.frame = frame

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 20)
    corner.Parent = frame

    -- Standard area-themed game pill around the whole menu, same as the inventory/pets shell
    -- (Jason: "same treatment as the pets menu outside border").
    PanelChrome.pillBorder(frame, PanelChrome.areaPill(), 130, 0, 0.07) -- match the shared shell

    local gradient = Instance.new("UIGradient")
    gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, COLORS.panelGradientTop),
        ColorSequenceKeypoint.new(1, COLORS.panel),
    })
    gradient.Rotation = 45
    gradient.Parent = frame

    self:_createHeader()
    self:_createToolbar()

    -- Scrolling list of owned stacks (below header + toolbar).
    local list = Instance.new("ScrollingFrame")
    list.Name = "StackList"
    list.Size = UDim2.new(1, -24, 1, -(HEADER_H + TOOLBAR_H + 16))
    list.Position = UDim2.new(0, 12, 0, HEADER_H + TOOLBAR_H + 4)
    list.BackgroundTransparency = 1
    list.BorderSizePixel = 0
    list.ScrollBarThickness = 6
    list.CanvasSize = UDim2.new(0, 0, 0, 0)
    list.AutomaticCanvasSize = Enum.AutomaticSize.Y
    list.ZIndex = 101
    list.Parent = frame
    self.listFrame = list

    -- Responsive GRID of square cards (same square footprint as the inventory grid).
    local grid = Instance.new("UIGridLayout")
    grid.CellSize = UDim2.new(0, CARD_SIZE, 0, CARD_SIZE)
    grid.CellPadding = UDim2.new(0, 12, 0, 12)
    grid.SortOrder = Enum.SortOrder.LayoutOrder
    grid.HorizontalAlignment = Enum.HorizontalAlignment.Left
    grid.Parent = list

    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, 6)
    pad.PaddingBottom = UDim.new(0, 6)
    pad.PaddingLeft = UDim.new(0, 4)
    pad.PaddingRight = UDim.new(0, 4)
    pad.Parent = list

    self:_animateEntrance()
end

function EnhancementSellPanel:_createHeader()
    local header = Instance.new("Frame")
    header.Name = "Header"
    header.Size = UDim2.new(1, 0, 0, HEADER_H)
    header.BackgroundColor3 = COLORS.header
    header.BorderSizePixel = 0
    header.ZIndex = 101
    header.Parent = self.frame

    local headerCorner = Instance.new("UICorner")
    headerCorner.CornerRadius = UDim.new(0, 20)
    headerCorner.Parent = header

    local headerGradient = Instance.new("UIGradient")
    headerGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, COLORS.header),
        ColorSequenceKeypoint.new(1, COLORS.headerGradient),
    })
    headerGradient.Rotation = 90
    headerGradient.Parent = header

    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, -320, 1, 0)
    title.Position = UDim2.new(0, 24, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "💎 Salvage Enhancements"
    title.TextColor3 = COLORS.text
    title.TextScaled = true
    title.Font = Enum.Font.GothamBold
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.ZIndex = 102
    title.Parent = header

    local titleConstraint = Instance.new("UITextSizeConstraint")
    titleConstraint.MaxTextSize = 30
    titleConstraint.Parent = title

    -- Live gem balance, right of the title (left of the X).
    local bal = Instance.new("TextLabel")
    bal.Name = "Balance"
    bal.Size = UDim2.new(0, 220, 0, 36)
    bal.Position = UDim2.new(1, -64, 0.5, 0)
    bal.AnchorPoint = Vector2.new(1, 0.5)
    bal.BackgroundTransparency = 1
    bal.Text = "💎 0"
    bal.TextColor3 = COLORS.text
    bal.TextScaled = true
    bal.Font = Enum.Font.GothamBold
    bal.TextXAlignment = Enum.TextXAlignment.Right
    bal.ZIndex = 102
    bal.Parent = header
    local balC = Instance.new("UITextSizeConstraint")
    balC.MaxTextSize = 24
    balC.Parent = bal
    self.balanceLabel = bal

    -- Parent the X to the panel frame at Z146 so it sits ABOVE the outer pill border (an X nested in
    -- the header would render under the 130 ring under Sibling z-order).
    CloseButton.attach(self.frame, {
        zindex = 146,
        onClick = function()
            self:Hide()
        end,
    })
end

function EnhancementSellPanel:_createToolbar()
    local bar = Instance.new("Frame")
    bar.Name = "Toolbar"
    bar.Size = UDim2.new(1, -24, 0, TOOLBAR_H - 12)
    bar.Position = UDim2.new(0, 12, 0, HEADER_H + 4)
    bar.BackgroundColor3 = COLORS.toolbar
    bar.BorderSizePixel = 0
    bar.ZIndex = 101
    bar.Parent = self.frame
    local barCorner = Instance.new("UICorner")
    barCorner.CornerRadius = UDim.new(0, 12)
    barCorner.Parent = bar
    local barPad = Instance.new("UIPadding")
    barPad.PaddingLeft = UDim.new(0, 12)
    barPad.PaddingRight = UDim.new(0, 12)
    barPad.PaddingTop = UDim.new(0, 8)
    barPad.PaddingBottom = UDim.new(0, 8)
    barPad.Parent = bar

    -- Left block: "Include duals" checkbox + the live preview label.
    -- "Sell Junk" button floats on the right.
    local sellJunkBtn = Instance.new("TextButton")
    sellJunkBtn.Name = "SellJunk"
    sellJunkBtn.Size = UDim2.new(0, 150, 0, 40)
    sellJunkBtn.Position = UDim2.new(1, 0, 0, 0)
    sellJunkBtn.AnchorPoint = Vector2.new(1, 0)
    sellJunkBtn.BackgroundColor3 = COLORS.junk
    sellJunkBtn.Text = "🧹 Sell Junk"
    sellJunkBtn.TextColor3 = COLORS.text
    sellJunkBtn.TextSize = 18
    sellJunkBtn.Font = Enum.Font.GothamBold
    sellJunkBtn.AutoButtonColor = true
    sellJunkBtn.ZIndex = 103
    sellJunkBtn.Parent = bar
    pillify(sellJunkBtn) -- pill around the Sell Junk action (Jason)
    sellJunkBtn.MouseEnter:Connect(function()
        sellJunkBtn.BackgroundColor3 = COLORS.junkHover
    end)
    sellJunkBtn.MouseLeave:Connect(function()
        sellJunkBtn.BackgroundColor3 = COLORS.junk
    end)
    sellJunkBtn.Activated:Connect(function()
        self:_onSellJunk()
    end)
    self.sellJunkBtn = sellJunkBtn

    -- "Include duals" checkbox (custom: a small toggle square + label).
    local checkBtn = Instance.new("TextButton")
    checkBtn.Name = "IncludeDuals"
    checkBtn.Size = UDim2.new(0, 28, 0, 28)
    checkBtn.Position = UDim2.new(0, 0, 0, 2)
    checkBtn.BackgroundColor3 = COLORS.checkOff
    checkBtn.Text = ""
    checkBtn.AutoButtonColor = true
    checkBtn.ZIndex = 103
    checkBtn.Parent = bar
    local ckCorner = Instance.new("UICorner")
    ckCorner.CornerRadius = UDim.new(0, 6)
    ckCorner.Parent = checkBtn
    local ckMark = Instance.new("TextLabel")
    ckMark.Size = UDim2.new(1, 0, 1, 0)
    ckMark.BackgroundTransparency = 1
    ckMark.Text = "✓"
    ckMark.TextColor3 = COLORS.text
    ckMark.TextScaled = true
    ckMark.Font = Enum.Font.GothamBold
    ckMark.Visible = false
    ckMark.ZIndex = 104
    ckMark.Parent = checkBtn
    self.checkMark = ckMark
    self.checkBtn = checkBtn

    local ckLabel = Instance.new("TextLabel")
    ckLabel.Size = UDim2.new(0, 160, 0, 28)
    ckLabel.Position = UDim2.new(0, 36, 0, 2)
    ckLabel.BackgroundTransparency = 1
    ckLabel.Text = "Include duals"
    ckLabel.TextColor3 = COLORS.subtext
    ckLabel.TextXAlignment = Enum.TextXAlignment.Left
    ckLabel.TextSize = 16
    ckLabel.Font = Enum.Font.GothamMedium
    ckLabel.ZIndex = 103
    ckLabel.Parent = bar

    checkBtn.Activated:Connect(function()
        self.includeDuals = not self.includeDuals
        self:_applyCheckState()
        self:_renderPreview() -- instant from already-fetched buckets (no re-fetch)
    end)

    -- Live preview label (Naturals / + Duals / Total). Multi-line.
    local preview = Instance.new("TextLabel")
    preview.Name = "Preview"
    preview.Size = UDim2.new(1, -170, 0, 36)
    preview.Position = UDim2.new(0, 0, 0, 34)
    preview.BackgroundTransparency = 1
    preview.Text = "Naturals: 0 · 💎0"
    preview.TextColor3 = COLORS.gem
    preview.TextXAlignment = Enum.TextXAlignment.Left
    preview.TextYAlignment = Enum.TextYAlignment.Top
    preview.TextSize = 15
    preview.Font = Enum.Font.GothamMedium
    preview.RichText = true
    preview.ZIndex = 103
    preview.Parent = bar
    self.previewLabel = preview

    self:_applyCheckState()
end

function EnhancementSellPanel:_applyCheckState()
    if self.checkMark then
        self.checkMark.Visible = self.includeDuals
    end
    if self.checkBtn then
        self.checkBtn.BackgroundColor3 = self.includeDuals and COLORS.checkOn or COLORS.checkOff
    end
end

function EnhancementSellPanel:_animateEntrance()
    if not self.frame then
        return
    end
    local uiScale = Instance.new("UIScale")
    uiScale.Scale = 0.92
    uiScale.Parent = self.frame
    TweenService:Create(
        uiScale,
        TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        { Scale = 1 }
    ):Play()
end

----------------------------------------------------------------------------------------
-- Preview / balance
----------------------------------------------------------------------------------------

-- The currently-selected junk totals, derived from the fetched preview + checkbox.
function EnhancementSellPanel:_selectedJunkTotals()
    local p = self.preview or {}
    local nat = p.naturals or { count = 0, gems = 0 }
    local dual = p.duals or { count = 0, gems = 0 }
    local count = (nat.count or 0)
    local gems = (nat.gems or 0)
    if self.includeDuals then
        count += (dual.count or 0)
        gems += (dual.gems or 0)
    end
    return count, gems
end

function EnhancementSellPanel:_renderPreview()
    if not self.previewLabel then
        return
    end
    local p = self.preview or {}
    local nat = p.naturals or { count = 0, gems = 0 }
    local dual = p.duals or { count = 0, gems = 0 }
    local _, totalGems = self:_selectedJunkTotals()
    local lines = ("Naturals: %d · 💎%d"):format(nat.count or 0, nat.gems or 0)
    if self.includeDuals then
        lines = lines .. ("   + Duals: %d · 💎%d"):format(dual.count or 0, dual.gems or 0)
    end
    lines = lines .. ("\n<b>Total: 💎%d</b>"):format(totalGems)
    self.previewLabel.Text = lines
end

function EnhancementSellPanel:_setBalance(n)
    self.balance = tonumber(n) or self.balance or 0
    if self.balanceLabel then
        self.balanceLabel.Text = ("💎 %d"):format(self.balance)
    end
end

----------------------------------------------------------------------------------------
-- Toast (lightweight, in-panel; the codebase has no global toast service)
----------------------------------------------------------------------------------------

function EnhancementSellPanel:_toast(text, accent)
    if not self.frame then
        return
    end
    local t = Instance.new("TextLabel")
    t.Name = "Toast"
    t.Size = UDim2.new(0, 380, 0, 44)
    t.AnchorPoint = Vector2.new(0.5, 1)
    t.Position = UDim2.new(0.5, 0, 1, -18)
    t.BackgroundColor3 = Color3.fromRGB(20, 22, 28)
    t.BackgroundTransparency = 0.05
    t.Text = text
    t.TextColor3 = COLORS.text
    t.TextScaled = true
    t.Font = Enum.Font.GothamBold
    t.ZIndex = 500
    t.Parent = self.frame
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 10)
    c.Parent = t
    local s = Instance.new("UIStroke")
    s.Color = accent or COLORS.sell
    s.Thickness = 2
    s.Parent = t
    local con = Instance.new("UITextSizeConstraint")
    con.MaxTextSize = 18
    con.Parent = t
    t.TextTransparency = 1
    t.BackgroundTransparency = 1
    s.Transparency = 1
    TweenService
        :Create(t, TweenInfo.new(0.15), { TextTransparency = 0, BackgroundTransparency = 0.05 })
        :Play()
    TweenService:Create(s, TweenInfo.new(0.15), { Transparency = 0 }):Play()
    task.delay(2.0, function()
        if t and t.Parent then
            local out = TweenService:Create(
                t,
                TweenInfo.new(0.25),
                { TextTransparency = 1, BackgroundTransparency = 1 }
            )
            out.Completed:Connect(function()
                if t then
                    t:Destroy()
                end
            end)
            out:Play()
        end
    end)
end

----------------------------------------------------------------------------------------
-- Data refresh + render
----------------------------------------------------------------------------------------

function EnhancementSellPanel:_refresh()
    task.spawn(function()
        local owned = self:_callBus("enhancement.shop.list_owned", {})
        local preview = self:_callBus("enhancement.shop.junk_preview", {})
        if not self.isVisible or not self.frame then
            return
        end
        self.items = (owned and type(owned.items) == "table" and owned.items) or {}
        -- balance from the bus result; else fall back to the replicated attribute.
        local bal = owned and owned.balance
        if bal == nil then
            bal = Players.LocalPlayer:GetAttribute("Gems") or 0
        end
        self:_setBalance(bal)
        if preview and preview.ok ~= false then
            self.preview = { naturals = preview.naturals, duals = preview.duals }
        else
            self.preview = nil
        end
        self:_renderPreview()
        self:_renderList()
    end)
end

-- Sort: junk first (so the salvage-worthy stacks surface), then by grade
-- (natural -> single -> dual), then level desc, then type A-Z.
local GRADE_RANK = { natural = 0, single = 1, dual = 2 }
local function sortItems(a, b)
    local aj = a.junk and 0 or 1
    local bj = b.junk and 0 or 1
    if aj ~= bj then
        return aj < bj
    end
    local ag = GRADE_RANK[tostring(a.grade)] or 9
    local bg = GRADE_RANK[tostring(b.grade)] or 9
    if ag ~= bg then
        return ag < bg
    end
    local al, bl = tonumber(a.level) or 0, tonumber(b.level) or 0
    if al ~= bl then
        return al > bl
    end
    return tostring(a.type) < tostring(b.type)
end

function EnhancementSellPanel:_renderList()
    if not self.listFrame then
        return
    end
    for _, child in ipairs(self.listFrame:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end
    -- empty-state label lives on the panel frame (not in the grid, which would size it)
    if self._emptyLabel then
        self._emptyLabel:Destroy()
        self._emptyLabel = nil
    end
    self.rows = {}

    local items = {}
    for _, it in ipairs(self.items) do
        items[#items + 1] = it
    end
    table.sort(items, sortItems)

    if #items == 0 then
        local lbl = Instance.new("TextLabel")
        lbl.Name = "EmptyLabel"
        lbl.Size = UDim2.new(1, -24, 0, 60)
        lbl.Position = UDim2.new(0, 12, 0, HEADER_H + TOOLBAR_H + 20)
        lbl.BackgroundTransparency = 1
        lbl.Text = "No enhancements to sell."
        lbl.TextColor3 = COLORS.dim
        lbl.TextSize = 18
        lbl.Font = Enum.Font.GothamMedium
        lbl.ZIndex = 102
        lbl.Parent = self.frame
        self._emptyLabel = lbl
        return
    end

    for i, item in ipairs(items) do
        self:_buildCard(item, i)
    end
end

-- One SQUARE stack card, visually IDENTICAL to the inventory enhancement card: shared
-- PetCardStyle.applyChrome chrome + a centered iconBG holding PetBadge's enhancement
-- disc + an L## chip (top-left) + ×N badge (top-right). The card's BOTTOM corners carry
-- the sell affordances (price bottom-left, Sell button bottom-right) — the same bottom-
-- corner real estate pet cards use for power chips. Junk stacks get an amber stroke + a
-- tiny corner tag.
function EnhancementSellPanel:_buildCard(item, order)
    local card = Instance.new("Frame")
    card.Name = "Card_" .. tostring(item.uid)
    card.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
    card.BorderSizePixel = 0
    card.LayoutOrder = order
    card.ZIndex = 102
    card.Parent = self.listFrame

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = card

    -- SHARED card chrome (rarity ring + variant ring + background gradient). The grade
    -- accent color tints the ring; rarityId/variant are nil for enhancements (applyChrome
    -- defaults), exactly as the inventory enhancement card passes them.
    local accent = enhancementCardColor(item)
    PetCardStyle.applyChrome(card, nil, nil, nil, accent)

    -- centered icon background holding the disc (mirrors InventoryPanel's iconBG)
    local iconSize = math.floor(CARD_SIZE * 0.5)
    local iconBG = Instance.new("Frame")
    iconBG.Name = "IconBG"
    iconBG.Size = UDim2.new(0, iconSize, 0, iconSize)
    iconBG.Position = UDim2.new(0.5, -math.floor(iconSize / 2), 0, math.floor(CARD_SIZE * 0.1))
    iconBG.BackgroundColor3 = accent
    iconBG.BackgroundTransparency = 0.8
    iconBG.BorderSizePixel = 0
    iconBG.ZIndex = 103
    iconBG.Parent = card
    local iconCorner = Instance.new("UICorner")
    iconCorner.CornerRadius = UDim.new(0, math.floor(CARD_SIZE * 0.3))
    iconCorner.Parent = iconBG

    -- the SAME enhancement disc the inventory cards render
    local origins = type(item.origins) == "table" and item.origins or {}
    if PetBadge and PetBadge.createEnhancementBadge then
        PetBadge.createEnhancementBadge(iconBG, {
            size = UDim2.fromScale(0.92, 0.92),
            position = UDim2.fromScale(0.5, 0.5),
            anchor = Vector2.new(0.5, 0.5),
            record = { type = item.type, origins = origins },
            dead = item.dead == true,
            zindex = 104,
        })
    else
        local fallback = Instance.new("TextLabel")
        fallback.Size = UDim2.fromScale(0.92, 0.92)
        fallback.AnchorPoint = Vector2.new(0.5, 0.5)
        fallback.Position = UDim2.fromScale(0.5, 0.5)
        fallback.BackgroundTransparency = 1
        fallback.Text = "⚙️"
        fallback.TextScaled = true
        fallback.ZIndex = 104
        fallback.Parent = iconBG
    end

    -- L## chip, TOP-LEFT (same spot/shape as the inventory enhancement card)
    local lW = math.max(16, math.floor(CARD_SIZE * 0.3))
    local lH = math.max(12, math.floor(CARD_SIZE * 0.18))
    local lM = math.max(2, math.floor(CARD_SIZE * 0.05))
    local lvl = Instance.new("TextLabel")
    lvl.Name = "EnhLevel"
    lvl.Size = UDim2.fromOffset(lW, lH)
    lvl.Position = UDim2.fromOffset(lM, lM)
    lvl.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    lvl.BackgroundTransparency = 0.25
    lvl.Text = "L" .. tostring(item.level or "?")
    lvl.TextColor3 = accent
    lvl.TextScaled = true
    lvl.Font = Enum.Font.GothamBold
    lvl.ZIndex = 105
    lvl.Parent = card
    local lc = Instance.new("UICorner")
    lc.CornerRadius = UDim.new(0, 5)
    lc.Parent = lvl

    -- ×N badge, TOP-RIGHT (only when quantity > 1)
    local qty = math.max(1, tonumber(item.quantity) or 1)
    if qty > 1 then
        local qW = math.max(16, math.floor(CARD_SIZE * 0.3))
        local qH = math.max(12, math.floor(CARD_SIZE * 0.18))
        local qM = math.max(2, math.floor(CARD_SIZE * 0.05))
        local qtyLabel = Instance.new("TextLabel")
        qtyLabel.Name = "QtyLabel"
        qtyLabel.Size = UDim2.fromOffset(qW, qH)
        qtyLabel.Position = UDim2.new(1, -qW - qM, 0, qM)
        qtyLabel.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
        qtyLabel.BackgroundTransparency = 0.25
        qtyLabel.Text = "×" .. tostring(qty)
        qtyLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        qtyLabel.TextScaled = true
        qtyLabel.Font = Enum.Font.GothamBold
        qtyLabel.ZIndex = 105
        qtyLabel.Parent = card
        local qc = Instance.new("UICorner")
        qc.CornerRadius = UDim.new(0, 5)
        qc.Parent = qtyLabel
    end

    -- type name, centered under the disc (the card's identity line)
    local typeName = tostring(item.type or "Enhancement")
    typeName = typeName:sub(1, 1):upper() .. typeName:sub(2)
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "TypeName"
    nameLabel.Size = UDim2.new(1, -10, 0, math.floor(CARD_SIZE * 0.16))
    nameLabel.Position = UDim2.new(0, 5, 0, math.floor(CARD_SIZE * 0.6))
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = typeName
    nameLabel.TextColor3 = COLORS.text
    nameLabel.TextScaled = true
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.ZIndex = 103
    nameLabel.Parent = card
    local nameC = Instance.new("UITextSizeConstraint")
    nameC.MaxTextSize = 15
    nameC.Parent = nameLabel

    -- BOTTOM-LEFT corner: per-unit gem price pill (gem-green accent)
    local priceW = math.floor(CARD_SIZE * 0.46)
    local priceH = math.floor(CARD_SIZE * 0.2)
    local priceM = math.max(3, math.floor(CARD_SIZE * 0.05))
    local price = Instance.new("TextLabel")
    price.Name = "Price"
    price.Size = UDim2.fromOffset(priceW, priceH)
    price.Position = UDim2.new(0, priceM, 1, -priceH - priceM)
    price.BackgroundColor3 = Color3.fromRGB(24, 40, 32)
    price.BackgroundTransparency = 0.15
    price.Text = ("💎%d"):format(tonumber(item.sellUnit) or 0)
    price.TextColor3 = COLORS.sell
    price.TextScaled = true
    price.Font = Enum.Font.GothamBold
    price.ZIndex = 105
    price.Parent = card
    local priceC = Instance.new("UICorner")
    priceC.CornerRadius = UDim.new(0, 6)
    priceC.Parent = price
    local priceCon = Instance.new("UITextSizeConstraint")
    priceCon.MaxTextSize = 14
    priceCon.Parent = price

    -- BOTTOM-RIGHT corner: compact Sell button (gem-green)
    local sellW = math.floor(CARD_SIZE * 0.4)
    local sellH = math.floor(CARD_SIZE * 0.22)
    local sellBtn = Instance.new("TextButton")
    sellBtn.Name = "Sell"
    sellBtn.Size = UDim2.fromOffset(sellW, sellH)
    sellBtn.Position = UDim2.new(1, -sellW - priceM, 1, -sellH - priceM)
    sellBtn.BackgroundColor3 = COLORS.sell
    sellBtn.Text = "Sell"
    sellBtn.TextColor3 = COLORS.text
    sellBtn.TextScaled = true
    sellBtn.Font = Enum.Font.GothamBold
    sellBtn.AutoButtonColor = true
    sellBtn.ZIndex = 105
    sellBtn.Parent = card
    local sbc = Instance.new("UICorner")
    sbc.CornerRadius = UDim.new(0, 8)
    sbc.Parent = sellBtn
    local sellCon = Instance.new("UITextSizeConstraint")
    sellCon.MaxTextSize = 15
    sellCon.Parent = sellBtn
    sellBtn.MouseEnter:Connect(function()
        sellBtn.BackgroundColor3 = COLORS.sellHover
    end)
    sellBtn.MouseLeave:Connect(function()
        sellBtn.BackgroundColor3 = COLORS.sell
    end)
    sellBtn.Activated:Connect(function()
        self:_onSellStack(item)
    end)

    -- JUNK flag: thin amber stroke around the card + a tiny corner tag
    -- ("dead" / "can't slot") so salvage-worthy stacks read at a glance.
    if item.junk then
        local js = Instance.new("UIStroke")
        js.Name = "JunkStroke"
        js.Color = COLORS.junk
        js.Thickness = 2
        js.Transparency = 0.1
        js.Parent = card
        local tagText = item.dead and "dead"
            or ((item.grade == "dual" and item.usable == false) and "can't slot")
            or "junk"
        local tag = Instance.new("TextLabel")
        tag.Name = "JunkTag"
        tag.Size = UDim2.new(0, math.floor(CARD_SIZE * 0.5), 0, math.floor(CARD_SIZE * 0.14))
        tag.AnchorPoint = Vector2.new(0.5, 0)
        tag.Position = UDim2.new(0.5, 0, 0, math.floor(CARD_SIZE * 0.02))
        tag.BackgroundColor3 = COLORS.junk
        tag.BackgroundTransparency = 0.1
        tag.Text = tagText
        tag.TextColor3 = Color3.fromRGB(20, 20, 24)
        tag.TextScaled = true
        tag.Font = Enum.Font.GothamBold
        tag.ZIndex = 106
        tag.Parent = card
        local tc = Instance.new("UICorner")
        tc.CornerRadius = UDim.new(0, 5)
        tc.Parent = tag
        local tcon = Instance.new("UITextSizeConstraint")
        tcon.MaxTextSize = 12
        tcon.Parent = tag
    end

    self.rows[#self.rows + 1] = card
end

----------------------------------------------------------------------------------------
-- Actions
----------------------------------------------------------------------------------------

function EnhancementSellPanel:_onSellStack(item)
    local qty = math.max(1, tonumber(item.quantity) or 1)
    if qty == 1 then
        self:_doSell(item, 1)
        return
    end
    QuantitySelector.prompt({
        parent = self.frame,
        title = "Sell " .. tostring(item.type),
        subtitle = ("💎%d each  •  have %d"):format(tonumber(item.sellUnit) or 0, qty),
        iconText = "⚙️",
        accent = COLORS.sell,
        min = 1,
        max = qty,
        default = qty,
        confirmText = "Sell",
        onConfirm = function(amount)
            self:_doSell(item, amount)
        end,
    })
end

function EnhancementSellPanel:_doSell(item, amount)
    task.spawn(function()
        local r = self:_callBus("enhancement.shop.sell", { uid = item.uid, quantity = amount })
            or {}
        if not self.isVisible then
            return
        end
        if r.ok then
            self:_toast(("Sold %d for 💎%d"):format(r.sold or amount, r.gems or 0), COLORS.sell)
            self:_refresh()
        else
            self:_toast("Couldn't sell: " .. tostring(r.reason or "unknown"), COLORS.danger)
        end
    end)
end

function EnhancementSellPanel:_onSellJunk()
    local count, gems = self:_selectedJunkTotals()
    if count <= 0 then
        self:_toast("Nothing to salvage.", COLORS.junk)
        return
    end
    local note = self.includeDuals and "Naturals + duals — singles are kept."
        or "Naturals only — duals & singles kept."
    self:_confirm({
        title = ("Sell %d dead enhancement(s) for 💎%d?"):format(count, gems),
        note = note,
        confirmText = "🧹 Sell Junk",
        accent = COLORS.junk,
        onConfirm = function()
            task.spawn(function()
                local r = self:_callBus(
                    "enhancement.shop.sell_junk",
                    { includeDuals = self.includeDuals }
                ) or {}
                if not self.isVisible then
                    return
                end
                if r.ok then
                    self:_toast(
                        ("Salvaged %d stack(s) for 💎%d"):format(r.stacks or 0, r.gems or 0),
                        COLORS.junk
                    )
                    self:_refresh()
                else
                    self:_toast(
                        "Couldn't salvage: " .. tostring(r.reason or "unknown"),
                        COLORS.danger
                    )
                end
            end)
        end,
    })
end

----------------------------------------------------------------------------------------
-- Confirm modal (small self-contained dialog — same shape as the inventory hatch/delete
-- confirms; no shared confirm component exists in this codebase).
----------------------------------------------------------------------------------------

function EnhancementSellPanel:_confirm(opts)
    opts = opts or {}
    local accent = opts.accent or COLORS.sell

    local scrim = Instance.new("TextButton")
    scrim.Name = "ConfirmScrim"
    scrim.Text = ""
    scrim.AutoButtonColor = false
    scrim.Size = UDim2.new(1, 0, 1, 0)
    scrim.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    scrim.BackgroundTransparency = 0.45
    scrim.BorderSizePixel = 0
    scrim.ZIndex = 600
    scrim.Parent = self.frame

    local card = Instance.new("Frame")
    card.Size = UDim2.new(0, 380, 0, 200)
    card.AnchorPoint = Vector2.new(0.5, 0.5)
    card.Position = UDim2.new(0.5, 0, 0.5, 0)
    card.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    card.BorderSizePixel = 0
    card.ZIndex = 601
    card.Parent = scrim
    local cc = Instance.new("UICorner")
    cc.CornerRadius = UDim.new(0, 18)
    cc.Parent = card
    -- Area pill border around the confirm card, same as the panel shell (Jason).
    PanelChrome.pillBorder(card, PanelChrome.areaPill(), 605, 0, 0.12)

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -28, 0, 70)
    title.Position = UDim2.new(0, 14, 0, 16)
    title.BackgroundTransparency = 1
    title.Text = opts.title or "Confirm?"
    title.TextColor3 = COLORS.text
    title.TextWrapped = true
    title.TextSize = 19
    title.Font = Enum.Font.GothamBold
    title.ZIndex = 602
    title.Parent = card

    if opts.note then
        local note = Instance.new("TextLabel")
        note.Size = UDim2.new(1, -28, 0, 40)
        note.Position = UDim2.new(0, 14, 0, 92)
        note.BackgroundTransparency = 1
        note.Text = opts.note
        note.TextColor3 = COLORS.subtext
        note.TextWrapped = true
        note.TextSize = 14
        note.Font = Enum.Font.GothamMedium
        note.ZIndex = 602
        note.Parent = card
    end

    local function destroy()
        scrim:Destroy()
    end
    scrim.Activated:Connect(destroy)

    local buttons = Instance.new("Frame")
    buttons.Size = UDim2.new(1, -28, 0, 40)
    buttons.Position = UDim2.new(0, 14, 1, -54)
    buttons.BackgroundTransparency = 1
    buttons.ZIndex = 602
    buttons.Parent = card
    local bl = Instance.new("UIListLayout")
    bl.FillDirection = Enum.FillDirection.Horizontal
    bl.HorizontalAlignment = Enum.HorizontalAlignment.Right
    bl.SortOrder = Enum.SortOrder.LayoutOrder
    bl.Padding = UDim.new(0, 10)
    bl.Parent = buttons

    local cancelBtn = Instance.new("TextButton")
    cancelBtn.Size = UDim2.new(0, 110, 1, 0)
    cancelBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 80)
    cancelBtn.Text = "Cancel"
    cancelBtn.TextColor3 = COLORS.text
    cancelBtn.TextSize = 15
    cancelBtn.Font = Enum.Font.GothamBold
    cancelBtn.LayoutOrder = 1
    cancelBtn.ZIndex = 603
    cancelBtn.Parent = buttons
    pillify(cancelBtn)
    cancelBtn.Activated:Connect(destroy)

    local okBtn = Instance.new("TextButton")
    okBtn.Size = UDim2.new(0, 160, 1, 0)
    okBtn.BackgroundColor3 = accent
    okBtn.Text = opts.confirmText or "Confirm"
    okBtn.TextColor3 = COLORS.text
    okBtn.TextSize = 15
    okBtn.Font = Enum.Font.GothamBold
    okBtn.LayoutOrder = 2
    okBtn.ZIndex = 603
    okBtn.Parent = buttons
    pillify(okBtn)
    okBtn.Activated:Connect(function()
        destroy()
        if opts.onConfirm then
            opts.onConfirm()
        end
    end)

    card.Size = UDim2.new(0, 0, 0, 0)
    TweenService:Create(
        card,
        TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        { Size = UDim2.new(0, 380, 0, 200) }
    ):Play()
end

return EnhancementSellPanel
