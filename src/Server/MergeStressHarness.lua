-- Studio-only in-memory load fixture. Never acquires a source account's profile/lease.
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Harness = {}
Harness.__index = Harness

local function isolatedProfile(source)
    local ended, saved = Instance.new("BindableEvent"), Instance.new("BindableEvent")
    local active = true
    local profile = {
        Data = HttpService:JSONDecode(HttpService:JSONEncode(source)),
        OnSessionEnd = ended.Event,
        OnAfterSave = saved.Event,
    }
    function profile:IsActive()
        return active
    end
    function profile:Reconcile() end
    function profile:Save()
        self.LastSavedData = HttpService:JSONDecode(HttpService:JSONEncode(self.Data))
        saved:Fire()
    end
    function profile:EndSession()
        if not active then
            return
        end
        self:Save()
        active = false
        ended:Fire()
        ended:Destroy()
        saved:Destroy()
    end
    return profile
end

function Harness.new(service)
    assert(RunService:IsStudio(), "stress harness is Studio-only")
    return setmetatable({ service = service, ids = {}, errors = {} }, Harness)
end

function Harness:stop()
    self.running = false
    if self.connection then
        self.connection:Disconnect()
        self.connection = nil
    end
    for _, id in ipairs(self.ids) do
        self.service:_stop(id, "stress_finished")
    end
    table.clear(self.ids)
end

function Harness:status()
    local rows = {}
    for _, id in ipairs(self.ids) do
        local worker = self.service._workers[id]
        if worker then
            local record = worker.runtime and worker.runtime.merge:_recordFor(worker.actor)
            table.insert(rows, {
                id = id,
                sourceUserId = worker.stressSourceUserId,
                bay = worker.bayId,
                level = worker.actor:GetAttribute("Level"),
                wave = record and record.waveIndex,
                busy = worker.busy,
                fixture = worker.fixture,
            })
        end
    end
    return { running = self.running == true, workers = rows, errors = self.errors }
end

-- Inclusive wall time (may contain yielding work), not MicroProfiler CPU attribution.
-- Bounded and self-restoring; never enabled in live servers.
function Harness:profile(selection)
    assert(not self.profiling, "profile capture already running")
    self.profiling = true
    local counters, originals = {}, {}
    local selected = selection
        or {
            PetFollowService = { "_tick", "_tickPrincipal", "_mine", "_findBreakable" },
            EnemyService = {
                "_combatTick",
                "_assignPetTargets",
                "_supportPass",
                "_regenPass",
                "_enemyRegenPass",
                "_dotPass",
                "_enemyPetDotPass",
                "_contagionPass",
                "_auraDamagePass",
                "_enemyHealPass",
                "_supportCleansePass",
                "_bossBreakoutPass",
                "_enforceLockouts",
                "_refreshGroundExclude",
                "_patrolTick",
                "_engageEnemy",
            },
            CombatService = { "ResolvePetDamage", "ResolveEnemyDamage" },
        }
    local merge = self.service._modules.MergeEggPrototypeService
    local services = {
        PetFollowService = merge._petFollowService,
        EnemyService = merge._enemyService,
        CombatService = merge._petFollowService and merge._petFollowService:_combatService(),
    }
    for serviceName, methods in pairs(selected) do
        local service = services[serviceName]
        for _, method in ipairs(methods) do
            local original = service and service[method]
            if type(original) == "function" then
                local key = serviceName .. "." .. method
                local counter = { calls = 0, seconds = 0, max = 0 }
                counters[key] = counter
                local function wrapped(...)
                    local started = os.clock()
                    local result = table.pack(pcall(original, ...))
                    local elapsed = os.clock() - started
                    counter.calls += 1
                    counter.seconds += elapsed
                    counter.max = math.max(counter.max, elapsed)
                    if not result[1] then
                        error(result[2], 0)
                    end
                    return table.unpack(result, 2, result.n)
                end
                service[method] = wrapped
                table.insert(originals, { service, method, original, wrapped })
            end
        end
    end
    task.wait(self.service._config.studio_stress.profile_seconds)
    for _, row in ipairs(originals) do
        if row[1][row[2]] == row[4] then
            row[1][row[2]] = row[3]
        end
    end
    self.profiling = false
    return counters
end

function Harness:start(sources)
    assert(not self.running, "stress already running")
    assert(type(sources) == "table" and #sources > 0, "source snapshots required")
    for _, source in ipairs(sources) do
        assert(type(source) == "table" and type(source.data) == "table", "profile data required")
        assert(type(source.userId) == "number" and source.userId > 0, "avatar source ID required")
    end
    local service = self.service
    local cfg = service._config.studio_stress
    assert(cfg.first_fixture_user_id < 0, "fixture IDs must be negative")
    service._filling = false
    service:_status("Filling", false)
    local empty, occupied = {}, 0
    for bayId, bay in pairs(service._modules.MergeEggPrototypeService._realm:GetBays()) do
        if bay.ownerUserId then
            occupied += 1
        else
            table.insert(empty, bayId)
        end
    end
    table.sort(empty)
    local count = math.min(#empty, math.max(0, cfg.maximum_occupied_bays - occupied))
    assert(count > 0, "no empty stress bays")
    self.running = true
    self.deadline = os.clock() + cfg.duration_seconds
    for index = 1, count do
        if not self.running then
            break
        end
        local source = sources[(index - 1) % #sources + 1]
        local id = cfg.first_fixture_user_id - index + 1
        assert(not service._workers[id], "stress ID already occupied")
        table.insert(self.ids, id)
        local profile = isolatedProfile(source.data)
        local ok, started = xpcall(function()
            return service:_startWorker(id, empty[index], profile, "stress_fixture", {
                expires = os.time() + cfg.duration_seconds,
            }, source.userId)
        end, debug.traceback)
        if not ok or not started then
            table.insert(self.errors, tostring(started))
            service:_stop(id, "stress_start_failed")
            if profile:IsActive() then
                profile:EndSession()
            end
        elseif service._workers[id] then
            service._workers[id].stressSourceUserId = source.userId
        end
    end
    if not self.running then
        self:stop()
        return self:status()
    end
    local elapsed = 0
    local tickSeconds = service._modules.MergeAutoplayService._config.tick_seconds
    self.connection = RunService.Heartbeat:Connect(function(dt)
        elapsed += dt
        if elapsed < tickSeconds then
            return
        end
        local delta = elapsed
        elapsed = 0
        if os.clock() >= self.deadline then
            task.spawn(function()
                self:stop()
            end)
            return
        end
        for _, id in ipairs(self.ids) do
            local worker = service._workers[id]
            if worker and not worker.busy and not worker.stopping and worker.runtime then
                worker.busy = true
                task.spawn(function()
                    worker.thread = coroutine.running()
                    local ok, alive, why = xpcall(function()
                        return worker.runtime:step(delta)
                    end, debug.traceback)
                    worker.busy = false
                    if service._workers[id] == worker then
                        worker.operationFinished:Fire()
                    end
                    if not ok or not alive then
                        table.insert(self.errors, tostring(ok and why or alive))
                        service:_stop(id, "stress_runtime_stopped")
                    end
                end)
            end
        end
    end)
    return self:status()
end

return Harness
