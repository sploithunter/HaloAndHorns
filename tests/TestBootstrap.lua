--[[
    TestBootstrap - Runs all unit and integration tests
    
    Usage:
    1. Place this script in ServerScriptService
    2. Run the game in Studio
    3. Check output for test results
    
    Or run from command line with:
    rojo serve --port 34872
    Then run this script in Studio
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- Wait for packages
local Packages = ReplicatedStorage:WaitForChild("Packages", 10)
if not Packages then
    error("Packages not found - run 'wally install' first")
end

local Locations = require(ReplicatedStorage.Shared.Locations)
local TestEZ = Locations.getPackage("TestEZ")

print("🧪 Starting Game Template Tests...")

-- Define test locations
local testLocations = {
    -- Test shared modules
    ReplicatedStorage.Shared,

    -- Test server modules
    ServerScriptService.Server,

    -- Test specific test files
    script.Parent.unit,
    script.Parent.integration,
}

-- Custom test reporter for better output
local TestReporter = {}
TestReporter.__index = TestReporter

function TestReporter.new()
    return setmetatable({
        testCount = 0,
        passCount = 0,
        failCount = 0,
        skipCount = 0,
        startTime = tick(),
    }, TestReporter)
end

function TestReporter:report(results)
    local endTime = tick()
    local duration = endTime - self.startTime

    print("\n" .. ("="):rep(50))
    print("🧪 TEST RESULTS")
    print(("="):rep(50))

    -- Count results
    for _, result in pairs(results) do
        if result.status == "Success" then
            self.passCount = self.passCount + 1
        elseif result.status == "Failure" then
            self.failCount = self.failCount + 1
        elseif result.status == "Skipped" then
            self.skipCount = self.skipCount + 1
        end
        self.testCount = self.testCount + 1
    end

    -- Print summary
    if self.failCount == 0 then
        print("✅ ALL TESTS PASSED!")
    else
        print("❌ SOME TESTS FAILED!")
    end

    print(
        string.format(
            "📊 Total: %d | Passed: %d | Failed: %d | Skipped: %d",
            self.testCount,
            self.passCount,
            self.failCount,
            self.skipCount
        )
    )
    print(string.format("⏱️  Duration: %.3f seconds", duration))

    -- Print failures
    if self.failCount > 0 then
        print("\n❌ FAILURES:")
        for _, result in pairs(results) do
            if result.status == "Failure" then
                print(
                    string.format(
                        "  • %s: %s",
                        result.test or "Unknown",
                        result.message or "No message"
                    )
                )
            end
        end
    end

    print(("="):rep(50))

    return self.failCount == 0
end

-- Run tests with custom reporter
local reporter = TestReporter.new()

local success, results = pcall(function()
    return TestEZ.TestBootstrap:run(testLocations, reporter)
end)

if not success then
    warn("❌ Test execution failed: " .. tostring(results))
else
    if reporter:report(results) then
        print("🎉 All tests completed successfully!")
    else
        warn("💥 Tests completed with failures!")
    end
end
