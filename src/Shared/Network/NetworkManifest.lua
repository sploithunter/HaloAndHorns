--[[
    Pure schema rules for configs/network.lua's manifest-driven packet table.
    Runtime boot and headless CI both call this module.
]]

local NetworkManifest = {}

local DIRECTIONS = {
    client_to_server = true,
    server_to_client = true,
}

local TRANSPORTS = {
    reliable_event = true,
    remote_function = true,
}

local AUTHORIZATION = {
    server = true,
    player = true,
    admin = true,
    studio = true,
    test = true,
}

local DELIVERIES = {
    player = true,
    broadcast = true,
    request = true,
}

local ENVIRONMENTS = {
    production = true,
    studio = true,
    test = true,
}

local LOCATIONS = {
    net = true,
    replicated_storage = true,
}

local VALUE_TYPES = {
    any = true,
    boolean = true,
    integer = true,
    number = true,
    string = true,
    table = true,
}

local function nonEmptyString(value)
    return type(value) == "string" and value ~= ""
end

local function validateSchema(packetPath, schema)
    if type(schema) ~= "table" or schema.kind ~= "tuple" then
        return false, packetPath .. ".schema: expected tuple schema"
    end
    if type(schema.arguments) ~= "table" then
        return false, packetPath .. ".schema.arguments: expected table"
    end

    local seen = {}
    for index, argument in ipairs(schema.arguments) do
        local path = packetPath .. ".schema.arguments[" .. index .. "]"
        if type(argument) ~= "table" then
            return false, path .. ": expected table"
        end
        if not nonEmptyString(argument.name) then
            return false, path .. ".name: expected non-empty string"
        end
        if seen[argument.name] then
            return false, path .. ".name: duplicate argument"
        end
        seen[argument.name] = true

        if not nonEmptyString(argument.type) then
            return false, path .. ".type: expected non-empty string"
        end
        local baseType = string.gsub(argument.type, "%?$", "")
        if not VALUE_TYPES[baseType] then
            return false, path .. ".type: unknown type '" .. tostring(argument.type) .. "'"
        end
    end
    return true
end

function NetworkManifest.validate(config)
    if type(config) ~= "table" then
        return false, "network: expected table"
    end
    if type(config.version) ~= "number" or config.version % 1 ~= 0 or config.version < 1 then
        return false, "network.version: expected positive integer"
    end
    if type(config.packets) ~= "table" then
        return false, "network.packets: expected table"
    end

    local names = {}
    for packetKey, packet in pairs(config.packets) do
        local path = "network.packets." .. tostring(packetKey)
        if type(packet) ~= "table" then
            return false, path .. ": expected table"
        end
        if not nonEmptyString(packetKey) or not nonEmptyString(packet.name) then
            return false, path .. ".name: expected non-empty string"
        end
        if packet.name ~= packetKey then
            return false, path .. ".name: must match packet key"
        end
        if names[packet.name] then
            return false, path .. ".name: duplicate packet name"
        end
        names[packet.name] = true

        if not TRANSPORTS[packet.transport] then
            return false, path .. ".transport: unknown transport"
        end
        if not DIRECTIONS[packet.direction] then
            return false, path .. ".direction: unknown direction"
        end
        if not AUTHORIZATION[packet.authorization] then
            return false, path .. ".authorization: unknown policy"
        end
        if not DELIVERIES[packet.delivery] then
            return false, path .. ".delivery: unknown delivery"
        end
        local location = packet.location or "net"
        if not LOCATIONS[location] then
            return false, path .. ".location: unknown location"
        end
        if packet.parent ~= nil then
            if location ~= "replicated_storage" or not nonEmptyString(packet.parent) then
                return false, path .. ".parent: requires a replicated_storage parent name"
            end
            local parent = config.packets[packet.parent]
            if
                type(parent) ~= "table"
                or parent.location ~= "replicated_storage"
                or parent.transport ~= "remote_function"
            then
                return false, path .. ".parent: expected a root RemoteFunction packet"
            end
        end

        if type(packet.environments) ~= "table" then
            return false, path .. ".environments: expected table"
        end
        local enabledEnvironment = false
        for environment, enabled in pairs(packet.environments) do
            if not ENVIRONMENTS[environment] or type(enabled) ~= "boolean" then
                return false, path .. ".environments: unknown environment or non-boolean value"
            end
            enabledEnvironment = enabledEnvironment or enabled
        end
        if not enabledEnvironment then
            return false, path .. ".environments: at least one environment must be enabled"
        end

        if packet.direction == "client_to_server" then
            if packet.authorization == "server" then
                return false, path .. ".authorization: client packets require a caller policy"
            end
            if packet.delivery ~= "request" then
                return false, path .. ".delivery: client packets must use request delivery"
            end
            if type(packet.rate_limit) ~= "number" or packet.rate_limit <= 0 then
                return false, path .. ".rate_limit: client packets require a positive limit"
            end
            if not nonEmptyString(packet.handler) then
                return false, path .. ".handler: client packets require a handler"
            end
        else
            if packet.authorization ~= "server" then
                return false, path .. ".authorization: server packets require server policy"
            end
            if packet.delivery ~= "player" and packet.delivery ~= "broadcast" then
                return false, path .. ".delivery: server packets require player or broadcast"
            end
            if not nonEmptyString(packet.topic) then
                return false, path .. ".topic: server packets require a topic"
            end
        end

        local ok, err = validateSchema(path, packet.schema)
        if not ok then
            return false, err
        end
    end

    local batching = config.combat_presentation
    if batching ~= nil then
        if type(batching) ~= "table" or type(batching.enabled) ~= "boolean" then
            return false, "network.combat_presentation: expected table with enabled boolean"
        end
        for _, key in ipairs({
            "flush_interval_seconds",
            "animation_radius",
            "participation_grace_seconds",
            "max_records",
            "startup_records_per_channel",
        }) do
            local value = batching[key]
            if type(value) ~= "number" or value <= 0 or value ~= value or value == math.huge then
                return false,
                    "network.combat_presentation." .. key .. ": expected finite positive number"
            end
        end
        if batching.max_records % 1 ~= 0 or batching.startup_records_per_channel % 1 ~= 0 then
            return false, "network.combat_presentation: record limits must be integers"
        end
        local remote = config.packets[batching.remote]
        if
            not remote
            or remote.transport ~= "reliable_event"
            or remote.direction ~= "server_to_client"
        then
            return false, "network.combat_presentation.remote: expected server reliable event"
        end
        if type(batching.channels) ~= "table" or next(batching.channels) == nil then
            return false, "network.combat_presentation.channels: expected nonempty table"
        end
        local ids = {}
        for name, id in pairs(batching.channels) do
            local packet = config.packets[name]
            if
                not packet
                or packet.transport ~= "reliable_event"
                or packet.direction ~= "server_to_client"
                or name == batching.remote
            then
                return false, "network.combat_presentation.channels: expected server reliable event"
            end
            if type(id) ~= "number" or id < 1 or id % 1 ~= 0 or ids[id] then
                return false,
                    "network.combat_presentation.channels: expected unique positive integer ids"
            end
            ids[id] = true
        end
    end
    return true
end

return NetworkManifest
