--[[
    combat_tutorial — isolated combat-training path (config-as-code, EVENT-DRIVEN).

    Live Homeworld combat beat: the Earth cave is the training venue. The Hall
    arch is no longer an entry. Progress persists as profile.CombatTutorial
    (never a ProfileStore template field).

    Each taught tool is its own lobby → ENTER → fight → pillar loop. Heal stays
    through its pillar. Debuff, brew-stacking, tank, enemy healer, then an
    unguided "on your own" room. The last pillar marks the track done.
]]

return {
    version = 11,
    -- Rhythm is lobby → ENTER door → fight → pillar back to lobby.
    -- The frost door stays sealed until the current lobby lesson is done.
    -- Pillar / leave-resume lobby returns wipe Heal/Revive CDs, pet recovery,
    -- and Focus so the next room is a fresh start.
    refresh_on_lobby = true,
    step_migrations = {
        [1] = {
            [1] = { step = 1 }, -- first_fight -> ready
            [2] = { step = 3 }, -- battle_brew
            [3] = { step = 4 }, -- bind_heal
            [4] = { step = 5 }, -- enter_arena -> select_pet
            [5] = { step = 5 },
            [6] = { step = 6 },
            [7] = { step = 7 },
        },
        [2] = {
            [1] = { step = 1 }, -- ready
            [2] = { step = 2 }, -- first_fight
            [3] = { step = 4 }, -- battle_brew
            [4] = { step = 5 }, -- bind_heal
            [5] = { step = 6 },
            [6] = { step = 7 },
            [7] = { step = 8 },
        },
        [3] = {
            [1] = { step = 1 }, -- ready
            [2] = { step = 2 }, -- first_fight
            [3] = { step = 3 }, -- advance_stage
            [4] = { step = 4 }, -- battle_brew
            [5] = { step = 8 }, -- bind_heal
            [6] = { step = 10 }, -- select_pet
            [7] = { step = 11 }, -- cast_heal
            [8] = { step = 12 }, -- more_coming
        },
        [4] = {
            [1] = { step = 1 },
            [2] = { step = 2 },
            [3] = { step = 3 },
            [4] = { step = 4 },
            [5] = { step = 5 },
            [6] = { step = 6 },
            [7] = { step = 7 },
            [8] = { step = 8 },
            [9] = { step = 9 },
            [10] = { step = 10 },
            [11] = { step = 11 }, -- cast_heal
            [12] = { step = 12 }, -- more_coming -> select_enemy
        },
        [5] = {
            [1] = { step = 1 },
            [2] = { step = 2 },
            [3] = { step = 3 },
            [4] = { step = 4 },
            [5] = { step = 5 },
            [6] = { step = 6 },
            [7] = { step = 7 },
            [8] = { step = 8 },
            [9] = { step = 9 },
            [10] = { step = 10 },
            [11] = { step = 11 }, -- cast_heal
            [12] = { step = 12 }, -- select_enemy -> advance_heal
            [13] = { step = 14 }, -- throw_weaken -> select_enemy
            [14] = { step = 31 }, -- more_coming
        },
        [6] = {
            [1] = { step = 1 },
            [2] = { step = 2 },
            [3] = { step = 3 },
            [4] = { step = 4 },
            [5] = { step = 5 },
            [6] = { step = 6 },
            [7] = { step = 7 },
            [8] = { step = 8 },
            [9] = { step = 9 },
            [10] = { step = 10 },
            [11] = { step = 11 }, -- cast_heal
            [12] = { step = 13 }, -- advance_heal (heal_fight inserted)
            [13] = { step = 14 },
            [14] = { step = 15 },
            [15] = { step = 16 },
            [16] = { step = 17 },
            [17] = { step = 18 },
            [18] = { step = 19 },
            [19] = { step = 20 },
            [20] = { step = 21 },
            [21] = { step = 22 },
            [22] = { step = 23 },
            [23] = { step = 24 },
            [24] = { step = 25 },
            [25] = { step = 26 },
            [26] = { step = 27 },
            [27] = { step = 28 },
            [28] = { step = 29 },
            [29] = { step = 30 },
            [30] = { step = 31 },
        },
        [7] = {
            [1] = { step = 1 },
            [2] = { step = 2 },
            [3] = { step = 3 },
            [4] = { step = 4 },
            [5] = { step = 5 },
            [6] = { step = 6 },
            [7] = { step = 7 },
            [8] = { step = 8 },
            [9] = { step = 9 },
            [10] = { step = 10 },
            [11] = { step = 11 },
            [12] = { step = 12 },
            [13] = { step = 13 },
            [14] = { step = 14 },
            [15] = { step = 15 },
            [16] = { step = 16 }, -- throw_weaken
            [17] = { step = 18 }, -- advance_weaken (weaken_fight inserted)
            [18] = { step = 19 },
            [19] = { step = 20 },
            [20] = { step = 21 },
            [21] = { step = 22 },
            [22] = { step = 23 },
            [23] = { step = 24 },
            [24] = { step = 25 },
            [25] = { step = 26 },
            [26] = { step = 27 },
            [27] = { step = 28 },
            [28] = { step = 29 },
            [29] = { step = 30 },
            [30] = { step = 31 },
            [31] = { step = 32 },
        },
        [8] = {
            [1] = { step = 1 },
            [2] = { step = 2 },
            [3] = { step = 3 },
            [4] = { step = 4 },
            [5] = { step = 5 },
            [6] = { step = 6 },
            [7] = { step = 7 },
            [8] = { step = 8 },
            [9] = { step = 9 },
            [10] = { step = 10 },
            [11] = { step = 11 },
            [12] = { step = 12 },
            [13] = { step = 13 },
            [14] = { step = 14 },
            [15] = { step = 15 },
            [16] = { step = 16 },
            [17] = { step = 17 },
            [18] = { step = 18 },
            [19] = { step = 19 },
            [20] = { step = 20 },
            [21] = { step = 21 },
            [22] = { step = 22 },
            [23] = { step = 23 },
            [24] = { step = 24 },
            [25] = { step = 25 },
            [26] = { step = 26 },
            [27] = { step = 27 }, -- healer_hunt
            [28] = { step = 29 }, -- advance_healer (healer_fight inserted)
            [29] = { step = 30 },
            [30] = { step = 31 },
            [31] = { step = 32 },
            [32] = { step = 33 },
        },
        [9] = {
            [1] = { step = 1 },
            [2] = { step = 2 },
            [3] = { step = 3 },
            [4] = { step = 4 },
            [5] = { step = 5 },
            [6] = { step = 6 },
            [7] = { step = 7 },
            [8] = { step = 8 },
            [9] = { step = 9 },
            [10] = { step = 10 },
            [11] = { step = 11 },
            [12] = { step = 12 },
            [13] = { step = 13 },
            [14] = { step = 14 },
            [15] = { step = 15 },
            [16] = { step = 16 },
            [17] = { step = 17 },
            [18] = { step = 18 },
            [19] = { step = 19 },
            [20] = { step = 20 },
            [21] = { step = 21 },
            [22] = { step = 22 },
            [23] = { step = 23 },
            [24] = { step = 24 },
            [25] = { step = 25 },
            [26] = { step = 26 },
            [27] = { step = 27 },
            [28] = { step = 28 },
            [29] = { step = 29 },
            [30] = { step = 30 },
            [31] = { step = 31 },
            [32] = { step = 32 }, -- advance_together
            [33] = { step = 33 }, -- more_coming past the end → done
        },
        [10] = {
            [1] = { step = 1 },
            [2] = { step = 2 },
            [3] = { step = 3 },
            [4] = { step = 4 },
            [5] = { step = 5 },
            [6] = { step = 6 },
            [7] = { step = 7 },
            [8] = { step = 8 }, -- bind_heal remains the binding lesson
            [9] = { step = 10 }, -- existing saves continue at ready_heal (no rewind)
            [10] = { step = 11 },
            [11] = { step = 12 },
            [12] = { step = 13 },
            [13] = { step = 14 },
            [14] = { step = 15 },
            [15] = { step = 16 },
            [16] = { step = 17 },
            [17] = { step = 18 },
            [18] = { step = 19 },
            [19] = { step = 20 },
            [20] = { step = 21 },
            [21] = { step = 22 },
            [22] = { step = 23 },
            [23] = { step = 24 },
            [24] = { step = 25 },
            [25] = { step = 26 },
            [26] = { step = 27 },
            [27] = { step = 28 },
            [28] = { step = 29 },
            [29] = { step = 30 },
            [30] = { step = 31 },
            [31] = { step = 32 },
            [32] = { step = 33 },
        },
    },
    entry = {
        enabled = false,
        hook_name = "HallOfWorldsPortal",
        title = "COMBAT TRAINING",
        mission_id = "combat_tutorial",
    },

    -- Cave mouth is the door only. Play uses MissionInstanceService slots —
    -- the same far-X band as Range / Training Ground (10 concurrent, 3072
    -- studs apart). Realm layers already own vertical stacking.
    venue = {
        mode = "mission_slot",
        door = "homeworld_cave",
        homeworld_step = "first_fight",
        mission_id = "combat_tutorial",
        -- Realm layers clone the same part name. Only the Homeworld cave is live.
        anchor_root = "Maps.Home",
        -- EarthLair is the visible mouth. BaddieSpawnerEarth is a 4-stud
        -- interior part; a 14-stud E on that part never reaches the entrance.
        anchor_name = "EarthLair",
        -- E stays on the mouth for everyone. Walk in unless they already
        -- finished this cave track — only then ask to redo.
        always_offer = true,
        enter_prompt = {
            prompt_name = "CombatTutorialCaveEnter",
            action_text = "Enter",
            object_text = "Combat Training",
            hold_duration = 0.25,
            max_distance = 40,
        },
        redo_confirm = {
            title = "Combat Training",
            body = "You've already finished this. Redo the training?",
            yes_text = "Redo",
            no_text = "Not now",
        },
        -- Leave is a SurfaceGui on the frost door, not a camera Billboard
        -- or E prompt. Confirm so a misclick does not dump them out.
        leave_prompt = {
            prompt_name = "CombatTutorialLobbyLeave",
            action_text = "Continue later",
            object_text = "Combat Training",
            hold_duration = 0.25,
            max_distance = 24,
            enable_after = 0.8,
        },
        leave_confirm = {
            title = "Continue later?",
            body = "Your progress is saved. Come back anytime.",
            yes_text = "Leave",
            no_text = "Stay",
        },
    },

    -- Live funnel: keep progress across cave visits. Isolated Hall testing
    -- used restart_on_enter so each walk-in started at ready.
    restart_on_enter = false,

    -- Temp inventory overlay (not Range GhostPets). Three of each starter
    -- common so Inventory can mix a 3-slot squad. The track starts on three
    -- doggies; the tank lesson resets to that and asks for a bear.
    -- Equipped.pets is snapshotted; the grants come back off on exit.
    loaned_squad = {
        count = 3,
        pets = {
            { pet = "bunny", variant = "basic" },
            { pet = "doggy", variant = "basic" },
            { pet = "bear", variant = "basic" },
            { pet = "kitty", variant = "basic" },
        },
        equip = { "doggy", "doggy", "doggy" },
    },

    -- Teaching rooms stay readable at any player level. Repeat testers must
    -- not stack leftover healers on top of the authored pack.
    pack_cap = {
        max_healers = 1,
        max_others = 3,
        enemy_level = 1,
    },

    -- Earth melee (rabid_dog) at the Homeworld first-fight onramp scale: jackalope
    -- hp 1100 × 0.25 and damage 6 × 0.2 (configs/combat.lua engagement.onramp).
    -- Pre-level-2 squads should delete it; it should barely scratch.
    enemy = {
        id = "rabid_dog",
        display_name = "Training Dog",
        hp = 275,
        move_speed = 14,
        armor = 0,
        attack = { damage = 1, cadence = 1.8, sundering = 0 },
    },

    -- Inner-door seal: two SurfaceGuis on the frost (lesson + Continue later).
    -- No camera Billboard. Transparency 0.28 reads as empty in a bright kit.
    door = {
        look = {
            material = "Ice",
            color = { 198, 220, 236 },
            transparency = 0.08,
            reflectance = 0.12,
        },
        button = {
            text = "ENTER",
            ready_text = "READY",
            pulse_seconds = 0.7,
            width = 420,
            height = 110,
            pixels_per_stud = 40,
            height_from_floor = 5,
            leave_height = 72,
            leave_gap = 18,
        },
        -- Shared ENTER gate. Every ready beat must pass this whole list.
        -- Rows name a check in src/Shared/Game/TutorialUnlock.lua.
        unlock_when = {
            {
                check = "pets_equipped",
                count = 1,
                fail_plate = "EQUIP PETS",
                fail_nudge = "Go equip pets.",
            },
            {
                check = "hotbar_not_editing",
                fail_plate = "PRESS DONE",
                fail_nudge = "Press Done first!",
            },
        },
    },

    -- Training Ground objective pillar. After a fight we light this, then the
    -- pillar warps the player back to the lobby and reseals ENTER. Same map —
    -- no gauntlet restamp.
    beacon = {
        part_name = "ObjectiveBeacon",
        action_text = "Advance",
        object_text = "Combat Training",
        hold_duration = 0,
        max_distance = 12,
        label = "⬇ ADVANCE",
    },

    -- Teaching lock only (Heal / Weakening rooms). Huge pool + refresh until
    -- drop_shields. Do not use this on the finale — that is invulnerability.
    shield = {
        power_id = "dune_shield",
        pool = 1000000,
        duration = 1800,
    },

    -- Real combat absorb: same pool and timer as pet Dune Shield
    -- (powers.effect_kinds.shield). Applied once; CombatApplication depletes it.
    combat_shield = {
        power_id = "dune_shield",
        pool = 400,
        duration = 12,
    },

    steps = {
        {
            id = "ready",
            theme = "grass",
            localization_key = "combat_tutorial.ready",
            title = "Ready to fight",
            body = "Press ENTER on the frost door when you're ready. A very weak enemy will appear.",
            lock_door = true,
            target = { kind = "part", name = "CombatTutorialDoorSeal", label = "⬇ ENTER" },
            complete_on = { event = "combat_tutorial_entered_arena" },
        },
        {
            id = "first_fight",
            localization_key = "combat_tutorial.first_fight",
            title = "Your first fight",
            body = "A weak enemy is here. Walk over — your pets fight for you. Defeat it!",
            spawn = { count = 1, where = "arena" },
            -- Mid-fight leave returns to this loop's ENTER, not the track start.
            leave_resume = "ready",
            complete_on = { event = "enemy_defeated" },
        },
        {
            id = "advance_stage",
            localization_key = "combat_tutorial.advance_stage",
            title = "Back to the lobby",
            body = "The room is clear. Follow the trail and activate the glowing pillar to return to the lobby.",
            body_gamepad = "The room is clear. Follow the trail and press X on the glowing pillar to return to the lobby.",
            target = {
                kind = "part",
                name = "ObjectiveBeacon",
                label = "⬇ ADVANCE",
            },
            activate_beacon = true,
            return_to_lobby = true,
            complete_on = { event = "combat_tutorial_advance" },
        },
        {
            id = "battle_brew",
            theme = "lava",
            localization_key = "combat_tutorial.battle_brew",
            title = "Drink for battle",
            grant = { potions = { { id = "berserk_brew", count = 2 } } },
            lock_door = true,
            door_button = {
                text = "DRINK FIRST",
                nudge = "Drink first!",
            },
            body = "You're safe here. CLICK the flashing Berserk Brew in your power bar. It makes every pet hit harder!",
            body_gamepad = "You're safe here. Use LB/RB to select the flashing brew, then RT to drink it.",
            target = {
                kind = "ui",
                hotbar_type = "potion",
                hotbar_target = "berserk_brew",
                cue = "click",
                cue_text = "CLICK HERE",
            },
            complete_on = { event = "potion_used", potion = "berserk_brew" },
        },
        {
            id = "ready_brew",
            localization_key = "combat_tutorial.ready_brew",
            title = "Try your brew",
            body = "Press ENTER when you're ready to try Berserk Brew in a fight.",
            lock_door = true,
            target = { kind = "part", name = "CombatTutorialDoorSeal", label = "⬇ ENTER" },
            complete_on = { event = "combat_tutorial_entered_arena" },
        },
        {
            id = "brew_fight",
            localization_key = "combat_tutorial.brew_fight",
            title = "Fight with Berserk Brew",
            body = "Your pets hit harder now. Defeat this enemy!",
            spawn = { count = 1, where = "arena" },
            leave_resume = "battle_brew",
            complete_on = { event = "enemy_defeated" },
        },
        {
            id = "advance_brew",
            localization_key = "combat_tutorial.advance_brew",
            title = "Back to the lobby",
            body = "Follow the trail and activate the glowing pillar to return to the lobby.",
            body_gamepad = "Follow the trail and press X on the glowing pillar to return to the lobby.",
            target = {
                kind = "part",
                name = "ObjectiveBeacon",
                label = "⬇ ADVANCE",
            },
            activate_beacon = true,
            return_to_lobby = true,
            complete_on = { event = "combat_tutorial_advance" },
        },
        {
            id = "bind_heal",
            theme = "heaven",
            localization_key = "combat_tutorial.bind_heal",
            title = "Set your Heal",
            lock_door = true,
            door_button = {
                text = "SET HEAL FIRST",
                nudge = "Set Heal on your bar, then press Done!",
            },
            -- Door stays locked until every named check is true.
            unlock_when = {
                {
                    check = "pets_equipped",
                    count = 1,
                    fail_plate = "EQUIP PETS",
                    fail_nudge = "Go equip pets.",
                },
                {
                    check = "hotbar_bound",
                    type = "power",
                    target = "heal",
                    fail_plate = "SET HEAL FIRST",
                    fail_nudge = "Set Heal on your bar first!",
                },
                {
                    check = "hotbar_not_editing",
                    fail_plate = "PRESS DONE",
                    fail_nudge = "Press Done first!",
                },
            },
            body = "You were born with Heal! Hit Edit on your power bar, drop Heal onto a slot, then press Done. You'll do this for every power you unlock.",
            body_gamepad = "You were born with Heal! Press D-pad Right for Powers, choose Heal with A, assign it to a slot, then press Done.",
            target = {
                kind = "ui",
                name = "Edit",
                cue = "bind",
                hotbar_target = "heal",
                cue_text = "CLICK HERE",
            },
            complete_on = { event = "tutorial_hotbar_finished" },
        },
        {
            id = "enhance_heal",
            theme = "heaven",
            localization_key = "combat_tutorial.enhance_heal",
            title = "Enhance your Heal",
            lock_door = true,
            door_button = {
                text = "ENHANCE HEAL",
                nudge = "Put Potency into Heal first!",
            },
            -- Reuse the Farm & Fight enhancement lesson: grant one Heal-compatible piece and an
            -- inherent slot, then require that exact power in the event payload. The receipt is
            -- versioned so a tester stranded by the old incompatible Potency grant gets Healing on
            -- the next enter instead of being blocked by the already-recorded step grant.
            grant = {
                receipt = "enhance_heal_healing_v1",
                enhancements = { { type = "healing", origins = {}, level = 3, count = 1 } },
                ensure_slot = "heal",
            },
            body = "Now improve Heal. Open POWERS, choose Heal, pick its empty slot, choose Healing, and Apply it. Enhancements make every power stronger.",
            body_gamepad = "Press D-pad Right, choose Heal with A, select its empty slot, choose Healing, and Apply it.",
            target = {
                kind = "ui",
                name = "PowersButton",
                cue = "enhance_power",
                tutorial_guide = "Power:heal",
                enhancement_guide = "EnhanceType:healing",
                cue_text = "CLICK HERE",
            },
            complete_on = {
                event = "enhancement_slotted",
                context = { powerId = "heal" },
            },
        },
        {
            id = "ready_heal",
            localization_key = "combat_tutorial.ready_heal",
            title = "Ready to heal",
            body = "Press ENTER when you're ready to heal your squad in a fight.",
            lock_door = true,
            target = { kind = "part", name = "CombatTutorialDoorSeal", label = "⬇ ENTER" },
            complete_on = { event = "combat_tutorial_entered_arena" },
        },
        {
            id = "select_pet",
            localization_key = "combat_tutorial.select_pet",
            title = "Choose who to heal",
            leave_resume = "ready_heal",
            spawn = { count = 2, where = "arena", shield = true },
            -- 0.45 remaining is the yellow band on the squad bar (green→yellow at 0.5, red below).
            wound = { remaining_fraction = 0.45 },
            body = "One of your pets is badly hurt. CLICK that pet's yellow card on the right so Heal knows who to mend.",
            body_gamepad = "One of your pets is badly hurt. Select that pet's yellow card so Heal knows who to mend.",
            target = {
                kind = "ui",
                name = "InjuredSlot",
                cue = "click",
                cue_side = "left",
                cue_text = "CLICK HERE",
            },
            complete_on = { event = "pet_target_selected" },
        },
        {
            id = "cast_heal",
            localization_key = "combat_tutorial.cast_heal",
            title = "Heal your pet",
            leave_resume = "ready_heal",
            body = "Now press Heal. After your pet recovers, the enemy shields drop and the fight is on.",
            body_gamepad = "Use LB/RB to select Heal, then press RT to mend the pet you chose. Shields drop after the heal.",
            target = {
                kind = "ui",
                hotbar_type = "power",
                hotbar_target = "heal",
                cue = "click",
                cue_text = "CLICK HERE",
            },
            complete_on = { event = "pet_healed" },
            drop_shields = true,
        },
        {
            id = "heal_fight",
            localization_key = "combat_tutorial.heal_fight",
            title = "Finish the fight",
            leave_resume = "ready_heal",
            body = "The shields are down. Defeat the training dogs — you can't leave until the room is clear.",
            body_gamepad = "The shields are down. Defeat the training dogs — the pillar waits until the room is clear.",
            lock_door = true,
            target = { kind = "none" },
            complete_on = { event = "combat_tutorial_room_cleared" },
        },
        {
            id = "advance_heal",
            localization_key = "combat_tutorial.advance_heal",
            title = "Back to the lobby",
            body = "The room is clear. Follow the trail and activate the glowing pillar to return to the lobby.",
            body_gamepad = "The room is clear. Follow the trail and press X on the glowing pillar to return to the lobby.",
            target = {
                kind = "part",
                name = "ObjectiveBeacon",
                label = "⬇ ADVANCE",
            },
            activate_beacon = true,
            return_to_lobby = true,
            complete_on = { event = "combat_tutorial_advance" },
        },
        {
            id = "ready_weaken",
            theme = "hell",
            localization_key = "combat_tutorial.ready_weaken",
            title = "A new tool",
            grant = { potions = { { id = "weakening_vial", count = 2 } } },
            body = "Some enemies hide behind a shield. Weakening Vial is on your bar — press ENTER when you're ready to strip one.",
            lock_door = true,
            target = { kind = "part", name = "CombatTutorialDoorSeal", label = "⬇ ENTER" },
            complete_on = { event = "combat_tutorial_entered_arena" },
        },
        {
            id = "select_enemy",
            localization_key = "combat_tutorial.select_enemy",
            title = "Choose who to weaken",
            leave_resume = "ready_weaken",
            spawn = { count = 2, where = "arena", shield = true },
            mark_enemy = true,
            body = "CLICK that enemy's card on the left. Weakening Vial needs a target, just like Heal.",
            body_gamepad = "Select that enemy's card so Weakening Vial knows who to hit.",
            target = {
                kind = "ui",
                name = "TutorialEnemy",
                cue = "click",
                cue_side = "right",
                cue_text = "CLICK HERE",
                force_overlay = true,
            },
            complete_on = { event = "enemy_target_selected" },
        },
        {
            id = "throw_weaken",
            localization_key = "combat_tutorial.throw_weaken",
            title = "Weaken the enemy",
            leave_resume = "ready_weaken",
            body = "Now throw the Weakening Vial. When it hits, the shield drops — then finish the dogs. The pillar waits until they are down.",
            body_gamepad = "Use LB/RB to select Weakening Vial, then press RT. After the shield drops, defeat the dogs.",
            target = {
                kind = "ui",
                hotbar_type = "potion",
                hotbar_target = "weakening_vial",
                cue = "click",
                cue_text = "CLICK HERE",
            },
            complete_on = { event = "potion_used", potion = "weakening_vial" },
            drop_shields = true,
        },
        {
            id = "weaken_fight",
            localization_key = "combat_tutorial.weaken_fight",
            title = "Finish the fight",
            leave_resume = "ready_weaken",
            body = "The shields are down. Defeat the training dogs — you can't leave until the room is clear.",
            body_gamepad = "The shields are down. Defeat the training dogs — the pillar waits until the room is clear.",
            lock_door = true,
            target = { kind = "none" },
            complete_on = { event = "combat_tutorial_room_cleared" },
        },
        {
            id = "advance_weaken",
            localization_key = "combat_tutorial.advance_weaken",
            title = "Back to the lobby",
            body = "The room is clear. Follow the trail and activate the glowing pillar to return to the lobby.",
            body_gamepad = "The room is clear. Follow the trail and press X on the glowing pillar to return to the lobby.",
            target = {
                kind = "part",
                name = "ObjectiveBeacon",
                label = "⬇ ADVANCE",
            },
            activate_beacon = true,
            return_to_lobby = true,
            complete_on = { event = "combat_tutorial_advance" },
        },
        {
            id = "stack_brew",
            theme = "desert",
            localization_key = "combat_tutorial.stack_brew",
            title = "Sip more Berserk",
            grant = { potions = { { id = "berserk_brew", count = 10 } } },
            lock_door = true,
            door_button = {
                text = "DRINK FIVE MORE",
                nudge = "Drink five more Berserk Brews!",
                remaining_plates = {
                    [5] = "DRINK FIVE MORE",
                    [4] = "DRINK FOUR MORE",
                    [3] = "DRINK THREE MORE",
                    [2] = "DRINK TWO MORE",
                    [1] = "DRINK ONE MORE",
                },
                remaining_nudges = {
                    [5] = "Drink five more Berserk Brews!",
                    [4] = "Drink four more Berserk Brews!",
                    [3] = "Drink three more Berserk Brews!",
                    [2] = "Drink two more Berserk Brews!",
                    [1] = "Drink one more Berserk Brew!",
                },
            },
            body = "You have ten Berserk Brews. Each sip fills more of the damage meter — hits get bigger, but the timer stays the same. Drink at least five.",
            body_gamepad = "You have ten Berserk Brews. Use LB/RB and RT to sip at least five. Damage climbs; the timer does not get longer.",
            target = {
                kind = "ui",
                hotbar_type = "potion",
                hotbar_target = "berserk_brew",
                cue = "click",
                cue_text = "CLICK HERE",
            },
            complete_on = { event = "potion_used", potion = "berserk_brew", count = 5 },
        },
        {
            id = "ready_stack",
            localization_key = "combat_tutorial.ready_stack",
            title = "See the surge",
            body = "Press ENTER now and watch the bigger hits. The meter is already draining — don't linger.",
            lock_door = true,
            ensure_meter = { id = "damage", min_charge = 0.9 },
            target = { kind = "part", name = "CombatTutorialDoorSeal", label = "⬇ ENTER" },
            complete_on = { event = "combat_tutorial_entered_arena" },
        },
        {
            id = "stack_fight",
            localization_key = "combat_tutorial.stack_fight",
            title = "Fight while surging",
            leave_resume = "stack_brew",
            body = "Your doggies should chunk this one down much faster than the last training dogs. Finish it!",
            ensure_meter = { id = "damage", min_charge = 0.9 },
            spawn = { count = 1, where = "arena", hp = 400 },
            complete_on = { event = "enemy_defeated" },
        },
        {
            id = "advance_stack",
            localization_key = "combat_tutorial.advance_stack",
            title = "Back to the lobby",
            body = "Follow the trail and activate the glowing pillar to return to the lobby.",
            body_gamepad = "Follow the trail and press X on the glowing pillar to return to the lobby.",
            target = {
                kind = "part",
                name = "ObjectiveBeacon",
                label = "⬇ ADVANCE",
            },
            activate_beacon = true,
            return_to_lobby = true,
            complete_on = { event = "combat_tutorial_advance" },
        },
        {
            id = "ready_tank",
            theme = "ice",
            localization_key = "combat_tutorial.ready_tank",
            title = "Bring a tank",
            reset_squad = true,
            lock_door = true,
            door_button = {
                text = "EQUIP A TANK",
                nudge = "Equip a tank (a bear) first!",
            },
            unlock_when = {
                {
                    check = "squad_has_role",
                    role = "tank",
                    fail_plate = "EQUIP A TANK",
                    fail_nudge = "Equip a tank. Tanks soak hits and deal less damage.",
                },
            },
            body = "Open Pets. You'll take one doggy off and put a tank (a bear) on the squad.",
            body_gamepad = "Press D-pad Left to open Pets. You'll take one doggy off and put a tank on the squad.",
            guide = {
                open = {
                    title = "Bring a tank",
                    body = "Open Pets. You'll take one doggy off and put a tank (a bear) on the squad.",
                    body_gamepad = "Press D-pad Left to open Pets. You'll take one doggy off and put a tank on the squad.",
                    cue_text = "CLICK HERE",
                },
                unequip = {
                    title = "Free a slot",
                    body = "The squad is full. Click that last doggy to take it off.",
                    body_gamepad = "The squad is full. Select the last doggy and press A to take it off.",
                    cue_text = "TAKE OFF",
                },
                pick = {
                    title = "Pick a tank",
                    body = "Click the strongest tank (the golden bear). Or tap Tank in Best Pets — that grabs the strongest one.",
                    body_gamepad = "Select the strongest tank (the golden bear), or highlight Tank in Best Pets and press A.",
                    cue_text = "CLICK HERE",
                },
                activate = {
                    title = "Activate",
                    body = "Press Activate to send the tank out. Pets will close when the squad is live.",
                    body_gamepad = "Press Activate (A) to send the tank out. Pets will close when the squad is live.",
                    cue_text = "ACTIVATE",
                },
                close = {
                    title = "Close Pets",
                    body = "The tank is on your squad. Close inventory, then press ENTER.",
                    body_gamepad = "The tank is on your squad. Close inventory, then press ENTER.",
                    cue_text = "CLOSE",
                },
                enter = {
                    title = "Let the tank soak",
                    body = "Press ENTER. Your tank will hold the enemy and take the hits.",
                    body_gamepad = "Press ENTER. Your tank will hold the enemy and take the hits.",
                },
            },
            target = {
                kind = "ui",
                name = "PetsButton",
                cue = "equip_tank",
                cue_text = "CLICK HERE",
            },
            complete_on = { event = "combat_tutorial_entered_arena" },
        },
        {
            id = "tank_fight",
            localization_key = "combat_tutorial.tank_fight",
            title = "Let the tank soak",
            leave_resume = "ready_tank",
            body = "Your tank holds the enemy and hits softer. Let them take the fight — then finish it.",
            spawn = { count = 1, where = "arena", hp = 500 },
            complete_on = { event = "enemy_defeated" },
        },
        {
            id = "advance_tank",
            localization_key = "combat_tutorial.advance_tank",
            title = "Back to the lobby",
            body = "Follow the trail and activate the glowing pillar to return to the lobby.",
            body_gamepad = "Follow the trail and press X on the glowing pillar to return to the lobby.",
            target = {
                kind = "part",
                name = "ObjectiveBeacon",
                label = "⬇ ADVANCE",
            },
            activate_beacon = true,
            return_to_lobby = true,
            complete_on = { event = "combat_tutorial_advance" },
        },
        {
            id = "ready_healer",
            theme = "heaven",
            localization_key = "combat_tutorial.ready_healer",
            title = "Kill the healer",
            body = "The next pack has a healer. If you leave it up, the others keep getting mended. Press ENTER when you're ready.",
            lock_door = true,
            target = { kind = "part", name = "CombatTutorialDoorSeal", label = "⬇ ENTER" },
            complete_on = { event = "combat_tutorial_entered_arena" },
        },
        {
            id = "healer_hunt",
            localization_key = "combat_tutorial.healer_hunt",
            title = "Cut off the mend",
            leave_resume = "ready_healer",
            spawn = {
                where = "arena",
                units = {
                    {
                        id = "rabid_bunny",
                        display_name = "Training Healer",
                        hp = 400,
                        mark = true,
                        auto_heal = { interval = 2.5, amount = 80, range = 45 },
                    },
                    { count = 2, hp = 400 },
                },
            },
            mark_enemy = true,
            lock_door = true,
            body = "KILL the glowing healer first. The others stay dangerous until it drops.",
            body_gamepad = "Focus the glowing healer first, then clean up the rest.",
            target = {
                kind = "ui",
                name = "TutorialEnemy",
                cue = "healer_focus",
                cue_side = "right",
                cue_text = "KILL THIS",
                force_overlay = true,
            },
            -- Click pins the squad on the healer (assist + wipe other pet threat)
            -- so dogs cannot peel pets off. Assist expiry is not a miss.
            healer_focus = { pin_seconds = 600, threat = 10000 },
            lost_banner = "Your pets left the healer! Click it again.",
            complete_on = { event = "enemy_defeated", enemy = "rabid_bunny" },
        },
        {
            id = "healer_fight",
            localization_key = "combat_tutorial.healer_fight",
            title = "Finish the fight",
            leave_resume = "ready_healer",
            body = "The healer is down. Defeat the rest of the pack — you can't leave until the room is clear.",
            body_gamepad = "The healer is down. Defeat the rest of the pack — the pillar waits until the room is clear.",
            lock_door = true,
            target = { kind = "none" },
            complete_on = { event = "combat_tutorial_room_cleared" },
        },
        {
            id = "advance_healer",
            localization_key = "combat_tutorial.advance_healer",
            title = "Back to the lobby",
            body = "The room is clear. Follow the trail and activate the glowing pillar to return to the lobby.",
            body_gamepad = "The room is clear. Follow the trail and press X on the glowing pillar to return to the lobby.",
            target = {
                kind = "part",
                name = "ObjectiveBeacon",
                label = "⬇ ADVANCE",
            },
            activate_beacon = true,
            return_to_lobby = true,
            complete_on = { event = "combat_tutorial_advance" },
        },
        {
            id = "ready_together",
            theme = "grass",
            localization_key = "combat_tutorial.ready_together",
            title = "On your own",
            grant = {
                potions = {
                    { id = "weakening_vial", count = 2 },
                    { id = "berserk_brew", count = 3 },
                },
            },
            body = "Last room: no arrows. Two dogs and a healer. Press ENTER — you can win this.",
            lock_door = true,
            target = { kind = "part", name = "CombatTutorialDoorSeal", label = "⬇ ENTER" },
            complete_on = { event = "combat_tutorial_entered_arena" },
        },
        {
            id = "together_fight",
            localization_key = "combat_tutorial.together_fight",
            title = "Clear the room",
            leave_resume = "ready_together",
            body = "Two dogs and a healer. Clear the room — this one is yours.",
            spawn = {
                where = "arena",
                units = {
                    {
                        id = "rabid_bunny",
                        display_name = "Training Healer",
                        hp = 400,
                        auto_heal = { interval = 2.5, amount = 80, range = 45 },
                    },
                    { count = 2, hp = 400 },
                },
            },
            target = { kind = "none" },
            complete_on = { event = "combat_tutorial_room_cleared" },
        },
        {
            id = "advance_together",
            localization_key = "combat_tutorial.advance_together",
            title = "Back to the lobby",
            body = "You did that without the arrows. Follow the trail and activate the glowing pillar.",
            body_gamepad = "You did that without the arrows. Follow the trail and press X on the glowing pillar.",
            target = {
                kind = "part",
                name = "ObjectiveBeacon",
                label = "⬇ ADVANCE",
            },
            activate_beacon = true,
            return_to_exit = true,
            complete_on = { event = "combat_tutorial_advance" },
        },
    },

    -- Live Homeworld combat beat: finishing the cave tops them to earned Level 2
    -- (same guarantee as configs/tutorial.lua) and warps them back outside.
    completion = {
        localization_key = "combat_tutorial.completion",
        grant_earned_level = 2,
        apply_level_grant = true,
        title = "🎉 COMBAT TRAINING COMPLETE — LEVEL 2!",
        body = "You earned Level 2! Head back outside — Rally is next, then the Ascension Altar.",
        banner = "Combat training complete!",
        show_seconds = 8,
        grant = {
            currencies = { grass_coins = 250 },
            potions = {
                { id = "berserk_brew", count = 3 },
                { id = "weakening_vial", count = 2 },
            },
        },
    },
}
