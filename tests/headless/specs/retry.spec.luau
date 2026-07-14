local Retry = loadModule("src/Shared/Utils/Retry.lua")

return function()
    describe("Retry.run", function()
        it("retries transient failures with configured backoff", function()
            local calls = 0
            local waits = {}
            local ok, value, attempts = Retry.run(function()
                calls += 1
                if calls < 3 then
                    return false, "transient"
                end
                return true, 47
            end, {
                attempts = 3,
                backoff_seconds = { 0.25, 1 },
                wait = function(seconds)
                    waits[#waits + 1] = seconds
                end,
            })

            expect(ok).to.equal(true)
            expect(value).to.equal(47)
            expect(attempts).to.equal(3)
            expect(#waits).to.equal(2)
            expect(waits[1]).to.equal(0.25)
            expect(waits[2]).to.equal(1)
        end)

        it("returns the final error after the configured attempt limit", function()
            local calls = 0
            local ok, err, attempts = Retry.run(function()
                calls += 1
                return false, "failure-" .. tostring(calls)
            end, { attempts = 2, wait = function() end })

            expect(ok).to.equal(false)
            expect(err).to.equal("failure-2")
            expect(attempts).to.equal(2)
            expect(calls).to.equal(2)
        end)
    end)
end
