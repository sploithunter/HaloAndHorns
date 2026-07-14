--[[
    EffectiveStats (pure) — THE per-axis buff source registry.

    Jason's SSOT doctrine (2026-07-14, magnet-display drift): every derived
    player stat has ONE formula, defined HERE and nowhere else. Three kinds of
    consumer, all reading THIS module:

      1. EffectiveStatsService (server) computes each axis and PUBLISHES it as
         a player attribute (Eff_<Axis>); it also re-publishes when a timed
         source expires.
      2. Gameplay fold sites (BreakableSpawner coin/mining, PetFollowService
         pet swings, PlayerProgressionService XP, PowerService recharge…)
         build their stacks via sources()/multiplier() — sites with extra
         per-entity or per-team terms APPEND to the shared list, so the
         player-level portion can never drift from the published number.
      3. UI (BuffStatsHud) displays the PUBLISHED attribute verbatim — no
         formula client-side, ever.

    Each axis entry:
      attr     — the published attribute name (Eff_<x>)
      watch    — every player attribute that can change the result (the
                 publisher subscribes to these)
      sources(get) — builds the BuffStack source list from an attribute
                 getter `get(name) -> value`. Pure: no Roblox APIs.

    Fraction conventions per source mirror the original fold sites exactly:
    "*Buff" multiplier attrs contribute (v - 1); raw-fraction attrs (powers /
    potions / enchant totals) contribute v directly.
]]

local BuffStack = require(script.Parent.BuffStack)

local EffectiveStats = {}

local function mult(get, name)
    return (tonumber(get(name)) or 1) - 1
end

local function frac(get, name)
    return tonumber(get(name)) or 0
end

EffectiveStats.AXES = {
    pet_damage = {
        attr = "Eff_Attack",
        watch = {
            "PetDamageBuff",
            "PetDamageBuffUntil",
            "PetTeamDamageBuff",
            "PetTeamDamageBuffUntil",
            "PetDamageBuffPotion",
            "PetDamageBuffPotionUntil",
        },
        sources = function(get)
            return {
                { fraction = mult(get, "PetDamageBuff"), expiry = frac(get, "PetDamageBuffUntil") },
                {
                    fraction = mult(get, "PetTeamDamageBuff"),
                    expiry = frac(get, "PetTeamDamageBuffUntil"),
                },
                {
                    fraction = frac(get, "PetDamageBuffPotion"),
                    expiry = frac(get, "PetDamageBuffPotionUntil"),
                },
            }
        end,
    },
    coin_yield = {
        attr = "Eff_Coin",
        watch = {
            "CoinYieldBuff",
            "CoinYieldBuffUntil",
            "CoinYieldPower",
            "CoinYieldPowerUntil",
            "EnchantCoinBonus",
        },
        sources = function(get)
            return {
                { fraction = mult(get, "CoinYieldBuff"), expiry = frac(get, "CoinYieldBuffUntil") },
                {
                    fraction = frac(get, "CoinYieldPower"),
                    expiry = frac(get, "CoinYieldPowerUntil"),
                },
                -- NOTE: EnchantCoinBonus is NOT in this stack — it folds into
                -- payouts via the breakable_reward MODIFIER PIPELINE. The
                -- publisher composes pipeline x stack for Eff_Coin (it's in
                -- `watch` purely as a republish trigger).
            }
        end,
    },
    mining = {
        attr = "Eff_Mining",
        watch = { "MiningBuff", "MiningBuffUntil" },
        sources = function(get)
            return {
                { fraction = frac(get, "MiningBuff"), expiry = frac(get, "MiningBuffUntil") },
            }
        end,
    },
    luck = {
        attr = "Eff_Luck",
        watch = {
            "LuckBuff",
            "LuckBuffUntil",
            "LuckBuffPotion",
            "LuckBuffPotionUntil",
            "HatchLuckBuff",
            "HatchLuckBuffUntil",
        },
        sources = function(get)
            return {
                { fraction = frac(get, "LuckBuff"), expiry = frac(get, "LuckBuffUntil") },
                {
                    fraction = frac(get, "LuckBuffPotion"),
                    expiry = frac(get, "LuckBuffPotionUntil"),
                },
                {
                    fraction = math.max(0, mult(get, "HatchLuckBuff")),
                    expiry = frac(get, "HatchLuckBuffUntil"),
                },
            }
        end,
    },
    move_speed = {
        attr = "Eff_Speed",
        watch = {
            "MoveSpeedBuff",
            "MoveSpeedBuffUntil",
            "MoveSpeedBuffPotion",
            "MoveSpeedBuffPotionUntil",
        },
        sources = function(get)
            return {
                { fraction = frac(get, "MoveSpeedBuff"), expiry = frac(get, "MoveSpeedBuffUntil") },
                {
                    fraction = frac(get, "MoveSpeedBuffPotion"),
                    expiry = frac(get, "MoveSpeedBuffPotionUntil"),
                },
            }
        end,
    },
    recharge = {
        attr = "Eff_Recharge",
        watch = { "RechargeBuff", "RechargeBuffUntil", "RechargeAura", "RechargeAuraUntil" },
        -- recharge is a CLAMPED FRACTION (cooldown reduction), not a BuffStack
        -- multiplier — computed in fraction() below; sources kept for symmetry.
        sources = function(get)
            return {
                { fraction = frac(get, "RechargeBuff"), expiry = frac(get, "RechargeBuffUntil") },
            }
        end,
    },
    xp = {
        attr = "Eff_XP",
        watch = { "XpBuff", "XpBuffUntil" },
        sources = function(get)
            return {
                { fraction = frac(get, "XpBuff"), expiry = frac(get, "XpBuffUntil") },
            }
        end,
    },
}

