-- Bounded numeric telemetry. Dependencies are injected so disabled counters, failures,
-- cadence and retention can be tested without Studio or real player profiles.
local Diagnostics = {}
Diagnostics.__index = Diagnostics

function Diagnostics.new(config, deps)
    assert(config.sample_seconds > 0 and config.history_limit >= 1, "invalid memory sampling config")
    return setmetatable({ config = config, deps = deps, samples = {}, count = 0 }, Diagnostics)
end

function Diagnostics:sample()
    local deps = self.deps
    local now = deps.clock()
    if self.nextAt and now < self.nextAt then
        return nil
    end
    self.nextAt = now + self.config.sample_seconds
    local row = table.clone(deps.identity)
    row.timestamp = deps.utc()
    row.serverAgeSeconds = deps.age()
    row.luaGcKb = deps.gcKb()
    row.errors = {}
    local function measure(name, read)
        local ok, value = pcall(read)
        if ok then
            row[name] = value
        else
            table.insert(row.errors, name)
        end
    end
    measure("totalMb", function()
        return deps.stats:GetTotalMemoryUsageMb()
    end)
    measure("instanceCount", function()
        return deps.stats.InstanceCount
    end)
    measure("memoryTrackingEnabled", function()
        return deps.stats.MemoryTrackingEnabled
    end)
    if row.memoryTrackingEnabled == true then
        row.categoriesMb = {}
        for _, tag in ipairs(deps.tags) do
            local ok, value = pcall(deps.stats.GetMemoryUsageMbForTag, deps.stats, tag)
            if ok then
                row.categoriesMb[tag.Name] = value
            else
                table.insert(row.errors, "category:" .. tag.Name)
            end
        end
    end
    measure("workload", deps.workload)
    self.firstAt = self.firstAt or now
    row.observedSeconds = now - self.firstAt
    if row.totalMb then
        self.baselineMb = self.baselineMb or row.totalMb
        row.growthFromFirstMb = row.totalMb - self.baselineMb
    end
    self.count += 1
    row.sample = self.count
    table.insert(self.samples, row)
    if #self.samples > self.config.history_limit then
        table.remove(self.samples, 1)
    end
    return row
end

function Diagnostics:snapshot(includeHistory)
    return {
        sampleCount = self.count,
        retainedSamples = #self.samples,
        latest = self.samples[#self.samples],
        history = includeHistory == true and table.clone(self.samples) or nil,
    }
end

return Diagnostics
