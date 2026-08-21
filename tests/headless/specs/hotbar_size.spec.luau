local HotbarSize = loadModule("src/Shared/Game/HotbarSize.lua")

return function()
    describe("HotbarSize", function()
        it("defaults unknown preferences to auto and migrates the old toggle", function()
            expect(HotbarSize.normalize(nil)).to.equal("auto")
            expect(HotbarSize.normalize("compact")).to.equal("auto")
            expect(HotbarSize.normalize("expanded")).to.equal("mobile")
            expect(HotbarSize.normalize("mobile")).to.equal("mobile")
        end)

        it("uses the bigger mobile size on phones in auto", function()
            expect(HotbarSize.resolve("auto", "phone")).to.equal("mobile")
            expect(HotbarSize.resolve("auto", "compact")).to.equal("mobile")
        end)

        it("uses tablet size on tablets and desktop size on desktop in auto", function()
            expect(HotbarSize.resolve("auto", "tablet")).to.equal("tablet")
            expect(HotbarSize.resolve("auto", "desktop")).to.equal("desktop")
            expect(HotbarSize.resolve("auto", "ten_foot")).to.equal("desktop")
        end)

        it("honors an explicit override on any device", function()
            expect(HotbarSize.resolve("desktop", "phone")).to.equal("desktop")
            expect(HotbarSize.resolve("tablet", "phone")).to.equal("tablet")
            expect(HotbarSize.resolve("mobile", "desktop")).to.equal("mobile")
        end)

        it("treats missing orientation as the horizontal keeper", function()
            expect(HotbarSize.orientation(nil)).to.equal("horizontal")
            expect(HotbarSize.orientation({})).to.equal("horizontal")
            expect(HotbarSize.orientation({ orientation = "vertical_left" })).to.equal(
                "vertical_left"
            )
        end)

        it("fits a vertical bar to viewport height instead of width", function()
            local config = {
                orientation = "vertical_left",
                vertical_span = 546,
                mobile_height_scale = 0.82,
                tablet_height_scale = 0.72,
                modes = { desktop = 1, mobile = 1.6, tablet = 1.2 },
            }
            expect(HotbarSize.multiplier("desktop", 1920, 1080, config)).to.equal(1)
            local phone = HotbarSize.multiplier("mobile", 844, 390, config)
            expect(phone < 1.3).to.equal(true)
            expect(phone > 0.9).to.equal(true)
        end)

        it(
            "uses the tablet scale on iPad viewports and the desktop scale on large screens",
            function()
                local config = {
                    design_span = 792,
                    mobile_width_scale = 0.81,
                    tablet_width_scale = 0.58,
                    modes = { desktop = 1.04, mobile = 1.6, tablet = 1.04 },
                }
                expect(HotbarSize.multiplier("tablet", 1080, 810, config)).to.equal(1.04)
                expect(HotbarSize.multiplier("mobile", 1080, 810, config)).to.equal(1.04)
                expect(HotbarSize.multiplier("desktop", 1920, 1080, config)).to.equal(1.04)
                expect(HotbarSize.multiplier("mobile", 1920, 1080, config)).to.equal(1.04)
            end
        )

        it("grows the phone bar and leaves a short desktop pin at its mode", function()
            local config = {
                design_span = 792,
                mobile_width_scale = 0.90,
                tablet_width_scale = 0.72,
                modes = { desktop = 1, mobile = 1.6, tablet = 1.2 },
            }
            expect(HotbarSize.multiplier("desktop", 800, 500, config)).to.equal(1)
            local phoneMobile = HotbarSize.multiplier("mobile", 844, 390, config)
            local phoneTablet = HotbarSize.multiplier("tablet", 844, 390, config)
            expect(phoneMobile > 1.5).to.equal(true)
            expect(phoneTablet < phoneMobile).to.equal(true)
        end)
    end)
end
