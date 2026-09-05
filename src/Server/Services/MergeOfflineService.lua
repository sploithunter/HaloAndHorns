-- Global offline pool + exclusive account sessions. Real Players always have priority.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local DataStoreService = game:GetService("DataStoreService")
local MessagingService = game:GetService("MessagingService")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Lease = require(ReplicatedStorage.Shared.Game.MergeOfflineLease)
local Adapter = require(ReplicatedStorage.Shared.Game.NonPreemptiveProfileStore)
local Locations = require(ReplicatedStorage.Shared.Locations)
local ProfileStore = Locations.getPackage("ProfileStore")
local Actors = require(script.Parent.Parent.OfflineActors)
local Runtime = require(script.Parent.Parent.MergeOfflineRuntime)
local Service = {}

function Service:Init()
    self._config = self._modules.ConfigLoader:LoadConfig("merge_offline")
    self._data = self._modules.DataService
    self._workers, self._online, self._loading = {}, {}, {}
    self._seeds, self._blocked = {}, {}
    local internal = self._modules.ConfigLoader:LoadConfig("internal_accounts")
    for _, id in ipairs(Lease.seeds(internal, self._config)) do
        self._seeds[id] = true
    end
    for _, id in ipairs(self._config.excluded_user_ids) do
        self._blocked[id] = true
    end
    local monetization = self._modules.ConfigLoader:LoadConfig("monetization")
    self._passId = monetization.product_id_mapping[self._config.pass]
    self._presence = MemoryStoreService:GetHashMap(self._config.presence_map)
    self._pool = DataStoreService:GetOrderedDataStore(self._config.pool_store)
    self._data:RegisterBeforeProfileLoad(function(player)
        self:_login(player)
    end)
end

function Service:_status(key, value)
    if self._folder then
        self._folder:SetAttribute(key, value)
    end
end

function Service:_presenceUpdate(id, transform)
    local ok, value = pcall(function()
        return self._presence:UpdateAsync(tostring(id), transform, self._config.lease_seconds)
    end)
    if not ok then
        self:_status("LastError", "presence_unavailable")
        return nil
    end
    return value
end

function Service:_login(player)
    local token = HttpService:GenerateGUID(false)
    self._online[player] = token
    self._loading[player.UserId] = nil
    self:_stop(player.UserId, "account_logged_in")
    self:_presenceUpdate(player.UserId, function(value)
        return Lease.online(value, token, os.time(), self._config.lease_seconds)
    end)
    pcall(function()
        MessagingService:PublishAsync(self._config.login_topic, player.UserId)
    end)
end

function Service:_eligible(id)
    if self._blocked[id] or Players:GetPlayerByUserId(id) then
        return false
    end
    if self._seeds[id] then
        return true
    end
    local ok, owns =
        pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, id, self._passId)
    return ok and owns == true
end

function Service:_register(player, confirmedPurchase)
    if self._blocked[player.UserId] then
        return
    end
    local ok, owns = pcall(
        MarketplaceService.UserOwnsGamePassAsync,
        MarketplaceService,
        player.UserId,
        self._passId
    )
    if self._seeds[player.UserId] or confirmedPurchase == true or (ok and owns) then
        pcall(function()
            self._pool:SetAsync(
                tostring(player.UserId),
                math.random(1, self._config.pool_sort_range)
            )
        end)
    end
end

function Service:_receipt(player)
    local data = self._data:GetData(player)
    local summary = data and data[self._config.profile_summary_key]
    if not summary or not summary.lastEnded or summary.lastEnded == summary.presented then
        return
    end
    local cfg = self._config
    player:SetAttribute(
        "OfflineMergeReceipt",
        HttpService:JSONEncode({
            awardId = "offline:" .. tostring(summary.lastEnded),
            title = cfg.summary_title,
            name = string.format(
                cfg.summary_details,
                cfg.summary_body,
                summary.xp or 0,
                summary.gems or 0,
                math.floor((summary.seconds or 0) / 60)
            ),
        })
    )
    -- This acknowledges presentation only. Rewards already reside in this exclusively owned
    -- canonical profile; no second add/claim transaction can duplicate them.
    summary.presented = summary.lastEnded
    summary.xp, summary.gems, summary.seconds = 0, 0, 0
    self._data:RequestSave(player, "offline_receipt")
end

