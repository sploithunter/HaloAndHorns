local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Signals = require(ReplicatedStorage.Shared.Network.Signals)
-- Events are scheduled in MOUNTAIN time ("ColoradoPlays"), not UTC. This converts the UTC
-- server clock to America/Denver (DST-aware) for every weekday/hour decision below.
local MountainTime = require(ReplicatedStorage.Shared.Game.MountainTime)

local EventService = {}
EventService.__index = EventService

local DEFAULT_CONFIG = {
    tick_seconds = 1,
    workspace = {
        active_folder = "GlobalEvents",
        modifier_folder = "EventModifiers",
        clock_folder = "EventClock",
    },
    modifiers = {},
    global_events = {},
    scheduled_global_events = {},
}

function EventService:Init()
    self._logger = self._modules.Logger
    self._configLoader = self._modules.ConfigLoader
    self._serverClock = self._modules.ServerClockService
    self._modifierService = self._modules.ModifierService
    self._running = false

    self._config = self:_loadConfig()
    self._activeFolder =
        self:_getOrCreateFolder(Workspace, self._config.workspace.active_folder or "GlobalEvents")
    self._modifierFolder = self:_getOrCreateFolder(
        Workspace,
        self._config.workspace.modifier_folder or "EventModifiers"
    )
    self._clockFolder =
        self:_getOrCreateFolder(Workspace, self._config.workspace.clock_folder or "EventClock")
    self._modifiers = {}
    self._scheduledActive = {}

    self:_resetModifiers()
    self:_registerModifierProvider()
    self:_updateClockValues()
    self:_setupNetworking()

    Players.PlayerAdded:Connect(function(player)
        task.defer(function()
            self:SendUpdate(player)
        end)
    end)

    self._logger:Info("EventService initialized", {
        globalEvents = self:_countTable(self._config.global_events),
        modifiers = self:_countTable(self._config.modifiers),
    })
end

function EventService:_registerModifierProvider()
    if not self._modifierService or not self._modifierService.RegisterProvider then
        return
    end

    self._modifierService:RegisterProvider("active_events", function(context)
        if type(context) ~= "table" then
            return nil
        end

        local contributions = {}
        if context.kind == "breakable_reward" then
            local rewardMultiplier = self:GetModifier("breakable_reward_multiplier", 1) or 1
            if rewardMultiplier ~= 1 then
                table.insert(contributions, {
                    label = "global_breakable_reward",
                    amount = rewardMultiplier,
                })
            end

            local currencyType = tostring(context.currency or "")
            if currencyType ~= "" then
                local currencyMultiplier = self:GetModifier(currencyType .. "_reward_multiplier", 1)
                    or 1
                if currencyMultiplier ~= 1 then
                    table.insert(contributions, {
                        label = "global_" .. currencyType .. "_reward",
                        amount = currencyMultiplier,
                    })
                end
            end
        end

        return contributions
    end)
end

function EventService:Start()
    if self._running then
        return
    end

    self._running = true
    task.spawn(function()
        while self._running do
            self:_tick()
            task.wait(tonumber(self._config.tick_seconds) or 1)
        end
    end)
end

function EventService:Destroy()
    self._running = false
end

function EventService:_loadConfig()
    local ok, config = pcall(function()
        return self._configLoader:LoadConfig("events")
    end)

    if ok and type(config) == "table" then
        config.workspace = config.workspace or DEFAULT_CONFIG.workspace
        config.modifiers = config.modifiers or {}
        config.global_events = config.global_events or {}
        config.scheduled_global_events = config.scheduled_global_events or {}
        return config
    end

    self._logger:Warn("EventService using default config", { error = tostring(config) })
    return DEFAULT_CONFIG
end

function EventService:_getSecondsUntilTomorrow(now)
    return self._serverClock:GetSecondsUntilNextUtcDay(now)
end

