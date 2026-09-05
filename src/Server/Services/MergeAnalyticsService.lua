-- Native Roblox analytics only. No gameplay remotes, profile writes, or rewards.
local AnalyticsService = game:GetService("AnalyticsService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Funnel = require(ReplicatedStorage.Shared.Game.MergeAnalyticsFunnel)
local InternalAccounts = require(ReplicatedStorage.Shared.Game.InternalAccounts)
local PlaceRuntime = require(ReplicatedStorage.Shared.Game.PlaceRuntime)

local Service = {}
Service.__index = Service

function Service:Init()
    self._config = self._modules.ConfigLoader:LoadConfig("merge_analytics")
    self._internal = self._modules.ConfigLoader:LoadConfig("internal_accounts")
    self._tutorialSteps =
        self._modules.ConfigLoader:LoadConfig("merge_egg_prototype").tutorial.steps
    self._enabled = self._config.enabled
        and PlaceRuntime.isMerge(game.PlaceId, self._modules.ConfigLoader:LoadConfig("places"))
    self._players, self._queue, self._blocked = {}, {}, {}
    self._elapsed, self._dropped = 0, 0
end

function Service:_state(cohort)
    local state = Funnel.new(self._config, cohort)
    state.id, state.started = HttpService:GenerateGUID(false), os.clock()
    state.fields = {}
    return state
end

function Service:_suppressed(player)
    if RunService:IsStudio() or InternalAccounts.isUserId(self._internal, player.UserId) then
        return true
    end
    for _, prefix in ipairs(InternalAccounts.namePrefixes(self._internal)) do
        if string.sub(string.lower(player.Name), 1, #prefix) == string.lower(prefix) then
            return true
        end
    end
    return false
end

function Service:_fields(player, cohort)
    return {
        [Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = cohort,
        [Enum.AnalyticsCustomFieldKeys.CustomField02.Name] = player:GetAttribute(
            "MergeAutoplayEnabled"
        ) == true and "autoplay" or "manual",
        [Enum.AnalyticsCustomFieldKeys.CustomField03.Name] = tostring(game.PlaceVersion),
    }
end

function Service:_enqueue(player, event)
    local visit = self._players[player]
    if not visit then
        return
    end
    table.insert(visit.trace, event)
    if #visit.trace > self._config.trace_limit then
        table.remove(visit.trace, 1)
    end
    if self:_suppressed(player) then
        return
    end
    if #self._queue >= self._config.queue_limit then
        self._dropped += 1
        -- Never allow a later step to fabricate a dropped predecessor.
        if event.session then
            self._blocked[tostring(player.UserId) .. ":" .. event.session .. event.funnel] = true
        end
        return
    end
    table.insert(self._queue, { player = player, event = event, attempts = 0 })
end

function Service:_observe(player, state, event)
    for _, step in ipairs(Funnel.observe(state, self._config, event)) do
        local fields = state.fields[step.funnel]
        if not fields then
            fields = self:_fields(player, state.cohort)
            state.fields[step.funnel] = fields
        end
        self:_enqueue(player, {
            kind = "funnel",
            funnel = self._config.funnels[step.funnel].name,
            session = state.id,
            step = step.step,
            name = step.name,
            fields = fields,
        })
    end
end

function Service:_custom(player, category, id, detail, value)
    self:_enqueue(player, {
        kind = "custom",
        name = self._config.custom[category],
        value = value or 1,
        fields = {
            [Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = id,
            [Enum.AnalyticsCustomFieldKeys.CustomField02.Name] = detail,
            [Enum.AnalyticsCustomFieldKeys.CustomField03.Name] = player:GetAttribute(
                "MergeAutoplayEnabled"
            ) == true and "autoplay" or "manual",
        },
    })
end

function Service:Register(player)
    if not self._enabled or self._players[player] then
        return
    end
    local state = self:_state("unknown")
    state.funnels = { entry = state.funnels.entry }
    local visit = { entry = state, trace = {}, connections = {} }
    self._players[player] = visit
    self:_observe(player, state, "joined")
    local function profile()
        if player:GetAttribute("DataLoaded") == true then
            self:_observe(player, state, "profile_ready")
        end
    end
    table.insert(visit.connections, player:GetAttributeChangedSignal("DataLoaded"):Connect(profile))
    profile()
end

function Service:BeginBay(player, record, restored)
    self:Register(player)
    local visit = self._players[player]
    if not visit or (visit.bay and visit.record == record) then
        return
    end
    if visit.bay then
        self:EndBay(player, visit.record, "replaced")
    end
    visit.bay = self:_state(restored and "restored" or "fresh")
    visit.bay.funnels.entry = nil
    visit.record = record
    visit.lastExit = nil
    self:_observe(player, visit.entry, "bay_claimed")
    if player:GetAttribute("MergeAutoplayOwned") == true then
        self:Observe(player, record, "autoplay_owned")
    end
end

function Service:EntryEvent(player, event)
    self:Register(player)
    local visit = self._players[player]
    if visit then
        self:_observe(player, visit.entry, event)
    end
end

function Service:Observe(player, record, event, wave)
    local visit = self._players[player]
    if not visit or not visit.bay or visit.record ~= record then
        return
    end
    local state = visit.bay
    if event == "tutorial_step" then
        if state.tutorialStep == wave then
            return
        end
        state.tutorialStep = wave
        if wave and (self._tutorialSteps[wave] or self._config.tutorial_stages[wave]) then
            local key = "tutorial_" .. wave
            if not state.milestones[key] then
                state.milestones[key] = true
                self:_custom(player, "tutorial", wave, state.cohort)
            end
        end
        return
    end
    self:_observe(player, visit.entry, event)
    self:_observe(player, state, event)
    if self._config.milestones[event] and not state.milestones[event] then
        state.milestones[event] = true
        self:_custom(player, "milestone", event, state.cohort)
    end
    if event == "wave_cleared" then
        for _, milestone in ipairs(Funnel.wave(state, self._config, wave)) do
            self:_observe(player, state, milestone)
        end
    elseif event == "autoplay_action" then
        for _, milestone in ipairs(Funnel.autoAction(state, self._config)) do
            self:_observe(player, state, milestone)
        end
    elseif event == "rebirth_completed" then
        state.lastWave = 0
    end
end

function Service:Failure(player, reason, action)
    local visit = self._players[player]
    if not visit then
        return
    end
    reason = self._config.failure_reasons[reason] and reason or "other"
    action = action or "entry"
    action = self._config.failure_actions[action] and action or "board"
    local state = visit.bay or visit.entry
    local key = action .. ":" .. reason
    if not state.failures[key] then
        state.failures[key] = true
        self:_custom(player, "failure", reason, action)
    end
end

function Service:CoinCollected(player)
    local visit = self._players[player]
    if visit and visit.bay then
        self:Observe(player, visit.record, "coin_collected")
    end
end

function Service:EndBay(player, record, reason)
    local visit = self._players[player]
    if not visit or not visit.bay or visit.record ~= record then
        return
    end
    local state = visit.bay
    local activation = state.funnels.activation
    local stage = activation and ("activation_" .. activation.reached) or "restored_session"
    if
        state.tutorialStep
        and (
            self._tutorialSteps[state.tutorialStep]
            or self._config.tutorial_stages[state.tutorialStep]
        )
    then
        stage = "tutorial_" .. state.tutorialStep
    end
    reason = self._config.exit_reasons[reason] and reason or "ended"
    self:_custom(player, "exit", stage, reason, math.max(0, os.clock() - state.started))
    visit.lastExit = visit.trace[#visit.trace]
    visit.bay, visit.record = nil, nil
end

function Service:_emit(player, event)
    if event.kind == "funnel" then
        AnalyticsService:LogFunnelStepEvent(
            player,
            event.funnel,
            event.session,
            event.step,
            event.name,
            event.fields
        )
    else
        AnalyticsService:LogCustomEvent(player, event.name, event.value, event.fields)
    end
end

function Service:_send(item)
    local event = item.event
    if event.sent then
        return true
    end
    local key = event.session
        and (tostring(item.player.UserId) .. ":" .. event.session .. event.funnel)
    if key and self._blocked[key] then
        return true
    end
    local ok = pcall(self._emit, self, item.player, event)
    item.attempts += 1
    if ok then
        event.sent = true
    end
    if not ok and item.attempts >= self._config.retry_limit then
        self._dropped += 1
        if key then
            self._blocked[key] = true
        end
        return true
    end
    return ok
end

function Service:Snapshot(player)
    local visit = self._players[player]
    return {
        enabled = self._enabled,
        suppressed = self:_suppressed(player),
        queued = #self._queue,
        dropped = self._dropped,
        entry = visit and visit.entry,
        bay = visit and visit.bay,
        trace = visit and visit.trace,
    }
end

function Service:Start()
    if not self._enabled then
        return
    end
    Players.PlayerAdded:Connect(function(player)
        self:Register(player)
    end)
    for _, player in ipairs(Players:GetPlayers()) do
        self:Register(player)
    end
    Players.PlayerRemoving:Connect(function(player)
        local visit = self._players[player]
        if not visit then
            return
        end
        self:EndBay(player, visit.record, "leave")
        if not visit.lastExit then
            self:_custom(
                player,
                "exit",
                "entry_" .. visit.entry.funnels.entry.reached,
                "leave",
                math.max(0, os.clock() - visit.entry.started)
            )
            visit.lastExit = visit.trace[#visit.trace]
        end
        -- Prioritize the independent exit summary; preserve FIFO for remaining funnel steps.
        -- Bound the departure burst and never send queued steps after the Player is removed.
        if not self:_suppressed(player) then
            self:_send({ player = player, event = visit.lastExit, attempts = 0 })
            local sent = 0
            for _, item in ipairs(self._queue) do
                if item.player == player and item.event ~= visit.lastExit then
                    if sent >= self._config.leave_flush_limit or not self:_send(item) then
                        break
                    end
                    item.departureSent = true
                    sent += 1
                end
            end
        end
        for index = #self._queue, 1, -1 do
            if self._queue[index].player == player then
                local item = self._queue[index]
                if not item.departureSent and item.event ~= visit.lastExit then
                    self._dropped += 1
                end
                table.remove(self._queue, index)
            end
        end
        for _, connection in ipairs(visit.connections) do
            connection:Disconnect()
        end
        local prefix = tostring(player.UserId) .. ":"
        for key in pairs(self._blocked) do
            if string.sub(key, 1, #prefix) == prefix then
                self._blocked[key] = nil
            end
        end
        self._players[player] = nil
    end)
    RunService.Heartbeat:Connect(function(dt)
        self._elapsed += dt
        if self._elapsed < self._config.send_interval or self._sending then
            return
        end
        self._elapsed = 0
        for player, visit in pairs(self._players) do
            if
                visit.entry.funnels.entry.reached < 4
                and os.clock() - visit.entry.started >= self._config.entry_timeout_seconds
            then
                self:Failure(player, "entry_timeout")
            end
            if visit.bay and player:GetAttribute("MergeAutoplayOwned") == true then
                self:Observe(player, visit.record, "autoplay_owned")
            end
        end
        local item = self._queue[1]
        if item then
            self._sending = true
            local consumed = self:_send(item)
            if consumed and self._queue[1] == item then
                table.remove(self._queue, 1)
            end
            self._sending = false
        end
    end)
    if RunService:IsStudio() then
        local control = Instance.new("BindableFunction")
        control.Name = "MergeAnalyticsStudioSnapshot"
        control.OnInvoke = function(player)
            return self:Snapshot(player)
        end
        control.Parent = ServerStorage
    end
end

return Service
