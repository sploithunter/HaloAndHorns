local Budget = loadModule("src/Shared/Game/PetPresentationBudget.lua")
local config = loadModule("configs/pet_follow.lua").npc_presentation

return function()
    describe("NPC observer presentation budget", function()
        it("keeps nearby squads at full frame rate", function()
            local run, elapsed, motionDt = Budget.step(0, 0.02, true, config)
            expect(run).to.equal(true)
            expect(elapsed).to.equal(0)
            expect(motionDt).to.equal(0.02)
        end)

        it("reduces distant updates without losing elapsed movement time", function()
            local elapsed, updates, simulated = 0, 0, 0
            for _ = 1, 500 do
                local run, pending, motionDt = Budget.step(elapsed, 0.02, false, config)
                elapsed = pending
                if run then
                    updates += 1
                    simulated += motionDt
                end
            end
            expect(updates).to.equal(100)
            expect(simulated + elapsed).to.near(10, 1e-6)
        end)

        it("flushes pending motion immediately on approaching a squad", function()
            local run, elapsed, motionDt = Budget.step(0.06, 0.02, true, config)
            expect(run).to.equal(true)
            expect(elapsed).to.equal(0)
            expect(motionDt).to.near(0.08, 1e-6)
        end)

        it("supports legacy config and explicit full-rate rollback", function()
            for _, cfg in ipairs({ {}, { enabled = false } }) do
                local run, elapsed, motionDt = Budget.step(0.06, 0.02, false, cfg)
                expect(run).to.equal(true)
                expect(elapsed).to.equal(0)
                expect(motionDt).to.near(0.08, 1e-6)
            end
            expect(Budget.step(0, 0.02, false, nil)).to.equal(true)
        end)

        it("does not subdivide a slow frame into a catch-up burst", function()
            local run, elapsed, motionDt = Budget.step(0.06, 0.2, false, config)
            expect(run).to.equal(true)
            expect(elapsed).to.equal(0)
            expect(motionDt).to.near(0.26, 1e-6)
        end)

        it("has a finite positive configured radius and interval", function()
            expect(config.full_rate_radius > 0 and config.full_rate_radius < math.huge).to.equal(
                true
            )
            expect(config.distant_interval > 0 and config.distant_interval < math.huge).to.equal(
                true
            )
        end)
    end)
end
