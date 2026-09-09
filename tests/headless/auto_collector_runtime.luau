-- Execute the actual DropService movement/pickup methods against in-memory service doubles.
-- No Roblox connection, profile, datastore, network grant, or live instance is used.
-- Run: mise exec -- lune run tests/headless/auto_collector_runtime.luau
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local Vector3, CFrame = roblox.Vector3, roblox.CFrame
local function pure(path)
    return luau.load(fs.readFile(path))()
end
local cfg = pure("configs/drops.lua")
local policy = pure("src/Shared/Game/AutoCollectorPickup.lua")
local player = { UserId = 42, attrs = { AutoCollectorEnabled = true, Eff_Speed = 1 } }
function player:GetAttribute(name)
    return self.attrs[name]
end
local players = {
    GetPlayers = function()
        return { player }
    end,
    GetPlayerByUserId = function(_, id)
        return id == player.UserId and player or nil
    end,
}
-- Dotted Roblox module paths become strings; only the policy and event function are exercised.
local function pathNode(path)
    return setmetatable({}, {
        __index = function(_, name)
            if name == "WaitForChild" then
                return function(_, child)
                    return pathNode(path .. "." .. child)
                end
            end
            return pathNode(path .. "." .. name)
        end,
        __tostring = function()
            return path
        end,
    })
end
local events = {}
local service = luau.load(fs.readFile("src/Server/Services/DropService.lua"), {
    environment = {
        typeof = function(value)
            return value == player and "Instance" or typeof(value)
        end,
        Vector3 = Vector3,
        CFrame = CFrame,
        game = {
            GetService = function(_, name)
                return name == "Players" and players or pathNode(name)
            end,
        },
        require = function(path)
            if tostring(path):match("AutoCollectorPickup$") then
                return policy
            elseif tostring(path):match("CollectorCommentPolicy$") then
                return pure("src/Shared/Game/CollectorCommentPolicy.lua")
            elseif tostring(path):match("collector_voice$") then
                return pure("configs/collector_voice.lua")
            elseif tostring(path):match("FireGameEvent$") then
                return function(owner, kind)
                    assert(owner == player)
                    table.insert(events, kind)
                end
            end
            return {}
        end,
    },
})()

local counts = { enhancement = 0, potion = 0, currency = 0, recycled = 0 }
local grants = {
    EnhancementService = {
        Grant = function(_, owner, record)
            assert(owner == player and record.id == "test_enhancement")
            counts.enhancement += 1
            return { ok = true, name = "Test enhancement" }
        end,
    },
    PotionService = {
        Grant = function(_, owner, id, amount)
            assert(owner == player and id == "test_potion" and amount == 1)
            counts.potion += 1
            return { ok = true }
        end,
    },
    EconomyService = {
        AddCurrency = function(_, owner, currency, amount, reason)
            assert(
                owner == player and currency == "gems" and amount == 7 and reason == "drop_collect"
            )
            counts.currency += amount
            return true
        end,
    },
}
local state =
    { position = Vector3.zero, nextTargetAt = 0, model = { SetAttribute = function() end } }
local runtime = setmetatable({
    _config = cfg,
    _collectorCommentProgress = {},
    _active = {},
    _autoCollectors = { [42] = state },
    _moduleLoader = {
        Get = function(_, name)
            return grants[name]
        end,
    },
    _recycle = function()
        counts.recycled += 1
    end,
    _ensureAutoCollector = function()
        return state
    end,
    _autoCollectorFollowFrame = function()
        return CFrame.identity
    end,
    _removeAutoCollector = function() end,
}, service)
local function drop(kind, x)
    return {
        kind = kind,
        owner = 42,
        currency = kind == nil and "gems" or nil,
        amount = kind == nil and 7 or nil,
        record = { id = "test_enhancement", origins = { "ice" } },
        potionId = "test_potion",
        part = { Position = Vector3.new(x or 0, 0, 0), Parent = true },
    }
end
local function reset(records)
    runtime._active = records
    state.position = Vector3.zero
    state.target = nil
    state.nextTargetAt = 0
    state.nextPublishAt = 0
end

