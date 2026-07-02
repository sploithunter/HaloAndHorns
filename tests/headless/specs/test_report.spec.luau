--[[
    Headless unit tests for TestReport (pure result aggregator).

    Run: mise run test-headless
]]

local TestReport = loadModule("src/Shared/API/TestReport.lua")

return function()
    describe("TestReport", function()
        it("accumulates passes and fails and computes the summary", function()
            local report = TestReport.new("demo")
            report:record("a", true)
            report:record("b", false, "boom")
            report:record("c", true)

            local summary = report:summary()
            expect(summary.suite).to.equal("demo")
            expect(summary.passed).to.equal(2)
            expect(summary.failed).to.equal(1)
            expect(summary.total).to.equal(3)
            expect(summary.ok).to.equal(false)
        end)

        it("reports ok=true only when every case passed", function()
            local report = TestReport.new()
            report:record("x", true)
            report:record("y", true)
            expect(report:summary().ok).to.equal(true)
        end)

        it("expect() records condition and attaches detail only on failure", function()
            local report = TestReport.new()
            report:expect("truthy", 1 == 1, "should not appear")
            report:expect("falsy", 1 == 2, "values differ")

            local summary = report:summary()
            expect(summary.cases[1].ok).to.equal(true)
            expect(summary.cases[1].detail).to.equal(nil)
            expect(summary.cases[2].ok).to.equal(false)
            expect(summary.cases[2].detail).to.equal("values differ")
        end)

        it("expectEqual() builds a descriptive failure detail", function()
            local report = TestReport.new()
            report:expectEqual("match", 5, 5)
            report:expectEqual("mismatch", 4, 7)

            local summary = report:summary()
            expect(summary.cases[1].ok).to.equal(true)
            expect(summary.cases[2].ok).to.equal(false)
            expect(summary.cases[2].detail).to.equal("expected 7, got 4")
        end)

        it("preserves case insertion order", function()
            local report = TestReport.new()
            report:record("first", true)
            report:record("second", false)
            report:record("third", true)
            local cases = report:summary().cases
            expect(cases[1].name).to.equal("first")
            expect(cases[2].name).to.equal("second")
            expect(cases[3].name).to.equal("third")
        end)
    end)
end
