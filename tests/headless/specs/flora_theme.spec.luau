--[[
    FloraTheme — [unit] the flora restyle resolution (layer > realm > keep).
    Run: mise run test-headless
]]

local FloraTheme = loadModule("src/Shared/Game/FloraTheme.lua")

return function()
    local cfg = {
        layers = {
            heaven_2 = {
                ["tree/desert_tree"] = "dawnbloom_tree",
                cactus = "crystal_cactus",
            },
        },
        realms = {
            heaven = {
                tree = "heaven_tree_default",
                ["rock/rockstone"] = "pearl_boulder",
            },
        },
    }

    describe("FloraTheme.resolve", function()
        it("layer kind/variant beats everything", function()
            expect(FloraTheme.resolve(cfg, "heaven_2", "tree", "desert_tree")).to.equal(
                "dawnbloom_tree"
            )
        end)

        it("layer kind catches other variants", function()
            expect(FloraTheme.resolve(cfg, "heaven_2", "cactus", "cactus")).to.equal(
                "crystal_cactus"
            )
        end)

        it("falls back to the realm kind", function()
            expect(FloraTheme.resolve(cfg, "heaven_1", "tree", "pine_tree")).to.equal(
                "heaven_tree_default"
            )
            -- heaven_2 tree WITHOUT a layer variant match also lands on realm kind?
            -- no: heaven_2 has no plain `tree`, so pine falls to the realm default.
            expect(FloraTheme.resolve(cfg, "heaven_2", "tree", "pine_tree")).to.equal(
                "heaven_tree_default"
            )
        end)

        it("realm kind/variant beats realm kind", function()
            expect(FloraTheme.resolve(cfg, "heaven_3", "rock", "rockstone")).to.equal(
                "pearl_boulder"
            )
        end)

        it("keeps the original when nothing matches", function()
            expect(FloraTheme.resolve(cfg, "hell_1", "tree", "pine_tree")).to.equal(nil)
            expect(FloraTheme.resolve(cfg, "base", "tree", "pine_tree")).to.equal(nil)
        end)

        it("handles junk config", function()
            expect(FloraTheme.resolve(nil, "heaven_1", "tree", "x")).to.equal(nil)
            expect(FloraTheme.resolve({}, "heaven_1", "tree", "x")).to.equal(nil)
        end)
    end)

    describe("FloraTheme.realmOf", function()
        it("parses layer ids", function()
            expect(FloraTheme.realmOf("heaven_2")).to.equal("heaven")
            expect(FloraTheme.realmOf("hell_5")).to.equal("hell")
            expect(FloraTheme.realmOf("base")).to.equal(nil)
        end)
    end)
end
