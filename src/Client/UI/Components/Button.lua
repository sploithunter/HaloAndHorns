--[[
    Button Component - Comprehensive UI Button with States and Animation
    
    Features:
    - Hover, clicked, disabled, and loading states
    - Configurable colors, sizes, fonts from UI config
    - Sound effects integration
    - Responsive design and mobile-first approach
    - Accessibility support
    
    Usage:
    local Button = require(Locations.ClientUIComponents.Button)
    local myButton = Button.new({
        text = "Click Me",
        size = UDim2.new(0, 200, 0, 50),
        variant = "primary",
        onClick = function() print("Clicked!") end
    })
    myButton:SetParent(screenGui)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

-- Get shared modules
local Locations = require(ReplicatedStorage.Shared.Locations)
local uiConfig = Locations.getConfig("ui")
local SoundGroups = require(ReplicatedStorage.Shared.Effects.SoundGroups)

-- Safety check for UI config
if not uiConfig or not uiConfig.helpers then
    error("UI configuration not loaded properly. Check ConfigLoader setup.")
end

local Button = {}
Button.__index = Button

-- === STATIC CONFIGURATION ===
local HOVER_SCALE = 1.05
local PRESS_SCALE = 0.95
local LOADING_ROTATION_SPEED = 2 -- rotations per second

-- Sound effects cache
local soundCache = {}

-- === HELPER FUNCTIONS ===
local function createSound(soundId, volume)
    if soundCache[soundId] then
        return soundCache[soundId]:Clone()
    end

    local sound = Instance.new("Sound")
    sound.SoundId = soundId
    sound.Volume = volume or 0.5
    SoundGroups.assign(sound, "ui") -- clones inherit the SoundGroup
    sound.Parent = SoundService
    soundCache[soundId] = sound

    return sound:Clone()
end

local function getThemeColor(variant, state)
    local theme = uiConfig.helpers.get_theme(uiConfig)
    state = state or "normal"

    if variant == "primary" then
        return theme.button.primary
    elseif variant == "secondary" then
        return theme.button.secondary
    elseif variant == "success" then
        return theme.button.success
    elseif variant == "danger" then
        return theme.button.danger
    elseif variant == "disabled" then
        return theme.button.disabled
    else
        return theme.button.primary
    end
end

local function getTextColor(variant, theme)
    if variant == "secondary" then
        return theme.text.primary
    else
        return theme.text.inverse
    end
end

-- === BUTTON CLASS ===
function Button.new(config)
    local self = setmetatable({}, Button)

    -- Configuration with defaults
    config = config or {}
    self.config = {
        text = config.text or "Button",
        size = config.size or uiConfig.defaults.button.size,
        position = config.position or UDim2.new(0, 0, 0, 0),
        variant = config.variant or "primary", -- primary, secondary, success, danger
        disabled = config.disabled or false,
        loading = config.loading or false,
        soundEnabled = config.soundEnabled ~= false, -- Default true
        onClick = config.onClick,
        onHover = config.onHover,
        onUnhover = config.onUnhover,

        -- Styling overrides
        cornerRadius = config.cornerRadius or uiConfig.defaults.button.corner_radius,
        font = config.font or uiConfig.fonts.primary,
        fontSize = config.fontSize or uiConfig.fonts.sizes.md,

        -- Responsive
        autoScale = config.autoScale ~= false, -- Default true
    }

    -- State management
    self.state = {
        hover = false,
        pressed = false,
        disabled = self.config.disabled,
        loading = self.config.loading,
    }

    -- Create UI elements
    self:_createUI()
    self:_setupInteractions()
    self:_updateAppearance()

    return self
end

function Button:_createUI()
    local theme = uiConfig.helpers.get_theme(uiConfig)

    -- Main button frame
    self.frame = Instance.new("TextButton")
    self.frame.Name = "Button"
    self.frame.Size = self.config.size
    self.frame.Position = self.config.position
    self.frame.BackgroundColor3 = getThemeColor(self.config.variant)
    self.frame.BorderSizePixel = 0
    self.frame.Text = ""
    self.frame.ClipsDescendants = true
    self.frame.AutoButtonColor = false -- We handle our own color changes

    -- Corner radius
    self.corner = Instance.new("UICorner")
    self.corner.CornerRadius = uiConfig.helpers.get_radius(uiConfig, self.config.cornerRadius)
    self.corner.Parent = self.frame

    -- Scale object for animations
    self.uiScale = Instance.new("UIScale")
    self.uiScale.Scale = 1
    self.uiScale.Parent = self.frame

    -- Text label
    self.textLabel = Instance.new("TextLabel")
    self.textLabel.Name = "TextLabel"
    self.textLabel.Size = UDim2.new(1, -16, 1, 0) -- Padding
    self.textLabel.Position = UDim2.new(0, 8, 0, 0)
    self.textLabel.BackgroundTransparency = 1
    self.textLabel.Text = self.config.text
    self.textLabel.TextColor3 = getTextColor(self.config.variant, theme)
    self.textLabel.Font = uiConfig.fonts[self.config.font] or uiConfig.fonts.primary
    self.textLabel.TextScaled = true
    self.textLabel.TextWrapped = true
    self.textLabel.Parent = self.frame

    -- Loading spinner (hidden by default)
    self.loadingFrame = Instance.new("Frame")
    self.loadingFrame.Name = "LoadingFrame"
    self.loadingFrame.Size = UDim2.new(1, 0, 1, 0)
    self.loadingFrame.Position = UDim2.new(0, 0, 0, 0)
    self.loadingFrame.BackgroundTransparency = 1
    self.loadingFrame.Visible = false
    self.loadingFrame.Parent = self.frame

    -- Loading spinner icon
    self.loadingSpinner = Instance.new("TextLabel")
    self.loadingSpinner.Name = "LoadingSpinner"
    self.loadingSpinner.Size = UDim2.new(0, 20, 0, 20)
    self.loadingSpinner.Position = UDim2.new(0.5, -10, 0.5, -10)
    self.loadingSpinner.BackgroundTransparency = 1
    self.loadingSpinner.Text = "⟳"
    self.loadingSpinner.TextColor3 = getTextColor(self.config.variant, theme)
    self.loadingSpinner.Font = Enum.Font.GothamBold
    self.loadingSpinner.TextScaled = true
    self.loadingSpinner.Parent = self.loadingFrame

    -- Drop shadow (if enabled)
    if uiConfig.defaults.panel.shadow_enabled then
        self.shadow = Instance.new("Frame")
        self.shadow.Name = "Shadow"
        self.shadow.Size = UDim2.new(1, 4, 1, 4)
        self.shadow.Position = UDim2.new(0, 2, 0, 2)
        self.shadow.BackgroundColor3 = theme.shadow
        self.shadow.BackgroundTransparency = uiConfig.defaults.panel.shadow_transparency
        self.shadow.BorderSizePixel = 0
        self.shadow.ZIndex = self.frame.ZIndex - 1

        local shadowCorner = Instance.new("UICorner")
        shadowCorner.CornerRadius = self.corner.CornerRadius
        shadowCorner.Parent = self.shadow

        -- Parent shadow to the same parent as the button when set
    end

    -- Auto-scaling for responsive design
    if self.config.autoScale then
        self:_setupAutoScaling()
    end
end

function Button:_setupAutoScaling()
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

function Button:_updateScale()
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

function Button:_setupInteractions()
    -- Mouse/touch interactions
    self.frame.MouseEnter:Connect(function()
        if not self.state.disabled and not self.state.loading then
            self:_onHoverStart()
        end
    end)

    self.frame.MouseLeave:Connect(function()
        if not self.state.disabled and not self.state.loading then
            self:_onHoverEnd()
        end
    end)

    self.frame.MouseButton1Down:Connect(function()
        if not self.state.disabled and not self.state.loading then
            self:_onPressStart()
        end
    end)

    self.frame.MouseButton1Up:Connect(function()
        if not self.state.disabled and not self.state.loading then
            self:_onPressEnd()
        end
    end)

    self.frame.Activated:Connect(function()
        if not self.state.disabled and not self.state.loading then
            self:_onClick()
        end
    end)

    -- Touch-specific handling for mobile
    if UserInputService.TouchEnabled then
        self:_setupTouchHandling()
    end
end

function Button:_setupTouchHandling()
    -- Enhanced touch handling for mobile devices
    local touchConnection

    self.frame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            if not self.state.disabled and not self.state.loading then
                self:_onHoverStart()
                self:_onPressStart()
            end
        end
    end)

    self.frame.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            if not self.state.disabled and not self.state.loading then
                self:_onHoverEnd()
                self:_onPressEnd()
            end
        end
    end)
