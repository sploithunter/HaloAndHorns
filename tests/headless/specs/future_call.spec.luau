--[[
    Future Call — reconciliation-safe Level 5–9 entitlement rules.
]]

local FutureCallLogic = loadModule("src/Shared/Game/FutureCallLogic.lua")
local config = loadModule("configs/future_call.lua")
local progressionConfig = loadModule("configs/player_progression.lua")

return function()
    describe("FutureCallLogic entitlement", function()
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
