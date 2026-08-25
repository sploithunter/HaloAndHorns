local LeaderboardStatus = loadModule("src/Shared/Game/LeaderboardStatus.lua")

return function()
    describe("LeaderboardStatus", function()
        local boards = {
            { id = "dragons", status_title = "Dragonlord" },
            { id = "defeats", status_title = "Slayer" },
            { id = "hatches", status_title = "Hatcher" },
            { id = "untitled" },
        }

        it("chooses the player's best visible placement", function()
            local best = LeaderboardStatus.bestForUser(42, boards, {
                dragons = { { userId = 42, rank = 7 } },
                defeats = { { userId = 42, rank = 2 } },
                hatches = { { userId = 42, rank = 5 } },
            }, 10)
            expect(best.title).to.equal("Slayer")
            expect(best.rank).to.equal(2)
            expect(best.boardId).to.equal("defeats")
        end)

        it("formats a hover placement line", function()
            expect(LeaderboardStatus.hoverLine("Farm", 16, "Crystal LB")).to.equal(
                "Farm #16 (#16 Crystal LB)"
            )
        end)

        it("uses config order to break an exact placement tie", function()
            local best = LeaderboardStatus.bestForUser(42, boards, {
                dragons = { { userId = 42, rank = 3 } },
                defeats = { { userId = 42, rank = 3 } },
            }, 10)
            expect(best.title).to.equal("Dragonlord")
        end)

        it("does not award a title below the configured top-100 cutoff", function()
            local best = LeaderboardStatus.bestForUser(42, boards, {
                hatches = { { userId = 42, rank = 101 } },
            }, 100)
            expect(best).to.equal(nil)
        end)
    end)
end
