--[[
    Feature 6: Element resonance matrix — [unit] scenarios.
    Run: mise run test-headless
]]

local ElementResonance = loadModule("src/Shared/Game/ElementResonance.lua")
local elementsConfig = loadModule("configs/elements.lua")

local biomeCfg = loadModule("configs/elements.lua")

return function()
    describe("ElementResonance.biomeMultiplier (zone RPS)", function()
        it("advantage in the zone your element beats", function()
            expect(ElementResonance.biomeMultiplier("lava", "grass", biomeCfg)).to.equal(1.25)
            expect(ElementResonance.biomeMultiplier("grass", "desert", biomeCfg)).to.equal(1.25)
            expect(ElementResonance.biomeMultiplier("desert", "ice", biomeCfg)).to.equal(1.25)
            expect(ElementResonance.biomeMultiplier("ice", "lava", biomeCfg)).to.equal(1.25)
        end)

        it("disadvantage in the zone that beats you", function()
            expect(ElementResonance.biomeMultiplier("grass", "lava", biomeCfg)).to.equal(0.8)
            expect(ElementResonance.biomeMultiplier("lava", "ice", biomeCfg)).to.equal(0.8)
        end)

        it("home and opposite are neutral", function()
            expect(ElementResonance.biomeMultiplier("grass", "grass", biomeCfg)).to.equal(1)
            expect(ElementResonance.biomeMultiplier("grass", "ice", biomeCfg)).to.equal(1)
            expect(ElementResonance.biomeMultiplier("lava", "desert", biomeCfg)).to.equal(1)
        end)

        it("special/unknown zones are neutral by construction", function()
            expect(ElementResonance.biomeMultiplier("lava", "heaven_3", biomeCfg)).to.equal(1)
            expect(ElementResonance.biomeMultiplier(nil, "grass", biomeCfg)).to.equal(1)
            expect(ElementResonance.biomeMultiplier("lava", "grass", nil)).to.equal(1)
        end)
    end)

    describe("ElementResonance.multiplier", function()
        local function m(element, realm)
            return ElementResonance.multiplier(element, realm, elementsConfig)
        end

        -- CROSS-REALM (Jason): a pet is weak in its OWN realm (0.8) and strong in the OPPOSITE one
        -- (1.5) — Heaven pets are weapons in Hell and vice versa, which drives cross-realm trading.
        it("light: weak at home (heaven) 0.8, strong opposing (hell) 1.5, neutral 1.0", function()
            expect(m("light", "heaven")).to.equal(0.8)
            expect(m("light", "hell")).to.equal(1.5)
            expect(m("light", "neutral")).to.equal(1.0)
        end)

        it(
            "shadow mirrors light: strong opposing (heaven) 1.5, weak at home (hell) 0.8, neutral 1.0",
            function()
                expect(m("shadow", "heaven")).to.equal(1.5)
                expect(m("shadow", "hell")).to.equal(0.8)
                expect(m("shadow", "neutral")).to.equal(1.0)
            end
        )

        it("chaotic is flat 1.3 across realms", function()
            expect(m("chaotic", "heaven")).to.equal(1.3)
            expect(m("chaotic", "hell")).to.equal(1.3)
            expect(m("chaotic", "neutral")).to.equal(1.3)
        end)

        it("neutral is flat 1.0 across realms", function()
            expect(m("neutral", "heaven")).to.equal(1.0)
            expect(m("neutral", "hell")).to.equal(1.0)
            expect(m("neutral", "neutral")).to.equal(1.0)
        end)

        it("unknown element or realm defaults to 1.0", function()
            expect(m("sparkly", "heaven")).to.equal(1.0)
            expect(m("light", "void")).to.equal(1.0)
        end)
    end)

    -- The shared pet-by-species-realm helper (server damage path AND client card both call it, so
    -- the displayed power equals the dealt power).
    describe("ElementResonance.petRealmMultiplier", function()
        local function p(petRealm, playerRealm)
            return ElementResonance.petRealmMultiplier(petRealm, playerRealm, elementsConfig)
        end
        it("maps heaven pets -> light: 0.8 home, 1.5 in hell, 1.0 homeworld", function()
            expect(p("heaven", "heaven")).to.equal(0.8)
            expect(p("heaven", "hell")).to.equal(1.5)
            expect(p("heaven", "neutral")).to.equal(1.0)
        end)
        it("maps hell pets -> shadow: 1.5 in heaven, 0.8 home, 1.0 homeworld", function()
            expect(p("hell", "heaven")).to.equal(1.5)
            expect(p("hell", "hell")).to.equal(0.8)
            expect(p("hell", "neutral")).to.equal(1.0)
        end)
        it("homeworld pets (no/other realm) -> neutral 1.0 everywhere", function()
            expect(p(nil, "hell")).to.equal(1.0)
            expect(p("base", "heaven")).to.equal(1.0)
        end)
    end)
end
