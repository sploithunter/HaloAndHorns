--[[
    PetPower — single source of truth for a pet's CONFIGURED BASE power.

    Both the server (PetHandler team-power / mining) and the client (inventory
    display) call this, so the number shown and the number that fights can never
    diverge again. Huge-aware: a huge pet uses `huge_base_power` (e.g. bear 100)
    instead of its variant `power` (bear 10).

    Eternal team-scaling (power = % of the top-N non-eternal baseline) is layered
    on TOP of this, server-side, where team context exists — see PetHandler
    resolveEffectivePetPower. This module is purely the per-pet base.

    No Roblox APIs (pure); headless-tested.

      configuredBasePower(petConfigData, isHuge)            -> number
      withLevel(base, level, progressionConfig)             -> integer
      basePowerForLevel(petConfigData, isHuge, level, prog) -> integer (compose)
]]

local PetPower = {}

-- petConfigData is the table returned by configs/pets.lua getPet(petType, variant)
-- (it carries `power` and, when configured, `huge_base_power`).
function PetPower.configuredBasePower(petConfigData, isHuge)
    if not petConfigData then
        return 1
    end
    if isHuge then
        local hugeBase = tonumber(petConfigData.huge_base_power)
        if hugeBase then
            return hugeBase
        end
    end
    return tonumber(petConfigData.power) or 1
end

-- Max pet level for a rarity (configs/pet_progression.lua max_level_by_rarity).
function PetPower.maxLevelForRarity(rarityId, progressionConfig)
    if not progressionConfig then
        return 1
    end
    local byRarity = progressionConfig.max_level_by_rarity
    local maxLevel = (rarityId and type(byRarity) == "table" and tonumber(byRarity[rarityId]))
        or tonumber(progressionConfig.default_max_level)
        or 1
    return math.max(1, math.floor(maxLevel))
end

-- Apply the shared level-progression multiplier (configs/pet_progression.lua).
-- NORMALIZED-CAP form (Jason: "we only have to set a cap... it's just scaled"):
--   multiplier = 1 + max_bonus_percent x (level-1)/(maxLevel-1)
-- Every pet spends its full arc earning the same cap, whatever its max level —
-- a 100-level huge gains ~1%/level toward +100%, a 50-level secret ~2%/level.
function PetPower.withLevel(base, level, progressionConfig, maxLevel)
    local multiplier = 1
    if progressionConfig and progressionConfig.enabled ~= false then
        local scaling = progressionConfig.power_scaling or {}
        local maxBonus = tonumber(scaling.max_bonus_percent) or 0
        local lvl = math.max(1, math.floor(tonumber(level) or 1))
        local cap = math.max(1, math.floor(tonumber(maxLevel) or 0))
        if cap <= 1 then
            cap = math.max(1, math.floor(tonumber(progressionConfig.default_max_level) or 1))
        end
        if maxBonus > 0 and cap > 1 then
            local fraction = math.clamp((lvl - 1) / (cap - 1), 0, 1)
            multiplier = 1 + maxBonus * fraction
        end
    end
    return math.max(1, math.floor((tonumber(base) or 1) * multiplier))
end

function PetPower.basePowerForLevel(petConfigData, isHuge, level, progressionConfig)
    local rarityId = petConfigData
        and (petConfigData.rarity_id or petConfigData.rarity_override or petConfigData.rarity)
    return PetPower.withLevel(
        PetPower.configuredBasePower(petConfigData, isHuge),
        level,
        progressionConfig,
        PetPower.maxLevelForRarity(rarityId, progressionConfig)
    )
end

-- === Mining/Combat power profile (Pet Realm "two numbers on the card") ===
-- Splits a pet's resolved base power (the huge/level-aware number above, i.e. its Power value)
-- into the two INTRINSIC card numbers (⛏ mining / ⚔ combat) and their live EFFECTIVE values.
-- One function for both the inventory display and the damage path (via PetPowerView), so the
-- shown number can never drift from the dealt number. Adding a future multiplier = add a key to
-- `context`; display + damage update together.
--
--   input = {
--     base,           -- resolved base power (Power value: dev base × huge × pet level)
--     baseScale?,     -- global lever (config base_scale; default 1)
--     elementMult?,   -- intrinsic element flat attack (combat_fx element_stats; default 1)
--     variantMult?,   -- intrinsic golden/rainbow bump (pet_power.variant_mult; default 1)
--     miningMult?,    -- intrinsic mining aptitude (role/pet; default 1)
--     combatMult?,    -- intrinsic combat aptitude (role/pet; default 1)
--     context = { lvl = m, boost = m, ... }  -- contextual multipliers (player), all default 1
--   }
local function num(v, default)
    return tonumber(v) or default
end

function PetPower.resolveProfile(input)
    input = input or {}
    -- Hard ceiling (config max_pet_power). Default huge so omitting it = no clamp (live-neutral).
    -- The Creator-class apex sits at this value; NOTHING resolves above it.
    local maxPower = num(input.maxPower, math.huge)
    local function cap(x)
        return math.min(x, maxPower)
    end
    -- CREATOR pets ARE the apex (Jason): pinned to max_pet_power — nothing can ever
    -- be stronger, and the ceiling doubles as the top anchor of the whole curve.
    if input.creator == true then
        local apex = num(input.maxPower, math.huge)
        return {
            base = apex,
            intrinsicCommon = apex,
            miningBase = apex,
            combatBase = apex,
            contextMult = 1,
            miningEffective = apex,
            combatEffective = apex,
        }
    end
    -- shinyMult: the 5th pet axis — a flat cosmetic multiplier, power-neutral by default (1.0).
    local base = num(input.base, 0) * num(input.baseScale, 1)
    local intrinsicCommon = base
        * num(input.elementMult, 1)
        * num(input.variantMult, 1)
        * num(input.shinyMult, 1)
    local miningBase = intrinsicCommon * num(input.miningMult, 1)
    local combatBase = intrinsicCommon * num(input.combatMult, 1)

    local contextMult = 1
    if type(input.context) == "table" then
        for _, v in pairs(input.context) do
            contextMult = contextMult * num(v, 1)
        end
    end

    return {
        base = cap(base),
        intrinsicCommon = cap(intrinsicCommon),
        miningBase = cap(miningBase),
        combatBase = cap(combatBase),
        contextMult = contextMult,
        miningEffective = cap(miningBase * contextMult),
        combatEffective = cap(combatBase * contextMult),
    }
end

-- Bounded geometric tier ladder (the "pets are stars" curve). tierBase(tier) =
-- starter_base * step^(tier-1), clamped to the ceiling. Pure; pet definitions adopt tiers at the
-- balance pass. `powerConfig` = configs/pet_power.lua (reads tier_curve + max_pet_power).
function PetPower.tierBase(tier, powerConfig)
    powerConfig = powerConfig or {}
    local tc = powerConfig.tier_curve or {}
    local starter = num(tc.starter_base, 1000)
    local step = num(tc.step, 1.4)
    local maxPower = num(powerConfig.max_pet_power, math.huge)
    tier = math.max(1, math.floor(num(tier, 1)))
    return math.min(starter * step ^ (tier - 1), maxPower)
end

-- Round a power number for DISPLAY only (damage keeps its own floor in PetCombat).
function PetPower.roundForDisplay(n, mode)
    n = num(n, 0)
    if mode == "floor" then
        return math.floor(n)
    elseif mode == "ceil" then
        return math.ceil(n)
    end
    return math.floor(n + 0.5)
end

return PetPower
