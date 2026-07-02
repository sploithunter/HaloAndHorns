--[[
    Storage Types Demonstration
    
    This test shows the key distinction between:
    1. Stackable items (identical) - stored as quantities
    2. Unique items (individual) - stored as separate instances
    
    Demonstrates the "8 different bears" scenario you described.
]]

print(
    "🧪 ═══════════════════════════════════════════════════════════"
)
print("🧪 STORAGE TYPES DEMONSTRATION")
print("🧪 Stackable vs Unique Item Storage")
print(
    "🧪 ═══════════════════════════════════════════════════════════"
)

-- Simulate a player's inventory with both storage types
local playerInventory = {
    -- UNIQUE STORAGE: Pets (each bear is different)
    pets = {
        storage_type = "unique",
        base_limit = 50,
        total_slots = 50,
        used_slots = 8, -- 8 different bears = 8 slots
        items = {
            ["pet_1701234567_001"] = {
                id = "bear",
                variant = "golden",
                level = 10,
                exp = 1250,
                nickname = "Goldie",
                stats = { power = 95, health = 850, speed = 1.3 },
                enchantments = {
                    { type = "power_boost", tier = 2, value = 15 },
                },
                obtained_at = 1701234567,
            },
            ["pet_1701234568_002"] = {
                id = "bear",
                variant = "basic",
                level = 5,
                exp = 320,
                nickname = "Bruno",
                stats = { power = 65, health = 720, speed = 1.1 },
                enchantments = {},
                obtained_at = 1701234568,
            },
            ["pet_1701234569_003"] = {
                id = "bear",
                variant = "rainbow",
                level = 15,
                exp = 2800,
                nickname = "Sparkles",
                stats = { power = 180, health = 1200, speed = 1.8 },
                enchantments = {
                    { type = "rainbow_boost", tier = 3, value = 25 },
                    { type = "speed_boost", tier = 1, value = 8 },
                },
                obtained_at = 1701234569,
            },
            ["pet_1701234570_004"] = {
                id = "bear",
                variant = "basic",
                level = 1,
                exp = 0,
                nickname = "", -- No nickname yet
                stats = { power = 50, health = 600, speed = 1.0 },
                enchantments = {},
                obtained_at = 1701234570,
            },
            ["pet_1701234571_005"] = {
                id = "bear",
                variant = "golden",
                level = 7,
                exp = 680,
                nickname = "Honey",
                stats = { power = 78, health = 780, speed = 1.2 },
                enchantments = {
                    { type = "luck_boost", tier = 1, value = 5 },
                },
                obtained_at = 1701234571,
            },
            ["pet_1701234572_006"] = {
                id = "bear",
                variant = "basic",
                level = 3,
                exp = 150,
                nickname = "Teddy",
                stats = { power = 58, health = 650, speed = 1.05 },
                enchantments = {},
                obtained_at = 1701234572,
            },
            ["pet_1701234573_007"] = {
                id = "bear",
                variant = "shadow",
                level = 12,
                exp = 1850,
                nickname = "Midnight",
                stats = { power = 145, health = 950, speed = 1.6 },
                enchantments = {
                    { type = "shadow_boost", tier = 2, value = 20 },
                },
                obtained_at = 1701234573,
            },
            ["pet_1701234574_008"] = {
                id = "bear",
                variant = "golden",
                level = 8,
                exp = 920,
                nickname = "Blaze",
                stats = { power = 85, health = 800, speed = 1.25 },
                enchantments = {
                    { type = "fire_boost", tier = 1, value = 10 },
                },
                obtained_at = 1701234574,
            },
        },
    },

    -- STACKABLE STORAGE: Consumables (identical items)
    consumables = {
        storage_type = "stackable",
        base_limit = 100,
        total_slots = 100,
        used_slots = 4, -- 4 different potion types = 4 slots (regardless of quantities)
        items = {
            ["health_potion"] = {
                id = "health_potion",
                quantity = 47, -- 47 identical health potions
                obtained_at = 1701234500,
            },
            ["speed_potion"] = {
                id = "speed_potion",
                quantity = 23, -- 23 identical speed potions
                obtained_at = 1701234501,
            },
            ["luck_potion"] = {
                id = "luck_potion",
                quantity = 12, -- 12 identical luck potions
                obtained_at = 1701234502,
            },
            ["power_potion"] = {
                id = "power_potion",
                quantity = 8, -- 8 identical power potions
                obtained_at = 1701234503,
            },
        },
    },

    -- STACKABLE STORAGE: Resources (identical materials)
    resources = {
        storage_type = "stackable",
        base_limit = 50,
        total_slots = 50,
        used_slots = 5, -- 5 different resource types = 5 slots
        items = {
            ["wood"] = {
                id = "wood",
                quantity = 1250, -- 1250 identical wood pieces
                obtained_at = 1701234400,
            },
            ["stone"] = {
                id = "stone",
                quantity = 800, -- 800 identical stones
                obtained_at = 1701234401,
            },
            ["iron"] = {
                id = "iron",
                quantity = 150, -- 150 identical iron ingots
                obtained_at = 1701234402,
            },
            ["gold"] = {
                id = "gold",
                quantity = 45, -- 45 identical gold pieces
                obtained_at = 1701234403,
            },
            ["diamond"] = {
                id = "diamond",
                quantity = 8, -- 8 identical diamonds
                obtained_at = 1701234404,
            },
        },
    },
}

