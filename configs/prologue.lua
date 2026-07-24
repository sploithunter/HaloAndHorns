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

    -- THE PLAYER'S TEMPORARY SQUAD (Jason: "one of every dragon, plus a huge Ent for a
    -- tank"). Ghost models in the player's own folder — the client drive gives them real
    -- formations exactly like owned pets; destroyed at warp-out, never inventory.
    player_squad = {
        -- Jason: "fill out a temporary 10 slots with dragons and a ent" — a preview of
        -- the endgame roster. Huge Ent tank up front, then one of every dragon, then
        -- variant repeats to fill all 10 slots.
        { pet = "worldroot_ent", variant = "basic", huge = true }, -- the tank, slot 1
        { pet = "dragon", variant = "rainbow" },
        { pet = "empyrean_dragon", variant = "rainbow" },
        { pet = "abyssal_wyrm", variant = "rainbow" },
        { pet = "aurora_dragon", variant = "golden" },
        { pet = "rimewraith_dragon", variant = "golden" },
        { pet = "dragon", variant = "golden" },
        { pet = "empyrean_dragon", variant = "golden" },
        { pet = "abyssal_wyrm", variant = "golden" },
        { pet = "aurora_dragon", variant = "rainbow" },
    },

    -- THE BATTLE (Jason: "spawn him and Colorado with Colorado's pets in the midst of a huge
    -- number of enemies"). Pre-filled at Begin exactly like the trials (dormant + persistent +
    -- room movementLeash) — the hell (lava) roster. Levels auto-tune: SpawnEnemy reads the
    -- spawner's EffectiveLevel, which the alliance has already lifted to ~49.
    wave = {
        units = {
            { enemy = "lava_imp", count = 6 },
            { enemy = "murder_crow", count = 4 },
            { enemy = "ember_acolyte", count = 4 },
            { enemy = "ember_brute", count = 2 },
        },
        ring_radius = 32, -- scatter ring around the room center, in front of the stage
        scatter = 12, -- deterministic per-index radial jitter
    },

    -- Seconds the sequence runs before the warp-out. Hard cap — the beats compress rather
    -- than the player waiting. DEBUG: held at 30 while the room is being iterated on;
    -- drop back to ~8-12 before launch.
    duration = 30,

    -- Where the player lands afterwards: nil = the normal spawn (tutorial takes over at
    -- `hatch_first_egg`).
    caption = {
        cut = "ONE MONTH FROM NOW", -- the black boot screen doubles as the title card (first runs only)
        victory = "VICTORY!", -- giant floating text the moment the wave is wiped
        land = "PRESENT DAY", -- the hard cut back to the real beginning
    },

    -- Seconds the VICTORY beat holds before the cut ("once the battle is over, it ends
    -- pretty quickly").
    victory_hold = 3,
}
