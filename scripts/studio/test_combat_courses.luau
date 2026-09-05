-- Edit-only isolated fixtures. Execute actual server methods without touching player saves.
local services = game.ServerScriptService.Server.Services
local configs = game.ReplicatedStorage.Configs
local shared = game.ReplicatedStorage.Shared.Game
local function sourceModule(module)
    return assert(loadstring(module.Source))()
end
local Courses = sourceModule(shared.CombatCourses)
local Flow = sourceModule(shared.TutorialFlow)
local cfg = sourceModule(configs.combat_courses)
local catalog = sourceModule(configs.combat_tutorial)
local events = {}
local function fire(player, name, ctx)
    table.insert(events, { player = player.Name, name = name, context = ctx })
end
local function method(module, class, name, prelude, ...)
    local source = module.Source
    local first = assert(source:find("function " .. class .. ":" .. name .. "(", 1, true))
    local last = source:find("\nfunction " .. class .. ":", first + 1, true) or #source + 1
    return assert(
        loadstring(
            (prelude or "")
                .. "\nlocal "
                .. class
                .. "={}\n"
                .. source:sub(first, last - 1)
                .. "\nreturn "
                .. class
                .. "."
                .. name
        )
    )(...)
end
local courseConfigs, definitions = {}, {}
for _, definition in ipairs(cfg.courses) do
    courseConfigs[definition.id] = Courses.project(catalog, definition)
    definitions[definition.id] = definition
end
local profiles, levels, awards, saves, exits = {}, {}, {}, 0, 0
local service = {
    _config = catalog,
    _courses = cfg,
    _courseConfigs = courseConfigs,
    _courseDefinitions = definitions,
    _activeCourses = {},
    _rewardInFlight = {},
    _dataService = {
        GetData = function(_, player)
            return profiles[player]
        end,
        IsDataLoaded = function()
            return true
        end,
        RequestSave = function()
            saves += 1
        end,
    },
}
for _, name in ipairs({
    "_courseId",
    "_courseConfig",
    "_progressKey",
    "_ensureProgress",
    "_onEvent",
    "_applyCompletionLevelGrant",
    "_applyCompletionReward",
    "_prepareLiveTrack",
}) do
    service[name] = method(
        services.CombatTutorialService,
        "CombatTutorialService",
        name,
        "local CombatCourses, TutorialFlow, fireGameEvent = ...",
        Courses,
        Flow,
        fire
    )
end
local progression = {
    GetEarnedLevel = function(_, player)
        return levels[player]
    end,
    EnsureEarnedLevel = function(_, player, target)
        levels[player] = math.max(levels[player], target)
        -- Completion listeners can re-enter during a grant. The runtime guard must hold.
        service:_ensureProgress(player)
        return { ok = true }
    end,
}
service._playerProgressionService = progression
local failToken = false
service._rewardService = {
    Grant = function(_, player, bundle)
        local items = {}
        for _, item in ipairs(bundle.items or {}) do
            if failToken then
                table.insert(items, {})
            else
                awards[player][item.id] = (awards[player][item.id] or 0) + item.qty
                table.insert(items, { uid = item.id })
            end
        end
        return { ok = true, granted = { items = items } }
    end,
}
function service:_grantPotions() end
function service:_syncCombatRank()
    return false
end
function service:_returnToExit()
    exits += 1
end
function service:_applyStepSideEffects() end
function service:_push() end
function service:_ensureWatchers() end
local function playerAt(level)
    local attrs = { Level = level, InCombatTutorial = true }
    local player = { Parent = true, Name = "CourseFixture" .. tostring(level) }
    function player:GetAttribute(key)
        return attrs[key]
    end
    function player:SetAttribute(key, value)
        attrs[key] = value
    end
    profiles[player], levels[player], awards[player] = {}, level, {}
    service:_ensureProgress(player)
    return player
