--[[
    RewardBundle — pure functional core for the reward spine (Phase 7).

    A reward bundle is the universal "what you get" — the single declarative shape
    that quests, daily streaks, shop offers, and achievements all terminate in. No
    Roblox APIs; RewardService applies a normalized bundle to a live player.

    Shape (every field optional):
      {
        currencies = { lava_coins = 500, light_tokens = 2 },
        pets       = { { id = "bear", variant = "golden", element = "light" } },
        items      = { { id = "health_potion", qty = 3, bucket = "consumables" } },
        effects    = { { id = "speed_boost", seconds = 600, modifiers = {...} } },
        slots      = { pet_equip_slots = 1 },   -- permanent capacity (upgrade levels)
      }
]]

local RewardBundle = {}

local function copyList(list)
    local out = {}
    for _, v in ipairs(list or {}) do
        table.insert(out, v)
    end
    return out
end

local function copyMap(map)
    local out = {}
    for k, v in pairs(map or {}) do
        out[k] = v
    end
    return out
end

-- Return a bundle with every section present (so consumers never nil-check).
function RewardBundle.normalize(bundle)
    bundle = bundle or {}
    return {
        currencies = copyMap(bundle.currencies),
        pets = copyList(bundle.pets),
        items = copyList(bundle.items),
        effects = copyList(bundle.effects),
        slots = copyMap(bundle.slots),
        experience = tonumber(bundle.experience) or 0,
    }
end

-- Combine two bundles (currencies/slots sum; pets/items/effects concatenate).
-- Used e.g. to roll a daily streak's day 1..N into a single claim.
function RewardBundle.merge(a, b)
    local out = RewardBundle.normalize(a)
    local nb = RewardBundle.normalize(b)
    for currency, amount in pairs(nb.currencies) do
        out.currencies[currency] = (out.currencies[currency] or 0) + amount
    end
    for slot, amount in pairs(nb.slots) do
        out.slots[slot] = (out.slots[slot] or 0) + amount
    end
    for _, p in ipairs(nb.pets) do
        table.insert(out.pets, p)
    end
    for _, i in ipairs(nb.items) do
        table.insert(out.items, i)
    end
    for _, e in ipairs(nb.effects) do
        table.insert(out.effects, e)
    end
    out.experience = (out.experience or 0) + (nb.experience or 0)
    return out
end

function RewardBundle.isEmpty(bundle)
    local n = RewardBundle.normalize(bundle)
    return next(n.currencies) == nil
        and #n.pets == 0
        and #n.items == 0
        and #n.effects == 0
        and next(n.slots) == nil
        and (n.experience or 0) == 0
end

return RewardBundle