function EventService:_updateClockValues()
    local now = self._serverClock:GetServerTime()
    -- Mountain-local calendar (the clock folder + UI read these; events are Mountain-scheduled).
    local current = MountainTime.fromUtc(now)
    local yesterday = MountainTime.fromUtc(now - 86400)

    self:_setValue(self._clockFolder, "IntValue", "UnixTime", now)
    self:_setValue(self._clockFolder, "IntValue", "Today", current.day)
    self:_setValue(self._clockFolder, "IntValue", "Yesterday", yesterday.day)
    self:_setValue(self._clockFolder, "IntValue", "Hour", current.hour)
    self:_setValue(self._clockFolder, "IntValue", "Minute", current.min)
    self:_setValue(self._clockFolder, "IntValue", "Month", current.month)
    self:_setValue(self._clockFolder, "IntValue", "Year", current.year)
    self:_setValue(self._clockFolder, "IntValue", "JulianDay", current.yday)
    self:_setValue(self._clockFolder, "IntValue", "Weekday", current.wday)
    self:_setValue(
        self._clockFolder,
        "IntValue",
        "SecondsUntilTomorrow",
        self:_getSecondsUntilTomorrow(now)
    )
end

function EventService:_weekdayMatches(schedule, weekday)
    -- weekdays = MOUNTAIN weekdays (1=Sun..7=Sat). weekdays_utc kept as a legacy fallback.
    local list = schedule.weekdays or schedule.weekdays_utc
    if type(list) ~= "table" then
        return true
    end

    for _, configuredWeekday in ipairs(list) do
        if tonumber(configuredWeekday) == weekday then
            return true
        end
    end

    return false
end

function EventService:_hourMatches(schedule, hour)
    -- start_hour/end_hour are MOUNTAIN hours; *_utc names kept as a legacy fallback.
    local startHour = tonumber(schedule.start_hour or schedule.start_hour_utc)
    local endHour = tonumber(schedule.end_hour or schedule.end_hour_utc)
    if not startHour and not endHour then
        return true
    end

    startHour = startHour or 0
    endHour = endHour or 24

    if startHour == endHour then
        return true
    elseif startHour < endHour then
        return hour >= startHour and hour < endHour
    else
        return hour >= startHour or hour < endHour
    end
end

function EventService:_isScheduleActive(schedule, now)
    if schedule.enabled == false then
        return false
    end

    local current = MountainTime.fromUtc(now)
    return self:_weekdayMatches(schedule, current.wday)
        and self:_hourMatches(schedule, current.hour)
end

function EventService:_syncScheduledEvents()
    local now = self._serverClock:GetServerTime()
    local changed = false

    for scheduleId, schedule in pairs(self._config.scheduled_global_events or {}) do
        local eventId = tostring(schedule.event_id or "")
        local active = eventId ~= "" and self:_isScheduleActive(schedule, now)
        local wasActive = self._scheduledActive[scheduleId] == true

        if active and not wasActive then
            local ok = self:StartGlobalEvent(eventId, {
                durationSeconds = -1,
                reason = schedule.reason or ("Schedule: " .. tostring(scheduleId)),
            })
            self._scheduledActive[scheduleId] = ok == true
            changed = ok == true or changed
        elseif not active and wasActive then
            self._scheduledActive[scheduleId] = nil
            local ok = self:StopGlobalEvent(eventId)
            changed = ok == true or changed
        end
    end

    return changed
end

function EventService:_setupNetworking()
    Signals.ActiveEffects.OnServerEvent:Connect(function(player, data)
        if type(data) == "table" and data.request == true then
            self:SendUpdate(player)
        end
    end)
end

function EventService:_getOrCreateFolder(parent, name)
    local folder = parent:FindFirstChild(name)
    if not folder then
        folder = Instance.new("Folder")
        folder.Name = name
        folder.Parent = parent
    end
    return folder
end

function EventService:_setValue(parent, className, name, value)
    local object = parent:FindFirstChild(name)
    if not object or not object:IsA(className) then
        if object then
            object:Destroy()
        end
        object = Instance.new(className)
        object.Name = name
        object.Parent = parent
    end
    object.Value = value
    return object
end

function EventService:_countTable(value)
    local count = 0
    if type(value) ~= "table" then
        return count
    end
    for _ in pairs(value) do
        count += 1
    end
    return count
end

function EventService:_resetModifiers()
    for modifierName, modifierConfig in pairs(self._config.modifiers or {}) do
        local baseValue = tonumber(modifierConfig.base) or 0
        self._modifiers[modifierName] = baseValue
        self:_setValue(self._modifierFolder, "NumberValue", modifierName, baseValue)
    end
end

function EventService:_normalizeDuration(eventConfig, durationSeconds)
    local duration = tonumber(durationSeconds) or tonumber(eventConfig.duration_seconds) or 0
    if duration < 0 then
        return -1
    end
    return math.max(1, math.floor(duration))
