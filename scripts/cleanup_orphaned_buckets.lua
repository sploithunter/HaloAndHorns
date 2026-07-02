--[[
    Orphaned Bucket Cleanup Script
    
    This script cleans up development/test buckets that are no longer configured
    but still exist in player ProfileStore data.
    
    USAGE:
    1. Paste this script in Studio Command Bar
    2. Review the buckets to be deleted (they'll be listed)
    3. Uncomment the actual deletion lines when ready
    4. Run the script
    
    SAFETY:
    - Script lists what will be deleted before doing anything
    - Actual deletion is commented out by default
    - Only cleans specific known orphaned buckets
    - Does NOT touch active/configured buckets
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Load required services
local ProfileStore = require(game.ServerStorage.ProfileStore)
local DataService = require(game.ServerScriptService.Server.Services.DataService)

-- Known orphaned buckets to clean up
local ORPHANED_BUCKETS = {
    "alamantic_aluminum", -- Development test bucket
    "health_potion", -- Old potion system
    "speed_potion", -- Old potion system
}

-- Additional buckets that might be orphaned (review these)
local REVIEW_BUCKETS = {
    "test_item",
    "debug_tool",
    "placeholder_item",
    "temp_bucket",
}

print("🧹 ORPHANED BUCKET CLEANUP SCRIPT")
print("==================================")

-- Function to clean a player's orphaned buckets
local function cleanupPlayerOrphanedBuckets(player)
    print("\n👤 CLEANING PLAYER:", player.Name)

    -- Get player's ProfileStore profile
    local profile = DataService:GetProfile(player)
    if not profile then
        print("❌ No profile found for", player.Name)
        return
    end

    local cleaned = false
    local bucketsCleaned = {}

    -- Check inventory data
    if profile.Data and profile.Data.inventory then
        print(
            "📦 Current inventory buckets:",
            table.concat(getTableKeys(profile.Data.inventory), ", ")
        )

        -- Clean known orphaned buckets
        for _, bucketName in ipairs(ORPHANED_BUCKETS) do
            if profile.Data.inventory[bucketName] then
                local itemCount = 0
                if type(profile.Data.inventory[bucketName]) == "table" then
                    for _ in pairs(profile.Data.inventory[bucketName]) do
                        itemCount = itemCount + 1
                    end
                end

                print("🗑️ FOUND ORPHANED BUCKET:", bucketName, "with", itemCount, "items")
                table.insert(bucketsCleaned, bucketName .. " (" .. itemCount .. " items)")

                -- 🚨 UNCOMMENT THE NEXT LINE TO ACTUALLY DELETE
                -- profile.Data.inventory[bucketName] = nil

                cleaned = true
            end
        end

        -- List buckets for review
        for _, bucketName in ipairs(REVIEW_BUCKETS) do
            if profile.Data.inventory[bucketName] then
                local itemCount = 0
                if type(profile.Data.inventory[bucketName]) == "table" then
                    for _ in pairs(profile.Data.inventory[bucketName]) do
                        itemCount = itemCount + 1
                    end
                end
                print(
                    "❓ REVIEW BUCKET:",
                    bucketName,
                    "with",
                    itemCount,
                    "items (manual review needed)"
                )
            end
        end
    end

    if cleaned then
        print("✅ WOULD CLEAN:", table.concat(bucketsCleaned, ", "))
        print("🚨 TO ACTUALLY DELETE: Uncomment the deletion line in the script")
    else
        print("✅ No orphaned buckets found for", player.Name)
    end
end

-- Function to get table keys
function getTableKeys(t)
    local keys = {}
    for key in pairs(t) do
        table.insert(keys, key)
    end
    return keys
end

-- Clean up all current players
print("🎯 SCANNING ALL PLAYERS...")
for _, player in pairs(Players:GetPlayers()) do
    cleanupPlayerOrphanedBuckets(player)
end

print("\n" .. string.rep("=", 50))
print("🔍 CLEANUP SUMMARY")
print("Orphaned buckets targeted:", table.concat(ORPHANED_BUCKETS, ", "))
print("Review buckets listed:", table.concat(REVIEW_BUCKETS, ", "))
print("\n🚨 IMPORTANT: This script is in SAFE MODE")
print("   To actually delete data, uncomment the deletion line")
print("   Look for: -- profile.Data.inventory[bucketName] = nil")
print("✅ Script completed safely")
