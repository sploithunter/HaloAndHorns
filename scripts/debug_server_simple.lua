-- Simple Server Debug - Copy line by line into server console
-- Line 1: Get player
local player = game.Players.coloradoplays

-- Line 2: Check if player exists
if not player then
    print("❌ Player not found")
    return
end

-- Line 3: Try to get services from _G
local EconomyService, DataService = _G.EconomyService, _G.DataService

-- Line 4: Check services
print(
    "EconomyService:",
    EconomyService and "✅" or "❌",
    "DataService:",
    DataService and "✅" or "❌"
)

-- Line 5: If no services in _G, check what's available
if not EconomyService then
    for k, v in pairs(_G) do
        if k:find("Service") then
            print(k, typeof(v))
        end
    end
    return
end

-- Line 6: Get profile
local profile = DataService:GetProfile(player)

-- Line 7: Check profile and coins
print(
    "Profile:",
    profile and "✅" or "❌",
    "Coins:",
    profile and profile.Data.Currencies and profile.Data.Currencies.coins or "N/A"
)

-- Line 8: Show inventory buckets
if profile and profile.Data.Inventory then
    for name, bucket in pairs(profile.Data.Inventory) do
        if type(bucket) == "table" and bucket.items then
            print("Bucket:", name, "#items:", #bucket.items)
        else
            print("Bucket:", name, "value:", bucket)
        end
    end
end

-- Line 9: Test purchase
local success, result = pcall(function()
    return EconomyService:PurchaseItem(player, { itemId = "health_potion" })
end)

-- Line 10: Show purchase result
print("Purchase - Success:", success, "Result:", result)

-- Line 11: Check inventory after purchase
local newProfile = DataService:GetProfile(player)
if newProfile and newProfile.Data.Inventory then
    for name, bucket in pairs(newProfile.Data.Inventory) do
        if type(bucket) == "table" and bucket.items and #bucket.items > 0 then
            print("After purchase - Bucket:", name, "#items:", #bucket.items)
            for i, item in ipairs(bucket.items) do
                print("  Item " .. i .. ":", game:GetService("HttpService"):JSONEncode(item))
            end
        end
    end
end

-- Line 12: Check client folders
local invFolder = player:FindFirstChild("Inventory")
print("Client Inventory Folder:", invFolder and "✅" or "❌")
if invFolder then
    for _, child in pairs(invFolder:GetChildren()) do
        print(
            "  " .. child.Name .. ":",
            child.ClassName,
            child:IsA("Folder") and ("#children: " .. #child:GetChildren()) or ""
        )
    end
end
