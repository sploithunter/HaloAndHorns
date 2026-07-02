-- Universal Inventory System Configuration
-- This file defines inventory buckets, schemas, and settings for the game

return {
    -- Version for migration support
    version = "1.0.0",

    -- Which inventory buckets this game uses
    enabled_buckets = {
        pets = true,
        eggs = true, -- held egg ITEMS (Meet-The-Creator etc.) — hatched on demand
        enhancements = true, -- CoH-style power enhancements (drops; slot via Power Choice)
        potions = true, -- brew-charge potions (drink from the hotbar strip; tradeable)
        weapons = false, -- Disabled for pet simulator
        tools = true, -- Enabled for pickaxes and mining tools
        consumables = true,
        resources = true, -- NEW: For stackable resources like wood, ore, etc.
        cosmetics = false,
        mounts = false,
    },

    -- Bucket definitions
    buckets = {
        -- PET STORAGE — single source of truth for OWNERSHIP lives in Inventory.pets.items:
        --   • common (fungible) → one entry per kind, keyed "id:variant": { id, variant, quantity }
        --   • special (unique)  → one entry per instance, keyed by uid: { uid, id, variant, ... }
        -- EQUIP is a SEPARATE, validated layer in Equipped.pets (slot → "<uid>" | "stack|id:variant").
        -- Equipping NEVER mutates ownership; the live equipped set is Equipped ∩ inventory
        -- (PetInventoryView.resolveEquipped), capped per kind at quantity. See Shared/Inventory/.
        pets = {
            display_name = "Pets",
            icon = "🐾",
            -- STORAGE V2 (docs/PET_STORAGE_V2.md): base_limit counts UNIQUE records ONLY
            -- (secret+). Stacks NEVER count — they're self-bounding (a kind exists once;
            -- the catalog is their cap). The old 50 was a template-era fossil that
            -- truncated auto-hatch batches in production (Jason's alt-account find).
            base_limit = 500,
            storage_type = "mixed",
            -- the ENCHANT is part of a stack's identity (Storage v2 D2): a mythic's
            -- hatch-rolled effect splits it into its own pile ("Mythic Scorpion · Coin
            -- Finder"). "" component for enchantless stacks.
            stack_key_fields = { "id", "variant", "enchant" },
            count_stacks_as_single = true, -- one display slot per kind (commons) + per special
            stacks_count_toward_limit = false, -- Storage v2: only uniques consume slots
            max_stack_size = 99999,
            -- mythic DEMOTED to stackable (Storage v2 D1) — it keeps an enchant via the
            -- stack key instead of a per-uid record (see enchants.lua stack_enchants)
            special_rarities = { "secret", "exclusive", "huge", "creator" },
            equip_individualization = "equipped_layer", -- equip is tracked in Equipped.pets, not the stack

            -- Limit extensions via gamepasses
            limit_extensions = {
                {
                    gamepass_id = 123456789, -- TODO: Replace with actual gamepass ID
                    additional_slots = 50,
                    name = "Extra Pet Storage",
                },
                {
                    gamepass_id = 987654321, -- TODO: Replace with actual gamepass ID
                    additional_slots = 100,
                    name = "Ultimate Pet Storage",
                },
            },

            -- Mixed schema definition
            schema = {
                stacks = {
                    required = { "id", "variant", "quantity" },
                    optional = { "obtained_at", "element", "enchant" },
                },
                special = {
                    required = { "id", "variant", "obtained_at" },
                    optional = {
                        "level",
                        "exp",
                        "max_level",
                        "xp_to_next_level",
                        "nickname",
                        "enchantments",
                        "enchantable",
                        "max_enchantments",
                        "unlocked_enchant_slots",
                        "locked",
                        "huge",
                        "serial",
                        "serial_key",
                        "serial_source",
                        "rarity_id",
                        "rarity_override",
                        "eternal",
                        "eternal_percent",
                        "hatcher_name",
                        "hatcher_user_id",
                        "grant_source",
                    },
                },
            },

            -- Validation rules
            validation = {
                max_nickname_length = 20,
                allowed_characters = "^[%w%s]+$", -- Alphanumeric + spaces
                max_level = 100,
                max_enchantments = 5,
                -- Mixed-specific rules
                forbid_enchants_on_stacks = true,
                forbid_levels_on_stacks = true,
            },

            tooltip_fields = {
                -- Pet records can keep audit/internal fields without making them UI.
                -- Add future fields here instead of editing InventoryPanel logic.
                order = {
                    "hatcher_name",
                },
                labels = {
                    hatcher_name = "Hatched By",
                    obtained_at = "Obtained",
                },
                hidden = {
                    "_kind",
                    "ItemId",
                    "ObtainedAt",
                    "Variant",
                    "BasePower",
                    "EffectivePower",
                    "EternalBaselinePower",
                    "EternalPercent",
                    "source",
                    "grant_source",
                    "hatcher_user_id",
                    "hatched_by", -- raw UserId — shown via the resolved "Hatched By" line
                    "element", -- shown explicitly (correct biome element); hide the raw stored attr
                    "variant", -- already shown as "Variant" up top
                    "player_class", -- internal rebirth class (audit)
                    "enchantable",
                    "max_enchantments",
                    "unlocked_enchant_slots",
                    "huge",
                    "serial",
                    "serial_source",
                    "serial_key",
                    "locked",
                    "quantity",
                    "Quantity",
                    "rarity_id",
                    "rarity_override",
                    "eternal",
                    "eternal_percent",
                    "enchantments",
                    "stats",
                },
            },

            card_visuals = {
                ring_default = {
                    colors = {
                        Color3.fromRGB(115, 120, 130),
                        Color3.fromRGB(210, 215, 225),
                        Color3.fromRGB(115, 120, 130),
                    },
                    thickness = 2,
                    animated = false,
                    rotation_seconds = 5,
                },
                rarity_rings = {
                    common = {
                        colors = {
                            Color3.fromRGB(120, 124, 132),
                            Color3.fromRGB(215, 220, 228),
                            Color3.fromRGB(120, 124, 132),
                        },
                        thickness = 2,
                        animated = false,
                    },
                    uncommon = {
                        colors = {
                            Color3.fromRGB(42, 190, 92),
                            Color3.fromRGB(175, 255, 198),
                            Color3.fromRGB(42, 190, 92),
                        },
                        thickness = 2,
                        animated = false,
                    },
                    rare = {
                        colors = {
                            Color3.fromRGB(38, 128, 255),
                            Color3.fromRGB(178, 220, 255),
                            Color3.fromRGB(38, 128, 255),
                        },
                        thickness = 2,
                        animated = false,
                    },
                    epic = {
                        colors = {
                            Color3.fromRGB(150, 74, 255),
                            Color3.fromRGB(225, 190, 255),
                            Color3.fromRGB(150, 74, 255),
                        },
                        thickness = 2,
                        animated = true,
                        rotation_seconds = 4,
                    },
                    legendary = {
                        colors = {
                            Color3.fromRGB(255, 202, 56),
                            Color3.fromRGB(255, 248, 186),
                            Color3.fromRGB(255, 152, 32),
                            Color3.fromRGB(255, 202, 56),
                        },
                        thickness = 3,
                        animated = true,
                        rotation_seconds = 3.5,
                    },
                    mythic = {
                        colors = {
                            Color3.fromRGB(255, 45, 226),
                            Color3.fromRGB(100, 235, 255),
                            Color3.fromRGB(255, 45, 226),
                        },
                        thickness = 2,
                        animated = true,
                        rotation_seconds = 3.25,
                    },
                    secret = {
                        colors = {
                            Color3.fromRGB(255, 120, 35),
                            Color3.fromRGB(255, 245, 180),
                            Color3.fromRGB(255, 120, 35),
                        },
                        thickness = 3,
                        animated = true,
                        rotation_seconds = 2.75,
                    },
                    exclusive = {
                        colors = {
                            Color3.fromRGB(0, 216, 214),
                            Color3.fromRGB(195, 255, 250),
                            Color3.fromRGB(0, 128, 180),
                            Color3.fromRGB(0, 216, 214),
                        },
                        thickness = 3,
                        animated = true,
                        rotation_seconds = 2.5,
                    },
                    huge = {
                        colors = {
                            Color3.fromRGB(255, 69, 184),
                            Color3.fromRGB(110, 120, 255),
                            Color3.fromRGB(65, 235, 255),
                            Color3.fromRGB(255, 69, 184),
                        },
                        thickness = 3,
                        animated = true,
                        rotation_seconds = 2,
                    },
                },
                variant_rings = {
                    golden = {
                        colors = {
                            Color3.fromRGB(255, 196, 54),
                            Color3.fromRGB(255, 255, 214),
                            Color3.fromRGB(255, 165, 42),
                            Color3.fromRGB(178, 102, 18),
                            Color3.fromRGB(255, 236, 136),
                            Color3.fromRGB(255, 196, 54),
                        },
                        thickness = 2,
                        animated = true,
                        rotation_seconds = 2.35,
                    },
                    rainbow = {
                        colors = {
                            Color3.fromRGB(255, 55, 95),
                            Color3.fromRGB(255, 214, 64),
                            Color3.fromRGB(64, 235, 112),
                            Color3.fromRGB(58, 190, 255),
                            Color3.fromRGB(150, 92, 255),
                            Color3.fromRGB(255, 55, 180),
                            Color3.fromRGB(255, 55, 95),
                        },
                        thickness = 2,
                        animated = true,
                        rotation_seconds = 1.85,
                    },
                },
                variant_backgrounds = {
                    basic = {
                        colors = {
                            Color3.fromRGB(42, 43, 50),
                            Color3.fromRGB(28, 29, 36),
                        },
                        rotation = 45,
                    },
                    golden = {
                        colors = {
                            Color3.fromRGB(132, 88, 18),
                            Color3.fromRGB(76, 48, 16),
                            Color3.fromRGB(148, 94, 22),
                        },
                        rotation = 35,
                        animated = true,
                        rotation_seconds = 4.5,
                    },
                    rainbow = {
                        colors = {
                            Color3.fromRGB(72, 26, 78),
                            Color3.fromRGB(30, 68, 112),
                            Color3.fromRGB(30, 92, 74),
                            Color3.fromRGB(92, 72, 24),
                            Color3.fromRGB(72, 26, 78),
                        },
                        rotation = 30,
                        animated = true,
                        rotation_seconds = 4.5,
                    },
                },
            },
        },

        eggs = {
            display_name = "Eggs",
            icon = "🥚",
            -- UNIFIED STORAGE MODEL (Jason): every stackable bucket follows the pet
            -- Storage-v2 path — stacks (and every variation) are FREE, only UNIQUE
            -- items count toward base_limit (the shared 500 cap), and OpsAlert warns
            -- us at 80% of uniques. base_limit = the unique headroom (eggs have none
            -- today). stack_size = per-identity quantity bound (< 2^53).
            base_limit = 500,
            stack_size = 1000000000000,
            stacks_count_toward_limit = false,
            allow_duplicates = true,
            -- INVENTORY eggs (Meet-The-Creator etc.) — held items hatched on demand,
            -- unlike the world egg stations. Stackable by egg id.
            storage_type = "stackable",
            item_schema = {
                required = { "id", "obtained_at" },
                optional = { "name", "source" },
            },
            limit_extensions = {},
        },
        enhancements = {
            display_name = "Enhancements",
            icon = "⚙️",
            -- UNIFIED STORAGE MODEL (Jason): the SAME pet Storage-v2 path. Cogs stack
            -- by identity (type+origins+level); stacks are FREE (stacks_count_toward_limit
            -- = false) — only UNIQUE items would count toward base_limit (the shared 500
            -- cap; enhancements have no unique tier, so they're effectively unbounded).
            -- stack_size = per-identity quantity, a Lua double exact to 2^53 (~9.0e15).
            base_limit = 500,
            stack_size = 1000000000000, -- 1e12 per identity (< 2^53) = effectively unlimited
            stacks_count_toward_limit = false,
            allow_duplicates = true,
            -- STACKABLE (Jason: uid-per-drop = "save explosion... that's why we have
            -- stacks"). The stack id IS the identity: type|origins(ordered)|level —
            -- ring + interior colors preserved exactly (order matters: geo+pyro and
            -- pyro+geo are different art, different stacks).
            storage_type = "stackable",
            item_schema = {
                required = {
                    "id", -- always "enhancement"
                    "obtained_at", -- when picked up (validator skips it on add)
                },
                optional = {
                    "type", -- damage / accuracy / recharge / ...
                    "origins", -- { archetype } single or { a, b } dual
                    "name", -- resolved display name ("Pyro Damage")
                    "level", -- enhancement tier — drives both the card badge AND the slotted
                    -- effect strength. Was MISSING from optional, so AddItem dropped it and
                    -- origin cogs stored no level (card showed "Level: ?", effect ran at
                    -- default). The stackId still encodes it (_L#), so it's recoverable.
                    "origins_csv", -- folder-mirror friendly ordered origins ("geo,cryo")
                },
            },
            limit_extensions = {},
            -- SOFT storage telemetry — NOT a cap. Stacks are free + auto-expand, so the
            -- usual used/total uniques alarm is blind to stack growth. DataService measures
            -- this bucket's live stack count and estimated serialized size at load and fires
            -- OpsAlert("bucket_storage_high") when EITHER crosses, so devs can catch runaway
            -- growth before it risks the ~4MB DataStore key limit (replaces the dead
            -- enhancements inventory_cap=60). Tuned above live worst-case (Macros ~504 stacks
            -- / ~884 items) so it only fires on genuinely abnormal growth.
            storage_alert = {
                stack_count = 1500, -- distinct identity stacks (type|origins|level)
                serialized_bytes = 350000, -- ~350KB of this bucket's JSON (~9% of the 4MB key)
            },
        },
        potions = {
            display_name = "Potions",
            icon = "🧪",
            -- Same stackable model as enhancements: same potion id merges into ONE quantity stack
            -- (no save explosion), stacks are free (only uniques count toward the 500 cap; potions
            -- have no unique tier). Drink decrements the stack; trade-ready (the potions bucket).
            base_limit = 500,
            stack_size = 1000000000000,
            stacks_count_toward_limit = false,
            allow_duplicates = true,
            storage_type = "stackable",
            item_schema = {
                required = { "id" }, -- the potion id (e.g. "berserk_brew")
                optional = { "category", "name", "quantity", "obtained_at" },
            },
            limit_extensions = {},
        },
        consumables = {
            display_name = "Consumables",
            icon = "🧪",
            base_limit = 500, -- unified unique cap (consumables have no unique tier)
            stack_size = 99, -- per-stack quantity cap stays a gameplay knob (see validation)
            stacks_count_toward_limit = false, -- unified model: stacks free, uniques count
            allow_duplicates = false, -- Same items merge into stacks
            storage_type = "stackable", -- NEW: Indicates items are identical/countable

            -- Limit extensions via gamepasses
            limit_extensions = {
                {
                    gamepass_id = 555666777, -- TODO: Replace with actual gamepass ID
                    additional_slots = 50,
                    name = "Extra Storage",
                },
            },

            item_schema = {
                required = {
                    "id",
                    "quantity",
                    "obtained_at",
                },
                optional = {
                    "expires_at", -- For time-limited items
                },
            },

            validation = {
                max_quantity_per_stack = 99,
                min_quantity = 1,
            },
        },

        resources = {
            display_name = "Resources",
            icon = "🪨",
            base_limit = 500, -- unified unique cap (resources have no unique tier)
            stack_size = 10000, -- per-stack quantity cap stays a gameplay knob (see validation)
            stacks_count_toward_limit = false, -- unified model: stacks free, uniques count
            allow_duplicates = false, -- Same resources merge into stacks
            storage_type = "stackable", -- Identical items, store as counts

            item_schema = {
                required = {
                    "id", -- Resource type (wood, stone, iron, etc.)
                    "quantity", -- How many of this resource
                    "obtained_at", -- When first obtained
                },
                optional = {
                    "quality", -- Resource quality/grade
                    "source", -- Where it was obtained
                },
            },

            validation = {
                max_quantity_per_stack = 10000,
                min_quantity = 1,
            },
        },

        tools = {
            display_name = "Tools",
            icon = "🔧",
            base_limit = 25, -- 25 different tools
            stack_size = 1, -- Tools don't stack (each has durability)
            allow_duplicates = true, -- Can have multiple of same tool type
            storage_type = "unique", -- Each tool instance has unique properties

            item_schema = {
                required = {
                    "id", -- Tool type (pickaxe, sword, etc.)
                    "obtained_at", -- When first obtained
                },
                optional = {
                    "durability", -- Current durability
                    "max_durability", -- Maximum durability
                    "level", -- Tool level/tier
                    "enchantments", -- Tool enchantments/modifiers
                    "nickname", -- Custom name
                },
            },

            validation = {
                min_durability = 0,
                max_level = 100,
            },
        },
    },

    -- Equipped configuration
    equipped = {
        pets = {
            slots = 3, -- Base equipped pet slots
            max_slots = 10, -- Hard cap after perks/gamepasses/rewards (level progression -> 10)
            extra_slots_perk = "extra_pet_slots",
            display_name = "Active Pets",
            icon = "🐾",

            -- Slot extensions via gamepasses
            slot_extensions = {
                {
                    gamepass_id = 456789123, -- TODO: Replace with actual gamepass ID
                    additional_slots = 1,
                    name = "4th Pet Slot",
                },
                {
                    gamepass_id = 789123456, -- TODO: Replace with actual gamepass ID
                    additional_slots = 2,
                    name = "5th & 6th Pet Slots",
                },
            },
        },

        tools = {
            slots = 1, -- Number of equipped tool slots (active pickaxe)
            display_name = "Active Tool",
            icon = "🔧",

            -- Slot extensions via gamepasses (optional for premium players)
            slot_extensions = {
                {
                    gamepass_id = 987654321, -- TODO: Replace with actual gamepass ID
                    additional_slots = 1,
                    name = "2nd Tool Slot",
                },
            },
        },
    },

    -- General settings
    settings = {
        enable_trading = true,
        enable_item_locking = true, -- Prevent accidental deletion/trading
        enable_bulk_actions = true, -- Mass delete/organize
        auto_sort_enabled = true,
        default_sort_order = "rarity", -- rarity/level/newest/oldest

        -- UID generation settings
        uid_prefix_length = 8, -- Length of random suffix
        uid_include_timestamp = true,

        -- Debug settings (keep off; flip on locally when debugging inventory)
        debug_logging = false, -- Detailed inventory logging
        trace_operations = false, -- Trace every inventory operation
        validate_on_load = true, -- Validate inventory structure on player join
    },

    -- UI overrides for InventoryPanel
    ui = {
        -- Grid cell/card size and padding. Adjust these to resolve overlap or fit more per row.
        -- InventoryPanel.lua will fall back to 96x96 and 8x8 if these are not provided.
        card_size = Vector2.new(96, 96),
        card_padding = Vector2.new(8, 8),

        -- Where the delete-amount slider starts when you tap a stack in delete mode:
        -- "min" (1 — safest; a misclick won't pre-arm "delete the whole stack") or
        -- "max" (the entire stack). Default "min" per Jason. Falls back to "min".
        delete_picker_default = "min",
    },

    -- Grid ordering for InventoryPanel. `section_order` ranks the buckets within the
    -- "All" view (lower = earlier); per-category tabs hold one bucket so only the
    -- within-section rule applies. Buckets not listed sort after the listed ones.
    sorting = {
        -- Pets first (kept power-sorted), then enhancements (grouped, see below), then
        -- eggs (by name), then everything else. Reorder / add buckets (tools,
        -- consumables, resources) here without touching code.
        section_order = {
            pets = 0,
            enhancements = 1,
            eggs = 2,
        },
        -- Enhancement ordering within its section (Jason): naturals first, dual origins
        -- second, single origins third. Then grouped by origin PAIR (e.g. every
        -- pyromancer+sandwalker together), then by type (A–Z), then highest level first.
        enhancement_class_order = {
            natural = 0,
            dual = 1,
            single = 2,
        },
    },

    -- Default values for new items
    defaults = {
        pets = {
            level = 1,
            exp = 0,
            nickname = "",
            stats = {}, -- Will be filled from pet config
            enchantments = {},
            locked = false,
        },
        consumables = {
            quantity = 1,
        },
    },

    -- UI Display Categories Configuration
    -- These define what tabs appear in the inventory UI and what folders they show
    display_categories = {
        {
            name = "All",
            icon = "📦",
            description = "All items across all categories",
            folders = {
                "pets",
                "consumables",
                "tools",
                "eggs",
                "resources",
                "enhancements",
                "potions",
            }, -- All enabled buckets
            display_order = 1,
            always_visible = true, -- Show even if no items
        },
        {
            name = "Pets",
            icon = "🐾",
            description = "Your collected pets and companions",
            folders = { "pets" },
            display_order = 2,
            always_visible = true,
        },
        {
            name = "Enhancements",
            icon = "⚙️",
            description = "Power enhancements — slot them via Power Choice",
            folders = { "enhancements" },
            display_order = 3,
            always_visible = false,
        },
        {
            name = "Items",
            icon = "⚡",
            description = "Consumable items and potions",
            folders = { "consumables", "potions" }, -- consumables + brew-charge potions (always stacked, a handful of types)
            display_order = 3,
            always_visible = false, -- Hide if no items
        },
        {
            name = "Eggs",
            icon = "🥚",
            description = "Eggs ready to hatch",
            folders = { "eggs" },
            display_order = 4,
            always_visible = false,
        },
        {
            name = "Tools",
            icon = "🔧",
            description = "Tools and equipment",
            folders = { "tools", "weapons" }, -- Group tools and weapons together
            display_order = 5,
            always_visible = false,
        },
        {
            name = "Resources",
            icon = "🪨",
            description = "Collected materials and resources",
            folders = { "resources" },
            display_order = 6,
            always_visible = false,
        },
    },

    -- Category display settings
    category_settings = {
        max_visible_categories = 8, -- Don't overwhelm the UI
        hide_empty_categories = true, -- Hide categories with 0 items (unless always_visible)
        show_item_counts = true, -- Show "X items" next to category names
        -- For mixed pets: if true, each stack counts as 1 item; if false, counts use Quantity
        count_stacks_as_single = true,
        compact_mode = false, -- Use smaller category tabs

        -- Category icons can fallback to bucket icons if not specified
        use_bucket_icons_fallback = true,

        -- Custom category colors (optional)
        category_colors = {
            All = Color3.fromRGB(100, 100, 100), -- Gray
            Pets = Color3.fromRGB(255, 182, 193), -- Pink
            Items = Color3.fromRGB(135, 206, 250), -- Light Blue
            Eggs = Color3.fromRGB(255, 255, 224), -- Light Yellow
            Tools = Color3.fromRGB(210, 180, 140), -- Tan
            Resources = Color3.fromRGB(160, 82, 45), -- Brown
        },
    },
}
