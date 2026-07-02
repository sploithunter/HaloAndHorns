--[[
    Admin Profile Cleanup - Clean up your own development buckets
    
    Quick cleanup script for admin to remove orphaned buckets from their own profile.
    
    USAGE: Paste in Studio Command Bar and run
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Get your player (change this if needed)
local adminPlayer = Players:FindFirstChild("coloradoplays") or Players.LocalPlayer

if not adminPlayer then
    print("❌ Admin player not found")
    return
end

print("🧹 CLEANING ADMIN PROFILE:", adminPlayer.Name)

-- Load DataService
local DataService = require(game.ServerScriptService.Server.Services.DataService)

-- Get your profile
local profile = DataService:GetProfile(adminPlayer)
if not profile then
    print("❌ No profile found")
    return
end

if not profile.Data or not profile.Data.Inventory then
    print("❌ No inventory data found")
    return
end

print("📦 Current buckets:", table.concat(getTableKeys(profile.Data.Inventory), ", "))

-- Get buckets that SHOULD exist from config
local ConfigLoader = require(game.ReplicatedStorage.Shared.ConfigLoader)
local inventoryConfig = ConfigLoader:LoadConfig("inventory")
local validBuckets = {}
for _, bucketConfig in ipairs(inventoryConfig.enabled_buckets or {}) do
    validBuckets[bucketConfig.name] = true
end

print("📋 Valid buckets from config:", table.concat(getTableKeys(validBuckets), ", "))

-- Remove everything that is NOT supposed to be there
local cleaned = {}
for bucketName, bucketData in pairs(profile.Data.Inventory) do
    if not validBuckets[bucketName] then
        local itemCount = 0
        if type(bucketData) == "table" and bucketData.items then
            for _ in pairs(bucketData.items) do
                itemCount = itemCount + 1
            end
        end

        print("🗑️ REMOVING INVALID BUCKET:", bucketName, "(" .. itemCount .. " items)")
        profile.Data.Inventory[bucketName] = nil -- 🚨 ACTUAL DELETION
        table.insert(cleaned, bucketName)
    end
end

if #cleaned > 0 then
    print("✅ CLEANED BUCKETS:", table.concat(cleaned, ", "))
    print("💾 Profile will be saved automatically")

    -- Force update the inventory folders
    local InventoryService = require(game.ServerScriptService.Server.Services.InventoryService)
    if InventoryService and InventoryService._updateBucketFolders then
        InventoryService:_updateBucketFolders(adminPlayer)
        print("🔄 Inventory folders updated")
    end
else
    print("✅ No orphaned buckets found to clean")
end

function getTableKeys(t)
    local keys = {}
    for key in pairs(t) do
        table.insert(keys, key)
    end
    return keys
end

print("🎉 Admin cleanup completed!")
