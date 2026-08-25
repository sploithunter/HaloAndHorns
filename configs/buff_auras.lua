--[[
    Buff auras — the IN-WORLD twin of the player power-badge row (PlayerPowerBadges).

    While a timed player buff is active, the owner wears a themed aura (rising sparkles + a warm
    glow). Driven purely from the SSOT: each row's `attr` is a player attribute `<attr>` + an
    `<attr>Until` (os.time) stamp that PowerService:_setAxisBuff writes — the SAME attributes the
    HUD badges read. BuffAuraController watches them on EVERY player (attributes replicate), so you
    see other players' auras too.

    Adding a buff aura = ONE ROW here (no new visual code). Potion meters use the same
    `<attr>/<attr>Until` convention plus an optional `charge_attr` (`Brew_<meter>`) so
    stacked sips look barely contained instead of a flat on/off glow.

    Fields per row:
      attr             player attribute base (e.g. "DropRateBuff" -> reads "DropRateBuffUntil")
      charge_attr      optional 0-1 brew charge (scales rate / light / containment)
      color / color2   sparkle gradient (RGB); color also tints the glow
      rate             steady sparkles per second
      burst            one-shot :Emit() count when the aura first appears (the cast flourish)
      size             sparkle size (studs, at its peak)
      speed            initial sparkle speed
      rise             upward acceleration (studs/s^2) — sparkles float up around the body
      light_brightness / light_range   the PointLight glow
      contain          ForceField bubble that leaks when charge is high
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
        -- Berserk Brew: fire leaking out of a barely-held shell. Intensity follows Brew_damage.
        {
            attr = "PetDamageBuffPotion",
            charge_attr = "Brew_damage",
            color = { 255, 70, 40 },
            color2 = { 255, 200, 70 },
            rate = 22,
            burst = 28,
            size = 1.05,
            speed = 5,
            rise = 8,
            light_brightness = 3.2,
            light_range = 14,
            contain = true,
        },
        -- Fortune Flask
        {
            attr = "LuckBuffPotion",
            charge_attr = "Brew_luck",
            color = { 70, 220, 110 },
            color2 = { 210, 255, 170 },
            rate = 16,
            burst = 18,
            size = 0.85,
            speed = 3,
            rise = 6,
            light_brightness = 2.2,
            light_range = 11,
        },
        -- Swift Tonic
        {
            attr = "MoveSpeedBuffPotion",
            charge_attr = "Brew_speed",
            color = { 80, 170, 255 },
            color2 = { 200, 230, 255 },
            rate = 18,
            burst = 16,
            size = 0.8,
            speed = 6,
            rise = 5,
            light_brightness = 2.4,
            light_range = 12,
        },
    },
}
