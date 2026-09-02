local PetRuntimeBridge = {}

local function create(deferCallback)
    local handler = nil
    local pending = {}
    local scheduled = {}
    local bridge = {}

    local function schedule(player)
        if scheduled[player] or handler == nil then
            return
        end
        scheduled[player] = true
        deferCallback(function()
            -- Keep one worker alive through the handler. Pet construction can yield while
            -- loading assets; an equipment change during that window must request one more
            -- pass, not start an overlapping handler that PetHandler rejects as "Skipped".
            while pending[player] and handler ~= nil do
                pending[player] = nil
                handler(player)
            end
            scheduled[player] = nil
        end)
    end

    function bridge.RegisterHandler(callback)
        assert(type(callback) == "function", "PetRuntimeBridge handler must be a function")
        assert(
            handler == nil or handler == callback,
            "PetRuntimeBridge handler is already registered"
        )
        handler = callback
        for player in pairs(pending) do
            schedule(player)
        end
    end

    function bridge.RequestRebuild(player)
        if player == nil then
            return false
        end
        pending[player] = true
        schedule(player)
        return true
    end

    function bridge.ClearPlayer(player)
        pending[player] = nil
    end

    return bridge
end

local taskLib = task
local singleton = create(function(callback)
    if taskLib then
        taskLib.defer(callback)
    else
        callback()
    end
end)

singleton.new = create

return singleton
