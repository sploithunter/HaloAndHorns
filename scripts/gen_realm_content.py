#!/usr/bin/env python3
"""Generate Lua blocks for the new Heaven-Desert + Hell pets, their eggs, and pet_roles
additions, from the resolved asset registries (scripts/pet_mesh_ids.json, scripts/egg_assets.json)
plus the roster spec below. Emits to /tmp/gen_*.lua for splicing into configs/pets.lua and
configs/pet_roles.lua. All three variants share the basic mesh+texture (matches the existing
Heaven pets — gold/rainbow are runtime tints, not separate meshes)."""
import json, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
pets_reg = json.load(open(os.path.join(ROOT, "scripts", "pet_mesh_ids.json")))
eggs_reg = json.load(open(os.path.join(ROOT, "scripts", "egg_assets.json")))

# species -> (display, role, rarity, base_power, base_health)
# Hell mirrors Heaven origin-by-origin (same archetype slots, parallel species).
ROSTER = {
    "heaven": {  # realm
        # Heaven DESERT origin (Sun pets) — the only un-wired Heaven origin
        "heaven_desert": [
            ("sun_scarab",    "Sun Scarab",     "support",  "common",    12, 130),
            ("mirage_jackal", "Mirage Jackal",  "melee",    "uncommon",  16, 140),
            ("dawn_camel",    "Dawn Camel",     "tank",     "rare",      22, 160),
            ("gilded_sphinx", "Gilded Sphinx",  "ranged",   "epic",      30, 150),
            ("solar_roc",     "Solar Roc",      "ranged",   "legendary", 42, 160),
        ],
    },
    "hell": {
        "hell_fire": [
            ("cinderling_imp",       "Cinderling Imp",       "support", "common",   12, 130),
            ("brimstone_salamander", "Brimstone Salamander", "melee",   "uncommon", 16, 140),
            ("ashmane_lion",         "Ashmane Lion",         "tank",    "rare",     22, 160),
            ("ashfeather_phoenix",   "Ashfeather Phoenix",   "ranged",  "epic",     30, 150),
            ("abyssal_wyrm",         "Abyssal Wyrm",         "ranged",  "secret",   45, 170),  # Hell secret (parallels empyrean_dragon)
        ],
        "hell_desert": [
            ("carrion_scarab", "Carrion Scarab", "support",  "common",    12, 130),
            ("phantom_jackal", "Phantom Jackal", "melee",    "uncommon",  16, 140),
            ("dust_camel",     "Dust Camel",     "tank",     "rare",      22, 160),
            ("glass_sphinx",   "Glass Sphinx",   "ranged",   "epic",      30, 150),
            ("ash_roc",        "Ash Roc",        "ranged",   "legendary", 42, 160),
        ],
        "hell_ice": [
            ("rimelight_hare",      "Rimelight Hare",      "support", "common",   12, 130),
            ("rimewraith_fox",      "Rimewraith Fox",      "melee",   "uncommon", 16, 140),
            ("dread_owl",           "Dread Owl",           "ranged",  "uncommon", 16, 140),
            ("black_seraph",        "Black Seraph",        "tank",    "rare",     22, 160),
            ("black_ice_leviathan", "Black-Ice Leviathan", "ranged",  "epic",     28, 150),
        ],
        "hell_earth": [
            ("blightlamb",    "Blightlamb",    "support", "common",   10, 130),
            ("dread_hare",    "Dread Hare",    "melee",   "common",   12, 130),
            ("rotleaf_stag",  "Rotleaf Stag",  "tank",    "uncommon", 16, 140),
            ("wither_sprite", "Wither Sprite", "ranged",  "uncommon", 14, 140),
            ("gravewood_ent", "Gravewood Ent", "tank",    "rare",     22, 160),
        ],
    },
}

