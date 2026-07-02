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
local TEST_CATEGORIES = {
    economy = {
        title = "💰 Economy Testing",
        tests = {
            { name = "Buy Test Item (50 coins)", action = "buy_test_item" },
            { name = "Buy Health Potion (25 coins)", action = "buy_health_potion" },
            { name = "Buy Wooden Sword (100 coins)", action = "buy_wooden_sword" },
            { name = "Buy Iron Sword (500 coins)", action = "buy_iron_sword" },
            { name = "Buy Basic Pickaxe (200 coins)", action = "buy_basic_pickaxe" },
            { name = "Buy Premium XP Boost (10 gems)", action = "buy_premium_xp_boost" },
            { name = "Buy Diamond Sword (25 gems)", action = "buy_diamond_sword" },
            { name = "Buy ⚡ Speed Potion (5 gems)", action = "buy_speed_potion" },
            { name = "Buy 📜 Trader Scroll (150 coins)", action = "buy_trader_scroll" },
        },
    },
    effects = {
        title = "⚡ Effects Testing",
        tests = {
            { name = "Test Effect Stacking", action = "test_effect_stacking" },
            { name = "Start Hatch Luck Hour", action = "start_hatch_luck_hour" },
            { name = "Start Double Rewards Hour", action = "start_double_rewards_hour" },
            { name = "Start Crystal Rush", action = "start_crystal_rush" },
            { name = "Start Coin Shower", action = "start_coin_shower" },
            { name = "Show Active Global Events", action = "show_global_events" },
            { name = "Clear Global Events", action = "clear_global_events" },
        },
    },
    system = {
        title = "🔧 System Testing",
        tests = {
            { name = "Test Rate Limiting", action = "test_rate_limiting" },
            { name = "Debug: Print Current Data", action = "debug_print_data" },
            { name = "Performance Test", action = "performance_test" },
            { name = "Network Bridge Test", action = "network_test" },
            { name = "Run Diagnostics", action = "run_diagnostics" },
        },
    },
    currency = {
        title = "💎 Currency Management",
        tests = {
            { name = "Add 1000 Coins", action = "add_coins_1000" },
            { name = "Add 100 Gems", action = "add_gems_100" },
            { name = "Add 50 Crystals", action = "add_crystals_50" },
            -- Grants 100k to EACH per-biome currency (grass/ice/lava/desert) in one click.
            -- The legacy "Add Coins" button grants the unused generic `coins`; the zone-unlock
            -- gates + egg costs run on biome coins, so use this to test progression.
            { name = "Add 100k Area Coins", action = "add_area_coins" },
            { name = "Reset All Currencies", action = "reset_currencies" },
        },
        customInputs = {
            {
                label = "Adjust Coins (+ to add, - to remove):",
                placeholder = "e.g. +1M, -500K, +2.5B, +42",
                currency = "coins",
                action = "adjust_coins_custom",
            },
            {
                label = "Adjust Gems (+ to add, - to remove):",
                placeholder = "e.g. +1M, -100K, +1T, +500",
                currency = "gems",
                action = "adjust_gems_custom",
            },
        },
    },
    developer = {
        title = "🧰 Developer Tools",
        tests = {
            { name = "📋 Snapshot Target Player", action = "admin_snapshot" },
            { name = "💾 Force Save Target Player", action = "admin_force_save" },
            { name = "🗑️ Reset Pets (Target)", action = "admin_reset_pets" },
            -- label says what the guard actually protects: ALL unique pets (per-uid
            -- records — huges, secrets/dragons, exclusives), not just huges (Jason
            -- almost didn't click it: "am I gonna lose my dragon?")
            {
                name = "🔄 Reset to Beginning (keeps ALL unique pets)",
                action = "admin_reset_to_beginning",
            },
            {
                name = "🔎 Reset to Beginning — PREVIEW",
                action = "admin_reset_to_beginning_preview",
            },
            { name = "🐻 Grant Bear Basic", action = "grant_bear_basic" },
            { name = "🐉 Grant Dragon Basic", action = "grant_dragon_basic" },
            { name = "🐻 Grant Golden Bear", action = "grant_bear_golden" },
            { name = "👤 Grant Colorado", action = "grant_colorado_basic" },
            { name = "👑 Grant Golden Colorado", action = "grant_colorado_golden" },
            { name = "🌈 Grant Rainbow Colorado", action = "grant_colorado_rainbow" },
            { name = "⬆ Grant Huge Rainbow Colorado", action = "grant_colorado_huge" },
            { name = "👑 Grant CREATOR Colorado (apex)", action = "grant_colorado_creator" },
            { name = "🗺️ Toggle Meadow Lock", action = "toggle_zone_meadow" },
            { name = "🗺️ Lock Meadow", action = "lock_zone_meadow" },
            { name = "🗺️ Unlock Meadow", action = "unlock_zone_meadow" },
            { name = "🗺️ Bypass Unlock Meadow", action = "unlock_zone_meadow_bypass" },
            { name = "🎲 +100 Area Enhancements", action = "grant_enhancements_100" },
            { name = "🥚 Hatch Unlock Status", action = "hatch_entitlement_status" },
            { name = "🥚 Unlock All Hatch Modes", action = "hatch_entitlement_unlock_all" },
            { name = "🥚 Lock All Hatch Modes", action = "hatch_entitlement_lock_all" },
            { name = "🥚 Reset Hatch Unlocks", action = "hatch_entitlement_reset_all" },
            { name = "🥚 Toggle Golden Hatch", action = "hatch_entitlement_toggle_golden" },
            { name = "🥚 Toggle Charged Hatch", action = "hatch_entitlement_toggle_charged" },
            { name = "🥚 Set Max Hatch 99", action = "hatch_entitlement_max_99" },
            { name = "🥚 Recent Hatch History", action = "hatch_history_recent" },
            { name = "🥚 Simulate 25 Basic Egg", action = "hatch_simulation_basic_25" },
        },
        customInputs = {
            {
                label = "Grant Pet (pet:variant:quantity[:huge]):",
                placeholder = "e.g. bear:basic:3, colorado:basic:1:huge",
                action = "grant_pet_custom",
            },
            {
                label = "Set Zone Lock (zoneId:toggle|lock|unlock|bypass):",
                placeholder = "e.g. Meadow:toggle, Meadow:lock, meadow_island:bypass",
                action = "set_zone_lock_custom",
            },
            {
                label = "Set Hatch Unlock (name:mode/value):",
                placeholder = "e.g. goldenMode:unlock, chargedMode:lock, maxHatchCount:25",
                action = "set_hatch_entitlement_custom",
            },
            {
                label = "Set Max Hatch (3-99):",
                placeholder = "e.g. 25 (clamped to 3-99)",
                action = "set_max_hatch_count",
            },
        },
    },
    combat = {
        title = "⚔️ Combat (test enemies)",
        tests = {
            -- Earth faction (real art): melee dog · ranged crow/cat · support bunny · tank bear.
            { name = "🐕 Spawn Rabid Dog (melee)", action = "spawn_enemy_rabid_dog" },
            { name = "🐦 Spawn Murder Crow (ranged)", action = "spawn_enemy_murder_crow" },
            { name = "🐈 Spawn Vicious Cat (ranged)", action = "spawn_enemy_vicious_cat" },
            { name = "🐰 Spawn Jackalope (healer)", action = "spawn_enemy_rabid_bunny" },
            { name = "🐻 Spawn Raging Bear (tank)", action = "spawn_enemy_raging_bear" },
            -- Desert faction.
            { name = "🦊 Spawn Sand Jackal (melee)", action = "spawn_enemy_sand_jackal" },
            {
                name = "🦅 Spawn Carrion Vulture (ranged)",
                action = "spawn_enemy_carrion_vulture",
            },
            { name = "🪲 Spawn Golden Scarab (healer)", action = "spawn_enemy_golden_scarab" },
            { name = "🐢 Spawn Dune Tortoise (tank)", action = "spawn_enemy_dune_tortoise" },
            { name = "🦂 Spawn Sand Scorpion (boss)", action = "spawn_enemy_sand_scorpion" },
            -- Ice faction.
            { name = "🦊 Spawn Frost Fox (melee)", action = "spawn_enemy_frost_fox" },
            { name = "🦉 Spawn Snowy Owl (ranged)", action = "spawn_enemy_snowy_owl" },
            { name = "🦭 Spawn Aurora Seal (healer)", action = "spawn_enemy_aurora_seal" },
            { name = "🐘 Spawn Glacial Mammoth (tank)", action = "spawn_enemy_glacial_mammoth" },
            {
                name = "🐲 Spawn Glacial Leviathan (boss)",
                action = "spawn_enemy_glacial_leviathan",
            },
            -- Lava faction.
            { name = "🦎 Spawn Cinder Whelp (melee)", action = "spawn_enemy_lava_imp" },
            { name = "🦏 Spawn Ember Brute (tank)", action = "spawn_enemy_ember_brute" },
            { name = "🦋 Spawn Ember Moth (healer)", action = "spawn_enemy_ember_acolyte" },
            { name = "🐉 Spawn Magma Wyrm (boss)", action = "spawn_enemy_infernal_boss" },
        },
        customInputs = {
            {
                label = "Spawn Enemy (id):",
                placeholder = "e.g. rabid_dog, murder_crow, raging_bear, ember_brute",
                action = "spawn_enemy_custom",
            },
        },
    },
    logging = {
        title = "📊 Logging Controls",
        tests = {
            { name = "Show Current Log Config", action = "show_log_config" },
            { name = "Set All to INFO", action = "set_all_info" },
            { name = "Set All to DEBUG", action = "set_all_debug" },
            { name = "Set All to WARN", action = "set_all_warn" },
            { name = "Disable Console Output", action = "disable_console" },
            { name = "Enable Console Output", action = "enable_console" },
            { name = "Enable Performance Logs", action = "enable_performance" },
            { name = "Disable Performance Logs", action = "disable_performance" },
        },
        customInputs = {
            {
                label = "Set Service Log Level (service:level):",
                placeholder = "e.g. EggPetPreviewService:debug, BaseUI:warn",
                action = "set_service_log_level",
            },
        },
    },
    inventory = {
        title = "🎒 Inventory Management",
        tests = {
            { name = "🗑️ Remove Orphaned Buckets", action = "cleanup_inventory" },
            { name = "🔧 Fix Item Categories", action = "fix_item_categories" },
        },
    },
    assets = {
        title = "🖼️ Asset Debugging",
        tests = {
            { name = "🔍 View All Generated Images", action = "view_all_assets" },
            { name = "🥚 Debug Egg ViewportFrames", action = "debug_egg_viewports" },
            { name = "🐾 Debug Pet ViewportFrames", action = "debug_pet_viewports" },
            { name = "📊 Asset Generation Stats", action = "asset_stats" },
            { name = "🔄 Force Regenerate Assets", action = "force_regenerate_assets" },
        },
    },
    eggHatching = {
        title = "🥚 Egg Hatching Simulation",
        tests = {
            { name = "🥚 Hatch 1 Egg (Random Pet)", action = "hatch_1_egg" },
            { name = "🥚🥚 Hatch 3 Eggs (Random Pets)", action = "hatch_3_eggs" },
            { name = "🥚🥚🥚 Hatch 5 Eggs (Random Pets)", action = "hatch_5_eggs" },
            { name = "🥚🥚🥚🥚 Hatch 10 Eggs (Random Pets)", action = "hatch_10_eggs" },
            { name = "🥚🥚🥚🥚🥚 Hatch 25 Eggs (Random Pets)", action = "hatch_25_eggs" },
            {
                name = "🥚🥚🥚🥚🥚🥚 Hatch 42 Eggs (Random Pets)",
                action = "hatch_42_eggs",
            },
            { name = "🎲 Hatch 99 Eggs (Random Pets)", action = "hatch_99_eggs" },
        },
        customInputs = {
            {
                label = "Custom Egg Count (1-99):",
                placeholder = "e.g. 15, 50, 99",
                action = "hatch_custom_eggs",
            },
            {
                label = "Specific Pet (petType:variant):",
                placeholder = "e.g. bear:basic, dragon:golden, kitty:rainbow",
                action = "hatch_specific_pet",
            },
        },
    },
}

function AdminPanel.new()
    local self = setmetatable({}, AdminPanel)

    self.logger = LoggerWrapper.new("AdminPanel")
    self.templateManager = TemplateManager.new()

    -- Panel state
    self.isVisible = false
    self.frame = nil

    -- Network bridges
    self.economyBridge = nil
    self.effectsBridge = nil

    -- Player targeting state (NEW)
    self.selectedTargetPlayerId = nil -- nil = self, number = target player ID
    self.playerList = {}
    self.playerDropdown = nil
    self.targetPlayerLabel = nil
    self.resultLabel = nil

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

    self.isVisible = false
    self.logger:info("Admin panel hidden")
end

function AdminPanel:_createUI(parent)
    -- Shared window shell (area-themed pill + header + close X on top).
    local shell = PanelChrome.build(parent, {
        name = "AdminPanel",
        title = "🛠️ Admin Control Panel",
        size = UDim2.new(0.8, 0, 0.9, 0),
        onClose = function()
            self:Hide()
        end,
    })
    self.frame = shell.frame
    self._areaKey = shell.areaKey

    -- Caution band (admin warning) just under the header.
    local warningLabel = Instance.new("TextLabel")
    warningLabel.Name = "Warning"
    warningLabel.AnchorPoint = Vector2.new(0.5, 0)
    warningLabel.Size = UDim2.new(0.96, 0, 0, 26)
    warningLabel.Position = UDim2.new(0.5, 0, 0.12, 0)
    warningLabel.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
    warningLabel.BorderSizePixel = 0
    warningLabel.Text = "⚠️ ADMIN TOOLS - USE WITH CAUTION ⚠️"
    warningLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    warningLabel.TextSize = 15
    warningLabel.Font = Enum.Font.GothamBold
    warningLabel.ZIndex = 102
    warningLabel.Parent = self.frame
    local warningCorner = Instance.new("UICorner")
    warningCorner.CornerRadius = UDim.new(0, 8)
    warningCorner.Parent = warningLabel

    -- Player selection + result display (positioned relatively below the warning band).
    self:_createPlayerSelector()
    self:_createResultDisplay()

    -- Scroll frame for test categories (bottom portion).
    local scrollFrame = Instance.new("ScrollingFrame")
    scrollFrame.Name = "AdminScroll"
    scrollFrame.AnchorPoint = Vector2.new(0.5, 0)
    scrollFrame.Size = UDim2.new(0.96, 0, 0.62, 0)
    scrollFrame.Position = UDim2.new(0.5, 0, 0.36, 0)
    scrollFrame.BackgroundTransparency = 1
    scrollFrame.BorderSizePixel = 0
    scrollFrame.ScrollBarThickness = 8
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scrollFrame.ZIndex = 101
    scrollFrame.Parent = self.frame

    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Vertical
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 12)
    layout.Parent = scrollFrame

    self.scrollFrame = scrollFrame

    -- Create test category sections
    self:_createTestCategories()

    -- Load player list on panel open
    self:_refreshPlayerList()
