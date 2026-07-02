--[[
    TextInput Component - Advanced Text Input with Validation and Focus States
    
    Features:
    - Text input fields with validation
    - Placeholder text support
    - Focus, blur, and error states with animations
    - Different input types (text, number, password, email)
    - Character limits and validation rules
    - Mobile-optimized virtual keyboard support
    - Theme integration
    
    Usage:
    local TextInput = require(Locations.ClientUIComponents.TextInput)
    local input = TextInput.new({
        placeholder = "Enter your name...",
        size = UDim2.new(0, 250, 0, 40),
        inputType = "text",
        maxLength = 50,
        validation = function(text) return #text > 0 end
    })
    input:SetParent(container)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

-- Get shared modules
local Locations = require(ReplicatedStorage.Shared.Locations)
local uiConfig = Locations.getConfig("ui")

-- Safety check for UI config
if not uiConfig or not uiConfig.helpers then
    error("UI configuration not loaded properly. Check ConfigLoader setup.")
end

local TextInput = {}
TextInput.__index = TextInput

-- === VALIDATION PATTERNS ===
local ValidationPatterns = {
    email = "^[%w%._%+%-]+@[%w%._%+%-]+%.%w+$",
    number = "^%-?%d*%.?%d*$",
    integer = "^%-?%d*$",
    phone = "^%+?[%d%s%-%(%)]+$",
    alphanumeric = "^[%w%s]*$",
    letters_only = "^[%a%s]*$",
    no_spaces = "^%S*$",
}

-- === HELPER FUNCTIONS ===
local function getInputColor(variant, state, theme)
    if state == "error" then
        return theme.input.error
    elseif state == "focus" then
        return theme.input.focus
    else
        return theme.input.border
    end
end

local function validateInput(text, inputType, customValidator)
    if customValidator then
        return customValidator(text)
    end

    if inputType == "email" then
        return string.match(text, ValidationPatterns.email) ~= nil
    elseif inputType == "number" then
        return string.match(text, ValidationPatterns.number) ~= nil
    elseif inputType == "integer" then
        return string.match(text, ValidationPatterns.integer) ~= nil
    elseif inputType == "phone" then
        return string.match(text, ValidationPatterns.phone) ~= nil
    elseif inputType == "alphanumeric" then
        return string.match(text, ValidationPatterns.alphanumeric) ~= nil
    elseif inputType == "letters_only" then
        return string.match(text, ValidationPatterns.letters_only) ~= nil
    elseif inputType == "no_spaces" then
        return string.match(text, ValidationPatterns.no_spaces) ~= nil
    end

    return true -- Default to valid for "text" type
end

-- === TEXTINPUT CLASS ===
function TextInput.new(config)
    local self = setmetatable({}, TextInput)

    -- Configuration with defaults
    config = config or {}
    self.config = {
        text = config.text or "",
        placeholder = config.placeholder or "Enter text...",
        size = config.size or uiConfig.defaults.text_input.size,
        position = config.position or UDim2.new(0, 0, 0, 0),

        -- Input type and validation
        inputType = config.inputType or "text", -- text, number, integer, email, password, phone, alphanumeric, letters_only, no_spaces
        maxLength = config.maxLength,
        validation = config.validation, -- Custom validation function
        required = config.required or false,

        -- Visual styling
        cornerRadius = config.cornerRadius or uiConfig.defaults.text_input.corner_radius,
        font = config.font or uiConfig.defaults.text_input.font,
        fontSize = config.fontSize or uiConfig.defaults.text_input.font_size,
        padding = config.padding or uiConfig.defaults.text_input.padding,

        -- Behavior
        clearButtonVisible = config.clearButtonVisible ~= false, -- Default true
        selectAllOnFocus = config.selectAllOnFocus or false,
        multiline = config.multiline or false,

        -- Callbacks
        onChanged = config.onChanged,
        onFocus = config.onFocus,
        onBlur = config.onBlur,
        onEnter = config.onEnter,

        -- Responsive
        autoScale = config.autoScale ~= false, -- Default true
    }

    -- State
    self.state = {
        focused = false,
        valid = true,
        errorMessage = "",
        text = self.config.text,
    }

    self.theme = uiConfig.helpers.get_theme(uiConfig)

    -- Create UI
    self:_createUI()

    return self
end

function TextInput:_createUI()
    -- Main container frame
    self.frame = Instance.new("Frame")
    self.frame.Name = "TextInputContainer"
    self.frame.Size = self.config.size
    self.frame.Position = self.config.position
    self.frame.BackgroundTransparency = 1
    self.frame.BorderSizePixel = 0

    -- Input background frame
    self.inputFrame = Instance.new("Frame")
    self.inputFrame.Name = "InputFrame"
    self.inputFrame.Size = UDim2.new(1, 0, 1, 0)
    self.inputFrame.Position = UDim2.new(0, 0, 0, 0)
    self.inputFrame.BackgroundColor3 = self.theme.input.background
    self.inputFrame.BorderSizePixel = 1
    self.inputFrame.BorderColor3 = self.theme.input.border
    self.inputFrame.Parent = self.frame

    -- Corner radius
    if self.config.cornerRadius and self.config.cornerRadius ~= "none" then
        self.corner = Instance.new("UICorner")
        self.corner.CornerRadius = uiConfig.helpers.get_radius(uiConfig, self.config.cornerRadius)
        self.corner.Parent = self.inputFrame
    end

    -- Padding
    self.uiPadding = Instance.new("UIPadding")
    local paddingValue = uiConfig.helpers.get_spacing(uiConfig, self.config.padding)
    self.uiPadding.PaddingTop = paddingValue
    self.uiPadding.PaddingBottom = paddingValue
    self.uiPadding.PaddingLeft = paddingValue
    self.uiPadding.PaddingRight = paddingValue
    self.uiPadding.Parent = self.inputFrame

    -- Text input box
    if self.config.multiline then
        self.textBox = Instance.new("TextBox")
        self.textBox.MultiLine = true
        self.textBox.TextYAlignment = Enum.TextYAlignment.Top
    else
        self.textBox = Instance.new("TextBox")
        self.textBox.MultiLine = false
        self.textBox.TextYAlignment = Enum.TextYAlignment.Center
    end

    self.textBox.Name = "TextBox"
    self.textBox.Size = UDim2.new(1, self.config.clearButtonVisible and -30 or 0, 1, 0)
    self.textBox.Position = UDim2.new(0, 0, 0, 0)
    self.textBox.BackgroundTransparency = 1
    self.textBox.BorderSizePixel = 0
    self.textBox.Text = self.config.text
    self.textBox.PlaceholderText = self.config.placeholder
    self.textBox.PlaceholderColor3 = self.theme.text.muted
    self.textBox.TextColor3 = self.theme.text.primary
    self.textBox.Font = uiConfig.fonts[self.config.font] or uiConfig.fonts.primary
    self.textBox.TextScaled = false
    self.textBox.TextSize = uiConfig.fonts.sizes[self.config.fontSize] or uiConfig.fonts.sizes.md
    self.textBox.TextXAlignment = Enum.TextXAlignment.Left
    self.textBox.ClearTextOnFocus = false
    self.textBox.Parent = self.inputFrame

    -- Configure text input based on type
    self:_configureInputType()

    -- Clear button (if enabled)
    if self.config.clearButtonVisible then
        self:_createClearButton()
    end

    -- Error message label (hidden by default)
    self:_createErrorLabel()

    -- Setup interactions
    self:_setupInteractions()

    -- Auto-scaling for responsive design
    if self.config.autoScale then
        self:_setupAutoScaling()
    end
end

function TextInput:_configureInputType()
    if self.config.inputType == "password" then
        self.textBox.TextScaled = false
        -- Create a custom password masking system since Roblox doesn't have built-in password fields
        self.actualText = ""
        self.maskedText = ""
    elseif self.config.inputType == "number" or self.config.inputType == "integer" then
        -- Will be validated on input
    end
end

function TextInput:_createClearButton()
    self.clearButton = Instance.new("TextButton")
    self.clearButton.Name = "ClearButton"
    self.clearButton.Size = UDim2.new(0, 20, 0, 20)
    self.clearButton.Position = UDim2.new(1, -25, 0.5, -10)
    self.clearButton.BackgroundTransparency = 1
    self.clearButton.BorderSizePixel = 0
    self.clearButton.Text = "X" -- (was "✕"; the glyph tofu-boxes in Gotham)
    self.clearButton.TextColor3 = self.theme.text.muted
    self.clearButton.Font = Enum.Font.GothamBold
    self.clearButton.TextScaled = true
    self.clearButton.Visible = false -- Hidden when empty
    self.clearButton.Parent = self.inputFrame

    self.clearButton.Activated:Connect(function()
        self:SetText("")
        self:_updateClearButtonVisibility()
    end)

    -- Hover effects for clear button
    self.clearButton.MouseEnter:Connect(function()
        self.clearButton.TextColor3 = self.theme.primary.error
    end)

    self.clearButton.MouseLeave:Connect(function()
        self.clearButton.TextColor3 = self.theme.text.muted
    end)
end

function TextInput:_createErrorLabel()
    self.errorLabel = Instance.new("TextLabel")
    self.errorLabel.Name = "ErrorLabel"
    self.errorLabel.Size = UDim2.new(1, 0, 0, 20)
    self.errorLabel.Position = UDim2.new(0, 0, 1, 2)
    self.errorLabel.BackgroundTransparency = 1
    self.errorLabel.BorderSizePixel = 0
    self.errorLabel.Text = ""
    self.errorLabel.TextColor3 = self.theme.primary.error
    self.errorLabel.Font = uiConfig.fonts[self.config.font] or uiConfig.fonts.primary
    self.errorLabel.TextSize = (
        uiConfig.fonts.sizes[self.config.fontSize] or uiConfig.fonts.sizes.md
    ) - 2
    self.errorLabel.TextXAlignment = Enum.TextXAlignment.Left
    self.errorLabel.TextYAlignment = Enum.TextYAlignment.Top
    self.errorLabel.TextScaled = false
    self.errorLabel.Visible = false
    self.errorLabel.Parent = self.frame
end

function TextInput:_setupInteractions()
    -- Focus events
    self.textBox.Focused:Connect(function()
        self:_onFocus()
    end)

    self.textBox.FocusLost:Connect(function(enterPressed)
        self:_onBlur()
        if enterPressed and self.config.onEnter then
            self.config.onEnter(self.state.text)
        end
    end)

    -- Text change events
    self.textBox:GetPropertyChangedSignal("Text"):Connect(function()
        self:_onTextChanged()
    end)

    -- Mobile-specific optimizations
    if UserInputService.TouchEnabled then
        self:_setupMobileOptimizations()
    end
end

function TextInput:_setupMobileOptimizations()
    -- Configure virtual keyboard for different input types
    if self.config.inputType == "email" then
        self.textBox.TextInputType = Enum.TextInputType.Email
    elseif self.config.inputType == "number" or self.config.inputType == "integer" then
        self.textBox.TextInputType = Enum.TextInputType.Number
    elseif self.config.inputType == "phone" then
        self.textBox.TextInputType = Enum.TextInputType.Phone
    else
        self.textBox.TextInputType = Enum.TextInputType.Default
    end
end

function TextInput:_onFocus()
    self.state.focused = true
    self:_updateAppearance()

    if self.config.selectAllOnFocus and #self.textBox.Text > 0 then
        self.textBox:CaptureFocus()
        task.wait(0.1) -- Small delay to ensure focus is captured
        self.textBox.SelectionStart = 1
        self.textBox.CursorPosition = #self.textBox.Text + 1
    end

    if self.config.onFocus then
        self.config.onFocus()
    end
end

function TextInput:_onBlur()
    self.state.focused = false
    self:_validateCurrentText()
    self:_updateAppearance()

    if self.config.onBlur then
        self.config.onBlur(self.state.text)
    end
end

function TextInput:_onTextChanged()
    local newText = self.textBox.Text

    -- Handle password masking
    if self.config.inputType == "password" then
        self:_handlePasswordInput(newText)
        return
    end

    -- Apply character limit
    if self.config.maxLength and #newText > self.config.maxLength then
        newText = string.sub(newText, 1, self.config.maxLength)
        self.textBox.Text = newText
    end

    self.state.text = newText
    self:_updateClearButtonVisibility()

    if self.config.onChanged then
        self.config.onChanged(newText)
    end
end

function TextInput:_handlePasswordInput(newText)
    -- Simple password masking - replace characters with dots
    local actualLength = #self.actualText
    local newLength = #newText

    if newLength > actualLength then
        -- Characters added
        local addedChars = string.sub(newText, actualLength + 1)
        self.actualText = self.actualText .. addedChars
    elseif newLength < actualLength then
        -- Characters removed
        self.actualText = string.sub(self.actualText, 1, newLength)
    end

    -- Update display with masked characters
    self.maskedText = string.rep("•", #self.actualText)
    self.textBox.Text = self.maskedText
    self.state.text = self.actualText -- Store actual password

    self:_updateClearButtonVisibility()

    if self.config.onChanged then
        self.config.onChanged(self.actualText)
    end
end

function TextInput:_validateCurrentText()
    local text = self.state.text
    local isValid = true
    local errorMessage = ""

    -- Required field validation
    if self.config.required and #text == 0 then
        isValid = false
        errorMessage = "This field is required"
    elseif #text > 0 then
        -- Type-specific validation
        isValid = validateInput(text, self.config.inputType, self.config.validation)

        if not isValid then
            if self.config.inputType == "email" then
                errorMessage = "Please enter a valid email address"
            elseif self.config.inputType == "number" then
                errorMessage = "Please enter a valid number"
            elseif self.config.inputType == "integer" then
                errorMessage = "Please enter a whole number"
            elseif self.config.inputType == "phone" then
                errorMessage = "Please enter a valid phone number"
            else
                errorMessage = "Invalid input"
            end
        end
    end

    self.state.valid = isValid
    self.state.errorMessage = errorMessage
    self:_updateErrorDisplay()
end

function TextInput:_updateErrorDisplay()
    if self.state.valid then
        self.errorLabel.Visible = false
        self.errorLabel.Text = ""
    else
        self.errorLabel.Text = self.state.errorMessage
        self.errorLabel.Visible = true

        -- Animate error message
        self.errorLabel.TextTransparency = 1
        local fadeTween = TweenService:Create(
            self.errorLabel,
            TweenInfo.new(
                uiConfig.animations.duration.fast,
                uiConfig.animations.easing.ease_out,
                uiConfig.animations.direction.out_dir
            ),
            { TextTransparency = 0 }
        )
        fadeTween:Play()
    end
end

function TextInput:_updateAppearance()
    local borderColor
    local backgroundColor = self.theme.input.background

    if not self.state.valid then
        borderColor = getInputColor("", "error", self.theme)
    elseif self.state.focused then
        borderColor = getInputColor("", "focus", self.theme)
        backgroundColor = self.theme.input.background
    else
        borderColor = self.theme.input.border
    end

    -- Animate border color change
    local borderTween = TweenService:Create(
        self.inputFrame,
        TweenInfo.new(
            uiConfig.animations.duration.fast,
            uiConfig.animations.easing.ease_out,
            uiConfig.animations.direction.out_dir
        ),
        { BorderColor3 = borderColor, BackgroundColor3 = backgroundColor }
    )
    borderTween:Play()
end

function TextInput:_updateClearButtonVisibility()
    if self.clearButton then
        local shouldShow = #self.state.text > 0 and self.state.focused
        self.clearButton.Visible = shouldShow
    end
end

function TextInput:_setupAutoScaling()
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

function TextInput:_updateScale()
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

-- === PUBLIC METHODS ===
function TextInput:SetText(text)
    self.state.text = text

    if self.config.inputType == "password" then
        self.actualText = text
        self.maskedText = string.rep("•", #text)
        self.textBox.Text = self.maskedText
    else
        self.textBox.Text = text
    end

    self:_updateClearButtonVisibility()
    self:_validateCurrentText()
end

function TextInput:GetText()
    return self.state.text
end

function TextInput:SetPlaceholder(placeholder)
    self.config.placeholder = placeholder
    self.textBox.PlaceholderText = placeholder
end

function TextInput:SetMaxLength(maxLength)
    self.config.maxLength = maxLength
end

function TextInput:SetRequired(required)
    self.config.required = required
    self:_validateCurrentText()
end

function TextInput:Focus()
    self.textBox:CaptureFocus()
end

function TextInput:Blur()
    self.textBox:ReleaseFocus()
end

function TextInput:IsValid()
    return self.state.valid
end

function TextInput:GetErrorMessage()
    return self.state.errorMessage
end

function TextInput:SetEnabled(enabled)
    self.textBox.Editable = enabled
    self.inputFrame.BackgroundTransparency = enabled and 0 or 0.5

    if self.clearButton then
        self.clearButton.Visible = enabled and self.clearButton.Visible
    end
end

function TextInput:SetParent(parent)
    self.frame.Parent = parent

    -- Setup auto-scaling if needed
    if self.config.autoScale then
        self:_setupAutoScaling()
    end
end

function TextInput:SetVisible(visible)
    self.frame.Visible = visible
end

function TextInput:SetSize(size)
    self.config.size = size
    self.frame.Size = size
end

function TextInput:SetPosition(position)
    self.config.position = position
    self.frame.Position = position
end

function TextInput:GetFrame()
    return self.frame
end

function TextInput:Destroy()
    self.frame:Destroy()
end

return TextInput
