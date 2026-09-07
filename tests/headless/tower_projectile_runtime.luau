-- Exercise production projectile birth, landing, expiry and bay teardown without Studio.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local source = fs.readFile("src/Server/Services/MergeEggPrototypeService.lua")
local env = {
    Instance = roblox.Instance,
    Vector3 = roblox.Vector3,
    CFrame = roblox.CFrame,
    Enum = roblox.Enum,
    requiredConfigNumber = function(value)
        return assert(tonumber(value))
    end,
}
local service = {}
for _, name in ipairs({
    "_fireTowerShot",
    "_stepTowerShots",
    "_beginTowerShotImpact",
    "_clearTowerShots",
}) do
    local first = assert(source:find("function MergeEggPrototypeService:" .. name .. "(", 1, true))
    local last = assert(source:find("\nfunction ", first + 1, true))
    service[name] = luau.load(
        "local MergeEggPrototypeService={}\n"
            .. source:sub(first, last - 1)
            .. "\nreturn MergeEggPrototypeService."
            .. name,
        { environment = env }
    )()
end
local shot =
    { apex_height = 1, diameter = 1, flight_seconds = 1, land_seconds = 1, bloom_scale = 1 }
function service:_edgeTowerConfig()
    return {}, shot
end
function service:_towerGateLook()
    return roblox.Vector3.xAxis
end
function service:_towerMuzzle()
    return roblox.Vector3.zero
end
function service:_towerShotTarget()
    return roblox.Vector3.new(10, 0, 0)
end
function service:_towerPlanarAim()
    return roblox.Vector3.xAxis
end
function service:_towerShotColor()
    return roblox.Color3.new(1, 0, 0)
end
function service:_towerImpactKind()
    return "linger"
end
function service:_towerFolder(world, name)
    local folder = world:FindFirstChild(name)
    if not folder then
        folder = roblox.Instance.new("Folder")
        folder.Name, folder.Parent = name, world
    end
    return folder
end
for _, name in ipairs({
    "_aimTowerCannon",
    "_dressTowerShotFlame",
    "_playCannonFire",
    "_beginTowerRecoil",
    "_playCannonImpact",
    "_playTowerLandingVisual",
}) do
    service[name] = function() end
end
local function bay()
    local world = roblox.Instance.new("Folder")
    local cannon = {
        GetPivot = function()
            return roblox.CFrame.new()
        end,
        GetAttribute = function()
            return "damage"
        end,
        SetAttribute = function() end,
    }
    return { world = world }, cannon
end
local record, cannon = bay()
local destroyed = {}
for index = 1, 100 do
    local now = index * 10
    assert(service:_fireTowerShot(record, cannon, now))
    local flight = service._towerShots[1]
    local part = flight.part
    service:_stepTowerShots(now + 1)
    assert(
        #service._towerShots == 1 and part.Parent,
        "landed projectile must finish its visual lifetime"
    )
    service:_stepTowerShots(now + 2)
    assert(
        #service._towerShots == 0 and part.Parent == nil,
        "expired projectile must leave the live registry"
    )
    destroyed[part] = true
end
local seen = {}
local function assertNoRetiredReferences(value)
    assert(not destroyed[value], "run state retains a destroyed projectile")
    if type(value) ~= "table" or seen[value] then
        return
    end
    seen[value] = true
    for key, child in pairs(value) do
        assertNoRetiredReferences(key)
        assertNoRetiredReferences(child)
    end
end
assertNoRetiredReferences(record)
assertNoRetiredReferences(service._towerShots)
local other, otherCannon = bay()
assert(service:_fireTowerShot(record, cannon, 2000))
assert(service:_fireTowerShot(other, otherCannon, 2000))
local otherPart = service._towerShots[2].part
service:_clearTowerShots(record)
assert(
    #service._towerShots == 1 and service._towerShots[1].part == otherPart and otherPart.Parent,
    "clearing one bay must preserve another bay's active projectile"
)
service:_clearTowerShots(other)
assert(#service._towerShots == 0 and otherPart.Parent == nil)
record.world:Destroy()
other.world:Destroy()
print(
    "PASS: 100 production projectile lifecycles release retired references; bay teardown stays isolated"
)