-- The recharge clamp mirrors PowerService's cooldown fold (RECHARGE_CLAMP).
EffectiveStats.RECHARGE_CLAMP = 0.9

-- Fold an axis for an attribute getter. `axisCfg` = configs/buffs.lua axes
-- entry (caps); `extraSources` lets a fold site append per-entity/per-team
-- terms (rage, empower, teammate shares) UNDER THE SAME CAP — the shared
-- player-level portion stays identical to the published number's inputs.
function EffectiveStats.multiplier(axisId, get, now, axisCfg, extraSources)
    local def = EffectiveStats.AXES[axisId]
    if not def then
        return 1
    end
    local sources = def.sources(get)
    for _, s in ipairs(extraSources or {}) do
        sources[#sources + 1] = s
    end
    return BuffStack.multiplier(sources, now, axisCfg)
end

-- Recharge's clamped-fraction semantics (shown as -N% CD; folds as a
-- cooldown divisor in PowerService).
function EffectiveStats.rechargeFraction(get, now)
    -- power buff + EMBER TEMPO aura (Ashwing): separate additive channels
    -- summed under one clamp — mirrors (now OWNS) PowerService's fold. The
    -- old HUD mirror missed the aura channel entirely (drift find 2026-07-14).
    local total = 0
    if (tonumber(get("RechargeBuffUntil")) or 0) > now then
        total += math.max(tonumber(get("RechargeBuff")) or 0, 0)
    end
    if (tonumber(get("RechargeAuraUntil")) or 0) > now then
        total += math.max(tonumber(get("RechargeAura")) or 0, 0)
    end
    return math.clamp(total, 0, EffectiveStats.RECHARGE_CLAMP)
end

-- Soonest FUTURE expiry across an axis's timed sources (for the publisher's
-- re-publish scheduling). nil = nothing pending.
function EffectiveStats.nextExpiry(axisId, get, now)
    local def = EffectiveStats.AXES[axisId]
    if not def then
        return nil
    end
    local soonest
    for _, name in ipairs(def.watch) do
        if name:sub(-5) == "Until" then
            local t = tonumber(get(name)) or 0
            if t > now and (not soonest or t < soonest) then
                soonest = t
            end
        end
    end
    return soonest
end

return EffectiveStats
