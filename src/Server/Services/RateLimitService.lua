--[[
    RateLimitService - Advanced rate limiting with effect support
    
    Features:
    - Configuration-driven base rates
    - Effect-based rate modifiers (potions, passes, items)
    - Anti-exploit protection with absolute maximums
    - Burst protection and escalating punishments
    - Effect stacking with diminishing returns
    
    Usage:
    RateLimitService:CheckRateLimit(player, "PurchaseItem")
    RateLimitService:ApplyEffect(player, "speed_boost", 300) -- 5 minutes
    RateLimitService:GetEffectiveRate(player, "DealDamage")
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local RateLimitService = {}
RateLimitService.__index = RateLimitService

-- Player rate limiting data
local playerRateLimits = {} -- Long-term rate limits (per minute)
local playerBurstLimits = {} -- Short-term burst protection
local playerViolations = {} -- Violation tracking for punishment
local playerEffects = {} -- Active effects per player

function RateLimitService:Init()
    self._logger = self._modules.Logger
    self._configLoader = self._modules.ConfigLoader
    self._dataService = self._modules.DataService
    self._serverClock = self._modules.ServerClockService
    self._economyBridge = nil -- Will be injected later by server

    -- Validate dependencies
    if not self._logger then
        error("RateLimitService: Logger dependency missing - check ModuleLoader configuration")
    end

    if not self._configLoader then
        error(
            "RateLimitService: ConfigLoader dependency missing - check ModuleLoader configuration"
        )
    end

    if not self._dataService then
        error("RateLimitService: DataService dependency missing - check ModuleLoader configuration")
    end

    if not self._serverClock then
        error(
            "RateLimitService: ServerClockService dependency missing - check ModuleLoader configuration"
        )
    end

    -- Load rate limiting configuration with error handling
    local success, configOrError = pcall(function()
        return self._configLoader:LoadConfig("ratelimits")
    end)

    if not success then
        self._logger:Error("CRITICAL: Failed to load ratelimits configuration", {
            error = configOrError,
            file = "configs/ratelimits.lua",
        })
        error("RateLimitService: Cannot load ratelimits.lua - check syntax and file existence")
    end

    self._rateLimitConfig = configOrError

    -- Validate configuration structure
    if not self._rateLimitConfig then
        self._logger:Error("CRITICAL: ratelimits configuration is nil")
        error("RateLimitService: ratelimits.lua returned nil - check file contents")
    end

    if not self._rateLimitConfig.baseRates then
        self._logger:Error(
            "CRITICAL: ratelimits.baseRates missing",
            { config = self._rateLimitConfig }
        )
        error("RateLimitService: ratelimits.lua missing 'baseRates' table")
    end

    if not self._rateLimitConfig.effectModifiers then
        self._logger:Error(
            "CRITICAL: ratelimits.effectModifiers missing",
            { config = self._rateLimitConfig }
        )
        error("RateLimitService: ratelimits.lua missing 'effectModifiers' table")
    end

    if not self._rateLimitConfig.antiExploit then
        self._logger:Error(
            "CRITICAL: ratelimits.antiExploit missing",
            { config = self._rateLimitConfig }
        )
        error("RateLimitService: ratelimits.lua missing 'antiExploit' table")
    end

    local baseRateCount = self:_getTableSize(self._rateLimitConfig.baseRates)
    local effectCount = self:_getTableSize(self._rateLimitConfig.effectModifiers)

    -- Validate we have meaningful configuration
    if baseRateCount == 0 then
        self._logger:Error("CRITICAL: No base rates configured")
        error("RateLimitService: ratelimits.lua has empty baseRates table")
    end

    self._logger:Info("RateLimitService initialized successfully", {
        baseRateCount = baseRateCount,
        effectCount = effectCount,
        configValid = true,
    })

    -- Set up cleanup for disconnected players
    Players.PlayerRemoving:Connect(function(player)
        self:_cleanupPlayerData(player)
    end)

    -- Set up ActiveEffects request handler (client ➜ server)
    do
        local ReplicatedStorage = game:GetService("ReplicatedStorage")
        local Signals = require(ReplicatedStorage.Shared.Network.Signals)
        Signals.ActiveEffects.OnServerEvent:Connect(function(p, data)
            if data and data.request then
                self:_handleActiveEffectsRequest(p)
            end
        end)
    end

    -- Effect expiration loop will be started after economy bridge injection
end

-- Inject economy bridge for client broadcasting
function RateLimitService:InjectEconomyBridge(economyBridge)
    self._economyBridge = economyBridge
    self._logger:Info("Economy bridge injected into RateLimitService for client broadcasting")

    -- Now start the effect expiration loop (requires economy bridge)
    if RunService:IsServer() then
        self:_startEffectExpirationLoop()
        self._logger:Info("Player clock loop started after economy bridge injection")
    end
end

-- Check if player can perform an action
function RateLimitService:CheckRateLimit(player, actionType)
    if not self._rateLimitConfig then
        self._logger:Error("Rate limit config not loaded")
        return true -- Fail open
    end

    local now = tick()
    local userId = player.UserId

    -- Initialize player data if needed
    if not playerRateLimits[userId] then
        self:_initializePlayerData(userId)
    end

    -- Check burst protection first (short-term)
    if not self:_checkBurstLimit(userId, actionType, now) then
        self:_recordViolation(player, actionType, "burst")
        return false
    end

    -- Check main rate limit (long-term)
    if not self:_checkMainRateLimit(userId, actionType, now) then
        self:_recordViolation(player, actionType, "rate")
        return false
    end

    -- Record successful action
    self:_recordAction(userId, actionType, now)
    return true
end

-- Apply an effect to a player (from potions, passes, etc.)
function RateLimitService:ApplyEffect(player, effectId, duration)
    local effectConfig = self._rateLimitConfig.effectModifiers[effectId]
    if not effectConfig then
        self._logger:Warn("Unknown effect applied", { player = player.Name, effectId = effectId })
        return false
    end

    local userId = player.UserId
    if not playerEffects[userId] then
        playerEffects[userId] = {}
    end

    -- Check if effect already exists
    if playerEffects[userId][effectId] then
        -- Effect already active - extend duration instead of stacking
        local existingEffect = playerEffects[userId][effectId]
        local currentTime = self._serverClock:GetServerTime() -- Use server clock
        local remainingTime = self._serverClock:CalculateTimeRemaining(existingEffect.expiresAt)
        local newExpiresAt = self._serverClock:CreateExpirationTime(duration)

        -- Use the longer duration (existing remaining time vs new duration)
        if remainingTime > duration then
            self._logger:Info("Effect not applied - existing effect has longer duration", {
                player = player.Name,
                effectId = effectId,
                existingRemaining = remainingTime,
                newDuration = duration,
            })
            return false
        else
            -- Extend the existing effect
            existingEffect.expiresAt = newExpiresAt
            self._logger:Info("Effect duration extended", {
                player = player.Name,
                effectId = effectId,
                previousExpiry = existingEffect.expiresAt,
                newExpiry = newExpiresAt,
                description = effectConfig.description,
            })
            return true
        end
    end

    -- Check effect stacking limits for NEW effects only
    local activeEffectCount = self:_getActiveEffectCount(userId)
    if activeEffectCount >= self._rateLimitConfig.effectStacking.maxStackedEffects then
        self._logger:Info("Effect not applied - too many active effects", {
            player = player.Name,
            effectId = effectId,
            activeCount = activeEffectCount,
            maxAllowed = self._rateLimitConfig.effectStacking.maxStackedEffects,
        })
        return false
    end

    -- Apply the new effect
    local expiresAt = self._serverClock:CreateExpirationTime(duration) -- Use server clock
    playerEffects[userId][effectId] = {
        expiresAt = expiresAt,
        config = effectConfig,
        stackLevel = 1, -- Track stacking level for future use
    }

    self._logger:Info("Effect applied", {
        player = player.Name,
        effectId = effectId,
        duration = duration,
        expiresAt = expiresAt,
        activeEffectCount = activeEffectCount + 1,
        description = effectConfig.description,
    })

    -- Save effect to ProfileStore for persistence
    self:_saveEffectToProfile(player, effectId, expiresAt, effectConfig)

    -- Send immediate update to client (don't wait for clock tick)
    local activeEffects = self:GetActiveEffects(player)
    self:_sendUnifiedEffectsUpdate(player, activeEffects)

    return true
end

-- Load effects from ProfileStore when player joins
function RateLimitService:LoadPlayerEffects(player)
    local data = self._dataService:GetData(player)
    if not data or not data.ActiveEffects then
        return
    end

    local userId = player.UserId
    if not playerEffects[userId] then
        playerEffects[userId] = {}
    end

    local currentTime = os.time()
    local effectsLoaded = 0

    for effectId, savedEffect in pairs(data.ActiveEffects) do
        -- Check if effect has expired
        if savedEffect.expiresAt > currentTime or savedEffect.expiresAt == -1 then
            -- Load effect config
            local effectConfig = self._rateLimitConfig.effectModifiers[effectId]
            if effectConfig then
                playerEffects[userId][effectId] = {
                    expiresAt = savedEffect.expiresAt,
                    usesRemaining = savedEffect.usesRemaining or savedEffect.maxUses or -1,
                    config = effectConfig,
                }
                effectsLoaded = effectsLoaded + 1

                self._logger:Info("Effect loaded from profile", {
                    player = player.Name,
                    effectId = effectId,
                    expiresAt = savedEffect.expiresAt,
                    usesRemaining = savedEffect.usesRemaining,
                })
            end
        else
            -- Remove expired effect from profile
            data.ActiveEffects[effectId] = nil
            self._logger:Info("Expired effect removed from profile", {
                player = player.Name,
                effectId = effectId,
            })
        end
    end

    if effectsLoaded > 0 then
        self._logger:Info("Player effects loaded from profile", {
            player = player.Name,
            effectsLoaded = effectsLoaded,
        })

        -- Initial effects will be sent on next player clock tick
    end
end

-- Save effect to ProfileStore
function RateLimitService:_saveEffectToProfile(player, effectId, expiresAt, effectConfig)
    local data = self._dataService:GetData(player)
    if not data then
        return
    end

    if not data.ActiveEffects then
        data.ActiveEffects = {}
    end

    data.ActiveEffects[effectId] = {
        expiresAt = expiresAt,
        usesRemaining = effectConfig.maxUses or -1,
        appliedAt = os.time(),
    }

    self._logger:Debug("Effect saved to profile", {
        player = player.Name,
        effectId = effectId,
        expiresAt = expiresAt,
    })
end

-- Get active effects for a player (for client GUI) - uses unified format
function RateLimitService:GetActiveEffects(player)
    local userId = player.UserId
    local activeEffects = {}
    local currentTime = os.time()

    if playerEffects[userId] then
        for effectId, effectData in pairs(playerEffects[userId]) do
            if effectData.expiresAt == -1 then
                -- Permanent effect
                activeEffects[effectId] = self:_formatEffectForClient(effectId, effectData)
            else
                -- Time-based effect
                local timeRemaining = math.max(0, effectData.expiresAt - currentTime)

                if timeRemaining > 0 then
                    local formattedEffect = self:_formatEffectForClient(effectId, effectData)
                    formattedEffect.timeRemaining = timeRemaining
                    activeEffects[effectId] = formattedEffect
                else
                    -- Remove expired effects
                    playerEffects[userId][effectId] = nil
                    self:_removeEffectFromProfile(player, effectId)
                end
            end
        end
    end

    return activeEffects
end

-- Remove an effect from a player
function RateLimitService:RemoveEffect(player, effectId)
    local userId = player.UserId
    if playerEffects[userId] and playerEffects[userId][effectId] then
        playerEffects[userId][effectId] = nil

        -- Remove from ProfileStore too
        self:_removeEffectFromProfile(player, effectId)

        self._logger:Info("Effect removed", { player = player.Name, effectId = effectId })

        -- Send immediate update to client
        local activeEffects = self:GetActiveEffects(player)
        self:_sendUnifiedEffectsUpdate(player, activeEffects)

        return true
    end
    return false
end

-- Helper to remove effect from ProfileStore
function RateLimitService:_removeEffectFromProfile(player, effectId)
    local data = self._dataService:GetData(player)
    if data and data.ActiveEffects then
        data.ActiveEffects[effectId] = nil
        self._logger:Debug("Effect removed from profile", {
            player = player.Name,
            effectId = effectId,
        })
    end
end

-- Clear all effects for a player (Alamantic Aluminum)
function RateLimitService:ClearAllEffects(player)
    local userId = player.UserId
    local effectsCleared = 0

    if playerEffects[userId] then
        for effectId, _ in pairs(playerEffects[userId]) do
            effectsCleared = effectsCleared + 1
        end
        playerEffects[userId] = {}
    end

    -- Clear from ProfileStore too
    local data = self._dataService:GetData(player)
    if data and data.ActiveEffects then
        data.ActiveEffects = {}
    end

    self._logger:Info("All effects cleared", {
        player = player.Name,
        effectsCleared = effectsCleared,
    })

    -- Send immediate update to client (empty effects)
    self:_sendUnifiedEffectsUpdate(player, {})

    return effectsCleared
end

-- Get the effective rate limit for a player (considering effects)
function RateLimitService:GetEffectiveRate(player, actionType)
    local baseRate = self._rateLimitConfig.baseRates[actionType]
    if not baseRate then
        return nil
    end

    local userId = player.UserId
    local effectiveRate = baseRate

    -- Apply active effects
    if playerEffects[userId] then
        local multipliers = {}

        for effectId, effectData in pairs(playerEffects[userId]) do
            -- Check if effect is still active
            if tick() > effectData.expiresAt then
                playerEffects[userId][effectId] = nil -- Clean up expired effect
            else
                -- Check if this effect applies to this action
                for _, affectedAction in ipairs(effectData.config.actions) do
                    if affectedAction == actionType then
                        table.insert(multipliers, effectData.config.multiplier)
                        break
                    end
                end
            end
        end

        -- Apply stacking rules
        if #multipliers > 0 then
            effectiveRate = self:_calculateStackedRate(baseRate, multipliers)
        end
    end

    -- Apply absolute maximum protection
    local absoluteMax = self._rateLimitConfig.antiExploit.absoluteMaxRates[actionType]
    if absoluteMax then
        effectiveRate = math.min(effectiveRate, absoluteMax)
    end

    return effectiveRate
end

-- Get all active effects for a player
function RateLimitService:GetActiveEffects(player)
    local userId = player.UserId
    if not playerEffects[userId] then
        return {}
    end

    local activeEffects = {}
    local now = tick()

    for effectId, effectData in pairs(playerEffects[userId]) do
        if now <= effectData.expiresAt then
            activeEffects[effectId] = {
                timeRemaining = effectData.expiresAt - now,
                description = effectData.config.description,
                actions = effectData.config.actions,
                multiplier = effectData.config.multiplier,
            }
        end
    end

    return activeEffects
end

-- Private methods

function RateLimitService:_initializePlayerData(userId)
    playerRateLimits[userId] = {}
    playerBurstLimits[userId] = {}
    playerViolations[userId] = {
        count = 0,
        lastViolation = 0,
        violations = {},
    }
end

function RateLimitService:_checkBurstLimit(userId, actionType, now)
    local burstConfig = self._rateLimitConfig.antiExploit.burstProtection
    local maxBurst = burstConfig.maxBurstRates[actionType]

    if not maxBurst then
        return true -- No burst limit for this action
    end

    -- Initialize burst tracking for this action
    if not playerBurstLimits[userId][actionType] then
        playerBurstLimits[userId][actionType] = {
            count = 0,
            windowStart = now,
        }
    end

    local burstData = playerBurstLimits[userId][actionType]

    -- Reset window if expired
    if now - burstData.windowStart > burstConfig.windowSize then
        burstData.count = 0
        burstData.windowStart = now
    end

    -- Check if burst limit exceeded
    if burstData.count >= maxBurst then
        return false
    end

    return true
end

function RateLimitService:_checkMainRateLimit(userId, actionType, now)
    local effectiveRate = self:GetEffectiveRate(Players:GetPlayerByUserId(userId), actionType)
    if not effectiveRate then
        return true -- No rate limit for this action
    end

    -- Initialize rate tracking for this action
    if not playerRateLimits[userId][actionType] then
        playerRateLimits[userId][actionType] = {
            count = 0,
            windowStart = now,
        }
    end

    local rateData = playerRateLimits[userId][actionType]

    -- Reset window if expired (1 minute window)
    if now - rateData.windowStart > 60 then
        rateData.count = 0
        rateData.windowStart = now
    end

    -- Check if rate limit exceeded
    if rateData.count >= effectiveRate then
        return false
    end

    return true
end

function RateLimitService:_recordAction(userId, actionType, now)
    -- Record for main rate limit
    if playerRateLimits[userId][actionType] then
        playerRateLimits[userId][actionType].count = playerRateLimits[userId][actionType].count + 1
    end

    -- Record for burst limit
    if playerBurstLimits[userId][actionType] then
        playerBurstLimits[userId][actionType].count = playerBurstLimits[userId][actionType].count
            + 1
    end
end

function RateLimitService:_recordViolation(player, actionType, violationType)
    local userId = player.UserId
    local now = tick()

    if not playerViolations[userId] then
        self:_initializePlayerData(userId)
    end

    local violationData = playerViolations[userId]

    -- Clean up old violations
    local escalationWindow = self._rateLimitConfig.antiExploit.punishment.escalationWindow
    violationData.violations = violationData.violations or {}

    for i = #violationData.violations, 1, -1 do
        if now - violationData.violations[i].timestamp > escalationWindow then
            table.remove(violationData.violations, i)
        end
    end

    -- Record new violation
    table.insert(violationData.violations, {
        timestamp = now,
        actionType = actionType,
        violationType = violationType,
    })

    local violationCount = #violationData.violations
    local punishment = self._rateLimitConfig.antiExploit.punishment

    self._logger:Warn("Rate limit violation", {
        player = player.Name,
        actionType = actionType,
        violationType = violationType,
        violationCount = violationCount,
    })

    -- Apply punishment based on violation count
    if violationCount >= punishment.banThreshold then
        self._logger:Error(
            "Player exceeded ban threshold",
            { player = player.Name, violationCount = violationCount }
        )
        -- TODO: Implement temporary ban
        player:Kick("Rate limit violations - temporary ban")
    elseif violationCount >= punishment.kickThreshold then
        self._logger:Error(
            "Player exceeded kick threshold",
            { player = player.Name, violationCount = violationCount }
        )
        player:Kick("Excessive rate limit violations")
    elseif violationCount >= punishment.warningThreshold then
        self._logger:Info(
            "Player warned for rate limit violations",
            { player = player.Name, violationCount = violationCount }
        )
        -- TODO: Send warning to player
    end
end

function RateLimitService:_calculateStackedRate(baseRate, multipliers)
    local stackingConfig = self._rateLimitConfig.effectStacking
    local effectiveRate = baseRate

    if stackingConfig.stackingMode == "multiply" then
        table.sort(multipliers, function(a, b)
            return a > b
        end) -- Sort highest first

        for i, multiplier in ipairs(multipliers) do
            local adjustedMultiplier = multiplier

            -- Apply diminishing returns
            if stackingConfig.diminishingReturns and i > 1 then
                adjustedMultiplier = 1
                    + (multiplier - 1) * (stackingConfig.diminishingFactor ^ (i - 1))
            end

            effectiveRate = effectiveRate * adjustedMultiplier
        end
    elseif stackingConfig.stackingMode == "add" then
        local totalBonus = 0
        for i, multiplier in ipairs(multipliers) do
            local bonus = multiplier - 1

            -- Apply diminishing returns
            if stackingConfig.diminishingReturns and i > 1 then
                bonus = bonus * (stackingConfig.diminishingFactor ^ (i - 1))
            end

            totalBonus = totalBonus + bonus
        end
        effectiveRate = baseRate * (1 + totalBonus)
    elseif stackingConfig.stackingMode == "best" then
        local bestMultiplier = math.max(unpack(multipliers))
        effectiveRate = baseRate * bestMultiplier
    end

    return effectiveRate
end

function RateLimitService:_getActiveEffectCount(userId)
    if not playerEffects[userId] then
        return 0
    end

    local count = 0
    local now = tick()

    for effectId, effectData in pairs(playerEffects[userId]) do
        if now <= effectData.expiresAt then
            count = count + 1
        end
    end

    return count
end

function RateLimitService:_startEffectExpirationLoop()
    -- Unified player clock: tick every second for all players
    task.spawn(function()
        while true do
            task.wait(1) -- Player clock ticks every second
            self:_tickPlayerClocks()
        end
    end)
end

-- Unified player clock: tick all effects and broadcast once per player
function RateLimitService:_tickPlayerClocks()
    if not self._economyBridge then
        self._logger:Debug("Player clock tick skipped - no economy bridge")
        return
    end

    local currentTime = self._serverClock:GetServerTime()
    self._logger:Debug(
        "Player clock tick",
        { currentTime = currentTime, playerCount = self:_getTableSize(playerEffects) }
    )

    for userId, effects in pairs(playerEffects) do
        local player = Players:GetPlayerByUserId(userId)
        if not player then
            -- Clean up offline players
            playerEffects[userId] = nil
            continue
        end

        local effectsChanged = false
        local activeEffects = {}

        -- Process each effect for this player
        for effectId, effectData in pairs(effects) do
            if effectData.expiresAt == -1 then
                -- Permanent effect - always include
                activeEffects[effectId] = self:_formatEffectForClient(effectId, effectData)
            else
                -- Time-based effect - calculate remaining time
                local timeRemaining = self._serverClock:CalculateTimeRemaining(effectData.expiresAt)

                if timeRemaining > 0 then
                    -- Effect still active
                    local formattedEffect = self:_formatEffectForClient(effectId, effectData)
                    formattedEffect.timeRemaining = timeRemaining
                    activeEffects[effectId] = formattedEffect
                else
                    -- Effect expired - remove it
                    effects[effectId] = nil
                    self:_removeEffectFromProfile(player, effectId)
                    effectsChanged = true

                    self._logger:Info("Effect expired", {
                        player = player.Name,
                        effectId = effectId,
                        expiredAt = effectData.expiresAt,
                    })
                end
            end
        end

        -- Clean up empty effect tables
        if next(effects) == nil then
            playerEffects[userId] = nil
        end

        -- Send unified effects message to client (only if player has effects)
        if next(activeEffects) then
            self:_sendUnifiedEffectsUpdate(player, activeEffects)
        elseif effectsChanged then
            -- Send empty update if effects were removed
            self:_sendUnifiedEffectsUpdate(player, {})
        end
    end
end

-- Format effect data for client consumption (configuration-driven)
function RateLimitService:_formatEffectForClient(effectId, effectData)
    local config = effectData.config

    return {
        id = effectId,
        name = self:_getEffectDisplayName(effectId),
        description = config.description or "Active effect",
        multiplier = config.multiplier or 1.0,
        actions = config.actions or {},
        usesRemaining = effectData.usesRemaining or -1,
        timeRemaining = -1, -- Will be calculated by caller for time-based effects
        permanent = effectData.expiresAt == -1,
        icon = self:_getEffectIcon(effectId),
    }
end

-- Configuration-driven effect display names
function RateLimitService:_getEffectDisplayName(effectId)
    local config = self._rateLimitConfig.effectModifiers[effectId]
    if config and config.displayName then
        return config.displayName
    end

    -- Fallback display names
    local names = {
        speed_boost = "⚡ Speed Boost",
        trader_blessing = "📜 Trader Blessing",
        vip_pass = "💎 VIP Pass",
        premium_speed = "🚀 Premium Speed",
        combat_frenzy = "⚔️ Combat Frenzy",
    }
    return names[effectId] or effectId
end

-- Configuration-driven effect icons
function RateLimitService:_getEffectIcon(effectId)
    local config = self._rateLimitConfig.effectModifiers[effectId]
    if config and config.icon then
        return config.icon
    end

    -- Fallback icons
    local icons = {
        speed_boost = "⚡",
        trader_blessing = "📜",
        vip_pass = "💎",
        premium_speed = "🚀",
        combat_frenzy = "⚔️",
    }
    return icons[effectId] or "✨"
end

-- Send unified effects update to client (single message with all effects)
function RateLimitService:_sendUnifiedEffectsUpdate(player, activeEffects)
    local success, error = pcall(function()
        local Signals = require(game:GetService("ReplicatedStorage").Shared.Network.Signals)
        Signals.ActiveEffects:FireClient(player, {
            effects = activeEffects,
            timestamp = self._serverClock:GetServerTime(), -- Use unified server clock
            playerClock = true, -- Indicates this uses unified player clock
        })
    end)

    if not success then
        self._logger:Error("Failed to send unified effects update", {
            error = error,
            player = player.Name,
            effectCount = next(activeEffects) and self:_getTableSize(activeEffects) or 0,
        })
    else
        self._logger:Debug("Effects update sent to client", {
            player = player.Name,
            effectCount = next(activeEffects) and self:_getTableSize(activeEffects) or 0,
            effects = activeEffects,
        })
    end
end

function RateLimitService:_cleanupPlayerData(player)
    local userId = player.UserId
    playerRateLimits[userId] = nil
    playerBurstLimits[userId] = nil
    playerViolations[userId] = nil
    playerEffects[userId] = nil

    self._logger:Info("Cleaned up rate limit data", { player = player.Name })
end

function RateLimitService:_getTableSize(table)
    local count = 0
    for _ in pairs(table) do
        count = count + 1
    end
    return count
end

-- Handle client request for current active effects
function RateLimitService:_handleActiveEffectsRequest(player)
    local userId = player.UserId
    local effects = playerEffects[userId]
    local activeEffectsFormatted = {}

    if effects then
        for effectId, effectData in pairs(effects) do
            local formatted = self:_formatEffectForClient(effectId, effectData)
            if effectData.expiresAt == -1 then
                formatted.timeRemaining = -1
            else
                formatted.timeRemaining =
                    self._serverClock:CalculateTimeRemaining(effectData.expiresAt)
            end
            activeEffectsFormatted[effectId] = formatted
        end
    end

    -- Send to client using unified method
    self:_sendUnifiedEffectsUpdate(player, activeEffectsFormatted)
end

return RateLimitService
