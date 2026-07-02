-- Manual Inventory Cleanup Script
-- Use this in Studio Command Bar for immediate ProfileStore cleanup
-- Run as: dofile("scripts/manual_inventory_cleanup.lua")

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

-- Get the target player (change this to the player you want to clean)
local targetPlayer = Players.coloradoplays -- Change this username as needed
if not targetPlayer then
    error("Player not found! Update the username in the script.")
end

-- Get DataService (adjust path if needed)
local dataServicePath = ServerScriptService.Server.Services.DataService
local DataService = require(dataServicePath)

print("🧹 Starting inventory cleanup for player:", targetPlayer.Name)

-- Function to clean up ProfileStore inventory
local function cleanupInventory(player)
    local profile = DataService:GetProfile(player)
    if not profile then
        error("❌ Could not get profile for player: " .. player.Name)
    end

    print("📊 Current inventory state:")
    for bucket, data in pairs(profile.Data.Inventory or {}) do
        if data.items then
            local itemCount = 0
            for _ in pairs(data.items) do
                itemCount = itemCount + 1
            end
            print("  " .. bucket .. ": " .. itemCount .. " items")
        end
    end

    -- Option 1: Clear specific bucket (e.g., consumables with miscategorized items)
    print("🗑️ Clearing consumables bucket...")
    if profile.Data.Inventory.consumables then
        profile.Data.Inventory.consumables.items = {}
        profile.Data.Inventory.consumables.used_slots = 0
        print("✅ Consumables bucket cleared")
    end

    -- Option 2: Clear all misplaced tools from consumables
    -- (Uncomment if you want to be more selective)
    --[[
    if profile.Data.Inventory.consumables and profile.Data.Inventory.consumables.items then
        local toDelete = {}
        for uid, item in pairs(profile.Data.Inventory.consumables.items) do
            if item.id and (item.id:find("pickaxe") or item.id:find("sword") or item.id:find("tool")) then
                table.insert(toDelete, uid)
            end
        end
        
        for _, uid in ipairs(toDelete) do
            profile.Data.Inventory.consumables.items[uid] = nil
            print("🔧 Removed misplaced tool:", uid)
        end
        
        -- Recalculate used slots
        local newCount = 0
        for _ in pairs(profile.Data.Inventory.consumables.items) do
            newCount = newCount + 1
        end
        profile.Data.Inventory.consumables.used_slots = newCount
    end
    --]]

    -- Force save the profile
    profile:Save()
    print("💾 Profile saved successfully!")

    print("📊 Updated inventory state:")
    for bucket, data in pairs(profile.Data.Inventory or {}) do
        if data.items then
            local itemCount = 0
            for _ in pairs(data.items) do
                itemCount = itemCount + 1
            end
            print("  " .. bucket .. ": " .. itemCount .. " items")
        end
    end
end

-- Execute the cleanup
local success, error = pcall(function()
    cleanupInventory(targetPlayer)
end)

if success then
    print("✅ CLEANUP COMPLETED SUCCESSFULLY!")
    print("🔄 The player should reconnect or wait for next data refresh to see changes.")
else
    print("❌ CLEANUP FAILED:", error)
end
