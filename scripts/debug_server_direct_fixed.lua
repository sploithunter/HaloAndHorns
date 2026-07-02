-- FIXED Direct Server Access Debug Script
-- Run this in the server console - uses proper service access

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

print("🧪 DIRECT SERVER TEST - Starting (Fixed Version)")

-- Test player (replace with actual player name)
local testPlayerName = "coloradoplays"  -- Change this to your username
local testPlayer = Players:FindFirstChild(testPlayerName)

if not testPlayer then
    print("❌ Player not found:", testPlayerName)
    local playerNames = {}
    for _, player in pairs(Players:GetPlayers()) do
        table.insert(playerNames, player.Name)
    end
    print("Available players:", table.concat(playerNames, ", "))
    return
end

print("📋 Testing player:", testPlayer.Name)

-- Get services through the server's module loader
-- The ModuleLoader should be accessible through the server init
local success, ModuleLoader = pcall(function()
    -- Try different paths to find the ModuleLoader
    local serverInit = ServerScriptService:FindFirstChild("Server")
    if serverInit and serverInit:FindFirstChild("init") then
        -- ModuleLoader might be stored in _G or as a global
        return _G.ModuleLoader or require(ReplicatedStorage.Shared.Libraries.ModuleLoader)
    end
    return require(ReplicatedStorage.Shared.Libraries.ModuleLoader)
end)

if not success or not ModuleLoader then
    print("❌ Could not access ModuleLoader:", ModuleLoader)
    print("Trying alternative approach...")
    
    -- Alternative: try to access services directly through _G
    local EconomyService = _G.EconomyService
    local InventoryService = _G.InventoryService
    local DataService = _G.DataService
    
    if not (EconomyService and InventoryService and DataService) then
        print("❌ Services not found in _G either")
        print("Available _G keys:")
        for k, v in pairs(_G) do
            if type(k) == "string" and k:find("Service") then
                print("  " .. k .. ":", typeof(v))
            end
        end
        return
    end
    
    print("✅ Found services in _G")
    goto servicesFound
end

print("✅ ModuleLoader found, getting services...")

-- Get services through ModuleLoader
local EconomyService = ModuleLoader:Get("EconomyService")
local InventoryService = ModuleLoader:Get("InventoryService")
local DataService = ModuleLoader:Get("DataService")

::servicesFound::

-- Test 1: Check if services exist
print("\n🔍 SERVICE AVAILABILITY:")
print("  EconomyService:", EconomyService and "✅ FOUND" or "❌ MISSING")
print("  InventoryService:", InventoryService and "✅ FOUND" or "❌ MISSING")
print("  DataService:", DataService and "✅ FOUND" or "❌ MISSING")

if not (EconomyService and InventoryService and DataService) then
    print("❌ Missing required services!")
    return
end

-- Test 2: Check player profile
print("\n🔍 PLAYER PROFILE:")
local profileSuccess, profile = pcall(function()
    return DataService:GetProfile(testPlayer)
end)

if not profileSuccess then
    print("  Profile access failed:", profile)
    return
end

if profile then
    print("  Profile found: ✅")
    print("  Coins:", profile.Data.Currencies and profile.Data.Currencies.coins or "NOT SET")
    
    -- Show inventory structure
    if profile.Data.Inventory then
        print("  Inventory buckets:")
        for bucketName, bucket in pairs(profile.Data.Inventory) do
            if type(bucket) == "table" and bucket.items then
                print("    " .. bucketName .. ": " .. #bucket.items .. " items")
            else
                print("    " .. bucketName .. ": " .. tostring(bucket) .. " (legacy format)")
            end
        end
    else
        print("  No inventory data")
    end
else
    print("  Profile: ❌ NOT FOUND")
    return
end

-- Test 3: Direct purchase test
print("\n🧪 DIRECT PURCHASE TEST:")
print("  Attempting to purchase health_potion...")

local purchaseData = {
    itemId = "health_potion"
}

print("  Purchase data:", game:GetService("HttpService"):JSONEncode(purchaseData))

-- Call EconomyService directly
local purchaseSuccess, purchaseResult = pcall(function()
    return EconomyService:PurchaseItem(testPlayer, purchaseData)
end)

print("  Purchase result:")
print("    Success:", purchaseSuccess)
print("    Result:", purchaseResult)

if not purchaseSuccess then
    print("    Error details:", tostring(purchaseResult))
end

-- Test 4: Check inventory after purchase
print("\n🔍 INVENTORY AFTER PURCHASE:")
local newProfileSuccess, newProfile = pcall(function()
    return DataService:GetProfile(testPlayer)
end)

if newProfileSuccess and newProfile and newProfile.Data.Inventory then
    for bucketName, bucket in pairs(newProfile.Data.Inventory) do
        if type(bucket) == "table" and bucket.items then
            print("  " .. bucketName .. ": " .. #bucket.items .. " items")
            if #bucket.items > 0 then
                for i, item in ipairs(bucket.items) do
                    local itemJson = game:GetService("HttpService"):JSONEncode(item)
                    print("    [" .. i .. "]", itemJson)
                end
            end
        end
    end
else
    print("  Could not access profile after purchase")
end

-- Test 5: Check client-side replication
print("\n🔍 CLIENT REPLICATION CHECK:")
local inventoryFolder = testPlayer:FindFirstChild("Inventory")
if inventoryFolder then
    print("  Inventory folder: ✅ FOUND")
    for _, child in pairs(inventoryFolder:GetChildren()) do
        print("    " .. child.Name .. ":", child.ClassName)
        if child:IsA("Folder") then
            print("      Items:", #child:GetChildren())
        end
    end
else
    print("  Inventory folder: ❌ NOT FOUND")
end

print("\n🧪 DIRECT SERVER TEST - Complete")