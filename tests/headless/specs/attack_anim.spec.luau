--[[
    Procedural attack-flourish (mining spin / melee pounce): style shapes, config resolve,
    time-driven advance. Companion to gait.spec. Run: mise run test-headless
]]

local AttackAnim = loadModule("src/Shared/Game/AttackAnim.lua")

local PI = math.pi

return function()
    describe("AttackAnim.resolve", function()
        it("nil / 'none' resolves disabled (no-op)", function()
            local a = AttackAnim.resolve(nil)
            expect(a.enabled).to.equal(false)
            expect(a.style).to.equal("none")
            local b = AttackAnim.resolve({ style = "none" })
            expect(b.enabled).to.equal(false)
        end)

        it("spin resolves enabled with its style fn + speed", function()
            local a = AttackAnim.resolve({ style = "spin", spin_speed = 9 })
            expect(a.enabled).to.equal(true)
            expect(a.spinSpeed).to.near(9, 1e-6)
            expect(a.fn).to.equal(AttackAnim.STYLES.spin)
        end)

        it("falls back to none for an unknown style", function()
            local a = AttackAnim.resolve({ style = "nonsense" })
            expect(a.enabled).to.equal(false)
            expect(a.fn).to.equal(AttackAnim.STYLES.none)
        end)
    end)

    describe("AttackAnim.STYLES", function()
        it("spin: yaw grows with time, lunge stays zero", function()
            local a = AttackAnim.resolve({ style = "spin", spin_speed = 4 })
            local y1, lunge1 = AttackAnim.STYLES.spin(0.1, a)
            local y2 = AttackAnim.STYLES.spin(0.2, a)
            expect(lunge1).to.equal(0)
            expect(y2 > y1).to.equal(true)
        end)

        it("pounce: 0 lunge at phase start, peaks mid-period, no yaw", function()
            local a = AttackAnim.resolve({ style = "pounce", pounce_depth = 3, pounce_period = 1 })
            local yaw0, lunge0 = AttackAnim.STYLES.pounce(0, a)
            expect(yaw0).to.equal(0)
            expect(lunge0).to.near(0, 1e-6)
            local _, lungeMid = AttackAnim.STYLES.pounce(0.5, a) -- mid-period -> full depth
            expect(lungeMid).to.near(3, 1e-6)
        end)

        it("peck: dips downward (bobN <= 0), no yaw or lunge", function()
            local a = AttackAnim.resolve({ style = "peck", peck_speed = 6 })
            local yaw, lunge, bobN = AttackAnim.STYLES.peck(0.25, a)
            expect(yaw).to.equal(0)
            expect(lunge).to.equal(0)
            expect(bobN <= 0).to.equal(true)
        end)

        it("none is always zero", function()
            local y, l, b = AttackAnim.STYLES.none(1.23, {})
            expect(y).to.equal(0)
            expect(l).to.equal(0)
            expect(b).to.equal(0)
        end)
    end)

    describe("AttackAnim.advance", function()
        it("accumulates t and scales bob by bobHeight", function()
            local a = AttackAnim.resolve({ style = "spin", spin_speed = 2, bob_height = 0.5 })
            local st = {}
            local _, _, bob = AttackAnim.advance(st, a, 1 / 60)
            expect(st.t).to.near(1 / 60, 1e-6)
            -- bob is bobHeight * |sin(...)| in [0, 0.5]
            expect(bob >= 0 and bob <= 0.5).to.equal(true)
        end)

        it("disabled anim returns zeros but still ticks t", function()
            local a = AttackAnim.resolve({ style = "none" })
            local st = { t = 0 }
            local y, l, b = AttackAnim.advance(st, a, 0.25)
            expect(y).to.equal(0)
            expect(l).to.equal(0)
            expect(b).to.equal(0)
            expect(st.t).to.near(0.25, 1e-6)
        end)

        it("spin yaw advances frame over frame", function()
            local a = AttackAnim.resolve({ style = "spin", spin_speed = 6 })
            local st = {}
            local yawA = select(1, AttackAnim.advance(st, a, 0.1))
            local yawB = select(1, AttackAnim.advance(st, a, 0.1))
            expect(yawB > yawA).to.equal(true)
        end)
    end)
end
