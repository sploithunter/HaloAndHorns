--[[
    TutorialFlow (pure core) — [unit] step machine over the live configs/tutorial.lua.
    Run: mise run test-headless
]]

local TutorialFlow = loadModule("src/Shared/Game/TutorialFlow.lua")
local cfg = loadModule("configs/tutorial.lua")

-- walk helper: feed events (string name, or {name, ctx} for sum_ctx steps)
local function feed(progress, events)
    for _, e in ipairs(events) do
        if type(e) == "table" then
            progress = TutorialFlow.advance(cfg, progress, e[1], e[2])
        else
            progress = TutorialFlow.advance(cfg, progress, e)
        end
    end
    return progress
end

return function()
    describe("config shape", function()
        it("has ordered steps with events", function()
            expect(#cfg.steps >= 3).to.equal(true) -- 4 since the quest-chain handoff (Jason)
            expect(type(cfg.completion)).to.equal("table") -- the level-2 completion card
            expect(cfg.completion.grant_earned_level).to.equal(2)
            for _, step in ipairs(cfg.steps) do
                expect(type(step.id)).to.equal("string")
                expect(type(step.title)).to.equal("string")
                expect(type(step.complete_on.event)).to.equal("string")
            end
        end)

        it("hides ascension until either independent tutorial is done", function()
            expect(cfg.hold_level_claim).to.equal(true)
            expect(TutorialFlow.allowsLevelClaim(cfg, { done = false }, {})).to.equal(false)
            expect(TutorialFlow.allowsLevelClaim(cfg, { done = true }, {})).to.equal(true)
            expect(TutorialFlow.allowsLevelClaim(cfg, { done = false }, {}, { done = true }, 1)).to.equal(
                true
            )
            expect(TutorialFlow.ascensionUnlocked(cfg, { done = false }, { done = false }, {}, 1)).to.equal(
                false
            )
            expect(TutorialFlow.ascensionUnlocked(cfg, { done = false }, { done = false }, {}, 2)).to.equal(
                true
            )
            expect(TutorialFlow.allowsLevelClaim(cfg, { done = false }, {
                TutorialCompleted = true,
            })).to.equal(true)
            expect(TutorialFlow.allowsLevelClaim(cfg, nil, {})).to.equal(true)
            expect(
                TutorialFlow.allowsLevelClaim({ hold_level_claim = false }, { done = false }, {})
            ).to.equal(true)
            local progression = readFile("src/Server/Services/PlayerProgressionService.lua")
            expect(progression:find("_tutorialAllowsClaim", 1, true)).to.be.ok()
            expect(progression:find('SetAttribute("AscensionUnlocked"', 1, true)).to.be.ok()
            expect(progression:find("tutorial_in_progress", 1, true)).to.be.ok()
            expect(progression:find("r.canClaim and self:_tutorialAllowsClaim(player)", 1, true)).to.be.ok()
            local tutorial = readFile("src/Server/Services/TutorialService.lua")
            expect(tutorial:find("progression:_publish(player)", 1, true)).to.be.ok()
        end)

        it("wires a retryable, once-only level guarantee to genuine completion", function()
            local source = readFile("src/Server/Services/TutorialService.lua")
            expect(source:find("data.Tutorial.completionLevelTarget = target", 1, true)).to.be.ok()
            expect(source:find("progression:EnsureEarnedLevel(player, target)", 1, true)).to.be.ok()
            expect(source:find("tutorial.completionLevelGranted = true", 1, true)).to.be.ok()
            expect(source:find('fireGameEvent(player, "tutorial_level_awarded"', 1, true)).to.be.ok()
        end)

        it("admin reset restores Home Spawn and clears the legacy completion flag", function()
            local source = readFile("src/Server/Services/TutorialService.lua")
            expect(source:find("hallTrack = true", 1, true)).to.equal(nil)
            expect(source:find("data.GameData.TutorialCompleted = false", 1, true)).to.be.ok()
            expect(source:find("data.CombatTutorial = nil", 1, true)).to.be.ok()
            expect(source:find("data.CombatTutorialLoadout = nil", 1, true)).to.be.ok()
            local admin = readFile("src/Server/Services/AdminToolsService.lua")
            expect(admin:find("playerData.GameData.TutorialCompleted = false", 1, true)).to.be.ok()
            expect(admin:find('playerData.GameData.UnlockedAreas = { "Spawn" }', 1, true)).to.be.ok()
            expect(admin:find('playerData.GameData.LastArea = "Spawn"', 1, true)).to.be.ok()
            expect(admin:find("ResetForBeginning", 1, true)).to.be.ok()
            expect(admin:find("CombatTutorialService", 1, true)).to.be.ok()
            local combat = readFile("src/Server/Services/CombatTutorialService.lua")
            expect(combat:find("function CombatTutorialService:ResetForBeginning", 1, true)).to.be.ok()
            expect(combat:find("session.skipRewind = true", 1, true)).to.be.ok()
            expect(combat:find("_publishCombatRank(player, nil)", 1, true)).to.be.ok()
            expect(combat:find("StatusBadgeSeen = {}", 1, true)).to.be.ok()
        end)

        it("restores the authored Homeworld lesson order and targets", function()
            local expected = {
                "hatch_first_egg",
                "farm_crystals",
                "hatch_another",
                "build_squad",
                "bind_power",
                "cast_power",
                "slot_power",
                "first_fight",
                "rally_call",
            }
            expect(cfg.version).to.equal(6)
            for index, id in ipairs(expected) do
                expect(cfg.steps[index].id).to.equal(id)
            end
            expect(cfg.steps[1].target.prefer).to.equal("Grass")
            expect(cfg.steps[3].target.prefer).to.equal("Grass")
            expect(cfg.steps[5].target.name).to.equal("Edit")
            expect(cfg.steps[8].target.name).to.equal("EarthLair")
            expect(cfg.steps[8].target.root).to.equal("Maps.Home")
            expect(cfg.steps[8].handoff.later_label).to.equal("Later")
            expect(cfg.steps[8].handoff.ok_label).to.equal("Okay")
            expect(cfg.steps[8].body).to.equal(
                "The Earth cave is a training ground. Press E to enter and learn how to fight."
            )
            expect(cfg.steps[8].complete_on.event).to.equal("combat_tutorial_complete")
        end)

        it("keeps guided auto-fill and squad review on server-authoritative seams", function()
            local egg = readFile("src/Server/Services/EggService.lua")
            local fillAt =
                egg:find("response.tutorialSquadAssist = self:ApplyTutorialSquadAssist", 1, true)
            local eventAt = egg:find("self:RecordHatchSuccess(player, request, response)", 1, true)
            expect(fillAt ~= nil and eventAt ~= nil and fillAt < eventAt).to.equal(true)

            local server = readFile("src/Server/Services/TutorialService.lua")
            expect(server:find('action == "opened"', 1, true)).to.be.ok()
            expect(server:find("self._squadReviewOpened[player]", 1, true)).to.be.ok()

            local client = readFile("src/Client/UI/Menus/InventoryPanel.lua")
            expect(client:find('FireServer("opened")', 1, true)).to.be.ok()
            expect(client:find("_reportSquadLessonReviewed", 1, true)).to.be.ok()
            expect(client:find("_squadLessonPracticed", 1, true)).to.be.ok()
            expect(client:find('FireServer("reviewed")', 1, true)).to.be.ok()
        end)

        it("makes the battle brew's exact hotbar slot impossible to miss", function()
            local combat = loadModule("configs/combat_tutorial.lua")
            local battleBrew
            for _, step in ipairs(combat.steps) do
                if step.id == "battle_brew" then
                    battleBrew = step
                    break
                end
            end
            expect(battleBrew).to.be.ok()
            expect(battleBrew.target.hotbar_type).to.equal("potion")
            expect(battleBrew.target.hotbar_target).to.equal("berserk_brew")
            expect(battleBrew.target.cue).to.equal("click")

            local client = readFile("src/Client/Systems/TutorialController.lua")
            expect(client:find("options.clickCue and 5 or 3", 1, true)).to.be.ok()
            expect(client:find('tostring(options.cueText or "CLICK HERE")', 1, true)).to.be.ok()
            expect(client:find('GetAttribute("HotbarBindTarget")', 1, true)).to.be.ok()

            local hotbar = readFile("src/Client/Systems/HotbarBar.lua")
            expect(hotbar:find('SetAttribute("HotbarBindTarget"', 1, true)).to.be.ok()
        end)

        it("points Call them back at the live Rally binding", function()
            local rallyCall
            for _, step in ipairs(cfg.steps) do
                if step.id == "rally_call" then
                    rallyCall = step
                    break
                end
            end
            expect(rallyCall).to.be.ok()
            expect(rallyCall.target.name).to.equal(nil)
            expect(rallyCall.target.hotbar_type).to.equal("tactical")
            expect(rallyCall.target.hotbar_target).to.equal("rally")
            expect(rallyCall.target.cue).to.equal("click")
            expect(rallyCall.target.cue_text).to.equal("CLICK HERE")
        end)

        it("points Use Resonance at its actual live hotbar binding", function()
            local castPower
            for _, step in ipairs(cfg.steps) do
                if step.id == "cast_power" then
                    castPower = step
                    break
                end
            end
            expect(castPower).to.be.ok()
            expect(castPower.target.name).to.equal(nil)
            expect(castPower.target.hotbar_type).to.equal("power")
            expect(castPower.target.hotbar_target).to.equal("resonance")
            expect(castPower.target.cue).to.equal("click")
            expect(castPower.target.cue_text).to.equal("CLICK HERE")
        end)

        it("gives every actionable tutorial button an anchored CLICK HERE cue", function()
            local expectedTargets = {
                bind_power = "Edit",
                slot_power = "PowersButton",
            }
            local found = {}
            for _, step in ipairs(cfg.steps) do
                local expectedName = expectedTargets[step.id]
                if expectedName then
                    expect(step.target.kind).to.equal("ui")
                    expect(step.target.name).to.equal(expectedName)
                    expect(step.target.cue).to.equal("click")
                    expect(step.target.cue_text).to.equal("CLICK HERE")
                    found[step.id] = true
                end
            end
            expect(found.bind_power).to.equal(true)
            expect(found.slot_power).to.equal(true)
        end)

        it("walks Build your squad through unequip, strongest pet, and Activate", function()
            local buildSquad
            for _, step in ipairs(cfg.steps) do
                if step.id == "build_squad" then
                    buildSquad = step
                    break
                end
            end
            expect(buildSquad).to.be.ok()
            expect(buildSquad.target.kind).to.equal("ui")
            expect(buildSquad.target.name).to.equal("PetsButton")
            expect(buildSquad.target.cue).to.equal("equip_squad")
            expect(buildSquad.target.cue_text).to.equal("CLICK HERE")
            expect(buildSquad.grant.pets[1].id).to.equal("kitty")
            expect(buildSquad.grant.pets[1].variant).to.equal("rainbow")
            expect(buildSquad.guide.unequip).to.be.ok()
            expect(buildSquad.guide.pick).to.be.ok()
            expect(buildSquad.guide.activate).to.be.ok()

            local client = readFile("src/Client/Systems/TutorialController.lua")
            local inventory = readFile("src/Client/UI/Menus/InventoryPanel.lua")
            local server = readFile("src/Server/Services/TutorialService.lua")
            expect(client:find('cue == "equip_squad"', 1, true)).to.be.ok()
            expect(client:find("showEquipSquadGuidance", 1, true)).to.be.ok()
            expect(client:find('tutorialGuide = "StrongestPet"', 1, true)).to.be.ok()
            expect(inventory:find('TutorialGuide", "StrongestPet"', 1, true)).to.be.ok()
            expect(inventory:find("_squadLessonPracticed", 1, true)).to.be.ok()
            expect(inventory:find("_reportSquadLessonReviewed", 1, true)).to.be.ok()
            expect(server:find("grant.pets", 1, true)).to.be.ok()
            expect(server:find("PetGrantService", 1, true)).to.be.ok()
        end)

        it(
            "walks Power up Resonance through Powers, Resonance, slot, Potency, and Apply",
            function()
                local client = readFile("src/Client/Systems/TutorialController.lua")
                local menu = readFile("src/Client/UI/Menus/PowerChoiceMenu.lua")
                expect(client:find('state.id == "slot_power"', 1, true)).to.be.ok()
                expect(client:find("showSlotPowerGuidance", 1, true)).to.be.ok()
                expect(client:find('nextPhase = "pick_power"', 1, true)).to.be.ok()
                expect(client:find('nextPhase = "pick_slot"', 1, true)).to.be.ok()
                expect(client:find('nextPhase = "pick_potency"', 1, true)).to.be.ok()
                expect(client:find('nextPhase = "apply"', 1, true)).to.be.ok()
                expect(client:find('tutorialGuide = "Resonance"', 1, true)).to.be.ok()
                expect(client:find('tutorialGuide = "EnhanceEmptySlot"', 1, true)).to.be.ok()
                expect(client:find('tutorialGuide = "EnhancePotency"', 1, true)).to.be.ok()
                expect(client:find('tutorialGuide = "EnhanceApply"', 1, true)).to.be.ok()
                expect(menu:find("_syncEnhanceTutorialAttrs", 1, true)).to.be.ok()
                expect(menu:find('TutorialGuide", "Resonance"', 1, true)).to.be.ok()
                expect(menu:find('TutorialGuide", "EnhanceEmptySlot"', 1, true)).to.be.ok()
                expect(menu:find('TutorialGuide", "EnhancePotency"', 1, true)).to.be.ok()
                expect(menu:find('TutorialGuide", "EnhanceApply"', 1, true)).to.be.ok()
                expect(menu:find('Name = "EnhanceApply"', 1, true)).to.be.ok()
            end
        )

        it("sequences the power-binding cue through Edit, selection, and Done", function()
            local client = readFile("src/Client/Systems/TutorialController.lua")
            local hotbar = readFile("src/Client/Systems/HotbarBar.lua")
            local server = readFile("src/Server/Services/TutorialService.lua")
            expect(client:find('state.id == "bind_power"', 1, true)).to.be.ok()
            expect(client:find('nextPhase = "done"', 1, true)).to.be.ok()
            expect(client:find('nextPhase = "choose"', 1, true)).to.be.ok()
            expect(hotbar:find('SetAttribute("HotbarEditing", editMode)', 1, true)).to.be.ok()
            expect(hotbar:find("Signals.TutorialHotbarDone:FireServer()", 1, true)).to.be.ok()
            expect(hotbar:find("TutorialResonanceArrow", 1, true)).to.be.ok()
            expect(hotbar:find("arrowScale.Scale = 0.88 + 0.24 * a", 1, true)).to.be.ok()
            expect(server:find('bind.target == "resonance"', 1, true)).to.be.ok()
            expect(server:find('fireGameEvent(player, "tutorial_hotbar_finished"', 1, true)).to.be.ok()
        end)

        it("hides the quest tracker on the dedicated Merge place", function()
            local tracker = readFile("src/Client/Systems/QuestTrackerStyle.lua")
            expect(tracker:find("PlaceRuntime.isMerge", 1, true)).to.be.ok()
            expect(tracker:find("not isMergePlace()", 1, true)).to.be.ok()
        end)

        it("aligns post-tutorial quests with the upper-right PlayerList", function()
            local tracker = readFile("src/Client/Systems/QuestTrackerStyle.lua")
            local stack = readFile("src/Client/Systems/TopHudStack.lua")
            local tutorial = readFile("src/Client/Systems/TutorialController.lua")
            expect(tracker:find('dock.Name = "QuestTrackerDock"', 1, true)).to.be.ok()
            expect(tracker:find("dock.AnchorPoint = Vector2.new(1, 0)", 1, true)).to.be.ok()
            expect(tracker:find("dock.Position = UDim2.fromScale(1, 0)", 1, true)).to.be.ok()
            expect(tracker:find("dock.Position = UDim2.new(", 1, true)).to.equal(nil)
            expect(tracker:find("pane.Parent = dock", 1, true)).to.be.ok()
            expect(tracker:find("pane.Position = UDim2.fromOffset(-4, 14)", 1, true)).to.be.ok()
            expect(tracker:find("pane.Size = UDim2.fromOffset(397, 40)", 1, true)).to.be.ok()
            expect(tracker:find("pane.ZIndex = 1", 1, true)).to.be.ok()
            expect(stack:find('WaitForChild("quest_tracker_pane"', 1, true)).to.equal(nil)
            expect(tutorial:find('SetAttribute("TutorialCornerOwned"', 1, true)).to.be.ok()
        end)

        it("keeps starter companion portraits visible when flat thumbnails fail", function()
            local client = readFile("src/Client/Systems/StarterPetController.lua")
            expect(client:find('viewport.Name = "PetModelFallback"', 1, true)).to.be.ok()
            expect(client:find("PetThumbnailFetchPolicy.action(status.Name)", 1, true)).to.be.ok()
            expect(client:find('family:WaitForChild("basic", 20)', 1, true)).to.be.ok()
            expect(client:find("ViewportModelPlacement.centerPreservingOrientation", 1, true)).to.be.ok()
        end)

        it("keeps every tutorial line at or above the mobile-readable type floor", function()
            local client = readFile("src/Client/Systems/TutorialController.lua")
            expect(client:find("capsule.Size = UDim2.fromOffset(420, 124)", 1, true)).to.be.ok()
            expect(client:find("stepLabel.TextSize = 18", 1, true)).to.be.ok()
            expect(client:find("titleLabel.TextSize = 20", 1, true)).to.be.ok()
            expect(client:find("bodyLabel.TextSize = 18", 1, true)).to.be.ok()
        end)

        it("renders the live breadcrumb as flowing 3D chevrons on a direct line", function()
            local client = readFile("src/Client/Systems/TutorialController.lua")
            local chevron = readFile("src/Client/UI/WorldChevron.lua")
            expect(client:find('name = "TutorialChevron"', 1, true)).to.be.ok()
            expect(client:find("WorldChevron.create", 1, true)).to.be.ok()
            expect(chevron:find('Instance.new("Highlight")', 1, true)).to.be.ok()
            expect(chevron:find('arm("LeftArm", leftTail)', 1, true)).to.be.ok()
            expect(chevron:find('arm("RightArm", rightTail)', 1, true)).to.be.ok()
            expect(client:find("local travel = (now * TRAIL_TRAVEL_SPEED)", 1, true)).to.be.ok()
            expect(client:find("local point = start:Lerp(target, alpha)", 1, true)).to.be.ok()
            expect(client:find("marker:PivotTo(", 1, true)).to.be.ok()
            expect(client:find("RunService.RenderStepped:Wait()", 1, true)).to.be.ok()
            expect(client:find("PathfindingService", 1, true)).to.equal(nil)
            expect(client:find("REPLAN_SECONDS", 1, true)).to.equal(nil)
            expect(client:find("Enum.PartType.Cylinder", 1, true)).to.equal(nil)
        end)

        it(
            "owns the upper-right player-list slot without becoming permanently dismissible",
            function()
                local client = readFile("src/Client/Systems/TutorialController.lua")
                expect(client:find('dock.Name = "TutorialDock"', 1, true)).to.be.ok()
                expect(client:find("dock.AnchorPoint = Vector2.new(1, 0)", 1, true)).to.be.ok()
                expect(client:find("dock.Position = UDim2.fromScale(1, 0)", 1, true)).to.be.ok()
                expect(client:find("dock.Position = UDim2.new(", 1, true)).to.equal(nil)
                expect(client:find("dock.Size = UDim2.fromOffset(0, 0)", 1, true)).to.be.ok()
                expect(client:find("capsule.AnchorPoint = Vector2.new(1, 0)", 1, true)).to.be.ok()
                expect(client:find("capsule.Position = UDim2.fromOffset(0, 0)", 1, true)).to.be.ok()
                expect(client:find("capsule.Parent = dock", 1, true)).to.be.ok()
                expect(client:find("gui.DisplayOrder = 110", 1, true)).to.be.ok()
                expect(client:find('GetAttribute("LargeMenuOpen") ~= true', 1, true)).to.be.ok()
                expect(client:find('GetAttributeChangedSignal("LargeMenuOpen")', 1, true)).to.be.ok()
                expect(client:find("capsule.Parent = stack", 1, true)).to.equal(nil)
                expect(client:find("PLAYER_LIST_PEEK_SECONDS = 10", 1, true)).to.be.ok()
                expect(client:find("playerListGuard:Suppress()", 1, true)).to.be.ok()
                expect(client:find("playerListGuard:Restore()", 1, true)).to.be.ok()
                expect(client:find('SetAttribute("PeopleListPeek"', 1, true)).to.be.ok()
                expect(client:find('peekButton.Name = "ShowPlayersTemporarily"', 1, true)).to.be.ok()
                expect(
                    client:find("peekButton.Activated:Connect(showPlayerListTemporarily)", 1, true)
                ).to.be.ok()
                expect(
                    client:find(
                        "playerListPeekConnection = RunService.Heartbeat:Connect(function()",
                        1,
                        true
                    )
                ).to.be.ok()
                expect(client:find('GetAttribute("LargeMenuOpen") == true', 1, true)).to.be.ok()
                expect(client:find("task.defer(syncCapsuleVisibility)", 1, true)).to.be.ok()

                local menus = readFile("src/Client/UI/MenuManager.lua")
                expect(menus:find('SetAttribute("LargeMenuOpen", hasPanel)', 1, true)).to.be.ok()
                expect(menus:find('SetAttribute("LargeMenuOpen", false)', 1, true)).to.be.ok()
            end
        )

        it("hands Combat Training to Quest behind a blocking Okay banner", function()
            local client = readFile("src/Client/Systems/TutorialController.lua")
            local server = readFile("src/Server/Services/TutorialService.lua")
            expect(client:find('handoffGui.Name = "TutorialHandoffGui"', 1, true)).to.be.ok()
            expect(client:find('laterBtn.Name = "Later"', 1, true)).to.be.ok()
            expect(client:find("Signals.TutorialCombatTrainingAck:FireServer()", 1, true)).to.be.ok()
            expect(client:find('SetAttribute("TutorialHandoffOpen", true)', 1, true)).to.be.ok()
            expect(server:find("Signals.TutorialCombatTrainingAck.OnServerEvent", 1, true)).to.be.ok()
            expect(server:find('fireGameEvent(player, "combat_training_quest_ack"', 1, true)).to.be.ok()
            expect(server:find("CombatTrainingQuestOffered", 1, true)).to.be.ok()
        end)
    end)

    describe("advance (the whole new-player path)", function()
        it("starts at step 1 (hatch first egg)", function()
            local step, idx = TutorialFlow.current(cfg, nil)
            expect(idx).to.equal(1)
            expect(step.id).to.equal("hatch_first_egg")
            expect(step.title).to.equal("Hatch your first egg")
            expect(step.body).to.equal(
                "Your companion needs a squadmate. Follow the trail to the Earth Egg and hatch one."
            )
        end)

        it("ignores non-matching events", function()
            local p, changed = TutorialFlow.advance(cfg, nil, "trade_complete")
            expect(changed).to.equal(false)
            expect(p.step).to.equal(1)
        end)

        it("accumulates COINS on the farm step (sum_ctx) — Jason's 100-coin gate", function()
            local p = feed(nil, { "egg_hatch" }) -- now on farm_crystals
            local step = TutorialFlow.current(cfg, p)
            expect(step.id).to.equal("farm_crystals")
            p = TutorialFlow.advance(cfg, p, "coin_payout", { amount = 40 })
            expect(p.count).to.equal(40) -- coins earned, not payout count
            expect(p.step).to.equal(2) -- still there
            p = TutorialFlow.advance(cfg, p, "coin_payout") -- amount-less payout: no credit
            expect(p.count).to.equal(40)
            p = feed(p, { { "coin_payout", { amount = 60 } } }) -- 100 total
            expect(TutorialFlow.current(cfg, p).id).to.equal("hatch_another")
            expect(p.count).to.equal(0) -- reset for the next step
        end)

        it("runs the full path to done", function()
            local p = feed(nil, {
                "egg_hatch", -- hatch_first_egg
                { "coin_payout", { amount = 60 } },
                { "coin_payout", { amount = 60 } }, -- farm_crystals (100 coins)
                "egg_hatch", -- hatch_another
                "tutorial_squad_reviewed", -- build_squad (unequip + equip + Activate)
                "tutorial_hotbar_finished", -- bind_power (Resonance bound, then Done pressed)
                "power_cast", -- cast_power
                "enhancement_slotted", -- slot_power
                "combat_training_quest_ack", -- first_fight (Quest handoff)
                "rally_used", -- rally_call (the flag at the top-left, slot 11) → done
            })
            expect(p.done).to.equal(true)
            expect(TutorialFlow.current(cfg, p)).to.equal(nil)
            -- further events are inert
            local p2, changed = TutorialFlow.advance(cfg, p, "egg_hatch")
            expect(changed).to.equal(false)
            expect(p2.done).to.equal(true)
        end)

        it("also lets finishing the Earth cave clear the Quest handoff", function()
            local p = feed(nil, {
                "egg_hatch",
                { "coin_payout", { amount = 100 } },
                "egg_hatch",
                "tutorial_squad_reviewed",
                "tutorial_hotbar_finished",
                "power_cast",
                "enhancement_slotted",
                "combat_tutorial_complete",
            })
            expect(TutorialFlow.current(cfg, p).id).to.equal("rally_call")
        end)

        it("egg_hatch does NOT skip the mining gate between two hatch steps", function()
            local p = feed(nil, { "egg_hatch", "egg_hatch", "egg_hatch" })
            expect(TutorialFlow.current(cfg, p).id).to.equal("farm_crystals")
        end)
    end)

    describe("resilience", function()
        it("migrates active progress through each tutorial reorder", function()
            local farm, changed = TutorialFlow.migrateProgress(cfg, {
                step = 3,
                count = 72,
                done = false,
            })
            expect(changed).to.equal(true)
            expect(farm.version).to.equal(6)
            expect(farm.step).to.equal(2)
            expect(farm.count).to.equal(72)

            local fighter = TutorialFlow.migrateProgress(cfg, {
                version = 1,
                step = 5,
                count = 0,
                done = false,
            })
            expect(fighter.version).to.equal(6)
            expect(fighter.step).to.equal(8) -- first_fight stays on the combat tail

            local binder = TutorialFlow.migrateProgress(cfg, {
                version = 2,
                step = 8,
                count = 0,
                done = false,
            })
            expect(binder.version).to.equal(6)
            expect(binder.step).to.equal(5) -- bind_power follows Resonance after squad

            local v3Binder = TutorialFlow.migrateProgress(cfg, {
                version = 3,
                step = 5,
                count = 0,
                done = false,
            })
            expect(v3Binder.version).to.equal(6)
            expect(v3Binder.step).to.equal(5)

            local v4Fighter = TutorialFlow.migrateProgress(cfg, {
                version = 4,
                step = 5,
                count = 0,
                done = false,
            })
            expect(v4Fighter.version).to.equal(6)
            expect(v4Fighter.step).to.equal(8)
        end)

        it(
            "grandfathers the old first-enemy beat and leaves pre-fight players on the new track",
            function()
                expect(TutorialFlow.startedFirstEnemy(3, 8, 1)).to.equal(true)
                expect(TutorialFlow.startedFirstEnemy(3, 8, 0)).to.equal(false)
                expect(TutorialFlow.startedFirstEnemy(2, 6, 0)).to.equal(true)
                expect(TutorialFlow.startedFirstEnemy(1, 5, 1)).to.equal(true)

                local mouth = TutorialFlow.migrateProgress(cfg, {
                    version = 5,
                    step = 8,
                    count = 0,
                    done = false,
                })
                expect(mouth.firstEnemy).to.equal(nil)
                local mouthDecision
                mouth, mouthDecision = TutorialFlow.reconcileGrandfather(cfg, mouth, {})
                expect(mouth.done).to.equal(false)
                expect(mouthDecision.unlockHeal).to.equal(false)
                expect(TutorialFlow.current(cfg, mouth).id).to.equal("first_fight")

                local v3Fight = TutorialFlow.migrateProgress(cfg, {
                    version = 3,
                    step = 8,
                    count = 1,
                    done = false,
                })
                expect(v3Fight.firstEnemy).to.equal(true)
                local v3Decision
                v3Fight, v3Decision = TutorialFlow.reconcileGrandfather(cfg, v3Fight, {})
                expect(v3Fight.done).to.equal(true)
                expect(v3Decision.unlockHeal).to.equal(true)

                local brewer = TutorialFlow.migrateProgress(cfg, {
                    version = 5,
                    step = 9,
                    count = 0,
                    done = false,
                })
                expect(brewer.firstEnemy).to.equal(true)
                expect(TutorialFlow.reconcileGrandfather(cfg, brewer, {}).done).to.equal(true)

                local remapped, remappedDecision = TutorialFlow.reconcileGrandfather(cfg, {
                    version = 6,
                    step = 8,
                    count = 0,
                    done = false,
                }, { tutorialFirstFight = true })
                expect(remapped.done).to.equal(false)
                expect(remappedDecision.unlockHeal).to.equal(false)

                local strayKills, strayDecision = TutorialFlow.reconcileGrandfather(cfg, {
                    version = 6,
                    step = 8,
                    count = 0,
                    done = false,
                }, { enemiesDefeated = 23 })
                expect(strayKills.done).to.equal(false)
                expect(strayDecision.unlockHeal).to.equal(false)

                local finished, finishedDecision = TutorialFlow.reconcileGrandfather(cfg, {
                    version = 6,
                    step = 1,
                    done = true,
                }, {})
                expect(finished.done).to.equal(true)
                expect(finishedDecision.completeTutorial).to.equal(false)
                expect(finishedDecision.unlockHeal).to.equal(true)

                local inNewTrack, inNewDecision = TutorialFlow.reconcileGrandfather(cfg, {
                    version = 6,
                    step = 8,
                    count = 0,
                    done = false,
                }, {
                    combatTutorial = { version = 1, step = 4 },
                    enemiesDefeated = 2,
                })
                expect(inNewTrack.done).to.equal(false)
                expect(inNewDecision.unlockHeal).to.equal(false)

                local beforeFight, beforeDecision = TutorialFlow.reconcileGrandfather(cfg, {
                    version = 6,
                    step = 5,
                    count = 0,
                    done = false,
                }, {})
                expect(beforeFight.done).to.equal(false)
                expect(beforeDecision.unlockHeal).to.equal(false)
                expect(TutorialFlow.current(cfg, beforeFight).id).to.equal("bind_power")
            end
        )

        it("treats ready/brew/bind as lobby and fights/pillars as not", function()
            local combat = loadModule("configs/combat_tutorial.lua")
            expect(TutorialFlow.isCombatLobbyStep(combat.steps[1])).to.equal(true)
            expect(TutorialFlow.isCombatLobbyStep(combat.steps[2])).to.equal(false)
            expect(TutorialFlow.isCombatLobbyStep(combat.steps[3])).to.equal(false)
            expect(TutorialFlow.isCombatLobbyStep(combat.steps[4])).to.equal(true)
            expect(TutorialFlow.isCombatLobbyStep(nil)).to.equal(false)
        end)

        it("asks to redo the cave only after combat training itself is done", function()
            expect(TutorialFlow.caveEnterNeedsConfirm({ done = false }, nil, {})).to.equal(false)
            expect(TutorialFlow.caveEnterNeedsConfirm({
                done = false,
                step = 8,
            }, { version = 10, step = 4, done = false }, {})).to.equal(false)
            expect(TutorialFlow.caveEnterNeedsConfirm({ done = true }, nil, {})).to.equal(false)
            expect(TutorialFlow.caveEnterNeedsConfirm({ done = false }, nil, {
                TutorialCompleted = true,
            })).to.equal(false)
            expect(TutorialFlow.caveEnterNeedsConfirm({ done = true }, {
                version = 10,
                step = 1,
                done = true,
            }, {})).to.equal(true)
            expect(TutorialFlow.caveEnterNeedsConfirm({ done = true }, {
                version = 10,
                step = 12,
                done = false,
            }, {})).to.equal(false)
        end)

        it("normalizes nil/corrupt progress", function()
            local p = TutorialFlow.normalizeProgress({ step = "x", count = -5 })
            expect(p.step).to.equal(1)
            expect(p.count).to.equal(0)
            expect(p.done).to.equal(false)
            expect(p.track).to.equal(nil)
        end)

        it("does not put new Homeworld records on the retired Hall track", function()
            expect(cfg.hall_track).to.equal(nil)
            local fresh = TutorialFlow.fresh(cfg)
            expect(fresh.track).to.equal(nil)
            -- Existing track metadata remains readable so the rollback is data-preserving.
            local kept = TutorialFlow.normalizeProgress({ step = 1, track = 2 })
            expect(kept.track).to.equal(2)
            local migrated = TutorialFlow.migrateProgress(cfg, { version = 2, step = 1 })
            expect(migrated.track).to.equal(nil)
        end)

        it("step index past the end (config shrank) reads as done", function()
            local p = { step = #cfg.steps + 5, count = 0, done = false }
            expect(TutorialFlow.current(cfg, p)).to.equal(nil)
            local p2, changed = TutorialFlow.advance(cfg, p, "egg_hatch")
            expect(p2.done).to.equal(true)
            expect(changed).to.equal(true)
        end)
    end)

    describe("veteran skip", function()
        it("level or pets short-circuits the tutorial", function()
            expect(TutorialFlow.isVeteran(cfg, 12, false)).to.equal(true)
            expect(TutorialFlow.isVeteran(cfg, 0, true)).to.equal(true)
            expect(TutorialFlow.isVeteran(cfg, 1, false)).to.equal(false)
        end)
    end)

    describe("stateFor (the wire view)", function()
        it("active step view carries index/total/target/count", function()
            local p = feed(nil, { "egg_hatch", { "coin_payout", { amount = 40 } } })
            local s = TutorialFlow.stateFor(cfg, p)
            expect(s.done).to.equal(false)
            expect(s.id).to.equal("farm_crystals")
            expect(s.index).to.equal(2)
            expect(s.total).to.equal(#cfg.steps)
            expect(s.count).to.equal(40)
            expect(s.need).to.equal(100)
            expect(s.target.kind).to.equal("crystal") -- farm step trails to a small crystal
        end)

        it("done view is minimal", function()
            expect(TutorialFlow.stateFor(cfg, { step = 1, count = 0, done = true }).done).to.equal(
                true
            )
        end)

        it("uses contextual squad-review copy without changing progression", function()
            local p = { version = 2, step = 4, count = 0, done = false }
            local full = TutorialFlow.stateFor(cfg, p, { hasUnequippedPets = false })
            local alternatives = TutorialFlow.stateFor(cfg, p, { hasUnequippedPets = true })
            expect(string.find(full.body, "equipped squad", 1, true) ~= nil).to.equal(true)
            expect(string.find(alternatives.body, "Rainbow Kitty", 1, true) ~= nil).to.equal(true)
            expect(alternatives.id).to.equal("build_squad")
        end)
    end)
end
