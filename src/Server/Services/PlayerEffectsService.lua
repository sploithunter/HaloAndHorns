--[[
    PlayerEffectsService - Manages player effects using native Roblox folder structure
    
    Simple, reliable architecture:
    - No network calls (uses built-in replication)
    - Player/TimedBoosts/effect_name/values structure
    - Configuration-driven display and logic
    - Real-time updates via Changed events
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Logger = require(game.ReplicatedStorage.Shared.Utils.Logger)

local PlayerEffectsService = {}
PlayerEffectsService.__index = PlayerEffectsService

-- Module dependencies (injected)
local _configLoader = nil
local _dataService = nil
local _serverClock = nil

-- Aggregate totals cache for fast lookups
local aggregateTotals = {} -- aggregateTotals[userId][statName] = totalValue

function PlayerEffectsService:Init()
    -- Debug: Check if _modules was injected
    if not self._modules then
        error(
            "PlayerEffectsService: self._modules is nil - ModuleLoader dependency injection failed"
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
            "PlayerEffectsService: ConfigLoader dependency missing - check ModuleLoader configuration"
        )
    end

    if not self._dataService then
        error(
            "PlayerEffectsService: DataService dependency missing - check ModuleLoader configuration"
        )
    end

    if not self._serverClock then
        error(
            "PlayerEffectsService: ServerClockService dependency missing - check ModuleLoader configuration"
        )
    end

    -- Load configuration
    self._rateLimitConfig = self._configLoader:LoadConfig("ratelimits")

    -- Set up player connections
    Players.PlayerAdded:Connect(function(player)
        self:_setupPlayerStructure(player)
        self:_setupPlayerAggregates(player)
    end)

    Players.PlayerRemoving:Connect(function(player)
        self:_cleanupPlayer(player)
    end)

    -- Start effect expiration loop
    self:_startEffectExpirationLoop()

    self._logger:Info("PlayerEffectsService initialized")
end

-- Create the folder structure for a player
function PlayerEffectsService:_setupPlayerStructure(player)
    local timedBoosts = Instance.new("Folder")
    timedBoosts.Name = "TimedBoosts"
    timedBoosts.Parent = player

    self._logger:Debug("Player effects structure created", { player = player.Name })
end

-- Create the aggregates folder for a player
function PlayerEffectsService:_setupPlayerAggregates(player)
    local aggregates = Instance.new("Folder")
    aggregates.Name = "Aggregates"
    aggregates.Parent = player

    -- Initialize aggregate totals cache
    local userId = player.UserId
    aggregateTotals[userId] = {}

    -- Create common stat NumberValues (can be extended via config)
    -- Note: Multiplier stats (like speedMultiplier) start at 1.0, additive stats start at 0
    local baseStats = {
        speedMultiplier = 1.0, -- Multiplicative: 1.0 = normal speed, 1.5 = +50% speed
        luckBoost = 0, -- Additive: 0 = no bonus luck
        rareLuckBoost = 0, -- Additive: 0 = no rare luck bonus
        ultraLuckBoost = 0, -- Additive: 0 = no ultra luck bonus
        damageBoost = 1.0, -- Multiplicative: 1.0 = normal damage
        defenseBoost = 1.0, -- Multiplicative: 1.0 = normal defense
    }

    for statName, baseValue in pairs(baseStats) do
        local statValue = Instance.new("NumberValue")
        statValue.Name = statName
        statValue.Value = baseValue
        statValue.Parent = aggregates
        aggregateTotals[userId][statName] = baseValue
    end

    self._logger:Debug("Player aggregates structure created", { player = player.Name, stats = 6 })
end

-- Apply stat modifiers from an effect
function PlayerEffectsService:_applyStatModifiers(player, effectConfig, sign)
    if not effectConfig.statModifiers then
        return
    end

    local userId = player.UserId
    local aggregates = player:FindFirstChild("Aggregates")

    if not aggregates or not aggregateTotals[userId] then
        self._logger:Warn("Aggregates not found for player", { player = player.Name })
        return
    end

    for statName, delta in pairs(effectConfig.statModifiers) do
        -- Get current value (with proper base value fallback)
        local baseStats = {
            speedMultiplier = 1.0,
            damageBoost = 1.0,
            defenseBoost = 1.0,
            luckBoost = 0,
            rareLuckBoost = 0,
            ultraLuckBoost = 0,
        }
        local baseValue = baseStats[statName] or 0
        local currentValue = aggregateTotals[userId][statName] or baseValue

        -- Update cached total (additive for all stats - effects are bonuses)
        aggregateTotals[userId][statName] = currentValue + (sign * delta)

        -- Update NumberValue for instant access
        local statValue = aggregates:FindFirstChild(statName)
        if statValue then
            statValue.Value = aggregateTotals[userId][statName]
        else
            -- Create new stat on demand with current value
            statValue = Instance.new("NumberValue")
            statValue.Name = statName
            statValue.Value = aggregateTotals[userId][statName]
            statValue.Parent = aggregates
        end
    end

    self._logger:Debug("Stat modifiers applied", {
        player = player.Name,
        modifiers = effectConfig.statModifiers,
        sign = sign,
        newTotals = aggregateTotals[userId],
    })
end

-- Apply an effect to a player
function PlayerEffectsService:ApplyEffect(player, effectId, duration, customEffectConfig)
    -- Use custom config if provided, otherwise get from rate limit config
    local effectConfig = customEffectConfig or self._rateLimitConfig.effectModifiers[effectId]
    if not effectConfig then
        self._logger:Warn("Unknown effect", { player = player.Name, effectId = effectId })
        return false
    end

    local timedBoosts = player:FindFirstChild("TimedBoosts")
    if not timedBoosts then
        self:_setupPlayerStructure(player)
        timedBoosts = player:FindFirstChild("TimedBoosts")
    end

    -- Check if effect already exists
    local existingEffect = timedBoosts:FindFirstChild(effectId)
    if existingEffect then
        local currentTimeRemaining = existingEffect:FindFirstChild("timeRemaining")
        local sessionStartTime = existingEffect:FindFirstChild("sessionStartTime")
        self._logger:Debug(
            "Existing effect stacking",
            { player = player.Name, effectId = effectId, stacking = effectConfig.stacking }
        )

        if effectConfig.stacking == "extend_duration" then
            -- Add duration to remaining time
            if currentTimeRemaining then
                currentTimeRemaining.Value = currentTimeRemaining.Value + duration
            end
            if sessionStartTime then
                sessionStartTime.Value = self._serverClock:GetServerTime()
            end
            self._logger:Info("Effect duration extended (stacking add)", {
                player = player.Name,
                effectId = effectId,
                addedDuration = duration,
                newRemaining = currentTimeRemaining and currentTimeRemaining.Value or duration,
            })
            -- Note: Don't apply stat modifiers again since effect already exists
            return true
        end

        -- Default behavior: reset timer only if new duration longer
        if currentTimeRemaining and currentTimeRemaining.Value > duration then
            self._logger:Info("Effect not applied - existing effect has longer duration", {
                player = player.Name,
                effectId = effectId,
                existingRemaining = currentTimeRemaining.Value,
                newDuration = duration,
            })
            return false
        end

        -- Reset remaining time to new duration
        if currentTimeRemaining then
            currentTimeRemaining.Value = duration
        end
        if sessionStartTime then
            sessionStartTime.Value = self._serverClock:GetServerTime()
        end
        self._logger:Info("Effect duration reset", {
            player = player.Name,
            effectId = effectId,
            newDuration = duration,
        })
        return true
    end

    -- Create new effect folder
    local effectFolder = Instance.new("Folder")
    effectFolder.Name = effectId
    effectFolder.Parent = timedBoosts

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
    description.Value = effectConfig.description or "Effect active"
    description.Parent = effectFolder

    local displayName = Instance.new("StringValue")
    displayName.Name = "displayName"
    displayName.Value = effectConfig.displayName or effectId
    displayName.Parent = effectFolder

    local icon = Instance.new("StringValue")
    icon.Name = "icon"
    icon.Value = effectConfig.icon or "✨"
    icon.Parent = effectFolder

    local usesRemaining = Instance.new("IntValue")
    usesRemaining.Name = "usesRemaining"
    usesRemaining.Value = effectConfig.maxUses or -1
    usesRemaining.Parent = effectFolder

    -- Apply stat modifiers
    self:_applyStatModifiers(player, effectConfig, 1)

    -- Save to ProfileStore for persistence (timeRemaining, not expiresAt)
    self:_saveEffectToProfile(player, effectId, duration, effectConfig)

    self._logger:Info("Effect applied", {
        player = player.Name,
        effectId = effectId,
        duration = duration,
        description = effectConfig.description,
    })

    return true
end

-- Remove an effect from a player
function PlayerEffectsService:RemoveEffect(player, effectId)
    -- Get effect config before removal for stat modifier cleanup
    local effectConfig = self._rateLimitConfig.effectModifiers[effectId]

    local timedBoosts = player:FindFirstChild("TimedBoosts")
    if not timedBoosts then
        return false
    end

    local effectFolder = timedBoosts:FindFirstChild(effectId)
    if effectFolder then
        -- Remove stat modifiers before destroying folder
        if effectConfig then
            self:_applyStatModifiers(player, effectConfig, -1)
        end

        effectFolder:Destroy()
        self:_removeEffectFromProfile(player, effectId)

        -- Send immediate update to client
        local activeEffects = self:GetActiveEffects(player)
        self:_sendUnifiedEffectsUpdate(player, activeEffects)

        self._logger:Info("Effect removed", { player = player.Name, effectId = effectId })
        return true
    end

    return false
end

-- Apply a permanent effect (for game passes)
function PlayerEffectsService:ApplyPermanentEffect(player, effectId, stats)
    -- Permanent effects are stored as "permanent_" prefix to avoid conflicts
    local permanentEffectId = "permanent_" .. effectId

    -- Get the effect config if it exists
    local effectConfig = self._rateLimitConfig.effectModifiers[effectId]
    if not effectConfig then
        -- Create a temporary config for the permanent effect
        effectConfig = {
            statModifiers = stats or {},
            description = "Permanent effect from game pass",
            displayName = effectId,
            icon = "⭐",
        }
    end

    -- Apply the effect with a very long duration (effectively permanent)
    local success = self:ApplyEffect(player, permanentEffectId, 999999999, effectConfig)

    if success then
        self._logger:Info("Permanent effect applied", {
            player = player.Name,
            effectId = effectId,
            permanentId = permanentEffectId,
            stats = stats,
        })
    else
        self._logger:Warn("Failed to apply permanent effect", {
            player = player.Name,
            effectId = effectId,
        })
    end

    return success
end

-- Clear all effects for a player
function PlayerEffectsService:ClearAllEffects(player)
    local timedBoosts = player:FindFirstChild("TimedBoosts")
    if not timedBoosts then
        self._logger:Info("ClearAllEffects: No TimedBoosts folder found", { player = player.Name })
        return 0
    end

    local effectsCleared = 0

    -- Clear all effect folders (this should automatically reset aggregates)
    for _, effectFolder in ipairs(timedBoosts:GetChildren()) do
        if effectFolder:IsA("Folder") then
            self._logger:Info(
                "Clearing effect folder",
                { player = player.Name, effectId = effectFolder.Name }
            )
            effectFolder:Destroy()
            effectsCleared = effectsCleared + 1
        end
    end

    -- Recalculate aggregates from scratch (should be base values now)
    self:_recalculateAggregates(player)

    -- Clear from ProfileStore
    local data = self._dataService:GetData(player)
    if data and data.ActiveEffects then
        data.ActiveEffects = {}
        self._logger:Info("Cleared ProfileStore ActiveEffects", { player = player.Name })
    end

    self._logger:Info("All effects cleared successfully", {
        player = player.Name,
        effectsCleared = effectsCleared,
    })

    return effectsCleared
end

-- Get active effects for rate limiting calculations
function PlayerEffectsService:GetActiveEffects(player)
    local timedBoosts = player:FindFirstChild("TimedBoosts")
    if not timedBoosts then
        return {}
    end

    local activeEffects = {}
    local currentTime = self._serverClock:GetServerTime()

    for _, effectFolder in ipairs(timedBoosts:GetChildren()) do
        if effectFolder:IsA("Folder") then
            local multiplier = effectFolder:FindFirstChild("multiplier")
            local timeRemaining = effectFolder:FindFirstChild("timeRemaining")

            if timeRemaining and (timeRemaining.Value == -1 or timeRemaining.Value > 0) then
                activeEffects[effectFolder.Name] = {
                    multiplier = multiplier and multiplier.Value or 1.0,
                    timeRemaining = timeRemaining.Value,
                }
            end
        end
    end

    return activeEffects
end

-- Check if player has access to an action (considering effects)
function PlayerEffectsService:CheckRateLimit(player, actionType)
    local baseRate = self._rateLimitConfig.baseRates[actionType]
    if not baseRate then
        return true -- No rate limit defined
    end

    local activeEffects = self:GetActiveEffects(player)
    local effectiveRate = baseRate

    -- Apply effect multipliers
    for effectId, effectData in pairs(activeEffects) do
        local effectConfig = self._rateLimitConfig.effectModifiers[effectId]
        if effectConfig then
            for _, action in ipairs(effectConfig.actions or {}) do
                if action == actionType then
                    effectiveRate = effectiveRate * effectData.multiplier
                    break
                end
            end
        end
    end

    -- Simple rate check for now (can be enhanced with burst protection)
    return true
end

-- Load effects from ProfileStore when player joins
function PlayerEffectsService:LoadPlayerEffects(player)
    -- Ensure player structure exists (called from DataService before PlayerAdded)
    if not player:FindFirstChild("TimedBoosts") then
        self:_setupPlayerStructure(player)
    end
    if not player:FindFirstChild("Aggregates") then
        self:_setupPlayerAggregates(player)
    end

    local data = self._dataService:GetData(player)
    if not data then
        self._logger:Info("No profile data found for load", { player = player.Name })
        return
    end

    if not data.ActiveEffects then
        self._logger:Info(
            "No ActiveEffects in profile data",
            { player = player.Name, profileData = data }
        )
        return
    end

    local function countTable(t)
        local count = 0
        for _ in pairs(t) do
            count = count + 1
        end
        return count
    end

    self._logger:Info("Loading effects from profile", {
        player = player.Name,
        activeEffectsCount = countTable(data.ActiveEffects),
        activeEffectsData = data.ActiveEffects,
    })

    local currentTime = self._serverClock:GetServerTime()
    local effectsLoaded = 0

    for effectId, effectData in pairs(data.ActiveEffects) do
        local timeRemaining = effectData.timeRemaining or 0
        if timeRemaining == -1 or timeRemaining > 0 then
            -- Restore effect with exact remaining time (no time loss!)
            self._logger:Info("Restoring effect from profile", {
                player = player.Name,
                effectId = effectId,
                timeRemaining = timeRemaining,
                originalData = effectData,
            })
            self:ApplyEffect(player, effectId, timeRemaining)
            effectsLoaded = effectsLoaded + 1
        else
            self._logger:Debug("Skipping expired effect", {
                player = player.Name,
                effectId = effectId,
                timeRemaining = timeRemaining,
            })
        end
    end

    -- Recalculate aggregates from restored effects (aggregates are calculated, not saved)
    self:_recalculateAggregates(player)

    self._logger:Info("Player effects loaded from profile", {
        player = player.Name,
        effectsLoaded = effectsLoaded,
    })
end

-- Recalculate all aggregate values from active effects
function PlayerEffectsService:_recalculateAggregates(player)
    local userId = player.UserId
    local aggregates = player:FindFirstChild("Aggregates")
    local timedBoosts = player:FindFirstChild("TimedBoosts")

    if not aggregates or not timedBoosts or not aggregateTotals[userId] then
        return
    end

    -- Reset all totals to base values
    local baseStats = {
        speedMultiplier = 1.0,
        damageBoost = 1.0,
        defenseBoost = 1.0,
        luckBoost = 0,
        rareLuckBoost = 0,
        ultraLuckBoost = 0,
    }

    for statName, _ in pairs(aggregateTotals[userId]) do
        aggregateTotals[userId][statName] = baseStats[statName] or 0
    end

    -- Sum up stat modifiers from all active effects
    for _, effectFolder in ipairs(timedBoosts:GetChildren()) do
        if effectFolder:IsA("Folder") then
            local effectId = effectFolder.Name
            local effectConfig = self._rateLimitConfig.effectModifiers[effectId]

            if effectConfig and effectConfig.statModifiers then
                for statName, delta in pairs(effectConfig.statModifiers) do
                    local baseValue = baseStats[statName] or 0
                    aggregateTotals[userId][statName] = (
                        aggregateTotals[userId][statName] or baseValue
                    ) + delta
                end
            end
        end
    end

    -- Update NumberValues to match calculated totals
    for statName, total in pairs(aggregateTotals[userId]) do
        local statValue = aggregates:FindFirstChild(statName)
        if statValue then
            statValue.Value = total
        end
    end

    self._logger:Debug("Recalculated aggregates", {
        player = player.Name,
        totals = aggregateTotals[userId],
    })
end

-- Save effect to ProfileStore for persistence (stores timeRemaining, not expiresAt)
function PlayerEffectsService:_saveEffectToProfile(player, effectId, timeRemaining, effectConfig)
    local data = self._dataService:GetData(player)
    if not data then
        return
    end

    if not data.ActiveEffects then
        data.ActiveEffects = {}
    end

    data.ActiveEffects[effectId] = {
        timeRemaining = timeRemaining, -- Store time left, not expiration time!
        usesRemaining = effectConfig.maxUses or -1,
        appliedAt = self._serverClock:GetServerTime(), -- For tracking when effect was first applied
    }
end

-- Remove effect from ProfileStore
function PlayerEffectsService:_removeEffectFromProfile(player, effectId)
    local data = self._dataService:GetData(player)
    if data and data.ActiveEffects then
        data.ActiveEffects[effectId] = nil
    end
end

-- Update effect time remaining in ProfileStore (called during countdown)
function PlayerEffectsService:_updateEffectInProfile(player, effectId, newTimeRemaining)
    local data = self._dataService:GetData(player)
    if data and data.ActiveEffects and data.ActiveEffects[effectId] then
        data.ActiveEffects[effectId].timeRemaining = newTimeRemaining
    end
end

-- Effect expiration loop
function PlayerEffectsService:_startEffectExpirationLoop()
    local lastSaveTime = 0
    local SAVE_INTERVAL = 30 -- Save every 30 seconds instead of every heartbeat

    RunService.Heartbeat:Connect(function()
        local currentTime = self._serverClock:GetServerTime()

        for _, player in ipairs(Players:GetPlayers()) do
            local timedBoosts = player:FindFirstChild("TimedBoosts")
            if timedBoosts then
                local needsSave = false
                for _, effectFolder in ipairs(timedBoosts:GetChildren()) do
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
                                    self:RemoveEffect(player, effectFolder.Name)
                                    needsSave = true
                                else
                                    -- Update remaining time (don't save every heartbeat)
                                    timeRemaining.Value = newTimeRemaining
                                    sessionStartTime.Value = currentTime
                                    needsSave = true
                                end
                            end
                        end
                    end
                end

                -- Periodic save (every 30 seconds) to avoid ProfileStore rate limits
                if needsSave and (currentTime - lastSaveTime) > SAVE_INTERVAL then
                    self:_saveAllPlayerEffects(player)
                    lastSaveTime = currentTime
                end
            end
        end
    end)
end

-- Save all active effects for a player (called on leave and periodically)
function PlayerEffectsService:_saveAllPlayerEffects(player)
    local timedBoosts = player:FindFirstChild("TimedBoosts")
    if not timedBoosts then
        self._logger:Warn("No TimedBoosts folder found for save", { player = player.Name })
        return
    end

    local data = self._dataService:GetData(player)
    if not data then
        self._logger:Warn("No profile data found for save", { player = player.Name })
        return
    end

    self._logger:Info("Profile data retrieved for save", {
        player = player.Name,
        hasData = data ~= nil,
        hasActiveEffects = data.ActiveEffects ~= nil,
        currentActiveEffects = data.ActiveEffects,
    })

    -- Clear existing effects and rebuild from current state
    data.ActiveEffects = {}
    local effectsSaved = 0

    for _, effectFolder in ipairs(timedBoosts:GetChildren()) do
        if effectFolder:IsA("Folder") then
            local effectId = effectFolder.Name
            local timeRemaining = effectFolder:FindFirstChild("timeRemaining")
            local effectConfig = self._rateLimitConfig.effectModifiers[effectId]

            -- Handle both regular effects and custom permanent effects
            local hasTimeRemaining = timeRemaining ~= nil
            local hasEffectConfig = effectConfig ~= nil

            if hasTimeRemaining then
                -- For custom effects (like permanent ones), create a basic config
                if not hasEffectConfig then
                    effectConfig = {
                        maxUses = -1, -- Unlimited uses for permanent effects
                        description = "Custom effect",
                        stacking = "none",
                    }
                end

                local effectData = {
                    timeRemaining = timeRemaining.Value,
                    usesRemaining = effectConfig.maxUses or -1,
                    appliedAt = self._serverClock:GetServerTime(),
                }
                data.ActiveEffects[effectId] = effectData
                effectsSaved = effectsSaved + 1

                self._logger:Info("Saving effect to profile", {
                    player = player.Name,
                    effectId = effectId,
                    timeRemaining = timeRemaining.Value,
                    effectData = effectData,
                    dataTableAfterSave = data.ActiveEffects,
                })
            else
                self._logger:Warn("Cannot save effect - missing timeRemaining", {
                    player = player.Name,
                    effectId = effectId,
                    hasTimeRemaining = hasTimeRemaining,
                })
            end
        end
    end

    -- Debug: Log the actual data.ActiveEffects content
    local function countTable(t)
        local count = 0
        for _ in pairs(t) do
            count = count + 1
        end
        return count
    end

    self._logger:Info("Saved all player effects to profile", {
        player = player.Name,
        effectsSaved = effectsSaved,
        totalEffectsInData = countTable(data.ActiveEffects),
        activeEffectsContent = data.ActiveEffects,
    })
end

-- Cleanup when player leaves
function PlayerEffectsService:_cleanupPlayer(player)
    self._logger:Info("Cleaning up player effects", { player = player.Name })

    -- Save effects before cleanup
    self:_saveAllPlayerEffects(player)

    local userId = player.UserId
    aggregateTotals[userId] = nil
    -- TimedBoosts folder will be automatically cleaned up with player
    self._logger:Info("Player effects cleaned up successfully", { player = player.Name })
end

return PlayerEffectsService
