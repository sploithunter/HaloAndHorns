-- Decorates existing signal handles. Combat producers and visual consumers keep their API.
local Queue = require(script.Parent.PresentationBatchQueue)
local PresentationBatchTransport = {}

function PresentationBatchTransport.installServer(signals, config, players, heartbeat, audience)
    local remote = signals[config.remote]
    local queue = Queue.new(config.max_records, function(player, records)
        if player.Parent == players then
            remote:FireClient(player, records)
        end
    end)
    local elapsed = 0
    heartbeat:Connect(function(dt)
        elapsed += dt
        if elapsed >= config.flush_interval_seconds then
            elapsed = 0 -- no catch-up bursts after a long server frame
            queue:flushAll()
            audience:prune(os.clock())
        end
    end)
    players.PlayerRemoving:Connect(function(player)
        queue:remove(player)
        audience:prune(os.clock(), player.UserId)
    end)
    for name, channel in pairs(config.channels) do
        local function publish(payload, candidates)
            for _, player in ipairs(audience:select(name, payload, candidates, os.clock())) do
                queue:enqueue(player, channel, payload)
            end
        end
        signals[name] = {
            FireClient = function(_, player, payload)
                publish(payload, { player })
            end,
            FireAllClients = function(_, payload)
                publish(payload, players:GetPlayers())
            end,
        }
    end
end

function PresentationBatchTransport.installClient(signals, config, makeSignal)
    makeSignal = makeSignal or require(script.Parent.Parent.Libraries.Signal).new
    local channels = {}
    for name, channel in pairs(config.channels) do
        local event = makeSignal()
        local state = { event = event, pending = {} }
        channels[channel] = state
        signals[name] = {
            OnClientEvent = {
                Connect = function(_, callback)
                    local connection = event:Connect(callback)
                    local pending = state.pending
                    state.pending = nil
                    if pending then
                        for _, payload in ipairs(pending) do
                            event:Fire(payload)
                        end
                    end
                    return connection
                end,
            },
        }
    end
    signals[config.remote].OnClientEvent:Connect(function(records)
        if type(records) ~= "table" then
            return
        end
        for _, record in ipairs(records) do
            local state = type(record) == "table" and channels[record[1]]
            local payload = type(record) == "table" and record[2]
            if state and type(payload) == "table" then
                if state.pending then
                    -- Match RemoteEvent's bounded startup buffering, not an unbounded history.
                    if #state.pending >= config.startup_records_per_channel then
                        table.remove(state.pending, 1)
                    end
                    state.pending[#state.pending + 1] = payload
                else
                    state.event:Fire(payload)
                end
            end
        end
    end)
end

return PresentationBatchTransport
