-- Limited testing-campaign rewards.
--
-- Campaign definitions stay in this file after distribution closes: already-awarded eggs and
-- pets continue to resolve their level thresholds by award_id. A campaign's `claim.enabled`
-- controls new eligibility reservations only; it never disables reconciliation for existing
-- awards.

return {
    version = 1,

    campaigns = {
        -- Week one is open for the public beta-testing run. Close `claim.enabled` after the
        -- advertised session; existing awards continue to reconcile while claiming is closed.
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
                enabled = true,
                -- Saturday 2026-08-08 00:00 through Saturday 2026-08-15 00:00 Mountain
                -- (06:00 UTC). The end is exclusive so week two can take over cleanly.
                starts_at = 1786168800,
                ends_at = 1786773600,
                -- Keep Studio on the same reservation/grant path for repeatable testing.
                studio_enabled = true,
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
