--[[
    LeaderboardController — CLIENT consumer for Signals.LeaderboardUpdated.

    LeaderboardService (server) broadcasts each board's snapshot to all clients on a cadence
    (~120s). Without a connected OnClientEvent listener those s->c events queue per-client until
    Roblox's ~128-event cap, then drop in doubling batches ("Remote event invocation queue
    exhausted ... did you forget to implement OnClientEvent?") — a slow leak + wasted bandwidth.

    This thin consumer connects that listener and caches the latest snapshot per board so a future
    leaderboard UI can read it (LeaderboardController.Get / .GetAll) or subscribe (.OnUpdate).
    Keeping the listener connected is what drains the queue; no UI is required for the fix.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signals = require(ReplicatedStorage.Shared.Network.Signals)

local LeaderboardController = {}

local snapshots = {} -- boardId -> latest snapshot table
local subscribers = {} -- fn -> true

local function boardIdOf(snapshot)
    if type(snapshot) ~= "table" then
        return nil
    end
    return snapshot.boardId or snapshot.id or snapshot.board or snapshot.name
end

-- Latest cached snapshot for a board (or nil if none received yet).
function LeaderboardController.Get(boardId)
    return snapshots[boardId]
end

-- The whole cache { boardId -> snapshot } (live table; treat as read-only).
function LeaderboardController.GetAll()
    return snapshots
end

-- Subscribe to updates: fn(boardId, snapshot) on each received snapshot. Returns an unsubscribe.
function LeaderboardController.OnUpdate(fn)
    subscribers[fn] = true
    return function()
        subscribers[fn] = nil
    end
end

function LeaderboardController.start()
    Signals.LeaderboardUpdated.OnClientEvent:Connect(function(snapshot)
        local id = boardIdOf(snapshot) or "default"
        snapshots[id] = snapshot
        for fn in pairs(subscribers) do
            task.spawn(fn, id, snapshot)
        end
    end)
end

return LeaderboardController
