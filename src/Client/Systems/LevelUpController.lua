--[[
    LevelUpController (client) — the City-of-Heroes-style level-up sequence.

    Owns its own ScreenGui so it doesn't depend on BaseUI's internals:
      * a glowing "LEVEL UP!" button that appears whenever the player's `PendingLevels`
        attribute > 0 (published by PlayerProgressionService),
      * clicking it claims ONE level via the `levelup.claim` bus command,
      * the server then fires Signals.LevelUp_Claimed, which opens a centered modal that
        reveals the new level + its rewards and — depending on the level — lets the player
        PICK A POWER (Feature 14) and/or SLOT enhancements (Feature 15, CoH "slotting").

    Stacked claims are handled one at a time: after Continue, if PendingLevels is still > 0
    the button reappears for the next claim.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Signals = require(ReplicatedStorage.Shared.Network.Signals)
local GameEvents = require(script.Parent.GameEvents)

local LevelUpController = {}
LevelUpController.__index = LevelUpController

-- ---- palette -------------------------------------------------------------
local GOLD = Color3.fromRGB(255, 205, 70)
local GOLD_DEEP = Color3.fromRGB(190, 140, 30)
-- ASCEND nudge colour: purple, so it pops against any area theme (esp. Desert/yellow, which would
-- otherwise blend with a gold button).
local PURPLE = Color3.fromRGB(150, 85, 225)
local PURPLE_DEEP = Color3.fromRGB(95, 45, 155)
local PANEL = Color3.fromRGB(28, 30, 40)
local PANEL_LIGHT = Color3.fromRGB(44, 47, 62)
local TEXT = Color3.fromRGB(245, 245, 250)
local TEXT_DIM = Color3.fromRGB(180, 184, 200)
local CARD = Color3.fromRGB(52, 56, 74)
local CARD_HOVER = Color3.fromRGB(70, 76, 100)
local OK_GREEN = Color3.fromRGB(110, 205, 120)

-- Slot types (mirror configs/augmentation.lua slot_types) with a short glyph.
local SLOT_TYPES = {
    { id = "recharge", label = "Recharge" },
    { id = "strength", label = "Strength" },
    { id = "range", label = "Range" },
    { id = "duration", label = "Duration" },
    { id = "efficiency", label = "Efficiency" },
    { id = "reliability", label = "Reliability" },
}

local function prettify(id)
    local s = tostring(id):gsub("_", " ")
    return (s:gsub("(%a)([%w]*)", function(a, b)
        return a:upper() .. b
    end))
end

local function callBus(name, args)
    local remote = ReplicatedStorage:FindFirstChild("GameAPICommand")
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

local function corner(inst, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 8)
    c.Parent = inst
    return c
end

local function stroke(inst, color, thickness)
    local s = Instance.new("UIStroke")
    s.Color = color
    s.Thickness = thickness or 1
    s.Parent = inst
    return s
end

-- ---- construction --------------------------------------------------------

function LevelUpController.start()
    local self = setmetatable({}, LevelUpController)
    self.player = Players.LocalPlayer
    self._claiming = false
    self:_build()
    self:_refreshButton()
    -- The nudge tracks TRAINING levels owed (power/slot/milestone) — those are claimed at the
    -- altar; filler levels auto-claim in the field (no button).
    self.player:GetAttributeChangedSignal("PendingTraining"):Connect(function()
        self:_refreshButton()
    end)
    Signals.LevelUp_Claimed.OnClientEvent:Connect(function(data)
        if data and data.auto then
            self:_toast(data) -- field auto-claim (filler) -> small toast
        else
            -- altar/training claim -> open the new PowerChoiceMenu (the real level-up UI), not the
            -- legacy grid modal. Falls back to the old sequence if MenuManager isn't up.
            self:_openChoiceMenu(data)
        end
    end)
    -- Altar engaged: open the level-up menu WITHOUT claiming (the level claims atomically on COMMIT).
    Signals.LevelUp_OpenChoice.OnClientEvent:Connect(function()
        self:_openChoiceMenu()
    end)
    -- Celebratory jingle whenever the CLAIMED level actually goes UP (catches every path: altar
    -- COMMIT, admin, etc. — commits are silent so we key off the attribute, not LevelUp_Claimed).
    -- Seed from the current value so the initial join replication doesn't fire it.
    local lastClaimed = tonumber(self.player:GetAttribute("ClaimedLevel"))
    self.player:GetAttributeChangedSignal("ClaimedLevel"):Connect(function()
        local lvl = tonumber(self.player:GetAttribute("ClaimedLevel"))
        if lvl and lastClaimed and lvl > lastClaimed then
            GameEvents.fire("level_up", { level = lvl }) -- config decides the reactions (sound/vfx/…)
        end
        lastClaimed = lvl or lastClaimed
    end)
    -- Hide the nudge while the PowerChoiceMenu is open (the nudge gui sits at a higher DisplayOrder,
    -- so it would otherwise render ON TOP of the menu and cover the instruction text). Cheap: only
    -- re-evaluates when the menu's open-state actually flips.
    local lastMenuOpen
    RunService.Heartbeat:Connect(function()
        local open = _G.PowerChoiceMenuOpen == true
        if open ~= lastMenuOpen then
            lastMenuOpen = open
            self:_refreshButton()
        end
    end)
    return self
end

-- Open the new PowerChoiceMenu (server-backed pick/slot flow). Falls back to the legacy reveal
-- modal only if the MenuManager / panel isn't available.
function LevelUpController:_openChoiceMenu()
    if _G.PowerChoiceMenuOpen then
        return -- already open; it refreshes itself after each in-menu claim (no rebuild/flicker)
    end
    -- Open the PowerChoiceMenu via MenuManager. MenuManager initialises a beat after join (it sits
    -- behind a pet-thumbnail prewarm that can take ~12s), so if the altar is triggered very early —
    -- e.g. resuming right next to it after a reboot — we RETRY for a while instead of dropping to the
    -- obsolete legacy reveal modal (which can't do the atomic claim-on-commit and shows "LEVEL ?!").
    task.spawn(function()
        for _ = 1, 300 do -- ~30s, covers the prewarm window
            if _G.PowerChoiceMenuOpen then
                return
            end
            local mm = _G.MenuManager
            if mm and mm.OpenPanel then
                mm:OpenPanel("PowerChoice", "scale_in")
                return
            end
            task.wait(0.1)
        end
    end)
end

function LevelUpController:_build()
    local gui = Instance.new("ScreenGui")
    gui.Name = "LevelUpGui"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 90
    gui.Enabled = true
    gui.Parent = self.player:WaitForChild("PlayerGui")
    self.gui = gui

    -- "LEVEL UP!" button (hidden until PendingLevels > 0)
    local btn = Instance.new("TextButton")
    btn.Name = "LevelUpButton"
    btn.Size = UDim2.new(0, 230, 0, 52)
    btn.Position = UDim2.new(0.5, 0, 0.17, 0)
    btn.AnchorPoint = Vector2.new(0.5, 0.5)
    btn.BackgroundColor3 = PURPLE
    btn.Text = "⬆  LEVEL UP!"
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.TextScaled = true
    btn.Font = Enum.Font.GothamBlack
    btn.AutoButtonColor = true
    btn.Visible = false
    btn.ZIndex = 5
    corner(btn, 12)
    stroke(btn, PURPLE_DEEP, 2)
    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, 8)
    pad.PaddingBottom = UDim.new(0, 8)
    pad.PaddingLeft = UDim.new(0, 12)
    pad.PaddingRight = UDim.new(0, 12)
    pad.Parent = btn
    btn.Parent = gui
    -- pixel-designed nudge: shrink on small viewports (center-anchored, scales in place)
    require(script.Parent.Parent.UI.UIViewportScale).attach(btn)
    self.button = btn
    -- Nudge: leveling up happens AT THE ALTAR (one consistent entry — Ascend opens the menu via
    -- LevelUp_OpenChoice). The nudge just points you there; it never opens the menu itself (devs use
    -- the admin POWER CHOICE button for a direct open). Keeps the flow consistent regardless of admin.
    btn.Activated:Connect(function()
        self:_toast({ title = "Ascend at the Ascension Altar", auto = true })
    end)

    -- gentle pulse so it draws the eye
    task.spawn(function()
        while gui.Parent do
            if btn.Visible then
                TweenService:Create(btn, TweenInfo.new(0.6, Enum.EasingStyle.Sine), {
                    Size = UDim2.new(0, 246, 0, 56),
                }):Play()
                task.wait(0.6)
                TweenService:Create(btn, TweenInfo.new(0.6, Enum.EasingStyle.Sine), {
                    Size = UDim2.new(0, 230, 0, 52),
                }):Play()
                task.wait(0.6)
            else
                task.wait(0.3)
            end
        end
    end)

    self:_buildModal()
end

function LevelUpController:_buildModal()
    local dim = Instance.new("TextButton") -- swallow clicks behind the panel
    dim.Name = "Dim"
    dim.Size = UDim2.new(1, 0, 1, 0)
    dim.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    dim.BackgroundTransparency = 0.4
    dim.Text = ""
    dim.AutoButtonColor = false
    dim.Visible = false
    dim.ZIndex = 10
    dim.Parent = self.gui
    self.dim = dim

    local panel = Instance.new("Frame")
    panel.Name = "Panel"
    panel.Size = UDim2.new(0, 560, 0, 460)
    panel.Position = UDim2.new(0.5, 0, 0.5, 0)
    panel.AnchorPoint = Vector2.new(0.5, 0.5)
    panel.BackgroundColor3 = PANEL
    panel.ZIndex = 11
    corner(panel, 18)
    stroke(panel, GOLD, 2)
    panel.Parent = dim
    self.panel = panel

    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, -40, 0, 56)
    title.Position = UDim2.new(0, 20, 0, 18)
    title.BackgroundTransparency = 1
    title.Text = "LEVEL UP!"
    title.TextColor3 = GOLD
    title.TextScaled = true
    title.Font = Enum.Font.GothamBlack
    title.ZIndex = 12
    title.Parent = panel
    self.title = title

    local subtitle = Instance.new("TextLabel")
    subtitle.Name = "Subtitle"
    subtitle.Size = UDim2.new(1, -40, 0, 26)
    subtitle.Position = UDim2.new(0, 20, 0, 76)
    subtitle.BackgroundTransparency = 1
    subtitle.Text = ""
    subtitle.TextColor3 = TEXT_DIM
    subtitle.TextScaled = true
    subtitle.Font = Enum.Font.GothamMedium
    subtitle.ZIndex = 12
    subtitle.Parent = panel
    self.subtitle = subtitle

    -- rewards line
    local rewards = Instance.new("TextLabel")
    rewards.Name = "Rewards"
    rewards.Size = UDim2.new(1, -40, 0, 30)
    rewards.Position = UDim2.new(0, 20, 0, 108)
    rewards.BackgroundTransparency = 1
    rewards.Text = ""
    rewards.TextColor3 = OK_GREEN
    rewards.TextScaled = true
    rewards.Font = Enum.Font.GothamBold
    rewards.ZIndex = 12
    rewards.Parent = panel
    self.rewards = rewards

    -- content area (power picker / slotting / hint live here)
    local content = Instance.new("Frame")
    content.Name = "Content"
    content.Size = UDim2.new(1, -40, 1, -210)
    content.Position = UDim2.new(0, 20, 0, 146)
    content.BackgroundTransparency = 1
    content.ZIndex = 12
    content.Parent = panel
    self.content = content

    local contentHeader = Instance.new("TextLabel")
    contentHeader.Name = "ContentHeader"
    contentHeader.Size = UDim2.new(1, 0, 0, 24)
    contentHeader.BackgroundTransparency = 1
    contentHeader.Text = ""
    contentHeader.TextColor3 = TEXT
    contentHeader.TextScaled = true
    contentHeader.Font = Enum.Font.GothamBold
    contentHeader.ZIndex = 13
    contentHeader.Parent = content
    self.contentHeader = contentHeader

    local scroll = Instance.new("ScrollingFrame")
    scroll.Name = "Scroll"
    scroll.Size = UDim2.new(1, 0, 1, -30)
    scroll.Position = UDim2.new(0, 0, 0, 30)
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 6
    scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scroll.ZIndex = 13
    scroll.Parent = content
    local grid = Instance.new("UIGridLayout")
    grid.CellSize = UDim2.new(0, 158, 0, 78)
    grid.CellPadding = UDim2.new(0, 10, 0, 10)
    grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
    grid.SortOrder = Enum.SortOrder.LayoutOrder
    grid.Parent = scroll
    self.scroll = scroll

    -- Continue button
    local cont = Instance.new("TextButton")
    cont.Name = "Continue"
    cont.Size = UDim2.new(0, 200, 0, 44)
    cont.Position = UDim2.new(0.5, 0, 1, -32)
    cont.AnchorPoint = Vector2.new(0.5, 1)
    cont.BackgroundColor3 = PANEL_LIGHT
    cont.Text = "Continue"
    cont.TextColor3 = TEXT
    cont.TextScaled = true
    cont.Font = Enum.Font.GothamBold
    cont.ZIndex = 13
    corner(cont, 10)
    stroke(cont, GOLD_DEEP, 1)
    local cpad = Instance.new("UIPadding")
    cpad.PaddingTop = UDim.new(0, 10)
    cpad.PaddingBottom = UDim.new(0, 10)
    cpad.Parent = cont
    cont.Parent = panel
    self.continue = cont
    cont.Activated:Connect(function()
        self:_close()
    end)
end

-- ---- nudge + toast ------------------------------------------------------

-- The button is now a NUDGE: shown only when TRAINING levels are owed, reminding the player to
-- visit the Ascension Altar (the claim itself happens at the altar's prompt).
function LevelUpController:_refreshButton()
    local training = tonumber(self.player:GetAttribute("PendingTraining")) or 0
    -- Suppressed while the level-up menu is open so the nudge never covers it.
    self.button.Visible = training > 0 and not (_G.PowerChoiceMenuOpen == true)
    if training > 1 then
        self.button.Text = string.format("✦  ASCEND  (%d)", training)
    else
        self.button.Text = "✦  ASCEND"
    end
end

-- A small auto-dismissing toast (top-center, below the nudge) for field auto-claims + hints.
function LevelUpController:_toast(data)
    data = data or {}
    local text = data.title
    if not text then
        local parts = { "Level " .. tostring(data.level or "?") .. "!" }
        if data.eggHatchTotal then
            table.insert(parts, "🥚 " .. tostring(data.eggHatchTotal))
        end
        text = table.concat(parts, "   ")
    end
    local toast = Instance.new("TextLabel")
    toast.Size = UDim2.new(0, 280, 0, 40)
    toast.Position = UDim2.new(0.5, 0, 0.24, 20)
    toast.AnchorPoint = Vector2.new(0.5, 0.5)
    toast.BackgroundColor3 = PANEL
    toast.BackgroundTransparency = 0.1
    toast.Text = "  " .. text .. "  "
    toast.TextColor3 = OK_GREEN
    toast.TextScaled = true
    toast.Font = Enum.Font.GothamBold
    toast.ZIndex = 8
    corner(toast, 10)
    stroke(toast, GOLD_DEEP, 1)
    toast.Parent = self.gui
    TweenService:Create(toast, TweenInfo.new(0.25), { Position = UDim2.new(0.5, 0, 0.24, 0) })
        :Play()
    task.delay(2.2, function()
        local fade = TweenService:Create(toast, TweenInfo.new(0.4), {
            TextTransparency = 1,
            BackgroundTransparency = 1,
        })
        fade:Play()
        fade.Completed:Wait()
        toast:Destroy()
    end)
end

-- ---- the sequence modal --------------------------------------------------

function LevelUpController:_showSequence(data)
    -- The new PowerChoiceMenu owns the level-up claim UX while it's open; don't double up with the
    -- legacy reveal modal (it already drives power.select / augment.place / levelup.claim itself).
    if _G.PowerChoiceMenuOpen then
        return
    end
    data = data or {}
    self.title.Text = "LEVEL " .. tostring(data.level or "?") .. "!"
    self.subtitle.Text = self:_kindBlurb(data)
    self.rewards.Text = self:_rewardLine(data)

    -- clear content grid
    for _, c in ipairs(self.scroll:GetChildren()) do
        if c:IsA("GuiObject") then
            c:Destroy()
        end
    end

    if data.powerPick then
        self.contentHeader.Text = "Choose a Power"
        self:_renderPowerPicker(data.level)
    elseif (tonumber(data.slots) or 0) > 0 then
        self.contentHeader.Text = "Slot an Enhancement"
        self:_renderSlotting()
    else
        self.contentHeader.Text = ""
    end

    self.dim.Visible = true
    -- pop-in
    self.panel.Size = UDim2.new(0, 480, 0, 400)
    TweenService
        :Create(self.panel, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Size = UDim2.new(0, 560, 0, 460),
        })
        :Play()
end

function LevelUpController:_kindBlurb(data)
    if data.milestone then
        return "★ Milestone reached!"
    elseif data.powerPick then
        return "A new power awaits."
    elseif (tonumber(data.slots) or 0) > 0 then
        return "Enhancement slots earned."
    end
    return "Onward and upward."
end

function LevelUpController:_rewardLine(data)
    local parts = {}
    if data.eggHatchTotal then
        table.insert(parts, "🥚 " .. tostring(data.eggHatchTotal) .. " egg hatch")
    end
    if (tonumber(data.slots) or 0) > 0 then
        table.insert(parts, "✦ +" .. tostring(data.slots) .. " slots")
    end
    return table.concat(parts, "    ")
end

local function makeCard(text, sub, accent)
    local card = Instance.new("TextButton")
    card.BackgroundColor3 = CARD
    card.AutoButtonColor = false
    card.Text = ""
    card.ZIndex = 14
    corner(card, 10)
    local st = stroke(card, accent or GOLD_DEEP, 1)
    local name = Instance.new("TextLabel")
    name.Size = UDim2.new(1, -12, 0, 26)
    name.Position = UDim2.new(0, 6, 0, 10)
    name.BackgroundTransparency = 1
    name.Text = text
    name.TextColor3 = TEXT
    name.TextScaled = true
    name.Font = Enum.Font.GothamBold
    name.ZIndex = 15
    name.Parent = card
    local desc = Instance.new("TextLabel")
    desc.Size = UDim2.new(1, -12, 0, 22)
    desc.Position = UDim2.new(0, 6, 0, 42)
    desc.BackgroundTransparency = 1
    desc.Text = sub or ""
    desc.TextColor3 = TEXT_DIM
    desc.TextScaled = true
    desc.Font = Enum.Font.Gotham
    desc.ZIndex = 15
    desc.Parent = card
    card.MouseEnter:Connect(function()
        card.BackgroundColor3 = CARD_HOVER
    end)
    card.MouseLeave:Connect(function()
        card.BackgroundColor3 = CARD
    end)
    return card, st
end

function LevelUpController:_renderPowerPicker(level)
    local state = callBus("power.get", { level = level })
    local available = (state and state.available) or {}
    local selected = {}
    for _, id in ipairs((state and state.powers) or {}) do
        selected[id] = true
    end

    local any = false
    for i, id in ipairs(available) do
        if not selected[id] then
            any = true
            local card = makeCard(prettify(id), "Click to learn", GOLD)
            card.LayoutOrder = i
            card.Parent = self.scroll
            card.Activated:Connect(function()
                self:_selectPower(id, level)
            end)
        end
    end

    if not any then
        self.contentHeader.Text = "No new powers available"
    end
end

function LevelUpController:_selectPower(powerId, level)
    local res = callBus("power.select", { powerId = powerId })
    if res and res.ok then
        self.contentHeader.Text = "✓ Learned " .. prettify(powerId)
        for _, c in ipairs(self.scroll:GetChildren()) do
            if c:IsA("GuiObject") then
                c:Destroy()
            end
        end
    else
        self.contentHeader.Text = "Couldn't learn that power"
        -- re-render so the player can retry
        self:_renderPowerPicker(level)
    end
end

function LevelUpController:_renderSlotting()
    local state = callBus("augment.get", {})
    local unallocated = (state and (state.unallocated or state.granted)) or 0
    if type(unallocated) == "table" then
        unallocated = unallocated.unallocated or 0
    end
    -- list the player's selected powers; clicking one places a strength slot (default).
    local powers = callBus("power.get", {})
    local list = (powers and powers.powers) or {}
    if #list == 0 then
        self.contentHeader.Text = "Pick a power first to slot it"
        return
    end
    self.contentHeader.Text = string.format("Slot a power  (%s available)", tostring(unallocated))
    for i, id in ipairs(list) do
        local card = makeCard(prettify(id), "Tap to slot", PANEL_LIGHT)
        card.LayoutOrder = i
        card.Parent = self.scroll
        card.Activated:Connect(function()
            self:_placeSlot(id)
        end)
    end
end

function LevelUpController:_placeSlot(powerId)
    -- Default to a "strength" enhancement; the full type chooser lives in the Powers menu.
    local res = callBus("augment.place", { powerId = powerId, slotType = "strength" })
    if res and res.ok then
        self.contentHeader.Text = "✓ Slotted " .. prettify(powerId) .. " (+Strength)"
    else
        self.contentHeader.Text = "No free slots — manage in the Powers menu"
    end
end

function LevelUpController:_close()
    self.dim.Visible = false
    -- next pending claim (if any) re-shows the button
    self:_refreshButton()
end

return LevelUpController
