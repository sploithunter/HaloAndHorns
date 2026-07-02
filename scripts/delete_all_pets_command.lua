--[[
    DELETE ALL PETS - Command Bar Version
    
    USAGE: Copy and paste this entire block into Studio Command Bar
    WARNING: This deletes ALL pets permanently!
]]

local p = Players.LocalPlayer or Players:FindFirstChild("coloradoplays")
if not p then
    print("❌ Player not found")
    return
end

local profile = require(game.ServerScriptService.Server.Services.DataService):GetProfile(p)
if not profile or not profile.Data.Inventory.pets then
    print("✅ No pets to delete")
    return
end

local petCount = 0
for _ in pairs(profile.Data.Inventory.pets.items) do
    petCount = petCount + 1
end
if petCount == 0 then
    print("✅ No pets found")
    return
end

print("🗑️ DELETING", petCount, "PETS...")
profile.Data.Inventory.pets.items = {}
profile.Data.Inventory.pets.used_slots = 0

-- Clear equipped slots
local equipped = p:FindFirstChild("Equipped")
if equipped and equipped:FindFirstChild("pets") then
    for _, slot in pairs(equipped.pets:GetChildren()) do
        if slot:IsA("StringValue") then
            slot.Value = ""
        end
    end
end

print("✅ DELETED ALL", petCount, "PETS!")
