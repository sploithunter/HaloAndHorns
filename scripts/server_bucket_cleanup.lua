-- server_bucket_cleanup.lua
-- Clean orphaned buckets from server-side ProfileStore data
-- Run this in Studio Server Command Bar

print("🚨 SERVER-SIDE BUCKET CLEANUP")
print("==============================")

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Get player
local targetPlayer = Players:FindFirstChild("coloradoplays")
if not targetPlayer then
    error("Player not found")
end

-- Get DataService
local ModuleLoader = require(game.ServerScriptService.Server.Utils.ModuleLoader)
local dataService = ModuleLoader:GetModule("DataService")

if not dataService then
    error("DataService not found")
end

-- Check if data is loaded
if not dataService:IsDataLoaded(targetPlayer) then
    error("Player data not loaded")
end

-- Get profile
local profile = dataService:GetProfile(targetPlayer)
if not profile or not profile.Data then
    error("Could not access player profile")
end

local inventoryData = profile.Data.Inventory
if not inventoryData then
    print("No inventory data found")
    return
end

-- List orphaned buckets to delete
local orphanedBuckets = {
    "health_potion",
    "speed_potion",
    "test_item",
    "premium_boost",
    "trader_scroll",
    "alamantic_aluminum",
}

print("🗑️ Deleting orphaned buckets...")

for _, bucketName in ipairs(orphanedBuckets) do
    if inventoryData[bucketName] then
        print("   Removing: " .. bucketName)
        inventoryData[bucketName] = nil
    end
end

-- Force save
profile:Save()

print("✅ Server-side cleanup complete!")
print("🔄 Restart server to see changes")