end

-- === EVENT HANDLERS ===
function Button:_onHoverStart()
    self.state.hover = true
    self:_updateAppearance()
    self:_playSound("hover")

    if self.config.onHover then
        self.config.onHover()
    end
end

function Button:_onHoverEnd()
    self.state.hover = false
    self:_updateAppearance()

    if self.config.onUnhover then
        self.config.onUnhover()
    end
end

function Button:_onPressStart()
    self.state.pressed = true
    self:_updateAppearance()
end

function Button:_onPressEnd()
    self.state.pressed = false
    self:_updateAppearance()
end

function Button:_onClick()
    self:_playSound("click")

    if self.config.onClick then
        self.config.onClick()
    end
end

function Button:_updateAppearance()
    local theme = uiConfig.helpers.get_theme(uiConfig)
    local targetColor = getThemeColor(self.config.variant)
    local targetScale = 1

    -- Determine color and scale based on state
    if self.state.disabled then
        targetColor = theme.button.disabled
    elseif self.state.pressed then
        targetColor = targetColor:lerp(Color3.new(0, 0, 0), 0.2) -- Darken
        targetScale = PRESS_SCALE
    elseif self.state.hover then
        targetColor = targetColor:lerp(Color3.new(1, 1, 1), 0.1) -- Lighten
        targetScale = HOVER_SCALE
    end

    -- Animate color change
    local colorTween = TweenService:Create(
        self.frame,
        TweenInfo.new(
            uiConfig.animations.duration.fast,
            uiConfig.animations.easing.ease_out,
            uiConfig.animations.direction.out_dir
        ),
        { BackgroundColor3 = targetColor }
    )
    colorTween:Play()

    -- Animate scale change
    local scaleTween = TweenService:Create(
        self.uiScale,
        TweenInfo.new(
            uiConfig.animations.duration.fast,
            uiConfig.animations.easing.ease_out,
            uiConfig.animations.direction.out_dir
        ),
        { Scale = targetScale }
    )
    scaleTween:Play()

    -- Update text color for disabled state
    local textColor = self.state.disabled and theme.text.disabled
        or getTextColor(self.config.variant, theme)
    self.textLabel.TextColor3 = textColor
    if self.loadingSpinner then
        self.loadingSpinner.TextColor3 = textColor
    end
