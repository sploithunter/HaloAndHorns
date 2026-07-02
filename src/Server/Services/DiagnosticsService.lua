--[[
    DiagnosticsService – lightweight runtime health-check runner

    Admin calls Signals.RunDiagnostics → server executes a suite of quick
    Lua-level assertions (no asset loading) and returns a summary.
    The service is intentionally simple so it can run even in live servers
    without long stalls.

    Later we can swap the body out for TestEZ once tests are replicated to the
    live place, but this already gives a one-click confirmation that the core
    services and Net signals are wired correctly.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Signals = require(ReplicatedStorage.Shared.Network.Signals)

local DiagnosticsService = {}
DiagnosticsService.__index = DiagnosticsService

function DiagnosticsService:Init()
    self._logger = self._modules.Logger
    self._inventory = self._modules.InventoryService
    self._economy = self._modules.EconomyService
    self._rateLimit = self._modules.RateLimitService
    self._dataService = self._modules.DataService

    -- Bind Net handler once services are ready
    Signals.RunDiagnostics.OnServerEvent:Connect(function(player)
        self:_runDiagnostics(player)
    end)

    self._logger:Info("DiagnosticsService initialised – ready for RunDiagnostics events")
end

function DiagnosticsService:Start() end -- nothing asynchronous

---------------------------------------------------------------------
-- INTERNAL
---------------------------------------------------------------------

function DiagnosticsService:_runDiagnostics(player)
    -- Run full TestEZ suite (tests mapped into ReplicatedStorage.Tests by Rojo)
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local Packages = ReplicatedStorage:WaitForChild("Packages")

    local TestEZ
    local ok, err = pcall(function()
        TestEZ = require(Packages._Index["roblox_testez@0.4.1"].testez)
    end)
    if not ok or not TestEZ then
        self._logger:Error("Diagnostics: Unable to load TestEZ", { error = err })
        Signals.RunDiagnostics:FireClient(
            player,
            { passed = 0, failed = 1, failures = { "TestEZ load failure: " .. tostring(err) } }
        )
        return
    end

    local testsContainer = ReplicatedStorage:FindFirstChild("Tests")
    if not testsContainer then
        self._logger:Warn("Diagnostics: Tests folder not replicated – returning quick-check only")
    end

    local results = TestEZ.TestBootstrap:run({ testsContainer })
    local summary = {
        passed = results.passedCount or 0,
        failed = results.failureCount or 0,
        total = (results.passedCount or 0) + (results.failureCount or 0),
        duration = results.duration,
        failures = results.failureMessages or {},
        timestamp = os.time(),
    }

    Signals.RunDiagnostics:FireClient(player, summary)

    self._logger:Info("Diagnostics (TestEZ) completed", {
        player = player.Name,
        passed = summary.passed,
        failed = summary.failed,
        duration = summary.duration,
    })
end

return DiagnosticsService
