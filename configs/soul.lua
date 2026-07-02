--[[
    Soul (alignment) config — Halo & Horns [PROTOTYPE].

    The Soul stat tracks the player's alignment along the Heaven (positive / Halo)
    / Hell (negative / Horns) axis. It shifts on biome conquest by the directional
    progression around the ring (see Feature 2, GWT_ACCEPTANCE_SPEC). All values
    here are config-driven — `src/Shared/Game/SoulMath.lua` reads them.

    `bands` define the alignment label thresholds:
      soul >= bands.halo  -> "halo"   (tilted toward the Light)
      soul <= bands.horns -> "horns"  (tilted toward the Dark)
      otherwise           -> "neutral"
]]

return {
    delta_per_conquest = 5,
    range = { min = -100, max = 100 },
    bands = { halo = 1, horns = -1 },
}
