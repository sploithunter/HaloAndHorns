--[[
    EnhancementPricing — pure price math for the enhancement STORE (buy/sell naturals for gems).

    Naturals all share one magnitude (configs/enhancements.lua values.natural), so price is a pure
    function of LEVEL (flat across types). The store sells in fixed increments (level_step) and shows
    only the ONE band the player can currently SLOT — the nearest multiple of level_step, which is
    always within the slot window (±2), so e.g. L17 → L15, L18 → L20.

      EnhancementPricing.value(grade, level, cfg)         -> number   (canonical gem value, unfloored)
      EnhancementPricing.bandFor(playerLevel, cfg)        -> number   (the buyable band)
      EnhancementPricing.buyPrice(grade, level, cfg)      -> number   (gems; value floored)
      EnhancementPricing.sellPrice(grade, level, cfg)     -> number   (gems; value × sell fraction)

    BUY is offered only at band levels (multiples of level_step) and only for buyable grades, but SELL
    works at the item's ACTUAL level (smooth — L14 sells for more than L13) and for ANY grade the
    player owns. Grade price scales by `grade_mult` (rarity-derived: rarer drop = pricier), so single
    and dual have a real buyback value even though they aren't sold yet.

    cfg = configs/enhancements.lua `shop` block. Pure (no Roblox APIs) → headless-testable.
]]

local EnhancementPricing = {}

local function clamp(x, lo, hi)
    if x < lo then
        return lo
    elseif x > hi then
        return hi
    end
    return x
end

-- The single slottable band shown to a player: the nearest multiple of `level_step`, clamped to
-- [min_level, max_level]. Every integer is <= step/2 from its nearest multiple, and with step 5 that
-- is <= 2 — i.e. always inside the ±2 slot window, so the shown band is always slottable.
function EnhancementPricing.bandFor(playerLevel, cfg)
    cfg = cfg or {}
    local step = tonumber(cfg.level_step) or 5
    if step < 1 then
        step = 1
    end
    local lvl = math.floor(tonumber(playerLevel) or 1)
    if lvl < 1 then
        lvl = 1
    end
    local band = math.floor(lvl / step + 0.5) * step
    local minL = tonumber(cfg.min_level) or step
    local maxL = tonumber(cfg.max_level) or 50
    return clamp(band, minL, maxL)
end

-- Canonical (unfloored) gem value of an enhancement: (base + per_level * level) * grade_mult[grade].
-- `level` is the ACTUAL enhancement level (smooth), so value rises every level — buy snaps it to a
-- band, sell reads it raw. grade_mult defaults to 1 for unknown grades.
function EnhancementPricing.value(grade, level, cfg)
    cfg = cfg or {}
    local buy = cfg.buy or {}
    local base = tonumber(buy.base) or 0
    local per = tonumber(buy.per_level) or 0
    local mult = (cfg.grade_mult and tonumber(cfg.grade_mult[grade])) or 1
    local lvl = math.floor(tonumber(level) or 0)
    if lvl < 0 then
        lvl = 0
    end
    local v = (base + per * lvl) * mult
    if v < 0 then
        v = 0
    end
    return v
end

-- Gems to BUY one enhancement of `grade` at `level` (a band level for naturals): value, floored.
function EnhancementPricing.buyPrice(grade, level, cfg)
    return math.floor(EnhancementPricing.value(grade, level, cfg))
end

-- Gems refunded when SELLING one back: value × sell fraction, floored — at the item's ACTUAL level
-- (smooth per-level: L14 > L13) and any grade. Fraction clamped to [0,1] so a sell can never beat the
-- buy (no arbitrage — it is a junk sink).
function EnhancementPricing.sellPrice(grade, level, cfg)
    cfg = cfg or {}
    local frac = (cfg.sell and tonumber(cfg.sell.fraction)) or 0
    frac = clamp(frac, 0, 1)
    return math.floor(EnhancementPricing.value(grade, level, cfg) * frac)
end

