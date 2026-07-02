--[[
    Panel Component - Flexible Container with Layout and Styling
    
    Features:
    - Responsive layouts (auto, grid, list, flex-like)
    - Border and shadow options
    - Background blur effects  
    - Nested container support
    - Auto-scaling and mobile optimization
    - Theme integration
    
    Usage:
    local Panel = require(Locations.ClientUIComponents.Panel)
    local container = Panel.new({
        size = UDim2.new(0, 400, 0, 300),
        layout = "list", -- auto, list, grid, none
        backgroundBlur = true,
        shadow = true
    })
    container:SetParent(screenGui)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

-- Get shared modules
local Locations = require(ReplicatedStorage.Shared.Locations)

-- Load UI config with fallback
local uiConfig
local configSuccess, configResult = pcall(function()
    return Locations.getConfig("ui")
end)

if configSuccess and configResult and configResult.helpers then
    uiConfig = configResult
else
    -- Fallback UI config for testing
    warn("Using fallback UI config - check configs/ui.lua loading")
    uiConfig = {
        themes = {
            dark = {
                primary = {
                    background = Color3.fromRGB(30, 30, 35),
                    surface = Color3.fromRGB(40, 40, 45),
                    accent = Color3.fromRGB(0, 120, 180),
                },
                text = {
                    primary = Color3.fromRGB(255, 255, 255),
                    secondary = Color3.fromRGB(200, 200, 200),
                },
                shadow = Color3.fromRGB(0, 0, 0),
                overlay = Color3.fromRGB(0, 0, 0),
            },
        },
        active_theme = "dark",
        spacing = { xs = 4, sm = 8, md = 16, lg = 24, xl = 32 },
        radius = { none = 0, sm = 4, md = 8, lg = 12, xl = 16 },
        animations = {
            duration = { fast = 0.15, normal = 0.25 },
            easing = { ease_out = Enum.EasingStyle.Quad },
            direction = { out_dir = Enum.EasingDirection.Out },
        },
        defaults = {
            panel = {
                corner_radius = "md",
                background_transparency = 0,
                border_size = 0,
                shadow_enabled = true,
                shadow_transparency = 0.3,
            },
        },
        helpers = {
            get_theme = function(config)
                return config.themes[config.active_theme] or config.themes.dark
            end,
            get_spacing = function(config, key)
                local value = config.spacing[key] or config.spacing.md
                return UDim.new(0, value)
            end,
            get_radius = function(config, key)
                local value = config.radius[key] or config.radius.md
                return UDim.new(0, value)
            end,
        },
    }
end

local Panel = {}
Panel.__index = Panel

-- === HELPER FUNCTIONS ===
local function destroyChild(child)
    if typeof(child) == "Instance" or (typeof(child) == "table" and child.Destroy) then
        child:Destroy()
    end
end

local function applyTheme(frame, variant, theme)
    variant = variant or "surface"

    local colors = {
        background = theme.primary.background,
        surface = theme.primary.surface,
        accent = theme.primary.accent,
    }
    frame.BackgroundColor3 = colors[variant] or colors.surface
end

-- === PANEL CLASS ===
function Panel.new(config)
    local self = setmetatable({}, Panel)

    -- Configuration with defaults
    config = config or {}
    self.config = {
        size = config.size or UDim2.new(0, 200, 0, 150),
        position = config.position or UDim2.new(0, 0, 0, 0),
        variant = config.variant or "surface", -- background, surface, accent

        -- Layout options
        layout = config.layout or "none", -- none, list, grid, auto
        layoutDirection = config.layoutDirection or "vertical", -- vertical, horizontal
        padding = config.padding or "md",
        spacing = config.spacing or "sm",

        -- Visual styling
        cornerRadius = config.cornerRadius or uiConfig.defaults.panel.corner_radius,
        backgroundTransparency = config.backgroundTransparency
            or uiConfig.defaults.panel.background_transparency,
        borderSize = config.borderSize or uiConfig.defaults.panel.border_size,
        borderColor = config.borderColor,

        -- Effects
        shadow = config.shadow ~= false, -- Default true
        backgroundBlur = config.backgroundBlur or false,

        -- Responsive
        autoScale = config.autoScale ~= false, -- Default true

        -- Grid specific (if layout = "grid")
        columns = config.columns or 2,
        rows = config.rows,

        -- Animation
        animateEntrance = config.animateEntrance or false,
    }

    -- State
    self.children = {}
    self.theme = uiConfig.helpers.get_theme(uiConfig)

    -- Create UI
    self:_createUI()

    if self.config.animateEntrance then
        self:_animateEntrance()
    end

    return self
end

function Panel:_createUI()
    -- Main panel frame
    self.frame = Instance.new("Frame")
    self.frame.Name = "Panel"
    self.frame.Size = self.config.size
    self.frame.Position = self.config.position
    self.frame.BackgroundTransparency = self.config.backgroundTransparency
    self.frame.BorderSizePixel = self.config.borderSize

    -- Apply theme
    applyTheme(self.frame, self.config.variant, self.theme)

    if self.config.borderColor then
        self.frame.BorderColor3 = self.config.borderColor
    end

    -- Corner radius
    if self.config.cornerRadius and self.config.cornerRadius ~= "none" then
        self.corner = Instance.new("UICorner")
        self.corner.CornerRadius = uiConfig.helpers.get_radius(uiConfig, self.config.cornerRadius)
        self.corner.Parent = self.frame
    end

    -- Padding
    self.uiPadding = Instance.new("UIPadding")
    local paddingValue = uiConfig.helpers.get_spacing(uiConfig, self.config.padding)
    self.uiPadding.PaddingTop = paddingValue
    self.uiPadding.PaddingBottom = paddingValue
    self.uiPadding.PaddingLeft = paddingValue
    self.uiPadding.PaddingRight = paddingValue
    self.uiPadding.Parent = self.frame

    -- Background blur effect
    if self.config.backgroundBlur then
        self:_createBlurEffect()
    end

    -- Drop shadow
    if self.config.shadow then
        self:_createShadow()
    end

    -- Layout management
    if self.config.layout ~= "none" then
        self:_setupLayout()
    end

    -- Auto-scaling for responsive design
    if self.config.autoScale then
        self:_setupAutoScaling()
    end
end

function Panel:_createBlurEffect()
    -- Create a blur effect behind the panel
    self.blurFrame = Instance.new("Frame")
    self.blurFrame.Name = "BlurBackground"
    self.blurFrame.Size = UDim2.new(1, 6, 1, 6) -- Slightly larger for blur effect
    self.blurFrame.Position = UDim2.new(0, -3, 0, -3)
    self.blurFrame.BackgroundColor3 = self.theme.overlay
    self.blurFrame.BackgroundTransparency = 0.8
    self.blurFrame.BorderSizePixel = 0
    self.blurFrame.ZIndex = self.frame.ZIndex - 1

    -- Add corner radius to blur
    if self.corner then
        local blurCorner = Instance.new("UICorner")
        blurCorner.CornerRadius = self.corner.CornerRadius
        blurCorner.Parent = self.blurFrame
    end

    -- Add subtle blur effect using gradient
    local gradient = Instance.new("UIGradient")
    gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
        ColorSequenceKeypoint.new(0.5, Color3.new(0.9, 0.9, 0.9)),
        ColorSequenceKeypoint.new(1, Color3.new(1, 1, 1)),
    })
    gradient.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.9),
        NumberSequenceKeypoint.new(0.5, 0.7),
        NumberSequenceKeypoint.new(1, 0.9),
    })
    gradient.Parent = self.blurFrame
