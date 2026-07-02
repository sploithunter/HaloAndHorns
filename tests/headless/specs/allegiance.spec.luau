--[[
    Allegiance — heaven/hell combat-targeting asymmetry.
    Run: mise run test-headless
]]

local Allegiance = loadModule("src/Shared/Game/Allegiance.lua")

return function()
    describe("Allegiance.normalize", function()
        it("maps heaven/light -> heaven", function()
            expect(Allegiance.normalize("heaven")).to.equal("heaven")
            expect(Allegiance.normalize("light")).to.equal("heaven")
        end)
        it("maps hell/shadow -> hell", function()
            expect(Allegiance.normalize("hell")).to.equal("hell")
            expect(Allegiance.normalize("shadow")).to.equal("hell")
        end)
        it("anything else (incl nil) -> neutral", function()
            expect(Allegiance.normalize(nil)).to.equal("neutral")
            expect(Allegiance.normalize("grass")).to.equal("neutral")
        end)
    end)

    describe("Allegiance.effective (neutral takes the realm side)", function()
        it("a neutral actor in heaven acts heaven", function()
            expect(Allegiance.effective("neutral", "heaven")).to.equal("heaven")
        end)
        it("a neutral actor in hell acts hell", function()
            expect(Allegiance.effective(nil, "hell")).to.equal("hell")
        end)
        it("a heaven actor stays heaven regardless of realm", function()
            expect(Allegiance.effective("heaven", "hell")).to.equal("heaven")
        end)
    end)

    describe("Allegiance.hostile — IN HEAVEN (heaven enemies)", function()
        it("heaven enemy does NOT attack a heaven pet (farming)", function()
            expect(Allegiance.hostile("heaven", "heaven", "heaven")).to.equal(false)
        end)
        it("heaven enemy does NOT attack a NEUTRAL pet (it sides with heaven)", function()
            expect(Allegiance.hostile("heaven", "neutral", "heaven")).to.equal(false)
        end)
        it("heaven enemy DOES attack a hell pet (bring hell pets to fight)", function()
            expect(Allegiance.hostile("heaven", "hell", "heaven")).to.equal(true)
        end)
        it(
            "a neutral pet does NOT PROACTIVELY attack a heaven enemy (reactive-join is runtime)",
            function()
                -- The PURE gate is proactive: a neutral pet sides with heaven so it won't INITIATE. Its
                -- "join a fight already engaged with the squad" override lives in the service
                -- (EnemyService._petHostileToEnemy), which can see the aggro state this module cannot.
                expect(Allegiance.hostile("neutral", "heaven", "heaven")).to.equal(false)
            end
        )
        it("a hell pet DOES attack a heaven enemy in heaven", function()
            expect(Allegiance.hostile("hell", "heaven", "heaven")).to.equal(true)
        end)
    end)

    describe("Allegiance.hostile — IN HELL (hell enemies attack all)", function()
        it("hell enemy attacks a heaven pet", function()
            expect(Allegiance.hostile("hell", "heaven", "hell")).to.equal(true)
        end)
        it("hell enemy attacks a neutral pet", function()
            expect(Allegiance.hostile("hell", "neutral", "hell")).to.equal(true)
        end)
        it("hell enemy attacks a hell pet", function()
            expect(Allegiance.hostile("hell", "hell", "hell")).to.equal(true)
        end)
        it("a neutral pet (sides hell) attacks a hell enemy", function()
            expect(Allegiance.hostile("neutral", "hell", "hell")).to.equal(true)
        end)
    end)

    describe("Allegiance.hostile — OFF-REALM (homeworld) is unchanged", function()
        it("everyone attacks all when the realm is neutral", function()
            expect(Allegiance.hostile("heaven", "neutral", "neutral")).to.equal(true)
            expect(Allegiance.hostile("heaven", "heaven", nil)).to.equal(true)
            expect(Allegiance.hostile("neutral", "neutral", "neutral")).to.equal(true)
        end)
    end)
end