end

function AdminPanel:_createTestCategories()
    local layoutOrder = 1

    for _, categoryData in pairs(TEST_CATEGORIES) do
        self:_createCategorySection(categoryData.title, categoryData, layoutOrder)
        layoutOrder = layoutOrder + 1
    end
end

function AdminPanel:_createCategorySection(title, categoryData, layoutOrder)
    local theme = uiConfig.helpers.get_theme(uiConfig)
    local tests = categoryData.tests or categoryData -- Support both old format and new format
    local customInputs = categoryData.customInputs or {}

    -- Calculate total height needed
    local totalItems = #tests + (#customInputs * 2) -- Custom inputs take 2 rows each (label + input)
    local containerHeight = totalItems * 45 + 10

    -- Category header — shared area-themed section band.
    PanelChrome.sectionHeader(self.scrollFrame, { title = title, layoutOrder = layoutOrder })

    -- Tests container
    local testsContainer = Instance.new("Frame")
    testsContainer.Name = title .. "Tests"
    testsContainer.Size = UDim2.new(1, 0, 0, containerHeight)
    testsContainer.BackgroundColor3 = theme.primary.card or Color3.fromRGB(50, 50, 55)
    testsContainer.BorderSizePixel = 0
    testsContainer.LayoutOrder = layoutOrder + 0.5
    testsContainer.Parent = self.scrollFrame

    local testsCorner = Instance.new("UICorner")
    testsCorner.CornerRadius = UDim.new(0, 8)
    testsCorner.Parent = testsContainer

    local testsLayout = Instance.new("UIListLayout")
    testsLayout.FillDirection = Enum.FillDirection.Vertical
    testsLayout.SortOrder = Enum.SortOrder.LayoutOrder
    testsLayout.Padding = UDim.new(0, 5)
    testsLayout.Parent = testsContainer

    local testsPadding = Instance.new("UIPadding")
    testsPadding.PaddingTop = UDim.new(0, 10)
    testsPadding.PaddingBottom = UDim.new(0, 5)
    testsPadding.PaddingLeft = UDim.new(0, 10)
    testsPadding.PaddingRight = UDim.new(0, 10)
    testsPadding.Parent = testsContainer

    local currentLayoutOrder = 1

    -- Create test buttons
    for _, test in ipairs(tests) do
        self:_createTestButton(test.name, test.action, currentLayoutOrder, testsContainer)
        currentLayoutOrder = currentLayoutOrder + 1
    end

    -- Create custom input fields
    for _, inputConfig in ipairs(customInputs) do
        self:_createCustomInput(inputConfig, currentLayoutOrder, testsContainer)
        currentLayoutOrder = currentLayoutOrder + 2 -- Takes 2 layout orders (label + input)
    end
