--[[
    TradePanel — client UI for the escrow two-player trade flow (Phase 10).

    Two layers:
      • List view (opened by the "Trade" side-menu button, via MenuManager): the
        online-player list; click a player to send a trade request.
      • Live layer (own ScreenGui, always present): the incoming-request popup and
        the two-player trade window, driven by the server's TradeUpdate RemoteEvent
        so they appear even when the menu is closed.

    All actions go through the GameAPICommand bus bridge (trade.players/request/
    respond/add/remove/confirm/cancel/myPets); the server pushes live state via
    TradeUpdate.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CloseButton = require(script.Parent.Parent.Components.CloseButton)
local PanelChrome = require(script.Parent.Parent.Components.PanelChrome)
local KeyedCardGrid = require(script.Parent.Parent.Components.KeyedCardGrid)
local Pill = require(script.Parent.Parent.Pill)
local InventoryPanel = require(script.Parent.InventoryPanel)
local PetCardStyle = require(script.Parent.Parent.PetCardStyle)
-- shared amount-picker popover (offer N copies of a stack with a slider, vs N clicks)
local QuantitySelector = require(script.Parent.Parent.Components.QuantitySelector)

local REMOTE_NAME = "GameAPICommand"
local Signals = require(ReplicatedStorage.Shared.Network.Signals)
local TradeReveal = require(ReplicatedStorage.Shared.Game.TradeReveal)
local TradePetSort = require(ReplicatedStorage.Shared.Game.TradePetSort)
local TradeLogic = require(ReplicatedStorage.Shared.Game.TradeLogic)
local PetPower = require(ReplicatedStorage.Shared.Game.PetPower)
local PetPowerView = require(ReplicatedStorage.Shared.Game.PetPowerView)
local ElementResonance = require(ReplicatedStorage.Shared.Game.ElementResonance)
local EnchantRuntime = require(ReplicatedStorage.Shared.Game.EnchantRuntime)
local gameEventsOk, GameEvents = pcall(function()
    return require(script.Parent.Parent.Parent.Systems.GameEvents)
end)

local function config(name)
    local ok, value = pcall(function()
        return require(ReplicatedStorage.Configs:WaitForChild(name))
    end)
    return ok and value or {}
end

local PETS_CONFIG = config("pets")
local PET_PROGRESSION = config("pet_progression")
local PET_ROLES = config("pet_roles")
local COMBAT_FX = config("combat_fx")
local AREAS_CONFIG = config("areas")
local ELEMENTS_CONFIG = config("elements")
local ENCHANTS_CONFIG = config("enchants")
local TRADE_CONFIG = config("trade")
local UI_CONFIG = config("ui")

local inventoryGridConfig = (
    UI_CONFIG.panel_configs
    and UI_CONFIG.panel_configs.inventory_panel
    and UI_CONFIG.panel_configs.inventory_panel.grid
) or {}
local TRADE_CARD_SIZE = typeof(inventoryGridConfig.card_size) == "Vector2"
        and inventoryGridConfig.card_size
    or Vector2.new(65, 65)
local TRADE_CARD_PADDING = typeof(inventoryGridConfig.card_padding) == "Vector2"
        and inventoryGridConfig.card_padding
    or Vector2.new(8, 8)

local function variantEternalScale(percent, variant)
    if not percent or percent <= 0 then
        return percent or 0
    end
    local multipliers = PET_ROLES.variant_effect_multipliers
    local multiplier = multipliers and tonumber(multipliers[string.lower(tostring(variant))])
    return percent * (multiplier or 1)
end

local function configuredEternalPercent(petData, record, variant)
    local eternal = PETS_CONFIG.eternal or {}
    local percent = 0
    if record.creator == true then
        percent = tonumber(eternal.creator_power_percent) or 130
    elseif record.huge == true then
        percent = tonumber(eternal.huge_power_percent) or 120
    elseif tonumber(record.eternal_percent) and tonumber(record.eternal_percent) > 0 then
        percent = tonumber(record.eternal_percent)
    elseif type(petData and petData.eternal) == "table" and petData.eternal.enabled == true then
        percent = tonumber(petData.eternal.power_percent) or 0
    else
        local defaults = eternal.default_percent_by_rarity
        percent = type(defaults) == "table" and tonumber(defaults[petData and petData.rarity_id])
            or 0
    end
    return variantEternalScale(percent, variant)
end

local function eternalLevelScale(rarityId, level)
    local cap = PETS_CONFIG.eternal and tonumber(PETS_CONFIG.eternal.level_bonus_max)
    if not cap or cap <= 0 then
        return 1
    end
    local maxLevel = PetPower.maxLevelForRarity(rarityId, PET_PROGRESSION)
    level = math.max(1, math.floor(tonumber(level) or 1))
    if maxLevel <= 1 or level <= 1 then
        return 1
    end
    return 1 + cap * math.clamp((level - 1) / (maxLevel - 1), 0, 1)
end

-- Resolve the same configured/level/Eternal base InventoryPanel puts on its card item. Inventory's
-- shared card renderer applies role aptitude, variant, live biome, and live realm to this value.
local function tradeCardPower(item)
    local record = type(item.record) == "table" and item.record or item
    local petType = item.id or record.id
    local variant = item.variant or record.variant or "basic"
    local petData = PETS_CONFIG.getPet and PETS_CONFIG.getPet(petType, variant)
    local level = item.level or record.level or 1
    local isHuge = item.huge == true or record.huge == true
    local power = PetPower.basePowerForLevel(petData, isHuge, level, PET_PROGRESSION)

    local eternalPercent = configuredEternalPercent(petData, record, variant)
    local eternalBaseline = tonumber(Players.LocalPlayer:GetAttribute("EternalPowerBase"))
    if eternalPercent > 0 and eternalBaseline and eternalBaseline > 0 then
        local rarityId = record.rarity_id or (petData and petData.rarity_id)
        local eternalPower = math.floor(
            eternalBaseline * (eternalPercent / 100) * eternalLevelScale(rarityId, level) + 0.5
        )
        power = math.max(power, eternalPower)
    end

    return power, petData
end

-- Resolve the same effective number inventory uses for sorting: configured level power, Eternal
-- floor, role aptitude, variant, live biome, and live realm.
local function tradeDisplayPower(item)
    local record = type(item.record) == "table" and item.record or item
    local petType = item.id or record.id
    local variant = item.variant or record.variant or "basic"
    local isCreator = item.creator == true or record.creator == true
    local power = tradeCardPower(item)

    local origin = COMBAT_FX.origin or {}
    local zones = AREAS_CONFIG.zones or {}
    local zone = zones[tostring(Players.LocalPlayer:GetAttribute("CurrentArea"))]
    local zoneMultiplier = ElementResonance.biomeMultiplierWithFloor(
        (origin.pettype_element or {})[petType],
        zone and zone.element,
        ELEMENTS_CONFIG,
        EnchantRuntime.effectMagnitude("home_world", record, ENCHANTS_CONFIG)
    )
    local petDef = PETS_CONFIG.pets and PETS_CONFIG.pets[petType]
    local realmMultiplier = ElementResonance.petRealmMultiplier(
        petDef and petDef.realm,
        Players.LocalPlayer:GetAttribute("CurrentRealm"),
        ELEMENTS_CONFIG
    )
    local profile = PetPowerView.profile({
        base = power,
        petType = petType,
        variant = variant,
        creator = isCreator,
        context = { zone = zoneMultiplier, realm = realmMultiplier },
    })
    return math.max(profile.miningEffective or 0, profile.combatEffective or 0)
end

local COLORS = {
    panel = Color3.fromRGB(20, 20, 25),
    header = Color3.fromRGB(56, 161, 178),
    headerGradient = Color3.fromRGB(43, 134, 148),
    row = Color3.fromRGB(40, 42, 52),
    rowStroke = Color3.fromRGB(70, 74, 88),
    you = Color3.fromRGB(46, 120, 170),
    them = Color3.fromRGB(120, 80, 160),
    accept = Color3.fromRGB(46, 204, 113),
    cancel = Color3.fromRGB(231, 76, 60),
    confirmed = Color3.fromRGB(46, 204, 113),
    pending = Color3.fromRGB(120, 124, 138),
    close = Color3.fromRGB(231, 76, 60),
    text = Color3.fromRGB(255, 255, 255),
    subtext = Color3.fromRGB(200, 205, 215),
    -- multi-bucket trade additions
    gem = Color3.fromRGB(120, 70, 200),
    gemStroke = Color3.fromRGB(170, 120, 240),
    enh = Color3.fromRGB(60, 64, 78),
    barBg = Color3.fromRGB(28, 30, 40),
    tabOn = Color3.fromRGB(56, 161, 178),
    tabOff = Color3.fromRGB(45, 48, 60),
}

local TradePanel = {}
TradePanel.__index = TradePanel

function TradePanel.new()
    local self = setmetatable({}, TradePanel)
    self.isVisible = false
    self.frame = nil
    self.liveGui = nil
    self.window = nil
    self.requestPopup = nil
    self.state = nil
    self._inventoryCards = InventoryPanel.CreateItemCardRenderer({
        cardSize = TRADE_CARD_SIZE,
        loggerName = "TradeInventoryCards",
    })
    -- Listen synchronously so a fast response cannot race panel construction. This connection
    -- stays live when the player picker closes, allowing decline/timeout/opened pushes to arrive.
    local remote = Signals.TradeUpdate
    if remote then
        self._tradeUpdateConnection = remote.OnClientEvent:Connect(function(payload)
            self:_onEvent(payload)
        end)
    end
    return self
end

-- Where the offer slider starts when you tap a stack: configs/trade.lua
-- offer_picker_default = "min" | "max", defaulting to "min" (1). Cached after first read.
function TradePanel:_offerPickerDefault(qty)
    if self._offerPickerMode == nil then
        local mode = "min"
        pcall(function()
            local cfg = require(ReplicatedStorage.Configs:WaitForChild("trade"))
            if cfg and cfg.offer_picker_default then
                mode = cfg.offer_picker_default
            end
        end)
        self._offerPickerMode = mode
    end
    return self._offerPickerMode == "max" and qty or 1
end

function TradePanel:_callBus(name, args)
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

----------------------------------------------------------------------
-- Small UI helpers
----------------------------------------------------------------------

local function corner(inst, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 10)
    c.Parent = inst
    return inst
end

-- Capsule treatment on an EXISTING button. UIGradient also colors a TextButton's built-in glyphs,
-- which produced the muddy outline/glow in the Trade flow. The native Text MUST be empty: Roblox
-- still rendered it under UIGradient when TextTransparency was 1, producing two overlaid labels.
-- State changes write through setPillText so only the un-tinted child label ever draws.
local function setPillText(btn, text)
    btn.Text = ""
    btn:SetAttribute("DisplayText", text)
    local buttonLabel = btn:FindFirstChild("Label")
    if buttonLabel and buttonLabel:IsA("TextLabel") then
        buttonLabel.Text = text
    end
end

local function pillify(btn, maxTextSize)
    local initialText = btn.Text
    for _, c in ipairs(btn:GetChildren()) do
        if c:IsA("UICorner") or c:IsA("UIGradient") or c:IsA("UIStroke") then
            c:Destroy()
        end
    end
    Pill.applyTo(btn, { color = btn.BackgroundColor3 })

    local buttonLabel = Instance.new("TextLabel")
    buttonLabel.Name = "Label"
    buttonLabel.Size = UDim2.fromScale(1, 1)
    buttonLabel.BackgroundTransparency = 1
    buttonLabel.Text = initialText
    buttonLabel.TextColor3 = btn.TextColor3
    buttonLabel.TextTransparency = 0
    buttonLabel.TextStrokeTransparency = 1
    buttonLabel.TextScaled = btn.TextScaled
    buttonLabel.TextSize = btn.TextSize
    buttonLabel.Font = btn.Font
    buttonLabel.ZIndex = btn.ZIndex + 1
    buttonLabel.Parent = btn

    local constraint = Instance.new("UITextSizeConstraint")
    constraint.MaxTextSize = maxTextSize or 18
    constraint.Parent = buttonLabel

    btn.Text = ""
    btn.TextStrokeTransparency = 1
    btn:SetAttribute("DisplayText", initialText)
    btn:GetPropertyChangedSignal("TextColor3"):Connect(function()
        buttonLabel.TextColor3 = btn.TextColor3
    end)
    return btn, buttonLabel
end

local function label(parent, text, size, pos, color, font, scaled)
    local l = Instance.new("TextLabel")
    l.Size = size
    l.Position = pos
    l.BackgroundTransparency = 1
    l.Text = text
    l.TextColor3 = color or COLORS.text
    l.Font = font or Enum.Font.Gotham
    l.TextScaled = scaled ~= false
    l.ZIndex = 103
    l.Parent = parent
    return l
end

local function petDisplayName(item)
    local id = item.id or (item.record and item.record.id)
    local pet = id and PETS_CONFIG.pets and PETS_CONFIG.pets[id]
    return tostring((pet and pet.display_name) or id or "Pet")
end

-- Translate an escrow/source descriptor into the exact display item consumed by InventoryPanel's
-- card renderer. Preserve the complete record so enchant and identity badges read the same fields
-- they do in Inventory; only the renderer-facing identity/name/power fields are normalized here.
local function inventoryPetCardItem(pet)
    local record = type(pet.record) == "table" and pet.record or pet
    local petType = pet.id or record.id
    local variant = pet.variant or record.variant or "basic"
    local petData = PETS_CONFIG.getPet and PETS_CONFIG.getPet(petType, variant)
    local huge = pet.huge == true or record.huge == true
    local creator = pet.creator == true or record.creator == true
    local rarityId = huge and "huge"
        or pet.rarity_id
        or record.rarity_id
        or (petData and petData.rarity_id)
        or variant
    local recordKey = pet.recordKey or pet.uid
    local stack = type(recordKey) == "string" and string.find(recordKey, ":", 1, true) ~= nil
    local familyName = (petData and (petData.family_display_name or petData.name))
        or petDisplayName(pet)

    local item = table.clone(record)
    item.id = (stack and "stack|" or "special|") .. tostring(recordKey or petType)
    item.uid = tostring(recordKey or pet.uid or petType)
    item.name = (huge and "Huge " or "")
        .. tostring(familyName)
        .. (pet.serial and (" #" .. tostring(pet.serial)) or "")
    item.icon = "🐾"
    item.rarity = tostring(rarityId):gsub("^%l", string.upper)
    item.rarityId = rarityId
    item.color = PetCardStyle.rarityColor(rarityId, petType)
    item.category = "Pets"
    item.folder_source = "pets"
    item.count = tonumber(pet.count) or tonumber(pet.quantity) or 1
    item.power = tradeCardPower(pet)
    item.basePower = item.power
    item.effectivePower = item.power
    item.level = pet.level or record.level or 1
    item.huge = huge
    item.creator = creator
    item.serial = pet.serial or record.serial
    item.locked = pet.locked == true or record.locked == true
    item.special = not stack
    item.petType = petType
    item.variant = variant
    item.use3DModel = true
    return item
end

local ENHANCEMENT_ORIGIN_COLORS = {
    geomancer = Color3.fromRGB(150, 230, 150),
    pyromancer = Color3.fromRGB(255, 150, 120),
    cryomancer = Color3.fromRGB(140, 200, 255),
    sandwalker = Color3.fromRGB(240, 215, 130),
}
local ENHANCEMENT_DUAL_COLOR = Color3.fromRGB(196, 156, 255)
local ENHANCEMENT_NATURAL_COLOR = Color3.fromRGB(205, 205, 215)

local function inventoryEnhancementCardItem(item)
    local enhancement = type(item.enh) == "table" and item.enh
        or type(item.record) == "table" and item.record
        or item
    local origins = enhancement.origins or item.origins or {}
    local typeName = enhancement.type or item.type
    local single = #origins == 1
    local rarity = (#origins == 0 and "Natural") or (single and "Single") or "Dual"
    local color = (#origins == 0 and ENHANCEMENT_NATURAL_COLOR)
        or (single and ENHANCEMENT_ORIGIN_COLORS[origins[1]])
        or ENHANCEMENT_DUAL_COLOR
    local shorts = {}
    for _, origin in ipairs(origins) do
        shorts[#shorts + 1] = origin:sub(1, 1):upper() .. origin:sub(2, 3)
    end

    return {
        id = tostring(item.recordKey or item.uid or item.id),
        uid = tostring(item.recordKey or item.uid or item.id),
        name = typeName and (typeName:sub(1, 1):upper() .. typeName:sub(2))
            or tostring(item.name or enhancement.name or "Enhancement"),
        icon = "⚙️",
        rarity = rarity,
        rarityId = rarity:lower(),
        color = color or ENHANCEMENT_NATURAL_COLOR,
        category = "Enhancements",
        count = tonumber(item.count or item.quantity or enhancement.quantity) or 1,
        enhancement_type = typeName,
        level = enhancement.level or item.level,
        origins = origins,
        origins_label = table.concat(shorts, "/"),
        folder_source = "enhancements",
    }
end

local function inventoryEggCardItem(item)
    local record = type(item.record) == "table" and item.record or item
    local eggId = item.id or record.id
    local eggDef = PETS_CONFIG.egg_sources and PETS_CONFIG.egg_sources[eggId]
    if eggDef and record.trial_reward_huge_chance ~= nil then
        eggDef = table.clone(eggDef)
        eggDef.huge = table.clone(eggDef.huge or {})
        eggDef.huge.chance = record.trial_reward_huge_chance
    end
    local tier = tostring(item.variant or record.award_tier or record.variant or "basic"):lower()
    local baseName = (eggDef and eggDef.name)
        or tostring(item.name or record.name or eggId or "Egg")
    local displayName = tier ~= "basic" and ((tier:gsub("^%l", string.upper)) .. " " .. baseName)
        or baseName
    local uid = tostring(item.recordKey or item.uid or record.uid or eggId)

    return {
        id = uid,
        uid = uid,
        name = displayName,
        icon = "🥚",
        image = eggDef and eggDef.image_id,
        rarity = "Exclusive",
        rarityId = "exclusive",
        color = Color3.fromRGB(255, 215, 0),
        category = "Eggs",
        count = tonumber(item.count or item.quantity or record.quantity) or 1,
        egg_def = eggDef,
        variant = tier,
        award_kind = record.award_kind,
        award_id = record.award_id or item.award_id,
        awarded_to_user_id = record.awarded_to_user_id,
        trial_reward_stage = record.trial_reward_stage,
        trial_reward_huge_chance = record.trial_reward_huge_chance,
        icon_zoom = eggDef and eggDef.icon_zoom,
        folder_source = "eggs",
    }
end

local function inventoryTradeCardItem(item)
    if item.category == "enhancements" then
        return inventoryEnhancementCardItem(item)
    elseif item.category == "eggs" then
        return inventoryEggCardItem(item)
    end
    return inventoryPetCardItem(item)
end

local function tradeKindKey(item)
    local category = item.category or "pets"
    if category == "currencies" then
        return "cur|" .. tostring(item.id)
    elseif category == "enhancements" then
        return "enh|" .. tostring(item.recordKey or item.id)
    elseif category == "eggs" then
        return "egg|" .. tostring(item.recordKey or item.award_id or item.uid or item.id)
    end

    -- Unique pets retain their record key so two same-species specials never collapse into one
    -- card. Common escrow copies share a colon-delimited stack record key and intentionally
    -- aggregate into one quantity card.
    local recordKey = item.recordKey or item.uid
    if type(recordKey) == "string" and not string.find(recordKey, ":", 1, true) then
        return "pet-unique|" .. recordKey
    end
    return "pet-stack|"
        .. tostring(recordKey or item.id)
        .. "|"
        .. tostring(item.variant or "basic")
        .. "|"
        .. tostring(item.huge == true)
end

local function cardsOf(items)
    local out = {}
    for _, item in ipairs(items or {}) do
        if (item.category or "pets") ~= "currencies" then
            out[#out + 1] = item
        end
    end
    return out
end

local function aggregateOffer(items)
    local groups, ordered = {}, {}
    for _, item in ipairs(cardsOf(items)) do
        local key = tradeKindKey(item)
        local group = groups[key]
        if not group then
            group = table.clone(item)
            group.count = 0
            group.uids = {}
            group._tradeKey = key
            groups[key] = group
            ordered[#ordered + 1] = group
        end
        group.count += 1
        group.uids[#group.uids + 1] = item.uid
    end
    return ordered
end

local function gemTotal(items)
    local amount = 0
    for _, item in ipairs(items or {}) do
        if item.category == "currencies" then
            amount += tonumber(item.amount) or 0
        end
    end
    return amount
end

local function sourceCardKey(item)
    return tostring(item.category or "pets") .. "|source|" .. tostring(item.uid or item.id)
end

local function offerCardKey(item)
    return tostring(item.category or "pets") .. "|offer|" .. tostring(item._tradeKey or item.uid)
end

----------------------------------------------------------------------
-- Menu-button list view (pick a player)
----------------------------------------------------------------------

function TradePanel:Show(parent)
    if self.isVisible then
        return
    end
    local frame = Instance.new("Frame")
    frame.Name = "TradePanel"
    frame.Size = UDim2.new(0.5, 0, 0.7, 0)
    frame.Position = UDim2.new(0.5, 0, 0.5, 0)
    frame.AnchorPoint = Vector2.new(0.5, 0.5)
    frame.BackgroundColor3 = COLORS.panel
    frame.BorderSizePixel = 0
    frame.ZIndex = 100
    frame.Parent = parent
    corner(frame, 20)
    -- Standard game pill border (area-themed, same style as the other panels) — Jason: "pills on
    -- the outside." Replaces the thin header-colored stroke.
    PanelChrome.pillBorder(frame, PanelChrome.areaPill(), 130, 0, 0.07) -- match the shared shell
    self.frame = frame

    self:_buildHeader(frame, "🤝 Trade", function()
        self:Hide()
    end)

    local hint = label(
        frame,
        "Pick a player to send a trade request:",
        UDim2.new(1, -48, 0, 24),
        UDim2.new(0, 24, 0, 84),
        COLORS.subtext,
        Enum.Font.Gotham
    )
    hint.TextXAlignment = Enum.TextXAlignment.Left
    hint.ZIndex = 102

    local privacy = Instance.new("Frame")
    privacy.Name = "InvitePrivacy"
    privacy.Size = UDim2.new(1, -48, 0, 40)
    privacy.Position = UDim2.new(0, 24, 0, 112)
    privacy.BackgroundTransparency = 1
    privacy.ZIndex = 102
    privacy.Parent = frame
    self.privacyBar = privacy
    local privacyLabel = label(
        privacy,
        "Accepting requests",
        UDim2.new(0.37, 0, 1, 0),
        UDim2.new(0, 0, 0, 0),
        COLORS.subtext,
        Enum.Font.Gotham
    )
    privacyLabel.TextXAlignment = Enum.TextXAlignment.Left
    privacyLabel.ZIndex = 103
    self.privacyButtons = {}
    for i, mode in ipairs({ "everyone", "friends", "off" }) do
        local btn = Instance.new("TextButton")
        btn.Name = mode
        btn.Size = UDim2.new(0.2, 0, 0.86, 0)
        btn.Position = UDim2.new(0.37 + (i - 1) * 0.21, 0, 0.07, 0)
        btn.BackgroundColor3 = COLORS.row
        btn.Text = TradeLogic.invitePrivacyLabel(mode, TRADE_CONFIG)
        btn.TextColor3 = COLORS.text
        btn.TextScaled = true
        btn.Font = Enum.Font.GothamBold
        btn.ZIndex = 103
        btn.Parent = privacy
        pillify(btn, 16)
        local constraint = Instance.new("UITextSizeConstraint")
        constraint.MaxTextSize = 14
        constraint.Parent = btn
        btn.Activated:Connect(function()
            local result = self:_callBus("trade.set_invite_privacy", { mode = mode })
            if result and result.ok then
                self._privacyOverride = result.mode
            end
            self:_refreshTradePrivacy()
        end)
        self.privacyButtons[mode] = btn
    end

    local list = Instance.new("ScrollingFrame")
    list.Name = "PlayerList"
    list.Size = UDim2.new(1, -24, 1, -204)
    list.Position = UDim2.new(0, 12, 0, 160)
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
    self.playerList = list

    local refresh = Instance.new("TextButton")
    refresh.Size = UDim2.new(0, 160, 0, 40)
    refresh.Position = UDim2.new(0.5, 0, 1, -30)
    refresh.AnchorPoint = Vector2.new(0.5, 0.5)
    refresh.BackgroundColor3 = COLORS.header
    refresh.Text = "Refresh"
    refresh.TextColor3 = COLORS.text
    refresh.TextScaled = true
    refresh.Font = Enum.Font.GothamBold
    refresh.ZIndex = 102
    refresh.Parent = frame
    pillify(refresh, 18)
    refresh.Activated:Connect(function()
        self:_refreshPlayers()
    end)

    self.isVisible = true
    self:_refreshTradePrivacy()
    self:_refreshPlayers()
end

function TradePanel:_refreshTradePrivacy()
    if not self.privacyButtons then
        return
    end
    local current = TradeLogic.invitePrivacy(
        self._privacyOverride or Players.LocalPlayer:GetAttribute("TradeInvitePrivacy"),
        TRADE_CONFIG
    )
    for mode, btn in pairs(self.privacyButtons) do
        local selected = mode == current
        btn.BackgroundColor3 = selected and COLORS.accept or COLORS.row
        btn.AutoButtonColor = not selected
    end
end

function TradePanel:Hide()
    if not self.isVisible then
        return
    end
    if self.frame then
        self.frame:Destroy()
        self.frame = nil
    end
    self.playerList = nil
    self.privacyBar = nil
    self.privacyButtons = nil
    self._privacyOverride = nil
    self.isVisible = false
end

function TradePanel:IsVisible()
    return self.isVisible
end

function TradePanel:GetFrame()
    return self.frame
end

function TradePanel:Destroy()
    self:Hide()
    if self._tradeUpdateConnection then
        self._tradeUpdateConnection:Disconnect()
        self._tradeUpdateConnection = nil
    end
    if self._inventoryCards then
        self._inventoryCards:Destroy()
        self._inventoryCards = nil
    end
end

function TradePanel:_closeSelectionPanel()
    local menuManager = _G.MenuManager
    if menuManager and menuManager:GetCurrentPanel() == self then
        menuManager:CloseCurrentPanel("fade")
    else
        self:Hide()
    end
end

-- baseZ keeps the header above its parent frame on high-ZIndex surfaces (the pet
-- picker sits at ZIndex 300, so its header children must be > 300).
function TradePanel:_buildHeader(parent, titleText, onClose, baseZ)
    baseZ = baseZ or 101
    -- Header takes the home-area color (gold on Sand) like the other menus — Jason: "should be a
    -- gold-like gradient, not teal."
    local _, areaColor = PanelChrome.areaPill()
    areaColor = areaColor or COLORS.header
    local areaDim = areaColor:Lerp(Color3.fromRGB(0, 0, 0), 0.35)
    local header = Instance.new("Frame")
    header.Name = "Header"
    header.Size = UDim2.new(1, 0, 0, 72)
    header.BackgroundColor3 = areaColor
    header.BorderSizePixel = 0
    header.ZIndex = baseZ
    header.Parent = parent
    corner(header, 20)
    local g = Instance.new("UIGradient")
    g.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, areaColor),
        ColorSequenceKeypoint.new(1, areaDim),
    })
    g.Rotation = 90
    g.Parent = header
    local title = label(
        header,
        titleText,
        UDim2.new(1, -150, 1, 0),
        UDim2.new(0, 24, 0, 0),
        COLORS.text,
        Enum.Font.GothamBold
    )
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.ZIndex = baseZ + 2
    local tc = Instance.new("UITextSizeConstraint")
    tc.MaxTextSize = 30
    tc.Parent = title
    -- THE standard close X — attach to the PANEL (sibling of the pill border) so it sits ABOVE the
    -- 130 border on the main panel; popups (high baseZ) keep their own layering.
    CloseButton.attach(parent, {
        zindex = math.max(baseZ + 2, 146),
        onClick = onClose,
    })
end

function TradePanel:_refreshPlayers()
    if not self.playerList then
        return
    end
    for _, ch in ipairs(self.playerList:GetChildren()) do
        if ch:IsA("Frame") then
            ch:Destroy()
        end
    end
    local result = self:_callBus("trade.players", {})
    local players = result and result.players or {}
    if #players == 0 then
        local empty = label(
            self.playerList,
            "No other players online to trade with.",
            UDim2.new(1, 0, 0, 50),
            UDim2.new(0, 0, 0, 0),
            COLORS.subtext,
            Enum.Font.Gotham
        )
        empty.ZIndex = 102
        local ec = Instance.new("UITextSizeConstraint")
        ec.MaxTextSize = 18
        ec.Parent = empty
        return
    end
    for i, p in ipairs(players) do
        self:_playerRow(p, i)
    end
end

function TradePanel:_playerRow(p, order)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -8, 0, 56)
    row.BackgroundColor3 = COLORS.row
    row.BorderSizePixel = 0
    row.LayoutOrder = order
    row.ZIndex = 102
    row.Parent = self.playerList
    corner(row, 10)

    -- "Lv N  name" — the Level attribute is server-published and replicates to every
    -- client, so other players' levels read directly (Jason: "can we put the players
    -- level?")
    local other = Players:GetPlayerByUserId(p.userId)
    local lvl = other and other:GetAttribute("Level")
    local status = p.privacy and ("   ·  " .. p.privacy) or ""
    local name = label(
        row,
        (lvl and ("Lv %d   "):format(lvl) or "") .. p.name .. status,
        UDim2.new(1, -140, 1, 0),
        UDim2.new(0, 14, 0, 0),
        COLORS.text,
        Enum.Font.GothamBold
    )
    name.TextXAlignment = Enum.TextXAlignment.Left
    local nc = Instance.new("UITextSizeConstraint")
    nc.MaxTextSize = 18
    nc.Parent = name

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 110, 0, 40)
    btn.Position = UDim2.new(1, -122, 0.5, -20)
    local blockedText = {
        friends_only = "Friends only",
        invites_off = "Off",
    }
    local unavailable = p.busy or p.blockedReason ~= nil
    btn.BackgroundColor3 = unavailable and COLORS.pending or COLORS.accept
    btn.Text = p.busy and "Busy" or blockedText[p.blockedReason] or "Request"
    btn.TextColor3 = COLORS.text
    btn.TextScaled = true
    btn.Font = Enum.Font.GothamBold
    btn.Active = not unavailable
    btn.AutoButtonColor = not unavailable
    btn.ZIndex = 103
    btn.Parent = row
    pillify(btn, 16)
    if not unavailable then
        btn.Activated:Connect(function()
            local res = self:_callBus("trade.request", { targetUserId = p.userId })
            if res and res.ok then
                setPillText(btn, "Sent ✓")
                self:_closeSelectionPanel()
            else
                setPillText(btn, blockedText[res and res.reason] or "Failed")
            end
            btn.Active = false
            btn.AutoButtonColor = false
        end)
    end
end

----------------------------------------------------------------------
-- Live layer: request popup + trade window (own ScreenGui)
----------------------------------------------------------------------

function TradePanel:_ensureLiveGui()
    if self.liveGui and self.liveGui.Parent then
        return self.liveGui
    end
    local pg = Players.LocalPlayer:WaitForChild("PlayerGui")
    local gui = Instance.new("ScreenGui")
    gui.Name = "TradeLive"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    -- Above MenuOverlay (120) and the inventory's viewport fallback (150): server responses must
    -- remain visible even if another normal menu opens while a request is pending.
    gui.DisplayOrder = 160
    gui.Parent = pg
    self.liveGui = gui
    return gui
end

function TradePanel:_onEvent(payload)
    if type(payload) ~= "table" then
        return
    end
    if payload.type == "request" then
        self:_showRequestPopup(payload.fromUserId, payload.fromName)
    elseif payload.type == "opened" or payload.type == "updated" then
        self.state = payload.state
        self:_renderWindow(payload.state)
    elseif payload.type == "completed" then
        self:_closeWindow()
        local receivedItems = payload.state and payload.state.them and payload.state.them.items
        if not self:_showReceivedPetReveal(receivedItems) then
            self:_toast("Trade complete!")
        end
    elseif payload.type == "cancelled" then
        self:_toast("Trade cancelled.")
        self:_closeWindow()
    elseif payload.type == "declined" then
        self:_statusBanner("trade_request_declined", "🤝 Trade request declined.")
    elseif payload.type == "timed_out" then
        self:_statusBanner("trade_request_timed_out", "⌛ Trade request timed out.")
    elseif payload.type == "request_expired" then
        self:_closeRequestPopup()
        self:_toast("Trade request expired.")
    end
end

-- A completed packet is sent after the atomic delivery and is recipient-relative, so
-- state.them.items is the authoritative set of pets this player just received. Reuse the hatch
-- result presenter (without an egg phase) and fall back to the normal toast if a real hatch is
-- already using that presenter.
function TradePanel:_showReceivedPetReveal(items)
    local prepared = TradeReveal.receivedPets(items, TradeReveal.MAX_PETS)
    if #prepared.pets == 0 then
        return false
    end

    local ok, hatchingService = pcall(function()
        return require(ReplicatedStorage.Shared.Services.EggHatchingService)
    end)
    if not ok or not hatchingService or not hatchingService:IsHatchReady() then
        return false
    end

    local started, result = pcall(function()
        return hatchingService:StartPetRevealAnimation(prepared.pets)
    end)
    return started and result ~= nil
end

-- Request outcomes are decisions the asker is actively waiting on, so they use the same prominent
-- floating banner pathway as awards and progression grants. Keep the local toast as a defensive
-- fallback if GameEvents failed to load; a response must never become silent again.
function TradePanel:_statusBanner(eventName, text)
    if gameEventsOk and GameEvents and GameEvents.fire then
        GameEvents.fire(eventName, { name = text })
        return
    end
    self:_toast(text)
end

function TradePanel:_showRequestPopup(fromUserId, fromName)
    self:_closeRequestPopup()
    local gui = self:_ensureLiveGui()
    local pop = Instance.new("Frame")
    pop.Name = "RequestPopup"
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
    self.requestPopup = pop

    local msg = label(
        pop,
        (fromName or "A player") .. " wants to trade",
        UDim2.new(1, -20, 0, 50),
        UDim2.new(0, 10, 0, 16),
        COLORS.text,
        Enum.Font.GothamBold
    )
    msg.ZIndex = 202 -- above the popup frame (200)
    msg.TextWrapped = true
    local mc = Instance.new("UITextSizeConstraint")
    mc.MaxTextSize = 20
    mc.Parent = msg

    local function actionButton(text, color, x, accept)
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
        pillify(b, 18)
        b.Activated:Connect(function()
            self:_callBus("trade.respond", { fromUserId = fromUserId, accept = accept })
            self:_closeRequestPopup()
        end)
    end
    actionButton("Accept", COLORS.accept, 0.05, true)
    actionButton("Decline", COLORS.cancel, 0.53, false)
end

function TradePanel:_closeRequestPopup()
    if self.requestPopup then
        self.requestPopup:Destroy()
        self.requestPopup = nil
    end
end

function TradePanel:_toast(text)
    local gui = self:_ensureLiveGui()
    local t = Instance.new("TextLabel")
    t.Size = UDim2.new(0, 320, 0, 44)
    t.Position = UDim2.new(0.5, 0, 0, 40)
    t.AnchorPoint = Vector2.new(0.5, 0)
    t.BackgroundColor3 = COLORS.header
    t.Text = text
    t.TextColor3 = COLORS.text
    t.TextScaled = true
    t.Font = Enum.Font.GothamBold
    t.ZIndex = 210
    t.Parent = gui
    corner(t, 10)
    local c = Instance.new("UITextSizeConstraint")
    c.MaxTextSize = 18
    c.Parent = t
    task.delay(2.5, function()
        if t and t.Parent then
            t:Destroy()
        end
    end)
end

function TradePanel:_closeWindow()
    if self.window then
        self.window:Destroy()
        self.window = nil
    end
    self._tradeView = nil
    self:_hideCardTooltip()
    self.state = nil
end

-- The live trade window uses the same shared shell and pet-card configuration as Inventory.
-- Authoritative TradeUpdate packets PATCH this hierarchy; they never replace the window or grids.
local VARIANT_COLORS = { -- tooltip stroke accents only; cards use PetCardStyle chrome
    basic = Color3.fromRGB(120, 125, 140),
    golden = Color3.fromRGB(255, 200, 60),
    rainbow = Color3.fromRGB(255, 90, 210),
}

function TradePanel:_createTradeWindow()
    local gui = self:_ensureLiveGui()
    local shell = PanelChrome.build(gui, {
        name = "TradeWindow",
        title = "🤝 Trading",
        size = UDim2.new(0.94, 0, 0.9, 0),
        onClose = function()
            self:_callBus("trade.cancel", {})
        end,
    })
    local win = shell.frame
    self.window = win

    local function changeSourceTab(tab)
        if self._sourceTab == tab then
            return
        end
        self._sourceTab = tab
        if self._lastState then
            self:_renderWindow(self._lastState)
        end
    end

    local source = self:_petColumn(win, {
        name = "TradeSourceColumn",
        position = UDim2.new(0.012, 0, 0.13, 0),
        size = UDim2.new(0.318, 0, 0.72, 0),
        tint = COLORS.row,
        pillKey = shell.areaKey,
        scrollKey = "source",
        tabs = {
            {
                id = "pets",
                label = "Pets",
                onClick = function()
                    changeSourceTab("pets")
                end,
            },
            {
                id = "enhancements",
                label = "Enhancements",
                onClick = function()
                    changeSourceTab("enhancements")
                end,
            },
            {
                id = "eggs",
                label = "Eggs",
                onClick = function()
                    changeSourceTab("eggs")
                end,
            },
        },
        gemMode = "input",
    })
    local yours = self:_petColumn(win, {
        name = "LocalOfferColumn",
        position = UDim2.new(0.341, 0, 0.13, 0),
        size = UDim2.new(0.318, 0, 0.72, 0),
        tint = COLORS.you,
        pillKey = "emerald",
        scrollKey = "your-offer",
        gemMode = "readout",
    })
    local theirs = self:_petColumn(win, {
        name = "PartnerOfferColumn",
        position = UDim2.new(0.67, 0, 0.13, 0),
        size = UDim2.new(0.318, 0, 0.72, 0),
        tint = COLORS.them,
        pillKey = "amethyst",
        scrollKey = "their-offer",
        gemMode = "readout",
    })

    local confirm, confirmLabel = Pill.button({
        parent = win,
        name = "ConfirmTrade",
        size = UDim2.new(0.24, 0, 0.075, 0),
        position = UDim2.new(0.43, 0, 0.89, 0),
        anchorPoint = Vector2.new(1, 0),
        color = COLORS.accept,
        text = "Confirm",
        textSize = 18,
        zIndex = 140,
    })
    confirm.Activated:Connect(function()
        self:_callBus("trade.confirm", {})
    end)

    local cancel = Pill.button({
        parent = win,
        name = "CancelTrade",
        size = UDim2.new(0.14, 0, 0.075, 0),
        position = UDim2.new(0.45, 0, 0.89, 0),
        color = COLORS.cancel,
        text = "Cancel",
        textSize = 18,
        zIndex = 140,
    })
    cancel.Activated:Connect(function()
        self:_callBus("trade.cancel", {})
    end)

    self._tradeView = {
        shell = shell,
        title = shell.header:FindFirstChild("Title"),
        source = source,
        yours = yours,
        theirs = theirs,
        confirm = confirm,
        confirmLabel = confirmLabel,
    }
end

function TradePanel:_renderWindow(state)
    self._sourceTab = self._sourceTab or "pets"
    self._lastState = state
    if not (self.window and self.window.Parent and self._tradeView) then
        self:_createTradeWindow()
    end

    local offeredCount = {}
    for _, item in ipairs(state.you.items or {}) do
        local key = tradeKindKey(item)
        offeredCount[key] = (offeredCount[key] or 0) + 1
    end

    local sourceItems
    if self._sourceTab == "enhancements" then
        local result = self:_callBus("trade.myEnhancements", {})
        sourceItems = (result and result.enhancements) or {}
    elseif self._sourceTab == "eggs" then
        local result = self:_callBus("trade.myEggs", {})
        sourceItems = (result and result.eggs) or {}
    else
        local result = self:_callBus("trade.myPets", {})
        sourceItems = (result and result.pets) or {}
        TradePetSort.sort(sourceItems, tradeDisplayPower)
    end

    local function addItem(item)
        if item.category == "enhancements" then
            self:_callBus("trade.addEnhancement", { uid = item.uid })
            return
        elseif item.category == "eggs" then
            self:_callBus("trade.addEgg", { uid = item.uid })
            return
        end

        local quantity = tonumber(item.quantity) or 1
        if quantity <= 1 then
            self:_callBus("trade.add", { uid = item.uid })
            return
        end
        QuantitySelector.prompt({
            parent = self:_ensureLiveGui(),
            title = "Offer how many?",
            subtitle = petDisplayName(item),
            accent = COLORS.accept,
            min = 1,
            max = quantity,
            default = self:_offerPickerDefault(quantity),
            confirmText = "Offer",
            onConfirm = function(amount)
                local result = self:_callBus("trade.addMany", { uid = item.uid, count = amount })
                if type(result) == "table" and result.added and result.added < amount then
                    self:_toast(("Offered %d of %d (offer full)"):format(result.added, amount))
                end
            end,
        })
    end

    local yourItems = aggregateOffer(state.you.items)
    local theirItems = aggregateOffer(state.them.items)
    self:_updatePetColumn(self._tradeView.source, "Your Stuff", sourceItems, {
        keyFor = sourceCardKey,
        sourceTab = self._sourceTab,
        offeredCount = offeredCount,
        kindKey = tradeKindKey,
        emptyText = "No tradeable items in this category",
        gemAmount = gemTotal(state.you.items),
        onSetGems = function(amount)
            self:_callBus("trade.setGems", { amount = amount })
        end,
        onClick = addItem,
    })
    self:_updatePetColumn(
        self._tradeView.yours,
        ("Your Offer (%d)"):format(#cardsOf(state.you.items)),
        yourItems,
        {
            keyFor = offerCardKey,
            offerMarker = true,
            confirmed = state.you.confirmed,
            emptyText = "Add pets, eggs, enhancements, or gems",
            gemAmount = gemTotal(state.you.items),
            onClick = function(item)
                local uid = item.uids and item.uids[#item.uids] or item.uid
                self:_callBus("trade.remove", { uid = uid })
            end,
        }
    )
    self:_updatePetColumn(
        self._tradeView.theirs,
        (state.them.name or "Them") .. ("'s Offer (%d)"):format(#cardsOf(state.them.items)),
        theirItems,
        {
            keyFor = offerCardKey,
            offerMarker = true,
            confirmed = state.them.confirmed,
            emptyText = "Nothing offered yet",
            gemAmount = gemTotal(state.them.items),
        }
    )

    if self._tradeView.title then
        self._tradeView.title.Text = "🤝 Trading with " .. (state.them.name or "Player")
    end
    local confirmed = state.you.confirmed == true
    self._tradeView.confirm.Active = not confirmed
    self._tradeView.confirm.AutoButtonColor = not confirmed
    self._tradeView.confirmLabel.Text = confirmed and "Confirmed ✓ (waiting…)" or "Confirm"
    Pill.recolor(self._tradeView.confirm, confirmed and COLORS.pending or COLORS.accept)
end

-- One stable titled column holding a keyed grid of cards. Only changed/removed keys are touched.
function TradePanel:_petColumn(parent, spec)
    local col = Instance.new("Frame")
    col.Name = spec.name
    col.Size = spec.size
    col.Position = spec.position
    col.BackgroundColor3 = spec.tint or COLORS.row
    col.BackgroundTransparency = 0.72
    col.ZIndex = 101
    col.Parent = parent
    corner(col, 12)
    PanelChrome.pillBorder(col, spec.pillKey or PanelChrome.areaPill(), 105, 0, 0.1)

    local head = label(
        col,
        "",
        UDim2.new(1, -28, 0, 24),
        UDim2.new(0, 14, 0, 6),
        COLORS.text,
        Enum.Font.GothamBold
    )
    head.Name = "ColumnTitle"
    head.TextXAlignment = Enum.TextXAlignment.Left
    local hc = Instance.new("UITextSizeConstraint")
    hc.MaxTextSize = 17
    hc.Parent = head

    -- optional Pets/Enhancements source tabs under the title
    local gridTop = 34
    local tabs = {}
    if spec.tabs then
        gridTop = 64
        local tx = 14
        for _, tabSpec in ipairs(spec.tabs) do
            local tabWidth = (tabSpec.label == "Enhancements") and 112 or 58
            local button, buttonLabel = Pill.button({
                parent = col,
                name = "Tab_" .. tabSpec.id,
                size = UDim2.fromOffset(tabWidth, 26),
                position = UDim2.fromOffset(tx, 32),
                color = COLORS.tabOff,
                text = tabSpec.label,
                textSize = 13,
                zIndex = 104,
            })
            tabs[tabSpec.id] = { button = button, label = buttonLabel }
            button.Activated:Connect(tabSpec.onClick)
            tx += tabWidth + 6
        end
    end

    local gridBottomInset = 0
    local gemBar
    if spec.gemMode then
        gridBottomInset = 52
        gemBar = self:_gemBar(col, spec.gemMode)
    end

    local grid = Instance.new("ScrollingFrame")
    grid.Name = "TradeItems"
    if spec.scrollKey then
        grid:SetAttribute("TradeScrollKey", spec.scrollKey)
    end
    grid.Size = UDim2.new(1, -24, 1, -(gridTop + 6 + gridBottomInset))
    grid.Position = UDim2.new(0, 12, 0, gridTop)
    grid.BackgroundTransparency = 1
    grid.BorderSizePixel = 0
    grid.ScrollBarThickness = 4
    grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
    grid.CanvasSize = UDim2.new(0, 0, 0, 0)
    grid.ZIndex = 102
    grid.Parent = col
    local lay = Instance.new("UIGridLayout")
    lay.CellSize = UDim2.fromOffset(TRADE_CARD_SIZE.X, TRADE_CARD_SIZE.Y)
    lay.CellPadding = UDim2.fromOffset(TRADE_CARD_PADDING.X, TRADE_CARD_PADDING.Y)
    lay.SortOrder = Enum.SortOrder.LayoutOrder
    lay.Parent = grid

    local empty = label(
        col,
        "",
        UDim2.new(1, -20, 0, 36),
        UDim2.new(0, 10, 0.45, 0),
        COLORS.subtext,
        Enum.Font.Gotham
    )
    empty.Name = "EmptyState"
    empty.TextWrapped = true
    empty.ZIndex = 103
    empty.Visible = false
    local ec = Instance.new("UITextSizeConstraint")
    ec.MaxTextSize = 14
    ec.Parent = empty

    local view = {
        frame = col,
        title = head,
        tabs = tabs,
        gemBar = gemBar,
        empty = empty,
    }
    view.cards = KeyedCardGrid.new(grid, function(cardParent, item, order, opts)
        return self:_tradeCard(cardParent, item, order, opts)
    end)
    return view
end

function TradePanel:_updatePetColumn(view, titleText, items, opts)
    view.title.Text = titleText .. (opts.confirmed and "  ✓" or "")
    view.title.TextColor3 = opts.confirmed and COLORS.confirmed or COLORS.text
    view.empty.Text = opts.emptyText or ""
    view.empty.Visible = #(items or {}) == 0 and opts.emptyText ~= nil
    for id, tab in pairs(view.tabs) do
        Pill.recolor(tab.button, id == opts.sourceTab and COLORS.tabOn or COLORS.tabOff)
    end
    if view.gemBar then
        view.gemBar:update(opts.gemAmount or 0, opts.onSetGems)
    end
    view.cards:update(items, opts.keyFor, opts)
end

function TradePanel:_tradeCard(parent, item, order, opts)
    return self:_inventoryCard(parent, item, order, opts)
end

-- Symmetric gem bar pinned at a column's bottom. Its controller updates in place with the offer.
function TradePanel:_gemBar(col, mode)
    local bar = Instance.new("Frame")
    bar.Name = "GemBar"
    bar.Size = UDim2.new(1, -16, 0, 40)
    bar.Position = UDim2.new(0, 8, 1, -46)
    bar.BackgroundColor3 = COLORS.barBg
    bar.ZIndex = 104
    bar.Parent = col
    corner(bar, 10)
    local stroke = Instance.new("UIStroke")
    stroke.Color = COLORS.gemStroke
    stroke.Thickness = 1
    stroke.Transparency = 0.2
    stroke.Parent = bar
    local gem = label(bar, "💎", UDim2.fromOffset(28, 40), UDim2.new(0, 8, 0, 0), COLORS.text)
    gem.ZIndex = 105

    local controller = { frame = bar, mode = mode }
    if mode == "input" then
        local box = Instance.new("TextBox")
        box.Name = "GemAmount"
        box.Size = UDim2.new(0.48, 0, 0, 30)
        box.Position = UDim2.new(0.17, 0, 0.5, -15)
        box.BackgroundColor3 = Color3.fromRGB(15, 16, 22)
        box.Text = ""
        box.PlaceholderText = "amount"
        box.ClearTextOnFocus = false
        box.TextColor3 = COLORS.text
        box.TextScaled = true
        box.Font = Enum.Font.GothamBold
        box.ZIndex = 106
        box.Parent = bar
        corner(box, 8)
        local constraint = Instance.new("UITextSizeConstraint")
        constraint.MaxTextSize = 16
        constraint.Parent = box

        local set = Pill.button({
            parent = bar,
            name = "SetGems",
            size = UDim2.new(0.25, 0, 0, 30),
            position = UDim2.new(0.72, 0, 0.5, -15),
            color = COLORS.gem,
            text = "Set",
            textSize = 14,
            zIndex = 106,
        })
        controller.box = box
        local function commit()
            local amount = math.max(0, math.floor(tonumber(box.Text) or 0))
            if controller.onSet then
                controller.onSet(amount)
            end
        end
        set.Activated:Connect(commit)
        box.FocusLost:Connect(function(enterPressed)
            if enterPressed then
                commit()
            end
        end)
    else
        local readout = label(
            bar,
            "0  Gems",
            UDim2.new(1, -50, 1, 0),
            UDim2.new(0, 42, 0, 0),
            COLORS.text,
            Enum.Font.GothamBold
        )
        readout.Name = "GemReadout"
        readout.TextXAlignment = Enum.TextXAlignment.Left
        readout.ZIndex = 105
        controller.readout = readout
    end
    function controller.update(controllerSelf, amount, onSet)
        controllerSelf.onSet = onSet
        if controllerSelf.readout then
            controllerSelf.readout.Text = ("%s  Gems"):format(tostring(amount or 0))
        elseif controllerSelf.box and not controllerSelf.box:IsFocused() then
            controllerSelf.box.PlaceholderText = amount > 0 and ("offering " .. tostring(amount))
                or "amount"
        end
    end
    return controller
end

-- The actual InventoryPanel card renderer, embedded behind a trade-only hit target. Pets,
-- enhancements, and eggs all take Inventory's one presentation path; Trade adds only offer state.
function TradePanel:_inventoryCard(parent, item, order, opts)
    local card = self._inventoryCards:Create(inventoryTradeCardItem(item), order, parent)
    local categoryName = item.category == "enhancements" and "Enhancement"
        or item.category == "eggs" and "Egg"
        or "Pet"
    card.Name = "Trade" .. categoryName .. "Card"
    local baseColor = card.BackgroundColor3
    local quantity = card:FindFirstChild("QtyLabel")

    local hitTarget = Instance.new("TextButton")
    hitTarget.Name = "TradeHitTarget"
    hitTarget.Size = UDim2.fromScale(1, 1)
    hitTarget.BackgroundTransparency = 1
    hitTarget.Text = ""
    hitTarget.AutoButtonColor = false
    hitTarget.ZIndex = 120
    hitTarget.Parent = card

    local offered = Instance.new("TextLabel")
    offered.Name = "OfferedCount"
    offered.Size = UDim2.new(0.7, 0, 0, 14)
    offered.Position = UDim2.new(0.5, 0, 0, 3)
    offered.AnchorPoint = Vector2.new(0.5, 0)
    offered.BackgroundColor3 = Color3.fromRGB(120, 95, 20)
    offered.BackgroundTransparency = 0.15
    offered.TextColor3 = Color3.fromRGB(255, 225, 140)
    offered.TextScaled = true
    offered.Font = Enum.Font.GothamBold
    offered.ZIndex = 121
    offered.Visible = false
    offered.Parent = card
    corner(offered, 6)

    local locked = Instance.new("TextLabel")
    locked.Name = "LockedOverlay"
    locked.Size = UDim2.fromScale(1, 1)
    locked.BackgroundColor3 = Color3.fromRGB(10, 10, 14)
    locked.BackgroundTransparency = 0.45
    locked.Text = "🔒"
    locked.TextColor3 = COLORS.text
    locked.TextScaled = true
    locked.Font = Enum.Font.GothamBold
    locked.ZIndex = 122
    locked.Visible = false
    locked.Parent = card
    corner(locked, 10)

    local controller = { frame = card, item = item, opts = opts }
    hitTarget.MouseEnter:Connect(function()
        self:_showCardTooltip(card, controller.item)
        if controller.opts.onClick and not controller.item.locked then
            card.BackgroundColor3 = Color3.fromRGB(60, 60, 75)
        end
    end)
    hitTarget.MouseLeave:Connect(function()
        self:_hideCardTooltip()
        card.BackgroundColor3 = baseColor
    end)
    hitTarget.Activated:Connect(function()
        if controller.opts.onClick and not controller.item.locked then
            self:_hideCardTooltip()
            controller.opts.onClick(controller.item)
        end
    end)

    function controller.update(controllerSelf, nextItem, nextOrder, nextOpts)
        controllerSelf.item = nextItem
        controllerSelf.opts = nextOpts
        card.LayoutOrder = nextOrder
        local record = type(nextItem.record) == "table" and nextItem.record or nextItem
        local isLocked = nextItem.locked == true or record.locked == true
        local clickable = nextOpts.onClick ~= nil and not isLocked
        hitTarget.Active = clickable
        hitTarget.Selectable = clickable

        local count = tonumber(nextItem.count) or tonumber(nextItem.quantity) or 1
        if quantity then
            quantity.Visible = count > 1
            quantity.Text = "×" .. tostring(count)
        end

        local offeredCount = 0
        if nextOpts.offeredCount and nextOpts.kindKey then
            offeredCount = nextOpts.offeredCount[nextOpts.kindKey(nextItem)] or 0
        end
        offered.Visible = offeredCount > 0 and nextOpts.offerMarker ~= true
        offered.Text = tostring(offeredCount) .. " offered"
        locked.Visible = isLocked
    end
    function controller.destroy(_controllerSelf)
        if card.Parent then
            card:Destroy()
        end
    end
    controller:update(item, order, opts)
    return controller
end

function TradePanel:_showCardTooltip(card, item)
    self:_hideCardTooltip()
    local gui = self:_ensureLiveGui()
    local tip = Instance.new("Frame")
    tip.Name = "TradeCardTooltip"
    tip.Size = UDim2.new(0, 180, 0, 0)
    tip.AutomaticSize = Enum.AutomaticSize.Y
    tip.BackgroundColor3 = Color3.fromRGB(14, 14, 20)
    tip.BackgroundTransparency = 0.06
    tip.ZIndex = 400
    tip.Parent = gui
    corner(tip, 8)
    local st = Instance.new("UIStroke")
    st.Color = VARIANT_COLORS[item.variant] or VARIANT_COLORS.basic
    st.Thickness = 2
    st.Parent = tip
    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, 6)
    pad.PaddingBottom = UDim.new(0, 6)
    pad.PaddingLeft = UDim.new(0, 8)
    pad.PaddingRight = UDim.new(0, 8)
    pad.Parent = tip
    local list = Instance.new("UIListLayout")
    list.Padding = UDim.new(0, 2)
    list.Parent = tip

    local lines
    if item.category == "eggs" then
        local egg = inventoryEggCardItem(item)
        lines = {
            egg.name,
            "Held egg · tradeable",
            "Variant: " .. tostring(egg.variant or "basic"),
        }
    elseif item.category == "enhancements" then
        local enhancement = inventoryEnhancementCardItem(item)
        lines = {
            enhancement.name,
            "Grade: " .. tostring(enhancement.rarity),
            "Level: " .. tostring(enhancement.level or "?"),
            "Origins: "
                .. (#enhancement.origins > 0 and table.concat(enhancement.origins, " + ") or "None"),
        }
    else
        lines = {
            petDisplayName(item) .. (item.serial and (" #" .. tostring(item.serial)) or ""),
            "Variant: " .. tostring(item.variant or "basic"),
        }
    end
    local qty = tonumber(item.quantity) or 1
    if qty > 1 then
        lines[#lines + 1] = "Owned: ×" .. qty
    end
    if item.count and item.count > 1 then
        lines[#lines + 1] = "In offer: ×" .. item.count
    end
    if item.category ~= "enhancements" and item.level then
        lines[#lines + 1] = "Level: " .. tostring(item.level)
    end
    if item.element and item.element ~= "neutral" then
        lines[#lines + 1] = "Element: " .. tostring(item.element)
    end
    if item.huge then
        lines[#lines + 1] = "HUGE"
    end
    if item.locked then
        lines[#lines + 1] = "🔒 Locked — can't be traded"
    end
    for i, text in ipairs(lines) do
        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(1, 0, 0, 16)
        l.BackgroundTransparency = 1
        l.Text = text
        l.TextColor3 = i == 1 and COLORS.text or COLORS.subtext
        l.TextSize = i == 1 and 14 or 12
        l.Font = i == 1 and Enum.Font.GothamBold or Enum.Font.Gotham
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.LayoutOrder = i
        l.ZIndex = 401
        l.Parent = tip
    end

    -- pin beside the card (right side, flips left near the screen edge)
    local cam = workspace.CurrentCamera
    local vpX = cam and cam.ViewportSize.X or 1280
    local x = card.AbsolutePosition.X + card.AbsoluteSize.X + 8
    if x + 190 > vpX then
        x = card.AbsolutePosition.X - 188
    end
    tip.Position = UDim2.fromOffset(x, card.AbsolutePosition.Y)
    self.cardTooltip = tip
end

function TradePanel:_hideCardTooltip()
    if self.cardTooltip then
        self.cardTooltip:Destroy()
        self.cardTooltip = nil
    end
end

return TradePanel
