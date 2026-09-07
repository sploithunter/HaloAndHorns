local Diagnostics = loadModule("src/Server/ServerMemoryDiagnostics.lua")

local function fixture(tracking)
    local now, calls = 0, 0
    local stats = { InstanceCount = 100, MemoryTrackingEnabled = tracking }
    function stats:GetTotalMemoryUsageMb()
        return 1000 + now
    end
    function stats:GetMemoryUsageMbForTag()
        calls += 1
        return 25
    end
    local d = Diagnostics.new({ sample_seconds = 60, history_limit = 3 }, {
        stats = stats,
        identity = { side = "Server", memoryScope = "live_server", placeVersion = 42 },
        clock = function()
            return now
        end,
        utc = function()
            return now
        end,
        age = function()
            return now
        end,
        gcKb = function()
            return 1234
        end,
        tags = { { Name = "LuaHeap" }, { Name = "Instances" } },
        workload = function()
            return { players = 1, petModels = 600 }
        end,
    })
    return d,
        stats,
        function(value)
            now = value
        end,
        function()
            return calls
        end
end

return function()
    describe("Server memory diagnostics", function()
        it("collects categories when enabled and retains explicit server provenance", function()
            local d, _, _, calls = fixture(true)
            local row = d:sample()
            expect(row.side).to.equal("Server")
            expect(row.memoryScope).to.equal("live_server")
            expect(row.categoriesMb.LuaHeap).to.equal(25)
            expect(row.workload.petModels).to.equal(600)
            expect(calls()).to.equal(2)
        end)
        it("never calls disabled category counters or invents zero usage", function()
            local d, _, _, calls = fixture(false)
            local row = d:sample()
            expect(row.memoryTrackingEnabled).to.equal(false)
            expect(row.categoriesMb).to.equal(nil)
            expect(row.totalMb).to.equal(1000)
            expect(row.luaGcKb).to.equal(1234)
            expect(calls()).to.equal(0)
        end)
        it("bounds history and measurement cadence while keeping the initial baseline", function()
            local d, _, setTime, calls = fixture(true)
            d:sample()
            setTime(59)
            expect(d:sample()).to.equal(nil)
            expect(calls()).to.equal(2)
            for t = 60, 600, 60 do
                setTime(t)
                d:sample()
            end
            local result = d:snapshot(true)
            expect(result.sampleCount).to.equal(11)
            expect(#result.history).to.equal(3)
            expect(result.latest.growthFromFirstMb).to.equal(600)
            expect(result.latest.observedSeconds).to.equal(600)
            expect(d:snapshot(false).history).to.equal(nil)
        end)
        it("records unsupported category reads without dropping other measurements", function()
            local d, stats = fixture(true)
            function stats:GetMemoryUsageMbForTag(tag)
                if tag.Name == "LuaHeap" then
                    error("unavailable")
                end
                return 4
            end
            local row = d:sample()
            expect(row.categoriesMb.LuaHeap).to.equal(nil)
            expect(row.categoriesMb.Instances).to.equal(4)
            expect(row.errors[1]).to.equal("category:LuaHeap")
            expect(row.totalMb).to.equal(1000)
        end)
    end)
end
