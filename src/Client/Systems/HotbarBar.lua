--[[
    HotbarBar — power/command bar (Feature 16 UI, slice B).

    Keeper: 20 slots as two rows of 10 (bottom 1-0, top Shift+1-0),
    lower-center. Plus a farming-mode cycle button (Off -> Near -> High).
    Size follows DisplayClass or Settings. Slots are fed by the server
    (Hotbar_State); pressing a slot's key OR clicking it fires
    Hotbar_Activate(slot).

    Keys: bottom row = 1..9,0 ; top row = Shift+1..9,0. (No Ctrl — the browser eats
    Ctrl+1-9.) The default Roblox Backpack is disabled so the number keys are free.
    The buttons are the cross-platform source of truth; keys are a desktop shortcut.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")

local Signals = require(ReplicatedStorage.Shared.Network.Signals)
local POWER_ICONS = require(ReplicatedStorage:WaitForChild("Configs"):WaitForChild("power_icons"))
local PILL = require(ReplicatedStorage.Configs:WaitForChild("pill_ui"))
local POWERS = require(ReplicatedStorage.Configs:WaitForChild("powers"))
local POWER_DESC = require(ReplicatedStorage.Configs:WaitForChild("power_descriptions"))
local POTIONS = require(ReplicatedStorage.Configs:WaitForChild("potions"))
local ITEMS = require(ReplicatedStorage.Configs:WaitForChild("items"))
local HOTBAR_CONFIG = require(ReplicatedStorage.Configs:WaitForChild("hotbar"))
-- Derived-description SSOT (the same source the powers menu uses). The hotbar tooltip used to read
-- the hardcoded POWER_DESC table, which only covered some powers — new ones (Taunt etc.) fell to
-- "(no description)" even though the menu showed a full one. PowerDescribe builds from the live
-- config so every power reads.
local PowerDescribe = require(ReplicatedStorage.Shared.Game.PowerDescribe)
local PotionDescribe = require(ReplicatedStorage.Shared.Game.PotionDescribe)
local BrewJuice = require(ReplicatedStorage.Shared.Game.BrewJuice)
local PetBadge = require(script.Parent.Parent.UI.PetBadge)
local UITheme = require(script.Parent.Parent.UI.UITheme)
local PanelChrome = require(script.Parent.Parent.UI.Components.PanelChrome)
local HotbarKeyboard = require(script.Parent.HotbarKeyboard)
local ConsoleHotbar = require(ReplicatedStorage.Shared.Game.ConsoleHotbar)
local InputGlyphs = require(ReplicatedStorage.Shared.Game.InputGlyphs)
local HotbarSize = require(ReplicatedStorage.Shared.Game.HotbarSize)

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
local TUTORIAL_HOTBAR_COVER_ATTRIBUTE = "MergeTutorialHotbarCovered"

local function tutorialCoversHotbar()
    return localPlayer:GetAttribute(TUTORIAL_HOTBAR_COVER_ATTRIBUTE) == true
end

local function activateHotbarSlot(slot)
    if tutorialCoversHotbar() then
        return
    end
    Signals.Hotbar_Activate:FireServer({ slot = slot })
end

local ITEM_BY_ID = {}
for _, item in ipairs(ITEMS) do
    ITEM_BY_ID[item.id] = item
end

local function tokenBadge(token)
    if type(token.badge) == "table" and token.badge.symbol then
        return {
            element = token.badge.element or "neutral",
            symbol = token.badge.symbol,
            ring = token.badge.ring or "aura",
        }
    end
    return PetBadge.forPower(token.icon_power or "world_travel")
end

local TYPE_COLOR = {
    power = Color3.fromRGB(150, 110, 235),
    tactical = Color3.fromRGB(230, 170, 60),
    roster = Color3.fromRGB(70, 170, 230),
    pet = Color3.fromRGB(90, 200, 120),
    potion = Color3.fromRGB(150, 80, 200), -- potion slot tint (overridden per-meter axis colour)
    token = Color3.fromRGB(90, 175, 255),
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
    disarm = "Disarm",
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

-- One description path powers both normal hotbar-slot tooltips and assignment-row tooltips.
local function describeBind(bind)
    if bind == nil then
        return {
            name = "Clear this slot",
            typeText = "Hotbar action",
            description = "Remove the current binding and leave this slot empty.",
            color = Color3.fromRGB(225, 105, 110),
        }
    end
    local id = tostring(bind.target or "")
    if bind.type == "power" then
        local def = POWERS.powers and POWERS.powers[id]
        local badge = PetBadge.forPower(id)
        local authored = POWER_DESC[id]
        local d = PowerDescribe.describe(POWERS, id)
        local description = d and d.summary or "A power you can cast from the hotbar."
        if d and d.lines and #d.lines > 0 then
            description ..= "\n" .. table.concat(d.lines, "  ·  ")
        end
        return {
            name = (def and def.display_name) or (id:gsub("_", " ")),
            typeText = ((type(authored) == "table") and authored.type) or deriveType(id),
            description = description,
            badge = badge,
            color = (badge and POWER_ICONS.elementColor3(badge.element, "bright"))
                or TYPE_COLOR.power,
        }
    elseif bind.type == "potion" then
        local d = PotionDescribe.describe(POTIONS, id)
        if d then
            local description = d.summary
            if d.lines and #d.lines > 0 then
                description ..= "\n" .. table.concat(d.lines, "  ·  ")
            end
            local badge = PetBadge.forPower("potion_" .. tostring(d.meter))
            return {
                name = d.name,
                typeText = d.type,
                description = description,
                badge = badge,
                color = (badge and POWER_ICONS.elementColor3(badge.element, "bright"))
                    or TYPE_COLOR.potion,
            }
        end
    elseif bind.type == "token" then
        local token = ITEM_BY_ID[id] or {}
        local badge = tokenBadge(token)
        return {
            name = token.name or (id:gsub("_", " ")),
            typeText = token.type_label or "Boost token",
            description = token.description or "Use this token when you are ready.",
            badge = badge,
            color = (badge and POWER_ICONS.elementColor3(badge.element, "bright"))
                or TYPE_COLOR.token,
        }
    elseif bind.type == "tactical" then
        local d = (HOTBAR_CONFIG.tactical_details or {})[id] or {}
        local badge = TACTICAL_BADGE[id]
        return {
            name = d.display_name or (id:gsub("_", " ")),
            typeText = d.type or "Squad command",
            description = d.description or "Give this command to your active pet squad.",
            badge = badge,
            color = TYPE_COLOR.tactical,
        }
    elseif bind.type == "roster" then
        return {
            name = id:gsub("_", " "),
            typeText = "Team roster",
            description = "Deploy the pets saved in this roster.",
            color = TYPE_COLOR.roster,
        }
    end
    return {
        name = id:gsub("_", " "),
        typeText = tostring(bind.type or "Hotbar action"),
        description = "Assign this action to the selected hotbar slot.",
        color = TYPE_COLOR[bind.type] or Color3.fromRGB(185, 190, 205),
    }
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

    local assemblyConfig = assert(HOTBAR_CONFIG.size.assembly, "hotbar.size.assembly is required")
    local leftSpan = assert(tonumber(assemblyConfig.left_span), "assembly.left_span is required")
    local barSpan = assert(tonumber(assemblyConfig.bar_span), "assembly.bar_span is required")
    local rightSpan = assert(tonumber(assemblyConfig.right_span), "assembly.right_span is required")
    local assemblyHeight = assert(tonumber(assemblyConfig.height), "assembly.height is required")
    local designSpan =
        assert(tonumber(HOTBAR_CONFIG.size.design_span), "size.design_span is required")
    assert(
        leftSpan + barSpan + rightSpan == designSpan,
        "hotbar assembly spans must equal design_span"
    )
    assert(barSpan == rowWidth + SLOT + PAD, "assembly.bar_span must fit the authored slots")
    assert(assemblyHeight == SLOT * 2 + PAD, "assembly.height must fit the authored rows")

    -- The complete lower-HUD cluster has one responsive owner. Pets/Menu, the white pill, and
    -- Powers/Board are children of this frame and therefore can never acquire different scaling.
    local greaterHotbar = Instance.new("Frame")
    greaterHotbar.Name = "GreaterHotbarFrame"
    greaterHotbar.AnchorPoint = Vector2.new(0.5, 1)
    greaterHotbar.Position = UDim2.new(0.5, 0, 1, -20)
    greaterHotbar.Size = UDim2.fromOffset(designSpan, assemblyHeight)
    greaterHotbar.BackgroundTransparency = 1
    greaterHotbar.BorderSizePixel = 0
    greaterHotbar.ClipsDescendants = false
    greaterHotbar.Parent = gui

    -- Pixel-designed internal chrome is legal inside this responsively anchored canvas. One
    -- UIViewportScale on the outer frame uniformly scales every child as a single assembly.
    local UIViewportScale = require(script.Parent.Parent.UI.UIViewportScale)
    UIViewportScale.attach(greaterHotbar)

    local leftControls = Instance.new("Frame")
    leftControls.Name = "LeftControls"
    leftControls.Position = UDim2.fromScale(0, 0)
    leftControls.Size = UDim2.fromScale(leftSpan / designSpan, 1)
    leftControls.BackgroundTransparency = 1
    leftControls.BorderSizePixel = 0
    leftControls.ClipsDescendants = false
    leftControls.Parent = greaterHotbar

    -- Keep HotbarBar.Bar stable for systems that use it as the central slot anchor.
    local root = Instance.new("Frame")
    root.Name = "Bar"
    root.Position = UDim2.fromScale(leftSpan / designSpan, 0)
    root.Size = UDim2.fromScale(barSpan / designSpan, 1)
    root.BackgroundTransparency = 1
    root.BorderSizePixel = 0
    root.ClipsDescendants = false
    root.Parent = greaterHotbar

    local rightControls = Instance.new("Frame")
    rightControls.Name = "RightControls"
    rightControls.Position = UDim2.fromScale((leftSpan + barSpan) / designSpan, 0)
    rightControls.Size = UDim2.fromScale(rightSpan / designSpan, 1)
    rightControls.BackgroundTransparency = 1
    rightControls.BorderSizePixel = 0
    rightControls.ClipsDescendants = false
    rightControls.Parent = greaterHotbar

    -- Full-viewport presentation layer for transient feedback only. Interactive hotbar controls do
    -- not live here; they all inherit GreaterHotbarFrame's single scale.
    local responsiveDock = Instance.new("Frame")
    responsiveDock.Name = "ResponsiveDock"
    responsiveDock.Size = UDim2.fromScale(1, 1)
    responsiveDock.BackgroundTransparency = 1
    responsiveDock.BorderSizePixel = 0
    responsiveDock.Parent = gui

    -- Keep the central power slots in their own visibility layer so Merge can cover only the pill.
    -- HotbarFlank mounts every persistent flank in the outer frame; none disappear with this layer.
    local centralContent = Instance.new("Frame")
    centralContent.Name = "CentralContent"
    centralContent.Size = UDim2.fromScale(1, 1)
    centralContent.BackgroundTransparency = 1
    centralContent.BorderSizePixel = 0
    centralContent.Parent = root

    local function applyTutorialCoverage()
        centralContent.Visible = not tutorialCoversHotbar()
    end
    localPlayer
        :GetAttributeChangedSignal(TUTORIAL_HOTBAR_COVER_ATTRIBUTE)
        :Connect(applyTutorialCoverage)
    applyTutorialCoverage()

    local controllerLegend = Instance.new("TextLabel")
    controllerLegend.Name = "ControllerLegend"
    controllerLegend.AnchorPoint = Vector2.new(0.5, 1)
    controllerLegend.Position = UDim2.new(0.5, 0, 0, -20)
    controllerLegend.Size = UDim2.fromOffset(520, 24)
    controllerLegend.BackgroundColor3 = Color3.fromRGB(18, 20, 28)
    controllerLegend.BackgroundTransparency = 0.12
    controllerLegend.BorderSizePixel = 0
    controllerLegend.Font = Enum.Font.GothamBold
    controllerLegend.TextColor3 = Color3.fromRGB(245, 225, 120)
    controllerLegend.TextSize = 15
    controllerLegend.Text = InputGlyphs.hotbarLegend("gamepad")
    controllerLegend.Visible = localPlayer:GetAttribute("InputMode") == "gamepad"
    controllerLegend.Parent = centralContent
    local legendCorner = Instance.new("UICorner")
    legendCorner.CornerRadius = UDim.new(1, 0)
    legendCorner.Parent = controllerLegend
    localPlayer:GetAttributeChangedSignal("InputMode"):Connect(function()
        controllerLegend.Visible = localPlayer:GetAttribute("InputMode") == "gamepad"
    end)

    -- Compact mobile HUD docks the bar against the usable bottom edge. Classic keeps the breathing
    -- room of the established desktop layout. Position is attribute-driven so Studio edits can be
    -- compared in either mode without rebuilding the UI. layoutBar is assigned after slots exist
    -- so orientation can also restack the 2×10 grid (horizontal keeper vs vertical_left).
    local layoutBar
    local function applyHudLayout()
        if layoutBar then
            layoutBar()
        end
    end
    localPlayer:GetAttributeChangedSignal("HudLayoutResolved"):Connect(applyHudLayout)
    localPlayer:GetAttributeChangedSignal("DisplayClass"):Connect(applyHudLayout)

    -- Blue neon pill_frame wrapping the whole bar (9-slice so the wide bar keeps proper corners;
    -- transparent inside AND outside, so the game shows through and the slots sit on top).
    local barFrame = Instance.new("ImageLabel")
    barFrame.Name = "PillFrame"
    barFrame.BackgroundTransparency = 1
    barFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    barFrame.Position = UDim2.fromScale(0.5, 0.5)
    local pillOverhang = assert(assemblyConfig.pill_overhang, "assembly.pill_overhang is required")
    local pillOverhangWidth =
        assert(tonumber(pillOverhang.width), "assembly.pill_overhang.width is required")
    local pillOverhangHeight =
        assert(tonumber(pillOverhang.height), "assembly.pill_overhang.height is required")
    barFrame.Size = UDim2.new(1, pillOverhangWidth, 1, pillOverhangHeight)
    bindPillFrame(barFrame) -- themed to the player's origin/area (was hardcoded sapphire/blue)
    barFrame.ScaleType = Enum.ScaleType.Slice
    barFrame.SliceCenter = Rect.new(180, 180, 330, 330)
    barFrame.ZIndex = 0
    barFrame.Parent = centralContent

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
    farmBtn.Parent = centralContent
    do
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 6)
        c.Parent = farmBtn
    end

    -- Assignment (edit) state: the palette pushed by the server + a forward-declared
    -- picker opener so a slot click can open it while in edit mode.
    local available = { powers = {}, tacticals = {}, potions = {}, tokens = {} }
    local editMode = false
    local openPicker
    local closePicker
    local paintEdit
    local editHint -- the "pick a slot" arrow over slot 1; dismissed once a slot is clicked (openPicker)

    -- ===== Potions: live brew-meter state for any slot bound to a potion =====
    -- PotionService is the SSOT; it pushes PotionUpdate (charge + owned counts) and answers
    -- potion.state for the initial pull. We keep the charge interpolating between 1s pushes so a
    -- potion slot's draining radial-clock reads smoothly (reusing the power-cooldown edge clock).
    local potionMeters = {} -- meterId -> { charge, drain_seconds, color }
    local potionByPotion = {} -- potionId -> { meter, icon, count, name }
    local tokenById = {} -- tokenId -> { count, icon_power, name, description }
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

    -- Overcharge chrome: a halo that leaks past the disc, plus a second ring that
    -- pulses when charge is high. Parent is the slot; ClipsDescendants flips off
    -- so the "barely contained" leak can sit around the badge.
    local function ensureOverchargeChrome(card)
        if card.brewHalo then
            return
        end
        card.frame.ClipsDescendants = false
        local halo = Instance.new("Frame")
        halo.Name = "BrewHalo"
        halo.AnchorPoint = Vector2.new(0.5, 0.5)
        halo.Position = UDim2.fromScale(0.5, 0.5)
        halo.Size = UDim2.fromScale(1.18, 1.18)
        halo.BackgroundColor3 = Color3.fromRGB(255, 80, 50)
        halo.BackgroundTransparency = 1
        halo.ZIndex = 1
        halo.Visible = false
        halo.Parent = card.frame
        local hc = Instance.new("UICorner")
        hc.CornerRadius = UDim.new(1, 0)
        hc.Parent = halo
        local stroke = Instance.new("UIStroke")
        stroke.Name = "BrewContain"
        stroke.Thickness = 3
        stroke.Color = Color3.fromRGB(255, 140, 70)
        stroke.Transparency = 1
        stroke.Parent = halo
        local leak = Instance.new("Frame")
        leak.Name = "BrewLeak"
        leak.AnchorPoint = Vector2.new(0.5, 0.5)
        leak.Position = UDim2.fromScale(0.5, 0.5)
        leak.Size = UDim2.fromScale(1.42, 1.42)
        leak.BackgroundTransparency = 1
        leak.ZIndex = 1
        leak.Visible = false
        leak.Parent = card.frame
        local lc = Instance.new("UICorner")
        lc.CornerRadius = UDim.new(1, 0)
        lc.Parent = leak
        local leakStroke = Instance.new("UIStroke")
        leakStroke.Name = "BrewLeakStroke"
        leakStroke.Thickness = 2
        leakStroke.Color = Color3.fromRGB(255, 210, 90)
        leakStroke.Transparency = 1
        leakStroke.Parent = leak
        card.brewHalo = halo
        card.brewStroke = stroke
        card.brewLeak = leak
        card.brewLeakStroke = leakStroke
        card.ringRest = { x = 0.5, y = 0.5 }
    end

    local function meterColor3(meterId)
        local m = potionMeters[meterId]
        local rgb = m and m.color
        if type(rgb) == "table" then
            return Color3.fromRGB(rgb[1] or 220, rgb[2] or 70, rgb[3] or 70)
        end
        return Color3.fromRGB(220, 70, 70)
    end

    local function hideOvercharge(card)
        if card.brewHalo then
            card.brewHalo.Visible = false
            card.brewLeak.Visible = false
            card.brewStroke.Transparency = 1
            card.brewLeakStroke.Transparency = 1
        end
        if card.icon then
            card.icon.Position = UDim2.fromScale(0.5, 0.5)
        end
        if card.ring and card.ringRest then
            card.ring.Position = UDim2.fromScale(card.ringRest.x, card.ringRest.y)
        end
        card.lastBrewCharge = 0
        card.brewPunchUntil = 0
    end

    local function applyOvercharge(card, charge, nowC)
        local knobs = POTIONS.overcharge or {}
        local juice = BrewJuice.sample(charge, knobs)
        if charge > (card.lastBrewCharge or 0) + 0.04 then
            card.brewPunchUntil = nowC + (tonumber(knobs.punch_seconds) or 0.28)
        end
        card.lastBrewCharge = charge
        if juice.glow <= 0 and nowC >= (card.brewPunchUntil or 0) then
            hideOvercharge(card)
            return
        end
        ensureOverchargeChrome(card)
        local color = meterColor3(card.potMeter)
        local punchDur = tonumber(knobs.punch_seconds) or 0.28
        local punchLeft = (card.brewPunchUntil or 0) - nowC
        local punch = punchLeft > 0 and math.clamp(punchLeft / punchDur, 0, 1) or 0
        local shake = juice.shake * (tonumber(knobs.shake_px) or 3)
            + punch * (tonumber(knobs.punch_px) or 5)
        local ox = math.sin(nowC * 41) * shake
        local oy = math.cos(nowC * 53) * shake
        card.icon.Position = UDim2.new(0.5, ox, 0.5, oy)
        local rest = card.ringRest or { x = 0.5, y = 0.5 }
        card.ring.Position = UDim2.new(rest.x, ox, rest.y, oy)
        local pulse = 1 + juice.leak * 0.1 * (0.5 + 0.5 * math.sin(nowC * 10))
        card.brewHalo.Visible = true
        card.brewHalo.BackgroundColor3 = color
        card.brewHalo.BackgroundTransparency = 1 - (0.18 + juice.glow * 0.22 + juice.leak * 0.12)
        card.brewHalo.Size = UDim2.fromScale(
            (tonumber(knobs.halo_scale) or 1.22) * pulse,
            (tonumber(knobs.halo_scale) or 1.22) * pulse
        )
        card.brewStroke.Color = color:Lerp(Color3.fromRGB(255, 230, 140), juice.leak * 0.55)
        card.brewStroke.Transparency = 0.55 - juice.glow * 0.25 - juice.leak * 0.2
        card.brewStroke.Thickness = 2.5 + juice.leak * 2.5 + punch * 2
        card.brewLeak.Visible = juice.leak > 0 or punch > 0.4
        card.brewLeak.Size = UDim2.fromScale(
            (tonumber(knobs.leak_scale) or 1.48) * (1 + juice.leak * 0.08 * math.sin(nowC * 7)),
            (tonumber(knobs.leak_scale) or 1.48) * (1 + juice.leak * 0.08 * math.cos(nowC * 7))
        )
        card.brewLeakStroke.Color = Color3.fromRGB(255, 210, 90)
        card.brewLeakStroke.Transparency = 0.78 - juice.leak * 0.35 - punch * 0.2
        card.brewLeakStroke.Thickness = 1.5 + juice.leak * 2
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
    local selectedSlot = nil
    local currentHotbar = {}
    local paintControllerSelection
    local locked = {} -- slot -> true when AUTO-CAST locked; re-fires on cooldown
    local lastAuto = {} -- slot -> os.clock() of the last auto-fire (bridges the fire->cooldown round-trip)
    local longPressConsumed = {} -- slot -> true: a long-press just toggled, so suppress the tap's activate
    local LONG_PRESS = 0.45 -- seconds: hold a slot this long (touch or mouse) to toggle the lock

    -- Auto-cast lock is slot-based, not power-based. A Range loaned kit overwrites
    -- those slots, so a leftover lock would fire Hasten (or anything else) that the
    -- player never locked. Clear every lock on catalog enter and exit.
    local function paintAutoLock(card, on)
        if not card then
            return
        end
        if card.lock then
            card.lock.Visible = on == true
        end
        if card.lockRing then
            card.lockRing.Visible = on == true
        end
    end

    local function clearAutoLocks()
        table.clear(locked)
        table.clear(lastAuto)
        for _, card in pairs(cards) do
            paintAutoLock(card, false)
        end
    end

    local lastChallengePowers = localPlayer:GetAttribute("ChallengePowers")
    local function challengeOverlayActive()
        return localPlayer:GetAttribute("ChallengePowers") ~= nil
    end
    localPlayer:GetAttributeChangedSignal("ChallengePowers"):Connect(function()
        local now = localPlayer:GetAttribute("ChallengePowers")
        if now ~= lastChallengePowers then
            lastChallengePowers = now
            clearAutoLocks()
            if now ~= nil and editMode then
                editMode = false
                if closePicker then
                    closePicker()
                end
                if paintEdit then
                    paintEdit()
                end
            end
        end
    end)

    -- Toggle a slot's auto-cast lock. Same action on desktop (right-click) and mobile (long-press).
    local function toggleAutoLock(slot)
        if editMode then
            return
        end
        local card = cards[slot]
        if
            not (
                card
                and card.bindObj
                and (card.bindObj.type == "power" or card.bindObj.type == "potion")
            )
        then
            return
        end
        locked[slot] = not locked[slot] or nil
        paintAutoLock(card, locked[slot] == true)
    end

    -- Hover tooltip shared by power and potion slots. Both descriptions are derived from their live
    -- configs, so the hotbar never owns a second copy of player-facing effect text. Anchored
    -- bottom-left at the slot's top edge, so it pops up and to the right of the slot.
    local HOVER_DELAY = 0.6 -- seconds hovering before it appears (bump toward 3 if you want it slower)
    local tip = Instance.new("Frame")
    tip.Name = "HotbarTooltip"
    tip.AnchorPoint = Vector2.new(0, 1)
    tip.Size = UDim2.fromOffset(236, 10)
    tip.AutomaticSize = Enum.AutomaticSize.Y
    tip.BackgroundColor3 = Color3.fromRGB(18, 20, 28)
    tip.BackgroundTransparency = 0.05
    tip.BorderSizePixel = 0
    tip.Visible = false
    -- The same tooltip is also used by the edit picker, whose panel chrome starts at ZIndex 100.
    -- Keep it above both surfaces instead of maintaining a second picker-only description widget.
    tip.ZIndex = 140
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
    tipName.ZIndex = 141
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
    tipType.ZIndex = 141
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
    tipDesc.ZIndex = 141
    tipDesc.Parent = tip

    local hoverToken = 0 -- bumped on enter/leave so a stale delayed show is ignored
    local function showBindTip(bind, source, pickerPlacement)
        if bind == nil and not pickerPlacement then
            return
        end
        local detail = describeBind(bind)

        tipName.Text = detail.name
        tipName.TextColor3 = detail.color
        tipType.Text = detail.typeText or ""
        tipType.Visible = tipType.Text ~= ""
        tipDesc.Text = detail.description or "(no description)"
        local ap = source.AbsolutePosition
        if pickerPlacement then
            local sourceRight = ap.X + source.AbsoluteSize.X
            local tipWidth = tip.AbsoluteSize.X > 0 and tip.AbsoluteSize.X or 236
            local camera = workspace.CurrentCamera
            local screenWidth = camera and camera.ViewportSize.X or 1920
            local x = sourceRight + 8
            if x + tipWidth > screenWidth - 8 then
                x = math.max(8, ap.X - tipWidth - 8)
            end
            tip.AnchorPoint = Vector2.new(0, 0)
            tip.Position = UDim2.fromOffset(math.floor(x), math.floor(ap.Y))
        else
            tip.AnchorPoint = Vector2.new(0, 1)
            tip.Position = UDim2.fromOffset(math.floor(ap.X), math.floor(ap.Y) - 6)
        end
        tip.Visible = true
    end
    local function showTip(card)
        local bind = card and card.bindObj
        if bind and card.frame then
            showBindTip(bind, card.frame, false)
        end
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
            b.Parent = centralContent
            b.ClipsDescendants = true
            local c = Instance.new("UICorner")
            c.CornerRadius = UDim.new(1, 0) -- circular slot
            c.Parent = b
            local selection = Instance.new("UIStroke")
            selection.Name = "ControllerSelection"
            selection.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
            selection.Color = Color3.fromRGB(255, 220, 55)
            selection.Thickness = 4
            selection.Transparency = 1
            selection.Parent = b

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

            -- Auto-cast lock: a pulsing ring around the disc. The old 14px ⟳
            -- sat in the corner and vanished on purple power art.
            b.ClipsDescendants = false
            local lockLook = HOTBAR_CONFIG.auto_cast or {}
            local lockRgb = lockLook.color or { 90, 255, 150 }
            local lockGlow = lockLook.glow or { 200, 255, 220 }
            local lockScale = tonumber(lockLook.scale) or 1.14
            local lockRing = Instance.new("Frame")
            lockRing.Name = "AutoLock"
            lockRing.AnchorPoint = Vector2.new(0.5, 0.5)
            lockRing.Position = UDim2.fromScale(0.5, 0.5)
            lockRing.Size = UDim2.fromScale(lockScale, lockScale)
            lockRing.BackgroundTransparency = 1
            lockRing.ZIndex = 6
            lockRing.Visible = false
            lockRing.Parent = b
            local lockCorner = Instance.new("UICorner")
            lockCorner.CornerRadius = UDim.new(1, 0)
            lockCorner.Parent = lockRing
            local lockStroke = Instance.new("UIStroke")
            lockStroke.Name = "AutoLockStroke"
            lockStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
            lockStroke.Color = Color3.fromRGB(lockRgb[1], lockRgb[2], lockRgb[3])
            lockStroke.Thickness = tonumber(lockLook.thickness) or 3.5
            lockStroke.Transparency = 0.15
            lockStroke.Parent = lockRing
            local lockHalo = Instance.new("Frame")
            lockHalo.Name = "AutoLockHalo"
            lockHalo.AnchorPoint = Vector2.new(0.5, 0.5)
            lockHalo.Position = UDim2.fromScale(0.5, 0.5)
            lockHalo.Size = UDim2.fromScale(1.08, 1.08)
            lockHalo.BackgroundTransparency = 1
            lockHalo.ZIndex = 5
            lockHalo.Parent = lockRing
            local haloCorner = Instance.new("UICorner")
            haloCorner.CornerRadius = UDim.new(1, 0)
            haloCorner.Parent = lockHalo
            local lockHaloStroke = Instance.new("UIStroke")
            lockHaloStroke.Name = "AutoLockHaloStroke"
            lockHaloStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
            lockHaloStroke.Color = Color3.fromRGB(lockGlow[1], lockGlow[2], lockGlow[3])
            lockHaloStroke.Thickness = (tonumber(lockLook.thickness) or 3.5) + 3
            lockHaloStroke.Transparency = 0.55
            lockHaloStroke.Parent = lockHalo

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

            b.Activated:Connect(function()
                -- A long-press just toggled the lock on this slot; swallow the tap so it doesn't
                -- also fire the power (mobile: a hold ends in a click event).
                if longPressConsumed[slot] then
                    longPressConsumed[slot] = nil
                    return
                end
                if editMode then
                    openPicker(slot)
                else
                    activateHotbarSlot(slot)
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
                lock = lockRing, -- auto-cast glow ring; paintAutoLock toggles .Visible
                lockStroke = lockStroke,
                lockHalo = lockHaloStroke,
                selection = selection,
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
        currentHotbar = {}
        if next(state.hotbar) ~= nil then
            stateApplied = true
        end
        if type(state.available) == "table" then
            available = state.available
            tokenById = {}
            for _, token in ipairs(available.tokens or {}) do
                if token.id then
                    tokenById[token.id] = token
                end
            end
        end
        for slot = 1, 20 do
            local card = cards[slot]
            if card then
                local bind = state.hotbar[tostring(slot)] or state.hotbar[slot]
                local prev = card.bindObj
                currentHotbar[slot] = bind
                card.bindObj = bind
                -- Tutorial/UI guidance resolves a live binding by identity. Slot numbers are not
                -- stable: auto-binding correctly chooses around whatever the player already has.
                card.frame:SetAttribute("HotbarBindType", bind and tostring(bind.type) or nil)
                card.frame:SetAttribute("HotbarBindTarget", bind and tostring(bind.target) or nil)
                -- An emptied/rebound slot drops its auto-cast lock so the badge can't linger.
                -- Compare identity: a Range overlay can keep type=power while swapping the target.
                local sameBind = prev
                    and bind
                    and prev.type == bind.type
                    and prev.target == bind.target
                if locked[slot] and not sameBind then
                    locked[slot] = nil
                    lastAuto[slot] = nil
                end
                paintAutoLock(card, locked[slot] == true)
                if bind and bind.type == "token" then
                    local token = tokenById[bind.target] or ITEM_BY_ID[bind.target] or {}
                    local authored = ITEM_BY_ID[bind.target] or {}
                    if token.badge == nil then
                        token.badge = authored.badge
                    end
                    if token.icon_power == nil then
                        token.icon_power = authored.icon_power
                    end
                    local badge = tokenBadge(token)
                    local discImg = badge and POWER_ICONS.discFor(badge.element, badge.symbol)
                        or nil
                    ensurePotionChrome(card)
                    card.potMeter = nil
                    card.potGlyph.Visible = false
                    card.potCount.Visible = true
                    card.potCount.Text = "×" .. tostring(token.count or 0)
                    if discImg then
                        card.icon.Image = discImg
                        card.icon.Size = UDim2.fromScale(0.82, 0.82)
                        card.ring.Image = POWER_ICONS.rings[badge.ring] or POWER_ICONS.rings.aura
                        card.ring.ImageColor3 = POWER_ICONS.elementColor3(badge.element, "dark")
                        local off = POWER_ICONS.ringCentering(badge.ring)
                        card.ring.Position = UDim2.new(0.5 + (off.x or 0), 0, 0.5 + (off.y or 0), 0)
                        card.ring.Size = UDim2.fromScale(off.scale or 1, off.scale or 1)
                        card.ring.Visible = true
                        card.bind.Visible = false
                        card.frame.BackgroundTransparency = 1
                    else
                        card.icon.Image = ""
                        card.ring.Visible = false
                        card.bind.Visible = true
                        card.bind.Text = bindLabel(bind)
                        card.frame.BackgroundTransparency = 0.05
                    end
                    card.frame.BackgroundColor3 = Color3.fromRGB(26, 28, 38)
                    continue
                elseif bind and bind.type == "potion" then
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
                        card.ringRest = { x = 0.5 + (off.x or 0), y = 0.5 + (off.y or 0) }
                        card.ring.Position = UDim2.new(card.ringRest.x, 0, card.ringRest.y, 0)
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
                hideOvercharge(card)
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
        if localPlayer:GetAttribute("InputMode") == "gamepad" then
            if selectedSlot == nil or currentHotbar[selectedSlot] == nil then
                selectedSlot = ConsoleHotbar.step(currentHotbar, nil, 1, 20)
            end
            if paintControllerSelection then
                paintControllerSelection()
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
        local remote = Signals.PotionUpdate
        if remote then
            remote.OnClientEvent:Connect(onPotionState)
        end
    end)

    -- Power cooldowns -> the per-slot radial edge-clock. Stamp the local clock when the
    -- push arrives so the sweep is smooth (server untilTime is only 1s-granular).
    local powerCooldowns = {} -- powerId -> { startClock, cooldown }
    Signals.Power_Cooldown.OnClientEvent:Connect(function(p)
        if type(p) ~= "table" or not p.power then
            return
        end
        if (tonumber(p.cooldown) or 0) <= 0 or (tonumber(p.untilTime) or 0) <= os.time() then
            powerCooldowns[p.power] = nil
            return
        end
        powerCooldowns[p.power] = { startClock = os.clock(), cooldown = p.cooldown }
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
                    applyOvercharge(card, charge, nowC)
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
                    if card.brewHalo then
                        hideOvercharge(card)
                    end
                end
                -- AUTO-CAST: a locked, bound slot re-fires the instant it's off cooldown. The 0.5s
                -- guard bridges the gap between firing and the server's Power_Cooldown push (so we
                -- don't double-fire in the round-trip window); the server is authoritative either way.
                if locked[slot] and b and not editMode and ready then
                    if nowC - (lastAuto[slot] or 0) > 0.5 then
                        lastAuto[slot] = nowC
                        activateHotbarSlot(slot)
                    end
                end
                if card.lockRing and card.lockRing.Visible then
                    local hz = tonumber((HOTBAR_CONFIG.auto_cast or {}).pulse_hz) or 1.6
                    local pulse = 0.55 + 0.45 * (0.5 + 0.5 * math.sin(nowC * hz * math.pi * 2))
                    local thick = tonumber((HOTBAR_CONFIG.auto_cast or {}).thickness) or 3.5
                    if card.lockStroke then
                        card.lockStroke.Transparency = 0.08 + (1 - pulse) * 0.35
                        card.lockStroke.Thickness = thick + pulse * 1.4
                    end
                    if card.lockHalo then
                        card.lockHalo.Transparency = 0.4 + (1 - pulse) * 0.35
                        card.lockHalo.Thickness = thick + 2.5 + pulse * 2
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
        local shift = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
            or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
        local slot = HotbarKeyboard.resolve(
            input.KeyCode.Name,
            shift,
            gameProcessed,
            UserInputService:GetFocusedTextBox() ~= nil,
            GuiService.MenuIsOpen
        )
        if slot then
            activateHotbarSlot(slot)
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

    local function cycleFarm()
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
    end
    farmBtn.Activated:Connect(cycleFarm)

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
    editBtn.Parent = centralContent
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

    local function isVertical()
        return HotbarSize.orientation(HOTBAR_CONFIG.size) == "vertical_left"
    end

    layoutBar = function()
        local compact = localPlayer:GetAttribute("HudLayoutResolved") == "compact"
        local tenFoot = localPlayer:GetAttribute("DisplayClass") == "ten_foot"
        if isVertical() then
            greaterHotbar.AnchorPoint = Vector2.new(0, 0.5)
            greaterHotbar.Size = UDim2.fromOffset(
                SLOT * 2 + PAD + leftSpan + rightSpan,
                SLOT + PAD + 10 * SLOT + 9 * PAD
            )
            -- Far-left experiment: 10px inset, vertically centered. SafeInsets
            -- are not available as a scale relationship here.
            greaterHotbar.Position = UDim2.new(0, 10, 0.5, 0)
            leftControls.Position = UDim2.fromScale(0, 0)
            leftControls.Size = UDim2.new(0, leftSpan, 1, 0)
            root.Position = UDim2.new(0, leftSpan, 0, 0)
            root.Size = UDim2.new(0, SLOT * 2 + PAD, 1, 0)
            rightControls.Position = UDim2.new(0, leftSpan + SLOT * 2 + PAD, 0, 0)
            rightControls.Size = UDim2.new(0, rightSpan, 1, 0)
            barFrame.Size = UDim2.new(1, pillOverhangHeight, 1, pillOverhangWidth)
            editBtn.AnchorPoint = Vector2.new(0, 0)
            editBtn.Position = UDim2.fromOffset(3, 3)
            farmBtn.AnchorPoint = Vector2.new(0, 0)
            farmBtn.Position = UDim2.fromOffset(SLOT + PAD + 3, 3)
            for slot = 1, 10 do
                local yBottom = SLOT + PAD + slot * SLOT + (slot - 1) * PAD
                cards[slot].frame.Position = UDim2.fromOffset(SLOT + PAD, yBottom)
                cards[slot + 10].frame.Position = UDim2.fromOffset(0, yBottom)
            end
            controllerLegend.AnchorPoint = Vector2.new(0, 0.5)
            controllerLegend.Position = UDim2.new(1, 16, 0, SLOT / 2)
            return
        end
        greaterHotbar.AnchorPoint = Vector2.new(0.5, 1)
        greaterHotbar.Size = UDim2.fromOffset(designSpan, assemblyHeight)
        greaterHotbar.Position = UDim2.new(0.5, 0, 1, tenFoot and -48 or (compact and -16 or -20))
        leftControls.Position = UDim2.fromScale(0, 0)
        leftControls.Size = UDim2.fromScale(leftSpan / designSpan, 1)
        root.Position = UDim2.fromScale(leftSpan / designSpan, 0)
        root.Size = UDim2.fromScale(barSpan / designSpan, 1)
        rightControls.Position = UDim2.fromScale((leftSpan + barSpan) / designSpan, 0)
        rightControls.Size = UDim2.fromScale(rightSpan / designSpan, 1)
        barFrame.Size = UDim2.new(1, pillOverhangWidth, 1, pillOverhangHeight)
        editBtn.AnchorPoint = Vector2.new(0, 1)
        editBtn.Position = UDim2.fromOffset(3, SLOT)
        farmBtn.AnchorPoint = Vector2.new(0, 1)
        -- Nudged up so the Farm ring clears the pill's bottom border.
        farmBtn.Position = UDim2.fromOffset(3, SLOT * 2 + PAD - 7)
        for i = 1, 10 do
            local x = SLOT + PAD + (i - 1) * (SLOT + PAD)
            cards[i].frame.Position = UDim2.fromOffset(x, SLOT * 2 + PAD)
            cards[i + 10].frame.Position = UDim2.fromOffset(x, SLOT)
        end
        controllerLegend.AnchorPoint = Vector2.new(0.5, 1)
        controllerLegend.Position = UDim2.new(0.5, 0, 0, -20)
    end
    applyHudLayout()

    local function applyHotbarSize()
        local cam = workspace.CurrentCamera
        local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
        local resolved = HotbarSize.resolve(
            localPlayer:GetAttribute("HotbarSize"),
            localPlayer:GetAttribute("DisplayClass")
        )
        UIViewportScale.setMultiplier(
            greaterHotbar,
            HotbarSize.multiplier(resolved, vp.X, vp.Y, HOTBAR_CONFIG.size)
        )
    end
    applyHotbarSize()
    localPlayer:GetAttributeChangedSignal("HotbarSize"):Connect(applyHotbarSize)
    localPlayer:GetAttributeChangedSignal("DisplayClass"):Connect(applyHotbarSize)
    do
        local camConn
        local function watchCam(cam)
            if camConn then
                camConn:Disconnect()
                camConn = nil
            end
            if cam then
                camConn = cam:GetPropertyChangedSignal("ViewportSize"):Connect(applyHotbarSize)
            end
            applyHotbarSize()
        end
        watchCam(workspace.CurrentCamera)
        workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
            watchCam(workspace.CurrentCamera)
        end)
    end

    local pickerFrame
    closePicker = function()
        hoverToken += 1
        hideTip()
        if pickerFrame then
            pickerFrame:Destroy()
            pickerFrame = nil
        end
    end

    -- Compact assignment picker: click the exact row to bind it. Full details use the same delayed
    -- hover tooltip as the hotbar itself, eliminating the old select-row -> travel-to-Assign flow
    -- where merely crossing another row could silently change what the button would bind.
    openPicker = function(slot)
        closePicker()
        -- The player clicked a slot — the "pick a slot" arrow has done its job; clear it so it doesn't
        -- linger through the picker + after binding (Jason: "once I click it why is there still an arrow").
        if editHint then
            editHint:Destroy()
            editHint = nil
        end
        -- MOBILE HEIGHT CLAMP (Jason, tutorial 6 on a phone: "you can't actually set your
        -- power because the menu is blocked by the player menu on top"). The fixed 330px
        -- panel rode up under the top-center player bar + tutorial capsule on short
        -- viewports, hiding the POWERS section it exists to offer. Clamp the panel to the
        -- space between the hotbar and the top HUD zone — the relative scroll list below
        -- keeps every row reachable at any height.
        local TOP_SAFE = 130 -- player bar + tutorial capsule zone (screen px)
        local panelH
        local shell
        if isVertical() then
            -- Sit to the right of the left-edge bar. Height uses most of the
            -- viewport because the bar no longer occupies the bottom.
            local availH = gui.AbsoluteSize.Y - TOP_SAFE - 24
            panelH = math.clamp(math.floor(availH), 180, 400)
        else
            local bottomOffset = math.floor(root.AbsoluteSize.Y + 18)
            local availH = gui.AbsoluteSize.Y - bottomOffset - TOP_SAFE
            panelH = math.clamp(math.floor(availH), 180, 330)
        end
        shell = PanelChrome.build(gui, {
            name = "Picker",
            title = "Assign slot " .. slot,
            size = UDim2.fromOffset(300, panelH),
            onClose = closePicker,
        })
        local p = shell.frame
        if isVertical() then
            -- 16px past the scaled bar so the picker clears the pill overhang.
            local left = math.floor(root.AbsolutePosition.X + root.AbsoluteSize.X + 16)
            p.AnchorPoint = Vector2.new(0, 0.5)
            p.Position = UDim2.new(0, left, 0.5, 0)
        else
            local bottomOffset = math.floor(root.AbsoluteSize.Y + 18)
            p.AnchorPoint = Vector2.new(0.5, 1)
            p.Position = UDim2.new(0.5, 0, 1, -bottomOffset)
        end
        pickerFrame = p

        local listFrame = Instance.new("ScrollingFrame")
        listFrame.Name = "Choices"
        listFrame.Position = UDim2.fromOffset(15, 45)
        listFrame.Size = UDim2.new(1, -30, 1, -62)
        listFrame.BackgroundTransparency = 1
        listFrame.BorderSizePixel = 0
        listFrame.ScrollBarThickness = 6
        listFrame.CanvasSize = UDim2.new()
        listFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
        listFrame.ZIndex = 102
        listFrame.Parent = p
        local layout = Instance.new("UIListLayout")
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.Padding = UDim.new(0, 5)
        layout.Parent = listFrame

        local order = 0
        local currentBind = lastHotbarState
            and lastHotbarState.hotbar
            and (lastHotbarState.hotbar[tostring(slot)] or lastHotbarState.hotbar[slot])
        local function bindMatches(a, b)
            return type(a) == "table"
                and type(b) == "table"
                and a.type == b.type
                and a.target == b.target
        end

        local function header(text)
            order += 1
            local h = Instance.new("TextLabel")
            h.Size = UDim2.new(1, -8, 0, 21)
            h.BackgroundColor3 = shell.areaColor
            h.BackgroundTransparency = 0.18
            h.Font = Enum.Font.GothamBold
            h.TextSize = 11
            h.TextXAlignment = Enum.TextXAlignment.Left
            h.TextColor3 = Color3.fromRGB(255, 255, 255)
            h.Text = "  " .. text
            h.LayoutOrder = order
            h.ZIndex = 103
            h.Parent = listFrame
            local hc = Instance.new("UICorner")
            hc.CornerRadius = UDim.new(0, 7)
            hc.Parent = h
        end

        local function entry(bind, suffix)
            order += 1
            local detail = describeBind(bind)
            local e = Instance.new("TextButton")
            e.Name = bind and tostring(bind.target) or "Clear"
            e.Size = UDim2.new(1, -8, 0, 43)
            e.AutoButtonColor = false
            e.Text = ""
            e.BackgroundColor3 = Color3.fromRGB(42, 44, 55)
            e.BorderSizePixel = 0
            e.LayoutOrder = order
            e.ZIndex = 103
            e.Parent = listFrame
            local ec = Instance.new("UICorner")
            ec.CornerRadius = UDim.new(0, 9)
            ec.Parent = e
            local accent = Instance.new("Frame")
            accent.Size = UDim2.fromOffset(5, 29)
            accent.Position = UDim2.fromOffset(5, 7)
            accent.BackgroundColor3 = detail.color
            accent.BorderSizePixel = 0
            accent.ZIndex = 104
            accent.Parent = e
            local ac = Instance.new("UICorner")
            ac.CornerRadius = UDim.new(1, 0)
            ac.Parent = accent
            local name = Instance.new("TextLabel")
            name.Position = UDim2.fromOffset(17, 4)
            name.Size = UDim2.new(1, -24, 0, 18)
            name.BackgroundTransparency = 1
            name.Font = Enum.Font.GothamBold
            name.TextSize = 12
            name.TextXAlignment = Enum.TextXAlignment.Left
            name.TextColor3 = Color3.fromRGB(242, 243, 250)
            name.Text = detail.name .. (suffix or "")
            name.ZIndex = 104
            name.Parent = e
            local kind = Instance.new("TextLabel")
            kind.Position = UDim2.fromOffset(17, 22)
            kind.Size = UDim2.new(1, -24, 0, 15)
            kind.BackgroundTransparency = 1
            kind.Font = Enum.Font.Gotham
            kind.TextSize = 10
            kind.TextXAlignment = Enum.TextXAlignment.Left
            kind.TextColor3 = Color3.fromRGB(157, 164, 184)
            kind.Text = detail.typeText or ""
            kind.ZIndex = 104
            kind.Parent = e
            local selectionStroke = Instance.new("UIStroke")
            selectionStroke.Name = "SelectionStroke"
            selectionStroke.Color = detail.color
            selectionStroke.Thickness = 2
            selectionStroke.Transparency = bindMatches(currentBind, bind) and 0 or 0.75
            selectionStroke.Parent = e
            e.Activated:Connect(function()
                if challengeOverlayActive() then
                    closePicker()
                    return
                end
                Signals.Hotbar_Rebind:FireServer({ slot = slot, bind = bind })
                closePicker()
            end)
            e.MouseEnter:Connect(function()
                hoverToken += 1
                local mine = hoverToken
                task.delay(HOVER_DELAY, function()
                    if hoverToken == mine and e.Parent then
                        showBindTip(bind, e, true)
                    end
                end)
            end)
            e.MouseLeave:Connect(function()
                hoverToken += 1
                hideTip()
            end)
            return e
        end

        header("Powers")
        -- Point the picker arrow at the power the current lesson is teaching. Homeworld
        -- bind_power → Resonance; combat bind_heal → Heal. A fresh Homeworld player with
        -- nothing bound still gets Resonance. Combat training never defaults to Resonance.
        local anyPowerBound = false
        if lastHotbarState and type(lastHotbarState.hotbar) == "table" then
            for _, b in pairs(lastHotbarState.hotbar) do
                if type(b) == "table" and b.type == "power" then
                    anyPowerBound = true
                    break
                end
            end
        end
        local stepId = localPlayer:GetAttribute("TutorialStepId")
        local teachPower = if stepId == "bind_heal"
            then "heal"
            elseif stepId == "bind_power" then "resonance"
            else nil
        if
            not teachPower
            and not anyPowerBound
            and localPlayer:GetAttribute("InCombatTutorial") ~= true
        then
            teachPower = "resonance"
        end
        for _, id in ipairs(available.powers or {}) do
            local row = entry({ type = "power", target = id })
            if teachPower and id == teachPower and row then
                local arrow = Instance.new("TextLabel")
                arrow.Name = id == "resonance" and "TutorialResonanceArrow" or "TutorialBindArrow"
                arrow.BackgroundTransparency = 1
                arrow.AnchorPoint = Vector2.new(1, 0.5)
                arrow.Position = UDim2.fromScale(0.98, 0.5)
                arrow.Size = UDim2.fromOffset(38, 38)
                arrow.Font = Enum.Font.GothamBlack
                arrow.TextSize = 32
                arrow.Text = "⬅"
                arrow.TextColor3 = Color3.fromRGB(255, 220, 90)
                arrow.TextStrokeColor3 = Color3.new(0, 0, 0)
                arrow.TextStrokeTransparency = 0.25
                arrow.ZIndex = 106
                arrow.Parent = row
                local arrowScale = Instance.new("UIScale")
                arrowScale.Parent = arrow
                task.spawn(function()
                    local t = 0
                    while row.Parent do
                        t += 0.05
                        local a = (math.sin(t * 5) + 1) / 2
                        arrow.TextTransparency = 0.02 + 0.28 * a
                        arrowScale.Scale = 0.88 + 0.24 * a
                        task.wait(0.05)
                    end
                end)
            end
        end
        -- Pet summons are intentionally OMITTED from the bar picker — summoning pets moves to the Teams
        -- feature (Jason). The squad is managed in the inventory deploy flow, not bound per hotbar slot.
        header("Tactical")
        for _, cmd in ipairs(available.tacticals or {}) do
            entry({ type = "tactical", target = cmd })
        end
        -- Potions you OWN (drink on tap, like a power). Prefer the LIVE map (potionByPotion, refreshed
        -- on every grant / PotionUpdate) so a mid-session grant appears immediately; the boot palette
        -- (available.potions) is only a fallback (it goes stale between Hotbar_State pushes).
        local potionList, seenPotion = {}, {}
        for _, potion in pairs(potionByPotion) do
            if potion.id and (tonumber(potion.count) or 0) > 0 then
                potionList[#potionList + 1] = potion
                seenPotion[potion.id] = true
            end
        end
        for _, potion in ipairs(available.potions or {}) do
            if potion.id and not seenPotion[potion.id] and (tonumber(potion.count) or 0) > 0 then
                potionList[#potionList + 1] = potion
            end
        end
        table.sort(potionList, function(a, b)
            return tostring(a.id) < tostring(b.id)
        end)
        if #potionList > 0 then
            header("Potions")
            for _, pot in ipairs(potionList) do
                entry({ type = "potion", target = pot.id }, "  ×" .. tostring(pot.count or 0))
            end
        end
        local tokenList = {}
        for _, token in ipairs(available.tokens or {}) do
            if token.id and (tonumber(token.count) or 0) > 0 then
                tokenList[#tokenList + 1] = token
            end
        end
        table.sort(tokenList, function(a, b)
            return tostring(a.id) < tostring(b.id)
        end)
        if #tokenList > 0 then
            header("Tokens")
            for _, token in ipairs(tokenList) do
                entry({ type = "token", target = token.id }, "  ×" .. tostring(token.count or 0))
            end
        end
        header("Slot")
        entry(nil)
    end

    -- EDIT MODE must SCREAM (Jason fell in the trap himself: forgot to press Done,
    -- "couldn't click a power" — the only tell was the tiny button text). While
    -- editing, the whole bar pill pulses orange and a banner floats above it.
    local editBanner
    -- "Pick a slot" cue: while editing, a blinking arrow hovers over slot 1 so a first-timer knows the
    -- next move is to click a slot. Cleared when a slot is clicked (openPicker) or editing ends.
    local function setEditHint(on)
        if on then
            local slot1 = centralContent:FindFirstChild("Slot_1")
            if not slot1 or editHint then
                return
            end
            editHint = Instance.new("TextLabel")
            editHint.Name = "EditSlotHint"
            editHint.BackgroundTransparency = 1
            editHint.Size = UDim2.fromOffset(56, 26)
            editHint.Font = Enum.Font.GothamBlack
            editHint.TextSize = 24
            editHint.TextColor3 = Color3.fromRGB(245, 205, 70)
            editHint.TextStrokeColor3 = Color3.new(0, 0, 0)
            editHint.TextStrokeTransparency = 0.3
            editHint.ZIndex = 13
            editHint.Parent = centralContent
            local baseX
            local baseY
            if isVertical() then
                -- Slot 1 is the top of the right column; point left at it.
                editHint.AnchorPoint = Vector2.new(0, 0.5)
                editHint.Text = "⬅"
                baseX = slot1.Position.X.Offset + slot1.Size.X.Offset + 4
                baseY = slot1.Position.Y.Offset - slot1.Size.Y.Offset / 2
            else
                editHint.AnchorPoint = Vector2.new(0.5, 1)
                editHint.Text = "⬇"
                baseX = slot1.Position.X.Offset + slot1.Size.X.Offset / 2
                baseY = slot1.Position.Y.Offset - slot1.Size.Y.Offset - 2
            end
            task.spawn(function()
                local t = 0
                while editMode and editHint do
                    t += 0.05
                    local a = (math.sin(t * 5) + 1) / 2
                    editHint.TextTransparency = 0.05 + 0.5 * a
                    if isVertical() then
                        editHint.Position = UDim2.fromOffset(baseX + math.floor(5 * a), baseY)
                    else
                        editHint.Position = UDim2.fromOffset(baseX, baseY - math.floor(5 * a))
                    end
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
                if isVertical() then
                    editBanner.AnchorPoint = Vector2.new(0, 0)
                    -- 10px past the pill so the banner sits in the playfield.
                    editBanner.Position = UDim2.new(1, 10, 0, 8)
                    editBanner.Size = UDim2.fromOffset(200, 48)
                else
                    editBanner.AnchorPoint = Vector2.new(0.5, 1)
                    editBanner.Position = UDim2.new(0.5, 0, 0, -8)
                    editBanner.Size = UDim2.fromOffset(380, 26)
                end
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
            task.spawn(function()
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

    paintEdit = function()
        editBtn.Text = editMode and "Done" or "Edit"
        editBtn:SetAttribute("HotbarEditing", editMode)
        editBtn.BackgroundColor3 = editMode and Color3.fromRGB(235, 170, 60)
            or Color3.fromRGB(60, 63, 76)
        setEditAttention(editMode)
        Signals.Hotbar_EditMode:FireServer(editMode)
    end
    editBtn.Activated:Connect(function()
        if challengeOverlayActive() then
            editMode = false
            closePicker()
            paintEdit()
            return
        end
        editMode = not editMode
        if not editMode then
            closePicker()
        end
        paintEdit()
        if not editMode then
            local stepId = localPlayer:GetAttribute("TutorialStepId")
            if stepId == "bind_power" or stepId == "bind_heal" then
                Signals.TutorialHotbarDone:FireServer()
            end
        end
    end)

    paintControllerSelection = function()
        local gamepad = localPlayer:GetAttribute("InputMode") == "gamepad"
        for slot, card in pairs(cards) do
            if card.selection then
                card.selection.Transparency = gamepad and slot == selectedSlot and 0 or 1
            end
        end
    end

    local controller = {}
    function controller:StepSelection(direction)
        selectedSlot = ConsoleHotbar.step(currentHotbar, selectedSlot, direction, 20)
        paintControllerSelection()
    end
    function controller:ActivateSelection()
        if selectedSlot and currentHotbar[selectedSlot] then
            activateHotbarSlot(selectedSlot)
        end
    end
    function controller:ToggleSelectionAutocast()
        if selectedSlot then
            toggleAutoLock(selectedSlot)
        end
    end
    function controller:CycleFarm()
        cycleFarm()
    end
    localPlayer:GetAttributeChangedSignal("InputMode"):Connect(function()
        if localPlayer:GetAttribute("InputMode") == "gamepad" and selectedSlot == nil then
            selectedSlot = ConsoleHotbar.step(currentHotbar, nil, 1, 20)
        end
        paintControllerSelection()
    end)
    _G.HotbarController = controller
end

return HotbarBar
