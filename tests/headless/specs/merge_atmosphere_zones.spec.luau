local Zones = loadModule("src/Shared/Game/MergeAtmosphereZones.lua")
local cfg = loadModule("configs/merge_egg_prototype.lua").atmosphere

return function()
    describe("Merge Heaven / mall / Hell sky zones", function()
        it("resolves fresh joins in all three regions without a previous side", function()
            expect(Zones.resolve(cfg, 240)).to.equal("heaven")
            expect(Zones.resolve(cfg, 0)).to.equal("mall")
            expect(Zones.resolve(cfg, -240)).to.equal("hell")
        end)
        it(
            "makes both mall walkways and bridges neutral, regardless of travel direction",
            function()
                for _, previous in ipairs({ "heaven", "hell", "mall" }) do
                    for _, x in ipairs({ -65, 0, 55 }) do
                        expect(Zones.resolve(cfg, x, previous)).to.equal("mall")
                    end
                end
            end
        )
        it(
            "uses small hysteresis at terrace edges, not a remembered side across the mall",
            function()
                local edge = cfg.mall_half_width
                expect(Zones.resolve(cfg, edge - 1, "heaven")).to.equal("heaven")
                expect(Zones.resolve(cfg, edge - cfg.hysteresis - 1, "heaven")).to.equal("mall")
                expect(Zones.resolve(cfg, edge + 1, "mall")).to.equal("mall")
                expect(Zones.resolve(cfg, edge + cfg.hysteresis + 1, "mall")).to.equal("heaven")
                expect(Zones.resolve(cfg, -edge + 1, "hell")).to.equal("hell")
                expect(Zones.resolve(cfg, -edge + cfg.hysteresis + 1, "hell")).to.equal("mall")
                expect(Zones.resolve(cfg, -edge - 1, "mall")).to.equal("mall")
                expect(Zones.resolve(cfg, -edge - cfg.hysteresis - 1, "mall")).to.equal("hell")
            end
        )
        it("handles direct teleports across sides", function()
            expect(Zones.resolve(cfg, 240, "hell")).to.equal("heaven")
            expect(Zones.resolve(cfg, -240, "heaven")).to.equal("hell")
        end)
        it("keeps the observed cloud skies and config-owned twilight faces", function()
            expect(cfg.layers.heaven).to.equal("heaven_1")
            expect(cfg.layers.hell).to.equal("hell_2")
            expect(cfg.layers.mall).to.equal("base")
            for _, face in ipairs({ "ft", "bk", "lf", "rt", "up", "dn" }) do
                expect(type(cfg.mall_sky[face])).to.equal("number")
            end
        end)
    end)
end
