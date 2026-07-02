--[[
    SettingsPanel - Game Settings and Configuration
    
    Features:
    - Audio settings (master volume, effects, music)
    - Graphics settings (quality, performance mode)
    - UI settings (scale, theme preference)
    - Admin panel access (for authorized users)
    - Player preferences and accessibility options
    
    Usage:
    local SettingsPanel = require(script.SettingsPanel)
    local settings = SettingsPanel.new()
    MenuManager:RegisterPanel("Settings", settings)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Get shared modules
local Locations = require(ReplicatedStorage.Shared.Locations)
local Signals = require(ReplicatedStorage.Shared.Network.Signals)
local SoundGroups = require(ReplicatedStorage.Shared.Effects.SoundGroups)
local AudioPrefs = require(script.Parent.Parent.Parent.Systems.AudioPrefs)
-- THE shared panel exterior + pill helpers (window shell, area theming, entry pills).
local PanelChrome = require(script.Parent.Parent.Components.PanelChrome)
-- THE capsule widget used by the currency HUD + ADMIN button (Jason: ON/OFF toggles use this exact pill).
local Pill = require(script.Parent.Parent.Pill)

-- ON/OFF capsule colors + a re-tint helper that mirrors Pill's own gradient/stroke math so a toggle
-- can flip its fill, gradient, and stroke in place.
local TOGGLE_ON = Color3.fromRGB(46, 170, 90)
local TOGGLE_OFF = Color3.fromRGB(95, 100, 110)
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
    local grad = btn:FindFirstChildOfClass("UIGradient")
    if grad then
        grad.Color = ColorSequence.new(lighten(color, 60), color)
    end
    local stroke = btn:FindFirstChildOfClass("UIStroke")
    if stroke then
        stroke.Color = lighten(color, 80)
    end
end

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
        defaults = {
            panel = {
                header = {
                    close_button = {
                        icon = "89257673063270",
                        size = { width = 30, height = 30 },
                        offset = { x = 10, y = -10 },
                        background_color = Color3.fromRGB(220, 60, 60),
                        hover_color = Color3.fromRGB(180, 40, 40),
                        corner_radius = 8,
                    },
                },
            },
        },
    }
end

local SettingsPanel = {}
SettingsPanel.__index = SettingsPanel

local AdminChecker = require(Locations.SharedUtils.AdminChecker)

function SettingsPanel.new()
    local self = setmetatable({}, SettingsPanel)

    self.logger = LoggerWrapper.new("SettingsPanel")
    self.templateManager = TemplateManager.new()

    -- Panel state
    self.isVisible = false
    self.frame = nil

    -- Settings state
    self.settings = {
        -- Default to full volume so the sliders' starting position matches actual loudness
        -- (the buses default to 1.0 = "no change"); drag a bus to 0 to silence it.
        audio = {
            masterVolume = 1.0,
            effectsVolume = 1.0,
            musicVolume = 1.0,
            uiSoundsEnabled = true,
        },
        graphics = {
            quality = "medium", -- low, medium, high
            performanceMode = false,
            reducedMotion = false,
            -- Display method preferences
            inventoryDisplay = "images", -- images, viewports
            eggPreviewDisplay = "images", -- images, viewports
        },
        ui = {
            scale = 1.0,
            theme = "dark", -- dark, light
            showTooltips = true,
            compactMode = false,
        },
        accessibility = {
            highContrast = false,
            largeText = false,
            keyboardNavigation = true,
        },
    }

    -- Check if user is admin (using centralized AdminChecker)
    self.isAdmin = AdminChecker.IsCurrentPlayerAdmin()

    -- Log admin status for debugging
    local adminStatus = AdminChecker.GetAdminStatus()
    self.logger:info("Admin status determined", adminStatus)

    return self
end

function SettingsPanel:Show(parent)
    if self.isVisible then
        return
    end

    self:_createUI(parent)
    self:_loadSettings()

    self.isVisible = true
    self.logger:info("Settings panel shown")
end

function SettingsPanel:Hide()
    if not self.isVisible then
        return
    end

    if self.frame then
        self.frame:Destroy()
        self.frame = nil
    end

    self.isVisible = false
    self.logger:info("Settings panel hidden")
end

function SettingsPanel:_createUI(parent)
    -- Shared window shell (outer pill + area-themed header + close X) — one code path (Jason).
    local shell = PanelChrome.build(parent, {
        name = "SettingsPanel",
        title = "⚙️ Settings",
        onClose = function()
            self:Hide()
        end,
    })
    self.frame = shell.frame
    self._areaKey = shell.areaKey
    self._areaColor = shell.areaColor

    -- Settings list: full width, starts just under the header (content-heavy → tall pane).
    self.scrollFrame = PanelChrome.scrollPane(shell.frame, {
        name = "SettingsScroll",
        position = UDim2.new(0.5, 0, 0.13, 0),
        size = UDim2.new(1, 0, 0.85, 0),
        padding = 12,
    })

    -- Create settings sections
    self:_createAudioSettings()
    self:_createGraphicsSettings()
    self:_createUISettings()
    self:_createPetSettings()
    self:_createHatchSettings()
    self:_createCombatSettings()

    -- (Admin Tools section removed — the tray's dedicated Admin button + performance-monitor button
    -- already cover this; no need to duplicate it inside Settings. Jason.)
end

function SettingsPanel:_createSectionHeader(title, layoutOrder)
    -- Shared area-themed section band (PanelChrome.sectionHeader).
    PanelChrome.sectionHeader(self.scrollFrame, {
        title = title,
        color = self._areaColor,
        layoutOrder = layoutOrder,
    })
end

function SettingsPanel:_createSliderSetting(
    name,
    currentValue,
    minValue,
    maxValue,
    layoutOrder,
    callback
)
    local theme = uiConfig.helpers.get_theme(uiConfig)

    local settingFrame = PanelChrome.entryRow(self.scrollFrame, {
        name = name .. "Setting",
        height = 50,
        corner = 8,
        bg = theme.primary.card or Color3.fromRGB(50, 50, 55),
        layoutOrder = layoutOrder,
    })

    -- Label
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.4, 0, 1, 0)
    label.Position = UDim2.new(0, 15, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = name
    label.TextColor3 = theme.text.primary
    label.TextSize = 14
    label.Font = Enum.Font.Gotham
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = settingFrame

    -- Slider background
    local sliderBG = Instance.new("Frame")
    sliderBG.Size = UDim2.new(0.35, 0, 0, 8)
    sliderBG.Position = UDim2.new(0.45, 0, 0.5, -4)
    sliderBG.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    sliderBG.BorderSizePixel = 0
    sliderBG.Parent = settingFrame

    local sliderCorner = Instance.new("UICorner")
    sliderCorner.CornerRadius = UDim.new(0, 4)
    sliderCorner.Parent = sliderBG

    -- Slider fill
    local sliderFill = Instance.new("Frame")
    local fillPercent = (currentValue - minValue) / (maxValue - minValue)
    sliderFill.Size = UDim2.new(fillPercent, 0, 1, 0)
    sliderFill.Position = UDim2.new(0, 0, 0, 0)
    sliderFill.BackgroundColor3 = theme.primary.accent or Color3.fromRGB(0, 120, 180)
    sliderFill.BorderSizePixel = 0
    sliderFill.Parent = sliderBG

    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(0, 4)
    fillCorner.Parent = sliderFill

    -- Value label
    local valueLabel = Instance.new("TextLabel")
    valueLabel.Size = UDim2.new(0.15, 0, 1, 0)
    valueLabel.Position = UDim2.new(0.85, 0, 0, 0)
    valueLabel.BackgroundTransparency = 1
    valueLabel.Text = tostring(math.floor(currentValue * 100)) .. "%"
    valueLabel.TextColor3 = theme.text.secondary or Color3.fromRGB(200, 200, 200)
    valueLabel.TextSize = 12
    valueLabel.Font = Enum.Font.Gotham
    valueLabel.TextXAlignment = Enum.TextXAlignment.Center
    valueLabel.Parent = settingFrame

    -- Click handling for slider
    local function updateSlider(input)
        local percent = math.clamp(
            (input.Position.X - sliderBG.AbsolutePosition.X) / sliderBG.AbsoluteSize.X,
            0,
            1
        )
        local newValue = minValue + (maxValue - minValue) * percent

        sliderFill.Size = UDim2.new(percent, 0, 1, 0)
        valueLabel.Text = tostring(math.floor(newValue * 100)) .. "%"

        if callback then
            callback(newValue)
        end
    end

    sliderBG.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            updateSlider(input)
        end
    end)