print("\n🐻 UNIQUE STORAGE EXAMPLE: Pet Bears")
print("📊 Total bears: 8 | Slots used: 8 (each bear takes 1 slot)")
print("🎯 Key point: All bears are same TYPE but have unique properties")

for uid, bear in pairs(playerInventory.pets.items) do
    local enchantCount = #bear.enchantments
    print(string.format(
        "  • %s (%s) - Level %d, Power %d, %d enchants - '%s'",
        bear.variant:upper(),
        uid:sub(-3), -- Last 3 chars of UID
        bear.level,
        bear.stats.power,
        enchantCount,
        bear.nickname ~= "" and bear.nickname or "No nickname"
    ))
end

print("\n🧪 STACKABLE STORAGE EXAMPLE: Consumables")
print("📊 Total potion items: 90 | Slots used: 4 (each type takes 1 slot)")
print("🎯 Key point: All potions of same type are identical")

for itemId, item in pairs(playerInventory.consumables.items) do
    print(
        string.format(
            "  • %s: %d potions (all identical)",
            item.id:gsub("_", " "):upper(),
            item.quantity
        )
    )
end

print("\n🪨 STACKABLE STORAGE EXAMPLE: Resources")
print("📊 Total resource items: 2,253 | Slots used: 5 (each type takes 1 slot)")
print("🎯 Key point: Massive quantities don't consume extra slots")

for itemId, item in pairs(playerInventory.resources.items) do
    print(string.format("  • %s: %d pieces (all identical)", item.id:upper(), item.quantity))
end

print("\n📈 STORAGE EFFICIENCY COMPARISON:")
print(
    "┌─────────────────┬──────────────┬──────────────┬─────────────────┐"
)
print("│ Storage Type    │ Total Items  │ Slots Used   │ Efficiency      │")
print(
    "├─────────────────┼──────────────┼──────────────┼─────────────────┤"
)
print("│ Unique (Bears)  │      8       │      8       │ 1 item/slot     │")
print("│ Stack (Potions) │     90       │      4       │ 22.5 items/slot │")
print("│ Stack (Resources)│   2,253      │      5       │ 450.6 items/slot│")
print(
    "└─────────────────┴──────────────┴──────────────┴─────────────────┘"
)

print("\n🎮 GAMEPLAY IMPLICATIONS:")

print("\n🐻 BEARS (Unique Storage):")
print("  ✅ Each bear can have unique level, experience, enchantments")
print("  ✅ Players can nickname individual bears")
print("  ✅ Different variants (basic, golden, rainbow, shadow)")
print("  ✅ Individual stat progression and customization")
print("  ⚠️  Each bear consumes 1 inventory slot")

print("\n🧪 POTIONS (Stackable Storage):")
print("  ✅ Efficient storage: 90 potions only use 4 slots")
print("  ✅ Simple quantity management")
print("  ✅ Easy to add/remove from stacks")
print("  ❌ All potions of same type are identical (no uniqueness)")

print("\n💡 DESIGN DECISION GUIDE:")
print("  🔹 Use UNIQUE storage when:")
print("    - Items need individual progression (levels, experience)")
print("    - Players can customize items (nicknames, enchantments)")
print("    - Each item has unique properties or stats")
print("    - Complex gameplay mechanics per item")
print("")
print("  🔹 Use STACKABLE storage when:")
print("    - All items of same type are functionally identical")
print("    - Large quantities are expected")
print("    - Simple add/remove mechanics")
print("    - Storage efficiency is important")

print("\n🛡️ SAFETY NOTE:")
print("Both storage types follow the same bucket preservation rules:")
print("  ✅ Buckets never deleted from profiles")
print("  ✅ Data preserved during format migrations")
print("  ✅ Configuration changes only add, never remove")

print("\n🎉 STORAGE TYPES DEMONSTRATION COMPLETE!")
print("This system gives you the best of both worlds:")
print("  • Efficiency for simple items (potions, resources)")
print("  • Flexibility for complex items (pets, equipment)")

return true