end

function Panel:_createShadow()
    self.shadow = Instance.new("Frame")
    self.shadow.Name = "Shadow"
    self.shadow.Size = UDim2.new(1, 8, 1, 8)
    self.shadow.Position = UDim2.new(0, 4, 0, 4)
    self.shadow.BackgroundColor3 = self.theme.shadow
    self.shadow.BackgroundTransparency = uiConfig.defaults.panel.shadow_transparency
    self.shadow.BorderSizePixel = 0
    self.shadow.ZIndex = self.frame.ZIndex - 2

    -- Add corner radius to shadow
    if self.corner then
        local shadowCorner = Instance.new("UICorner")
        shadowCorner.CornerRadius = self.corner.CornerRadius
        shadowCorner.Parent = self.shadow
    end
end

function Panel:_setupLayout()
    if self.config.layout == "list" then
        self.layoutObject = Instance.new("UIListLayout")
        self.layoutObject.Padding = uiConfig.helpers.get_spacing(uiConfig, self.config.spacing)
        self.layoutObject.SortOrder = Enum.SortOrder.LayoutOrder

        if self.config.layoutDirection == "horizontal" then
            self.layoutObject.FillDirection = Enum.FillDirection.Horizontal
        else
            self.layoutObject.FillDirection = Enum.FillDirection.Vertical
        end

        self.layoutObject.Parent = self.frame
    elseif self.config.layout == "grid" then
        self.layoutObject = Instance.new("UIGridLayout")
        self.layoutObject.CellPadding = UDim2.new(
            uiConfig.helpers.get_spacing(uiConfig, self.config.spacing),
            uiConfig.helpers.get_spacing(uiConfig, self.config.spacing)
        )
        self.layoutObject.SortOrder = Enum.SortOrder.LayoutOrder

        -- Calculate cell size based on columns
        local availableWidth = 1 / self.config.columns
        self.layoutObject.CellSize = UDim2.new(availableWidth, -8, 0, 50) -- Default height

        self.layoutObject.Parent = self.frame
    elseif self.config.layout == "auto" then
        -- Auto layout tries to fit content efficiently
        self.layoutObject = Instance.new("UIListLayout")
        self.layoutObject.Padding = uiConfig.helpers.get_spacing(uiConfig, self.config.spacing)
        self.layoutObject.SortOrder = Enum.SortOrder.LayoutOrder
        self.layoutObject.Wraps = true -- Allow wrapping if supported
        self.layoutObject.Parent = self.frame

        -- Add auto-sizing constraint
        self.sizeConstraint = Instance.new("UISizeConstraint")
        self.sizeConstraint.MinSize = Vector2.new(100, 50)
        self.sizeConstraint.Parent = self.frame
    end

    -- Setup auto-resizing if layout is enabled
    if self.layoutObject and self.layoutObject:IsA("UIListLayout") then
        self:_setupAutoResize()
    end
