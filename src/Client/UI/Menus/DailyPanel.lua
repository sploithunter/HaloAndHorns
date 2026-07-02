--[[
    DailyPanel — the client UI for the reward spine's Daily streak gate (Phase 9).

    Mirrors the ShopPanel/QuestPanel contract (.new / Show / Hide / GetFrame /
    IsVisible / Destroy) so MenuManager opens it from the "Daily" side-menu button.
    Renders the full streak calendar (claimed / today / upcoming), the current streak,
    and a Claim button. Live data via the GameAPICommand bus bridge: `daily.status`
    (calendar + claimable + streak) and `daily.claim`.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
-- Shared panel exterior (window + outer pill + header + close X + the pill helpers the tray buttons
-- use) + the currency-HUD capsule for the Claim button.
local PanelChrome = require(script.Parent.Parent.Components.PanelChrome)
local Pill = require(script.Parent.Parent.Pill)

local REMOTE_NAME = "GameAPICommand"

-- Claim-capsule colors + a re-tint helper mirroring Pill's gradient/stroke math (flip green/grey).
local CLAIM_ON = Color3.fromRGB(46, 170, 90)
local CLAIM_OFF = Color3.fromRGB(95, 100, 110)
local function lighten(c, amt)
    amt = amt / 255
    return Color3.new(
        math.clamp(c.R + amt, 0, 1),
        math.clamp(c.G + amt, 0, 1),
        math.clamp(c.B + amt, 0, 1)
    )
end
local function retintPill(btn, color)
    btn.BackgroundColor3 = color
    local g = btn:FindFirstChildOfClass("UIGradient")
    if g then
        g.Color = ColorSequence.new(lighten(color, 60), color)
    end
    local s = btn:FindFirstChildOfClass("UIStroke")
    if s then
        s.Color = lighten(color, 80)
    end
end
-- Dark text on the BRIGHT glossy tiles (citrine gold, emerald green) where white was unreadable;
-- white only on the dark upcoming tiles.
local function tileTextColor(key)
    if key == "citrine" then
        return Color3.fromRGB(64, 46, 8) -- dark amber on gold
    elseif key == "emerald" then
        return Color3.fromRGB(14, 46, 28) -- dark green on bright green
    end
    return Color3.fromRGB(255, 255, 255)
end

local COLORS = {
    panel = Color3.fromRGB(20, 20, 25),
    panelGradientTop = Color3.fromRGB(30, 30, 40),
    header = Color3.fromRGB(56, 161, 178),
    headerGradient = Color3.fromRGB(43, 134, 148),
    dayClaimed = Color3.fromRGB(39, 120, 92),
    dayToday = Color3.fromRGB(46, 204, 113),
    dayUpcoming = Color3.fromRGB(40, 42, 52),
    dayStroke = Color3.fromRGB(70, 74, 88),
    claimable = Color3.fromRGB(46, 204, 113),
    disabled = Color3.fromRGB(70, 74, 88),
    close = Color3.fromRGB(231, 76, 60),
    text = Color3.fromRGB(255, 255, 255),
    subtext = Color3.fromRGB(200, 205, 215),
    gold = Color3.fromRGB(255, 215, 0),
}

local DailyPanel = {}
DailyPanel.__index = DailyPanel

function DailyPanel.new()
    local self = setmetatable({}, DailyPanel)
    self.isVisible = false
    self.frame = nil
    return self
end

function DailyPanel:_callBus(name, args)
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

function DailyPanel:Show(parent)
    if self.isVisible then
        return
    end
    self:_createUI(parent)
    self.isVisible = true
    self:_refresh()
end

function DailyPanel:Hide()
    if not self.isVisible then
        return
    end
    if self.frame then
        self.frame:Destroy()
        self.frame = nil
    end
    self.isVisible = false
end

function DailyPanel:IsVisible()
    return self.isVisible
end

function DailyPanel:GetFrame()
    return self.frame
end

function DailyPanel:Destroy()
    self:Hide()
end

function DailyPanel:_createUI(parent)
    -- Shared window shell (outer area-themed pill + header + close X on top).
    local shell = PanelChrome.build(parent, {
        name = "DailyPanel",
        title = "📅 Daily Rewards",
        onClose = function()
            self:Hide()
        end,
    })
    local frame = shell.frame
    self.frame = frame

    -- Streak summary line (just under the header).
    self.streakLabel = Instance.new("TextLabel")
    self.streakLabel.Name = "StreakLabel"
    self.streakLabel.Size = UDim2.new(1, -48, 0, 28)
    self.streakLabel.Position = UDim2.new(0, 24, 0.16, 0)
    self.streakLabel.BackgroundTransparency = 1
    self.streakLabel.Text = "🔥 Streak: …"
    self.streakLabel.TextColor3 = COLORS.gold
    self.streakLabel.TextScaled = true
    self.streakLabel.Font = Enum.Font.GothamBold
    self.streakLabel.TextXAlignment = Enum.TextXAlignment.Left
    self.streakLabel.ZIndex = 102
    self.streakLabel.Parent = frame
    local streakConstraint = Instance.new("UITextSizeConstraint")
    streakConstraint.MaxTextSize = 22
    streakConstraint.Parent = self.streakLabel

    -- Calendar row of square day tiles (centered).
    local cal = Instance.new("Frame")
    cal.Name = "Calendar"
    cal.Size = UDim2.new(0.94, 0, 0, 132)
    cal.Position = UDim2.new(0.5, 0, 0.5, 0)
    cal.AnchorPoint = Vector2.new(0.5, 0.5)
    cal.BackgroundTransparency = 1
    cal.ZIndex = 101
    cal.Parent = frame
    self.calendarFrame = cal

    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.VerticalAlignment = Enum.VerticalAlignment.Center
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 8)
    layout.Parent = cal

    -- Claim button — THE shared currency-HUD capsule (green claimable / grey disabled).
    self.claimButton = Pill.button({
        parent = frame,
        color = CLAIM_OFF,
        size = UDim2.fromOffset(220, 54),
        position = UDim2.new(0.5, 0, 0.9, 0),
        anchorPoint = Vector2.new(0.5, 0.5),
        text = "…",
        textSize = 20,
        zIndex = 106,
    })
    self.claimButton.Name = "ClaimButton"
    self.claimButton.Activated:Connect(function()
        self:_claim()
    end)

    self:_animateEntrance()
end

local CURRENCY_LABELS = {
    area_coins = "Area Coins", -- resolves to the zone-you're-in coin at claim
    grass_coins = "Grass Coins",
    ice_coins = "Ice Coins",
    lava_coins = "Lava Coins",
    desert_coins = "Desert Coins",
}

local function rewardLabel(bundle)
    local parts = {}
    for currency, amount in pairs((bundle and bundle.currencies) or {}) do
        table.insert(parts, amount .. " " .. (CURRENCY_LABELS[currency] or currency))
    end
    for _, pet in ipairs((bundle and bundle.pets) or {}) do
        table.insert(parts, (pet.variant and (pet.variant .. " ") or "") .. tostring(pet.id))
    end
    for _, item in ipairs((bundle and bundle.items) or {}) do
        table.insert(parts, (item.qty or 1) .. "x " .. tostring(item.id))
    end
    if (bundle and bundle.experience or 0) > 0 then
        table.insert(parts, bundle.experience .. " XP")
    end
    return table.concat(parts, "\n")
end

function DailyPanel:_refresh()
    local status = self:_callBus("daily.status", {})
    if not status or not status.ok then
        self.streakLabel.Text = "Couldn't load daily rewards."
        return
    end

    self.streakLabel.Text = string.format(
        "🔥 Streak: %d day%s",
        status.streak or 0,
        (status.streak == 1) and "" or "s"
    )

    -- Rebuild calendar day cards.
    for _, ch in ipairs(self.calendarFrame:GetChildren()) do
        if ch:IsA("Frame") then
            ch:Destroy()
        end
    end

    local cycle = status.cycleLength or 7
    local claimDay = status.claimDay or 1
    local claimedThrough = status.claimable and (claimDay - 1) or claimDay
    for day = 1, cycle do
        self:_createDayCard(
            day,
            status.calendar and status.calendar[tostring(day)],
            claimDay,
            claimedThrough,
            status.claimable
        )
    end

    -- Claim button (capsule label + re-tint in place).
    if status.claimable then
        self.claimButton.Label.Text = "Claim Day " .. claimDay
        retintPill(self.claimButton, CLAIM_ON)
        self.claimButton.AutoButtonColor = true
        self.claimButton.Active = true
    else
        self.claimButton.Label.Text = "Come back tomorrow"
        retintPill(self.claimButton, CLAIM_OFF)
        self.claimButton.AutoButtonColor = false
        self.claimButton.Active = false
    end
end

function DailyPanel:_createDayCard(day, bundle, claimDay, claimedThrough, claimable)
    local isToday = claimable and day == claimDay
    local isClaimed = day <= claimedThrough

    local card = Instance.new("Frame")
    card.Name = "Day_" .. day
    card.Size = UDim2.new(0, 92, 1, 0)
    card.LayoutOrder = day
    card.ZIndex = 102
    card.Parent = self.calendarFrame

    -- ACTIVE states (today/claimed) get the full glossy tray-button pill so they POP; UPCOMING
    -- days recede to a dark fill + subtle neutral ring (the light pill panel made them too loud).
    local key
    if isToday or isClaimed then
        key = isToday and "citrine" or "emerald" -- gold = claimable, green = claimed
        card.BackgroundTransparency = 1
        PanelChrome.pillPanel(card, key, 100) -- glossy fill (same as the lower-left tray buttons)
        PanelChrome.pillBorder(card, key, 103, 0) -- neon ring
    else
        key = "upcoming"
        card.BackgroundColor3 = Color3.fromRGB(40, 42, 52)
        card.BorderSizePixel = 0
        local cc = Instance.new("UICorner")
        cc.CornerRadius = UDim.new(0, 10)
        cc.Parent = card
        PanelChrome.pillBorder(card, "neutral", 103, 2, 0.08)
    end

    local dayLabel = Instance.new("TextLabel")
    dayLabel.Size = UDim2.new(1, 0, 0, 22)
    dayLabel.Position = UDim2.new(0, 0, 0, 8)
    dayLabel.BackgroundTransparency = 1
    dayLabel.Text = isClaimed and ("Day " .. day .. " ✓") or ("Day " .. day)
    dayLabel.TextColor3 = tileTextColor(key)
    dayLabel.TextScaled = true
    dayLabel.Font = Enum.Font.GothamBold
    dayLabel.ZIndex = 110
    dayLabel.Parent = card
    local dayConstraint = Instance.new("UITextSizeConstraint")
    dayConstraint.MaxTextSize = 14
    dayConstraint.Parent = dayLabel

    local reward = Instance.new("TextLabel")
    reward.Size = UDim2.new(1, -8, 1, -34)
    reward.Position = UDim2.new(0, 4, 0, 30)
    reward.BackgroundTransparency = 1
    reward.Text = rewardLabel(bundle)
    reward.TextColor3 = tileTextColor(key)
    reward.TextWrapped = true
    reward.TextScaled = true
    reward.Font = Enum.Font.Gotham
    reward.ZIndex = 110
    reward.Parent = card
    local rewardConstraint = Instance.new("UITextSizeConstraint")
    rewardConstraint.MaxTextSize = 12
    rewardConstraint.Parent = reward
end

function DailyPanel:_claim()
    self.claimButton.Label.Text = "…"
    self.claimButton.Active = false
    self:_callBus("daily.claim", {})
    -- Refresh regardless: success advances the streak, failure (already claimed)
    -- just re-renders the disabled state.
    self:_refresh()
    -- clear the tray "!" immediately (BaseUI's poll would also catch it within a
    -- minute) — direct instance hide, no BaseUI handle needed from a panel
    local pg = game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui")
    local base = pg and pg:FindFirstChild("ProfessionalBaseUI")
    local btn = base and base:FindFirstChild("DailyButton", true)
    local badge = btn and btn:FindFirstChild("Notification")
    if badge then
        badge.Visible = false
    end
end

function DailyPanel:_animateEntrance()
    if not self.frame then
        return
    end
    self.frame.Size = UDim2.new(0.52, 0, 0.5, 0)
    TweenService:Create(
        self.frame,
        TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        { Size = UDim2.new(0.62, 0, 0.6, 0) }
    ):Play()
end

return DailyPanel
