-- Limited testing-campaign rewards.
--
-- Campaign definitions stay in this file after distribution closes: already-awarded eggs and
-- pets continue to resolve their level thresholds by award_id. A campaign's `claim.enabled`
-- controls new eligibility reservations only; it never disables reconciliation for existing
-- awards.

return {
    version = 1,

    campaigns = {
        -- Week one is closed to new claims. Existing Beta Byte eggs and pets still reconcile
        -- because campaign definitions remain permanent after their public window ends.
        beta_week_1_2026 = {
            version = 1,
            egg_id = "beta_tester_egg",
            pet_id = "beta_tester_bot",
            claim_limit = 1,
            minimum_claim_level = 2,
            golden_level = 5,
            rainbow_level = 10,
            huge_chance = 0.01,
            claim = {
                enabled = false,
                -- Saturday 2026-08-08 00:00 through Saturday 2026-08-15 00:00 Mountain
                -- (06:00 UTC). The end is exclusive so week two can take over cleanly.
                starts_at = 1786168800,
                ends_at = 1786773600,
                studio_enabled = false,
            },
        },

        -- Week two: Signal Seal. This deliberately uses the same progression contract as week
        -- one while keeping a distinct award id, egg id, and pet id for provenance and trading.
        beta_week_2_2026 = {
            version = 1,
            egg_id = "signal_seal_egg",
            pet_id = "signal_seal",
            claim_limit = 1,
            minimum_claim_level = 2,
            golden_level = 5,
            rainbow_level = 10,
            huge_chance = 0.01,
            claim = {
                enabled = false,
                -- Saturday 2026-08-15 00:00 through Saturday 2026-08-22 00:00 Mountain
                -- (06:00 UTC). The end is exclusive so week three can take over cleanly.
                starts_at = 1786773600,
                ends_at = 1787378400,
                studio_enabled = false,
            },
        },

        beta_week_3_2026 = {
            version = 1,
            egg_id = "patch_phoenix_egg",
            pet_id = "patch_phoenix",
            claim_limit = 1,
            minimum_claim_level = 2,
            golden_level = 5,
            rainbow_level = 10,
            huge_chance = 0.01,
            claim = {
                enabled = false,
                starts_at = 1787378400,
                ends_at = 1787983200,
                -- Exercise closed campaigns through their explicit admin grant controls.
                -- Opening multiple reservation paths would award every egg at level two.
                studio_enabled = false,
            },
        },

        beta_week_4_2026 = {
            version = 1,
            egg_id = "core_digger_egg",
            pet_id = "core_digger",
            claim_limit = 1,
            minimum_claim_level = 2,
            golden_level = 5,
            rainbow_level = 10,
            huge_chance = 0.01,
            claim = {
                enabled = true,
                starts_at = 1787983200,
                ends_at = 1788588000,
                studio_enabled = false,
            },
        },

        beta_week_5_2026 = {
            version = 1,
            egg_id = "cache_bandit_egg",
            pet_id = "cache_bandit",
            claim_limit = 1,
            minimum_claim_level = 2,
            golden_level = 5,
            rainbow_level = 10,
            huge_chance = 0.01,
            claim = {
                enabled = false,
                starts_at = 1788588000,
                ends_at = 1789192800,
                studio_enabled = false,
            },
        },
    },

    -- New campaigns may copy these launch-round values, but the service always reads the values
    -- stored on the individual campaign. Later weeks can use different level thresholds without
    -- changing code or retroactively changing week one.
    defaults = {
        claim_limit = 1,
        minimum_claim_level = 2,
        golden_level = 5,
        rainbow_level = 10,
        huge_chance = 0.01,
    },
}
