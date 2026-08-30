--[[
    CombatRank — pillar grants, first-earn only, tutorial backfill.
]]

local CombatRank = loadModule("src/Shared/Game/CombatRank.lua")
local ranks = loadModule("configs/combat_ranks.lua")
local tutorial = loadModule("configs/combat_tutorial.lua")

local PILLARS = {
    advance_stage = "spark",
    advance_brew = "kindled",
    advance_heal = "warden",
    advance_weaken = "hexed",
    advance_stack = "surge",
    advance_tank = "bulwark",
    advance_healer = "hunter",
    advance_together = "skilled",
}

local function stepIndex(id)
    for i, step in ipairs(tutorial.steps) do
        if step.id == id then
            return i
        end
    end
    return nil
end

return function()
    describe("combat_ranks config", function()
        it("authors eight unique ranks on the eight pillar steps", function()
            expect(#ranks.ranks).to.equal(8)
            local seenId = {}
            local seenStep = {}
            for _, rank in ipairs(ranks.ranks) do
                expect(type(rank.id)).to.equal("string")
                expect(type(rank.label)).to.equal("string")
                expect(#rank.label <= 8).to.equal(true)
                expect(type(rank.grant_step)).to.equal("string")
                expect(type(rank.prompt)).to.equal("string")
                expect(#rank.prompt > 20).to.equal(true)
                expect(string.sub(rank.icon, 1, 13)).to.equal("rbxassetid://")
                expect(seenId[rank.id]).to.equal(nil)
                expect(seenStep[rank.grant_step]).to.equal(nil)
                seenId[rank.id] = true
                seenStep[rank.grant_step] = true
                expect(PILLARS[rank.grant_step]).to.equal(rank.id)
            end
            expect(ranks.ranks[#ranks.ranks].id).to.equal("skilled")
            expect(ranks.ceremony.chip_top).to.equal(14)
        end)

        it("docks the status chip to the PlayerBar portrait", function()
            local source = readFile("src/Client/Systems/CombatRankController.lua")
            local playerBar = readFile("src/Client/Systems/PlayerBar.lua")
            expect(source:find('WaitForChild("PlayerBar"', 1, true)).to.be.ok()
            expect(source:find("layoutChipDock", 1, true)).to.be.ok()
            expect(playerBar:find('emblem.Name = "Emblem"', 1, true)).to.be.ok()
        end)

        it("maps every pillar grant_step to a live combat-tutorial step", function()
            for stepId in pairs(PILLARS) do
                expect(stepIndex(stepId) ~= nil).to.equal(true)
            end
        end)
    end)

    describe("CombatRank", function()
        it("grants a new rank once and ignores repeats", function()
            local state, isNew = CombatRank.grant(nil, ranks, "spark")
            expect(isNew).to.equal(true)
            expect(state.current).to.equal("spark")
            expect(state.earned.spark).to.equal(true)
            local again, replay = CombatRank.grant(state, ranks, "spark")
            expect(replay).to.equal(false)
            expect(again.current).to.equal("spark")
            local nextState, promoted = CombatRank.grant(state, ranks, "kindled")
            expect(promoted).to.equal(true)
            expect(nextState.current).to.equal("kindled")
            expect(nextState.earned.spark).to.equal(true)
        end)

        it("rejects unknown ids", function()
            local state, isNew = CombatRank.grant(nil, ranks, "halo_initiate")
            expect(isNew).to.equal(false)
            expect(state.current).to.equal(nil)
        end)

        it("resolves ranks from pillar step ids", function()
            expect(CombatRank.rankForStep(ranks, "advance_brew").id).to.equal("kindled")
            expect(CombatRank.rankForStep(ranks, "battle_brew")).to.equal(nil)
        end)

        it("backfills finished cave players to Skilled without a new grant later", function()
            local state, changed =
                CombatRank.syncFromTutorial(nil, ranks, tutorial, { done = true })
            expect(changed).to.equal(true)
            expect(state.current).to.equal("skilled")
            expect(state.earned.spark).to.equal(true)
            expect(state.earned.skilled).to.equal(true)
            local again, againChanged = CombatRank.syncFromTutorial(state, ranks, tutorial, {
                done = true,
            })
            expect(againChanged).to.equal(false)
            expect(again.current).to.equal("skilled")
            local _, replay = CombatRank.grant(again, ranks, "skilled")
            expect(replay).to.equal(false)
        end)

        it("backfills only pillars already finished on a mid-run save", function()
            local afterBrew = stepIndex("advance_brew") + 1
            local state = CombatRank.syncFromTutorial(nil, ranks, tutorial, { step = afterBrew })
            expect(state.current).to.equal("kindled")
            expect(state.earned.spark).to.equal(true)
            expect(state.earned.kindled).to.equal(true)
            expect(state.earned.warden).to.equal(nil)
        end)
    end)

    describe("wiring", function()
        it("admin reset clears earned ranks and the worn Status pick", function()
            local combat = readFile("src/Server/Services/CombatTutorialService.lua")
            expect(combat:find("data.GameData.CombatRank = nil", 1, true)).to.be.ok()
            expect(combat:find("_publishCombatRank(player, nil)", 1, true)).to.be.ok()
            expect(combat:find("StatusBadgeSeen = {}", 1, true)).to.be.ok()
        end)
    end)
end
