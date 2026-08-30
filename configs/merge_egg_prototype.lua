--[[
    Merge an Egg Phase 6.

    The complete ten-bay realm is permanent Studio-authored geometry. Its explicit Edit-mode bake
    starts from one atomic bay fixture; runtime never builds or transforms the map. The realm has
    no tile kit or streaming/chunk lifecycle. Up to nine stationary NPC principals own
    independently targeted temporary defense squads; every principal, unit, and enemy remains
    session-only.
]]

local NORMAL_EGG_PROGRESSION = {
    "grass_egg",
    "ice_egg",
    "lava_egg",
    "desert_egg",
    "bloom_egg",
    "aurora_egg",
    "solar_egg",
    "gilded_egg",
    "blight_egg",
    "black_ice_egg",
    "infernal_egg",
    "ash_egg",
    "heaven2_grass_egg",
    "heaven2_ice_egg",
    "heaven2_fire_egg",
    "heaven2_desert_egg",
    "hell2_grass_egg",
    "hell2_ice_egg",
    "hell2_fire_egg",
    "hell2_desert_egg",
    "heaven3_grass_egg",
    "heaven3_ice_egg",
    "heaven3_fire_egg",
    "heaven3_desert_egg",
    "hell3_grass_egg",
    "hell3_ice_egg",
    "hell3_fire_egg",
    "hell3_desert_egg",
}

