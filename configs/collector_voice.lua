-- Optional character comments; never a purchase gate or prompt.
return {
    enabled = true,
    recording_catalog = "configs/voice_comments/collector.json",
    pass_id = "auto_collect",
    eligibility_attribute = "CollectorCommentEligible",
    manual_pickups = 8,
    notification_interval_seconds = 90,
    max_notifications = 3,
    pending_seconds = 20,
    scan_seconds = 0.25,
    group_name = "CollectorComments",
    event = "collector_comment",
    currencies = {
        coins = true,
        hall_coins = true,
        grass_coins = true,
        ice_coins = true,
        lava_coins = true,
        desert_coins = true,
        beach_coins = true,
    },
    cues = { angel = "collector_comment.angel", demon = "collector_comment.demon" },
    sections = {
        {
            ["speaker"] = "angel",
            ["lines"] = {
                {
                    ["id"] = "EN_COIN_ANGEL",
                    ["cue"] = "collector_comment.angel",
                    ["text"] = "You work so hard, little light. If you'd like a helping paw, a Coin Pup can gather coins and other treasures while you explore. The choice is yours.",
                },
            },
        },
        {
            ["speaker"] = "demon",
            ["lines"] = {
                {
                    ["id"] = "EN_COIN_DEMON",
                    ["cue"] = "collector_comment.demon",
                    ["text"] = "Still gathering every coin yourself? Such admirable stubbornness. A Coin Pup could fetch the loot for you. Though I admit, watching you run in circles has its charms.",
                },
            },
        },
    },
    clips = {
        ["collector_comment.angel"] = { ["asset_id"] = 131358066920529, ["seconds"] = 10.588299 },
        ["collector_comment.demon"] = { ["asset_id"] = 104094276382137, ["seconds"] = 17.554286 },
    },
    locales = {
        ["es"] = {
            ["collector_comment.angel"] = { ["asset_id"] = 132152235467950, ["seconds"] = 12.631655 },
            ["collector_comment.demon"] = { ["asset_id"] = 124353306850158, ["seconds"] = 18.018685 },
        },
        ["pt-br"] = {
            ["collector_comment.angel"] = { ["asset_id"] = 105745455251031, ["seconds"] = 11.749297 },
            ["collector_comment.demon"] = { ["asset_id"] = 87026591390259, ["seconds"] = 19.179683 },
        },
    },
}
