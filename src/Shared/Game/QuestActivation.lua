--[[
    QuestActivation — pure pause/resume math for activation-gated (since_start) quests.

    Single-focus model (Jason 2026-06-21): a grind quest ("Hatch 1,000 Eggs") only makes progress
    while ITS track is the player's active focus, and counts FORWARD from activation — not the
    lifetime total. Switching tracks pauses the old one and resumes the new; switching back keeps
    what you'd already banked.

    State per quest: { banked = <progress earned in past active windows>, base = <counter value at
    the start of the CURRENT open window, or nil when paused> }. The live forward progress is
    `banked + (open ? max(0, current - base) : 0)`. Milestone (absolute, non-since_start) quests
    don't use any of this — they always read the real lifetime counter.

    Pure: no Roblox APIs, no profile/config knowledge. QuestService owns the storage and decides
    which quest is the active head; this module just does the arithmetic so it can be unit-tested.
]]

local QuestActivation = {}

-- Forward progress to show/score for an activation-gated quest.
function QuestActivation.forward(banked, base, current)
    local f = banked or 0
    if base ~= nil then
        f += math.max(0, (current or 0) - base)
    end
    return f
end

-- Close (pause) an open window: fold the current window's gains into `banked`. Returns the new
-- banked total. Idempotent when already paused (base == nil).
function QuestActivation.bank(banked, base, current)
    if base == nil then
        return banked or 0
    end
    return (banked or 0) + math.max(0, (current or 0) - base)
end

return QuestActivation
