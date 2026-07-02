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
            expect(type(cfg.completion)).to.equal("table") -- the QUESTS UNLOCKED card
            for _, step in ipairs(cfg.steps) do
                expect(type(step.id)).to.equal("string")
                expect(type(step.title)).to.equal("string")
                expect(type(step.complete_on.event)).to.equal("string")
            end
        end)
    end)

    describe("advance (the whole new-player path)", function()
        it("starts at step 1 (hatch first egg)", function()
            local step, idx = TutorialFlow.current(cfg, nil)
            expect(idx).to.equal(1)
            expect(step.id).to.equal("hatch_first_egg")
        end)

        it("ignores non-matching events", function()
            local p, changed = TutorialFlow.advance(cfg, nil, "trade_complete")
            expect(changed).to.equal(false)
            expect(p.step).to.equal(1)
        end)

        it("accumulates COINS on the farm step (sum_ctx) — Jason's 100-coin gate", function()
            local p = feed(nil, { "egg_hatch", "pet_equipped" }) -- now on farm_crystals
            local step = TutorialFlow.current(cfg, p)
            expect(step.id).to.equal("farm_crystals")
            p = TutorialFlow.advance(cfg, p, "coin_payout", { amount = 40 })
            expect(p.count).to.equal(40) -- coins earned, not payout count
            expect(p.step).to.equal(3) -- still there
            p = TutorialFlow.advance(cfg, p, "coin_payout") -- amount-less payout: no credit
            expect(p.count).to.equal(40)
            p = feed(p, { { "coin_payout", { amount = 60 } } }) -- 100 total
            expect(TutorialFlow.current(cfg, p).id).to.equal("hatch_another")
            expect(p.count).to.equal(0) -- reset for the next step
        end)

        it("runs the full path to done", function()
            local p = feed(nil, {
                "egg_hatch", -- hatch_first_egg
                "pet_equipped", -- equip_pet (Activate commit)
                { "coin_payout", { amount = 60 } },
                { "coin_payout", { amount = 60 } }, -- farm_crystals (100 coins)
                "egg_hatch", -- hatch_another
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

        it("egg_hatch does NOT skip two egg steps at once (different positions)", function()
            local p = feed(nil, { "egg_hatch", "egg_hatch", "egg_hatch" })
            -- only step 1 consumed the first; the others hit equip_pet and were ignored
            expect(TutorialFlow.current(cfg, p).id).to.equal("equip_pet")
        end)
    end)

    describe("resilience", function()
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
            local p = feed(nil, { "egg_hatch", "pet_equipped", { "coin_payout", { amount = 40 } } })
            local s = TutorialFlow.stateFor(cfg, p)
            expect(s.done).to.equal(false)
            expect(s.id).to.equal("farm_crystals")
            expect(s.index).to.equal(3)
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
    end)
end
