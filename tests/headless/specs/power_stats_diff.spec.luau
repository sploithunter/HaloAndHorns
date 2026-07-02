--[[
    PowerStatsDiff.diff — [unit] which axes shift between two resolveEffective outputs.
    Pairs with PowerStats.resolveEffective: the strip resolves a power twice (committed vs
    committed+staged) and diff() names the changed lines for the preview.
    Run: mise run test-headless
]]

local PowerStats = loadModule("src/Shared/Game/PowerStats.lua")
local PowerStatsDiff = loadModule("src/Shared/Game/PowerStatsDiff.lua")

local function approx(a, b)
    return type(a) == "number" and math.abs(a - b) < 1e-9
end

local function byAxis(rows)
    local out = {}
    for _, r in ipairs(rows) do
        out[r.axis] = r
    end
    return out
end

return function()
    describe("PowerStatsDiff.diff — only changed axes, in display order", function()
        it("reports nothing when the two stat sets match", function()
            local eff = { recharge = 10, damage = 100 }
            expect(#PowerStatsDiff.diff(eff, eff)).to.equal(0)
        end)

        it("surfaces a recharge drop as an improvement (lower is better)", function()
            local rows = PowerStatsDiff.diff({ recharge = 10 }, { recharge = 8 })
            expect(#rows).to.equal(1)
            local r = rows[1]
            expect(r.axis).to.equal("recharge")
            expect(r.label).to.equal("Recharge")
            expect(r.from).to.equal(10)
            expect(r.to).to.equal(8)
            expect(r.lowerBetter).to.equal(true)
            expect(r.improved).to.equal(true)
            expect(approx(r.deltaPct, -0.2)).to.equal(true) -- 10 → 8 = −20%
        end)

        it("surfaces a damage gain as an improvement (higher is better)", function()
            local r = PowerStatsDiff.diff({ damage = 120 }, { damage = 138 })[1]
            expect(r.axis).to.equal("damage")
            expect(r.improved).to.equal(true)
            expect(approx(r.deltaPct, 0.15)).to.equal(true) -- +15%
        end)

        it("flags a regression (a recharge that grew) as not improved", function()
            local r = PowerStatsDiff.diff({ recharge = 8 }, { recharge = 10 })[1]
            expect(r.improved).to.equal(false)
        end)

        it("ignores sub-EPS float wobble (e.g. a clamped axis)", function()
            local rows = PowerStatsDiff.diff({ accuracy = 0.95 }, { accuracy = 0.9500001 })
            expect(#rows).to.equal(0)
        end)

        it("leaves deltaPct nil when there is no baseline (from == 0)", function()
            local r = PowerStatsDiff.diff({ damage = 0 }, { damage = 50 })[1]
            expect(r.from).to.equal(0)
            expect(r.to).to.equal(50)
            expect(r.deltaPct).to.equal(nil)
        end)

        it("returns multiple changed axes in AXES order (recharge before damage)", function()
            local rows = PowerStatsDiff.diff(
                { recharge = 10, damage = 100 },
                { recharge = 8, damage = 133 }
            )
            expect(#rows).to.equal(2)
            expect(rows[1].axis).to.equal("recharge")
            expect(rows[2].axis).to.equal("damage")
        end)
    end)

    describe("PowerStatsDiff.diff — wired to a real resolveEffective pair", function()
        -- a power with a 10s cooldown + 120 base DoT; stage a +20% recharge enhancement
        local record = { kind = { "aoe", "dot" }, rechargeBase = 10, damageBase = 120 }
        local current = PowerStats.resolveEffective(record, { casterLevel = 10 })
        local projected = PowerStats.resolveEffective(record, {
            casterLevel = 10,
            enhancements = { recharge = 0.25 }, -- 10 / 1.25 = 8.0s
        })

        it("recharge enhancement shortens recharge only, leaving damage untouched", function()
            local rows = byAxis(PowerStatsDiff.diff(current, projected))
            expect(rows.recharge).to.be.ok()
            expect(approx(rows.recharge.to, 8)).to.equal(true)
            expect(rows.recharge.improved).to.equal(true)
            expect(rows.damage).to.equal(nil) -- damage axis unchanged ⇒ no row
        end)
    end)
end
