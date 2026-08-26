return function()
    describe("ephemeral combat runtime contract", function()
        it("gates the complete normal defeat side-effect block by reward policy", function()
            local source = readFile("src/Server/Services/EnemyService.lua")
            local gate = source:find(
                "EnemyRewardPolicy.awardsNormalRewards(entry.rewardPolicy) and combat and contrib",
                1,
                true
            )
            local award = source:find("combat:AwardLoot(", gate, true)
            local gameEvent = source:find('fireGameEvent(player, "enemy_defeated"', gate, true)
            local callback = source:find("local onDefeated = entry.onDefeated", gate, true)

            expect(gate ~= nil).to.equal(true)
            expect(award ~= nil and award > gate).to.equal(true)
            expect(gameEvent ~= nil and gameEvent > gate).to.equal(true)
            expect(callback ~= nil and callback > gameEvent).to.equal(true)
        end)

        it("destroys opted-in ephemeral pets before down or lockout writes", function()
            local source = readFile("src/Server/Services/EnemyService.lua")
            local down = source:find("function EnemyService:_downPet", 1, true)
            local ephemeral = source:find('pet:GetAttribute("EphemeralDownPolicy")', down, true)
            local downed = source:find('pet:SetAttribute("CombatDowned", true)', down, true)
            local lockout = source:find("self:_recordDownLockout(pet)", down, true)

            expect(down ~= nil).to.equal(true)
            expect(ephemeral ~= nil and ephemeral > down).to.equal(true)
            expect(downed ~= nil and ephemeral < downed).to.equal(true)
            expect(lockout ~= nil and ephemeral < lockout).to.equal(true)
        end)

        it("stamps construction attributes before a ghost enters the live folder", function()
            local source = readFile("src/Server/Services/NpcPrincipalService.lua")
            local spawn = source:find("function NpcPrincipalService:SpawnGhostSquad", 1, true)
            local attributes = source:find("model:SetAttribute(name, value)", spawn, true)
            local parent = source:find("model.Parent = folder", spawn, true)

            expect(spawn ~= nil).to.equal(true)
            expect(attributes ~= nil and attributes > spawn).to.equal(true)
            expect(parent ~= nil and attributes < parent).to.equal(true)
        end)

        it("supports an interruptible forward goal on spawned enemies", function()
            local source = readFile("src/Server/Services/EnemyService.lua")
            local follow = source:find("function EnemyService:_followAuthoredMarchGoal", 1, true)
            local step = source:find("EnemyMarchGoal.step(goal", follow, true)
            local callback = source:find("local onReached = goal.onReached", step, true)
            local loiter = source:find("function EnemyService:_loiter", callback, true)
            local followCall = source:find("self:_followAuthoredMarchGoal", loiter, true)

            expect(follow ~= nil).to.equal(true)
            expect(step ~= nil and step > follow).to.equal(true)
            expect(callback ~= nil and callback > step).to.equal(true)
            expect(followCall ~= nil and followCall > loiter).to.equal(true)
        end)

        it("can alert both aggro tables without forcing pet target ids", function()
            local source = readFile("src/Server/Services/EnemyService.lua")
            local alert = source:find("function EnemyService:AlertSquadToEnemy", 1, true)
            local focus = source:find("function EnemyService:FocusSquadOnEnemy", alert, true)
            local block = source:sub(alert, focus - 1)

            expect(alert ~= nil).to.equal(true)
            expect(focus ~= nil and focus > alert).to.equal(true)
            expect(block:find("AggroTable.reinforce(entry.aggro, pet, threat)", 1, true)).to.be.ok()
            expect(block:find("self:_petAggroTable(pet)", 1, true)).to.be.ok()
            expect(block:find('FindFirstChild("TargetID")', 1, true)).to.equal(nil)
        end)
    end)
end
