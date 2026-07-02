--[[
    RealmTheme — [unit] depth-scaled realm atmosphere blending (World S3 A1).
    Run: mise run test-headless
]]

local RealmTheme = loadModule("src/Shared/Game/RealmTheme.lua")

return function()
    describe("RealmTheme.depthOf / realmOf", function()
        it("base = depth 0, no realm", function()
            expect(RealmTheme.depthOf("base")).to.equal(0)
            expect(RealmTheme.realmOf("base")).to.equal(nil)
        end)
        it("parses depth + realm from a layer id", function()
            expect(RealmTheme.depthOf("hell_3")).to.equal(3)
            expect(RealmTheme.realmOf("hell_3")).to.equal("hell")
            expect(RealmTheme.realmOf("heaven_5")).to.equal("heaven")
        end)
    end)

    describe("RealmTheme.progress", function()
        it("0 at base, faint at depth 1, full at max depth", function()
            expect(RealmTheme.progress("base", 5)).to.equal(0)
            expect(RealmTheme.progress("hell_1", 5)).to.near(0.2, 1e-9)
            expect(RealmTheme.progress("hell_5", 5)).to.equal(1)
        end)
        it("clamps past the max depth", function()
            expect(RealmTheme.progress("hell_9", 5)).to.equal(1)
        end)
    end)

    describe("RealmTheme.interpolate", function()
        it("lerps numbers", function()
            local r = RealmTheme.interpolate({ brightness = 0 }, { brightness = 1 }, 0.25)
            expect(r.brightness).to.near(0.25, 1e-9)
        end)
        it("lerps numeric arrays (colors) per-component", function()
            local r = RealmTheme.interpolate(
                { tint = { 0, 0, 0 } },
                { tint = { 1, 0.5, 0.2 } },
                0.5
            )
            expect(r.tint[1]).to.near(0.5, 1e-9)
            expect(r.tint[2]).to.near(0.25, 1e-9)
            expect(r.tint[3]).to.near(0.1, 1e-9)
        end)
        it("recurses into nested tables (atmosphere)", function()
            local a = { atmosphere = { density = 0, color = { 0, 0, 0 } } }
            local b = { atmosphere = { density = 0.5, color = { 100, 50, 0 } } }
            local r = RealmTheme.interpolate(a, b, 0.5)
            expect(r.atmosphere.density).to.near(0.25, 1e-9)
            expect(r.atmosphere.color[1]).to.near(50, 1e-9)
        end)
        it("t=0 returns the base anchor, t=1 the deep anchor", function()
            local base = { brightness = 0, tint = { 1, 1, 1 } }
            local deep = { brightness = -0.5, tint = { 1, 0.4, 0.3 } }
            local at0 = RealmTheme.interpolate(base, deep, 0)
            local at1 = RealmTheme.interpolate(base, deep, 1)
            expect(at0.brightness).to.near(0, 1e-9)
            expect(at1.brightness).to.near(-0.5, 1e-9)
            expect(at1.tint[2]).to.near(0.4, 1e-9)
        end)
    end)
end