end

function SettingsPanel:_createToggleSetting(name, currentValue, layoutOrder, callback)
    local theme = uiConfig.helpers.get_theme(uiConfig)

    local settingFrame = PanelChrome.entryRow(self.scrollFrame, {
        name = name .. "Setting",
        height = 50,
        corner = 8,
        bg = theme.primary.card or Color3.fromRGB(50, 50, 55),
        layoutOrder = layoutOrder,
    })

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.7, 0, 1, 0)
    label.Position = UDim2.new(0, 15, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = name
    label.TextColor3 = theme.text.primary or Color3.fromRGB(245, 245, 250)
    label.TextSize = 14
    label.Font = Enum.Font.Gotham
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.ZIndex = 2
    label.Parent = settingFrame

    -- ON/OFF as THE shared currency-HUD pill (Pill.button: rounded capsule + gradient + stroke +
    -- child white label). Re-tints green/grey in place on toggle. (Jason: same pill as the currency HUD.)
    local state = currentValue and true or false
    local toggle = Pill.button({
        parent = settingFrame,
        color = state and TOGGLE_ON or TOGGLE_OFF,
        size = UDim2.fromOffset(74, 30),
        position = UDim2.new(1, -88, 0.5, 0),
        anchorPoint = Vector2.new(0, 0.5),
        text = state and "ON" or "OFF",
        textSize = 13,
        zIndex = 106, -- above the entry pill ring (105)
    })
    toggle.Activated:Connect(function()
        state = not state
        retintPill(toggle, state and TOGGLE_ON or TOGGLE_OFF)
        toggle.Label.Text = state and "ON" or "OFF"
        if callback then
            callback(state)
        end
    end)

    return { container = settingFrame, toggle = toggle }
end

function SettingsPanel:_createButtonSetting(name, buttonText, layoutOrder, callback)
    local theme = uiConfig.helpers.get_theme(uiConfig)

    local settingFrame = PanelChrome.entryRow(self.scrollFrame, {
        name = name .. "Setting",
        height = 40,
        corner = 8,
        bg = theme.primary.card or Color3.fromRGB(50, 50, 55),
        layoutOrder = layoutOrder,
    })

    -- Label
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.6, 0, 1, 0)
    label.Position = UDim2.new(0, 15, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = name
    label.TextColor3 = theme.text.primary
    label.TextSize = 14
    label.Font = Enum.Font.Gotham
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = settingFrame

    -- Action button
    local actionButton = Instance.new("TextButton")
    actionButton.Size = UDim2.new(0, 120, 0, 25)
    actionButton.Position = UDim2.new(1, -135, 0.5, -12.5)
    actionButton.BackgroundColor3 = theme.button and theme.button.primary
        or Color3.fromRGB(0, 120, 180)
    actionButton.BorderSizePixel = 0
    actionButton.Text = buttonText
    actionButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    actionButton.TextSize = 12
    actionButton.Font = Enum.Font.Gotham
    actionButton.Parent = settingFrame

    local buttonCorner = Instance.new("UICorner")
    buttonCorner.CornerRadius = UDim.new(0, 6)
    buttonCorner.Parent = actionButton

    actionButton.Activated:Connect(function()
        if callback then
            callback()
        end
    end)
end

function SettingsPanel:_createDropdownSetting(title, currentValue, options, layoutOrder, callback)
    local container = PanelChrome.entryRow(self.scrollFrame, {
        name = title:gsub(" ", ""),
        height = 50,
        corner = 8,
        bg = Color3.fromRGB(50, 50, 55),
        layoutOrder = layoutOrder,
    })

    -- Title label — left padding 15 + size 14 to match the slider/toggle/button rows (Jason: the
    -- dropdown rows weren't aligned with the others). Vertically centered.
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "Title"
    titleLabel.Size = UDim2.new(0.5, -25, 1, 0)
    titleLabel.Position = UDim2.new(0, 15, 0, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = title
    titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    titleLabel.TextSize = 14
    titleLabel.Font = Enum.Font.Gotham
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.TextYAlignment = Enum.TextYAlignment.Center
    titleLabel.ZIndex = 2
    titleLabel.Parent = container

    -- Dropdown button (changed from Frame to TextButton to support clicking)
    local dropdownFrame = Instance.new("TextButton")
    dropdownFrame.Name = "Dropdown"
    dropdownFrame.Size = UDim2.new(0.5, -10, 0, 32)
    dropdownFrame.Position = UDim2.new(0.5, 10, 0.5, -16)
    dropdownFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
    dropdownFrame.BorderSizePixel = 0
    dropdownFrame.Text = "" -- No text on the button itself
    dropdownFrame.ZIndex = 106 -- whole dropdown subtree above the entry pill ring (105)
    dropdownFrame.Parent = container

    local dropdownCorner = Instance.new("UICorner")
    dropdownCorner.CornerRadius = UDim.new(0, 6)
    dropdownCorner.Parent = dropdownFrame

    -- Current value label
    local valueLabel = Instance.new("TextLabel")
    valueLabel.Name = "ValueLabel"
    valueLabel.Size = UDim2.new(1, -40, 1, 0)
    valueLabel.Position = UDim2.new(0, 10, 0, 0)
    valueLabel.BackgroundTransparency = 1
    valueLabel.Text = tostring(currentValue)
    valueLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    valueLabel.TextSize = 14
    valueLabel.Font = Enum.Font.Gotham
    valueLabel.TextXAlignment = Enum.TextXAlignment.Left
    valueLabel.Parent = dropdownFrame

    -- Arrow icon
    local arrowLabel = Instance.new("TextLabel")
    arrowLabel.Name = "Arrow"
    arrowLabel.Size = UDim2.new(0, 20, 1, 0)
    arrowLabel.Position = UDim2.new(1, -30, 0, 0)
    arrowLabel.BackgroundTransparency = 1
    arrowLabel.Text = "▼"
    arrowLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    arrowLabel.TextSize = 12
    arrowLabel.Font = Enum.Font.Gotham
    arrowLabel.TextXAlignment = Enum.TextXAlignment.Center
    arrowLabel.Parent = dropdownFrame

    -- Click to cycle through options
    local currentIndex = 1
    for i, option in ipairs(options) do
        if option.value == currentValue then
            currentIndex = i
            break
        end
    end
    if options[currentIndex] then
        valueLabel.Text = options[currentIndex].display
    end

    dropdownFrame.Activated:Connect(function()
        currentIndex = currentIndex + 1
        if currentIndex > #options then
            currentIndex = 1
        end

        local selectedOption = options[currentIndex]
        valueLabel.Text = selectedOption.display

        if callback then
            callback(selectedOption.value)
        end
    end)

    return container
end

function SettingsPanel:_createAudioSettings()
    self:_createSectionHeader("🔊 Audio Settings", 1)

    -- seed the sliders from the PERSISTED prefs (AudioPrefs loads + applies them at boot;
    -- without this the controls re-default to 1.0 every session)
    local saved = AudioPrefs.loaded()
    if type(saved) == "table" then
        for k, v in pairs(saved) do
            self.settings.audio[k] = v
        end
    end

    -- Each control updates its setting then re-applies all buses. (SoundService has NO
    -- MasterVolume property, so Master is folded into the per-bus volumes below.)
    self:_createSliderSetting(
        "Master Volume",
        self.settings.audio.masterVolume,
        0,
        1,
        2,
        function(value)
            self.settings.audio.masterVolume = value
            self:_applyAudioSettings()
        end
    )

    self:_createSliderSetting(
        "Effects Volume",
        self.settings.audio.effectsVolume,
        0,
        1,
        3,
        function(value)
            self.settings.audio.effectsVolume = value
            self:_applyAudioSettings()
        end
    )

    self:_createSliderSetting(
        "Music Volume",
        self.settings.audio.musicVolume,
        0,
        1,
        4,
        function(value)
            self.settings.audio.musicVolume = value
            self:_applyAudioSettings()
        end
    )

    self:_createToggleSetting("UI Sounds", self.settings.audio.uiSoundsEnabled, 5, function(value)
        self.settings.audio.uiSoundsEnabled = value
        self:_applyAudioSettings()
    end)

    -- Sync the live audio buses to the displayed values so the controls reflect reality
    -- the moment the panel opens (not just after the user drags something).
    self:_applyAudioSettings()
end

-- Push the current audio settings onto the live SoundGroup bus volumes. Master is a
-- multiplier across every bus (SoundService has no MasterVolume); all game sound routes
-- through these three buses, so master scales effects + music + UI together.
function SettingsPanel:_applyAudioSettings()
    local audio = self.settings.audio
    AudioPrefs.apply(audio)
    AudioPrefs.save(audio) -- debounced persist — sliders survive rejoin (Jason)
end

function SettingsPanel:_createGraphicsSettings()
    self:_createSectionHeader("🎨 Graphics Settings", 6)

    self:_createToggleSetting(
        "Performance Mode",
        self.settings.graphics.performanceMode,
        7,
        function(value)
            self.settings.graphics.performanceMode = value
            -- Apply performance optimizations
        end
    )

    self:_createToggleSetting(
        "Reduced Motion",
        self.settings.graphics.reducedMotion,
        8,
        function(value)
            self.settings.graphics.reducedMotion = value
            -- Disable/reduce animations
        end
    )

    -- Display Method Preferences (only show if user control is allowed)
    self:_createDisplayPreferences()
end

function SettingsPanel:_createDisplayPreferences()
    -- Use simplified DisplayPreferences utility
    local DisplayPreferences = require(script.Parent.Parent.Parent.Utils.DisplayPreferences)

    -- Get controllable contexts
    local controllableContexts = DisplayPreferences.GetControllableContexts()

    if #controllableContexts == 0 then
        self.logger:debug("No user-controllable display contexts available")
        return
    end

    -- Create dropdown options
    local displayOptions = {
        { value = "images", display = "📷 Images (Fast)" },
        { value = "viewports", display = "🎮 3D Models (High Quality)" },
    }

    -- Add dropdown for each controllable context
    local layoutOrder = 9
    for _, context in ipairs(controllableContexts) do
        -- Get current user preference
        local currentPref = DisplayPreferences.GetDisplayMethod(context)

        -- Create friendly context name
        local contextDisplayNames = {
            inventory = "Inventory Display",
            egg_preview = "Egg Preview Display",
            shop_display = "Shop Display",
        }

        local contextTitle = contextDisplayNames[context] or (context .. " Display")

        -- Create dropdown
        self:_createDropdownSetting(
            contextTitle,
            currentPref,
            displayOptions,
            layoutOrder,
            function(value)
                -- Set the preference via DisplayPreferences utility
                DisplayPreferences.SetDisplayMethod(context, value)

                self.logger:info("Display preference updated", {
                    context = context,
                    value = value,
                })

                -- Show performance warning if switching to viewports
                if value == "viewports" then
                    -- Simple performance warning
                    self:_showPerformanceWarning(
                        "Viewports may impact performance on older devices. Switch to Images if you experience frame drops."
                    )
                end

                -- Update local settings cache
                if context == "inventory" then
                    self.settings.graphics.inventoryDisplay = value
                elseif context == "egg_preview" then
                    self.settings.graphics.eggPreviewDisplay = value
                end

                self:_saveSettings()
            end
        )

        layoutOrder = layoutOrder + 1
    end
end

function SettingsPanel:_showPerformanceWarning(message)
    -- Create a temporary warning message
    self.logger:warn("Performance Warning: " .. message)

    -- TODO: Could add a proper warning UI here
    -- For now, just log the warning
end

function SettingsPanel:_createUISettings()
    self:_createSectionHeader("📱 UI Settings", 20)

    self:_createSliderSetting("UI Scale", self.settings.ui.scale, 0.8, 1.2, 21, function(value)
        self.settings.ui.scale = value
        -- Apply UI scaling
    end)

    self:_createToggleSetting("Show Tooltips", self.settings.ui.showTooltips, 22, function(value)
        self.settings.ui.showTooltips = value
    end)

    self:_createToggleSetting("Compact Mode", self.settings.ui.compactMode, 23, function(value)
        self.settings.ui.compactMode = value
    end)

    -- Target Highlight: outline the enemy/crystal the SELECTED pet is fighting (SquadHud reads the
    -- TargetHighlightOn attribute). On by default at startup; this just lets you turn it off.
    self:_createToggleSetting(
        "Target Highlight",
        Players.LocalPlayer:GetAttribute("TargetHighlightOn") ~= false,
        24,
        function(value)
            Players.LocalPlayer:SetAttribute("TargetHighlightOn", value)
        end
    )
end

function SettingsPanel:_getReplicatedHatchFolder()
    local settingsFolder = Players.LocalPlayer:FindFirstChild("Settings")
    local autoFolder = settingsFolder and settingsFolder:FindFirstChild("AutoSystems")
    return autoFolder and autoFolder:FindFirstChild("Hatch") or nil
end

function SettingsPanel:_getHatchActionMode()
    local hatchFolder = self:_getReplicatedHatchFolder()
    local value = hatchFolder and hatchFolder:FindFirstChild("ActionMode")
    if value and value:IsA("StringValue") then
        return value.Value
    end

    local ok, eggConfig = pcall(function()
        return Locations.getConfig("egg_system")
    end)
    if ok and eggConfig and eggConfig.ui and eggConfig.ui.hatch_panel then
        return eggConfig.ui.hatch_panel.default_action_mode or "single"
    end
    return "single"
end

function SettingsPanel:_getHatchModeValue(optionName, defaultValue)
    local hatchFolder = self:_getReplicatedHatchFolder()
    local modesFolder = hatchFolder and hatchFolder:FindFirstChild("Modes")
    local value = modesFolder and modesFolder:FindFirstChild(optionName)
    if value and value:IsA("BoolValue") then
        return value.Value == true
    end
    return defaultValue == true
end

function SettingsPanel:_setHatchModeValue(optionName, enabled)
    local currentModes = {}
    local hatchFolder = self:_getReplicatedHatchFolder()
    local modesFolder = hatchFolder and hatchFolder:FindFirstChild("Modes")
    if modesFolder then
        for _, child in ipairs(modesFolder:GetChildren()) do
            if child:IsA("BoolValue") then
                currentModes[child.Name] = child.Value == true
            end
        end
    end
    currentModes[optionName] = enabled == true
    Signals.HatchSettings_SetModes:FireServer({
        modes = currentModes,
    })
end

function SettingsPanel:_createHatchSettings()
    self:_createSectionHeader("🥚 Egg Settings", 25)

    -- (the E-Key Hatch Action dropdown moved OUT: hatch mode/count/auto now live as
    -- the inventory-header pills, which drive the same EggInteractionService state —
    -- Jason: "once it's working you can clear it out of settings". Animation/audio
    -- toggles stay: they're display preferences the pills don't cover.)

    self:_createToggleSetting(
        "Show Hatch Animation",
        self:_getHatchModeValue("showHatch", true),
        27,
        function(value)
            self:_setHatchModeValue("showHatch", value)
        end
    )

    self:_createToggleSetting(
        "Silent Hatch Audio",
        self:_getHatchModeValue("silentHatch", false),
        28,
        function(value)
            self:_setHatchModeValue("silentHatch", value)
        end
    )
end

-- Current equipped-pet formation, read from the replicated PetFormationMode attribute the
-- server sets from the saved setting.
function SettingsPanel:_getPetFormation()
    local mode = Players.LocalPlayer:GetAttribute("PetFormationMode")
    if type(mode) == "string" then
        return mode
    end
    return "risers"
end

function SettingsPanel:_getPetAttackStyle()
    local style = Players.LocalPlayer:GetAttribute("PetAttackStyle")
    if type(style) == "string" then
        return style
    end
    return "orbit"
end

function SettingsPanel:_createPetSettings()
    self:_createSectionHeader("🐾 Pet Settings", 22)

    self:_createDropdownSetting(
        "Pet Formation",
        self:_getPetFormation(),
        {
            { value = "risers", display = "Tiered Rows" },
            { value = "conga", display = "Conga Line" },
            { value = "arc", display = "Arc Cradle" },
        },
        23,
        function(value)
            Signals.Settings_SetPetFormation:FireServer({ mode = value })
        end
    )

    self:_createDropdownSetting(
        "Pet Attack Style",
        self:_getPetAttackStyle(),
        {
            { value = "orbit", display = "Orbit Ring" },
            { value = "static_ring", display = "Static Ring" },
            { value = "lunge", display = "Lunge" },
            { value = "spiral", display = "Spiral Vortex" },
            { value = "pincer", display = "Pincer" },
            { value = "firing_line", display = "Firing Line" },
            { value = "swarm", display = "Swarm" },
        },
        24,
        function(value)
            Signals.Settings_SetPetAttackStyle:FireServer({ style = value })
        end
    )
end

-- Current enemy spawn-level offset vs the player, read from the replicated
-- EnemyLevelOffset attribute the server sets from the saved setting. String value so
-- the dropdown can key on it ("-3".."3").
function SettingsPanel:_getEnemyLevelOffset()
    local offset = tonumber(Players.LocalPlayer:GetAttribute("EnemyLevelOffset")) or 0
    offset = math.clamp(math.floor(offset + 0.5), -3, 3)
    return tostring(offset)
end

function SettingsPanel:_createCombatSettings()
    self:_createSectionHeader("⚔️ Combat", 29)

    self:_createDropdownSetting(
        "Enemy Level",
        self:_getEnemyLevelOffset(),
        {
            { value = "-3", display = "3 Below You" },
            { value = "-2", display = "2 Below You" },
            { value = "-1", display = "1 Below You" },
            { value = "0", display = "Same As You" },
            { value = "1", display = "1 Above You" },
            { value = "2", display = "2 Above You" },
            { value = "3", display = "3 Above You" },
        },
        30,
        function(value)
            Signals.Settings_SetEnemyLevelOffset:FireServer({ offset = tonumber(value) or 0 })
        end
    )
end

function SettingsPanel:_openAdminPanel()
    self.logger:info("Opening admin panel")

    -- Create admin panel (this would open your test menu system)
    -- For now, we'll emit an event that MenuManager can listen to
    if self.onAdminPanelRequested then
        self.onAdminPanelRequested()
    end
end

function SettingsPanel:_loadSettings()
    -- Load settings from player data or local storage
    -- For now, using defaults
    self.logger:info("Settings loaded")
end

function SettingsPanel:_saveSettings()
    -- Save settings to player data or local storage
    self.logger:info("Settings saved")
end

-- Set callback for admin panel requests
function SettingsPanel:SetAdminPanelCallback(callback)
    self.onAdminPanelRequested = callback
end

-- Public interface methods
function SettingsPanel:IsVisible()
    return self.isVisible
end

function SettingsPanel:GetFrame()
    return self.frame
end

function SettingsPanel:IsAdmin()
    return self.isAdmin
end

function SettingsPanel:Destroy()
    self:_saveSettings()
    self:Hide()
    self.logger:info("Settings panel destroyed")
end

return SettingsPanel
