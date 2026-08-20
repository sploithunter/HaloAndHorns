--[[
    Future Call — reconciliation-safe onboarding and Level 5–9 entitlement rules.
]]

local FutureCallLogic = loadModule("src/Shared/Game/FutureCallLogic.lua")
local config = loadModule("configs/future_call.lua")
local progressionConfig = loadModule("configs/player_progression.lua")

return function()
    describe("FutureCallLogic entitlement", function()
        it("waits for the Level-2 ascend before granting the promise token", function()
            expect(config.onboarding.grant_claimed_level).to.equal(2)
            expect(FutureCallLogic.onboardingPlan({}, 1, 1, config).kind).to.equal("none")
            local plan = FutureCallLogic.onboardingPlan({}, 2, 2, config)
            expect(plan.kind).to.equal("grant")
            expect(plan.amount).to.equal(1)
            expect(FutureCallLogic.isUnlocked(3, config)).to.equal(false)
        end)

        it("unlocks the held onboarding token at earned Level 4", function()
            local gameData = {}
            local grant = FutureCallLogic.onboardingPlan(gameData, 2, 2, config)
            FutureCallLogic.markOnboarding(gameData, grant)
            expect(FutureCallLogic.onboardingPlan(gameData, 3, 3, config).kind).to.equal("none")
            local unlock = FutureCallLogic.onboardingPlan(gameData, 3, 4, config)
            expect(unlock.kind).to.equal("unlock")
            expect(FutureCallLogic.isUnlocked(4, config)).to.equal(true)
            FutureCallLogic.markOnboarding(gameData, unlock)
            expect(FutureCallLogic.onboardingPlan(gameData, 4, 4, config).kind).to.equal("none")
        end)

        it("migrates an existing Level-4 profile without granting a third token", function()
            local gameData = {}
            local plan = FutureCallLogic.onboardingPlan(gameData, 4, 4, config)
            expect(plan.kind).to.equal("migrate")
            expect(plan.amount).to.equal(nil)
            FutureCallLogic.markOnboarding(gameData, plan)
            expect(gameData.FutureCall.onboarding_token_v1).to.equal(true)
            expect(gameData.FutureCall.onboarding_unlocked_v1).to.equal(true)
        end)

        it("restores onboarding markers when inventory mutation fails", function()
            local gameData = { FutureCall = { onboarding_token_v1 = false } }
            local plan = FutureCallLogic.onboardingPlan(gameData, 2, 2, config)
            FutureCallLogic.markOnboarding(gameData, plan)
            expect(gameData.FutureCall.onboarding_token_v1).to.equal(true)
            FutureCallLogic.restoreOnboarding(gameData, plan)
            expect(gameData.FutureCall.onboarding_token_v1).to.equal(false)
        end)

        it("waits until claimed level 5", function()
            expect(FutureCallLogic.pendingGrants({}, 4, config).total).to.equal(0)
            expect(FutureCallLogic.pendingGrants({}, 5, config).total).to.equal(5)
        end)

        it("grants the descending Level 5-9 schedule exactly once", function()
            local gameData = {}
            local level5 = FutureCallLogic.pendingGrants(gameData, 5, config)
            expect(level5.total).to.equal(5)
            FutureCallLogic.markPending(gameData, level5)

            local level6 = FutureCallLogic.pendingGrants(gameData, 6, config)
            expect(level6.total).to.equal(4)
            FutureCallLogic.markPending(gameData, level6)

            local level9 = FutureCallLogic.pendingGrants(gameData, 9, config)
            expect(level9.total).to.equal(6)
            FutureCallLogic.markPending(gameData, level9)
            expect(FutureCallLogic.pendingGrants(gameData, 29, config).total).to.equal(0)
        end)

        it("reconciles a fresh existing Level-9 profile for all 15 tokens", function()
            local pending = FutureCallLogic.pendingGrants({}, 9, config)
            expect(pending.total).to.equal(15)
            expect(#pending.grants).to.equal(5)
        end)

        it("tops an original Level-5 recipient up by two tokens", function()
            local gameData = { FutureCall = { level5_v1 = true } }
            expect(FutureCallLogic.pendingGrants(gameData, 5, config).total).to.equal(2)
            expect(FutureCallLogic.pendingGrants(gameData, 9, config).total).to.equal(12)
        end)

        it("restores milestone markers when inventory mutation fails", function()
            local gameData = { FutureCall = { level5_v2 = false } }
            local pending = FutureCallLogic.pendingGrants(gameData, 6, config)
            FutureCallLogic.markPending(gameData, pending)
            expect(gameData.FutureCall.level5_v2).to.equal(true)
            expect(gameData.FutureCall.level6_v1).to.equal(true)
            FutureCallLogic.restorePending(gameData, pending)
            expect(gameData.FutureCall.level5_v2).to.equal(false)
            expect(gameData.FutureCall.level6_v1).to.equal(nil)
        end)

        it("derives a unique, username-impossible NPC principal name", function()
            expect(FutureCallLogic.principalName("ColoradoPlays", config)).to.equal(
                "ColoradoPlays's Future Self"
            )
        end)

        it("sets the future self five levels above the caller", function()
            expect(FutureCallLogic.summonLevel(1, config, progressionConfig)).to.equal(6)
            expect(FutureCallLogic.summonLevel(20, config, progressionConfig)).to.equal(25)
            expect(FutureCallLogic.summonLevel(45, config, progressionConfig)).to.equal(50)
        end)

        it("caps the future self at the game's level cap", function()
            expect(FutureCallLogic.summonLevel(46, config, progressionConfig)).to.equal(50)
            expect(FutureCallLogic.summonLevel(50, config, progressionConfig)).to.equal(50)
        end)

        it("keeps the authored two-minute four-pet squad at every caller level", function()
            expect(config.token.duration).to.equal(120)
            expect(config.principal.level_offset).to.equal(5)
            expect(#config.principal.squad).to.equal(4)
            expect(config.principal.squad[1].pet).to.equal("polarbear")
            expect(config.principal.squad[1].variant).to.equal("rainbow")
            expect(config.principal.squad[2].pet).to.equal("dragon")
            expect(config.principal.squad[2].variant).to.equal("golden")
            expect(config.principal.squad[3].pet).to.equal("penguin")
            expect(config.principal.squad[3].variant).to.equal("rainbow")
            expect(config.principal.squad[4].pet).to.equal("snowleopard")
            expect(config.principal.squad[4].variant).to.equal("rainbow")
        end)

        it("shows one farewell banner only after a natural Future Self expiry", function()
            local futureCallSource = readFile("src/Server/Services/FutureCallService.lua")
            local principalSource = readFile("src/Server/Services/NpcPrincipalService.lua")
            local gameEvents = loadModule("configs/game_events.lua")

            expect(futureCallSource:find('if reason == "expired"', 1, true)).to.be.ok()
            expect(futureCallSource:find('fireGameEvent(player, "future_call_departed"', 1, true)).to.be.ok()
            expect(futureCallSource:find("See you—or be you—soon", 1, true)).to.be.ok()
            expect(principalSource:find('self:Despawn(name, "expired")', 1, true)).to.be.ok()
            expect(type(gameEvents.future_call_departed.banner)).to.equal("table")
        end)

        it("replicates the two-minute Future Self countdown into the player badge row", function()
            local futureCallSource = readFile("src/Server/Services/FutureCallService.lua")
            local badgeSource = readFile("src/Client/Systems/PlayerPowerBadges.lua")

            expect(
                futureCallSource:find(
                    'player:SetAttribute("FutureCallUntil", os.time() + duration)',
                    1,
                    true
                )
            ).to.be.ok()
            expect(futureCallSource:find('player:SetAttribute("FutureCallUntil", 0)', 1, true)).to.be.ok()
            expect(badgeSource:find('attr = "FutureCall"', 1, true)).to.be.ok()
            expect(badgeSource:find('symbol = "portal"', 1, true)).to.be.ok()
        end)

        it("keeps the Level-4 promise visible and bindable while gating activation", function()
            local futureCallSource = readFile("src/Server/Services/FutureCallService.lua")
            local hotbarSource = readFile("src/Server/Services/HotbarService.lua")
            local inventorySource = readFile("src/Client/UI/Menus/InventoryPanel.lua")
            local gameEvents = loadModule("configs/game_events.lua")
            local items = loadModule("configs/items.lua")
            local item
            for _, candidate in ipairs(items) do
                if candidate.id == "future_call_token" then
                    item = candidate
                    break
                end
            end

            expect(item.unlock_level).to.equal(4)
            expect(item.locked_description).to.equal("Reach Level 4 to summon Your Future Self.")
            expect(futureCallSource:find('reason = "level_locked"', 1, true)).to.be.ok()
            expect(hotbarSource:find("locked = not unlocked", 1, true)).to.be.ok()
            expect(hotbarSource:find('if type(bind) == "table" and bind.type == "token"', 1, true)).never.to.be.ok()
            expect(inventorySource:find("if item.locked then", 1, true)).to.be.ok()
            expect(futureCallSource:find('fireGameEvent(player, "future_call_locked"', 1, true)).to.be.ok()
            expect(type(gameEvents.future_call_locked.banner)).to.equal("table")
        end)

        it("wires manifested squads into their owner's whole-team combat", function()
            local enemySource = readFile("src/Server/Services/EnemyService.lua")
            expect(enemySource:find("function EnemyService:_playerForPetFolder", 1, true)).to.be.ok()
            expect(enemySource:find("local player = self:_playerForPetFolder(folder)", 1, true)).to.be.ok()
            expect(enemySource:find("local owner = self:_playerForPetFolder(key.Parent)", 1, true)).to.be.ok()
            expect(
                enemySource:find("local combatPlayer = self:_playerForPetFolder(folder)", 1, true)
            ).to.be.ok()
            expect(
                enemySource:find(
                    'local owner = owners[tostring(folder:GetAttribute("NpcOwner") or "")]',
                    1,
                    true
                )
            ).to.be.ok()
        end)

        it("uses the live NPC anchor instead of its pets' stale server pivots", function()
            local enemySource = readFile("src/Server/Services/EnemyService.lua")
            expect(enemySource:find("local npc = Workspace:FindFirstChild(folder.Name)", 1, true)).to.be.ok()
            expect(enemySource:find('npc:FindFirstChild("HumanoidRootPart")', 1, true)).to.be.ok()
        end)
    end)
end