-- Grade from an enhancement's origins list: 0 origins = natural, 1 = single, 2+ = dual. This is the
-- grade key into grade_mult — the SELL path reads it off the owned stack so single/dual buy back too.
function EnhancementPricing.gradeFromOrigins(origins)
    local n = (type(origins) == "table") and #origins or 0
    if n <= 0 then
        return "natural"
    elseif n == 1 then
        return "single"
    end
    return "dual"
end

-- The buyable catalog for a player: ONE band (their slottable multiple-of-step) × each buyable grade
-- × each non-excluded type. `typeKeys` is an array of type-name strings (configs/enhancements.lua
-- types keys). Returns { band = number, offers = { {type, grade, level, price}, ... } }.
function EnhancementPricing.catalog(playerLevel, typeKeys, cfg)
    cfg = cfg or {}
    local band = EnhancementPricing.bandFor(playerLevel, cfg)
    local exclude = cfg.exclude_types or {}
    local grades = cfg.buyable_grades or { "natural" }
    local offers = {}
    for _, grade in ipairs(grades) do
        for _, t in ipairs(typeKeys or {}) do
            if not exclude[t] then
                offers[#offers + 1] = {
                    type = t,
                    grade = grade,
                    level = band,
                    price = EnhancementPricing.buyPrice(grade, band, cfg),
                }
            end
        end
    end
    return { band = band, offers = offers }
end

-- Does the player's origin match one of this enhancement's origins? Inlined here so the pricing core
-- stays dependency-free (mirrors Enhancements.usableBy for the dual case — a dual is slottable only if
-- one of its two origins is the player's archetype).
local function originMatches(origins, archetype)
    for _, o in ipairs(origins or {}) do
        if o == archetype then
            return true
        end
    end
    return false
end

-- Categorize a player's enhancement STACKS for the bulk "Sell Junk" sweep. `stacks` = array of
-- { uid, origins, level, quantity }. Returns:
--   { naturals = {items, count, gems}, duals = {items, count, gems} }
-- where each item = {uid, grade, level, quantity, unit, gems}. Buckets:
--   • naturals — DEAD naturals (more than `dead_window` below the player; contribute nothing).
--   • duals    — duals that are junk TO THIS PLAYER: DEAD (outgrown) OR WRONG-ORIGIN (neither origin
--                is the player's archetype, so it can NEVER be slotted — Jason). Usable+alive duals are
--                kept. This whole bucket is gated behind the player's "include duals" checkbox.
--   • singles  — never swept (protected: rare + tradeable).
-- `opts.playerArchetype` = the player's origin (data.Archetype). Pure: the service executes the plan.
function EnhancementPricing.junkSweep(stacks, playerLevel, cfg, opts)
    cfg = cfg or {}
    opts = opts or {}
    local archetype = opts.playerArchetype
    local window = (cfg.bulk and tonumber(cfg.bulk.dead_window)) or 2
    local nat = { items = {}, count = 0, gems = 0 }
    local dual = { items = {}, count = 0, gems = 0 }
    for _, s in ipairs(stacks or {}) do
        local grade = EnhancementPricing.gradeFromOrigins(s.origins)
        local level = tonumber(s.level) or 0
        local qty = math.max(0, math.floor(tonumber(s.quantity) or 0))
        if qty > 0 and grade ~= "single" then
            local dead = level < ((tonumber(playerLevel) or 1) - window)
            local bucket, include
            if grade == "natural" then
                bucket, include = nat, dead
            else -- dual: dead OR wrong-origin (never slottable by this player)
                bucket, include = dual, (dead or not originMatches(s.origins, archetype))
            end
            if include then
                local unit = EnhancementPricing.sellPrice(grade, level, cfg)
                local g = unit * qty
                bucket.items[#bucket.items + 1] = {
                    uid = s.uid,
                    grade = grade,
                    level = level,
                    quantity = qty,
                    unit = unit,
                    gems = g,
                }
                bucket.count += qty
                bucket.gems += g
            end
        end
    end
    return { naturals = nat, duals = dual }
end

return EnhancementPricing
