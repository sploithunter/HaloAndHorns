local QuestReward = loadModule("src/Shared/Game/QuestReward.lua")

return function()
    describe("QuestReward.resolve", function()
        local policy = {
            enabled = true,
            base_step_fraction = 0.08,
            per_order_fraction = 0.02,
            max_step_fraction = 0.18,
            minimum_xp = 50,
            fallback_xp = 100,
            round_to = 10,
        }

        it("preserves an explicitly authored XP reward", function()
            local reward = { experience = 300, currencies = { gems = 15 } }
            local resolved = QuestReward.resolve(reward, { order = 5 }, policy, 3500)
            expect(resolved.experience).to.equal(300)
            expect(resolved.currencies.gems).to.equal(15)
        end)

        it("pays a moderate fraction of the current level step", function()
            local resolved = QuestReward.resolve({}, { order = 3 }, policy, 3500)
            expect(resolved.experience).to.equal(420) -- 12% of the Level-5 3,500-XP step
        end)

        it("scales later chain claims but caps the fraction", function()
            expect(QuestReward.resolve({}, { order = 1 }, policy, 1000).experience).to.equal(80)
            expect(QuestReward.resolve({}, { order = 6 }, policy, 1000).experience).to.equal(180)
            expect(QuestReward.resolve({}, { order = 99 }, policy, 1000).experience).to.equal(180)
        end)

        it("uses safe minimum and fallback rewards", function()
            expect(QuestReward.resolve({}, { order = 1 }, policy, 100).experience).to.equal(50)
            expect(QuestReward.resolve({}, { order = 1 }, policy, 0).experience).to.equal(100)
        end)

        it("does not mutate the authored reward table", function()
            local reward = { currencies = { gems = 10 } }
            local resolved = QuestReward.resolve(reward, { order = 1 }, policy, 1000)
            expect(reward.experience).to.equal(nil)
            expect(resolved.experience).to.equal(80)
        end)
    end)

    describe("quest XP wiring", function()
        it("preserves the First Steps total while paying every claim", function()
            local quests = loadModule("configs/quests.lua")
            local total = 0
            for _, def in pairs(quests.defs) do
                if def.track == "first_steps" then
                    expect((def.reward.experience or 0) > 0).to.equal(true)
                    total += def.reward.experience
                end
            end
            expect(total).to.equal(700)
        end)

        it("resolves positive XP for every configured quest", function()
            local quests = loadModule("configs/quests.lua")
            for id, def in pairs(quests.defs) do
                local reward = QuestReward.resolve(def.reward, def, quests.claim_experience, 3500)
                if not ((reward.experience or 0) > 0) then
                    error("quest '" .. id .. "' resolves no claim XP")
                end
            end
        end)

        it("passes the quest reward family through the progression choke point", function()
            local source = readFile("src/Server/Services/RewardService.lua")
            expect(source:find('source:match("^([^:]+)")', 1, true)).to.be.ok()
            expect(source:find("AddExperience(player, b.experience, xpSource)", 1, true)).to.be.ok()
            expect(loadModule("configs/leveling.lua").onramp.xp_mult_by_source.quest).to.equal(1)
        end)
    end)
end
