--[[
    EggInteractionService - Simplified to work with CurrentTarget system
    
    Now only handles E key presses and egg purchasing.
    All proximity detection and UI positioning is handled by EggCurrentTargetService.
    Follows the working game's pattern exactly.
--]]

local EggInteractionService = {}

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

-- Dependencies
local Locations = require(ReplicatedStorage.Shared.Locations)
local petConfig = Locations.getConfig("pets")
local eggSystemConfig = Locations.getConfig("egg_system")
local autoSystemsConfig = Locations.getConfig("auto_systems")
local EggWorldQuery = require(ReplicatedStorage.Shared.Services.EggWorldQuery)
local Signals = require(ReplicatedStorage.Shared.Network.Signals)

-- Local player reference
local player = Players.LocalPlayer

-- Current target service reference
local currentTargetService = nil
local hatchRequestInFlight = false

-- Cached EggHatchingService handle. Consulted via IsHatchReady() to gate re-entry: a hatch
-- holds an animation lock from start until teardown completes, so HandleEggPurchase / auto-hatch
-- won't start a second hatch on top of one that's still animating.
local cachedHatchingService = nil
local function getHatchingService()
    if cachedHatchingService then
        return cachedHatchingService
    end
    local ok, service = pcall(function()
        return require(ReplicatedStorage.Shared.Services.EggHatchingService)
    end)
    if ok and service then
        cachedHatchingService = service
    end
    return cachedHatchingService
end
local autoHatchEnabled = false
local autoHatchSessionId = 0
local selectedHatchCount = 1
local hatchActionMode = "single"
local hatchPanelGui = nil
local hatchPanel = nil
local hatchPanelFields = {}
local hatchPanelConnection = nil
local entitlementConnections = {}
local settingsConnections = {}
local hatchSettingsOpen = false
local lastHatchPanelEggType = nil
local lastPersistedHatchCount = nil
local lastPersistedHatchModesKey = nil
local autoDeleteState = {
    enabled = false,
    rarities = {},
    pet_types = {},
    variants = {},
}
local hatchModeState = {
    showHatch = true,
    goldenMode = false,
    chargedMode = false,
    fastHatch = false,
    skipHatch = false,
    silentHatch = false,
}
local lastStatusAt = 0

local MODE_STUB_KEYS = {
    goldenMode = "golden_mode",
    chargedMode = "charged_mode",
    fastHatch = "fast_hatch",
    skipHatch = "skip_hatch",
}

local MODE_ENTITLEMENT_ATTRIBUTES = {
    goldenMode = "GoldenHatchUnlocked",
    chargedMode = "ChargedHatchUnlocked",
    fastHatch = "FastHatchUnlocked",
    skipHatch = "SkipHatchUnlocked",
}

-- Logger setup using singleton pattern
local Logger
local loggerSuccess, loggerResult = pcall(function()
    return require(Locations.Logger)
end)

if loggerSuccess and loggerResult then
    Logger = loggerResult -- Use singleton directly
else
    Logger = {
        Info = function(_self, message, context)
            print("[INFO]", message, context)
        end,
        Warn = function(_self, message, context)
            warn("[WARN]", message, context)
        end,
        Error = function(_self, message, context)
            warn("[ERROR]", message, context)
        end,
        Debug = function(_self, message, context)
            print("[DEBUG]", message, context)
        end,
    }
end

local function getHatchingConfig()
    return eggSystemConfig.hatching or {}
end

local function getHatchPanelConfig()
    return eggSystemConfig.ui and eggSystemConfig.ui.hatch_panel or {}
end

local function getHatchPanelHelpConfig()
    return getHatchPanelConfig().help or {}
end

local function getModeConfigByOption(optionName)
    local modes = getHatchPanelConfig().modes or {}
    for key, cfg in pairs(modes) do
        if (cfg.option or key) == optionName then
            return cfg
        end
    end
    return nil
end

local function getModeStub(optionName)
    local stubKey = MODE_STUB_KEYS[optionName]
    if not stubKey then
        return nil
    end

    local stub = (getHatchingConfig().shop_stubs or {})[stubKey]
    return type(stub) == "table" and stub or nil
end

local function formatMultiplier(multiplier)
    multiplier = tonumber(multiplier)
    if not multiplier or multiplier == 1 then
        return nil
    end

    if math.abs(multiplier - math.floor(multiplier)) < 0.001 then
        return tostring(math.floor(multiplier)) .. "x"
    end

    return string.format("%.2fx", multiplier)
end

local function formatSignedNumber(value)
    value = tonumber(value)
    if not value or value == 0 then
        return nil
    end

    if math.abs(value - math.floor(value)) < 0.001 then
        return "+" .. tostring(math.floor(value))
    end

    return string.format("+%.2f", value)
end

local function getModeDetailText(optionName)
    local stub = getModeStub(optionName)
    if not stub then
        return ""
    end

    local details = {}
    local costMultiplier = formatMultiplier(stub.cost_multiplier)
    if costMultiplier then
        table.insert(details, "Cost " .. costMultiplier)
    end

    local luckBonus = formatSignedNumber(stub.luck_bonus)
    if luckBonus then
        table.insert(details, "Luck " .. luckBonus)
    end

    local secretLuckBonus = formatSignedNumber(stub.secret_luck_bonus)
    if secretLuckBonus then
        table.insert(details, "Secret " .. secretLuckBonus)
    end

    return table.concat(details, ", ")
end

local function isModeOwned(optionName)
    if optionName == "silentHatch" then
        return true
    end

    local attributeName = MODE_ENTITLEMENT_ATTRIBUTES[optionName]
    if attributeName then
        local attributeValue = player:GetAttribute(attributeName)
        if attributeValue ~= nil then
            return attributeValue == true
        end
    end

    local stubKey = MODE_STUB_KEYS[optionName]
    local stub = stubKey and (getHatchingConfig().shop_stubs or {})[stubKey]
    if type(stub) == "table" then
        if stub.enabled == false then
            return false
        end
        return stub.owned_by_default == true
    end

    return true
end

local function getModeHelpText(optionName, cfg)
    cfg = cfg or getModeConfigByOption(optionName) or {}
    local owned = isModeOwned(optionName)
    local detailText = getModeDetailText(optionName)
    local baseText
    if not owned then
        baseText = cfg.locked_description or cfg.description
    elseif hatchModeState[optionName] == true then
        baseText = cfg.active_description or cfg.description
    else
        baseText = cfg.available_description or cfg.description
    end
    if detailText ~= "" then
        return tostring(baseText or "") .. " (" .. detailText .. ")"
    end
    return baseText
end

local function getMaxHatchCount()
    local hatching = getHatchingConfig()
    return math.clamp(math.floor(tonumber(hatching.max_count) or 99), 1, 99)
end

local function getEffectiveMaxHatchCount()
    local hatching = getHatchingConfig()
    local stubs = hatching.shop_stubs or {}
    local maxStub = stubs.max_hatch_count or {}
    local configuredDefault = tonumber(maxStub.default_value)
        or tonumber(hatching.default_max_entitled_count)
        or getMaxHatchCount()
    local attributeMax = tonumber(player:GetAttribute("MaxEggHatchCount"))
    local effective = attributeMax or configuredDefault
    return math.clamp(math.floor(tonumber(effective) or 1), 1, getMaxHatchCount())
end

local function isAutoHatchOwned()
    local attributeValue = player:GetAttribute("AutoHatchUnlocked")
    if attributeValue ~= nil then
        return attributeValue == true
    end

    local autoStub = (getHatchingConfig().shop_stubs or {}).auto_hatch or {}
    if autoStub.enabled == false then
        return false
    end
    return autoStub.owned_by_default == true
end

local function clampSelectedCount(count)
    return math.clamp(math.floor(tonumber(count) or 1), 1, getEffectiveMaxHatchCount())
end

local function getDefaultSelectedHatchCount()
    local hatching = getHatchingConfig()
    local panel = getHatchPanelConfig()
    return clampSelectedCount(
        tonumber(panel.default_selected_count) or tonumber(hatching.default_requested_count) or 1
    )
end

local function sanitizeHatchActionMode(value)
    local valid = { single = true, max = true, auto = true }
    local panel = getHatchPanelConfig()
    local defaultMode = tostring(panel.default_action_mode or "single"):lower()
    if not valid[defaultMode] then
        defaultMode = "single"
    end

    value = tostring(value or defaultMode):lower()
    if valid[value] then
        return value
    end
    return defaultMode
end

local function getHatchActionModeLabel(actionMode)
    actionMode = sanitizeHatchActionMode(actionMode)
    local actionConfig = getHatchPanelConfig().action_modes or {}
    local cfg = actionConfig[actionMode] or {}
    local fallback = actionMode:gsub("^%l", string.upper) .. " Hatch"
    return tostring(cfg.label or fallback)
end

local function getPersistedHatchActionMode()
    local settingsFolder = player:FindFirstChild("Settings")
    local autoFolder = settingsFolder and settingsFolder:FindFirstChild("AutoSystems")
    local hatchFolder = autoFolder and autoFolder:FindFirstChild("Hatch")
    local actionValue = hatchFolder and hatchFolder:FindFirstChild("ActionMode")
    if actionValue and actionValue:IsA("StringValue") then
        return sanitizeHatchActionMode(actionValue.Value)
    end
    return nil
end

local function persistHatchActionMode(actionMode)
    hatchActionMode = sanitizeHatchActionMode(actionMode)
    Signals.HatchSettings_SetActionMode:FireServer({
        actionMode = hatchActionMode,
    })
end

local function getPersistedSelectedHatchCount()
    local settingsFolder = player:FindFirstChild("Settings")
    local autoFolder = settingsFolder and settingsFolder:FindFirstChild("AutoSystems")
    local hatchFolder = autoFolder and autoFolder:FindFirstChild("Hatch")
    local selectedValue = hatchFolder and hatchFolder:FindFirstChild("SelectedCount")
    if selectedValue and selectedValue:IsA("IntValue") then
        return clampSelectedCount(selectedValue.Value)
    end
    return nil
end

