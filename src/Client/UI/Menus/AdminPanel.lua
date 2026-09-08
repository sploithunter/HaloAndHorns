--[[
    AdminPanel - Administrative Tools and Test Interface
    
    Features:
    - Economy testing tools (buy items, adjust currencies)
    - Effects testing (start/stop effects, global effects)
    - Rate limiting tests
    - Debug utilities
    - System monitoring
    - Player data manipulation
    
    Usage:
    local AdminPanel = require(script.AdminPanel)
    local admin = AdminPanel.new()
    MenuManager:RegisterPanel("Admin", admin)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

-- Get shared modules
local Locations = require(ReplicatedStorage.Shared.Locations)
-- NetworkConfig removed - using Signals instead

-- New Net Signals
local Signals = require(ReplicatedStorage.Shared.Network.Signals)
local MonetizationCatalog = require(ReplicatedStorage.Shared.Game.MonetizationCatalog)
local monetizationConfig =
    require(ReplicatedStorage:WaitForChild("Configs"):WaitForChild("monetization"))
-- THE shared panel exterior (window + outer pill + header + close X + section/button pill helpers).
local PanelChrome = require(script.Parent.Parent.Components.PanelChrome)

-- Load Logger with wrapper (following the established pattern)
local LoggerWrapper
local loggerSuccess, loggerResult = pcall(function()
    return require(Locations.Logger)
end)

if loggerSuccess and loggerResult then
    LoggerWrapper = {
        new = function(name)
            return {
                info = function(_self, ...)
                    loggerResult:Info("[" .. name .. "] " .. tostring((...)), { context = name })
                end,
                warn = function(_self, ...)
                    loggerResult:Warn("[" .. name .. "] " .. tostring((...)), { context = name })
                end,
                error = function(_self, ...)
                    loggerResult:Error("[" .. name .. "] " .. tostring((...)), { context = name })
                end,
                debug = function(_self, ...)
                    loggerResult:Debug("[" .. name .. "] " .. tostring((...)), { context = name })
                end,
            }
        end,
    }
else
    LoggerWrapper = {
        new = function(name)
            return {
                info = function(_self, ...)
                    print("[" .. name .. "] INFO:", ...)
                end,
                warn = function(_self, ...)
                    warn("[" .. name .. "] WARN:", ...)
                end,
                error = function(_self, ...)
                    warn("[" .. name .. "] ERROR:", ...)
                end,
                debug = function(_self, ...)
                    print("[" .. name .. "] DEBUG:", ...)
                end,
            }
        end,
    }
end

-- Load TemplateManager
local TemplateManager
local templateSuccess, templateResult = pcall(function()
    return require(Locations.TemplateManager)
end)
if templateSuccess and templateResult then
    TemplateManager = templateResult
else
    TemplateManager = {
        new = function()
            return {
                CreatePanel = function()
                    return nil
                end,
                CreateFromTemplate = function()
                    return nil
                end,
            }
        end,
    }
end

-- Load UI config
local uiConfig
local configSuccess, configResult = pcall(function()
    return Locations.getConfig("ui")
end)
if configSuccess and configResult then
    uiConfig = configResult
else
    uiConfig = {
        themes = {
            dark = {
                primary = { surface = Color3.fromRGB(40, 40, 45) },
                text = { primary = Color3.fromRGB(255, 255, 255) },
            },
        },
        active_theme = "dark",
        helpers = {
            get_theme = function(config)
                return config.themes.dark
            end,
        },
    }
end

local AdminPanel = {}
AdminPanel.__index = AdminPanel

-- Test categories and their actions
local adminConfig = require(ReplicatedStorage.Configs.admin_menu)
local TEST_CATEGORIES = adminConfig.categories
local menuConfig = require(ReplicatedStorage.Configs.menu_ui)

function AdminPanel.new()
    local self = setmetatable({}, AdminPanel)

    self.logger = LoggerWrapper.new("AdminPanel")
    self.templateManager = TemplateManager.new()

    -- Panel state
    self.isVisible = false
    self.frame = nil

    self._connections = {}

    -- Player targeting state (NEW)
    self.selectedTargetPlayerId = nil -- nil = self, number = target player ID
    self.playerList = {}
    self.playerDropdown = nil
    self.targetPlayerLabel = nil
    self.resultLabel = nil
    self.creatorPassToggleButton = nil
    self.isCreatorPassTester =
        MonetizationCatalog.creatorOwnsAllPasses(monetizationConfig, Players.LocalPlayer.UserId)

    self:_initializeNetworking()

    return self
end

function AdminPanel:Show(parent)
    if self.isVisible then
        return
    end

    self:_createUI(parent)

    self.isVisible = true
    self.logger:info("Admin panel shown")
end

function AdminPanel:Hide()
    if not self.isVisible then
        return
    end

    if self.frame then
        self.frame:Destroy()
        self.frame = nil
    end
    self.scrollFrame = nil
    self.resultLabel = nil
    self.targetPlayerLabel = nil
    self.creatorPassToggleButton = nil

    self.isVisible = false
    self.logger:info("Admin panel hidden")
end

function AdminPanel:_createUI(parent)
    local shell = PanelChrome.build(parent, {
        name = "AdminPanel",
        title = menuConfig.admin_title,
        expanded = true,
        onClose = function()
            self:Hide()
        end,
    })
    self.frame = shell.frame
    self._areaKey = shell.areaKey
    local body = Instance.new("Frame")
    body.Name = "AdminBody"
    body.AnchorPoint = Vector2.new(0.5, 0)
    body.Position = UDim2.fromScale(0.5, 0.16)
    body.Size = UDim2.fromScale(0.96, 0.82)
    body.BackgroundTransparency = 1
    body.ZIndex = 101
    body.Parent = self.frame
    self.body = body
    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, menuConfig.row_gap)
    layout.Parent = body
    self:_createPlayerSelector()

    local filters = Instance.new("Frame")
    filters.Name = "Filters"
    filters.Size = UDim2.new(1, 0, 0, menuConfig.control_height)
    filters.BackgroundTransparency = 1
    filters.LayoutOrder = 2
    filters.Parent = body
    self.categoryIndex = self.categoryIndex or 1
    local categoryButton = Instance.new("TextButton")
    categoryButton.Name = "CategoryButton"
    categoryButton.Size = UDim2.fromScale(0.45, 1)
    categoryButton.BackgroundColor3 = shell.areaColor
    categoryButton.TextColor3 = Color3.fromRGB(table.unpack(menuConfig.colors.text))
    categoryButton.TextSize = menuConfig.control_font_size
    categoryButton.TextWrapped = true
    categoryButton.Font = Enum.Font.GothamBold
    categoryButton.Parent = filters
    self.categoryButton = categoryButton
    local categoryButtonCorner = Instance.new("UICorner")
    categoryButtonCorner.Parent = categoryButton
    categoryButton.Activated:Connect(function()
        self.categoryIndex = self.categoryIndex % #adminConfig.category_order + 1
        self:_createTestCategories()
    end)
    local search = Instance.new("TextBox")
    search.Name = "ActionSearch"
    search.Position = UDim2.fromScale(0.47, 0)
    search.Size = UDim2.fromScale(0.53, 1)
    search.BackgroundColor3 = Color3.fromRGB(table.unpack(menuConfig.colors.input))
    search.TextColor3 = Color3.fromRGB(table.unpack(menuConfig.colors.text))
    search.PlaceholderColor3 = Color3.fromRGB(table.unpack(menuConfig.colors.muted_text))
    search.PlaceholderText = menuConfig.admin_filter_placeholder
    search.Text = self.searchQuery or ""
    search.TextSize = menuConfig.control_font_size
    search.ClearTextOnFocus = false
    search.Font = Enum.Font.Gotham
    search.Parent = filters
    local searchCorner = Instance.new("UICorner")
    searchCorner.Parent = search
    search:GetPropertyChangedSignal("Text"):Connect(function()
        self.searchQuery = search.Text
        self:_createTestCategories()
    end)
    self:_createResultDisplay()
    self.scrollFrame = PanelChrome.scrollPane(body, {
        name = "AdminScroll",
        size = UDim2.fromScale(1, 0),
        position = UDim2.fromScale(0, 0),
        anchor = Vector2.zero,
        padding = menuConfig.row_gap,
        inset = 0,
    })
    self.scrollFrame.LayoutOrder = 4
    local flex = Instance.new("UIFlexItem")
    flex.FlexMode = Enum.UIFlexMode.Fill
    flex.Parent = self.scrollFrame
    self:_createTestCategories()
    if self.isCreatorPassTester then
        Signals.Admin_SetCreatorPassBenefits:FireServer({ mode = "status" })
    end
    self:_refreshPlayerList()
end

function AdminPanel:_createTestCategories()
    if not self.scrollFrame then
        return
    end
    self.creatorPassToggleButton = nil
    for _, child in ipairs(self.scrollFrame:GetChildren()) do
        if child:IsA("GuiObject") then
            child:Destroy()
        end
    end
    local key = adminConfig.category_order[self.categoryIndex or 1]
    self.categoryButton.Text = adminConfig.category_labels[key] .. "  ›"
    self:_createCategorySection(TEST_CATEGORIES[key].title, TEST_CATEGORIES[key], 1)
    self.scrollFrame.CanvasPosition = Vector2.zero
end

function AdminPanel:_createCategorySection(_title, categoryData, _layoutOrder)
    local query = string.lower(self.searchQuery or "")
    local function matches(text)
        return query == "" or string.find(string.lower(text), query, 1, true) ~= nil
    end
    local order = 0
    for _, test in ipairs(categoryData.tests or {}) do
        if (not test.creatorOnly or self.isCreatorPassTester) and matches(test.name) then
            order += 1
            self:_createTestButton(test.name, test.action, order, self.scrollFrame)
        end
    end
    for _, input in ipairs(categoryData.customInputs or {}) do
        if matches(input.label) then
            order += 1
            self:_createCustomInput(input, order, self.scrollFrame)
            order += 1
        end
    end
    if order == 0 then
        local empty = Instance.new("TextLabel")
        empty.Name = "NoMatches"
        empty.Size = UDim2.new(1, 0, 0, menuConfig.control_height)
        empty.BackgroundTransparency = 1
        empty.Text = menuConfig.admin_no_matches
        empty.TextColor3 = Color3.fromRGB(table.unpack(menuConfig.colors.muted_text))
        empty.TextSize = menuConfig.control_font_size
        empty.Parent = self.scrollFrame
    end
end

function AdminPanel:_createTestButton(testName, action, layoutOrder, parent)
    local theme = uiConfig.helpers.get_theme(uiConfig)

    local button = Instance.new("TextButton")
    button.Name = action .. "Button"
    button.Size = UDim2.new(1, 0, 0, menuConfig.control_height)
    button.BackgroundColor3 = theme.button and theme.button.primary or Color3.fromRGB(0, 120, 180)
    button.BorderSizePixel = 0
    button.Text = testName
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.TextSize = menuConfig.control_font_size
    button.TextWrapped = true
    button.Font = Enum.Font.Gotham
    button.LayoutOrder = layoutOrder
    button.Parent = parent
    if action == "toggle_creator_game_passes" then
        self.creatorPassToggleButton = button
        if self.creatorPassBenefitsEnabled ~= nil then
            button.Text = self.creatorPassBenefitsEnabled
                    and adminConfig.creator_pass_labels.enabled
                or adminConfig.creator_pass_labels.disabled
        end
    end

    local buttonCorner = Instance.new("UICorner")
    buttonCorner.CornerRadius = UDim.new(0, 6)
    buttonCorner.Parent = button

    -- Hover effects
    button.MouseEnter:Connect(function()
        local tween = TweenService:Create(
            button,
            TweenInfo.new(0.15, Enum.EasingStyle.Quad),
            { BackgroundColor3 = Color3.fromRGB(0, 140, 200) }
        )
        tween:Play()
    end)

    button.MouseLeave:Connect(function()
        local tween = TweenService:Create(button, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {
            BackgroundColor3 = theme.button and theme.button.primary or Color3.fromRGB(0, 120, 180),
        })
        tween:Play()
    end)

    button.Activated:Connect(function()
        self:_executeTestAction(action, testName)
    end)
end

function AdminPanel:_createCustomInput(inputConfig, layoutOrder, parent)
    local theme = uiConfig.helpers.get_theme(uiConfig)

    -- Label
    local label = Instance.new("TextLabel")
    label.Name = inputConfig.action .. "Label"
    label.Size = UDim2.new(1, 0, 0, 25)
    label.BackgroundTransparency = 1
    label.Text = inputConfig.label
    label.TextColor3 = theme.text and theme.text.primary or Color3.fromRGB(255, 255, 255)
    label.TextSize = 12
    label.Font = Enum.Font.Gotham
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.LayoutOrder = layoutOrder
    label.Parent = parent

    -- Input container frame
    local inputFrame = Instance.new("Frame")
    inputFrame.Name = inputConfig.action .. "InputFrame"
    inputFrame.Size = UDim2.new(1, 0, 0, menuConfig.control_height)
    inputFrame.BackgroundColor3 = theme.input and theme.input.background
        or Color3.fromRGB(30, 30, 35)
    inputFrame.BorderSizePixel = 0
    inputFrame.LayoutOrder = layoutOrder + 1
    inputFrame.Parent = parent

    local inputCorner = Instance.new("UICorner")
    inputCorner.CornerRadius = UDim.new(0, 6)
    inputCorner.Parent = inputFrame

    -- Text input
    local textBox = Instance.new("TextBox")
    textBox.Name = inputConfig.action .. "TextBox"
    textBox.Size = UDim2.fromScale(0.7, 1)
    textBox.Position = UDim2.fromScale(0.015, 0)
    textBox.BackgroundTransparency = 1
    textBox.Text = ""
    textBox.PlaceholderText = inputConfig.placeholder
    textBox.TextColor3 = theme.text and theme.text.primary or Color3.fromRGB(255, 255, 255)
    textBox.PlaceholderColor3 = Color3.fromRGB(150, 150, 150)
    textBox.TextSize = 12
    textBox.Font = Enum.Font.Gotham
    textBox.TextXAlignment = Enum.TextXAlignment.Left
    textBox.ClearTextOnFocus = false
    textBox.Parent = inputFrame

    -- Set button
    local setButton = Instance.new("TextButton")
    setButton.Name = inputConfig.action .. "SetButton"
    setButton.Size = UDim2.fromScale(0.27, 1)
    setButton.Position = UDim2.fromScale(0.73, 0)
    setButton.BackgroundColor3 = theme.button and theme.button.primary
        or Color3.fromRGB(0, 120, 180)
    setButton.BorderSizePixel = 0
    -- Set button text based on input type
    if inputConfig.currency then
        setButton.Text = "Adjust " .. inputConfig.currency:gsub("^%l", string.upper)
    else
        setButton.Text = "Set"
    end
    setButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    setButton.TextSize = 11
    setButton.Font = Enum.Font.GothamBold
    setButton.Parent = inputFrame

    local setButtonCorner = Instance.new("UICorner")
    setButtonCorner.CornerRadius = UDim.new(0, 4)
    setButtonCorner.Parent = setButton

    -- Shared function for both button click and enter key
    local function handleCustomInput()
        if inputConfig.currency then
            -- Currency adjustment
            local amount = self:_parseAmount(textBox.Text)
            if amount then -- Allow negative numbers for decrement
                self:_executeCustomCurrencyAdjust(inputConfig.currency, amount)
                textBox.Text = "" -- Clear after adjusting
            else
                self:_showAdminResult(menuConfig.admin_invalid_amount, false)
            end
        else
            -- Other custom actions (like logging)
            local inputValue = textBox.Text
            if inputValue and inputValue ~= "" then
                self:_executeCustomAction(inputConfig.action, inputValue)
                textBox.Text = "" -- Clear after executing
            else
                self:_showAdminResult(menuConfig.admin_empty_input, false)
            end
        end
    end

    -- Button click handler
    setButton.Activated:Connect(handleCustomInput)

    -- Enter key handler for text box
    textBox.FocusLost:Connect(function(enterPressed)
        if enterPressed then
            handleCustomInput()
        end
    end)
end

function AdminPanel:_parseAmount(input)
    if not input or input == "" then
        return nil
    end

    local originalInput = input

    -- Clean up the input
    input = string.upper(string.gsub(input, "%s+", "")) -- Remove spaces and convert to uppercase

    -- Handle sign
    local sign = 1
    if string.sub(input, 1, 1) == "+" then
        input = string.sub(input, 2)
    elseif string.sub(input, 1, 1) == "-" then
        sign = -1
        input = string.sub(input, 2)
    end

    -- Suffix multipliers matching BaseUI:_formatNumber exactly
    local suffixes = {
        { 1e15, "QA" }, -- Quadrillion
        { 1e12, "T" }, -- Trillion
        { 1e9, "B" }, -- Billion
        { 1e6, "M" }, -- Million
        { 1e3, "K" }, -- Thousand
    }

    -- Find matching suffix
    local multiplier = 1
    local baseNumber = input

    for _, suffix in ipairs(suffixes) do
        local suffixStr = suffix[2]
        if string.sub(input, -string.len(suffixStr)) == suffixStr then
            multiplier = suffix[1]
            baseNumber = string.sub(input, 1, -string.len(suffixStr) - 1)
            break
        end
    end

    -- Parse the base number
    local numericValue = tonumber(baseNumber)
    if not numericValue then
        return nil
    end

    -- Calculate final amount
    local rawAmount = numericValue * multiplier * sign
    if rawAmount ~= rawAmount or math.abs(rawAmount) == math.huge then
        return nil
    end
    local finalAmount = math.floor(rawAmount)

    -- Log the parsing for debugging
    self.logger:info("💰 Amount parsed", {
        originalInput = originalInput,
        cleanedInput = input,
        baseNumber = baseNumber,
        numericValue = numericValue,
        multiplier = multiplier,
        sign = sign,
        parsedAs = finalAmount,
    })

    return finalAmount
end

function AdminPanel:_executeTestAction(action, _testName)
    self.logger:info("Executing test action:", action)

    if adminConfig.event_actions[action] then
        self:_executeEffectAction(action)
    elseif adminConfig.logging_actions[action] then
        self:_executeLoggingAction(action)
    elseif action:find("^add_") then
        self:_executeCurrencyAction(action)
    elseif action == "reset_currencies" then
        self:_resetCurrencies()
    elseif action == "admin_snapshot" then
        self:_requestPlayerSnapshot()
    elseif action == "admin_force_save" then
        self:_requestForceSave()
    elseif action == "toggle_creator_game_passes" then
        self:_requestCreatorPassToggle()
    elseif action == "admin_reset_pets" then
        self:_requestResetPets()
    elseif action == "admin_reset_to_beginning" then
        self:_requestResetToBeginning(false)
    elseif action == "admin_reset_to_beginning_preview" then
        self:_requestResetToBeginning(true)
    elseif action == "admin_full_respec" then
        self:_requestFullRespec()
    elseif action == "grant_enhancements_100" then
        self:_runCommand(
            "enh.grant",
            { count = adminConfig.quick_grants.enhancements },
            function(result)
                return string.format(
                    adminConfig.command_results.enhancements,
                    tostring(result.granted or 0)
                )
            end
        )
    elseif action == "grant_future_call_tokens" then
        self:_runCommand(
            "futureCall.grant",
            { count = adminConfig.quick_grants.future_call },
            function(result)
                return string.format(
                    adminConfig.command_results.future_call,
                    tostring(result.count or 0)
                )
            end
        )
    elseif action:find("^spawn_pack_") then
        local faction = action:gsub("^spawn_pack_", "")
        self:_runCommand("combat.spawnPack", { faction = faction }, function(result)
            return string.format(
                adminConfig.command_results.spawn_pack,
                faction,
                tostring(result.spawned or 0),
                tostring(result.failed or 0)
            ),
                (result.failed or 0) == 0
        end)
    elseif action:find("^spawn_enemy_") then
        self:_executeSpawnEnemyAction(action)
    elseif action:find("^grant_") then
        self:_executePetGrantAction(action)
    elseif
        action:find("^toggle_zone_")
        or action:find("^lock_zone_")
        or action:find("^unlock_zone_")
    then
        self:_executeZoneLockAction(action)
    elseif action:find("^hatch_entitlement_") then
        self:_executeHatchEntitlementAction(action)
    elseif action == "hatch_history_recent" then
        self:_requestHatchHistory()
    elseif action == "hatch_simulation_basic_25" then
        self:_requestHatchSimulation({
            eggType = "basic_egg",
            requestedCount = 25,
        })

    -- Effects actions
    elseif action == "run_diagnostics" then
        self:_runDiagnostics()

    -- System actions
    elseif action == "debug_print_data" then
        self:_debugPrintData()

    -- Inventory management actions
    elseif action == "cleanup_inventory" then
        self:_cleanupInventory()
    elseif action == "fix_item_categories" then
        self:_fixItemCategories()

    -- Egg hatching simulation actions
    elseif action:find("hatch_") then
        self:_executeEggHatchingAction(action)
    else
        self:_showAdminResult("Unsupported action: " .. tostring(action), false)
    end
end

function AdminPanel:_requestCreatorPassToggle()
    Signals.Admin_SetCreatorPassBenefits:FireServer({ mode = "toggle" })
    self:_showAdminResult(adminConfig.command_results.creator_pending, true)
end

function AdminPanel:_runCommand(name, args, describeResult)
    task.spawn(function()
        local remote = ReplicatedStorage:WaitForChild("GameAPICommand", 5)
        if not remote then
            self:_showAdminResult(adminConfig.command_results.unavailable, false)
            return
        end
        local ok, envelope = pcall(function()
            return remote:InvokeServer(name, args)
        end)
        local result = ok
            and type(envelope) == "table"
            and (envelope.result or envelope.data or envelope)
        if type(result) ~= "table" or result.ok ~= true then
            self:_showAdminResult(
                string.format(
                    adminConfig.command_results.failed,
                    name,
                    tostring(
                        type(result) == "table" and (result.reason or result.code)
                            or "network_error"
                    )
                ),
                false
            )
            return
        end
        local message, succeeded = describeResult(result)
        self:_showAdminResult(message, succeeded ~= false)
    end)
end

function AdminPanel:_executeCurrencyAction(action)
    -- Grant a big stack to every per-biome currency at once (progression-testing helper).
    -- Each fires its own AdjustCurrency (the remote takes a single currency per call).
    if action == "add_area_coins" then
        local areaCoins = { "grass_coins", "ice_coins", "lava_coins", "desert_coins" }
        for _, currency in ipairs(areaCoins) do
            local actionData = self:_getAdminActionData({ currency = currency, amount = 100000 })
            Signals.AdjustCurrency:FireServer(actionData)
        end
        self.logger:info("Granted 100k to each area currency", { currencies = areaCoins })
        return
    end

    local currencyAdjustments = {
        add_coins_1000 = { currency = "coins", amount = 1000 },
        add_gems_100 = { currency = "gems", amount = 100 },
        add_crystals_50 = { currency = "crystals", amount = 50 },
    }

    local adjustment = currencyAdjustments[action]
    if adjustment then
        -- Add target player data if selected
        local actionData = self:_getAdminActionData(adjustment)
        Signals.AdjustCurrency:FireServer(actionData)
        self.logger:info("Currency adjustment sent:", actionData)
        return
    end
end

function AdminPanel:_executeCustomCurrencyAdjust(currency, amount)
    local adjustCurrencyData = {
        currency = currency,
        amount = amount,
    }

    -- Add target player data if selected
    local actionData = self:_getAdminActionData(adjustCurrencyData)
    Signals.AdjustCurrency:FireServer(actionData)
    self.logger:info("🔧 Custom currency ADJUST action sent:", actionData)
end

function AdminPanel:_resetCurrencies()
    -- Add target player data if selected
    local actionData = self:_getAdminActionData({ reset = true })
    Signals.AdjustCurrency:FireServer(actionData)
    self.logger:info("Currency reset requested:", actionData)
end

function AdminPanel:_executeEffectAction(action)
    self.logger:info("Effect action:", action)

    local authored = adminConfig.event_actions[action]
    local command = authored and table.clone(authored)
    if not command then
        self:_showAdminResult("Unknown event action: " .. tostring(action), false)
        return
    end

    command.reason = "Admin panel: " .. tostring(action)
    Signals.Admin_EventCommand:FireServer(command)
    self:_showAdminResult("Event command sent: " .. tostring(action), true)
end

function AdminPanel:_debugPrintData()
    local player = Players.LocalPlayer
    local lines = { player.Name .. " (" .. tostring(player.UserId) .. ")" }
    local stats = player:FindFirstChild("leaderstats")
    if stats then
        for _, stat in ipairs(stats:GetChildren()) do
            if stat:IsA("ValueBase") then
                table.insert(lines, stat.Name .. ": " .. tostring(stat.Value))
            end
        end
    end
    self:_showAdminResult(table.concat(lines, "\n"), true)
end

function AdminPanel:_runDiagnostics()
    self.logger:info("Running diagnostics...")
    Signals.RunDiagnosticsRequest:FireServer()
end

function AdminPanel:_executeLoggingAction(action)
    local Logger = loggerResult -- Access the actual Logger directly

    if action == "show_log_config" then
        local config = Logger:GetConfig()
        self.logger:info("Current Logging Configuration:", config)
        print("📊 Current Logging Configuration:")
        print("  Default Level:", config.defaultLevel)
        print("  Console Output:", config.consoleOutput)
        print("  Performance Logs:", config.performanceLogs)
        print("  Remote Logging:", config.remoteLogging)
        print("  Max History:", config.maxHistory)
        print("  Service-Specific Levels:", config.serviceSpecificLevels, "configured")
    elseif action == "set_all_info" then
        Logger:SetLogLevel(2) -- LogLevel.INFO
        self.logger:info("All services set to INFO level")
    elseif action == "set_all_debug" then
        Logger:SetLogLevel(1) -- LogLevel.DEBUG
        self.logger:info("All services set to DEBUG level")
    elseif action == "set_all_warn" then
        Logger:SetLogLevel(3) -- LogLevel.WARN
        self.logger:info("All services set to WARN level")
    elseif action == "disable_console" then
        Logger:SetConsoleOutput(false)
        print("Console output disabled")
    elseif action == "enable_console" then
        Logger:SetConsoleOutput(true)
        self.logger:info("Console output enabled")
    elseif action == "enable_performance" then
        Logger:SetPerformanceLogging(true)
        self.logger:info("Performance logging enabled")
    elseif action == "disable_performance" then
        Logger:SetPerformanceLogging(false)
        self.logger:info("Performance logging disabled")
    else
        self.logger:warn("Unknown logging action:", action)
    end
    local current = Logger:GetConfig()
    self:_showAdminResult(
        string.format(
            menuConfig.admin_logging_result,
            tostring(current.defaultLevel),
            tostring(current.consoleOutput),
            tostring(current.performanceLogs)
        ),
        true
    )
end

function AdminPanel:_executeCustomAction(action, inputValue)
    if action == "set_service_log_level" then
        -- Parse input format: "ServiceName:level" or "ServiceName level"
        local serviceName, levelString = inputValue:match("([^:]+):(.+)")
        if not serviceName then
            serviceName, levelString = inputValue:match("([^%s]+)%s+(.+)")
        end

        if serviceName and levelString then
            serviceName = serviceName:gsub("^%s*(.-)%s*$", "%1") -- Trim whitespace
            levelString = levelString:gsub("^%s*(.-)%s*$", "%1") -- Trim whitespace

            levelString = levelString:lower()
            if not adminConfig.logging_levels[levelString] or serviceName == "" then
                self:_showAdminResult(menuConfig.admin_invalid_log_level, false)
                return
            end
            local Logger = loggerResult
            Logger:SetServiceLogLevel(serviceName, levelString)
            self:_showAdminResult(
                string.format(
                    menuConfig.admin_log_level_set,
                    serviceName,
                    Logger:GetServiceLogLevel(serviceName)
                ),
                true
            )
        else
            self:_showAdminResult(menuConfig.admin_invalid_log_level, false)
        end
    elseif action == "grant_pet_custom" then
        self:_executeCustomPetGrant(inputValue)
    elseif action == "set_zone_lock_custom" then
        self:_executeCustomZoneLock(inputValue)
    elseif action == "set_hatch_entitlement_custom" then
        self:_executeCustomHatchEntitlement(inputValue)
    elseif action == "set_max_hatch_count" then
        self:_setMaxHatchCount(inputValue)
    elseif action == "spawn_enemy_custom" then
        self:_spawnEnemy(inputValue)
    elseif action == "hatch_custom_eggs" or action == "hatch_specific_pet" then
        -- Handle egg hatching custom inputs
        self:_executeCustomEggHatching({
            action = action,
            value = inputValue,
        })
    else
        self.logger:warn("Unknown custom action:", action)
    end
end

function AdminPanel:_initializeNetworking()
    -- Signals is required at module load, so its registry is already complete here.

    if Signals.RunDiagnostics then
        table.insert(
            self._connections,
            Signals.RunDiagnostics.OnClientEvent:Connect(function(report)
                self:_showDiagnosticsPopup(report)
            end)
        )
    end

    if Signals.AdminToolResult then
        table.insert(
            self._connections,
            Signals.AdminToolResult.OnClientEvent:Connect(function(result)
                self:_handleAdminToolResult(result)
            end)
        )
    end

    self.logger:info("Admin result signals connected")
end

-- Public interface methods
function AdminPanel:IsVisible()
    return self.isVisible
end

function AdminPanel:GetFrame()
    return self.frame
end

function AdminPanel:Destroy()
    for _, connection in ipairs(self._connections) do
        connection:Disconnect()
    end
    table.clear(self._connections)
    self:Hide()
    self.logger:info("Admin panel destroyed")
end

-- Player Selection Methods (NEW)
function AdminPanel:_createPlayerSelector()
    local selector = Instance.new("Frame")
    selector.Name = "PlayerSelector"
    selector.Size = UDim2.new(1, 0, 0, menuConfig.control_height)
    selector.BackgroundColor3 = Color3.fromRGB(table.unpack(menuConfig.colors.input))
    selector.LayoutOrder = 1
    selector.Parent = self.body
    local selectorCorner = Instance.new("UICorner")
    selectorCorner.Parent = selector
    local selected = self.selectedTargetPlayerId
        and Players:GetPlayerByUserId(self.selectedTargetPlayerId)
    if not selected then
        self.selectedTargetPlayerId = nil
    end
    local label = Instance.new("TextLabel")
    label.Name = "CurrentTarget"
    label.Position = UDim2.fromScale(0.025, 0)
    label.Size = UDim2.fromScale(0.6, 1)
    label.BackgroundTransparency = 1
    label.Text = selected and selected.Name or "Self (You)"
    label.TextColor3 = Color3.fromRGB(table.unpack(menuConfig.colors.text))
    label.TextSize = menuConfig.control_font_size
    label.TextWrapped = true
    label.Font = Enum.Font.GothamBold
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = selector
    self.targetPlayerLabel = label
    local button = Instance.new("TextButton")
    button.Name = "DropdownButton"
    button.Position = UDim2.fromScale(0.65, 0)
    button.Size = UDim2.fromScale(0.35, 1)
    button.Text = menuConfig.admin_next_player_label
    button.TextColor3 = Color3.fromRGB(table.unpack(menuConfig.colors.text))
    button.BackgroundColor3 = Color3.fromRGB(table.unpack(menuConfig.colors.action))
    button.Font = Enum.Font.GothamBold
    button.TextSize = menuConfig.control_font_size
    button.TextWrapped = true
    button.Parent = selector
    local buttonCorner = Instance.new("UICorner")
    buttonCorner.Parent = button
    button.Activated:Connect(function()
        self:_showPlayerDropdown()
    end)
    self.playerDropdown = button
end

function AdminPanel:_createResultDisplay()
    local result = Instance.new("ScrollingFrame")
    result.Name = "AdminResult"
    result.Size = UDim2.new(1, 0, 0, menuConfig.result_height)
    result.LayoutOrder = 3
    result.BackgroundColor3 = Color3.fromRGB(table.unpack(menuConfig.colors.input))
    result.BorderSizePixel = 0
    result.Active = true
    result.ScrollingDirection = Enum.ScrollingDirection.Y
    result.AutomaticCanvasSize = Enum.AutomaticSize.Y
    result.CanvasSize = UDim2.fromScale(0, 0)
    result.ScrollBarThickness = menuConfig.row_gap
    result.Parent = self.body
    local label = Instance.new("TextLabel")
    label.Name = "ResultText"
    label.Position = UDim2.fromScale(0.025, 0)
    label.Size = UDim2.fromScale(0.94, 0)
    label.AutomaticSize = Enum.AutomaticSize.Y
    label.BackgroundTransparency = 1
    label.Text = menuConfig.admin_result_ready
    label.TextColor3 = Color3.fromRGB(table.unpack(menuConfig.colors.text))
    label.TextSize = menuConfig.control_font_size
    label.Font = Enum.Font.Gotham
    label.TextWrapped = true
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextYAlignment = Enum.TextYAlignment.Top
    label.Parent = result
    self.resultLabel = label
end

function AdminPanel:_showAdminResult(message, success)
    if self.resultLabel and self.resultLabel.Parent then
        self.resultLabel.Parent.CanvasPosition = Vector2.zero
        self.resultLabel.Text = message
        self.resultLabel.TextColor3 = success == false and Color3.fromRGB(255, 120, 120)
            or Color3.fromRGB(170, 255, 170)
    end

    if success == false then
        self.logger:warn(message)
    else
        self.logger:info(message)
    end
end

function AdminPanel:_refreshPlayerList()
    self.playerList = Players:GetPlayers()
    table.sort(self.playerList, function(a, b)
        if a == b then
            return false
        end
        if a == Players.LocalPlayer then
            return true
        end
        if b == Players.LocalPlayer then
            return false
        end
        return a.UserId < b.UserId
    end)
end

function AdminPanel:_showPlayerDropdown()
    self:_refreshPlayerList()
    local selectedId = self.selectedTargetPlayerId or Players.LocalPlayer.UserId
    local index = 0
    for i, player in ipairs(self.playerList) do
        if player.UserId == selectedId then
            index = i
            break
        end
    end
    local target = self.playerList[index % #self.playerList + 1]
    self.selectedTargetPlayerId = target ~= Players.LocalPlayer and target.UserId or nil
    self.targetPlayerLabel.Text = target == Players.LocalPlayer and "Self (You)" or target.Name
end

function AdminPanel:_getAdminActionData(baseData)
    -- Add target player ID to action data if a target is selected
    local actionData = table.clone(baseData)

    -- Add target player if one is selected
    if self.selectedTargetPlayerId then
        actionData.targetPlayerId = self.selectedTargetPlayerId
    end

    return actionData
end

function AdminPanel:_requestPlayerSnapshot()
    Signals.Admin_GetPlayerSnapshot:FireServer(self:_getAdminActionData({}))
    self:_showAdminResult("Snapshot requested...", true)
end

function AdminPanel:_requestForceSave()
    Signals.Admin_ForceSave:FireServer(self:_getAdminActionData({}))
    self:_showAdminResult("Force save requested...", true)
end

function AdminPanel:_requestResetPets()
    Signals.Admin_ResetPets:FireServer(self:_getAdminActionData({}))
    self:_showAdminResult("Reset pets requested for target...", true)
end

function AdminPanel:_requestResetToBeginning(dryRun)
    Signals.Admin_ResetToBeginning:FireServer(self:_getAdminActionData({ dryRun = dryRun == true }))
    self:_showAdminResult(
        dryRun and "Reset-to-beginning PREVIEW requested..."
            or "Reset to beginning (keep HUGE) requested...",
        true
    )
end

function AdminPanel:_requestFullRespec()
    task.spawn(function()
        local remote = game:GetService("ReplicatedStorage"):WaitForChild("GameAPICommand", 5)
        if not remote then
            self:_showAdminResult("GameAPICommand remote missing", false)
            return
        end
        local args = {}
        if self.selectedTargetPlayerId then
            args.targetPlayerId = self.selectedTargetPlayerId
        end
        local response = remote:InvokeServer("respec.begin", args)
        local result = type(response) == "table" and (response.result or response.data or response)
            or response
        if result and result.ok then
            self:_showAdminResult(
                ("Full respec started: replay to L%d; %d enhancements returned"):format(
                    tonumber(result.targetClaimedLevel) or 1,
                    tonumber(result.enhancementsReturned) or 0
                ),
                true
            )
        else
            self:_showAdminResult(
                "Full respec failed: " .. tostring(result and result.reason or "no response"),
                false
            )
        end
    end)
end

function AdminPanel:_executePetGrantAction(action)
    local quickGrants = {
        grant_bear_basic = { petType = "bear", variant = "basic", quantity = 1 },
        grant_dragon_basic = { petType = "dragon", variant = "basic", quantity = 1 },
        grant_bear_golden = { petType = "bear", variant = "golden", quantity = 1 },
        grant_colorado_basic = { petType = "colorado", variant = "basic", quantity = 1 },
        grant_colorado_golden = { petType = "colorado", variant = "golden", quantity = 1 },
        grant_colorado_rainbow = { petType = "colorado", variant = "rainbow", quantity = 1 },
        grant_colorado_huge = {
            petType = "colorado",
            variant = "rainbow",
            quantity = 1,
            huge = true,
        },
        -- the APEX: dev-only, untradeable, pinned to max_pet_power (own serial chain)
        grant_colorado_creator = {
            petType = "colorado_creator",
            variant = "rainbow",
            quantity = 1,
            huge = true,
            creator = true,
        },
        grant_kade_basic = { petType = "kade", variant = "basic", quantity = 1 },
        grant_kade_golden = { petType = "kade", variant = "golden", quantity = 1 },
        grant_kade_rainbow = { petType = "kade", variant = "rainbow", quantity = 1 },
        grant_kade_huge = {
            petType = "kade",
            variant = "rainbow",
            quantity = 1,
            huge = true,
        },
        grant_beta_egg_basic = {
            testerAwardId = "beta_week_2_2026",
            testerTier = "basic",
        },
        grant_beta_egg_golden = {
            testerAwardId = "beta_week_2_2026",
            testerTier = "golden",
        },
        grant_beta_egg_rainbow = {
            testerAwardId = "beta_week_2_2026",
            testerTier = "rainbow",
        },
        grant_beta_egg_huge = {
            testerAwardId = "beta_week_2_2026",
            testerTier = "rainbow",
            testerForceHuge = true,
        },
        grant_patch_egg_basic = {
            testerAwardId = "beta_week_3_2026",
            testerTier = "basic",
        },
        grant_patch_egg_golden = {
            testerAwardId = "beta_week_3_2026",
            testerTier = "golden",
        },
        grant_patch_egg_rainbow = {
            testerAwardId = "beta_week_3_2026",
            testerTier = "rainbow",
        },
        grant_patch_egg_huge = {
            testerAwardId = "beta_week_3_2026",
            testerTier = "rainbow",
            testerForceHuge = true,
        },
        grant_core_egg_basic = {
            testerAwardId = "beta_week_4_2026",
            testerTier = "basic",
        },
        grant_core_egg_golden = {
            testerAwardId = "beta_week_4_2026",
            testerTier = "golden",
        },
        grant_core_egg_rainbow = {
            testerAwardId = "beta_week_4_2026",
            testerTier = "rainbow",
        },
        grant_core_egg_huge = {
            testerAwardId = "beta_week_4_2026",
            testerTier = "rainbow",
            testerForceHuge = true,
        },
        grant_cache_egg_basic = {
            testerAwardId = "beta_week_5_2026",
            testerTier = "basic",
        },
        grant_cache_egg_golden = {
            testerAwardId = "beta_week_5_2026",
            testerTier = "golden",
        },
        grant_cache_egg_rainbow = {
            testerAwardId = "beta_week_5_2026",
            testerTier = "rainbow",
        },
        grant_cache_egg_huge = {
            testerAwardId = "beta_week_5_2026",
            testerTier = "rainbow",
            testerForceHuge = true,
        },
    }

    local grantData = quickGrants[action]
    if not grantData then
        self.logger:warn("Unknown pet grant action:", action)
        return
    end

    Signals.Admin_GrantPet:FireServer(self:_getAdminActionData(grantData))
    self:_showAdminResult(
        grantData.testerAwardId and ("Tester egg requested: " .. grantData.testerTier)
            or ("Pet grant requested: " .. grantData.petType .. ":" .. grantData.variant),
        true
    )
end

function AdminPanel:_executeCustomPetGrant(inputValue)
    local petType, variant, quantity, trait =
        inputValue:match("^%s*([^:%s]+)%s*:%s*([^:%s]+)%s*:%s*(%d+)%s*:%s*([^:%s]+)%s*$")
    if not petType then
        petType, variant, trait =
            inputValue:match("^%s*([^:%s]+)%s*:%s*([^:%s]+)%s*:%s*([^:%s%d]+)%s*$")
        quantity = 1
    end
    if not petType then
        petType, variant, quantity =
            inputValue:match("^%s*([^:%s]+)%s*:%s*([^:%s]+)%s*:%s*(%d+)%s*$")
    end
    if not petType then
        petType, variant = inputValue:match("^%s*([^:%s]+)%s*:%s*([^:%s]+)%s*$")
        quantity = 1
    end

    if not petType or not variant then
        self:_showAdminResult("Invalid pet grant format. Use pet:variant:quantity[:huge]", false)
        return
    end
    local huge = trait and string.lower(trait) == "huge"

    Signals.Admin_GrantPet:FireServer(self:_getAdminActionData({
        petType = petType,
        variant = variant,
        quantity = tonumber(quantity) or 1,
        huge = huge,
    }))
    self:_showAdminResult(
        "Pet grant requested: " .. petType .. ":" .. variant .. (huge and " huge" or ""),
        true
    )
end

function AdminPanel:_executeZoneLockAction(action)
    local quickActions = {
        toggle_zone_meadow = {
            zoneId = "Meadow",
        },
        lock_zone_meadow = {
            zoneId = "Meadow",
            locked = true,
        },
        unlock_zone_meadow = {
            zoneId = "Meadow",
            locked = false,
            bypassRequirements = false,
        },
        unlock_zone_meadow_bypass = {
            zoneId = "Meadow",
            locked = false,
            bypassRequirements = true,
        },
    }

    local lockData = quickActions[action]
    if not lockData then
        self.logger:warn("Unknown zone lock action:", action)
        return
    end

    Signals.Admin_SetZoneLock:FireServer(self:_getAdminActionData(lockData))
    self:_showAdminResult("Zone lock change requested: " .. lockData.zoneId, true)
end

function AdminPanel:_executeCustomZoneLock(inputValue)
    local zoneId, mode = inputValue:match("^%s*([^:%s]+)%s*:?(.-)%s*$")
    if not zoneId or zoneId == "" then
        self:_showAdminResult(
            "Invalid zone lock format. Use zoneId:toggle|lock|unlock|bypass",
            false
        )
        return
    end

    mode = tostring(mode or ""):lower()
    local lockData = {
        zoneId = zoneId,
    }

    if mode == "lock" or mode == "locked" then
        lockData.locked = true
    elseif mode == "unlock" or mode == "unlocked" then
        lockData.locked = false
    elseif mode == "bypass" or mode == "free" then
        lockData.locked = false
        lockData.bypassRequirements = true
    elseif mode ~= "" and mode ~= "toggle" then
        self:_showAdminResult("Invalid zone mode. Use toggle, lock, unlock, or bypass", false)
        return
    end

    Signals.Admin_SetZoneLock:FireServer(self:_getAdminActionData(lockData))
    self:_showAdminResult("Zone lock change requested: " .. zoneId, true)
end

function AdminPanel:_executeHatchEntitlementAction(action)
    local quickActions = {
        hatch_entitlement_status = {
            mode = "status",
        },
        hatch_entitlement_unlock_all = {
            mode = "unlock_all_modes",
        },
        hatch_entitlement_lock_all = {
            mode = "lock_all_modes",
        },
        hatch_entitlement_reset_all = {
            mode = "reset_all",
        },
        hatch_entitlement_toggle_golden = {
            entitlement = "goldenMode",
            mode = "toggle",
        },
        hatch_entitlement_toggle_charged = {
            entitlement = "chargedMode",
            mode = "toggle",
        },
        hatch_entitlement_max_99 = {
            entitlement = "maxHatchCount",
            value = 99,
        },
    }

    local entitlementData = quickActions[action]
    if not entitlementData then
        self.logger:warn("Unknown hatch entitlement action:", action)
        return
    end

    Signals.Admin_SetHatchEntitlement:FireServer(self:_getAdminActionData(entitlementData))
    self:_showAdminResult("Hatch entitlement change requested", true)
end

function AdminPanel:_executeCustomHatchEntitlement(inputValue)
    local entitlementId, rawValue = inputValue:match("^%s*([^:%s]+)%s*:%s*(.-)%s*$")
    if not entitlementId or entitlementId == "" or not rawValue or rawValue == "" then
        self:_showAdminResult(
            "Invalid hatch entitlement format. Use name:unlock|lock|toggle|reset or maxHatchCount:number",
            false
        )
        return
    end

    rawValue = tostring(rawValue):lower()
    local payload = {
        entitlement = entitlementId,
    }

    if rawValue == "unlock" or rawValue == "on" or rawValue == "true" then
        payload.value = true
    elseif rawValue == "lock" or rawValue == "off" or rawValue == "false" then
        payload.value = false
    elseif rawValue == "toggle" then
        payload.mode = "toggle"
    elseif rawValue == "reset" or rawValue == "default" then
        payload.mode = "reset"
    else
        local numericValue = tonumber(rawValue)
        if numericValue then
            payload.value = numericValue
        else
            self:_showAdminResult(
                "Invalid hatch entitlement value. Use unlock, lock, toggle, reset, or a number.",
                false
            )
            return
        end
    end

    Signals.Admin_SetHatchEntitlement:FireServer(self:_getAdminActionData(payload))
    self:_showAdminResult("Hatch entitlement change requested: " .. entitlementId, true)
end

-- Dedicated control for the max-hatch-count entitlement: takes a number, clamps to [3, 99],
-- and routes through the same Admin_SetHatchEntitlement path as the other hatch controls.
function AdminPanel:_setMaxHatchCount(inputValue)
    local count = tonumber(inputValue)
    if not count then
        self:_showAdminResult("Enter a number 3-99 for max hatch", false)
        return
    end

    count = math.clamp(math.floor(count), 3, 99)
    Signals.Admin_SetHatchEntitlement:FireServer(self:_getAdminActionData({
        entitlement = "maxHatchCount",
        value = count,
    }))
    self:_showAdminResult("Max hatch set to " .. count .. " for target", true)
end

-- Spawn a test combat enemy near the target player so reverse mining can be tried
-- live (pets attack back, enemy mines pet endurance, downs, chases). Routes through
-- Admin_SpawnEnemy (server validates admin + globalEffects target).
function AdminPanel:_spawnEnemy(enemyId)
    enemyId = tostring(enemyId or ""):gsub("%s+", "")
    if enemyId == "" then
        enemyId = "lava_imp"
    end
    Signals.Admin_SpawnEnemy:FireServer(self:_getAdminActionData({ enemy = enemyId }))
    self:_showAdminResult("Spawned enemy: " .. enemyId, true)
end

-- Button actions are "spawn_enemy_<id>" (e.g. spawn_enemy_lava_imp).
function AdminPanel:_executeSpawnEnemyAction(action)
    self:_spawnEnemy((action:gsub("^spawn_enemy_", "")))
end

function AdminPanel:_requestHatchHistory()
    Signals.Admin_RequestHatchHistory:FireServer(self:_getAdminActionData({
        limit = 8,
    }))
    self:_showAdminResult("Hatch history requested", true)
end

function AdminPanel:_requestHatchSimulation(payload)
    Signals.Admin_RequestHatchSimulation:FireServer(self:_getAdminActionData(payload or {
        eggType = "basic_egg",
        requestedCount = 25,
    }))
    self:_showAdminResult("Hatch simulation requested", true)
end

function AdminPanel:_formatCountMap(counts)
    local parts = {}
    for key, count in pairs(counts or {}) do
        table.insert(parts, tostring(key) .. "=" .. tostring(count))
    end
    table.sort(parts)
    return #parts > 0 and table.concat(parts, ", ") or "none"
end

function AdminPanel:_formatSnapshot(snapshot)
    local currencies = snapshot.currencies or {}
    local save = snapshot.save or {}
    local autoTarget = snapshot.autoTarget or {}
    local hatchParts = {}
    for entitlementId, entitlement in pairs(snapshot.hatchEntitlements or {}) do
        table.insert(
            hatchParts,
            string.format("%s=%s", entitlementId, tostring(entitlement and entitlement.effective))
        )
    end
    table.sort(hatchParts)
    local hatchSummary = #hatchParts > 0 and table.concat(hatchParts, ", ") or "none"
    local creatorPasses = snapshot.creatorPassBenefits or {}
    local creatorPassSummary = creatorPasses.eligible and (creatorPasses.enabled and "ON" or "OFF")
        or "n/a"

    return string.format(
        "%s | Coins %s, Gems %s, Crystals %s | Pets %d (%d entries), Equipped %d/%d | Creator passes %s | Hatch %s | Auto low=%s high=%s | Data %s/%s | Save dirty=%s scheduled=%s inFlight=%s reason=%s",
        snapshot.name or "Player",
        tostring(currencies.coins or 0),
        tostring(currencies.gems or 0),
        tostring(currencies.crystals or 0),
        snapshot.petCount or 0,
        snapshot.petEntryCount or 0,
        snapshot.equippedPetCount or 0,
        snapshot.equippedPetLimit or 0,
        creatorPassSummary,
        hatchSummary,
        tostring(autoTarget.low == true),
        tostring(autoTarget.high == true),
        snapshot.dataLoaded and "loaded" or "not loaded",
        snapshot.persistenceEnabled and tostring(snapshot.dataStoreState or "Access")
            or "no persistence",
        tostring(save.dirty == true),
        tostring(save.scheduled == true),
        tostring(save.inFlight == true),
        tostring(save.lastReason or "none")
    )
end

function AdminPanel:_handleAdminToolResult(result)
    if type(result) ~= "table" then
        return
    end

    local message = result.message or "Admin tool completed"
    if result.snapshot then
        message ..= "\n" .. self:_formatSnapshot(result.snapshot)
    end
    if result.kind == "event_command" then
        local eventCount = result.events and #result.events or 0
        message ..= "\nActive global events: " .. tostring(eventCount)
        if result.modifiers then
            local modifierParts = {}
            for key, value in pairs(result.modifiers) do
                table.insert(modifierParts, key .. "=" .. tostring(value))
            end
            table.sort(modifierParts)
            if #modifierParts > 0 then
                message ..= "\nModifiers: " .. table.concat(modifierParts, ", ")
            end
        end
    elseif result.kind == "creator_pass_benefits" and result.creatorPassBenefits then
        local enabled = result.creatorPassBenefits.enabled == true
        self.creatorPassBenefitsEnabled = enabled
        if self.creatorPassToggleButton then
            self.creatorPassToggleButton.Text = enabled and adminConfig.creator_pass_labels.enabled
                or adminConfig.creator_pass_labels.disabled
        end
    elseif result.kind == "hatch_entitlement" and result.hatchEntitlements then
        local entitlementParts = {}
        for entitlementId, entitlement in pairs(result.hatchEntitlements) do
            table.insert(
                entitlementParts,
                string.format(
                    "%s=%s",
                    entitlementId,
                    tostring(entitlement and entitlement.effective)
                )
            )
        end
        table.sort(entitlementParts)
        if #entitlementParts > 0 then
            message ..= "\nHatch unlocks: " .. table.concat(entitlementParts, ", ")
        end
    elseif result.kind == "hatch_history" then
        local lines = {}
        for _, entry in ipairs(result.hatchHistory or {}) do
            table.insert(
                lines,
                string.format(
                    "#%s %s %s requested=%s hatched=%s cost=%s %s stop=%s autoDel=%s special=%s",
                    tostring(entry.id or "?"),
                    entry.ok == true and "OK" or tostring(entry.code or "ERR"),
                    tostring(entry.eggType or "?"),
                    tostring(entry.requestedCount or 0),
                    tostring(entry.hatchCount or 0),
                    tostring(entry.totalCost or 0),
                    tostring(entry.currency or ""),
                    tostring(entry.stopReason or "-"),
                    tostring(entry.autoDeletedCount or 0),
                    tostring(entry.specialHatchCount or 0)
                )
            )
        end
        message ..= "\nRecent hatches: " .. (#lines > 0 and table.concat(lines, "\n") or "none")
    elseif result.kind == "hatch_simulation" and result.simulation then
        local simulation = result.simulation
        local counts = simulation.counts or {}
        message ..= string.format(
            "\nSimulation: requested=%s hatch=%s totalCost=%s %s stop=%s autoDel=%s special=%s",
            tostring(simulation.requestedCount or 0),
            tostring(simulation.hatchCount or 0),
            tostring(simulation.totalCost or simulation.TotalCost or 0),
            tostring(simulation.currency or simulation.Currency or ""),
            tostring(simulation.stopReason or "-"),
            tostring(simulation.autoDeletedCount or 0),
            tostring(simulation.specialHatchCount or 0)
        )
        message ..= "\nPets: " .. self:_formatCountMap(counts.pets)
        message ..= "\nVariants: " .. self:_formatCountMap(counts.variants)
        message ..= "\nRarities: " .. self:_formatCountMap(counts.rarities)
    end

    self:_showAdminResult(message, result.success ~= false)
end

-- Display diagnostics in a simple popup
function AdminPanel:_showDiagnosticsPopup(report)
    local message =
        string.format("Diagnostics completed: %d passed, %d failed", report.passed, report.failed)
    if report.failed > 0 then
        message ..= "\nFailures:\n" .. table.concat(report.failures, "\n")
    end
    self:_showAdminResult(message, report.failed == 0)
end

-- 🔧 INVENTORY MANAGEMENT COMMANDS
function AdminPanel:_cleanupInventory()
    self.logger:info(
        "🗑️ ADMIN: Removing orphaned buckets (preserves valid inventory from config)"
    )

    Signals.CleanupInventory:FireServer({
        action = "remove_orphaned_buckets",
        targetPlayerId = self.selectedTargetPlayerId or Players.LocalPlayer.UserId,
    })
    self.logger:info("✅ Orphaned bucket cleanup command sent via Signals")
end

function AdminPanel:_fixItemCategories()
    self.logger:info("🔧 ADMIN: Fixing item categories (moving items to correct buckets)")

    Signals.FixItemCategories:FireServer({
        action = "migrate_items_to_correct_buckets",
        targetPlayerId = self.selectedTargetPlayerId or Players.LocalPlayer.UserId,
    })
    self.logger:info("✅ Fix categories command sent via Signals")
end

-- ═══════════════════════════════════════════════════════════════════════════════════
-- ASSET DEBUGGING FUNCTIONS
-- ═══════════════════════════════════════════════════════════════════════════════════

function AdminPanel:_executeEggHatchingAction(action)
    self.logger:info("🥚 ADMIN: Executing egg hatching action:", action)

    -- Load the EggHatchingService
    local EggHatchingService = require(ReplicatedStorage.Shared.Services.EggHatchingService)

    -- Available pet types and variants
    local petTypes = { "bear", "bunny", "doggy", "dragon", "kitty" }
    local variants = { "basic", "golden", "rainbow" }

    -- Generate test eggs based on action
    local testEggs = {}
    local eggCount = 1

    if action == "hatch_1_egg" then
        eggCount = 1
    elseif action == "hatch_3_eggs" then
        eggCount = 3
    elseif action == "hatch_5_eggs" then
        eggCount = 5
    elseif action == "hatch_10_eggs" then
        eggCount = 10
    elseif action == "hatch_25_eggs" then
        eggCount = 25
    elseif action == "hatch_42_eggs" then
        eggCount = 42
    elseif action == "hatch_99_eggs" then
        eggCount = 99
    elseif action == "hatch_custom_eggs" then
        -- This will be handled by custom input
        return
    elseif action == "hatch_specific_pet" then
        -- This will be handled by custom input
        return
    else
        self.logger:warn("Unknown egg hatching action:", action)
        return
    end

    -- Optionally create local anchor parts so 3D FX can play during tests
    local anchors = {}
    local maxAnchors = math.min(eggCount, 5) -- limit FX to avoid spam
    local player = Players.LocalPlayer
    local hrp = player and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if hrp then
        local basePos = hrp.Position + Vector3.new(0, 3, 0)
        local radius = 6
        for i = 1, maxAnchors do
            local theta = (i / maxAnchors) * math.pi * 2
            local anchor = Instance.new("Part")
            anchor.Name = "LocalEggFXAnchor_" .. i
            anchor.Size = Vector3.new(0.5, 0.5, 0.5)
            anchor.Transparency = 1
            anchor.Anchored = true
            anchor.CanCollide = false
            anchor.CanQuery = false
            anchor.CanTouch = false
            anchor.CFrame = CFrame.new(
                basePos + Vector3.new(math.cos(theta) * radius, 0, math.sin(theta) * radius)
            )
            anchor.Parent = workspace
            table.insert(anchors, anchor)
        end
        -- Cleanup anchors after a short delay
        task.delay(8, function()
            for _, a in ipairs(anchors) do
                if a and a.Parent then
                    a:Destroy()
                end
            end
        end)
    end

    -- Generate random eggs and attach worldPart for first few
    for i = 1, eggCount do
        table.insert(testEggs, {
            eggType = "basic_egg",
            petType = petTypes[math.random(1, #petTypes)],
            variant = variants[math.random(1, #variants)],
            imageId = "generated_image",
            petImageId = "generated_image",
            worldPart = anchors[i], -- nil beyond maxAnchors
        })
    end

    -- Start the animation
    local success, result = pcall(function()
        return EggHatchingService:StartHatchingAnimation(testEggs)
    end)

    if success then
        self.logger:info("✅ Egg hatching animation started for", eggCount, "eggs")
    else
        self.logger:error("❌ Failed to start egg hatching animation:", result)
    end
end

function AdminPanel:_executeCustomEggHatching(inputData)
    self.logger:info("🥚 ADMIN: Executing custom egg hatching with input:", inputData)

    -- Load the EggHatchingService
    local EggHatchingService = require(ReplicatedStorage.Shared.Services.EggHatchingService)

    -- Available pet types and variants
    local petTypes = { "bear", "bunny", "doggy", "dragon", "kitty" }
    local variants = { "basic", "golden", "rainbow" }

    local testEggs = {}

    if inputData.action == "hatch_custom_eggs" then
        -- Parse custom egg count
        local eggCount = tonumber(inputData.value)
        if not eggCount or eggCount < 1 or eggCount > 99 then
            self.logger:warn("Invalid egg count:", inputData.value, "- must be 1-99")
            return
        end

        -- Create local anchors (limit to first few) and generate eggs
        local anchors = {}
        local maxAnchors = math.min(eggCount, 5)
        local player = Players.LocalPlayer
        local hrp = player
            and player.Character
            and player.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            local basePos = hrp.Position + Vector3.new(0, 3, 0)
            local radius = 6
            for i = 1, maxAnchors do
                local theta = (i / maxAnchors) * math.pi * 2
                local anchor = Instance.new("Part")
                anchor.Name = "LocalEggFXAnchor_" .. i
                anchor.Size = Vector3.new(0.5, 0.5, 0.5)
                anchor.Transparency = 1
                anchor.Anchored = true
                anchor.CanCollide = false
                anchor.CanQuery = false
                anchor.CanTouch = false
                anchor.CFrame = CFrame.new(
                    basePos + Vector3.new(math.cos(theta) * radius, 0, math.sin(theta) * radius)
                )
                anchor.Parent = workspace
                table.insert(anchors, anchor)
            end
            task.delay(8, function()
                for _, a in ipairs(anchors) do
                    if a and a.Parent then
                        a:Destroy()
                    end
                end
            end)
        end

        for i = 1, eggCount do
            table.insert(testEggs, {
                eggType = "basic_egg",
                petType = petTypes[math.random(1, #petTypes)],
                variant = variants[math.random(1, #variants)],
                imageId = "generated_image",
                petImageId = "generated_image",
                worldPart = anchors[i],
            })
        end

        self.logger:info("🥚 Generating", eggCount, "random eggs")
    elseif inputData.action == "hatch_specific_pet" then
        -- Parse specific pet (format: petType:variant)
        local petType, variant = inputData.value:match("([^:]+):([^:]+)")
        if not petType or not variant then
            self.logger:warn(
                "Invalid pet format:",
                inputData.value,
                "- use format: petType:variant"
            )
            return
        end

        -- Validate pet type and variant
        local validPetType = false
        for _, validType in ipairs(petTypes) do
            if validType == petType then
                validPetType = true
                break
            end
        end

        local validVariant = false
        for _, validVar in ipairs(variants) do
            if validVar == variant then
                validVariant = true
                break
            end
        end

        if not validPetType then
            self.logger:warn(
                "Invalid pet type:",
                petType,
                "- valid types:",
                table.concat(petTypes, ", ")
            )
            return
        end

        if not validVariant then
            self.logger:warn(
                "Invalid variant:",
                variant,
                "- valid variants:",
                table.concat(variants, ", ")
            )
            return
        end

        -- Generate single egg with specific pet
        table.insert(testEggs, {
            eggType = "basic_egg",
            petType = petType,
            variant = variant,
            imageId = "generated_image",
            petImageId = "generated_image",
        })

        self.logger:info("🥚 Generating 1 egg with specific pet:", petType, variant)
    end

    -- Start the animation
    if #testEggs > 0 then
        local success, result = pcall(function()
            return EggHatchingService:StartHatchingAnimation(testEggs)
        end)

        if success then
            self.logger:info("✅ Custom egg hatching animation started for", #testEggs, "eggs")
        else
            self.logger:error("❌ Failed to start custom egg hatching animation:", result)
        end
    end
end

return AdminPanel
