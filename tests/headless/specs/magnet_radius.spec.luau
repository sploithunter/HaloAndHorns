local MagnetRadius = loadModule("src/Shared/Game/MagnetRadius.lua")

return function()
    describe("MagnetRadius", function()
        it("preserves the shipped base plus Magnet-power reach", function()
            expect(MagnetRadius.resolve(11, 30, 0, 0)).to.equal(41)
        end)

        it("applies an Onyx Exclusive Magnet to the complete useful radius", function()
            -- Onyx (+5) × Exclusive (2.0) × 3% per strength = +30%.
            local radius = MagnetRadius.resolve(11, 30, 0, 0.30)
            expect(math.abs(radius - 53.3) < 1e-9).to.equal(true)
        end)

        it("multiplies a stronger absolute pet-ability range", function()
            expect(MagnetRadius.resolve(11, 30, 125, 0.20)).to.equal(150)
        end)

        it("clamps malformed and negative inputs", function()
            expect(MagnetRadius.resolve(-5, "bad", -1, -2)).to.equal(0)
        end)
    end)
end