-- RAW persisted selection (no clamp). Used when the entitlement ceiling RISES — MaxEggHatchCount
-- replicates a beat after join, and a selection clamped against the early config default could
-- never climb back (clamping only lowers). Re-applying the raw choice lets it recover.
local function getPersistedRawSelectedHatchCount()
    local settingsFolder = player:FindFirstChild("Settings")
    local autoFolder = settingsFolder and settingsFolder:FindFirstChild("AutoSystems")
    local hatchFolder = autoFolder and autoFolder:FindFirstChild("Hatch")
    local selectedValue = hatchFolder and hatchFolder:FindFirstChild("SelectedCount")
    if selectedValue and selectedValue:IsA("IntValue") then
        return selectedValue.Value
    end
    return nil
end

local function persistSelectedHatchCount(count)
    count = clampSelectedCount(count)
    if lastPersistedHatchCount == count then
        return
    end

    lastPersistedHatchCount = count
    Signals.HatchSettings_SetCount:FireServer({
        selectedCount = count,
    })
end

local function getPersistedHatchModes()
    local settingsFolder = player:FindFirstChild("Settings")
    local autoFolder = settingsFolder and settingsFolder:FindFirstChild("AutoSystems")
    local hatchFolder = autoFolder and autoFolder:FindFirstChild("Hatch")
    local modesFolder = hatchFolder and hatchFolder:FindFirstChild("Modes")
    if not modesFolder then
        return nil
    end

    local modes = {}
    local found = false
    for optionName in pairs(hatchModeState) do
        local value = modesFolder:FindFirstChild(optionName)
        if value and value:IsA("BoolValue") then
            modes[optionName] = value.Value == true
            found = true
        end
    end
    return found and modes or nil
end

local function readBoolSetFolder(parent, folderName)
    local result = {}
    local folder = parent and parent:FindFirstChild(folderName)
    if not folder then
        return result
    end

    for _, child in ipairs(folder:GetChildren()) do
        if child:IsA("BoolValue") and child.Value == true then
            result[child.Name] = true
        end
    end

    return result
end

local function getPersistedAutoDeleteStatus()
    local settingsFolder = player:FindFirstChild("Settings")
    local autoFolder = settingsFolder and settingsFolder:FindFirstChild("AutoSystems")
    local autoDeleteFolder = autoFolder and autoFolder:FindFirstChild("AutoDelete")
    if not autoDeleteFolder then
        return nil
    end

    local enabledValue = autoDeleteFolder:FindFirstChild("Enabled")
    return {
        enabled = enabledValue and enabledValue:IsA("BoolValue") and enabledValue.Value == true
            or false,
        rarities = readBoolSetFolder(autoDeleteFolder, "Rarities"),
        pet_types = readBoolSetFolder(autoDeleteFolder, "PetTypes"),
        variants = readBoolSetFolder(autoDeleteFolder, "Variants"),
    }
end

local function hatchModesKey(modes)
    local parts = {}
    for optionName in pairs(hatchModeState) do
        table.insert(parts, optionName .. "=" .. tostring(modes and modes[optionName] == true))
    end
    table.sort(parts)
    return table.concat(parts, ";")
end

local function currentHatchModes()
    local modes = {}
    for optionName, enabled in pairs(hatchModeState) do
        modes[optionName] = enabled == true
    end
    return modes
end

local function getRelativeBounds(parent, child)
    local parentPosition = parent.AbsolutePosition
    local childPosition = child.AbsolutePosition
    local childSize = child.AbsoluteSize

    return {
        x = childPosition.X - parentPosition.X,
        y = childPosition.Y - parentPosition.Y,
        width = childSize.X,
        height = childSize.Y,
        right = childPosition.X - parentPosition.X + childSize.X,
        bottom = childPosition.Y - parentPosition.Y + childSize.Y,
    }
end

local function getDrawerDebugLayout()
    local drawer = hatchPanelFields.settings
    if not drawer then
        return nil
    end

    local drawerSize = drawer.AbsoluteSize
    local children = {}
    local clippedChildren = {}
    for _, child in ipairs(drawer:GetDescendants()) do
        if child:IsA("GuiObject") and child.Visible == true then
            local bounds = getRelativeBounds(drawer, child)
            local clipped = bounds.x < -0.5
                or bounds.y < -0.5
                or bounds.right > drawerSize.X + 0.5
                or bounds.bottom > drawerSize.Y + 0.5
            table.insert(children, {
                name = child.Name,
                className = child.ClassName,
                clipped = clipped,
                bounds = bounds,
            })
            if clipped then
                table.insert(clippedChildren, child.Name)
            end
        end
    end

    return {
        visible = drawer.Visible == true,
        width = drawerSize.X,
        height = drawerSize.Y,
        childCount = #children,
        clippedChildren = clippedChildren,
        children = children,
    }
end

local function persistHatchModes()
    local modes = currentHatchModes()
    local key = hatchModesKey(modes)
    if lastPersistedHatchModesKey == key then
        return
    end

    lastPersistedHatchModesKey = key
    Signals.HatchSettings_SetModes:FireServer({
        modes = modes,
    })
end

local function getViewportSize()
    local camera = Workspace.CurrentCamera
    if camera then
        return camera.ViewportSize
    end
    local panelConfig = getHatchPanelConfig()
    return Vector2.new((tonumber(panelConfig.width) or 500) + 64, 800)
end

local function asSet(values)
    local result = {}
    if type(values) ~= "table" then
        return result
    end

    for key, value in pairs(values) do
        if type(key) == "number" then
            result[tostring(value)] = true
        elseif value == true then
            result[tostring(key)] = true
        end
    end
    return result
end

local function setToArray(set)
    local values = {}
    for key, enabled in pairs(set or {}) do
        if enabled == true then
            table.insert(values, key)
        end
    end
    table.sort(values)
    return values
end

local function countSet(set)
    local count = 0
    for _, enabled in pairs(set or {}) do
        if enabled == true then
            count += 1
        end
    end
    return count
end

local function titleCaseId(id)
    return tostring(id or ""):gsub("_", " "):gsub("(%l)(%w*)", function(a, b)
        return string.upper(a) .. b
    end)
end

local function getEggDisplayData(eggType)
    local eggData = petConfig.egg_sources[eggType]
    if not eggData then
        return nil
    end

    local cost = (petConfig.getEggCost and petConfig.getEggCost(eggType)) or eggData.cost or 0
    return {
        name = eggData.name or titleCaseId(eggType),
        currency = eggData.currency or "coins",
        cost = math.max(0, tonumber(cost) or 0),
    }
end

local function formatNumber(value)
    value = tonumber(value) or 0
    if value >= 1000000000 then
        return string.format("%.1fB", value / 1000000000)
    elseif value >= 1000000 then
        return string.format("%.1fM", value / 1000000)
    elseif value >= 1000 then
        return string.format("%.1fK", value / 1000)
    end
    return tostring(math.floor(value))
end

local function getCurrencyIcon(currency)
    if currency == "gems" then
        return "💎"
    elseif currency == "crystals" then
        return "🔮"
    end
    return "💰"
end

local function getCurrencyAttributeName(currency)
    currency = tostring(currency or "")
    return currency:gsub("^%l", string.upper)
end

local function getPlayerCurrencyBalance(currency)
    local attributeName = getCurrencyAttributeName(currency)
    local value = player:GetAttribute(attributeName)
    if value == nil then
        return nil
    end
    return math.max(0, tonumber(value) or 0)
end

local function formatCostDetail(costEach, multiplier, selectedCount, affordableCount)
    local parts = {}
    table.insert(parts, formatNumber(costEach) .. " each")
    if multiplier and multiplier > 1 then
        table.insert(parts, formatMultiplier(multiplier))
    end
    if affordableCount then
        table.insert(
            parts,
            "afford "
                .. tostring(math.min(selectedCount, affordableCount))
                .. "/"
                .. tostring(selectedCount)
        )
    end
    return table.concat(parts, " • ")
end

local function formatStopReason(stopReason)
    local labels = {
        currency = "out of currency",
        -- Storage v2: stacks never truncate; only UNIQUE (secret+) jackpots can hit
        -- the cap, so name the resource so the player knows what filled up.
        storage = "unique pet storage full",
        entitlement = "hatch limit",
        partial = "partial hatch",
        grant_failed = "grant issue",
        no_storage = "unique pet storage full",
    }
    return labels[stopReason] or tostring(stopReason or "")
end

local function isTerminalAutoStopReason(stopReason)
    return stopReason == "currency"
        or stopReason == "storage"
        or stopReason == "entitlement"
        or stopReason == "grant_failed"
        or stopReason == "partial"
end

local function formatAutoErrorStopReason(result)
    if type(result) ~= "table" then
        return nil
    end

    local labels = {
        insufficient_currency = "out of currency",
        no_storage = "storage full",
        too_far = "too far away",
        feature_locked = "locked feature",
        egg_locked = "locked egg",
        partial_not_allowed = "partial hatch unavailable",
        invalid_egg = "egg unavailable",
    }
    return labels[result.code]
end

local function getSelectedCostMultiplier()
    local hatching = getHatchingConfig()
    local shopStubs = hatching.shop_stubs or {}
    local golden = shopStubs.golden_mode or {}
    local charged = shopStubs.charged_mode or {}
    local multiplier = 1
    if hatchModeState.goldenMode == true then
        multiplier *= math.max(1, tonumber(golden.cost_multiplier) or 20)
    end
    if hatchModeState.chargedMode == true then
        multiplier *= math.max(1, tonumber(charged.cost_multiplier) or 5)
    end
    return multiplier
end

local function getFilterDisplayName(id)
    local petFamily = petConfig.pets and petConfig.pets[id]
    return (petConfig.rarities[id] and petConfig.rarities[id].name)
        or (petFamily and (petFamily.display_name or petFamily.name))
        or (petConfig.variants[id] and petConfig.variants[id].name)
        or titleCaseId(id)
end

local function getProtectedAutoDeleteRarities()
    local autoDeleteConfig = autoSystemsConfig.auto_delete or {}
    local values = {}
    for rarityId, protected in pairs(autoDeleteConfig.protected_rarities or {}) do
        if protected == true then
            table.insert(values, tostring(rarityId))
        end
    end
    table.sort(values)
    return values
end

local function getProtectedAutoDeleteText()
    local protectedRarities = getProtectedAutoDeleteRarities()
    local labels = {}
    for _, rarityId in ipairs(protectedRarities) do
        table.insert(labels, getFilterDisplayName(rarityId))
    end

    if #labels == 0 then
        return "Protected: none"
    end

    return "Protected: " .. table.concat(labels, ", ")
end

