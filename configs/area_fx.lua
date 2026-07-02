--[[
    Area (AoE) effects — Halo & Horns [PROTOTYPE].

    Config for src/Shared/Effects/AreaFX.lua. Two variants per element:
      self     — a burst AROUND the caster (ground ring + dome + rising motes)
      targeted — a strike AT a point with a cast beam + ground telegraph, then an eruption

    Elements: grass / desert / ice / lava. `color` is the core, `color2` the accent/motes.
    `material` is the part Material name (Neon glows; Glass = icy; SmoothPlastic = earthy sand).
    Read client-side; purely visual (gameplay/damage live elsewhere).
]]

return {
    -- Self burst (point-blank AoE around the caster).
    self = {
        radius = 12, -- studs the ground ring/dome reach
        rise = 8, -- how high the motes float
        motes = 16,
        duration = 0.6,
    },
    -- Targeted strike (cast at a ground point).
    targeted = {
        radius = 9,
        cast_time = 0.18, -- seconds of cast beam + telegraph before the eruption
        rise = 7,
        motes = 12,
        debris = 16,
        duration = 0.6,
    },
    -- Lingering ground-hazard (e.g. lava "pit" = molten tar pit). Stays for `duration` seconds.
    pit = {
        radius = 8,
        duration = 4, -- the pool bubbles this long, then fades
    },
    -- Scatter cast (chunks fly outward from the caster, themed by element). radius = how far the
    -- debris flings; duration = its flight time.
    scatter = {
        radius = 9,
        duration = 0.7,
    },
    -- Rubble impact (chunks hit the target, bounce, roll away, fade — ricochet). radius = how far
    -- they roll out; the bounce phase timings are fixed in AreaFX so the physics reads right.
    rubble = {
        radius = 7,
        duration = 1.0,
    },

    themes = {
        -- Grassy nature burst — green growth + leafy motes.
        grass = { color = { 90, 200, 80 }, color2 = { 170, 240, 130 }, material = "Neon" },
        -- Desert sandstorm — tan dust + rubble (earthy, non-glowing).
        desert = {
            color = { 205, 180, 130 },
            color2 = { 150, 125, 90 },
            material = "SmoothPlastic",
        },
        -- Ice nova — pale blue + white, glassy.
        ice = { color = { 150, 220, 255 }, color2 = { 235, 250, 255 }, material = "Glass" },
        -- Lava eruption — orange/red molten glow.
        lava = { color = { 255, 110, 30 }, color2 = { 255, 200, 90 }, material = "Neon" },
        -- Lightning storm — electric blue core + near-white accent (matches the grass pets' bolts).
        lightning = { color = { 130, 170, 255 }, color2 = { 225, 245, 255 }, material = "Neon" },
        -- Heal — restorative green/gold (used by the heal category's nova + splash variants).
        heal = { color = { 120, 230, 120 }, color2 = { 220, 255, 200 }, material = "Neon" },
    },

    -- Per-biome heal tints: CombatFX reuses the heal nova/splash SHAPES with these colours so an
    -- ally heal reads with its biome origin (green / warm-gold / mint / amber) instead of one green.
    heal_tints = {
        grass = { color = { 130, 240, 130 }, color2 = { 220, 255, 200 }, material = "Neon" },
        lava = { color = { 255, 215, 120 }, color2 = { 255, 245, 200 }, material = "Neon" },
        ice = { color = { 170, 245, 215 }, color2 = { 230, 255, 240 }, material = "Neon" },
        desert = { color = { 240, 220, 140 }, color2 = { 215, 255, 185 }, material = "Neon" },
    },
}
