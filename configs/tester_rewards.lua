-- Limited testing-campaign rewards.
--
-- Campaign definitions stay in this file after distribution closes: already-awarded eggs and
-- pets continue to resolve their level thresholds by award_id. A campaign's `claim.enabled`
-- controls new eligibility reservations only; it never disables reconciliation for existing
-- awards.

return {
    version = 1,

    -- Safe shipped state until the first authored egg/pet/huge-pet assets are wired in.
    campaigns = {},

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
