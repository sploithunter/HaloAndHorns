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

        it("guarantees Level 4 and adds the second Future Call token at the capstone", function()
            local quests = loadModule("configs/quests.lua")
            local reward = quests.defs.fs_cave.reward
            expect(reward.ensure_earned_level).to.equal(4)
            expect(reward.future_call_tokens).to.equal(1)
            expect(reward.currencies.hall_coins).to.equal(1500)
            expect(reward.currencies.grass_coins).to.equal(nil)
            expect(reward.currencies.area_coins).to.equal(nil)
        end)

        it("makes the Hatchery capstone thematic with five Fortune Flasks", function()
            local reward = loadModule("configs/quests.lua").defs.hatch_250.reward
            expect(reward.items[1].id).to.equal("fortune_flask")
            expect(reward.items[1].qty).to.equal(5)
            expect(reward.items[1].bucket).to.equal("potions")
        end)

        it("keeps finite exploration actions lifetime-backed and reachable", function()
            local defs = loadModule("configs/quests.lua").defs
            expect(defs.path_next_area.condition.since_start).to.equal(nil)
            expect(defs.path_3_areas.condition.since_start).to.equal(nil)
            expect(defs.path_creators.name).to.equal("Unlock 4 Areas")
            expect(defs.path_creators.condition.counter).to.equal("areas_unlocked")
            expect(defs.path_creators.condition.value).to.equal(4)
            expect(defs.realm_settler.condition.counter).to.equal("realm_areas_unlocked")
        end)

        it("moves extreme Trial milestones into achievements without losing rewards", function()
            local quests = loadModule("configs/quests.lua")
            local achievements = loadModule("configs/achievements.lua")
            expect(quests.defs.tr_random_1000).to.equal(nil)
            expect(quests.defs.tr_random_10000).to.equal(nil)
            local tiers = achievements.achievements.missions_completed.tiers
            expect(tiers[1].goal).to.equal(1000)
            expect(tiers[1].legacy_quest_claim).to.equal("tr_random_1000")
            expect(tiers[1].reward.bundle.currencies.gems).to.equal(500)
            expect(tiers[1].reward.bundle.titles[1]).to.equal("Thousand-Door Veteran")
            expect(tiers[2].goal).to.equal(10000)
        end)

        it("tracks creator meetings as achievable one- and two-creator achievements", function()
            local tiers = loadModule("configs/achievements.lua").achievements.creators_met.tiers
            expect(tiers[1].goal).to.equal(1)
            expect(tiers[2].goal).to.equal(2)
        end)

        it("defines Health Potion as a 25-percent deployed-squad heal", function()
            local items = loadModule("configs/items.lua")
            local health
            for _, item in ipairs(items) do
                if item.id == "health_potion" then
                    health = item
                    break
                end
            end
            expect(health).to.be.ok()
            expect(health.consumable).to.equal(true)
            expect(health.effects.squad_health_restore_fraction).to.equal(0.25)
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

        it(
            "keeps lifetime hatching achievements well beyond the active Hatchery capstone",
            function()
                local quests = loadModule("configs/quests.lua")
                local achievements = loadModule("configs/achievements.lua")
                local capstone = quests.defs.hatch_250
                local target = capstone.condition.value
                local tiersBeyond = 0
                local maximum = 0

                expect(target).to.equal(1000)
                expect(capstone.name).to.equal("Hatch 1,000 Eggs")
                for _, tier in ipairs(achievements.achievements.eggs_hatched.tiers) do
                    maximum = math.max(maximum, tier.goal)
                    if tier.goal > target then
                        tiersBeyond += 1
                    end
                end
                expect(tiersBeyond >= 2).to.equal(true)
                expect(maximum >= 25000).to.equal(true)
            end
        )

        it("passes the quest reward family through the progression choke point", function()
            local source = readFile("src/Server/Services/RewardService.lua")
            expect(source:find('source:match("^([^:]+)")', 1, true)).to.be.ok()
            expect(source:find("AddExperience(player, b.experience, xpSource)", 1, true)).to.be.ok()
            expect(loadModule("configs/leveling.lua").onramp.xp_mult_by_source.quest).to.equal(1)
        end)

        it(
            "applies capstone XP before the exact level guarantee and canonical token grant",
            function()
                local source = readFile("src/Server/Services/QuestService.lua")
                local ordinary = source:find("rewards:Grant(player", 1, true)
                local special = source:find(
                    "self:_reconcileCompletionReward(player, questId, def, data)",
                    ordinary,
                    true
                )
                expect(ordinary).to.be.ok()
                expect(special).to.be.ok()
                expect(special > ordinary).to.equal(true)
                expect(source:find("progression:EnsureEarnedLevel", 1, true)).to.be.ok()
                expect(source:find('futureCall:GrantTokens(player, tokenCount, "quest")', 1, true)).to.be.ok()
            end
        )

        it("previews both special capstone rewards in the Quest menu", function()
            local source = readFile("src/Client/UI/Menus/QuestPanel.lua")
            expect(source:find("L%d guarantee", 1, true)).to.be.ok()
            expect(source:find("%dx Future Call", 1, true)).to.be.ok()
        end)
    end)
end
