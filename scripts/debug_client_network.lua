-- Client Network Debug Script
-- Run this in the client console to test NetworkBridge directly

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Get the NetworkBridge
local Locations = require(ReplicatedStorage.Shared.Locations)
local NetworkBridge = require(Locations.Network.NetworkBridge)

print("🧪 CLIENT NETWORK TEST - Starting")

-- Test 1: Check NetworkBridge availability
print("\n🔍 NETWORK BRIDGE AVAILABILITY:")
print("  NetworkBridge:", NetworkBridge and "✅ FOUND" or "❌ MISSING")

if not NetworkBridge then
    print("❌ NetworkBridge not available!")
    return
end

-- Test 2: Check economy bridge
local economyBridge = NetworkBridge.new("economy")
print("  Economy bridge created:", economyBridge and "✅ SUCCESS" or "❌ FAILED")

if not economyBridge then
    print("❌ Could not create economy bridge!")
    return
end

print("  Economy bridge type:", typeof(economyBridge))
print("  Has Fire method:", economyBridge.Fire and "✅ YES" or "❌ NO")

-- Test 3: Check available packets
print("\n🔍 AVAILABLE PACKETS:")
local success, packets = pcall(function()
    return economyBridge._packets
end)

if success and packets then
    print("  Packets found:", success)
    local packetNames = {}
    for name, _ in pairs(packets) do
        table.insert(packetNames, name)
    end
    print("  Available packet types:", table.concat(packetNames, ", "))

    -- Check if purchase_item exists
    if packets.purchase_item then
        print("  purchase_item packet: ✅ FOUND")
        print(
            "  purchase_item config:",
            game:GetService("HttpService"):JSONEncode(packets.purchase_item)
        )
    else
        print("  purchase_item packet: ❌ NOT FOUND")
    end
else
    print("  Could not access packets:", packets)
end

-- Test 4: Test Fire method directly
print("\n🧪 DIRECT FIRE TEST:")
local testData = {
    itemId = "health_potion",
}

print("  Test data:", game:GetService("HttpService"):JSONEncode(testData))
print("  Attempting to fire purchase_item packet...")

local fireSuccess, fireError = pcall(function()
    economyBridge:Fire("purchase_item", testData)
    print("  ✅ Fire call completed successfully")
end)

if not fireSuccess then
    print("  ❌ Fire call failed:", fireError)
end

-- Test 5: Alternative Fire signature test
print("\n🧪 ALTERNATIVE FIRE SIGNATURE TEST:")
print("  Attempting old signature: Fire('server', 'purchase_item', data)...")

local altFireSuccess, altFireError = pcall(function()
    economyBridge:Fire("server", "purchase_item", testData)
    print("  ✅ Alternative Fire call completed")
end)

if not altFireSuccess then
    print("  ❌ Alternative Fire call failed:", altFireError)
end

-- Test 6: Check rate limiting
print("\n🔍 RATE LIMITING CHECK:")
local rateLimitSuccess, rateLimitResult = pcall(function()
    return economyBridge._rateLimiter
end)

if rateLimitSuccess and rateLimitResult then
    print("  Rate limiter found: ✅")
    print("  Rate limiter type:", typeof(rateLimitResult))
else
    print("  Rate limiter: ❌ NOT FOUND")
end

-- Test 7: Multiple rapid calls
print("\n🧪 RAPID FIRE TEST:")
for i = 1, 3 do
    local rapidSuccess, rapidError = pcall(function()
        economyBridge:Fire("purchase_item", { itemId = "health_potion_" .. i })
    end)
    print(
        "  Call " .. i .. ":",
        rapidSuccess and "✅ SUCCESS" or ("❌ FAILED: " .. tostring(rapidError))
    )
    wait(0.1)
end

print("\n🧪 CLIENT NETWORK TEST - Complete")
