-- Execute the actual purchase method with isolated economy/board doubles, never live data.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local source = fs.readFile("src/Server/Services/MergeEggPrototypeService.lua")
local first = assert(source:find("function MergeEggPrototypeService:CreateBaseEgg(", 1, true))
local last = assert(source:find("function MergeEggPrototypeService:UpgradeBaseEgg(", first, true))
local now = 1
local class = luau.load(
    "local MergeEggPrototypeService = {}\n"
        .. source:sub(first, last - 1)
        .. "\nreturn MergeEggPrototypeService",
    {
        environment = {
            os = {
                clock = function()
                    return now
                end,
            },
        },
    }
)()
local cfg = luau.load(fs.readFile("configs/merge_egg_prototype.lua"), {
    environment = {
        script = { Parent = { merge_tier_art = "configs/merge_tier_art.lua" } },
        require = function(path)
            return luau.load(fs.readFile(path))()
        end,
    },
})()
local player = { Name = "IsolatedTest" }
local record = { player = player, encounterSpawned = true }
local wallet, transactions, full, near, reenter, invalidate = 2000, 0, false, true, false, false
local svc = setmetatable({ _config = cfg }, { __index = class })
function svc:_allowsGameplayActions()
    return true
end
function svc:_recordFor()
    return record
end
function svc:_canUseEggStation()
    return near, "too_far", 1
end
function svc:_eggInventoryTotal()
    return full and 16 or 0
end
function svc:_mergeBoardCapacity()
    return 16
end
function svc:_baseEggCreationCost()
    return { amount = 100, currency = "hall_coins", tier = 1 }
end
function svc:_isRecordActive()
    return not invalidate
end
function svc:_eggInventoryCount(r, tier)
    return r.eggInventory and r.eggInventory[tier] or 0
end
function svc:_markEggTierMilestone()
    return false
end
function svc:_markPetSlotMilestone()
    return false
end
function svc:_autoMergeActive()
    return false
end
function svc:_publishBoardMutation() end
function svc:_analytics() end
function svc:_log() end
function svc:_updateTutorial() end
function svc:_eggProgression()
    return { "earth" }
end
function svc:_eggDisplayName(id)
    return id
end
svc._economyService = {
    Transact = function(_, _, tx)
        transactions += 1
        if reenter then
            local ok, reason = svc:CreateBaseEgg(player)
            assert(not ok and reason == "egg_create_in_progress")
        end
        if wallet < tx.debits.hall_coins then
            return { ok = false, reason = "precondition_failed" }
        end
        if not tx.commit() then
            return { ok = false, reason = "commit_failed" }
        end
        wallet -= tx.debits.hall_coins
        return { ok = true }
    end,
}
-- Ten regular clicks a second, with duplicate events between them.
for i = 0, 9 do
    now = 1 + i / 10
    assert(svc:CreateBaseEgg(player), "regular click refused at " .. tostring(now))
    now += 0.01
    local ok, reason = svc:CreateBaseEgg(player)
    assert(not ok and reason == "egg_create_throttled")
end
assert(record.eggsCreated == 10 and wallet == 1000 and transactions == 10)
now = 3
full = true
assert(select(2, svc:CreateBaseEgg(player)) == "merge_board_full")
full, near = false, false
assert(select(2, svc:CreateBaseEgg(player)) == "too_far")
near, wallet = true, 0
assert(select(2, svc:CreateBaseEgg(player)) == "insufficient_currency")
assert(record.eggsCreated == 10 and not record.eggCreateInProgress)
wallet, invalidate = 1000, true
assert(select(2, svc:CreateBaseEgg(player)) == "board_state_changed")
assert(wallet == 1000 and record.eggsCreated == 10)
invalidate, reenter = false, true
assert(svc:CreateBaseEgg(player))
assert(wallet == 900 and record.eggsCreated == 11)
print(
    "PASS: actual egg purchase accepts 10 clicks/sec, rejects duplicates, preserves funds/capacity/proximity and in-flight transaction guards"
)