for _, kind in ipairs({ "enhancement", "potion", "currency" }) do
    local rec = drop(kind ~= "currency" and kind or nil)
    reset({ rec })
    runtime:_stepAutoCollectors(1, 0)
    assert(rec._done and #runtime._active == 0, "not collected: " .. kind)
    local recycled = counts.recycled
    runtime:_collect(rec) -- competing player Magnet/timeout attempt must not award again
    runtime:_stepAutoCollectors(2, 0)
    assert(counts.recycled == recycled, "duplicate recycle: " .. kind)
end
assert(counts.enhancement == 1 and counts.potion == 1 and counts.currency == 7)
assert(events[1] == "enhancement_pickup" and events[2] == "potion_pickup")

for _, kind in ipairs({ "enhancement", "potion" }) do
    local rec = drop(kind, cfg.auto_collector.collect_radius + 1)
    reset({ rec })
    runtime:_stepAutoCollectors(3, 0)
    assert(not rec._done, "collected beyond unchanged reach")
    runtime:_stepAutoCollectors(4, 0.25)
    assert(rec._done and state.position.Magnitude > 0, "did not walk into reach")
    local other = drop(kind)
    other.owner = 99
    reset({ other })
    state.target = other -- stale cached target must not bypass owner validation
    state.nextTargetAt = 100
    runtime:_stepAutoCollectors(5, 0)
    assert(not other._done and state.target == nil, "cross-owner pickup")
    local denied = drop(kind)
    reset({ denied })
    player.attrs.AutoCollectorEnabled = false
    runtime:_stepAutoCollectors(6, 0)
    assert(not denied._done, "pickup without entitlement")
    player.attrs.AutoCollectorEnabled = true
end
local egg = drop("egg_item")
local settling = drop("potion")
settling.settling = true
local dead = drop("enhancement")
dead._done = true
reset({ egg, settling, dead })
runtime:_stepAutoCollectors(7, 0)
assert(not egg._done and not settling._done and state.target == nil)
assert(counts.enhancement == 2 and counts.potion == 2 and counts.currency == 7)
local farCoin = drop(nil, 50)
local nearPotion = drop("potion", 10)
local nearestEnhancement = drop("enhancement", 5)
reset({ farCoin, nearPotion, nearestEnhancement })
assert(runtime:_nearestAutoCollectorDrop(42, Vector3.zero) == nearestEnhancement)
nearestEnhancement._done = true
assert(runtime:_nearestAutoCollectorDrop(42, Vector3.zero) == nearPotion)
nearPotion._done = true
assert(runtime:_nearestAutoCollectorDrop(42, Vector3.zero) == farCoin)

-- Reentrant pickup while a downstream service is executing uses the same done guard.
local reentrant = drop("potion")
local originalGrant = grants.PotionService.Grant
grants.PotionService.Grant = function(...)
    runtime:_collect(reentrant)
    return originalGrant(...)
end
reset({ reentrant })
runtime:_stepAutoCollectors(8, 0)
assert(counts.potion == 3, "reentrant grant duplicated")
print(
    "PASS: actual Auto Collector movement, canonical grants, duplicate guard, owner isolation, entitlement, reach, exclusions, and currency"
)

-- Exercise the actual currency grant path, including forced/passive and failed grants.
local commentConfig = pure("configs/collector_voice.lua")
local paid = true
grants.EconomyService.AddCurrency = function()
    return paid
end
local function coin(force, collector)
    local r = drop(nil)
    r.currency = "coins"
    runtime:_collect(r, force, collector)
end
player.attrs.AutoCollectorEnabled = false
player.attrs.CollectorCommentEligible = true
local before = #events
for _ = 1, commentConfig.manual_pickups do
    coin(true, false)
    coin(false, true)
end
assert(#events == before and runtime._collectorCommentProgress[player] == nil)
paid = false
coin()
assert(runtime._collectorCommentProgress[player] == nil, "Failed payout counted")
paid = true
for _ = 1, commentConfig.manual_pickups do
    coin()
end
assert(
    #events == before + 1 and events[#events] == commentConfig.event,
    "Manual collection never notified"
)
for _ = 1, 100 do
    coin()
end
assert(#events == before + 1, "Notification flooded")
for _, attrs in { { false, false }, { true, true } } do
    runtime._collectorCommentProgress = {}
    player.attrs.CollectorCommentEligible, player.attrs.AutoCollectorEnabled = attrs[1], attrs[2]
    for _ = 1, commentConfig.manual_pickups do
        coin()
    end
    assert(#events == before + 1, "Ineligible/owner received comment")
end
print(
    "PASS: collector comments only after credited manual coins; forced, passive, failed, unverified and entitled excluded"
)
