--[[
    TestReport (pure)

    A tiny result accumulator for integration scenarios. Kept Roblox-API-free so
    the report shape and pass/fail accounting are headless-tested, while the
    Studio orchestrator (tests/studio/AutomationSuite) feeds it real outcomes and
    serializes summary() to JSON for the MCP to read.

    Purity contract: standard Lua only. Tested via `mise run test-headless`.
]]

local TestReport = {}
TestReport.__index = TestReport

function TestReport.new(suiteName)
    local self = setmetatable({}, TestReport)
    self.suite = suiteName or "suite"
    self._cases = {}
    return self
end

-- Record a case outcome. `detail` is an optional message (usually the failure
-- reason). Returns `ok` so callers can branch.
function TestReport:record(name, ok, detail)
    table.insert(self._cases, {
        name = name,
        ok = ok and true or false,
        detail = detail,
    })
    return ok and true or false
end

-- Convenience: record `name` as passed iff `condition` is truthy, attaching
-- `failDetail` when it isn't. Returns the boolean condition.
function TestReport:expect(name, condition, failDetail)
    return self:record(name, condition and true or false, (not condition) and failDetail or nil)
end

-- Record a case that should equal an expected value; builds the failure detail.
function TestReport:expectEqual(name, actual, expected)
    local ok = actual == expected
    local detail = nil
    if not ok then
        detail = `expected {tostring(expected)}, got {tostring(actual)}`
    end
    return self:record(name, ok, detail)
end

-- Produce the structured summary. `ok` is true only if every case passed.
function TestReport:summary()
    local passed, failed = 0, 0
    for _, case in ipairs(self._cases) do
        if case.ok then
            passed += 1
        else
            failed += 1
        end
    end
    return {
        suite = self.suite,
        ok = failed == 0,
        passed = passed,
        failed = failed,
        total = passed + failed,
        cases = self._cases,
    }
end

return TestReport
