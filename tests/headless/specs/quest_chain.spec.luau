--[[
    QuestChain — [unit] per-track quest gating. Tracks run in parallel; within a track a mission
    is locked until every lower-order non-repeatable one is claimed.
    Run: mise run test-headless
]]

local QuestChain = loadModule("src/Shared/Game/QuestChain.lua")

-- Build a fresh entry list each test (annotate mutates `.locked` in place).
local function entries()
    return {
        { id = "h1", track = "hatchery", order = 1, claimedCount = 1 },
        { id = "h2", track = "hatchery", order = 2, claimedCount = 0 },
        { id = "h3", track = "hatchery", order = 3, claimedCount = 0 },
        { id = "m1", track = "mining", order = 1, claimedCount = 0 },
        { id = "m2", track = "mining", order = 2, claimedCount = 0 },
    }
end

local function byId(list)
    local map = {}
    for _, e in ipairs(list) do
        map[e.id] = e
    end
    return map
end

return function()
    describe("QuestChain.annotate — per-track locking", function()
        it("unlocks a track's head and locks everything behind it", function()
            local list, heads = QuestChain.annotate(entries())
            local q = byId(list)
            -- hatchery: h1 claimed -> h2 is the active head (unlocked), h3 locked behind h2
            expect(q.h1.locked).to.equal(false)
            expect(q.h2.locked).to.equal(false)
            expect(q.h3.locked).to.equal(true)
            expect(heads.h2).to.equal(true)
            expect(heads.h3).never.to.be.ok()
        end)

        it("tracks are independent — each has its own active head", function()
            local _, heads = QuestChain.annotate(entries())
            -- mining: m1 unclaimed is its head; hatchery head is h2 — both active at once
            expect(heads.m1).to.equal(true)
            expect(heads.h2).to.equal(true)
        end)

        it("a fully-claimed track has no head and nothing locked", function()
            local list, heads = QuestChain.annotate({
                { id = "a", track = "t", order = 1, claimedCount = 1 },
                { id = "b", track = "t", order = 2, claimedCount = 1 },
            })
            local q = byId(list)
            expect(q.a.locked).to.equal(false)
            expect(q.b.locked).to.equal(false)
            expect(heads.a).never.to.be.ok()
            expect(heads.b).never.to.be.ok()
        end)

        it("respects order regardless of input ordering", function()
            -- same track, supplied out of order — order 1 must still be the head
            local list = QuestChain.annotate({
                { id = "third", track = "t", order = 3, claimedCount = 0 },
                { id = "first", track = "t", order = 1, claimedCount = 0 },
                { id = "second", track = "t", order = 2, claimedCount = 0 },
            })
            local q = byId(list)
            expect(q.first.locked).to.equal(false)
            expect(q.second.locked).to.equal(true)
            expect(q.third.locked).to.equal(true)
        end)

        it("a repeatable unclaimed mission does not block the rest of its track", function()
            local list = QuestChain.annotate({
                { id = "rep", track = "t", order = 1, claimedCount = 0, repeatable = true },
                { id = "next", track = "t", order = 2, claimedCount = 0 },
            })
            local q = byId(list)
            expect(q.rep.locked).to.equal(false)
            expect(q.next.locked).to.equal(false)
        end)
    end)
end
