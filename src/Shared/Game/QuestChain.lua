--[[
    QuestChain — pure per-track gating for the quest system.

    Quests are grouped into independent ordered TRACKS (configs/quests.lua `tracks`). Within a
    track, a quest is LOCKED until every lower-order non-repeatable quest in the SAME track has
    been claimed. Tracks are independent, so several quests run in parallel — one "head" (the
    first unlocked, unclaimed mission) per track is active at a time.

    This is the structural fix for "no new quest for several levels": the old design was one
    global chain (a single active quest), so a player could stall on one grind. Splitting into
    parallel tracks keeps multiple quests live.

    Pure: no Roblox APIs, no config knowledge — operates on a plain array of entries so it can be
    unit-tested headless. QuestService builds the entries from the live profile + config.
]]

local QuestChain = {}

-- entries: array of { id, track, order, claimedCount, repeatable }
-- Sets `.locked` (boolean) on every entry IN PLACE, gated per-track by ascending `order`.
-- Returns (entries, heads) where `heads` is a set { [id] = true } of each track's active head —
-- the first unlocked, unclaimed mission in the track (nil if the track is fully claimed).
function QuestChain.annotate(entries)
    local byTrack = {}
    for _, e in ipairs(entries) do
        local t = e.track or "default"
        local list = byTrack[t]
        if not list then
            list = {}
            byTrack[t] = list
        end
        list[#list + 1] = e
    end

    local heads = {}
    for _, list in pairs(byTrack) do
        table.sort(list, function(a, b)
            return (a.order or math.huge) < (b.order or math.huge)
        end)
        local blocked = false
        local headFound = false
        for _, e in ipairs(list) do
            e.locked = blocked
            local claimed = (e.claimedCount or 0) > 0
            -- The active head is the first unlocked mission that hasn't been claimed yet. It is
            -- captured BEFORE we raise `blocked`, since that same mission is what blocks the rest.
            if not blocked and not headFound and not claimed then
                heads[e.id] = true
                headFound = true
            end
            -- A non-repeatable mission that isn't claimed yet locks everything after it in its
            -- track. Repeatable missions never block the chain (you can keep claiming them).
            if not e.repeatable and not claimed then
                blocked = true
            end
        end
    end

    return entries, heads
end

return QuestChain
