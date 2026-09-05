-- Exercise production join binding with a simulated delayed profile and transient full realm.
-- Pure fake Players/signals/scheduler: never claims a real bay or loads/saves real profiles.
local source = game.ServerScriptService.Server.Services.MergeEggPrototypeService.Source
local first =
    assert(source:find("function MergeEggPrototypeService:_bindMergePlaceJoin()", 1, true))
local last = assert(source:find("function MergeEggPrototypeService:Start()", first, true))
local function signal()
    local callbacks = {}
    return {
        Connect = function(_, fn)
            callbacks[#callbacks + 1] = fn
        end,
        Fire = function(_, ...)
            for _, fn in ipairs(callbacks) do
                fn(...)
            end
        end,
    }
end
local players, threads, now = {}, {}, 0
local playerService = {
    PlayerAdded = signal(),
    PlayerRemoving = signal(),
    GetPlayers = function()
        return players
    end,
}
local function player(name)
    local attrs = {}
    local who = { Name = name, Parent = playerService, CharacterAdded = signal() }
    who.Character = {
        FindFirstChild = function()
            return {}
        end,
    }
    function who:GetAttribute(key)
        return attrs[key]
    end
    function who:SetAttribute(key, value)
        attrs[key] = value
    end
    players[#players + 1] = who
    return who
end
local delayed, full, respawned = player("Delayed"), player("Full"), player("Respawned")
local function spawn(fn)
    local thread = coroutine.create(fn)
    threads[#threads + 1] = thread
    local ok, err = coroutine.resume(thread)
    assert(ok, err)
end
local runtime = assert(
    loadstring(
        "local Players, RunService, task, os, game = ...\nlocal MergeEggPrototypeService = {}\n"
            .. source:sub(first, last - 1)
            .. "\nreturn MergeEggPrototypeService"
    )
)(
    playerService,
    { Heartbeat = {
        Wait = function()
            coroutine.yield()
        end,
    } },
    { spawn = spawn, defer = spawn },
    {
        clock = function()
            return now
        end,
    },
    { PlaceId = game.PlaceId }
)
local configModule = game.ReplicatedStorage.Configs.merge_egg_prototype
local cfg = assert(loadstring("local script = ...\n" .. configModule.Source))(configModule)
runtime.__index = runtime
local ready, attempts, warnings = { [full] = true }, {}, 0
local service = setmetatable({
    _config = cfg,
    _activeByPlayer = {},
    _dataService = {
        IsDataLoaded = function(_, who)
            return ready[who] == true
        end,
    },
}, runtime)
function service:_isDedicatedMergePlace()
    return true
end
function service:_hasPreviewAccess()
    return true
end
function service:_analyticsFailure() end
function service:_log()
    warnings += 1
end
function service:_mergeDefenseProgress(who)
    assert(ready[who], "Touched unloaded profile")
end
function service:_begin(who)
    attempts[who] = (attempts[who] or 0) + 1
    if who == full and attempts[who] <= 3 then
        return false, "realm_full"
    end
    if who == delayed and attempts[who] == 1 then
        return false, "world_or_character_unavailable"
    end
    self._activeByPlayer[who] = { character = who.Character }
    return true
end
service:_bindMergePlaceJoin()
local function advance(seconds)
    for _ = 1, seconds do
        now += 1
        local count = #threads
        for i = 1, count do
            if coroutine.status(threads[i]) == "suspended" then
                local ok, err = coroutine.resume(threads[i])
                assert(ok, err)
            end
        end
    end
end
advance(10)
respawned.Character = {
    FindFirstChild = function()
        return {}
    end,
}
respawned.CharacterAdded:Fire()
advance(35)
assert(not attempts[delayed] and not attempts[respawned], "Entered before data loaded")
assert(delayed:GetAttribute("MergeJoinStatus") == "data", "Late profile lacks user guidance")
assert(service._activeByPlayer[full], "Full realm did not retry")
ready[delayed], ready[respawned] = true, true
advance(5)
assert(service._activeByPlayer[delayed], "Profile after 30 seconds never claimed")
assert(
    service._activeByPlayer[respawned].character == respawned.Character,
    "Stale respawn worker entered"
)
assert(attempts[respawned] == 1, "Duplicate respawn worker")
assert(delayed:GetAttribute("MergeJoinStatus") == nil, "Join guidance never clears")
local previous = attempts[delayed]
service._activeByPlayer[delayed] = nil
advance(20)
assert(attempts[delayed] == previous, "Auto-join reclaimed a bay after deliberate departure")
assert(warnings <= 3, "Repeated wait log spam")
return "PASS: 45-second profile delay, automatic retry, full realm recovery, respawn cancellation, one entry, cleared guidance, no reclaim after departure"
