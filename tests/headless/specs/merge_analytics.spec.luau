local Funnel = loadModule("src/Shared/Game/MergeAnalyticsFunnel.lua")
local Config = loadModule("configs/merge_analytics.lua")

local function reached(state, key)
    return state.funnels[key] and state.funnels[key].reached or 0
end

return function()
    describe("Merge native analytics contract", function()
        it("keeps realm filters finite and preserves manual versus autoplay cohorts", function()
            expect(Funnel.realm("heaven")).to.equal("heaven")
            expect(Funnel.realm("hell")).to.equal("hell")
            for _, value in ipairs({ false, "unknown", "arbitrary player text", 12 }) do
                expect(Funnel.realm(value)).to.equal("unassigned")
            end
            expect(Funnel.realm(nil)).to.equal("unassigned")
            expect(Funnel.controlRealm(false, "heaven")).to.equal("manual:heaven")
            expect(Funnel.controlRealm(true, "hell")).to.equal("autoplay:hell")
            expect(Funnel.controlRealm(nil, nil)).to.equal("manual:unassigned")
        end)
        it("validates six active Merge funnels within the universe tab budget", function()
            expect(Funnel.validate(Config)).to.equal(true)
            local bad = table.clone(Config)
            bad.send_interval = 0
            expect(Funnel.validate(bad)).to.equal(false)
        end)
        it("buffers late prerequisites without Roblox inventing skipped actions", function()
            local state = Funnel.new(Config, "fresh")
            Funnel.observe(state, Config, "wave_cleared")
            Funnel.observe(state, Config, "wave_started")
            Funnel.observe(state, Config, "egg_placed")
            expect(reached(state, "activation")).to.equal(0)
            Funnel.observe(state, Config, "session_ready")
            expect(reached(state, "activation")).to.equal(1)
            local pending = Funnel.observe(state, Config, "egg_created")
            expect(reached(state, "activation")).to.equal(5)
            expect(#pending).to.equal(4)
            expect(pending[1].step).to.equal(2)
            expect(pending[4].step).to.equal(5)
            expect(#Funnel.observe(state, Config, "egg_created")).to.equal(0)
        end)
        it("does not manufacture first activation from a restored board", function()
            local state = Funnel.new(Config, "restored")
            expect(state.funnels.activation).to.equal(nil)
            Funnel.observe(state, Config, "session_ready")
            for _, event in ipairs(Funnel.wave(state, Config, 308)) do
                Funnel.observe(state, Config, event)
            end
            expect(state.clears).to.equal(1)
            expect(reached(state, "depth")).to.equal(2)
            expect(#Funnel.wave(state, Config, 308)).to.equal(0)
            expect(#Funnel.wave(state, Config, 307)).to.equal(0)
        end)
        it("caps wave counters and keeps all thresholds in order", function()
            local state = Funnel.new(Config, "fresh")
            Funnel.observe(state, Config, "session_ready")
            for wave = 1, 1000 do
                for _, event in ipairs(Funnel.wave(state, Config, wave)) do
                    Funnel.observe(state, Config, event)
                end
            end
            expect(state.clears).to.equal(100)
            expect(reached(state, "depth")).to.equal(7)
            expect(#Funnel.wave(state, Config, math.huge)).to.equal(0)
            expect(#Funnel.wave(state, Config, 0 / 0)).to.equal(0)
        end)
        it("isolates three players and a replacement bay session", function()
            local a, b, c =
                Funnel.new(Config, "fresh"),
                Funnel.new(Config, "fresh"),
                Funnel.new(Config, "restored")
            Funnel.observe(a, Config, "session_ready")
            Funnel.observe(a, Config, "egg_created")
            expect(reached(a, "activation")).to.equal(2)
            expect(reached(b, "activation")).to.equal(0)
            expect(reached(c, "depth")).to.equal(0)
            a = Funnel.new(Config, "restored")
            expect(reached(a, "depth")).to.equal(0)
            Funnel.observe(b, Config, "session_ready")
            expect(reached(b, "activation")).to.equal(1)
        end)
        it("keeps optional workshop and rebirth paths out of activation", function()
            local state = Funnel.new(Config, "fresh")
            for _, event in ipairs({ "cannon_opened", "cannon_unlocked", "rebirth_confirmed" }) do
                Funnel.observe(state, Config, event)
            end
            expect(reached(state, "activation")).to.equal(0)
            expect(reached(state, "artillery")).to.equal(1)
            expect(reached(state, "rebirth")).to.equal(0)
            Funnel.observe(state, Config, "rebirth_eligible")
            expect(reached(state, "rebirth")).to.equal(2)
            Funnel.observe(state, Config, "cannon_purchased")
            expect(reached(state, "artillery")).to.equal(2)
        end)
        it("counts only successful automated actions and caps repeated milestones", function()
            local state = Funnel.new(Config, "restored")
            Funnel.observe(state, Config, "autoplay_owned")
            Funnel.observe(state, Config, "autoplay_enabled")
            for _ = 1, 20 do
                for _, event in ipairs(Funnel.autoAction(state, Config)) do
                    Funnel.observe(state, Config, event)
                end
            end
            expect(reached(state, "autoplay")).to.equal(0)
            expect(state.autoActions).to.equal(10)
        end)
        it("only restarts wave identity when the caller confirms a real rebirth", function()
            local state = Funnel.new(Config, "restored")
            Funnel.wave(state, Config, 310)
            expect(#Funnel.wave(state, Config, 1)).to.equal(0)
            state.lastWave = 0
            Funnel.wave(state, Config, 1)
            expect(state.clears).to.equal(2)
        end)
    end)
end
