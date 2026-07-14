-- Monetization Configuration — THE RATING-SAFE CATALOG
--
-- THE ONE RULE (Jason 2026-07-09, after the paid-item-trading declaration cost
-- the game a 16+ label): everything sold for Robux must be DETERMINISTIC,
-- UNTRADEABLE, and NEVER a currency that can reach eggs or the trade window.
-- The two rating traps are CHAINS, not items:
--   Robux -> any currency -> egg          = Paid Random Items (odds disclosure)
--   Robux -> anything tradeable            = Paid Item Trading (the 16+ hammer)
-- Removed accordingly (2026-07-09): gem packs (gems are TRADEABLE), the
-- starter pack (granted gems + coins; coins reach eggs), and every daily
-- CURRENCY grant on passes/premium. Earning-rate MULTIPLIERS on earned
-- currency are the industry-standard safe substitute (you earn faster; you
-- never buy the currency itself) — same reasoning as the egg luck passes.
--
-- Questionnaire posture this catalog supports: Paid Random Items = No,
-- Paid Item Trading = No. Revisit BOTH answers before wiring any SKU that
-- breaks the rule above.

return {
    -- Product ID Mapping (ConfigID -> Roblox Product ID)
    -- IMPORTANT: create these on the platform (group-owned) and replace ids.
    product_id_mapping = {
        -- Developer Products (deterministic consumables)
        xp_hour = 0, -- REPLACE: "2x XP (1 Hour)" product
        frenzy_burst = 0, -- REPLACE: "Personal Frenzy (30 min)" product
        supporter_pet = 0, -- REPLACE: "Supporter Pet" product
        focus_surge = 0, -- REPLACE: "Focus Surge (30 min)" product
        endurance_surge = 0, -- REPLACE: "Endurance Surge (30 min)" product

        -- Game Passes
        vip_pass = 1905890871, -- LIVE (dashboard 2026-07-14)
        auto_collect = 1911982576, -- LIVE (dashboard 2026-07-14)
        speed_boost = 1912298316, -- LIVE (dashboard 2026-07-14)
        golden_luck_pass = 1912204586, -- LIVE (dashboard 2026-07-14)
        rainbow_luck_pass = 1912084589, -- LIVE (dashboard 2026-07-14)
        huge_luck_pass = 1912772276, -- LIVE (dashboard 2026-07-14)
        pet_slot_pass = 1912340314, -- LIVE (dashboard 2026-07-14)
        second_wind = 1912664284, -- LIVE (dashboard 2026-07-14)
    },

    -- Developer Products (consumable Robux purchases).
    -- DETERMINISTIC ONLY: the buyer knows exactly what they get, nothing here
    -- is tradeable, and no product grants currency of any kind.
    products = {
        {
            id = "xp_hour",
            name = "⚡ 2x XP (1 Hour)",
            description = "Double XP from everything for one hour!",
            price_robux = 99,
            rewards = {
                -- TODO(handler): timed-boost handler contract (Jason
                -- 2026-07-14): boosts live in INVENTORY, remaining seconds
                -- PERSIST in the profile, and the clock ticks ONLY while
                -- in-session — logging out pauses it, logging in resumes.
                -- Never wall-clock: a bedtime logout must not eat the hour.
                boost = { axis = "xp", mult = 2.0, duration_minutes = 60 },
            },
            category = "boosts",
            analytics_category = "boost_xp",
            test_mode_enabled = true,
        },
        {
            id = "frenzy_burst",
            name = "🔥 Personal Frenzy (30 min)",
            description = "Your own Frenzy window — double drops for a full hour!",
            price_robux = 149,
            rewards = {
                -- TODO(handler): xp_hour handler + persistence contract.
                boost = { axis = "drops", mult = 2.0, duration_minutes = 60 }, -- Jason: "for 149 I would give at least an hour"
            },
            category = "boosts",
            popular = true,
            analytics_category = "boost_frenzy",
            test_mode_enabled = true,
        },
        {
            id = "supporter_pet",
            name = "💜 Supporter Pet",
            description = "A one-of-a-kind companion that says: I keep the lights on.",
            price_robux = 399,
            rewards = {
                -- DESIGN v2 (Jason 2026-07-14: "I thought by support it
                -- could support the PLAYER"): an INTANGIBLE companion — no
                -- team slot, no stats, untargetable, never downed, never in
                -- the threat table — that carries ONE gentle player aura:
                -- focus +0.25/s, a third of the Lumen Dove's +0.75/s. Focus
                -- is the one axis with NO player-level source (speed/magnet
                -- already have passes/auras); the dove stays the real focus
                -- engine that costs a slot, the companion is the slot-free
                -- trickle. Stacks under Focus Surge's x2 regen naturally.
                -- Unique model + heart-spark trail + Supporter title.
                -- TODO(content + handler): companion model + follow rig via
                -- the pet pipeline; mint UNTRADEABLE via PetGrantService;
                -- focus trickle rides the same aura path as lumen_dove.
                pet = {
                    id = "supporter_companion",
                    untradeable = true,
                    cosmetic = true,
                    aura = { kind = "focus", amount = 0.25 },
                },
            },
            category = "supporter",
            one_time_only = true,
            analytics_category = "supporter",
            test_mode_enabled = true,
        },
        -- RECURRING ITEMS (Jason 2026-07-14): cheap consumable boosts on axes
        -- we DELIBERATELY kept out of the earnable game because they're
        -- powerful (focus + pet endurance/recovery). Non-tradable by the
        -- rating rule; timed, deterministic, repurchasable. Game passes are
        -- PERMANENT by platform contract — anything timed lives here.
        {
            id = "focus_surge",
            name = "\u{1F4A7} Focus Surge (30 min)",
            description = "Focus regenerates twice as fast for 30 minutes!",
            price_robux = 59,
            rewards = {
                -- TODO(handler): same timed-boost handler as xp_hour.
                boost = { axis = "focus_regen", mult = 2.0, duration_minutes = 30 },
            },
            category = "boosts",
            analytics_category = "boost_focus",
            test_mode_enabled = true,
        },
        {
            id = "endurance_surge",
            name = "\u{1F49E} Endurance Surge (30 min)",
            description = "Your pets shrug off exhaustion — recovery timers melt for 30 minutes!",
            price_robux = 79,
            rewards = {
                -- TODO(handler): timed-boost handler; stacks multiplicatively
                -- with the Second Wind pass by design (pass = always-on 3x
                -- out of combat; this = everywhere, briefly).
                boost = { axis = "pet_recovery", mult = 3.0, duration_minutes = 30 },
            },
            category = "boosts",
            analytics_category = "boost_endurance",
            test_mode_enabled = true,
        },
    },

    -- Game Passes (permanent, personal, deterministic benefits)
    passes = {
        {
            id = "vip_pass",
            name = "👑 VIP Pass",
            description = "2x XP, faster earnings, +speed, VIP tag!",
            price_robux = 499,
            benefits = {
                -- NO currency dailies (rating rule) — RATE multipliers only:
                -- VIPs EARN faster; they never receive currency for Robux.
                multipliers = {
                    xp = 2.0,
                    coins = 1.5,
                },
                effects = {
                    id = "vip_effect",
                    permanent = true,
                    stats = {
                        -- luckBoost CUT (2026-07-14, same verdict as the
                        -- Lucky! pass: species luck is crowded AND capped at
                        -- max_luck=100 — a paid boost there can silently buy
                        -- nothing). VIP sells rates + speed + status only.
                        speedMultiplier = 0.25, -- +25% speed
                    },
                },
                perks = {
                    exclusive_chat_tag = "[VIP]",
                    exclusive_area_access = true,
                    extra_inventory_slots = 50,
                },
            },
            icon = "rbxassetid://0", -- Replace with actual asset ID
            test_mode_enabled = true,
        },
        {
            id = "auto_collect",
            name = "🤖 Auto Collector",
            description = "Automatically collect resources near you!",
            price_robux = 299,
            benefits = {
                -- CONTRACT (Jason 2026-07-14): base range MATCHES the magnet
                -- power's magnitude (30) and they ADD — pass + magnet power
                -- = 60-stud automation bubble. The power keeps paying for
                -- everyone: reach alone for non-buyers, double bubble for
                -- buyers; slot focus-cost reductions and the magnet runs
                -- near-free AND big. Verbs stay distinct: power = reach,
                -- pass = never click again.
                features = {
                    auto_collect_enabled = true,
                    auto_collect_range = 30, -- = powers.magnet magnitude; stacks additively
                    auto_collect_rate = 1.0,
                },
            },
            icon = "rbxassetid://0", -- Replace with actual asset ID
            test_mode_enabled = true,
        },
        {
            id = "speed_boost",
            name = "⚡ Speed Boost",
            -- CONTRACT (Jason 2026-07-14): speed reaches PET SPEED too — pets
            -- mine faster when faster — so this is farming throughput, not
            -- just travel. Stacks ADDITIVELY with VIP (+25%) and the speed
            -- power picks, hard-capped at +100% total (2x): past 2x, enemy
            -- chase/leash logic and mission pacing break.
            description = "Move 50% faster forever!",
            price_robux = 199,
            benefits = {
                effects = {
                    id = "speed_pass",
                    permanent = true,
                    stats = {
                        speedMultiplier = 0.5, -- +50% speed
                    },
                },
            },
            icon = "rbxassetid://0", -- Replace with actual asset ID
            test_mode_enabled = true,
        },
        -- EGG LUCK LADDER (reworked 2026-07-14): species luck CUT — that axis
        -- is crowded (luck_aura pets, VIP luckBoost, luck powers) and HARD
        -- CAPPED at max_luck=100, so a pass there can silently buy nothing.
        -- These three sell odds on axes with at most ONE other source:
        -- golden/rainbow variant luck (none) and huge luck (huge_fortune
        -- power's short window only). Boost odds of eggs bought with EARNED coins.
        -- The industry-standard No on Paid Random Items: the pass modifies
        -- probabilities of a free-currency purchase; the item is never bought
        -- with Robux. pets.lua modifier_support gates which eggs honor these
        -- (fixed_odds exclusives NEVER do — stated odds are exact).
        {
            id = "golden_luck_pass",
            name = "✨ Golden Touch",
            description = "Golden pets hatch more often from coin eggs!",
            price_robux = 349,
            benefits = { features = { egg_golden_luck = true } },
            icon = "rbxassetid://0",
            test_mode_enabled = true,
        },
        {
            id = "rainbow_luck_pass",
            name = "🌈 Rainbow Radiance",
            description = "Rainbow pets hatch more often from coin eggs!",
            price_robux = 449,
            benefits = { features = { egg_rainbow_luck = true } },
            icon = "rbxassetid://0",
            test_mode_enabled = true,
        },
        {
            id = "huge_luck_pass",
            name = "\u{1F409} Huge Hunter",
            description = "HUGE pets hatch more often from coin eggs!",
            price_robux = 549,
            benefits = { features = { egg_huge_luck = true } },
            icon = "rbxassetid://0",
            test_mode_enabled = true,
        },
        {
            id = "pet_slot_pass",
            name = "🐾 +1 Pet Slot",
            description = "Deploy an eleventh pet!",
            price_robux = 399,
            benefits = { features = { extra_equip_slots = 1 } },
            icon = "rbxassetid://0",
            test_mode_enabled = true,
        },
        {
            id = "second_wind",
            name = "\u{1FA79} Second Wind",
            description = "Pets recover 3x faster when you're out of combat!",
            price_robux = 279,
            benefits = {
                -- PAY FOR CONVENIENCE, never power (Jason 2026-07-14: "it
                -- doesn't change the fight, it minimizes waiting between
                -- battles"): 3x spirit-form/lockout recovery whenever the
                -- player is NOT InCombat (the same server attribute the
                -- combat music keys off). Does NOTHING mid-fight by design.
                -- TODO(handler): recovery-rate consumer in the spirit-form
                -- lockout tick; feature flag below is stored today.
                features = { fast_recovery_mult = 3 },
            },
            icon = "rbxassetid://0",
            test_mode_enabled = true,
        },
    },

    -- Premium (Roblox Premium) Benefits — engagement payouts are the zero-
    -- compliance revenue stream; keep Premium players happy. RATE multipliers
    -- and perks only (no currency dailies — same rating rule as VIP).
    premium_benefits = {
        enabled = true,
        multipliers = {
            xp = 1.5,
            coins = 1.25,
        },
        perks = {
            exclusive_chat_tag = "[Premium]",
            extra_inventory_slots = 25,
            premium_discount = 0.1, -- 10% off purchases
        },
        effects = {
            id = "premium_effect",
            permanent = true,
            stats = {
                speedMultiplier = 0.1, -- +10% speed
                luckBoost = 0.05, -- +5% luck
            },
        },
    },

    -- First Purchase Bonus — a TITLE, not currency (rating rule).
    first_purchase_bonus = {
        enabled = true,
        rewards = {
            title = "Supporter",
        },
    },

    -- Purchase Validation Rules
    validation_rules = {
        check_one_time_purchases = true,
        enforce_level_requirements = true,
        enforce_first_time_buyer = true,
        test_mode = {
            enabled = true, -- Allow free purchases in Studio
            bypass_robux = true,
            log_transactions = true,
        },
    },

    -- Analytics Configuration
    analytics = {
        track_purchases = true,
        track_failures = true,
        events = {
            purchase_initiated = "monetization_purchase_start",
            purchase_completed = "monetization_purchase_success",
            purchase_failed = "monetization_purchase_fail",
            pass_checked = "monetization_pass_check",
        },
    },

    -- Error Messages
    error_messages = {
        product_not_found = "Product not found. Please try again.",
        already_owned = "You already own this item!",
        level_too_high = "This item is only for new players!",
        level_too_low = "You need to be level {level} to purchase this!",
        one_time_only = "This is a one-time purchase and you already own it!",
        purchase_failed = "Purchase failed. Please try again.",
        not_enough_robux = "Not enough Robux to complete this purchase.",
    },

    -- Purchase UI Configuration
    shop_config = {
        featured_products = { "frenzy_burst", "vip_pass", "luck_pass" },
        categories = {
            { id = "featured", name = "🌟 Featured", icon = "⭐" },
            { id = "boosts", name = "⚡ Boosts", icon = "⚡" },
            { id = "passes", name = "🎫 Game Passes", icon = "🎫" },
            { id = "supporter", name = "💜 Supporter", icon = "💜" },
        },
        badges = {
            popular = { text = "POPULAR", color = Color3.fromRGB(255, 170, 0) },
            best_value = { text = "BEST VALUE", color = Color3.fromRGB(0, 255, 127) },
            one_time = { text = "ONE TIME", color = Color3.fromRGB(255, 0, 127) },
            new = { text = "NEW", color = Color3.fromRGB(0, 162, 255) },
        },
    },
}
