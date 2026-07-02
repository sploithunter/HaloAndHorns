--[[
    HotbarBar — lower-center power/command bar (Feature 16 UI, slice B).

    20 slots laid out as two rows of 10 (bottom row 1-0, top row Shift+1-0), plus a
    farming-mode cycle button on the left (Off -> Near -> High) that drives the
    auto-target toggles. Slots are fed by the server (Hotbar_State); pressing a slot's
    key OR clicking it fires Hotbar_Activate(slot), which the server resolves to the
    bound power / tactical / pet-summon.

    Keys: bottom row = 1..9,0 ; top row = Shift+1..9,0. (No Ctrl — the browser eats
    Ctrl+1-9.) The default Roblox Backpack is disabled so the number keys are free.
    The buttons are the cross-platform source of truth; keys are a desktop shortcut.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local Signals = require(ReplicatedStorage.Shared.Network.Signals)
local POWER_ICONS = require(ReplicatedStorage:WaitForChild("Configs"):WaitForChild("power_icons"))
local PILL = require(ReplicatedStorage.Configs:WaitForChild("pill_ui"))
local POWERS = require(ReplicatedStorage.Configs:WaitForChild("powers"))
local POWER_DESC = require(ReplicatedStorage.Configs:WaitForChild("power_descriptions"))
-- Derived-description SSOT (the same source the powers menu uses). The hotbar tooltip used to read
-- the hardcoded POWER_DESC table, which only covered some powers — new ones (Taunt etc.) fell to
-- "(no description)" even though the menu showed a full one. PowerDescribe builds from the live
-- config so every power reads.
local PowerDescribe = require(ReplicatedStorage.Shared.Game.PowerDescribe)
local PetBadge = require(script.Parent.Parent.UI.PetBadge)
local UITheme = require(script.Parent.Parent.UI.UITheme)
local CloseButton = require(script.Parent.Parent.UI.Components.CloseButton)

-- Tint a pill ImageLabel to the player's area palette (frames are keyed by colour name —
-- sapphire/citrine/ruby/emerald/neutral — same keys UITheme returns), re-applying when the area
-- (HomeArea / origin) changes. Falls back to sapphire if a colour has no frame.
local function bindPillFrame(img)
    UITheme.bind(nil, function(palette)
        img.Image = PILL.frames[palette.color] or PILL.frames.sapphire
    end)
end

local HotbarBar = {}

local localPlayer = Players.LocalPlayer

-- KeyCode -> base digit slot (1..10). Shift adds 10 (slots 11..20).
local DIGIT_SLOT = {
    [Enum.KeyCode.One] = 1,
    [Enum.KeyCode.Two] = 2,
    [Enum.KeyCode.Three] = 3,
    [Enum.KeyCode.Four] = 4,
    [Enum.KeyCode.Five] = 5,
    [Enum.KeyCode.Six] = 6,
    [Enum.KeyCode.Seven] = 7,
    [Enum.KeyCode.Eight] = 8,
    [Enum.KeyCode.Nine] = 9,
    [Enum.KeyCode.Zero] = 10,
}

local TYPE_COLOR = {
    power = Color3.fromRGB(150, 110, 235),
    tactical = Color3.fromRGB(230, 170, 60),
    roster = Color3.fromRGB(70, 170, 230),
    pet = Color3.fromRGB(90, 200, 120),
    potion = Color3.fromRGB(150, 80, 200), -- potion slot tint (overridden per-meter axis colour)
}
-- Authored disc icons for tactical commands (rendered like a power disc but with NO targeting ring).
-- element = disc colour tier (neutral = the purple "generic command" disc). Add rows as art lands.
local TACTICAL_BADGE = {
    rally = { element = "neutral", symbol = "flag" }, -- rally the squad = banner/flag
}
local FARM_COLOR = {
    Off = Color3.fromRGB(70, 72, 84),
    Near = Color3.fromRGB(90, 200, 120),
    High = Color3.fromRGB(230, 120, 70),
}

local function keyLabel(slot)
    local digit = slot
    if slot > 10 then
        digit = slot - 10
    end
    local d = (digit == 10) and "0" or tostring(digit)
    return slot > 10 and ("⇧" .. d) or d
end

-- Short label for a bind so the slot reads at a glance.
local function bindLabel(bind)
    if not bind then
        return ""
    end
    local t = tostring(bind.target or "")
    if bind.type == "tactical" then
        local abbr = {
            focus_fire = "Focus",
            scatter = "Scatter",
            regroup = "Regroup",
            retreat = "Retreat",
            rally = "Rally",
        }
        return abbr[t] or t
    end
    -- power/roster/pet: trim to something readable
    t = t:gsub("_", " ")
    if #t > 9 then
        t = t:sub(1, 8) .. "…"
    end
    return t
end

-- Tooltip "type" line = <targeting> <category>, derived from the badge: ring -> targeting word,
-- symbol -> effect category. `aura` (self/squad) shows just the category. A power can override the
-- whole string in configs/power_descriptions (entry as a table with `type`) for nuance, e.g. a
-- secondary "DoT (minor)".
local RING_TARGET = {
    target_in = "Single Target",
    target_out = "Single Ally",
    aoe = "AoE",
    target_aoe = "Team AoE",
}
local SYMBOL_KIND = {
    armor_chest = "Armor",
    shield = "Shield",
    fist = "Damage Buff",
    fist_impact = "Damage",
    fist_broken = "Damage Debuff",
    chevrons_up = "Buff",
    chevrons_down = "Debuff",
    eye = "Accuracy Buff",
    eye_hidden = "Blind",
    contagion = "DoT",
    capacitor = "Hold",
    user_desk = "Root",
    target = "Accuracy Buff",
    target_down = "Accuracy Debuff",
    shield_broken = "Armor Break",
    plus = "Heal",
    plus_down = "Heal Debuff",
    coins_up = "Coin Buff",
    gift_up = "Drop Buff",
    clover_lucky = "Luck",
    clover_huge = "Huge Luck",
    history = "Recharge",
    magnet = "Magnet",
    pet_transfer = "Recall",
    portal = "Teleport",
    revive = "Summon",
    xp_up = "XP Buff",
    star_sparkle = "Support",
    arrow_right = "Speed",
    knockback = "Knockback",
}
local function deriveType(powerId)
    local b = PetBadge.forPower(powerId)
    if not b then
        return ""
    end
    local cat = SYMBOL_KIND[b.symbol] or "Power"
    local tgt = RING_TARGET[b.ring]
    return tgt and (tgt .. " " .. cat) or cat
end

function HotbarBar.start()
    -- Free the number keys: this game uses a custom inventory, not the Roblox Backpack.
    pcall(function()
        StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
    end)

    local gui = Instance.new("ScreenGui")
    gui.Name = "HotbarBar"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.Parent = localPlayer:WaitForChild("PlayerGui")

    local SLOT = 46
    local PAD = 4
    local rowWidth = 10 * SLOT + 9 * PAD

    local root = Instance.new("Frame")
    root.Name = "Bar"
    root.AnchorPoint = Vector2.new(0.5, 1)
    root.Position = UDim2.new(0.5, 0, 1, -20)
    root.Size = UDim2.fromOffset(rowWidth + SLOT + PAD, SLOT * 2 + PAD)
    -- pixel-designed bar: shrink on small viewports (anchored bottom-center, stays docked)
    require(script.Parent.Parent.UI.UIViewportScale).attach(root)
    root.BackgroundTransparency = 1
    root.Parent = gui

    -- Blue neon pill_frame wrapping the whole bar (9-slice so the wide bar keeps proper corners;
    -- transparent inside AND outside, so the game shows through and the slots sit on top).
    local barFrame = Instance.new("ImageLabel")
    barFrame.Name = "PillFrame"
    barFrame.BackgroundTransparency = 1
    barFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    barFrame.Position = UDim2.fromScale(0.5, 0.5)
    barFrame.Size = UDim2.new(1, 46, 1, 30)
    bindPillFrame(barFrame) -- themed to the player's origin/area (was hardcoded sapphire/blue)
    barFrame.ScaleType = Enum.ScaleType.Slice
    barFrame.SliceCenter = Rect.new(180, 180, 330, 330)
    barFrame.ZIndex = 0
    barFrame.Parent = root

    -- Farming cycle button (left of the bar).
    local farmBtn = Instance.new("TextButton")
    farmBtn.Name = "Farming"
    farmBtn.AnchorPoint = Vector2.new(0, 1)
    farmBtn.Position = UDim2.fromOffset(3, SLOT * 2 + PAD - 7) -- nudged up so its ring clears the frame's bottom border
    farmBtn.Size = UDim2.fromOffset(SLOT - 6, SLOT - 6) -- square (bottom-left), pairs with the Edit square above
    farmBtn.AutoButtonColor = false
    farmBtn.Font = Enum.Font.GothamBold
    farmBtn.TextSize = 12
    farmBtn.TextColor3 = Color3.fromRGB(240, 240, 245)
    farmBtn.Text = "Farm\nOff"
    farmBtn.BackgroundColor3 = FARM_COLOR.Off
    farmBtn.BorderSizePixel = 0
    farmBtn.Parent = root
    do
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 6)
        c.Parent = farmBtn
    end

    -- Assignment (edit) state: the palette pushed by the server + a forward-declared
    -- picker opener so a slot click can open it while in edit mode.
    local available = { powers = {}, tacticals = {}, potions = {} }
    local editMode = false
    local openPicker
    local editHint -- the "pick a slot" arrow over slot 1; dismissed once a slot is clicked (openPicker)

    -- ===== Potions: live brew-meter state for any slot bound to a potion =====
    -- PotionService is the SSOT; it pushes PotionUpdate (charge + owned counts) and answers
    -- potion.state for the initial pull. We keep the charge interpolating between 1s pushes so a
    -- potion slot's draining radial-clock reads smoothly (reusing the power-cooldown edge clock).
    local potionMeters = {} -- meterId -> { charge, drain_seconds, color }
    local potionByPotion = {} -- potionId -> { meter, icon, count, name }
    local potionPushClock = os.clock()
    local function potionLiveCharge(meterId)
        local m = potionMeters[meterId]
        if not m then
            return 0
        end
        local c = (m.charge or 0)
            - (os.clock() - potionPushClock) / math.max(1, m.drain_seconds or 1)
        return math.clamp(c, 0, 1)
    end
    local function ingestPotionState(state)
        if type(state) ~= "table" then
            return
        end
        potionMeters = state.meters or {}
        potionPushClock = os.clock()
        potionByPotion = {}
        for _, p in ipairs(state.potions or {}) do
            potionByPotion[p.id] = p
        end
    end
    local function callBus(name, args)
        local remote = ReplicatedStorage:FindFirstChild("GameAPICommand")
        if not remote then
            return nil
        end
        local ok, envelope = pcall(function()
            return remote:InvokeServer(name, args or {})
        end)
        if ok and type(envelope) == "table" then
            return envelope.result
        end
        return nil
    end
    -- Lazily attach the potion-only chrome to a card: a big centred glyph + a top-right count badge.
    -- (Powers use the disc/ring art; potions are emoji-glyph + "×N", so this lives separate.)
    local function ensurePotionChrome(card)
        if card.potGlyph then
            return
        end
        local glyph = Instance.new("TextLabel")
        glyph.Name = "PotionGlyph"
        glyph.BackgroundTransparency = 1
        glyph.Size = UDim2.fromScale(0.7, 0.7)
        glyph.Position = UDim2.fromScale(0.5, 0.5)
        glyph.AnchorPoint = Vector2.new(0.5, 0.5)
        glyph.Font = Enum.Font.GothamBold
        glyph.TextScaled = true
        glyph.Text = "🧪"
        glyph.ZIndex = 3
        glyph.Visible = false
        glyph.Parent = card.frame
        local count = Instance.new("TextLabel")
        count.Name = "PotionCount"
        count.AnchorPoint = Vector2.new(1, 0)
        count.Position = UDim2.new(1, -2, 0, 1)
        count.Size = UDim2.fromOffset(20, 14)
        count.BackgroundColor3 = Color3.fromRGB(10, 10, 14)
        count.BackgroundTransparency = 0.2
        count.Font = Enum.Font.GothamBold
        count.TextScaled = true
        count.TextColor3 = Color3.fromRGB(255, 255, 255)
        count.Text = "×0"
        count.ZIndex = 4
        count.Visible = false
        count.Parent = card.frame
        local cc = Instance.new("UICorner")
        cc.CornerRadius = UDim.new(0, 4)
        cc.Parent = count
        card.potGlyph = glyph
        card.potCount = count
    end

    -- Cooldown overlay on a (circular) slot, reusing the golden/rainbow-pet shimmer:
    -- while recharging the icon dims, a rainbow UIGradient ring spins around it (same
    -- look as the inventory variant ring), and a seconds countdown shows the exact time
    -- left. Returns set(elapsed, secondsLeft); elapsed >= 1 (ready) hides it.
    local RAINBOW = ColorSequence.new({
        ColorSequenceKeypoint.new(0.0, Color3.fromRGB(255, 90, 90)),
        ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 205, 70)),
        ColorSequenceKeypoint.new(0.4, Color3.fromRGB(95, 230, 120)),
        ColorSequenceKeypoint.new(0.6, Color3.fromRGB(70, 185, 255)),
        ColorSequenceKeypoint.new(0.8, Color3.fromRGB(185, 120, 255)),
        ColorSequenceKeypoint.new(1.0, Color3.fromRGB(255, 90, 90)),
    })
    local function attachRadial(slotBtn)
        local holder = Instance.new("Frame")
        holder.Name = "Cool"
        holder.Size = UDim2.fromScale(1, 1)
        holder.BackgroundTransparency = 1
        holder.Visible = false
        holder.ZIndex = 4
        holder.Parent = slotBtn

        local dim = Instance.new("Frame") -- darkens the icon while recharging
        dim.Size = UDim2.fromScale(1, 1)
        dim.BackgroundColor3 = Color3.fromRGB(6, 7, 11)
        dim.BackgroundTransparency = 0.45
        dim.BorderSizePixel = 0
        dim.ZIndex = 4
        dim.Parent = holder
        local dc = Instance.new("UICorner")
        dc.CornerRadius = UDim.new(1, 0)
        dc.Parent = dim

        local ring = Instance.new("UIStroke") -- the spinning rainbow shimmer
        ring.Thickness = 3
        ring.Parent = dim
        local grad = Instance.new("UIGradient")
        grad.Color = RAINBOW
        grad.Parent = ring

        local num = Instance.new("TextLabel")
        num.BackgroundTransparency = 1
        num.Size = UDim2.fromScale(1, 1)
        num.Font = Enum.Font.GothamBold
        num.TextSize = 16
        num.TextColor3 = Color3.fromRGB(255, 255, 255)
        num.TextStrokeTransparency = 0.3
        num.ZIndex = 5
        num.Text = ""
        num.Parent = holder

        return function(elapsed, secondsLeft)
            if not elapsed or elapsed >= 1 then
                holder.Visible = false
                return
            end
            holder.Visible = true
            num.Text = secondsLeft and tostring(math.ceil(secondsLeft)) or ""
            grad.Rotation = (os.clock() * 160) % 360 -- continuous shimmer spin
        end
    end

    -- Two rows of 10 slots. Bottom row = slots 1-10, top row = 11-20.
    local cards = {}
    local locked = {} -- slot -> true when AUTO-CAST locked; re-fires on cooldown
    local lastAuto = {} -- slot -> os.clock() of the last auto-fire (bridges the fire->cooldown round-trip)
    local longPressConsumed = {} -- slot -> true: a long-press just toggled, so suppress the tap's activate
    local LONG_PRESS = 0.45 -- seconds: hold a slot this long (touch or mouse) to toggle the lock

    -- Toggle a slot's auto-cast lock. Same action on desktop (right-click) and mobile (long-press).
    local function toggleAutoLock(slot)
        if editMode then
            return
        end
        local card = cards[slot]
        if not (card and card.bindObj) then
            return
        end
        locked[slot] = not locked[slot] or nil
        if card.lock then
            card.lock.Visible = locked[slot] == true
        end
    end

    -- Hover tooltip: after a short hover on a power slot, a popup shows the power's NAME + what it
    -- DOES (configs/power_descriptions). Anchored bottom-left at the slot's top edge, so it pops up
    -- and to the right of the slot (origin = lower-left, per Jason).
    local HOVER_DELAY = 0.6 -- seconds hovering before it appears (bump toward 3 if you want it slower)
    local tip = Instance.new("Frame")
    tip.Name = "PowerTooltip"
    tip.AnchorPoint = Vector2.new(0, 1)
    tip.Size = UDim2.fromOffset(236, 10)
    tip.AutomaticSize = Enum.AutomaticSize.Y
    tip.BackgroundColor3 = Color3.fromRGB(18, 20, 28)
    tip.BackgroundTransparency = 0.05
    tip.BorderSizePixel = 0
    tip.Visible = false
    tip.ZIndex = 40
    tip.Parent = gui
    do
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 8)
        c.Parent = tip
        local s = Instance.new("UIStroke")
        s.Color = Color3.fromRGB(70, 75, 95)
        s.Thickness = 1.5
        s.Parent = tip
        local pad = Instance.new("UIPadding")
        pad.PaddingTop = UDim.new(0, 8)
        pad.PaddingBottom = UDim.new(0, 8)
        pad.PaddingLeft = UDim.new(0, 10)
        pad.PaddingRight = UDim.new(0, 10)
        pad.Parent = tip
        local list = Instance.new("UIListLayout")
        list.SortOrder = Enum.SortOrder.LayoutOrder
        list.Padding = UDim.new(0, 3)
        list.Parent = tip
    end
    local tipName = Instance.new("TextLabel")
    tipName.LayoutOrder = 1
    tipName.BackgroundTransparency = 1
    tipName.Size = UDim2.new(1, 0, 0, 16)
    tipName.Font = Enum.Font.GothamBold
    tipName.TextSize = 14
    tipName.TextXAlignment = Enum.TextXAlignment.Left
    tipName.TextColor3 = Color3.fromRGB(245, 245, 255)
    tipName.Text = ""
    tipName.ZIndex = 41
    tipName.Parent = tip
    local tipType = Instance.new("TextLabel")
    tipType.LayoutOrder = 2
    tipType.BackgroundTransparency = 1
    tipType.Size = UDim2.new(1, 0, 0, 13)
    tipType.Font = Enum.Font.GothamMedium
    tipType.TextSize = 11
    tipType.TextXAlignment = Enum.TextXAlignment.Left
    tipType.TextColor3 = Color3.fromRGB(150, 156, 175)
    tipType.Text = ""
    tipType.ZIndex = 41
    tipType.Parent = tip
    local tipDesc = Instance.new("TextLabel")
    tipDesc.LayoutOrder = 3
    tipDesc.BackgroundTransparency = 1
    tipDesc.Size = UDim2.new(1, 0, 0, 0)
    tipDesc.AutomaticSize = Enum.AutomaticSize.Y
    tipDesc.Font = Enum.Font.Gotham
    tipDesc.TextSize = 12
    tipDesc.TextWrapped = true
    tipDesc.TextXAlignment = Enum.TextXAlignment.Left
    tipDesc.TextYAlignment = Enum.TextYAlignment.Top
    tipDesc.TextColor3 = Color3.fromRGB(205, 210, 225)
    tipDesc.Text = ""
    tipDesc.ZIndex = 41
    tipDesc.Parent = tip

    local hoverToken = 0 -- bumped on enter/leave so a stale delayed show is ignored
    local function showTip(card)
        local bind = card and card.bindObj
        if not (bind and bind.type == "power") then
            return -- only powers have descriptions; empty/tactical/roster slots show nothing
        end
        local id = tostring(bind.target)
        local def = POWERS.powers and POWERS.powers[id]
        tipName.Text = (def and def.display_name) or (id:gsub("_", " "))
        local badge = PetBadge.forPower(id)
        tipName.TextColor3 = (badge and POWER_ICONS.elementColor3(badge.element, "bright"))
            or Color3.fromRGB(245, 245, 255)
        -- Description from the DERIVED SSOT (PowerDescribe) — the exact source the powers menu
        -- uses, so the hotbar can never disagree or fall to "(no description)" for a newer power.
        -- POWER_DESC is kept only for an optional `type` override on the type line.
        local entry = POWER_DESC[id]
        local typeOverride = (type(entry) == "table") and entry.type or nil
        local descText
        local d = PowerDescribe.describe(POWERS, id)
        if d then
            descText = d.summary
            if d.lines and #d.lines > 0 then
                descText = descText .. "\n" .. table.concat(d.lines, "  ·  ")
            end
        end
        tipType.Text = typeOverride or deriveType(id)
        tipType.Visible = tipType.Text ~= ""
        tipDesc.Text = descText or "(no description)"
        local ap = card.frame.AbsolutePosition
        tip.Position = UDim2.fromOffset(math.floor(ap.X), math.floor(ap.Y) - 6)
        tip.Visible = true
    end
    local function hideTip()
        tip.Visible = false
    end

    local function makeRow(yOffset, base)
        for i = 1, 10 do
            local slot = base + i
            local b = Instance.new("TextButton")
            b.Name = "Slot_" .. slot
            b.AnchorPoint = Vector2.new(0, 1)
            b.Position = UDim2.fromOffset(SLOT + PAD + (i - 1) * (SLOT + PAD), yOffset)
            b.Size = UDim2.fromOffset(SLOT, SLOT)
            b.AutoButtonColor = false
            b.Text = ""
            b.BackgroundColor3 = Color3.fromRGB(26, 28, 38)
            b.BackgroundTransparency = 0.15
            b.BorderSizePixel = 0
            b.Parent = root
            b.ClipsDescendants = true
            local c = Instance.new("UICorner")
            c.CornerRadius = UDim.new(1, 0) -- circular slot
            c.Parent = b

            local iconImg = Instance.new("ImageLabel")
            iconImg.Name = "Icon"
            iconImg.BackgroundTransparency = 1
            iconImg.Position = UDim2.fromScale(0.5, 0.5)
            iconImg.AnchorPoint = Vector2.new(0.5, 0.5)
            iconImg.ScaleType = Enum.ScaleType.Fit
            iconImg.Size = UDim2.fromScale(1, 1) -- zoom set per-icon in applyState (border crop)
            iconImg.Image = ""
            iconImg.ZIndex = 2
            iconImg.Parent = b

            -- Directional targeting ring framing the disc (powers only; hidden otherwise).
            local ringImg = Instance.new("ImageLabel")
            ringImg.Name = "Ring"
            ringImg.BackgroundTransparency = 1
            ringImg.Position = UDim2.fromScale(0.5, 0.5)
            ringImg.AnchorPoint = Vector2.new(0.5, 0.5)
            ringImg.ScaleType = Enum.ScaleType.Fit
            ringImg.Size = UDim2.fromScale(1, 1)
            ringImg.Image = ""
            ringImg.Visible = false
            ringImg.ZIndex = 3
            ringImg.Parent = b

            local key = Instance.new("TextLabel")
            key.Name = "Key"
            key.ZIndex = 3
            key.BackgroundTransparency = 1
            key.Position = UDim2.fromOffset(3, 1)
            key.Size = UDim2.fromOffset(SLOT - 6, 13)
            key.Font = Enum.Font.GothamBold
            key.TextSize = 11
            key.TextXAlignment = Enum.TextXAlignment.Left
            key.TextColor3 = Color3.fromRGB(150, 155, 170)
            key.Text = keyLabel(slot)
            key.Parent = b

            -- Auto-cast lock badge (top-right): shown when the slot is locked to auto-fire on cooldown.
            local lockBadge = Instance.new("TextLabel")
            lockBadge.Name = "Lock"
            lockBadge.ZIndex = 4
            lockBadge.AnchorPoint = Vector2.new(1, 0)
            lockBadge.BackgroundTransparency = 1
            lockBadge.Position = UDim2.new(1, -3, 0, 0)
            lockBadge.Size = UDim2.fromOffset(14, 14)
            lockBadge.Font = Enum.Font.GothamBold
            lockBadge.TextSize = 12
            lockBadge.TextColor3 = Color3.fromRGB(120, 235, 140) -- green = "running"
            lockBadge.TextStrokeTransparency = 0.3
            lockBadge.Text = "⟳"
            lockBadge.Visible = false
            lockBadge.Parent = b

            local lbl = Instance.new("TextLabel")
            lbl.Name = "Bind"
            lbl.BackgroundTransparency = 1
            lbl.Position = UDim2.fromOffset(2, 14)
            lbl.Size = UDim2.fromOffset(SLOT - 4, SLOT - 16)
            lbl.Font = Enum.Font.GothamMedium
            lbl.TextSize = 10
            lbl.TextWrapped = true
            lbl.TextColor3 = Color3.fromRGB(235, 235, 245)
            lbl.Text = ""
            lbl.Parent = b

            local cool = attachRadial(b)

            b.MouseButton1Click:Connect(function()
                -- A long-press just toggled the lock on this slot; swallow the tap so it doesn't
                -- also fire the power (mobile: a hold ends in a click event).
                if longPressConsumed[slot] then
                    longPressConsumed[slot] = nil
                    return
                end
                if editMode then
                    openPicker(slot)
                else
                    Signals.Hotbar_Activate:FireServer({ slot = slot })
                end
            end)
            -- AUTO-CAST LOCK toggle: a locked slot re-fires itself the moment its power is off
            -- cooldown (the Heartbeat loop below). Desktop: RIGHT-CLICK. Mobile: LONG-PRESS the slot.
            b.MouseButton2Click:Connect(function()
                toggleAutoLock(slot)
            end)
            -- Long-press (touch or held mouse): start a timer on press; if still held past LONG_PRESS
            -- without a release/leave bumping the token, toggle the lock and mark the tap consumed.
            local pressToken = 0
            local function startPress(input)
                if
                    input.UserInputType == Enum.UserInputType.Touch
                    or input.UserInputType == Enum.UserInputType.MouseButton1
                then
                    pressToken += 1
                    local mine = pressToken
                    task.delay(LONG_PRESS, function()
                        if pressToken == mine then -- still held
                            longPressConsumed[slot] = true
                            toggleAutoLock(slot)
                        end
                    end)
                end
            end
            local function endPress()
                pressToken += 1 -- cancel any pending long-press
            end
            b.InputBegan:Connect(startPress)
            b.InputEnded:Connect(endPress)
            -- Delayed hover tooltip: show after HOVER_DELAY of hovering; cancel/hide on leave.
            b.MouseEnter:Connect(function()
                hoverToken += 1
                local mine = hoverToken
                task.delay(HOVER_DELAY, function()
                    if hoverToken == mine then
                        showTip(cards[slot])
                    end
                end)
            end)
            b.MouseLeave:Connect(function()
                hoverToken += 1 -- invalidate any pending show
                hideTip()
                endPress() -- cursor left the slot: cancel a pending long-press
            end)
            cards[slot] = {
                frame = b,
                bind = lbl,
                cool = cool,
                bindObj = nil,
                icon = iconImg,
                ring = ringImg,
                lock = lockBadge, -- the auto-cast "⟳" badge; toggleAutoLock toggles its .Visible
            }
        end
    end
    makeRow(SLOT, 10) -- TOP row (upper): slots 11-20 = Shift+1-0
    makeRow(SLOT * 2 + PAD, 0) -- BOTTOM row (primary, nearest hand): slots 1-10 = 1-0

    -- Render bindings pushed from the server.
    local stateApplied = false -- true once a non-empty hotbar has landed (stops join-retry)
    local lastHotbarState -- kept so a PotionUpdate can re-render bound potion slots (fresh glyph/count)
    local function applyState(state)
        if type(state) ~= "table" or type(state.hotbar) ~= "table" then
            return
        end
        lastHotbarState = state
        if next(state.hotbar) ~= nil then
            stateApplied = true
        end
        if type(state.available) == "table" then
            available = state.available
        end
        for slot = 1, 20 do
            local card = cards[slot]
            if card then
                local bind = state.hotbar[tostring(slot)] or state.hotbar[slot]
                card.bindObj = bind
                -- An emptied/rebound slot drops its auto-cast lock so the badge can't linger.
                if not bind and locked[slot] then
                    locked[slot] = nil
                end
                if card.lock then
                    card.lock.Visible = locked[slot] == true
                end
                if bind and bind.type == "potion" then
                    -- Potion slot: the SAME unified badge a power uses — element disc + a directional
                    -- targeting ring (who the buff hits: team-AoE for all-pet buffs, aura for self/luck,
                    -- single for the enemy throw), resolved via PetBadge.forPower("potion_<meter>"). Plus
                    -- a "×count" badge (potions are countable). Its draining buff duration rides the radial
                    -- edge-clock (Heartbeat below). No emoji one-off when the disc art resolves.
                    local p = potionByPotion[bind.target]
                    local meterId = p and p.meter
                    local badge = meterId and PetBadge.forPower("potion_" .. meterId) or nil
                    local discImg = badge and POWER_ICONS.discFor(badge.element, badge.symbol)
                        or nil
                    ensurePotionChrome(card)
                    if discImg then
                        card.icon.Image = discImg
                        card.icon.Size = UDim2.fromScale(0.82, 0.82) -- inset so the ring frames it
                        card.ring.Image = POWER_ICONS.rings[badge.ring] or POWER_ICONS.rings.aura
                        card.ring.ImageColor3 = POWER_ICONS.elementColor3(badge.element, "dark")
                        local off = POWER_ICONS.ringCentering(badge.ring)
                        card.ring.Position = UDim2.new(0.5 + (off.x or 0), 0, 0.5 + (off.y or 0), 0)
                        card.ring.Size = UDim2.fromScale(off.scale or 1, off.scale or 1)
                        card.ring.Visible = true
                        card.potGlyph.Visible = false
                    else -- no disc art for this meter: fall back to the emoji glyph
                        card.icon.Image = ""
                        card.ring.Visible = false
                        card.potGlyph.Text = tostring((p and p.icon) or "🧪")
                        card.potGlyph.Visible = true
                    end
                    card.bind.Visible = false
                    card.potCount.Visible = true
                    card.potCount.Text = "×" .. tostring((p and p.count) or 0)
                    card.potMeter = meterId
                    -- art stands on a clear slot, exactly like a power; tinted only on the emoji fallback
                    card.frame.BackgroundColor3 = Color3.fromRGB(26, 28, 38)
                    card.frame.BackgroundTransparency = discImg and 1 or 0.05
                    continue
                end
                card.potMeter = nil
                if card.potGlyph then
                    card.potGlyph.Visible = false
                    card.potCount.Visible = false
                end
                -- Power slots render the universal badge: element disc + tinted directional ring
                -- (the ring's SHAPE = targeting). Falls back to the old flat icon, then to text.
                local badge = bind and bind.type == "power" and PetBadge.forPower(bind.target)
                    or nil
                local discImg = badge and POWER_ICONS.discFor(badge.element, badge.symbol) or nil
                -- Tactical commands can carry an authored disc (e.g. rally -> flag) — same disc art as
                -- powers, but NO targeting ring (a command isn't aimed).
                local tacBadge = not discImg
                        and bind
                        and bind.type == "tactical"
                        and TACTICAL_BADGE[bind.target]
                    or nil
                local tacDisc = tacBadge and POWER_ICONS.discFor(tacBadge.element, tacBadge.symbol)
                    or nil
                local hasArt = false
                if discImg then
                    card.icon.Image = discImg
                    card.icon.Size = UDim2.fromScale(0.82, 0.82) -- inset so the ring frames it
                    card.ring.Image = POWER_ICONS.rings[badge.ring] or POWER_ICONS.rings.aura
                    card.ring.ImageColor3 = POWER_ICONS.elementColor3(badge.element, "dark")
                    -- apply the per-shape ring centering (PNG canvases aren't all centred), same as
                    -- PetBadge.create — otherwise this hand-rolled ring ignores ring_centering.
                    local off = POWER_ICONS.ringCentering(badge.ring)
                    card.ring.Position = UDim2.new(0.5 + (off.x or 0), 0, 0.5 + (off.y or 0), 0)
                    card.ring.Size = UDim2.fromScale(off.scale or 1, off.scale or 1)
                    card.ring.Visible = true
                    card.bind.Visible = false
                    hasArt = true
                elseif tacDisc then
                    card.icon.Image = tacDisc
                    card.icon.Size = UDim2.fromScale(0.9, 0.9) -- no ring, so a touch larger
                    card.ring.Visible = false
                    card.bind.Visible = false
                    hasArt = true
                else
                    -- Fallback: old flat power icon (no ring), else the text label.
                    local icon = bind and bind.type == "power" and POWER_ICONS.powers[bind.target]
                        or nil
                    card.icon.Image = icon or ""
                    if icon then
                        local s = POWER_ICONS.scaleFor(icon) -- zoom past the art's transparent border
                        card.icon.Size = UDim2.fromScale(s, s)
                    end
                    card.ring.Visible = false
                    card.bind.Visible = not icon
                    hasArt = icon ~= nil
                end
                card.bind.Text = bindLabel(bind)
                card.frame.BackgroundColor3 = bind
                        and (TYPE_COLOR[bind.type] or Color3.fromRGB(26, 28, 38))
                    or Color3.fromRGB(26, 28, 38)
                -- With real art present, let it stand on a clear slot; keep the coloured
                -- placeholder for text-only / empty slots so they're still legible.
                card.frame.BackgroundTransparency = hasArt and 1 or (bind and 0.05 or 0.4)
            end
        end
    end
    Signals.Hotbar_State.OnClientEvent:Connect(applyState)
    Signals.Hotbar_RequestState:FireServer()

    -- Potions: seed the brew-meter state + subscribe to live pushes. On each push we re-apply the
    -- last hotbar state so a bound potion slot's glyph/colour refresh (counts already tick in the
    -- Heartbeat). The slot's draining duration is driven from these meters by the Heartbeat above.
    local function onPotionState(state)
        ingestPotionState(state)
        if lastHotbarState then
            applyState(lastHotbarState)
        end
    end
    -- Seed the potion state, RETRYING: at join GameAPICommand/PotionService may not be up yet, so a
    -- single pull can come back empty and a bound potion slot would show the emoji fallback until the
    -- first drink pushes PotionUpdate. Retry until owned potions land (or give up after a few tries).
    task.spawn(function()
        for _ = 1, 12 do
            local st = callBus("potion.state", {})
            if st then
                onPotionState(st)
                if st.potions and #st.potions > 0 then
                    break -- owned potions resolved -> bound slots can render the unified disc
                end
            end
            task.wait(1)
        end
    end)
    task.spawn(function()
        local remote = ReplicatedStorage:WaitForChild("PotionUpdate", 30)
        if remote then
            remote.OnClientEvent:Connect(onPotionState)
        end
    end)

    -- Power cooldowns -> the per-slot radial edge-clock. Stamp the local clock when the
    -- push arrives so the sweep is smooth (server untilTime is only 1s-granular).
    local powerCooldowns = {} -- powerId -> { startClock, cooldown }
    Signals.Power_Cooldown.OnClientEvent:Connect(function(p)
        if type(p) == "table" and p.power and (p.cooldown or 0) > 0 then
            powerCooldowns[p.power] = { startClock = os.clock(), cooldown = p.cooldown }
        end
    end)
    RunService.Heartbeat:Connect(function()
        local nowC = os.clock()
        for slot = 1, 20 do
            local card = cards[slot]
            if card and card.cool then
                local b = card.bindObj
                local cd = b and b.type == "power" and powerCooldowns[b.target]
                local ready = true
                if cd then
                    local since = nowC - cd.startClock
                    card.cool(since / cd.cooldown, cd.cooldown - since)
                    ready = since >= cd.cooldown
                elseif b and b.type == "potion" and card.potMeter then
                    -- A potion's draining buff rides the same radial: progress = 1-charge (full meter =
                    -- full overlay), countdown = charge×drain. Hides when the meter empties.
                    local charge = potionLiveCharge(card.potMeter)
                    local m = potionMeters[card.potMeter]
                    if charge > 0 and m then
                        card.cool(1 - charge, charge * (m.drain_seconds or 0))
                    else
                        card.cool(1)
                    end
                    local owned = 0
                    if card.potCount then -- keep the count live as you drink / as pushes land
                        local p = potionByPotion[b.target]
                        owned = (p and p.count) or 0
                        card.potCount.Text = "×" .. tostring(owned)
                    end
                    -- LOCK = auto-maintain: a locked potion auto-drinks when the meter drains below the
                    -- meter's maintain_at AND you still own one. Refills in chunks toward full; the
                    -- diminishing sip keeps it from pinning at 100%. nil maintain_at = no auto-drink.
                    local threshold = m and m.maintain_at
                    ready = threshold ~= nil and charge < threshold and owned > 0
                else
                    card.cool(1) -- ready / not a power -> hide the clock
                end
                -- AUTO-CAST: a locked, bound slot re-fires the instant it's off cooldown. The 0.5s
                -- guard bridges the gap between firing and the server's Power_Cooldown push (so we
                -- don't double-fire in the round-trip window); the server is authoritative either way.
                if locked[slot] and b and not editMode and ready then
                    if nowC - (lastAuto[slot] or 0) > 0.5 then
                        lastAuto[slot] = nowC
                        Signals.Hotbar_Activate:FireServer({ slot = slot })
                    end
                end
            end
        end
    end)
    -- Join race: the first request can beat the server's profile/hotbar load, leaving
    -- the bar blank. Keep re-requesting (backing off) until a non-empty state lands.
    task.spawn(function()
        for _ = 1, 10 do
            if stateApplied then
                break
            end
            task.wait(1)
            Signals.Hotbar_RequestState:FireServer()
        end
    end)

    -- Number-key activation: digit -> slot (bottom row), Shift+digit -> +10 (top row).
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then
            return
        end
        local base = DIGIT_SLOT[input.KeyCode]
        if base then
            local shift = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
                or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
            local slot = shift and (base + 10) or base
            Signals.Hotbar_Activate:FireServer({ slot = slot })
        end
    end)

    -- Farming-mode cycle: Off -> Near -> High -> Off, driven by the auto-target toggles.
    -- Near = "free" targeting on (auto_systems free_mode = nearest), High = "paid" on
    -- (highest_value); we flip whichever differs to reach the next state. The label tracks
    -- the server's authoritative status.
    local status = { free = false, paid = false }
    local function modeOf()
        if status.paid then
            return "High"
        elseif status.free then
            return "Near"
        end
        return "Off"
    end
    local function paintFarm()
        local m = modeOf()
        farmBtn.Text = "Farm\n" .. m
        farmBtn.BackgroundColor3 = FARM_COLOR[m]
    end
    Signals.AutoTarget_Status.OnClientEvent:Connect(function(s)
        status.free = s.free and true or false
        status.paid = s.paid and true or false
        paintFarm()
    end)
    paintFarm()

    farmBtn.MouseButton1Click:Connect(function()
        -- next desired state
        local m = modeOf()
        local wantFree, wantPaid
        if m == "Off" then
            wantFree, wantPaid = true, false -- -> Near
        elseif m == "Near" then
            wantFree, wantPaid = false, true -- -> High
        else
            wantFree, wantPaid = false, false -- -> Off
        end
        if status.free ~= wantFree then
            Signals.AutoTarget_ToggleFree:FireServer()
        end
        if status.paid ~= wantPaid then
            Signals.AutoTarget_TogglePaid:FireServer()
        end
    end)

    -- ===== Assignment: Edit toggle + per-slot picker =====
    local editBtn = Instance.new("TextButton")
    editBtn.Name = "Edit"
    editBtn.AnchorPoint = Vector2.new(0, 1)
    editBtn.Position = UDim2.fromOffset(3, SLOT) -- square, top-left, directly above the Farm square
    editBtn.Size = UDim2.fromOffset(SLOT - 6, SLOT - 6)
    editBtn.TextSize = 12
    editBtn.AutoButtonColor = false
    editBtn.Font = Enum.Font.GothamBold
    editBtn.TextSize = 11
    editBtn.TextColor3 = Color3.fromRGB(235, 235, 245)
    editBtn.Text = "Edit"
    editBtn.BackgroundColor3 = Color3.fromRGB(60, 63, 76)
    editBtn.BorderSizePixel = 0
    editBtn.Parent = root
    do
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 6)
        c.Parent = editBtn
    end

    -- Blue pill_frame ring around the Edit + Farm squares, so they read as power-bar buttons like the
    -- ringed slots (transparent center -> the button + label show through).
    local function ringButton(btn)
        local r = Instance.new("ImageLabel")
        r.Name = "Ring"
        r.BackgroundTransparency = 1
        r.AnchorPoint = Vector2.new(0.5, 0.5)
        r.Position = UDim2.fromScale(0.5, 0.5)
        r.Size = UDim2.fromScale(1.12, 1.12)
        bindPillFrame(r) -- Edit/Farm button rings: match the bar's area theme
        r.ScaleType = Enum.ScaleType.Fit
        r.ZIndex = 9
        r.Parent = btn
    end
    ringButton(editBtn)
    ringButton(farmBtn)

    local pickerFrame
    local function closePicker()
        if pickerFrame then
            pickerFrame:Destroy()
            pickerFrame = nil
        end
    end

    -- Build the assignment picker for a slot: powers (server palette), pet summons
    -- (the player's equipped squad), tacticals, and Clear. Selecting one rebinds.
    openPicker = function(slot)
        closePicker()
        -- The player clicked a slot — the "pick a slot" arrow has done its job; clear it so it doesn't
        -- linger through the picker + after binding (Jason: "once I click it why is there still an arrow").
        if editHint then
            editHint:Destroy()
            editHint = nil
        end
        local p = Instance.new("Frame")
        p.Name = "Picker"
        p.AnchorPoint = Vector2.new(0.5, 1)
        p.Position = UDim2.new(0.5, 0, 1, -(SLOT * 2 + PAD + 18))
        p.Size = UDim2.fromOffset(320, 280)
        p.BackgroundColor3 = Color3.fromRGB(18, 20, 28)
        p.BorderSizePixel = 0
        p.Parent = gui
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 8)
        c.Parent = p
        pickerFrame = p

        local title = Instance.new("TextLabel")
        title.BackgroundTransparency = 1
        title.Size = UDim2.new(1, -28, 0, 24)
        title.Position = UDim2.fromOffset(10, 4)
        title.Font = Enum.Font.GothamBold
        title.TextSize = 13
        title.TextXAlignment = Enum.TextXAlignment.Left
        title.TextColor3 = Color3.fromRGB(255, 215, 120)
        title.Text = "Assign slot " .. slot
        title.Parent = p

        -- THE standard close X (shared component; "✕" tofu-boxes in Gotham)
        CloseButton.attach(p, { onClick = closePicker })

        local listFrame = Instance.new("ScrollingFrame")
        listFrame.Position = UDim2.fromOffset(6, 30)
        listFrame.Size = UDim2.new(1, -12, 1, -36)
        listFrame.BackgroundTransparency = 1
        listFrame.BorderSizePixel = 0
        listFrame.ScrollBarThickness = 6
        listFrame.CanvasSize = UDim2.new()
        listFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
        listFrame.Parent = p
        local layout = Instance.new("UIListLayout")
        layout.Padding = UDim.new(0, 3)
        layout.Parent = listFrame

        local order = 0
        local function header(text)
            order += 1
            local h = Instance.new("TextLabel")
            h.Size = UDim2.new(1, 0, 0, 16)
            h.BackgroundTransparency = 1
            h.Font = Enum.Font.GothamBold
            h.TextSize = 11
            h.TextXAlignment = Enum.TextXAlignment.Left
            h.TextColor3 = Color3.fromRGB(150, 155, 170)
            h.Text = text
            h.LayoutOrder = order
            h.Parent = listFrame
        end
        local function entry(label, color, bind)
            order += 1
            local e = Instance.new("TextButton")
            e.Size = UDim2.new(1, 0, 0, 24)
            e.AutoButtonColor = true
            e.Font = Enum.Font.GothamMedium
            e.TextSize = 12
            e.TextXAlignment = Enum.TextXAlignment.Left
            e.Text = "  " .. label
            e.TextColor3 = Color3.fromRGB(235, 235, 245)
            e.BackgroundColor3 = color
            e.BorderSizePixel = 0
            e.LayoutOrder = order
            e.Parent = listFrame
            local ec = Instance.new("UICorner")
            ec.CornerRadius = UDim.new(0, 4)
            ec.Parent = e
            e.MouseButton1Click:Connect(function()
                Signals.Hotbar_Rebind:FireServer({ slot = slot, bind = bind })
                closePicker()
            end)
            return e
        end

        header("Powers")
        -- A fresh player (no power bound yet) gets a blinking gold arrow + stroke on Resonance so it
        -- stands out among the tactical choices (Jason). Clears when the picker closes.
        local anyPowerBound = false
        if lastHotbarState and type(lastHotbarState.hotbar) == "table" then
            for _, b in pairs(lastHotbarState.hotbar) do
                if type(b) == "table" and b.type == "power" then
                    anyPowerBound = true
                    break
                end
            end
        end
        for _, id in ipairs(available.powers or {}) do
            local row = entry(
                (tostring(id):gsub("_", " ")),
                TYPE_COLOR.power,
                { type = "power", target = id }
            )
            if id == "resonance" and not anyPowerBound and row then
                local arrow = Instance.new("TextLabel")
                arrow.BackgroundTransparency = 1
                arrow.AnchorPoint = Vector2.new(1, 0.5)
                arrow.Position = UDim2.new(1, -6, 0.5, 0)
                arrow.Size = UDim2.fromOffset(22, 22)
                arrow.Font = Enum.Font.GothamBlack
                arrow.TextSize = 18
                arrow.Text = "⬅"
                arrow.TextColor3 = Color3.fromRGB(255, 220, 90)
                arrow.ZIndex = 5
                arrow.Parent = row
                local st = Instance.new("UIStroke")
                st.Color = Color3.fromRGB(255, 220, 90)
                st.Thickness = 2
                st.Parent = row
                task.spawn(function()
                    local t = 0
                    while row.Parent do
                        t += 0.05
                        local a = (math.sin(t * 5) + 1) / 2
                        arrow.TextTransparency = 0.05 + 0.5 * a
                        st.Transparency = 0.2 + 0.6 * a
                        task.wait(0.05)
                    end
                end)
            end
        end
        -- Pet summons are intentionally OMITTED from the bar picker — summoning pets moves to the Teams
        -- feature (Jason). The squad is managed in the inventory deploy flow, not bound per hotbar slot.
        header("Tactical")
        for _, cmd in ipairs(available.tacticals or {}) do
            entry(
                (tostring(cmd):gsub("_", " ")),
                TYPE_COLOR.tactical,
                { type = "tactical", target = cmd }
            )
        end
        -- Potions you OWN (drink on tap, like a power). Prefer the LIVE map (potionByPotion, refreshed
        -- on every grant / PotionUpdate) so a mid-session grant appears immediately; the boot palette
        -- (available.potions) is only a fallback (it goes stale between Hotbar_State pushes).
        local potionList, seenPotion = {}, {}
        for _, p in pairs(potionByPotion) do
            if p.id and (tonumber(p.count) or 0) > 0 then
                potionList[#potionList + 1] = p
                seenPotion[p.id] = true
            end
        end
        for _, p in ipairs(available.potions or {}) do
            if p.id and not seenPotion[p.id] and (tonumber(p.count) or 0) > 0 then
                potionList[#potionList + 1] = p
            end
        end
        table.sort(potionList, function(a, b)
            return tostring(a.id) < tostring(b.id)
        end)
        if #potionList > 0 then
            header("Potions")
            for _, pot in ipairs(potionList) do
                local label = tostring(pot.icon or "🧪")
                    .. " "
                    .. tostring(pot.name or pot.id)
                    .. " ×"
                    .. tostring(pot.count or 0)
                entry(label, TYPE_COLOR.potion, { type = "potion", target = pot.id })
            end
        end
        header("")
        entry("✖ Clear slot", Color3.fromRGB(70, 50, 50), nil)
    end

    -- EDIT MODE must SCREAM (Jason fell in the trap himself: forgot to press Done,
    -- "couldn't click a power" — the only tell was the tiny button text). While
    -- editing, the whole bar pill pulses orange and a banner floats above it.
    local editPulseThread
    local editBanner
    -- "Pick a slot" cue: while editing, a blinking arrow hovers over slot 1 so a first-timer knows the
    -- next move is to click a slot. Cleared when a slot is clicked (openPicker) or editing ends.
    local function setEditHint(on)
        if on then
            local slot1 = root:FindFirstChild("Slot_1")
            if not slot1 or editHint then
                return
            end
            editHint = Instance.new("TextLabel")
            editHint.Name = "EditSlotHint"
            editHint.BackgroundTransparency = 1
            editHint.AnchorPoint = Vector2.new(0.5, 1)
            editHint.Size = UDim2.fromOffset(56, 26)
            editHint.Font = Enum.Font.GothamBlack
            editHint.TextSize = 24
            editHint.TextColor3 = Color3.fromRGB(245, 205, 70)
            editHint.TextStrokeColor3 = Color3.new(0, 0, 0)
            editHint.TextStrokeTransparency = 0.3
            editHint.Text = "⬇"
            editHint.ZIndex = 13
            editHint.Parent = root
            local baseX = slot1.Position.X.Offset + slot1.Size.X.Offset / 2
            local baseY = slot1.Position.Y.Offset - slot1.Size.Y.Offset - 2
            task.spawn(function()
                local t = 0
                while editMode and editHint do
                    t += 0.05
                    local a = (math.sin(t * 5) + 1) / 2
                    editHint.TextTransparency = 0.05 + 0.5 * a
                    editHint.Position = UDim2.fromOffset(baseX, baseY - math.floor(5 * a))
                    task.wait(0.05)
                end
            end)
        elseif editHint then
            editHint:Destroy()
            editHint = nil
        end
    end
    local function setEditAttention(on)
        setEditHint(on)
        if on then
            if not editBanner then
                editBanner = Instance.new("TextLabel")
                editBanner.Name = "EditBanner"
                editBanner.AnchorPoint = Vector2.new(0.5, 1)
                editBanner.Position = UDim2.new(0.5, 0, 0, -8)
                editBanner.Size = UDim2.fromOffset(380, 26)
                editBanner.BackgroundColor3 = Color3.fromRGB(235, 170, 60)
                editBanner.TextColor3 = Color3.fromRGB(30, 24, 10)
                editBanner.Font = Enum.Font.GothamBlack
                editBanner.TextScaled = true
                editBanner.Text = "✎ EDITING HOTBAR — press Done to play"
                editBanner.ZIndex = 12
                local bc = Instance.new("UICorner")
                bc.CornerRadius = UDim.new(0, 8)
                bc.Parent = editBanner
                editBanner.Parent = barFrame
            end
            editBanner.Visible = true
            editPulseThread = task.spawn(function()
                -- the pill is a 9-slice ImageLabel: pulse its TINT (ImageColor3)
                local t = 0
                while editMode do
                    t += 0.05
                    local a = (math.sin(t * 4) + 1) / 2 -- 0..1 pulse
                    local pulseColor = Color3.fromRGB(235, 170, 60)
                        :Lerp(Color3.fromRGB(255, 90, 60), a)
                    barFrame.ImageColor3 = pulseColor
                    editBanner.BackgroundColor3 = pulseColor
                    task.wait(0.05)
                end
                -- the pill frames are PRE-COLORED images; restoring = clearing the
                -- tint (bindPillFrame only swaps Image — calling it left the last
                -- pulse color baked in, getting "more and more red" per session)
                barFrame.ImageColor3 = Color3.new(1, 1, 1)
            end)
        else
            if editBanner then
                editBanner.Visible = false
            end
            -- the pulse loop exits on editMode=false and restores the theme
        end
    end

    local function paintEdit()
        editBtn.Text = editMode and "Done" or "Edit"
        editBtn.BackgroundColor3 = editMode and Color3.fromRGB(235, 170, 60)
            or Color3.fromRGB(60, 63, 76)
        setEditAttention(editMode)
    end
    editBtn.MouseButton1Click:Connect(function()
        editMode = not editMode
        if not editMode then
            closePicker()
        end
        paintEdit()
    end)
end

return HotbarBar
