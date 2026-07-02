--[[
    Procedural walk gait (shared by enemies + pets): style shapes, config merge,
    distance-driven phase + speed-eased amplitude. Run: mise run test-headless
]]

local Gait = loadModule("src/Shared/Game/Gait.lua")

local PI = math.pi

return function()
    describe("Gait.STYLES", function()
        it("waddle: down at phase 0, banks left/right across the cycle", function()
            local bob0, roll0 = Gait.STYLES.waddle(0)
            expect(bob0).to.near(-1, 1e-6) -- fully down
            expect(roll0).to.near(0, 1e-6)
            local _, rollL = Gait.STYLES.waddle(PI / 2)
            expect(rollL).to.near(1, 1e-6) -- banks one way
            local _, rollR = Gait.STYLES.waddle(3 * PI / 2)
            expect(rollR).to.near(-1, 1e-6) -- and the other
        end)

        it("waddle bobs twice per cycle (up at the half-stride)", function()
            local bobUp = Gait.STYLES.waddle(PI / 2)
            expect(bobUp).to.near(1, 1e-6)
        end)

        it("march has bob but never tilts", function()
            local _, roll, yaw = Gait.STYLES.march(PI / 2)
            expect(roll).to.equal(0)
            expect(yaw).to.equal(0)
        end)

        it("slither yaws but never bobs", function()
            local bob, _, yaw = Gait.STYLES.slither(PI / 2)
            expect(bob).to.equal(0)
            expect(yaw).to.near(1, 1e-6)
        end)

        it("flap: smooth sine bob centred on zero, gentle bank, no yaw", function()
            local bob0, roll0, yaw0 = Gait.STYLES.flap(0)
            expect(bob0).to.near(0, 1e-6) -- centred (not sunk like hop/waddle at phase 0)
            expect(roll0).to.near(0, 1e-6)
            expect(yaw0).to.equal(0)
            local bobUp = Gait.STYLES.flap(PI / 2)
            expect(bobUp).to.near(1, 1e-6) -- peaks at the quarter cycle
        end)
    end)

    describe("Gait.resolve", function()
        it("uses defaults when no override", function()
            local g = Gait.resolve({ style = "march", bob_height = 0.9, tilt_degrees = 0 })
            expect(g.style).to.equal("march")
            expect(g.bobHeight).to.near(0.9, 1e-6)
            expect(g.tiltRad).to.near(0, 1e-6)
        end)

        it("override fields win over the default, others fall through", function()
            local default =
                { style = "waddle", bob_height = 0.6, tilt_degrees = 12, stride_length = 5 }
            local g = Gait.resolve(default, { style = "hop", bob_height = 1.2 })
            expect(g.style).to.equal("hop")
            expect(g.bobHeight).to.near(1.2, 1e-6)
            expect(g.stride).to.near(5, 1e-6) -- not overridden -> default
        end)

        it("converts tilt_degrees to radians and picks the style fn", function()
            local g = Gait.resolve({ style = "waddle", tilt_degrees = 90 })
            expect(g.tiltRad).to.near(PI / 2, 1e-6)
            expect(g.fn).to.equal(Gait.STYLES.waddle)
        end)

        it("falls back to waddle for an unknown style", function()
            local g = Gait.resolve({ style = "nonsense" })
            expect(g.fn).to.equal(Gait.STYLES.waddle)
        end)
    end)

    describe("Gait.advance", function()
        it("rests (no offsets) when the gait is disabled", function()
            local g = Gait.resolve({ enabled = false })
            local st = { phase = 1, amp = 1 }
            local bob, roll, yaw = Gait.advance(st, g, 5, 1 / 60)
            expect(bob).to.equal(0)
            expect(roll).to.equal(0)
            expect(yaw).to.equal(0)
            expect(st.amp).to.equal(0)
        end)

        it("advances phase by distance / stride", function()
            local g = Gait.resolve({ style = "march", stride_length = 4 })
            local st = { phase = 0, amp = 0 }
            Gait.advance(st, g, 2, 1 / 60) -- half a stride -> phase = π
            expect(st.phase).to.near(PI, 1e-6)
        end)

        it("eases amplitude up toward full at ref_speed and decays when idle", function()
            local g =
                Gait.resolve({ style = "march", ref_speed = 8, ease_rate = 8, stride_length = 5 })
            -- moving at ~ref_speed for several frames -> amp climbs toward 1
            local st = { phase = 0, amp = 0 }
            for _ = 1, 60 do
                Gait.advance(st, g, 8 * (1 / 60), 1 / 60) -- speed ~= 8 studs/s
            end
            expect(st.amp > 0.7).to.equal(true)
            -- then stand still -> amp decays back toward 0
            for _ = 1, 120 do
                Gait.advance(st, g, 0, 1 / 60)
            end
            expect(st.amp < 0.05).to.equal(true)
        end)

        it("hover: phase advances by time even when standing still", function()
            local g = Gait.resolve({ style = "flap", hover = true, flap_hz = 1, stride_length = 5 })
            local st = { phase = 0, amp = 0 }
            Gait.advance(st, g, 0, 0.25) -- no movement, quarter-second at 1 Hz -> quarter cycle
            expect(st.phase).to.near(PI / 2, 1e-6)
        end)

        it("hover: amplitude never decays below idle_amp when still", function()
            local g = Gait.resolve({
                style = "flap",
                hover = true,
                idle_amp = 0.6,
                ease_rate = 8,
                stride_length = 5,
            })
            local st = { phase = 0, amp = 0 }
            for _ = 1, 240 do
                Gait.advance(st, g, 0, 1 / 60) -- stationary the whole time
            end
            expect(st.amp > 0.55).to.equal(true) -- floored at idle_amp, not decayed to 0
        end)

        it("non-hover gait still rests fully when idle (regression)", function()
            local g = Gait.resolve({ style = "flap", stride_length = 5 }) -- hover defaults off
            local st = { phase = 0, amp = 0.9 }
            for _ = 1, 120 do
                Gait.advance(st, g, 0, 1 / 60)
            end
            expect(st.amp < 0.05).to.equal(true)
        end)
    end)
end
