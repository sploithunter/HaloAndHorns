local AmbientFaunaMotion = loadModule("src/Shared/Game/AmbientFaunaMotion.lua")

return function()
    describe("AmbientFaunaMotion.sample", function()
        it("keeps motion on the configured circular radius", function()
            local spec = { radius = 3, speed = 0.7, phase = 0.3 }
            for _, time in ipairs({ 0, 1, 7.5 }) do
                local sample = AmbientFaunaMotion.sample("ground", time, spec)
                local radius = math.sqrt(sample.x * sample.x + sample.z * sample.z)
                expect(math.abs(radius - 3) < 0.0001).to.equal(true)
            end
        end)

        it("adds hover height only to hovering fauna", function()
            local spec = { hover_height = 2.5, bob_height = 0, radius = 0 }
            expect(AmbientFaunaMotion.sample("hover", 0, spec).y).to.equal(2.5)
            expect(AmbientFaunaMotion.sample("ground", 0, spec).y).to.equal(0)
        end)

        it("is deterministic for a shared time and phase", function()
            local spec = { radius = 2, speed = 0.4, phase = 1.2, bob_height = 0.3 }
            local first = AmbientFaunaMotion.sample("hover", 9, spec)
            local second = AmbientFaunaMotion.sample("hover", 9, spec)
            expect(second.x).to.equal(first.x)
            expect(second.y).to.equal(first.y)
            expect(second.z).to.equal(first.z)
            expect(second.yaw).to.equal(first.yaw)
        end)
    end)
end
