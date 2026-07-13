--[[
    Archetypes — Halo & Horns [PROTOTYPE] (Feature 13).

    The player picks ONE archetype (at character creation); it gates which power
    pool they can select from (Feature 14). Alignment (Soul) is orthogonal — it
    does not change the archetype or its pool. Archetype can only change via the
    respec ritual (which also resets powers + augmentation slots).

    Config-as-code: add/replace archetypes and their power pools here with no
    service changes (Feature 26). Pure logic lives in
    `src/Shared/Game/ArchetypeLogic.lua`; power definitions live in configs/powers.lua.
]]

return {
    -- No default: a new player must select before play (Feature 13 [studio]).
    default = nil,

    -- Respec ritual cost (changes archetype + resets powers/slots).
    respec_cost = { currency = "shadow_tokens", amount = 100 },

    -- GENERIC pool — universal powers EVERY archetype can pick (farming / luck / utility). White
    -- disc (no element origin). ArchetypeLogic.availablePowers appends these to the archetype pool,
    -- so the player's pickable pool = origin powers + generic ≈ 20 (pick 10).
    generic_pool = {
        -- Resonance is INNATE (owned by everyone from spawn, configs/powers.lua innate=true). It's in
        -- the pool so it RENDERS in the NATURAL column as an owned, slottable row (unlock_level=1 sorts
        -- it to the top, above Magnet) — but it's surfaced as already-owned, so it never costs a pick.
        "resonance",
        "prospector",
        "windfall",
        "fortune",
        "huge_fortune",
        "swift",
        "hasten",
        "revive",
        "recall",
        "world_travel",
        "xp_surge",
        "magnet",
    },

    archetypes = {
        geomancer = {
            display_name = "Geomancer",
            theme = "earth",
            choice = {
                role = "Tank",
                tagline = "Take the hit. Hold the line. Protect the squad.",
                description = "Geomancers are defensive tanks designed to take damage and keep their squad standing. They pull enemy attention with Taunt, reinforce pets with armor and shields, and grow more dangerous as the fight wears on.",
                strengths = {
                    "Takes and redirects enemy pressure",
                    "Protects the squad with armor and shields",
                    "Controls aggro and strengthens team damage",
                },
                tradeoff = "Very little direct damage. Geomancers win through durability, protection, and letting their pets do the hurting.",
            },
            power_pool = {
                -- cores (7)
                "stone_skin",
                "ironclad",
                "mountains_strength",
                "sunder",
                "taunt",
                "rage",
                "armor_field",
                -- signatures (gaia_colossus = summon capstone)
                "bastion",
                "seismic_hold",
                "living_mountain",
                "gaia_colossus",
            },
        },
        sandwalker = {
            display_name = "Sandwalker",
            theme = "desert",
            choice = {
                role = "Support",
                tagline = "Heal allies. Weaken enemies. Keep everyone fighting.",
                description = "Sandwalkers are support specialists built around healing, shielding, and enabling the squad. They restore injured pets, weaken and misdirect enemies, and use fear and quicksand to buy the team breathing room.",
                strengths = {
                    "Strong single-target and area healing",
                    "Shields allies and weakens enemy attacks",
                    "Adds fear, roots, and other utility control",
                },
                tradeoff = "Low direct damage. Sandwalkers are strongest when their pets and teammates can capitalize on the support they provide.",
            },
            power_pool = {
                -- cores (8)
                "mirage_step",
                "sandstorm",
                "dune_shield",
                "expose",
                "restoring_sands",
                -- fear = NEGATIVE aggro (Phase 2, live): drives the enemy's threat below zero so the
                -- aggro system inverts into RUNNING AWAY (EnemyService flee branch), then it recovers.
                "fear",
                "quicksand", -- AoE root: lock the pack so pets pile on + stay in Healing Field
                "healing_field",
                -- signatures (genie_dunes = summon+revive capstone)
                "oasis",
                "mirage_veil",
                "simoom",
                "genie_dunes",
            },
        },
        cryomancer = {
            display_name = "Cryomancer",
            theme = "ice",
            choice = {
                role = "Control",
                tagline = "Freeze the battlefield and decide who gets to act.",
                description = "Cryomancers are battlefield controllers. They root enemies in place, disarm their attacks, freeze whole groups, and lock dangerous targets down so the squad can fight on its own terms.",
                strengths = {
                    "Roots, disarms, slows, and holds enemies",
                    "Controls dangerous groups and priority targets",
                    "Adds focused ice damage and defensive armor",
                },
                tradeoff = "No healing and less raw damage than a Pyromancer. Cryomancers trade speed for safety and control.",
            },
            power_pool = {
                -- cores (7)
                "frost_bind",
                "ice_armor",
                "disarm",
                "focus_fire",
                "ice_shard",
                "deep_freeze",
                "frost_field",
                -- signatures (eternal_winter = field-hold capstone)
                "permafrost",
                "shatter",
                "absolute_zero",
                "eternal_winter",
            },
        },
        pyromancer = {
            display_name = "Pyromancer",
            theme = "lava",
            choice = {
                role = "Damage",
                tagline = "Burn down single targets and entire groups.",
                description = "Pyromancers are glass-cannon damage dealers. They combine direct strikes, burning damage over time, critical hits, and explosive area attacks to end fights before the enemy can recover.",
                strengths = {
                    "Highest direct and area damage potential",
                    "Burns enemies over time and boosts critical hits",
                    "Excels at finishing fights quickly",
                },
                tradeoff = "Only one defensive shield and no healing or hard control. Pyromancers survive by defeating enemies fast.",
            },
            -- mark_of_flame/ember_ward/eruption = shared-pool placeholders; wildfire/firestorm/
            -- cataclysm = the exclusive signatures (§17.8), cataclysm the high-level capstone.
            power_pool = {
                -- cores (7)
                "mark_of_flame",
                "ember_ward",
                "eruption",
                "strike",
                "critical_strike",
                "scorch",
                "fire_nova",
                -- signatures (cataclysm = capstone)
                "wildfire",
                "firestorm",
                "cataclysm",
                "inferno_brand",
            },
        },
    },
}
