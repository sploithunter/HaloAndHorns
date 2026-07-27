return function()
    local XpGlide = loadModule("src/Client/Systems/XpGlide.lua")

    describe("XP glide timing", function()
        it("fills one complete bar per second", function()
            expect(XpGlide.advance(0, 5, 1, 1)).to.equal(1)
            expect(XpGlide.advance(0, 5, 3, 1)).to.equal(3)
        end)

        it("fills one tenth of a bar in one tenth of a second", function()
            expect(XpGlide.advance(0, 0.1, 0.1, 1)).to.equal(0.1)
        end)

        it("stops exactly on the target and safely handles decreases", function()
            expect(XpGlide.advance(0.95, 1, 1, 1)).to.equal(1)
            expect(XpGlide.advance(3, 1, 0.1, 1)).to.equal(1)
        end)
    end)

    describe("HUD progress animation wiring", function()
        it("advances XP through segment units on the heartbeat", function()
            local source = readFile("src/Client/Systems/PlayerBar.lua")
            expect(source:find("local xpShownUnits = nil", 1, true)).to.be.ok()
            expect(source:find("local xpTargetUnits = 0", 1, true)).to.be.ok()
            expect(source:find("progress * SEGMENTS", 1, true)).to.be.ok()
            expect(source:find("local XP_BARS_PER_SECOND = 1", 1, true)).to.be.ok()
            expect(
                source:find(
                    "XpGlide.advance(xpShownUnits, xpTargetUnits, dt, XP_BARS_PER_SECOND)",
                    1,
                    true
                )
            ).to.be.ok()
            expect(source:find("math.floor(units)", 1, true)).to.be.ok()
            expect(source:find("eff > xpState.level", 1, true)).to.be.ok()
        end)

        it("provides a retargetable shared FillBar tween", function()
            local source = readFile("src/Client/UI/FillBar.lua")
            expect(source:find("function FillBar.setAnimated", 1, true)).to.be.ok()
            expect(source:find("active:Cancel()", 1, true)).to.be.ok()
            expect(source:find("Enum.EasingStyle.Quad", 1, true)).to.be.ok()
        end)

        it("smooths both quest and mission objective progress", function()
            local source = readFile("src/Client/UI/BaseUI.lua")
            expect(source:find("FillBar.setAnimated(self._questProgressBar, frac, 0.28)", 1, true)).to.be.ok()
            expect(source:find("sameQuest", 1, true)).to.be.ok()
            expect(source:find("sameObjective", 1, true)).to.be.ok()
        end)
    end)
end
