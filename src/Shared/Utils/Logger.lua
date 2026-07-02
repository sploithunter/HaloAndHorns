--[[
    Logger - Centralized logging system for debugging and monitoring
    
    Features:
    - Multiple log levels (Debug, Info, Warn, Error)
    - Structured logging with context
    - Performance tracking
    - Remote logging capability
    
    Usage:
    local Logger = require(ReplicatedStorage.Shared.Utils.Logger)
    Logger:Info("Player joined", {playerId = player.UserId})
    Logger:Error("Failed to load data", {error = err, playerId = player.UserId})
]]

local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local Logger = {}
Logger.__index = Logger

-- Log levels
local LogLevel = {
    DEBUG = 1,
    INFO = 2,
    WARN = 3,
    ERROR = 4,
}

local LogLevelNames = {
    [LogLevel.DEBUG] = "DEBUG",
    [LogLevel.INFO] = "INFO",
    [LogLevel.WARN] = "WARN",
    [LogLevel.ERROR] = "ERROR",
}

-- Default configuration (will be updated from logging config)
local Config = {
    MinLogLevel = LogLevel.INFO,
    EnableRemoteLogging = false,
    MaxLogHistory = 100,
    ConsoleOutput = true,
    EnablePerformanceLogs = false,
    ServiceLogLevels = {}, -- Per-service log levels
}

-- Internal state
local LogHistory = {}
local StartTime = tick()

-- Color codes for output
local Colors = {
    [LogLevel.DEBUG] = "\27[36m", -- Cyan
    [LogLevel.INFO] = "\27[32m", -- Green
    [LogLevel.WARN] = "\27[33m", -- Yellow
    [LogLevel.ERROR] = "\27[31m", -- Red
}
local ColorReset = "\27[0m"

function Logger:Init()
    -- Load logging configuration
    self:LoadLoggingConfig()

    -- Initialize logger
    self:Info("Logger initialized", {
        minLogLevel = LogLevelNames[Config.MinLogLevel],
        consoleOutput = Config.ConsoleOutput,
        performanceLogs = Config.EnablePerformanceLogs,
        serviceLogLevels = #Config.ServiceLogLevels > 0 and "configured" or "default",
        isStudio = RunService:IsStudio(),
        isServer = RunService:IsServer(),
    })
end

