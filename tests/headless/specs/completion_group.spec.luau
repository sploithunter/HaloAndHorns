local CompletionGroup = loadModule("src/Shared/Utils/CompletionGroup.lua")

return function()
    describe("CompletionGroup", function()
        it("completes immediately when no work is expected", function()
            local group = CompletionGroup.new(0)
            expect(group:IsComplete()).to.equal(true)
            local ok = group:Await()
            expect(ok).to.equal(true)
        end)

        it("joins parallel completions independent of order", function()
            local group = CompletionGroup.new(3)
            local finished = false
            local waiter = coroutine.create(function()
                local ok = group:Await()
                finished = ok
            end)
            coroutine.resume(waiter)

            group:Resolve("third")
            group:Resolve("first")
            expect(finished).to.equal(false)
            group:Resolve("second")

            expect(finished).to.equal(true)
            expect(coroutine.status(waiter)).to.equal("dead")
        end)

        it("counts each completion key once", function()
            local group = CompletionGroup.new(2)
            expect(group:Resolve("one")).to.equal(true)
            expect(group:Resolve("one")).to.equal(false)
            expect(group:IsComplete()).to.equal(false)
            expect(group:Resolve("two")).to.equal(true)
            expect(group:IsComplete()).to.equal(true)
        end)

        it("cancels waiters with a named reason", function()
            local group = CompletionGroup.new(2)
            local ok, reason
            local waiter = coroutine.create(function()
                ok, reason = group:Await()
            end)
            coroutine.resume(waiter)
            group:Cancel("superseded")

            expect(ok).to.equal(false)
            expect(reason).to.equal("superseded")
        end)
    end)
end
