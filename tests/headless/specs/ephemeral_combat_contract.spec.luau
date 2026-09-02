return function()
    describe("ephemeral combat runtime contract", function()
        it("gates the complete normal defeat side-effect block by reward policy", function()
            local source = readFile("src/Server/Services/EnemyService.lua")
            local reward = source:find("function EnemyService:_awardCombatDefeat", 1, true)
            local defeat = source:find("function EnemyService:_onDefeated", reward, true)
            local normalization = source:find(
                "local awardsNormalRewards = EnemyRewardPolicy.awardsNormalRewards(entry.rewardPolicy)",
                defeat,
                true
            )
            local gate = source:find("if awardsNormalRewards and combat and contrib then", 1, true)
            local award = source:find("self:_awardCombatDefeat(player", gate, true)
            local callback = source:find("local onDefeated = entry.onDefeated", award, true)

            expect(reward ~= nil and defeat ~= nil and reward < defeat).to.equal(true)
            expect(source:find("combat:AwardLoot(", reward, true) < defeat).to.equal(true)
            expect(source:find('fireGameEvent(player, "enemy_defeated"', reward, true) < defeat).to.equal(
                true
            )
            expect(source:find("drops:TrySpawnEnhancementDrop", reward, true) < defeat).to.equal(
                true
            )
            expect(normalization ~= nil and gate ~= nil and gate > normalization).to.equal(true)
            expect(award ~= nil and award > gate).to.equal(true)
            expect(callback ~= nil and callback > award).to.equal(true)
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
            expect(source:find("function EnemyService:RedirectMarchGoal", 1, true)).to.be.ok()
            expect(source:find("function EnemyService:ForceAttackTarget", 1, true)).to.be.ok()
            expect(source:find("AggroTable.clearAll(entry.aggro)", 1, true)).to.be.ok()
        end)

        it("can alert one explicit pet folder without forcing pet target ids", function()
            local source = readFile("src/Server/Services/EnemyService.lua")
            local alert = source:find("function EnemyService:_alertPetFoldersToEnemy", 1, true)
            local focus = source:find("function EnemyService:FocusSquadOnEnemy", alert, true)
            local block = source:sub(alert, focus - 1)

            expect(alert ~= nil).to.equal(true)
            expect(focus ~= nil and focus > alert).to.equal(true)
            expect(block:find("AggroTable.reinforce(entry.aggro, pet, threat)", 1, true)).to.be.ok()
            expect(block:find("self:_petAggroTable(pet)", 1, true)).to.be.ok()
            expect(block:find("function EnemyService:AlertPetFolderToEnemy", 1, true)).to.be.ok()
            expect(block:find('FindFirstChild("TargetID")', 1, true)).to.equal(nil)
        end)

        it("enforces opt-in combat target groups in both targeting directions", function()
            local source = readFile("src/Server/Services/EnemyService.lua")
            local enemyToPet = source:find("function EnemyService:_enemyHostileToPet", 1, true)
            local petToEnemy = source:find("function EnemyService:_petHostileToEnemy", 1, true)

            expect(enemyToPet ~= nil).to.equal(true)
            expect(petToEnemy ~= nil and petToEnemy > enemyToPet).to.equal(true)
            expect(source:find("CombatTargetGroup.compatible", enemyToPet, true) < petToEnemy).to.equal(
                true
            )
            expect(source:find("CombatTargetGroup.compatible", petToEnemy, true)).to.be.ok()
            expect(source:find("CombatTargetOpen", enemyToPet, true) < petToEnemy).to.equal(true)
            expect(source:find("CombatTargetOpen", petToEnemy, true)).to.be.ok()
        end)

        it("reuses NPC principals as explicit stationary authored anchors", function()
            local source = readFile("src/Server/Services/NpcPrincipalService.lua")
            local spawn = source:find("function NpcPrincipalService:SpawnStationary", 1, true)
            local step = source:find("function NpcPrincipalService:_step", spawn, true)

            expect(spawn ~= nil).to.equal(true)
            expect(source:find("args.stationary = true", spawn, true)).to.be.ok()
            expect(source:find("args.formTeam = false", spawn, true)).to.be.ok()
            expect(source:find("args.formAlliance = false", spawn, true)).to.be.ok()
            expect(step ~= nil and step > spawn).to.equal(true)
            expect(source:find("elseif rec.stationary then", step, true)).to.be.ok()
        end)

        it("honors config-owned non-collidable NPC character bodies", function()
            local source = readFile("src/Server/Services/NpcPrincipalService.lua")
            local config = readFile("configs/merge_egg_prototype.lua")
            local helper = source:find("local function makeCharacterNonCollidable", 1, true)
            local build = source:find("function NpcPrincipalService:_buildCharacter", helper, true)

            expect(helper ~= nil and build ~= nil and helper < build).to.equal(true)
            expect(source:find('instance:IsA("BasePart")', helper, true) < build).to.equal(true)
            expect(source:find("instance.CanCollide = false", helper, true) < build).to.equal(true)
            expect(source:find("model.DescendantAdded:Connect(apply)", helper, true) < build).to.equal(
                true
            )
            expect(source:find("if def.character_non_collidable == true then", build, true)).to.be.ok()
            expect(config:find("character_non_collidable = true", 1, true)).to.be.ok()
        end)

        it("gives NPC pets bounded server-authoritative combat positions", function()
            local source = readFile("src/Server/Services/PetFollowService.lua")
            local motion = source:find("function PetFollowService:_stepNpcCombatPosition", 1, true)
            local tick = source:find("function PetFollowService:_tickPrincipal", motion, true)

            expect(motion ~= nil).to.equal(true)
            expect(source:find("movement.max_travel_speed", motion, true)).to.be.ok()
            expect(source:find('source = "npc"', motion, true)).to.be.ok()
            expect(tick ~= nil and tick > motion).to.equal(true)
            expect(source:find("self:_stepNpcCombatPosition", tick, true)).to.be.ok()
        end)

        it("lets existing pet threat bypass only the ambient acquisition radius", function()
            local source = readFile("src/Server/Services/EnemyService.lua")
            local assign = source:find("function EnemyService:_assignPetTargets", 1, true)
            local candidates = source:find("local candidates = {}", assign, true)
            local retained =
                source:find("AggroTable.hasThreat(petAggro, etid, exitFloor)", candidates, true)
            local territory = source:find("self:_inTerritory(entry, player)", retained, true)
            local hostility =
                source:find("self:_petHostileToEnemy(pet, entry, player)", retained, true)

            expect(assign ~= nil).to.equal(true)
            expect(retained ~= nil and retained > candidates).to.equal(true)
            expect(territory ~= nil and territory > retained).to.equal(true)
            expect(hostility ~= nil and hostility > retained).to.equal(true)
        end)
    end)
end
