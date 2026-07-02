--[[
    Feature 20: Chaotic Fusion — [unit] / [integration] scenarios.
    Run: mise run test-headless
]]

local FusionLogic = loadModule("src/Shared/Game/FusionLogic.lua")
local config = loadModule("configs/fusion.lua")

return function()
    describe("FusionLogic.validateInputs", function()
        it("accepts one Light + one Shadow pet", function()
            expect(FusionLogic.validateInputs("light", "shadow", config).ok).to.equal(true)
        end)

        it("accepts Shadow + Light (order-independent)", function()
            expect(FusionLogic.validateInputs("shadow", "light", config).ok).to.equal(true)
        end)

        it("rejects two same-element (Light + Light) inputs", function()
            local r = FusionLogic.validateInputs("light", "light", config)
            expect(r.ok).to.equal(false)
            expect(r.reason).to.equal("not_light_shadow")
            expect(r.message).to.equal("Fusion requires one Light and one Shadow pet")
        end)

        it("rejects a Chaotic input", function()
            local r = FusionLogic.validateInputs("chaotic", "shadow", config)
            expect(r.ok).to.equal(false)
            expect(r.reason).to.equal("chaotic_input")
            expect(r.message).to.equal("Cannot fuse Chaotic pets")
        end)

        it("rejects a Neutral input", function()
            local r = FusionLogic.validateInputs("neutral", "light", config)
            expect(r.ok).to.equal(false)
            expect(r.reason).to.equal("neutral_input")
            expect(r.message).to.equal("Fusion requires aligned pets (Light + Shadow)")
        end)
    end)

    describe("FusionLogic output", function()
        it("produces a Chaotic pet", function()
            expect(FusionLogic.outputElement(config)).to.equal("chaotic")
        end)

        it("inherits input A's theme by default", function()
            expect(FusionLogic.resolveTheme("frost", "ember", config)).to.equal("frost")
        end)

        it("honors an explicit recipe", function()
            local cfg =
                { recipes = { ["ember+frost"] = "void" }, default_output_theme_from = "input_a" }
            expect(FusionLogic.resolveTheme("frost", "ember", cfg)).to.equal("void")
        end)
    end)

    describe("FusionLogic.fusionRecord", function()
        it("captures inputs, output, player and timestamp", function()
            local rec = FusionLogic.fusionRecord(42, "petA", "petB", "petC", 999)
            expect(rec.player).to.equal(42)
            expect(rec.input_a).to.equal("petA")
            expect(rec.input_b).to.equal("petB")
            expect(rec.output).to.equal("petC")
            expect(rec.timestamp).to.equal(999)
        end)
    end)
end
