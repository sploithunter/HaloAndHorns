--[[
    Drops / pickup config (#167) — Halo & Horns.

    When a crystal breaks, its COIN reward no longer credits instantly: a physical coin pickup pops
    out at the node and the owner collects it by walking near (auto-collect radius). The Magnet power
    widens that radius and pulls drops in. XP, pet progression and realm-token cuts stay INSTANT —
    only the coin currency rides the drop. A drop never loses coins: if it times out or the server
    cap is hit, it auto-collects to its owner. DropService.lua implements it.

    Every number is a dev knob. `enabled=false` falls back to instant-credit (the pre-#167 behavior).
]]

return {
    enabled = true, -- drops ON by default (Jason): mining spawns pickups, not instant coins

    -- PREMIUM GEM bonus roll (Jason: "a chance for a gem drop on crystal break"):
    -- each break rolls once per contributor; on a hit, a `gems` pickup pops from the
    -- node (same pipeline: owner-only visible, magnet, never lost). gems_earned_lifetime
    -- counts it (earned in the environment). chance 0.01 = ~1 gem per 100 breaks.
    gem_bonus = {
        enabled = true,
        chance = 0.01,
        min = 1,
        max = 2,
    },

    collect_radius = 11, -- base auto-collect distance (studs) from the owner's character
    magnet_pull_radius = 6, -- once within this, a drop flies to the player (visual "vacuum")
    magnet_pull_speed = 60, -- studs/s a drop travels while being pulled in

    despawn_seconds = 30, -- a drop auto-collects to its owner after this long (never lost)
    max_active = 90, -- per-server live-drop cap; the oldest auto-collects when exceeded
    min_coins_for_drop = 1, -- awards below this credit instantly (no dust pickups)

    -- Spawn pop: the coin arcs up+out from the node so a cluster fans out instead of stacking.
    pop_up = 7, -- initial upward hop (studs)
    pop_out = 5, -- horizontal scatter radius (studs)
    pop_time = 0.35, -- arc settle time (s) before it rests on the ground

    -- Coin part look (placeholder — swap for a coin mesh later).
    part_size = 1.3,
    part_color = { 240, 200, 70 },
    part_spin = 90, -- deg/s idle spin for readability

    -- Magnet power: the cast sets MagnetBuff (radius BONUS in studs) for its duration; the collect
    -- loop adds it to collect_radius while MagnetBuffUntil is live. Tunable here for reference; the
    -- actual bonus + duration come from the power's effect_kind in configs/powers.lua.
    magnet_default_bonus = 30,
}
