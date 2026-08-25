--[[
    FloraTheme — [unit] the flora restyle resolution (layer > realm > keep).
    Run: mise run test-headless
]]

local FloraTheme = loadModule("src/Shared/Game/FloraTheme.lua")
local realConfig = loadModule("configs/flora.lua")

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

    describe("FloraTheme.pick", function()
        it("passes strings through", function()
            expect(FloraTheme.pick("oak_tree", 10, 20)).to.equal("oak_tree")
            expect(FloraTheme.pick(nil, 10, 20)).to.equal(nil)
        end)

        it("picks deterministically from arrays by position", function()
            local list = { "a", "b", "c" }
            local first = FloraTheme.pick(list, 100, 200)
            expect(FloraTheme.pick(list, 100, 200)).to.equal(first)
            -- some other position eventually differs (not all same)
            local seen = { [first] = true }
            for x = 1, 20 do
                seen[FloraTheme.pick(list, x * 7.3, x * 3.1)] = true
            end
            local count = 0
            for _ in pairs(seen) do
                count += 1
            end
            expect(count > 1).to.equal(true)
        end)

        it("empty array means keep original", function()
            expect(FloraTheme.pick({}, 1, 2)).to.equal(nil)
        end)
    end)

    describe("FloraTheme.realmOf", function()
        it("parses layer ids", function()
            expect(FloraTheme.realmOf("heaven_2")).to.equal("heaven")
            expect(FloraTheme.realmOf("hell_5")).to.equal("hell")
            expect(FloraTheme.realmOf("base")).to.equal(nil)
        end)
    end)

    describe("Layer 3 production theme", function()
        it("uses the new Heaven flora for every plant anchor variant", function()
            for _, variant in ipairs({
                "cloudtiplant",
                "grass_tuft",
                "field_flower_bush",
                "meadow_bush",
            }) do
                local resolved = FloraTheme.resolve(realConfig, "heaven_3", "plant", variant)
                expect(type(resolved)).to.equal("table")
                expect(#resolved > 1).to.equal(true)
            end
        end)

        it("uses the new Hell flora for every plant anchor variant", function()
            for _, variant in ipairs({ "grass_tuft", "field_flower_bush", "meadow_bush" }) do
                local resolved = FloraTheme.resolve(realConfig, "hell_3", "plant", variant)
                expect(type(resolved)).to.equal("table")
                expect(#resolved >= 4).to.equal(true)
            end
        end)

        it("uses the new Layer 3 rocks and cacti", function()
            local heavenRocks = FloraTheme.resolve(realConfig, "heaven_3", "rock", "ice_rock")
            expect(type(heavenRocks)).to.equal("table")
            expect(#heavenRocks).to.equal(2)

            local hellRocks = FloraTheme.resolve(realConfig, "hell_3", "rock", "rockstone")
            expect(type(hellRocks)).to.equal("table")
            expect(#hellRocks).to.equal(2)

            expect(FloraTheme.resolve(realConfig, "heaven_3", "cactus", "cactus")).to.equal(
                "empyrean_bloom_cactus"
            )
            expect(FloraTheme.resolve(realConfig, "hell_3", "cactus", "cactus")).to.equal(
                "dreadspire_thorn_cactus"
            )
        end)

        it("mixes each signature Layer 3 tree into the copied biome anchors", function()
            for _, layer in ipairs({ "heaven_3", "hell_3" }) do
                local signature = if layer == "heaven_3"
                    then "luminous_canopy_tree"
                    else "dreadthorn_tree"
                for _, variant in ipairs({ "baobab_tree", "oak_tree", "pine_tree", "tree1" }) do
                    local resolved = FloraTheme.resolve(realConfig, layer, "tree", variant)
                    if type(resolved) == "table" then
                        local found = false
                        for _, modelName in ipairs(resolved) do
                            found = found or modelName == signature
                        end
                        expect(found).to.equal(true)
                    else
                        expect(resolved).to.equal(signature)
                    end
                end
            end
        end)
    end)
end
