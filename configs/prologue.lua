--[[
    THE PROLOGUE — the playable cold open (docs/PROLOGUE.md).

    A genuinely-new player spawns into a dressed dungeon room at level 50, mid-battle, with a
    squad already fighting — then hard-cuts to the starter egg with "ONE MONTH FROM NOW".
    Jason: "our player retention bottleneck is literally in the first 15 seconds."

    It does NOT compete with boot (measured 8.1s cold / 3.5s warm, only ~3s usable). It
    REPLACES the first ~8 seconds of gameplay, which are currently the weakest in the session.

    GATED exactly like the starter-pet chooser: a one-time `data.Prologue` record written on
    START (so a rage-quit can't re-trigger it). Admin "Reset to Beginning" clears it — that's
    the test path.
]]

return {
    enabled = true,

    -- A/B: fraction of eligible new players who see it. The ad run buys the sample that
    -- settles whether the cold open earns its seconds; 0.5 = half see it, half don't.
    ab_split = 0.5,

    -- THE ROOM. Jason: "in the procedurally generated maps that we use for trials, there is a
    -- procedurally generated large room that has a mezzanine. That's what we're going to spawn
    -- into." That's the graybox kit's `mezzanine_hall` — 144x144 studs, 64-stud walls, an
    -- upper U-gallery with walk-up ramps. Multi-level FEEL without a multi-level map.
    room = {
        kit = "graybox", -- Shared/Worldgen/GrayBoxKit
        tile = "mezzanine_hall",
        -- Built far from the playable world so it never collides with the map or streams into
        -- an ordinary session. Y is well below the realms (Home ±2000).
        origin = { x = 0, y = -8000, z = 0 },
    },

    -- Seconds the sequence runs before the warp-out. Hard cap — the beats compress rather
    -- than the player waiting.
    duration = 8,

    -- Where the player lands afterwards: nil = the normal spawn (tutorial takes over at
    -- `hatch_first_egg`).
    caption = {
        cut = "ONE MONTH FROM NOW",
        land = "Today.",
    },
}