# Support pets -> a distinct aura per origin (Jason: one good support each, none too strong).
SUPPORT_AURAS = {
    "sun_scarab":     '{ kind = "yield", interval = 2.0, mult = 1.1667, duration = 6 }',   # Heaven desert: coin yield
    "cinderling_imp": '{ kind = "offense", interval = 2.0, mult = 1.1667, duration = 6 }',  # Hell fire: offense
    "carrion_scarab": '{ kind = "yield", interval = 2.0, mult = 1.1667, duration = 6 }',    # Hell desert: yield
    "rimelight_hare": '{ kind = "heal", interval = 2.0, fraction = 0.08, duration = 6 }',   # Hell ice: heal
    "blightlamb":     '{ kind = "defense", interval = 2.0, amount = 53.3, duration = 6 }',  # Hell earth: defense
}

# Eggs: egg_id -> (Name, currency, realm, origin-key in ROSTER OR existing species list)
WEIGHT_BY_RARITY = {"common": 45, "uncommon": 28, "rare": 16, "epic": 6, "legendary": 1, "secret": 0.05}

# Existing (already-wired) Heaven ice/grass species + rarities for their new eggs.
EXISTING = {
    "heaven_ice":   [("frostlight_hare", "common"), ("aurora_fox", "uncommon"), ("seraph_owl", "uncommon"), ("glacial_seraph", "rare"), ("aurora_leviathan", "epic")],
    "heaven_grass": [("bloomlamb", "common"), ("halo_hare", "common"), ("goldleaf_stag", "uncommon"), ("verdant_sprite", "uncommon"), ("worldroot_ent", "rare")],
}

EGGS = {
    # heaven
    "aurora_egg": ("Aurora Egg",  "ice_coins",    "Heaven egg — hatches the radiant Ice pets (Frostlight Hare up to the Aurora Leviathan).", "heaven_ice"),
    "bloom_egg":  ("Bloom Egg",   "grass_coins",  "Heaven egg — hatches the verdant Earth pets (Bloomlamb up to the Worldroot Ent).",       "heaven_grass"),
    "gilded_egg": ("Gilded Egg",  "desert_coins", "Heaven egg — hatches the gilded Desert pets (Sun Scarab up to the Solar Roc).",          "heaven_desert"),
    # hell
    "infernal_egg":  ("Infernal Egg",  "lava_coins",   "Hell egg — hatches the molten Ash pets (Cinderling Imp up to the secret Abyssal Wyrm).", "hell_fire"),
    "black_ice_egg": ("Black Ice Egg", "ice_coins",    "Hell egg — hatches the frostbitten pets (Rimelight Hare up to the Black-Ice Leviathan).", "hell_ice"),
    "ash_egg":       ("Ash Egg",       "desert_coins", "Hell egg — hatches the dust-blasted Desert pets (Carrion Scarab up to the Ash Roc).",      "hell_desert"),
    "blight_egg":    ("Blight Egg",    "grass_coins",  "Hell egg — hatches the rotten Earth pets (Blightlamb up to the Gravewood Ent).",          "hell_earth"),
}


def mesh_img(species):
    e = pets_reg.get(species + "_basic")
    if not e or e.get("meshId", "").startswith("PENDING") or e.get("imageId", "").startswith("PENDING"):
        raise SystemExit(f"missing/unresolved registry for {species}_basic")
    return e["meshId"], e["imageId"]


def pet_entry(realm, species, display, role, rarity, power, hp):
    mesh, img = mesh_img(species)
    cat = realm
    return f'''        {species} = {{
            display_name = "{display}",
            category = "{cat}",
            realm = "{realm}",
            rarity = "{rarity}",
            base_power = {power},
            base_health = {hp},
            viewport_zoom = 1.5,
            asset_transform = {{ scale = 1.6, huge_scale = 3, orientation = {{ x = 0, y = 0, z = 0 }} }},
            camera = {{
                distance = 3.5,
                angle_y = 0,
                angle_x = 180,
                offset = Vector3.new(0, 0, 0),
                lighting = "default",
            }},
            variants = {{
                basic = {{
                    mesh_asset = "{mesh}",
                    texture_asset = "{img}",
                    display_name = "{display}",
                    abilities = {{}},
                }},
                golden = {{
                    mesh_asset = "{mesh}",
                    texture_asset = "{img}",
                    display_name = "Golden {display}",
                    abilities = {{ "golden_flame", "coin_magnet" }},
                }},
                rainbow = {{
                    mesh_asset = "{mesh}",
                    texture_asset = "{img}",
                    display_name = "Rainbow {display}",
                    abilities = {{ "luck_aura" }},
                }},
            }},
        }},'''


