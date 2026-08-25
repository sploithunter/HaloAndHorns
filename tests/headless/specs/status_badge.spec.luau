--[[
    StatusBadge — earned titles the player can wear on the chip / Status.
    Run: mise run test-headless
]]

local StatusBadge = loadModule("src/Shared/Game/StatusBadge.lua")
local PlayerListStatus = loadModule("src/Shared/Game/PlayerListStatus.lua")

local function people()
    return loadModule("configs/people_list.lua")
end

local function ranks()
    return loadModule("configs/combat_ranks.lua")
end

return function()
    describe("StatusBadge.options", function()
        it("lists training, adventure, and leaderboard badges the player has", function()
            local options = StatusBadge.options(people(), ranks(), {
                earnedCombat = { spark = true, skilled = true },
                level = 20,
                hugeHatcher = true,
                leaderboardTitle = "Farmer",
                leaderboardRank = 16,
                leaderboardHoverTitle = "Farm",
                leaderboardHoverBoard = "Crystal LB",
                leaderboardBoardId = "crystal_crusher",
            })
            local byKind = {}
            for _, option in ipairs(options) do
                byKind[option.kind .. ":" .. option.id] = option
            end
            expect(byKind["combat:spark"].label).to.equal("Spark")
            expect(byKind["combat:skilled"].source).to.equal("Combat Training 1")
            expect(byKind["adventure:Hero"].label).to.equal("Hero")
            expect(byKind["adventure:Hero"].icon).to.equal("rbxassetid://103517372435641")
            expect(byKind["adventure:Noob"].source).to.equal("New but going somewhere!")
            expect(byKind["adventure:Noob"].icon).to.equal("rbxassetid://109253922126750")
            expect(byKind["huge:huge"].label).to.equal("Huge Hatcher")
            expect(byKind["huge:huge"].icon).to.equal("rbxassetid://105338046020621")
            expect(byKind["leaderboard:crystal_crusher"].source).to.equal(
                "Farm #16 (#16 Crystal LB)"
            )
        end)
    end)

    describe("StatusBadge.resolve", function()
        it("wears a saved pick when it is still earned", function()
            local chosen = StatusBadge.resolve(people(), ranks(), {
                earnedCombat = { skilled = true },
                combatRankId = "skilled",
                level = 50,
            }, { kind = "adventure", id = "Legend" })
            expect(chosen.kind).to.equal("adventure")
            expect(chosen.label).to.equal("Legend")
        end)

        it("falls back to the current combat title when no pick is saved", function()
            local chosen = StatusBadge.resolve(people(), ranks(), {
                earnedCombat = { spark = true, skilled = true },
                combatRankId = "skilled",
                level = 1,
            }, nil)
            expect(chosen.id).to.equal("skilled")
        end)
    end)

    describe("StatusBadge.choose", function()
        it("keeps a saved pick when nothing new has been earned", function()
            local state = {
                earnedCombat = { spark = true, kindled = true },
                combatRankId = "kindled",
                level = 1,
            }
            local seen = { "adventure:Noob", "combat:spark", "combat:kindled" }
            local chosen = StatusBadge.choose(people(), ranks(), state, {
                kind = "adventure",
                id = "Noob",
            }, seen)
            expect(chosen.kind).to.equal("adventure")
            expect(chosen.id).to.equal("Noob")
        end)

        it("wears a newly earned combat title over a saved pick", function()
            local state = {
                earnedCombat = { spark = true, kindled = true },
                combatRankId = "kindled",
                level = 1,
            }
            local chosen = StatusBadge.choose(people(), ranks(), state, {
                kind = "adventure",
                id = "Noob",
            }, { "adventure:Noob", "combat:spark" })
            expect(chosen.kind).to.equal("combat")
            expect(chosen.id).to.equal("kindled")
        end)

        it("wears a newly earned adventure title over a saved combat pick", function()
            local state = {
                earnedCombat = { skilled = true },
                combatRankId = "skilled",
                level = 5,
            }
            local chosen = StatusBadge.choose(people(), ranks(), state, {
                kind = "combat",
                id = "skilled",
            }, { "adventure:Noob", "combat:skilled" })
            expect(chosen.kind).to.equal("adventure")
            expect(chosen.id).to.equal("Novice")
        end)

        it("seeds seen on first publish without replacing the saved pick", function()
            local state = {
                earnedCombat = { spark = true, kindled = true },
                combatRankId = "kindled",
                level = 1,
            }
            local chosen, nextSeen = StatusBadge.choose(people(), ranks(), state, {
                kind = "adventure",
                id = "Noob",
            }, {})
            expect(chosen.kind).to.equal("adventure")
            expect(chosen.id).to.equal("Noob")
            local hasKindled = false
            for _, key in ipairs(nextSeen) do
                if key == "combat:kindled" then
                    hasKindled = true
                end
            end
            expect(hasKindled).to.equal(true)
        end)
    end)

    describe("wiring", function()
        it("auto-wears a fresh title from the progression publish path", function()
            local service = readFile("src/Server/Services/PlayerProgressionService.lua")
            expect(service:find("StatusBadge.choose", 1, true)).to.be.ok()
            expect(service:find("StatusBadgeSeen", 1, true)).to.be.ok()
            local data = readFile("src/Server/Services/DataService.lua")
            expect(data:find("StatusBadgeSeen = {}", 1, true)).to.be.ok()
        end)
    end)

    describe("PlayerListStatus.status", function()
        it("prefers the worn Status badge over auto titles", function()
            expect(PlayerListStatus.status({
                chosenTitle = "Hero",
                combatRank = "Skilled",
                leaderboardTitle = "Farmer",
                level = 1,
            })).to.equal("Hero")
        end)
    end)
end
