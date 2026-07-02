--[[
    SpiritForm (pure) — Feature 7.

    Deployability + state for unique pets based on a downed timestamp and the
    cooldown of the content tier where they fell. Heaven biomes halve the
    effective cooldown. Never mutates the input pet (returns new records).

    Pet record fields used: lastDownedAt (timestamp or nil), cooldown_seconds.
    Pure: standard Lua only; unit-tested via `mise run test-headless`.
]]

local SpiritForm = {}

SpiritForm.State = { Healthy = "Healthy", SpiritForm = "Spirit Form" }

local function copy(pet)
    local out = {}
    for k, v in pairs(pet) do
        out[k] = v
    end
    return out
end

-- Effective cooldown after the Heaven recharge bonus.
function SpiritForm.effectiveCooldown(cooldownSeconds, inHeaven, config)
    local mult = (inHeaven and config and config.heaven_recharge_multiplier) or 1
    if mult <= 0 then
        mult = 1
    end
    return (cooldownSeconds or 0) / mult
end

-- Cooldown for a content tier (0 if unknown).
function SpiritForm.cooldownForTier(tier, config)
    local tiers = (config and config.cooldown_tiers) or {}
    return tiers[tier] or 0
end

-- status(pet, now, inHeaven, config) -> { state, deployable, remaining }
function SpiritForm.status(pet, now, inHeaven, config)
    if pet.lastDownedAt == nil then
        return { state = SpiritForm.State.Healthy, deployable = true, remaining = 0 }
    end
    local cd = SpiritForm.effectiveCooldown(pet.cooldown_seconds or 0, inHeaven, config)
    local elapsed = now - pet.lastDownedAt
    if elapsed >= cd then
        return { state = SpiritForm.State.Healthy, deployable = true, remaining = 0 }
    end
    return { state = SpiritForm.State.SpiritForm, deployable = false, remaining = cd - elapsed }
end

-- Down a pet at `now` for `tier` content: sets lastDownedAt + cooldown_seconds.
function SpiritForm.down(pet, tier, now, config)
    local out = copy(pet)
    out.lastDownedAt = now
    out.cooldown_seconds = SpiritForm.cooldownForTier(tier, config)
    return out
end

-- Clear the cooldown (instant-recharge consumable).
function SpiritForm.instantRecharge(pet)
    local out = copy(pet)
    out.lastDownedAt = nil
    return out
end

return SpiritForm
