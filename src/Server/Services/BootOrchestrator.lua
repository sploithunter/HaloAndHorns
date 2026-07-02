--[[
    BootOrchestrator (server) — owns the event-driven boot milestone graph.

    See docs/BOOT_ORCHESTRATION.md. Responsibilities:
      1. Validate the configs/boot.lua dependency graph at boot (loud error if cyclic / a
         required milestone has no declared producer) — the next race caught at startup.
      2. Observe every BootReadiness.signal and LOG it ([BOOT] milestone ready), warning on any
         undeclared milestone — the permanent, structured replacement for the lag-hunt perf tags.
      3. Mirror milestone state to ReplicatedStorage.BootStatus (one bool attribute per server
         milestone) so clients gate the loading screen on REAL server readiness, not workspace
         symptom-polls.

    Services produce/consume milestones by requiring BootReadiness directly
    (signal/await) — this service only validates, mirrors, and logs.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BootReadiness = require(ReplicatedStorage.Shared.Boot.BootReadiness)
local BootGraph = require(ReplicatedStorage.Shared.Boot.BootGraph)

local BootOrchestrator = {}
BootOrchestrator.__index = BootOrchestrator

local STATUS_FOLDER_NAME = "BootStatus"

function BootOrchestrator:Init()
    self._logger = self._modules.Logger
    assert(self._logger, "BootOrchestrator: Logger dependency missing")

    local ok, bootConfig = pcall(function()
        return require(ReplicatedStorage.Configs:WaitForChild("boot"))
    end)
    if not ok or type(bootConfig) ~= "table" then
        self._logger:Error("BootOrchestrator: configs/boot.lua failed to load; boot graph inert", {
            error = tostring(bootConfig),
        })
        self._milestones = {}
        bootConfig = { milestones = {} }
    else
        self._milestones = bootConfig.milestones or {}
    end
    self._config = bootConfig
    self._bootT0 = os.clock() -- reference for the elapsed-since-boot stamp on each milestone line

    -- Validate the dependency graph LOUDLY at boot.
    local valid, errors = BootGraph.validate(self._milestones)
    if not valid then
        for _, msg in ipairs(errors) do
            self._logger:Error("BootOrchestrator: invalid boot graph", { problem = msg })
            print("[BOOT] INVALID GRAPH: " .. tostring(msg))
        end
    else
        -- print (not just logger) so the expected milestone order is visible in Studio Output.
        print("[BOOT] graph: " .. table.concat(BootGraph.order(self._milestones), " -> "))
    end

    -- Create the client-facing mirror with one (false) attribute per server milestone.
    local folder = ReplicatedStorage:FindFirstChild(STATUS_FOLDER_NAME)
    if not folder then
        folder = Instance.new("Folder")
        folder.Name = STATUS_FOLDER_NAME
        folder.Parent = ReplicatedStorage
    end
    self._statusFolder = folder
    for name in pairs(self._milestones) do
        if folder:GetAttribute(name) == nil then
            folder:SetAttribute(name, false)
        end
    end
end

function BootOrchestrator:Start()
    -- Seed from anything that already started/finished before this observer attaches (a producer
    -- with no dependencies may begin/signal during its own Init/Start).
    for name, info in pairs(BootReadiness.snapshot()) do
        if info.startedAt then
            self:_markStarted(name)
        end
        if info.ready then
            self:_markReady(name, info.duration)
        end
    end

    -- Mirror + log every future begin/signal.
    BootReadiness.observe(function(name, info)
        if info and info.phase == "started" then
            self:_markStarted(name)
        else
            self:_markReady(name, info and info.duration)
        end
    end)
end

-- Raw print(), NOT the Logger: the structured Logger output is SUPPRESSED in Studio (same reason
-- [PREBAKE] prints), so a print is the only way these per-stage lines actually show in Studio Output
-- during boot. Each carries elapsed-since-boot so the running/slow stage is obvious at a glance.
function BootOrchestrator:_elapsed()
    return os.clock() - (self._bootT0 or os.clock())
end

function BootOrchestrator:_markStarted(name)
    if self._milestones[name] then
        print(string.format("[BOOT] %s started  +%.1fs", name, self:_elapsed()))
    end
end

function BootOrchestrator:_markReady(name, duration)
    if self._statusFolder and self._statusFolder:GetAttribute(name) ~= true then
        self._statusFolder:SetAttribute(name, true)
    end
    if self._milestones[name] then
        local tag = self._milestones[name].background and "  (background)" or ""
        local took = duration and string.format("  (took %.1fs)", duration) or ""
        print(string.format("[BOOT] %s ready  +%.1fs%s%s", name, self:_elapsed(), took, tag))
    else
        -- A BootReadiness signal with no matching declaration — almost certainly a typo.
        print(string.format("[BOOT] WARNING: undeclared milestone '%s' signalled", name))
        if self._statusFolder then
            self._statusFolder:SetAttribute(name, true)
        end
    end
end

return BootOrchestrator
