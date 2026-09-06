-- Actual service methods with isolated attributes/inventory doubles; no live profile or grants.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
-- Compile full production chunks too (including Luau's per-function local-register limit).
for _, path in ipairs({
    "src/Client/Systems/MergeEggPrototypeObserver.lua",
    "src/Client/Systems/PlayerPowerBadges.lua",
    "src/Server/Services/MergeEggPrototypeService.lua",
}) do
    assert(luau.load(fs.readFile(path)))
end
local function pure(path)
    return luau.load(fs.readFile(path))()
end
local powers = pure("configs/powers.lua")
local enhancements = pure("configs/enhancements.lua")
local deps = {}
for _, name in ipairs({ "Enhancements", "PowerRegistry", "PowerStats", "FocusUpkeep" }) do
    deps[name] = pure("src/Shared/Game/" .. name .. ".lua")
end
local function node(path)
    return setmetatable({}, {
        __tostring = function()
            return path
        end,
        __index = function(_, name)
            if name == "WaitForChild" then
                return function(_, child)
                    return node(path .. "." .. child)
                end
            end
            return node(path .. "." .. name)
        end,
    })
end
local function service(name)
    return luau.load(fs.readFile("src/Server/Services/" .. name .. ".lua"), {
        environment = {
            Color3 = roblox.Color3,
            script = node("script"),
            game = {
                GetService = function(_, id)
                    return node(id)
                end,
            },
            require = function(path)
                return deps[tostring(path):match("([^.]+)$")] or {}
            end,
        },
    })()
end
local player = { attrs = { Level = 10, EffectiveLevel = 10 } }
function player:GetAttribute(key)
    return self.attrs[key]
end
function player:SetAttribute(key, value)
    self.attrs[key] = value
end
local ids = { "swift", "magnet", "xp_surge", "prospector", "windfall", "fortune" }
local data = { Powers = ids, Slots = {} }
local power = setmetatable({
    _powersConfig = powers,
    _enhConfig = enhancements,
    _activeToggles = {},
    _dataService = {
        GetData = function()
            return data
        end,
    },
}, service("PowerService"))
power:ReapplyPassives(player)
assert(math.abs(power:_activeUpkeepRate(player, power._activeToggles[player]) - 2.4) < 1e-8)
for id, attr in pairs({
    prospector = "CoinYieldPower",
    windfall = "DropRateBuff",
    fortune = "LuckBuff",
}) do
    assert(player.attrs[attr] > 0 and player.attrs[attr .. "Toggle"])
    assert(power:ToggleActive(player, id, false).ok)
    assert(player.attrs[attr] == nil and player.attrs[attr .. "Owned"] == id)
    assert(power:ToggleActive(player, id, true).ok)
    assert(player.attrs[attr] > 0)
end
data.Powers = {}
assert(power:ToggleActive(player, "prospector", true).reason == "not_owned")
power:ReapplyPassives(player)
assert(player.attrs.CoinYieldPower == nil and player.attrs.CoinYieldPowerOwned == nil)

local function piece(kind)
    return { enh = { type = kind, origins = { "geomancer" }, level = 10 } }
end
data.Slots = {
    prospector = { piece("duration"), piece("potency") },
    windfall = { piece("recharge") },
    hasten = { piece("recharge") },
}
local saves = 0
data.Slots.prospector[1].inherent = true
local originalPotency = data.Slots.prospector[2].enh
local enh = setmetatable({
    _config = enhancements,
    _powersConfig = powers,
    _dataService = {
        GetData = function()
            return data
        end,
        RequestSave = function(_, _, reason)
            assert(reason == "enhancement_toggle_conversion")
            saves += 1
        end,
    },
}, service("EnhancementService"))
assert(enh:ConvertToggleSlots(player) == 0 and saves == 0) -- Origin not chosen yet.
assert(data.Slots.prospector[1].enh.type == "duration")
data.Archetype = "cryomancer"
assert(enh:ConvertToggleSlots(player) == 2 and saves == 1)
assert(data.Slots.prospector[1].enh.type == "potency")
assert(data.Slots.windfall[1].enh.type == "focus")
assert(data.Slots.prospector[1].inherent and #data.Slots.prospector == 2)
assert(
    data.Slots.prospector[2].enh == originalPotency and data.Slots.hasten[1].enh.type == "recharge"
)
for _, rec in ipairs({ data.Slots.prospector[1].enh, data.Slots.windfall[1].enh }) do
    assert(rec.level == 15 and #rec.origins == 1 and rec.origins[1] == data.Archetype)
    assert(deps.Enhancements.canSlotAtLevel(enhancements, rec.level, player.attrs.Level))
    assert(deps.Enhancements.levelFactor(enhancements, rec.level, player.attrs.Level) == 1.5)
end
assert(enh:ConvertToggleSlots(player) == 0 and saves == 1)
player.attrs.Level = 50
data.Slots.fortune = { piece("duration") }
assert(enh:ConvertToggleSlots(player) == 1 and data.Slots.fortune[1].enh.level == 55)
print(
    "PASS: actual toggle stamping/on/off/ownership, 2.4 focus upkeep, best-usable single-origin in-slot conversion, origin deferral and repeat safety"
)