local MERGE_EGG_PROGRESSION = {}
local MERGE_EGG_DRAFT_ROLLS = {}
local MERGE_EGG_TEAM_POSITIONS = {}
for pass = 1, 2 do
    for normalTier, eggId in ipairs(NORMAL_EGG_PROGRESSION) do
        MERGE_EGG_PROGRESSION[#MERGE_EGG_PROGRESSION + 1] = eggId
        MERGE_EGG_DRAFT_ROLLS[#MERGE_EGG_DRAFT_ROLLS + 1] = ((normalTier - 1) % 4) + 2
        local positions = pass == 2 and 6
            or normalTier <= 4 and 3
            or normalTier <= 12 and 4
            or normalTier <= 20 and 5
            or 6
        MERGE_EGG_TEAM_POSITIONS[#MERGE_EGG_TEAM_POSITIONS + 1] = positions
    end
end

return {
    version = 6,
    enabled = true,
    stream_timeout = 8,

    gate = {
        hook_name = "HallOfWorldsPortal",
        prompt_name = "MergeEggPrototypeEnterPrompt",
        action_text = "Enter",
        object_text = "Coming Soon",
        title = "COMING SOON",
        access = {
            -- Preview access is ID-only in every environment. Reuse the canonical
            -- internal-account registry used by leaderboards/retention, then add collaborators
            -- without changing their global internal-account classification.
            internal_accounts = true,
            additional_user_ids = {
                536245038, -- KadeDevLux
            },
            studio_bypass = false,
        },
        return_route = {
            -- The dedicated Merge place owns a second HallOfWorldsPortal hook in its common mall.
            -- Unlike preview entry, returning to the main Farm and Fight place is public.
            hook_name = "HallOfWorldsPortal",
            prompt_name = "MergeEggPrototypeExitPrompt",
            action_text = "Return",
            object_text = "Farm & Fight",
            label = "RETURN TO FARM & FIGHT",
            destination_role = "main",
            public = true,
            color = { 82, 216, 255 },
        },
    },

    world = {
        maps_root = "Maps",
        model_name = "MergeEggPrototype",
        area_id = "MergeEggPrototype",
        player_spawn = "PlayerSpawn",
        hatcher_control = "HatcherControl",
        hatcher_control_position = { x = -38, y = 3, z = -230 },
        hatcher_control_local_position = { x = -38, y = 3, z = -80 },
        hatcher_spawn = "HatcherSpawn",
        start_platform = "StartPlatform",
        egg_create_control = "EggCreateControl",
        egg_base_upgrade_control = "EggBaseUpgradeControl",
        egg_merge_control = "EggMergeControl",
        equip_best_control = "EquipBestControl",
        merge_board = "MergeBoard",
        reset_control = "ResetControl",
        exit_control = "ExitControl",
        enemy_spawn_area = "EnemySpawnArea",
        enemy_finish_line = "EnemyFinishLine",
        bulwark_line = "BulwarkLine",
        breach_line = "BreachLine",
        enemy_portal_visual = "EnemyPortalVisual",
        bounds = {
            center_x = -16000,
            center_z = -150,
            half_x = 46,
            half_z = 149,
            inset = 1,
        },
        containment_walls = {
            enabled = true,
            height = 64,
            thickness = 2,
            close_player_entrance = false,
        },
    },

    -- Permanent Studio-authored realm. `scripts/studio/bake_merge_egg_realm.luau` consumes the
    -- temporary MergeEggPrototype source fixture and writes all ten editable bays plus their hall
    -- to Workspace.Maps.MergeEggRealm. Runtime only validates/binds this map and owns claims.
    realm_layout = {
        enabled = true,
        authored = true,
        root_name = "MergeEggRealm",
        source_model_name = "MergeEggPrototype",
        -- Temporary authoring selector. Flip only `side` to "hell" when Hell Bay 1 becomes the
        -- refinement target; set `enabled` false to restore random empty-bay assignment.
        primary_bay_id = "heaven_01",
        authoring_bay = {
            enabled = true,
            side = "heaven",
            column = 1,
        },
        bays_per_side = 5,
        center_x = -16000,
        center_z = -325,
        floor_y = 1,
        -- 100-ish playable width plus the reference's 36-stud landscaped berm.
        bay_pitch = 136,
        bay_depth = 300,
        -- Raised bays overlook a formal civic mall ten studs below the play fields. The centerline
        -- river is straight; water and lava meet in a narrow steam/pearl cancellation band.
        corridor_gap = 180,
        mall_length = 680,
        mall_width = 180,
        mall_drop = 10,
        river_width = 18,
        river_wave_amplitude = 0,
        river_segments = 40,
        river_bridge_count = 4,
        bay_stair_width = 56,
        bay_stair_steps = 10,
        bay_stair_run = 44,
        plaza_stair_steps = 10,
        plaza_stair_run = 44,
        end_plaza_diameter = 184,
        hell_plaza_size_x = 184,
        hell_plaza_size_z = 184,
        heaven_plaza_size_x = 184,
        heaven_plaza_size_z = 184,
        lower_park_drop = 22,
        lower_park_size_x = 190,
        lower_park_size_z = 220,
        -- Sightlines stay open over low stone walls. Invisible collision lives farther into the
        -- planting seams, preventing side-entry into another bay while leaving the front open.
        lane_visible_wall_height = 4,
        lane_boundary_height = 22,
        lane_boundary_offset = 52,
        lane_boundary_extension = 14,
        themes = {
            heaven = {
                accent = { 105, 220, 255 },
                floor = { 184, 198, 210 },
                platform = { 222, 229, 236 },
                wall = { 126, 145, 165 },
                asset_sets = {
                    { "cloud_sapling", "pearl_quartz", "heaven_star_fountain" },
                    { "frosted_pine_1", "amethyst_geode", "heaven_diamond_altar" },
                    { "luminous_canopy_tree", "pearlroot_boulder", "heaven_golden_guardian" },
                    { "cherry_heaven_tree_1", "rosegold_geode", "heaven_marble_throne" },
                    { "empyrean_bloom_cactus", "bloomstone_shelf", "heaven_golden_throne" },
                },
            },
            hell = {
                accent = { 255, 65, 35 },
                floor = { 52, 39, 47 },
                platform = { 72, 47, 59 },
                wall = { 45, 30, 39 },
                asset_sets = {
                    { "withered_sapling", "bone_rock", "hell_skull_lantern" },
                    { "coldfire_pine", "dark_ice_shard", "hell_infernal_archive" },
                    { "dreadthorn_tree", "dreadspire_faultstone", "hell_infernal_fountain" },
                    { "lava_eye_tree", "cinder_rock", "hell_infernal_throne_flat" },
                    { "dreadspire_thorn_cactus", "dreadspire_razorstone", "hell_gate_of_damned" },
                },
            },
        },
    },

    -- Nine hatcher stations share one permanent layout within each bay, but ownership is separate
    -- from authoring. A new run starts with four evenly spaced stations. The center is the first
    -- slot purchase, then the remaining positions fill symmetrically toward the lane edges.
    station_layout = {
        total_positions = 9,
        spacing = 8,
        initial_position_slots = { 2, 4, 6, 8 },
        unlock_position_slots = { 5, 3, 7, 1, 9 },
        roster_panel = {
            gap = 0.5,
            -- A strict canvas-aspect projection made the six-row roster too shallow to read from
            -- the management area. Keep the station-cell width fixed, but give the floor panel a
            -- minimum rearward footprint so its rows remain legible at normal camera angles.
            minimum_depth = 6.25,
            -- Heaven Layer 3 can field six pets; panels keep that final physical height from the
            -- beginning so a mid-run capacity increase never forces the whole HUD to reflow.
            logical_slots = 6,
        },
        deployment_pads = {
            size = 6.6,
            egg_offset = 3,
            available_color = { 82, 145, 190 },
            available_transparency = 0.3,
            occupied_transparency = 0.14,
        },
        -- Stand on the gate side of the egg (spawn looks at the gate) so the
        -- board/work area can see which egg is installed.
        captain_front_offset = 4.5,
        -- Sit the egg on the authored stand rim, not the flush floor pad.
        stand_cup_inset = 0.25,
    },

    -- Durable balance knobs. Combat/economy upgrade ranks spend the player's real Gems and persist
    -- across resets, rebirths, and sessions, while the base-egg generator and egg purchase remain
    -- resettable Waycoin progression mechanics. Final prices remain subject to prototype balance.
    management_upgrades = {
        currency = "gems",
        definitions = {
            coin_value = {
                display_name = "Coin Value",
                base_cost = 50,
                cost_growth = 1.5,
                step = 0.05,
                max_level = 20,
            },
            damage = {
                display_name = "Damage",
                base_cost = 50,
                cost_growth = 1.5,
                step = 0.05,
                max_level = 20,
            },
            fire_rate = {
                display_name = "Fire Rate",
                base_cost = 50,
                cost_growth = 1.5,
                step = 0.05,
                max_level = 20,
            },
            active_slots = {
                display_name = "Active Slots",
                base_cost = 250,
                cost_growth = 2,
                step = 1,
                max_level = 5,
            },
            egg_health = {
                display_name = "Egg HP",
                base_cost = 100,
                cost_growth = 1.75,
                step = 0.05,
                max_level = 20,
            },
        },
    },

    -- Every Wave-1 run starts at zero and lays 600 owner-only Waycoins beyond the Bulwark. This is
    -- invariant across first visits, completed tutorials, pre-checkpoint resets, and rebirths.
    -- Five physical stacks preserve the collection lesson while leaving a 100-Waycoin buffer after
    -- the tutorial's five Earth Eggs have been purchased.
    opening_economy = {
        currency = "hall_coins",
        wallet_amount = 0,
        pickup_amount = 120,
        pickup_offsets = {
            { x = -24, z = 18 },
            { x = -12, z = 18 },
            { x = 0, z = 18 },
            { x = 12, z = 18 },
            { x = 24, z = 18 },
        },
    },

    -- First-visit teaching is server-authoritative setup, not a separate safe room. The player may
    -- spend the 600-Waycoin opening freely: Wave 1 waits only until at least one egg is deployed and
    -- one equal-tier combination has happened, either on the board or at a deployed hatcher. Auto
    -- Collector owners may skip only the walking portion.
    tutorial = {
        enabled = true,
        step_pause_seconds = 1.25,
        resume_wave_delay_seconds = 3,
        auto_collector_attribute = "AutoCollectorEnabled",
        required_eggs = 5,
        click_cue_purchase_count = 3,
        disable_after_rebirth = true,
        steps = {
            collect_setup = {
                title = "COLLECT 600 WAYCOINS",
                body = "Follow the chevrons and collect all five Waycoin stacks.",
                auto_body = "Your Coin Pup collects the five stacks for you. You can skip the walking lesson.",
                target = "coins",
            },
            create_five = {
                title = "CREATE FIVE EARTH EGGS",
                body = "Click the highlighted BUY EGG button five times.",
                target = "buy_egg",
            },
            combine_once = {
                title = "COMBINE TWO MATCHING EGGS",
                body = "Merge them on the board or drag one onto a deployed matching egg.",
                target = "board_egg",
            },
            deploy_one = {
                title = "DEPLOY AN EGG",
                body = "Drag an egg to any open frontline slot, or press EQUIP BEST.",
                target = "board_egg",
            },
        },
    },

    -- The existing Future Self / Colorado NPC-principal lifecycle consumes this base definition.
    -- The owner avatar is a temporary visual stand-in for purpose-built hatcher NPC assets.
    principal = {
        avatar_owner = true,
        level = 1, -- startup fallback only; runtime snapshots the entering player's combat level
        squad = {},
        alliance = { enabled = false },
        powers = {},
        auto_farm = { enabled = false },
    },

    -- Required by the config schema for compatibility; Phase 5 never reads a fixed roster.
    squad = {},

    -- Freeze one fair combat baseline when the player enters. Ordinary enemies, tanks, NPC pets,
    -- the temporary player escort, and installed eggs all use it. Lieutenant/boss rank offsets are
    -- still applied by EnemyService on top of that common base.
    combat_level = {
        source = "active_player_effective_level",
        freeze_for_run = true,
        rank_tiers = {
            trash = "trash_mob",
            tank = "trash_mob",
            lieutenant = "mid_tier",
            boss = "boss",
            villain = "boss",
            archvillain = "archvillain",
        },
    },

    team = {
        return_ready_distance = 20,
        starts_with_egg = false,
        -- Capacity now belongs to the world stage. Home fields three pets per hatcher and Heaven
        -- Layer 1 fields four; egg tier changes draft quality, not formation size.
        positions_by_egg_tier = { 3, 3, 3, 3 },
        -- Studio balance variants keep the actual pet definitions immutable. The runner can select
        -- one with { automation = "coin_runner", experiment = <id> } for matched A/B/C runs.
        balance_experiments = {
            default = "world_draft",
            modes = {
                world_draft = {
                    stage_positions = true,
                    draft_quality = true,
                    origin_power_per_tier = 0,
                },
                positions = {
                    positions_by_egg_tier = { 3, 4, 5, 6 },
                    origin_power_per_tier = 0,
                },
                origin_10 = {
                    positions_by_egg_tier = { 4, 4, 4, 4 },
                    origin_power_per_tier = 0.10,
                },
                origin_20 = {
                    positions_by_egg_tier = { 4, 4, 4, 4 },
                    origin_power_per_tier = 0.20,
                },
            },
        },
        earth_egg_pricing = {
            currency = "hall_coins",
            base_amount = 100,
            -- The generator begins with Grass at 100 Waycoins. Its output tier and creation price
            -- advance separately below; two equal board eggs still merge into the next tier.
            growth = 2,
        },
        base_egg_generator = {
            initial_tier = 1,
            -- Grass costs 100. The first generator advance changes its output to Ice at 250;
            -- later creation prices double to 500, 1,000, 2,000, and so on.
            first_upgraded_egg_cost = 250,
            egg_cost_growth = 2,
            -- Grass → Ice costs 1,000; every later generator advance doubles.
            first_upgrade_cost = 1000,
            upgrade_cost_growth = 2,
        },
        prototype_huge_progression = {
            normal_tier_count = #NORMAL_EGG_PROGRESSION,
            start_tier = #NORMAL_EGG_PROGRESSION + 1,
            counts_as_real_huge = false,
            design_horizon_wave = 140,
        },
        merge_board = {
            merge_ratio = 2,
            station_use_distance = 16,
            board_use_distance = 36,
            rows = 4,
            columns = 4,
            slot_size = 6.6,
            slot_gap = 0.6,
            -- Prefer the exact StartPlatform rear-edge anchor. This remains the fallback when an
            -- authored map lacks that pedestal.
            forward_offset = 24,
            anchor_to_start_platform_back_edge = true,
            egg_height = 4.8,
            rotate_degrees_per_second = 28,
            empty_slot_color = { 45, 52, 64 },
            empty_slot_transparency = 0.08,
            egg_sign_size = 4.8,
            egg_sign_transparency = 0.12,
            equip_best_size = { x = 7, z = 12 },
            equip_best_gap = 1.5,
            -- The plate points upfield; turn its copy back toward the management side.
            equip_best_rotation_degrees = 90,
            equip_best_text_rotation_degrees = 180,
            -- Tier identity: matching colors mean the eggs can merge. The sequence repeats every
            -- six tiers; Earth begins green and Ice begins blue.
            slot_colors = {
                { 87, 210, 112 },
                { 76, 165, 245 },
                { 174, 100, 235 },
                { 242, 82, 91 },
                { 255, 151, 64 },
                { 250, 220, 80 },
            },
        },
        edge_towers = {
            model_folder_name = "MergeCannons",
            model_tier_count = 4,
            current_art_tier = 2,
            -- Tier 1 intentionally reads as the starter chassis; Tier 2 is the corrected
            -- Repulsor-sized reference shared by all six current cannon meshes.
            tier_1_scale = 0.85,
            available_roles = {
                "heal",
                "rage",
                "debuff",
                "gravity",
                "repulsor",
                "nullifier",
            },
            -- First combat slice: spawn the current-art cannon on both authored pads and loft a
            -- spear toward the nearest in-lane enemy, or a gate-side landing point if the lane is
            -- empty. Upgrades and role acquisition stay unwired.
            starter_role = "repulsor",
            spear = {
                interval = 2.4,
                flight_seconds = 0.85,
                apex_height = 14,
                range = 90,
                length = 4.2,
                land_seconds = 1.2,
            },
        },
        -- The existing camera-facing button is only a presentation surface. The server accepts an
        -- egg action when the avatar is both safely behind the actual BulwarkLine and physically
        -- beneath the selected captain's button.
        build_access = {
            minimum_bulwark_depth = 4,
            maximum_hatcher_distance = 18,
        },
        -- Each captain begins empty and can accept any board egg unchanged. Once occupied, the
        -- deployed egg becomes one half of a normal merge: another board egg of the same tier
        -- advances the hatcher by one tier and improves best-of-N quality for future FIFO rolls.
        egg_progression = {
            "grass_egg",
            "ice_egg",
            "lava_egg",
            "desert_egg",
        },
    },

    -- The default run owns one continuous Home → Heaven 3 egg track. Combat layers can change
    -- pressure at authored wave checkpoints, but they never gate which next egg can be purchased.
    -- Heaven 1 can also be launched directly for isolated combat tuning.
    progression_loop = {
        default_stage = "home",
        order = { "home", "heaven_1" },
        stages = {
            home = {
                display_name = "Home → Heaven • Layer 3",
                team_positions = 3,
                team_positions_by_egg_tier = MERGE_EGG_TEAM_POSITIONS,
                egg_progression = MERGE_EGG_PROGRESSION,
                draft_rolls_by_tier = MERGE_EGG_DRAFT_ROLLS,
                egg_pricing = {
                    currency = "hall_coins",
                    base_amount = 100,
                    growth = 2,
                },
                starting_coins = 100,
                enemy = {
                    hp_multiplier = 1,
                    damage_multiplier = 1,
                    reward_multiplier = 1,
                },
                -- Eggs are never gated by these combat layers. They form one continuous eight-egg
                -- price track; the layer checkpoint changes enemy pressure and payout only.
                combat_layers = {
                    {
                        id = "home",
                        display_name = "Home",
                        through_wave = 10,
                        enemy = {
                            hp_multiplier = 1,
                            damage_multiplier = 1,
                            reward_multiplier = 1,
                        },
                    },
                    {
                        id = "heaven_1",
                        display_name = "Heaven • Layer 1",
                        through_wave = 20,
                        enemy = {
                            hp_multiplier = 2.25,
                            damage_multiplier = 1.5,
                            reward_multiplier = 5,
                        },
                    },
                    {
                        id = "heaven_2",
                        display_name = "Heaven • Layer 2",
                        through_wave = 30,
                        enemy = {
                            hp_multiplier = 4.5,
                            damage_multiplier = 2.1,
                            reward_multiplier = 12,
                        },
                    },
                    {
                        id = "heaven_3",
                        display_name = "Heaven • Layer 3",
                        through_wave = 999999,
                        enemy = {
                            hp_multiplier = 8,
                            damage_multiplier = 3,
                            reward_multiplier = 25,
                        },
                    },
                },
            },
            heaven_1 = {
                display_name = "Heaven • Layers 1–3",
                team_positions = 4,
                team_positions_by_egg_tier = {
                    4,
                    4,
                    4,
                    4,
                    5,
                    5,
                    5,
                    5,
                    6,
                    6,
                    6,
                    6,
                },
                -- Preserve the Home origin order: Earth, Ice, Lava, Desert.
                egg_progression = {
                    "bloom_egg",
                    "aurora_egg",
                    "solar_egg",
                    "gilded_egg",
                    "heaven2_grass_egg",
                    "heaven2_ice_egg",
                    "heaven2_fire_egg",
                    "heaven2_desert_egg",
                    "heaven3_grass_egg",
                    "heaven3_ice_egg",
                    "heaven3_fire_egg",
                    "heaven3_desert_egg",
                },
                draft_rolls_by_tier = {
                    2,
                    3,
                    4,
                    5,
                    2,
                    3,
                    4,
                    5,
                    2,
                    3,
                    4,
                    5,
                },
                egg_pricing = {
                    currency = "hall_coins",
                    base_amount = 1600,
                    growth = 2,
                },
                -- Four first-tier Heaven eggs for the isolated tuning entry point.
                independent_starting_coins = 6400,
                enemy = {
                    hp_multiplier = 2.25,
                    damage_multiplier = 1.5,
                    reward_multiplier = 5,
                },
                combat_layers = {
                    {
                        id = "heaven_1",
                        display_name = "Heaven • Layer 1",
                        through_wave = 20,
                        enemy = {
                            hp_multiplier = 2.25,
                            damage_multiplier = 1.5,
                            reward_multiplier = 5,
                        },
                    },
                    {
                        id = "heaven_2",
                        display_name = "Heaven • Layer 2",
                        through_wave = 30,
                        enemy = {
                            hp_multiplier = 4.5,
                            damage_multiplier = 2.1,
                            reward_multiplier = 12,
                        },
                    },
                    {
                        id = "heaven_3",
                        display_name = "Heaven • Layer 3",
                        through_wave = 999999,
                        enemy = {
                            hp_multiplier = 8,
                            damage_multiplier = 3,
                            reward_multiplier = 25,
                        },
                    },
                },
            },
        },
    },

    -- A Studio-only upper-bound balance runner. It skips the opening five-stack pickup lesson by
    -- temporarily giving the active prototype session the equivalent 100-Waycoin bankroll, then
    -- walks the actual avatar between later physical drops,
    -- the Earth creation station, the two-to-one merge station, and the selected hatcher. Reset or
    -- exit restores the tester's pre-run Waycoin balance. The default run crafts continuously
    -- through Home and Heaven 1, then sweeps after Wave 20.
    automation = {
        coin_runner = {
            starting_coins = 100,
            random_seed = 260826,
            target_hatchers = 4,
            sequential_stages = true,
            completed_drop_poll_seconds = 0.6,
            navigation_timeout = 18,
            hatcher_arrival_distance = 7,
            station_arrival_distance = 7,
            drop_arrival_distance = 6,
            idle_poll_seconds = 0.15,
            maximum_navigation_failures = 8,
        },
        -- Checkpoint upgrade calibration keeps combat/economy state fixed while increasing one
        -- permanent-style modifier after each failed post-10 attempt. The service-owned sweep can
        -- chain isolated phases without an external Studio coroutine losing its place.
        upgrade_runner = {
            step = 0.05,
            phases = { "speed", "power", "coins" },
            maximum_navigation_restarts = 2,
        },
    },

    -- The shipping egg roll is now the source of every prototype pet. This queue experiment
    -- preserves each NPC team's world-scaled stable slots: a defeated slot enters its captain's
    -- FIFO, then the current egg supplies two to five candidates. The weakest becomes a player
    -- cast-off and the composition-aware draft picks the hatcher replacement from the rest. Species,
    -- variant, and the rare Huge roll can change; only the slot itself remains stable.
    -- Four real seconds at 4× combat approximates a 16-second production cadence for comparison.
    reinforcement = {
        enabled = true,
        hatch_seconds = 4,
        -- Any real combat damage to an installed egg interrupts that hatcher's production. Each
        -- later hit refreshes the window, so a hatcher under sustained rear-line pressure cannot
        -- manufacture its way out until defenders peel the attackers away.
        damage_production_lock_seconds = 5,
        queue_policy = "per_team_fifo_random_egg_roll",
    },

    -- Every completed hatcher draft gives its weakest candidate to a session-only player roster.
    -- The strongest available tank/ranged/melee become the player's three-pet escort; the paid
    -- extra-equip-slot feature adds a fourth support slot. A defeated escort slot stays empty for
    -- 30 real seconds, then takes the strongest matching cast-off still on the reserve bench.
    player_reserve = {
        enabled = true,
        base_slots = 3,
        extra_slot_feature = "extra_equip_slots",
        maximum_slots = 4,
        replacement_seconds = 30,
        castoff_policy = "weakest_draft_candidate",
        roles = { "tank", "ranged", "melee", "support" },
        -- The player's temporary combat escort guards the breach while the character manages the
        -- board. Ordinary targets may pull it into combat; its idle formation returns here rather
        -- than following the character through the rear work area.
        hold_at_breach_line = true,
        -- Simple remains the accessible, fully automatic reserve-roster ruleset. Full keeps the
        -- player's real equipped squad and normal down/revive/power rules. A saved Full preference
        -- resolves back to Simple until either eligibility route has been earned.
        full_mode = {
            default_mode = "full",
            minimum_level = 10,
            notices = {
                full_intro = {
                    title = "FULL COMBAT ACTIVE",
                    body = "Your real pets and powers are active in Merge Defense. If you prefer automatic pet management, Simple Mode is always available in Settings.",
                    primary_label = "OKAY",
                },
                full_unlock_choice = {
                    title = "FULL COMBAT UNLOCKED",
                    body = "You can now manage your real pets and powers in Merge Defense. Would you like to stay in automatic Simple Mode or switch to Full Mode?",
                    primary_label = "SWITCH TO FULL",
                    secondary_label = "STAY SIMPLE",
                },
            },
            -- A real defense hatch may never jump beyond the deployed hatcher egg, and it may use
            -- only the highest corresponding egg the player has unlocked in Halo & Horns proper.
            -- Grass/Earth intentionally has no gate: it is the fresh-profile floor.
            unlock_area_by_egg = {
                ice_egg = "Ice",
                lava_egg = "Lava",
                desert_egg = "Desert",
                bloom_egg = "Heaven_1_Grass",
                aurora_egg = "Heaven_1_Ice",
                solar_egg = "Heaven_1_Lava",
                gilded_egg = "Heaven_1_Desert",
                blight_egg = "Hell_1_Grass",
                black_ice_egg = "Hell_1_Ice",
                infernal_egg = "Hell_1_Lava",
                ash_egg = "Hell_1_Desert",
                heaven2_grass_egg = "Heaven_2_Grass",
                heaven2_ice_egg = "Heaven_2_Ice",
                heaven2_fire_egg = "Heaven_2_Lava",
                heaven2_desert_egg = "Heaven_2_Desert",
                hell2_grass_egg = "Hell_2_Grass",
                hell2_ice_egg = "Hell_2_Ice",
                hell2_fire_egg = "Hell_2_Lava",
                hell2_desert_egg = "Hell_2_Desert",
                heaven3_grass_egg = "Heaven_3_Grass",
                heaven3_ice_egg = "Heaven_3_Ice",
                heaven3_fire_egg = "Heaven_3_Lava",
                heaven3_desert_egg = "Heaven_3_Desert",
                hell3_grass_egg = "Hell_3_Grass",
                hell3_ice_egg = "Hell_3_Ice",
                hell3_fire_egg = "Hell_3_Lava",
                hell3_desert_egg = "Hell_3_Desert",
            },
        },
    },

    -- Five protected reserve eggs are the prototype's base health. Every installed hatcher source
    -- is also a stationary target-only combat objective: it has endurance but cannot move, attack,
    -- regenerate, or receive pet support. Enemies can acquire these objectives only after crossing
    -- the red breach line; ordinary threat and tank taunts still decide whether they stay there.
    -- Destroying an installed source consumes one reserve egg and forces that hatcher to rebuild.
    objective = {
        starting_eggs = 5,
        damage_per_escape = 1,
        hatcher_egg_max_health = 5000,
        hatcher_egg_threat = 120,
        hatcher_egg_size = { x = 5.5, y = 7, z = 5.5 },
        hatcher_egg_offset = { x = 0, y = 3.5, z = 3 },
        -- An installed egg can protect its immediate back-line area with the existing combat
        -- anti-heal status. The first breach wakes every installed field; direct damage wakes only
        -- the struck egg. Thirty seconds active followed by thirty seconds unavailable makes this
        -- a defensive proc rather than permanent healer immunity.
        heal_denial = {
            enabled = true,
            radius = 12,
            active_seconds = 30,
            recharge_seconds = 30,
            suppression_refresh_seconds = 2,
            tick_seconds = 0.25,
            color = { 255, 70, 150 },
        },
    },

    -- Every defeat pays the prototype's board currency and independently rolls a persistent Gem
    -- pickup. The physical pickups use the same prototype-owned radius so later board upgrades can
    -- scale collection without inheriting the player's regular Magnet build.
    -- Baseline 8/30 rewards could not fund the 100-Waycoin second position before a Wave 3
    -- objective loss (the perfect runner earned only 62). The first balance correction targets the
    -- authored cadence directly: three Wave 1 Whelps gross 120 for position two, while Wave 2's
    -- lone Brute grosses another 120 toward later positions and future upgrades.
    rewards = {
        currency = "hall_coins",
        trash_amount = 40,
        tank_amount = 120,
        lieutenant_amount = 180,
        boss_amount = 2400,
        gem_drop = {
            currency = "gems",
            amount = 1,
            base_chance = 0.02,
            rank_chance_multiplier = {
                trash = 1,
                tank = 1,
                lieutenant = 3,
                boss = 10,
            },
            visual_scale = 1.5,
        },
        pickup_visual_scale = 2,
        pickup_despawn_seconds = 600,
        contain_pickups_to_world = true,
        pickup_wall_inset = 2,
    },

    -- Early-balance accelerator: both sides attack four times as often. Movement, regeneration,
    -- aggro decay, and wave timing remain at real speed so the lane still reads clearly.
    combat = {
        attack_cadence_multiplier = 4,
    },

    debug = {
        trace_bulwark_aggro = true,
        bulwark_trace_seconds = 2,
    },

    -- Keep enemy stats fixed so this isolates concurrency and cumulative squad endurance. With
    -- replacement queues enabled, an empty field may recover; the protected egg reserve is defeat.
    endurance = {
        stop_when_all_teams_defeated = false,
    },

    teams = {
        {
            id = 1,
            position_slot = 1,
            principal_name = "Merge Hatcher Team 1",
            principal_display_name = "Hatcher Captain 1",
            display_name = "NPC Team 1",
            spawn_offset = { z = 0 },
        },
        {
            id = 2,
            position_slot = 2,
            principal_name = "Merge Hatcher Team 2",
            principal_display_name = "Hatcher Captain 2",
            display_name = "NPC Team 2",
            spawn_offset = { z = 0 },
        },
        {
            id = 3,
            position_slot = 3,
            principal_name = "Merge Hatcher Team 3",
            principal_display_name = "Hatcher Captain 3",
            display_name = "NPC Team 3",
            spawn_offset = { z = 0 },
        },
        {
            id = 4,
            position_slot = 4,
            principal_name = "Merge Hatcher Team 4",
            principal_display_name = "Hatcher Captain 4",
            display_name = "NPC Team 4",
            spawn_offset = { z = 0 },
        },
        {
            id = 5,
            position_slot = 5,
            principal_name = "Merge Hatcher Team 5",
            principal_display_name = "Hatcher Captain 5",
            display_name = "NPC Team 5",
            spawn_offset = { z = 0 },
        },
        {
            id = 6,
            position_slot = 6,
            principal_name = "Merge Hatcher Team 6",
            principal_display_name = "Hatcher Captain 6",
            display_name = "NPC Team 6",
            spawn_offset = { z = 0 },
        },
        {
            id = 7,
            position_slot = 7,
            principal_name = "Merge Hatcher Team 7",
            principal_display_name = "Hatcher Captain 7",
            display_name = "NPC Team 7",
            spawn_offset = { z = 0 },
        },
        {
            id = 8,
            position_slot = 8,
            principal_name = "Merge Hatcher Team 8",
            principal_display_name = "Hatcher Captain 8",
            display_name = "NPC Team 8",
            spawn_offset = { z = 0 },
        },
        {
            id = 9,
            position_slot = 9,
            principal_name = "Merge Hatcher Team 9",
            principal_display_name = "Hatcher Captain 9",
            display_name = "NPC Team 9",
            spawn_offset = { z = 0 },
        },
    },

    enemy = {
        -- Enemy identity follows the egg installed at the hatcher receiving each front. Home eggs
        -- retain the existing Earth/Lava attackers. A Heaven egg draws models from its exact Hell
        -- counterpart, so mixed-tier hatchers can face different families in the same wave.
        rosters = {
            home = {
                faction = "home",
                by_archetype = {
                    whelp = { "lava_imp", "rabid_dog", "vicious_cat", "murder_crow" },
                    brute = { "ember_brute", "raging_bear" },
                    lieutenant = {
                        "lava_imp",
                        "rabid_dog",
                        "vicious_cat",
                        "murder_crow",
                        "ember_acolyte",
                        "rabid_bunny",
                    },
                    boss = {
                        "lava_imp",
                        "rabid_dog",
                        "vicious_cat",
                        "murder_crow",
                        "ember_brute",
                        "raging_bear",
                        "infernal_boss",
                    },
                },
            },
            opposition_egg_by_defender_egg = {
                bloom_egg = "blight_egg",
                aurora_egg = "black_ice_egg",
                solar_egg = "infernal_egg",
                gilded_egg = "ash_egg",
                blight_egg = "bloom_egg",
                black_ice_egg = "aurora_egg",
                infernal_egg = "solar_egg",
                ash_egg = "gilded_egg",
                heaven2_grass_egg = "hell2_grass_egg",
                heaven2_ice_egg = "hell2_ice_egg",
                heaven2_fire_egg = "hell2_fire_egg",
                heaven2_desert_egg = "hell2_desert_egg",
                hell2_grass_egg = "heaven2_grass_egg",
                hell2_ice_egg = "heaven2_ice_egg",
                hell2_fire_egg = "heaven2_fire_egg",
                hell2_desert_egg = "heaven2_desert_egg",
                heaven3_grass_egg = "hell3_grass_egg",
                heaven3_ice_egg = "hell3_ice_egg",
                heaven3_fire_egg = "hell3_fire_egg",
                heaven3_desert_egg = "hell3_desert_egg",
                hell3_grass_egg = "heaven3_grass_egg",
                hell3_ice_egg = "heaven3_ice_egg",
                hell3_fire_egg = "heaven3_fire_egg",
                hell3_desert_egg = "heaven3_desert_egg",
            },
            -- Every authored position is an independent weighted hatch from the whole opposing
            -- egg. Species/role/powers are selected first; the wave slot's minion/lieutenant/boss
            -- rank overlay is applied afterward. This intentionally permits unusual formations.
        },
        -- Rank is applied AFTER the independent egg hatch. HP grows from the rolled species through
        -- a multiplier (never a replacement species/default rank pool); bosses force Huge scale.
        -- These are prototype tuning knobs and deliberately do not modify the canonical pet tables.
        rank_presentation = {
            trash = {},
            tank = {},
            lieutenant = {
                tier = "mid_tier",
                hp_mult = 2,
                dmg_mult = 1,
                scale_mult = 1.2,
                display_prefix = "Lieutenant ",
            },
            boss = {
                tier = "boss",
                hp_mult = 6,
                dmg_mult = 1,
                use_huge_scale = true,
                scale_mult = 2.5,
                display_prefix = "Boss ",
            },
            villain = {
                tier = "boss",
                dmg_mult = 1,
                scale_mult = 4,
                display_prefix = "Villain ",
            },
            archvillain = {
                tier = "archvillain",
                dmg_mult = 1,
                scale_mult = 6,
                display_prefix = "Archvillain ",
            },
        },
        -- The wave plan names combat/stat archetypes. Roster selection supplies their model and
        -- native role mechanics, then these prototype values preserve the established balance.
        opposition_by_defender_realm = {
            heaven = "hell",
            hell = "heaven",
        },
        archetypes = {
            whelp = {
                id = "lava_imp",
                faction = "hell",
                rank = "trash",
                composition_role = "melee",
                reward_kind = "trash",
                hp = 320,
                armor = 0,
                damage = 4,
                cadence = 2,
            },
            brute = {
                id = "ember_brute",
                faction = "hell",
                rank = "tank",
                composition_role = "tank",
                reward_kind = "tank",
                hp = 1600,
                armor = 80,
                damage = 10,
                cadence = 2,
            },
            lieutenant = {
                id = "ember_acolyte",
                display_name = "Prototype Ember Lieutenant",
                faction = "hell",
                rank = "lieutenant",
                composition_role = "support",
                reward_kind = "lieutenant",
                hp = 1800,
                armor = 30,
                damage = 8,
                cadence = 2,
            },
            boss = {
                id = "infernal_boss",
                display_name = "Prototype Magma Wyrm",
                faction = "hell",
                rank = "boss",
                composition_role = "tank",
                reward_kind = "boss",
                hp = 9000,
                armor = 160,
                damage = 40,
                cadence = 2.5,
            },
            heaven_melee = {
                id = "zealous_cherub",
                faction = "heaven",
                rank = "trash",
                composition_role = "melee",
                reward_kind = "trash",
                hp = 320,
                armor = 0,
                damage = 4,
                cadence = 2,
            },
            heaven_tank = {
                id = "prism_warden",
                faction = "heaven",
                rank = "tank",
                composition_role = "tank",
                reward_kind = "tank",
                hp = 1600,
                armor = 80,
                damage = 10,
                cadence = 2,
            },
            heaven_lieutenant = {
                id = "radiant_sprite_guard",
                display_name = "Prototype Radiant Lieutenant",
                faction = "heaven",
                rank = "lieutenant",
                composition_role = "support",
                reward_kind = "lieutenant",
                hp = 1800,
                armor = 30,
                damage = 8,
                cadence = 2,
            },
            heaven_boss = {
                id = "celestial_archon",
                display_name = "Prototype Celestial Archon",
                faction = "heaven",
                rank = "boss",
                composition_role = "tank",
                reward_kind = "boss",
                hp = 9000,
                armor = 160,
                damage = 40,
                cadence = 2.5,
            },
        },
        -- A configuration mistake must not reproduce the 100+ model Studio pileups. Difficulty
        -- above this ceiling comes from composition, lieutenants, bosses, and later mechanics.
        maximum_wave_enemies = 32,
        march_speed = 22,
        finish_distance = 2,
        engagement_distance = 260,
        engagement_threat = 250,
        reengage_seconds = 1,
        -- Past the authored BulwarkLine, strict team ownership ends. A breached enemy becomes an
        -- open emergency target and every surviving hatcher folder receives a sustained ordinary
        -- threat floor. The breach plane uses authoritative MoveTarget plus the enemy's forward
        -- visual extent, never its stale server pivot (client interpolation owns visible movement).
        -- Refreshing the floor lets a team finish its current target, then respond.
        bulwark_threat = 250,
        bulwark_reengage_seconds = 0.5,
        bulwark_contact_padding = 1,
        -- Opening CombatTargetGroups remain authoritative long enough to establish readable
        -- fronts. Afterward, idle teams may duplicate the hardest live target. Keep no more than
        -- one team in reserve unless group pressure already requires every available defense;
        -- crossing the Bulwark releases that reserve immediately for the rest of the wave.
        idle_reinforcement_grace_seconds = 2,
        maximum_reserve_teams = 1,
        -- BulwarkLine still means all teams engage. The separate red BreachLine sits before the
        -- hatchers; crossing it is the authoritative breach. "Overrun" is a warning state, not the
        -- final egg-loss condition: it begins when breached enemies equal the remaining defenders.
        breach_overrun_enemy_per_active_pet = 1,
        breach_overrun_minimum = 4,
        spawn_inset = 5,
        finish_inset = 5,
        portal_spawn_interval = 0.15,
    },

    wave_gap = 2,

    -- Clearing every tenth wave banks the defense/economy state reached during its extended
    -- intermission. A later objective loss can restart from the following wave instead of ending
    -- the run. The first three waves after each checkpoint are authored as a recovery ramp so the
    -- checkpoint cannot become a no-income trap; later decades should preserve the same shape.
    checkpoints = {
        interval = 10,
        intermission_seconds = 8,
        restart_delay_seconds = 3,
        recovery_wave_count = 3,
        -- Ordinary play rewinds only the wave number: the live board, deployed eggs, wallet, and
        -- permanent Gem upgrades survive. Automated balance runs retain the old exact-snapshot
        -- restore so repeated experiments can share one known checkpoint state.
        gameplay_restore_mode = "retain_progress",
        test_restore_mode = "checkpoint_snapshot",
        auto_restart_gameplay = true,
    },

    -- Waves 1–20 remain a fixed, repeatable balance baseline. Wave 21 begins an effectively
    -- endless ten-wave cycle. Later cycles preserve the configured body count while replacing
    -- minions with lieutenants/bosses and applying additive HP, damage, and payout growth. The
    -- high numeric ceiling is only a session-safety guard; the player-facing meter shows infinity.
    endless_waves = {
        enabled = true,
        start_wave = 21,
        maximum_wave = 999999,
        defender_realm = "heaven",
        attacker_realm = "hell",
        scaling = {
            hp_per_cycle = 0.30,
            damage_per_cycle = 0.12,
            reward_per_cycle = 0.40,
        },
        promotions = {
            lieutenants_per_group_per_cycle = 1,
            maximum_lieutenants_per_group = 4,
            boss_every_cycles = 2,
            maximum_bosses_per_wave = 2,
        },
        cycle = {
            {
                id = "endless_recovery_1",
                gap_after = 8,
                groups = {
                    { units = { { archetype = "whelp", count = 6 } } },
                    { units = { { archetype = "whelp", count = 6 } } },
                },
            },
            {
                id = "endless_recovery_2",
                gap_after = 8,
                groups = {
                    { units = { { archetype = "whelp", count = 6 } } },
                    { units = { { archetype = "whelp", count = 6 } } },
                    { units = { { archetype = "whelp", count = 6 } } },
                },
            },
            {
                id = "endless_recovery_3",
                gap_after = 6,
                groups = {
                    { units = { { archetype = "whelp", count = 6 } } },
                    { units = { { archetype = "whelp", count = 6 } } },
                    { units = { { archetype = "whelp", count = 6 } } },
                    { units = { { archetype = "whelp", count = 6 } } },
                },
            },
            {
                id = "endless_mixed_4",
                groups = {
                    {
                        units = {
                            { archetype = "brute", count = 1 },
                            { archetype = "whelp", count = 3 },
                            { archetype = "lieutenant", count = 1 },
                        },
                    },
                    {
                        units = {
                            { archetype = "brute", count = 1 },
                            { archetype = "whelp", count = 3 },
                            { archetype = "lieutenant", count = 1 },
                        },
                    },
                    {
                        units = {
                            { archetype = "brute", count = 1 },
                            { archetype = "whelp", count = 3 },
                            { archetype = "lieutenant", count = 1 },
                        },
                    },
                    {
                        units = {
                            { archetype = "brute", count = 1 },
                            { archetype = "whelp", count = 3 },
                            { archetype = "lieutenant", count = 1 },
                        },
                    },
                },
            },
            {
                id = "endless_boss_5",
                groups = {
                    {
                        units = {
                            { archetype = "boss", count = 1 },
                            { archetype = "lieutenant", count = 1 },
                        },
                    },
                    {
                        units = {
                            { archetype = "brute", count = 1 },
                            { archetype = "whelp", count = 4 },
                            { archetype = "lieutenant", count = 1 },
                        },
                    },
                    {
                        units = {
                            { archetype = "brute", count = 1 },
                            { archetype = "whelp", count = 4 },
                            { archetype = "lieutenant", count = 1 },
                        },
                    },
                    {
                        units = {
                            { archetype = "brute", count = 1 },
                            { archetype = "whelp", count = 4 },
                            { archetype = "lieutenant", count = 1 },
                        },
                    },
                },
            },
            {
                id = "endless_lieutenants_6",
                groups = {
                    {
                        units = {
                            { archetype = "brute", count = 1 },
                            { archetype = "whelp", count = 3 },
                            { archetype = "lieutenant", count = 2 },
                        },
                    },
                    {
                        units = {
                            { archetype = "brute", count = 1 },
                            { archetype = "whelp", count = 3 },
                            { archetype = "lieutenant", count = 2 },
                        },
                    },
                    {
                        units = {
                            { archetype = "brute", count = 1 },
                            { archetype = "whelp", count = 3 },
                            { archetype = "lieutenant", count = 2 },
                        },
                    },
                    {
                        units = {
                            { archetype = "brute", count = 1 },
                            { archetype = "whelp", count = 3 },
                            { archetype = "lieutenant", count = 2 },
                        },
                    },
                },
            },
            {
                id = "endless_tanks_7",
                groups = {
                    {
                        units = {
                            { archetype = "brute", count = 2 },
                            { archetype = "whelp", count = 3 },
                            { archetype = "lieutenant", count = 1 },
                        },
                    },
                    {
                        units = {
                            { archetype = "brute", count = 2 },
                            { archetype = "whelp", count = 3 },
                            { archetype = "lieutenant", count = 1 },
                        },
                    },
                    {
                        units = {
                            { archetype = "brute", count = 2 },
                            { archetype = "whelp", count = 3 },
                            { archetype = "lieutenant", count = 1 },
                        },
                    },
                    {
                        units = {
                            { archetype = "brute", count = 2 },
                            { archetype = "whelp", count = 3 },
                            { archetype = "lieutenant", count = 1 },
                        },
                    },
                },
            },
            {
                id = "endless_elites_8",
                groups = {
                    {
                        units = {
                            { archetype = "brute", count = 1 },
                            { archetype = "whelp", count = 3 },
                            { archetype = "lieutenant", count = 3 },
                        },
                    },
                    {
                        units = {
                            { archetype = "brute", count = 1 },
                            { archetype = "whelp", count = 3 },
                            { archetype = "lieutenant", count = 3 },
                        },
                    },
                    {
                        units = {
                            { archetype = "brute", count = 1 },
                            { archetype = "whelp", count = 3 },
                            { archetype = "lieutenant", count = 3 },
                        },
                    },
                    {
                        units = {
                            { archetype = "brute", count = 1 },
                            { archetype = "whelp", count = 3 },
                            { archetype = "lieutenant", count = 3 },
                        },
                    },
                },
            },
            {
                id = "endless_elites_9",
                groups = {
                    {
                        units = {
                            { archetype = "brute", count = 1 },
                            { archetype = "whelp", count = 2 },
                            { archetype = "lieutenant", count = 4 },
                        },
                    },
                    {
                        units = {
                            { archetype = "brute", count = 1 },
                            { archetype = "whelp", count = 2 },
                            { archetype = "lieutenant", count = 4 },
                        },
                    },
                    {
                        units = {
                            { archetype = "brute", count = 1 },
                            { archetype = "whelp", count = 2 },
                            { archetype = "lieutenant", count = 4 },
                        },
                    },
                    {
                        units = {
                            { archetype = "brute", count = 1 },
                            { archetype = "whelp", count = 2 },
                            { archetype = "lieutenant", count = 4 },
                        },
                    },
                },
            },
            {
                id = "endless_checkpoint_10",
                groups = {
                    {
                        units = {
                            { archetype = "boss", count = 2 },
                            { archetype = "lieutenant", count = 2 },
                        },
                    },
                    {
                        units = {
                            { archetype = "brute", count = 1 },
                            { archetype = "whelp", count = 2 },
                            { archetype = "lieutenant", count = 4 },
                        },
                    },
                    {
                        units = {
                            { archetype = "brute", count = 1 },
                            { archetype = "whelp", count = 2 },
                            { archetype = "lieutenant", count = 4 },
                        },
                    },
                    {
                        units = {
                            { archetype = "brute", count = 1 },
                            { archetype = "whelp", count = 2 },
                            { archetype = "lieutenant", count = 4 },
                        },
                    },
                },
            },
        },
    },

    -- Merge-only prestige. Rank 1 is the free starting state. Exact transitions are authored by
    -- target rank rather than extrapolated: Rank 2 costs 50,000 and Rank 3 costs 200,000, with no
    -- Rank 4 price yet. A future pass may add
    -- minimum deployed-egg tiers per rank through the empty requirements list below. Rebirth keeps
    -- permanent player progression and Gem upgrades, resets the active Merge run and wallet, and
    -- adds +100% of base allied Merge damage per rank without compounding. Rebirth percentage and
    -- the Gem damage-upgrade percentage share one additive pool (for example +100% and +45% =
    -- 2.45x total), scoped strictly to Merge Defense.
    rebirth = {
        enabled = true,
        scope = "merge_defense_only",
        currency = "hall_coins",
        costs_by_rank = {
            [2] = 50000,
            [3] = 200000,
        },
        requirements = {
            minimum_deployed_egg_tier_by_rank = {},
        },
        cost_multiplier_per_rebirth = 1,
        allied_damage_bonus_per_rebirth = 1,
        damage_stacking = "additive",
        management_damage_stacking = "additive",
        minimum_cost = 1,
        minimum_drop = 1,
        resets = { "wave", "checkpoint", "board", "deployed_eggs", "merge_wallet" },
        preserves = { "pets", "player_level", "world_unlocks", "gem_upgrades" },
        denomination_names = { "Wayfinder Coins", "Gold Bars", "Diamonds" },
        denomination_scale = 1000000000,
    },

    waves = {
        -- Each top-level group is one independently assigned front. Units within that group stay
        -- on the same front. Counts are derived from the units, so inserting or editing a wave is
        -- entirely a configuration change and never requires a matching total elsewhere.
        {
            id = "home_01_whelps",
            gap_after = 8,
            groups = {
                { units = { { archetype = "whelp", count = 3 } } },
            },
        },
        {
            id = "home_02_brute",
            gap_after = 8,
            groups = {
                { units = { { archetype = "brute", count = 1 } } },
            },
        },
        {
            id = "home_03_two_fronts",
            gap_after = 6,
            groups = {
                {
                    units = {
                        { archetype = "brute", count = 1 },
                        { archetype = "whelp", count = 3 },
                    },
                },
                { units = { { archetype = "whelp", count = 4 } } },
            },
        },
        {
            id = "home_04_three_fronts",
            groups = {
                {
                    units = {
                        { archetype = "brute", count = 1 },
                        { archetype = "whelp", count = 3 },
                    },
                },
                {
                    units = {
                        { archetype = "brute", count = 1 },
                        { archetype = "whelp", count = 3 },
                    },
                },
                { units = { { archetype = "whelp", count = 4 } } },
            },
        },
        {
            id = "home_05_four_fronts",
            groups = {
                {
                    units = {
                        { archetype = "brute", count = 1 },
                        { archetype = "whelp", count = 3 },
                    },
                },
                {
                    units = {
                        { archetype = "brute", count = 1 },
                        { archetype = "whelp", count = 3 },
                    },
                },
                {
                    units = {
                        { archetype = "brute", count = 1 },
                        { archetype = "whelp", count = 3 },
                    },
                },
                {
                    units = {
                        { archetype = "brute", count = 1 },
                        { archetype = "whelp", count = 3 },
                    },
                },
            },
        },
        {
            id = "home_06_lieutenants",
            groups = {
                {
                    units = {
                        { archetype = "brute", count = 1 },
                        { archetype = "whelp", count = 2 },
                        { archetype = "lieutenant", count = 1 },
                    },
                },
                {
                    units = {
                        { archetype = "brute", count = 1 },
                        { archetype = "whelp", count = 2 },
                        { archetype = "lieutenant", count = 1 },
                    },
                },
                {
                    units = {
                        { archetype = "brute", count = 1 },
                        { archetype = "whelp", count = 2 },
                        { archetype = "lieutenant", count = 1 },
                    },
                },
                {
                    units = {
                        { archetype = "brute", count = 1 },
                        { archetype = "whelp", count = 2 },
                        { archetype = "lieutenant", count = 1 },
                    },
                },
            },
        },
        {
            id = "home_07_reinforced",
            groups = {
                {
                    units = {
                        { archetype = "brute", count = 1 },
                        { archetype = "whelp", count = 3 },
                        { archetype = "lieutenant", count = 1 },
                    },
                },
                {
                    units = {
                        { archetype = "brute", count = 1 },
                        { archetype = "whelp", count = 3 },
                        { archetype = "lieutenant", count = 1 },
                    },
                },
                {
                    units = {
                        { archetype = "brute", count = 1 },
                        { archetype = "whelp", count = 3 },
                        { archetype = "lieutenant", count = 1 },
                    },
                },
                {
                    units = {
                        { archetype = "brute", count = 1 },
                        { archetype = "whelp", count = 3 },
                        { archetype = "lieutenant", count = 1 },
                    },
                },
            },
        },
        {
            id = "home_08_large_battle",
            groups = {
                {
                    units = {
                        { archetype = "brute", count = 1 },
                        { archetype = "whelp", count = 4 },
                        { archetype = "lieutenant", count = 1 },
                    },
                },
                {
                    units = {
                        { archetype = "brute", count = 1 },
                        { archetype = "whelp", count = 4 },
                        { archetype = "lieutenant", count = 1 },
                    },
                },
                {
                    units = {
                        { archetype = "brute", count = 1 },
                        { archetype = "whelp", count = 4 },
                        { archetype = "lieutenant", count = 1 },
                    },
                },
                {
                    units = {
                        { archetype = "brute", count = 1 },
                        { archetype = "whelp", count = 4 },
                        { archetype = "lieutenant", count = 1 },
                    },
                },
            },
        },
        {
            id = "home_09_pressure",
            groups = {
                {
                    units = {
                        { archetype = "brute", count = 1 },
                        { archetype = "whelp", count = 3 },
                        { archetype = "lieutenant", count = 1 },
                    },
                },
                {
                    units = {
                        { archetype = "brute", count = 1 },
                        { archetype = "whelp", count = 3 },
                        { archetype = "lieutenant", count = 1 },
                    },
                },
                {
                    units = {
                        { archetype = "brute", count = 1 },
                        { archetype = "whelp", count = 3 },
                        { archetype = "lieutenant", count = 1 },
                    },
                },
                {
                    units = {
                        { archetype = "brute", count = 1 },
                        { archetype = "whelp", count = 3 },
                        { archetype = "lieutenant", count = 1 },
                    },
                },
            },
        },
        {
            id = "home_10_boss",
            groups = {
                { units = { { archetype = "boss", count = 1 } } },
                {
                    units = {
                        { archetype = "brute", count = 1 },
                        { archetype = "whelp", count = 3 },
                    },
                },
                {
                    units = {
                        { archetype = "brute", count = 1 },
                        { archetype = "whelp", count = 3 },
                    },
                },
                {
                    units = {
                        { archetype = "brute", count = 1 },
                        { archetype = "whelp", count = 3 },
                    },
                },
            },
        },
        -- Once Heaven eggs enter the defense, the attacker realm remains explicitly Hell. A future
        -- Hell egg track can use the heaven_* archetypes above for the inverse matchup.
        {
            id = "heaven_01_hell_vanguard",
            defender_realm = "heaven",
            attacker_realm = "hell",
            gap_after = 8,
            groups = {
                { units = { { archetype = "whelp", count = 8 } } },
            },
        },
        {
            id = "heaven_02_reinforced",
            defender_realm = "heaven",
            attacker_realm = "hell",
            gap_after = 8,
            groups = {
                { units = { { archetype = "whelp", count = 8 } } },
                { units = { { archetype = "whelp", count = 8 } } },
            },
        },
        {
            id = "heaven_03_large_battle",
            defender_realm = "heaven",
            attacker_realm = "hell",
            gap_after = 6,
            groups = {
                { units = { { archetype = "whelp", count = 8 } } },
                { units = { { archetype = "whelp", count = 8 } } },
                { units = { { archetype = "whelp", count = 8 } } },
            },
        },
        {
            id = "heaven_04_double_lieutenants",
            defender_realm = "heaven",
            attacker_realm = "hell",
            groups = {
                {
                    units = {
                        { archetype = "brute", count = 1 },
                        { archetype = "whelp", count = 3 },
                        { archetype = "lieutenant", count = 2 },
                    },
                },
                {
                    units = {
                        { archetype = "brute", count = 1 },
                        { archetype = "whelp", count = 3 },
                        { archetype = "lieutenant", count = 2 },
                    },
                },
                {
                    units = {
                        { archetype = "brute", count = 1 },
                        { archetype = "whelp", count = 3 },
                        { archetype = "lieutenant", count = 2 },
                    },
                },
                {
                    units = {
                        { archetype = "brute", count = 1 },
                        { archetype = "whelp", count = 3 },
                        { archetype = "lieutenant", count = 2 },
                    },
                },
            },
        },
        {
            id = "heaven_05_boss",
            defender_realm = "heaven",
            attacker_realm = "hell",
            groups = {
                { units = { { archetype = "boss", count = 1 } } },
                {
                    units = {
                        { archetype = "brute", count = 1 },
                        { archetype = "whelp", count = 4 },
                        { archetype = "lieutenant", count = 1 },
                    },
                },
                {
                    units = {
                        { archetype = "brute", count = 1 },
                        { archetype = "whelp", count = 4 },
                        { archetype = "lieutenant", count = 1 },
                    },
                },
                {
                    units = {
                        { archetype = "brute", count = 1 },
                        { archetype = "whelp", count = 4 },
                        { archetype = "lieutenant", count = 1 },
                    },
                },
            },
        },
        {
            id = "heaven_06_seven_unit_fronts",
            defender_realm = "heaven",
            attacker_realm = "hell",
            groups = {
                {
                    units = {
                        { archetype = "brute", count = 1 },
                        { archetype = "whelp", count = 4 },
                        { archetype = "lieutenant", count = 2 },
                    },
                },
                {
                    units = {
                        { archetype = "brute", count = 1 },
                        { archetype = "whelp", count = 4 },
                        { archetype = "lieutenant", count = 2 },
                    },
                },
                {
                    units = {
                        { archetype = "brute", count = 1 },
                        { archetype = "whelp", count = 4 },
                        { archetype = "lieutenant", count = 2 },
                    },
                },
                {
                    units = {
                        { archetype = "brute", count = 1 },
                        { archetype = "whelp", count = 4 },
                        { archetype = "lieutenant", count = 2 },
                    },
                },
            },
        },
        {
            id = "heaven_07_tank_pressure",
            defender_realm = "heaven",
            attacker_realm = "hell",
            groups = {
                {
                    units = {
                        { archetype = "brute", count = 2 },
                        { archetype = "whelp", count = 3 },
                        { archetype = "lieutenant", count = 2 },
                    },
                },
                {
                    units = {
                        { archetype = "brute", count = 2 },
                        { archetype = "whelp", count = 3 },
                        { archetype = "lieutenant", count = 2 },
                    },
                },
                {
                    units = {
                        { archetype = "brute", count = 2 },
                        { archetype = "whelp", count = 3 },
                        { archetype = "lieutenant", count = 2 },
                    },
                },
                {
                    units = {
                        { archetype = "brute", count = 2 },
                        { archetype = "whelp", count = 3 },
                        { archetype = "lieutenant", count = 2 },
                    },
                },
            },
        },
        {
            id = "heaven_08_peak_battle",
            defender_realm = "heaven",
            attacker_realm = "hell",
            groups = {
                {
                    units = {
                        { archetype = "brute", count = 2 },
                        { archetype = "whelp", count = 4 },
                        { archetype = "lieutenant", count = 2 },
                    },
                },
                {
                    units = {
                        { archetype = "brute", count = 2 },
                        { archetype = "whelp", count = 4 },
                        { archetype = "lieutenant", count = 2 },
                    },
                },
                {
                    units = {
                        { archetype = "brute", count = 2 },
                        { archetype = "whelp", count = 4 },
                        { archetype = "lieutenant", count = 2 },
                    },
                },
                {
                    units = {
                        { archetype = "brute", count = 2 },
                        { archetype = "whelp", count = 4 },
                        { archetype = "lieutenant", count = 2 },
                    },
                },
            },
        },
        {
            id = "heaven_09_peak_composition",
            defender_realm = "heaven",
            attacker_realm = "hell",
            groups = {
                {
                    units = {
                        { archetype = "brute", count = 1 },
                        { archetype = "whelp", count = 5 },
                        { archetype = "lieutenant", count = 2 },
                    },
                },
                {
                    units = {
                        { archetype = "brute", count = 1 },
                        { archetype = "whelp", count = 5 },
                        { archetype = "lieutenant", count = 2 },
                    },
                },
                {
                    units = {
                        { archetype = "brute", count = 1 },
                        { archetype = "whelp", count = 5 },
                        { archetype = "lieutenant", count = 2 },
                    },
                },
                {
                    units = {
                        { archetype = "brute", count = 1 },
                        { archetype = "whelp", count = 5 },
                        { archetype = "lieutenant", count = 2 },
                    },
                },
            },
        },
        {
            id = "heaven_10_boss_finale",
            defender_realm = "heaven",
            attacker_realm = "hell",
            groups = {
                {
                    units = {
                        { archetype = "boss", count = 1 },
                        { archetype = "lieutenant", count = 2 },
                    },
                },
                {
                    units = {
                        { archetype = "brute", count = 2 },
                        { archetype = "whelp", count = 4 },
                        { archetype = "lieutenant", count = 2 },
                    },
                },
                {
                    units = {
                        { archetype = "brute", count = 2 },
                        { archetype = "whelp", count = 4 },
                        { archetype = "lieutenant", count = 2 },
                    },
                },
                {
                    units = {
                        { archetype = "brute", count = 2 },
                        { archetype = "whelp", count = 4 },
                        { archetype = "lieutenant", count = 2 },
                    },
                },
            },
        },
    },
}
