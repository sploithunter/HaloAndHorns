-- Pure, per-recipient FIFO. Never coalesce hits: each result/animation keeps its payload.
local PresentationBatchQueue = {}
PresentationBatchQueue.__index = PresentationBatchQueue

local function snapshot(value, seen)
    if type(value) ~= "table" then
        return value -- Instances and value types keep their identity/value.
    end
    if seen[value] then
        return seen[value]
    end
    local copy = {}
    seen[value] = copy
    for key, child in pairs(value) do
        copy[key] = snapshot(child, seen)
    end
    return copy
end

function PresentationBatchQueue.new(maxRecords, send)
    return setmetatable(
        { _pending = {}, _maxRecords = maxRecords, _send = send },
        PresentationBatchQueue
    )
end

function PresentationBatchQueue:enqueue(recipient, channel, payload)
    local records = self._pending[recipient]
    if not records then
        records = {}
        self._pending[recipient] = records
    end
    -- PetFollowService sets hit.foreign AFTER publishing the owner's hit. Copy now, not at flush.
    records[#records + 1] = { channel, snapshot(payload, {}) }
    if #records >= self._maxRecords then
        self:flush(recipient)
    end
end

function PresentationBatchQueue:flush(recipient)
    local records = self._pending[recipient]
    self._pending[recipient] = nil -- detach before sending; reentrant sends belong to the next batch
    if records and #records > 0 then
        self._send(recipient, records)
    end
end

function PresentationBatchQueue:flushAll()
    local recipients = {}
    for recipient in pairs(self._pending) do
        recipients[#recipients + 1] = recipient
    end
    for _, recipient in ipairs(recipients) do
        self:flush(recipient)
    end
end

function PresentationBatchQueue:remove(recipient)
    self._pending[recipient] = nil
end

return PresentationBatchQueue