end

function EventService:_buildEventFolder(eventId, eventConfig, durationSeconds, reason)
    local now = self._serverClock:GetServerTime()
    local duration = self:_normalizeDuration(eventConfig, durationSeconds)
    local expiresAt = duration == -1 and -1 or now + duration

    local folder = self._activeFolder:FindFirstChild(eventId)
    if folder then
        folder:Destroy()
    end

    folder = Instance.new("Folder")
    folder.Name = eventId
    folder:SetAttribute("EventId", eventId)
    folder:SetAttribute("StartedAt", now)
    folder:SetAttribute("ExpiresAt", expiresAt)
    folder.Parent = self._activeFolder

    self:_setValue(folder, "StringValue", "displayName", eventConfig.display_name or eventId)
    self:_setValue(
        folder,
        "StringValue",
        "description",
        eventConfig.description or "Global event active"
    )
    self:_setValue(folder, "StringValue", "icon", eventConfig.icon or "EVENT")
    self:_setValue(folder, "StringValue", "reason", reason or "Admin event")
    self:_setValue(folder, "IntValue", "duration", duration)
    self:_setValue(folder, "IntValue", "startedAt", now)
    self:_setValue(folder, "IntValue", "expiresAt", expiresAt)
    self:_setValue(folder, "IntValue", "timeRemaining", duration)

    return folder
end

function EventService:StartGlobalEvent(eventId, options)
    options = type(options) == "table" and options or {}
    eventId = tostring(eventId or "")

    local eventConfig = self._config.global_events[eventId]
    if not eventConfig then
        return false, "Unknown global event: " .. eventId
    end

    local existing = self._activeFolder:FindFirstChild(eventId)
    if existing and eventConfig.stacking == "extend_duration" then
        local duration = self:_normalizeDuration(eventConfig, options.durationSeconds)
        local expiresAtValue = existing:FindFirstChild("expiresAt")
        local timeRemainingValue = existing:FindFirstChild("timeRemaining")
        local currentTimeRemaining = self:_getFolderTimeRemaining(existing)

        if duration == -1 then
            if expiresAtValue then
                expiresAtValue.Value = -1
            end
            existing:SetAttribute("ExpiresAt", -1)
            if timeRemainingValue then
                timeRemainingValue.Value = -1
            end
        else
            local newRemaining = math.max(0, currentTimeRemaining) + duration
            local newExpiresAt = self._serverClock:GetServerTime() + newRemaining
            if expiresAtValue then
                expiresAtValue.Value = newExpiresAt
            end
            existing:SetAttribute("ExpiresAt", newExpiresAt)
            if timeRemainingValue then
                timeRemainingValue.Value = newRemaining
            end
        end
    else
        self:_buildEventFolder(eventId, eventConfig, options.durationSeconds, options.reason)
    end

    self:_recalculateModifiers()
    self:BroadcastUpdate()

    self._logger:Info("Global event started", {
        eventId = eventId,
        reason = options.reason or "Admin event",
    })

    return true
end

function EventService:StopGlobalEvent(eventId)
    eventId = tostring(eventId or "")
    local folder = self._activeFolder:FindFirstChild(eventId)
    if not folder then
        return false, "Global event is not active: " .. eventId
    end

    folder:Destroy()
    self:_recalculateModifiers()
    self:BroadcastUpdate()

    self._logger:Info("Global event stopped", { eventId = eventId })
    return true
end

function EventService:ClearGlobalEvents()
    local count = 0
    for _, child in ipairs(self._activeFolder:GetChildren()) do
        if child:IsA("Folder") then
            child:Destroy()
            count += 1
        end
    end

    self:_recalculateModifiers()
    self:BroadcastUpdate()
    return count
end

function EventService:_getFolderTimeRemaining(folder)
    local expiresAt = folder:GetAttribute("ExpiresAt")
    if type(expiresAt) ~= "number" then
        local expiresAtValue = folder:FindFirstChild("expiresAt")
        expiresAt = expiresAtValue and expiresAtValue.Value or 0
    end

    if expiresAt == -1 then
        return -1
    end

    return math.max(0, expiresAt - self._serverClock:GetServerTime())
end

