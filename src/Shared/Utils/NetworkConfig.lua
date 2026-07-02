--[[
    NetworkConfig (stub)
    Legacy module retained to satisfy existing code but NetworkBridge system has
    been removed.  All callers should migrate to sleitnick/Net Signals directly.

    This stub exposes:
        NetworkConfig:GetBridge(name) -> Signals[name]
        NetworkConfig:GetBridges()   -> Signals table
        NetworkConfig:ConnectServerHandlers() -- no-op

    Any other legacy methods are intentionally omitted.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Signals = require(ReplicatedStorage.Shared.Network.Signals)

local NetworkConfig = {}
NetworkConfig.__index = NetworkConfig

function NetworkConfig:GetBridge(bridgeName)
    return Signals[bridgeName]
end

function NetworkConfig:GetBridges()
    return Signals
end

function NetworkConfig:ConnectServerHandlers()
    -- Deprecated – handlers should connect directly to Signals in services.
end

function NetworkConfig:Init()
    -- No initialization required.
end

return NetworkConfig
