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

-- A slot can be re-crewed once its cooldown has elapsed (nil cooldown = ready).
function ActiveSquad.slotReady(cooldownUntil, now)
    return cooldownUntil == nil or now >= cooldownUntil
end

-- Summon is allowed only when the slot is off cooldown AND a ready instance exists
-- (stack ready_count > 0, or a unique past its spirit-form cooldown).
function ActiveSquad.canSummon(slotReady, hasReadyInstance)
    if not slotReady then
        return { ok = false, reason = "slot_recharging" }
    end
    if not hasReadyInstance then
        return { ok = false, reason = "no_ready_instance" }
    end
    return { ok = true }
end

return ActiveSquad
