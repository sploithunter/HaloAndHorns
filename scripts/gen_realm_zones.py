#!/usr/bin/env python3
"""Generate the per-origin realm ZONES (configs/areas.lua) + CRYSTAL blocks (configs/breakables.lua)
for Heaven_1 / Hell_1. Each realm splits into 4 independent origin zones (Lava/Ice/Desert/Grass),
each unlock-gated at 100k of its origin coin (any order, all gated behind homeworld Desert), each
spawning the homeworld biome's ore on its own floor. Emits /tmp/gen_zones.lua + /tmp/gen_breakables.lua."""

# floor part name -> (center x,z, size x,z, currency, ore family, element, display-suffix)
ORIGINS = [
    # floorName  cx     cz    sx    sz   currency        ore           element   suffix
    ("Lava",   -206,   67,  340,  420, "lava_coins",   "Emberstone", "lava",   "Lava"),
    ("Ice",    -374,  377,  300,  300, "ice_coins",    "Frostshard", "ice",    "Frost"),
    ("Desert", -126,  474,  310,  280, "desert_coins", "Sunglass",   "desert", "Sands"),
    ("Grass",  -150,  266,  330,  240, "grass_coins",  "Bloomstone", "grass",  "Grove"),
]
REALMS = [
    # world      floorY  prefix       order_base
    ("Heaven_1",  2000,  "Empyrean",  6),
    ("Hell_1",   -1999,  "Infernal", 10),
]

UNLOCK_COST = 100000


def ore_table(family):
    rows = []
    for size, n in (("Small", 3), ("Medium", 3), ("Large", 3)):
        w = {"Small": 4, "Medium": 2, "Large": 1}[size]
        for i in range(1, n + 1):
            rows.append(f'                {{ name = "{family}{size}V{i}", weight = {w} }},')
    return "\n".join(rows)


zones, breaks = [], []
for world, fy, prefix, ob in REALMS:
    zones.append(f"        -- {world}: four independent per-origin zones (unlock any order, 100k each).")
    for oi, (floor, cx, cz, sx, sz, currency, ore, element, suffix) in enumerate(ORIGINS):
        zid = f"{world}_{floor}"  # suffix = floor part name so ZoneTrackerService resolves it
        display = f"{prefix} {suffix}"
        zones.append(f'''        {zid} = {{
            id = "{zid}",
            kind = "area",
            element = "{element}",
            zone_level = 5,
            mining_currency = "{currency}",
            display_name = "{display}",
            order = {ob + oi},
            unlock = {{
                unlocked_by_default = false,
                required_zone = "Desert", -- homeworld last gate; the four realm origins are then any-order
                currency = "{currency}",
                cost = {UNLOCK_COST},
            }},
            boosts = {{}},
            synthetic = {{
                center = {{ x = {cx}, y = {fy}, z = {cz} }},
                size = {{ x = {sx + 21}, y = 4, z = {sz + 38} }},
                floor_y = {fy + 0.5},
                spawn_position = {{ x = {cx}, y = {fy + 6}, z = {cz} }},
            }},
        }},''')

    # breakables: one block per origin, keyed by the per-origin zone id (gates via IsZoneUnlocked).
    breaks.append(f"        -- {world} per-origin ore (reuses homeworld families; gated on each origin zone).")
    for floor, cx, cz, sx, sz, currency, ore, element, suffix in ORIGINS:
        zid = f"{world}_{floor}"
        radius = min(sx, sz) // 2 - 20
        breaks.append(f'''        {zid} = {{
            max = 100,
            interval = 8,
            spawn_area = {{
                name = "SpawnArea",
                size = {{ x = {sx}, y = 1, z = {sz} }},
                position = {{ x = {cx}, y = {fy}, z = {cz} }},
            }},
            spawn_settings = {{
                upright = true,
                surface_y = {fy},
                use_spawner_bounds = true,
                surface_mode = "surface",
                surface_match_name = "{floor}",
                surface_raycast_height = 140,
                surface_normal_min_y = 0.5,
                spawn_area_margin = 24,
                spawn_center = {{ x = {cx}, z = {cz} }},
                spawn_radius = {radius},
                spawn_exclusion_radius = 12,
                embed_ratio = 0,
                min_distance = 12,
                spawn_attempts = 90,
                respawn_min_seconds = 5,
                respawn_max_seconds = 60,
            }},
            spawn_table = {{
{ore_table(ore)}
            }},
        }},''')

open("/tmp/gen_zones.lua", "w").write("\n".join(zones) + "\n")
open("/tmp/gen_breakables.lua", "w").write("\n".join(breaks) + "\n")
print(f"zones: {sum(1 for z in zones if z.strip().endswith('= {'))}  breakable blocks: {sum(1 for b in breaks if b.strip().endswith('= {'))}")
print("wrote /tmp/gen_zones.lua /tmp/gen_breakables.lua")
