-- EnemyCon — the City-of-Heroes con-colour scale (enemy level relative to the player).
-- Pins the exact tier boundaries Jason specified so a refactor can't silently shift them.

local EnemyCon = loadModule("src/Shared/Game/EnemyCon.lua")

return function()
    describe("EnemyCon.tier (con scale by level diff)", function()
        it("maps the exact 8-tier scale", function()
            expect(EnemyCon.tier(-2)).to.equal("green")
            expect(EnemyCon.tier(-1)).to.equal("blue")
            expect(EnemyCon.tier(0)).to.equal("white")
            expect(EnemyCon.tier(1)).to.equal("yellow")
            expect(EnemyCon.tier(2)).to.equal("orange")
            expect(EnemyCon.tier(3)).to.equal("red")
        end)

        it("clamps gray at -3 and below", function()
            expect(EnemyCon.tier(-3)).to.equal("gray")
            expect(EnemyCon.tier(-9)).to.equal("gray")
        end)

        it("clamps purple at +4 and above", function()
            expect(EnemyCon.tier(4)).to.equal("purple")
            expect(EnemyCon.tier(99)).to.equal("purple")
        end)

        it("defaults a nil/garbage diff to even (white)", function()
            expect(EnemyCon.tier(nil)).to.equal("white")
            expect(EnemyCon.tier("x")).to.equal("white")
        end)

        it("rgb resolves a tier for every diff (no nil)", function()
            for d = -5, 6 do
                local c = EnemyCon.rgb(d)
                expect(type(c)).to.equal("table")
                expect(#c).to.equal(3)
            end
        end)
    end)
end
