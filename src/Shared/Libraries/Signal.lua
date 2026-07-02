-- Basic Signal implementation for Roblox
local Signal = {}
Signal.__index = Signal

function Signal.new()
    return setmetatable({
        _connections = {},
    }, Signal)
end

function Signal:Connect(callback)
    local connection = {
        _callback = callback,
        _signal = self,
        Connected = true,
    }

    function connection:Disconnect()
        if self.Connected then
            self.Connected = false
            local connections = self._signal._connections
            for i = #connections, 1, -1 do
                if connections[i] == self then
                    table.remove(connections, i)
                    break
                end
            end
        end
    end

    table.insert(self._connections, connection)
    return connection
end

function Signal:Fire(...)
    for _, connection in ipairs(self._connections) do
        if connection.Connected then
            task.spawn(connection._callback, ...)
        end
    end
end

function Signal:Wait()
    local thread = coroutine.running()
    local connection
    connection = self:Connect(function(...)
        connection:Disconnect()
        task.spawn(thread, ...)
    end)
    return coroutine.yield()
end

function Signal:Destroy()
    for _, connection in ipairs(self._connections) do
        connection:Disconnect()
    end
    self._connections = {}
end

return Signal
