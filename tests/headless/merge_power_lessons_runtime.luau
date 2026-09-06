-- Production lesson runtime with isolated player/profile doubles; never touches live saves.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local function pure(path)
    return luau.load(fs.readFile(path), {
        environment = {
            script = { Parent = { merge_tier_art = "configs/merge_tier_art.lua" } },
            require = function(dependency)
                return luau.load(fs.readFile(dependency))()
            end,
        },
    })()
end
local Lessons = pure("src/Shared/Game/MergePowerLessons.lua")
local cfg = pure("configs/merge_egg_prototype.lua").tutorial
local powers = pure("configs/powers.lua")
local enhCfg = pure("configs/enhancements.lua")
local deps =
    { MergePowerLessons = Lessons, Enhancements = pure("src/Shared/Game/Enhancements.lua") }
local function node(path)
    return setmetatable({}, {
        __index = function(_, id)
            return node(path .. "." .. id)
        end,
        __tostring = function()
            return path
        end,
    })
end
local Runtime = luau.load(fs.readFile("src/Server/Services/MergePowerLessonRuntime.lua"), {
    environment = {
        game = {
            GetService = function(_, id)
                return node(id)
            end,
        },
        require = function(path)
            return assert(deps[tostring(path):match("([^.]+)$")])
        end,
    },
})()
for _, path in ipairs({
    "src/Client/UI/MergePowerLessonGuide.lua",
    "src/Client/UI/Menus/PowerChoiceMenu.lua",
    "src/Client/Systems/LevelUpController.lua",
    "src/Client/Systems/MergeEggPrototypeObserver.lua",
    "src/Server/Services/MergeEggPrototypeService.lua",
    "src/Server/init.server.lua",
}) do
    assert(luau.load(fs.readFile(path)), path)
end

local function fixture(wave, dog)
    local player = { attrs = {}, Name = "isolated" }
    function player:SetAttribute(k, v)
        self.attrs[k] = v
    end
    local data = { GameData = {}, Powers = {}, Slots = {} }
    local record = { player = player, waveIndex = wave, aliveEnemies = 0 }
    local counts = { grants = 0, levels = 0, resumes = 0, saves = 0, warnings = 0 }
    local earned, claimed = 1, 1
    local progression = {
        GetClaimedLevel = function()
            return claimed
        end,
        GetEarnedLevel = function()
            return earned
        end,
        EnsureEarnedLevel = function(_, _, level)
            earned = math.max(earned, level)
            counts.levels += 1
        end,
        RefreshPublishedState = function() end,
    }
    local inventory = {}
    local enh = { _config = enhCfg, _powersConfig = powers }
    function enh:GetState()
        return { inventory = inventory }
    end
    function enh:Grant(_, item, options)
        assert(options.deferFlush)
        counts.grants += 1
        item.uid = "gift-" .. counts.grants
        table.insert(inventory, item)
        return { ok = true, uid = item.uid }
    end
    function enh:_inventoryService()
        return {
            FlushBucket = function()
                assert(data.GameData.MergePowerLessons.enhancementGranted, "receipt before flush")
            end,
        }
    end
    local service = {
        _modules = { PlayerProgressionService = progression, EnhancementService = enh },
        _dataService = {
            GetData = function()
                return data
            end,
            RequestSave = function()
                counts.saves += 1
            end,
        },
        _tutorialConfig = function()
            return cfg
        end,
        _mergeDefenseProgress = function()
            return data.GameData.MergeDefense or {}
        end,
        _isRecordActive = function(_, r)
            return r == record and not r.ended
        end,
        _tutorialUsesAutoCollector = function()
            return dog
        end,
        _setTutorialStep = function(_, r, step)
            r.tutorialStep = step
        end,
        _setWorldState = function() end,
        _scheduleTutorialWaveResume = function()
            counts.resumes += 1
        end,
        _log = function(_, _, _, details)
            counts.warnings += 1
            counts.error = details.error
        end,
    }
    return service,
        record,
        data,
        counts,
        inventory,
        function(value)
            claimed = value
            earned = math.max(earned, value)
        end
end

