local HatchViewportReadiness = loadModule("src/Shared/Game/HatchViewportReadiness.lua")

return function()
    describe("HatchViewportReadiness", function()
        it("rejects a usable but transient first-session width", function()
            local policy = HatchViewportReadiness.resolvePolicy({
                stable_frames = 3,
                max_wait_frames = 30,
                min_width = 320,
                min_height = 240,
                size_tolerance = 1,
            })
            local state = HatchViewportReadiness.newState()

            expect(HatchViewportReadiness.observe(state, 684, 696, policy)).to.equal(false)
            expect(HatchViewportReadiness.observe(state, 1468, 696, policy)).to.equal(false)
            expect(HatchViewportReadiness.observe(state, 1468, 696, policy)).to.equal(false)
            expect(HatchViewportReadiness.observe(state, 1468, 696, policy)).to.equal(true)
        end)

        it("resets stability when the rendered bounds change", function()
            local policy = HatchViewportReadiness.resolvePolicy({ stable_frames = 2 })
            local state = HatchViewportReadiness.newState()

            expect(HatchViewportReadiness.observe(state, 1280, 720, policy)).to.equal(false)
            expect(HatchViewportReadiness.observe(state, 900, 600, policy)).to.equal(false)
            expect(HatchViewportReadiness.observe(state, 900, 600, policy)).to.equal(true)
        end)

        it("never accepts bootstrap-sized GUI geometry", function()
            local policy = HatchViewportReadiness.resolvePolicy({ stable_frames = 2 })
            local state = HatchViewportReadiness.newState()

            expect(HatchViewportReadiness.observe(state, 1, 1, policy)).to.equal(false)
            expect(HatchViewportReadiness.observe(state, 1, 1, policy)).to.equal(false)
            expect(state.stableFrames).to.equal(0)
        end)
    end)
end
