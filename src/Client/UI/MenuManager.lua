--[[
    MenuManager - Advanced UI panel management with configurable transitions
    
    Version: 2.0 - Enhanced Integration & Global Access
    
    Features:
    - Opens/closes specific menu panels with smooth transitions
    - Configurable animation effects (slide, fade, scale, bounce)
    - Single panel active at a time
    - ESC key handling
    - Panel state management
    - Audio feedback
    - Template-based UI integration
    - Global accessibility via _G.MenuManager
    - Integration with BaseUI system
    - Professional panel designs (InventoryPanel, ShopPanel, EffectsPanel, etc.)
    
    Architecture:
    - Works with BaseUI to manage popup panels
    - Automatically registered panels: Shop, Inventory, Effects, Settings, Admin
    - Smooth transitions between different panel types
    - Centralized panel management for the entire game
    
    Usage:
    local menuManager = MenuManager.new()
    menuManager:RegisterPanel("Shop", shopPanel)
    menuManager:OpenPanel("Shop", "slide_in")
    menuManager:TogglePanel("Inventory", "fade_in")
    
    Global Access:
    _G.MenuManager:OpenPanel("Shop")  -- Accessible from anywhere
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Get shared modules
local Locations = require(ReplicatedStorage.Shared.Locations)
local SoundGroups = require(ReplicatedStorage.Shared.Effects.SoundGroups)

-- Load Logger with wrapper (following the established pattern)
local LoggerWrapper
local loggerSuccess, loggerResult = pcall(function()
    return require(Locations.Logger)
end)

if loggerSuccess and loggerResult then
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

-- Load UI config with enhanced fallback
local uiConfig
local configSuccess, configResult = pcall(function()
    return Locations.getConfig("ui")
end)

if configSuccess and configResult then
    uiConfig = configResult
else
    warn("[MenuManager] Using fallback UI config - check configs/ui.lua loading")
    uiConfig = {
        animations = {
            duration = { fast = 0.15, normal = 0.25, slow = 0.4 },
            easing = { ease_out = Enum.EasingStyle.Quad, ease_in = Enum.EasingStyle.Quad },
            direction = { out_dir = Enum.EasingDirection.Out, in_dir = Enum.EasingDirection.In },
            menu_transitions = {
                enabled = true,
                default_effect = "slide_in",
                effects = {
                    slide_in = {
                        duration = "normal",
                        easing = "ease_out",
                        direction = "out_dir",
                        start_position = UDim2.new(1.2, 0, 0.5, 0),
                        end_position = UDim2.new(0.5, 0, 0.5, 0),
                        anchor_point = Vector2.new(0.5, 0.5),
                    },
                },
            },
        },
        sounds = {
            enabled = true,
            volume = 0.5,
            effects = { panel_open = "rbxassetid://0", panel_close = "rbxassetid://0" },
        },
    }
end

local MenuManager = {}
MenuManager.__index = MenuManager

function MenuManager.new()
    local self = setmetatable({}, MenuManager)

    self.logger = LoggerWrapper.new("MenuManager")

    -- Panel state
    self.currentPanel = nil
    self.currentPanelName = nil
    self.panels = {}
    self.isTransitioning = false

    -- UI elements
    self.overlayFrame = nil
    self.escConnection = nil

    -- Initialize overlay
    self:_createOverlay()
    self:_setupInputHandling()

    self.logger:info("MenuManager initialized with transition effects")
    return self
end

-- Create overlay frame for panels
function MenuManager:_createOverlay()
    local player = Players.LocalPlayer
    local playerGui = player:WaitForChild("PlayerGui")

    -- Find or create overlay ScreenGui
    local overlayGui = playerGui:FindFirstChild("MenuOverlay")
    if not overlayGui then
        overlayGui = Instance.new("ScreenGui")
        overlayGui.Name = "MenuOverlay"
        overlayGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        overlayGui.Parent = playerGui
    end
    -- Menus sit ABOVE the HUD + quest tracker (PlayerBar=80, BuffStats=100) so a near-fullscreen menu
    -- doesn't fight the player bar / currency bleeding through (Jason).
    overlayGui.DisplayOrder = 120

    -- Panels parent DIRECTLY to the MenuOverlay ScreenGui — no wrapper Frame layer (Jason: cleaner).
    -- Show/hide is driven by the scrim's visibility; panels create/destroy their own frame on Show/Hide.
    self.overlayFrame = overlayGui

    -- Dim scrim behind every panel — darkens the HUD so the menu reads as a modal ("blink out the
    -- screen like egg hatches"). TextButton so it absorbs clicks (HUD buttons behind aren't hit by
    -- accident); ZIndex 1 keeps it under the panels (ZIndex 100+). Hidden until a panel opens.
    local scrim = Instance.new("TextButton")
    scrim.Name = "Scrim"
    scrim.Text = ""
    scrim.AutoButtonColor = false
    scrim.Size = UDim2.new(1, 0, 1, 0)
    scrim.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    scrim.BackgroundTransparency = 0.4
    scrim.BorderSizePixel = 0
    scrim.ZIndex = 1
    scrim.Visible = false
    scrim.Parent = overlayGui
    self._scrim = scrim

    -- The scrim MUST hide whenever no panel is showing. Panels can self-close (their own X /
    -- _requestClose / ESC) without routing through CloseCurrentPanel, and a stale click-absorbing
    -- scrim would lock the whole screen (Jason). So derive its visibility reactively from panel
    -- presence — robust to every close path.
    local function updateScrim()
        local hasPanel = false
        for _, c in ipairs(overlayGui:GetChildren()) do
            if c ~= scrim and c:IsA("GuiObject") then
                hasPanel = true
                break
            end
        end
        scrim.Visible = hasPanel
    end
    overlayGui.ChildAdded:Connect(updateScrim)
    overlayGui.ChildRemoved:Connect(updateScrim)

    self.logger:debug("Overlay frame created")
end

-- Register a panel for management
function MenuManager:RegisterPanel(name, panelObject)
    if not name or not panelObject then
        self.logger:error("Invalid panel registration:", name, panelObject)
        return
    end

    self.panels[name] = panelObject
    self.logger:info("Registered panel:", name)
end

function MenuManager:_hideCurrentPanelForSwitch()
    local panelToClose = self.currentPanel
    local panelName = self.currentPanelName

    if not panelToClose then
        return
    end

    self.currentPanel = nil
    self.currentPanelName = nil

    if self.escConnection then
        self.escConnection:Disconnect()
        self.escConnection = nil
    end

    panelToClose:Hide()
    self.logger:info("Switched away from panel:", panelName)
end

-- Open a specific panel with configurable transition
function MenuManager:OpenPanel(panelName, transitionEffect)
    if self.isTransitioning then
        self.logger:warn("Already transitioning, ignoring open request")
        return false
    end

    -- Switch panels inside the same overlay without running an async close that can hide the new panel.
    if self.currentPanel then
        self:_hideCurrentPanelForSwitch()
    end

    local panel = self.panels[panelName]
    if not panel then
        self.logger:error("Panel not found: " .. tostring(panelName))
        return false
    end

    self.isTransitioning = true

    -- Show the dim scrim, then the panel (both parent to the MenuOverlay ScreenGui).
    if self._scrim then
        self._scrim.Visible = true
    end
    panel:Show(self.overlayFrame)

    -- Get panel frame and animate entrance
    local panelFrame = panel:GetFrame()
    if panelFrame then
        self:_animateEntrance(panelFrame, transitionEffect)
    end

    self.currentPanel = panel
    self.currentPanelName = panelName

    -- Setup ESC key handling
    self:_setupEscapeHandling()

    self.isTransitioning = false
    self.logger:info("Opened panel:", panelName, "with effect:", transitionEffect or "default")
    return true
end

-- Close the current panel
function MenuManager:CloseCurrentPanel(transitionEffect)
    if not self.currentPanel then
        return
    end

    if self.isTransitioning then
        self.logger:warn("Already transitioning, ignoring close request")
        return
    end

    self.isTransitioning = true

    local panelToClose = self.currentPanel
    local panelFrame = panelToClose:GetFrame()
    local panelName = self.currentPanelName

    -- Clear current references immediately
    self.currentPanel = nil
    self.currentPanelName = nil

    -- Disable ESC handling
    if self.escConnection then
        self.escConnection:Disconnect()
        self.escConnection = nil
    end

    -- Animate exit and then hide
    self:_animateExit(panelFrame, function()
        -- Hide the panel
        panelToClose:Hide()

        -- Hide the dim scrim (the panel destroyed its own frame in :Hide()).
        if self._scrim then
            self._scrim.Visible = false
        end

        self.isTransitioning = false
        self.logger:info("Closed panel:", panelName)
    end, transitionEffect)
end

-- Toggle a panel (open if closed, close if open)
function MenuManager:TogglePanel(panelName, transitionEffect)
    if self.currentPanelName == panelName then
        -- SELF-HEAL stale open-state (Jason: "you have to click the pets button
        -- twice to get it to open again"): panels' own X buttons call panel:Hide()
        -- directly without informing the manager, so currentPanelName still says
        -- open. If the tracked panel reports itself hidden, clear the stale state
        -- and OPEN instead of no-op "closing" a destroyed frame.
        local panel = self.currentPanel
        if panel and panel.isVisible == false then
            self.currentPanel = nil
            self.currentPanelName = nil
            return self:OpenPanel(panelName, transitionEffect)
        end
        self:CloseCurrentPanel(transitionEffect)
        return false
    else
        return self:OpenPanel(panelName, transitionEffect)
    end
end

-- Animate panel entrance with configurable effects
-- Supports 15 different animation types including slides, scales, rotations, bounces, and fades
-- Effects are defined in configs/ui.lua under animations.menu_transitions.effects
function MenuManager:_animateEntrance(frame, effectName)
    if not frame then
        return
    end

    -- Get transition effect configuration
    local transitions = uiConfig.animations and uiConfig.animations.menu_transitions
    if not transitions or not transitions.enabled then
        -- No transitions configured, just center the frame
        frame.Position = UDim2.new(0.5, 0, 0.5, 0)
        frame.AnchorPoint = Vector2.new(0.5, 0.5)
        return
    end

    -- Use specified effect or default
    effectName = effectName or transitions.default_effect
    self.logger:info("Attempting to use transition effect:", effectName)

    local effect = transitions.effects[effectName]

    if not effect then
        self.logger:warn("Unknown transition effect:", effectName, "using default")
        self.logger:info("Available effects:", table.concat(self:_getAvailableEffects(), ", "))
        effect = transitions.effects[transitions.default_effect]
            or transitions.effects.slide_in_right
    end

    if not effect then
        -- No valid effect found, use simple positioning
        frame.Position = UDim2.new(0.5, 0, 0.5, 0)
        frame.AnchorPoint = Vector2.new(0.5, 0.5)
        return
    end

    -- Setup initial state
    frame.AnchorPoint = effect.anchor_point or Vector2.new(0.5, 0.5)
    frame.Position = effect.start_position or UDim2.new(1.1, 0, 0.5, 0)

    if effect.start_transparency then
        frame.BackgroundTransparency = effect.start_transparency
    end

    -- Setup UIScale for scale effects
    local uiScale = frame:FindFirstChildOfClass("UIScale")
    if effect.start_scale then
        if not uiScale then
            uiScale = Instance.new("UIScale")
            uiScale.Parent = frame
        end
        uiScale.Scale = effect.start_scale
    end

    -- Setup rotation for rotation effects (spin_in, flip_in, spiral_in, etc.)
    if effect.start_rotation then
        frame.Rotation = effect.start_rotation
    end

    -- Create tween properties
    local tweenProperties = {}

    if effect.end_position then
        tweenProperties.Position = effect.end_position
    end

    if effect.end_transparency then
        tweenProperties.BackgroundTransparency = effect.end_transparency
    end

    -- Add rotation tween properties for spinning effects
    if effect.end_rotation then
        tweenProperties.Rotation = effect.end_rotation
    end

    -- Create main tween
    local duration = uiConfig.animations.duration[effect.duration]
        or uiConfig.animations.duration.normal
    local easingStyle = uiConfig.animations.easing[effect.easing]
        or uiConfig.animations.easing.ease_out
    local easingDirection = uiConfig.animations.direction[effect.direction]
        or uiConfig.animations.direction.out_dir

    local mainTween = TweenService:Create(
        frame,
        TweenInfo.new(duration, easingStyle, easingDirection),
        tweenProperties
    )

    -- Create scale tween if needed
    local scaleTween = nil
    if effect.end_scale and uiScale then
        scaleTween = TweenService:Create(
            uiScale,
            TweenInfo.new(duration, easingStyle, easingDirection),
            { Scale = effect.end_scale }
        )
    end

    -- Play animations
    mainTween:Play()
    if scaleTween then
        scaleTween:Play()
    end

    -- Play sound effect if configured
    self:_playPanelSound("panel_open")

    self.logger:debug("Applied entrance effect:", effectName)
end

-- Animate panel exit
function MenuManager:_animateExit(frame, callback, effectName)
    if not frame then
        if callback then
            callback()
        end
        return
    end

    -- Get transition effect configuration for exit
    local transitions = uiConfig.animations and uiConfig.animations.menu_transitions
    if not transitions or not transitions.enabled then
        -- No transitions, just call callback
        if callback then
            callback()
        end
        return
    end

    -- Use specified effect or default (but reversed for exit)
    effectName = effectName or transitions.default_effect
    local effect = transitions.effects[effectName]

    if not effect then
        self.logger:warn("Unknown exit effect:", effectName)
        if callback then
            callback()
        end
        return
    end

    -- Create exit tween (reverse of entrance)
    local tweenProperties = {}

    -- For exit, we usually go to start position or off-screen
    if effect.start_position then
        tweenProperties.Position = effect.start_position
    end

    if effect.start_transparency then
        tweenProperties.BackgroundTransparency = effect.start_transparency
    end

    if effect.start_rotation then
        tweenProperties.Rotation = effect.start_rotation
    end

    -- Setup UIScale for scale effects
    local uiScale = frame:FindFirstChildOfClass("UIScale")
    local scaleTween = nil
    if effect.start_scale and uiScale then
        scaleTween = TweenService:Create(
            uiScale,
            TweenInfo.new(
                uiConfig.animations.duration.fast,
                Enum.EasingStyle.Quad,
                Enum.EasingDirection.In
            ),
            { Scale = effect.start_scale }
        )
    end

    -- Create main exit tween
    local exitTween = TweenService:Create(
        frame,
        TweenInfo.new(
            uiConfig.animations.duration.fast,
            Enum.EasingStyle.Quad,
            Enum.EasingDirection.In
        ),
        tweenProperties
    )

    exitTween.Completed:Connect(function()
        if callback then
            callback()
        end
    end)

    -- Play animations
    exitTween:Play()
    if scaleTween then
        scaleTween:Play()
    end

    -- Play sound effect if configured
    self:_playPanelSound("panel_close")

    self.logger:debug("Applied exit effect:", effectName)
end

-- Setup ESC key handling
function MenuManager:_setupEscapeHandling()
    if self.escConnection then
        self.escConnection:Disconnect()
    end

    self.escConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then
            return
        end

        if input.KeyCode == Enum.KeyCode.Escape and self.currentPanel then
            self:CloseCurrentPanel()
        end
    end)
end

-- Setup general input handling
function MenuManager:_setupInputHandling()
    -- Additional input handling can go here
    self.logger:debug("Input handling setup")
end

-- Play panel sound effects
function MenuManager:_playPanelSound(soundType)
    if not uiConfig.sounds or not uiConfig.sounds.enabled then
        return
    end

    local soundId = uiConfig.sounds.effects and uiConfig.sounds.effects[soundType]
    if not soundId or soundId == "rbxassetid://0" then
        return
    end

    task.spawn(function()
        pcall(function()
            local sound = Instance.new("Sound")
            sound.SoundId = soundId
            sound.Volume = uiConfig.sounds.volume or 0.5
            SoundGroups.assign(sound, "ui")
            sound.Parent = SoundService

            sound:Play()

            sound.Ended:Connect(function()
                sound:Destroy()
            end)

            -- Cleanup after 5 seconds if still playing
            task.wait(5)
            if sound.Parent then
                sound:Destroy()
            end
        end)
    end)
end

-- Convenience methods for specific effects
function MenuManager:SlideInPanel(panelName)
    return self:OpenPanel(panelName, "slide_in")
end

function MenuManager:FadeInPanel(panelName)
    return self:OpenPanel(panelName, "fade_in")
end

function MenuManager:ScaleInPanel(panelName)
    return self:OpenPanel(panelName, "scale_in")
end

function MenuManager:BounceInPanel(panelName)
    return self:OpenPanel(panelName, "bounce_in")
end

-- Panel interface methods with effect options
function MenuManager:OpenShopPanel(effect)
    return self:OpenPanel("Shop", effect)
end

function MenuManager:OpenInventoryPanel(effect)
    return self:OpenPanel("Inventory", effect)
end

function MenuManager:OpenEffectsPanel(effect)
    return self:OpenPanel("Effects", effect)
end

function MenuManager:OpenEnchantPanel(effect)
    return self:OpenPanel("Enchant", effect)
end

function MenuManager:OpenSettingsPanel(effect)
    return self:OpenPanel("Settings", effect)
end

function MenuManager:OpenAdminPanel(effect)
    return self:OpenPanel("Admin", effect)
end

-- Get current panel info
function MenuManager:GetCurrentPanel()
    return self.currentPanel
end

function MenuManager:GetCurrentPanelName()
    return self.currentPanelName
end

function MenuManager:IsTransitioning()
    return self.isTransitioning
end

-- Get registered panels
function MenuManager:GetRegisteredPanels()
    local panelNames = {}
    for name, _ in pairs(self.panels) do
        table.insert(panelNames, name)
    end
    return panelNames
end

-- Get a registered panel by name (for external access like network updates)
function MenuManager:GetPanel(panelName)
    return self.panels[panelName]
end

-- Get the name of the currently open panel
function MenuManager:GetCurrentPanelName()
    return self.currentPanelName
end

-- Check if a panel is currently open
function MenuManager:IsPanelOpen(panelName)
    return self.currentPanelName == panelName
end

-- Get available animation effects for debugging
-- Returns a list of all configured animation effect names from the UI config
function MenuManager:_getAvailableEffects()
    local effects = {}
    local transitions = uiConfig.animations and uiConfig.animations.menu_transitions
    if transitions and transitions.effects then
        for effectName, _ in pairs(transitions.effects) do
            table.insert(effects, effectName)
        end
    end
    return effects
end

-- Cleanup
function MenuManager:Destroy()
    -- Close current panel
    if self.currentPanel then
        self.currentPanel:Hide()
    end

    -- Disconnect input handling
    if self.escConnection then
        self.escConnection:Disconnect()
    end

    -- Clean up overlay
    if self.overlayFrame then
        self.overlayFrame:Destroy()
    end

    self.logger:info("MenuManager destroyed")
end

return MenuManager
