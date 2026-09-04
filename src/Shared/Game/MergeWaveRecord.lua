-- All-time reached-wave record, independent of restart checkpoints and rebirths.
local MergeWaveRecord = {}

local function whole(value)
    local n = tonumber(value) or 0
    if n ~= n or n == math.huge or n == -math.huge then
        return 0
    end
    return math.max(0, math.floor(n))
end

function MergeWaveRecord.best(progress, banners, catalog, currentWave)
    progress = type(progress) == "table" and progress or {}
    local checkpoint = type(progress.checkpoint) == "table" and progress.checkpoint or {}
    local playstate = type(progress.playstate) == "table" and progress.playstate or {}
    local best = math.max(
        whole(progress.highest_wave),
        whole(checkpoint.wave),
        whole(playstate.wave),
        whole(currentWave)
    )
    -- Older profiles have no exact all-time counter. Existing wave awards prove a lower bound;
    -- never infer a wave from level, rebirth count, egg tier, or a different kind of award.
    local owned = type(banners) == "table" and banners.owned or {}
    for id, award in pairs(type(owned) == "table" and owned or {}) do
        local definition = type(catalog) == "table" and catalog[id]
        local trigger = type(definition) == "table" and definition.trigger
        if type(trigger) == "table" and trigger.fact == "merge_wave" then
            best = math.max(
                best,
                whole(trigger.at_least),
                whole(type(award) == "table" and award.value)
            )
        end
    end
    return best
end

return MergeWaveRecord
