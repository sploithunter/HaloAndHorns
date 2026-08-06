-- Limited testing-campaign rewards.
--
-- Campaign definitions stay in this file after distribution closes: already-awarded eggs and
-- pets continue to resolve their level thresholds by award_id. A campaign's `claim.enabled`
-- controls new eligibility reservations only; it never disables reconciliation for existing
-- awards.

return {
    version = 1,

    campaigns = {
        -- Week one is fully authored but deliberately CLOSED. Admin tools can grant/reset test
        -- copies without opening public eligibility; set the real UTC window immediately before
        -- the advertised Friday/Saturday session.
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
                -- Exercise the real reservation/grant path in Studio without opening the
                -- production campaign before the advertised public window.
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