end

function Panel:_setupAutoResize()
    if not self.layoutObject then
        return
    end

    -- Auto-resize based on content
    local function updateSize()
        if self.config.layout == "auto" then
            local contentSize = self.layoutObject.AbsoluteContentSize
            local padding = self.uiPadding.PaddingTop.Offset + self.uiPadding.PaddingBottom.Offset

            self.frame.Size = UDim2.new(
                self.config.size.X.Scale,
                self.config.size.X.Offset,
                0,
                contentSize.Y + padding
            )
        end
    end

    self.layoutObject:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateSize)
    updateSize() -- Initial sizing
end

function Panel:_setupAutoScaling()
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

function Panel:_updateScale()
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

function Panel:_animateEntrance()
    -- Animate panel entrance with scale and fade
    local originalSize = self.frame.Size
    local originalTransparency = self.frame.BackgroundTransparency

    -- Start hidden and small
    self.frame.Size = UDim2.new(0, 0, 0, 0)
    self.frame.BackgroundTransparency = 1

    -- Animate to full size and visibility
    local sizeTween = TweenService:Create(
        self.frame,
        TweenInfo.new(
            uiConfig.animations.duration.normal,
            uiConfig.animations.easing.bounce,
            uiConfig.animations.direction.out_dir
        ),
        { Size = originalSize }
    )

    local fadeTween = TweenService:Create(
        self.frame,
        TweenInfo.new(
            uiConfig.animations.duration.normal,
            uiConfig.animations.easing.ease_out,
            uiConfig.animations.direction.out_dir
        ),
        { BackgroundTransparency = originalTransparency }
    )

    sizeTween:Play()
    fadeTween:Play()
