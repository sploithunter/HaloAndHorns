--[[
    Create Test Orphaned Buckets Script
    
    This script creates various types of orphaned buckets to test the cleanup functionality:
    1. Old development buckets that aren't in the config anymore
    2. Mishandled items (like health_potion directly in inventory instead of consumables)
    3. Legacy test buckets
    
    USAGE: Run in Studio Command Bar to create test orphaned data
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Get your player
local player = Players:FindFirstChild("coloradoplays") or Players.LocalPlayer

if not player then
    print("❌ Player not found")
    return
end

print("🧪 CREATING TEST ORPHANED BUCKETS FOR:", player.Name)

-- Load required services
local DataService = require(game.ServerScriptService.Server.Services.DataService)

-- Get player's profile
local profile = DataService:GetProfile(player)
if not profile then
    print("❌ No profile found")
    return
end

if not profile.Data.Inventory then
    print("❌ No inventory data found")
    return
end

print("📦 Current buckets BEFORE:", table.concat(getTableKeys(profile.Data.Inventory), ", "))

-- === CREATE ORPHANED BUCKETS ===

-- 1. OLD DEVELOPMENT BUCKET (legacy test bucket)
profile.Data.Inventory.test_legacy_bucket = {
    items = {
        ["test_item_001"] = {
            id = "test_item",
            name = "Legacy Test Item",
            count = 5,
            created_at = tick(),
        },
        ["debug_tool_001"] = {
            id = "debug_tool",
            name = "Debug Tool",
            count = 1,
            created_at = tick(),
        },
    },
    total_slots = 50,
    used_slots = 2,
}
print("✅ Created: test_legacy_bucket (2 items)")

-- 2. MISHANDLED HEALTH POTIONS (should be in consumables, not direct inventory)
profile.Data.Inventory.health_potion = {
    items = {
        ["health_potion_001"] = {
            id = "health_potion",
            name = "Health Potion",
            count = 15,
            created_at = tick(),
        },
    },
    total_slots = 100,
    used_slots = 1,
}
print("✅ Created: health_potion bucket (should be in consumables - mishandled)")

-- 3. OLD SPEED POTION BUCKET (legacy from before consumables system)
profile.Data.Inventory.speed_potion = {
    items = {
        ["speed_potion_001"] = {
            id = "speed_potion",
            name = "Speed Potion",
            count = 8,
            created_at = tick(),
        },
        ["speed_potion_002"] = {
            id = "speed_potion",
            name = "Speed Potion",
            count = 12,
            created_at = tick(),
        },
    },
    total_slots = 100,
    used_slots = 2,
}
print("✅ Created: speed_potion bucket (legacy system - 20 total potions)")

-- 4. PREMIUM BOOSTS (old monetization system)
profile.Data.Inventory.premium_boosts = {
    items = {
        ["premium_boost_001"] = {
            id = "premium_boost",
            name = "Premium XP Boost",
            duration = 3600, -- 1 hour
            multiplier = 2.0,
            count = 3,
            created_at = tick(),
        },
    },
    total_slots = 20,
    used_slots = 1,
}
print("✅ Created: premium_boosts bucket (old monetization system)")

-- 5. ALAMANTIC ALUMINUM (typo in early development)
profile.Data.Inventory.alamantic_aluminum = {
    items = {
        ["alamantic_aluminum_001"] = {
            id = "alamantic_aluminum",
            name = "Alamantic Aluminum", -- Should be "Atlantic Aluminum"
            rarity = "legendary",
            count = 50,
            created_at = tick(),
        },
    },
    total_slots = 200,
    used_slots = 1,
}
print("✅ Created: alamantic_aluminum bucket (typo in development)")

-- 6. TRADER SCROLLS (removed feature)
profile.Data.Inventory.trader_scrolls = {
    items = {
        ["trader_scroll_001"] = {
            id = "trader_scroll",
            name = "Merchant Summon Scroll",
            uses_remaining = 5,
            count = 2,
            created_at = tick(),
        },
    },
    total_slots = 10,
    used_slots = 1,
}
print("✅ Created: trader_scrolls bucket (removed trading feature)")

print("\n📦 Current buckets AFTER:", table.concat(getTableKeys(profile.Data.Inventory), ", "))

-- Update the inventory folders to show these new orphaned buckets
local InventoryService = require(game.ServerScriptService.Server.Services.InventoryService)
if InventoryService then
    -- Recreate folders to include the orphaned buckets
    if InventoryService._playerInventoryFolders[player] then
        InventoryService._playerInventoryFolders[player]:Destroy()
    end
    if InventoryService._playerEquippedFolders[player] then
        InventoryService._playerEquippedFolders[player]:Destroy()
    end

    InventoryService._playerInventoryFolders[player] = nil
    InventoryService._playerEquippedFolders[player] = nil
    InventoryService:_createInventoryFolders(player)

    print("🔄 Inventory folders recreated to show orphaned buckets")
end

print("\n🎯 TEST ORPHANED BUCKETS CREATED!")
print("Expected to be cleaned up:")
print("  - test_legacy_bucket")
print("  - health_potion (mishandled)")
print("  - speed_potion (legacy)")
print("  - premium_boosts (old system)")
print("  - alamantic_aluminum (typo)")
print("  - trader_scrolls (removed feature)")
print("\nExpected to be preserved:")
print("  - pets (in config)")
print("  - consumables (in config)")
print("  - resources (in config)")

function getTableKeys(t)
    local keys = {}
    for key in pairs(t) do
        table.insert(keys, key)
    end
    return keys
end

print("\n✅ Ready to test admin cleanup command!")