local s, r, d, c, inv, claim = fixture(5, false)
assert(not Runtime.tryStart(s, r))
r.waveIndex = 6
assert(Runtime.tryStart(s, r))
assert(c.levels == 1 and r.player.attrs.MergePowerRecommendation == "magnet")
assert(d.GameData.MergePowerLessons.unlocked and not d.CombatTutorial)
assert(not Runtime.tryStart(s, r))
Runtime.update(s, r)
assert(c.levels == 1 and c.resumes == 0, "no repeated grant / no automatic claim")
claim(2)
d.Powers = { "magnet" }
Runtime.update(s, r)
assert(c.resumes == 1 and not r.player.attrs.MergePowerLesson)
r.waveIndex = 8
assert(not Runtime.tryStart(s, r))
r.waveIndex = 10
assert(Runtime.tryStart(s, r) and c.levels == 2)
assert(r.player.attrs.MergePowerLessonTarget == "magnet")
claim(3)
d.Slots.magnet = { { inherent = true }, {} }
Runtime.update(s, r)
assert(r.powerLessonId == "slots")
table.insert(d.Slots.magnet, {})
Runtime.update(s, r)
assert(c.resumes == 2)
r.waveIndex = 12
assert(Runtime.tryStart(s, r))
assert(c.grants == 1 and inv[1].type == "focus" and #inv[1].origins == 0 and inv[1].level == 8)
assert(r.player.attrs.MergePowerLessonTarget == "magnet")
for _ = 1, 10 do
    Runtime.update(s, r)
end
assert(c.grants == 1 and c.warnings == 0, c.error)
-- Simulated rejoin keeps the same profile receipt and does not mint another item.
r.tutorialActive, r.powerLessonId = false, nil
assert(Runtime.tryStart(s, r) and c.grants == 1)
d.Slots.magnet[2].enh = inv[1]
Runtime.update(s, r)
assert(c.resumes == 3 and d.GameData.MergePowerLessons.completed.enhance)
assert(not Runtime.tryStart(s, r))

for _, kind in ipairs({ "Tutorial", "CombatTutorial", "legacy", "rebirth", "offline" }) do
    local a, b, data, counts = fixture(12, true)
    if kind == "legacy" then
        data.GameData.TutorialCompleted = true
    elseif kind == "rebirth" then
        data.GameData.MergeDefense = { rebirths = 1 }
    elseif kind == "offline" then
        b.player.OfflineActor = true
    else
        data[kind] = { done = true }
    end
    assert(not Runtime.tryStart(a, b), kind)
    assert(counts.levels == 0 and counts.grants == 0, kind)
end
local a, b, data, counts = fixture(6, true)
assert(Runtime.tryStart(a, b) and b.player.attrs.MergePowerRecommendation == "magnet")
assert(d.GameData.MergePowerLessons.completed.enhance, "other player's receipts untouched")
b.ended = true
assert(not Runtime.update(a, b) and counts.levels == 1)

local s2, r2, d2, c2, inv2, claim2 = fixture(12, false)
claim2(10)
d2.Powers = { "magnet" }
d2.Slots.magnet = { {}, {} }
inv2[1] = { type = "focus", origins = {}, level = 10 }
assert(Runtime.tryStart(s2, r2))
assert(c2.levels == 0 and c2.grants == 0 and r2.powerLessonId == "enhance")
-- Delivery failure retries; subsequent successful calls remain once-only.
inv2[1] = nil
local originalGrant = s2._modules.EnhancementService.Grant
s2._modules.EnhancementService.Grant = function()
    return { ok = false }
end
Runtime.update(s2, r2)
assert(not d2.GameData.MergePowerLessons.enhancementGranted)
s2._modules.EnhancementService.Grant = originalGrant
Runtime.update(s2, r2)
Runtime.update(s2, r2)
assert(c2.grants == 1 and c2.warnings == 0)

-- Exercise the real menu selection + Undo methods, not a second state machine.
local source = fs.readFile("src/Client/UI/Menus/PowerChoiceMenu.lua")
local function method(name)
    local start = assert(source:find("function PowerChoiceMenu:" .. name .. "(", 1, true))
    local finish = source:find("\nfunction PowerChoiceMenu:", start + 1, true) or #source
    local code = "local PowerChoiceMenu = {}; local MAX_SLOTS = 6\n"
        .. source:sub(start, finish - 1)
        .. "\nreturn PowerChoiceMenu."
        .. name
    return luau.load(code)()
end
local menu = {
    owned = { magnet = true },
    slots = { magnet = 1 },
    staged = {},
    pendingPower = 0,
    pendingSlots = 2,
    _isRangeCatalog = function()
        return false
    end,
    _effectiveSlots = function(self)
        return 1 + #self.staged
    end,
    _remainingSlots = function(self)
        return self.pendingSlots - #self.staged
    end,
    _render = function() end,
    _onRow = method("_onRow"),
    _undo = method("_undo"),
}
menu:_onRow("magnet")
assert(menu:_remainingSlots() == 1)
menu:_onRow("magnet")
assert(menu:_remainingSlots() == 0)
menu:_undo()
assert(menu:_remainingSlots() == 1)
menu:_undo()
assert(menu:_remainingSlots() == 2)
-- Deploying an existing egg is the intentional no-money escape hatch.
local mergeSource = fs.readFile("src/Server/Services/MergeEggPrototypeService.lua")
local start =
    assert(mergeSource:find("function MergeEggPrototypeService:_tutorialUpgradeEggsDone(", 1, true))
local finish = assert(mergeSource:find("\nfunction MergeEggPrototypeService:", start + 1, true))
local done = luau.load(
    "local MergeEggPrototypeService = {}\n"
        .. mergeSource:sub(start, finish - 1)
        .. "\nreturn MergeEggPrototypeService._tutorialUpgradeEggsDone"
)()
assert(not done({}, { eggsCreated = 2 }))
assert(done({}, { eggsCreated = 0, eggsPlaced = 1 }))
assert(done({}, { eggsCreated = 0, eggsMerged = 1 }))
assert(done({}, { baseEggTier = 2, upgradeBeatBaseEggTier = 1 }))
-- The real offline start method must reject an incomplete locked profile before
-- reconciliation/migration, actor creation, or purchases. No real accounts are loaded.
local offlineDeps = {
    MergePowerLessons = Lessons,
    MergeOfflineLease = pure("src/Shared/Game/MergeOfflineLease.lua"),
    Locations = {
        getPackage = function()
            return {}
        end,
    },
}
local offline = luau.load(fs.readFile("src/Server/Services/MergeOfflineService.lua"), {
    environment = {
        game = {
            GetService = function(_, id)
                return node(id)
            end,
        },
        script = node("script"),
        require = function(path)
            return offlineDeps[tostring(path):match("([^.]+)$")] or {}
        end,
    },
})()
local ended, released = 0, 0
local profile = {
    Data = { GameData = { MergePowerLessons = { unlocked = true } } },
    IsActive = function()
        return true
    end,
    EndSession = function()
        ended += 1
    end,
    Reconcile = function()
        error("incomplete profiles must not reach migration")
    end,
}
local service = setmetatable({
    _config = { logout_grace_seconds = 1 },
    _status = function(_, key, value)
        assert(key == "LastReason" and value == "onboarding_incomplete")
    end,
    _presenceUpdate = function(_, _, transform)
        released += 1
        transform({ kind = "offline", token = "test", expires = os.time() + 10 })
    end,
}, { __index = offline })
assert(not service:_startWorker(-1, "test", profile, "test", {}))
assert(ended == 1 and released == 1)
profile.Data.GameData.MergeDefense = { tutorial_completed = true }
profile.Reconcile = function()
    error("eligible_profile_reached_normal_start")
end
local ok, err = pcall(service._startWorker, service, -1, "test", profile, "test", {})
assert(not ok and tostring(err):find("eligible_profile_reached_normal_start", 1, true))
assert(ended == 1 and released == 1)
print(
    "PASS: actual lesson runtime, grants/retries/isolation/graduate skips, real menu Pick/Undo, no-money placement fallback, full-chunk compilation"
)
