local LeasePool = loadModule("src/Shared/Utils/LeasePool.lua")

local function setup(capacity)
    local factory = {}
    function factory.create()
        return { dead = false, resets = 0, cleans = 0, destroys = 0 }
    end
    function factory.usable(value)
        return not value.dead
    end
    function factory.reset(value)
        value.resets += 1
        value.dirty = nil
    end
    function factory.clean(value)
        value.cleans += 1
        if factory.onClean then
            factory.onClean(value)
        end
    end
    function factory.destroy(value)
        value.dead = true
        value.destroys += 1
    end
    return LeasePool.new(capacity, factory), factory
end

return function()
    describe("Bounded lease pool", function()
        it("reuses a released object and resets it before the next owner", function()
            local pool = setup(2)
            local a, lease = pool:acquire()
            a.dirty = true
            expect(pool:release(a, lease)).to.equal(true)
            local b, nextLease = pool:acquire()
            expect(b).to.equal(a)
            expect(b.dirty).to.equal(nil)
            expect(b.resets).to.equal(2)
            expect(nextLease == lease).to.equal(false)
            expect(pool:stats().created).to.equal(1)
            expect(pool:stats().reused).to.equal(1)
        end)
        it("an old timeout cannot release a newer lease", function()
            local pool = setup(1)
            local a, old = pool:acquire()
            pool:release(a, old)
            local b, current = pool:acquire()
            expect(pool:release(a, old)).to.equal(false)
            expect(pool:isCurrent(b, current)).to.equal(true)
            expect(b.cleans).to.equal(1)
        end)
        it("ignores duplicate, missing and foreign releases", function()
            local pool = setup(1)
            local a, lease = pool:acquire()
            expect(pool:release(a, nil)).to.equal(false)
            expect(pool:release({}, lease)).to.equal(false)
            expect(pool:release(a, lease)).to.equal(true)
            expect(pool:release(a, lease)).to.equal(false)
            expect(pool:stats().idle).to.equal(1)
        end)
        it("caps only idle retention, never active effects", function()
            local pool = setup(1)
            local a, la = pool:acquire()
            local b, lb = pool:acquire()
            local c, lc = pool:acquire()
            expect(pool:stats().active).to.equal(3)
            pool:release(a, la)
            pool:release(b, lb)
            pool:release(c, lc)
            expect(pool:stats().idle).to.equal(1)
            expect(pool:stats().destroyed).to.equal(2)
            expect(a.dead).to.equal(false)
        end)
        it("zero capacity restores allocate/destroy", function()
            local pool = setup(0)
            local a, lease = pool:acquire()
            pool:release(a, lease)
            local b = pool:acquire()
            expect(a.dead).to.equal(true)
            expect(a == b).to.equal(false)
            expect(pool:stats().idle).to.equal(0)
        end)
        it("skips externally destroyed idle objects", function()
            local pool = setup(1)
            local a, lease = pool:acquire()
            pool:release(a, lease)
            a.dead = true
            local b = pool:acquire()
            expect(a == b).to.equal(false)
            expect(pool:stats().created).to.equal(2)
        end)
        it("does not retain an externally destroyed active object", function()
            local pool = setup(1)
            local a, lease = pool:acquire()
            a.dead = true
            pool:release(a, lease)
            expect(pool:stats().idle).to.equal(0)
            expect(pool:stats().active).to.equal(0)
        end)
        it("invalidates ownership before cleanup callbacks run", function()
            local pool, factory = setup(1)
            local a, lease = pool:acquire()
            factory.onClean = function(value)
                expect(pool:isCurrent(value, lease)).to.equal(false)
                expect(pool:release(value, lease)).to.equal(false)
            end
            pool:release(a, lease)
            expect(pool:stats().released).to.equal(1)
        end)
        it("disposes active and idle objects once and rejects later acquisition", function()
            local pool = setup(2)
            local a, la = pool:acquire()
            local b, lb = pool:acquire()
            pool:release(a, la)
            pool:dispose()
            pool:dispose()
            expect(pool:stats().idle).to.equal(0)
            expect(pool:stats().active).to.equal(0)
            expect(pool:stats().destroyed).to.equal(2)
            expect(pool:release(b, lb)).to.equal(false)
            expect(pcall(function()
                pool:acquire()
            end)).to.equal(false)
        end)
        it("performs repeated lifetimes with bounded creations", function()
            local pool = setup(4)
            for _ = 1, 100 do
                local active = {}
                for _ = 1, 4 do
                    local value, lease = pool:acquire()
                    table.insert(active, { value, lease })
                end
                for _, pair in active do
                    pool:release(pair[1], pair[2])
                end
            end
            expect(pool:stats().created).to.equal(4)
            expect(pool:stats().reused).to.equal(396)
            expect(pool:stats().idle).to.equal(4)
        end)
    end)
end
