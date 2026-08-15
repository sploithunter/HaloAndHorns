--[[
    PlayerPowerBadges — a small HUD row of the PLAYER's own active power buffs.

    The squad cards show buffs on the PETS; this shows the buffs the player cast on THEMSELF
    (Mountain's Strength, Prospector, Fortune, Swift, Hasten, XP Surge, …). Each is a player
    attribute `<Buff>` + `<Buff>Until` (an os.time stamp) + `<Buff>PowerId` (which power applied
    it). The badge is the universal two-layer disc resolved via PetBadge.forPower(powerId) — same
    art as the hotbar/cards — with a countdown that blinks in its last few seconds.

    Row sits top-centre, just under the player nameplate. Steady (refreshed) player buffs are rare,
    so these all show a countdown + near-expiry blink (timed-power behaviour, per Jason's rule).
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local POWER_ICONS = require(ReplicatedStorage.Configs:WaitForChild("power_icons"))
local CREATORS = require(ReplicatedStorage.Configs:WaitForChild("creators"))
local ENCHANTS_CONFIG = require(ReplicatedStorage.Configs:WaitForChild("enchants"))
local MONETIZATION = require(ReplicatedStorage.Configs:WaitForChild("monetization"))
local POTIONS = require(ReplicatedStorage.Configs:WaitForChild("potions"))
local POWERS = require(ReplicatedStorage.Configs:WaitForChild("powers"))
local EnchantRuntime = require(ReplicatedStorage.Shared.Game.EnchantRuntime)
local PotionDescribe = require(ReplicatedStorage.Shared.Game.PotionDescribe)
local PowerDescribe = require(ReplicatedStorage.Shared.Game.PowerDescribe)
local PetBadge = require(script.Parent.Parent.UI.PetBadge)
local Signals = require(ReplicatedStorage.Shared.Network.Signals)

local PlayerPowerBadges = {}
local localPlayer = Players.LocalPlayer

-- The player self-power buffs to surface, in display order. label = short tag under the icon.
local BUFFS = {
    { attr = "PetDamageBuff", label = "DMG" }, -- Mountain's Strength
    {
        attr = "TitanTeamDamageBuff",
        label = "TITAN",
        fixed = { element = "exclusive", symbol = "pet" },
        valueActive = true,
        timedValue = true,
    },
    {
        attr = "CoinProductBuff",
        label = "2X",
        fixed = { element = "exclusive", symbol = "coins_up" },
        valueActive = true,
        timedValue = true,
    },
    {
        attr = "XpProductBuff",
        label = "2X",
        fixed = { element = "exclusive", symbol = "xp_up" },
        valueActive = true,
        timedValue = true,
    },
    {
        attr = "FutureCall",
        label = "SELF",
        fixed = { element = "exclusive", symbol = "portal" },
    },
    { attr = "OverheatDamageBuff", label = "HEAT", toggleable = true }, -- Pyromancer Overheat
    { attr = "CritBuff", label = "CRIT" }, -- Critical Strike
    { attr = "CoinYieldPower", label = "CRYS" }, -- Prospector (coin_yield axis) — "Crystals" display
    { attr = "DropRateBuff", label = "DROP" }, -- Windfall (drop_rate axis — +loot-table chance)
    { attr = "LuckBuff", label = "LUCK" }, -- Fortune / Huge Fortune (purple clover)
    { attr = "LuckBuffPotion", label = "LUCK" }, -- Fortune potion (own source; adds to the power)
    -- bunny support aura: GREEN clover (earth disc + clover_lucky — composed from
    -- existing assets, Jason's spec). Fixed badge: no PowerId to resolve.
    {
        attr = "HatchLuckBuff",
        label = "LUCK",
        fixed = { element = "earth", symbol = "clover_lucky" },
        steady = true, -- continuously refreshed aura: solid badge, no countdown/blink
        petSource = true, -- a PET grants this (free, not a toggle) -> labelled "PET" not "ON"
    },
    {
        attr = "PetXpAura",
        label = "XP",
        fixed = { element = "exclusive", symbol = "xp_up" },
        steady = true,
        petSource = true,
    },
    {
        attr = "HugeLuckAura",
        label = "HUGE",
        fixed = { element = "exclusive", symbol = "clover_huge" },
        steady = true,
        petSource = true,
    },
    {
        attr = "DropRateAura",
        label = "DROP",
        fixed = { element = "exclusive", symbol = "gift_up" },
        steady = true,
        petSource = true,
    },
    -- LUCKY SERVER presence sources arbitrate server-side and never stack. Separate replicated
    -- attrs preserve truthful source styling even though EggService consumes one ServerLuckBuff.
    {
        attr = "CreatorServerLuckBuff",
        label = "2X",
        fixed = { element = "neutral", symbol = "clover_lucky" },
        steady = true,
        tint = (function()
            local c = CREATORS.server_luck and CREATORS.server_luck.display
            c = c and c.color or { 170, 90, 255 }
            return Color3.fromRGB(c[1], c[2], c[3])
        end)(),
    },
    {
        attr = "FounderServerLuckBuff",
        label = "1.5X",
        fixed = { element = "neutral", symbol = "clover_lucky" },
        steady = true,
        tint = (function()
            local ok, monetization = pcall(function()
                return require(
                    game:GetService("ReplicatedStorage").Configs:WaitForChild("monetization")
                )
            end)
            local c = ok
                    and monetization
                    and monetization.founders_choice
                    and monetization.founders_choice.legacy
                    and monetization.founders_choice.legacy.server_luck
                    and monetization.founders_choice.legacy.server_luck.display
                    and monetization.founders_choice.legacy.server_luck.display.color
                or { 255, 198, 55 }
            return Color3.fromRGB(c[1], c[2], c[3])
        end)(),
    },
    -- INNER LIGHT (Lumen Dove focus aura): +focus/s while the dove is deployed.
    -- Constant-on pet aura -> steady badge, "PET" source label (Jason: "if it's
    -- constant on, that badge should be in the player's HUD"). Purple exclusive
    -- disc + the LIGHTNING BOLT (focus_regen glyph — the focus bar IS the
    -- bolt; the droplet is the focus-cost-REDUCTION enhancement glyph). NEVER capacitor: capacitor is THE hold/mez art (the
    -- wrapped-up figure), it means control and nothing else.
    {
        attr = "FocusRegenAura",
        label = "FOCUS",
        fixed = { element = "exclusive", symbol = "focus_regen" },
        steady = true,
        petSource = true,
    },
    -- EMBER TEMPO (Ashwing recharge aura): cooldown shave while deployed.
    -- Purple exclusive disc + the history/clock glyph (recharge vocabulary).
    {
        attr = "RechargeAura",
        label = "RCH",
        fixed = { element = "exclusive", symbol = "history" },
        steady = true,
        petSource = true,
    },
    -- toggleable: always-on powers the player turns on/off (drain focus_upkeep). The badge persists
    -- while OWNED (greyed "OFF" when off / crashed) and clicking it toggles the power — the player's
    -- on/off control, no hotbar slot needed.
    { attr = "MoveSpeedBuff", label = "SPD", toggleable = true }, -- Swift
    { attr = "MoveSpeedBuffPotion", label = "SPD" }, -- Swift potion (own source; adds to the power)
    { attr = "RechargeBuff", label = "RCH" }, -- Hasten (TIMED self-buff now → countdown, not a toggle)
    { attr = "XpBuff", label = "XP", toggleable = true }, -- XP Surge
    { attr = "MagnetBuff", label = "MAG", toggleable = true }, -- Magnet (drop pull radius, #167)
}

-- Every enchant gets its own replicated effect channel and therefore its own correct badge. The
-- previous hardcoded three-entry subset omitted Tactics/Efficiency/Leadership/Secret Luck and
-- collapsed Home World, Coin Finder, and Crystal Finder into one misleading coin icon.
local enchantIds = {}
for effectId in pairs(ENCHANTS_CONFIG.effects or {}) do
    enchantIds[#enchantIds + 1] = effectId
end
table.sort(enchantIds)
for _, effectId in ipairs(enchantIds) do
    table.insert(BUFFS, {
        attr = EnchantRuntime.effectAttribute(effectId),
        enchantId = effectId,
        label = string.upper(effectId),
        fixed = {
            element = "neutral",
            symbol = (ENCHANTS_CONFIG.display.symbols or {})[effectId] or "star_sparkle",
        },
        steady = true,
        petSource = true,
    })
end

local BLINK_LEAD = 5 -- seconds: blink in the final stretch
local BLINK_PERIOD = 0.5
local PERMANENT_THRESHOLD = 86400 * 30 -- >30 days remaining = always-on (passive/toggle) -> "ON"
local TOUCH_HOLD_SECONDS = 0.45

local POTION_BY_METER = {}
for potionId, potion in pairs(POTIONS.potions or {}) do
    if potion.meter then
        POTION_BY_METER[potion.meter] = potionId
    end
end

local function percent(value)
    return math.floor((tonumber(value) or 0) * 100 + 0.5)
end

local function formatCountdown(remaining)
    local seconds = math.max(0, math.ceil(tonumber(remaining) or 0))
    if seconds >= 60 then
        return ("%d:%02d"):format(math.floor(seconds / 60), seconds % 60)
    end
    return tostring(seconds) .. "s"
end

local function joinLines(lines)
    if not lines or #lines == 0 then
        return ""
    end
    return table.concat(lines, "  ·  ")
end

local function configuredProduct(productId)
    for _, product in ipairs(MONETIZATION.products or {}) do
        if product.id == productId then
            return product
        end
    end
    return nil
end

-- One config-derived description path for every badge. Fixed status badges describe their actual
-- replicated mechanic; powers, potions, and enchants read the same definitions as their menus.
local function describeBadge(def)
    local attr = def.attr
    local powerId = localPlayer:GetAttribute(attr .. "PowerId")
        or localPlayer:GetAttribute(attr .. "Owned")

    if type(powerId) == "string" and powerId:sub(1, 7) == "potion_" then
        local potionId = POTION_BY_METER[powerId:sub(8)]
        local desc = potionId and PotionDescribe.describe(POTIONS, potionId)
        if desc then
            return desc.name, desc.type, desc.summary, joinLines(desc.lines)
        end
    elseif powerId and POWERS.powers and POWERS.powers[powerId] then
        local power = POWERS.powers[powerId]
        local desc = PowerDescribe.describe(POWERS, powerId)
        local details = desc and joinLines(desc.lines) or ""
        if def.toggleable then
            local isOn = (localPlayer:GetAttribute(attr .. "Until") or 0)
                > Workspace:GetServerTimeNow()
            details = (isOn and "Currently ON" or "Currently OFF")
                .. (details ~= "" and ("  ·  " .. details) or "")
                .. "  ·  Tap to toggle"
        end
        return power.display_name or power.name or powerId,
            power.subtitle or "Player Power",
            desc and desc.summary or "This power is active.",
            details
    end

    if def.enchantId then
        local effect = (ENCHANTS_CONFIG.effects or {})[def.enchantId] or {}
        local stacks = tonumber(localPlayer:GetAttribute(attr .. "Stacks")) or 1
        return effect.display_name or def.enchantId,
            "Pet Enchantment",
            effect.description or "A deployed pet is granting this enhancement.",
            ("%d contributing pet%s"):format(stacks, stacks == 1 and "" or "s")
    end

    local value = tonumber(localPlayer:GetAttribute(attr)) or 0
    local stacks = tonumber(localPlayer:GetAttribute(attr .. "Stacks")) or 1
    local fixed = {
        TitanTeamDamageBuff = function()
            local product = configuredProduct("titan_team") or {}
            return product.name or "Titan Team",
                "Paid Boost",
                product.description or "Your deployed pets grow and gain more power.",
                "Remaining game time is shown below the badge"
        end,
        CoinProductBuff = function()
            local product = configuredProduct("coin_hour") or {}
            return product.name or "2x Coins",
                "Paid Boost",
                product.description or "Doubles origin-crystal earnings.",
                "Remaining game time is shown below the badge"
        end,
        XpProductBuff = function()
            local product = configuredProduct("xp_hour") or {}
            return product.name or "2x XP",
                "Paid Boost",
                product.description or "Doubles XP from everything.",
                "Remaining game time is shown below the badge"
        end,
        FutureCall = function()
            return "Future Self",
                "Summon Token",
                "Your Future Self is fighting and farming beside your squad.",
                "Remaining game time is shown below the badge"
        end,
        HatchLuckBuff = function()
            return "Hatch Luck",
                "Pet Aura",
                ("Deployed support pets improve hatch luck by +%d%%."):format(
                    percent(math.max(0, value - 1))
                ),
                ("%d contributing pet%s"):format(stacks, stacks == 1 and "" or "s")
        end,
        PetXpAura = function()
            return "Pet XP",
                "Pet Aura",
                ("Deployed support pets increase pet XP by +%d%%."):format(
                    percent(math.max(0, value - 1))
                ),
                ("%d contributing pet%s"):format(stacks, stacks == 1 and "" or "s")
        end,
        HugeLuckAura = function()
            return "Huge Fortune",
                "Pet Aura",
                ("Deployed support pets improve HUGE hatch luck by +%d%%."):format(
                    percent(math.max(0, value - 1))
                ),
                ("%d contributing pet%s"):format(stacks, stacks == 1 and "" or "s")
        end,
        DropRateAura = function()
            return "Windfall",
                "Pet Aura",
                ("Deployed support pets increase loot drops by +%d%%."):format(
                    percent(math.max(0, value - 1))
                ),
                ("%d contributing pet%s"):format(stacks, stacks == 1 and "" or "s")
        end,
        CreatorServerLuckBuff = function()
            local mult = (CREATORS.server_luck or {}).mult or 2
            return "Creator Luck",
                "Server Aura",
                ("A creator is in this server. Hatch luck is now %gx for everyone else!"):format(
                    mult
                ),
                "Creator and Founder server luck do not stack"
        end,
        FounderServerLuckBuff = function()
            local legacy = (MONETIZATION.founders_choice or {}).legacy or {}
            local mult = (legacy.server_luck or {}).mult or 1.5
            return legacy.name or "Founder's Legacy",
                "Server Aura",
                ("A Founder's Legacy holder is here. Server hatch luck is %.1fx!"):format(mult),
                "Creator and Founder server luck do not stack"
        end,
        FocusRegenAura = function()
            return "Inner Light",
                "Pet Aura",
                ("Deployed support pets restore +%.2f Focus per second."):format(value),
                ("%d contributing pet%s"):format(stacks, stacks == 1 and "" or "s")
        end,
        RechargeAura = function()
            return "Ember Tempo",
                "Pet Aura",
                ("Deployed support pets reduce power cooldowns by %d%%."):format(percent(value)),
                ("%d contributing pet%s"):format(stacks, stacks == 1 and "" or "s")
        end,
    }
    if fixed[attr] then
        return fixed[attr]()
    end

    return def.label or attr, "Active Effect", "This effect is currently active.", ""
end

-- Clicking a toggleable badge flips its always-on power on/off (the player's HUD control). Reads live
-- state at click time: `<attr>Owned` carries the powerId; the buff being present = currently ON.
local function makeToggleClick(def)
    return function()
        local owned = localPlayer:GetAttribute(def.attr .. "Owned")
        if not owned then
            return
        end
        local on = (localPlayer:GetAttribute(def.attr .. "Until") or 0)
            > Workspace:GetServerTimeNow()
        Signals.Power_ToggleActive:FireServer({ powerId = owned, on = not on })
    end
end

local function makeBadge(parent, order, onClick, def, showTooltip, hideTooltip)
    local attr = def.attr
    local holder = Instance.new("Frame")
    -- Stable destination name for GameEvents' consumable-transfer animation. The animation can
    -- now visibly land on the exact timed effect it just activated instead of vaguely flying at
    -- the whole player bar.
    holder.Name = "PBadge_" .. tostring(attr or "Status")
    holder.Size = UDim2.fromOffset(38, 50)
    holder.BackgroundTransparency = 1
    holder.LayoutOrder = order
    holder.Parent = parent

    -- Every badge owns a full-size hit target: desktop hover describes it, while touch taps describe
    -- display-only statuses. Toggleable powers retain tap-to-toggle; holding one on touch describes
    -- it without accidentally changing its state.
    local hit = Instance.new("TextButton")
    hit.Name = onClick and "ToggleHit" or "TooltipHit"
    hit.BackgroundTransparency = 1
    hit.Text = ""
    hit.Size = UDim2.fromScale(1, 1)
    hit.ZIndex = 20
    hit.Parent = holder

    local touchBeganAt = nil
    hit.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            touchBeganAt = os.clock()
        end
    end)
    hit.MouseEnter:Connect(function()
        showTooltip(holder, def, false)
    end)
    hit.MouseLeave:Connect(function()
        hideTooltip(false)
    end)
    hit.Activated:Connect(function(input)
        local held = input
                and input.UserInputType == Enum.UserInputType.Touch
                and touchBeganAt
                and (os.clock() - touchBeganAt) >= TOUCH_HOLD_SECONDS
            or false
        touchBeganAt = nil
        if held or not onClick then
            showTooltip(holder, def, true)
        else
            hideTooltip(true)
            onClick()
        end
    end)

    local disc = Instance.new("ImageLabel")
    disc.Name = "Disc"
    disc.Size = UDim2.fromOffset(36, 36)
    -- pinned to the holder's RIGHT edge; stack discs fan LEFT from here (Jason: anchor
    -- at 1 on X, grow left — the pile must never crowd the avatar on its right)
    disc.Position = UDim2.fromScale(1, 0)
    disc.AnchorPoint = Vector2.new(1, 0)
    disc.BackgroundTransparency = 1
    disc.ScaleType = Enum.ScaleType.Fit
    disc.Parent = holder

    local timer = Instance.new("TextLabel")
    timer.Name = "Timer"
    timer.Size = UDim2.fromOffset(38, 12)
    timer.Position = UDim2.fromScale(1, 1)
    timer.AnchorPoint = Vector2.new(1, 1) -- under the front (right-pinned) disc
    timer.BackgroundTransparency = 1
    timer.Font = Enum.Font.GothamBold
    timer.TextScaled = true
    timer.TextColor3 = Color3.fromRGB(255, 255, 255)
    timer.TextStrokeTransparency = 0.4
    timer.Parent = holder

    return { holder = holder, disc = disc, timer = timer }
end

function PlayerPowerBadges.start()
    local gui = Instance.new("ScreenGui")
    gui.Name = "PlayerPowerBadges"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 26
    gui.Parent = localPlayer:WaitForChild("PlayerGui")

    local tooltip = Instance.new("Frame")
    tooltip.Name = "StatusTooltip"
    tooltip.Size = UDim2.fromOffset(320, 166)
    tooltip.BackgroundColor3 = Color3.fromRGB(24, 25, 32)
    tooltip.BorderSizePixel = 0
    tooltip.Visible = false
    tooltip.ZIndex = 100
    tooltip.Parent = gui

    local tooltipCorner = Instance.new("UICorner")
    tooltipCorner.CornerRadius = UDim.new(0, 10)
    tooltipCorner.Parent = tooltip
    local tooltipStroke = Instance.new("UIStroke")
    tooltipStroke.Color = Color3.fromRGB(85, 185, 255)
    tooltipStroke.Thickness = 2
    tooltipStroke.Parent = tooltip
    local tooltipPadding = Instance.new("UIPadding")
    tooltipPadding.PaddingTop = UDim.new(0, 10)
    tooltipPadding.PaddingBottom = UDim.new(0, 10)
    tooltipPadding.PaddingLeft = UDim.new(0, 12)
    tooltipPadding.PaddingRight = UDim.new(0, 12)
    tooltipPadding.Parent = tooltip

    local function tooltipLabel(name, height, font, color, size)
        local label = Instance.new("TextLabel")
        label.Name = name
        label.Size = UDim2.new(1, 0, 0, height)
        label.BackgroundTransparency = 1
        label.Font = font
        label.TextColor3 = color
        label.TextSize = size
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.TextYAlignment = Enum.TextYAlignment.Top
        label.TextWrapped = true
        label.ZIndex = 101
        label.Parent = tooltip
        return label
    end

    local tooltipLayout = Instance.new("UIListLayout")
    tooltipLayout.SortOrder = Enum.SortOrder.LayoutOrder
    tooltipLayout.Padding = UDim.new(0, 2)
    tooltipLayout.Parent = tooltip
    local tooltipTitle =
        tooltipLabel("Title", 25, Enum.Font.GothamBold, Color3.fromRGB(255, 255, 255), 20)
    tooltipTitle.LayoutOrder = 1
    local tooltipSource =
        tooltipLabel("Source", 18, Enum.Font.GothamBold, Color3.fromRGB(120, 200, 255), 13)
    tooltipSource.LayoutOrder = 2
    local tooltipDescription =
        tooltipLabel("Description", 72, Enum.Font.Gotham, Color3.fromRGB(225, 226, 235), 14)
    tooltipDescription.LayoutOrder = 3
    local tooltipDetails =
        tooltipLabel("Details", 25, Enum.Font.Gotham, Color3.fromRGB(165, 170, 185), 12)
    tooltipDetails.LayoutOrder = 4

    local tooltipAnchor = nil
    local function hideTooltip(force)
        if force or not UserInputService.TouchEnabled then
            tooltip.Visible = false
            tooltipAnchor = nil
        end
    end
    local function showTooltip(anchor, def, touch)
        if touch and tooltip.Visible and tooltipAnchor == anchor then
            tooltip.Visible = false
            tooltipAnchor = nil
            return
        end
        local title, source, description, details = describeBadge(def)
        tooltipTitle.Text = title
        tooltipSource.Text = source
        tooltipDescription.Text = description
        tooltipDetails.Text = details
        tooltipDetails.Visible = details ~= ""

        local viewport = Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize
            or Vector2.new(1280, 720)
        local anchorCenter = anchor.AbsolutePosition.X + anchor.AbsoluteSize.X * 0.5
        local x = math.clamp(anchorCenter - 160, 8, math.max(8, viewport.X - 328))
        local y = math.clamp(
            anchor.AbsolutePosition.Y + anchor.AbsoluteSize.Y + 8,
            8,
            math.max(8, viewport.Y - 174)
        )
        tooltip.Position = UDim2.fromOffset(x, y)
        tooltip.Visible = true
        tooltipAnchor = anchor
    end

    local row = Instance.new("Frame")
    row.Name = "Row"
    -- SINGLE ROW growing LEFTWARD from the player bar's left edge (Jason: players can carry
    -- a lot of buffs even at high levels, so one row stacking left scales best). Right edge
    -- pinned beside the capsule, vertically centred on it; new badges extend left.
    -- Parented INTO the capsule, so it inherits the bar's viewport scale and moves with it.
    row.AnchorPoint = Vector2.new(1, 0.5)
    row.Position = UDim2.new(0, -10, 0.5, 0)
    row.Size = UDim2.fromOffset(0, 50)
    row.AutomaticSize = Enum.AutomaticSize.X
    row.BackgroundTransparency = 1
    row.ZIndex = 8
    task.spawn(function()
        local pg = localPlayer:WaitForChild("PlayerGui")
        local bar = pg:WaitForChild("PlayerBar", 20)
        local cap = bar and bar:WaitForChild("Capsule", 10)
        if cap then
            row.Parent = cap
        else
            row.Parent = gui -- fallback: original floating placement
        end
    end)
    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Right -- stack from the bar outward (leftward)
    layout.VerticalAlignment = Enum.VerticalAlignment.Center
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 4)
    layout.Parent = row

    local badges = {} -- attr -> badge

    RunService.RenderStepped:Connect(function()
        local now = Workspace:GetServerTimeNow()
        for i, def in ipairs(BUFFS) do
            local untilT = localPlayer:GetAttribute(def.attr .. "Until") or 0
            local valueIsActive = def.valueActive
                and (tonumber(localPlayer:GetAttribute(def.attr)) or 0) > 0
            local active = untilT > now or (valueIsActive and def.timedValue ~= true)
            -- toggleable always-on powers keep a (greyed) badge while OWNED but off, so the player can
            -- click to turn them back on. `<attr>Owned` carries the powerId; it persists across on/off.
            local owned = def.toggleable and localPlayer:GetAttribute(def.attr .. "Owned") or nil
            local b = badges[def.attr]
            if active or owned then
                if not b then
                    b = makeBadge(
                        row,
                        i,
                        def.toggleable and makeToggleClick(def) or nil,
                        def,
                        showTooltip,
                        hideTooltip
                    )
                    badges[def.attr] = b
                end
                local disc
                if def.fixed then
                    disc = POWER_ICONS.discFor(def.fixed.element, def.fixed.symbol)
                else
                    local powerId = localPlayer:GetAttribute(def.attr .. "PowerId") or owned
                    local badge = powerId and PetBadge.forPower(powerId)
                    disc = badge and POWER_ICONS.discFor(badge.element, badge.symbol)
                end
                b.disc.Image = disc or ""
                if def.toggleable and not active then
                    -- OWNED but toggled OFF (or upkeep-crashed): grey out + "OFF"; click re-enables it.
                    if b.extra then -- drop any stack pile left over from when it was on
                        for n = 1, #b.extra do
                            if b.extra[n] then
                                b.extra[n]:Destroy()
                                b.extra[n] = nil
                            end
                        end
                    end
                    b.holder.Size = UDim2.fromOffset(38, 50)
                    b.disc.ImageColor3 = Color3.fromRGB(120, 120, 120)
                    b.disc.ImageTransparency = 0.4
                    b.timer.Text = "OFF"
                    b.timer.TextColor3 = Color3.fromRGB(165, 165, 165)
                else
                    b.disc.ImageColor3 = def.tint or Color3.fromRGB(255, 255, 255)
                    local remaining = math.max(0, untilT - now)
                    -- PASSIVE / TOGGLE buffs (Magnet/Swift/Hasten/XP) are always-on: their `Until` is a
                    -- far-future sentinel. Show "ON", not a ~73-year countdown.
                    local permanent = def.steady == true
                        or (localPlayer:GetAttribute(def.attr .. "Toggle") == true)
                        or remaining > PERMANENT_THRESHOLD
                    if permanent then
                        -- stacked sources render as a coin-stack PILE of discs (Jason: "the
                        -- stacking makes it more powerful... rather than just having numbers"),
                        -- matching the squad-card pile. Half-overlap; capped so it can't sprawl.
                        local stacks = math.min(
                            tonumber(localPlayer:GetAttribute(def.attr .. "Stacks")) or 1,
                            5
                        )
                        b.extra = b.extra or {}
                        for n = 1, stacks - 1 do
                            if not b.extra[n] then
                                local d = b.disc:Clone()
                                d.Name = "Stack" .. n
                                d.ZIndex = b.disc.ZIndex - n -- behind the front disc
                                d.Parent = b.holder
                                b.extra[n] = d
                            end
                            b.extra[n].Image = b.disc.Image
                            b.extra[n].Position = UDim2.new(1, -n * 18, 0, 0) -- fan LEFT, half-overlap
                            b.extra[n].ImageTransparency = 0
                        end
                        for n = stacks, #b.extra do -- prune dropped stacks
                            if b.extra[n] then
                                b.extra[n]:Destroy()
                                b.extra[n] = nil
                            end
                        end
                        b.holder.Size = UDim2.fromOffset(38 + (stacks - 1) * 18, 50)
                        if def.petSource then
                            -- a PET grants this for free (not a toggle the player owns/spends on)
                            b.timer.Text = "PET"
                            b.timer.TextColor3 = Color3.fromRGB(120, 200, 255)
                        else
                            b.timer.Text = "ON"
                            b.timer.TextColor3 = Color3.fromRGB(150, 230, 150)
                        end
                        b.disc.ImageTransparency = 0
                    else
                        b.timer.Text = formatCountdown(remaining)
                        -- near-expiry blink (timed powers)
                        local blink = remaining <= BLINK_LEAD
                        local hidden = blink and (os.clock() % BLINK_PERIOD) >= (BLINK_PERIOD * 0.5)
                        b.disc.ImageTransparency = hidden and 0.6 or 0
                        b.timer.TextColor3 = blink and Color3.fromRGB(255, 180, 120)
                            or Color3.fromRGB(255, 255, 255)
                    end
                end
            elseif b then
                b.holder:Destroy()
                badges[def.attr] = nil -- pile discs die with the holder
            end
        end
    end)
end

return PlayerPowerBadges
