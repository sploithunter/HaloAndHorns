return {
    zones = {
        spawn_world = {
            id = "spawn_world",
            kind = "world",
            display_name = "Spawn World",
            order = 1,
        },
        spawn_island = {
            id = "spawn_island",
            kind = "island",
            parent = "spawn_world",
            display_name = "Spawn Island",
            order = 1,
            primary_area = "Spawn",
        },
        meadow_island = {
            id = "meadow_island",
            kind = "island",
            parent = "spawn_world",
            display_name = "Meadow Island",
            order = 2,
            primary_area = "Meadow",
        },
        Spawn = {
            id = "Spawn",
            kind = "area",
            element = "grass", -- biome RPS (elements.lua biome)
            -- ZONE LEVEL (Jason): the base level of this zone's content. Crystals stamp
            -- MiningLevel = zone_level + size offset (S/M/L = +0/+1/+2, mirroring enemy
            -- rank_offset); XP diminishes vs out-leveled targets (leveling.xp_level_scale).
            zone_level = 1, -- earth tier (homeworld spans 1-4; heaven/hell realms take 5+)
            mining_currency = "grass_coins", -- what the zone's ore PAYS (area_coins rewards resolve here)
            parent = "spawn_island",
            display_name = "Spawn Area",
            order = 1,
            unlock = {
                unlocked_by_default = true,
            },
            boosts = {},
            synthetic = {
                center = { x = 0, y = 0, z = 0 },
                size = { x = 160, y = 4, z = 160 },
                floor_y = 0,
                spawn_position = { x = 0, y = 3, z = 0 },
                egg_stands = {
                    {
                        egg_id = "grass_egg",
                        spawn_id = "Grass",
                        position = { x = 0, y = 0.5, z = -22 },
                    },
                },
            },
        },
        Meadow = {
            id = "Meadow",
            kind = "area",
            element = "grass", -- biome RPS (elements.lua biome)
            zone_level = 1, -- earth tier, same as Spawn (boost island, not a step up)
            mining_currency = "grass_coins", -- what the zone's ore PAYS (area_coins rewards resolve here)
            parent = "meadow_island",
            display_name = "Meadow",
            order = 2,
            unlock = {
                required_zone = "Spawn",
                unlocked_by_default = false,
                -- grass_coins ("Grass Crystals", 🌿) — the mined coin, like every other home-world gate.
                -- Was "crystals" (the rare "Relics" currency, default 0, NOT mined) → Meadow was
                -- effectively unpurchasable. Stale legacy id from before the per-biome currency split.
                currency = "grass_coins",
                -- Meadow grants a PERMANENT +10% coins boost, so it must not be near-free.
                -- ~3 min of grass mining at the fresh-squad rate.
                cost = 2000,
            },
            boosts = {
                coins = 1.1,
            },
            synthetic = {
                center = { x = 220, y = 0, z = 0 },
                size = { x = 160, y = 4, z = 160 },
                floor_y = 0,
                spawn_position = { x = 220, y = 4, z = 0 },
                egg_stands = {},
            },
        },
        lava_island = {
            id = "lava_island",
            kind = "island",
            parent = "spawn_world",
            display_name = "Lava Island",
            order = 3,
            primary_area = "Lava",
        },
        Lava = {
            id = "Lava",
            kind = "area",
            element = "lava", -- biome RPS (elements.lua biome)
            zone_level = 3, -- third gate (see Spawn note)
            mining_currency = "lava_coins", -- what the zone's ore PAYS (area_coins rewards resolve here)
            parent = "lava_island",
            display_name = "Lava Fields",
            order = 3,
            unlock = {
                unlocked_by_default = false,
                required_zone = "Ice",
                currency = "ice_coins",
                cost = 18000, -- ~15 min of ice mining (see Ice unlock note + design doc §10)
            },
            boosts = {},
            -- Real authored "Lava" baseplate (Home.Lava): center ~(-207,0,68), top ~Y0.5.
            synthetic = {
                center = { x = -207, y = 0, z = 68 },
                size = { x = 360, y = 4, z = 458 },
                floor_y = 0.5,
                spawn_position = { x = -207, y = 5, z = 68 },
                egg_stands = {},
            },
        },
        ice_island = {
            id = "ice_island",
            kind = "island",
            parent = "spawn_world",
            display_name = "Ice Island",
            order = 4,
            primary_area = "Ice",
        },
        Ice = {
            id = "Ice",
            kind = "area",
            element = "ice", -- biome RPS (elements.lua biome)
            zone_level = 2, -- second gate (see Spawn note)
            mining_currency = "ice_coins", -- what the zone's ore PAYS (area_coins rewards resolve here)
            parent = "ice_island",
            display_name = "Ice Fields",
            order = 4,
            -- Unlock chain (ring order): grass(Spawn) -> Ice -> Lava -> Desert. Each biome is paid
            -- for with the PREVIOUS biome's coins, so you mine one zone to afford the next.
            -- PACING PRINCIPLE (see design doc §10/§11): a gate should cost a real *chapter* in the
            -- current zone (~10-20 min fresh farming, a fraction of the ~20k-coin graduate arc), not
            -- be trivially cheap. Tune the "minutes per zone" by scaling these. At ~10 cps fresh
            -- grass, 8000 ~= 13 min.
            unlock = {
                unlocked_by_default = false,
                required_zone = "Spawn",
                currency = "grass_coins",
                cost = 8000,
            },
            boosts = {},
            -- Real authored "Ice" baseplate (Home.Ice): center ~(-375,0,377).
            synthetic = {
                center = { x = -375, y = 0, z = 377 },
                size = { x = 318, y = 4, z = 326 },
                floor_y = 0.5,
                spawn_position = { x = -375, y = 5, z = 377 },
                egg_stands = {},
            },
        },
        desert_island = {
            id = "desert_island",
            kind = "island",
            parent = "spawn_world",
            display_name = "Desert Island",
            order = 5,
            primary_area = "Desert",
        },
        Desert = {
            id = "Desert",
            kind = "area",
            element = "desert", -- biome RPS (elements.lua biome)
            zone_level = 4, -- last homeworld gate (see Spawn note)
            mining_currency = "desert_coins", -- what the zone's ore PAYS (area_coins rewards resolve here)
            parent = "desert_island",
            display_name = "Desert Fields",
            order = 5,
            unlock = {
                unlocked_by_default = false,
                required_zone = "Lava",
                currency = "lava_coins",
                cost = 35000, -- ~23 min of lava mining; last homeworld gate, biggest commitment
            },
            boosts = {},
            -- Real authored "Desert" baseplate (Home.Desert): center ~(-127,1,475).
            synthetic = {
                center = { x = -127, y = 1, z = 475 },
                size = { x = 330, y = 4, z = 301 },
                floor_y = 1.5,
                spawn_position = { x = -127, y = 6, z = 475 },
                egg_stands = {},
            },
        },
        -- REALM ZONES (Heaven_1 + Hell_1): each realm splits into FOUR independent per-origin
        -- zones (Lava/Ice/Desert/Grass), unlock-gated at 100k of the origin's coin, any order
        -- (all behind the homeworld Desert gate). Zone id = <World>_<FloorName> so
        -- ZoneTrackerService resolves the floor you stand on to the right origin zone.
        -- Generated by scripts/gen_realm_zones.py.
        -- Heaven_1: four independent per-origin zones (unlock any order, 100k each).
        Heaven_1_Lava = {
            id = "Heaven_1_Lava",
            kind = "area",
            element = "lava",
            zone_level = 5,
            mining_currency = "lava_coins",
            display_name = "Empyrean Lava",
            order = 6,
            unlock = {
                unlocked_by_default = false,
                required_zone = "Desert", -- homeworld last gate; the four realm origins are then any-order
                currency = "lava_coins",
                cost = 100000,
            },
            boosts = {},
            synthetic = {
                center = { x = -206, y = 2000, z = 67 },
                size = { x = 361, y = 4, z = 458 },
                floor_y = 2000.5,
                spawn_position = { x = -206, y = 2006, z = 67 },
            },
        },
        Heaven_1_Ice = {
            id = "Heaven_1_Ice",
            kind = "area",
            element = "ice",
            zone_level = 5,
            mining_currency = "ice_coins",
            display_name = "Empyrean Frost",
            order = 7,
            unlock = {
                unlocked_by_default = false,
                required_zone = "Desert", -- homeworld last gate; the four realm origins are then any-order
                currency = "ice_coins",
                cost = 100000,
            },
            boosts = {},
            synthetic = {
                center = { x = -374, y = 2000, z = 377 },
                size = { x = 321, y = 4, z = 338 },
                floor_y = 2000.5,
                spawn_position = { x = -374, y = 2006, z = 377 },
            },
        },
        Heaven_1_Desert = {
            id = "Heaven_1_Desert",
            kind = "area",
            element = "desert",
            zone_level = 5,
            mining_currency = "desert_coins",
            display_name = "Empyrean Sands",
            order = 8,
            unlock = {
                unlocked_by_default = false,
                required_zone = "Desert", -- homeworld last gate; the four realm origins are then any-order
                currency = "desert_coins",
                cost = 100000,
            },
            boosts = {},
            synthetic = {
                center = { x = -126, y = 2000, z = 474 },
                size = { x = 331, y = 4, z = 318 },
                floor_y = 2000.5,
                spawn_position = { x = -126, y = 2006, z = 474 },
            },
        },
        Heaven_1_Grass = {
            id = "Heaven_1_Grass",
            kind = "area",
            element = "grass",
            zone_level = 5,
            mining_currency = "grass_coins",
            display_name = "Empyrean Grove",
            order = 9,
            unlock = {
                unlocked_by_default = false,
                required_zone = "Desert", -- homeworld last gate; the four realm origins are then any-order
                currency = "grass_coins",
                cost = 100000,
            },
            boosts = {},
            synthetic = {
                center = { x = -150, y = 2000, z = 266 },
                size = { x = 351, y = 4, z = 278 },
                floor_y = 2000.5,
                spawn_position = { x = -150, y = 2006, z = 266 },
            },
        },
        -- Hell_1: four independent per-origin zones (unlock any order, 100k each).
        Hell_1_Lava = {
            id = "Hell_1_Lava",
            kind = "area",
            element = "lava",
            zone_level = 5,
            mining_currency = "lava_coins",
            display_name = "Infernal Lava",
            order = 10,
            unlock = {
                unlocked_by_default = false,
                required_zone = "Desert", -- homeworld last gate; the four realm origins are then any-order
                currency = "lava_coins",
                cost = 100000,
            },
            boosts = {},
            synthetic = {
                center = { x = -206, y = -1999, z = 67 },
                size = { x = 361, y = 4, z = 458 },
                floor_y = -1998.5,
                spawn_position = { x = -206, y = -1993, z = 67 },
            },
        },
        Hell_1_Ice = {
            id = "Hell_1_Ice",
            kind = "area",
            element = "ice",
            zone_level = 5,
            mining_currency = "ice_coins",
            display_name = "Infernal Frost",
            order = 11,
            unlock = {
                unlocked_by_default = false,
                required_zone = "Desert", -- homeworld last gate; the four realm origins are then any-order
                currency = "ice_coins",
                cost = 100000,
            },
            boosts = {},
            synthetic = {
                center = { x = -374, y = -1999, z = 377 },
                size = { x = 321, y = 4, z = 338 },
                floor_y = -1998.5,
                spawn_position = { x = -374, y = -1993, z = 377 },
            },
        },
        Hell_1_Desert = {
            id = "Hell_1_Desert",
            kind = "area",
            element = "desert",
            zone_level = 5,
            mining_currency = "desert_coins",
            display_name = "Infernal Sands",
            order = 12,
            unlock = {
                unlocked_by_default = false,
                required_zone = "Desert", -- homeworld last gate; the four realm origins are then any-order
                currency = "desert_coins",
                cost = 100000,
            },
            boosts = {},
            synthetic = {
                center = { x = -126, y = -1999, z = 474 },
                size = { x = 331, y = 4, z = 318 },
                floor_y = -1998.5,
                spawn_position = { x = -126, y = -1993, z = 474 },
            },
        },
        Hell_1_Grass = {
            id = "Hell_1_Grass",
            kind = "area",
            element = "grass",
            zone_level = 5,
            mining_currency = "grass_coins",
            display_name = "Infernal Grove",
            order = 13,
            unlock = {
                unlocked_by_default = false,
                required_zone = "Desert", -- homeworld last gate; the four realm origins are then any-order
                currency = "grass_coins",
                cost = 100000,
            },
            boosts = {},
            synthetic = {
                center = { x = -150, y = -1999, z = 266 },
                size = { x = 351, y = 4, z = 278 },
                floor_y = -1998.5,
                spawn_position = { x = -150, y = -1993, z = 266 },
            },
        },
        -- ===== LAYER 2 (Heaven 2 "Aurora Reaches" +4000 / Hell 2 "Frozen Dark" -4000) =====
        -- Mirrors the Heaven_1/Hell_1 footprints at the layer-2 Y; egg_stands placed from config
        -- (WorldBindingService) using the layer-2 egg pools. zone_level 6 (one tier over layer 1).
        Heaven_2_Lava = {
            id = "Heaven_2_Lava",
            kind = "area",
            element = "lava",
            zone_level = 6,
            mining_currency = "lava_coins",
            display_name = "Aurora Lava",
            order = 14,
            unlock = {
                unlocked_by_default = false,
                required_zone = "Desert",
                currency = "lava_coins",
                cost = 500000,
            },
            boosts = {},
            synthetic = {
                center = { x = -206, y = 4000, z = 67 },
                size = { x = 361, y = 4, z = 458 },
                floor_y = 4000.5,
                spawn_position = { x = -206, y = 4006, z = 67 },
                egg_stands = {},
            },
        },
        Heaven_2_Ice = {
            id = "Heaven_2_Ice",
            kind = "area",
            element = "ice",
            zone_level = 6,
            mining_currency = "ice_coins",
            display_name = "Aurora Frost",
            order = 15,
            unlock = {
                unlocked_by_default = false,
                required_zone = "Desert",
                currency = "ice_coins",
                cost = 500000,
            },
            boosts = {},
            synthetic = {
                center = { x = -374, y = 4000, z = 377 },
                size = { x = 321, y = 4, z = 338 },
                floor_y = 4000.5,
                spawn_position = { x = -374, y = 4006, z = 377 },
                egg_stands = {},
            },
        },
        Heaven_2_Desert = {
            id = "Heaven_2_Desert",
            kind = "area",
            element = "desert",
            zone_level = 6,
            mining_currency = "desert_coins",
            display_name = "Aurora Sands",
            order = 16,
            unlock = {
                unlocked_by_default = false,
                required_zone = "Desert",
                currency = "desert_coins",
                cost = 500000,
            },
            boosts = {},
            synthetic = {
                center = { x = -126, y = 4000, z = 474 },
                size = { x = 331, y = 4, z = 318 },
                floor_y = 4000.5,
                spawn_position = { x = -126, y = 4006, z = 474 },
                egg_stands = {},
            },
        },
        Heaven_2_Grass = {
            id = "Heaven_2_Grass",
            kind = "area",
            element = "grass",
            zone_level = 6,
            mining_currency = "grass_coins",
            display_name = "Aurora Grove",
            order = 17,
            unlock = {
                unlocked_by_default = false,
                required_zone = "Desert",
                currency = "grass_coins",
                cost = 500000,
            },
            boosts = {},
            synthetic = {
                center = { x = -150, y = 4000, z = 266 },
                size = { x = 351, y = 4, z = 278 },
                floor_y = 4000.5,
                spawn_position = { x = -150, y = 4006, z = 266 },
                egg_stands = {},
            },
        },
        Hell_2_Lava = {
            id = "Hell_2_Lava",
            kind = "area",
            element = "lava",
            zone_level = 6,
            mining_currency = "lava_coins",
            display_name = "Frozen Lava",
            order = 18,
            unlock = {
                unlocked_by_default = false,
                required_zone = "Desert",
                currency = "lava_coins",
                cost = 500000,
            },
            boosts = {},
            synthetic = {
                center = { x = -206, y = -3999, z = 67 },
                size = { x = 361, y = 4, z = 458 },
                floor_y = -3998.5,
                spawn_position = { x = -206, y = -3993, z = 67 },
                egg_stands = {},
            },
        },
        Hell_2_Ice = {
            id = "Hell_2_Ice",
            kind = "area",
            element = "ice",
            zone_level = 6,
            mining_currency = "ice_coins",
            display_name = "Frozen Frost",
            order = 19,
            unlock = {
                unlocked_by_default = false,
                required_zone = "Desert",
                currency = "ice_coins",
                cost = 500000,
            },
            boosts = {},
            synthetic = {
                center = { x = -374, y = -3999, z = 377 },
                size = { x = 321, y = 4, z = 338 },
                floor_y = -3998.5,
                spawn_position = { x = -374, y = -3993, z = 377 },
                egg_stands = {},
            },
        },
        Hell_2_Desert = {
            id = "Hell_2_Desert",
            kind = "area",
            element = "desert",
            zone_level = 6,
            mining_currency = "desert_coins",
            display_name = "Frozen Sands",
            order = 20,
            unlock = {
                unlocked_by_default = false,
                required_zone = "Desert",
                currency = "desert_coins",
                cost = 500000,
            },
            boosts = {},
            synthetic = {
                center = { x = -126, y = -3999, z = 474 },
                size = { x = 331, y = 4, z = 318 },
                floor_y = -3998.5,
                spawn_position = { x = -126, y = -3993, z = 474 },
                egg_stands = {},
            },
        },
        Hell_2_Grass = {
            id = "Hell_2_Grass",
            kind = "area",
            element = "grass",
            zone_level = 6,
            mining_currency = "grass_coins",
            display_name = "Frozen Grove",
            order = 21,
            unlock = {
                unlocked_by_default = false,
                required_zone = "Desert",
                currency = "grass_coins",
                cost = 500000,
            },
            boosts = {},
            synthetic = {
                center = { x = -150, y = -3999, z = 266 },
                size = { x = 351, y = 4, z = 278 },
                floor_y = -3998.5,
                spawn_position = { x = -150, y = -3993, z = 266 },
                egg_stands = {},
            },
        },
    },
}
