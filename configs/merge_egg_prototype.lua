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
        -- Four eggs belong to each world level. Home starts at three pets, then every level adds
        -- one: Heaven 1 = 4, Hell 1 = 5, Heaven 2 = 6, through Hell 3 = 9. Rebirth retains the
        -- completed nine-pet formation while its second pass improves draft quality.
        local positions = pass == 2 and 9 or 3 + math.floor((normalTier - 1) / 4)
        MERGE_EGG_TEAM_POSITIONS[#MERGE_EGG_TEAM_POSITIONS + 1] = positions
    end
end

local MERGE_TIER_ART = require(script.Parent.merge_tier_art)

return {
    version = 6,
    place_join = {
        retry_seconds = 2,
        slow_warning_seconds = 30,
        messages = {
            data = "Still syncing your data. Your bay will be assigned automatically.",
            character = "Getting your character ready…",
            bay = "Preparing your bay. No need to claim one yourself.",
            full = "Waiting for a free bay. We’ll assign one automatically.",
        },
        display_order = 120,
        position = { 0.5, 0.3 },
        width_scale = 0.7,
        height = 60,
        text_size = 20,
        background = { 20, 24, 35 },
        text_color = { 255, 224, 145 },
    },
    enabled = true,
    stream_timeout = 8,
    tier_art = MERGE_TIER_ART,

    ui = {
        egg_health_billboard = {
            width = 156,
            height = 18,
            max_distance = 180,
            vertical_gap = 0.8,
            label_text_size = 11,
            viewport_scale_min = 0.45,
            viewport_scale_max = 1,
        },
    },

    -- The two Studio-authored return gates in the dedicated Merge place use a thin cylinder named
    -- LightningRing as their only runtime hook. The client hides that marker, then derives every
    -- effect from its live CFrame and diameter so either gate can be moved or uniformly resized in
    -- Studio without rewriting coordinates here. Camera-facing lettering names the destination
    -- explicitly; Heaven leans into FARM while Hell leans into FIGHT.
    farm_fight_portals = {
        enabled = true,
        marker_name = "LightningRing",
        runtime_name = "MergeFarmFightPortalFX",
        view_distance = 220,
        scan_interval = 1.5,
        veil = {
            diameter_scale = 0.92,
            thickness = 0.06,
            material = "ForceField",
            transparency_min = 0.48,
            transparency_max = 0.66,
            pulse_seconds = 2.6,
            light_brightness = 2.2,
            light_range_scale = 1.35,
        },
        orbit = {
            count = 22,
            radius_scale = 0.86,
            inner_radius_scale = 0.64,
            part_size = 0.16,
            material = "Neon",
            angular_speed = 0.52,
            depth_amplitude = 0.24,
            radial_wave_amplitude = 0.22,
            radial_wave_cycles = 3,
            transparency_min = 0.1,
            transparency_max = 0.72,
        },
        particles = {
            texture = "rbxasset://textures/particles/sparkles_main.dds",
            rate = 15,
            lifetime = { 1.4, 2.6 },
            speed = { 0.15, 0.75 },
            rotation = { 0, 360 },
            rotational_speed = { -55, 55 },
            spread_angle = { 18, 18 },
            light_emission = 0.82,
            light_influence = 0.12,
            size = {
                { 0, 0.08 },
                { 0.45, 0.22 },
                { 1, 0 },
            },
            transparency = {
                { 0, 1 },
                { 0.12, 0.18 },
                { 0.78, 0.42 },
                { 1, 1 },
            },
        },
        beacon = {
            enabled = true,
            height_above_center = 32,
            column_bottom_gap = 2,
            column_width = 0.22,
            column_transparency = 0.42,
            core_size = 1.1,
            core_transparency = 0.08,
            core_bob = 0.3,
            material = "Neon",
            light_brightness = 2.6,
            light_range = 22,
            orbit_count = 14,
            orbit_radius = 2.8,
            orbit_part_size = 0.22,
            orbit_transparency = 0.12,
            orbit_angular_speed = 0.58,
            orbit_vertical_wave = 0.24,
        },
        lightning = {
            interval_min = 0.22,
            interval_max = 0.62,
            bolts_per_pulse = 1,
            radius_scale = 0.88,
            minimum_arc_degrees = 72,
            maximum_arc_degrees = 245,
            depth_jitter = 0.18,
            marker_size = 0.08,
            bolt = {
                enabled = true,
                duration = 0.34,
                thickness = 0.2,
                segments = 18,
                origin_limit = 1,
                strands_per_origin = 1,
                min_radius = 0,
                max_radius = 0.72,
                curve_size0 = 0,
                curve_size1 = 0,
                center_flash = false,
                animation_speed = 9,
                flicker = 0.34,
                fade_out_seconds = 0.13,
                core_enabled = true,
                core_thickness_multiplier = 0.28,
                core_opacity_multiplier = 0.9,
                sound_name = "_silent",
            },
        },
        signage = {
            canvas_size = { 360, 360 },
            max_distance = 220,
            always_on_top = false,
            light_influence = 0,
            z_offset = 0.08,
            content_rotation = 180,
            destination = {
                position = { 0.08, 0.1 },
                size = { 0.84, 0.1 },
                font = "GothamBold",
                text_size_min = 18,
                text_size_max = 34,
                stroke_transparency = 0.28,
            },
            word = {
                -- Shared baseline; the larger infernal aperture is already optically centered
                -- here. Individual gate geometry may override only this position below.
                position = { 0.05, 0.26 },
                size = { 0.9, 0.34 },
                font = "GothamBlack",
                text_size_min = 54,
                text_size_max = 150,
                stroke_transparency = 0.04,
                shimmer_seconds = 2.2,
                gradient_rotation = 12,
            },
            tagline = {
                position = { 0.1, 0.63 },
                size = { 0.8, 0.1 },
                font = "GothamBold",
                text_size_min = 16,
                text_size_max = 32,
                stroke_transparency = 0.2,
            },
            invitation = {
                position = { 0.16, 0.79 },
                size = { 0.68, 0.08 },
                font = "GothamMedium",
                text_size_min = 14,
                text_size_max = 25,
                stroke_transparency = 0.3,
                text = "STEP THROUGH TO RETURN",
            },
            divider = {
                position = { 0.24, 0.755 },
                size = { 0.52, 0.008 },
                transparency = 0.12,
            },
        },
        portals = {
            {
                id = "heaven_farm",
                ancestor_name = "Meshy_AI_Celestial_Marble_Gate_0903140522_texture",
                destination = "PORTAL TO FARM & FIGHT",
                word = "FARM",
                tagline = "GROW YOUR FORTUNE",
                layout = {
                    -- The celestial gate has a smaller visual aperture than its LightningRing
                    -- marker, so FARM needs a lower optical center than FIGHT.
                    word_position = { 0.05, 0.32 },
                },
                palette = {
                    veil = { 44, 170, 134 },
                    primary = { 255, 224, 102 },
                    secondary = { 119, 255, 194 },
                    accent = { 220, 250, 255 },
                    stroke = { 20, 57, 49 },
                    lightning = {
                        { 255, 226, 112 },
                        { 126, 255, 205 },
                        { 205, 245, 255 },
                    },
                    particles = {
                        { 255, 233, 139 },
                        { 119, 255, 194 },
                    },
                },
            },
            {
                id = "hell_fight",
                ancestor_name = "Meshy_AI_Infernal_Eclipse_Gate_0903140501_texture",
                destination = "PORTAL TO FARM & FIGHT",
                word = "FIGHT",
                tagline = "EARN IT THE HARD WAY",
                palette = {
                    veil = { 112, 17, 34 },
                    primary = { 255, 72, 45 },
                    secondary = { 255, 172, 54 },
                    accent = { 255, 222, 180 },
                    stroke = { 49, 5, 12 },
                    lightning = {
                        { 255, 54, 64 },
                        { 255, 139, 31 },
                        { 238, 55, 208 },
                    },
                    particles = {
                        { 255, 68, 42 },
                        { 255, 184, 64 },
                    },
                },
            },
        },
    },

    gate = {
        hook_name = "HallOfWorldsPortal",
        prompt_name = "MergeEggPrototypeEnterPrompt",
        action_text = "Merge Eggs & Battle Waves",
        object_text = "Small eggs. Big waves.",
        title = "MERGE EGGS • WAVE COMBAT\nSmall eggs. Big waves.",
        access = {
            -- Public release: the same policy opens the source prompt and direct-place joins.
            -- Keep preview grants available for an explicit future rollback, without changing
            -- anyone's global internal-account classification.
            public = true,
            internal_accounts = true,
            additional_user_ids = {
                536245038, -- KadeDevLux
            },
            studio_bypass = false,
        },
        return_route = {
            -- Both themed LightningRing gates are public return routes. The old cyan common-area
            -- HallOfWorldsPortal was an authoring placeholder and is removed if an older place
            -- version still contains it.
            legacy_hook_name = "HallOfWorldsPortal",
            remove_legacy_hook = true,
            expected_gate_count = 2,
            prompt_name = "MergeEggPrototypeExitPrompt",
            action_text = "Return",
            object_text = "Farm & Fight",
            destination_role = "main",
            public = true,
        },
        -- Cross-place travel can spend several seconds negotiating before the source server lets
        -- the character go. The server stamps this short-lived state before calling
        -- TeleportService; every client renders the world-space shield while the travelling
        -- player also receives a compact status card and a matching teleport loading screen.
        transit_feedback = {
            enabled = true,
            runtime_name = "MergePortalTransitFX",
            active_attribute = "MergePortalTransitActive",
            role_attribute = "MergePortalTransitRole",
            token_attribute = "MergePortalTransitToken",
            request_delay_seconds = 0.12,
            timeout_seconds = 25,
            arrival_hold_seconds = 0.65,
            arrival_fade_seconds = 0.35,
            bubble = {
                material = "ForceField",
                character_padding = 4.5,
                minimum_diameter = 8,
                maximum_diameter = 13,
                transparency_min = 0.3,
                transparency_max = 0.56,
                pulse_scale = 1.1,
                pulse_seconds = 0.82,
                light_brightness = 2.5,
                light_range_scale = 1.25,
                highlight_fill_transparency = 0.78,
                highlight_outline_transparency = 0.08,
            },
            particles = {
                texture = "rbxasset://textures/particles/sparkles_main.dds",
                rate = 38,
                lifetime = { 0.7, 1.45 },
                speed = { 1.5, 4.5 },
                rotation = { 0, 360 },
                rotational_speed = { -100, 100 },
                spread_angle = { 180, 180 },
                acceleration_y = 4.5,
                light_emission = 0.92,
                size = {
                    { 0, 0 },
                    { 0.18, 0.2 },
                    { 0.76, 0.11 },
                    { 1, 0 },
                },
                transparency = {
                    { 0, 1 },
                    { 0.12, 0.08 },
                    { 0.82, 0.32 },
                    { 1, 1 },
                },
            },
            orbit = {
                count = 12,
                radius_scale = 0.56,
                height_scale = 0.42,
                vertical_cycles = 2,
                angular_speed = 1.75,
                part_size = 0.2,
                transparency_min = 0.05,
                transparency_max = 0.56,
                material = "Neon",
                fade_speed = 0.7,
            },
            world_label = {
                width = 310,
                height = 58,
                max_distance = 90,
                height_above_bubble = 1.15,
                title_text_size = 18,
                detail_text_size = 12,
                stroke_transparency = 0.08,
                title_position = { 0, 0 },
                title_size = { 1, 0.57 },
                detail_position = { 0, 0.52 },
                detail_size = { 1, 0.42 },
            },
            hud = {
                display_order = 96,
                width = 410,
                height = 72,
                top_margin = 104,
                panel_transparency = 0.14,
                panel_corner_radius = 15,
                border_thickness = 2,
                title_text_size = 18,
                detail_text_size = 13,
                content_left = 74,
                content_right = 14,
                title_top = 9,
                title_height = 28,
                detail_top = 36,
                detail_height = 24,
                sigil = {
                    left = 27,
                    top = 22,
                    size = 28,
                    corner_radius = 5,
                    transparency = 0.22,
                    spin_seconds = 1.1,
                },
            },
            teleport_screen = {
                display_order = 10000,
                backdrop_transparency = 0.25,
                card_width = 430,
                card_height = 118,
                card_transparency = 0.08,
                card_corner_radius = 18,
                border_thickness = 3,
                title_text_size = 24,
                detail_text_size = 15,
                spinner_size = 48,
                spinner_thickness = 5,
                spinner_seconds = 1.15,
                spinner_left = 24,
                content_left = 92,
                content_right = 20,
                title_top = 25,
                title_height = 34,
                detail_top = 60,
                detail_height = 30,
            },
            roles = {
                merge = {
                    title = "ENTERING MERGE",
                    detail = "Your bay is being prepared",
                    primary = { 164, 101, 255 },
                    secondary = { 72, 225, 255 },
                    accent = { 255, 211, 92 },
                    panel = { 23, 17, 46 },
                },
                main = {
                    title = "RETURNING TO FARM & FIGHT",
                    detail = "The realms are opening",
                    primary = { 75, 245, 166 },
                    secondary = { 82, 216, 255 },
                    accent = { 255, 196, 64 },
                    panel = { 13, 34, 42 },
                },
            },
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
        auto_combine_control = "AutoCombineControl",
        merge_board = "MergeBoard",
        reset_control = "ResetControl",
        exit_control = "ExitControl",
        enemy_spawn_area = "EnemySpawnArea",
        enemy_finish_line = "EnemyFinishLine",
        bulwark_line = "BulwarkLine",
        breach_line = "BreachLine",
        enemy_portal_visual = "EnemyPortalVisual",
        voxel_map_name = "GeneratedMap_MergeEggVoxel",
        playfields_folder = "PlayFields",
        potion_shop_heaven = "HeavenPotionShop",
        potion_shop_hell = "HellPotionShop",
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
            -- Hell Layer 3 can field nine pets; panels keep that final physical height from the
            -- beginning so a mid-run capacity increase never forces the whole HUD to reflow.
            logical_slots = 9,
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
                -- Purchases unlock physical slots 5 through 9 in order. Keep this as an explicit
                -- authored ladder: capacity is a scarce permanent advantage, and the final slot
                -- should be a 100,000-Gem long-term goal rather than another cheap doubling.
                costs_by_level = { 250, 1000, 5000, 25000, 100000 },
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
            pet_endurance = {
                display_name = "Pet Endurance",
                base_cost = 100,
                cost_growth = 1.75,
                step = 0.05,
                max_level = 20,
            },
            focus_regen = {
                display_name = "Focus Regen",
                base_cost = 100,
                cost_growth = 1.75,
                step = 0.05,
                max_level = 20,
            },
        },
    },

    -- Every Wave-1 run starts at zero and lays 600 owner-only Waycoins plus one
    -- Gem beyond the Bulwark. Chevrons walk the five stacks nearest-first,
    -- then the gem in front of the gold-line engineer (left of the field
    -- while facing the enemy gate). This is invariant across
    -- first visits, completed tutorials, pre-checkpoint resets, and rebirths.
    -- Five physical stacks preserve the collection lesson while leaving a
    -- 100-Waycoin buffer after the tutorial's five Earth Eggs have been
    -- purchased. The opening gem unlocks Impaler Palisade. After Wave 4 a
    -- second gem is laid in front of the right-pad commander if the wallet
    -- is empty; that one unlocks Heal.
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
        gem = {
            currency = "gems",
            amount = 1,
            -- Gold-line engineer stands on the left of the field while
            -- facing the enemy gate (`posts[2]`, along = "right" in strip
            -- space). Place the gem in front of that vendor,
            -- toward the gate, stepped inward onto the playboard. `offset` is
            -- only used if that stand pose cannot be resolved.
            engineer_post = 2,
            toward_gate = 12,
            inward = 8,
            offset = { x = 24, z = 28 },
            visual_scale = 1.5,
        },
        -- Laid after Wave 4 only when the gem wallet is 0. Lands on the
        -- field past the stone wall, in front of the right pad — not on
        -- the pad deck or the commander stand behind it.
        cannon_gem = {
            currency = "gems",
            amount = 1,
            toward_gate = 12,
            inward = 8,
            offset = { x = 24, z = 28 },
            visual_scale = 1.5,
        },
    },

    -- First-visit teaching is server-authoritative setup, not a separate safe room. The player may
    -- spend the 600-Waycoin opening freely: Wave 1 waits only until at least one egg is deployed and
    -- one equal-tier combination has happened, either on the board or at a deployed hatcher. Auto
    -- Collector owners may skip only the walking portion.
    tutorial = {
        basic_combat_reminder = {
            progress = "BASIC COMBAT TRAINING",
            title = "COMPLETE BASIC COMBAT TRAINING TO UNLOCK PETS",
            body = "Talk to the Quartermaster to start or resume. Finish the Heal lesson to unlock your pets and powers.",
        },
        enabled = true,
        step_pause_seconds = 1.25,
        resume_wave_delay_seconds = 3,
        auto_collector_attribute = "AutoCollectorEnabled",
        required_eggs = 5,
        -- The tutorial card mounts over the hotbar's inner PillFrame and copies that frame's UDim
        -- relationship. `relative` and `size_constraint` below are retained for transient board
        -- feedback in the full-screen presentation layer, not for interactive hotbar controls.
        card_layout = {
            background_transparency = 0.5,
            display_order = 100,
            feedback_display_order = 130,
            inactive_display_order = 0,
            relative = {
                classic = {
                    anchor = { x = 0, y = 1 },
                    position = { x = 0.251, y = 0.97 },
                    size = { x = 0.605, y = 0.24 },
                    aspect_ratio = 4.7,
                },
                compact = {
                    anchor = { x = 0.5, y = 1 },
                    position = { x = 0.5, y = 0.97 },
                    size = { x = 0.72, y = 0.24 },
                    aspect_ratio = 4.7,
                },
            },
            size_constraint = {
                minimum = { width = 280, height = 60 },
                maximum = { width = 1200, height = 320 },
            },
        },
        click_cue_purchase_count = 3,
        click_cue = {
            width = 330,
            height = 108,
            text_size = 45,
            target_stroke_thickness = 12,
            callout_stroke_thickness = 7,
            corner_radius = 18,
            target_gap = 12,
            pulse_travel = 12,
            display_scale = {
                desktop = 1,
                tablet = 0.75,
                phone = 0.5,
                ten_foot = 1,
            },
        },
        disable_after_rebirth = true,
        -- Locked drip: Wave 0 eggs → Wave 2 Impaler → Wave 4 Heal →
        -- Wave 6 optional coins + egg upgrades → Wave 10 Quartermaster.
        -- Phase 1 unlocks Waves 1–2. After this wave clears, hold Wave 3
        -- and baby-step the gold-line (second) engineer workshop.
        pause_after_wave = 2,
        workshop_slot = "lane",
        -- After Wave 4, hold Wave 5 and baby-step the right-pad commander.
        -- If the Waycoin wallet is empty, chevron any existing pile first.
        -- Do not spawn or place piles here — a missing or off-map drop
        -- must not block the beat (credit 1 Waycoin instead).
        pause_after_cannon_wave = 4,
        workshop_cannon_slot = "right",
        workshop_cannon_family = "heal",
        -- After Wave 6, pause only if they have not upgraded or installed
        -- eggs since the Heal install. 600 Waycoins covers six Earth eggs
        -- at the opening price. Then one loose card: create a couple,
        -- then upgrade or place. Skip entirely when they already did that work.
        pause_after_upgrade_wave = 6,
        upgrade_coin_target = 600,
        upgrade_create_count = 2,
        -- After Wave 10, reveal the potion tent and post Macros as
        -- Quartermaster. Talk only for now; the shop opens after that.
        pause_after_quartermaster_wave = 10,
        -- The central hotbar remains covered through Wave 10. Between the hands-on lesson pauses,
        -- keep that footprint useful with a concise preview of the next tutorial milestone instead
        -- of leaving a blank hole in both desktop and compact HUDs.
        combat_cards = {
            combat_waves = {
                progress = "MERGE DEFENSE TUTORIAL  •  COMBAT",
                title = "DEFEND THROUGH WAVE 2",
                body = "The Bulwark Engineer lesson begins after Wave 2.",
            },
            cannon_waves = {
                progress = "MERGE DEFENSE TUTORIAL  •  COMBAT",
                title = "DEFEND THROUGH WAVE 4",
                body = "The Artillery Commander lesson begins after Wave 4.",
            },
            upgrade_waves = {
                progress = "MERGE DEFENSE TUTORIAL  •  COMBAT",
                title = "DEFEND THROUGH WAVE 6",
                body = "The egg-upgrade lesson will begin after Wave 6.",
            },
            quartermaster_waves = {
                progress = "MERGE DEFENSE TUTORIAL  •  COMBAT",
                title = "DEFEND THROUGH WAVE 10",
                body = "The Quartermaster arrives after Wave 10.",
            },
        },
        steps = {
            collect_setup = {
                title = "COLLECT 600 WAYCOINS AND 1 GEM",
                body = "Follow the chevrons to the closest Waycoin stack. After all five, pick up the gem.",
                auto_body = "Your Coin Pup collects the five stacks and the gem for you. You can skip the walking lesson.",
                target = "coins",
            },
            create_five = {
                title = "CREATE FIVE EARTH EGGS",
                body = "Click the highlighted BUY EGG button five times.",
                target = "buy_egg",
            },
            combine_once = {
                title = "CLICK DEPLOY BEST",
                body = "Click the highlighted DEPLOY BEST button.",
                target = "equip_best",
            },
            deploy_one = {
                title = "CLICK DEPLOY BEST",
                body = "Click the highlighted DEPLOY BEST button.",
                target = "equip_best",
            },
            collect_workshop_coins = {
                title = "PICK UP A WAYCOIN PILE",
                body = "Follow the chevrons to any pile. You need at least one Waycoin to install the wall.",
                target = "stage_coins",
            },
            talk_engineer = {
                title = "THE ENGINEER TOOK THE GOLD LINE",
                body = "He just posted on your left. Follow the chevrons and Talk — he will not wait through the next waves.",
                target = "engineer",
            },
            unlock_bulwark = {
                title = "UNLOCK A FAMILY",
                body = "Click UNLOCK. Impaler Palisade costs 1 Gem.",
                target = "bulwark_unlock",
            },
            install_bulwark = {
                title = "INSTALL THE BULWARK",
                body = "Click INSTALL to place Tier 1 on this line.",
                target = "bulwark_install",
            },
            collect_cannon_coins = {
                title = "PICK UP A WAYCOIN PILE",
                body = "Follow the chevrons to any pile. You need at least one Waycoin to install the cannon.",
                target = "stage_coins",
            },
            collect_cannon_gem = {
                title = "PICK UP THE GEM",
                body = "The commander left a gem in front of the right gun. You will need it to unlock Heal.",
                target = "cannon_gem",
            },
            talk_commander = {
                title = "THE COMMANDER TOOK THE RIGHT GUN",
                body = "He just posted behind the right pad. Follow the chevrons and Talk — four fronts are coming.",
                target = "commander",
            },
            unlock_cannon = {
                title = "UNLOCK HEAL",
                body = "Click UNLOCK. The Heal cannon costs 1 Gem.",
                target = "cannon_unlock",
            },
            install_cannon = {
                title = "INSTALL THE CANNON",
                body = "Click INSTALL to place Tier 1 Heal on this pad.",
                target = "cannon_install",
            },
            collect_upgrade_coins = {
                title = "GRAB SOME WAYCOINS",
                body = "Pick up coins on the field until you have about 600 — enough for six eggs. You will want them.",
                auto_body = "Your Coin Pup will gather the coins. You need about 600 for a few more eggs.",
                target = "upgrade_coins",
            },
            upgrade_eggs = {
                title = "MAKE A COUPLE OF EGGS",
                body = "Create a couple of eggs, then upgrade one or place one on the line. However you like.",
                target = "buy_egg",
            },
            talk_quartermaster = {
                title = "THE QUARTERMASTER POSTED UP",
                body = "Macros is at the potion tent. Follow the chevrons and Talk.",
                target = "quartermaster",
            },
        },
        -- One-time milestones temporarily cover the already-scaled tutorial/hotbar footprint
        -- instead of adding another mobile HUD element. Distinct milestones queue.
        activity_feedback = {
            default_duration_seconds = 2.5,
            egg_upgrade_duration_seconds = 5,
            maximum_queue = 4,
            copies = {
                egg_created = "%s CREATED",
                tutorial_egg_upgraded = "%s UPGRADED — GREAT JOB. YOU'VE GOT THIS.",
                generator_unlocked = "%s GENERATOR UNLOCKED",
                pet_slot_unlocked = "%s PET SLOT UNLOCKED",
                bulwark_unlocked = "BULWARK UNLOCKED",
                cannon_unlocked = "CANNON UNLOCKED",
                quartermaster_ready = "QUARTERMASTER READY",
            },
        },
    },

    -- Macros sits at the bay supply booth. Hidden with the booth until Wave 10, then owns potion
    -- sales, the Merge-relevant permanent-pass catalog, and the full Combat Training mission. The
    -- authored tent remains scenery only; its legacy Browse Potions prompt is deliberately
    -- disabled by the Merge service. Pass membership lives here rather than in client UI code so
    -- Quartermaster inventory remains configuration-as-code and independently auditable.
    quartermaster = {
        enabled = true,
        user_id = 873359641,
        name = "MacrosGodOfMagic",
        display_name = "Macros",
        action_text = "Services",
        object_text = "Quartermaster",
        idle_animation = "507766388",
        max_distance = 16,
        stand_front_studs = 8,
        shop_visible_transparency = 0,
        introduction_seconds = 5,
        greeting = "Rebirths unlock new eggs. Finish Combat Training, and their pets are yours to keep.",
        greeting_complete = "Training complete. Pets from your rebirth eggs are yours to keep.",
        services = {
            title = "QUARTERMASTER",
            body = "Rebirths unlock personal eggs. Finish Combat Training so their pets can enter your inventory.",
            body_complete = "Training complete. Pets from your rebirth eggs now enter your inventory.",
            game_passes_label = "GAME PASSES — SUPERCHARGE YOUR CHARACTER",
            game_passes_body = "Permanent upgrades for speed, pets, hatches, and recovery.",
            game_passes_shop_title = "QUARTERMASTER PASSES",
            game_passes_shop_subtitle = "Permanent upgrades selected for Merge Defense",
            game_pass_ids = {
                "auto_merge",
                "vip_pass",
                "auto_collect",
                "speed_boost",
                "golden_luck_pass",
                "rainbow_luck_pass",
                "huge_luck_pass",
                "pet_slot_pass",
                "second_wind",
            },
            potions_label = "BROWSE POTIONS — BUY SOME PICK-ME-UPS",
            potions_body = "A little bottled courage. Browse boosts for you and your pets.",
            training_label = "COMBAT TRAINING — UNLOCK YOUR PETS",
            training_resume_label = "FINISH TRAINING — UNLOCK YOUR PETS",
            training_body = "Basic unlocks pets. Advanced 1 and 2 are optional: earn a level and a boost token for each.",
            training_complete_label = "ADVANCED TRAINING — EARN LEVELS & BOOSTS",
            enhancements_label = "💎 ENHANCEMENTS",
            enhancements_body = "Buy what you need. Sell what you don't.",
            enhancements_color = { 109, 65, 174 },
            farm_fight_label = "FARM & FIGHT — TAKE A BREATHER",
            farm_fight_body = "Farm coins. Hatch pets. Find the Merge gate when chaos calls.",
            four_service_height = 586,
            five_service_height = 674,
            close_label = "NOT NOW",
        },
    },

    -- The existing Future Self / Colorado NPC-principal lifecycle consumes this base definition.
    -- The owner avatar is a temporary visual stand-in for purpose-built hatcher NPC assets.
    principal = {
        avatar_owner = true,
        -- Captains are readable world anchors, not lane blockers. Their body remains queryable for
        -- targeting/tutorial rays, but players must be able to walk through the entire R15 rig.
        character_non_collidable = true,
        level = 1, -- startup fallback only; runtime snapshots the entering player's combat level
        squad = {},
        alliance = { enabled = false },
        powers = {},
        auto_farm = { enabled = false },
    },

    -- Required by the config schema for compatibility; Phase 5 never reads a fixed roster.
    squad = {},

    -- Resolve the player's current combat level whenever a new combatant/objective is spawned.
    -- Existing actors keep the level stamped when they spawned; newly hatched pets and later-wave
    -- enemies immediately follow an earned level-up without requiring a leave/rejoin. Lieutenant/
    -- boss rank offsets are still applied by EnemyService on top of that common base.
    combat_level = {
        source = "active_player_effective_level",
        freeze_for_run = false,
        rank_tiers = {
            trash = "trash_mob",
            tank = "trash_mob",
            lieutenant = "mid_tier",
            boss = "boss",
            villain = "boss",
            archvillain = "archvillain",
        },
    },

    -- Merge Defense owns a faster player-pet recovery cadence than Farm & Fight. The slot timer
    -- governs ordinary/stacked replacements; the identity timer keeps the exact downed Huge out
    -- longer. Equipped pets automatically return as soon as their applicable timer finishes.
    player_pet_recovery = {
        auto_summon_on_recovery = true,
        slot_recovery = {
            down_cooldown_seconds = 10,
        },
        down_lockout = {
            pet_lockout_seconds = 60,
        },
    },

    team = {
        return_ready_distance = 20,
        starts_with_egg = false,
        workshop_replacement_confirmation = {
            title = "REPLACE TIER %d %s?",
            lines = {
                "THIS SLOT'S TIER %d PROGRESS WILL BE LOST",
                "%s WILL START AGAIN AT TIER 1",
                "CLICK %s TO CONTINUE",
            },
            button = "CONFIRM REPLACE",
        },
        -- Capacity belongs to the config-authored world/egg track. Home fields three pets per
        -- hatcher, then each realm layer adds one position.
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
            -- Raising the global spawn floor promotes every owned hatcher. Charge twice the
            -- proposed output egg's current creation value for each available hatcher slot.
            upgrade_proposed_egg_value_multiplier = 2,
        },
        prototype_huge_progression = {
            normal_tier_count = #NORMAL_EGG_PROGRESSION,
            start_tier = #NORMAL_EGG_PROGRESSION + 1,
            counts_as_real_huge = false,
            design_horizon_wave = 140,
        },
        merge_board = {
            merge_ratio = 2,
            auto_merge = {
                enabled = true,
                pass_id = "auto_merge",
                entitlement_feature = "merge_auto_merge",
                labels = {
                    locked = "AUTO MERGE\nBUY PASS",
                    off = "AUTO MERGE\nOFF",
                    on = "AUTO MERGE\nON",
                },
                pass_required_copy = "AUTO MERGE PASS REQUIRED",
                purchase_menu = {
                    title = "AUTO MERGE",
                    eyebrow = "MERGE DEFENSE PASS",
                    description = "Keeps your defenses supplied without wasting the egg your line needs.",
                    priority_copy = "LINE FIRST  •  BOARD SECOND",
                    buy_label_format = "BUY  •  R$ %d",
                    cancel_label = "NOT NOW",
                    display_order = 1170,
                    minimum_scale = 0.68,
                    panel_size = { x = 520, y = 340 },
                    palette = {
                        scrim = { 0, 0, 0 },
                        panel = { 19, 24, 37 },
                        header = { 53, 72, 164 },
                        accent = { 84, 157, 255 },
                        card = { 29, 37, 56 },
                        text = { 248, 250, 255 },
                        body = { 207, 219, 238 },
                        buy = { 45, 185, 92 },
                        cancel = { 72, 81, 101 },
                    },
                },
            },
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
            touch_input = {
                -- A short stationary touch is a board tap. Camera pans and multi-touch gestures
                -- do not select, combine, deploy, or clear eggs accidentally.
                max_movement_pixels = 24,
                max_duration_seconds = 0.65,
            },
            empty_slot_color = { 45, 52, 64 },
            empty_slot_transparency = 0.08,
            egg_sign_size = 4.8,
            egg_sign_transparency = 0.12,
            equip_best_size = { x = 7, z = 12 },
            equip_best_label = "DEPLOY BEST",
            equip_best_gap = 1.5,
            auto_combine_size = { x = 7, z = 12 },
            auto_combine_gap = 1.5,
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
            -- A player begins at Rebirth Rank 1. The rear pair becomes usable
            -- together at Rank 20; the authored pads may exist before then,
            -- but server-side install, commander, and spawn paths stay locked.
            slot_unlock_rebirth_ranks = {
                left = 1,
                right = 1,
                rear_left = 20,
                rear_right = 20,
            },
            pad_layout = {
                footprint_studs = 8.4,
                lateral_clearance_studs = 0.65,
                initial_depth_intervals = 1,
                -- Rear center = initial center + this many copies of the
                -- authored red-line-to-initial-pad depth vector.
                rear_gap_multiplier = 1,
            },
            -- Permanent cadence: award the first tower during the Wave-10 intermission.
            -- Pads start empty; the Artillery Commander installs a chassis.
            unlock_wave = 10,
            tutorial_intermission_wave = 10,
            playtest_spawn_enabled = false,
            -- Unlock is one-time and global. Robux-only roles will set this
            -- flag via game passes; Gem unlocks use the workshop Buy. Do not
            -- grant the catalog for free — the menu must show LOCKED until
            -- that flag is set. Placement and upgrade are paid per pad.
            visual_catalog_owned = false,
            playtest_unlock_enabled = true,
            playtest_unlock_wave = 1,
            -- Unlock is paid once per family in Gems. Install/replacement and
            -- upgrade are paid per pad in Waycoins at the target tier's price.
            -- Heal stays deliberately cheap because the tutorial requires it.
            currency = "hall_coins",
            unlock_costs = {
                heal = { currency = "gems", amount = 1 },
                rage = { currency = "gems", amount = 10 },
                debuff = { currency = "gems", amount = 100 },
                gravity = { currency = "gems", amount = 1000 },
                repulsor = { currency = "gems", amount = 10000 },
                nullifier = { currency = "gems", amount = 100000 },
            },
            tier_costs = {
                heal = { 1, 1000, 10000, 100000 },
                rage = { 1000, 10000, 100000, 1000000 },
                debuff = { 5000, 50000, 500000, 5000000 },
                gravity = { 10000, 100000, 1000000, 10000000 },
                repulsor = { 25000, 250000, 2500000, 25000000 },
                nullifier = { 50000, 500000, 5000000, 50000000 },
            },
            maximum_tier = 4,
            model_folder_name = "MergeCannons",
            model_tier_count = 4,
            -- All six families ship distinct Tier 1–4 meshes at a uniform template scale.
            -- Per-tier presentation size lives on merge_tier_art.worldScale.
            distinct_art_tiers = true,
            available_roles = {
                "heal",
                "rage",
                "debuff",
                "gravity",
                "repulsor",
                "nullifier",
            },
            -- An installed chassis lofts a sphere toward the nearest in-lane enemy.
            -- Pads stay empty until Buy/Install; the installed gameplay tier selects art and tuning.
            starter_role = "repulsor",
            starter_tier = 1,
            shot = {
                interval = 2.4,
                interval_jitter = 0.05,
                flight_seconds = 0.85,
                apex_height = 14,
                range = 90,
                range_gate_padding = 16,
                diameter = 1.2,
                land_seconds = 0.55,
                -- Ability shots land on the floor under the target (the ring
                -- plane). The ball blooms out quietly instead of lingering.
                land_at = "ground",
                ability_impact = "bloom",
                bloom_seconds = 0.16,
                bloom_scale = 2.0,
                -- Fire kick. Aim freezes for this window, then resumes.
                -- Keep shorter than any shot interval so it never owns cadence.
                recoil = {
                    duration = 0.18,
                    height = 0.2,
                    peak_at = 0.32,
                    shake = 0.03,
                },
                heal_fire_texture = "83142936306716",
                -- Heal landing casts the real Healing Field at impact (same
                -- kind numbers, no Focus/cooldown). Rage landing is a one-time
                -- Berserk sip in a ruddy MagicCircle — no tick loop.
                -- Debuff sips Weakening Vial on enemies (Rage's sibling).
                -- Gravity pulls with a black-hole rune. Repulsor is a
                -- concussion blast (CombatFX detonation, outward fling,
                -- per-enemy hit roll). Nullifier is Frost Bind with a
                -- per-enemy hit roll so the circle cannot hard-lock
                -- the lane. No rebuilt powers.
                -- Hard floor: never shoot a target on the egg side of BreachLine.
                -- Heal aims injured pets (CombatDamageTaken). Rage fires at
                -- one ally already in combat (TargetType Enemy / AggroTargetRef);
                -- that pet and anyone else inside the landing circle get a
                -- per-unit sip. The other four aim the nearest in-lane enemy.
                -- No idle-pet or empty-lane shot.
                -- heal_fire_line / rage_fire_line can tighten to
                -- "bulwark" or "mid" later; breach is the live floor.
                fire_line = "breach",
                fire_line_epsilon = 2,
                heal_target = "injured_pets",
                heal_fire_line = "breach",
                rage_target = "combat_pets",
                rage_fire_line = "breach",
                landing = {
                    -- Tiers only change magnitude (existing per-tick heal) and
                    -- fire interval. hot_tick stays 2s on Healing Field.
                    heal = {
                        cast = "healing_field",
                        land_at = "ground",
                        impact = "bloom",
                        magnitude = { 110, 110, 110, 110 },
                        interval = { 2.4, 2.4, 2.4, 2.4 },
                    },
                    -- Tiers only change fire interval and circle size.
                    -- Sip size stays Berserk Brew's sip_fraction.
                    -- One radius is both the MagicCircle and who gets sipped
                    -- (same ground-rune path as Healing Field / Rage).
                    rage = {
                        cast = "berserk_brew",
                        land_at = "ground",
                        impact = "bloom",
                        interval = { 2.4, 2.4, 2.4, 2.4 },
                        radius = { 7, 28, 28, 28 },
                    },
                    -- Hex: same Weakening Vial sip Rage uses for Berserk,
                    -- but on enemies. Meter and drain stay the potion's.
                    debuff = {
                        cast = "weakening_vial",
                        land_at = "ground",
                        impact = "bloom",
                        interval = { 2.4, 2.4, 2.4, 2.4 },
                        radius = { 7, 28, 28, 28 },
                    },
                    -- Pull toward the impact. Black-hole rune is visual;
                    -- displacement is still Seismic's directed knockback.
                    gravity = {
                        cast = "seismic_hold",
                        toward = "impact",
                        black_hole = true,
                        land_at = "ground",
                        impact = "bloom",
                        interval = { 2.4, 2.4, 2.4, 2.4 },
                        radius = { 7, 28, 28, 28 },
                        shove = { 14, 14, 18, 22 },
                    },
                    -- Concussion blast: existing CombatFX lava detonation
                    -- (no magic ring). Fling is radial from the impact so
                    -- the pack spreads instead of stacking at the gate.
                    -- Each enemy rolls hit_chance — T4 at 100% froze the
                    -- lane. Dest is still leashed before Y-snap.
                    repulsor = {
                        cast = "seismic_hold",
                        toward = "outward",
                        fling = true,
                        explosion = true,
                        land_at = "ground",
                        impact = "bloom",
                        interval = { 2.4, 2.4, 2.4, 2.4 },
                        radius = { 7, 28, 28, 28 },
                        shove = { 22, 28, 34, 40 },
                        height = { 10, 12, 14, 16 },
                        flight = { 0.55, 0.6, 0.65, 0.7 },
                        recover = { 0.45, 0.5, 0.55, 0.6 },
                        tumble_spins = 1.35,
                        wall_inset = 6,
                        hit_chance = { 0.5, 0.5, 0.45, 0.4 },
                    },
                    -- Frost Bind. A 2.4s circle would lock the lane if it
                    -- always landed, so each enemy rolls hit_chance. T1 is
                    -- conservative; duration stays the power's 5s root.
                    nullifier = {
                        cast = "frost_bind",
                        land_at = "ground",
                        impact = "bloom",
                        interval = { 2.4, 2.4, 2.4, 2.4 },
                        radius = { 7, 28, 28, 28 },
                        hit_chance = { 0.4, 0.5, 0.6, 0.7 },
                    },
                },
                role_colors = {
                    heal = { 85, 255, 130 },
                    rage = { 235, 80, 60 },
                    debuff = { 174, 100, 235 },
                    gravity = { 76, 165, 245 },
                    repulsor = { 255, 148, 36 },
                    nullifier = { 196, 150, 255 },
                },
            },
            -- Talkable vendor behind each pad cannon. Same workshop as
            -- the Bulwark Engineer, but the list is cannons and each
            -- commander opens only that pad.
            commander = {
                enabled = true,
                user_id = 864785140,
                name = "sploithunter",
                display_name = "Artillery Commander",
                action_text = "Talk",
                object_text = "Artillery Commander",
                idle_animation = "507766388",
                max_distance = 16,
                stand_behind_studs = 7,
            },
        },
        edge_bulwarks = {
            enabled = true,
            -- Yellow/lane and red/egg are the starting rows. Orange/mid is
            -- enabled at Rebirth Rank 10 and green/front at Rank 30.
            slot_unlock_rebirth_ranks = {
                lane = 1,
                egg = 1,
                mid = 10,
                front = 30,
            },
            line_layout = {
                -- One interval is half the red-to-yellow separation.
                interval_fraction = 0.5,
                -- Exact appearance approved on Heaven_01_Lines in Studio.
                -- Keep the row-specific transparency when duplicating it.
                lane_color = { 255, 255, 0 },
                lane_transparency = 0.08,
                mid_color = { 175, 113, 32 },
                mid_transparency = 0.05,
                front_color = { 58, 125, 21 },
                front_transparency = 0.05,
                egg_color = { 151, 0, 0 },
                egg_transparency = 0.08,
            },
            tile_count = 10,
            wall_inset_studs = 1,
            canonical_tile_length_studs = 10,
            -- Land Sharks are a moving field hazard, not a wall tile. Count scales by tier
            -- (4/5/6/7). They wander the full strip width and only a few studs off the
            -- bulwark line, then occasionally porpoise so a sliver of body breaks the playfield.
            land_shark_count = { 4, 5, 6, 7 },
            land_shark_track_studs = 28,
            land_shark_min_field_width_studs = 24,
            land_shark_field_depth_studs = 7,
            land_shark_field_margin_studs = 8,
            land_shark_speed_studs = 10,
            land_shark_tempo_divisor = 10,
            land_shark_chase_speed_studs = 26,
            land_shark_drag_speed_studs = 16,
            land_shark_return_speed_studs = 18,
            land_shark_hunt_blend_rate = 5,
            land_shark_sample_lead_seconds = 0.12,
            land_shark_proximity_poll_seconds = 0.1,
            land_shark_surface_distance = 8,
            land_shark_fin_exposure_studs = 1,
            land_shark_bite_period_seconds = 1.4,
            land_shark_breach_period_seconds = 7.5,
            land_shark_breach_duration_seconds = 1.55,
            land_shark_breach_rise_studs = 2.3,
            land_shark_breach_pitch_degrees = 14,
            maximum_tier = 4,
            -- Permanent cadence is Wave 20. Unlock is one-time and global
            -- (requirements TBD). Placement and upgrade are paid per slot
            -- (lane and egg now; mid/front later). Impaler unlocks for 1 Gem;
            -- install/upgrade prices are paid per line at the target tier.
            unlock_wave = 20,
            tutorial_intermission_wave = 20,
            playtest_unlock_enabled = true,
            playtest_unlock_wave = 1,
            currency = "hall_coins",
            unlock_costs = {
                impaler_palisade = { currency = "gems", amount = 1 },
                concertina_line = { currency = "gems", amount = 10 },
                land_shark = { currency = "gems", amount = 100 },
                saw_blade = { currency = "gems", amount = 1000 },
                grasping_hedge = { currency = "gems", amount = 10000 },
                wardstone_barrier = { currency = "gems", amount = 100000 },
            },
            tier_costs = {
                impaler_palisade = { 1, 1000, 10000, 100000 },
                concertina_line = { 1000, 10000, 100000, 1000000 },
                land_shark = { 5000, 50000, 500000, 5000000 },
                saw_blade = { 10000, 100000, 1000000, 10000000 },
                grasping_hedge = { 25000, 250000, 2500000, 25000000 },
                wardstone_barrier = { 50000, 500000, 5000000, 50000000 },
            },
            prompt_distance = 14,
            -- Talkable vendors, same idea as Kade's Boards. The workshop is
            -- unchanged; each post opens one slot. Same avatar for now; later
            -- posts can set their own user_id (alts) without a line picker.
            engineer = {
                enabled = true,
                user_id = 3200870803,
                name = "ColoradoPlays",
                display_name = "Bulwark Engineer",
                action_text = "Talk",
                object_text = "Bulwark Engineer",
                idle_animation = "507766388",
                max_distance = 16,
                posts = {
                    { slot = "egg", along = "left" },
                    { slot = "lane", along = "right" },
                    { slot = "mid", along = "left" },
                    { slot = "front", along = "right" },
                },
            },
            -- Impaler Palisade: tank-style shove + short pin, no damage. Charges are per marcher.
            -- T1 is one bounce; five per enemy would lock the wave for pets to farm.
            combat = {
                impaler_palisade = {
                    charges = { 1, 2, 3, 4 },
                    shove_studs = { 16, 20, 24, 28 },
                    root_seconds = { 0.4, 0.45, 0.55, 0.7 },
                    venom_damage = { 0, 0, 12, 18 },
                    venom_period = { 1, 1, 0.7, 0.55 },
                    venom_permanent = { false, false, true, true },
                    contagion_radius = { 0, 0, 0, 12 },
                    contagion_interval = { 1, 1, 1, 1.0 },
                    contagion_hops = { 0, 0, 0, 4 },
                },
                concertina_line = {
                    bleed_damage = { 8, 14, 20, 16 },
                    bleed_period = { 0.9, 0.75, 0.55, 0.4 },
                    slow_factor = { 0.8, 0.7, 0.58, 0.45 },
                    linger_seconds = { 0, 1.5, 3.5, 0 },
                    bleed_permanent = { false, false, false, true },
                    bleed_stacks = { false, false, false, true },
                    stack_cap = { 1, 1, 1, 4 },
                    strip_depth_studs = { 8, 8, 10, 12 },
                },
                grasping_hedge = {
                    grab_count = { 1, 2, 3, 4 },
                    root_seconds = { 0.9, 1.2, 1.6, 2.2 },
                    slow_factor = { 0.7, 0.6, 0.5, 0.42 },
                    slow_seconds = { 0.8, 1.1, 1.6, 2.0 },
                    venom_damage = { 0, 0, 10, 14 },
                    venom_period = { 1, 1, 0.7, 0.55 },
                    venom_duration = { 0, 0, 4, 5 },
                    strip_depth_studs = { 8, 8, 8, 10 },
                    exit_buffer_studs = { 6, 6, 6, 6 },
                },
                saw_blade = {
                    shred_damage = { 16, 24, 30, 42 },
                    shred_period = { 0.16, 0.13, 0.10, 0.08 },
                    strip_depth_studs = { 6, 6, 6, 6 },
                    chunk_count = { 6, 7, 8, 10 },
                },
                land_shark = {
                    shark_count = { 4, 5, 6, 7 },
                    bite_damage = { 36, 90, 130, 190 },
                    bite_period = { 0.575, 0.25, 0.21, 0.175 },
                    hunt_range_studs = { 16, 18, 20, 22 },
                    grab_range_studs = { 7, 7, 8, 8 },
                    sink_studs = { 8, 9, 10, 12 },
                    venom_damage = { 0, 0, 10, 14 },
                    venom_period = { 0.5, 0.5, 0.35, 0.275 },
                    venom_range_studs = { 0, 0, 8, 9 },
                    prefer_bosses = { false, false, false, true },
                },
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
                    6,
                    6,
                    6,
                    6,
                    8,
                    8,
                    8,
                    8,
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
    -- extra-equip-slot feature adds a fourth support slot. A defeated escort slot uses the shared
    -- Merge player-pet recovery config above, then takes the strongest matching cast-off still on
    -- the reserve bench. A Huge cast-off uses the longer identity recovery.
    player_reserve = {
        enabled = true,
        base_slots = 3,
        extra_slot_feature = "extra_equip_slots",
        maximum_slots = 4,
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
            -- Personal inventory hatches are Merge-rebirth progression, not a mirror of Farm &
            -- Fight purchases. Rank 1 owns Grass; every paid rebirth adds the next ordinary egg.
            -- Owning an egg also grants its corresponding Farm & Fight area, but LayerService's
            -- earned-level gates remain independent. Inventory delivery is stricter than Full-mode
            -- availability: no personal hatch enters inventory before Combat Training is complete.
            personal_hatches = {
                starting_tier = 1,
                tiers_per_rebirth = 1,
                inventory_requires_combat_tutorial = true,
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
        -- Ordinary combat XP already diminishes when an enemy's level trails the player. Merge
        -- keeps both sides at one base level, then independently grows enemy HP and durable allied
        -- DPS. After a paid rebirth, scale XP by that relative time-to-kill so a trivial Wave-1
        -- reset is not a leveling engine. Full XP returns naturally once layer/cycle HP catches up.
        -- The floor keeps even an extreme-rank opening kill worth a visible amount of XP.
        combat_xp_yield = {
            enabled = true,
            after_rebirth_only = true,
            include_allied_cadence = true,
            minimum_multiplier = 0.05,
            maximum_multiplier = 1,
            full_yield_difficulty_ratio = 1,
            -- Cubing the sub-peer difficulty ratio fits the live Rank-10/Wave-30 checkpoint:
            -- 0.45 relative difficulty becomes 0.091 XP yield, about one fifth of the former
            -- linear payout. Ratios at or above one still reach full XP at the same wave.
            relative_difficulty_exponent = 3,
            simulation_player_pet_kill_share = 0.5,
        },
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
        trace_bulwark_aggro = false,
        bulwark_trace_seconds = 2,
    },

    performance = {
        -- The Merge HUD does not need a 60-70 Hz copy of the complete world state. State-name
        -- transitions still publish immediately; repeated snapshots are capped to this cadence.
        world_state_replication_interval = 0.2,
        asset_warmup = {
            enabled = true,
            cache_folder = "MergeAssetWarmCache",
            reconcile_interval = 1,
            preload_next_source = true,
            maximum_pet_types = 40,
            preload_batch_size = 24,
            preload_debounce_seconds = 0.12,
        },
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
                -- Earned player level, not wave number, enemy rank, or temporary combat scaling.
                minimum_player_levels = {
                    infernal_boss = 30,
                },
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
    -- Applied after layer/rank/endless scaling, without changing rewards or body counts.
    -- Fixed to wave number so earning a level never suddenly strengthens the current fight.
    -- Keep waves 1–30 forgiving, then fade back to the existing curve through wave 60.
    early_wave_difficulty = {
        enabled = true,
        checkpoints = {
            { wave = 1, hp_multiplier = 0.25, damage_multiplier = 0.20 },
            { wave = 10, hp_multiplier = 0.30, damage_multiplier = 0.25 },
            { wave = 20, hp_multiplier = 0.40, damage_multiplier = 0.35 },
            { wave = 30, hp_multiplier = 0.50, damage_multiplier = 0.45 },
            { wave = 60, hp_multiplier = 1, damage_multiplier = 1 },
        },
    },
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

    -- Merge-only prestige. Rank 1 is the free starting state and Rank 50 is the progression cap.
    -- Proposed Rank N indexes Merge egg tier N and costs that tier's authored creation value times
    -- one constant. The quote therefore follows the egg ladder but never changes when the player
    -- buys Spawn Level or hatcher capacity during a live run. A multiplier of 400 makes the
    -- first transition: Rank 2 indexes Ice at 250 Waycoins and costs 100,000. A future pass may add
    -- minimum deployed-egg tiers per rank through the empty requirements list below. Rebirth keeps
    -- permanent player progression and Gem upgrades, resets the active Merge run and wallet, and
    -- scales pets, defenses, and enemy currency payouts without compounding. A factor of 2 means
    -- 2x at Rank 2 and 3x at Rank 3; a factor of 1 is an explicit no-change policy. Cannon and
    -- bulwark radii begin at 1x because increasing spatial coverage at every rebirth would get out
    -- of hand quickly. Rebirth pet power and the Gem damage-upgrade percentage share one additive
    -- pool (for example +100% and +45% = 2.45x total), scoped strictly to Merge Defense. The
    -- 400x price factor is the post-simulation correction for rebirths arriving before pressure.
    rebirth = {
        enabled = true,
        scope = "merge_defense_only",
        currency = "hall_coins",
        max_rank = 50,
        indexed_egg_value_multiplier = 400,
        -- Rebirth starts from a durable wallet credit, not collectible world drops. A player who
        -- logs out immediately after confirming can therefore always buy back onto the board.
        starting_wallet_amount = 600,
        requirements = {
            minimum_deployed_egg_tier_by_rank = {},
        },
        damage_stacking = "additive",
        management_damage_stacking = "additive",
        per_rebirth_factors = {
            stacking = "additive",
            pets = {
                power = 2,
                -- Scales the endurance ceiling inside Merge Defense so rank-matched pets are not
                -- one-shot while enemy damage continues to grow through wave progression.
                defense = 2,
            },
            cannons = {
                power = 2,
                radius = 1,
                cadence = 1,
            },
            bulwarks = {
                power = 2,
                radius = 1,
                cadence = 1,
                duration = 1,
                capacity = 1,
                control = 1,
            },
            coins = {
                amount = 2,
            },
            gems = {
                amount = 2,
                chance = 1,
            },
        },
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
