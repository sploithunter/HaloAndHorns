--[[
    Combat tutorial — isolated combat-training track (configs/combat_tutorial.lua).
    Does not replace the Homeworld tutorial. Room 1 reuses Training Ground maps.
]]

local TutorialFlow = loadModule("src/Shared/Game/TutorialFlow.lua")
local TutorialPack = loadModule("src/Shared/Game/TutorialPack.lua")
local ChallengeRun = loadModule("src/Shared/Game/ChallengeRun.lua")
local cfg = loadModule("configs/combat_tutorial.lua")
local missions = loadModule("configs/missions.lua")
local challengeCfg = loadModule("configs/challenge_runs.lua")
local powers = loadModule("configs/powers.lua")
local stats = loadModule("configs/stats.lua")

local function feed(progress, events)
    for _, event in ipairs(events) do
        if type(event) == "table" then
            progress = TutorialFlow.advance(cfg, progress, event[1], event[2])
        else
            progress = TutorialFlow.advance(cfg, progress, event)
        end
    end
    return progress
end

return function()
    describe("combat tutorial config", function()
        it("injects progression into Combat Training so its level floor can run", function()
            local source = readFile("src/Server/init.server.lua")
            local first = assert(
                source:find("ServerScriptService.Server.Services.CombatTutorialService,", 1, true)
            )
            local last = assert(source:find("-- RetentionService:", first, true))
            local registration = source:sub(first, last - 1)
            expect(registration:find("appendIfEnabled({", 1, true)).to.be.ok()
            expect(
                registration:find('}, "player_progression", "PlayerProgressionService")', 1, true)
            ).to.be.ok()
        end)
        it("restores the squad before publishing tutorial exit readiness", function()
            local source = readFile("src/Server/Services/CombatTutorialService.lua")
            local first =
                assert(source:find("function CombatTutorialService:_leave(player)", 1, true))
            local last =
                assert(source:find("function CombatTutorialService:_loanedLoadout", first, true))
            local leave = source:sub(first, last - 1)
            local restore = assert(leave:find("self:_restoreLoanedSquad(player)", 1, true))
            local ready =
                assert(leave:find('player:SetAttribute("InCombatTutorial", nil)', 1, true))
            expect(restore < ready).to.equal(true)
            expect(leave:find("session.leaving = true", 1, true)).to.be.ok()
            local combat = loadModule("configs/combat.lua")
            expect(combat.engagement.training_completion_unlocks_engagement).to.equal(true)
        end)
        it("authors the first-slice lessons and a completion reward", function()
            local expected = {
                "ready",
                "first_fight",
                "advance_stage",
                "battle_brew",
                "ready_brew",
                "brew_fight",
                "advance_brew",
                "bind_heal",
                "enhance_heal",
                "ready_heal",
                "select_pet",
                "cast_heal",
                "heal_fight",
                "advance_heal",
                "ready_weaken",
                "select_enemy",
                "throw_weaken",
                "weaken_fight",
                "advance_weaken",
                "stack_brew",
                "ready_stack",
                "stack_fight",
                "advance_stack",
                "ready_tank",
                "tank_fight",
                "advance_tank",
                "ready_healer",
                "healer_hunt",
                "healer_fight",
                "advance_healer",
                "ready_together",
                "together_fight",
                "advance_together",
            }
            expect(#cfg.steps).to.equal(#expected)
            for index, id in ipairs(expected) do
                expect(cfg.steps[index].id).to.equal(id)
                expect(type(cfg.steps[index].complete_on.event)).to.equal("string")
            end
            expect(cfg.restart_on_enter).to.equal(false)
            expect(cfg.venue.mode).to.equal("mission_slot")
            expect(cfg.venue.door).to.equal("homeworld_cave")
            expect(cfg.venue.mission_id).to.equal("combat_tutorial")
            expect(cfg.venue.anchor_root).to.equal("Maps.Home")
            expect(cfg.venue.anchor_name).to.equal("EarthLair")
            expect(cfg.venue.always_offer).to.equal(true)
            expect(cfg.venue.enter_prompt.action_text).to.equal("Enter")
            expect(cfg.venue.redo_confirm.yes_text).to.equal("Redo")
            expect(cfg.venue.leave_prompt.action_text).to.equal("Continue later")
            expect(cfg.door.button.leave_height).to.be.ok()
            expect(cfg.venue.leave_confirm.body).to.equal(
                "Your progress is saved. Come back anytime."
            )
            expect(cfg.entry.enabled).to.equal(false)
            expect(cfg.loaned_squad.count).to.equal(3)
            expect(#cfg.loaned_squad.pets).to.equal(4)
            expect(cfg.loaned_squad.equip[1]).to.equal("doggy")
            expect(#cfg.loaned_squad.equip).to.equal(3)
            expect(cfg.steps[1].lock_door).to.equal(true)
            expect(cfg.steps[1].spawn).to.equal(nil)
            expect(cfg.steps[2].spawn.where).to.equal("arena")
            expect(cfg.steps[3].activate_beacon).to.equal(true)
            expect(cfg.steps[3].return_to_lobby).to.equal(true)
            expect(cfg.steps[3].target.name).to.equal("ObjectiveBeacon")
            expect(cfg.steps[4].lock_door).to.equal(true)
            expect(cfg.steps[4].door_button.text).to.equal("DRINK FIRST")
            expect(cfg.steps[4].door_button.nudge).to.be.ok()
            expect(cfg.steps[4].spawn).to.equal(nil)
            expect(cfg.steps[5].lock_door).to.equal(true)
            expect(cfg.steps[6].spawn.where).to.equal("arena")
            expect(cfg.steps[7].return_to_lobby).to.equal(true)
            expect(cfg.door.look.transparency < 0.2).to.equal(true)
            expect(cfg.door.button.text).to.equal("ENTER")
            expect(cfg.door.button.ready_text).to.equal("READY")
            expect(cfg.door.button.height_from_floor > 0).to.equal(true)
            local service = readFile("src/Server/Services/CombatTutorialService.lua")
            expect(service:find("_applyLoanedSquad", 1, true)).to.be.ok()
            expect(service:find("TutorialSquad.equipRefs", 1, true)).to.be.ok()
            expect(service:find("_resetAuthoredSquad", 1, true)).to.be.ok()
            expect(service:find("_ensureMeter", 1, true)).to.be.ok()
            expect(service:find("EnsureCharge", 1, true)).to.be.ok()
            expect(service:find("_restoreLoanedSquad", 1, true)).to.be.ok()
            expect(service:find("CombatTutorialLoadout", 1, true)).to.be.ok()
            local inventory = readFile("src/Client/UI/Menus/InventoryPanel.lua")
            expect(inventory:find("_isCombatTutorialKit", 1, true)).to.be.ok()
            expect(inventory:find("_petAllowedNow", 1, true)).to.be.ok()
            expect(service:find("doorBottom", 1, true)).to.be.ok()
            expect(service:find("height_from_floor", 1, true)).to.be.ok()
            expect(service:find("lock_door", 1, true)).to.be.ok()
            expect(service:find("_restartTrack", 1, true)).to.be.ok()
            expect(service:find("sealToken", 1, true)).to.be.ok()
            expect(service:find('Name == "MissionSpawn"', 1, true)).to.be.ok()
            expect(service:find("hooks.MissionSpawn", 1, true)).to.equal(nil)
            expect(service:find("CombatTutorialAdvancePrompt", 1, true)).to.be.ok()
            expect(service:find("session.watchStepId == stepId", 1, true)).to.be.ok()
            expect(service:find('FindFirstChild("MissionCompletePrompt")', 1, true)).to.be.ok()
            expect(cfg.beacon.object_text).to.equal("Combat Training")
            expect(service:find("_setBeaconActive", 1, true)).to.be.ok()
            expect(service:find("_returnToLobby", 1, true)).to.be.ok()
            expect(service:find("_refreshLobbyReady", 1, true)).to.be.ok()
            expect(service:find("ClearCooldowns", 1, true)).to.be.ok()
            expect(cfg.refresh_on_lobby).to.equal(true)
            local powerService = readFile("src/Server/Services/PowerService.lua")
            expect(powerService:find("function PowerService:ClearCooldowns", 1, true)).to.be.ok()
            local hotbarClient = readFile("src/Client/Systems/HotbarBar.lua")
            expect(hotbarClient:find("powerCooldowns[p.power] = nil", 1, true)).to.be.ok()
            expect(service:find("_stepAcceptsEnter", 1, true)).to.be.ok()
            expect(service:find("_applyDoorPlate", 1, true)).to.be.ok()
            expect(service:find("_tryFinishUnlockWhen", 1, true)).to.be.ok()
            expect(service:find("_firstUnlockFailure", 1, true)).to.be.ok()
            expect(service:find("TutorialUnlock", 1, true)).to.be.ok()
            expect(service:find('name == "power_bound"', 1, true)).to.be.ok()
            expect(service:find('name == "pet_equipped"', 1, true)).to.be.ok()
            expect(cfg.door.unlock_when[1].check).to.equal("pets_equipped")
            expect(cfg.door.unlock_when[2].check).to.equal("hotbar_not_editing")
            local bindHeal = cfg.steps[8]
            expect(bindHeal.id).to.equal("bind_heal")
            expect(bindHeal.unlock_when[1].check).to.equal("pets_equipped")
            expect(bindHeal.unlock_when[2].target).to.equal("heal")
            expect(bindHeal.unlock_when[3].check).to.equal("hotbar_not_editing")
            local enhanceHeal = cfg.steps[9]
            expect(enhanceHeal.id).to.equal("enhance_heal")
            local entryEnhancement = cfg.entry_grant.enhancements[1]
            expect(entryEnhancement.type).to.equal("healing")
            expect(entryEnhancement.level).to.equal(3)
            expect(entryEnhancement.count).to.equal(1)
            expect(#entryEnhancement.origins).to.equal(0)
            expect(enhanceHeal.grant.enhancements).to.equal(nil)
            expect(enhanceHeal.grant.ensure_slot).to.equal("heal")
            expect(enhanceHeal.target.cue).to.equal("enhance_power")
            expect(enhanceHeal.target.tutorial_guide).to.equal("Power:heal")
            expect(enhanceHeal.target.enhancement_guide).to.equal("EnhanceType:healing")
            expect(enhanceHeal.complete_on.context.powerId).to.equal("heal")
            local enhancements = loadModule("src/Shared/Game/Enhancements.lua")
            local enhancementsConfig = loadModule("configs/enhancements.lua")
            local grantedType = entryEnhancement.type
            local compatible = enhancements.compatibleWith(
                enhancementsConfig,
                grantedType,
                powers.powers.heal,
                powers.effect_kinds
            )
            expect(compatible).to.equal(true)
            local unlock = loadModule("src/Shared/Game/TutorialUnlock.lua")
            for _, cond in ipairs(bindHeal.unlock_when) do
                expect(unlock.hasCheck(cond.check)).to.equal(true)
            end
            local hotbar = readFile("src/Client/Systems/HotbarBar.lua")
            expect(hotbar:find("Signals.Hotbar_EditMode:FireServer(editMode)", 1, true)).to.be.ok()
            expect(hotbar:find('stepId == "bind_heal"', 1, true)).to.be.ok()
            expect(hotbar:find('then "heal"', 1, true)).to.be.ok()
            expect(hotbar:find("TutorialBindArrow", 1, true)).to.be.ok()
            expect(powers.powers.resonance.hidden_while.in_combat_tutorial).to.equal(true)
            expect(powers.powers.heal.hidden_while.until_combat_tutorial).to.equal(true)
            expect(service:find("_unlockHeal", 1, true)).to.be.ok()
            expect(service:find("CombatTutorialHealUnlocked", 1, true)).to.be.ok()
            expect(service:find("self._enhancementService", 1, true)).to.be.ok()
            expect(service:find("enhancements:Grant", 1, true)).to.be.ok()
            expect(
                service:find(
                    'self:_applyGrant(player, data, { id = "entry", grant = self._config.entry_grant })',
                    1,
                    true
                )
            ).to.be.ok()
            expect(service:find('type(grant.ensure_slot) == "string"', 1, true)).to.be.ok()
            expect(service:find("restart_on_enter wipes that table", 1, true)).to.be.ok()
            local watchAt = service:find("function CombatTutorialService:_ensureWatchers", 1, true)
            local plateAt = watchAt and service:find("self:_applyDoorPlate(player)", watchAt, true)
            expect(watchAt ~= nil and plateAt ~= nil).to.equal(true)
            expect(service:find("combat_tutorial_door_blocked", 1, true)).to.be.ok()
            expect(service:find("_stampDoorSurface", 1, true)).to.be.ok()
            expect(service:find("_requestLeave", 1, true)).to.be.ok()
            expect(service:find('face, "Lesson"', 1, true)).to.be.ok()
            expect(service:find('face, "Leave"', 1, true)).to.be.ok()
            expect(service:find("CombatTutorialDoorBillboard", 1, true)).to.be.ok()
            expect(service:find('Instance.new("BillboardGui")', 1, true)).to.equal(nil)
            local doorButtons = readFile("src/Client/Systems/CombatTutorialDoorButtons.lua")
            expect(doorButtons:find("CombatTutorialDoorAction", 1, true)).to.be.ok()
            local events = loadModule("configs/game_events.lua")
            expect(events.combat_tutorial_door_blocked.banner).to.be.ok()
            local controller = readFile("src/Client/Systems/TutorialController.lua")
            expect(controller:find("MissionInstances", 1, true)).to.be.ok()
            local combatOverride =
                controller:find('if player:GetAttribute("InCombatTutorial") == true then', 1, true)
            local mergeGate = controller:find("return isMergePlace()", 1, true)
            expect(combatOverride ~= nil and mergeGate ~= nil and combatOverride < mergeGate).to.equal(
                true
            )
            expect(cfg.steps[11].spawn.shield).to.equal(true)
            local selectPet = cfg.steps[11]
            expect(selectPet.id).to.equal("select_pet")
            expect(selectPet.wound.remaining_fraction >= 0.4).to.equal(true)
            expect(selectPet.wound.remaining_fraction <= 0.5).to.equal(true)
            expect(selectPet.target.name).to.equal("InjuredSlot")
            expect(selectPet.target.cue_side).to.equal("left")
            expect(selectPet.body:find("Let a pet take a hit", 1, true)).to.equal(nil)
            expect(service:find("_woundForStep", 1, true)).to.be.ok()
            expect(service:find("CombatTutorialWoundSlot", 1, true)).to.be.ok()
            expect(service:find("NotePetHit", 1, true)).to.be.ok()
            local enemy = readFile("src/Server/Services/EnemyService.lua")
            expect(enemy:find("function EnemyService:NotePetHit", 1, true)).to.be.ok()
            expect(controller:find("InjuredSlot", 1, true)).to.be.ok()
            expect(controller:find('cueSide == "left"', 1, true)).to.be.ok()
            expect(cfg.steps[12].drop_shields).to.equal(true)
            expect(cfg.steps[13].id).to.equal("heal_fight")
            expect(cfg.steps[13].complete_on.event).to.equal("combat_tutorial_room_cleared")
            expect(cfg.steps[13].activate_beacon).to.equal(nil)
            expect(cfg.steps[14].id).to.equal("advance_heal")
            expect(cfg.steps[14].return_to_lobby).to.equal(true)
            expect(cfg.steps[15].grant.potions[1].id).to.equal("weakening_vial")
            local selectEnemy = cfg.steps[16]
            expect(selectEnemy.id).to.equal("select_enemy")
            expect(selectEnemy.spawn.shield).to.equal(true)
            expect(selectEnemy.mark_enemy).to.equal(true)
            expect(selectEnemy.target.name).to.equal("TutorialEnemy")
            expect(selectEnemy.target.cue_side).to.equal("right")
            expect(selectEnemy.target.force_overlay).to.equal(true)
            expect(service:find("_markTargetEnemy", 1, true)).to.be.ok()
            expect(service:find("CombatTutorialTargetEnemy", 1, true)).to.be.ok()
            expect(service:find("CombatTutorialMark", 1, true)).to.be.ok()
            expect(service:find("expandSpawnUnits", 1, true)).to.be.ok()
            expect(service:find("TutorialPack.clamp", 1, true)).to.be.ok()
            expect(service:find("ignoreEnemyLevelOffset", 1, true)).to.be.ok()
            expect(service:find("CombatTutorialOwner", 1, true)).to.be.ok()
            expect(service:find("_maybeClearRoom", 1, true)).to.be.ok()
            expect(service:find("packRemaining", 1, true)).to.be.ok()
            expect(service:find("packSpawned", 1, true)).to.be.ok()
            expect(controller:find("TutorialEnemy", 1, true)).to.be.ok()
            expect(controller:find('cueSide == "right"', 1, true)).to.be.ok()
            local throwWeaken = cfg.steps[17]
            expect(throwWeaken.id).to.equal("throw_weaken")
            expect(throwWeaken.complete_on.potion).to.equal("weakening_vial")
            expect(throwWeaken.drop_shields).to.equal(true)
            expect(cfg.steps[18].id).to.equal("weaken_fight")
            expect(cfg.steps[18].complete_on.event).to.equal("combat_tutorial_room_cleared")
            expect(cfg.steps[18].activate_beacon).to.equal(nil)
            expect(cfg.steps[19].id).to.equal("advance_weaken")
            expect(cfg.steps[19].return_to_lobby).to.equal(true)
            expect(cfg.steps[4].complete_on.potion).to.equal("berserk_brew")
            local stackBrew = cfg.steps[20]
            expect(stackBrew.id).to.equal("stack_brew")
            expect(stackBrew.grant.potions[1].count).to.equal(10)
            expect(stackBrew.complete_on.count).to.equal(5)
            expect(stackBrew.door_button.remaining_plates[5]).to.equal("DRINK FIVE MORE")
            expect(stackBrew.door_button.remaining_plates[1]).to.equal("DRINK ONE MORE")
            expect(TutorialFlow.doorButtonCopy(stackBrew, { count = 0 })).to.equal(
                "DRINK FIVE MORE"
            )
            expect(TutorialFlow.doorButtonCopy(stackBrew, { count = 1 })).to.equal(
                "DRINK FOUR MORE"
            )
            expect(TutorialFlow.doorButtonCopy(stackBrew, { count = 3 })).to.equal("DRINK TWO MORE")
            expect(TutorialFlow.doorButtonCopy(stackBrew, { count = 4 })).to.equal("DRINK ONE MORE")
            expect(cfg.steps[21].ensure_meter.id).to.equal("damage")
            expect(cfg.steps[22].id).to.equal("stack_fight")
            expect(cfg.steps[22].spawn.hp).to.equal(400)
            expect(cfg.steps[22].ensure_meter.min_charge >= 0.9).to.equal(true)
            expect(cfg.steps[24].id).to.equal("ready_tank")
            expect(cfg.steps[24].reset_squad).to.equal(true)
            expect(cfg.steps[24].unlock_when[1].role).to.equal("tank")
            expect(cfg.steps[24].target.cue).to.equal("equip_tank")
            expect(cfg.steps[24].guide.unequip.cue_text).to.equal("TAKE OFF")
            expect(cfg.steps[24].guide.pick.body:find("Best Pets", 1, true)).to.be.ok()
            expect(cfg.steps[24].guide.activate.cue_text).to.equal("ACTIVATE")
            expect(cfg.steps[24].guide.activate.body:find("close", 1, true)).to.be.ok()
            expect(inventory:find("self:_commitDraft(function()", 1, true)).to.be.ok()
            expect(inventory:find("self:Hide()", 1, true)).to.be.ok()
            expect(controller:find("showEquipTankGuidance", 1, true)).to.be.ok()
            expect(controller:find('cue == "equip_tank"', 1, true)).to.be.ok()
            expect(controller:find("TutorialCueOverlay", 1, true)).to.be.ok()
            expect(controller:find("ancestorClips", 1, true)).to.be.ok()
            expect(controller:find("DisplayOrder = 130", 1, true)).to.be.ok()
            expect(controller:find("IgnoreGuiInset = false", 1, true)).to.be.ok()
            expect(controller:find("GetGuiInset", 1, true)).to.be.ok()
            expect(controller:find("useOverlay", 1, true)).to.be.ok()
            expect(controller:find("options.forceOverlay == true", 1, true)).to.be.ok()
            -- Inset is read from the ScreenGui parent, not the ancestorClips boolean.
            expect(controller:find("host.IgnoreGuiInset", 1, true)).to.be.ok()
            expect(inventory:find("_stampTankLessonGuides", 1, true)).to.be.ok()
            expect(inventory:find("UnequipWeakest", 1, true)).to.be.ok()
            expect(inventory:find("StrongestTank", 1, true)).to.be.ok()
            expect(inventory:find("_removeWeakestDraftMember", 1, true)).to.be.ok()
            expect(cfg.steps[28].complete_on.enemy).to.equal("rabid_bunny")
            expect(cfg.steps[28].spawn.units[1].mark).to.equal(true)
            expect(cfg.steps[28].id).to.equal("healer_hunt")
            expect(cfg.steps[28].target.cue).to.equal("healer_focus")
            expect(cfg.steps[28].target.force_overlay).to.equal(true)
            expect(cfg.steps[28].lost_banner:find("healer", 1, true)).to.be.ok()
            expect(service:find("_updateHealerFocus", 1, true)).to.be.ok()
            expect(service:find("FocusSquadOnEnemy", 1, true)).to.be.ok()
            expect(service:find("healer_focus", 1, true)).to.be.ok()
            expect(cfg.steps[28].healer_focus.pin_seconds).to.equal(600)
            expect(service:find("roomClearToken", 1, true)).to.be.ok()
            expect(service:find("this step still has to", 1, true)).to.be.ok()
            expect(service:find("CombatTutorialHealerCue", 1, true)).to.be.ok()
            expect(service:find("combat_tutorial_healer_lost", 1, true)).to.be.ok()
            expect(controller:find("showHealerFocusGuidance", 1, true)).to.be.ok()
            expect(controller:find('cue == "healer_focus"', 1, true)).to.be.ok()
            expect(controller:find('CombatTutorialHealerCue") == true', 1, true)).to.be.ok()
            expect(service:find("HealerFocus.tick", 1, true)).to.be.ok()
            expect(events.combat_tutorial_healer_lost.banner).to.be.ok()
            expect(cfg.steps[29].id).to.equal("healer_fight")
            expect(cfg.steps[29].complete_on.event).to.equal("combat_tutorial_room_cleared")
            expect(cfg.steps[29].activate_beacon).to.equal(nil)
            expect(cfg.steps[29].lock_door).to.equal(true)
            expect(cfg.steps[32].complete_on.event).to.equal("combat_tutorial_room_cleared")
            expect(cfg.steps[32].target.kind).to.equal("none")
            expect(cfg.combat_shield.pool).to.equal(400)
            expect(cfg.combat_shield.duration).to.equal(12)
            expect(cfg.steps[32].spawn.units[1].auto_heal).to.be.ok()
            expect(cfg.steps[32].spawn.units[2].count).to.equal(2)
            expect(cfg.steps[32].spawn.units[2].shield).to.equal(nil)
            expect(cfg.steps[32].spawn.units[2].absorb).to.equal(nil)
            expect(cfg.steps[33].id).to.equal("advance_together")
            expect(cfg.steps[33].return_to_exit).to.equal(true)
            expect(cfg.steps[33].return_to_lobby).to.equal(nil)
            expect(cfg.completion.grant_earned_level).to.equal(2)
            expect(cfg.completion.apply_level_grant).to.equal(true)
            expect(cfg.completion.grant.currencies.grass_coins).to.equal(250)
            expect(service:find("_applyCompletionReward", 1, true)).to.be.ok()
            expect(service:find("CombatTutorialRewardGranted", 1, true)).to.be.ok()
            expect(service:find("_applyCompletionLevelGrant", 1, true)).to.be.ok()
            expect(service:find("completionLevelTarget = target", 1, true)).to.be.ok()
            expect(service:find("tutorial.completionLevelGranted = true", 1, true)).to.be.ok()
            expect(service:find("progression:GetEarnedLevel(player)", 1, true)).to.be.ok()
            expect(service:find("combat_tutorial_completion_level", 1, true)).to.be.ok()
            expect(service:find("never mark the track done", 1, true)).to.equal(nil)
            expect(controller:find("activeCompletionConfig", 1, true)).to.be.ok()
            expect(events.combat_tutorial_complete.banner).to.be.ok()
            expect(events.combat_rank_achieved.sound).to.be.ok()
            expect(service:find("_syncCombatRank", 1, true)).to.be.ok()
            expect(service:find("combat_rank_achieved", 1, true)).to.be.ok()
        end)

        it("fields a very weak melee only after ENTER, not on mission enter", function()
            expect(cfg.enemy.id).to.equal("rabid_dog")
            expect(cfg.enemy.hp <= 275).to.equal(true)
            expect(cfg.enemy.attack.damage <= 2).to.equal(true)
            local enemies = loadModule("configs/enemies.lua")
            expect(enemies.enemies.rabid_dog.role).to.equal("melee")
            local progress = TutorialFlow.fresh(cfg)
            local step = TutorialFlow.current(cfg, progress)
            expect(step.id).to.equal("ready")
            expect(step.spawn).to.equal(nil)
            local stillReady = TutorialFlow.advance(cfg, progress, "enemy_defeated")
            expect(stillReady.step).to.equal(1)
            progress = TutorialFlow.advance(cfg, progress, "combat_tutorial_entered_arena")
            step = TutorialFlow.current(cfg, progress)
            expect(step.id).to.equal("first_fight")
            expect(step.spawn.count).to.equal(1)
            expect(step.spawn.where).to.equal("arena")
            progress = TutorialFlow.advance(cfg, progress, "enemy_defeated")
            step = TutorialFlow.current(cfg, progress)
            expect(step.id).to.equal("advance_stage")
            expect(step.activate_beacon).to.equal(true)
            local stillPillar = TutorialFlow.advance(cfg, progress, "enemy_defeated")
            expect(stillPillar.step).to.equal(progress.step)
            progress = TutorialFlow.advance(cfg, progress, "combat_tutorial_advance")
            expect(TutorialFlow.current(cfg, progress).id).to.equal("battle_brew")
        end)

        it("caps teaching packs at one healer and three others at any level", function()
            expect(cfg.pack_cap.max_healers).to.equal(1)
            expect(cfg.pack_cap.max_others).to.equal(3)
            expect(cfg.pack_cap.enemy_level).to.equal(1)
            local stacked = {
                { auto_heal = { amount = 80 } },
                { auto_heal = { amount = 80 } },
                { hp = 400 },
                { hp = 400 },
                { hp = 400 },
                { hp = 400 },
            }
            local clamped = TutorialPack.clamp(stacked, cfg.pack_cap)
            expect(#clamped).to.equal(4)
            local healers = 0
            for _, unit in ipairs(clamped) do
                if type(unit.auto_heal) == "table" then
                    healers += 1
                end
            end
            expect(healers).to.equal(1)
            local leftover = {
                { auto_heal = { amount = 80 } },
                { hp = 200 },
                { hp = 200 },
                { auto_heal = { amount = 80 } },
                { hp = 200 },
                { hp = 200 },
            }
            local extra = TutorialPack.surplus(leftover, cfg.pack_cap)
            expect(#extra).to.equal(2)
            expect(extra[1].auto_heal).to.be.ok()
            expect(extra[2].hp).to.equal(200)
            for _, step in ipairs(cfg.steps) do
                local spec = step.spawn
                if type(spec) == "table" then
                    local units = {}
                    if type(spec.units) == "table" and #spec.units > 0 then
                        for _, unit in ipairs(spec.units) do
                            local n = math.max(1, math.floor(tonumber(unit.count) or 1))
                            for _ = 1, n do
                                units[#units + 1] = unit
                            end
                        end
                    else
                        local n = math.max(1, math.floor(tonumber(spec.count) or 1))
                        for _ = 1, n do
                            units[#units + 1] = spec
                        end
                    end
                    local live = TutorialPack.clamp(units, cfg.pack_cap)
                    local healerCount, otherCount = 0, 0
                    for _, unit in ipairs(live) do
                        if type(unit.auto_heal) == "table" then
                            healerCount += 1
                        else
                            otherCount += 1
                        end
                    end
                    expect(healerCount <= cfg.pack_cap.max_healers).to.equal(true)
                    expect(otherCount <= cfg.pack_cap.max_others).to.equal(true)
                end
            end
            local service = readFile("src/Server/Services/CombatTutorialService.lua")
            expect(service:find("function CombatTutorialService:_leave", 1, true)).to.be.ok()
            expect(service:find("self:_despawnTutorialEnemies(player)", 1, true)).to.be.ok()
            expect(service:find("DespawnForCombatTutorial", 1, true)).to.be.ok()
            expect(service:find("DespawnEnemiesInBounds", 1, true)).to.be.ok()
            expect(service:find("_enforceLivePackCap", 1, true)).to.be.ok()
            expect(service:find("CombatTutorialRole", 1, true)).to.be.ok()
            expect(service:find("def.level = math.max(1", 1, true)).to.be.ok()
            local enemy = readFile("src/Server/Services/EnemyService.lua")
            expect(enemy:find("function EnemyService:DespawnForCombatTutorial", 1, true)).to.be.ok()
            expect(enemy:find("function EnemyService:FocusSquadOnEnemy", 1, true)).to.be.ok()
            expect(enemy:find("function EnemyService:DespawnModel", 1, true)).to.be.ok()
        end)

        it("rewinds a mid-fight leave to that loop's lobby, not the track start", function()
            local resume = {
                first_fight = "ready",
                brew_fight = "battle_brew",
                select_pet = "ready_heal",
                cast_heal = "ready_heal",
                heal_fight = "ready_heal",
                select_enemy = "ready_weaken",
                throw_weaken = "ready_weaken",
                weaken_fight = "ready_weaken",
                stack_fight = "stack_brew",
                tank_fight = "ready_tank",
                healer_hunt = "ready_healer",
                healer_fight = "ready_healer",
                together_fight = "ready_together",
            }
            for _, step in ipairs(cfg.steps) do
                expect(step.leave_resume).to.equal(resume[step.id])
            end
            local progress = feed(TutorialFlow.fresh(cfg), {
                "combat_tutorial_entered_arena",
                "enemy_defeated",
                "combat_tutorial_advance",
                { "potion_used", { potion = "berserk_brew" } },
                "combat_tutorial_entered_arena",
            })
            expect(TutorialFlow.current(cfg, progress).id).to.equal("brew_fight")
            progress.granted = { battle_brew = true, ready_brew = true }
            local rewound, changed = TutorialFlow.rewindTo(cfg, progress, "battle_brew")
            expect(changed).to.equal(true)
            expect(TutorialFlow.current(cfg, rewound).id).to.equal("battle_brew")
            expect(rewound.granted.battle_brew).to.equal(nil)
            expect(rewound.granted.ready_brew).to.equal(nil)
            local stayed, again = TutorialFlow.rewindTo(cfg, rewound, "battle_brew")
            expect(again).to.equal(false)
            expect(TutorialFlow.current(cfg, stayed).id).to.equal("battle_brew")
            local service = readFile("src/Server/Services/CombatTutorialService.lua")
            expect(service:find("_rewindLeaveResume", 1, true)).to.be.ok()
            expect(service:find('stepId = "combat_" ..', 1, true)).to.be.ok()
        end)

        it("migrates v1 saves onto the ENTER-then-spawn order", function()
            local brew, _ = TutorialFlow.migrateProgress(cfg, {
                version = 1,
                step = 2,
                count = 0,
                done = false,
            })
            expect(brew.version).to.equal(11)
            expect(TutorialFlow.current(cfg, brew).id).to.equal("battle_brew")
            local arena, _ = TutorialFlow.migrateProgress(cfg, {
                version = 1,
                step = 4,
                count = 0,
                done = false,
            })
            expect(TutorialFlow.current(cfg, arena).id).to.equal("select_pet")
        end)

        it("adds the Heal enhancement lesson without rewinding existing test saves", function()
            local bind = TutorialFlow.migrateProgress(cfg, {
                version = 10,
                step = 8,
                count = 0,
                done = false,
            })
            expect(TutorialFlow.current(cfg, bind).id).to.equal("bind_heal")

            local alreadyPast = TutorialFlow.migrateProgress(cfg, {
                version = 10,
                step = 9,
                count = 0,
                done = false,
            })
            expect(TutorialFlow.current(cfg, alreadyPast).id).to.equal("ready_heal")

            local fresh = feed(TutorialFlow.fresh(cfg), {
                "combat_tutorial_entered_arena",
                "enemy_defeated",
                "combat_tutorial_advance",
                { "potion_used", { potion = "berserk_brew" } },
                "combat_tutorial_entered_arena",
                "enemy_defeated",
                "combat_tutorial_advance",
                "tutorial_hotbar_finished",
            })
            expect(TutorialFlow.current(cfg, fresh).id).to.equal("enhance_heal")
            local wrongPower =
                TutorialFlow.advance(cfg, fresh, "enhancement_slotted", { powerId = "resonance" })
            expect(TutorialFlow.current(cfg, wrongPower).id).to.equal("enhance_heal")
            local completed =
                TutorialFlow.advance(cfg, fresh, "enhancement_slotted", { powerId = "heal" })
            expect(TutorialFlow.current(cfg, completed).id).to.equal("ready_heal")
        end)

        it("uses the existing absorb shield instead of a special unkillable flag", function()
            expect(cfg.shield.power_id).to.equal("dune_shield")
            expect(cfg.shield.pool >= 1000000).to.equal(true)
            expect(cfg.shield.duration > 0).to.equal(true)
            expect(cfg.combat_shield.pool).to.equal(400)
            expect(cfg.combat_shield.duration).to.equal(12)
            local service = readFile("src/Server/Services/CombatTutorialService.lua")
            expect(service:find("CombatTutorialEnter", 1, true)).to.be.ok()
            expect(service:find("CombatShield", 1, true)).to.be.ok()
            expect(service:find("_dropShields", 1, true)).to.be.ok()
            expect(service:find("unkillable", 1, true)).to.equal(nil)
            local apply = readFile("src/Server/CombatApplication.lua")
            expect(apply:find('GetAttribute("CombatShield")', 1, true)).to.be.ok()
            expect(apply:find('outcome = "absorbed"', 1, true)).to.be.ok()
        end)

        it("advances through the authored events and completes after the last pillar", function()
            local progress = TutorialFlow.fresh(cfg)
            progress = feed(progress, {
                "combat_tutorial_entered_arena",
                "enemy_defeated",
                "combat_tutorial_advance",
                { "potion_used", { potion = "berserk_brew" } },
                "combat_tutorial_entered_arena",
                "enemy_defeated",
                "combat_tutorial_advance",
                "tutorial_hotbar_finished",
                { "enhancement_slotted", { powerId = "heal" } },
                "combat_tutorial_entered_arena",
                "pet_target_selected",
                "pet_healed",
                "combat_tutorial_room_cleared",
                "combat_tutorial_advance",
                "combat_tutorial_entered_arena",
                "enemy_target_selected",
                { "potion_used", { potion = "weakening_vial" } },
                "combat_tutorial_room_cleared",
                "combat_tutorial_advance",
                { "potion_used", { potion = "berserk_brew" } },
                { "potion_used", { potion = "berserk_brew" } },
                { "potion_used", { potion = "berserk_brew" } },
                { "potion_used", { potion = "berserk_brew" } },
                { "potion_used", { potion = "berserk_brew" } },
                "combat_tutorial_entered_arena",
                "enemy_defeated",
                "combat_tutorial_advance",
                "combat_tutorial_entered_arena",
                "enemy_defeated",
                "combat_tutorial_advance",
                "combat_tutorial_entered_arena",
                { "enemy_defeated", { enemy = "rabid_bunny" } },
                "combat_tutorial_room_cleared",
                "combat_tutorial_advance",
                "combat_tutorial_entered_arena",
                "combat_tutorial_room_cleared",
                "combat_tutorial_advance",
            })
            expect(progress.done).to.equal(true)
            expect(TutorialFlow.current(cfg, progress)).to.equal(nil)
        end)

        it("only credits the authored potion on brew and weaken lessons", function()
            local progress = TutorialFlow.fresh(cfg)
            progress = feed(progress, {
                "combat_tutorial_entered_arena",
                "enemy_defeated",
                "combat_tutorial_advance",
            })
            expect(TutorialFlow.current(cfg, progress).id).to.equal("battle_brew")
            local stillBrew = TutorialFlow.advance(cfg, progress, "potion_used", {
                potion = "weakening_vial",
            })
            expect(stillBrew.step).to.equal(progress.step)
            progress = TutorialFlow.advance(cfg, progress, "potion_used", {
                potion = "berserk_brew",
            })
            expect(TutorialFlow.current(cfg, progress).id).to.equal("ready_brew")
            progress = feed(progress, {
                "combat_tutorial_entered_arena",
                "enemy_defeated",
                "combat_tutorial_advance",
                "tutorial_hotbar_finished",
                { "enhancement_slotted", { powerId = "heal" } },
                "combat_tutorial_entered_arena",
                "pet_target_selected",
                "pet_healed",
                "combat_tutorial_room_cleared",
                "combat_tutorial_advance",
                "combat_tutorial_entered_arena",
                "enemy_target_selected",
            })
            expect(TutorialFlow.current(cfg, progress).id).to.equal("throw_weaken")
            local stillThrow = TutorialFlow.advance(cfg, progress, "potion_used", {
                potion = "berserk_brew",
            })
            expect(stillThrow.step).to.equal(progress.step)
            progress = TutorialFlow.advance(cfg, progress, "potion_used", {
                potion = "weakening_vial",
            })
            expect(TutorialFlow.current(cfg, progress).id).to.equal("weaken_fight")
            local stillFight = TutorialFlow.advance(cfg, progress, "combat_tutorial_advance")
            expect(stillFight.step).to.equal(progress.step)
            progress = TutorialFlow.advance(cfg, progress, "combat_tutorial_room_cleared")
            expect(TutorialFlow.current(cfg, progress).id).to.equal("advance_weaken")
        end)

        it("only credits the authored enemy on the healer hunt", function()
            local progress = TutorialFlow.fresh(cfg)
            progress = feed(progress, {
                "combat_tutorial_entered_arena",
                "enemy_defeated",
                "combat_tutorial_advance",
                { "potion_used", { potion = "berserk_brew" } },
                "combat_tutorial_entered_arena",
                "enemy_defeated",
                "combat_tutorial_advance",
                "tutorial_hotbar_finished",
                { "enhancement_slotted", { powerId = "heal" } },
                "combat_tutorial_entered_arena",
                "pet_target_selected",
                "pet_healed",
                "combat_tutorial_room_cleared",
                "combat_tutorial_advance",
                "combat_tutorial_entered_arena",
                "enemy_target_selected",
                { "potion_used", { potion = "weakening_vial" } },
                "combat_tutorial_room_cleared",
                "combat_tutorial_advance",
                { "potion_used", { potion = "berserk_brew" } },
                { "potion_used", { potion = "berserk_brew" } },
                { "potion_used", { potion = "berserk_brew" } },
                { "potion_used", { potion = "berserk_brew" } },
                { "potion_used", { potion = "berserk_brew" } },
                "combat_tutorial_entered_arena",
                "enemy_defeated",
                "combat_tutorial_advance",
                "combat_tutorial_entered_arena",
                "enemy_defeated",
                "combat_tutorial_advance",
                "combat_tutorial_entered_arena",
            })
            expect(TutorialFlow.current(cfg, progress).id).to.equal("healer_hunt")
            local stillHunt = TutorialFlow.advance(cfg, progress, "enemy_defeated", {
                enemy = "rabid_dog",
            })
            expect(stillHunt.step).to.equal(progress.step)
            progress = TutorialFlow.advance(cfg, progress, "enemy_defeated", {
                enemy = "rabid_bunny",
            })
            expect(TutorialFlow.current(cfg, progress).id).to.equal("healer_fight")
            local stillFight = TutorialFlow.advance(cfg, progress, "combat_tutorial_advance")
            expect(stillFight.step).to.equal(progress.step)
            progress = TutorialFlow.advance(cfg, progress, "combat_tutorial_room_cleared")
            expect(TutorialFlow.current(cfg, progress).id).to.equal("advance_healer")
        end)

        it("needs five berserk sips before the stacked-brew fight", function()
            local progress = TutorialFlow.fresh(cfg)
            progress = feed(progress, {
                "combat_tutorial_entered_arena",
                "enemy_defeated",
                "combat_tutorial_advance",
                { "potion_used", { potion = "berserk_brew" } },
                "combat_tutorial_entered_arena",
                "enemy_defeated",
                "combat_tutorial_advance",
                "tutorial_hotbar_finished",
                { "enhancement_slotted", { powerId = "heal" } },
                "combat_tutorial_entered_arena",
                "pet_target_selected",
                "pet_healed",
                "combat_tutorial_room_cleared",
                "combat_tutorial_advance",
                "combat_tutorial_entered_arena",
                "enemy_target_selected",
                { "potion_used", { potion = "weakening_vial" } },
                "combat_tutorial_room_cleared",
                "combat_tutorial_advance",
            })
            expect(TutorialFlow.current(cfg, progress).id).to.equal("stack_brew")
            for _ = 1, 4 do
                progress = TutorialFlow.advance(cfg, progress, "potion_used", {
                    potion = "berserk_brew",
                })
            end
            expect(TutorialFlow.current(cfg, progress).id).to.equal("stack_brew")
            expect(progress.count).to.equal(4)
            progress = TutorialFlow.advance(cfg, progress, "potion_used", {
                potion = "berserk_brew",
            })
            expect(TutorialFlow.current(cfg, progress).id).to.equal("ready_stack")
            local BrewMeter = loadModule("src/Shared/Game/BrewMeter.lua")
            local charge = 0
            for _ = 1, 5 do
                charge = BrewMeter.sip(charge, 0.5)
            end
            expect(charge >= 0.9).to.equal(true)
        end)

        it("keeps Heal as an innate long-recharge single-pet power", function()
            local heal = powers.powers.heal
            expect(heal.innate).to.equal(true)
            expect(heal.effect).to.equal("innate_heal")
            expect(heal.target).to.equal("single_pet")
            expect(heal.cooldown_seconds >= 90).to.equal(true)
            expect(powers.effect_kinds.innate_heal.family).to.equal("heal")
            expect(stats.counters.combat_tutorials_completed).to.be.ok()
        end)
    end)

    describe("combat tutorial mission + hall gate", function()
        it("reuses Training Ground Room 1 and skips ChallengeRuns persist", function()
            local mission = missions.missions.combat_tutorial
            expect(mission.tutorial).to.equal(true)
            expect(mission.theme).to.equal("grass")
            expect(mission.decor.props_min >= 2).to.equal(true)
            expect(mission.decor.wall_decor_min >= 2).to.equal(true)
            expect(cfg.steps[1].theme).to.equal("grass")
            expect(cfg.steps[4].theme).to.equal("lava")
            expect(cfg.steps[8].theme).to.equal("heaven")
            expect(cfg.steps[15].theme).to.equal("hell")
            expect(mission.seed_policy).to.equal("gauntlet_room")
            expect(mission.gauntlet.mode).to.equal("combat_tutorial")
            expect(mission.gauntlet.rooms).to.equal(1)
            expect(ChallengeRun.layoutContext(1, "combat_tutorial")).to.equal("train#1")
            expect(ChallengeRun.layoutContext(1, "combat_tutorial")).to.equal(
                ChallengeRun.layoutContext(1, "training_ground")
            )
            local mode = challengeCfg.modes.combat_tutorial
            expect(ChallengeRun.skipsEngageGate(mode)).to.equal(true)
            expect(ChallengeRun.persistsRuns(mode)).to.equal(false)
            expect(ChallengeRun.persistsRuns(challengeCfg.modes.training_ground)).to.equal(true)
        end)

        it("opens combat training in a mission slot from the Earth cave door", function()
            expect(cfg.entry.enabled).to.equal(false)
            expect(cfg.venue.mode).to.equal("mission_slot")
            expect(cfg.venue.door).to.equal("homeworld_cave")
            local hall = loadModule("configs/hall_of_worlds.lua")
            expect(hall.entry_enabled).to.equal(false)
            local enemies = loadModule("configs/enemies.lua")
            expect(enemies.spawners.bindings.Earth.disabled).to.equal(true)
            local missions = loadModule("configs/missions.lua")
            expect(missions.slots.count).to.equal(10)
            expect(missions.slots.origin_x).to.equal(24000)
            expect(missions.missions.combat_tutorial.tutorial).to.equal(true)
            local service = readFile("src/Server/Services/CombatTutorialService.lua")
            expect(service:find("_openCaveMission", 1, true)).to.be.ok()
            expect(service:find("_offerCaveEnter", 1, true)).to.be.ok()
            expect(service:find("_needsRedoConfirm", 1, true)).to.be.ok()
            expect(service:find("CombatTutorialRedoOffer", 1, true)).to.be.ok()
            expect(service:find("_syncLobbyLeavePrompt", 1, true)).to.be.ok()
            expect(service:find("_leaveCaveMission", 1, true)).to.be.ok()
            expect(service:find("Maps.Home", 1, true)).to.be.ok()
            local missionService = readFile("src/Server/Services/MissionInstanceService.lua")
            expect(missionService:find("if not mission.tutorial then", 1, true)).to.be.ok()
            expect(missionService:find("if mission and mission.tutorial then", 1, true)).to.be.ok()
        end)

        it("keeps Homeworld Resonance-before-combat and only gates it while inside", function()
            local home = loadModule("configs/tutorial.lua")
            expect(home.version).to.equal(6)
            expect(home.steps[5].id).to.equal("bind_power")
            expect(home.steps[8].id).to.equal("first_fight")
            expect(home.steps[8].complete_on.event).to.equal("combat_tutorial_complete")
            expect(home.steps[9].id).to.equal("rally_call")
            local tutorialService = readFile("src/Server/Services/TutorialService.lua")
            expect(tutorialService:find('GetAttribute("InCombatTutorial")', 1, true)).to.be.ok()
            expect(tutorialService:find('name ~= "combat_tutorial_complete"', 1, true)).to.be.ok()
        end)
    end)
end
