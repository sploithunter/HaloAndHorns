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

        it("wires a retryable, once-only level guarantee to genuine completion", function()
            local source = readFile("src/Server/Services/TutorialService.lua")
            expect(source:find("data.Tutorial.completionLevelTarget = target", 1, true)).to.be.ok()
            expect(source:find("progression:EnsureEarnedLevel(player, target)", 1, true)).to.be.ok()
            expect(source:find("tutorial.completionLevelGranted = true", 1, true)).to.be.ok()
            expect(source:find('fireGameEvent(player, "tutorial_level_awarded"', 1, true)).to.be.ok()
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
            expect(client:find("self:_commitDraft(closeAndReport)", 1, true)).to.be.ok()
            expect(client:find('FireServer("reviewed")', 1, true)).to.be.ok()
        end)

        it("makes the battle brew's exact hotbar slot impossible to miss", function()
            local battleBrew
            for _, step in ipairs(cfg.steps) do
                if step.id == "battle_brew" then
                    battleBrew = step
                    break
                end
            end
            expect(battleBrew).to.be.ok()
            expect(battleBrew.target.name).to.equal(nil)
            expect(battleBrew.target.hotbar_type).to.equal("potion")
            expect(battleBrew.target.hotbar_target).to.equal("berserk_brew")
            expect(battleBrew.target.cue).to.equal("click")
            expect(battleBrew.target.cue_text).to.equal("CLICK HERE")

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

        it("keeps starter companion portraits visible when flat thumbnails fail", function()
            local client = readFile("src/Client/Systems/StarterPetController.lua")
            expect(client:find('viewport.Name = "PetModelFallback"', 1, true)).to.be.ok()
            expect(client:find("PetThumbnailFetchPolicy.action(status.Name)", 1, true)).to.be.ok()
            expect(client:find('family:WaitForChild("basic", 20)', 1, true)).to.be.ok()
            expect(client:find("ViewportModelPlacement.centerPreservingOrientation", 1, true)).to.be.ok()
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
                "tutorial_squad_reviewed", -- build_squad (Pets panel reviewed + server commit)
                "enemy_defeated", -- first_fight (the Earth-cave onramp creature)
                "potion_used", -- battle_brew (drink from the top-right slot)
                "rally_used", -- rally_call (the flag at the top-left, slot 11)
                "power_bound", -- bind_power (Resonance onto the bar)
                "power_cast", -- cast_power
                "enhancement_slotted", -- slot_power → done
            })
            expect(p.done).to.equal(true)
            expect(TutorialFlow.current(cfg, p)).to.equal(nil)
            -- further events are inert
            local p2, changed = TutorialFlow.advance(cfg, p, "egg_hatch")
            expect(changed).to.equal(false)
            expect(p2.done).to.equal(true)
        end)

        it("egg_hatch does NOT skip the mining gate between two hatch steps", function()
            local p = feed(nil, { "egg_hatch", "egg_hatch", "egg_hatch" })
            expect(TutorialFlow.current(cfg, p).id).to.equal("farm_crystals")
        end)
    end)

    describe("resilience", function()
        it("migrates active v1 progress through the reordered steps", function()
            local farm, changed = TutorialFlow.migrateProgress(cfg, {
                step = 3,
                count = 72,
                done = false,
            })
            expect(changed).to.equal(true)
            expect(farm.version).to.equal(2)
            expect(farm.step).to.equal(2)
            expect(farm.count).to.equal(72)

            local fighter = TutorialFlow.migrateProgress(cfg, {
                version = 1,
                step = 5,
                count = 0,
                done = false,
            })
            expect(fighter.step).to.equal(5) -- does not force the new review on past players
        end)

        it("normalizes nil/corrupt progress", function()
            local p = TutorialFlow.normalizeProgress({ step = "x", count = -5 })
            expect(p.step).to.equal(1)
            expect(p.count).to.equal(0)
            expect(p.done).to.equal(false)
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
            expect(string.find(full.body, "take a look", 1, true) ~= nil).to.equal(true)
            expect(string.find(alternatives.body, "more pets to choose from", 1, true) ~= nil).to.equal(
                true
            )
            expect(alternatives.id).to.equal("build_squad")
        end)
    end)
end
