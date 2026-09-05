-- Edit-mode isolated regression. No live player/profile/teleport or authored prop changes.
local services = game.ServerScriptService.Server.Services
local configs = game.ReplicatedStorage.Configs
-- Edit-mode requires may retain a pre-Rojo config; exercise the currently synced source.
local config = assert(loadstring("local script = ...\n" .. configs.merge_egg_prototype.Source))(
    configs.merge_egg_prototype
)
local source = services.MergeEggPrototypeService.Source
local function method(name, prelude, ...)
    local first = assert(source:find("function MergeEggPrototypeService:" .. name .. "(", 1, true))
    local last = source:find("\nfunction MergeEggPrototypeService:", first + 1, true) or #source + 1
    return assert(
        loadstring(
            (prelude or "")
                .. "\nlocal MergeEggPrototypeService = {}\n"
                .. source:sub(first, last - 1)
                .. "\nreturn MergeEggPrototypeService."
                .. name
        )
    )(...)
end
local service = { _config = config, _placesConfig = require(configs.places) }
service._quartermasterConfig = method("_quartermasterConfig")
service._quartermasterMenuState = method(
    "_quartermasterMenuState",
    "local PlaceRuntime = ...",
    require(game.ReplicatedStorage.Shared.Game.PlaceRuntime)
)
service.UseQuartermasterService = method("UseQuartermasterService")
service._returnToFarmAndFight = method("_returnToFarmAndFight")
local player = { Name = "TravelFixture" }
local record = { player = player }
local allowed, travelCalls = true, 0
function service:_canUseQuartermaster()
    return allowed, "quartermaster_too_far", record
end
function service:_isDedicatedMergePlace()
    return true
end
function service:_teleportToRole(who, role)
    assert(who == player and role == "main")
    travelCalls += 1
    return false, "teleport_pending"
end
local payload = service:_quartermasterMenuState(record)
assert(
    payload.farmFightAvailable
        and payload.farmFightLabel == config.quartermaster.services.farm_fight_label
)
local ok, reason = service:UseQuartermasterService(player, { choice = "farm_fight" })
assert(not ok and reason == "teleport_pending" and travelCalls == 1)
allowed = false
ok, reason = service:UseQuartermasterService(player, { choice = "farm_fight" })
assert(not ok and reason == "quartermaster_too_far" and travelCalls == 1)

service._setVendorPosted = method("_setVendorPosted")
service._setPotionShopPosted = method(
    "_setPotionShopPosted",
    "local requiredConfigNumber = ...",
    function(value)
        return assert(tonumber(value))
    end
)
local count = 0
for _, authored in workspace:GetDescendants() do
    if
        authored:IsA("Model")
        and (authored.Name == "HeavenPotionShop" or authored.Name == "HellPotionShop")
    then
        local clone = authored:Clone()
        local mesh = assert(clone:FindFirstChildWhichIsA("MeshPart", true))
        local position = mesh.CFrame
        mesh.Anchored = false -- reproduce the imported prop's original state
        for _ = 1, 3 do
            service:_setPotionShopPosted(clone, false)
            assert(mesh.Anchored and mesh.Transparency == 1 and not mesh.CanCollide)
            service:_setPotionShopPosted(clone, true)
            assert(
                mesh.Parent and mesh.Anchored and mesh.Transparency == 0 and mesh.CFrame == position
            )
            assert(clone:GetAttribute("PotionShopPromptSuppressed") == true)
        end
        clone:Destroy()
        count += 1
    end
end
assert(count == 10, "Expected all authored Heaven/Hell tents")
return { ok = true, tents = count, hide_show_cycles = count * 3, travelCalls = travelCalls }
