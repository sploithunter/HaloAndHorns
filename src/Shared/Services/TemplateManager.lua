--[[
    TemplateManager - Template-based UI creation service
    
    This service manages UI template cloning and configuration following
    the configuration-as-code pattern. Templates are stored as actual
    Roblox instances in ReplicatedStorage and cloned when needed.
    
    Features:
    - Clone templates from ReplicatedStorage.UI_Templates
    - Configure templates with asset IDs, colors, and properties
    - Apply theme and responsive settings
    - Handle template validation and fallbacks
    - Cache templates for performance
    
    Usage:
    local templateManager = TemplateManager.new()
    local currencyLabel = templateManager:CreateFromTemplate("currency_display", {
        currency_type = "gems",
        amount = 1500,
        parent = screenGui
    })
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

-- Get shared modules
local Locations = require(ReplicatedStorage.Shared.Locations)

-- Load Logger with wrapper for instance-like behavior
local LoggerWrapper
local loggerSuccess, loggerResult = pcall(function()
    return require(Locations.Logger)
end)

if loggerSuccess and loggerResult then
    print("[TemplateManager] Logger loaded successfully")
    -- The real Logger is a singleton, create wrapper for instance-like behavior
    LoggerWrapper = {
        new = function(name)
            return {
                info = function(self, ...)
                    loggerResult:Info("[" .. name .. "] " .. tostring((...)), { context = name })
                end,
                warn = function(self, ...)
                    loggerResult:Warn("[" .. name .. "] " .. tostring((...)), { context = name })
                end,
                error = function(self, ...)
                    loggerResult:Error("[" .. name .. "] " .. tostring((...)), { context = name })
                end,
                debug = function(self, ...)
                    loggerResult:Debug("[" .. name .. "] " .. tostring((...)), { context = name })
                end,
            }
        end,
    }
else
    print("[TemplateManager] Logger failed to load, using fallback. Error:", loggerResult)
    LoggerWrapper = {
        new = function(name)
            return {
                info = function(self, ...)
                    print("[" .. name .. "] INFO:", ...)
                end,
                warn = function(self, ...)
                    warn("[" .. name .. "] WARN:", ...)
                end,
                error = function(self, ...)
                    warn("[" .. name .. "] ERROR:", ...)
                end,
                debug = function(self, ...)
                    print("[" .. name .. "] DEBUG:", ...)
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
    warn("[TemplateManager] Failed to load UI config, using fallback")
    uiConfig = {
        templates = {
            storage_path = "ReplicatedStorage.UI_Templates",
            assets = { currency_icons = {}, ui_icons = {}, backgrounds = {} },
            types = {},
            defaults = {},
        },
        themes = { dark = { primary = { background = Color3.fromRGB(30, 30, 35) } } },
        active_theme = "dark",
        helpers = {
            get_theme = function(config)
                return config.themes.dark
            end,
            get_asset_id = function(config, category, key)
                return "rbxassetid://0"
            end,
            get_template_config = function(config, template_type)
                return {}
            end,
            format_currency = function(config, amount)
                return tostring(amount)
            end,
        },
    }
end

local TemplateManager = {}
TemplateManager.__index = TemplateManager

-- Template cache for performance
local templateCache = {}
local templateStorage = nil

function TemplateManager.new()
    local self = setmetatable({}, TemplateManager)

    self.logger = LoggerWrapper.new("TemplateManager")
    self.isInitialized = false

    -- Initialize template storage reference
    self:_initializeStorage()

    return self
end

function TemplateManager:_initializeStorage()
    -- Try to find UI_Templates in ReplicatedStorage
    local storage = ReplicatedStorage:FindFirstChild("UI_Templates")

    if not storage then
        self.logger:warn(
            "UI_Templates folder not found in ReplicatedStorage. Creating placeholder."
        )
        -- Create a basic structure if missing
        storage = Instance.new("Folder")
        storage.Name = "UI_Templates"
        storage.Parent = ReplicatedStorage

        -- Create basic subfolders
        local templates = Instance.new("Folder")
        templates.Name = "Templates"
        templates.Parent = storage

        local icons = Instance.new("Folder")
        icons.Name = "Icons"
        icons.Parent = storage
    end

    templateStorage = storage
    self.isInitialized = true
    self.logger:info("Template storage initialized")
end

-- Main template creation function
function TemplateManager:CreateFromTemplate(templateType, config)
    if not self.isInitialized then
        self:_initializeStorage()
    end

    config = config or {}

    -- Get template name from type mapping
    local templateName = uiConfig.templates.types[templateType]
    if not templateName then
        self.logger:error("Unknown template type: " .. tostring(templateType))
        return nil
    end

    -- Get or create template
    local template = self:_getTemplate(templateName)
    if not template then
        self.logger:error("Failed to get template: " .. templateName)
        return nil
    end

    -- Clone and configure
    local instance = template:Clone()
    self:_configureTemplate(instance, templateType, config)

    self.logger:debug("Created template instance:", templateType, "as", templateName)
    return instance
end

-- Get template from cache or storage
function TemplateManager:_getTemplate(templateName)
    -- Check cache first
    if templateCache[templateName] then
        return templateCache[templateName]
    end

    -- Try to find in ReplicatedStorage
    local template = self:_findTemplateInStorage(templateName)

    if template then
        templateCache[templateName] = template
        return template
    end

    -- Create fallback template
    template = self:_createFallbackTemplate(templateName)
    if template then
        templateCache[templateName] = template
    end

    return template
end

-- Find template in various storage locations
function TemplateManager:_findTemplateInStorage(templateName)
    if not templateStorage then
        return nil
    end

    -- Check direct child
    local template = templateStorage:FindFirstChild(templateName)
    if template then
        return template
    end

    -- Check Templates subfolder
    local templatesFolder = templateStorage:FindFirstChild("Templates")
    if templatesFolder then
        template = templatesFolder:FindFirstChild(templateName)
        if template then
            return template
        end
    end

    -- Check Frames subfolder (from MCP pattern)
    local framesFolder = templateStorage:FindFirstChild("Frames")
    if framesFolder then
        template = framesFolder:FindFirstChild(templateName)
        if template then
            return template
        end
    end

    return nil
end

-- Create basic fallback templates
function TemplateManager:_createFallbackTemplate(templateName)
    self.logger:warn("Creating fallback template for:", templateName)

    if templateName == "CurrencyLabel" then
        return self:_createCurrencyLabelTemplate()
    elseif templateName == "MenuButton" then
        return self:_createMenuButtonTemplate()
    elseif templateName == "GenericEntryTemplate" then
        return self:_createGenericEntryTemplate()
    elseif templateName == "LargeUIBlank" then
        return self:_createLargePanelTemplate()
    elseif templateName == "TextLabelStyle" then
        return self:_createTextLabelTemplate()
    end

    -- Generic frame fallback
    local frame = Instance.new("Frame")
    frame.Name = templateName
    frame.Size = UDim2.new(0, 100, 0, 100)
    frame.BackgroundColor3 = Color3.fromRGB(50, 50, 55)

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = frame

    return frame
end

-- Configure template with provided settings
function TemplateManager:_configureTemplate(instance, templateType, config)
    -- Get template defaults
    local defaults = uiConfig.helpers.get_template_config(uiConfig, templateType)
    local theme = uiConfig.helpers.get_theme(uiConfig)

    -- Merge config with defaults
    local finalConfig = {}
    for key, value in pairs(defaults) do
        finalConfig[key] = value
    end
    for key, value in pairs(config) do
        finalConfig[key] = value
    end

    -- Apply configuration based on template type
    if templateType == "currency_display" then
        self:_configureCurrencyDisplay(instance, finalConfig, theme)
    elseif templateType == "menu_button" then
        self:_configureMenuButton(instance, finalConfig, theme)
    elseif templateType == "shop_item" or templateType == "inventory_item" then
        self:_configureGenericEntry(instance, finalConfig, theme)
    elseif templateType == "panel_large" or templateType == "panel_scroll" then
        self:_configureLargePanel(instance, finalConfig, theme)
    end

    -- Apply common properties
    if finalConfig.size then
        instance.Size = finalConfig.size
    end
    if finalConfig.position then
        instance.Position = finalConfig.position
    end
    if finalConfig.anchor_point then
        instance.AnchorPoint = finalConfig.anchor_point
    end
    if finalConfig.parent then
        instance.Parent = finalConfig.parent
    end
end

-- Template-specific configuration functions
function TemplateManager:_configureCurrencyDisplay(instance, config, theme)
    -- Find currency type value
    local currencyTypeValue = instance:FindFirstChild("CurrencyType")
    if currencyTypeValue and currencyTypeValue:IsA("StringValue") then
        currencyTypeValue.Value = config.currency_type or "coins"
    end

    -- Configure icon
    local imageLabel = instance:FindFirstChildOfClass("ImageLabel")
    if imageLabel then
        local assetId = uiConfig.helpers.get_asset_id(
            uiConfig,
            "currency_icons",
            config.currency_type or "coins"
        )
        imageLabel.Image = assetId
        imageLabel.ImageColor3 = theme.text.primary
    end

    -- Configure text
    local textLabel = instance:FindFirstChildOfClass("TextLabel")
    if textLabel then
        if config.amount then
            textLabel.Text = uiConfig.helpers.format_currency(uiConfig, config.amount)
        end
        textLabel.TextColor3 = theme.text.primary
        textLabel.Font = uiConfig.fonts.primary
        textLabel.TextSize = uiConfig.fonts.sizes.md
    end

    -- Apply theme colors
    if instance.ClassName == "ImageLabel" then
        instance.ImageColor3 = theme.primary.accent
    end
end

function TemplateManager:_configureMenuButton(instance, config, theme)
    -- Configure background
    instance.BackgroundColor3 = theme.button.primary

    -- Find and configure icon
    local iconLabel = instance:FindFirstChild("IconLabel")
    if iconLabel and iconLabel:IsA("ImageLabel") then
        local assetId =
            uiConfig.helpers.get_asset_id(uiConfig, "ui_icons", config.icon_type or "shop")
        iconLabel.Image = assetId
        iconLabel.ImageColor3 = theme.text.primary
        if config.icon_size then
            iconLabel.Size = config.icon_size
        end
    end

    -- Find and configure text
    local textLabel = instance:FindFirstChildOfClass("TextLabel")
    if textLabel then
        textLabel.Text = config.text or "Button"
        textLabel.TextColor3 = theme.text.primary
        textLabel.Font = uiConfig.fonts.primary
        textLabel.TextSize = config.text_size or uiConfig.fonts.sizes.sm
    end

    -- Add corner radius
    local corner = instance:FindFirstChildOfClass("UICorner")
    if corner then
        corner.CornerRadius = UDim.new(0, config.corner_radius or 12)
    end
end

function TemplateManager:_configureGenericEntry(instance, config, theme)
    -- Apply theme to frame
    instance.BackgroundColor3 = theme.primary.card

    -- Configure stroke
    local stroke = instance:FindFirstChildOfClass("UIStroke")
    if stroke then
        stroke.Color = theme.border.primary
        stroke.Thickness = config.stroke_thickness or 1
    end

    -- Configure gradient
    local gradient = instance:FindFirstChildOfClass("UIGradient")
    if gradient and config.gradient_enabled then
        gradient.Color = ColorSequence.new(theme.gradient.primary)
    end

    -- Configure corner
    local corner = instance:FindFirstChildOfClass("UICorner")
    if corner then
        corner.CornerRadius = UDim.new(0, config.corner_radius or 8)
    end
end

function TemplateManager:_configureLargePanel(instance, config, theme)
    instance.BackgroundColor3 = theme.primary.surface

    local corner = instance:FindFirstChildOfClass("UICorner")
    if corner then
        corner.CornerRadius = UDim.new(0, config.corner_radius or 16)
    end
end

-- Fallback template creators
function TemplateManager:_createCurrencyLabelTemplate()
    local frame = Instance.new("ImageLabel")
    frame.Name = "CurrencyLabel"
    frame.Size = UDim2.new(0, 120, 0, 40)
    frame.BackgroundTransparency = 1
    frame.Image = "rbxassetid://12155643116"

    -- Icon
    local icon = Instance.new("ImageLabel")
    icon.Name = "ImageLabel"
    icon.Size = UDim2.new(0, 24, 0, 24)
    icon.Position = UDim2.new(0, 8, 0.5, -12)
    icon.BackgroundTransparency = 1
    icon.Parent = frame

    -- Text
    local text = Instance.new("TextLabel")
    text.Name = "TextLabel"
    text.Size = UDim2.new(1, -40, 1, 0)
    text.Position = UDim2.new(0, 36, 0, 0)
    text.BackgroundTransparency = 1
    text.Text = "0"
    text.TextXAlignment = Enum.TextXAlignment.Left
    text.Parent = frame

    -- Currency type metadata
    local currencyType = Instance.new("StringValue")
    currencyType.Name = "CurrencyType"
    currencyType.Value = "coins"
    currencyType.Parent = frame

    return frame
end

function TemplateManager:_createMenuButtonTemplate()
    local button = Instance.new("TextButton")
    button.Name = "MenuButton"
    button.Size = UDim2.new(0, 80, 0, 80)
    button.BackgroundColor3 = Color3.fromRGB(60, 60, 65)
    button.BorderSizePixel = 0
    button.Text = ""

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = button

    -- Icon
    local icon = Instance.new("ImageLabel")
    icon.Name = "IconLabel"
    icon.Size = UDim2.new(0, 40, 0, 40)
    icon.Position = UDim2.new(0.5, -20, 0.5, -20)
    icon.BackgroundTransparency = 1
    icon.Parent = button

    -- Text
    local text = Instance.new("TextLabel")
    text.Name = "TextLabel"
    text.Size = UDim2.new(1, 0, 0, 16)
    text.Position = UDim2.new(0, 0, 1, -18)
    text.BackgroundTransparency = 1
    text.Text = "Menu"
    text.TextSize = 12
    text.Parent = button

    return button
end

function TemplateManager:_createGenericEntryTemplate()
    local frame = Instance.new("Frame")
    frame.Name = "GenericEntryTemplate"
    frame.Size = UDim2.new(0, 100, 0, 100)
    frame.BackgroundColor3 = Color3.fromRGB(45, 45, 50)

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = frame

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(80, 80, 85)
    stroke.Thickness = 1
    stroke.Parent = frame

    -- Invisible button for interactions
    local button = Instance.new("TextButton")
    button.Name = "InvisibleButton"
    button.Size = UDim2.new(1, 0, 1, 0)
    button.BackgroundTransparency = 1
    button.Text = ""
    button.Parent = frame

    return frame
end

function TemplateManager:_createLargePanelTemplate()
    local frame = Instance.new("Frame")
    frame.Name = "LargeUIBlank"
    frame.Size = UDim2.new(0.8, 0, 0.8, 0)
    frame.Position = UDim2.new(0.5, 0, 0.5, 0)
    frame.AnchorPoint = Vector2.new(0.5, 0.5)
    frame.BackgroundColor3 = Color3.fromRGB(40, 40, 45)

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 16)
    corner.Parent = frame

    return frame
end

function TemplateManager:_createTextLabelTemplate()
    local label = Instance.new("TextLabel")
    label.Name = "TextLabelStyle"
    label.Size = UDim2.new(0, 200, 0, 50)
    label.BackgroundTransparency = 1
    label.Text = "Sample Text"
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.Font = Enum.Font.Gotham
    label.TextSize = 14

    return label
end

-- Utility functions
function TemplateManager:ClearCache()
    templateCache = {}
    self.logger:info("Template cache cleared")
end

function TemplateManager:GetCachedTemplates()
    local count = 0
    for _ in pairs(templateCache) do
        count = count + 1
    end
    return templateCache, count
end

function TemplateManager:CreateCurrencyDisplay(currencyType, amount, parent)
    return self:CreateFromTemplate("currency_display", {
        currency_type = currencyType,
        amount = amount,
        parent = parent,
    })
end

function TemplateManager:CreateMenuButton(iconType, text, parent, onClick)
    local button = self:CreateFromTemplate("menu_button", {
        icon_type = iconType,
        text = text,
        parent = parent,
    })

    if onClick and button then
        local clickButton = button:FindFirstChild("InvisibleButton") or button
        if clickButton:IsA("GuiButton") then
            clickButton.Activated:Connect(onClick)
        end
    end

    return button
end

function TemplateManager:CreatePanel(panelType, config)
    panelType = panelType or "panel_large"
    return self:CreateFromTemplate(panelType, config)
end

return TemplateManager
