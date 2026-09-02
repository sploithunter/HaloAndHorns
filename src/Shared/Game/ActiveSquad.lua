--[[
    ActiveSquad (pure) — Feature 9.

    Rules for the active fighting squad: a max size, and an in-combat swap
    cooldown (out of combat, swaps are instant). A stacked pet occupies one slot
    regardless of its count. Never mutates input; the service applies the result.

    Pure: standard Lua only; unit-tested via `mise run test-headless`.
]]

local ActiveSquad = {}

-- Whether another pet can be deployed given the current squad size.
function ActiveSquad.canDeploy(currentSize, maxSize)
    if currentSize >= maxSize then
        return { ok = false, reason = "active_squad_full" }
    end
    return { ok = true }
end

-- Whether a swap is allowed now. Out of combat: always. In combat: only once the
-- swap cooldown has elapsed (returns remaining time when blocked).
function ActiveSquad.canSwap(inCombat, lastSwapAt, now, cooldown)
    if not inCombat or lastSwapAt == nil then
        return { ok = true }
    end
    local elapsed = now - lastSwapAt
    if elapsed >= cooldown then
        return { ok = true }
    end
    return { ok = false, reason = "swap_cooldown_active", remaining = cooldown - elapsed }
end

-- ===== Slot recovery (the player-managed timer) =====
-- A squad slot is a crew position: when its pet leaves, the SLOT recharges before it
-- can be re-crewed. This paces throughput independent of stack depth (1000 pets can't
-- be spammed). A proactive RECALL leaves a short cooldown; a forced DOWN, a long one.

function ActiveSquad.slotCooldownSeconds(reason, config)
    local sr = (config and config.slot_recovery) or {}
    if reason == "recall" then
        return sr.recall_cooldown_seconds or 4
    end
    return sr.down_cooldown_seconds or 20 -- "down" (default) = the long cost
end

-- Apply a place-owned recovery override without mutating either source table. Callers can keep the
-- canonical squad config for every other rule while a dedicated place replaces only its recovery
-- cadence. Nested recovery tables are merged so an omitted recall value keeps the shared default.
function ActiveSquad.withRecoveryOverride(config, override)
    local resolved = {}
    for key, value in pairs(config or {}) do
        resolved[key] = value
    end
    for key, value in pairs(override or {}) do
        if key ~= "slot_recovery" and key ~= "down_lockout" then
            resolved[key] = value
        end
    end
    for _, key in ipairs({ "slot_recovery", "down_lockout" }) do
        local merged = {}
        for field, value in pairs((config and config[key]) or {}) do
            merged[field] = value
        end
        for field, value in pairs((override and override[key]) or {}) do
            merged[field] = value
        end
        resolved[key] = merged
    end
    return resolved
end

-- A normal pet is unavailable only for the slot timer. A special identity (currently Huge pets)
-- also observes its longer identity lock after a forced down. Recall is never an identity lock.
function ActiveSquad.petUnavailableSeconds(reason, config, special)
    local slotSeconds = ActiveSquad.slotCooldownSeconds(reason, config)
    if reason == "recall" or special ~= true then
        return slotSeconds
    end
    local downLockout = (config and config.down_lockout) or {}
    return math.max(slotSeconds, tonumber(downLockout.pet_lockout_seconds) or slotSeconds)
end

-- A slot can be re-crewed once its cooldown has elapsed (nil cooldown = ready).
function ActiveSquad.slotReady(cooldownUntil, now)
    return cooldownUntil == nil or now >= cooldownUntil
end

-- Summon is allowed only when the slot is off cooldown AND a ready instance exists
-- (stack ready_count > 0, or a unique past its spirit-form cooldown). Gauntlets
-- (`noRevive`) refuse resummon for the rest of the run — no timer, no Ready.
function ActiveSquad.canSummon(slotReady, hasReadyInstance, noRevive)
    if noRevive then
        return { ok = false, reason = "gauntlet_no_revive" }
    end
    if not slotReady then
        return { ok = false, reason = "slot_recharging" }
    end
    if not hasReadyInstance then
        return { ok = false, reason = "no_ready_instance" }
    end
    return { ok = true }
end

-- Place-owned automatic recovery uses the same availability deadline as manual Summon. The
-- gauntlet contract always wins, even if a place enables automatic recovery.
function ActiveSquad.shouldAutoSummon(downed, unavailableUntil, now, config, noRevive)
    return (config and config.auto_summon_on_recovery) == true
        and downed == true
        and noRevive ~= true
        and ActiveSquad.slotReady(unavailableUntil, now)
end

return ActiveSquad
