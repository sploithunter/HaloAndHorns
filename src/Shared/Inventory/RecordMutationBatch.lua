--[[
    RecordMutationBatch

    Applies independent record mutations and commits their projection/persistence once.
    The caller owns award calculation; this helper only establishes the batch boundary.
]]

local RecordMutationBatch = {}

function RecordMutationBatch.run(recordKeys, mutateOne, commit)
    local changed = {}
    local results = {}

    for _, recordKey in ipairs(recordKeys or {}) do
        local ok, result = mutateOne(recordKey)
        if ok then
            table.insert(changed, recordKey)
            results[recordKey] = result
        end
    end

    if #changed > 0 then
        commit(changed)
    end

    return #changed, results
end

return RecordMutationBatch