local function formatAutoDeleteSummary()
    local filterConfig = getHatchPanelConfig().auto_delete or {}
    local rarityCount = countSet(autoDeleteState.rarities)
    local petTypeCount = countSet(autoDeleteState.pet_types)
    local variantCount = countSet(autoDeleteState.variants)
    local totalCount = rarityCount + petTypeCount + variantCount

    if totalCount <= 0 then
        return tostring(filterConfig.summary_empty or "Auto-delete: Off (no filters)"),
            totalCount,
            rarityCount,
            petTypeCount,
            variantCount
    end

    local formatText = autoDeleteState.enabled and filterConfig.summary_enabled_format
        or filterConfig.summary_disabled_format
    formatText = tostring(formatText or "Auto-delete: %s (%d filters)")
    local ok, text = pcall(function()
        if formatText:find("%s", 1, true) then
            return string.format(
                formatText,
                autoDeleteState.enabled and "On" or "Off",
                totalCount,
                rarityCount,
                petTypeCount,
                variantCount
            )
        end
        return string.format(formatText, totalCount, rarityCount, petTypeCount, variantCount)
    end)

    if ok then
        return text, totalCount, rarityCount, petTypeCount, variantCount
    end

    return "Auto-delete: " .. (autoDeleteState.enabled and "On" or "Off") .. " (" .. tostring(
        totalCount
    ) .. " filters)",
        totalCount,
        rarityCount,
        petTypeCount,
        variantCount
end

function EggInteractionService:CreateButton(parent, name, text, size, position, color, callback)
    local button = Instance.new("TextButton")
    button.Name = name
    button.Size = size
    button.Position = position
    button.BackgroundColor3 = color
    button.BorderSizePixel = 0
    button.Text = text
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.TextScaled = true
    button.Font = Enum.Font.GothamBold
    button.AutoButtonColor = true
    button.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = button

    button.MouseButton1Click:Connect(function()
        if callback then
            callback()
        end
    end)

    return button
end

function EggInteractionService:SetPanelStatus(message, isError)
    if not hatchPanelFields.status then
        return
    end

    lastStatusAt = os.clock()
    hatchPanelFields.status.Text = tostring(message or "")
    hatchPanelFields.status.TextColor3 = isError and Color3.fromRGB(255, 150, 150)
        or Color3.fromRGB(170, 255, 210)
end

function EggInteractionService:SetHatchHelp(message)
    if not hatchPanelFields.helpText then
        return
    end

    local helpConfig = getHatchPanelHelpConfig()
    hatchPanelFields.helpText.Text = tostring(message or helpConfig.default or "")
end

function EggInteractionService:RefreshHatchCostDisplay(eggType)
    if not hatchPanel or not hatchPanelFields.cost then
        return
    end

    local eggData = getEggDisplayData(eggType)
    if not eggData then
        return
    end

    local costMultiplier = getSelectedCostMultiplier()
    local costEach = math.floor((eggData.cost * costMultiplier) + 0.5)
    local displayCount = hatchActionMode == "max" and getEffectiveMaxHatchCount()
        or selectedHatchCount
    local totalCost = costEach * displayCount
    local balance = getPlayerCurrencyBalance(eggData.currency)
    local affordableCount = balance and math.floor(balance / math.max(1, costEach)) or nil
    hatchPanelFields.title.Text = eggData.name
    hatchPanelFields.cost.Text = string.format(
        "%s %s %s",
        getCurrencyIcon(eggData.currency),
        formatNumber(totalCost),
        titleCaseId(eggData.currency)
    )
    if hatchPanelFields.costDetail then
        hatchPanelFields.costDetail.Text =
            formatCostDetail(costEach, costMultiplier, displayCount, affordableCount)
    end
    hatchPanel:SetAttribute("HatchCurrency", eggData.currency)
    hatchPanel:SetAttribute("BaseCostEach", eggData.cost)
    hatchPanel:SetAttribute("CostMultiplier", costMultiplier)
    hatchPanel:SetAttribute("EstimatedCostEach", costEach)
    hatchPanel:SetAttribute("EstimatedTotalCost", totalCost)
    hatchPanel:SetAttribute("EstimatedDisplayCount", displayCount)
    hatchPanel:SetAttribute("EstimatedAffordableCount", affordableCount)
end

function EggInteractionService:BindHelpText(instance, helpText)
    if not instance or not helpText or helpText == "" then
        return
    end

    instance:SetAttribute("HelpText", helpText)
    if instance.MouseEnter then
        instance.MouseEnter:Connect(function()
            self:SetHatchHelp(helpText)
        end)
    end
    if instance.MouseLeave then
        instance.MouseLeave:Connect(function()
            self:SetHatchHelp()
        end)
    end
    if instance.SelectionGained then
        instance.SelectionGained:Connect(function()
            self:SetHatchHelp(helpText)
        end)
    end
    if instance.SelectionLost then
        instance.SelectionLost:Connect(function()
            self:SetHatchHelp()
        end)
    end
end

function EggInteractionService:BindModeHelpText(instance, optionName, cfg)
    if not instance then
        return
    end

    instance:SetAttribute("HelpText", cfg.description or "")
    instance:SetAttribute("LockedHelpText", cfg.locked_description or "")
    instance:SetAttribute("ActiveHelpText", cfg.active_description or "")
    instance:SetAttribute("AvailableHelpText", cfg.available_description or "")
    if instance.MouseEnter then
        instance.MouseEnter:Connect(function()
            self:SetHatchHelp(getModeHelpText(optionName, cfg))
        end)
    end
    if instance.MouseLeave then
        instance.MouseLeave:Connect(function()
            self:SetHatchHelp()
        end)
    end
    if instance.SelectionGained then
        instance.SelectionGained:Connect(function()
            self:SetHatchHelp(getModeHelpText(optionName, cfg))
        end)
    end
    if instance.SelectionLost then
        instance.SelectionLost:Connect(function()
            self:SetHatchHelp()
        end)
    end
end

function EggInteractionService:CreateHatchPanel()
    if hatchPanelGui then
        hatchPanelGui:Destroy()
    end

    local staleGui = player.PlayerGui:FindFirstChild("EggHatchPanel")
    if staleGui then
        staleGui:Destroy()
    end

    hatchPanelGui = nil
    hatchPanel = nil
    hatchPanelFields = {}

    -- The proximity UI (billboard) is owned by EggCurrentTargetService. This builds
    -- the tappable ACTION BAR — buttons are primary input (Jason, mobile playtest:
    -- "no way to click it... couldn't hatch an egg"); E/M/T keys remain as shortcuts.
    if getHatchPanelConfig().show_inline_controls ~= true then
        return
    end
    do -- all buttons config-disabled -> no bar at all (card carries the controls)
        local bc = getHatchPanelConfig().action_bar or {}
        if bc.hatch == false and bc.max == false and bc.auto == false then
            return
        end
    end
    local gui = Instance.new("ScreenGui")
    gui.Name = "EggActionBar"
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 20
    gui.Parent = player:WaitForChild("PlayerGui")
    hatchPanelGui = gui

    local bar = Instance.new("Frame")
    bar.Name = "Bar"
    bar.AnchorPoint = Vector2.new(0.5, 1)
    bar.Position = UDim2.new(0.5, 0, 0.86, 0)
    bar.Size = UDim2.fromOffset(396, 52)
    bar.BackgroundTransparency = 1
    bar.Visible = false
    bar.Parent = gui

    local function makeBtn(text, x, color)
        local b = Instance.new("TextButton")
        b.Size = UDim2.fromOffset(124, 48) -- touch-friendly (>44px)
        b.Position = UDim2.fromOffset(x, 0)
        b.BackgroundColor3 = color
        b.Text = text
        b.TextScaled = true
        b.Font = Enum.Font.GothamBold
        b.TextColor3 = Color3.fromRGB(255, 255, 255)
        b.Parent = bar
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 10)
        c.Parent = b
        local stroke = Instance.new("UIStroke")
        stroke.Color = Color3.fromRGB(20, 20, 28)
        stroke.Thickness = 1.5
        stroke.Parent = b
        return b
    end
    -- buttons per config (Jason: no STOP button — walking away ends auto; the AUTO
    -- button itself is the toggle, tinted while running)
    local barCfg = getHatchPanelConfig().action_bar or {}
    local x = 0
    local autoBtn
    if barCfg.hatch ~= false then
        local b = makeBtn("HATCH", x, Color3.fromRGB(90, 170, 90))
        b.Activated:Connect(function()
            self:OnEKeyPressed()
        end)
        x += 136
    end
    if barCfg.max ~= false then
        local b = makeBtn("MAX", x, Color3.fromRGB(80, 130, 200))
        b.Activated:Connect(function()
            self:OnMaxHatchKeyPressed()
        end)
        x += 136
    end
    if barCfg.auto ~= false then
        autoBtn = makeBtn("AUTO", x, Color3.fromRGB(150, 110, 200))
        autoBtn.Activated:Connect(function()
            self:ToggleAutoHatch()
        end)
    end

    -- visibility + auto-state tint follow the current target (cheap poll)
    task.spawn(function()
        while gui.Parent do
            local target = currentTargetService and currentTargetService:GetCurrentTarget()
            bar.Visible = target ~= nil and target ~= "None"
            if autoBtn then
                autoBtn.BackgroundColor3 = autoHatchEnabled and Color3.fromRGB(220, 82, 95)
                    or Color3.fromRGB(150, 110, 200)
            end
            task.wait(0.25)
        end
    end)
end

