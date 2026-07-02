--[[
    Manual Test Orphaned Buckets Script
    
    This script creates orphaned bucket folders for testing the cleanup functionality.
    It works by creating folder structures directly instead of trying to access ProfileStore.
    
    USAGE:
    1. Copy this script content to Studio Command Bar (Server side)
    2. Execute to create test orphaned buckets
    3. Test admin cleanup: Admin Panel → "🗑️ Remove Orphaned Buckets"
    4. Verify only orphaned buckets are removed, valid ones preserved
    
    Expected behavior:
    - Creates: health_potion, speed_potion, test_legacy folders
    - Admin cleanup should remove these orphaned folders
    - Should preserve: pets, consumables, resources (valid buckets)
]]

-- Simple manual bucket creation
local Players = game:GetService("Players")
local player = Players.coloradoplays

-- Wait for data to be loaded
repeat
    wait()
until player:FindFirstChild("Inventory")

-- Get the existing profile through the folders
local inventoryFolder = player.Inventory

-- Create simple orphaned bucket folders manually
local healthPotionFolder = Instance.new("Folder")
healthPotionFolder.Name = "health_potion"
healthPotionFolder.Parent = inventoryFolder

local speedPotionFolder = Instance.new("Folder")
speedPotionFolder.Name = "speed_potion"
speedPotionFolder.Parent = inventoryFolder

local testFolder = Instance.new("Folder")
testFolder.Name = "test_legacy"
testFolder.Parent = inventoryFolder

-- Optional: Add some items to make it more realistic
local function addTestItem(folder, itemName, count)
    local itemFolder = Instance.new("Folder")
    itemFolder.Name = itemName
    itemFolder.Parent = folder

    local countValue = Instance.new("IntValue")
    countValue.Name = "count"
    countValue.Value = count or 1
    countValue.Parent = itemFolder
end

-- Add some test items to the orphaned buckets
addTestItem(healthPotionFolder, "health_potion_001", 15)
addTestItem(speedPotionFolder, "speed_potion_001", 8)
addTestItem(testFolder, "test_item_001", 5)

print("✅ Created 3 orphaned bucket folders with test items:")
print("  - health_potion (15 items)")
print("  - speed_potion (8 items)")
print("  - test_legacy (5 items)")
print("")
print("🎯 Now test admin cleanup!")
print("   Admin Panel → Inventory Management → '🗑️ Remove Orphaned Buckets'")
print("")
print("Expected result:")
print("  ✅ Remove: health_potion, speed_potion, test_legacy")
print("  ✅ Preserve: pets, consumables, resources")
