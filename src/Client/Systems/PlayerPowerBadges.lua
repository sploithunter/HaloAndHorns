--[[
    PlayerPowerBadges — two compact HUD rows for active effects and permanent entitlements.

    The squad cards show buffs on the PETS; this shows the buffs the player cast on THEMSELF
    (Mountain's Strength, Prospector, Fortune, Swift, Hasten, XP Surge, …). Each is a player
    attribute `<Buff>` + `<Buff>Until` (an os.time stamp) + `<Buff>PowerId` (which power applied
    it). The badge is the universal two-layer disc resolved via PetBadge.forPower(powerId) — same
    art as the hotbar/cards — with a countdown that blinks in its last few seconds.

    Game-pass entitlements sit first (they cannot be toggled). Toggleable powers sit
    second. Keeper placement (`top_chrome`) hangs the two rows under the Roblox left
    chrome. `vertical_left` stands those rows up as columns on the far left edge
    inside a scale-height box; contents shrink to fit (Colorado Plays is the
    long list). Passes are icon-only. ON/OFF/PET/timer sit beside the discs.
    The column hides while EnemyHud has engaged foes (`EnemyHudActive`) when
    Settings "Hide Toggles in Battle" is on (the default).
]]

local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local UI_CONFIG = require(ReplicatedStorage:WaitForChild("Configs"):WaitForChild("ui"))

local POWER_ICONS = require(ReplicatedStorage.Configs:WaitForChild("power_icons"))
local CREATORS = require(ReplicatedStorage.Configs:WaitForChild("creators"))
local ENCHANTS_CONFIG = require(ReplicatedStorage.Configs:WaitForChild("enchants"))
local MONETIZATION = require(ReplicatedStorage.Configs:WaitForChild("monetization"))
local POTIONS = require(ReplicatedStorage.Configs:WaitForChild("potions"))
local POWERS = require(ReplicatedStorage.Configs:WaitForChild("powers"))
local EnchantRuntime = require(ReplicatedStorage.Shared.Game.EnchantRuntime)
local MonetizationCatalog = require(ReplicatedStorage.Shared.Game.MonetizationCatalog)
local PotionDescribe = require(ReplicatedStorage.Shared.Game.PotionDescribe)
local PowerDescribe = require(ReplicatedStorage.Shared.Game.PowerDescribe)
local PetBadge = require(script.Parent.Parent.UI.PetBadge)
local Signals = require(ReplicatedStorage.Shared.Network.Signals)

local PlayerPowerBadges = {}
local localPlayer = Players.LocalPlayer

-- The player self-power buffs to surface, in display order. label = short tag under the icon.
local BUFFS = {
    { attr = "PetDamageBuff", label = "DMG" }, -- Mountain's Strength
    { attr = "PetDamageBuffPotion", label = "DMG" }, -- Berserk Brew (own source; adds to the power)
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
    { attr = "CoinYieldPower", label = "CRYS", toggleable = true }, -- Prospector
    { attr = "DropRateBuff", label = "DROP", toggleable = true }, -- Windfall
    { attr = "LuckBuff", label = "LUCK", toggleable = true }, -- Luck (not Huge Fortune)
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
    if def.passConfig then
        local sources = def.passSources or {}
        local source = "Permanent Game Pass"
        if sources.marketplace == true then
            source = "Permanent Game Pass"
        elseif sources.founder == true then
            source = "Founder's Benefit"
        elseif sources.creator == true then
            source = "Creator Entitlement"
        elseif sources.test == true then
            source = "Studio Test Entitlement"
        end
        return def.passConfig.name or def.passId or "Game Pass",
            source,
            def.passConfig.description or "This permanent benefit is active.",
            "Owned  ·  Always active"
    end

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

local function badgeCfg()
    return (UI_CONFIG.hud and UI_CONFIG.hud.power_badges) or {}
end

local function isVerticalBadges()
    return badgeCfg().placement == "vertical_left"
end

local function powerDiscSize()
    if isVerticalBadges() then
        return tonumber(badgeCfg().disc) or 48
    end
    return 36
end

local function passDiscSize()
    if isVerticalBadges() then
        return tonumber(badgeCfg().pass_disc) or 40
    end
    return 28
end

local function labelWidth()
    return tonumber(badgeCfg().label_width) or 32
end

-- Size the disc + ON/OFF/PET/timer. Vertical-left puts the status beside the
-- disc (see-through, toward the playfield) so the disc can be a bigger tap.
local function applyPowerChrome(holder, disc, timer, stacks)
    stacks = math.max(1, tonumber(stacks) or 1)
    local d = powerDiscSize()
    disc.Size = UDim2.fromOffset(d, d)
    local hit = holder:FindFirstChild("ToggleHit") or holder:FindFirstChild("TooltipHit")
    if isVerticalBadges() then
        local overlap = math.floor(d * 0.5)
        local stackPad = (stacks - 1) * overlap
        local lw = labelWidth()
        local labelLeft = badgeCfg().label_side == "left"
        local labelX = labelLeft and 0 or (stackPad + d + 3)
        local discX = labelLeft and (lw + 3) or stackPad
        holder.Size = UDim2.fromOffset(stackPad + d + 4 + lw, d)
        disc.AnchorPoint = Vector2.new(0, 0)
        disc.Position = UDim2.fromOffset(discX, 0)
        timer.Size = UDim2.fromOffset(lw, 16)
        timer.AnchorPoint = Vector2.new(0, 0.5)
        -- Side status; scale cannot park this beside a fixed disc.
        timer.Position = UDim2.fromOffset(labelX, d * 0.5)
        timer.TextXAlignment = labelLeft and Enum.TextXAlignment.Right or Enum.TextXAlignment.Left
        timer.TextScaled = false
        timer.TextSize = 11
        timer.TextTransparency = 0.12
        timer.TextStrokeTransparency = 0.55
        if hit then
            hit.AnchorPoint = Vector2.new(0, 0)
            hit.Position = UDim2.fromOffset(discX, 0)
            hit.Size = UDim2.fromOffset(d, d)
        end
        return overlap, discX
    end
    holder.Size = UDim2.fromOffset(38 + (stacks - 1) * 18, 50)
    disc.AnchorPoint = Vector2.new(1, 0)
    disc.Position = UDim2.fromScale(1, 0)
    timer.Size = UDim2.fromOffset(38, 12)
    timer.AnchorPoint = Vector2.new(1, 1)
    timer.Position = UDim2.fromScale(1, 1)
    timer.TextXAlignment = Enum.TextXAlignment.Center
    timer.TextScaled = true
    timer.TextTransparency = 0
    timer.TextStrokeTransparency = 0.4
    if hit then
        hit.AnchorPoint = Vector2.new(0, 0)
        hit.Position = UDim2.fromScale(0, 0)
        hit.Size = UDim2.fromScale(1, 1)
    end
    return 18, (stacks - 1) * 18
end

local function makeBadge(parent, order, onClick, def, showTooltip, hideTooltip)
    local attr = def.attr
    local holder = Instance.new("Frame")
    -- Stable destination name for GameEvents' consumable-transfer animation. The animation can
    -- now visibly land on the exact timed effect it just activated instead of vaguely flying at
    -- the whole player bar.
    holder.Name = "PBadge_" .. tostring(attr or "Status")
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
    disc.BackgroundTransparency = 1
    disc.ScaleType = Enum.ScaleType.Fit
    disc.Parent = holder

    local timer = Instance.new("TextLabel")
    timer.Name = "Timer"
    timer.BackgroundTransparency = 1
    timer.Font = Enum.Font.GothamBold
    timer.TextColor3 = Color3.fromRGB(255, 255, 255)
    timer.Parent = holder

    applyPowerChrome(holder, disc, timer, 1)
    return { holder = holder, disc = disc, timer = timer }
end

-- Permanent entitlements stay quieter than live effects: same Marketplace
-- artwork, slightly subdued. No infinity marker — passes are always on.
local function makePassBadge(parent, order, def, showTooltip, hideTooltip)
    local d = passDiscSize()
    local holder = Instance.new("Frame")
    holder.Name = "PassBadge_" .. tostring(def.passId or "Unknown")
    holder.Size = UDim2.fromOffset(d, d)
    holder.BackgroundTransparency = 1
    holder.LayoutOrder = order
    holder.Parent = parent

    local hit = Instance.new("TextButton")
    hit.Name = "TooltipHit"
    hit.BackgroundTransparency = 1
    hit.Text = ""
    hit.Size = UDim2.fromScale(1, 1)
    hit.ZIndex = 20
    hit.Parent = holder
    hit.MouseEnter:Connect(function()
        showTooltip(holder, def, false)
    end)
    hit.MouseLeave:Connect(function()
        hideTooltip(false)
    end)
    hit.Activated:Connect(function()
        showTooltip(holder, def, true)
    end)

    local icon = Instance.new("ImageLabel")
    icon.Name = "Icon"
    icon.Size = UDim2.fromScale(1, 1)
    icon.BackgroundTransparency = 1
    icon.Image = def.passConfig.icon or ""
    icon.ImageColor3 = Color3.fromRGB(225, 225, 235)
    icon.ImageTransparency = 0.14
    icon.ScaleType = Enum.ScaleType.Fit
    icon.Parent = holder

    return { holder = holder, def = def }
end

function PlayerPowerBadges.start()
    local gui = Instance.new("ScreenGui")
    gui.Name = "PlayerPowerBadges"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 26
    gui.Parent = localPlayer:WaitForChild("PlayerGui")

    local function applyBattleHide()
        local hideInBattle = localPlayer:GetAttribute("HideTogglesInBattle") ~= false
        gui.Enabled = not (hideInBattle and localPlayer:GetAttribute("EnemyHudActive") == true)
    end
    localPlayer:GetAttributeChangedSignal("EnemyHudActive"):Connect(applyBattleHide)
    localPlayer:GetAttributeChangedSignal("HideTogglesInBattle"):Connect(applyBattleHide)
    applyBattleHide()

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
        local cfg = (UI_CONFIG.hud and UI_CONFIG.hud.power_badges) or {}
        local x, y
        if cfg.placement == "vertical_left" then
            -- Open to the right of the left-edge column.
            x = math.clamp(
                anchor.AbsolutePosition.X + anchor.AbsoluteSize.X + 8,
                8,
                math.max(8, viewport.X - 328)
            )
            y = math.clamp(anchor.AbsolutePosition.Y, 8, math.max(8, viewport.Y - 174))
        else
            local anchorCenter = anchor.AbsolutePosition.X + anchor.AbsoluteSize.X * 0.5
            x = math.clamp(anchorCenter - 160, 8, math.max(8, viewport.X - 328))
            y = math.clamp(
                anchor.AbsolutePosition.Y + anchor.AbsoluteSize.Y + 8,
                8,
                math.max(8, viewport.Y - 174)
            )
        end
        tooltip.Position = UDim2.fromOffset(x, y)
        tooltip.Visible = true
        tooltipAnchor = anchor
    end

    local host = Instance.new("Frame")
    host.Name = "BadgeStack"
    host.AnchorPoint = Vector2.new(0.5, 0)
    host.AutomaticSize = Enum.AutomaticSize.XY
    host.BackgroundTransparency = 1
    host.ZIndex = 8
    host.Parent = gui
    local UIViewportScale = require(script.Parent.Parent.UI.UIViewportScale)
    UIViewportScale.attach(host)

    local fit = Instance.new("Frame")
    fit.Name = "Fit"
    fit.AutomaticSize = Enum.AutomaticSize.XY
    fit.BackgroundTransparency = 1
    fit.ZIndex = 8
    fit.Parent = host
    local fitScale = Instance.new("UIScale")
    fitScale.Name = "FitScale"
    fitScale.Scale = 1
    fitScale.Parent = fit

    local stackLayout = Instance.new("UIListLayout")
    stackLayout.FillDirection = Enum.FillDirection.Vertical
    stackLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    stackLayout.SortOrder = Enum.SortOrder.LayoutOrder
    stackLayout.Padding = UDim.new(0, 2)
    stackLayout.Parent = fit

    local passRow = Instance.new("Frame")
    passRow.Name = "OwnedPassesRow"
    passRow.LayoutOrder = 1
    passRow.Size = UDim2.fromOffset(0, 38)
    passRow.AutomaticSize = Enum.AutomaticSize.X
    passRow.BackgroundTransparency = 1
    passRow.ZIndex = 8
    passRow.Parent = fit

    local activeRow = Instance.new("Frame")
    activeRow.Name = "ActiveEffectsRow"
    activeRow.LayoutOrder = 2
    activeRow.Size = UDim2.fromOffset(0, 50)
    activeRow.AutomaticSize = Enum.AutomaticSize.X
    activeRow.BackgroundTransparency = 1
    activeRow.ZIndex = 8
    activeRow.Parent = fit

    local activeLayout = Instance.new("UIListLayout")
    activeLayout.FillDirection = Enum.FillDirection.Horizontal
    activeLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    activeLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    activeLayout.SortOrder = Enum.SortOrder.LayoutOrder
    activeLayout.Padding = UDim.new(0, 4)
    activeLayout.Parent = activeRow

    local passLayout = Instance.new("UIListLayout")
    passLayout.FillDirection = Enum.FillDirection.Horizontal
    passLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    passLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    passLayout.SortOrder = Enum.SortOrder.LayoutOrder
    passLayout.Padding = UDim.new(0, 2)
    passLayout.Parent = passRow

    local function fitToBox()
        local cfg = (UI_CONFIG.hud and UI_CONFIG.hud.power_badges) or {}
        if cfg.placement ~= "vertical_left" then
            fitScale.Scale = 1
            return
        end
        local boxH = host.AbsoluteSize.Y
        local current = fitScale.Scale
        if current < 0.05 then
            current = 1
        end
        local natural = fit.AbsoluteSize.Y / current
        if boxH <= 1 or natural <= 1 then
            return
        end
        local nextScale = math.clamp(boxH / natural, tonumber(cfg.min_fit) or 0.42, 1)
        if math.abs(nextScale - current) > 0.01 then
            fitScale.Scale = nextScale
        end
    end

    local function placeStack()
        local inset = GuiService:GetGuiInset()
        local cfg = (UI_CONFIG.hud and UI_CONFIG.hud.power_badges) or {}
        local gap = tonumber(cfg.gap_under_topbar) or 4
        local compact = localPlayer:GetAttribute("HudLayoutResolved") == "compact"
            or localPlayer:GetAttribute("DisplayClass") == "phone"
        if cfg.placement == "vertical_left" then
            -- The box is screen-relative. A ViewportScale here was shrinking
            -- a "50%" box down to ~quarter-screen on a phone.
            local vs = host:FindFirstChild("ViewportScale")
            if vs then
                vs:Destroy()
            end
            host.AnchorPoint = Vector2.new(0, 0)
            host.AutomaticSize = Enum.AutomaticSize.X
            host.Position =
                UDim2.new(0, tonumber(cfg.left_edge) or 8, tonumber(cfg.box_top_scale) or 0.15, 0)
            host.Size = UDim2.new(0, 0, tonumber(cfg.box_height_scale) or 0.50, 0)
            stackLayout.FillDirection = Enum.FillDirection.Horizontal
            stackLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
            stackLayout.VerticalAlignment = Enum.VerticalAlignment.Top
            passLayout.FillDirection = Enum.FillDirection.Vertical
            passLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
            activeLayout.FillDirection = Enum.FillDirection.Vertical
            activeLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
            passRow.Size = UDim2.fromOffset(0, 0)
            passRow.AutomaticSize = Enum.AutomaticSize.XY
            activeRow.Size = UDim2.fromOffset(0, 0)
            activeRow.AutomaticSize = Enum.AutomaticSize.XY
            task.defer(fitToBox)
            return
        end
        fitScale.Scale = 1
        if not host:FindFirstChild("ViewportScale") then
            UIViewportScale.attach(host)
        end
        UIViewportScale.setMultiplier(host, compact and (tonumber(cfg.compact_scale) or 0.72) or 1)
        host.AnchorPoint = Vector2.new(0.5, 0)
        host.AutomaticSize = Enum.AutomaticSize.XY
        host.Size = UDim2.fromOffset(0, 0)
        local button = math.max(36, inset.Y)
        local count = tonumber(cfg.topbar_buttons) or 5
        -- Midpoint of logo…shop. CoreGui is not a layout parent we can anchor to.
        host.Position = UDim2.fromOffset(button * count * 0.5, inset.Y + gap)
        stackLayout.FillDirection = Enum.FillDirection.Vertical
        stackLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
        stackLayout.VerticalAlignment = Enum.VerticalAlignment.Top
        passLayout.FillDirection = Enum.FillDirection.Horizontal
        passLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
        activeLayout.FillDirection = Enum.FillDirection.Horizontal
        activeLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
        passRow.Size = UDim2.fromOffset(0, 38)
        passRow.AutomaticSize = Enum.AutomaticSize.X
        activeRow.Size = UDim2.fromOffset(0, 50)
        activeRow.AutomaticSize = Enum.AutomaticSize.X
    end
    placeStack()
    localPlayer:GetAttributeChangedSignal("HudLayoutResolved"):Connect(placeStack)
    localPlayer:GetAttributeChangedSignal("DisplayClass"):Connect(placeStack)
    pcall(function()
        GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(placeStack)
    end)
    local cam = Workspace.CurrentCamera
    if cam then
        cam:GetPropertyChangedSignal("ViewportSize"):Connect(placeStack)
    end
    host:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitToBox)
    fit:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitToBox)
    passRow.ChildAdded:Connect(function()
        task.defer(fitToBox)
    end)
    activeRow.ChildAdded:Connect(function()
        task.defer(fitToBox)
    end)

    local badges = {} -- attr -> badge
    local passBadges = {} -- pass id -> badge
    local livePasses = MonetizationCatalog.livePasses(MONETIZATION)

    local function refreshOwnedPasses(snapshot)
        local owned = MonetizationCatalog.ownedSet(snapshot)
        local detailsById = {}
        for _, detail in ipairs((snapshot and snapshot.passes) or {}) do
            if type(detail) == "table" and type(detail.id) == "string" then
                detailsById[detail.id] = detail
            end
        end

        for _, entry in ipairs(livePasses) do
            local passId = entry.id
            local badge = passBadges[passId]
            if owned[passId] then
                local detail = detailsById[passId] or {}
                if not badge then
                    local def = {
                        passId = passId,
                        passConfig = entry.config,
                        passSources = detail.sources or {},
                    }
                    badge = makePassBadge(passRow, entry.order, def, showTooltip, hideTooltip)
                    passBadges[passId] = badge
                else
                    badge.def.passSources = detail.sources or {}
                end
            elseif badge then
                badge.holder:Destroy()
                passBadges[passId] = nil
            end
        end
    end

    Signals.OwnedPasses.OnClientEvent:Connect(refreshOwnedPasses)
    Signals.GetOwnedPasses:FireServer()

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
                        activeRow,
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
                    applyPowerChrome(b.holder, b.disc, b.timer, 1)
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
                        local overlap, stackPad =
                            applyPowerChrome(b.holder, b.disc, b.timer, stacks)
                        for n = 1, stacks - 1 do
                            if not b.extra[n] then
                                local d = b.disc:Clone()
                                d.Name = "Stack" .. n
                                d.ZIndex = b.disc.ZIndex - n -- behind the front disc
                                d.Parent = b.holder
                                b.extra[n] = d
                            end
                            b.extra[n].Image = b.disc.Image
                            b.extra[n].Size = b.disc.Size
                            b.extra[n].AnchorPoint = b.disc.AnchorPoint
                            -- Fan LEFT of the front disc, half-overlap.
                            if isVerticalBadges() then
                                b.extra[n].Position = UDim2.fromOffset(stackPad - n * overlap, 0)
                            else
                                b.extra[n].Position = UDim2.new(1, -n * overlap, 0, 0)
                            end
                            b.extra[n].ImageTransparency = 0
                        end
                        for n = stacks, #b.extra do -- prune dropped stacks
                            if b.extra[n] then
                                b.extra[n]:Destroy()
                                b.extra[n] = nil
                            end
                        end
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
                        applyPowerChrome(b.holder, b.disc, b.timer, 1)
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
