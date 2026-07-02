--[[
    TextLabel Component - Advanced Text Display with Auto-scaling and Rich Text
    
    Features:
    - Auto-scaling text that adapts to container size
    - Rich text support with color, bold, italic formatting
    - Theme integration with multiple color variants
    - Responsive design and mobile optimization
    - Icon + text combinations
    - Text animation effects
    
    Usage:
    local TextLabel = require(Locations.ClientUIComponents.TextLabel)
    local label = TextLabel.new({
        text = "Hello World!",
        size = UDim2.new(0, 200, 0, 50),
        variant = "primary",
        richText = true
    })
    label:SetParent(container)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local TextService = game:GetService("TextService")

-- Get shared modules
local Locations = require(ReplicatedStorage.Shared.Locations)
local uiConfig = Locations.getConfig("ui")

-- Safety check for UI config
if not uiConfig or not uiConfig.helpers then
    error("UI configuration not loaded properly. Check ConfigLoader setup.")
end

local TextLabel = {}
TextLabel.__index = TextLabel

-- === HELPER FUNCTIONS ===
local function getTextColor(variant, theme)
    if variant == "primary" then
        return theme.text.primary
    elseif variant == "secondary" then
        return theme.text.secondary
    elseif variant == "muted" then
        return theme.text.muted
    elseif variant == "disabled" then
        return theme.text.disabled
    elseif variant == "inverse" then
        return theme.text.inverse
    elseif variant == "success" then
        return theme.primary.success
    elseif variant == "warning" then
        return theme.primary.warning
    elseif variant == "error" then
        return theme.primary.error
    elseif variant == "info" then
        return theme.primary.info
    else
        return theme.text.primary
    end
end

local function calculateOptimalTextSize(text, font, maxSize, container)
    -- Calculate the optimal text size for the given container
    local testFrame = Instance.new("TextLabel")
    testFrame.Font = font
    testFrame.Text = text
    testFrame.Size = maxSize
    testFrame.TextScaled = false
    testFrame.Parent = container

    local textBounds = TextService:GetTextSize(text, 14, font, maxSize)
    testFrame:Destroy()

    -- Calculate scale factor to fit
    local scaleX = maxSize.X.Offset / textBounds.X
    local scaleY = maxSize.Y.Offset / textBounds.Y
    local scale = math.min(scaleX, scaleY, 1) -- Don't scale up

    return math.max(8, 14 * scale) -- Minimum 8pt font
end

-- === TEXTLABEL CLASS ===
function TextLabel.new(config)
    local self = setmetatable({}, TextLabel)

    -- Configuration with defaults
    config = config or {}
    self.config = {
        text = config.text or "Text",
        size = config.size or UDim2.new(0, 100, 0, 30),
        position = config.position or UDim2.new(0, 0, 0, 0),
        variant = config.variant or "primary", -- primary, secondary, muted, disabled, inverse, success, warning, error, info

        -- Typography
        font = config.font or uiConfig.fonts.primary,
        fontSize = config.fontSize or uiConfig.fonts.sizes.md,
        fontWeight = config.fontWeight or "normal", -- normal, bold

        -- Text formatting
        richText = config.richText or false,
        textWrapped = config.textWrapped ~= false, -- Default true
        textScaled = config.textScaled ~= false, -- Default true
        textAlign = config.textAlign or "center", -- left, center, right
        textVAlign = config.textVAlign or "center", -- top, center, bottom

        -- Visual styling
        backgroundTransparency = config.backgroundTransparency or 1,
        backgroundColor = config.backgroundColor,

        -- Icon support
        icon = config.icon,
        iconSize = config.iconSize or UDim2.new(0, 16, 0, 16),
        iconPosition = config.iconPosition or "left", -- left, right, top, bottom

        -- Animation
        animateText = config.animateText or false,
        typewriterSpeed = config.typewriterSpeed or 0.05,

        -- Responsive
        autoScale = config.autoScale ~= false, -- Default true
        autoFontSize = config.autoFontSize or false,
    }

    -- State
    self.theme = uiConfig.helpers.get_theme(uiConfig)
    self.originalText = self.config.text
    self.animationConnection = nil

    -- Create UI
    self:_createUI()

    if self.config.animateText then
        self:_startTypewriterAnimation()
    end

    return self
end

function TextLabel:_createUI()
    -- Main container frame
    self.frame = Instance.new("Frame")
    self.frame.Name = "TextLabelContainer"
    self.frame.Size = self.config.size
    self.frame.Position = self.config.position
    self.frame.BackgroundTransparency = self.config.backgroundTransparency
    self.frame.BorderSizePixel = 0

    if self.config.backgroundColor then
        self.frame.BackgroundColor3 = self.config.backgroundColor
    end

    -- Create layout based on icon position
    if self.config.icon then
        self:_createIconTextLayout()
    else
        self:_createTextOnly()
    end

    -- Auto-scaling for responsive design
    if self.config.autoScale then
        self:_setupAutoScaling()
    end

    -- Auto font sizing
    if self.config.autoFontSize then
        self:_setupAutoFontSizing()
    end
end

function TextLabel:_createTextOnly()
    -- Single text label
    self.textLabel = Instance.new("TextLabel")
    self.textLabel.Name = "TextLabel"
    self.textLabel.Size = UDim2.new(1, 0, 1, 0)
    self.textLabel.Position = UDim2.new(0, 0, 0, 0)
    self.textLabel.BackgroundTransparency = 1
    self.textLabel.BorderSizePixel = 0

    self:_configureTextLabel(self.textLabel)
    self.textLabel.Parent = self.frame
end

function TextLabel:_createIconTextLayout()
    local iconSize = self.config.iconSize
    local spacing = 4 -- pixels between icon and text

    -- Icon label
    self.iconLabel = Instance.new("TextLabel")
    self.iconLabel.Name = "IconLabel"
    self.iconLabel.Size = iconSize
    self.iconLabel.BackgroundTransparency = 1
    self.iconLabel.BorderSizePixel = 0
    self.iconLabel.Text = self.config.icon
    self.iconLabel.TextColor3 = getTextColor(self.config.variant, self.theme)
    self.iconLabel.Font = Enum.Font.GothamBold
    self.iconLabel.TextScaled = true
    self.iconLabel.Parent = self.frame

    -- Text label
    self.textLabel = Instance.new("TextLabel")
    self.textLabel.Name = "TextLabel"
    self.textLabel.BackgroundTransparency = 1
    self.textLabel.BorderSizePixel = 0
    self:_configureTextLabel(self.textLabel)
    self.textLabel.Parent = self.frame

    -- Position based on icon layout
    if self.config.iconPosition == "left" then
        self.iconLabel.Position = UDim2.new(0, 0, 0.5, -iconSize.Y.Offset / 2)
        self.textLabel.Position = UDim2.new(0, iconSize.X.Offset + spacing, 0, 0)
        self.textLabel.Size = UDim2.new(1, -(iconSize.X.Offset + spacing), 1, 0)
    elseif self.config.iconPosition == "right" then
        self.iconLabel.Position = UDim2.new(1, -iconSize.X.Offset, 0.5, -iconSize.Y.Offset / 2)
        self.textLabel.Position = UDim2.new(0, 0, 0, 0)
        self.textLabel.Size = UDim2.new(1, -(iconSize.X.Offset + spacing), 1, 0)
    elseif self.config.iconPosition == "top" then
        self.iconLabel.Position = UDim2.new(0.5, -iconSize.X.Offset / 2, 0, 0)
        self.textLabel.Position = UDim2.new(0, 0, 0, iconSize.Y.Offset + spacing)
        self.textLabel.Size = UDim2.new(1, 0, 1, -(iconSize.Y.Offset + spacing))
    elseif self.config.iconPosition == "bottom" then
        self.iconLabel.Position = UDim2.new(0.5, -iconSize.X.Offset / 2, 1, -iconSize.Y.Offset)
        self.textLabel.Position = UDim2.new(0, 0, 0, 0)
        self.textLabel.Size = UDim2.new(1, 0, 1, -(iconSize.Y.Offset + spacing))
    end
end

function TextLabel:_configureTextLabel(textLabel)
    textLabel.Text = self.config.text
    textLabel.TextColor3 = getTextColor(self.config.variant, self.theme)

    -- Font configuration
    if self.config.fontWeight == "bold" then
        textLabel.Font = uiConfig.fonts.bold
    else
        textLabel.Font = uiConfig.fonts[self.config.font] or uiConfig.fonts.primary
    end

    -- Text properties
    textLabel.RichText = self.config.richText
    textLabel.TextWrapped = self.config.textWrapped
    textLabel.TextScaled = self.config.textScaled

    -- Alignment
    if self.config.textAlign == "left" then
        textLabel.TextXAlignment = Enum.TextXAlignment.Left
    elseif self.config.textAlign == "right" then
        textLabel.TextXAlignment = Enum.TextXAlignment.Right
    else
        textLabel.TextXAlignment = Enum.TextXAlignment.Center
    end

    if self.config.textVAlign == "top" then
        textLabel.TextYAlignment = Enum.TextYAlignment.Top
    elseif self.config.textVAlign == "bottom" then
        textLabel.TextYAlignment = Enum.TextYAlignment.Bottom
    else
        textLabel.TextYAlignment = Enum.TextYAlignment.Center
    end

    -- Font size (if not using TextScaled)
    if not self.config.textScaled then
        textLabel.TextSize = uiConfig.fonts.sizes[self.config.fontSize] or uiConfig.fonts.sizes.md
    end
end

function TextLabel:_setupAutoScaling()
    local screenGui = self.frame:FindFirstAncestorOfClass("ScreenGui")
    if not screenGui then
        -- Defer until parented
        local connection
        connection = self.frame.AncestryChanged:Connect(function()
            screenGui = self.frame:FindFirstAncestorOfClass("ScreenGui")
            if screenGui then
                connection:Disconnect()
                self:_updateScale()

                -- Listen for viewport changes
                screenGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
                    self:_updateScale()
                end)
            end
        end)
    else
        self:_updateScale()

        -- Listen for viewport changes
        screenGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
            self:_updateScale()
        end)
    end
