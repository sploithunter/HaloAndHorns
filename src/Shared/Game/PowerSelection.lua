--[[
    PowerSelection — pure functional core for level-up power selection (Feature 14).

    No Roblox APIs. The service supplies the player's level, selected list, and the
    archetype's available power pool (computed via ArchetypeLogic). Selections are
    one-per-selection-level and accumulate; a power must be in the archetype pool
    and not already selected.

      selectionsReached(level, selectionLevels)                 -> integer
      pendingSelections(level, selectedCount, selectionLevels)  -> integer (>= 0)
      isSelected(powerId, selectedList)                         -> boolean
      canSelect(powerId, availablePowers, selectedList, level, selectionLevels)
                                                                -> { ok, reason? }
      menuRows(pool, powers, level, ownedSet)                   -> { {id, unlockLevel, state}, ... }
]]

local PowerSelection = {}

-- How many selection levels the player has reached at `level`.
function PowerSelection.selectionsReached(level, selectionLevels)
    local lvl = tonumber(level) or 1
    local count = 0
    for _, threshold in ipairs(selectionLevels or {}) do
        if lvl >= threshold then
            count += 1
        end
    end
    return count
end

-- Selections available to spend = levels reached - already selected (never < 0).
function PowerSelection.pendingSelections(level, selectedCount, selectionLevels)
    local reached = PowerSelection.selectionsReached(level, selectionLevels)
    return math.max(0, reached - (tonumber(selectedCount) or 0))
end

local function contains(list, value)
    for _, v in ipairs(list or {}) do
        if v == value then
            return true
        end
    end
    return false
end

function PowerSelection.isSelected(powerId, selectedList)
    return contains(selectedList, powerId)
end

-- Validate a selection: in the archetype pool, not a duplicate, and a selection
-- is currently pending (level reached one not yet spent).
function PowerSelection.canSelect(powerId, availablePowers, selectedList, level, selectionLevels)
    if not contains(availablePowers, powerId) then
        return { ok = false, reason = "not_in_archetype_pool" }
    end
    if contains(selectedList, powerId) then
        return { ok = false, reason = "already_selected" }
    end
    local pending = PowerSelection.pendingSelections(level, #(selectedList or {}), selectionLevels)
    if pending <= 0 then
        return { ok = false, reason = "no_pending_selection" }
    end
    return { ok = true }
end

-- Resolve a powerset POOL (a list of power ids — e.g. configs/archetypes.lua `generic_pool`) into
-- menu rows ORDERED BY unlock_level ascending, then id alphabetically (a stable tiebreak). The pool
-- array only defines MEMBERSHIP; ordering + gating both come from each power's `unlock_level` in
-- `powers`, so a balance pass (re-gate, which re-orders) is a CONFIG edit only — never code.
-- `ownedSet` = { [powerId] = true } for already-picked powers.
--   state: "owned" (picked) | "available" (unlocked: unlock_level <= level) | "locked" (future level)
-- The level you can actually CHOOSE a power: the first selection level >= its unlock_level.
-- Falls back to the unlock level when no schedule is given (or none qualifies), so callers
-- without a schedule behave exactly as before.
function PowerSelection.pickLevel(unlock, selectionLevels)
    unlock = tonumber(unlock) or 1
    if type(selectionLevels) ~= "table" then
        return unlock
    end
    local best
    for _, s in ipairs(selectionLevels) do
        local sl = tonumber(s)
        if sl and sl >= unlock and (not best or sl < best) then
            best = sl
        end
    end
    return best or unlock
end

function PowerSelection.menuRows(pool, powers, level, ownedSet, selectionLevels)
    local lvl = tonumber(level) or 1
    powers = powers or {}
    ownedSet = ownedSet or {}
    local rows = {}
    for _, id in ipairs(pool or {}) do
        local def = powers[id]
        local unlock = (def and tonumber(def.unlock_level)) or 1
        -- pickLevel = when you can truly choose it; the menu shows + gates by THIS, not raw unlock.
        local pick = PowerSelection.pickLevel(unlock, selectionLevels)
        local state
        if ownedSet[id] then
            state = "owned"
        elseif pick <= lvl then
            state = "available"
        else
            state = "locked"
        end
        rows[#rows + 1] = {
            id = id,
            unlockLevel = unlock,
            pickLevel = pick,
            state = state,
            innate = (def and def.innate) == true,
        }
    end
    table.sort(rows, function(a, b)
        -- INNATE powers (owned-free, e.g. Resonance) pin to the TOP — "your first power". Their
        -- pickLevel collapses to the first selection level (same as L2 picks), so without this they'd
        -- lose the alphabetical tiebreak; an explicit innate-first key keeps them at the head.
        if a.innate ~= b.innate then
            return a.innate
        end
        if a.pickLevel ~= b.pickLevel then
            return a.pickLevel < b.pickLevel
        end
        return a.id < b.id
    end)
    return rows
end

return PowerSelection