function EggInteractionService:CreateAutoDeleteSettings(parent)
    local panelConfig = getHatchPanelConfig()
    local filterConfig = panelConfig.auto_delete or {}

    local header = Instance.new("TextLabel")
    header.Name = "Header"
    header.Size = UDim2.new(1, -108, 0, 24)
    header.Position = UDim2.new(0, 8, 0, 8)
    header.BackgroundTransparency = 1
    header.Text = "Auto-delete"
    header.TextColor3 = Color3.fromRGB(255, 255, 255)
    header.TextScaled = true
    header.Font = Enum.Font.GothamBold
    header.TextXAlignment = Enum.TextXAlignment.Left
    header.Parent = parent
    hatchPanelFields.autoDeleteHeader = header
    self:BindHelpText(header, filterConfig.description)

    local enabledButton = self:CreateButton(
        parent,
        "AutoDeleteEnabled",
        "Off",
        UDim2.new(0, 82, 0, 30),
        UDim2.new(1, -92, 0, 6),
        Color3.fromRGB(80, 85, 98),
        function()
            autoDeleteState.enabled = not autoDeleteState.enabled
            self:SendAutoDeleteFilters()
        end
    )
    hatchPanelFields.filterButtons.enabled = enabledButton
    self:BindHelpText(enabledButton, filterConfig.enabled_description)

    local y = 44
    self:CreateFilterRow(
        parent,
        "Rarities",
        filterConfig.rarity_filters or {},
        "rarities",
        y,
        filterConfig.rarity_description
    )
    self:CreateFilterRow(
        parent,
        "Pets",
        filterConfig.pet_type_filters or {},
        "pet_types",
        y + 58,
        filterConfig.pet_type_description
    )
    self:CreateFilterRow(
        parent,
        "Variants",
        filterConfig.variant_filters or {},
        "variants",
        y + 116,
        filterConfig.variant_description
    )

    local protectedLabel = Instance.new("TextLabel")
    protectedLabel.Name = "ProtectedAutoDeleteRarities"
    protectedLabel.Size = UDim2.new(1, -16, 0, 22)
    protectedLabel.Position = UDim2.new(0, 8, 0, y + 148)
    protectedLabel.BackgroundTransparency = 1
    protectedLabel.Text = getProtectedAutoDeleteText()
    protectedLabel.TextColor3 = Color3.fromRGB(170, 224, 214)
    protectedLabel.TextScaled = true
    protectedLabel.TextWrapped = true
    protectedLabel.Font = Enum.Font.Gotham
    protectedLabel.TextXAlignment = Enum.TextXAlignment.Left
    protectedLabel.Parent = parent
    protectedLabel:SetAttribute(
        "ProtectedRarities",
        table.concat(getProtectedAutoDeleteRarities(), ",")
    )
    self:BindHelpText(protectedLabel, filterConfig.description)
end

function EggInteractionService:CreateModeSettings(parent)
    local panelConfig = getHatchPanelConfig()
    local modeConfig = panelConfig.modes or {}
    local y = 218

    local label = Instance.new("TextLabel")
    label.Name = "ModesLabel"
    label.Size = UDim2.new(0, 74, 0, 28)
    label.Position = UDim2.new(0, 8, 0, y)
    label.BackgroundTransparency = 1
    label.Text = "Modes"
    label.TextColor3 = Color3.fromRGB(205, 214, 230)
    label.TextScaled = true
    label.Font = Enum.Font.Gotham
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = parent

    local orderedModes = { "show", "golden", "charged", "fast", "skip", "silent" }
    local buttonWidth = #orderedModes > 5 and 58 or 70
    local buttonGap = #orderedModes > 5 and 62 or 76
    for index, key in ipairs(orderedModes) do
        local cfg = modeConfig[key]
        if cfg then
            local optionName = cfg.option or key
            local button = self:CreateButton(
                parent,
                "Mode_" .. optionName,
                cfg.label or titleCaseId(key),
                UDim2.new(0, buttonWidth, 0, 28),
                UDim2.new(0, 88 + (index - 1) * buttonGap, 0, y),
                Color3.fromRGB(80, 85, 98),
                function()
                    self:SetHatchModeState(optionName, hatchModeState[optionName] ~= true)
                end
            )
            hatchPanelFields.modeButtons[optionName] = button
            button:SetAttribute("ModeOption", optionName)
            button:SetAttribute("ModeLabel", cfg.label or titleCaseId(key))
            self:BindModeHelpText(button, optionName, cfg)
        end
    end

    local modeStatus = Instance.new("TextLabel")
    modeStatus.Name = "ModeStatus"
    modeStatus.Size = UDim2.new(1, -16, 0, 26)
    modeStatus.Position = UDim2.new(0, 8, 0, y + 34)
    modeStatus.BackgroundTransparency = 1
    modeStatus.Text = ""
    modeStatus.TextColor3 = Color3.fromRGB(180, 190, 210)
    modeStatus.TextScaled = true
    modeStatus.TextWrapped = true
    modeStatus.Font = Enum.Font.Gotham
    modeStatus.TextXAlignment = Enum.TextXAlignment.Left
    modeStatus.Parent = parent
    hatchPanelFields.modeStatus = modeStatus
end

function EggInteractionService:CreateFilterRow(
    parent,
    labelText,
    filterIds,
    bucketName,
    y,
    helpText
)
    local label = Instance.new("TextLabel")
    label.Name = bucketName .. "Label"
    label.Size = UDim2.new(0, 74, 0, 28)
    label.Position = UDim2.new(0, 8, 0, y)
    label.BackgroundTransparency = 1
    label.Text = labelText
    label.TextColor3 = Color3.fromRGB(205, 214, 230)
    label.TextScaled = true
    label.Font = Enum.Font.Gotham
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = parent
    self:BindHelpText(label, helpText)

    hatchPanelFields.filterButtons[bucketName] = hatchPanelFields.filterButtons[bucketName] or {}
    for index, id in ipairs(filterIds) do
        local x = 88 + ((index - 1) % 4) * 92
        local row = math.floor((index - 1) / 4)
        local button = self:CreateButton(
            parent,
            bucketName .. "_" .. id,
            getFilterDisplayName(id),
            UDim2.new(0, 84, 0, 28),
            UDim2.new(0, x, 0, y + row * 32),
            Color3.fromRGB(80, 85, 98),
            function()
                autoDeleteState[bucketName] = autoDeleteState[bucketName] or {}
                autoDeleteState[bucketName][id] = autoDeleteState[bucketName][id] ~= true
                self:SendAutoDeleteFilters()
            end
        )
        hatchPanelFields.filterButtons[bucketName][id] = button
        self:BindHelpText(button, helpText)
    end
end

function EggInteractionService:CreateHatchHelpText(parent)
    local panelConfig = getHatchPanelConfig()
    local helpConfig = panelConfig.help or {}
    local helpText = Instance.new("TextLabel")
    helpText.Name = "HelpText"
    helpText.Size = UDim2.new(1, -16, 0, 42)
    helpText.Position =
        UDim2.new(0, 8, 0, math.max(252, (tonumber(panelConfig.settings_height) or 304) - 50))
    helpText.BackgroundColor3 = Color3.fromRGB(25, 28, 36)
    helpText.BackgroundTransparency = 0.12
    helpText.BorderSizePixel = 0
    helpText.Text = tostring(helpConfig.default or "")
    helpText.TextColor3 = Color3.fromRGB(205, 214, 230)
    helpText.TextScaled = true
    helpText.TextWrapped = true
    helpText.Font = Enum.Font.Gotham
    helpText.TextXAlignment = Enum.TextXAlignment.Left
    helpText.Parent = parent

    local padding = Instance.new("UIPadding")
    padding.PaddingLeft = UDim.new(0, 10)
    padding.PaddingRight = UDim.new(0, 10)
    padding.Parent = helpText

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = helpText

    hatchPanelFields.helpText = helpText
end

function EggInteractionService:SendAutoDeleteFilters()
    Signals.AutoDelete_SetFilters:FireServer({
        enabled = autoDeleteState.enabled == true,
        rarities = setToArray(autoDeleteState.rarities),
        pet_types = setToArray(autoDeleteState.pet_types),
        variants = setToArray(autoDeleteState.variants),
    })
    self:RefreshAutoDeleteButtons()
    self:SetPanelStatus("Filters saved", false)
end

function EggInteractionService:ApplyAutoDeleteStatus(status)
    if type(status) ~= "table" then
        return
    end

    autoDeleteState.enabled = status.enabled == true
    autoDeleteState.rarities = asSet(status.rarities)
    autoDeleteState.pet_types = asSet(status.pet_types)
    autoDeleteState.variants = asSet(status.variants)
    self:RefreshAutoDeleteButtons()
end

function EggInteractionService:RefreshAutoDeleteButtons()
    if not hatchPanelFields.filterButtons then
        return
    end

    local enabledButton = hatchPanelFields.filterButtons.enabled
    local summaryText, totalCount, rarityCount, petTypeCount, variantCount =
        formatAutoDeleteSummary()
    if hatchPanelFields.autoDeleteHeader then
        hatchPanelFields.autoDeleteHeader.Text = summaryText
        hatchPanelFields.autoDeleteHeader:SetAttribute("SelectedFilterCount", totalCount)
        hatchPanelFields.autoDeleteHeader:SetAttribute("SelectedRarityFilterCount", rarityCount)
        hatchPanelFields.autoDeleteHeader:SetAttribute("SelectedPetTypeFilterCount", petTypeCount)
        hatchPanelFields.autoDeleteHeader:SetAttribute("SelectedVariantFilterCount", variantCount)
        hatchPanelFields.autoDeleteHeader:SetAttribute("AutoDeleteEnabled", autoDeleteState.enabled)
    end
    if enabledButton then
        enabledButton.Text = autoDeleteState.enabled and "On" or "Off"
        enabledButton:SetAttribute("SelectedFilterCount", totalCount)
        enabledButton:SetAttribute("SelectedRarityFilterCount", rarityCount)
        enabledButton:SetAttribute("SelectedPetTypeFilterCount", petTypeCount)
        enabledButton:SetAttribute("SelectedVariantFilterCount", variantCount)
        enabledButton.BackgroundColor3 = autoDeleteState.enabled and Color3.fromRGB(39, 161, 92)
            or Color3.fromRGB(80, 85, 98)
    end

    for bucketName, buttons in pairs(hatchPanelFields.filterButtons) do
        if type(buttons) == "table" then
            for id, button in pairs(buttons) do
                local enabled = autoDeleteState[bucketName]
                    and autoDeleteState[bucketName][id] == true
                button.BackgroundColor3 = enabled and Color3.fromRGB(220, 82, 95)
                    or Color3.fromRGB(80, 85, 98)
            end
        end
    end
end

