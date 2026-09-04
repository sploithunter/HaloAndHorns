local Record = loadModule("src/Shared/Game/MergeWaveRecord.lua")
local Combat = loadModule("src/Shared/Game/MergeEggPlayerCombat.lua")
local People = loadModule("src/Shared/Game/PeopleList.lua")
local config = loadModule("configs/people_list.lua")
local awards = loadModule("configs/achievement_banners.lua").awards

return function()
    describe("Merge personal-best status", function()
        it("recovers only proven old checkpoint and wave-award progress", function()
            expect(Record.best({ checkpoint = { wave = 90 } })).to.equal(90)
            expect(Record.best({ playstate = { wave = 120 } })).to.equal(120)
            expect(Record.best({}, { owned = { wave_250 = { value = 260 } } }, awards)).to.equal(
                260
            )
            expect(Record.best({}, { owned = { level_50 = { value = 999 } } }, awards)).to.equal(0)
        end)
        it("preserves the best across normalization, checkpoint reset and rebirth", function()
            local state =
                Combat.normalizeOnboarding({ highest_completed_wave = 251, rebirths = 10 })
            expect(state.highest_completed_wave).to.equal(251)
            expect(Record.best(state, nil, nil, 30)).to.equal(251)
            expect(Record.best(state, nil, nil, 252)).to.equal(252)
            expect(Record.best({ highest_completed_wave = -10 })).to.equal(0)
            expect(Record.best({ highest_completed_wave = math.huge })).to.equal(0)
        end)
        it("shows each player's record instead of equipped titles only inside Merge", function()
            local state = {
                inMergePlace = true,
                mergeHighestCompletedWave = 251,
                level = 50,
                veteranLevel = 149,
                chosenTitle = "Legend",
                chosenKind = "leaderboard",
                leaderboardTitle = "Slayer",
                leaderboardRank = 1,
                area = "MergeEggPrototype",
            }
            local row = People.row(config, {}, state)
            expect(row.status).to.equal("Wave 251")
            expect(row.inspect.title).to.equal("Wave 251")
            expect(row.inspect.body).to.equal(config.merge_status.description)
            expect(People.hoverStatus(config, {}, state):find("Wave 251", 1, true)).to.be.ok()
            expect(People.profile(config, {}, state).status).to.equal("Wave 251")
            state.mergeHighestCompletedWave = 37
            expect(People.row(config, {}, state).status).to.equal("Wave 37")
            state.inMergePlace = false
            state.area = "Grass"
            state.chosenKind = "level"
            state.leaderboardTitle = nil
            expect(People.row(config, {}, state).status).to.equal("Legend")
        end)
        it("distinguishes loading from a new player's Wave 0", function()
            expect(People.row(config, {}, { inMergePlace = true }).status).to.equal("Wave —")
            expect(People.row(config, {}, {
                inMergePlace = true,
                mergeHighestCompletedWave = 0,
            }).status).to.equal("Wave 0")
        end)
    end)
end
