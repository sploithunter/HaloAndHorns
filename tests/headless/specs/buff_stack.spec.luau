--[[
    BuffStack — additive-on-base stacking [unit] tests.
    Run: mise run test-headless  (or mise run ci)
]]

local BuffStack = loadModule("src/Shared/Game/BuffStack.lua")
local buffsCfg = loadModule("configs/buffs.lua")

local NOW = 1000

return function()
    describe("BuffStack.sum", function()
        it("sums all live source fractions", function()
            local s = BuffStack.sum({
                { fraction = 0.25, expiry = 2000 },
                { fraction = 0.25, expiry = 2000 },
            }, NOW)
            expect(s).to.near(0.50, 1e-9)
        end)

        it("ignores expired sources", function()
            local s = BuffStack.sum({
                { fraction = 0.25, expiry = 2000 }, -- live
                { fraction = 1.00, expiry = 500 }, -- expired (< NOW)
            }, NOW)
            expect(s).to.near(0.25, 1e-9)
        end)

        it("counts permanent sources (no expiry) as always live", function()
            local s = BuffStack.sum({
                { fraction = 0.10 }, -- permanent
                { fraction = 0.20, expiry = 2000 },
            }, NOW)
            expect(s).to.near(0.30, 1e-9)
        end)

        it("is zero for an empty / all-expired list", function()
            expect(BuffStack.sum({}, NOW)).to.equal(0)
            expect(BuffStack.sum({ { fraction = 0.5, expiry = 10 } }, NOW)).to.equal(0)
        end)
    end)

    describe("BuffStack.multiplier (additive on base 1.0)", function()
        it("one +25% source = x1.25", function()
            expect(BuffStack.multiplier({ { fraction = 0.25 } }, NOW)).to.near(1.25, 1e-9)
        end)

        it("two +25% sources ADD to x1.50 (NOT x1.5625 compounding)", function()
            local m = BuffStack.multiplier({ { fraction = 0.25 }, { fraction = 0.25 } }, NOW)
            expect(m).to.near(1.50, 1e-9)
        end)

        it("ten +25% sources = +250% = x3.5 (linear, not x9.3)", function()
            local sources = {}
            for _ = 1, 10 do
                sources[#sources + 1] = { fraction = 0.25 }
            end
            expect(BuffStack.multiplier(sources, NOW)).to.near(3.5, 1e-9)
        end)

        it("clamps the summed fraction to the axis cap", function()
            -- cap 3.0 (+300%): sources summing to +400% clamp to +300% => x4.0
            local sources = {}
            for _ = 1, 8 do
                sources[#sources + 1] = { fraction = 0.5 } -- 8 x 0.5 = 4.0
            end
            local m = BuffStack.multiplier(sources, NOW, { cap = 3.0 })
            expect(m).to.near(4.0, 1e-9)
        end)
    end)

    describe("BuffStack.withGlobals / resolve (the only multiplicative step)", function()
        it("global multipliers multiply the axis result", function()
            -- axis x1.40, then a 2x gamepass global => x2.80
            expect(BuffStack.withGlobals(1.40, { 2.0 })).to.near(2.80, 1e-9)
        end)

        it("worked luck example: Fortune 0.25 + aura 0.15 + 2x global = x2.80", function()
            local sources = {
                { fraction = 0.25 }, -- Fortune
                { fraction = 0.15 }, -- lucky pet aura
            }
            local m = BuffStack.resolve(sources, NOW, buffsCfg.axes.luck, { 2.0 })
            expect(m).to.near(2.80, 1e-9)
        end)

        it("+ Huge Fortune (0.50) stays linear: x3.80 (never x1000)", function()
            local sources = {
                { fraction = 0.25 }, -- Fortune
                { fraction = 0.15 }, -- aura
                { fraction = 0.50 }, -- Huge Fortune
            }
            local m = BuffStack.resolve(sources, NOW, buffsCfg.axes.luck, { 2.0 })
            expect(m).to.near(3.80, 1e-9)
        end)
    end)

    describe("BuffStack.isActive / prune", function()
        it("isActive is true if any source is live", function()
            expect(
                BuffStack.isActive(
                    { { fraction = 1, expiry = 10 }, { fraction = 1, expiry = 2000 } },
                    NOW
                )
            ).to.equal(true)
        end)

        it("isActive is false if all expired", function()
            expect(
                BuffStack.isActive(
                    { { fraction = 1, expiry = 10 }, { fraction = 1, expiry = 20 } },
                    NOW
                )
            ).to.equal(false)
        end)

        it("prune drops expired, keeps live + permanent", function()
            local kept = BuffStack.prune({
                { fraction = 0.1, expiry = 2000 }, -- live
                { fraction = 0.2, expiry = 10 }, -- expired
                { fraction = 0.3 }, -- permanent
            }, NOW)
            expect(#kept).to.equal(2)
        end)
    end)

    describe("configs/buffs.lua", function()
        it("defines axis caps + a default", function()
            expect(buffsCfg.axes.luck.cap).to.equal(3.0)
            expect(buffsCfg.default_cap).to.a("number")
        end)
    end)
end
