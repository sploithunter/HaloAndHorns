local Enhancements = loadModule("src/Shared/Game/Enhancements.lua")
local cfg = loadModule("configs/enhancements.lua")
local powers = loadModule("configs/powers.lua")

return function()
    describe("Utility toggle in-slot compensation", function()
        it("replaces timing types with the strongest usable matching single-origin gear", function()
            for _, origin in ipairs(cfg.origins) do
                for level = 1, 50 do
                    local slots = {
                        prospector = {
                            {
                                inherent = true,
                                enh = { type = "duration", origins = {}, level = 1 },
                            },
                            {
                                enh = {
                                    type = "recharge",
                                    origins = { "geomancer", "cryomancer" },
                                    level = 1,
                                },
                            },
                        },
                    }
                    expect(Enhancements.convertToggleSlots(cfg, powers, slots, origin, level)).to.equal(
                        2
                    )
                    expect(slots.prospector[1].inherent).to.equal(true)
                    expect(slots.prospector[1].enh.type).to.equal("potency")
                    expect(slots.prospector[2].enh.type).to.equal("focus")
                    for _, slot in ipairs(slots.prospector) do
                        expect(slot.enh.level).to.equal(level + cfg.drops.levels.scaling.window)
                        expect(Enhancements.isSingle(slot.enh)).to.equal(true)
                        expect(Enhancements.usableBy(slot.enh, origin)).to.equal(true)
                        expect(Enhancements.canSlotAtLevel(cfg, slot.enh.level, level)).to.equal(
                            true
                        )
                        expect(Enhancements.levelFactor(cfg, slot.enh.level, level)).to.equal(1.5)
                    end
                    expect(Enhancements.convertToggleSlots(cfg, powers, slots, origin, level)).to.equal(
                        0
                    )
                end
            end
        end)
        it("preserves other pieces, empty slots, malformed data and pre-origin builds", function()
            local original = { type = "duration", origins = {}, level = 10 }
            local slots = {
                fortune = { { enh = original }, {}, { enh = false } },
                hasten = { { enh = { type = "recharge", origins = {}, level = 10 } } },
            }
            expect(Enhancements.convertToggleSlots(cfg, powers, slots, nil, 10)).to.equal(0)
            expect(slots.fortune[1].enh).to.equal(original)
            expect(Enhancements.convertToggleSlots(cfg, powers, slots, "pyromancer", 10)).to.equal(
                1
            )
            expect(slots.hasten[1].enh.type).to.equal("recharge")
            expect(#slots.fortune).to.equal(3)
            expect(slots.fortune[2].enh).to.equal(nil)
            expect(slots.fortune[3].enh).to.equal(false)
        end)
    end)
end
