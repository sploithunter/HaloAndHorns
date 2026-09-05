-- Isolated fake players and injected transport. No real analytics calls or profile mutations.
local RS = game:GetService("ReplicatedStorage")
local Service = require(game.ServerScriptService.Server.Services.MergeAnalyticsService)
local Smoke = {}

function Smoke.run()
    local container = Instance.new("Folder")
    local ok, result = pcall(function()
        local service = setmetatable({
            _modules = {
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
        local ra, rb, rc = { player = a }, { player = b }, { player = c }
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
        assert(
            service:Snapshot(a).bay.funnels.activation.reached == 5,
            "Fresh activation incomplete"
        )
        assert(service:Snapshot(b).bay.funnels.activation.reached == 0, "Second player changed")
        assert(service:Snapshot(c).bay.funnels.activation == nil, "Restored activation included")
        service:Observe(c, rc, "session_ready")
        service:Observe(c, rc, "wave_cleared", 308)
        assert(service:Snapshot(c).bay.clears == 1, "Restored history counted as live clears")
        service:EndBay(a, ra, "ended")
        assert(
            service:Snapshot(b).bay ~= nil and service:Snapshot(c).bay ~= nil,
            "Other bays ended"
        )
        local replacement = { player = a }
        service:BeginBay(a, replacement, true)
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
            coverage = "activation, restored waves, stale sessions, exit, tutorial, failure buckets, transport retries, dedup, overflow",
        }
    end)
    container:Destroy()
    assert(ok, result)
    return result
end

return Smoke
