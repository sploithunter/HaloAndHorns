-- Builds the runtime signal table from the validated packet manifest.

local SignalRegistry = {}

function SignalRegistry.build(config, transport)
    assert(type(config) == "table" and type(config.packets) == "table", "invalid network config")
    assert(type(transport) == "table", "network transport is required")

    local packetKeys = {}
    for packetKey in pairs(config.packets) do
        table.insert(packetKeys, packetKey)
    end
    table.sort(packetKeys)

    local signals = {}
    for _, packetKey in ipairs(packetKeys) do
        local packet = config.packets[packetKey]
        if packet.transport == "reliable_event" then
            signals[packetKey] = transport:RemoteEvent(packet.name)
        elseif packet.transport == "remote_function" then
            signals[packetKey] = transport:RemoteFunction(packet.name)
        else
            error("unsupported network transport: " .. tostring(packet.transport))
        end
    end
    return signals
end

return SignalRegistry
