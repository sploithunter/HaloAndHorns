--[[
    Feature 3: Layer access & portals — [unit] scenarios.
    Run: mise run test-headless
]]

local LayerAccess = loadModule("src/Shared/Game/LayerAccess.lua")
local layersConfig = loadModule("configs/layers.lua")

return function()
    describe("LayerAccess.canAccess", function()
        local function access(soul, balance, layer, opts)
            return LayerAccess.canAccess(soul, balance, layer, layersConfig, opts)
        end

        it("a new player (soul 0) can access base", function()
            expect(access(0, 0, "base").ok).to.equal(true)
        end)

        it("rejects Heaven 1 when Soul is too low (no deduction)", function()
            local r = access(10, 1000, "heaven_1")
            expect(r.ok).to.equal(false)
            expect(r.reason).to.equal("soul_too_low")
        end)

        it("rejects Heaven 1 when tokens are insufficient", function()
            local r = access(50, 50, "heaven_1")
            expect(r.ok).to.equal(false)
            expect(r.reason).to.equal("insufficient_tokens")
            expect(r.cost).to.equal(100)
            expect(r.currency).to.equal("light_tokens")
        end)

        it("allows Heaven 1 with enough Soul and tokens", function()
            local r = access(25, 150, "heaven_1")
            expect(r.ok).to.equal(true)
            expect(r.cost).to.equal(100)
            expect(r.currency).to.equal("light_tokens")
        end)

        it("rejects Hell 1 with positive Soul (wrong direction)", function()
            local r = access(30, 1000, "hell_1")
            expect(r.ok).to.equal(false)
            expect(r.reason).to.equal("soul_wrong_direction")
        end)

        it("allows Hell 1 with sufficiently negative Soul + tokens", function()
            expect(access(-25, 150, "hell_1").ok).to.equal(true)
        end)

        it("cross-path visit portal ignores Soul (token cost still applies)", function()
            -- Heaven-aligned player visiting Hell 1 via a visit portal
            expect(access(50, 100, "hell_1", { crossPathVisit = true }).ok).to.equal(true)
            -- but still needs the tokens
            expect(access(50, 50, "hell_1", { crossPathVisit = true }).reason).to.equal(
                "insufficient_tokens"
            )
        end)

        it("unknown layer is rejected", function()
            expect(access(0, 0, "valhalla").reason).to.equal("unknown_layer")
        end)

        -- World S3: requires_level third gate (enforced only when a level is supplied).
        it("rejects Heaven 1 when player level is too low", function()
            local r = access(25, 150, "heaven_1", { playerLevel = 5 })
            expect(r.ok).to.equal(false)
            expect(r.reason).to.equal("level_too_low")
            expect(r.requiresLevel).to.equal(7) -- Jason: Heaven/Hell 1 = Lv 7 (+7 per layer)
        end)

        it("allows Heaven 1 once Soul, tokens, AND level all clear", function()
            expect(access(25, 150, "heaven_1", { playerLevel = 10 }).ok).to.equal(true)
        end)

        it("omitting playerLevel skips the level gate (pure module stays judgable)", function()
            -- soul + tokens fine, no level supplied -> level gate not enforced
            expect(access(25, 150, "heaven_1").ok).to.equal(true)
        end)

        -- World S3: the new deepest layers (5/side) with soul ±100 / level 35 / 2000 tokens.
        it("Heaven 5 is the deepest gate (soul 100 + level 35 + 2000 light tokens)", function()
            expect(access(100, 2000, "heaven_5", { playerLevel = 35 }).ok).to.equal(true)
            expect(access(80, 2000, "heaven_5", { playerLevel = 35 }).reason).to.equal(
                "soul_too_low"
            )
            expect(access(100, 2000, "heaven_5", { playerLevel = 34 }).reason).to.equal(
                "level_too_low"
            )
            expect(access(100, 100, "heaven_5", { playerLevel = 35 }).reason).to.equal(
                "insufficient_tokens"
            )
        end)

        it("Hell 5 mirrors with negative soul", function()
            expect(access(-100, 2000, "hell_5", { playerLevel = 35 }).ok).to.equal(true)
            expect(access(-100, 2000, "hell_5", { playerLevel = 50 }).currency).to.equal(
                "shadow_tokens"
            )
        end)

        it("cross-path visit waives Soul but NOT the level gate", function()
            -- heaven-aligned player visiting hell_3: soul ignored, but level still required
            expect(access(60, 1000, "hell_3", { crossPathVisit = true, playerLevel = 5 }).reason).to.equal(
                "level_too_low"
            )
            expect(access(60, 1000, "hell_3", { crossPathVisit = true, playerLevel = 30 }).ok).to.equal(
                true
            )
        end)
    end)

    describe("LayerAccess traversal sink (charge_on)", function()
        -- layersConfig defaults charge_on = "deeper_only".
        it("layerDepth: base 0, heaven_3 = 3, hell_2 = 2", function()
            expect(LayerAccess.layerDepth("base")).to.equal(0)
            expect(LayerAccess.layerDepth("heaven_3")).to.equal(3)
            expect(LayerAccess.layerDepth("hell_2")).to.equal(2)
        end)

        it("deeper_only charges a deeper move", function()
            expect(LayerAccess.isCharged("heaven_1", "heaven_2", layersConfig)).to.equal(true)
        end)

        it("deeper_only is free retreating toward base", function()
            expect(LayerAccess.isCharged("heaven_3", "heaven_1", layersConfig)).to.equal(false)
            expect(LayerAccess.isCharged("heaven_2", "base", layersConfig)).to.equal(false)
        end)

        it("canAccess: retreating costs 0 and needs no tokens (deeper_only)", function()
            -- heaven_2 -> heaven_1: shallower, so free even with zero tokens (soul/level still met)
            local r = LayerAccess.canAccess(50, 0, "heaven_1", layersConfig, {
                playerLevel = 20,
                fromLayer = "heaven_2",
            })
            expect(r.ok).to.equal(true)
            expect(r.cost).to.equal(0)
        end)

        it("canAccess: descending deeper charges the target token_cost", function()
            local r = LayerAccess.canAccess(60, 500, "heaven_3", layersConfig, {
                playerLevel = 30,
                fromLayer = "heaven_2",
            })
            expect(r.ok).to.equal(true)
            expect(r.cost).to.equal(500)
        end)

        it("no fromLayer => charges (preserves every-move behavior)", function()
            local r = LayerAccess.canAccess(25, 0, "heaven_1", layersConfig, { playerLevel = 10 })
            expect(r.ok).to.equal(false)
            expect(r.reason).to.equal("insufficient_tokens")
        end)
    end)

    describe("LayerAccess.accessibleLayers", function()
        it("a fresh player can only access base", function()
            local layers = LayerAccess.accessibleLayers(0, {}, layersConfig)
            expect(#layers).to.equal(1)
            expect(layers[1]).to.equal("base")
        end)

        it("a Heaven-aligned, token-rich, level-10 player can access base + Heaven 1", function()
            local layers =
                LayerAccess.accessibleLayers(25, { light_tokens = 150 }, layersConfig, 10)
            -- base + heaven_1 (soul 25 >= 20, tokens 150 >= 100, level 10 >= 10); heaven_2 needs soul 40
            local set = {}
            for _, l in ipairs(layers) do
                set[l] = true
            end
            expect(set.base).to.equal(true)
            expect(set.heaven_1).to.equal(true)
            expect(set.heaven_2).to.equal(nil)
        end)

        it("level gate filters Heaven 1 out for a low-level player (soul+tokens fine)", function()
            local layers = LayerAccess.accessibleLayers(25, { light_tokens = 150 }, layersConfig, 5)
            local set = {}
            for _, l in ipairs(layers) do
                set[l] = true
            end
            expect(set.base).to.equal(true) -- base has no level req
            expect(set.heaven_1).to.equal(nil) -- needs level 10
        end)
    end)
end