function EggInteractionService:RefreshModeButtons()
    if not hatchPanelFields.modeButtons then
        return
    end

    local activeModes = {}
    local lockedModes = {}
    for optionName, button in pairs(hatchPanelFields.modeButtons) do
        local owned = isModeOwned(optionName)
        local enabled = hatchModeState[optionName] == true
        local label = button:GetAttribute("ModeLabel") or titleCaseId(optionName)
        local detailText = getModeDetailText(optionName)
        local statusLabel = detailText ~= "" and (label .. " (" .. detailText .. ")") or label
        local stub = getModeStub(optionName) or {}
        button:SetAttribute("ModeDetail", detailText)
        button:SetAttribute("CostMultiplier", tonumber(stub.cost_multiplier) or 1)
        button:SetAttribute("LuckBonus", tonumber(stub.luck_bonus) or 0)
        button:SetAttribute("SecretLuckBonus", tonumber(stub.secret_luck_bonus) or 0)
        if not owned then
            if enabled then
                hatchModeState[optionName] = false
            end
            button.BackgroundColor3 = Color3.fromRGB(58, 62, 76)
            button.TextColor3 = Color3.fromRGB(150, 158, 176)
            button:SetAttribute("ModeOwned", false)
            button:SetAttribute("ModeState", "locked")
            table.insert(lockedModes, statusLabel)
        else
            button.BackgroundColor3 = enabled and Color3.fromRGB(244, 172, 54)
                or Color3.fromRGB(80, 85, 98)
            button.TextColor3 = Color3.fromRGB(255, 255, 255)
            button:SetAttribute("ModeOwned", true)
            button:SetAttribute("ModeState", enabled and "active" or "available")
            if enabled then
                table.insert(activeModes, statusLabel)
            end
        end
        button:SetAttribute("CurrentHelpText", getModeHelpText(optionName))
    end

    if hatchPanelFields.modeStatus then
        local parts = {}
        if #activeModes > 0 then
            table.insert(parts, "Active: " .. table.concat(activeModes, ", "))
        end
        if #lockedModes > 0 then
            table.insert(parts, "Locked: " .. table.concat(lockedModes, ", "))
        end
        hatchPanelFields.modeStatus.Text = #parts > 0 and table.concat(parts, "  |  ")
            or "Modes available"
    end
end

function EggInteractionService:ApplyPersistedHatchModes(options)
    options = options or {}
    local persistedModes = getPersistedHatchModes()
    if not persistedModes then
        return
    end

    for optionName in pairs(hatchModeState) do
        if persistedModes[optionName] ~= nil then
            hatchModeState[optionName] = persistedModes[optionName] == true
        end
    end

    if options.persist ~= false then
        persistHatchModes()
    else
        lastPersistedHatchModesKey = hatchModesKey(currentHatchModes())
    end
    self:RefreshModeButtons()
    self:UpdateHatchPanel()
end

function EggInteractionService:DisconnectSettingsConnections()
    for _, connection in ipairs(settingsConnections) do
        connection:Disconnect()
    end
    settingsConnections = {}
end

function EggInteractionService:BindReplicatedHatchSettings()
    self:DisconnectSettingsConnections()

    task.spawn(function()
        local settingsFolder = player:WaitForChild("Settings", 15)
        local autoFolder = settingsFolder and settingsFolder:WaitForChild("AutoSystems", 15)
        local hatchFolder = autoFolder and autoFolder:WaitForChild("Hatch", 15)
        if not hatchFolder then
            return
        end

        local actionValue = hatchFolder:FindFirstChild("ActionMode")
        if actionValue and actionValue:IsA("StringValue") then
            local function applyActionMode()
                hatchActionMode = sanitizeHatchActionMode(actionValue.Value)
                self:UpdateHatchPanel()
            end
            applyActionMode()
            table.insert(
                settingsConnections,
                actionValue:GetPropertyChangedSignal("Value"):Connect(applyActionMode)
            )
        end

        local autoDeleteFolder = autoFolder:FindFirstChild("AutoDelete")
        if autoDeleteFolder then
            local filterConnections = {}
            local function track(connection)
                table.insert(settingsConnections, connection)
                table.insert(filterConnections, connection)
            end
            local function disconnectFilterConnections()
                for _, connection in ipairs(filterConnections) do
                    connection:Disconnect()
                end
                filterConnections = {}
            end
            local function applyAutoDeleteValue()
                local status = getPersistedAutoDeleteStatus()
                if status then
                    self:ApplyAutoDeleteStatus(status)
                end
            end
            local function bindFilterFolder(folder)
                if not folder or not folder:IsA("Folder") then
                    return
                end

                track(folder.ChildAdded:Connect(function(child)
                    if child:IsA("BoolValue") then
                        track(child:GetPropertyChangedSignal("Value"):Connect(applyAutoDeleteValue))
                    end
                    applyAutoDeleteValue()
                end))
                track(folder.ChildRemoved:Connect(applyAutoDeleteValue))
                for _, child in ipairs(folder:GetChildren()) do
                    if child:IsA("BoolValue") then
                        track(child:GetPropertyChangedSignal("Value"):Connect(applyAutoDeleteValue))
                    end
                end
            end
            local function bindAutoDeleteFolder()
                disconnectFilterConnections()
                local enabledValue = autoDeleteFolder:FindFirstChild("Enabled")
                if enabledValue and enabledValue:IsA("BoolValue") then
                    track(
                        enabledValue:GetPropertyChangedSignal("Value"):Connect(applyAutoDeleteValue)
                    )
                end
                bindFilterFolder(autoDeleteFolder:FindFirstChild("Rarities"))
                bindFilterFolder(autoDeleteFolder:FindFirstChild("PetTypes"))
                bindFilterFolder(autoDeleteFolder:FindFirstChild("Variants"))
                track(autoDeleteFolder.ChildAdded:Connect(function()
                    bindAutoDeleteFolder()
                    applyAutoDeleteValue()
                end))
                track(autoDeleteFolder.ChildRemoved:Connect(function()
                    bindAutoDeleteFolder()
                    applyAutoDeleteValue()
                end))
                applyAutoDeleteValue()
            end
            bindAutoDeleteFolder()
        end

        local selectedValue = hatchFolder:FindFirstChild("SelectedCount")
        if selectedValue and selectedValue:IsA("IntValue") then
            local function applySelectedCount()
                selectedHatchCount = clampSelectedCount(selectedValue.Value)
                lastPersistedHatchCount = selectedHatchCount
                self:UpdateHatchPanel()
                if lastHatchPanelEggType then
                    self:RefreshHatchCostDisplay(lastHatchPanelEggType)
                end
                if hatchPanelFields.count then
                    hatchPanelFields.count.Text = "x" .. tostring(selectedHatchCount)
                end
            end
            applySelectedCount()
            table.insert(
                settingsConnections,
                selectedValue:GetPropertyChangedSignal("Value"):Connect(applySelectedCount)
            )
        end

        local modesFolder = hatchFolder:FindFirstChild("Modes")
        if modesFolder then
            local function bindModeValue(value)
                if not value:IsA("BoolValue") or hatchModeState[value.Name] == nil then
                    return
                end

                local function applyModeValue()
                    hatchModeState[value.Name] = value.Value == true
                    lastPersistedHatchModesKey = hatchModesKey(currentHatchModes())
                    self:RefreshModeButtons()
                    self:UpdateHatchPanel()
                end

                applyModeValue()
                table.insert(
                    settingsConnections,
                    value:GetPropertyChangedSignal("Value"):Connect(applyModeValue)
                )
            end

            for _, value in ipairs(modesFolder:GetChildren()) do
                bindModeValue(value)
            end
            table.insert(settingsConnections, modesFolder.ChildAdded:Connect(bindModeValue))
        end
    end)
end

function EggInteractionService:SetHatchModeState(optionName, enabled, options)
    options = options or {}
    if hatchModeState[optionName] == nil then
        return false
    end

    hatchModeState[optionName] = enabled == true and isModeOwned(optionName)
    if options.persist ~= false then
        persistHatchModes()
    end
    self:RefreshModeButtons()
    self:UpdateHatchPanel()
    return true
end

function EggInteractionService:BuildHatchOptions()
    return {
        showHatch = hatchModeState.showHatch ~= false,
        goldenMode = hatchModeState.goldenMode == true,
        chargedMode = hatchModeState.chargedMode == true,
        fastHatch = hatchModeState.fastHatch == true,
        skipHatch = hatchModeState.skipHatch == true,
        silentHatch = hatchModeState.silentHatch == true,
    }
end

function EggInteractionService:ApplyResolvedHatchOptions(options)
    if type(options) ~= "table" then
        return
    end

    for optionName in pairs(hatchModeState) do
        if options[optionName] ~= nil then
            hatchModeState[optionName] = options[optionName] == true
        end
    end
    persistHatchModes()
    self:RefreshModeButtons()
    self:UpdateHatchPanel()
end

function EggInteractionService:HandleHatchError(result)
    local message = result.message or "Purchase failed"
    if result.code == "feature_locked" then
        local lockedMode = result.details and result.details.mode
        if lockedMode and hatchModeState[lockedMode] ~= nil then
            hatchModeState[lockedMode] = false
        elseif hatchModeState.goldenMode == true then
            hatchModeState.goldenMode = false
        end
        persistHatchModes()
        self:RefreshModeButtons()
        self:UpdateHatchPanel()
        message = message .. " Turn off the locked mode or unlock it first."
    end

    self:ShowErrorMessage(message)
    self:SetPanelStatus(message, true)
end

function EggInteractionService:SetSelectedHatchCount(count, options)
    options = options or {}
    selectedHatchCount = clampSelectedCount(count)
    if options.persist ~= false then
        persistSelectedHatchCount(selectedHatchCount)
    end
    self:UpdateHatchPanel()
    if lastHatchPanelEggType then
        self:RefreshHatchCostDisplay(lastHatchPanelEggType)
    end
    if hatchPanelFields.count then
        hatchPanelFields.count.Text = "x" .. tostring(selectedHatchCount)
    end
end

function EggInteractionService:SubmitHatchCountInput(text)
    local parsed = tostring(text or ""):match("%d+")
    if parsed then
        self:SetSelectedHatchCount(tonumber(parsed))
    elseif hatchPanelFields.count then
        hatchPanelFields.count.Text = "x" .. tostring(selectedHatchCount)
    end
    return selectedHatchCount
end

function EggInteractionService:SetHatchSettingsOpen(open)
    hatchSettingsOpen = open == true
    self:UpdateHatchPanel()
end