function EventService:_formatEvent(folder)
    local eventId = folder.Name
    local eventConfig = self._config.global_events[eventId] or {}
    local durationValue = folder:FindFirstChild("duration")
    local displayName = folder:FindFirstChild("displayName")
    local description = folder:FindFirstChild("description")
    local icon = folder:FindFirstChild("icon")
    local reason = folder:FindFirstChild("reason")
    local remaining = self:_getFolderTimeRemaining(folder)

    return {
        id = eventId,
        name = displayName and displayName.Value or eventConfig.display_name or eventId,
        displayName = displayName and displayName.Value or eventConfig.display_name or eventId,
        description = description and description.Value or eventConfig.description or "",
        icon = icon and icon.Value or eventConfig.icon or "EVENT",
        reason = reason and reason.Value or "Global event",
        duration = durationValue and durationValue.Value
            or eventConfig.duration_seconds
            or remaining,
        remaining = remaining,
        timeRemaining = remaining,
        active = remaining == -1 or remaining > 0,
        modifiers = eventConfig.modifiers or {},
    }
end

function EventService:GetActiveGlobalEvents()
    local events = {}
    for _, folder in ipairs(self._activeFolder:GetChildren()) do
        if folder:IsA("Folder") then
            local event = self:_formatEvent(folder)
            if event.active then
                table.insert(events, event)
            end
        end
    end
    table.sort(events, function(a, b)
        return a.id < b.id
    end)
    return events
end

function EventService:_recalculateModifiers()
    self:_resetModifiers()

    for _, event in ipairs(self:GetActiveGlobalEvents()) do
        for modifierName, delta in pairs(event.modifiers or {}) do
            local baseValue = self._modifiers[modifierName]
            if baseValue == nil then
                baseValue = 0
            end
            self._modifiers[modifierName] = baseValue + (tonumber(delta) or 0)
        end
    end

    for modifierName, value in pairs(self._modifiers) do
        self:_setValue(self._modifierFolder, "NumberValue", modifierName, value)
    end
end

function EventService:GetModifier(modifierName, fallback)
    local value = self._modifiers[modifierName]
    if value == nil then
        return fallback
    end
    return value
end

function EventService:GetAllModifiers()
    return table.clone(self._modifiers)
end

function EventService:GetConfiguredGlobalEvents()
    local events = {}
    for eventId, eventConfig in pairs(self._config.global_events or {}) do
        table.insert(events, {
            id = eventId,
            name = eventConfig.display_name or eventId,
            description = eventConfig.description or "",
            duration = eventConfig.duration_seconds or 0,
            icon = eventConfig.icon or "EVENT",
            modifiers = eventConfig.modifiers or {},
        })
    end
    table.sort(events, function(a, b)
        return a.id < b.id
    end)
    return events
end

function EventService:BuildClientPayload()
    return {
        effects = {
            playerEffects = {},
            globalEffects = self:GetActiveGlobalEvents(),
        },
        globalEvents = self:GetActiveGlobalEvents(),
        configuredGlobalEvents = self:GetConfiguredGlobalEvents(),
        modifiers = self:GetAllModifiers(),
        serverTime = self._serverClock:GetServerTime(),
        serverDayNumber = self._serverClock:GetServerDayNumber(),
        dailySeed = self._serverClock:GetDailySeed("events"),
        secondsUntilTomorrow = self:_getSecondsUntilTomorrow(self._serverClock:GetServerTime()),
    }
end

function EventService:SendUpdate(player)
    Signals.ActiveEffects:FireClient(player, self:BuildClientPayload())
end

function EventService:BroadcastUpdate()
    local payload = self:BuildClientPayload()
    for _, player in ipairs(Players:GetPlayers()) do
        Signals.ActiveEffects:FireClient(player, payload)
    end
end

function EventService:_tick()
    self:_updateClockValues()
    local scheduleChanged = self:_syncScheduledEvents()
    local changed = false

    for _, folder in ipairs(self._activeFolder:GetChildren()) do
        if folder:IsA("Folder") then
            local remaining = self:_getFolderTimeRemaining(folder)
            local timeRemainingValue = folder:FindFirstChild("timeRemaining")
            if timeRemainingValue then
                timeRemainingValue.Value = remaining
            end

            if remaining == 0 then
                folder:Destroy()
                changed = true
            end
        end
    end

    if changed then
        self:_recalculateModifiers()
    end

    if changed or scheduleChanged then
        self:BroadcastUpdate()
    end
end

return EventService
