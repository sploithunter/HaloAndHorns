--[[
    Public promo/reward codes.

    IMPORTANT: configs are replicated to clients. Do not pre-stage an unannounced future code in
    this file; add it when the campaign is announced (or generate it from a private server source).
    The server remains authoritative for eligibility, claim limits, dates, level gates, and grants.

    Reward is a standard RewardBundle and may contain currencies, pets, items, timed effects,
    titles, slots, or experience. The stable table key is the claim + analytics identity even if a
    public spelling changes or gains aliases.
]]

return {
    version = 1,
    enabled = true,
    input = {
        min_length = 3,
        max_length = 32,
    },
    attempts = {
        window_seconds = 60,
        max_per_window = 10,
        cooldown_seconds = 10,
    },
    codes = {
        -- Safe end-to-end smoke test. Never works in a published server.
        studio_smoke = {
            code = "CODETEST",
            aliases = { "TESTCODE" },
            enabled = true,
            studio_only = true,
            minimum_level = 1,
            per_player_limit = 1,
            campaign = "studio_smoke",
            reward = {
                currencies = { gems = 25 },
            },
            success_message = "🎁 CODE REDEEMED — 25 GEMS!",
        },
    },
}
