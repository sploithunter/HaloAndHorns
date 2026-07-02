--[[
    Component Showcase - Demonstration of All UI Components
    
    This screen demonstrates all available UI components with various configurations,
    serving as both a testing ground and documentation for the UI system.
    
    Components demonstrated:
    - Button (all variants, states, loading)
    - Panel (layouts, shadows, blur effects)
    - TextLabel (variants, icons, animations)
    - TextInput (validation, input types, focus states)
    
    Usage:
    local ComponentShowcase = require(game.StarterPlayer.StarterPlayerScripts.Client.UI.ComponentShowcase)
    ComponentShowcase:Show()
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Get shared modules
local Locations = require(ReplicatedStorage.Shared.Locations)
local uiConfig = Locations.getConfig("ui")

-- Safety check for UI config
if not uiConfig or not uiConfig.helpers then
    error("UI configuration not loaded properly. Check ConfigLoader setup.")
end

-- Get UI components
local Button = require(script.Parent.Components.Button)
local Panel = require(script.Parent.Components.Panel)
local TextLabel = require(script.Parent.Components.TextLabel)
local TextInput = require(script.Parent.Components.TextInput)

local ComponentShowcase = {}

-- === SHOWCASE STATE ===
local showcaseGui = nil
local mainPanel = nil
local scrollPanel = nil
local currentSection = 1
local sections = {}

-- === HELPER FUNCTIONS ===
local function createSection(title, description)
    local section = {
        title = title,
        description = description,
        components = {},
    }

    -- Section header panel
    section.headerPanel = Panel.new({
        size = UDim2.new(1, -20, 0, 80),
        layout = "none",
        variant = "accent",
        cornerRadius = "lg",
        shadow = true,
        animateEntrance = true,
    })

    -- Title label
    section.titleLabel = TextLabel.new({
        text = title,
        size = UDim2.new(1, -20, 0, 30),
        position = UDim2.new(0, 10, 0, 10),
        variant = "inverse",
        font = uiConfig.fonts.bold,
        fontSize = uiConfig.fonts.sizes.xl,
        textAlign = "left",
    })

    -- Description label
    section.descLabel = TextLabel.new({
        text = description,
        size = UDim2.new(1, -20, 0, 25),
        position = UDim2.new(0, 10, 0, 45),
        variant = "inverse",
        fontSize = uiConfig.fonts.sizes.sm,
        textAlign = "left",
    })

    section.headerPanel:AddChild(section.titleLabel)
    section.headerPanel:AddChild(section.descLabel)

    -- Content panel
    section.contentPanel = Panel.new({
        size = UDim2.new(1, -20, 0, 400),
        layout = "list",
        layoutDirection = "vertical",
        spacing = "md",
        variant = "surface",
        cornerRadius = "md",
        shadow = true,
        padding = "lg",
    })

    return section
end

local function addComponentToSection(section, component)
    table.insert(section.components, component)
    section.contentPanel:AddChild(component)
end

local function createDivider(text)
    local dividerPanel = Panel.new({
        size = UDim2.new(1, 0, 0, 40),
        layout = "none",
        variant = "background",
        cornerRadius = "sm",
    })

    local dividerLabel = TextLabel.new({
        text = text or "•••",
        size = UDim2.new(1, 0, 1, 0),
        variant = "muted",
        fontSize = uiConfig.fonts.sizes.lg,
    })

    dividerPanel:AddChild(dividerLabel)
    return dividerPanel
end

-- === BUTTON SHOWCASE ===
local function createButtonShowcase()
    local section = createSection(
        "🔘 Button Components",
        "Interactive buttons with hover, loading states, and sound effects"
    )

    -- Button variants row
    local variantsPanel = Panel.new({
        size = UDim2.new(1, 0, 0, 60),
        layout = "list",
        layoutDirection = "horizontal",
        spacing = "sm",
    })

    local primaryBtn = Button.new({
        text = "Primary",
        size = UDim2.new(0, 100, 0, 40),
        variant = "primary",
        onClick = function()
            print("Primary clicked!")
        end,
    })

    local secondaryBtn = Button.new({
        text = "Secondary",
        size = UDim2.new(0, 100, 0, 40),
        variant = "secondary",
        onClick = function()
            print("Secondary clicked!")
        end,
    })

    local successBtn = Button.new({
        text = "Success",
        size = UDim2.new(0, 100, 0, 40),
        variant = "success",
        onClick = function()
            print("Success clicked!")
        end,
    })

    local dangerBtn = Button.new({
        text = "Danger",
        size = UDim2.new(0, 100, 0, 40),
        variant = "danger",
        onClick = function()
            print("Danger clicked!")
        end,
    })

    variantsPanel:AddChild(primaryBtn)
    variantsPanel:AddChild(secondaryBtn)
    variantsPanel:AddChild(successBtn)
    variantsPanel:AddChild(dangerBtn)

    addComponentToSection(section, variantsPanel)
    addComponentToSection(section, createDivider("States & Loading"))

    -- States row
    local statesPanel = Panel.new({
        size = UDim2.new(1, 0, 0, 60),
        layout = "list",
        layoutDirection = "horizontal",
        spacing = "sm",
    })

    local loadingBtn = Button.new({
        text = "Loading...",
        size = UDim2.new(0, 120, 0, 40),
        variant = "primary",
        loading = true,
    })

    local disabledBtn = Button.new({
        text = "Disabled",
        size = UDim2.new(0, 120, 0, 40),
        variant = "secondary",
        disabled = true,
    })

    local toggleLoadingBtn = Button.new({
        text = "Toggle Loading",
        size = UDim2.new(0, 120, 0, 40),
        variant = "info",
        onClick = function()
            loadingBtn:SetLoading(not loadingBtn.state.loading)
        end,
    })

    statesPanel:AddChild(loadingBtn)
    statesPanel:AddChild(disabledBtn)
    statesPanel:AddChild(toggleLoadingBtn)

    addComponentToSection(section, statesPanel)

    return section
end

-- === PANEL SHOWCASE ===
local function createPanelShowcase()
    local section = createSection(
        "📋 Panel Components",
        "Flexible containers with layouts, shadows, and responsive design"
    )

    -- Layout examples
    local layoutsContainer = Panel.new({
        size = UDim2.new(1, 0, 0, 200),
        layout = "list",
        layoutDirection = "horizontal",
        spacing = "md",
    })

    -- List layout panel
    local listPanel = Panel.new({
        size = UDim2.new(0.3, 0, 1, 0),
        layout = "list",
        layoutDirection = "vertical",
        spacing = "xs",
        variant = "surface",
        cornerRadius = "md",
        shadow = true,
        padding = "sm",
    })

    local listTitle = TextLabel.new({
        text = "List Layout",
        size = UDim2.new(1, 0, 0, 25),
        variant = "primary",
        fontSize = uiConfig.fonts.sizes.sm,
    })

    for i = 1, 4 do
        local item = Panel.new({
            size = UDim2.new(1, 0, 0, 20),
            variant = "accent",
            cornerRadius = "sm",
        })

        local itemLabel = TextLabel.new({
            text = "Item " .. i,
            size = UDim2.new(1, 0, 1, 0),
            variant = "inverse",
            fontSize = uiConfig.fonts.sizes.xs,
        })

        item:AddChild(itemLabel)
        listPanel:AddChild(item)
    end

    listPanel:AddChild(listTitle, 1) -- Insert at beginning

    -- Grid layout panel
    local gridPanel = Panel.new({
        size = UDim2.new(0.3, 0, 1, 0),
        layout = "grid",
        columns = 2,
        spacing = "xs",
        variant = "surface",
        cornerRadius = "md",
        shadow = true,
        padding = "sm",
    })

    local gridTitle = TextLabel.new({
        text = "Grid Layout",
        size = UDim2.new(1, 0, 0, 25),
        variant = "primary",
        fontSize = uiConfig.fonts.sizes.sm,
    })

    for i = 1, 6 do
        local gridItem = Panel.new({
            size = UDim2.new(0.45, 0, 0, 30),
            variant = "success",
            cornerRadius = "sm",
        })

        local gridItemLabel = TextLabel.new({
            text = tostring(i),
            size = UDim2.new(1, 0, 1, 0),
            variant = "inverse",
            fontSize = uiConfig.fonts.sizes.sm,
        })

        gridItem:AddChild(gridItemLabel)
        gridPanel:AddChild(gridItem)
    end

    gridPanel:AddChild(gridTitle, 1)

    -- Effect panel
    local effectPanel = Panel.new({
        size = UDim2.new(0.3, 0, 1, 0),
        layout = "list",
        layoutDirection = "vertical",
        spacing = "sm",
        variant = "background",
        cornerRadius = "lg",
        shadow = true,
        backgroundBlur = true,
        padding = "md",
    })

    local effectTitle = TextLabel.new({
        text = "Blur Effect",
        size = UDim2.new(1, 0, 0, 30),
        variant = "primary",
        fontSize = uiConfig.fonts.sizes.md,
    })

    local effectDesc = TextLabel.new({
        text = "This panel has background blur enabled for a modern glass effect.",
        size = UDim2.new(1, 0, 0, 60),
        variant = "secondary",
        fontSize = uiConfig.fonts.sizes.sm,
        textWrapped = true,
    })

    effectPanel:AddChild(effectTitle)
    effectPanel:AddChild(effectDesc)

    layoutsContainer:AddChild(listPanel)
    layoutsContainer:AddChild(gridPanel)
    layoutsContainer:AddChild(effectPanel)

    addComponentToSection(section, layoutsContainer)

    return section
end

-- === TEXT SHOWCASE ===
local function createTextShowcase()
    local section = createSection(
        "📝 Text Components",
        "Rich text labels and input fields with validation and theming"
    )

    -- Text variants
    local variantsPanel = Panel.new({
        size = UDim2.new(1, 0, 0, 200),
        layout = "list",
        layoutDirection = "vertical",
        spacing = "sm",
        variant = "surface",
        cornerRadius = "md",
        padding = "md",
    })

    local variants = {
        { variant = "primary", text = "Primary text color" },
        { variant = "secondary", text = "Secondary text color" },
        { variant = "muted", text = "Muted text color" },
        { variant = "success", text = "✅ Success message" },
        { variant = "warning", text = "⚠️ Warning message" },
        { variant = "error", text = "❌ Error message" },
        { variant = "info", text = "ℹ️ Info message" },
    }

    for _, config in ipairs(variants) do
        local label = TextLabel.new({
            text = config.text,
            size = UDim2.new(1, 0, 0, 25),
            variant = config.variant,
            textAlign = "left",
            fontSize = uiConfig.fonts.sizes.md,
        })
        variantsPanel:AddChild(label)
    end

    addComponentToSection(section, variantsPanel)
    addComponentToSection(section, createDivider("Icons & Animation"))

    -- Icon examples
    local iconPanel = Panel.new({
        size = UDim2.new(1, 0, 0, 80),
        layout = "list",
        layoutDirection = "horizontal",
        spacing = "lg",
        variant = "surface",
        cornerRadius = "md",
        padding = "md",
    })

    local iconLabels = {
        { icon = "🚀", text = "Launch", position = "left" },
        { icon = "⭐", text = "Favorite", position = "right" },
        { icon = "📊", text = "Stats", position = "top" },
        { icon = "🔧", text = "Settings", position = "bottom" },
    }

    for _, config in ipairs(iconLabels) do
        local iconLabel = TextLabel.new({
            text = config.text,
            icon = config.icon,
            iconPosition = config.position,
            size = UDim2.new(0, 80, 0, 60),
            variant = "primary",
            fontSize = uiConfig.fonts.sizes.sm,
        })
        iconPanel:AddChild(iconLabel)
    end

    addComponentToSection(section, iconPanel)

    return section
end

-- === INPUT SHOWCASE ===
local function createInputShowcase()
    local section = createSection(
        "⌨️ Input Components",
        "Text inputs with validation, different types, and focus states"
    )

    -- Input types container
    local inputsContainer = Panel.new({
        size = UDim2.new(1, 0, 0, 300),
        layout = "list",
        layoutDirection = "vertical",
        spacing = "md",
        variant = "surface",
        cornerRadius = "md",
        padding = "lg",
    })

    -- Basic text input
    local textInput = TextInput.new({
        placeholder = "Enter your name...",
        size = UDim2.new(1, 0, 0, 40),
        inputType = "text",
        maxLength = 50,
        onChanged = function(text)
            print("Name changed:", text)
        end,
    })

    -- Email input with validation
    local emailInput = TextInput.new({
        placeholder = "Enter your email address...",
        size = UDim2.new(1, 0, 0, 40),
        inputType = "email",
        required = true,
        onChanged = function(text)
            print("Email changed:", text, "Valid:", emailInput:IsValid())
        end,
    })

    -- Number input
    local numberInput = TextInput.new({
        placeholder = "Enter a number...",
        size = UDim2.new(1, 0, 0, 40),
        inputType = "number",
        onChanged = function(text)
            print("Number changed:", text)
        end,
    })

    -- Password input
    local passwordInput = TextInput.new({
        placeholder = "Enter password...",
        size = UDim2.new(1, 0, 0, 40),
        inputType = "password",
        required = true,
        onChanged = function(text)
            print("Password length:", #text)
        end,
    })

    -- Multiline input
    local multilineInput = TextInput.new({
        placeholder = "Enter a longer message...",
        size = UDim2.new(1, 0, 0, 80),
        inputType = "text",
        multiline = true,
        maxLength = 200,
    })

    -- Add labels for each input
    local nameLabel = TextLabel.new({
        text = "Name (Text Input)",
        size = UDim2.new(1, 0, 0, 20),
        variant = "primary",
        textAlign = "left",
        fontSize = uiConfig.fonts.sizes.sm,
    })

    local emailLabel = TextLabel.new({
        text = "Email (Required + Validation)",
        size = UDim2.new(1, 0, 0, 20),
        variant = "primary",
        textAlign = "left",
        fontSize = uiConfig.fonts.sizes.sm,
    })

    local numberLabel = TextLabel.new({
        text = "Number (Number Input)",
        size = UDim2.new(1, 0, 0, 20),
        variant = "primary",
        textAlign = "left",
        fontSize = uiConfig.fonts.sizes.sm,
    })

    local passwordLabel = TextLabel.new({
        text = "Password (Masked Input)",
        size = UDim2.new(1, 0, 0, 20),
        variant = "primary",
        textAlign = "left",
        fontSize = uiConfig.fonts.sizes.sm,
    })

    local multilineLabel = TextLabel.new({
        text = "Message (Multiline)",
        size = UDim2.new(1, 0, 0, 20),
        variant = "primary",
        textAlign = "left",
        fontSize = uiConfig.fonts.sizes.sm,
    })

    inputsContainer:AddChild(nameLabel)
    inputsContainer:AddChild(textInput)
    inputsContainer:AddChild(emailLabel)
    inputsContainer:AddChild(emailInput)
    inputsContainer:AddChild(numberLabel)
    inputsContainer:AddChild(numberInput)
    inputsContainer:AddChild(passwordLabel)
    inputsContainer:AddChild(passwordInput)
    inputsContainer:AddChild(multilineLabel)
    inputsContainer:AddChild(multilineInput)

    addComponentToSection(section, inputsContainer)

    return section
end

-- === THEME SHOWCASE ===
local function createThemeShowcase()
    local section = createSection(
        "🎨 Theme System",
        "Dynamic theme switching and responsive design demonstration"
    )

    -- Theme controls
    local themePanel = Panel.new({
        size = UDim2.new(1, 0, 0, 100),
        layout = "list",
        layoutDirection = "vertical",
        spacing = "md",
        variant = "surface",
        cornerRadius = "md",
        padding = "md",
    })

    local themeLabel = TextLabel.new({
        text = "Theme Controls",
        size = UDim2.new(1, 0, 0, 25),
        variant = "primary",
        fontSize = uiConfig.fonts.sizes.lg,
        textAlign = "left",
    })

    local buttonPanel = Panel.new({
        size = UDim2.new(1, 0, 0, 50),
        layout = "list",
        layoutDirection = "horizontal",
        spacing = "md",
    })

    local darkThemeBtn = Button.new({
        text = "🌙 Dark Theme",
        size = UDim2.new(0, 140, 0, 40),
        variant = "primary",
        onClick = function()
            -- Theme switching would be implemented here
            print("Switching to dark theme...")
        end,
    })

    local lightThemeBtn = Button.new({
        text = "☀️ Light Theme",
        size = UDim2.new(0, 140, 0, 40),
        variant = "secondary",
        onClick = function()
            print("Switching to light theme...")
        end,
    })

    buttonPanel:AddChild(darkThemeBtn)
    buttonPanel:AddChild(lightThemeBtn)

    themePanel:AddChild(themeLabel)
    themePanel:AddChild(buttonPanel)

    addComponentToSection(section, themePanel)

    return section
end

-- === MAIN SHOWCASE FUNCTIONS ===
function ComponentShowcase:Show()
    if showcaseGui then
        showcaseGui:Destroy()
    end

    -- Create main ScreenGui
    showcaseGui = Instance.new("ScreenGui")
    showcaseGui.Name = "ComponentShowcase"
    showcaseGui.ResetOnSpawn = false
    showcaseGui.Parent = playerGui

    -- Create main container panel
    mainPanel = Panel.new({
        size = UDim2.new(0.9, 0, 0.9, 0),
        position = UDim2.new(0.05, 0, 0.05, 0),
        layout = "list",
        layoutDirection = "vertical",
        spacing = "lg",
        variant = "background",
        cornerRadius = "xl",
        shadow = true,
        padding = "lg",
        animateEntrance = true,
    })

    -- Title section
    local titlePanel = Panel.new({
        size = UDim2.new(1, 0, 0, 100),
        layout = "none",
        variant = "accent",
        cornerRadius = "lg",
        shadow = true,
    })

    local titleLabel = TextLabel.new({
        text = "🎨 UI Component Showcase",
        size = UDim2.new(1, -40, 0, 40),
        position = UDim2.new(0, 20, 0, 20),
        variant = "inverse",
        fontSize = uiConfig.fonts.sizes.xxxl,
        fontWeight = "bold",
        textAlign = "left",
    })

    local subtitleLabel = TextLabel.new({
        text = "Interactive demonstration of all available UI components",
        size = UDim2.new(1, -40, 0, 30),
        position = UDim2.new(0, 20, 0, 60),
        variant = "inverse",
        fontSize = uiConfig.fonts.sizes.md,
        textAlign = "left",
    })

    titlePanel:AddChild(titleLabel)
    titlePanel:AddChild(subtitleLabel)

    -- Create scrolling container for sections
    scrollPanel = Panel.new({
        size = UDim2.new(1, 0, 1, -120),
        layout = "list",
        layoutDirection = "vertical",
        spacing = "xl",
        variant = "background",
        cornerRadius = "md",
        padding = "md",
    })

    -- Create sections
    sections = {
        createButtonShowcase(),
        createPanelShowcase(),
        createTextShowcase(),
        createInputShowcase(),
        createThemeShowcase(),
    }

    -- Add sections to scroll panel
    for _, section in ipairs(sections) do
        scrollPanel:AddChild(section.headerPanel)
        scrollPanel:AddChild(section.contentPanel)
    end

    -- Add main components to main panel
    mainPanel:AddChild(titlePanel)
    mainPanel:AddChild(scrollPanel)

    -- Set parent to show everything
    mainPanel:SetParent(showcaseGui)

    print("🎨 Component Showcase loaded! Demonstrating all UI components.")
end

function ComponentShowcase:Hide()
    if showcaseGui then
        -- Animate out
        local fadeOut = TweenService:Create(
            showcaseGui,
            TweenInfo.new(
                uiConfig.animations.duration.normal,
                uiConfig.animations.easing.ease_in,
                uiConfig.animations.direction.in_dir
            ),
            { BackgroundTransparency = 1 }
        )

        fadeOut.Completed:Connect(function()
            showcaseGui:Destroy()
            showcaseGui = nil
        end)

        fadeOut:Play()
    end
end

return ComponentShowcase