def egg_entry(egg_id, name, currency, desc, pool):
    e = eggs_reg[egg_id]
    if pool in ROSTER.get("heaven", {}) or pool in ROSTER.get("hell", {}):
        realm = "heaven" if pool.startswith("heaven") else "hell"
        members = [(s, rar) for (s, _d, _ro, rar, _p, _h) in ROSTER[realm][pool]]
    else:
        members = EXISTING[pool]
    weights = "\n".join(f"                {s} = {WEIGHT_BY_RARITY[rar]}," for s, rar in members)
    return f'''        {egg_id} = {{
            name = "{name}",
            description = "{desc}",
            world_placeable = true,
            cost = 500,
            currency = "{currency}",
            huge = {{ chance = 0.00002, any_pet = true }}, -- 1 in 50,000; tune freely
            mesh_asset = "{e['mesh_id']}", -- egg mesh
            texture_asset = "{e['mesh_image']}", -- egg image (IMAGE, not Decal)
            asset_id = "rbxassetid://{e['model_asset']}", -- 3D egg model fallback
            image_id = "rbxassetid://{e['icon_image']}", -- 2D egg icon (UI)
            camera = {{
                distance = 3.5,
                angle_y = 0,
                angle_x = 180,
                offset = Vector3.new(0, 0, 0),
                lighting = "default",
            }},
            pet_weights = {{
{weights}
            }},
            rarity_rates = {{
                golden_chance = 0.05,
                rainbow_chance = 0.005,
            }},
            variant_rolls = {{
                enabled = true,
                allow_basic = true,
                allow_golden = true,
                allow_rainbow = true,
                cost_multiplier = 20,
            }},
            modifier_support = {{
                supports_luck_gamepass = true,
                supports_golden_gamepass = true,
                supports_rainbow_gamepass = true,
                max_luck_multiplier = 10.0,
            }},
            hatching_time = 3,
            guaranteed_shiny_chance = 0,
            bonus_xp = 0,
        }},'''


# --- emit pets ---
pet_blocks, role_lines, aura_lines = [], [], []
for realm, origins in ROSTER.items():
    for origin, members in origins.items():
        pet_blocks.append(f"        -- {origin.replace('_', ' ').title()} origin ({realm})")
        for (species, display, role, rarity, power, hp) in members:
            pet_blocks.append(pet_entry(realm, species, display, role, rarity, power, hp))
            role_lines.append(f'        {species} = "{role}",')
            if species in SUPPORT_AURAS:
                aura_lines.append(f"        {species} = {SUPPORT_AURAS[species]},")

open("/tmp/gen_pets.lua", "w").write("\n".join(pet_blocks) + "\n")
open("/tmp/gen_roles.lua", "w").write(
    "-- by_type additions:\n" + "\n".join(role_lines) +
    "\n\n-- support_auras additions:\n" + "\n".join(aura_lines) + "\n")

# --- emit eggs ---
egg_blocks = [egg_entry(eid, *meta) for eid, meta in EGGS.items()]
open("/tmp/gen_eggs.lua", "w").write("\n".join(egg_blocks) + "\n")

print(f"pets: {sum(len(m) for o in ROSTER.values() for m in o.values())}  eggs: {len(EGGS)}  roles: {len(role_lines)}  auras: {len(aura_lines)}")
print("wrote /tmp/gen_pets.lua /tmp/gen_eggs.lua /tmp/gen_roles.lua")
