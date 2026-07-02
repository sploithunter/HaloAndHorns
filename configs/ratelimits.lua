-- Rate Limiting Configuration
-- Defines base rates, effect modifiers, and anti-exploit measures

return {
    -- Base rate limits per action (requests per minute)
    baseRates = {
        PurchaseItem = 30, -- 30 purchases per minute
        SellItem = 60, -- 60 sells per minute
        GetShopItems = 10, -- 10 shop refreshes per minute
        DealDamage = 120, -- 120 attacks per minute (2 per second)
        CollectResource = 180, -- 180 collections per minute (3 per second)
        UseItem = 60, -- 60 item uses per minute
        Chat = 30, -- 30 chat messages per minute
        Trade = 5, -- 5 trade requests per minute
    },

    -- Effect-based rate modifiers
    -- These can be applied by potions, passes, or special items
    effectModifiers = {
        -- Speed-based effects
        speed_boost = {
            actions = { "CollectResource", "DealDamage" },
            multiplier = 1.5, -- 50% faster
            duration = 300, -- 5 minutes
            maxUses = 20, -- OR 20 uses, whichever comes first
            consumeOnUse = true,
            description = "Increases action speed by 50% for 5 minutes or 20 uses",
            displayName = "⚡ Speed Boost",
            icon = "⚡",
            stacking = "extend_duration", -- resets timer by adding duration instead of overwrite
            statModifiers = {
                speedMultiplier = 0.5, -- +50% speed boost
                luckBoost = 0.1, -- +10% luck as bonus
            },
        },

        premium_speed = {
            actions = { "PurchaseItem", "SellItem", "CollectResource" },
            multiplier = 2.0, -- 100% faster (double speed)
            duration = 1800, -- 30 minutes
            maxUses = 50, -- OR 50 uses
            consumeOnUse = true,
            description = "Premium pass: Double action speed for 30 minutes or 50 uses",
        },

        combat_frenzy = {
            actions = { "DealDamage" },
            multiplier = 3.0, -- 200% faster (triple speed)
            duration = 120, -- 2 minutes
            maxUses = 15, -- OR 15 attacks
            consumeOnUse = true,
            description = "Combat frenzy potion: Triple attack speed for 2 minutes or 15 attacks",
        },

        trader_blessing = {
            actions = { "PurchaseItem", "SellItem", "Trade" },
            multiplier = 1.25, -- 25% faster
            duration = 600, -- 10 minutes
            maxUses = 30, -- OR 30 trades
            consumeOnUse = true,
            description = "Trader blessing: 25% faster trading for 10 minutes or 30 trades",
            displayName = "📜 Trader Blessing",
            icon = "📜",
            statModifiers = {
                speedMultiplier = 0.25, -- +25% speed boost
                luckBoost = 0.05, -- +5% luck as bonus
            },
        },

        -- VIP/Premium effects (permanent)
        vip_pass = {
            actions = { "PurchaseItem", "SellItem", "GetShopItems", "UseItem" },
            multiplier = 1.5,
            duration = -1, -- Permanent (no time limit)
            maxUses = -1, -- Unlimited uses
            consumeOnUse = false,
            description = "VIP Pass: Permanent 50% faster economy actions",
            displayName = "💎 VIP Pass",
            icon = "💎",
        },

        -- Global server-wide effects
        global_xp_weekend = {
            actions = {}, -- No specific actions, affects global XP
            multiplier = 1.0,
            duration = 172800, -- 48 hours (weekend)
            maxUses = -1,
            consumeOnUse = false,
            description = "Double XP Weekend: +100% experience gain for all players",
            displayName = "🎉 Double XP Weekend",
            icon = "🎉",
            stacking = "extend_duration",
            statModifiers = {
                globalXPMultiplier = 1.0, -- +100% XP (2x total)
                globalLuckBoost = 0.1, -- +10% luck bonus too
            },
        },

        global_speed_hour = {
            actions = { "CollectResource", "DealDamage" },
            multiplier = 2.0, -- 2x speed for actions
            duration = 3600, -- 1 hour
            maxUses = -1,
            consumeOnUse = false,
            description = "Speed Hour: Double action speed for all players",
            displayName = "⚡ Speed Hour",
            icon = "⚡",
            stacking = "extend_duration",
            statModifiers = {
                globalSpeedMultiplier = 1.0, -- +100% speed (2x total)
                globalDropRateBoost = 0.05, -- +5% drop rate bonus
            },
        },

        global_luck_boost = {
            actions = {},
            multiplier = 1.0,
            duration = 7200, -- 2 hours
            maxUses = -1,
            consumeOnUse = false,
            description = "Global Luck Boost: Increased rare item drops for all players",
            displayName = "🍀 Global Luck Boost",
            icon = "🍀",
            stacking = "extend_duration",
            statModifiers = {
                globalLuckBoost = 0.25, -- +25% luck
                globalDropRateBoost = 0.15, -- +15% drop rate
            },
        },
    },

    -- Anti-exploit measures
    antiExploit = {
        -- Maximum possible rate limit (even with all effects)
        absoluteMaxRates = {
            PurchaseItem = 120, -- Never more than 2 purchases per second
            SellItem = 240, -- Never more than 4 sells per second
            DealDamage = 600, -- Never more than 10 attacks per second
            CollectResource = 600, -- Never more than 10 collections per second
            GetShopItems = 30, -- Never more than 30 shop refreshes per minute
            UseItem = 180, -- Never more than 3 item uses per second
            Chat = 60, -- Never more than 60 chat messages per minute
            Trade = 15, -- Never more than 15 trades per minute
        },

        -- Burst protection (short-term rate limiting)
        burstProtection = {
            windowSize = 10, -- 10 second window
            maxBurstRates = {
                PurchaseItem = 10, -- Max 10 purchases in 10 seconds
                SellItem = 20, -- Max 20 sells in 10 seconds
                DealDamage = 50, -- Max 50 attacks in 10 seconds
                CollectResource = 50, -- Max 50 collections in 10 seconds
            },
        },

        -- Escalating punishment for rate limit violations
        punishment = {
            warningThreshold = 3, -- Warnings after 3 violations
            kickThreshold = 10, -- Kick after 10 violations
            banThreshold = 25, -- Temporary ban after 25 violations
            escalationWindow = 300, -- 5 minute window for violation counting
        },
    },

    -- Effect stacking rules
    effectStacking = {
        maxStackedEffects = 3, -- Maximum 3 effects can stack
        stackingMode = "multiply", -- "multiply", "add", or "best"
        diminishingReturns = true, -- Apply diminishing returns to stacked effects
        diminishingFactor = 0.8, -- Each additional effect is 80% as effective
    },
}
