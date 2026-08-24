--[[
    Challenge Runs — Range (catalog / rank) and Training Ground (own loadout).

    Persist GameData.ChallengeRuns.<mode>.best_room only when a run exists.
    Do not put ChallengeRuns on the ProfileStore template (Reconcile trap).
]]

return {
    rooms = 99,
    no_pet_revives = true,
    wipe_ends_run = true,

    -- Current boards: best cleared room in one fixed, clock-aligned round.
    -- Persist GameData.ChallengeRuns.<mode>.recent only when a run exists.
    leaderboard = {
        -- Release cadence: one America/Denver calendar day, midnight to midnight.
        -- The boundary policy, not a fixed UTC offset, keeps midnight correct across DST.
        window_seconds = 24 * 60 * 60,
        fixed_rounds = true,
        round_boundary = "mountain_midnight",
        recent_cap = 48,
        -- Rotate stale round scores: server start, BindToClose, and this interval.
        sweep_seconds = 5 * 60,
        -- Rewards pay LeaderboardScoring.publicTop only. Release-hidden internal
        -- accounts never enter the award observation path.
    },

    modes = {
        -- Rank mode. Catalog pets/powers; the run is scored, not the roster.
        range = {
            loadout = "catalog",
            display = "The Range",
            -- The authored gate now lives in Home/Lava, so mission_* uses the ordinary
            -- Homeworld currency HUD instead of carrying Hall Waycoins into the run.
            hall_currency_hud = false,
            -- Rank mode is a solo test of an archetype kit. A party would
            -- share the instance and break the leaderboard.
            solo_only = true,
            -- Combat/power axis only (same seam as sidekick). Claimed/earned
            -- Level and entitlements stay put; exit clears the pin.
            effective_level = 50,
            -- Kill XP uses earned Level, not the 50 pin. Combat stays endgame;
            -- the bar ticks like a peer fight outside. xp_mult is a spare knob
            -- (1 = same as overworld at your rank).
            xp_from = "earned_level",
            xp_mult = 1,
            guide = {
                title = "The Range",
                lines = {
                    "Solo catalog run. Leave your team at the door.",
                    "Everyone fights at level 50.",
                    "XP pays at your real level, not 50.",
                    "Room 1 is two whelps. Maps change after that.",
                    "Pick an origin kit and a loaned squad.",
                    "Best room this award round ranks the board.",
                },
            },
            -- Room 1 teaches. Room 2 keeps two whelps but grows the map.
            -- Room 3+ uses trash packs on changing layouts.
            curve = {
                rooms = 99,
                hp_growth = 1.07,
                dmg_growth = 1.045,
                count_every = 12,
                count_cap = 5,
                lieutenant_at = 14,
                boss_at = 28,
                beats = {
                    {
                        upto = 1,
                        intro_only = true,
                        count_mult = 1,
                        tile_budget = 2,
                        target_depth = { min = 1, max = 1 },
                    },
                    {
                        upto = 2,
                        intro_only = true,
                        count_mult = 1,
                        tile_budget = 3,
                        target_depth = { min = 1, max = 2 },
                    },
                    {
                        upto = 9,
                        count_mult = 1,
                        tile_budget = 3,
                        target_depth = { min = 1, max = 2 },
                    },
                    {
                        upto = 13,
                        count_mult = 1,
                        tile_budget = 4,
                        target_depth = { min = 2, max = 3 },
                    },
                    {
                        upto = 21,
                        count_mult = 1,
                        add_lieutenant = true,
                        tile_budget = 4,
                        target_depth = { min = 2, max = 3 },
                    },
                    {
                        upto = 27,
                        count_mult = 2,
                        add_lieutenant = true,
                        tile_budget = 4,
                        target_depth = { min = 2, max = 3 },
                    },
                    {
                        upto = 40,
                        count_mult = 2,
                        add_lieutenant = true,
                        add_boss = true,
                        tile_budget = 4,
                        target_depth = { min = 2, max = 3 },
                    },
                    {
                        upto = 60,
                        count_mult = 3,
                        add_lieutenant = true,
                        add_boss = true,
                        extra_lieutenants = 1,
                        tile_budget = 4,
                        target_depth = { min = 2, max = 3 },
                    },
                    {
                        upto = 80,
                        count_mult = 4,
                        add_lieutenant = true,
                        add_boss = true,
                        extra_lieutenants = 2,
                        tile_budget = 4,
                        target_depth = { min = 2, max = 3 },
                    },
                    {
                        upto = 99,
                        count_mult = 5,
                        add_lieutenant = true,
                        add_boss = true,
                        extra_lieutenants = 2,
                        tile_budget = 4,
                        target_depth = { min = 2, max = 3 },
                    },
                },
            },
            catalog = {
                pet_slots = 5,
                power_slots = 6,
                -- Loaned arcade roster. Meet exclusives are basic Colorado +
                -- Kade. Creator Colorado is apex/test-only and never legal here.
                disallowed_pets = { "colorado_creator" },
                pets = {
                    { pet = "colorado", variant = "basic", default = true },
                    { pet = "kade", variant = "basic", default = true },
                    { pet = "blade_lynx", variant = "golden", default = true },
                    { pet = "fortune_wisp", variant = "golden", default = true },
                    { pet = "clockwork_spider", variant = "basic", default = true },
                    { pet = "atlas_golem", variant = "golden" },
                    { pet = "portal_drake", variant = "golden" },
                    { pet = "crownwing_falcon", variant = "basic" },
                    { pet = "rift_panther", variant = "golden" },
                    { pet = "bolt_hawk", variant = "golden" },
                    { pet = "chain_serpent", variant = "basic" },
                    { pet = "bastion_ram", variant = "golden" },
                    { pet = "banner_hare", variant = "basic" },
                    { pet = "keytail_raccoon", variant = "golden" },
                    { pet = "star_moth", variant = "basic" },
                    { pet = "vault_beetle", variant = "basic" },
                    { pet = "lockbox_imp", variant = "basic" },
                    { pet = "compass_fox", variant = "golden" },
                    { pet = "beacon_finch", variant = "basic" },
                    { pet = "guide_moth", variant = "basic" },
                },
                -- Full PowerChoice menu: any authored power except gauntlet-illegal
                -- kit (Genie revive, instant Revive). One saved kit per origin.
                origins = { "geomancer", "sandwalker", "cryomancer", "pyromancer" },
                powers = "all",
                disallowed_powers = { "genie_dunes", "revive" },
                default_powers = { "sunder", "taunt", "rage", "restoring_sands" },
                -- Loaned powers are auto-slotted. Players do not slot by hand.
                -- Optional custom slotting can ride this table later; defaults stay fair.
                slotting = {
                    max_slots = 6,
                    origin = "sandwalker",
                    default = { "recharge", "recharge", "recharge", "focus", "focus", "focus" },
                    recipes = {
                        hasten = {
                            "recharge",
                            "recharge",
                            "recharge",
                            "recharge",
                            "recharge",
                            "recharge",
                        },
                    },
                },
            },
        },

        -- Own pets/powers, same recycled arena, easier curve.
        training_ground = {
            loadout = "own",
            display = "Training Ground",
            hall_currency_hud = false,
            -- Overworld onramp (combat.engagement.min_engage_level 5) is for
            -- the Hall/Crystal display fight. TG is the place to train with
            -- your real pets as soon as you can walk in.
            skip_engage_gate = true,
            guide = {
                title = "Training Ground",
                lines = {
                    "Your own pets and powers.",
                    "Fight as soon as you can get here.",
                    "Teams are allowed.",
                    "Room 1 is two whelps. Maps change after that.",
                    "Easier rooms than The Range.",
                    "Best room this award round ranks the board.",
                },
            },
            curve = {
                rooms = 99,
                hp_growth = 1.04,
                dmg_growth = 1.025,
                count_every = 14,
                count_cap = 4,
                lieutenant_at = 18,
                boss_at = 40,
                beats = {
                    {
                        upto = 1,
                        intro_only = true,
                        count_mult = 1,
                        tile_budget = 2,
                        target_depth = { min = 1, max = 1 },
                    },
                    {
                        upto = 2,
                        intro_only = true,
                        count_mult = 1,
                        tile_budget = 3,
                        target_depth = { min = 1, max = 2 },
                    },
                    {
                        upto = 12,
                        count_mult = 1,
                        tile_budget = 3,
                        target_depth = { min = 1, max = 2 },
                    },
                    {
                        upto = 17,
                        count_mult = 1,
                        tile_budget = 4,
                        target_depth = { min = 2, max = 3 },
                    },
                    {
                        upto = 27,
                        count_mult = 1,
                        add_lieutenant = true,
                        tile_budget = 4,
                        target_depth = { min = 2, max = 3 },
                    },
                    {
                        upto = 39,
                        count_mult = 2,
                        add_lieutenant = true,
                        tile_budget = 4,
                        target_depth = { min = 2, max = 3 },
                    },
                    {
                        upto = 55,
                        count_mult = 2,
                        add_lieutenant = true,
                        add_boss = true,
                        tile_budget = 4,
                        target_depth = { min = 2, max = 3 },
                    },
                    {
                        upto = 75,
                        count_mult = 3,
                        add_lieutenant = true,
                        add_boss = true,
                        extra_lieutenants = 1,
                        tile_budget = 4,
                        target_depth = { min = 2, max = 3 },
                    },
                    {
                        upto = 99,
                        count_mult = 4,
                        add_lieutenant = true,
                        add_boss = true,
                        extra_lieutenants = 2,
                        tile_budget = 4,
                        target_depth = { min = 2, max = 3 },
                    },
                },
            },
        },

        -- Isolated combat tutorial. Reuses Training Ground Room 1 maps (train#1).
        -- No public board, no ChallengeRuns persist, no level-5 engage gate.
        -- Own-loadout stamp: CombatTutorialService temp-grants the starter
        -- commons from combat_tutorial.loaned_squad (mix-and-match in inventory).
        combat_tutorial = {
            loadout = "own",
            display = "Combat Training",
            hall_currency_hud = false,
            skip_engage_gate = true,
            persist_runs = false,
            tutorial = true,
            curve = {
                rooms = 1,
                hp_growth = 1,
                dmg_growth = 1,
                beats = {
                    {
                        upto = 1,
                        intro_only = true,
                        count_mult = 1,
                        tile_budget = 2,
                        target_depth = { min = 1, max = 1 },
                    },
                },
            },
        },
    },
}