end

-- === PUBLIC METHODS ===
function Panel:AddChild(child, layoutOrder)
    if typeof(child) == "table" and child.frame then
        -- Child is a UI component
        child:SetParent(self.frame)
        child.frame.LayoutOrder = layoutOrder or #self.children + 1
        table.insert(self.children, child)
    elseif typeof(child) == "Instance" then
        -- Child is a Roblox instance
        child.Parent = self.frame
        child.LayoutOrder = layoutOrder or #self.children + 1
        table.insert(self.children, child)
    end
end

function Panel:RemoveChild(child)
    for i, existingChild in ipairs(self.children) do
        if existingChild == child then
            destroyChild(child)
            table.remove(self.children, i)
            break
        end
    end
end

function Panel:ClearChildren()
    for _, child in ipairs(self.children) do
        destroyChild(child)
    end
    self.children = {}
end

function Panel:SetTheme(themeName)
    local newTheme = uiConfig.themes[themeName]
    if newTheme then
        self.theme = newTheme
        applyTheme(self.frame, self.config.variant, self.theme)

        -- Update shadow color
        if self.shadow then
            self.shadow.BackgroundColor3 = self.theme.shadow
        end

        -- Update blur overlay
        if self.blurFrame then
            self.blurFrame.BackgroundColor3 = self.theme.overlay
        end
    end
end

function Panel:SetVariant(variant)
    self.config.variant = variant
    applyTheme(self.frame, variant, self.theme)
end

function Panel:SetSize(size)
    self.config.size = size
    self.frame.Size = size

    -- Update shadow size
    if self.shadow then
        self.shadow.Size = UDim2.new(1, 8, 1, 8)
    end

    -- Update blur size
    if self.blurFrame then
        self.blurFrame.Size = UDim2.new(1, 6, 1, 6)
    end
end

function Panel:SetPosition(position)
    self.config.position = position
    self.frame.Position = position

    -- Update shadow position
    if self.shadow then
        self.shadow.Position = position + UDim2.new(0, 4, 0, 4)
    end

    -- Update blur position
    if self.blurFrame then
        self.blurFrame.Position = position + UDim2.new(0, -3, 0, -3)
    end
end

function Panel:SetVisible(visible)
    self.frame.Visible = visible

    if self.shadow then
        self.shadow.Visible = visible
    end

    if self.blurFrame then
        self.blurFrame.Visible = visible
    end
end

function Panel:SetParent(parent)
    -- Set effects parents first
    if self.shadow then
        self.shadow.Parent = parent
    end

    if self.blurFrame then
        self.blurFrame.Parent = parent
    end

    self.frame.Parent = parent

    -- Setup auto-scaling if needed
    if self.config.autoScale then
        self:_setupAutoScaling()
    end
end

function Panel:GetFrame()
    return self.frame
end

function Panel:GetChildren()
    return self.children
end

function Panel:SetLayoutSpacing(spacing)
    self.config.spacing = spacing
    if self.layoutObject and self.layoutObject.Padding then
        self.layoutObject.Padding = uiConfig.helpers.get_spacing(uiConfig, spacing)
    end
end

function Panel:SetGridColumns(columns)
    if self.config.layout == "grid" and self.layoutObject then
        self.config.columns = columns
        local availableWidth = 1 / columns
        self.layoutObject.CellSize = UDim2.new(
            availableWidth,
            -8,
            self.layoutObject.CellSize.Y.Scale,
            self.layoutObject.CellSize.Y.Offset
        )
    end
end

function Panel:Destroy()
    self:ClearChildren()

    if self.shadow then
        self.shadow:Destroy()
    end

    if self.blurFrame then
        self.blurFrame:Destroy()
    end

    self.frame:Destroy()
end

return Panel