function EggInteractionService:SetHatchActionMode(actionMode, options)
    options = options or {}
    hatchActionMode = sanitizeHatchActionMode(actionMode)
    if options.persist ~= false then
        persistHatchActionMode(hatchActionMode)
    end
    -- Max/Auto means "hatch everything I'm entitled to": snap the selected count to the CURRENT
    -- effective max (#176 — previously Auto kept a stale lower selection until one manual Max hatch).
    if hatchActionMode == "max" or hatchActionMode == "auto" then
        self:SetSelectedHatchCount(getEffectiveMaxHatchCount(), { persist = options.persist })
    end
    self:UpdateHatchPanel()
    return hatchActionMode
end

-- Read-only snapshot for EXTERNAL hatch controls (the inventory header strip):
-- auto state, selected count, and the live effective max.
function EggInteractionService:GetHatchUiState()
    local target = currentTargetService and currentTargetService:GetCurrentTarget()
    return {
        auto = autoHatchEnabled, -- the RUNNING loop (an action state)
        mode = hatchActionMode, -- the persisted SETTING ("single"/"max"/"auto")
        autoOwned = isAutoHatchOwned(),
        count = selectedHatchCount,
        max = getEffectiveMaxHatchCount(),
        hasTarget = target ~= nil and target ~= "None",
    }
end

function EggInteractionService:HatchSelectedCount(purchaseType)
    if not currentTargetService then
        return false
    end

    local currentTarget = currentTargetService:GetCurrentTarget()
    if currentTarget == "None" or not currentTarget then
        self:SetPanelStatus("Move near an egg", true)
        return false
    end

    return self:HandleEggPurchase(currentTarget, selectedHatchCount, purchaseType or "Selected")
end

function EggInteractionService:ComputeHatchPanelLayout(viewportSize, settingsOpenOverride)
    local panelConfig = getHatchPanelConfig()
    local width = tonumber(panelConfig.width) or 500
    local baseHeight = tonumber(panelConfig.height) or 176
    local settingsHeight = tonumber(panelConfig.settings_height) or 168
    local settingsOpen = settingsOpenOverride
    if settingsOpen == nil then
        settingsOpen = hatchSettingsOpen
    end
    local height = settingsOpen and (baseHeight + settingsHeight) or baseHeight
    local bottomOffset = tonumber(panelConfig.bottom_offset) or 126
    local responsive = panelConfig.responsive or {}
    local margin = math.max(0, tonumber(responsive.margin) or 16)
    local minScale = math.clamp(tonumber(responsive.min_scale) or 0.64, 0.25, 1)
    local maxScale = math.clamp(tonumber(responsive.max_scale) or 1, 0.25, 2)
    if maxScale < minScale then
        maxScale = minScale
    end

    viewportSize = viewportSize or getViewportSize()
    local viewportWidth = math.max(1, tonumber(viewportSize.X) or width + margin * 2)
    local viewportHeight = math.max(1, tonumber(viewportSize.Y) or height + bottomOffset + margin)
    local widthFit = (viewportWidth - margin * 2) / math.max(1, width)
    local heightFit = (viewportHeight - margin * 2) / math.max(1, height + bottomOffset)
    local fitScale = math.min(widthFit, heightFit, maxScale)
    local scale = fitScale >= minScale and fitScale or math.max(0.25, fitScale)
    scale = math.clamp(scale, 0.25, maxScale)

    return {
        width = width,
        height = height,
        bottomOffset = bottomOffset,
        margin = margin,
        scale = scale,
        scaledWidth = width * scale,
        scaledHeight = height * scale,
        viewportWidth = viewportWidth,
        viewportHeight = viewportHeight,
        fitsWidth = (width * scale) <= math.max(0, viewportWidth - margin * 2) + 0.01,
        fitsHeight = ((height + bottomOffset) * scale)
            <= math.max(0, viewportHeight - margin * 2) + 0.01,
    }
end

function EggInteractionService:UpdateHatchPanel()
    if not hatchPanel then
        return
    end

    local panelConfig = getHatchPanelConfig()
    local currentTarget = currentTargetService and currentTargetService:GetCurrentTarget() or "None"
    local visible = currentTarget ~= nil and currentTarget ~= "None"
    hatchPanel.Visible = visible
    if not visible then
        return
    end

    local effectiveMaxCount = getEffectiveMaxHatchCount()
    if selectedHatchCount > effectiveMaxCount then
        selectedHatchCount = effectiveMaxCount
    end

    local layout = self:ComputeHatchPanelLayout(getViewportSize(), hatchSettingsOpen)

    hatchPanel.Size = UDim2.new(0, layout.width, 0, layout.height)
    hatchPanel.Position = UDim2.new(0.5, 0, 1, -math.floor(layout.bottomOffset * layout.scale))
    hatchPanel:SetAttribute("ResponsiveScale", layout.scale)
    hatchPanel:SetAttribute("ResponsiveScaledWidth", layout.scaledWidth)
    hatchPanel:SetAttribute("ResponsiveScaledHeight", layout.scaledHeight)
    hatchPanel:SetAttribute("ResponsiveFitsWidth", layout.fitsWidth)
    hatchPanel:SetAttribute("ResponsiveFitsHeight", layout.fitsHeight)
    hatchPanel:SetAttribute("ResponsiveViewportWidth", layout.viewportWidth)
    hatchPanel:SetAttribute("ResponsiveViewportHeight", layout.viewportHeight)
    if hatchPanelFields.responsiveScale then
        hatchPanelFields.responsiveScale.Scale = layout.scale
    end
    if hatchPanelFields.settings then
        hatchPanelFields.settings.Visible = hatchSettingsOpen
    end

    lastHatchPanelEggType = currentTarget
    self:RefreshHatchCostDisplay(currentTarget)

    hatchPanelFields.count.Text = "x" .. tostring(selectedHatchCount)
    if hatchPanelFields.actionMode then
        hatchPanelFields.actionMode.Text = getHatchActionModeLabel(hatchActionMode)
        hatchPanelFields.actionMode:SetAttribute("ActionMode", hatchActionMode)
    end

    local inlineControlsVisible = panelConfig.show_inline_controls == true
    for _, fieldName in ipairs({
        "count",
        "countDownButton",
        "countUpButton",
        "hatchButton",
        "maxButton",
        "autoButton",
        "settingsButton",
    }) do
        if hatchPanelFields[fieldName] then
            hatchPanelFields[fieldName].Visible = inlineControlsVisible
        end
    end
    local busy = hatchRequestInFlight == true
    local autoOwned = isAutoHatchOwned()
    hatchPanelFields.hatchButton.Active = not busy
    hatchPanelFields.maxButton.Active = not busy
    hatchPanelFields.autoButton.Active = not busy
    hatchPanelFields.hatchButton.AutoButtonColor = not busy
    hatchPanelFields.maxButton.AutoButtonColor = not busy
    hatchPanelFields.autoButton.AutoButtonColor = not busy
    hatchPanelFields.hatchButton.BackgroundColor3 = busy and Color3.fromRGB(70, 76, 90)
        or Color3.fromRGB(31, 138, 255)
    hatchPanelFields.maxButton.BackgroundColor3 = busy and Color3.fromRGB(70, 76, 90)
        or Color3.fromRGB(72, 82, 103)
    hatchPanelFields.autoButton.Text = autoHatchEnabled and "Stop" or "Auto"
    hatchPanelFields.autoButton.BackgroundColor3 = busy and Color3.fromRGB(70, 76, 90)
        or autoHatchEnabled and Color3.fromRGB(220, 82, 95)
        or autoOwned and Color3.fromRGB(39, 161, 92)
        or Color3.fromRGB(58, 62, 76)
    hatchPanelFields.autoButton.TextColor3 = autoOwned and Color3.fromRGB(255, 255, 255)
        or Color3.fromRGB(150, 158, 176)
    hatchPanel:SetAttribute("MaxHatchCount", getMaxHatchCount())
    hatchPanel:SetAttribute("MaxEntitledHatchCount", effectiveMaxCount)
    hatchPanel:SetAttribute("AutoHatchOwned", autoOwned)
    hatchPanel:SetAttribute("HatchActionMode", hatchActionMode)
    hatchPanel:SetAttribute("InlineControlsVisible", inlineControlsVisible)
    hatchPanelFields.count:SetAttribute("MaxEntitledHatchCount", effectiveMaxCount)
    hatchPanelFields.maxButton:SetAttribute("MaxEntitledHatchCount", effectiveMaxCount)
    hatchPanelFields.autoButton:SetAttribute("ModeOwned", autoOwned)
    hatchPanelFields.autoButton:SetAttribute("ModeState", autoOwned and "available" or "locked")

    if os.clock() - lastStatusAt > (tonumber(panelConfig.status_display_time) or 3) then
        hatchPanelFields.status.Text = ""
    end
    self:RefreshAutoDeleteButtons()
    self:RefreshModeButtons()
end

-- === E KEY INTERACTION ===

function EggInteractionService:OnEKeyPressed()
    -- Get current target from the targeting service
    if not currentTargetService then
        Logger:Warn("CurrentTargetService not available", { context = "EggInteractionService" })
        return
    end

    local currentTarget = currentTargetService:GetCurrentTarget()
    if currentTarget == "None" or not currentTarget then
        Logger:Debug("No egg currently targeted", { context = "EggInteractionService" })
        return
    end

    Logger:Info("E pressed - attempting hatch", {
        context = "EggInteractionService",
        eggType = currentTarget,
        actionMode = hatchActionMode,
        requestedCount = selectedHatchCount,
    })
    if hatchActionMode == "max" then
        self:OnMaxHatchKeyPressed()
    elseif hatchActionMode == "auto" then
        self:ToggleAutoHatch()
    else
        -- MANUAL = one hatch SESSION per press, of the SELECTED count (Jason: "not
        -- one egg, one hatch session — it is manual"). The server clamps the count
        -- to entitlement + affordability either way.
        self:HandleEggPurchase(currentTarget, selectedHatchCount, "Selected")
    end
end

function EggInteractionService:OnMaxHatchKeyPressed()
    if not currentTargetService then
        Logger:Warn("CurrentTargetService not available", { context = "EggInteractionService" })
        return
    end

    local currentTarget = currentTargetService:GetCurrentTarget()
    if currentTarget == "None" or not currentTarget then
        return
    end

    local maxCount = getEffectiveMaxHatchCount()
    self:SetSelectedHatchCount(maxCount)
    self:HandleEggPurchase(currentTarget, maxCount, "Max")
end

function EggInteractionService:ToggleAutoHatch()
    if autoHatchEnabled then
        autoHatchEnabled = false
        autoHatchSessionId += 1
        self:SetPanelStatus("Auto hatch stopped", false)
        self:UpdateHatchPanel()
        return
    end

    if not isAutoHatchOwned() then
        self:SetPanelStatus("Auto hatch locked", true)
        self:ShowErrorMessage("Auto hatch locked")
        self:UpdateHatchPanel()
        return
    end

    if not currentTargetService then
        Logger:Warn("CurrentTargetService not available", { context = "EggInteractionService" })
        return
    end

    local currentTarget = currentTargetService:GetCurrentTarget()
    if currentTarget == "None" or not currentTarget then
        self:SetPanelStatus("Move near an egg", true)
        return
    end

    autoHatchEnabled = true
    autoHatchSessionId += 1
    local sessionId = autoHatchSessionId
    local hatching = getHatchingConfig()
    local waitSeconds = tonumber(hatching.auto_loop_delay)
        or tonumber(eggSystemConfig.cooldowns.purchase_cooldown)
        or 3
    self:SetPanelStatus("Auto hatch running", false)
    self:UpdateHatchPanel()

    task.spawn(function()
        while autoHatchEnabled and sessionId == autoHatchSessionId do
            local target = currentTargetService:GetCurrentTarget()
            if target == "None" or not target then
                autoHatchEnabled = false
                self:SetPanelStatus("Auto hatch stopped: too far away", true)
                break
            end

            -- Pace on the hatch lock: wait for any in-progress animation to finish before the
            -- next request, so the re-entry gate doesn't read as a hard failure and stop auto.
            local readyService = getHatchingService()
            while
                readyService
                and not readyService:IsHatchReady()
                and autoHatchEnabled
                and sessionId == autoHatchSessionId
            do
                task.wait(0.1)
            end
            if not (autoHatchEnabled and sessionId == autoHatchSessionId) then
                break
            end

            local ok = self:HandleEggPurchase(target, selectedHatchCount, "Auto", sessionId)
            if not ok then
                if autoHatchEnabled and sessionId == autoHatchSessionId then
                    autoHatchEnabled = false
                    self:SetPanelStatus("Auto hatch stopped", true)
                end
                break
            end

            task.wait(waitSeconds)
        end
        self:UpdateHatchPanel()
    end)
end

-- === EGG PURCHASE HANDLING ===

function EggInteractionService:HandleEggPurchase(
    eggType,
    requestedCount,
    purchaseType,
    autoSessionId
)
    -- Gate re-entry. hatchRequestInFlight covers the server round-trip; the hatching service's
    -- IsHatchReady() covers the *animation* window that runs after the response (the gap where a
    -- rapid second hatch used to overlap and the new pets failed to display).
    local hatchingService = getHatchingService()
    if hatchRequestInFlight or (hatchingService and not hatchingService:IsHatchReady()) then
        self:ShowErrorMessage("Please wait before hatching again")
        return false
    end

    requestedCount = requestedCount or 1
    purchaseType = purchaseType or "Single"
    Logger:Info("Requesting egg hatch", {
        context = "EggInteractionService",
        eggType = eggType,
        requestedCount = requestedCount,
        purchaseType = purchaseType,
    })

    -- Validate egg type
    local eggData = petConfig.egg_sources[eggType]
    if not eggData then
        Logger:Warn("Invalid egg type", { context = "EggInteractionService", eggType = eggType })
        self:ShowErrorMessage("Invalid egg type")
        return false
    end

    -- Client-side distance check (like working game)
    if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
        Logger:Warn("No character or root part", { context = "EggInteractionService" })
        self:ShowErrorMessage("Character not ready")
        return false
    end

    -- Find egg in workspace
    local eggInWorkspace = self:FindEggByType(eggType)
    if not eggInWorkspace then
        Logger:Warn("Egg not found in workspace", { context = "EggInteractionService" })
        self:ShowErrorMessage("Egg not found")
        return false
    end

    local anchor = EggWorldQuery.GetAnchor(eggInWorkspace)

    if not anchor then
        Logger:Warn("No anchor found on egg", { context = "EggInteractionService" })
        self:ShowErrorMessage("Egg configuration error")
        return false
    end

    local distance = (player.Character.HumanoidRootPart.Position - anchor.Position).Magnitude
    if distance > eggSystemConfig.proximity.max_distance then
        Logger:Info("Too far from egg", { context = "EggInteractionService", distance = distance })
        self:ShowErrorMessage(eggSystemConfig.messages.too_far_away)
        return false
    end

    Logger:Debug(
        "Distance check passed",
        { context = "EggInteractionService", distance = distance }
    )

    -- Call server using RemoteFunction (like working game)
    local eggRemote = ReplicatedStorage:FindFirstChild("EggOpened")
    if not eggRemote then
        Logger:Error("EggOpened RemoteFunction not found", { context = "EggInteractionService" })
        self:ShowErrorMessage("Server not ready, please restart game")
        return false
    end

    hatchRequestInFlight = true
    self:UpdateHatchPanel()
    local success, result, message = pcall(function()
        return eggRemote:InvokeServer({
            eggType = eggType,
            requestedCount = requestedCount,
            purchaseType = purchaseType,
            options = self:BuildHatchOptions(),
            autoSessionId = autoSessionId,
        })
    end)
    hatchRequestInFlight = false
    self:UpdateHatchPanel()

    if autoSessionId ~= nil and autoSessionId ~= autoHatchSessionId then
        return false
    end

    if success then
        Logger:Info(
            "Server call successful",
            { context = "EggInteractionService", resultType = typeof(result) }
        )
        if type(result) == "table" and result.success then
            Logger:Info("Purchase successful", { context = "EggInteractionService" })
            self:ApplyResolvedHatchOptions(result.options)
            self:ShowHatchingResults(result)
            local status = "Hatched " .. tostring(result.hatchCount or 1)
            if result.stopReason then
                status ..= " - " .. formatStopReason(result.stopReason)
            end
            if autoSessionId ~= nil and isTerminalAutoStopReason(result.stopReason) then
                autoHatchEnabled = false
                autoHatchSessionId += 1
                status = "Auto hatch stopped: " .. formatStopReason(result.stopReason)
            end
            self:SetPanelStatus(status, false)
            return true
        elseif type(result) == "table" and result.success == false then
            Logger:Warn("Purchase failed", {
                context = "EggInteractionService",
                message = result.message or "Purchase failed",
                code = result.code,
            })
            self:HandleHatchError(result)
            if autoSessionId ~= nil and autoSessionId == autoHatchSessionId then
                local stopReason = formatAutoErrorStopReason(result)
                if stopReason then
                    autoHatchEnabled = false
                    autoHatchSessionId += 1
                    self:SetPanelStatus("Auto hatch stopped: " .. stopReason, true)
                end
            end
            return false
        elseif result == "Error" then
            Logger:Warn(
                "Purchase failed",
                { context = "EggInteractionService", message = message or "Unknown error" }
            )
            self:ShowErrorMessage(message or "Purchase failed")
            self:SetPanelStatus(message or "Purchase failed", true)
            return false
        elseif type(result) == "table" and result.Pet then
            -- Handle successful result without explicit success flag
            Logger:Info(
                "Purchase successful (legacy format)",
                { context = "EggInteractionService" }
            )
            self:ShowHatchingResults(result)
            self:SetPanelStatus("Hatched 1", false)
            return true
        else
            Logger:Warn(
                "Unexpected result format",
                { context = "EggInteractionService", resultType = typeof(result) }
            )
            self:ShowErrorMessage("Unexpected server response")
            self:SetPanelStatus("Unexpected server response", true)
            return false
        end
    else
        Logger:Error(
            "Server call failed",
            { context = "EggInteractionService", error = tostring(result) }
        )
        self:ShowErrorMessage("Connection error")
        self:SetPanelStatus("Connection error", true)
        return false
    end
end

function EggInteractionService:FindEggByType(eggType)
    return EggWorldQuery.FindEggByType(eggType)
end

-- === UI FEEDBACK ===

function EggInteractionService:ShowErrorMessage(errorMessage)
    self:SetPanelStatus(errorMessage, true)

    -- Create simple error notification
    local errorGui = Instance.new("ScreenGui")
    errorGui.Name = "EggError"
    errorGui.ResetOnSpawn = false
    errorGui.Parent = player.PlayerGui

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 300, 0, 80)
    frame.Position = UDim2.new(0.5, -150, 0.8, -40)
    frame.BackgroundColor3 = Color3.fromRGB(220, 53, 69)
    frame.BorderSizePixel = 0
    frame.Parent = errorGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = frame

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -20, 1, -10)
    label.Position = UDim2.new(0, 10, 0, 5)
    label.BackgroundTransparency = 1
    label.Text = "❌ " .. errorMessage
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextScaled = true
    label.Font = Enum.Font.Gotham
    label.Parent = frame

    -- Slide in animation
    frame.Position = UDim2.new(0.5, -150, 1, 0)
    local tween = TweenService:Create(
        frame,
        TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        {
            Position = UDim2.new(0.5, -150, 0.8, -40),
        }
    )
    tween:Play()

    -- Auto-remove after configured time
    task.spawn(function()
        task.wait(eggSystemConfig.cooldowns.ui_error_display_time)
        errorGui:Destroy()
    end)
