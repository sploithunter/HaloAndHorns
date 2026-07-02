--[[
    UserDisplayPreferences Service
    
    Manages user preferences for UI display methods (images vs viewports).
    Integrates with DataService for persistence and provides configuration-based defaults.
    
    Features:
    - Per-context user preferences (inventory, egg_preview, etc.)
    - Developer control over which preferences users can change
    - Performance monitoring and auto-fallback
    - Warning system for performance impact
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- Dependencies
local Locations = require(ReplicatedStorage.Shared.Locations)
local Logger = require(ReplicatedStorage.Shared.Utils.Logger)

-- Logger wrapper for this service
local LoggerWrapper
local loggerSuccess, loggerResult = pcall(function()
    return require(ReplicatedStorage.Shared.Utils.Logger)
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
    -- Fallback
    LoggerWrapper = {
        new = function(name)
            return {
                info = function(self, ...)
                    print("[" .. name .. "]", ...)
                end,
                warn = function(self, ...)
                    warn("[" .. name .. "]", ...)
                end,
                error = function(self, ...)
                    error("[" .. name .. "] " .. tostring((...)))
                end,
                debug = function(self, ...)
                    print("[DEBUG " .. name .. "]", ...)
                end,
            }
        end,
    }
end

local UserDisplayPreferences = {}
local logger = LoggerWrapper.new("UserDisplayPreferences")

-- Configuration cache
local petConfig = nil
local uiDisplayConfig = nil

-- User preferences cache (per player)
local userPreferences = {}

-- Performance monitoring
local performanceMonitoring = {}

-- Initialize service
function UserDisplayPreferences:Initialize()
    local isServer = game:GetService("RunService"):IsServer()
    print(
        "🔧 UserDisplayPreferences:Initialize() called on "
            .. (isServer and "SERVER" or "CLIENT")
            .. "!"
    ) -- Debug print
    logger:info("UserDisplayPreferences initializing on " .. (isServer and "server" or "client"))

    -- Load configuration
    petConfig = Locations.getConfig("pets")
    uiDisplayConfig = petConfig.ui_display

    -- Set up automatic preference loading for new players
    if game:GetService("RunService"):IsServer() then
        -- Server-side: Load preferences when player data is ready
        local Players = game:GetService("Players")

        -- Connect to existing players
        for _, player in pairs(Players:GetPlayers()) do
            self:SetupPlayerPreferences(player)
        end

        -- Connect to new players
        Players.PlayerAdded:Connect(function(player)
            self:SetupPlayerPreferences(player)
        end)

        -- Clean up when players leave
        Players.PlayerRemoving:Connect(function(player)
            local playerId = tostring(player.UserId)
            userPreferences[playerId] = nil

            -- Clean up performance monitoring
            if performanceMonitoring[playerId] then
                for _, connection in pairs(performanceMonitoring[playerId]) do
                    if connection and connection.Disconnect then
                        connection:Disconnect()
                    end
                end
                performanceMonitoring[playerId] = nil
            end
        end)

        -- Set up server-side signal handlers
        self:SetupServerSignalHandlers()
    end

    logger:info("UserDisplayPreferences initialized successfully")
end

-- Set up server-side signal handlers (server-side only)
function UserDisplayPreferences:SetupServerSignalHandlers()
    local success, Signals = pcall(function()
        return require(game:GetService("ReplicatedStorage").Shared.Network.Signals)
    end)

    if success and Signals.SaveDisplayPreferences then
        -- Handle client requests to save display preferences
        Signals.SaveDisplayPreferences.OnServerEvent:Connect(function(player, data)
            local playerId = tostring(player.UserId)

            logger:info("Received display preferences save request from client", {
                player = player.Name,
                data = data,
                dataType = type(data),
                hasPreferences = data and data.preferences ~= nil,
            })

            if data and data.preferences then
                -- DON'T update server-side cache - ProfileStore is single source of truth
                -- Instead, save directly to ProfileStore and let it update the replicated folders

                logger:info("Received preferences from client, saving to ProfileStore", {
                    player = player.Name,
                    preferences = data.preferences,
                })

                -- Save directly to ProfileStore (single source of truth)
                local success = self:SavePreferencesToProfileStore(player, data.preferences)

                if success then
                    logger:info("Successfully saved display preferences to ProfileStore", {
                        player = player.Name,
                        preferences = data.preferences,
                    })
                else
                    logger:warn("Failed to save display preferences to ProfileStore", {
                        player = player.Name,
                        preferences = data.preferences,
                    })
                end
            else
                logger:warn("Invalid display preferences data from client", {
                    player = player.Name,
                    data = data,
                    dataType = type(data),
                })
            end
        end)

        logger:debug("Server signal handlers set up successfully")
    else
        logger:warn("Failed to set up server signal handlers", {
            error = success and "Signals.SaveDisplayPreferences not found" or Signals,
        })
    end
end

-- Set up preference loading for a player (waits for data to be ready)
function UserDisplayPreferences:SetupPlayerPreferences(player)
    task.spawn(function()
        -- Wait for player data to be loaded
        while not player:GetAttribute("DataLoaded") do
            task.wait(0.1)
        end

        -- Load user preferences
        self:LoadUserPreferences(player)

        logger:debug("Player preferences setup completed", {
            player = player.Name,
            preferences = userPreferences[tostring(player.UserId)],
        })
    end)
end

-- Get display method for a context, respecting user preferences
function UserDisplayPreferences:GetDisplayMethod(player, context)
    if not player or not context then
        logger:warn("Invalid parameters for GetDisplayMethod", {
            player = player and player.Name or "nil",
            context = context,
        })
        return "images" -- Safe fallback
    end

    -- Auto-initialize if not already done
    if not uiDisplayConfig then
        self:Initialize()
    end

    -- Safety check
    if not uiDisplayConfig then
        logger:warn("Failed to initialize UI display configuration")
        return "images" -- Safe fallback
    end

    -- Get base configuration
    local baseMethod = uiDisplayConfig[context]

    -- Check for developer override first (highest priority)
    if uiDisplayConfig.context_overrides[context] then
        logger:debug("Using developer override", {
            player = player.Name,
            context = context,
            method = uiDisplayConfig.context_overrides[context],
        })
        return uiDisplayConfig.context_overrides[context]
    end

    -- If base method is not "user", return it directly
    if baseMethod ~= "user" then
        logger:debug("Using developer-set method", {
            player = player.Name,
            context = context,
            method = baseMethod,
        })
        return baseMethod
    end

    -- Base method is "user" - check if user control is allowed
    local allowUserControl = uiDisplayConfig.user_preferences.allow_user_control[context]
    if not allowUserControl then
        -- User control not allowed, use default
        local defaultMethod = uiDisplayConfig.user_preferences.defaults[context] or "images"
        logger:debug("User control not allowed, using default", {
            player = player.Name,
            context = context,
            method = defaultMethod,
        })
        return defaultMethod
    end

    -- Get user preference
    local userPref = self:GetUserPreference(player, context)

    -- Check performance monitoring
    if self:ShouldForceImagesForPerformance(player, context, userPref) then
        logger:info("Forcing images due to performance", {
            player = player.Name,
            context = context,
            originalPreference = userPref,
        })
        return "images"
    end

    logger:debug("Using user preference", {
        player = player.Name,
        context = context,
        method = userPref,
    })

    return userPref
end

-- Get user preference for a specific context
function UserDisplayPreferences:GetUserPreference(player, context)
    -- Auto-initialize if not already done
    if not uiDisplayConfig then
        self:Initialize()
    end

    local playerId = tostring(player.UserId)

    -- Initialize user preferences if not cached
    if not userPreferences[playerId] then
        self:LoadUserPreferences(player)
    end

    local userPref = userPreferences[playerId] and userPreferences[playerId][context]

    -- Use default if no preference set
    if not userPref then
        if uiDisplayConfig and uiDisplayConfig.user_preferences then
            userPref = uiDisplayConfig.user_preferences.defaults[context] or "images"
        else
            userPref = "images" -- Safe fallback
        end
    end

    return userPref
end

-- Set user preference for a specific context
function UserDisplayPreferences:SetUserPreference(player, context, method)
    if not player or not context or not method then
        logger:warn("Invalid parameters for SetUserPreference")
        return false
    end

    -- Auto-initialize if not already done
    if not uiDisplayConfig then
        self:Initialize()
    end

    -- Safety check
    if not uiDisplayConfig or not uiDisplayConfig.user_preferences then
        logger:warn("UI display configuration not available")
        return false
    end

    -- Check if user control is allowed
    local allowUserControl = uiDisplayConfig.user_preferences.allow_user_control[context]
    if not allowUserControl then
        logger:warn("User tried to change preference for restricted context", {
            player = player.Name,
            context = context,
            attemptedMethod = method,
        })
        return false
    end

    -- Validate method
    if method ~= "images" and method ~= "viewports" then
        logger:warn("Invalid display method", {
            player = player.Name,
            context = context,
            method = method,
        })
        return false
    end

    local playerId = tostring(player.UserId)

    -- Initialize if needed
    if not userPreferences[playerId] then
        userPreferences[playerId] = {}
    end

    -- Set preference
    userPreferences[playerId][context] = method

    -- Save to DataService (if available)
    self:SaveUserPreferences(player)

    -- Start performance monitoring if switching to viewports
    if method == "viewports" then
        self:StartPerformanceMonitoring(player, context)
    end

    logger:info("User preference updated", {
        player = player.Name,
        context = context,
        method = method,
    })

    return true
end

-- Load user preferences (server loads from DataService, client reads from replicated folders)
function UserDisplayPreferences:LoadUserPreferences(player)
    local playerId = tostring(player.UserId)

    -- Initialize with defaults first
    userPreferences[playerId] = {}

    -- Safety check for configuration
    if
        uiDisplayConfig
        and uiDisplayConfig.user_preferences
        and uiDisplayConfig.user_preferences.defaults
    then
        for context, defaultMethod in pairs(uiDisplayConfig.user_preferences.defaults) do
            userPreferences[playerId][context] = defaultMethod
        end
    else
        -- Fallback defaults
        userPreferences[playerId].inventory = "images"
        userPreferences[playerId].egg_preview = "images"
    end

    -- Different behavior for server vs client
    if game:GetService("RunService"):IsServer() then
        -- Server-side: Load from DataService and create replicated folders
        self:LoadUserPreferencesServer(player, playerId)
    else
        -- Client-side: Read from automatically replicated player folders
        self:LoadUserPreferencesClient(player, playerId)
    end
end

-- Server-side preference loading
function UserDisplayPreferences:LoadUserPreferencesServer(player, playerId)
    local success, result = pcall(function()
        -- Get DataService through Locations
        local Locations = require(game:GetService("ReplicatedStorage").Shared.Locations)
        local dataService = Locations.getService("DataService")

        if dataService then
            local playerData = dataService:GetData(player)
            if playerData then
                -- Ensure Settings exists in the profile data
                if not playerData.Settings then
                    playerData.Settings = {
                        MusicEnabled = true,
                        SFXEnabled = true,
                        GraphicsQuality = "Auto",
                        DisplayPreferences = {},
                    }
                end

                -- Ensure DisplayPreferences exists
                if not playerData.Settings.DisplayPreferences then
                    playerData.Settings.DisplayPreferences = {}
                end

                -- Override defaults with saved preferences if they exist
                if playerData.Settings.DisplayPreferences then
                    for context, savedMethod in pairs(playerData.Settings.DisplayPreferences) do
                        if userPreferences[playerId][context] ~= nil then -- Only override known contexts
                            userPreferences[playerId][context] = savedMethod
                        end
                    end

                    logger:info("Loaded user preferences from DataService", {
                        player = player.Name,
                        saved = playerData.Settings.DisplayPreferences,
                        final = userPreferences[playerId],
                    })
                else
                    logger:debug("No saved display preferences found, using defaults", {
                        player = player.Name,
                        preferences = userPreferences[playerId],
                    })
                end
            else
                logger:warn("No player data available", {
                    player = player.Name,
                })
            end

            -- Always create replicated folders for client access (regardless of saved data)
            self:CreateReplicatedSettingsFolders(player, playerId)
            return true
        else
            logger:warn("DataService not available for preference loading", {
                player = player.Name,
            })
            return false
        end
    end)

    if not success then
        logger:warn("Error loading user preferences from DataService", {
            player = player.Name,
            error = tostring(result),
        })
    end
end

-- Create replicated Settings folders (server-side only)
function UserDisplayPreferences:CreateReplicatedSettingsFolders(player, playerId)
    -- Create Settings folder if it doesn't exist
    local settingsFolder = player:FindFirstChild("Settings")
    if not settingsFolder then
        settingsFolder = Instance.new("Folder")
        settingsFolder.Name = "Settings"
        settingsFolder.Parent = player
    end

    -- Create DisplayPreferences folder if it doesn't exist
    local displayPrefsFolder = settingsFolder:FindFirstChild("DisplayPreferences")
    if not displayPrefsFolder then
        displayPrefsFolder = Instance.new("Folder")
        displayPrefsFolder.Name = "DisplayPreferences"
        displayPrefsFolder.Parent = settingsFolder
    end

    -- Create StringValue objects for each preference
    for context, method in pairs(userPreferences[playerId] or {}) do
        local valueObj = displayPrefsFolder:FindFirstChild(context)
        if not valueObj then
            valueObj = Instance.new("StringValue")
            valueObj.Name = context
            valueObj.Parent = displayPrefsFolder
        end
        valueObj.Value = method
    end

    logger:debug("Created replicated settings folders", {
        player = player.Name,
        preferences = userPreferences[playerId],
    })
end

-- Client-side preference loading (read from automatically replicated player folders)
function UserDisplayPreferences:LoadUserPreferencesClient(player, playerId)
    -- Wait for replication if needed, then read from player Settings folder
    local function readFromPlayerFolder()
        local settingsFolder = player:FindFirstChild("Settings")
        if settingsFolder then
            local displayPrefsFolder = settingsFolder:FindFirstChild("DisplayPreferences")
            if displayPrefsFolder then
                -- Override defaults with replicated preferences
                for _, child in pairs(displayPrefsFolder:GetChildren()) do
                    if
                        child:IsA("StringValue")
                        and userPreferences[playerId][child.Name] ~= nil
                    then
                        userPreferences[playerId][child.Name] = child.Value
                    end
                end

                logger:info("Loaded user preferences from replicated player folder", {
                    player = player.Name,
                    preferences = userPreferences[playerId],
                })
                return true
            end
        end
        return false
    end

    -- Try immediately first
    if not readFromPlayerFolder() then
        -- Wait for replication (server may still be creating folders)
        task.spawn(function()
            local maxWait = 5 -- seconds
            local waited = 0

            while waited < maxWait do
                if readFromPlayerFolder() then
                    return
                end
                task.wait(0.1)
                waited = waited + 0.1
            end

            logger:debug("No replicated display preferences found after waiting, using defaults", {
                player = player.Name,
                preferences = userPreferences[playerId],
            })
        end)
    end
end

-- Save user preferences to DataService (server-side) or send to server (client-side)
function UserDisplayPreferences:SaveUserPreferences(player)
    local playerId = tostring(player.UserId)

    if not userPreferences[playerId] then
        logger:warn("No preferences to save for player", { player = player.Name })
        return false
    end

    -- Different behavior for server vs client
    if game:GetService("RunService"):IsServer() then
        -- Server-side: Direct DataService access
        return self:SaveUserPreferencesServer(player, playerId)
    else
        -- Client-side: Send to server via Signals
        return self:SaveUserPreferencesClient(player, playerId)
    end
end

-- Save preferences directly to ProfileStore (single source of truth)
function UserDisplayPreferences:SavePreferencesToProfileStore(player, preferences)
    local success, result = pcall(function()
        -- Get DataService through Locations
        local Locations = require(game:GetService("ReplicatedStorage").Shared.Locations)
        local dataService = Locations.getService("DataService")

        logger:debug("Saving preferences to ProfileStore", {
            player = player.Name,
            preferences = preferences,
            hasDataService = dataService ~= nil,
        })

        if dataService then
            local playerData = dataService:GetData(player)

            if playerData then
                -- Ensure Settings exists
                if not playerData.Settings then
                    playerData.Settings = {
                        MusicEnabled = true,
                        SFXEnabled = true,
                        GraphicsQuality = "Auto",
                        DisplayPreferences = {},
                    }
                end

                -- Ensure DisplayPreferences exists
                if not playerData.Settings.DisplayPreferences then
                    playerData.Settings.DisplayPreferences = {}
                end

                -- Update ProfileStore with new preferences (SINGLE SOURCE OF TRUTH)
                for context, method in pairs(preferences) do
                    playerData.Settings.DisplayPreferences[context] = method
                end

                logger:info("Updated ProfileStore with display preferences", {
                    player = player.Name,
                    preferences = playerData.Settings.DisplayPreferences,
                })

                -- ProfileStore will handle persistence automatically
                -- Player folders will be updated by InventoryService-like pattern if needed
                return true
            else
                logger:warn("No player data available in ProfileStore", {
                    player = player.Name,
                })
                return false
            end
        else
            logger:warn("DataService not available", {
                player = player.Name,
            })
            return false
        end
    end)

    if not success then
        logger:warn("Error saving preferences to ProfileStore", {
            player = player.Name,
            error = tostring(result),
            errorType = type(result),
        })
        return false
    end

    return result
end

-- Update replicated Settings folders (server-side only)
function UserDisplayPreferences:UpdateReplicatedSettingsFolders(player, playerId)
    local settingsFolder = player:FindFirstChild("Settings")
    if not settingsFolder then
        -- Create folders if they don't exist
        self:CreateReplicatedSettingsFolders(player, playerId)
        return
    end

    local displayPrefsFolder = settingsFolder:FindFirstChild("DisplayPreferences")
    if not displayPrefsFolder then
        -- Create folders if they don't exist
        self:CreateReplicatedSettingsFolders(player, playerId)
        return
    end

    -- Update existing StringValue objects
    for context, method in pairs(userPreferences[playerId] or {}) do
        local valueObj = displayPrefsFolder:FindFirstChild(context)
        if not valueObj then
            valueObj = Instance.new("StringValue")
            valueObj.Name = context
            valueObj.Parent = displayPrefsFolder
        end
        valueObj.Value = method
    end

    logger:debug("Updated replicated settings folders", {
        player = player.Name,
        preferences = userPreferences[playerId],
    })
end

-- Client-side preference saving (send to server via Signals)
function UserDisplayPreferences:SaveUserPreferencesClient(player, playerId)
    local success, result = pcall(function()
        -- Get Signals for communication
        local Locations = require(game:GetService("ReplicatedStorage").Shared.Locations)
        local Signals = require(ReplicatedStorage.Shared.Network.Signals)

        -- Send preferences to server for saving
        if Signals.SaveDisplayPreferences then
            Signals.SaveDisplayPreferences:FireServer({
                preferences = userPreferences[playerId],
            })

            logger:info("Sent user preferences to server for saving", {
                player = player.Name,
                preferences = userPreferences[playerId],
            })
            return true
        else
            logger:warn("SaveDisplayPreferences signal not available", {
                player = player.Name,
            })
            return false
        end
    end)

    if not success then
        logger:warn("Error sending user preferences to server", {
            player = player.Name,
            error = tostring(result),
        })
        return false
    end

    return result
end

-- Performance monitoring functions
function UserDisplayPreferences:StartPerformanceMonitoring(player, context)
    local autoPerf = uiDisplayConfig.user_preferences.auto_performance
    if not autoPerf.enabled then
        return
    end

    local playerId = tostring(player.UserId)
    local monitorKey = playerId .. "_" .. context

    -- Clear existing monitoring
    if performanceMonitoring[monitorKey] then
        performanceMonitoring[monitorKey]:Disconnect()
    end

    local startTime = tick()
    local fpsSamples = {}

    performanceMonitoring[monitorKey] = RunService.Heartbeat:Connect(function()
        local currentTime = tick()
        local deltaTime = currentTime
            - (fpsSamples[#fpsSamples] and fpsSamples[#fpsSamples].time or startTime)

        if deltaTime > 0 then
            local fps = 1 / deltaTime
            table.insert(fpsSamples, { time = currentTime, fps = fps })

            -- Keep only recent samples
            while #fpsSamples > 100 do
                table.remove(fpsSamples, 1)
            end

            -- Check if monitoring duration exceeded
            if currentTime - startTime > autoPerf.monitor_duration then
                -- Calculate average FPS
                local totalFps = 0
                for _, sample in ipairs(fpsSamples) do
                    totalFps = totalFps + sample.fps
                end
                local avgFps = totalFps / #fpsSamples

                if avgFps < autoPerf.force_images_below_fps then
                    -- Force images due to low FPS
                    self:SetUserPreference(player, context, "images")

                    logger:warn("Automatically switched to images due to low FPS", {
                        player = player.Name,
                        context = context,
                        averageFps = avgFps,
                        threshold = autoPerf.force_images_below_fps,
                    })
                end

                -- Stop monitoring
                performanceMonitoring[monitorKey]:Disconnect()
                performanceMonitoring[monitorKey] = nil
            end
        end
    end)
end

function UserDisplayPreferences:ShouldForceImagesForPerformance(player, context, userPref)
    if userPref ~= "viewports" then
        return false
    end

    local autoPerf = uiDisplayConfig.user_preferences.auto_performance
    if not autoPerf.enabled then
        return false
    end

    -- Additional performance checks could go here
    -- For now, rely on the monitoring system

    return false
end

-- Get available contexts that user can control
function UserDisplayPreferences:GetUserControllableContexts()
    -- Auto-initialize if not already done
    if not uiDisplayConfig then
        self:Initialize()
    end

    local controllable = {}

    -- Safety check
    if not uiDisplayConfig or not uiDisplayConfig.user_preferences then
        logger:warn("UI display configuration not available")
        return controllable
    end

    for context, allowed in pairs(uiDisplayConfig.user_preferences.allow_user_control) do
        if allowed and uiDisplayConfig[context] == "user" then
            table.insert(controllable, context)
        end
    end

    return controllable
end

-- Get performance warning text
function UserDisplayPreferences:GetPerformanceWarning()
    -- Auto-initialize if not already done
    if not uiDisplayConfig then
        self:Initialize()
    end

    -- Safety check
    if not uiDisplayConfig or not uiDisplayConfig.user_preferences then
        return nil
    end

    local warnings = uiDisplayConfig.user_preferences.performance_warnings
    if not warnings or not warnings.enabled then
        return nil
    end

    return warnings.viewport_warning
end

-- Cleanup
function UserDisplayPreferences:Destroy()
    -- Disconnect all performance monitoring
    for monitorKey, connection in pairs(performanceMonitoring) do
        connection:Disconnect()
    end
    performanceMonitoring = {}

    -- Clear caches
    userPreferences = {}
    petConfig = nil
    uiDisplayConfig = nil

    logger:info("UserDisplayPreferences destroyed")
end

return UserDisplayPreferences
