--[[
    RetentionService — persistent activation milestones + Roblox Analytics funnel.

    It observes the existing server GameEvents bus, so quest/zone/tutorial owners stay unaware of
    analytics.     New-player onboarding steps go to LogOnboardingFunnelStepEvent and end at
    Rally (Homeworld spine only). Cave room-by-room beats go to LogFunnelStepEvent
    as Combat Training. Optional first quest / First Steps / first area go to
    the Activation funnel. All first-time milestones also
    go to one low-cardinality custom event with category/id breakdown fields.
]]

local AnalyticsService = game:GetService("AnalyticsService")
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local fireGameEvent = require(ReplicatedStorage.Shared.Network.FireGameEvent)
local InternalAccounts = require(ReplicatedStorage.Shared.Game.InternalAccounts)
local Readiness = require(ReplicatedStorage.Shared.Utils.Readiness)
local RetentionLogic = require(ReplicatedStorage.Shared.Game.RetentionLogic)
local CombatCourses = require(ReplicatedStorage.Shared.Game.CombatCourses)

local RetentionService = {}
RetentionService.__index = RetentionService

local function utcDate(timestamp)
    return os.date("!%Y%m%d", timestamp)
end

local function countEntries(value)
    local count = 0
    for _ in pairs(type(value) == "table" and value or {}) do
        count += 1
    end
    return count
end

local function inventoryCounts(inventory)
    local counts = {}
    for bucketName, bucket in pairs(type(inventory) == "table" and inventory or {}) do
        if type(bucket) == "table" and type(bucket.items) == "table" then
            counts[bucketName] = countEntries(bucket.items)
        end
    end
    return counts
end

local function progressionSnapshot(data, player)
    data = type(data) == "table" and data or {}
    local stats = type(data.Stats) == "table" and data.Stats or {}
    local gameData = type(data.GameData) == "table" and data.GameData or {}
    local tutorial = type(data.Tutorial) == "table" and data.Tutorial or {}
    return {
        schemaVersion = data.SchemaVersion,
        joinDate = data.JoinDate,
        lastLogin = data.LastLogin,
        level = (player and player:GetAttribute("Level")) or stats.Level,
        claimedLevel = (player and player:GetAttribute("ClaimedLevel")) or stats.ClaimedLevel,
        experience = stats.Experience,
        counters = stats.Counters,
        currencies = data.Currencies,
        tutorial = {
            step = tutorial.step,
            count = tutorial.count,
            done = tutorial.done == true,
        },
        questClaims = data.QuestClaims,
        questActiveTrack = data.QuestActiveTrack,
        unlockedAreas = gameData.UnlockedAreas,
        unlocks = gameData.Unlocks,
        inventoryCounts = inventoryCounts(data.Inventory),
        equippedCount = countEntries(data.Equipped),
    }
end

