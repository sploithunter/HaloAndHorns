--[[
    BootReadiness — race-free one-shot latch [unit] scenarios.
    Run: mise run test-headless

    Under the headless runner there is no `task`, so BootReadiness resumes waiters via
    coroutine.resume. These specs drive `await` from explicit coroutines to exercise both the
    already-signalled fast path and the wait-then-resume path deterministically.
]]

local Boot = loadModule("src/Shared/Boot/BootReadiness.lua")

return function()
    describe("BootReadiness", function()
        beforeEach(function()
            Boot.reset()
        end)

        it("isReady is false before signal, true after", function()
            expect(Boot.isReady("models_ready")).to.equal(false)
            Boot.signal("models_ready")
            expect(Boot.isReady("models_ready")).to.equal(true)
        end)

        it("await after signal returns immediately without yielding", function()
            Boot.signal("world_structure")
            local done = false
            local co = coroutine.create(function()
                Boot.await("world_structure")
                done = true
            end)
            coroutine.resume(co)
            -- never yielded: the coroutine ran to completion in one resume
            expect(done).to.equal(true)
            expect(coroutine.status(co)).to.equal("dead")
        end)

        it("await before signal waits, then resumes when signalled", function()
            local done = false
            local co = coroutine.create(function()
                Boot.await("crystals_ready")
                done = true
            end)
            coroutine.resume(co) -- enters await, yields
            expect(done).to.equal(false)
            expect(coroutine.status(co)).to.equal("suspended")

            Boot.signal("crystals_ready") -- releases the waiter
            expect(done).to.equal(true)
            expect(coroutine.status(co)).to.equal("dead")
        end)

        it("releases multiple waiters on a single signal", function()
            local count = 0
            for _ = 1, 3 do
                local co = coroutine.create(function()
                    Boot.await("models_ready")
                    count = count + 1
                end)
                coroutine.resume(co)
            end
            expect(count).to.equal(0)
            Boot.signal("models_ready")
            expect(count).to.equal(3)
        end)

        it("signal is idempotent: first returns true, second returns false", function()
            expect(Boot.signal("eggs_placed")).to.equal(true)
            expect(Boot.signal("eggs_placed")).to.equal(false)
            expect(Boot.isReady("eggs_placed")).to.equal(true)
        end)

        it("a second signal does not re-resume an already-completed waiter", function()
            local count = 0
            local co = coroutine.create(function()
                Boot.await("models_ready")
                count = count + 1
            end)
            coroutine.resume(co)
            Boot.signal("models_ready")
            expect(count).to.equal(1)
            Boot.signal("models_ready") -- no-op
            expect(count).to.equal(1)
        end)

        it("observers fire on signal with the milestone name", function()
            local seen = {}
            Boot.observe(function(name)
                seen[name] = true
            end)
            Boot.signal("world_structure")
            Boot.signal("models_ready")
            expect(seen.world_structure).to.equal(true)
            expect(seen.models_ready).to.equal(true)
        end)

        it("snapshot reflects ready state per milestone", function()
            Boot.signal("world_structure")
            local snap = Boot.snapshot()
            expect(snap.world_structure.ready).to.equal(true)
            -- an unsignalled milestone that was awaited shows up as not-ready
            local co = coroutine.create(function()
                Boot.await("models_ready")
            end)
            coroutine.resume(co)
            expect(Boot.snapshot().models_ready.ready).to.equal(false)
        end)

        it("begin then signal: observer sees started then ready with a numeric duration", function()
            local phases = {}
            local readyDuration = "none"
            Boot.observe(function(name, info)
                table.insert(phases, info and info.phase or "?")
                if info and info.phase == "ready" then
                    readyDuration = info.duration
                end
            end)
            Boot.begin("models_ready")
            Boot.signal("models_ready")
            expect(phases[1]).to.equal("started")
            expect(phases[2]).to.equal("ready")
            expect(type(readyDuration)).to.equal("number")
        end)

        it("begin is idempotent and ignored once ready", function()
            expect(Boot.begin("eggs_placed")).to.equal(true)
            expect(Boot.begin("eggs_placed")).to.equal(false) -- already started
            Boot.signal("eggs_placed")
            expect(Boot.begin("eggs_placed")).to.equal(false) -- already ready
        end)

        it("snapshot exposes startedAt after begin", function()
            Boot.begin("crystals_ready")
            expect(type(Boot.snapshot().crystals_ready.startedAt)).to.equal("number")
        end)
    end)
end