end

function EggInteractionService:ShowHatchingResults(result)
    if
        type(result) == "table"
        and result.options
        and (result.options.skipHatch == true or result.options.showHatch == false)
    then
        return
    end

    -- Reduce console noise: keep egg-related logs through Logger only
    local activeLogger = self._modules and self._modules.Logger
    if activeLogger and activeLogger.Info then
        activeLogger:Info("Hatched pet", {
            pet = result.Pet,
            variant = result.Type,
            power = result.Power,
            hatchCount = result.hatchCount or 1,
        })
    end

    -- Use the full egg hatching animation system instead of simple notification
    local success, hatchingService = pcall(function()
        return require(ReplicatedStorage.Shared.Services.EggHatchingService)
    end)

    if success and hatchingService then
        -- Prepare egg data for animation. Batch responses carry one entry per egg;
        -- legacy single-hatch responses still flow through the same path.
        local eggsData = {}
        local resultEntries = type(result.results) == "table" and result.results or { result }
        for _, entry in ipairs(resultEntries) do
            local eggType = entry.EggType or result.EggType or "basic_egg"
            table.insert(eggsData, {
                petType = entry.Pet or entry.pet,
                variant = entry.Type or entry.variant,
                power = entry.Power or entry.power,
                eggType = eggType,
                imageId = self:GetEggImageId(eggType),
                petImageId = self:GetPetImageId(
                    entry.Pet or entry.pet,
                    entry.Type or entry.variant
                ),
                animation = result.animation,
                hatchOptions = result.options,
                rarityId = entry.RarityId or entry.rarityId,
                rarityName = entry.RarityName or entry.rarityName,
                specialHatch = entry.SpecialHatch == true or entry.specialHatch == true,
                autoDeleted = entry.AutoDeleted or entry.autoDeleted,
                autoDeleteReason = entry.AutoDeleteReason or entry.autoDeleteReason,
            })
        end

        -- Start the hatching animation (uses persistent reusable GUI)
        if activeLogger and activeLogger.Info then
            activeLogger:Info(
                "Starting egg hatching animation",
                { pet = result.Pet, variant = result.Type, hatchCount = #eggsData }
            )
        end
        hatchingService:StartHatchingAnimation(eggsData)
        if activeLogger and activeLogger.Info then
            activeLogger:Info("Hatching animation started (persistent GUI)")
        end
    else
        -- Fallback to simple notification if animation service fails
        warn("Failed to load EggHatchingService, falling back to simple notification")
        self:ShowSimpleHatchingNotification(result)
    end
end

-- Fallback simple notification (moved from original function)
function EggInteractionService:ShowSimpleHatchingNotification(result)
    local successGui = Instance.new("ScreenGui")
    successGui.Name = "HatchingSuccess"
    successGui.ResetOnSpawn = false
    successGui.Parent = player.PlayerGui

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 400, 0, 120)
    frame.Position = UDim2.new(0.5, -200, 0.5, -60)
    frame.BackgroundColor3 = Color3.fromRGB(34, 139, 34)
    frame.BorderSizePixel = 0
    frame.Parent = successGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 16)
    corner.Parent = frame

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -20, 0.5, 0)
    title.Position = UDim2.new(0, 10, 0, 5)
    title.BackgroundTransparency = 1
    title.Text = "🎉 EGG HATCHED!"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextScaled = true
    title.Font = Enum.Font.GothamBold
    title.Parent = frame

    local details = Instance.new("TextLabel")
    details.Size = UDim2.new(1, -20, 0.5, 0)
    details.Position = UDim2.new(0, 10, 0.5, 0)
    details.BackgroundTransparency = 1
    details.Text = result.Type .. " " .. result.Pet .. " (Power: " .. result.Power .. ")"
    details.TextColor3 = Color3.fromRGB(255, 255, 255)
    details.TextScaled = true
    details.Font = Enum.Font.Gotham
    details.Parent = frame

    -- Auto-remove after configured time
    task.spawn(function()
        task.wait(eggSystemConfig.cooldowns.success_notification_time)
        successGui:Destroy()
    end)
