-- Isolated fake players and injected transport. No real analytics calls or profile mutations.
local RS = game:GetService("ReplicatedStorage")
local Service = require(game.ServerScriptService.Server.Services.MergeAnalyticsService)
local Smoke = {}

function Smoke.run()
    local container = Instance.new("Folder")
    local ok, result = pcall(function()
        local archived = {}
        local service = setmetatable({
            _modules = {
                DataService = {
                    GetData = function(_, player)
                        return { GameData = {}, Tutorial = { done = player.graduate == true } }
                    end,
                },
                RetentionService = {
                    RecordMergeTelemetry = function(_, player, name, context)
                        table.insert(archived, { player = player, name = name, context = context })
                    end,
                },
                ConfigLoader = {
                    LoadConfig = function(_, name)
                        return require(RS.Configs[name])
                    end,
                },
            },
        }, { __index = Service })
        service:Init()
        assert(service._enabled, "Run in the Merge place")
        local function actor(id)
            local attrs = Instance.new("Folder")
            attrs.Parent = container
            local player = { Name = "analytics_test_" .. id, UserId = id }
            function player:GetAttribute(key)
                return attrs:GetAttribute(key)
            end
            function player:SetAttribute(key, value)
                attrs:SetAttribute(key, value)
            end
            function player:GetAttributeChangedSignal(key)
                return attrs:GetAttributeChangedSignal(key)
            end
            service:Register(player)
            return player
        end
        local a, b, c = actor(-1), actor(-2), actor(-3)
        local function world(side)
            local model = Instance.new("Model")
            model:SetAttribute("MergeEggBaySide", side)
            model.Parent = container
            return model
        end
        local ra, rb, rc =
            { player = a, world = world("heaven") },
            { player = b, world = world("hell") },
            { player = c, world = world("heaven") }
        local offline = { UserId = 123, Name = "offline_test", OfflineActor = true }
        service:Register(offline)
        assert(service._players[offline] == nil, "Offline worker entered player funnels")
        a:SetAttribute("DataLoaded", true)
        b:SetAttribute("DataLoaded", true)
        c:SetAttribute("DataLoaded", true)
        service:BeginBay(a, ra, false)
        service:BeginBay(b, rb, false)
        service:BeginBay(c, rc, true)
        service:Observe(a, ra, "session_ready")
        service:Observe(a, ra, "egg_created")
        service:Observe(a, ra, "egg_placed")
        service:Observe(a, ra, "wave_started")
        service:Observe(a, ra, "wave_cleared", 1)
        local aState = service:Snapshot(a)
        assert(
            aState.entry.fields.entry.CustomField02 == "manual:unassigned",
            "Entry was relabeled"
        )
        assert(
            aState.bay.fields.activation.CustomField02 == "manual:heaven",
            "Missing Heaven filter"
        )
        assert(
            aState.bay.fields.depth.CustomField03 == tostring(game.PlaceVersion),
            "Build filter lost"
        )
        a:SetAttribute("MergeAutoplayEnabled", true)
        service:Observe(a, ra, "coin_collected")
        assert(
            aState.bay.fields.activation.CustomField02 == "manual:heaven",
            "Funnel cohort changed"
        )
        assert(
            aState.trace[#aState.trace].fields.CustomField03 == "autoplay:heaven",
            "Current mode missing"
        )
        a:SetAttribute("MergeAutoplayEnabled", false)
        assert(
            service:Snapshot(a).bay.funnels.activation.reached == 6,
            "Fresh activation incomplete"
        )
        assert(service:Snapshot(b).bay.funnels.activation.reached == 0, "Second player changed")
        assert(service:Snapshot(c).bay.funnels.activation == nil, "Restored activation included")
        service:Observe(c, rc, "session_ready")
        service:Observe(c, rc, "wave_cleared", 308)
        assert(service:Snapshot(c).bay.clears == 1, "Restored history counted as live clears")
        assert(service:Snapshot(c).bay.lastActivity == "wave_later", "Late exit mislabeled early")
        local graduate = actor(-4)
        graduate.graduate = true
        service:BeginBay(graduate, { player = graduate, world = world("hell") }, false)
        assert(
            service:Snapshot(graduate).bay.funnels.activation == nil,
            "Graduate entered onboarding"
        )
        for _, step in ipairs(service._config.funnels.activation.steps) do
            local waveNumber = tonumber(step[1]:match("^wave_resolved_(%d+)$"))
            if waveNumber then
                service:Observe(b, rb, "wave_started", waveNumber)
                service:Observe(b, rb, "wave_cleared", waveNumber)
            else
                service:Observe(b, rb, step[1])
            end
        end
        assert(service:Snapshot(b).bay.funnels.activation.reached == 33, "Wave 20 path incomplete")
        local earlyEvents = #archived
        service:Observe(b, rb, "wave_cleared", 20)
        service:Observe(b, rb, "wave_started", 20)
        assert(#archived == earlyEvents, "Early-wave events repeated")
        a:SetAttribute("MergeEggBaySide", "hell") -- Incoming attribute must not relabel outgoing exit.
        service:EndBay(a, ra, "ended")
        assert(archived[#archived].context.realm == "heaven", "Exit attributed to incoming bay")
        assert(archived[#archived].context.resolvedWavesCapped == 1, "Exit lost run depth")
        assert(archived[#archived].context.baySessionId == aState.bay.id, "Exit lost bay identity")
        assert(
            service:Snapshot(b).bay ~= nil and service:Snapshot(c).bay ~= nil,
            "Other bays ended"
        )
        local replacement = { player = a, world = world("hell") }
        service:BeginBay(a, replacement, true)
        service:Observe(a, replacement, "session_ready")
        assert(
            service:Snapshot(a).bay.fields.depth.CustomField02 == "manual:hell",
            "Switch kept old realm"
        )
        service:Observe(a, ra, "wave_cleared", 500)
        service:EndBay(a, ra, "ended")
        assert(service:Snapshot(a).bay.clears == 0, "Stale record changed replacement session")
        assert(service:Snapshot(a).bay ~= nil, "Stale record ended replacement")
        local before = #service:Snapshot(b).trace
        for _ = 1, 20 do
            service:Failure(b, "arbitrary player/error data", "arbitrary client action")
        end
        assert(#service:Snapshot(b).trace == before + 1, "Failures must deduplicate and bucket")
        assert(
            service:Snapshot(b).trace[#service:Snapshot(b).trace].fields.CustomField01 == "other",
            "Unbounded failure dimension"
        )
        service:Observe(b, rb, "tutorial_step", "collect_setup")
        service:Observe(b, rb, "tutorial_step", "collect_setup")
        service:EndBay(b, rb, "leave")
        assert(
            service._players[b].lastExit.fields.CustomField01 == "tutorial_collect_setup",
            "Wrong exit stage"
        )
        assert(service:Snapshot(a).queued == 0, "Studio must not send native analytics")
        assert(
            #archived > 0 and archived[1].name == service._config.archive_event,
            "Raw mirror missing"
        )

        -- Test the actual archive sink with no stores, real players, profile saves or remotes.
        local Retention = require(game.ServerScriptService.Server.Services.RetentionService)
        local rawBegins, rawWrites = 0, 0
        local sink = setmetatable({
            _dataService = {
                IsDataLoaded = function(_, player)
                    return player.loaded
                end,
            },
            _beginRawSession = function()
                rawBegins += 1
            end,
            _appendRawEvent = function()
                rawWrites += 1
            end,
        }, { __index = Retention })
        sink:RecordMergeTelemetry({ Parent = true, loaded = true }, "test", {})
        sink:RecordMergeTelemetry({ Parent = true, loaded = false }, "test", {})
        sink:RecordMergeTelemetry({ Parent = true, loaded = true, OfflineActor = true }, "test", {})
        sink:RecordMergeTelemetry({ loaded = true }, "test", {})
        assert(
            rawBegins == 0 and rawWrites == 1,
            "Raw sink must reject unloaded/departed/offline actors"
        )

        -- Inject transport to test failures without AnalyticsService/production traffic.
        local emissions = 0
        function service:_emit()
            emissions += 1
            error("synthetic transport outage")
        end
        local event = { kind = "funnel", session = "isolated", funnel = "test", step = 1 }
        local item = { player = a, event = event, attempts = 0 }
        for attempt = 1, service._config.retry_limit do
            assert(
                service:_send(item) == (attempt == service._config.retry_limit),
                "Wrong retry bound"
            )
        end
        assert(service:_send({
            player = a,
            event = { kind = "funnel", session = "isolated", funnel = "test", step = 2 },
            attempts = 0,
        }))
        assert(
            emissions == service._config.retry_limit,
            "Later native steps must not fill a failed predecessor"
        )
        function service:_emit()
            emissions += 1
        end
        local delivered = { player = c, event = { kind = "custom" }, attempts = 0 }
        assert(service:_send(delivered))
        assert(service:_send(delivered))
        assert(
            emissions == service._config.retry_limit + 1,
            "Exit flush must not resend delivered events"
        )
        function service:_suppressed()
            return false
        end
        service._config = table.clone(service._config)
        service._config.queue_limit = 1
        service:_enqueue(a, { kind = "custom" })
        service:_enqueue(c, { kind = "funnel", session = "overflow", funnel = "test", step = 1 })
        assert(#service._queue == 1, "Queue exceeded bound")
        assert(service:_send({
            player = c,
            event = { kind = "funnel", session = "overflow", funnel = "test", step = 2 },
            attempts = 0,
        }))
        assert(emissions == service._config.retry_limit + 1, "Overflow fabricated a later step")
        for _, visit in pairs(service._players) do
            for _, connection in ipairs(visit.connections) do
                connection:Disconnect()
            end
        end
        return {
            passed = true,
            actors = 3,
            isolated = true,
            nativeCalls = 0,
            coverage = "activation, realms, immutable cohorts, raw mirror, offline exclusion, restored waves, stale sessions, exit, tutorial, failure buckets, transport retries, dedup, overflow",
        }
    end)
    container:Destroy()
    assert(ok, result)
    return result
end

return Smoke