end

function Button:_playSound(soundType)
    if not self.config.soundEnabled or not uiConfig.sounds.enabled then
        return
    end

    local soundId
    if soundType == "hover" then
        soundId = uiConfig.sounds.button_hover
    elseif soundType == "click" then
        soundId = uiConfig.sounds.button_click
    else
        return
    end

    local sound = createSound(soundId, uiConfig.sounds.volume)
    sound:Play()

    -- Clean up sound after playing
    sound.Ended:Connect(function()
        sound:Destroy()
    end)
end

function Button:_startLoadingAnimation()
    if not self.loadingSpinner then
        return
    end

    -- Create infinite rotation tween
    local rotationTween = TweenService:Create(
        self.loadingSpinner,
        TweenInfo.new(
            1 / LOADING_ROTATION_SPEED,
            Enum.EasingStyle.Linear,
            Enum.EasingDirection.InOut,
            -1 -- Infinite repeats
        ),
        { Rotation = 360 }
    )

    self.loadingTween = rotationTween
    rotationTween:Play()
end

function Button:_stopLoadingAnimation()
    if self.loadingTween then
        self.loadingTween:Cancel()
        self.loadingTween = nil
    end

    if self.loadingSpinner then
        self.loadingSpinner.Rotation = 0
    end
end

-- === PUBLIC METHODS ===
function Button:SetText(text)
    self.config.text = text
    self.textLabel.Text = text
end

function Button:SetEnabled(enabled)
    self.state.disabled = not enabled
    self.frame.Active = enabled
    self:_updateAppearance()
end

function Button:SetLoading(loading)
    self.state.loading = loading

    if loading then
        self.textLabel.Visible = false
        self.loadingFrame.Visible = true
        self:_startLoadingAnimation()
    else
        self.textLabel.Visible = true
        self.loadingFrame.Visible = false
        self:_stopLoadingAnimation()
    end

    self:_updateAppearance()
end

function Button:SetVariant(variant)
    self.config.variant = variant
    self:_updateAppearance()
end

function Button:SetParent(parent)
    -- Set shadow parent first if it exists
    if self.shadow then
        self.shadow.Parent = parent
    end

    self.frame.Parent = parent

    -- Setup auto-scaling if needed
    if self.config.autoScale then
        self:_setupAutoScaling()
    end
end

function Button:SetVisible(visible)
    self.frame.Visible = visible
    if self.shadow then
        self.shadow.Visible = visible
    end
end

function Button:SetSize(size)
    self.config.size = size
    self.frame.Size = size
end

function Button:SetPosition(position)
    self.config.position = position
    self.frame.Position = position

    if self.shadow then
        self.shadow.Position = position + UDim2.new(0, 2, 0, 2)
    end
end

function Button:GetFrame()
    return self.frame
end

function Button:Destroy()
    self:_stopLoadingAnimation()

    if self.shadow then
        self.shadow:Destroy()
    end

    self.frame:Destroy()
end

return Button