end

-- Helper functions to get image IDs for animations
function EggInteractionService:GetEggImageId(eggType)
    -- Try to get egg image from generated assets
    local success, imageId = pcall(function()
        local assetsFolder = ReplicatedStorage:FindFirstChild("Assets")
        if assetsFolder then
            local imagesFolder = assetsFolder:FindFirstChild("Images")
            if imagesFolder then
                local eggsFolder = imagesFolder:FindFirstChild("Eggs")
                if eggsFolder then
                    local eggImage = eggsFolder:FindFirstChild(eggType)
                    if eggImage then
                        return "generated_image" -- Special flag for cloned ViewportFrame
                    end
                end
            end
        end
        return "rbxasset://textures/face.png" -- Fallback
    end)

    return success and imageId or "rbxasset://textures/face.png"
end

function EggInteractionService:GetPetImageId(petType, variant)
    -- Try to get pet image from generated assets
    local success, imageId = pcall(function()
        local assetsFolder = ReplicatedStorage:FindFirstChild("Assets")
        if assetsFolder then
            local imagesFolder = assetsFolder:FindFirstChild("Images")
            if imagesFolder then
                local petsFolder = imagesFolder:FindFirstChild("Pets")
                if petsFolder then
                    local petTypeFolder = petsFolder:FindFirstChild(petType)
                    if petTypeFolder then
                        local petImage = petTypeFolder:FindFirstChild(variant)
                        if petImage then
                            return "generated_image" -- Special flag for cloned ViewportFrame
                        end
                    end
                end
            end
        end
        return "rbxasset://textures/face.png" -- Fallback
    end)

    return success and imageId or "rbxasset://textures/face.png"
end

-- === INITIALIZATION ===

function EggInteractionService:Initialize()
    Logger:Info("Initializing with CurrentTarget system", { context = "EggInteractionService" })

    -- Get reference to CurrentTargetService
    local success, currentTargetServiceOrError = pcall(function()
        return require(ReplicatedStorage.Shared.Services.EggCurrentTargetService)
    end)

    if success then
        currentTargetService = currentTargetServiceOrError
        Logger:Info("Got CurrentTargetService reference", { context = "EggInteractionService" })
        -- tapping the proximity card == pressing E — the ONLY hatch button (Jason:
        -- max/auto are SETTINGS, not buttons; "we could only click E, leave it that way")
        if currentTargetService.SetCardActivatedHandler then
            currentTargetService:SetCardActivatedHandler(function()
                self:OnEKeyPressed()
            end)
        end
    else
        Logger:Error(
            "Failed to get CurrentTargetService",
            { error = tostring(currentTargetServiceOrError) }
        )
        return
    end

    self:CreateHatchPanel()
    self:ApplyPersistedHatchModes({ persist = false })
    hatchActionMode = getPersistedHatchActionMode() or sanitizeHatchActionMode(nil)
    self:SetSelectedHatchCount(
        getPersistedSelectedHatchCount() or getDefaultSelectedHatchCount(),
        { persist = false }
    )
    self:BindReplicatedHatchSettings()

    for _, attributeName in ipairs({
        "MaxEggHatchCount",
        "AutoHatchUnlocked",
        "GoldenHatchUnlocked",
        "ChargedHatchUnlocked",
        "FastHatchUnlocked",
        "SkipHatchUnlocked",
    }) do
        table.insert(
            entitlementConnections,
            player:GetAttributeChangedSignal(attributeName):Connect(function()
                -- The ceiling moved (MaxEggHatchCount replicates after join / level-up bumps it).
                -- Re-clamping the in-memory value can only LOWER it — the "stuck at 3" bug — so:
                -- max/auto intent tracks the new max; otherwise re-apply the RAW persisted choice.
                if hatchActionMode == "max" or hatchActionMode == "auto" then
                    self:SetSelectedHatchCount(getEffectiveMaxHatchCount(), { persist = false })
                else
                    self:SetSelectedHatchCount(
                        getPersistedRawSelectedHatchCount() or selectedHatchCount,
                        { persist = false }
                    )
                end
                self:RefreshModeButtons()
                self:UpdateHatchPanel()
            end)
        )
    end

    Signals.AutoTarget_Status.OnClientEvent:Connect(function(status)
        if type(status) == "table" then
            self:ApplyAutoDeleteStatus(status.auto_delete)
        end
    end)

    local updateAccumulator = 0
    hatchPanelConnection = RunService.Heartbeat:Connect(function(step)
        updateAccumulator += step
        if updateAccumulator >= 0.12 then
            updateAccumulator = 0
            self:UpdateHatchPanel()
        end
    end)

    -- Set up E key listening (only when not typing)
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then
            return
        end

        if input.UserInputType == Enum.UserInputType.Keyboard then
            if UserInputService:GetFocusedTextBox() ~= nil then
                return
            end

            if input.KeyCode == eggSystemConfig.proximity.interaction_key then
                self:OnEKeyPressed()
            elseif input.KeyCode == eggSystemConfig.proximity.hatch_max_key then
                self:OnMaxHatchKeyPressed()
            elseif input.KeyCode == eggSystemConfig.proximity.auto_hatch_key then
                self:ToggleAutoHatch()
            end
        end
    end)

    Logger:Info("Initialized with E key listening", { context = "EggInteractionService" })
end

function EggInteractionService:GetHatchPanelDebugState()
    return {
        autoHatchEnabled = autoHatchEnabled == true,
        autoHatchSessionId = autoHatchSessionId,
        autoHatchOwned = isAutoHatchOwned(),
        hatchActionMode = hatchActionMode,
        persistedHatchActionMode = getPersistedHatchActionMode(),
        autoDelete = getPersistedAutoDeleteStatus() or {
            enabled = autoDeleteState.enabled,
            rarities = autoDeleteState.rarities,
            pet_types = autoDeleteState.pet_types,
            variants = autoDeleteState.variants,
        },
        selectedHatchCount = selectedHatchCount,
        persistedSelectedHatchCount = getPersistedSelectedHatchCount(),
        hatchModes = currentHatchModes(),
        persistedHatchModes = getPersistedHatchModes(),
        responsiveScale = hatchPanel and hatchPanel:GetAttribute("ResponsiveScale") or nil,
        responsiveFitsWidth = hatchPanel and hatchPanel:GetAttribute("ResponsiveFitsWidth") or nil,
        responsiveFitsHeight = hatchPanel and hatchPanel:GetAttribute("ResponsiveFitsHeight")
            or nil,
        maxHatchCount = getMaxHatchCount(),
        maxEntitledHatchCount = getEffectiveMaxHatchCount(),
        statusText = hatchPanelFields.status and hatchPanelFields.status.Text or "",
        helpText = hatchPanelFields.helpText and hatchPanelFields.helpText.Text or "",
        modeStatus = hatchPanelFields.modeStatus and hatchPanelFields.modeStatus.Text or "",
        settingsOpen = hatchSettingsOpen == true,
        drawerLayout = getDrawerDebugLayout(),
    }
end

function EggInteractionService:Destroy()
    if hatchPanelConnection then
        hatchPanelConnection:Disconnect()
        hatchPanelConnection = nil
    end
    for _, connection in ipairs(entitlementConnections) do
        connection:Disconnect()
    end
    entitlementConnections = {}
    self:DisconnectSettingsConnections()
    if hatchPanelGui then
        hatchPanelGui:Destroy()
        hatchPanelGui = nil
        hatchPanel = nil
        hatchPanelFields = {}
    end
end

return EggInteractionService
