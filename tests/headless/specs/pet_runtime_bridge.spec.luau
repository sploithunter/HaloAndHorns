local PetRuntimeBridge = loadModule("src/Shared/Services/PetRuntimeBridge.lua")

return function()
    describe("PetRuntimeBridge", function()
        local queue
        local bridge

        beforeEach(function()
            queue = {}
            bridge = PetRuntimeBridge.new(function(callback)
                table.insert(queue, callback)
            end)
        end)

        local function flush()
            local callbacks = queue
            queue = {}
            for _, callback in ipairs(callbacks) do
                callback()
            end
        end

        it("latches requests made before the handler registers", function()
            local calls = {}
            bridge.RequestRebuild("player")
            expect(#queue).to.equal(0)

            bridge.RegisterHandler(function(player)
                table.insert(calls, player)
            end)
            expect(#queue).to.equal(1)
            flush()

            expect(#calls).to.equal(1)
            expect(calls[1]).to.equal("player")
        end)

        it("coalesces same-turn rebuild requests per player", function()
            local calls = 0
            bridge.RegisterHandler(function()
                calls += 1
            end)

            bridge.RequestRebuild("player")
            bridge.RequestRebuild("player")
            bridge.RequestRebuild("player")
            expect(#queue).to.equal(1)
            flush()

            expect(calls).to.equal(1)
        end)

        it("keeps different players independent", function()
            local seen = {}
            bridge.RegisterHandler(function(player)
                seen[player] = true
            end)

            bridge.RequestRebuild("one")
            bridge.RequestRebuild("two")
            expect(#queue).to.equal(2)
            flush()

            expect(seen.one).to.equal(true)
            expect(seen.two).to.equal(true)
        end)

        it("can clear a departing player's pending request", function()
            local calls = 0
            bridge.RegisterHandler(function()
                calls += 1
            end)
            bridge.RequestRebuild("player")
            bridge.ClearPlayer("player")
            flush()

            expect(calls).to.equal(0)
        end)
    end)
end
