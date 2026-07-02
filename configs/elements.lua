--[[
    Element resonance — Halo & Horns [PROTOTYPE] (Feature 6).

    Multiplier applied to a pet's power based on its element and the realm
    alignment of the player's current biome/layer. Light and Shadow are STRONGER
    in the opposing realm (dominance); Chaotic is flat across realms; Neutral is
    flat 1.0. Read by `src/Shared/Game/ElementResonance.lua` and `PowerFormula`.
]]

return {
    -- BIOME ROCK-PAPER-SCISSORS (Jason, 2026-06-12): one directed cycle over the four
    -- homeworld elements — each element is STRONG in the zone it beats, WEAK in the
    -- zone that beats it, neutral at home and at its opposite. Replaces the old
    -- static element_stats attack bias ("weird fire pets are just better") with pure
    -- geography. Special/unknown zones resolve neutral by construction (map miss).
    --   lava -> grass   (fire burns the meadow)
    --   grass -> desert (life reclaims the wasteland)
    --   desert -> ice   (the desert heat melts the ice)
    --   ice -> lava     (ice quenches the fire)
    -- Migration ring: zone N's pets shine later in the unlock chain — ice pets
    -- conquer Lava, and the day-one grass starters get their renaissance in Desert.
    biome = {
        beats = {
            lava = "grass",
            grass = "desert",
            desert = "ice",
            ice = "lava",
        },
        advantage = 1.25, -- standing in the zone your element beats
        disadvantage = 0.8, -- standing in the zone that beats your element
    },

    -- resonance[petElement][realmAlignment] -> multiplier. CROSS-REALM by design (Jason): a pet is
    -- STRONGEST in the OPPOSITE realm and weak in its own, so a Heaven (light) pet is a weapon down
    -- in Hell and a Hell (shadow) pet shines in Heaven — you want the other realm's pets, which
    -- drives cross-realm trading. Homeworld pets are neutral (1.0 everywhere — never obsolete).
    -- Realm pets are NOT a self-upgrade at home (0.8); their value is the opposite realm + trade.
    resonance = {
        light = { heaven = 0.8, hell = 1.5, neutral = 1.0 }, -- Heaven pets: weak at home, 1.5x in Hell
        shadow = { heaven = 1.5, hell = 0.8, neutral = 1.0 }, -- Hell pets: 1.5x in Heaven, weak at home
        chaotic = { heaven = 1.3, hell = 1.3, neutral = 1.3 }, -- fusion-only: strong everywhere
        neutral = { heaven = 1.0, hell = 1.0, neutral = 1.0 }, -- homeworld: untagged, always 1.0
    },
}
