local Timeline = loadModule("src/Shared/Effects/CrystalTimeline.lua")
local Preset = loadModule("configs/vfx/crystal_eruption.lua")

return function()
    describe("Crystal eruption timeline", function()
        it("has no visible crystals during anticipation and fully fades by its deadline", function()
            for _, fraction in ipairs({ 0, 0.4, 1 }) do
                local growth = Timeline.crystal(Preset, 0, fraction)
                expect(growth).to.equal(0)
                local _, fade = Timeline.crystal(Preset, Timeline.duration(Preset), fraction)
                expect(fade).to.near(1)
            end
        end)
        it("ripples outward and supports frame independent backward seeking", function()
            local time = Preset.anticipation + Preset.stagger / 2
            local inner = Timeline.crystal(Preset, time, 0)
            local outer = Timeline.crystal(Preset, time, 1)
            expect(inner > outer).to.equal(true)
            Timeline.crystal(Preset, Timeline.duration(Preset), 0)
            expect(Timeline.crystal(Preset, time, 0)).to.equal(inner)
        end)
        it("re-evaluates timing edits against the same paused time", function()
            local p = table.clone(Preset)
            local time = p.anticipation + p.rise / 2
            local before = Timeline.crystal(p, time, 0)
            p.rise *= 2
            expect(Timeline.crystal(p, time, 0) < before).to.equal(true)
        end)
        it("produces stable normalized shape randomness", function()
            for i = 1, 40 do
                local n = Timeline.random(Preset.seed, i, 1)
                expect(n >= 0 and n < 1).to.equal(true)
                expect(Timeline.random(Preset.seed, i, 1)).to.equal(n)
            end
        end)
        it("rejects nonfinite, unknown, fractional count, and malformed color values", function()
            local schema = {
                version = 1,
                numbers = { { key = "count", min = 3, max = 40, step = 1 } },
                colors = { { key = "primary" } },
            }
            local p = { version = 1, count = 5, primary = { 100, 150, 255 } }
            expect(Timeline.validate(p, schema)).to.equal(true)
            p.count = 0 / 0
            expect(Timeline.validate(p, schema)).to.equal(false)
            p.count = math.huge
            expect(Timeline.validate(p, schema)).to.equal(false)
            p.count = 5.5
            expect(Timeline.validate(p, schema)).to.equal(false)
            p.count = 5
            p.primary = { 100, 150, 255, 20 }
            expect(Timeline.validate(p, schema)).to.equal(false)
            p.primary = { 100, 150, 255 }
            p.path = "elsewhere.lua"
            expect(Timeline.validate(p, schema)).to.equal(false)
        end)
    end)
end
