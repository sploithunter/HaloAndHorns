--[[
    OpsAlert — fire-and-forget dev telemetry (Storage v2 D8 — the first piece of the
    logging service Jason asked for: "use a logging service which we probably need
    anyway... have a message delivered to us when it gets too high").

    OpsAlert.send(kind, payload) never throws and never blocks gameplay. Entries batch
    every FLUSH_SECONDS into a DAY-KEYED DataStore ring buffer (OpsAlerts_v1) capped at
    MAX_ENTRIES_PER_DAY — readable on demand from Studio/MCP or the ops.alerts bus
    command. Transport v2 (push: webhook/external sink) swaps in behind the same API.

        local OpsAlert = require(script.Parent.OpsAlert)  -- (Server-scoped module)
        OpsAlert.send("unique_storage_high", { player = name, count = n, cap = cap })
        OpsAlert.recent(3) -> { { day = "2026-06-12", entries = {...} }, ... }
]]

local DataStoreService = game:GetService("DataStoreService")

local STORE_NAME = "OpsAlerts_v1"
local MAX_ENTRIES_PER_DAY = 200
local FLUSH_SECONDS = 30

local OpsAlert = {}

local _queue = {}
local _flusherStarted = false
local _store -- nil = untried, false = unavailable

local function getStore()
    if _store == nil then
        local ok, s = pcall(function()
            return DataStoreService:GetDataStore(STORE_NAME)
        end)
        _store = ok and s or false
    end
    return _store or nil
end

local function dayKey(offsetDays)
    return os.date("!%Y-%m-%d", os.time() - (offsetDays or 0) * 86400)
end

local function flush()
    if #_queue == 0 then
        return
    end
    local store = getStore()
    if not store then
        _queue = {} -- no transport (offline Studio): drop rather than grow unbounded
        return
    end
    local batch = _queue
    _queue = {}
    pcall(function()
        store:UpdateAsync(dayKey(), function(list)
            list = type(list) == "table" and list or {}
            for _, entry in ipairs(batch) do
                table.insert(list, entry)
            end
            -- ring: keep the newest MAX_ENTRIES_PER_DAY
            while #list > MAX_ENTRIES_PER_DAY do
                table.remove(list, 1)
            end
            return list
        end)
    end)
end

local function ensureFlusher()
    if _flusherStarted then
        return
    end
    _flusherStarted = true
    task.spawn(function()
        while true do
            task.wait(FLUSH_SECONDS)
            flush()
        end
    end)
    game:BindToClose(function()
        flush()
    end)
end

-- Fire-and-forget. kind = short machine id ("unique_storage_high"); payload = small
-- plain table (JSON-safe). Never throws; never blocks the caller.
function OpsAlert.send(kind, payload)
    table.insert(_queue, {
        t = os.time(),
        k = tostring(kind),
        p = type(payload) == "table" and payload or { value = tostring(payload) },
    })
    ensureFlusher()
end

-- Read the last N days of alerts (today first). Studio/MCP + ops.alerts bus command.
function OpsAlert.recent(daysBack)
    local store = getStore()
    if not store then
        return {}
    end
    local out = {}
    for offset = 0, math.clamp(tonumber(daysBack) or 1, 0, 14) do
        local key = dayKey(offset)
        local ok, list = pcall(function()
            return store:GetAsync(key)
        end)
        if ok and type(list) == "table" and #list > 0 then
            table.insert(out, { day = key, entries = list })
        end
    end
    return out
end

return OpsAlert
