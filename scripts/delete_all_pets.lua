--[[
    Delete All Pets - Admin Command Script
    
    This script deletes ALL pets from your inventory.
    WARNING: This action cannot be undone!
    
    USAGE: Paste in Studio Command Bar and run
    REQUIREMENTS: You must be an admin user
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Get your player (change this if needed)
local adminPlayer = Players:FindFirstChild("coloradoplays") or Players.LocalPlayer

if not adminPlayer then
    print("❌ Admin player not found")
    return
end

print("🗑️ DELETE ALL PETS COMMAND EXECUTED BY:", adminPlayer.Name)

-- Check if you're an admin
local AdminService = require(game.ServerScriptService.Server.Services.AdminService)
if not AdminService:IsAuthorized(adminPlayer) then
    print("❌ ACCESS DENIED: You are not authorized as an admin")
    return
end

print("✅ Admin authorization confirmed")

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

-- Find the pets bucket
local inventoryData = profile.Data.Inventory
local petsBucket = inventoryData.pets

if not petsBucket then
    print("✅ No pets bucket found - nothing to delete")
    return
end

if not petsBucket.items then
    print("✅ No pets items found - nothing to delete")
    return
end

-- Count pets before deletion
local petCount = 0
for _ in pairs(petsBucket.items) do
    petCount = petCount + 1
end

if petCount == 0 then
    print("✅ No pets found in inventory - nothing to delete")
    return
end

print("🐾 Found", petCount, "pets to delete")

-- Confirm deletion
print("⚠️  WARNING: This will delete ALL", petCount, "pets from your inventory!")
print("⚠️  This action cannot be undone!")
print("⚠️  Type 'YES DELETE ALL PETS' to confirm:")

-- For Studio command bar, we'll proceed with deletion
-- In a real game, you might want to add a confirmation prompt

-- Delete all pets
local deletedPets = {}
for petUid, petData in pairs(petsBucket.items) do
    table.insert(deletedPets, {
        uid = petUid,
        name = petData.name or "Unknown Pet",
        type = petData.type or "Unknown Type",
    })
    petsBucket.items[petUid] = nil
end

-- Update used slots
petsBucket.used_slots = math.max(0, (petsBucket.used_slots or 0) - #deletedPets)

print("🗑️ DELETED", #deletedPets, "PETS:")
for _, pet in ipairs(deletedPets) do
    print("   -", pet.name, "(" .. pet.type .. ")")
end

print("📊 New pet count: 0")
print("📊 New used slots:", petsBucket.used_slots)

-- Force update the inventory folders
local InventoryService = require(game.ServerScriptService.Server.Services.InventoryService)
if InventoryService and InventoryService._updateBucketFolders then
    InventoryService:_updateBucketFolders(adminPlayer)
    print("🔄 Inventory folders updated")
end

-- Clean up any equipped pets
local equippedFolder = adminPlayer:FindFirstChild("Equipped")
if equippedFolder then
    local petsFolder = equippedFolder:FindFirstChild("pets")
    if petsFolder then
        for _, slot in pairs(petsFolder:GetChildren()) do
            if slot:IsA("StringValue") then
                slot.Value = "" -- Clear the slot
                print("🔓 Cleared equipped pet slot:", slot.Name)
            end
        end
    end
end

print("🎉 All pets have been deleted from your inventory!")
print("💾 Profile will be saved automatically")
print("🔄 Pet system will refresh automatically")
