--[[
    PetLockout (pure) — "a down should MATTER" (#179).

    When a pet is downed in combat it can't just be revived for free by re-teaming. The recovery is
    tracked at the pet's IDENTITY and persisted in the player's profile, so it survives rebuilding the
    PlayerPets models. Two mechanisms, matching the SSOT pet inventory (docs/PET_SYSTEM_ARCHITECTURE,
    docs/INVENTORY_STORAGE_TYPES):

      • SPECIAL pets (secret/exclusive — "huges") are UNIQUE, one-per-UUID. We lock that exact uid:
        a different huge of the same type is still deployable; the downed one is out for the lockout.
      • STACKED pets (normal/common) have no per-unit id — just a `quantity` per `<id:variant>` key.
        We can't lock "that one", so we lock by COUNT: each down adds a recovery timestamp to the
        stack key, reducing how many of that stack are deployable until it expires. Field a 15-bear
        stack, down 3, and 12 are still deployable while those 3 recover.

      • The SLOT the pet fell in is also locked (a shorter timer), so a stack can refill the slot with
        a sibling only once the slot frees.

    All times are os.time() epochs; durations come from configs/squad.lua (down_lockout /
    slot_recovery). Pure + immutable (returns new state) so it's unit-testable headless.
]]

local PetLockout = {}

local function norm(state)
    state = state or {}
    return {
        pets = state.pets or {}, -- [uid] = untilEpoch        (special, one per uid)
        stacks = state.stacks or {}, -- [stackKey] = { untilEpoch, ... }  (normal, one per downed unit)
        slots = state.slots or {}, -- [slotName] = untilEpoch   (the slot it fell in)
    }
end

function PetLockout.empty()
    return { pets = {}, stacks = {}, slots = {} }
end

local function shallow(t)
    local n = {}
    for k, v in pairs(t) do
        n[k] = v
    end
    return n
end

-- Record a downed pet. `entry` = { kind="special", uid=... } | { kind="stack", stackKey=... }, plus an
-- optional `slot`. cfg = { pet_lockout_seconds, slot_lock_seconds }. Returns a NEW state table.
function PetLockout.recordDown(state, entry, now, cfg)
    state = norm(state)
    cfg = cfg or {}
    entry = entry or {}
    local petUntil = now + (tonumber(cfg.pet_lockout_seconds) or 300)
    local slotUntil = now + (tonumber(cfg.slot_lock_seconds) or 60)
    local pets, stacks, slots = shallow(state.pets), shallow(state.stacks), shallow(state.slots)
    if entry.kind == "special" and entry.uid then
        pets[entry.uid] = petUntil -- the EXACT huge is out for the long pet lockout (5 min)
    elseif entry.kind == "stack" and entry.stackKey then
        -- STACK units are fungible: they recover with the SLOT (1 min), not the long pet lockout —
        -- after the slot frees you just re-summon a sibling from the stack.
        local list = {}
        for _, t in ipairs(state.stacks[entry.stackKey] or {}) do
            list[#list + 1] = t
        end
        list[#list + 1] = slotUntil
        stacks[entry.stackKey] = list
    end
    if entry.slot then
        slots[entry.slot] = slotUntil
    end
    return { pets = pets, stacks = stacks, slots = slots }
end

-- RELEASE a downed pet's locks — the mirror of recordDown, for POWERED revives (the Revive power,
-- Genie of the Dunes). Without this, PetRevive stands the pet up but the lockout enforcement pass
-- holds it right back down with the remaining clock ("back for a split second and then dead
-- again" — Jason, live 2026-07-02). Clears the special uid lock, ONE stack lock for the key (the
-- latest — units are fungible), and the slot lock. Returns a NEW state table.
function PetLockout.release(state, entry)
    state = norm(state)
    entry = entry or {}
    local pets, stacks, slots = shallow(state.pets), shallow(state.stacks), shallow(state.slots)
    if entry.kind == "special" and entry.uid then
        pets[entry.uid] = nil
    elseif entry.kind == "stack" and entry.stackKey then
        local list = {}
        local latestIdx, latest
        for i, t in ipairs(state.stacks[entry.stackKey] or {}) do
            list[i] = t
            if not latest or t > latest then
                latestIdx, latest = i, t
            end
        end
        if latestIdx then
            table.remove(list, latestIdx)
        end
        stacks[entry.stackKey] = (#list > 0) and list or nil
    end
    if entry.slot then
        slots[entry.slot] = nil
    end
    return { pets = pets, stacks = stacks, slots = slots }
end

-- # of stack units of `stackKey` still recovering at `now`.
function PetLockout.activeStackLocks(state, stackKey, now)
    local n = 0
    for _, t in ipairs(norm(state).stacks[stackKey] or {}) do
        if t > now then
            n = n + 1
        end
    end
    return n
end

function PetLockout.isPetLocked(state, uid, now)
    return (norm(state).pets[uid] or 0) > now
end

function PetLockout.isSlotLocked(state, slot, now)
    return (norm(state).slots[slot] or 0) > now
end

-- How many of a stack of `quantity` are deployable right now (quantity minus the recovering units).
function PetLockout.availableQuantity(state, stackKey, quantity, now)
    return math.max(
        0,
        (tonumber(quantity) or 0) - PetLockout.activeStackLocks(state, stackKey, now)
    )
end

-- The deploy gate for a pet ENTRY. entry = { kind="special", uid } | { kind="stack", stackKey, quantity }.
-- Returns { ok, reason, secondsLeft }.
function PetLockout.canDeploy(state, entry, now)
    state = norm(state)
    entry = entry or {}
    if entry.kind == "special" and entry.uid then
        local until_ = state.pets[entry.uid] or 0
        if until_ > now then
            return { ok = false, reason = "pet_recovering", secondsLeft = math.ceil(until_ - now) }
        end
    elseif entry.kind == "stack" and entry.stackKey then
        if PetLockout.availableQuantity(state, entry.stackKey, entry.quantity or 0, now) <= 0 then
            local soonest
            for _, t in ipairs(state.stacks[entry.stackKey] or {}) do
                if t > now and (not soonest or t < soonest) then
                    soonest = t
                end
            end
            return {
                ok = false,
                reason = "stack_recovering",
                secondsLeft = soonest and math.ceil(soonest - now) or nil,
            }
        end
    end
    return { ok = true }
end

-- Slot gate (separate so the caller can distinguish "slot still locked" from "pet still recovering").
function PetLockout.canUseSlot(state, slot, now)
    local until_ = norm(state).slots[slot] or 0
    if until_ > now then
        return { ok = false, reason = "slot_recovering", secondsLeft = math.ceil(until_ - now) }
    end
    return { ok = true }
end

-- Drop expired entries (call before persisting to keep the table small). Returns a NEW state.
function PetLockout.prune(state, now)
    state = norm(state)
    local pets, stacks, slots = {}, {}, {}
    for uid, t in pairs(state.pets) do
        if t > now then
            pets[uid] = t
        end
    end
    for key, list in pairs(state.stacks) do
        local kept = {}
        for _, t in ipairs(list) do
            if t > now then
                kept[#kept + 1] = t
            end
        end
        if #kept > 0 then
            stacks[key] = kept
        end
    end
    for slot, t in pairs(state.slots) do
        if t > now then
            slots[slot] = t
        end
    end
    return { pets = pets, stacks = stacks, slots = slots }
end

return PetLockout
