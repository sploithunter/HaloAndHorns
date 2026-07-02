--[[
    GlobalEffectsService - Manages server-wide effects using native Roblox folder structure
    
    Simple, reliable architecture:
    - Uses Workspace/GlobalEffects as source of truth
    - Workspace/GlobalAggregates for calculated totals
    - Configuration-driven display and logic
    - Real-time updates via Changed events for all clients
    - Server-authoritative clock for accurate timing
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Logger = require(game.ReplicatedStorage.Shared.Utils.Logger)

local GlobalEffectsService = {}
GlobalEffectsService.__index = GlobalEffectsService

-- Module dependencies (injected)
local _configLoader = nil
local _dataService = nil
local _serverClock = nil

-- Global aggregate totals cache for fast lookups
local globalAggregates = {} -- globalAggregates[statName] = totalValue

function GlobalEffectsService:Init()
    -- Debug: Check if _modules was injected
    if not self._modules then
        error(
            "GlobalEffectsService: self._modules is nil - ModuleLoader dependency injection failed"
        )
    end

    -- Get dependencies with validation (matches other services pattern)
    self._logger = self._modules.Logger
    self._configLoader = self._modules.ConfigLoader
    self._dataService = self._modules.DataService
    self._serverClock = self._modules.ServerClockService

    -- Validate critical dependencies
    if not self._configLoader then
        error(
            "GlobalEffectsService: ConfigLoader dependency missing - check ModuleLoader configuration"
        )
    end

    if not self._dataService then
        error(
            "GlobalEffectsService: DataService dependency missing - check ModuleLoader configuration"
        )
    end

    if not self._serverClock then
        error(
            "GlobalEffectsService: ServerClockService dependency missing - check ModuleLoader configuration"
        )
    end

    -- Load configuration
    self._rateLimitConfig = self._configLoader:LoadConfig("ratelimits")

    -- Set up global effects structure
    self:_setupGlobalStructure()
    self:_setupGlobalAggregates()

    -- Start global effect expiration loop
    self:_startGlobalEffectExpirationLoop()

    self._logger:Info("GlobalEffectsService initialized")
end

-- Create the folder structure for global effects
function GlobalEffectsService:_setupGlobalStructure()
    local globalEffects = Workspace:FindFirstChild("GlobalEffects")
    if not globalEffects then
        globalEffects = Instance.new("Folder")
        globalEffects.Name = "GlobalEffects"
        globalEffects.Parent = Workspace
    end

    self._logger:Debug("Global effects structure created")
end

-- Create the global aggregates folder
function GlobalEffectsService:_setupGlobalAggregates()
    local globalAggregatesFolder = Workspace:FindFirstChild("GlobalAggregates")
    if not globalAggregatesFolder then
        globalAggregatesFolder = Instance.new("Folder")
        globalAggregatesFolder.Name = "GlobalAggregates"
        globalAggregatesFolder.Parent = Workspace
    end

    -- Initialize common global stat NumberValues (can be extended via config)
    local commonGlobalStats = {
        globalSpeedMultiplier = 1.0, -- Multiplicative: 1.0 = normal speed
        globalLuckBoost = 0, -- Additive: 0 = no bonus luck
        globalXPMultiplier = 1.0, -- Multiplicative: 1.0 = normal XP
        globalDropRateBoost = 0, -- Additive: 0 = no drop rate bonus
        globalDamageMultiplier = 1.0, -- Multiplicative: 1.0 = normal damage
        globalDefenseMultiplier = 1.0, -- Multiplicative: 1.0 = normal defense
    }

    for statName, baseValue in pairs(commonGlobalStats) do
        local statValue = globalAggregatesFolder:FindFirstChild(statName)
        if not statValue then
            statValue = Instance.new("NumberValue")
            statValue.Name = statName
            statValue.Value = baseValue
            statValue.Parent = globalAggregatesFolder
        end
        globalAggregates[statName] = baseValue
    end

    self._logger:Debug("Global aggregates structure created", { stats = 6 })
end

-- Apply stat modifiers from a global effect
function GlobalEffectsService:_applyGlobalStatModifiers(effectConfig, sign)
    if not effectConfig.statModifiers then
        return
    end

    local globalAggregatesFolder = Workspace:FindFirstChild("GlobalAggregates")

    if not globalAggregatesFolder then
        self._logger:Warn("GlobalAggregates folder not found")
        return
    end

    for statName, delta in pairs(effectConfig.statModifiers) do
        -- Get current value (with proper base value fallback)
        local baseStats = {
            globalSpeedMultiplier = 1.0,
            globalDamageMultiplier = 1.0,
            globalDefenseMultiplier = 1.0,
            globalXPMultiplier = 1.0,
            globalLuckBoost = 0,
            globalDropRateBoost = 0,
        }
        local baseValue = baseStats[statName] or 0
        local currentValue = globalAggregates[statName] or baseValue

        -- Update cached total (additive for all stats - effects are bonuses)
        globalAggregates[statName] = currentValue + (sign * delta)

        -- Update NumberValue for instant access
        local statValue = globalAggregatesFolder:FindFirstChild(statName)
        if statValue then
            statValue.Value = globalAggregates[statName]
        else
            -- Create new stat on demand with current value
            statValue = Instance.new("NumberValue")
            statValue.Name = statName
            statValue.Value = globalAggregates[statName]
            statValue.Parent = globalAggregatesFolder
        end
    end

    self._logger:Debug("Global stat modifiers applied", {
        modifiers = effectConfig.statModifiers,
        sign = sign,
        newTotals = globalAggregates,
    })
end

-- Apply a global effect (affects all players)
function GlobalEffectsService:ApplyGlobalEffect(effectId, duration, reason)
    local effectConfig = self._rateLimitConfig.effectModifiers[effectId]
    if not effectConfig then
        self._logger:Warn("Unknown global effect", { effectId = effectId })
        return false
    end

    local globalEffects = Workspace:FindFirstChild("GlobalEffects")
    if not globalEffects then
        self:_setupGlobalStructure()
        globalEffects = Workspace:FindFirstChild("GlobalEffects")
    end

    -- Check if effect already exists
    local existingEffect = globalEffects:FindFirstChild(effectId)
    if existingEffect then
        local currentTimeRemaining = existingEffect:FindFirstChild("timeRemaining")
        local sessionStartTime = existingEffect:FindFirstChild("sessionStartTime")

        if effectConfig.stacking == "extend_duration" then
            -- Extend the duration by adding to current time remaining
            if currentTimeRemaining and sessionStartTime then
                currentTimeRemaining.Value = currentTimeRemaining.Value + duration
                sessionStartTime.Value = self._serverClock:GetServerTime()

                self._logger:Info("Global effect duration extended", {
                    effectId = effectId,
                    newDuration = currentTimeRemaining.Value,
                    reason = reason or "Manual trigger",
                })
                return true
            end
        else
            -- Default: reset the effect
            existingEffect:Destroy()
        end
    end

    -- Create new effect folder
    local effectFolder = Instance.new("Folder")
    effectFolder.Name = effectId
    effectFolder.Parent = globalEffects

    -- Create effect values
    local timeRemaining = Instance.new("IntValue")
    timeRemaining.Name = "timeRemaining"
    timeRemaining.Value = duration
    timeRemaining.Parent = effectFolder

    -- Store session start time for calculating elapsed time
    local sessionStartTime = Instance.new("IntValue")
    sessionStartTime.Name = "sessionStartTime"
    sessionStartTime.Value = self._serverClock:GetServerTime()
    sessionStartTime.Parent = effectFolder

    local multiplier = Instance.new("NumberValue")
    multiplier.Name = "multiplier"
    multiplier.Value = effectConfig.multiplier or 1.0
    multiplier.Parent = effectFolder

    local description = Instance.new("StringValue")
    description.Name = "description"
    description.Value = effectConfig.description or "Global effect active"
    description.Parent = effectFolder

    local displayName = Instance.new("StringValue")
    displayName.Name = "displayName"
    displayName.Value = effectConfig.displayName or effectId
    displayName.Parent = effectFolder

    local icon = Instance.new("StringValue")
    icon.Name = "icon"
    icon.Value = effectConfig.icon or "🌟"
    icon.Parent = effectFolder

    local reasonValue = Instance.new("StringValue")
    reasonValue.Name = "reason"
    reasonValue.Value = reason or "Server event"
    reasonValue.Parent = effectFolder

    -- Apply global stat modifiers
    self:_applyGlobalStatModifiers(effectConfig, 1)

    self._logger:Info("Global effect applied", {
        effectId = effectId,
        duration = duration,
        description = effectConfig.description,
        reason = reason or "Server event",
    })

    return true
end

-- Remove a global effect
function GlobalEffectsService:RemoveGlobalEffect(effectId)
    -- Get effect config before removal for stat modifier cleanup
    local effectConfig = self._rateLimitConfig.effectModifiers[effectId]

    local globalEffects = Workspace:FindFirstChild("GlobalEffects")
    if not globalEffects then
        return false
    end

    local effectFolder = globalEffects:FindFirstChild(effectId)
    if effectFolder then
        -- Remove stat modifiers before destroying folder
        if effectConfig then
            self:_applyGlobalStatModifiers(effectConfig, -1)
        end

        effectFolder:Destroy()

        self._logger:Info("Global effect removed", { effectId = effectId })
        return true
    end

    return false
end

-- Clear all global effects
function GlobalEffectsService:ClearAllGlobalEffects()
    local globalEffects = Workspace:FindFirstChild("GlobalEffects")
    if not globalEffects then
        return 0
    end

    local effectsCleared = 0
    for _, effectFolder in ipairs(globalEffects:GetChildren()) do
        if effectFolder:IsA("Folder") then
            local effectId = effectFolder.Name
            local effectConfig = self._rateLimitConfig.effectModifiers[effectId]

            -- Remove stat modifiers
            if effectConfig then
                self:_applyGlobalStatModifiers(effectConfig, -1)
            end

            effectFolder:Destroy()
            effectsCleared = effectsCleared + 1
        end
    end

    self._logger:Info("All global effects cleared", {
        effectsCleared = effectsCleared,
    })

    return effectsCleared
end

-- Get active global effects
function GlobalEffectsService:GetActiveGlobalEffects()
    local globalEffects = Workspace:FindFirstChild("GlobalEffects")
    if not globalEffects then
        return {}
    end

    local activeEffects = {}

    for _, effectFolder in ipairs(globalEffects:GetChildren()) do
        if effectFolder:IsA("Folder") then
            local multiplier = effectFolder:FindFirstChild("multiplier")
            local timeRemaining = effectFolder:FindFirstChild("timeRemaining")
            local description = effectFolder:FindFirstChild("description")
            local displayName = effectFolder:FindFirstChild("displayName")
            local icon = effectFolder:FindFirstChild("icon")
            local reason = effectFolder:FindFirstChild("reason")

            if timeRemaining and (timeRemaining.Value == -1 or timeRemaining.Value > 0) then
                activeEffects[effectFolder.Name] = {
                    multiplier = multiplier and multiplier.Value or 1.0,
                    timeRemaining = timeRemaining.Value,
                    description = description and description.Value or "Global effect",
                    displayName = displayName and displayName.Value or effectFolder.Name,
                    icon = icon and icon.Value or "🌟",
                    reason = reason and reason.Value or "Server event",
                }
            end
        end
    end

    return activeEffects
end

-- Get global aggregate value for a specific stat
function GlobalEffectsService:GetGlobalAggregate(statName)
    return globalAggregates[statName] or 0
end

-- Get all global aggregates
function GlobalEffectsService:GetAllGlobalAggregates()
    return globalAggregates
end

-- Recalculate all global aggregate values from active effects
function GlobalEffectsService:_recalculateGlobalAggregates()
    local globalEffects = Workspace:FindFirstChild("GlobalEffects")
    local globalAggregatesFolder = Workspace:FindFirstChild("GlobalAggregates")

    if not globalEffects or not globalAggregatesFolder then
        return
    end

    -- Reset all totals to base values
    local baseStats = {
        globalSpeedMultiplier = 1.0,
        globalDamageMultiplier = 1.0,
        globalDefenseMultiplier = 1.0,
        globalXPMultiplier = 1.0,
        globalLuckBoost = 0,
        globalDropRateBoost = 0,
    }

    for statName, _ in pairs(globalAggregates) do
        globalAggregates[statName] = baseStats[statName] or 0
    end

    -- Sum up stat modifiers from all active effects
    for _, effectFolder in ipairs(globalEffects:GetChildren()) do
        if effectFolder:IsA("Folder") then
            local effectId = effectFolder.Name
            local effectConfig = self._rateLimitConfig.effectModifiers[effectId]

            if effectConfig and effectConfig.statModifiers then
                for statName, delta in pairs(effectConfig.statModifiers) do
                    local baseValue = baseStats[statName] or 0
                    globalAggregates[statName] = (globalAggregates[statName] or baseValue) + delta
                end
            end
        end
    end

    -- Update NumberValues to match calculated totals
    for statName, total in pairs(globalAggregates) do
        local statValue = globalAggregatesFolder:FindFirstChild(statName)
        if statValue then
            statValue.Value = total
        end
    end

    self._logger:Debug("Recalculated global aggregates", {
        totals = globalAggregates,
    })
end

-- Global effect expiration loop
function GlobalEffectsService:_startGlobalEffectExpirationLoop()
    RunService.Heartbeat:Connect(function()
        local currentTime = self._serverClock:GetServerTime()

        local globalEffects = Workspace:FindFirstChild("GlobalEffects")
        if globalEffects then
            for _, effectFolder in ipairs(globalEffects:GetChildren()) do
                if effectFolder:IsA("Folder") then
                    local timeRemaining = effectFolder:FindFirstChild("timeRemaining")
                    local sessionStartTime = effectFolder:FindFirstChild("sessionStartTime")

                    if timeRemaining and sessionStartTime then
                        if timeRemaining.Value == -1 then
                            -- Permanent effect, no countdown needed
                        else
                            -- Calculate elapsed time since session started
                            local elapsedTime = currentTime - sessionStartTime.Value
                            local newTimeRemaining =
                                math.max(0, timeRemaining.Value - math.floor(elapsedTime))

                            if newTimeRemaining <= 0 then
                                -- Effect expired
                                self:RemoveGlobalEffect(effectFolder.Name)
                            else
                                -- Update remaining time
                                timeRemaining.Value = newTimeRemaining
                                sessionStartTime.Value = currentTime
                            end
                        end
                    end
                end
            end
        end
    end)
end

return GlobalEffectsService
