-- Debug Service Exposer - Put this in ServerScriptService temporarily
-- This will expose services to _G for console testing

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Wait for services to be loaded
wait(5)

print("🔍 DEBUG: Attempting to expose services to _G...")

-- Try to get the ModuleLoader
local success, result = pcall(function()
    local Locations = require(ReplicatedStorage.Shared.Locations)
    local ModuleLoader = require(Locations.Libraries.ModuleLoader)

    -- Expose services to _G
    _G.DEBUG_EconomyService = ModuleLoader:Get("EconomyService")
    _G.DEBUG_InventoryService = ModuleLoader:Get("InventoryService")
    _G.DEBUG_DataService = ModuleLoader:Get("DataService")

    print("✅ DEBUG: Services exposed to _G")
    print("  EconomyService:", _G.DEBUG_EconomyService and "✅" or "❌")
    print("  InventoryService:", _G.DEBUG_InventoryService and "✅" or "❌")
    print("  DataService:", _G.DEBUG_DataService and "✅" or "❌")

    return true
end)

if not success then
    print("❌ DEBUG: Failed to expose services:", result)
end
