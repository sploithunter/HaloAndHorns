--[[
    Aggro/threat table: accumulate, clamp, decay-to-zero, top-with-filter, pacify.
    Run: mise run test-headless
]]

local AggroTable = loadModule("src/Shared/Game/AggroTable.lua")

return function()
    describe("AggroTable.add / get", function()
        it("accumulates aggro per attacker", function()
            local t = AggroTable.new()
            AggroTable.add(t, "petA", 10)
            AggroTable.add(t, "petA", 5)
            AggroTable.add(t, "petB", 3)
            expect(AggroTable.get(t, "petA")).to.equal(15)
            expect(AggroTable.get(t, "petB")).to.equal(3)
            expect(AggroTable.get(t, "nobody")).to.equal(0)
        end)

        it("entries may go NEGATIVE (fear = negative aggro, Phase 2)", function()
            -- was clamped at 0; Jason: "the aggro system goes negative and the enemy RUNS"
            local t = AggroTable.new()
            AggroTable.add(t, "petA", 4)
            AggroTable.add(t, "petA", -10)
            expect(AggroTable.get(t, "petA")).to.equal(-6)
            expect(AggroTable.size(t)).to.equal(1)
        end)

        it("set() forces an exact value (fear writes a deterministic negative)", function()
            local t = AggroTable.new()
            AggroTable.add(t, "petA", 100) -- even a heavily-threatened source
            AggroTable.set(t, "petA", -50)
            expect(AggroTable.get(t, "petA")).to.equal(-50)
            AggroTable.set(t, "petA", 0) -- zero clears
            expect(AggroTable.size(t)).to.equal(0)
        end)

        it("ignores nil keys and zero amounts", function()
            local t = AggroTable.new()
            AggroTable.add(t, nil, 5)
            AggroTable.add(t, "petA", 0)
            expect(AggroTable.size(t)).to.equal(0)
        end)
    end)

    describe("AggroTable.top", function()
        it("returns the highest-aggro key above the floor", function()
            local t = AggroTable.new()
            AggroTable.add(t, "tank", 40)
            AggroTable.add(t, "dps", 25)
            local key, val = AggroTable.top(t, 0)
            expect(key).to.equal("tank")
            expect(val).to.equal(40)
        end)

        it("returns nil when nothing exceeds the floor (disengage)", function()
            local t = AggroTable.new()
            AggroTable.add(t, "petA", 0.3)
            expect(AggroTable.top(t, 0.5)).to.equal(nil)
        end)

        it("skips entries filtered out by isValid (e.g. downed pets)", function()
            local t = AggroTable.new()
            AggroTable.add(t, "downed", 100)
            AggroTable.add(t, "alive", 10)
            local key = AggroTable.top(t, 0, function(k)
                return k ~= "downed"
            end)
            expect(key).to.equal("alive")
        end)
    end)

    describe("AggroTable.decay", function()
        it("bleeds every entry by rate*dt and removes those that hit zero", function()
            local t = AggroTable.new()
            AggroTable.add(t, "petA", 10)
            AggroTable.add(t, "petB", 2)
            AggroTable.decay(t, 1, 3) -- drop 3 each
            expect(AggroTable.get(t, "petA")).to.equal(7)
            expect(AggroTable.get(t, "petB")).to.equal(0) -- 2-3 -> removed
            expect(AggroTable.size(t)).to.equal(1)
        end)

        it("a non-refreshed top entry eventually decays below the disengage floor", function()
            local t = AggroTable.new()
            AggroTable.add(t, "petA", 5)
            for _ = 1, 20 do
                AggroTable.decay(t, 0.1, 3) -- 0.3/tick * 20 = 6 > 5
            end
            expect(AggroTable.top(t, 0.5)).to.equal(nil)
        end)
    end)

    describe("AggroTable.reinforce (proximity floor)", function()
        it("raises a below-floor entry up to the floor", function()
            local t = AggroTable.new()
            AggroTable.add(t, "petA", 2)
            AggroTable.reinforce(t, "petA", 6)
            expect(AggroTable.get(t, "petA")).to.equal(6)
        end)

        it("never lowers an above-floor entry", function()
            local t = AggroTable.new()
            AggroTable.add(t, "petA", 50)
            AggroTable.reinforce(t, "petA", 6)
            expect(AggroTable.get(t, "petA")).to.equal(50)
        end)

        it("floors a brand-new attacker (just being near keeps aggro non-zero)", function()
            local t = AggroTable.new()
            AggroTable.reinforce(t, "petA", 6)
            expect(AggroTable.get(t, "petA")).to.equal(6)
            -- and it survives a decay tick that would otherwise zero a fresh entry
            AggroTable.decay(t, 1, 3)
            expect(AggroTable.top(t, 0.5)).to.equal("petA")
        end)
    end)

    describe("AggroTable.clear (pacify)", function()
        it("removes an attacker entirely", function()
            local t = AggroTable.new()
            AggroTable.add(t, "petA", 50)
            AggroTable.clear(t, "petA")
            expect(AggroTable.get(t, "petA")).to.equal(0)
            expect(AggroTable.top(t, 0)).to.equal(nil)
        end)
    end)

    describe("FEAR — negative aggro (docs/AGGRO_MODEL.md: negative top ⇒ flee)", function()
        it("bottom() returns the most-feared (most negative) source", function()
            local t = AggroTable.new()
            AggroTable.set(t, "sandwalker", -50)
            AggroTable.set(t, "tank", -10)
            AggroTable.add(t, "dps", 20) -- a positive coexists
            local key, val = AggroTable.bottom(t)
            expect(key).to.equal("sandwalker")
            expect(val).to.equal(-50)
        end)

        it("bottom() is nil when nothing is negative; top() ignores negatives", function()
            local t = AggroTable.new()
            AggroTable.add(t, "tank", 40)
            expect(AggroTable.bottom(t)).to.equal(nil)
            AggroTable.set(t, "feared", -50)
            expect(AggroTable.top(t, 0)).to.equal("tank") -- attack rule unaffected by the negative
        end)

        it("bottom() respects the isValid filter (downed pets don't scare anyone)", function()
            local t = AggroTable.new()
            AggroTable.set(t, "downed", -99)
            AggroTable.set(t, "alive", -10)
            local key = AggroTable.bottom(t, function(k)
                return k ~= "downed"
            end)
            expect(key).to.equal("alive")
        end)

        it("decay RECOVERS a negative entry up toward 0 (fear wears off)", function()
            local t = AggroTable.new()
            AggroTable.set(t, "petA", -6)
            AggroTable.decay(t, 1, 4) -- +4 toward 0
            expect(AggroTable.get(t, "petA")).to.equal(-2)
            AggroTable.decay(t, 1, 4) -- crosses 0 -> removed (calm)
            expect(AggroTable.get(t, "petA")).to.equal(0)
            expect(AggroTable.size(t)).to.equal(0)
        end)

        it("reinforce (proximity floor) CANNOT re-anchor a feared entry", function()
            -- without this, the proximity floor would instantly cancel a fear (raise -50 to 6)
            local t = AggroTable.new()
            AggroTable.set(t, "petA", -50)
            AggroTable.reinforce(t, "petA", 6)
            expect(AggroTable.get(t, "petA")).to.equal(-50)
        end)

        it("clearNegatives() snaps only the feared entries back to 0 (window lapsed)", function()
            local t = AggroTable.new()
            AggroTable.set(t, "feared1", -50)
            AggroTable.set(t, "feared2", -20)
            AggroTable.add(t, "tank", 40)
            AggroTable.clearNegatives(t)
            expect(AggroTable.get(t, "feared1")).to.equal(0)
            expect(AggroTable.get(t, "feared2")).to.equal(0)
            expect(AggroTable.get(t, "tank")).to.equal(40)
        end)
    end)

    describe("AggroTable.heat (rage tipping point input)", function()
        it("sums the positive entries", function()
            local t = AggroTable.new()
            AggroTable.add(t, "petA", 120)
            AggroTable.add(t, "petB", 80)
            expect(AggroTable.heat(t)).to.equal(200)
        end)

        it("ignores negative (feared) entries — terror is not pressure", function()
            local t = AggroTable.new()
            AggroTable.add(t, "petA", 150)
            AggroTable.set(t, "petB", -50)
            expect(AggroTable.heat(t)).to.equal(150)
        end)

        it("is 0 for an empty table", function()
            expect(AggroTable.heat(AggroTable.new())).to.equal(0)
        end)
    end)
end