end

function AdminPanel:_createTestButton(testName, action, layoutOrder, parent)
    local theme = uiConfig.helpers.get_theme(uiConfig)

    local button = Instance.new("TextButton")
    button.Name = action .. "Button"
    button.Size = UDim2.new(1, 0, 0, 35)
    button.BackgroundColor3 = theme.button and theme.button.primary or Color3.fromRGB(0, 120, 180)
    button.BorderSizePixel = 0
    button.Text = testName
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.TextSize = 13
    button.Font = Enum.Font.Gotham
    button.LayoutOrder = layoutOrder
    button.Parent = parent

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
    inputFrame.Size = UDim2.new(1, 0, 0, 35)
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
    textBox.Size = UDim2.new(0.7, -10, 1, -6)
    textBox.Position = UDim2.new(0, 5, 0, 3)
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
    setButton.Size = UDim2.new(0.3, -5, 1, -6)
    setButton.Position = UDim2.new(0.7, 0, 0, 3)
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
                self.logger:warn("Invalid amount entered:", textBox.Text)
            end
        else
            -- Other custom actions (like logging)
            local inputValue = textBox.Text
            if inputValue and inputValue ~= "" then
                self:_executeCustomAction(inputConfig.action, inputValue)
                textBox.Text = "" -- Clear after executing
            else
                self.logger:warn("Empty input provided")
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
    local finalAmount = math.floor(numericValue * multiplier * sign)

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

    -- Economy actions
    if action:find("buy_") then
        self:_executePurchaseAction(action)
    elseif action:find("add_") then
        self:_executeCurrencyAction(action)
    elseif action == "reset_currencies" then
        self:_resetCurrencies()
    elseif action == "admin_snapshot" then
        self:_requestPlayerSnapshot()
    elseif action == "admin_force_save" then
        self:_requestForceSave()
    elseif action == "admin_reset_pets" then
        self:_requestResetPets()
    elseif action == "admin_reset_to_beginning" then
        self:_requestResetToBeginning(false)
    elseif action == "admin_reset_to_beginning_preview" then
        self:_requestResetToBeginning(true)
    elseif action == "grant_enhancements_100" then
        task.spawn(function()
            local remote = game:GetService("ReplicatedStorage"):WaitForChild("GameAPICommand", 5)
            if not remote then
                self:_showAdminResult("GameAPICommand remote missing", false)
                return
            end
            local res = remote:InvokeServer("enh.grant", { count = 100 })
            local r = type(res) == "table" and (res.result or res.data or res) or res
            self:_showAdminResult(
                ("Granted %s random area enhancements"):format(tostring(r and r.granted or "?")),
                r and r.ok == true
            )
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
    elseif action:find("effect") or action:find("start_") then
        self:_executeEffectAction(action)

    -- System actions
    elseif action == "test_rate_limiting" then
        self:_testRateLimit()
    elseif action == "debug_print_data" then
        self:_debugPrintData()
    elseif action == "performance_test" then
        self:_performanceTest()
    elseif action == "network_test" then
        self:_networkTest()

    -- Logging control actions
    elseif action:find("log") or action:find("console") or action:find("performance") then
        self:_executeLoggingAction(action)

    -- Inventory management actions
    elseif action == "cleanup_inventory" then
        self:_cleanupInventory()
    elseif action == "fix_item_categories" then
        self:_fixItemCategories()

    -- Asset debugging actions
    elseif action == "view_all_assets" then
        self:_viewAllAssets()
    elseif action == "debug_egg_viewports" then
        self:_debugEggViewports()
    elseif action == "debug_pet_viewports" then
        self:_debugPetViewports()
    elseif action == "asset_stats" then
        self:_showAssetStats()
    elseif action == "force_regenerate_assets" then
        self:_forceRegenerateAssets()

    -- Egg hatching simulation actions
    elseif action:find("hatch_") then
        self:_executeEggHatchingAction(action)
    else
        self.logger:warn("Unknown action:", action)
    end
end

function AdminPanel:_executePurchaseAction(action)
    if not self.economyBridge then
        self.logger:warn("Economy bridge not available")
        return
    end

    -- Map actions to purchase data
    local purchases = {
        buy_test_item = { itemId = "test_item", cost = 50, currency = "coins" },
        buy_health_potion = { itemId = "health_potion", cost = 25, currency = "coins" },
        buy_wooden_sword = { itemId = "wooden_sword", cost = 100, currency = "coins" },
        buy_iron_sword = { itemId = "iron_sword", cost = 500, currency = "coins" },
        buy_basic_pickaxe = { itemId = "basic_pickaxe", cost = 200, currency = "coins" },
        buy_premium_xp_boost = { itemId = "premium_xp_boost", cost = 10, currency = "gems" },
        buy_diamond_sword = { itemId = "diamond_sword", cost = 25, currency = "gems" },
        buy_speed_potion = { itemId = "speed_potion", cost = 5, currency = "gems" },
        buy_trader_scroll = { itemId = "trader_scroll", cost = 150, currency = "coins" },
    }

    local purchaseData = purchases[action]
    if purchaseData then
        -- Add target player data if selected
        local actionData = self:_getAdminActionData(purchaseData)

        -- 🔍 DEBUG: Check if bridge exists and is callable
        self.logger:info("🔍 ADMIN PANEL - About to call bridge Fire", {
            hasBridge = self.economyBridge ~= nil,
            bridgeType = typeof(self.economyBridge),
            hasFireMethod = self.economyBridge and typeof(self.economyBridge.Fire) == "function",
            item = purchaseData.itemId,
            targetData = actionData,
        })

        if not self.economyBridge then
            self.logger:warn("🚨 ADMIN PANEL - Economy bridge is nil!")
            return
        end

        if not self.economyBridge.Fire then
            self.logger:warn("🚨 ADMIN PANEL - Economy bridge has no Fire method!")
            return
        end

        Signals.PurchaseItem:FireServer(actionData)
        self.logger:info(
            "Purchase request sent:",
            { item = purchaseData.itemId, targetData = actionData }
        )
    end
end

function AdminPanel:_executeCurrencyAction(action)
    if not self.economyBridge then
        self.logger:warn("Economy bridge not available")
        return
    end

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
    if not self.economyBridge then
        self.logger:warn("Economy bridge not available")
        return
    end

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
    if not self.economyBridge then
        self.logger:warn("Economy bridge not available")
        return
    end

    -- Add target player data if selected
    local actionData = self:_getAdminActionData({})
    Signals.AdjustCurrency:FireServer({ reset = true, target = actionData.target })
    self.logger:info("Currency reset requested:", actionData)
end

function AdminPanel:_executeEffectAction(action)
    self.logger:info("Effect action:", action)

    local eventActions = {
        test_effect_stacking = {
            command = "start",
            eventId = "hatch_luck_hour",
            durationSeconds = 300,
        },
        start_xp_weekend = { command = "start", eventId = "double_rewards_hour" },
        start_speed_hour = { command = "start", eventId = "crystal_rush" },
        start_hatch_luck_hour = { command = "start", eventId = "hatch_luck_hour" },
        start_double_rewards_hour = { command = "start", eventId = "double_rewards_hour" },
        start_crystal_rush = { command = "start", eventId = "crystal_rush" },
        start_coin_shower = { command = "start", eventId = "coin_shower" },
        show_global_events = { command = "snapshot" },
        clear_global_events = { command = "clear" },
    }

    local command = eventActions[action]
    if not command then
        self:_showAdminResult("Unknown event action: " .. tostring(action), false)
        return
    end

    command.reason = "Admin panel: " .. tostring(action)
    Signals.Admin_EventCommand:FireServer(command)
    self:_showAdminResult("Event command sent: " .. tostring(action), true)
end

function AdminPanel:_testRateLimit()
    self.logger:info("Testing rate limits...")
    -- After migrating to sleitnick/Net, the legacy NetworkBridge is no longer available.
    -- Temporarily disable this until a Net-based rate-limit test is implemented.
    self.logger:warn("Rate-limit test disabled pending Net migration")
end

function AdminPanel:_debugPrintData()
    local player = Players.LocalPlayer
    print("=== DEBUG: Player Data ===")
    print("Player:", player.Name)
    print("UserId:", player.UserId)
    if player:FindFirstChild("leaderstats") then
        print("Leaderstats found:")
        for _, stat in pairs(player.leaderstats:GetChildren()) do
            print("  ", stat.Name, "=", stat.Value)
        end
    else
        print("No leaderstats found")
    end
    print("=== END DEBUG ===")
end

function AdminPanel:_performanceTest()
    self.logger:info("Running performance test...")
    local startTime = tick()

    -- Create and destroy many UI elements
    for _ = 1, 1000 do
        local testFrame = Instance.new("Frame")
        testFrame.Size = UDim2.new(0, 10, 0, 10)
        testFrame.Parent = workspace
        testFrame:Destroy()
    end

    local endTime = tick()
    self.logger:info("Performance test completed in", endTime - startTime, "seconds")
end

function AdminPanel:_runDiagnostics()
    self.logger:info("Running diagnostics...")
    Signals.RunDiagnostics:FireServer()
end

function AdminPanel:_networkTest()
    self.logger:info("Testing network connections...")
    if self.economyBridge then
        self.logger:info("Economy bridge: CONNECTED")
    else
        self.logger:warn("Economy bridge: NOT CONNECTED")
    end

    if self.effectsBridge then
        self.logger:info("Effects bridge: CONNECTED")
    else
        self.logger:warn("Effects bridge: NOT CONNECTED")
    end
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

            local Logger = loggerResult
            Logger:SetServiceLogLevel(serviceName, levelString)
            self.logger:info("Set service log level", {
                service = serviceName,
                level = levelString,
            })
        else
            self.logger:warn("Invalid format. Use 'ServiceName:level' or 'ServiceName level'")
            print("Invalid format. Examples:")
            print("  EggPetPreviewService:debug")
            print("  BaseUI warn")
            print("  AssetPreloadService:info")
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
    task.spawn(function()
        task.wait(2) -- Wait for Signals to initialize

        -- Use new Signals system instead of old NetworkBridge
        self.economyBridge = {
            Fire = function(_, _action, data)
                if Signals.PurchaseItem then
                    Signals.PurchaseItem:FireServer(data)
                end
            end,
        }

        -- Listen for diagnostics result once
        if Signals.RunDiagnostics then
            Signals.RunDiagnostics.OnClientEvent:Connect(function(report)
                self:_showDiagnosticsPopup(report)
            end)
        end

        if Signals.AdminToolResult then
            Signals.AdminToolResult.OnClientEvent:Connect(function(result)
                self:_handleAdminToolResult(result)
            end)
        end

        self.logger:info("Economy bridge connected via Signals")
    end)
end

-- Public interface methods
function AdminPanel:IsVisible()
    return self.isVisible
end

function AdminPanel:GetFrame()
    return self.frame
end

function AdminPanel:Destroy()
    self:Hide()
    self.logger:info("Admin panel destroyed")
end

-- Player Selection Methods (NEW)
function AdminPanel:_createPlayerSelector()
    local theme = uiConfig.helpers.get_theme(uiConfig)

    -- Player selector container
    local selectorContainer = Instance.new("Frame")
    selectorContainer.Name = "PlayerSelector"
    selectorContainer.AnchorPoint = Vector2.new(0.5, 0)
    selectorContainer.Size = UDim2.new(0.96, 0, 0, 40)
    selectorContainer.Position = UDim2.new(0.5, 0, 0.18, 0)
    selectorContainer.BackgroundColor3 = theme.primary.card or Color3.fromRGB(60, 60, 65)
    selectorContainer.BorderSizePixel = 0
    selectorContainer.ZIndex = 102
    selectorContainer.Parent = self.frame

    local selectorCorner = Instance.new("UICorner")
    selectorCorner.CornerRadius = UDim.new(0, 8)
    selectorCorner.Parent = selectorContainer

    -- Label
    local selectorLabel = Instance.new("TextLabel")
    selectorLabel.Name = "Label"
    selectorLabel.Size = UDim2.new(0, 120, 1, 0)
    selectorLabel.Position = UDim2.new(0, 10, 0, 0)
    selectorLabel.BackgroundTransparency = 1
    selectorLabel.Text = "🎯 Target Player:"
    selectorLabel.TextColor3 = theme.text.primary or Color3.fromRGB(255, 255, 255)
    selectorLabel.TextSize = 14
    selectorLabel.Font = Enum.Font.Gotham
    selectorLabel.TextXAlignment = Enum.TextXAlignment.Left
    selectorLabel.Parent = selectorContainer

    -- Current target display
    self.targetPlayerLabel = Instance.new("TextLabel")
    self.targetPlayerLabel.Name = "CurrentTarget"
    self.targetPlayerLabel.Size = UDim2.new(0, 150, 1, 0)
    self.targetPlayerLabel.Position = UDim2.new(0, 130, 0, 0)
    self.targetPlayerLabel.BackgroundTransparency = 1
    self.targetPlayerLabel.Text = "Self (You)"
    self.targetPlayerLabel.TextColor3 = Color3.fromRGB(100, 200, 100) -- Green for self
    self.targetPlayerLabel.TextSize = 14
    self.targetPlayerLabel.Font = Enum.Font.GothamBold
    self.targetPlayerLabel.TextXAlignment = Enum.TextXAlignment.Left
    self.targetPlayerLabel.Parent = selectorContainer

    -- Dropdown button
    local dropdownButton = Instance.new("TextButton")
    dropdownButton.Name = "DropdownButton"
    dropdownButton.Size = UDim2.new(0, 120, 0, 30)
    dropdownButton.Position = UDim2.new(1, -130, 0, 5)
    dropdownButton.BackgroundColor3 = theme.primary.accent or Color3.fromRGB(0, 120, 180)
    dropdownButton.BorderSizePixel = 0
    dropdownButton.Text = "📝 Select Player"
    dropdownButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    dropdownButton.TextSize = 12
    dropdownButton.Font = Enum.Font.Gotham
    dropdownButton.Parent = selectorContainer

    local dropdownCorner = Instance.new("UICorner")
    dropdownCorner.CornerRadius = UDim.new(0, 6)
    dropdownCorner.Parent = dropdownButton

    dropdownButton.Activated:Connect(function()
        self:_showPlayerDropdown()
    end)

    self.playerDropdown = dropdownButton
end

function AdminPanel:_createResultDisplay()
    local theme = uiConfig.helpers.get_theme(uiConfig)

    local resultContainer = Instance.new("Frame")
    resultContainer.Name = "AdminResult"
    resultContainer.AnchorPoint = Vector2.new(0.5, 0)
    resultContainer.Size = UDim2.new(0.96, 0, 0, 56)
    resultContainer.Position = UDim2.new(0.5, 0, 0.26, 0)
    resultContainer.BackgroundColor3 = theme.primary.card or Color3.fromRGB(45, 45, 50)
    resultContainer.BorderSizePixel = 0
    resultContainer.ZIndex = 102
    resultContainer.Parent = self.frame

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = resultContainer

    self.resultLabel = Instance.new("TextLabel")
    self.resultLabel.Name = "ResultText"
    self.resultLabel.Size = UDim2.new(1, -20, 1, -10)
    self.resultLabel.Position = UDim2.new(0, 10, 0, 5)
    self.resultLabel.BackgroundTransparency = 1
    self.resultLabel.Text = "Admin tools ready. Select a target, then run a developer action."
    self.resultLabel.TextColor3 = theme.text.primary or Color3.fromRGB(255, 255, 255)
    self.resultLabel.TextSize = 12
    self.resultLabel.Font = Enum.Font.Gotham
    self.resultLabel.TextXAlignment = Enum.TextXAlignment.Left
    self.resultLabel.TextYAlignment = Enum.TextYAlignment.Top
    self.resultLabel.TextWrapped = true
    self.resultLabel.Parent = resultContainer
end

function AdminPanel:_showAdminResult(message, success)
    if self.resultLabel then
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
    -- Request updated player list from server
    if self.economyBridge then
        self.economyBridge:Fire("get_player_list", {})
        self.logger:info("Requested player list from server")
    else
        self.logger:warn("Cannot refresh player list - economy bridge not available")
    end
end

function AdminPanel:_showPlayerDropdown()
    -- Simple implementation: cycle through available players
    local players = game.Players:GetPlayers()
    local currentIndex = 1

    -- Find current selection
    if self.selectedTargetPlayerId then
        for i, player in ipairs(players) do
            if player.UserId == self.selectedTargetPlayerId then
                currentIndex = i
                break
            end
        end
    end

    -- Move to next player (or back to self)
    local nextIndex = currentIndex + 1
    if nextIndex > #players then
        -- Back to self
        self.selectedTargetPlayerId = nil
        self.targetPlayerLabel.Text = "Self (You)"
        self.targetPlayerLabel.TextColor3 = Color3.fromRGB(100, 200, 100) -- Green
        self.logger:info("Target changed to: Self")
    else
        local targetPlayer = players[nextIndex]
        self.selectedTargetPlayerId = targetPlayer.UserId
        self.targetPlayerLabel.Text = targetPlayer.Name
        self.targetPlayerLabel.TextColor3 = Color3.fromRGB(255, 200, 100) -- Orange for others
        self.logger:info(
            "Target changed to: " .. targetPlayer.Name,
            { targetUserId = targetPlayer.UserId }
        )
    end
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
    }

    local grantData = quickGrants[action]
    if not grantData then
        self.logger:warn("Unknown pet grant action:", action)
        return
    end

    Signals.Admin_GrantPet:FireServer(self:_getAdminActionData(grantData))
    self:_showAdminResult(
        "Pet grant requested: " .. grantData.petType .. ":" .. grantData.variant,
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

    return string.format(
        "%s | Coins %s, Gems %s, Crystals %s | Pets %d (%d entries), Equipped %d/%d | Hatch %s | Auto low=%s high=%s | Data %s/%s | Save dirty=%s scheduled=%s inFlight=%s reason=%s",
        snapshot.name or "Player",
        tostring(currencies.coins or 0),
        tostring(currencies.gems or 0),
        tostring(currencies.crystals or 0),
        snapshot.petCount or 0,
        snapshot.petEntryCount or 0,
        snapshot.equippedPetCount or 0,
        snapshot.equippedPetLimit or 0,
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
    -- Simple Roblox alert replacement
    self.logger:info(message)
    print(message)
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

function AdminPanel:_viewAllAssets()
    self.logger:info("🔍 ADMIN: Opening comprehensive asset viewer")

    local success, viewer = pcall(function()
        return self:_createComprehensiveAssetViewer()
    end)

    if success and viewer then
        self.logger:info("✅ Asset viewer opened successfully")
    else
        self.logger:error("❌ Failed to open asset viewer:", viewer)
    end
end

function AdminPanel:_debugEggViewports()
    self.logger:info("🥚 ADMIN: Opening egg ViewportFrame debugger")

    local success, debugger = pcall(function()
        local EggHatchingService = require(ReplicatedStorage.Shared.Services.EggHatchingService)
        return EggHatchingService:DebugEggViewports()
    end)

    if success and debugger then
        self.logger:info("✅ Egg debugger opened successfully")
    else
        self.logger:error("❌ Failed to open egg debugger:", debugger)
    end
end

function AdminPanel:_debugPetViewports()
    self.logger:info("🐾 ADMIN: Opening pet ViewportFrame debugger - Coming Soon!")
    -- Placeholder for now
end

function AdminPanel:_showAssetStats()
    self.logger:info("📊 ADMIN: Showing asset generation statistics")

    -- Quick stats display
    local assetsFolder = ReplicatedStorage:FindFirstChild("Assets")
    if not assetsFolder then
        self.logger:error("Assets folder not found!")
        return
    end

    local stats = {}
    table.insert(stats, "📊 ASSET GENERATION STATISTICS")
    table.insert(
        stats,
        "════════════════════════════════"
    )

    -- Count eggs
    local eggsFolder = assetsFolder:FindFirstChild("Images")
        and assetsFolder.Images:FindFirstChild("Eggs")
    local eggCount = 0
    if eggsFolder then
        for _, child in pairs(eggsFolder:GetChildren()) do
            if child:IsA("ViewportFrame") then
                eggCount = eggCount + 1
            end
        end
    end
    table.insert(stats, "🥚 Generated Eggs: " .. eggCount)

    -- Count pets
    local petsFolder = assetsFolder:FindFirstChild("Images")
        and assetsFolder.Images:FindFirstChild("Pets")
    local petCount = 0
    local variantCount = 0
    if petsFolder then
        for _, petTypeFolder in pairs(petsFolder:GetChildren()) do
            if petTypeFolder:IsA("Folder") then
                petCount = petCount + 1
                for _, variant in pairs(petTypeFolder:GetChildren()) do
                    if variant:IsA("ViewportFrame") then
                        variantCount = variantCount + 1
                    end
                end
            end
        end
    end
    table.insert(stats, "🐾 Pet Types: " .. petCount)
    table.insert(stats, "🎨 Pet Variants: " .. variantCount)
    table.insert(stats, "📁 Total Generated Images: " .. (eggCount + variantCount))

    self.logger:info(table.concat(stats, "\n"))
end

function AdminPanel:_createComprehensiveAssetViewer()
    -- Placeholder - will implement the full scrollable viewer
    self.logger:info("📋 Comprehensive asset viewer - placeholder implementation")
    self.logger:info("Use 'Debug Egg ViewportFrames' button for now")
    return true
end

function AdminPanel:_forceRegenerateAssets()
    self.logger:info("🔄 ADMIN: Force regenerating all assets with updated positioning")

    -- Send signal to server to trigger AssetPreloadService regeneration
    local success = pcall(function()
        Signals.ForceRegenerateAssets:FireServer({
            requestedBy = Players.LocalPlayer.UserId,
            reason = "Admin debug - fixing egg positioning",
        })
    end)

    if success then
        self.logger:info("✅ Asset regeneration request sent to server")
        self.logger:info("⏱️ Check server console for regeneration progress")
    else
        self.logger:error("❌ Failed to send regeneration request")
    end
end

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