end

function TextLabel:_updateScale()
    local screenGui = self.frame:FindFirstAncestorOfClass("ScreenGui")
    if not screenGui then
        return
    end

    local screenSize = screenGui.AbsoluteSize
    local scaleFactor = uiConfig.helpers.get_scale_factor(uiConfig, screenSize)

    -- Create or update UIScale
    local uiScale = self.frame:FindFirstChild("UIScale") or Instance.new("UIScale")
    uiScale.Scale = scaleFactor
    uiScale.Parent = self.frame
end

function TextLabel:_setupAutoFontSizing()
    if not self.textLabel then
        return
    end

    local function updateFontSize()
        if self.config.textScaled then
            return
        end -- Don't interfere with TextScaled

        local containerSize =
            Vector2.new(self.textLabel.AbsoluteSize.X, self.textLabel.AbsoluteSize.Y)

        local optimalSize = calculateOptimalTextSize(
            self.originalText,
            self.textLabel.Font,
            containerSize,
            self.textLabel.Parent
        )

        self.textLabel.TextSize = optimalSize
    end

    -- Update when size changes
    self.textLabel:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateFontSize)
    updateFontSize() -- Initial sizing
end

function TextLabel:_startTypewriterAnimation()
    if not self.textLabel then
        return
    end

    local fullText = self.originalText
    local currentLength = 0

    -- Start with empty text
    self.textLabel.Text = ""

    -- Animate character by character
    self.animationConnection = task.spawn(function()
        while currentLength < #fullText do
            currentLength = currentLength + 1
            self.textLabel.Text = string.sub(fullText, 1, currentLength)
            task.wait(self.config.typewriterSpeed)
        end
    end)