function Service:_candidates()
    local ids, seen = {}, {}
    local function add(id)
        if id and not seen[id] and not self._blocked[id] then
            seen[id] = true
            ids[#ids + 1] = id
        end
    end
    -- Random pivot + wrap selects across the entire persistent population, not only page one.
    local pivot = math.random(1, self._config.pool_sort_range)
    local ok, page = pcall(function()
        return self._pool:GetSortedAsync(true, self._config.selection_count, pivot):GetCurrentPage()
    end)
    if ok then
        for _, row in ipairs(page) do
            add(tonumber(row.key))
        end
    end
    if #ids < self._config.selection_count then
        local wrapOk, wrap = pcall(function()
            return self._pool
                :GetSortedAsync(true, self._config.selection_count, nil, pivot)
                :GetCurrentPage()
        end)
        if wrapOk then
            for _, row in ipairs(wrap) do
                add(tonumber(row.key))
            end
        end
    end
    for id in pairs(self._seeds) do
        add(id)
    end
    for i = #ids, 2, -1 do
        local j = math.random(i)
        ids[i], ids[j] = ids[j], ids[i]
    end
    self:_status("Candidates", #ids)
    return ids
end

function Service:_store()
    if self._profileStore then
        return self._profileStore
    end
    if ProfileStore.DataStoreState ~= "Access" then
        return nil
    end
    local store = ProfileStore.New(self._data.ProfileStore.Name, self._data.ProfileStore.template)
    if not store.is_ready or not store.data_store then
        return nil
    end
    self._backend = Adapter.wrap(store.data_store)
    store.data_store = self._backend
    self._profileStore = store
    return store
end

function Service:_acquire(id, bayId)
    if self._workers[id] or self._loading[id] or not self:_eligible(id) then
        return false
    end
    local store = self:_store()
    if not store then
        return false
    end
    local key = "Player_" .. tostring(id)
    local screened, available = pcall(self._backend.canAcquire, self._backend, key)
    if not screened or not available then
        return false
    end
    local token = HttpService:GenerateGUID(false)
    self._loading[id] = token
    local lease = self:_presenceUpdate(id, function(value)
        return Lease.acquire(value, token, os.time(), self._config.lease_seconds)
    end)
    if not lease or lease.token ~= token then
        self._loading[id] = nil
        return false
    end
    local deadline = os.clock() + self._config.load_timeout_seconds
    self._backend:begin(key)
    local function cancelled()
        return self._closing
            or self._loading[id] ~= token
            or Players:GetPlayerByUserId(id) ~= nil
            or os.clock() >= deadline
            or self._backend:denied(key)
    end
    local ok, profile = pcall(function()
        return store:StartSessionAsync(key, { Cancel = cancelled })
    end)
    if not ok or not profile or cancelled() then
        if ok and profile then
            profile:EndSession()
        end
        self._loading[id] = nil
        self:_presenceUpdate(id, function(value)
            return Lease.release(value, token, os.time(), self._config.logout_grace_seconds)
        end)
        return false
    end
    self._loading[id] = nil
    local started, result = xpcall(function()
        return self:_startWorker(id, bayId, profile, token, lease)
    end, debug.traceback)
    if not started then
        self:_status("LastError", tostring(result))
        self:_stop(id, "startup_error")
        if profile:IsActive() then
            profile:EndSession()
        end
        return false
    end
    return result
end

function Service:_startWorker(id, bayId, profile, token, lease, fixtureAvatar)
    profile:Reconcile()
    self._data:MigrateProfile(profile)
    local nameOk, username = pcall(Players.GetNameFromUserIdAsync, Players, fixtureAvatar or id)
    username = nameOk and username or tostring(id)
    if not fixtureAvatar then
        lease = self:_presenceUpdate(id, function(value)
            return Lease.renew(value, token, os.time(), self._config.lease_seconds)
        end)
    end
    if
        not lease
        or lease.token and lease.token ~= token
        or not profile:IsActive()
        or Players:GetPlayerByUserId(id)
        or self._closing
    then
        if profile:IsActive() then
            profile:EndSession()
        end
        return false
    end
    local actor = Actors.create(
        id,
        self._config.name_prefix .. username,
        username .. self._config.display_suffix,
        self._folder
    )
    local worker = {
        actor = actor,
        profile = profile,
        token = token,
        bayId = bayId,
        busy = true,
        thread = coroutine.running(),
        expires = lease.expires,
        started = os.time(),
        nextRenew = os.clock() + self._config.heartbeat_seconds,
        startCoins = tonumber(profile.Data.Currencies.hall_coins) or 0,
        startGems = tonumber(profile.Data.Currencies.gems) or 0,
        startXP = tonumber(profile.Data.Stats.Experience) or 0,
        fixture = fixtureAvatar ~= nil,
    }
    self._workers[id] = worker
    self:_updateCount()
    self._data.Profiles[actor] = profile
    profile.OnSessionEnd:Connect(function()
        self:_stop(id, "profile_released")
    end)
    local built, reason = pcall(function()
        self._modules.PlayerProgressionService:_publish(actor)
        local bay = self._modules.MergeEggPrototypeService._realm:GetBay(bayId)
        assert(bay, "bay_missing")
        local character = self._modules.NpcPrincipalService:_buildCharacter({
            name = actor.Name,
            display_name = actor.DisplayName,
            avatar_user_id = fixtureAvatar or id,
            level = actor:GetAttribute("Level"),
            walk_speed = self._config.walk_speed,
        }, bay:GetPivot())
        if self._workers[id] ~= worker or worker.stopping or Players:GetPlayerByUserId(id) then
            character:Destroy()
            error("login_during_build")
        end
        actor.Character = character
        character:SetAttribute("OfflineUserId", id)
        character.Parent = workspace
        local root = character:FindFirstChild("HumanoidRootPart")
        if root then
            root.Anchored = false
            root:SetNetworkOwner(nil)
        end
        assert(
            self._workers[id] == worker and not Players:GetPlayerByUserId(id),
            "login_during_build"
        )
        worker.runtime = Runtime.new(self._modules, actor, self._config)
        local entered, why = worker.runtime:begin(bayId)
        assert(entered, why)
        local ownedBay = self._modules.MergeEggPrototypeService._realm:GetBays()[bayId]
        ownedBay.model:SetAttribute("MergeOfflineUserId", id)
        for _, fixture in ipairs(ownedBay.claimFixtures or {}) do
            fixture.prompt.Enabled = true
            fixture.prompt.ActionText = self._config.claim_action_text
        end
    end)
    worker.busy = false
    if not built then
        self:_status("LastError", tostring(reason))
        self:_stop(id, "startup_failed")
        return false
    end
    self:_status("LastStartedUserId", id)
    return true
end

function Service:_stop(id, reason)
    local worker = self._workers[id]
    if not worker or worker.stopping then
        return
    end
    worker.stopping = true
    -- Join/claim may arrive while a normal gameplay operation yields for model creation or
    -- pathfinding. Do not release its profile or bay until that operation has unwound.
    while worker.busy and worker.thread ~= coroutine.running() do
        task.wait()
    end
    -- Teardown is scoped by actor identity; a delayed cleanup cannot release a new claimant.
    if worker.runtime then
        local ok, err = xpcall(function()
            worker.runtime:stop()
        end, debug.traceback)
        if not ok then
            self:_status("LastError", tostring(err))
        end
    end
    local data = worker.profile.Data
    local summary = data[self._config.profile_summary_key] or {}
    summary.seconds = (tonumber(summary.seconds) or 0) + math.max(0, os.time() - worker.started)
    summary.xp = (tonumber(summary.xp) or 0)
        + math.max(0, (data.Stats.Experience or 0) - worker.startXP)
    summary.gems = (tonumber(summary.gems) or 0)
        + math.max(0, (data.Currencies.gems or 0) - worker.startGems)
    summary.lastEnded, summary.reason = os.time(), reason
    data[self._config.profile_summary_key] = summary
    local realm = self._modules.MergeEggPrototypeService._realm
    local bay = realm and realm:GetBays()[worker.bayId]
    if bay and bay.model:GetAttribute("MergeOfflineUserId") == id then
        bay.model:SetAttribute("MergeOfflineUserId", nil)
    end
    if bay and bay.claimant == worker.actor then
        realm:Release(worker.actor)
    end
    if worker.profile:IsActive() then
        worker.profile:EndSession()
    end
    local save = self._data.SaveRequests[worker.actor]
    if save and save.afterSaveConnection then
        save.afterSaveConnection:Disconnect()
    end
    self._data.SaveRequests[worker.actor], self._data.Profiles[worker.actor] = nil, nil
    self._data.PersistenceWarningsIssued[worker.actor] = nil
    self._modules.EconomyService.TransactionHistory[worker.actor] = nil
    self._modules.PlayerProgressionService._lastEarned[worker.actor] = nil
    self._modules.InventoryService:_onPlayerRemoving(worker.actor)
    worker.actor:Destroy()
    self._workers[id] = nil
    self:_updateCount()
    self:_status("LastStoppedUserId", id)
    self:_status("LastStopReason", reason)
    if worker.fixture then
        return
    end
    task.spawn(function()
        self:_presenceUpdate(id, function(value)
            return Lease.release(value, worker.token, os.time(), self._config.logout_grace_seconds)
        end)
    end)
end

function Service:_updateCount()
    local count = 0
    for _ in pairs(self._workers) do
        count += 1
    end
    self:_status("ActiveWorkers", count)
    return count
end

function Service:_fill()
    if not self._filling then
        return
    end
    local realm = self._modules.MergeEggPrototypeService._realm
    if not realm then
        return
    end
    local count, bayId = 0, nil
    for _ in pairs(self._workers) do
        count += 1
    end
    self:_status("ActiveWorkers", count)
    if count >= self._config.maximum_bays then
        return
    end
    for id, bay in pairs(realm:GetBays()) do
        if not bay.ownerUserId then
            bayId = id
            break
        end
    end
    if not bayId then
        return
    end
    local attempts = 0
    for _, id in ipairs(self:_candidates()) do
        if self._closing then
            return
        end
        if not self._workers[id] and not Players:GetPlayerByUserId(id) then
            attempts += 1
        end
        if self:_acquire(id, bayId) then
            return
        end
        if attempts >= self._config.acquisition_attempts then
            return
        end
    end
end

function Service:Start()
    local cfg = self._config
    self._folder = Instance.new("Folder")
    self._folder.Name = cfg.namespace
    self._folder.Parent = ServerStorage
    self:_status("Enabled", cfg.enabled)
    self:_status("StudioEnabled", cfg.studio_enabled)
    if RunService:IsStudio() then
        local control = Instance.new("BindableFunction")
        control.Name = "MergeOfflineStudioControl"
        control.Parent = ServerStorage
        control.OnInvoke = function(action, sourcePlayer)
            local id = cfg.studio_fixture_user_id
            if action == "fixture_start" then
                assert(
                    typeof(sourcePlayer) == "Instance" and sourcePlayer:IsA("Player"),
                    "live source Player required"
                )
                assert(not self._workers[id], "fixture already running")
                local source = assert(self._data:GetData(sourcePlayer), "source profile loading")
                local snapshot = HttpService:JSONDecode(HttpService:JSONEncode(source))
                local active = true
                local ended, saved = Instance.new("BindableEvent"), Instance.new("BindableEvent")
                local profile =
                    { Data = snapshot, OnSessionEnd = ended.Event, OnAfterSave = saved.Event }
                profile.IsActive = function()
                    return active
                end
                profile.Reconcile = function() end
                profile.Save = function()
                    profile.LastSavedData =
                        HttpService:JSONDecode(HttpService:JSONEncode(profile.Data))
                    saved:Fire()
                end
                profile.EndSession = function()
                    if not active then
                        return
                    end
                    profile.Save()
                    active = false
                    ended:Fire()
                    ended:Destroy()
                    saved:Destroy()
                end
                for bayId, bay in pairs(self._modules.MergeEggPrototypeService._realm:GetBays()) do
                    if not bay.ownerUserId then
                        return self:_startWorker(
                            id,
                            bayId,
                            profile,
                            "isolated_fixture",
                            { expires = os.time() + cfg.lease_seconds },
                            sourcePlayer.UserId
                        )
                    end
                end
                return false, "realm_full"
            elseif action == "fixture_step" then
                local worker = assert(self._workers[id], "no fixture")
                return worker.runtime:step(self._modules.MergeAutoplayService._config.tick_seconds)
            elseif action == "fixture_stop" then
                self:_stop(id, "fixture_finished")
                return true
            elseif action == "enable" then
                self._filling = true
                self:_status("Filling", true)
                return true
            elseif action == "pause_filling" then
                self._filling = false
                self:_status("Filling", false)
                return true
            elseif action == "fixture_preempt" then
                local worker = assert(self._workers[id], "no fixture")
                self._modules.MergeEggPrototypeService._realm.beforeClaim(worker.bayId)
                return self._workers[id] == nil
            elseif action == "disable" then
                self._filling = false
                self:_status("Filling", false)
                for workerId in pairs(self._workers) do
                    self:_stop(workerId, "studio_disabled")
                end
                return true
            elseif action == "status" then
                local out = { attributes = self._folder:GetAttributes(), workers = {} }
                for workerId, worker in pairs(self._workers) do
                    out.workers[tostring(workerId)] = {
                        bay = worker.bayId,
                        fixture = worker.fixture,
                        report = worker.runtime and worker.runtime.autoplay:Report(worker.actor),
                        attributes = worker.actor:GetAttributes(),
                    }
                end
                return out
            end
            return false, "unsupported_test_action"
        end
    end
    local function join(player)
        if not self._online[player] then
            self:_login(player)
        end
        self:_register(player)
        if self._data:IsDataLoaded(player) then
            self:_receipt(player)
        else
            local connection
            connection = player:GetAttributeChangedSignal("DataLoaded"):Connect(function()
                if player:GetAttribute("DataLoaded") then
                    connection:Disconnect()
                    self:_receipt(player)
                end
            end)
            player.Destroying:Once(function()
                connection:Disconnect()
            end)
        end
    end
    Players.PlayerAdded:Connect(function(player)
        task.spawn(join, player)
    end)
    Players.PlayerRemoving:Connect(function(player)
        local token = self._online[player]
        self._online[player] = nil
        if token then
            task.spawn(function()
                self:_presenceUpdate(player.UserId, function(value)
                    return Lease.release(value, token, os.time(), cfg.logout_grace_seconds)
                end)
            end)
        end
    end)
    MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
        if passId == self._passId and purchased then
            task.spawn(function()
                self:_register(player, true)
            end)
        end
    end)
    for _, player in ipairs(Players:GetPlayers()) do
        task.spawn(join, player)
    end
    pcall(function()
        self._subscription = MessagingService:SubscribeAsync(cfg.login_topic, function(message)
            local id = tonumber(message.Data)
            if id then
                self._loading[id] = nil
                self:_stop(id, "account_logged_in")
            end
        end)
    end)
    local merge = self._modules.MergeEggPrototypeService
    local enabled = cfg.enabled
        and merge:_isDedicatedMergePlace()
        and (not RunService:IsStudio() or cfg.studio_enabled)
    self:_status("Filling", enabled)
    self._filling = enabled
    local canRun = cfg.enabled and merge:_isDedicatedMergePlace()
    if canRun and merge._realm then
        merge._realm.beforeClaim = function(bayId)
            for id, worker in pairs(self._workers) do
                if worker.bayId == bayId then
                    self:_stop(id, "bay_claimed")
                end
            end
        end
        merge._realm.vacateOffline = function()
            for id, worker in pairs(self._workers) do
                local bayId = worker.bayId
                self:_stop(id, "player_priority")
                return bayId
            end
        end
    end
    task.spawn(function()
        while not self._closing do
            for player, token in pairs(self._online) do
                if player.Parent then
                    self:_presenceUpdate(player.UserId, function(value)
                        return Lease.online(value, token, os.time(), cfg.lease_seconds)
                    end)
                end
            end
            task.wait(cfg.heartbeat_seconds)
        end
    end)
    if canRun then
        task.spawn(function()
            while not self._closing do
                local ok, err = pcall(self._fill, self)
                if not ok then
                    self:_status("LastError", tostring(err))
                end
                task.wait(cfg.fill_seconds)
            end
        end)
        local elapsed = 0
        RunService.Heartbeat:Connect(function(dt)
            elapsed += dt
            if elapsed < self._modules.MergeAutoplayService._config.tick_seconds then
                return
            end
            local delta = elapsed
            elapsed = 0
            for id, worker in pairs(self._workers) do
                if
                    not worker.fixture
                    and not worker.busy
                    and not worker.stopping
                    and worker.runtime
                then
                    worker.busy = true
                    task.spawn(function()
                        worker.thread = coroutine.running()
                        local ok, err = pcall(function()
                            if
                                os.time() >= worker.expires
                                or os.time() - worker.started >= cfg.rotation_seconds
                            then
                                self:_stop(id, "rotation_or_lease_expired")
                                return
                            end
                            if os.clock() >= worker.nextRenew then
                                local lease = self:_presenceUpdate(id, function(value)
                                    return Lease.renew(
                                        value,
                                        worker.token,
                                        os.time(),
                                        cfg.lease_seconds
                                    )
                                end)
                                if not lease or lease.token ~= worker.token then
                                    self:_stop(id, "lease_lost")
                                    return
                                end
                                worker.expires = lease.expires
                                worker.nextRenew = os.clock() + cfg.heartbeat_seconds
                            end
                            if self._workers[id] ~= worker or worker.stopping then
                                return
                            end
                            local alive, why = worker.runtime:step(delta)
                            if not alive then
                                self:_stop(id, why)
                            end
                        end)
                        worker.busy = false
                        if not ok then
                            self:_status("LastError", tostring(err))
                            self:_stop(id, "runtime_error")
                        end
                    end)
                end
            end
        end)
    end
    game:BindToClose(function()
        self._closing = true
        for id in pairs(self._workers) do
            self:_stop(id, "server_shutdown")
        end
    end)
end

return Service
