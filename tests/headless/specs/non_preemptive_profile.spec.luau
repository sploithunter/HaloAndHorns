local Adapter = loadModule("src/Shared/Game/NonPreemptiveProfileStore.lua")

return function()
    describe("non-preemptive offline profile backend", function()
        local function backend(value)
            return {
                value = value,
                GetAsync = function(self)
                    return self.value
                end,
                UpdateAsync = function(self, _, transform)
                    local nextValue = transform(self.value)
                    if nextValue then
                        self.value = nextValue
                    end
                    return nextValue
                end,
            }
        end
        it("screens absent, malformed and locked accounts without a write", function()
            local store = backend(nil)
            local adapter = Adapter.wrap(store)
            expect(adapter:canAcquire("a")).to.equal(false)
            store.value = { Data = {}, MetaData = {} }
            expect(adapter:canAcquire("a")).to.equal(true)
            store.value.MetaData.ActiveSession = { 1, "other", "online" }
            expect(adapter:canAcquire("a")).to.equal(false)
        end)
        it("screens profile eligibility without writing or acquiring a session", function()
            local store = backend({ Data = { ready = false }, MetaData = {} })
            store.UpdateAsync = function()
                error("preflight must not write")
            end
            local adapter = Adapter.wrap(store)
            local function eligible(data)
                return data.ready
            end
            expect(adapter:canAcquire("a", eligible)).to.equal(false)
            store.value.Data.ready = true
            expect(adapter:canAcquire("a", eligible)).to.equal(true)
            expect(store.value.MetaData.ActiveSession).to.equal(nil)
        end)
        it("never creates missing accounts or invokes a transform on a locked account", function()
            for _, value in ipairs({
                false,
                { MetaData = { ActiveSession = { 1, "other", "online" } } },
            }) do
                local store = backend(value or nil)
                local adapter = Adapter.wrap(store)
                adapter:begin("a")
                local called = false
                local observed = adapter:UpdateAsync("a", function()
                    called = true
                end)
                expect(called).to.equal(false)
                expect(adapter:denied("a")).to.equal(true)
                expect(observed.MetaData.ActiveSession).to.equal(nil)
                expect(store.value).to.equal(value or nil)
            end
        end)
        it("acquires an unlocked existing profile and permits only its exact session", function()
            local store = backend({ MetaData = {}, Data = { coins = 10 } })
            local adapter = Adapter.wrap(store)
            adapter:begin("a")
            adapter:UpdateAsync("a", function(current)
                current.MetaData.ActiveSession = { 1, "job", "worker" }
                return current
            end)
            adapter:UpdateAsync("a", function(current)
                current.Data.coins = 12
                return current
            end)
            expect(store.value.Data.coins).to.equal(12)
            store.value = {
                MetaData = { ActiveSession = { 1, "job", "replacement" } },
                Data = {
                    coins = 30,
                },
            }
            local called = false
            local observed = adapter:UpdateAsync("a", function(current)
                called = true
                current.Data.coins = 0
                return current
            end)
            expect(called).to.equal(false)
            expect(observed.MetaData.ActiveSession[3]).to.equal("replacement")
            expect(store.value.Data.coins).to.equal(30)
        end)
        it("keeps accounts independently fenced and permits a normal release", function()
            local store = backend({ MetaData = {}, Data = {} })
            local adapter = Adapter.wrap(store)
            adapter:begin("a")
            adapter:UpdateAsync("a", function(current)
                current.MetaData.ActiveSession = { 1, "job", "worker" }
                return current
            end)
            adapter:begin("b")
            adapter:UpdateAsync("b", function()
                error("must not steal")
            end)
            expect(adapter:denied("b")).to.equal(true)
            adapter:UpdateAsync("a", function(current)
                current.MetaData.ActiveSession = nil
                return current
            end)
            expect(store.value.MetaData.ActiveSession).to.equal(nil)
        end)
    end)
end