end
for _, level in ipairs({ 1, 28, 49, 50 }) do
    local player = playerAt(level)
    local data = profiles[player]
    for _, definition in ipairs(cfg.courses) do
        local before = levels[player]
        service._activeCourses[player] = { id = definition.id }
        data[definition.key].step = #courseConfigs[definition.id].steps
        service:_onEvent(player, "combat_tutorial_advance", {})
        assert(data[definition.key].done == true, "Course did not complete")
        assert(levels[player] == math.min(50, before + 1), "Incorrect level award")
        assert(player:GetAttribute("CombatTutorialDone") == true, "Basic unlock was lost")
        service:_onEvent(player, "combat_tutorial_advance", {})
        service:_ensureProgress(player)
        assert(levels[player] == math.min(50, before + 1), "Duplicate level award")
    end
    assert(
        awards[player].double_xp_token == 1 and awards[player].double_coins_token == 1,
        "Tokens not exactly once"
    )
    service._activeCourses[player] = { id = "basic", replay = true }
    service:_prepareLiveTrack(player, true)
    assert(data.CombatTutorial.done, "Replay relocked Basic")
    data.CombatTutorialReplay.step = #courseConfigs.basic.steps
    local before = levels[player]
    service:_onEvent(player, "combat_tutorial_advance", {})
    assert(levels[player] == before and data.CombatTutorial.done, "Replay granted or relocked")
end
-- Independent profiles/course cursors cannot overwrite one another; failed token grants retry.
local first, second = playerAt(10), playerAt(20)
local a, b = profiles[first], profiles[second]
a.CombatTutorial.done, a.CombatTutorialRewardGranted = true, true
a.CombatTutorial.completionLevelGranted = true
service._activeCourses[first] = { id = "advanced_1" }
a.CombatTutorialAdvanced1.step = #courseConfigs.advanced_1.steps
failToken = true
service:_onEvent(first, "combat_tutorial_advance", {})
assert(levels[first] == 11 and not a.CombatTutorialAdvanced1RewardGranted)
assert(b.CombatTutorial.step == 1 and not b.CombatTutorial.done, "Other player's track changed")
failToken = false
service:_ensureProgress(first)
service:_ensureProgress(first)
assert(
    awards[first].double_xp_token == 1 and levels[first] == 11,
    "Retry duplicated or lost reward"
)
-- Deferred level target is fixed at completion, never re-derived as current+1 on retry.
service._activeCourses[second] = nil
b.CombatTutorial.step = #courseConfigs.basic.steps
service._playerProgressionService = nil
service:_onEvent(second, "combat_tutorial_advance", {})
assert(b.CombatTutorial.completionLevelTarget == 21 and levels[second] == 20)
service._playerProgressionService = progression
service:_ensureProgress(second)
service:_ensureProgress(second)
assert(levels[second] == 21 and b.CombatTutorial.completionLevelGranted)
-- Execute real squad restoration: it must never clear course progress or reward receipts.
service._restoreLoanedSquad = method(
    services.CombatTutorialService,
    "CombatTutorialService",
    "_restoreLoanedSquad",
    "local TutorialSquad, PetLockout = ...",
    sourceModule(shared.TutorialSquad),
    sourceModule(shared.PetLockout)
)
function service:_loanedLoadout(player)
    return profiles[player], profiles[player].CombatTutorialLoadout
end
function service:_recoverOwnedSquad() end
a.CombatTutorialLoadout = { active = true, savedEquipped = {}, grants = {} }
service:_restoreLoanedSquad(first)
assert(
    a.CombatTutorial.done
        and a.CombatTutorialAdvanced1.done
        and a.CombatTutorialAdvanced1RewardGranted
)
assert(a.CombatTutorialLoadout == nil)
assert(exits == 18, "A course did not return to the game")
return "PASS: actual completion/replay/restore methods; Basic unlock; capped +1 awards; one token per advanced course; reentrant and failed-grant retries; independent concurrent profiles"
