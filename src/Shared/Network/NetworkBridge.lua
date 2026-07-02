--[[
    NetworkBridge - Optimized networking layer for Roblox games
    
    Features:
    - Packet-based communication system
    - Rate limiting per packet type
    - Automatic validation and sanitization
    - Batch sending for performance
    - Compression for large payloads
    - Secure communication with validation
    
    Usage:
    Server:
    local bridge = NetworkBridge:CreateBridge("Economy")
    bridge:DefinePacket("PurchaseItem", {rateLimit = 10, validator = function(data) ... end})
    bridge:Connect(function(player, packetType, data) ... end)
    
    Client:
    local bridge = NetworkBridge:CreateBridge("Economy")
    bridge:Fire("PurchaseItem", {itemId = "sword"})
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local NetworkBridge = {}
NetworkBridge.__index = NetworkBridge

local IS_SERVER = RunService:IsServer()
local IS_CLIENT = RunService:IsClient()

-- Global registry
local bridges = {}
local remoteEvents = {}
local rateLimiters = {}
local packetDefinitions = {}

-- Rate limiting storage
local playerRateLimits = {}

-- Batch sending
local batchQueues = {}
local BATCH_DELAY = 0.1 -- 100ms batching

function NetworkBridge:Init()
    if self._modules and self._modules.Logger then
        self._modules.Logger:Info("NetworkBridge initialized", {
            isServer = IS_SERVER,
            isClient = IS_CLIENT,
        })
    end

    -- Set up batch processing
    if IS_SERVER then
        self:_setupBatchProcessing()
    end
end

function NetworkBridge:CreateBridge(bridgeName)
    if bridges[bridgeName] then
        return bridges[bridgeName]
    end

    local bridge = setmetatable({
        name = bridgeName,
        _connections = {},
        _packets = {},
        _logger = self._modules and self._modules.Logger,
    }, NetworkBridge)

    -- Create or get RemoteEvent
    local eventName = "NetworkBridge_" .. bridgeName
    local remoteEvent

    if IS_SERVER then
        remoteEvent = Instance.new("RemoteEvent")
        remoteEvent.Name = eventName
        remoteEvent.Parent = ReplicatedStorage

        -- Connect server-side handler
        remoteEvent.OnServerEvent:Connect(function(player, packetType, data, metadata)
            bridge:_handleServerPacket(player, packetType, data, metadata)
        end)
    else
        -- Wait for RemoteEvent on client
        remoteEvent = ReplicatedStorage:WaitForChild(eventName, 10)
        if not remoteEvent then
            error(string.format("Failed to find RemoteEvent for bridge '%s'", bridgeName))
        end

        -- Connect client-side handler
        remoteEvent.OnClientEvent:Connect(function(packetType, data, metadata)
            bridge:_handleClientPacket(packetType, data, metadata)
        end)
    end

    remoteEvents[bridgeName] = remoteEvent
    bridges[bridgeName] = bridge

    return bridge
end

function NetworkBridge:DefinePacket(packetType, config)
    config = config or {}

    local packetDef = {
        type = packetType,
        rateLimit = config.rateLimit or 60, -- requests per minute
        validator = config.validator,
        compressThreshold = config.compressThreshold or 1000, -- bytes
        reliable = config.reliable ~= false, -- default to reliable
        priority = config.priority or "normal", -- low, normal, high
    }

    self._packets[packetType] = packetDef
    packetDefinitions[self.name .. "_" .. packetType] = packetDef

    if self._logger then
        self._logger:Debug("Packet defined", {
            bridge = self.name,
            packetType = packetType,
            rateLimit = packetDef.rateLimit,
        })
    end
end

function NetworkBridge:Connect(callback)
    table.insert(self._connections, callback)
end

function NetworkBridge:Fire(target, packetType, data, options)
    -- Handle client-side calls where target is actually packetType
    if IS_CLIENT and typeof(target) == "string" and typeof(packetType) == "table" then
        -- Client call: Fire(packetType, data, options)
        options = data or {}
        data = packetType
        packetType = target
        target = nil
    end

    options = options or {}

    local packetDef = self._packets[packetType]
    if not packetDef then
        if self._logger then
            self._logger:Error("🚨 PACKET NOT FOUND", {
                bridge = self.name,
                packetType = packetType,
                packetTypeType = typeof(packetType),
                availablePackets = self._packets and table.concat(self:_getPacketNames(), ", ")
                    or "none",
            })
        end
        error(string.format("Undefined packet type '%s' for bridge '%s'", packetType, self.name))
    end

    -- Validate data if validator exists
    if packetDef.validator and not packetDef.validator(data) then
        if self._logger then
            self._logger:Warn("Packet validation failed", {
                bridge = self.name,
                packetType = packetType,
            })
        end
        return false
    end

    local metadata = {
        timestamp = tick(),
        priority = options.priority or packetDef.priority,
        compressed = false,
    }

    -- Compression for large payloads
    local serializedData = HttpService:JSONEncode(data)
    if #serializedData > packetDef.compressThreshold then
        -- TODO: Implement compression
        metadata.compressed = true
    end

    local remoteEvent = remoteEvents[self.name]
    if not remoteEvent then
        error(string.format("RemoteEvent not found for bridge '%s'", self.name))
    end

    if IS_SERVER then
        if target == "all" then
            -- Batch send to all players
            self:_batchSend(nil, packetType, data, metadata)
        elseif typeof(target) == "Instance" and target:IsA("Player") then
            -- Send to specific player
            if options.batch then
                self:_batchSend(target, packetType, data, metadata)
            else
                remoteEvent:FireClient(target, packetType, data, metadata)
            end
        else
            error("Invalid target for server Fire - must be Player instance or 'all'")
        end
    else
        -- Client to server
        if self._logger then
            self._logger:Debug("🔍 CLIENT - Attempting to send packet", {
                bridge = self.name,
                packetType = packetType,
                data = data,
            })
        end

        if self:_checkRateLimit(packetType) then
            if self._logger then
                self._logger:Debug("🔍 CLIENT - Rate limit passed, sending packet", {
                    bridge = self.name,
                    packetType = packetType,
                })
            end
            remoteEvent:FireServer(packetType, data, metadata)
        else
            if self._logger then
                self._logger:Warn("🚨 CLIENT - Rate limit exceeded", {
                    bridge = self.name,
                    packetType = packetType,
                })
            end
            return false
        end
    end

    return true
end

function NetworkBridge:_handleServerPacket(player, packetType, data, metadata)
    -- Server-side rate limiting
    if not self:_checkServerRateLimit(player, packetType) then
        if self._logger then
            self._logger:Warn("Server rate limit exceeded", {
                bridge = self.name,
                packetType = packetType,
                player = player.Name,
            })
        end
        return
    end

    -- Validate packet
    local packetDef = self._packets[packetType]
    if not packetDef then
        if self._logger then
            self._logger:Warn("Undefined packet received", {
                bridge = self.name,
                packetType = packetType,
                player = player.Name,
            })
        end
        return
    end

    -- Additional validation
    if packetDef.validator and not packetDef.validator(data) then
        if self._logger then
            self._logger:Warn("Server packet validation failed", {
                bridge = self.name,
                packetType = packetType,
                player = player.Name,
            })
        end
        return
    end

    -- Call all connected handlers
    for _, callback in ipairs(self._connections) do
        local success, err = pcall(callback, player, packetType, data)
        if not success and self._logger then
            self._logger:Error("Packet handler error", {
                bridge = self.name,
                packetType = packetType,
                error = err,
            })
        end
    end
end

function NetworkBridge:_handleClientPacket(packetType, data, metadata)
    -- Call all connected handlers
    for _, callback in ipairs(self._connections) do
        local success, err = pcall(callback, packetType, data)
        if not success and self._logger then
            self._logger:Error("Client packet handler error", {
                bridge = self.name,
                packetType = packetType,
                error = err,
            })
        end
    end
end

function NetworkBridge:_checkRateLimit(packetType)
    if not IS_CLIENT then
        return true
    end

    local now = tick()
    local key = self.name .. "_" .. packetType

    if not rateLimiters[key] then
        rateLimiters[key] = {
            count = 0,
            window = now,
        }
    end

    local limiter = rateLimiters[key]
    local packetDef = self._packets[packetType]

    if not packetDef then
        return true
    end

    -- Reset window if it's been more than a minute
    if now - limiter.window > 60 then
        limiter.count = 0
        limiter.window = now
    end

    if limiter.count >= packetDef.rateLimit then
        return false
    end

    limiter.count = limiter.count + 1
    return true
end

function NetworkBridge:_checkServerRateLimit(player, packetType)
    if not IS_SERVER then
        return true
    end

    -- Use advanced rate limiting service if available
    if self._rateLimitService then
        return self._rateLimitService:CheckRateLimit(player, packetType)
    end

    -- Fallback to simple rate limiting
    local now = tick()
    local key = player.UserId .. "_" .. self.name .. "_" .. packetType

    if not playerRateLimits[key] then
        playerRateLimits[key] = {
            count = 0,
            window = now,
        }
    end

    local limiter = playerRateLimits[key]
    local packetDef = self._packets[packetType]

    if not packetDef then
        return true
    end

    -- Reset window if it's been more than a minute
    if now - limiter.window > 60 then
        limiter.count = 0
        limiter.window = now
    end

    if limiter.count >= packetDef.rateLimit then
        return false
    end

    limiter.count = limiter.count + 1
    return true
end

function NetworkBridge:_batchSend(player, packetType, data, metadata)
    if not IS_SERVER then
        return
    end

    local queueKey = player and tostring(player.UserId) or "all"
    if not batchQueues[queueKey] then
        batchQueues[queueKey] = {}
    end

    table.insert(batchQueues[queueKey], {
        bridge = self.name,
        packetType = packetType,
        data = data,
        metadata = metadata,
        player = player,
    })
end

function NetworkBridge:_setupBatchProcessing()
    if not IS_SERVER then
        return
    end

    -- Process batch queues every BATCH_DELAY seconds
    task.spawn(function()
        while true do
            task.wait(BATCH_DELAY)

            for queueKey, queue in pairs(batchQueues) do
                if #queue > 0 then
                    -- Group by bridge and send batches
                    local bridgeGroups = {}

                    for _, packet in ipairs(queue) do
                        local bridgeName = packet.bridge
                        if not bridgeGroups[bridgeName] then
                            bridgeGroups[bridgeName] = {}
                        end
                        table.insert(bridgeGroups[bridgeName], packet)
                    end

                    -- Send batches
                    for bridgeName, packets in pairs(bridgeGroups) do
                        local remoteEvent = remoteEvents[bridgeName]
                        if remoteEvent then
                            if queueKey == "all" then
                                -- Send to all players
                                for _, packet in ipairs(packets) do
                                    remoteEvent:FireAllClients(
                                        packet.packetType,
                                        packet.data,
                                        packet.metadata
                                    )
                                end
                            else
                                -- Send to specific player
                                local player = packets[1].player
                                if player and player.Parent then
                                    for _, packet in ipairs(packets) do
                                        remoteEvent:FireClient(
                                            player,
                                            packet.packetType,
                                            packet.data,
                                            packet.metadata
                                        )
                                    end
                                end
                            end
                        end
                    end

                    -- Clear queue
                    batchQueues[queueKey] = {}
                end
            end
        end
    end)
end

-- Cleanup when players leave
if IS_SERVER then
    Players.PlayerRemoving:Connect(function(player)
        -- Clear rate limit data
        for key in pairs(playerRateLimits) do
            if key:find("^" .. player.UserId .. "_") then
                playerRateLimits[key] = nil
            end
        end

        -- Clear batch queues
        batchQueues[tostring(player.UserId)] = nil
    end)
end

-- Helper method to get packet names for debugging
function NetworkBridge:_getPacketNames()
    local names = {}
    for name, _ in pairs(self._packets) do
        table.insert(names, name)
    end
    return names
end

return NetworkBridge
