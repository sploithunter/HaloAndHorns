-- Quick script to create test orphaned buckets (Command Bar friendly)
local DataService = require(game.ServerScriptService.Services.DataService)
local player = game.Players.coloradoplays
local profile = DataService:GetProfile(player)

-- Create orphaned buckets
profile.Data.Inventory.health_potion = {
    items = { ["hp1"] = { id = "health_potion", count = 15 } },
    total_slots = 100,
    used_slots = 1,
}
profile.Data.Inventory.speed_potion =
    { items = { ["sp1"] = { id = "speed_potion", count = 8 } }, total_slots = 100, used_slots = 1 }
profile.Data.Inventory.test_legacy =
    { items = { ["tl1"] = { id = "test_item", count = 5 } }, total_slots = 50, used_slots = 1 }
profile.Data.Inventory.alamantic_aluminum = {
    items = { ["aa1"] = { id = "alamantic_aluminum", count = 50 } },
    total_slots = 200,
    used_slots = 1,
}

-- Recreate folders
local InventoryService = require(game.ServerScriptService.Services.InventoryService)
if InventoryService._playerInventoryFolders[player] then
    InventoryService._playerInventoryFolders[player]:Destroy()
end
InventoryService._playerInventoryFolders[player] = nil
InventoryService:_createInventoryFolders(player)

print(
    "✅ Created 4 orphaned buckets: health_potion, speed_potion, test_legacy, alamantic_aluminum"
)
