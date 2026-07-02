--[[
    Buff auras — the IN-WORLD twin of the player power-badge row (PlayerPowerBadges).

    While a timed player buff is active, the owner wears a themed aura (rising sparkles + a warm
    glow). Driven purely from the SSOT: each row's `attr` is a player attribute `<attr>` + an
    `<attr>Until` (os.time) stamp that PowerService:_setAxisBuff writes — the SAME attributes the
    HUD badges read. BuffAuraController watches them on EVERY player (attributes replicate), so you
    see other players' auras too.

    Adding a buff aura = ONE ROW here (no new visual code). Potions are timed axis buffs on the same
    `<attr>/<attr>Until` convention, so they slot in here later the same way.

    Fields per row:
      attr             player attribute base (e.g. "DropRateBuff" -> reads "DropRateBuffUntil")
      color / color2   sparkle gradient (RGB); color also tints the glow
      rate             steady sparkles per second
      burst            one-shot :Emit() count when the aura first appears (the cast flourish)
      size             sparkle size (studs, at its peak)
      speed            initial sparkle speed
      rise             upward acceleration (studs/s^2) — sparkles float up around the body
      light_brightness / light_range   the PointLight glow
]]

return {
    enabled = true,
    poll_interval = 0.2, -- seconds between buff-timer checks per player (cheap)

    auras = {
        -- Windfall (drop_rate axis): a warm GOLD sparkle aura — "loot is flowing".
        {
            attr = "DropRateBuff",
            color = { 255, 205, 70 },
            color2 = { 255, 240, 170 },
            rate = 26,
            burst = 30,
            size = 1.0,
            speed = 4,
            rise = 7,
            light_brightness = 3.5,
            light_range = 15,
        },
    },
}
