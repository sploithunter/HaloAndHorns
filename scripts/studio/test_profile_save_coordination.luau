-- Production DataService save functions with a deterministic fake backend. No DataStore calls.
local source = game.ServerScriptService.Server.Services.DataService.Source
local first = assert(source:find("function DataService:_getSaveState(player)", 1, true))
local last = assert(source:find("function DataService:LoadProfile(player)", first, true))
local cfg = require(game.ReplicatedStorage.Configs.profile_persistence)
local function signal()
    local callbacks = {}
    return {
        Connect = function(_, fn)
            local conn = { Connected = true }
            function conn:Disconnect()
                self.Connected = false
            end
            callbacks[conn] = fn
            return conn
        end,
        Fire = function(_, value)
            for conn, fn in pairs(table.clone(callbacks)) do
                if conn.Connected then
                    fn(value)
                end
            end
        end,
    }
end
local function copy(value)
    if type(value) ~= "table" then
        return value
    end
    local result = {}
    for key, child in pairs(value) do
        result[key] = copy(child)
    end
    return result
end
local function fixture()
    local now, serial, pending, threads, warnings = 0, 0, {}, {}, 0
    local fakeTask = {
        delay = function(seconds, callback)
            pending[#pending + 1] = { at = now + seconds, callback = callback }
        end,
        wait = function()
            coroutine.yield()
        end,
    }
    local clock = function()
        return now
    end
    local service = assert(
        loadstring(
            "local task, tick, ProfileStore, HttpService, DEFAULT_SAVE_DEBOUNCE_SECONDS, CRITICAL_SAVE_DEBOUNCE_SECONDS, PERIODIC_SAVE_SECONDS, SAVE_CONFIRM_TIMEOUT_SECONDS = ...\nlocal DataService = {}\n"
                .. source:sub(first, last - 1)
                .. "\nreturn DataService"
        )
    )(
        fakeTask,
        clock,
        { DataStoreState = "Access" },
        {
            GenerateGUID = function()
                serial += 1
                return "request-" .. serial
            end,
        },
        cfg.ordinary_debounce_seconds,
        cfg.critical_debounce_seconds,
        cfg.periodic_save_seconds,
        cfg.confirmation_timeout_seconds
    )
    local who = { Name = "Fake", Parent = true }
    local profile =
        { Data = { Coins = 0 }, Active = true, OnAfterSave = signal(), snapshots = {}, saves = 0 }
    function profile:IsActive()
        return self.Active
    end
    function profile:Save()
        self.saves += 1
        if self.throw then
            error("fake backend start failure")
        end
        self.snapshots[self.saves] = copy(self.Data)
    end
    service.Profiles, service.SaveRequests, service.PersistenceWarningsIssued =
        { [who] = profile }, {}, {}
    service._logger = {
        Debug = function() end,
        Error = function() end,
        Warn = function()
            warnings += 1
        end,
    }
    local function advance(seconds)
        for _ = 1, seconds do
            now += 1
            local work = pending
            pending = {}
            for _, job in ipairs(work) do
                if job.at <= now then
                    job.callback()
                else
                    pending[#pending + 1] = job
                end
            end
            for _, thread in ipairs(threads) do
                if coroutine.status(thread) == "suspended" then
                    local ok, err = coroutine.resume(thread)
                    assert(ok, err)
                end
            end
        end
    end
    local function barrier()
        local result = {}
        local thread = coroutine.create(function()
            result.ok, result.reason = service:SaveAndConfirm(who, "ownership")
        end)
        threads[#threads + 1] = thread
        local ok, err = coroutine.resume(thread)
        assert(ok, err)
        return result
    end
    return service, who, profile, advance, barrier, function()
        return warnings
    end
end

do
    local service, who, profile, advance, _, warnings = fixture()
    service:RequestSave(who, "initial", { debounceSeconds = 0 })
    for _ = 1, 100 do
        profile.Data.Coins += 1
        service:RequestSave(who, "currency")
        advance(1)
    end
    assert(profile.saves == 1, "Timeout spawned overlapping manual writers")
    assert(warnings() == 1, "Unconfirmed save spammed warnings")
    assert(service.SaveRequests[who].inFlight, "Timed-out operation was treated as cancelled")
    profile.OnAfterSave:Fire(profile.snapshots[1])
    assert(service.SaveRequests[who].dirty, "Changes during a pending write were lost")
    advance(cfg.ordinary_debounce_seconds)
    assert(
        profile.saves == 2 and profile.snapshots[2].Coins == 100,
        "Follow-up was not coalesced/preserved"
    )
    profile.OnAfterSave:Fire(profile.snapshots[1])
    assert(
        service.SaveRequests[who].lastConfirmedRequestId == 1,
        "Old snapshot confirmed a newer write"
    )
    profile.OnAfterSave:Fire(profile.snapshots[2])
    assert(
        service.SaveRequests[who].lastConfirmedRequestId == 2,
        "Matching follow-up did not confirm"
    )
end
do
    local service, who, profile, advance, barrier = fixture()
    local firstBarrier = barrier()
    profile.OnAfterSave:Fire({ Coins = 0 })
    advance(cfg.confirmation_timeout_seconds + 1)
    assert(
        firstBarrier.ok == false and firstBarrier.reason == "save_confirm_timeout",
        "Timeout claimed durability"
    )
    assert(profile.saves == 1 and service.SaveRequests[who].inFlight)
    local nextBarrier = barrier()
    profile.OnAfterSave:Fire(profile.snapshots[1])
    assert(profile.saves == 2, "Critical queued request did not proceed after real confirmation")
    advance(1)
    assert(nextBarrier.ok == nil, "First write falsely confirmed the second ownership barrier")
    profile.OnAfterSave:Fire(profile.snapshots[2])
    advance(1)
    assert(nextBarrier.ok == true, "Exact second ownership barrier did not confirm")
end
do
    local service, who, profile, _, barrier = fixture()
    profile.throw = true
    service:RequestSave(who, "failed-start", { debounceSeconds = 0 })
    assert(not service.SaveRequests[who].inFlight and service.SaveRequests[who].dirty)
    profile.Active = false
    assert(barrier().ok == false, "Released profile accepted a save barrier")
end
return "PASS: 100 pending mutations/one writer, one timeout warning, late confirmation, dirty preservation, stale-snapshot rejection, exact critical barrier, failed start and release"