end

function TextLabel:_stopTypewriterAnimation()
    if self.animationConnection then
        task.cancel(self.animationConnection)
        self.animationConnection = nil
    end

    if self.textLabel then
        self.textLabel.Text = self.originalText
    end
end

-- === PUBLIC METHODS ===
function TextLabel:SetText(text)
    self.originalText = text
    self.config.text = text

    if self.config.animateText then
        self:_stopTypewriterAnimation()
        self:_startTypewriterAnimation()
    else
        if self.textLabel then
            self.textLabel.Text = text
        end
    end
end

function TextLabel:SetVariant(variant)
    self.config.variant = variant
    local newColor = getTextColor(variant, self.theme)

    if self.textLabel then
        self.textLabel.TextColor3 = newColor
    end

    if self.iconLabel then
        self.iconLabel.TextColor3 = newColor
    end
end

function TextLabel:SetFont(font, weight)
    self.config.font = font or self.config.font
    self.config.fontWeight = weight or self.config.fontWeight

    if self.textLabel then
        if self.config.fontWeight == "bold" then
            self.textLabel.Font = uiConfig.fonts.bold
        else
            self.textLabel.Font = uiConfig.fonts[self.config.font] or uiConfig.fonts.primary
        end
    end
end

function TextLabel:SetIcon(icon)
    self.config.icon = icon

    if self.iconLabel then
        self.iconLabel.Text = icon
    elseif icon then
        -- Need to recreate with icon
        self:_destroyUI()
        self:_createUI()
    end
