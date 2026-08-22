local WindowAward = loadModule("src/Shared/Game/LeaderboardWindowAward.lua")

local TIERS = {
    { max_rank = 1, label = "100 Gems", reward = { currencies = { gems = 100 } } },
    { max_rank = 3, label = "50 Gems", reward = { currencies = { gems = 50 } } },
    { max_rank = 10, label = "25 Gems", reward = { currencies = { gems = 25 } } },
}

local function advance(state, rank, now)
    return WindowAward.advance(state, rank and { rank = rank } or nil, {
        now = now,
        window_seconds = 300,
        board_id = "range_current",
        board_name = "The Range",
        tiers = TIERS,
    })
end

local function advanceFixed(state, rank, now, startedAt)
    return WindowAward.advance(state, rank and {
        rank = rank,
        window_started_at = startedAt,
    } or nil, {
        now = now,
        window_seconds = 300,
        board_id = "range_current",
        board_name = "The Range",
        tiers = TIERS,
    })
end

return function()
    describe("LeaderboardWindowAward", function()
        it("keeps the lowest numeric rank reached during the rolling window", function()
            local state = advance(nil, 6, 100)
            state = advance(state, 8, 150)
            state = advance(state, 2, 200)
            expect(state.active.started_at).to.equal(100)
            expect(state.active.best_rank).to.equal(2)
            expect(state.pending).to.equal(nil)
        end)

        it("settles one immutable award and starts the next observed window", function()
            local state = advance(nil, 6, 100)
            state = advance(state, 2, 200)
            state = advance(state, 5, 400)

            expect(state.pending.id).to.equal("leaderboard:range_current:100")
            expect(state.pending.rank).to.equal(2)
            expect(state.pending.bundle.currencies.gems).to.equal(50)
            expect(state.active.started_at).to.equal(400)
            expect(state.active.best_rank).to.equal(5)

            TIERS[2].reward.currencies.gems = 999
            expect(state.pending.bundle.currencies.gems).to.equal(50)
            TIERS[2].reward.currencies.gems = 50
        end)

        it("acknowledges only the matching outbox id without losing the active window", function()
            local state = advance(advance(nil, 1, 100), 4, 400)
            local unchanged, didAck = WindowAward.acknowledge(state, "wrong", 401)
            expect(didAck).to.equal(false)
            expect(unchanged.pending).never.to.equal(nil)

            local acknowledged
            acknowledged, didAck = WindowAward.acknowledge(state, state.pending.id, 402)
            expect(didAck).to.equal(true)
            expect(acknowledged.pending).to.equal(nil)
            expect(acknowledged.last_queued_at).to.equal(402)
            expect(acknowledged.active.best_rank).to.equal(4)
        end)

        it("settles an expired offline window without requiring a new placement", function()
            local state = advance(nil, 10, 100)
            state = advance(state, nil, 401)
            expect(state.active).to.equal(nil)
            expect(state.pending.rank).to.equal(10)
            expect(state.pending.bundle.currencies.gems).to.equal(25)
        end)

        it(
            "aligns an entrant to the public board round rather than first observation time",
            function()
                local state = advanceFixed(nil, 4, 275, 0)
                expect(state.active.started_at).to.equal(0)
                state = advanceFixed(state, nil, 300, 300)
                expect(state.active).to.equal(nil)
                expect(state.pending.id).to.equal("leaderboard:range_current:0")
                expect(state.pending.rank).to.equal(4)
            end
        )

        it("freezes an expired active window while an older outbox award is pending", function()
            local state = advance(nil, 1, 100)
            state = advance(state, 4, 400)
            expect(state.pending.rank).to.equal(1)
            expect(state.active.best_rank).to.equal(4)

            state = advance(state, 2, 701)
            expect(state.pending.rank).to.equal(1)
            expect(state.active.best_rank).to.equal(4)
        end)
    end)
end
