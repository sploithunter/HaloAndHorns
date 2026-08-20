local AwardPodiumLogic = loadModule("src/Shared/Game/AwardPodiumLogic.lua")
local BlockLetterSign = loadModule("src/Shared/Assets/BlockLetterSign.lua")
local leaderboards = loadModule("configs/leaderboards.lua")

return function()
    describe("AwardPodiumLogic", function()
        it("stands second left, first center, third right", function()
            expect(AwardPodiumLogic.stepX(1, 4, 0.5)).to.equal(0)
            expect(AwardPodiumLogic.stepX(2, 4, 0.5)).to.equal(-4.5)
            expect(AwardPodiumLogic.stepX(3, 4, 0.5)).to.equal(4.5)
            expect(AwardPodiumLogic.stepHeight(1, { 6, 4, 2 })).to.equal(6)
        end)

        it("fills ranks from the snapshot and pads extras without duplicates", function()
            local slots = AwardPodiumLogic.slots({
                { userId = 11, displayName = "Ace", value = 90 },
                { userId = 22, displayName = "Bea", value = 40 },
            }, {
                { userId = 11, displayName = "Ace", value = 0 },
                { userId = 33, displayName = "Cy", value = 0 },
            }, 3)
            expect(#slots).to.equal(3)
            expect(slots[1].userId).to.equal(11)
            expect(slots[2].userId).to.equal(22)
            expect(slots[3].userId).to.equal(33)
            expect(slots[1].rank).to.equal(1)
        end)

        it("picks a dance from the pool and avoids repeating the last clip", function()
            local pool = { "rbxassetid://1", "rbxassetid://2" }
            local first = AwardPodiumLogic.pickClip(pool)
            expect(first == pool[1] or first == pool[2]).to.equal(true)
            local second = AwardPodiumLogic.pickClip(pool, pool[1])
            expect(second).to.equal(pool[2])
        end)

        it("rebuilds figures only when the occupants change", function()
            local first = AwardPodiumLogic.slots({
                { userId = 11, displayName = "Ace", value = 90 },
                { userId = 22, displayName = "Bea", value = 40 },
                { userId = 33, displayName = "Cy", value = 10 },
            }, nil, 3)
            local samePeople = AwardPodiumLogic.slots({
                { userId = 11, displayName = "Ace", value = 91 },
                { userId = 22, displayName = "Bea", value = 40 },
                { userId = 33, displayName = "Cy", value = 10 },
            }, nil, 3)
            local newPeople = AwardPodiumLogic.slots({
                { userId = 44, displayName = "Dee", value = 100 },
                { userId = 22, displayName = "Bea", value = 40 },
                { userId = 33, displayName = "Cy", value = 10 },
            }, nil, 3)
            expect(AwardPodiumLogic.occupantKey(first)).to.equal(
                AwardPodiumLogic.occupantKey(samePeople)
            )
            expect(AwardPodiumLogic.scoreKey(first) == AwardPodiumLogic.scoreKey(samePeople)).to.equal(
                false
            )
            expect(AwardPodiumLogic.occupantKey(first) == AwardPodiumLogic.occupantKey(newPeople)).to.equal(
                false
            )
        end)

        it("authors four Hall award stands on the origin boards", function()
            expect(#leaderboards.podiums).to.equal(4)
            local boards = {}
            for _, podium in ipairs(leaderboards.podiums) do
                boards[podium.board_id] = podium
                expect(podium.location).to.equal(nil)
                expect(podium.pad_with_server_players).to.equal(nil)
                expect(#BlockLetterSign.missingGlyphs(podium.title)).to.equal(0)
            end
            expect(boards.most_dragons).to.be.ok()
            local dragonlord
            for _, board in ipairs(leaderboards.boards) do
                if board.id == "most_dragons" then
                    dragonlord = board
                end
            end
            local counted = {}
            for _, petId in ipairs(dragonlord.score.pet_ids) do
                counted[petId] = true
            end
            expect(counted.wyrmling).to.equal(nil)
            expect(counted.dragon).to.equal(true)
            expect(counted.abyssal_wyrm).to.equal(true)
            expect(counted.portal_drake).to.equal(true)
            expect(boards.crystal_crusher).to.be.ok()
            expect(boards.enemies_defeated).to.be.ok()
            expect(boards.team_power).to.be.ok()
            expect(leaderboards.publication.studio_read_global).to.equal(true)
            local accounts = loadModule("configs/internal_accounts.lua")
            local InternalAccounts = loadModule("src/Shared/Game/InternalAccounts.lua")
            expect(InternalAccounts.isUserId(accounts, 3200870803)).to.equal(true)
            expect(InternalAccounts.isUserId(accounts, 3539984059)).to.equal(true)
            expect(InternalAccounts.isUserId(accounts, 3086045027)).to.equal(true)
            expect(InternalAccounts.isUserId(accounts, 3047771242)).to.equal(true)
            expect(BlockLetterSign.glyph("1")).to.be.ok()
            expect(BlockLetterSign.glyph("2")).to.be.ok()
            expect(BlockLetterSign.glyph("3")).to.be.ok()
        end)
    end)
end
