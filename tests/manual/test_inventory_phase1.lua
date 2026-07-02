--[[
    Manual Test for Inventory System Phase 1
    
    This script tests that:
    1. Inventory configuration loads properly
    2. ProfileTemplate is generated with correct inventory structure
    3. New player profiles get the expected inventory buckets
    
    Run this in Studio after connecting to Rojo:
    1. Place this script in ServerScriptService
    2. Run the server
    3. Check output for trace logs
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Wait for Shared to be available
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Locations = require(Shared.Locations)

-- Get services
local ConfigLoader = require(Locations.ConfigLoader)
local DataService = Locations.getService("DataService")

print("🧪 PHASE 1 TEST - Starting inventory system phase 1 tests")

-- Test 1: Verify inventory configuration loads
print("\n📋 TEST 1: Loading inventory configuration")
local success, inventoryConfig = pcall(function()
    return ConfigLoader:LoadConfig("inventory")
end)

if success then
    print("✅ TEST 1 PASSED - Inventory configuration loaded successfully")
    print("📦 Inventory config summary:", {
        version = inventoryConfig.version,
        enabledBuckets = inventoryConfig.enabled_buckets,
        bucketCount = 0,
    })

    -- Count enabled buckets
    local bucketCount = 0
    for bucketName, enabled in pairs(inventoryConfig.enabled_buckets) do
        if enabled then
            bucketCount = bucketCount + 1
            print(
                string.format(
                    "  ✓ Bucket '%s' enabled with %d base slots",
                    bucketName,
                    inventoryConfig.buckets[bucketName].base_limit
                )
            )
        end
    end
    print(string.format("📊 Total enabled buckets: %d", bucketCount))
else
    print("❌ TEST 1 FAILED - Failed to load inventory configuration:", inventoryConfig)
    return
end

-- Test 2: Verify DataService initialization (should generate ProfileTemplate with inventory buckets)
print("\n📋 TEST 2: DataService inventory template generation")
-- The template generation happens during DataService:Init(), so we just need to wait for a player

-- Test 3: Monitor for player joins and check their profile structure
print("\n📋 TEST 3: Waiting for player to join to test profile structure...")

Players.PlayerAdded:Connect(function(player)
    print(
        string.format("\n👤 PLAYER JOINED: %s - Testing inventory profile structure", player.Name)
    )

    -- Wait a moment for profile to load
    task.wait(2)

    -- Get the player's profile
    local profile = DataService:GetProfile(player)
    if not profile then
        print("❌ TEST 3 FAILED - No profile found for player:", player.Name)
        return
    end

    local data = profile.Data

    -- Test inventory structure
    print("📦 INVENTORY STRUCTURE TEST:")
    if data.Inventory then
        print("✅ Inventory section exists")

        for bucketName, enabled in pairs(inventoryConfig.enabled_buckets) do
            if enabled then
                if data.Inventory[bucketName] then
                    local bucket = data.Inventory[bucketName]
                    print(
                        string.format(
                            "✅ Bucket '%s' exists: %d/%d slots",
                            bucketName,
                            bucket.used_slots,
                            bucket.total_slots
                        )
                    )

                    -- Verify bucket structure
                    if bucket.items and bucket.total_slots and bucket.used_slots ~= nil then
                        print(string.format("  ✓ Bucket '%s' has correct structure", bucketName))
                    else
                        print(
                            string.format("  ❌ Bucket '%s' missing required fields", bucketName)
                        )
                    end
                else
                    print(
                        string.format("❌ Expected bucket '%s' not found in profile", bucketName)
                    )
                end
            end
        end
    else
        print("❌ TEST 3 FAILED - No Inventory section in profile")
    end

    -- Test equipped structure
    print("\n⚔️ EQUIPPED STRUCTURE TEST:")
    if data.Equipped then
        print("✅ Equipped section exists")

        for equipCategory, equipConfig in pairs(inventoryConfig.equipped or {}) do
            if data.Equipped[equipCategory] then
                local equippedSlots = data.Equipped[equipCategory]
                local slotCount = 0
                for _ in pairs(equippedSlots) do
                    slotCount = slotCount + 1
                end

                print(
                    string.format(
                        "✅ Equipped category '%s' exists with %d slots",
                        equipCategory,
                        slotCount
                    )
                )
            else
                print(string.format("❌ Expected equipped category '%s' not found", equipCategory))
            end
        end
    else
        print("❌ TEST 3 FAILED - No Equipped section in profile")
    end

    print(string.format("\n🎉 PHASE 1 TESTING COMPLETE for player: %s", player.Name))
    print("📊 Next step: Implement InventoryService and test pet hatching integration")
end)

print("✅ PHASE 1 TEST SETUP COMPLETE - Join the game to see profile structure tests")
