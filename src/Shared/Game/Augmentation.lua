--[[
    Augmentation — pure functional core for augmentation slots (Feature 15).

    No Roblox APIs. The service supplies the player's level, total allocated slot
    count, the slot list already on a power, and whether the power is unlocked.

      slotsGranted(level, slotGrantLevels, slotsPerGrant)   -> integer
      unallocatedSlots(level, allocatedCount, slotGrantLevels, slotsPerGrant) -> integer (>= 0)
      canPlace(isPowerUnlocked, slotsOnPower, unallocated, config) -> { ok, reason? }
      -- (future enhancements layer; not consumed by empty slots yet:)
      isSlotType(slotType, config)                          -> boolean
      matchingCounts(slotsOnPower)                          -> { [slotType] = count }
      activeSetBonuses(slotsOnPower, config)                -> { {type, tier, amount}, ... }
]]

local Augmentation = {}

-- Total slots earned from level grants: (# grant levels reached) * slotsPerGrant (default 1).
function Augmentation.slotsGranted(level, slotGrantLevels, slotsPerGrant)
    local lvl = tonumber(level) or 1
    local count = 0
    for _, threshold in ipairs(slotGrantLevels or {}) do
        if lvl >= threshold then
            count += 1
        end
    end
    return count * (tonumber(slotsPerGrant) or 1)
end

-- Free granted slots not yet placed. `allocatedCount` must EXCLUDE inherent slots (those are free
-- with the pick and don't draw from the granted pool) — the service computes it that way.
function Augmentation.unallocatedSlots(level, allocatedCount, slotGrantLevels, slotsPerGrant)
    return math.max(
        0,
        Augmentation.slotsGranted(level, slotGrantLevels, slotsPerGrant)
            - (tonumber(allocatedCount) or 0)
    )
end

-- Validate placing an EMPTY slot on a power that already has `slotsOnPower` slots, given
-- `unallocated` free granted slots. Slots are untyped capacity now; typed enhancements come later.
function Augmentation.canPlace(isPowerUnlocked, slotsOnPower, unallocated, config)
    if not isPowerUnlocked then
        return { ok = false, reason = "power_locked" }
    end
    if (tonumber(unallocated) or 0) <= 0 then
        return { ok = false, reason = "no_unallocated_slots" }
    end
    if #(slotsOnPower or {}) >= ((config and config.max_slots_per_power) or math.huge) then
        return { ok = false, reason = "max_slots_reached" }
    end
    return { ok = true }
end

function Augmentation.isSlotType(slotType, config)
    for _, t in ipairs(config and config.slot_types or {}) do
        if t == slotType then
            return true
        end
    end
    return false
end

-- Count slots by type on a single power.
function Augmentation.matchingCounts(slotsOnPower)
    local counts = {}
    for _, slotType in ipairs(slotsOnPower or {}) do
        counts[slotType] = (counts[slotType] or 0) + 1
    end
    return counts
end

-- Every active set-bonus tier for a power: for each slot type, each configured
-- tier whose threshold is met (so 4 matching => both the 3- and 4-tier apply).
function Augmentation.activeSetBonuses(slotsOnPower, config)
    local active = {}
    local counts = Augmentation.matchingCounts(slotsOnPower)
    local bonuses = config and config.set_bonuses or {}
    for slotType, count in pairs(counts) do
        for tier, amount in pairs(bonuses) do
            if count >= tier then
                table.insert(active, { type = slotType, tier = tier, amount = amount })
            end
        end
    end
    return active
end

return Augmentation