local function customFields(category, id)
    return {
        [Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = category,
        [Enum.AnalyticsCustomFieldKeys.CustomField02.Name] = id,
    }
end

function RetentionService:Init()
    self._logger = self._modules and self._modules.Logger
    self._configLoader = self._modules and self._modules.ConfigLoader
    self._dataService = self._modules and self._modules.DataService
    self._config = table.clone(self._configLoader:LoadConfig("retention"))
    self._config.course_funnels = CombatCourses.funnels(
        self._configLoader:LoadConfig("combat_tutorial"),
        self._configLoader:LoadConfig("combat_courses")
    )
    self._tutorialConfig = self._configLoader:LoadConfig("tutorial")
    self._buildInfo = self._configLoader:LoadConfig("build_info")
    self._internalAccounts = self._configLoader:LoadConfig("internal_accounts")
    self._excludedUserIds = InternalAccounts.userIds(self._internalAccounts)
    self._excludedNamePrefixes = InternalAccounts.namePrefixes(self._internalAccounts)
    self._sessionStarted = {}
    self._sessionStartedAt = {}
    self._rawSessions = {}
    self._aggregates = {}
    self._pendingClientContext = {}
    self._rawFlushElapsed = 0
    self._eventConfig = self._config.event_store or {}
    self._dashboardConfig = self._config.dashboard or {}
    self._rawStore = nil
    self._dashboardStore = nil

    if
        self._eventConfig.enabled ~= false
        and (not RunService:IsStudio() or self._eventConfig.write_in_studio == true)
    then
        local ok, storeOrError = pcall(function()
            return DataStoreService:GetDataStore(self._eventConfig.name or "RetentionEvents_v1")
        end)
        if ok then
            self._rawStore = storeOrError
        elseif self._logger then
            self._logger:Warn("Retention event store unavailable", {
                context = "RetentionService",
                store = self._eventConfig.name or "RetentionEvents_v1",
                error = tostring(storeOrError),
            })
        end
    end

    if
        self._dashboardConfig.enabled ~= false
        and (not RunService:IsStudio() or self._dashboardConfig.write_in_studio == true)
    then
        local ok, storeOrError = pcall(function()
            return DataStoreService:GetDataStore(
                self._dashboardConfig.name or "RetentionDashboard_v1"
            )
        end)
        if ok then
            self._dashboardStore = storeOrError
        elseif self._logger then
            self._logger:Warn("Retention dashboard store unavailable", {
                context = "RetentionService",
                store = self._dashboardConfig.name or "RetentionDashboard_v1",
                error = tostring(storeOrError),
            })
        end
    end

    fireGameEvent.tap(function(player, name, ctx)
        self:_onGameEvent(player, name, ctx)
    end)
    self._dataService:RegisterBeforeProfileRelease(function(player)
        self:_queueSessionEnd(player, "profile_release")
    end)
end

function RetentionService:Start()
    local function begin(player)
        self._sessionStarted[player] = os.clock()
        self._sessionStartedAt[player] = os.time()
        task.spawn(function()
            if Readiness.awaitAttribute(player, "DataLoaded", true, 20) and player.Parent then
                self:_beginRawSession(player)
                self:_recordEvent(player, "retention_joined", {})
            end
        end)
    end
    Players.PlayerAdded:Connect(begin)
    Players.PlayerRemoving:Connect(function(player)
        self:_endRawSession(player, "player_removing")
        self._sessionStarted[player] = nil
        self._sessionStartedAt[player] = nil
        self._pendingClientContext[player] = nil
    end)
    for _, player in ipairs(Players:GetPlayers()) do
        begin(player)
    end

    RunService.Heartbeat:Connect(function(deltaTime)
        self._rawFlushElapsed += deltaTime
        local interval = math.max(5, tonumber(self._eventConfig.flush_seconds) or 15)
        if self._rawFlushElapsed < interval then
            return
        end
        self._rawFlushElapsed = 0
        for player in pairs(self._rawSessions) do
            self:_scheduleRawFlush(player)
        end
        for cohortDate in pairs(self._aggregates) do
            self:_scheduleAggregateFlush(cohortDate)
        end
    end)

    game:BindToClose(function()
        local activePlayers = {}
        for player in pairs(self._rawSessions) do
            table.insert(activePlayers, player)
        end
        for _, player in ipairs(activePlayers) do
            self:_endRawSession(player, "server_shutdown")
        end
        for cohortDate, aggregate in pairs(self._aggregates) do
            aggregate.closing = true
            self:_flushAggregate(cohortDate)
        end
    end)
end

function RetentionService:_beginRawSession(player)
    if self._rawSessions[player] or not self._rawStore then
        return
    end
    local data = self._dataService:GetData(player)
    if type(data) ~= "table" then
        return
    end
    local startedAt = self._sessionStartedAt[player] or os.time()
    local sessionNumber =
        math.max(1, math.floor(tonumber(data.Analytics and data.Analytics.SessionCount) or 1))
    local cohortDate = utcDate(startedAt)
    self._rawSessions[player] = {
        userId = player.UserId,
        sessionNumber = sessionNumber,
        startedAt = startedAt,
        cohortDate = cohortDate,
        keyPrefix = RetentionLogic.eventKeyPrefix(cohortDate, player.UserId, sessionNumber),
        sequence = 0,
        nextChunk = 1,
        pending = {},
        flushing = false,
        closing = false,
        endQueued = false,
        firstSession = sessionNumber == 1,
        aggregateSeen = {},
        dashboardEligible = not RetentionLogic.isInternalPlayer(
            player.UserId,
            player.Name,
            self._excludedUserIds,
            self._excludedNamePrefixes
        ),
        dashboardSeen = {},
        server = {
            jobId = game.JobId,
            placeId = game.PlaceId,
            placeVersion = game.PlaceVersion,
            universeId = game.GameId,
            privateServer = game.PrivateServerId ~= "",
            buildVersion = self._buildInfo.version,
            buildCommit = self._buildInfo.commit,
            buildBranch = self._buildInfo.branch,
            buildBuiltAt = self._buildInfo.built_at,
            buildDirty = self._buildInfo.dirty == true,
            analyticsSchemaVersion = tonumber(self._eventConfig.schema_version) or 1,
        },
    }
    self:_appendRawEvent(player, "session_started", {
        accountAgeDays = player.AccountAge,
        membership = player.MembershipType.Name,
        firstSession = sessionNumber == 1,
        progression = progressionSnapshot(data, player),
    })
    self:_aggregateSessionStarted(self._rawSessions[player])
    self:_recordDistinctReturner(player, self._rawSessions[player], data)
    if self._pendingClientContext[player] then
        self:_appendRawEvent(player, "client_context", self._pendingClientContext[player])
        self._pendingClientContext[player] = nil
    end
end

function RetentionService:_tutorialDefinitions()
    local definitions = {}
    for index, step in ipairs(self._tutorialConfig.steps or {}) do
        table.insert(definitions, {
            index = index,
            id = step.id,
            name = step.title or step.id,
        })
    end
    return definitions
end

function RetentionService:_dashboardDefinitions()
    return {
        tutorialSteps = self:_tutorialDefinitions(),
        distinctRetention = {
            attribution = "first_join_utc_date",
            denominator = "newPlayers",
            windows = {
                d1 = { firstDay = 1, lastDay = 1 },
                d2_7 = { firstDay = 2, lastDay = 7 },
                d8_30 = { firstDay = 8, lastDay = 30 },
            },
        },
    }
end

function RetentionService:_aggregateForDate(cohortDate, server)
    local aggregate = self._aggregates[cohortDate]
    if aggregate then
        return aggregate
    end
    local bucketCount = math.max(1, math.floor(tonumber(self._dashboardConfig.bucket_count) or 16))
    local dashboardBucket = RetentionLogic.dashboardBucketIndex(game.JobId, bucketCount)
    aggregate = {
        key = RetentionLogic.aggregateKey(cohortDate, game.JobId),
        dashboardKey = RetentionLogic.dashboardBucketKey(cohortDate, dashboardBucket),
        dashboardBucket = dashboardBucket,
        dashboardBucketCount = bucketCount,
        cohortDate = cohortDate,
        server = server,
        definitions = self:_dashboardDefinitions(),
        counters = RetentionLogic.newAggregate(),
        dashboardCounters = RetentionLogic.newAggregate(),
        dirty = false,
        dashboardDirty = false,
        flushing = false,
        closing = false,
    }
    self._aggregates[cohortDate] = aggregate
    return aggregate
end

function RetentionService:_aggregateFor(session)
    return self:_aggregateForDate(session.cohortDate, session.server)
end

function RetentionService:_recordDistinctReturner(player, session, data)
    if not session.dashboardEligible or session.firstSession then
        return
    end
    data.Analytics = type(data.Analytics) == "table" and data.Analytics or {}
    local state = RetentionLogic.ensure(data.Analytics.Retention, false, os.time())
    data.Analytics.Retention = state
    local windowId, cohortDate, dayOffset = RetentionLogic.claimReturnWindow(
        state,
        data.JoinDate,
        session.startedAt,
        self._dashboardConfig.distinct_retention_start_utc
    )
    if not windowId then
        return
    end

    local cohortAggregate = self:_aggregateForDate(cohortDate, session.server)
    RetentionLogic.aggregateDistinctReturner(cohortAggregate.dashboardCounters, windowId)
    cohortAggregate.dashboardDirty = true
    self:_appendRawEvent(player, "distinct_retention_window", {
        cohortDate = cohortDate,
        dayOffset = dayOffset,
        window = windowId,
    })
    self:_scheduleAggregateFlush(cohortDate)
    self._dataService:RequestSave(player, "distinct_retention_window")
end

function RetentionService:_aggregateSessionStarted(session)
    local aggregate = self:_aggregateFor(session)
    RetentionLogic.aggregateSessionStarted(aggregate.counters, session.firstSession)
    aggregate.dirty = true
    if session.dashboardEligible then
        RetentionLogic.aggregateSessionStarted(aggregate.dashboardCounters, session.firstSession)
        aggregate.dashboardDirty = true
    end
end

function RetentionService:_aggregateEvent(player, name, context)
    local session = self._rawSessions[player]
    if not session then
        return
    end
    local aggregate = self:_aggregateFor(session)
    RetentionLogic.aggregateEvent(
        aggregate.counters,
        session.aggregateSeen,
        name,
        context,
        os.clock() - (self._sessionStarted[player] or os.clock()),
        session.firstSession
    )
    aggregate.dirty = true
    if session.dashboardEligible then
        RetentionLogic.aggregateEvent(
            aggregate.dashboardCounters,
            session.dashboardSeen,
            name,
            context,
            os.clock() - (self._sessionStarted[player] or os.clock()),
            session.firstSession
        )
        aggregate.dashboardDirty = true
    end
end

function RetentionService:_currentTutorialStep(data)
    local progress = data and data.Tutorial
    if type(progress) ~= "table" then
        return "not_initialized", false
    end
    if progress.done == true then
        return "completed", true
    end
    local step = self._tutorialConfig.steps and self._tutorialConfig.steps[progress.step]
    return (step and step.id) or "unknown", false
end

function RetentionService:_queueSessionEnd(player, reason)
    local session = self._rawSessions[player]
    if not session or session.endQueued then
        return
    end
    local data = self._dataService:GetData(player)
    local progression = progressionSnapshot(data, player)
    local currentTutorialStep, tutorialDone = self:_currentTutorialStep(data)
    self:_appendRawEvent(player, "session_ended", {
        reason = reason,
        progression = progression,
    })
    local aggregate = self:_aggregateFor(session)
    local summary = {
        durationSeconds = os.clock() - (self._sessionStarted[player] or os.clock()),
        firstSession = session.firstSession,
        earnedLevel = progression.level,
        claimedLevel = progression.claimedLevel,
        tutorialDone = tutorialDone,
        currentTutorialStep = currentTutorialStep,
    }
    RetentionLogic.aggregateSessionEnded(aggregate.counters, summary)
    aggregate.dirty = true
    if session.dashboardEligible then
        RetentionLogic.aggregateSessionEnded(aggregate.dashboardCounters, summary)
        aggregate.dashboardDirty = true
    end
    session.endQueued = true
end

function RetentionService:_appendRawEvent(player, name, context)
    local session = self._rawSessions[player]
    if not session or session.closing then
        return
    end
    session.sequence += 1
    table.insert(
        session.pending,
        RetentionLogic.rawEvent(
            session.sequence,
            name,
            os.time(),
            os.clock() - (self._sessionStarted[player] or os.clock()),
            context,
            self._eventConfig
        )
    )
    local maxEvents = math.max(10, math.floor(tonumber(self._eventConfig.events_per_chunk) or 100))
    if #session.pending >= maxEvents then
        self:_scheduleRawFlush(player)
    end
end

function RetentionService:_rawPayload(session, chunk, events)
    return {
        kind = "events",
        schemaVersion = math.max(1, math.floor(tonumber(self._eventConfig.schema_version) or 1)),
        cohortDate = session.cohortDate,
        userId = session.userId,
        sessionNumber = session.sessionNumber,
        sessionStartedAt = session.startedAt,
        chunk = chunk,
        server = session.server,
        events = events,
    }
end

function RetentionService:_aggregatePayload(aggregate)
    return RetentionLogic.sanitize({
        kind = "aggregate",
        schemaVersion = math.max(1, math.floor(tonumber(self._eventConfig.schema_version) or 1)),
        cohortDate = aggregate.cohortDate,
        updatedAt = os.time(),
        server = aggregate.server,
        definitions = aggregate.definitions,
        counters = aggregate.counters,
    }, self._eventConfig)
end

function RetentionService:_dashboardContribution(aggregate)
    return {
        schemaVersion = math.max(
            1,
            math.floor(tonumber(self._dashboardConfig.schema_version) or 1)
        ),
        dateUtc = aggregate.cohortDate,
        bucket = aggregate.dashboardBucket,
        bucketCount = aggregate.dashboardBucketCount,
        jobId = game.JobId,
        updatedAt = os.time(),
        server = aggregate.server,
        definitions = aggregate.definitions,
        exclusions = {
            playerNamePrefixes = self._excludedNamePrefixes,
            userIds = self._excludedUserIds,
        },
        counters = RetentionLogic.sanitize(aggregate.dashboardCounters, self._eventConfig),
    }
end

function RetentionService:_flushAggregate(cohortDate)
    local aggregate = self._aggregates[cohortDate]
    if
        not aggregate
        or aggregate.flushing
        or (not aggregate.dirty and not aggregate.dashboardDirty)
    then
        return
    end
    aggregate.flushing = true

    if aggregate.dirty and self._rawStore then
        aggregate.dirty = false
        local payload = self:_aggregatePayload(aggregate)
        local ok, err = pcall(function()
            self._rawStore:SetAsync(aggregate.key, payload)
        end)
        if not ok then
            aggregate.dirty = true
            if self._logger then
                self._logger:Warn("Retention aggregate shard save failed", {
                    context = "RetentionService",
                    key = aggregate.key,
                    error = tostring(err),
                })
            end
        end
    end

    if aggregate.dashboardDirty and self._dashboardStore then
        aggregate.dashboardDirty = false
        local contribution = self:_dashboardContribution(aggregate)
        local ok, err = pcall(function()
            self._dashboardStore:UpdateAsync(aggregate.dashboardKey, function(current)
                return RetentionLogic.replaceDashboardContribution(current, contribution)
            end)
        end)
        if not ok then
            aggregate.dashboardDirty = true
            if self._logger then
                self._logger:Warn("Retention dashboard counter save failed", {
                    context = "RetentionService",
                    key = aggregate.dashboardKey,
                    error = tostring(err),
                })
            end
        end
    end

    aggregate.flushing = false
end

function RetentionService:_scheduleAggregateFlush(cohortDate)
    local aggregate = self._aggregates[cohortDate]
    if
        not aggregate
        or aggregate.flushing
        or (not aggregate.dirty and not aggregate.dashboardDirty)
    then
        return
    end
    task.spawn(function()
        self:_flushAggregate(cohortDate)
    end)
end

function RetentionService:_restoreRawBatch(session, batch)
    local restored = {}
    for _, event in ipairs(batch) do
        table.insert(restored, event)
    end
    for _, event in ipairs(session.pending) do
        table.insert(restored, event)
    end
    session.pending = restored
end

function RetentionService:_flushRawSession(player)
    local session = self._rawSessions[player]
    if not session or session.flushing or #session.pending == 0 then
        return
    end
    session.flushing = true
    local maxEvents = math.max(10, math.floor(tonumber(self._eventConfig.events_per_chunk) or 100))

    while #session.pending > 0 do
        local batch = {}
        local remaining = {}
        for index, event in ipairs(session.pending) do
            table.insert(index <= maxEvents and batch or remaining, event)
        end
        session.pending = remaining

        local chunk = session.nextChunk
        local key = RetentionLogic.eventChunkKey(session.keyPrefix, chunk)
        local ok, err = pcall(function()
            self._rawStore:SetAsync(
                key,
                self:_rawPayload(session, chunk, batch),
                { session.userId }
            )
        end)
        if not ok then
            self:_restoreRawBatch(session, batch)
            if self._logger then
                self._logger:Warn("Retention event chunk save failed", {
                    context = "RetentionService",
                    key = key,
                    events = #batch,
                    error = tostring(err),
                })
            end
            break
        end
        session.nextChunk += 1
        if not session.closing then
            break
        end
    end

    session.flushing = false
    if session.closing and #session.pending == 0 then
        self._rawSessions[player] = nil
    end
end

function RetentionService:_scheduleRawFlush(player)
    local session = self._rawSessions[player]
    if not session or session.flushing or #session.pending == 0 then
        return
    end
    task.spawn(function()
        self:_flushRawSession(player)
    end)
end

function RetentionService:_endRawSession(player, reason)
    local session = self._rawSessions[player]
    if not session or session.closing then
        return
    end
    self:_queueSessionEnd(player, reason)
    session.closing = true
    local cohortDate = session.cohortDate
    self:_flushRawSession(player)
    self:_flushAggregate(cohortDate)
end

function RetentionService:_state(player)
    local data = self._dataService:GetData(player)
    if type(data) ~= "table" then
        return nil, nil
    end
    data.Analytics = type(data.Analytics) == "table" and data.Analytics or {}
    local firstSession = tonumber(data.Analytics.SessionCount) == 1
    data.Analytics.Retention =
        RetentionLogic.ensure(data.Analytics.Retention, firstSession, os.time())
    return data.Analytics.Retention, data
end

function RetentionService:_meta(player, detail)
    local data = self._dataService:GetData(player)
    local started = self._sessionStarted[player] or os.clock()
    return {
        at = os.time(),
        session = data and data.Analytics and data.Analytics.SessionCount or 1,
        seconds = os.clock() - started,
        detail = detail,
    }
end

function RetentionService:_logCustom(player, category, id)
    local cfg = self._config.custom_event or {}
    if RunService:IsStudio() or cfg.enabled == false then
        return
    end
    pcall(function()
        AnalyticsService:LogCustomEvent(
            player,
            cfg.name or "RetentionMilestone",
            1,
            customFields(category, id)
        )
    end)
end

function RetentionService:_logPowerPick(player, powerId, level)
    local cfg = self._config.power_pick_event or {}
    if RunService:IsStudio() or cfg.enabled == false then
        return
    end
    if
        RetentionLogic.isInternalPlayer(
            player.UserId,
            player.Name,
            self._excludedUserIds,
            self._excludedNamePrefixes
        )
    then
        return
    end
    pcall(function()
        AnalyticsService:LogCustomEvent(player, cfg.name or "PowerPicked", 1, {
            [Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = tostring(powerId),
            [Enum.AnalyticsCustomFieldKeys.CustomField02.Name] = tostring(
                tonumber(level) and math.floor(level) or "unknown"
            ),
        })
    end)
end

function RetentionService:_flushFunnel(player, state)
    local cfg = self._config.onboarding or {}
    if RunService:IsStudio() or cfg.enabled == false then
        return false
    end
    local changed = false
    for _, step in ipairs(RetentionLogic.pendingFunnelSteps(self._config, state)) do
        local ok = pcall(function()
            AnalyticsService:LogOnboardingFunnelStepEvent(
                player,
                step.index,
                step.name,
                customFields("onboarding", step.id)
            )
        end)
        if not ok then
            break
        end
        state.AnalyticsFunnelStep = step.index
        changed = true
    end
    return changed
end

function RetentionService:_flushActivation(player, state)
    local cfg = self._config.activation or {}
    if RunService:IsStudio() or cfg.enabled == false then
        return false
    end
    local sessionId = "activation:" .. tostring(player.UserId)
    local changed = false
    for _, step in ipairs(RetentionLogic.pendingActivationSteps(self._config, state)) do
        local ok = pcall(function()
            AnalyticsService:LogFunnelStepEvent(
                player,
                cfg.name or "Activation",
                sessionId,
                step.index,
                step.name,
                customFields("activation", step.id)
            )
        end)
        if not ok then
            break
        end
        state.ActivationFunnelStep = step.index
        changed = true
    end
    return changed
end

function RetentionService:_flushCombatTraining(player, state)
    local coursesChanged = self:_flushCombatCourses(player, state)
    local cfg = self._config.combat_training or {}
    if RunService:IsStudio() or cfg.enabled == false then
        return coursesChanged
    end
    local sessionId = "combat:" .. tostring(player.UserId)
    local changed = coursesChanged
    for _, step in ipairs(RetentionLogic.pendingCombatTrainingSteps(self._config, state)) do
        local ok = pcall(function()
            AnalyticsService:LogFunnelStepEvent(
                player,
                cfg.name or "Combat Training",
                sessionId,
                step.index,
                step.name,
                customFields("combat_training", step.id)
            )
        end)
        if not ok then
            break
        end
        state.CombatFunnelStep = step.index
        changed = true
    end
    return changed
end

function RetentionService:_flushCombatCourses(player, state)
    if
        RunService:IsStudio()
        or RetentionLogic.isInternalPlayer(
            player.UserId,
            player.Name,
            self._excludedUserIds,
            self._excludedNamePrefixes
        )
    then
        return false
    end
    state.CombatCourseFunnelSteps = state.CombatCourseFunnelSteps or {}
    local changed = false
    for _, funnel in ipairs(self._config.course_funnels or {}) do
        for _, step in ipairs(RetentionLogic.pendingCourseSteps(funnel, state)) do
            local ok = pcall(function()
                AnalyticsService:LogFunnelStepEvent(
                    player,
                    funnel.name,
                    "course:" .. funnel.key .. ":" .. tostring(player.UserId),
                    step.index,
                    step.name,
                    customFields("combat_course", step.id)
                )
            end)
            if not ok then
                break
            end
            state.CombatCourseFunnelSteps[funnel.key] = step.index
            changed = true
        end
    end
    return changed
end

function RetentionService:_recordMilestone(player, id, category, detail)
    local state = self:_state(player)
    if not state then
        return false
    end
    if not RetentionLogic.record(state, id, category, self:_meta(player, detail)) then
        if
            self:_flushFunnel(player, state)
            or self:_flushActivation(player, state)
            or self:_flushCombatTraining(player, state)
        then
            self._dataService:RequestSave(player, "retention_funnel")
        end
        return false
    end
    self:_logCustom(player, category, id)
    self:_flushFunnel(player, state)
    self:_flushActivation(player, state)
    self:_flushCombatTraining(player, state)
    self._dataService:RequestSave(player, "retention_milestone")
    return true
end

function RetentionService:_recordEvent(player, name, ctx)
    if not (player and player.Parent) or not self._dataService:IsDataLoaded(player) then
        return
    end
    self:_appendRawEvent(player, name, ctx)
    self:_aggregateEvent(player, name, ctx)
    for _, step in ipairs(RetentionLogic.matchingSteps(self._config, name, ctx)) do
        self:_recordMilestone(player, step.id, step.funnel or "onboarding")
    end

    if name == "quest_complete" and type(ctx) == "table" and type(ctx.quest) == "string" then
        self:_recordMilestone(player, "quest:" .. ctx.quest, "quest", ctx.quest)
    elseif name == "area_unlocked" and type(ctx) == "table" and type(ctx.areaId) == "string" then
        self:_recordMilestone(player, "area:" .. ctx.areaId, "area", ctx.areaId)
    elseif name == "power_selected" and type(ctx) == "table" and type(ctx.power) == "string" then
        self:_logPowerPick(player, ctx.power, ctx.level)
    end
end

function RetentionService:_onGameEvent(player, name, ctx)
    self:_recordEvent(player, name, ctx)
end

function RetentionService:SetClientContext(player, context)
    if not self._rawSessions[player] then
        self._pendingClientContext[player] = context
        return { ok = true, queued = true }
    end
    self:_appendRawEvent(player, "client_context", context)
    return { ok = true }
end

function RetentionService:GetSnapshot(player)
    local state, data = self:_state(player)
    if not state then
        return { ok = false, reason = "data_not_loaded" }
    end
    local snapshot = RetentionLogic.snapshot(self._config, state)
    snapshot.ok = true
    snapshot.sessionCount = data.Analytics.SessionCount
    snapshot.totalPlayTime = data.Analytics.TotalPlayTime
    snapshot.lastSessionDuration = data.Analytics.LastSessionDuration
    snapshot.joinDate = data.JoinDate
    snapshot.lastLogin = data.LastLogin
    local rawSession = self._rawSessions[player]
    local aggregate = rawSession and self._aggregates[rawSession.cohortDate]
    snapshot.eventStore = {
        enabled = self._rawStore ~= nil,
        name = self._eventConfig.name or "RetentionEvents_v1",
        keyPrefix = rawSession and rawSession.keyPrefix or nil,
        pendingEvents = rawSession and #rawSession.pending or 0,
        nextChunk = rawSession and rawSession.nextChunk or nil,
        aggregateKey = aggregate and aggregate.key or nil,
        aggregateDirty = aggregate and aggregate.dirty or false,
    }
    snapshot.dashboardStore = {
        enabled = self._dashboardStore ~= nil,
        name = self._dashboardConfig.name or "RetentionDashboard_v1",
        eligible = rawSession and rawSession.dashboardEligible or false,
        key = aggregate and aggregate.dashboardKey or nil,
        dirty = aggregate and aggregate.dashboardDirty or false,
    }
    return snapshot
end

function RetentionService:GetDashboard(dateUtc)
    if not self._dashboardStore then
        return { ok = false, reason = "dashboard_store_unavailable" }
    end
    dateUtc = tostring(dateUtc or utcDate(os.time())):gsub("[^%d]", "")
    if #dateUtc ~= 8 then
        return { ok = false, reason = "invalid_date" }
    end

    if self._aggregates[dateUtc] then
        self:_flushAggregate(dateUtc)
    end

    local bucketCount = math.max(1, math.floor(tonumber(self._dashboardConfig.bucket_count) or 16))
    local buckets = {}
    local failures = {}
    local completed = 0
    local failureCount = 0
    local readsCompleted = Instance.new("BindableEvent")
    for bucket = 0, bucketCount - 1 do
        task.spawn(function()
            local key = RetentionLogic.dashboardBucketKey(dateUtc, bucket)
            local ok, value = pcall(function()
                return self._dashboardStore:GetAsync(key)
            end)
            if ok then
                if type(value) == "table" then
                    buckets[bucket + 1] = value
                end
            else
                failures[bucket + 1] = {
                    key = key,
                    error = tostring(value),
                }
                failureCount += 1
            end
            completed += 1
            if completed == bucketCount then
                readsCompleted:Fire()
            end
        end)
    end
    if completed < bucketCount then
        readsCompleted.Event:Wait()
    end
    readsCompleted:Destroy()

    local counters = {}
    local builds = {}
    local updatedAt = 0
    local bucketsPresent = 0
    for _, bucket in pairs(buckets) do
        RetentionLogic.mergeNumeric(counters, bucket.counters)
        updatedAt = math.max(updatedAt, tonumber(bucket.updatedAt) or 0)
        bucketsPresent += 1
        for _, contribution in
            pairs(type(bucket.contributions) == "table" and bucket.contributions or {})
        do
            local buildKey = RetentionLogic.dashboardBuildKey(contribution.server)
            local build = builds[buildKey]
            if not build then
                build = {
                    server = contribution.server,
                    contributors = 0,
                    counters = {},
                }
                builds[buildKey] = build
            end
            build.contributors += 1
            RetentionLogic.mergeNumeric(build.counters, contribution.counters)
        end
    end
    for _, build in pairs(builds) do
        build.summary = RetentionLogic.dashboardSummary(build.counters)
    end

    return {
        ok = failureCount == 0,
        partial = failureCount > 0,
        dateUtc = dateUtc,
        store = self._dashboardConfig.name or "RetentionDashboard_v1",
        bucketCount = bucketCount,
        bucketsPresent = bucketsPresent,
        readFailures = failures,
        updatedAt = updatedAt,
        exclusions = {
            playerNamePrefixes = self._excludedNamePrefixes,
            userIds = self._excludedUserIds,
        },
        definitions = self:_dashboardDefinitions(),
        builds = builds,
        summary = RetentionLogic.dashboardSummary(counters),
        powerPicks = RetentionLogic.powerPickShares(counters),
        counters = counters,
    }
end

return RetentionService