end

function TextLabel:SetRichText(enabled)
    self.config.richText = enabled

    if self.textLabel then
        self.textLabel.RichText = enabled
    end
end

function TextLabel:AnimateIn()
    if not self.textLabel then
        return
    end

    -- Fade in animation
    local originalTransparency = self.textLabel.TextTransparency
    self.textLabel.TextTransparency = 1

    local fadeTween = TweenService:Create(
        self.textLabel,
        TweenInfo.new(
            uiConfig.animations.duration.normal,
            uiConfig.animations.easing.ease_out,
            uiConfig.animations.direction.out_dir
        ),
        { TextTransparency = originalTransparency }
    )

    fadeTween:Play()

    -- Also animate icon if present
    if self.iconLabel then
        self.iconLabel.TextTransparency = 1
        local iconTween = TweenService:Create(
            self.iconLabel,
            TweenInfo.new(
                uiConfig.animations.duration.normal,
                uiConfig.animations.easing.ease_out,
                uiConfig.animations.direction.out_dir
            ),
            { TextTransparency = 0 }
        )
        iconTween:Play()
    end
end

function TextLabel:AnimateOut(callback)
    if not self.textLabel then
        if callback then
            callback()
        end
        return
    end

    -- Fade out animation
    local fadeTween = TweenService:Create(
        self.textLabel,
        TweenInfo.new(
            uiConfig.animations.duration.fast,
            uiConfig.animations.easing.ease_in,
            uiConfig.animations.direction.in_dir
        ),
        { TextTransparency = 1 }
    )

    if callback then
        fadeTween.Completed:Connect(callback)
    end

    fadeTween:Play()

    -- Also animate icon if present
    if self.iconLabel then
        local iconTween = TweenService:Create(
            self.iconLabel,
            TweenInfo.new(
                uiConfig.animations.duration.fast,
                uiConfig.animations.easing.ease_in,
                uiConfig.animations.direction.in_dir
            ),
            { TextTransparency = 1 }
        )
        iconTween:Play()
    end
end

function TextLabel:SetTheme(themeName)
    local newTheme = uiConfig.themes[themeName]
    if newTheme then
        self.theme = newTheme
        self:SetVariant(self.config.variant) -- Refresh colors
    end
end

function TextLabel:SetParent(parent)
    self.frame.Parent = parent

    -- Setup auto-scaling if needed
    if self.config.autoScale then
        self:_setupAutoScaling()
    end

    -- Setup auto font sizing if needed
    if self.config.autoFontSize then
        self:_setupAutoFontSizing()
    end
end

function TextLabel:SetVisible(visible)
    self.frame.Visible = visible
end

function TextLabel:SetSize(size)
    self.config.size = size
    self.frame.Size = size
end

function TextLabel:SetPosition(position)
    self.config.position = position
    self.frame.Position = position
end

function TextLabel:GetFrame()
    return self.frame
end

function TextLabel:GetText()
    return self.originalText
end

function TextLabel:_destroyUI()
    self:_stopTypewriterAnimation()

    if self.textLabel then
        self.textLabel:Destroy()
        self.textLabel = nil
    end

    if self.iconLabel then
        self.iconLabel:Destroy()
        self.iconLabel = nil
    end
end

function TextLabel:Destroy()
    self:_destroyUI()
    self.frame:Destroy()
end

return TextLabel