-- Load logging configuration from configs/logging.lua
function Logger:LoadLoggingConfig()
    local success, loggingConfig = pcall(function()
        local ReplicatedStorage = game:GetService("ReplicatedStorage")
        local Configs = ReplicatedStorage:WaitForChild("Configs", 5)
        if Configs and Configs:FindFirstChild("logging") then
            return require(Configs.logging)
        end
        return nil
    end)

    if success and loggingConfig then
        -- Apply global settings
        if loggingConfig.global then
            local global = loggingConfig.global

            if global.default_level then
                Config.MinLogLevel = self:_stringToLogLevel(global.default_level)
            end

            if global.console_output ~= nil then
                Config.ConsoleOutput = global.console_output
            end

            if global.enable_performance_logs ~= nil then
                Config.EnablePerformanceLogs = global.enable_performance_logs
            end

            if global.max_log_history then
                Config.MaxLogHistory = global.max_log_history
            end

            if global.enable_remote_logging ~= nil then
                Config.EnableRemoteLogging = global.enable_remote_logging
            end
        end

        -- Apply service-specific log levels
        if loggingConfig.services then
            for serviceName, levelString in pairs(loggingConfig.services) do
                Config.ServiceLogLevels[serviceName] = self:_stringToLogLevel(levelString)
            end
        end

        -- Use logger output instead of raw print to respect log levels
        self:Info("[Logger] Loaded logging configuration", {
            context = "Logger",
            serviceSpecificLevels = (table.getn and #Config.ServiceLogLevels) or 0,
        })
    else
        self:Warn("[Logger] No logging configuration found, using defaults", { context = "Logger" })
    end
end

-- Convert string log level to LogLevel constant
function Logger:_stringToLogLevel(levelString)
    if not levelString then
        return LogLevel.INFO
    end

    local level = string.upper(levelString)
    if level == "DEBUG" then
        return LogLevel.DEBUG
    elseif level == "INFO" then
        return LogLevel.INFO
    elseif level == "WARN" or level == "WARNING" then
        return LogLevel.WARN
    elseif level == "ERROR" then
        return LogLevel.ERROR
    elseif level == "DISABLED" or level == "OFF" then
        return LogLevel.ERROR + 1 -- Higher than any real level = disabled
    else
        return LogLevel.INFO
    end
end

-- Get effective log level for a service (checks service-specific config)
function Logger:_getEffectiveLogLevel(context)
    if not context or type(context) ~= "table" or not context.context then
        return Config.MinLogLevel
    end

    local serviceName = context.context
    local serviceLevel = Config.ServiceLogLevels[serviceName]

    if serviceLevel then
        return serviceLevel
    else
        return Config.MinLogLevel
    end
end

function Logger:SetLogLevel(level)
    Config.MinLogLevel = level
    self:Info("Log level changed", { newLevel = LogLevelNames[level] })
end

function Logger:_log(level, message, context)
    -- Check if this log should be filtered based on service-specific levels
    local effectiveLogLevel = self:_getEffectiveLogLevel(context)
    if level < effectiveLogLevel then
        return
    end

    -- Skip console output if disabled
    if not Config.ConsoleOutput then
        return
    end

    local timestamp = tick() - StartTime
    local levelName = LogLevelNames[level]
    local contextStr = ""

    if context and type(context) == "table" then
        contextStr = " " .. HttpService:JSONEncode(context)
    end

    local logEntry = {
        timestamp = timestamp,
        level = level,
        levelName = levelName,
        message = message,
        context = context,
    }

    -- Add to history
    table.insert(LogHistory, logEntry)
    if #LogHistory > Config.MaxLogHistory then
        table.remove(LogHistory, 1)
    end

    -- Format output
    local output = string.format(
        "%s[%.3f] [%s] %s%s%s",
        Colors[level] or "",
        timestamp,
        levelName,
        message,
        contextStr,
        ColorReset
    )

    if level >= LogLevel.ERROR then
        warn(output)
    else
        print(output)
    end

    -- Remote logging (if enabled)
    if Config.EnableRemoteLogging and RunService:IsServer() then
        self:_sendRemoteLog(logEntry)
    end
end

function Logger:Debug(message, context)
    self:_log(LogLevel.DEBUG, message, context)
end

function Logger:Info(message, context)
    self:_log(LogLevel.INFO, message, context)
end

function Logger:Warn(message, context)
    self:_log(LogLevel.WARN, message, context)
end

function Logger:Error(message, context)
    self:_log(LogLevel.ERROR, message, context)
end

function Logger:Performance(name, func, ...)
    local startTime = tick()
    local results = { func(...) }
    local endTime = tick()
    local duration = endTime - startTime

    -- Only log performance if enabled in config
    if Config.EnablePerformanceLogs then
        self:Debug("Performance measurement", {
            operation = name,
            duration = duration,
            durationMs = duration * 1000,
        })
    end

    return unpack(results)
end

function Logger:StartTimer(name)
    return {
        name = name,
        startTime = tick(),
    }
end

function Logger:EndTimer(timer)
    local duration = tick() - timer.startTime

    -- Only log timer if performance logging is enabled
    if Config.EnablePerformanceLogs then
        self:Debug("Timer completed", {
            name = timer.name,
            duration = duration,
            durationMs = duration * 1000,
        })
    end

    return duration
end

function Logger:GetHistory()
    return LogHistory
end

function Logger:ClearHistory()
    LogHistory = {}
    self:Info("Log history cleared")
end

-- Set log level for a specific service at runtime
function Logger:SetServiceLogLevel(serviceName, levelString)
    local level = self:_stringToLogLevel(levelString)
    Config.ServiceLogLevels[serviceName] = level

    self:Info("Service log level changed", {
        service = serviceName,
        newLevel = LogLevelNames[level] or "DISABLED",
    })
end

-- Get current log level for a service
function Logger:GetServiceLogLevel(serviceName)
    local level = Config.ServiceLogLevels[serviceName] or Config.MinLogLevel
    return LogLevelNames[level] or "DISABLED"
end

-- Enable/disable console output at runtime
function Logger:SetConsoleOutput(enabled)
    Config.ConsoleOutput = enabled
    if enabled then
        self:Info("Console output enabled")
    end
end

-- Enable/disable performance logging at runtime
function Logger:SetPerformanceLogging(enabled)
    Config.EnablePerformanceLogs = enabled
    self:Info("Performance logging " .. (enabled and "enabled" or "disabled"))
end

-- Get current logging configuration for debugging
function Logger:GetConfig()
    local serviceCount = 0
    for _ in pairs(Config.ServiceLogLevels) do
        serviceCount = serviceCount + 1
    end

    return {
        defaultLevel = LogLevelNames[Config.MinLogLevel],
        consoleOutput = Config.ConsoleOutput,
        performanceLogs = Config.EnablePerformanceLogs,
        remoteLogging = Config.EnableRemoteLogging,
        maxHistory = Config.MaxLogHistory,
        serviceSpecificLevels = serviceCount,
    }
end

function Logger:_sendRemoteLog(logEntry)
    -- TODO: Implement remote logging to external service
    -- This could send logs to Discord webhooks, external APIs, etc.
end

-- Engine console errors we do NOT mirror into structured Logger output. Crucially this
-- includes asset-access failures: the engine already prints those with a clickable
-- "Click to share access" affordance — re-emitting them as plain Logger lines strips the
-- link (so you can't grant access) and buries the originals. Plain-text matches.
local SUPPRESSED_CONSOLE_ERROR_PATTERNS = {
    "Failed to load animation",
    "Failed to load sound",
    "MeshContentProvider failed",
    "Failed to parse batch json response",
    "Unable to load plugin icon",
    -- Asset ownership / access (keep the native clickable message, drop the duplicate)
    "access permission to use asset",
    "is not authorized to access Asset",
    "not authorized to access",
    "Click to share access",
}

function Logger.isSuppressedConsoleError(message)
    if type(message) ~= "string" then
        return false
    end
    for _, pattern in ipairs(SUPPRESSED_CONSOLE_ERROR_PATTERNS) do
        if string.find(message, pattern, 1, true) then
            return true
        end
    end
    return false
end

-- Global error handler
local function globalErrorHandler(message, trace)
    Logger:Error("Uncaught error", {
        message = message,
        trace = trace,
        timestamp = tick(),
    })
end

-- Set up global error handling
if not _G.__LOGGER_ERROR_HANDLER_SET then
    _G.__LOGGER_ERROR_HANDLER_SET = true
    local LogService = game:GetService("LogService")
    if LogService then
        LogService.MessageOut:Connect(function(message, messageType)
            if messageType == Enum.MessageType.MessageError then
                if Logger.isSuppressedConsoleError(message) then
                    return -- leave the native (clickable) message; don't duplicate it
                end
                globalErrorHandler(message)
            end
        end)
    end
end

return Logger
