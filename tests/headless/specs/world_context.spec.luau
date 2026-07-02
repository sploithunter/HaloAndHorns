--[[
    WorldContext — folder-name -> realm/depth parsing + depth-scaled difficulty (pure parts).
    The of(instance) ancestry walk needs real instances, so it's exercised live, not here.
    Run: mise run test-headless
]]

local WorldContext = loadModule("src/Shared/Game/WorldContext.lua")

return function()
    describe("WorldContext.parseName", function()
        it("maps Home/Base to base depth 0", function()
            expect(WorldContext.parseName("Home").realm).to.equal("base")
            expect(WorldContext.parseName("Home").depth).to.equal(0)
            expect(WorldContext.parseName("Base").realm).to.equal("base")
        end)

        it("parses Heaven_<n> and Hell_<n>", function()
            local h3 = WorldContext.parseName("Heaven_3")
            expect(h3.realm).to.equal("heaven")
            expect(h3.depth).to.equal(3)
            local d1 = WorldContext.parseName("Hell_1")
            expect(d1.realm).to.equal("hell")
            expect(d1.depth).to.equal(1)
        end)

        it("is case-insensitive and tolerates no separator", function()
            expect(WorldContext.parseName("heaven5").realm).to.equal("heaven")
            expect(WorldContext.parseName("heaven5").depth).to.equal(5)
            expect(WorldContext.parseName("HELL_2").depth).to.equal(2)
        end)

        it("defaults a bare Heaven/Hell to depth 1", function()
            expect(WorldContext.parseName("Heaven").depth).to.equal(1)
            expect(WorldContext.parseName("Hell").depth).to.equal(1)
        end)

        it("returns nil for non-world names", function()
            expect(WorldContext.parseName("Game")).to.equal(nil)
            expect(WorldContext.parseName("BaddieSpawnerDesert")).to.equal(nil)
            expect(WorldContext.parseName(123)).to.equal(nil)
        end)
    end)

    describe("WorldContext.realmOfZoneId", function()
        it("maps realm zone ids (<World>_<Floor>) to their realm", function()
            expect(WorldContext.realmOfZoneId("Heaven_1_Lava")).to.equal("heaven")
            expect(WorldContext.realmOfZoneId("Hell_1_Ice")).to.equal("hell")
            expect(WorldContext.realmOfZoneId("Heaven_3_Grass")).to.equal("heaven")
        end)

        it("treats bare homeworld biome zones as base", function()
            expect(WorldContext.realmOfZoneId("Lava")).to.equal("base")
            expect(WorldContext.realmOfZoneId("Desert")).to.equal("base")
            expect(WorldContext.realmOfZoneId("Spawn")).to.equal("base")
        end)

        it("is safe on nil / non-string", function()
            expect(WorldContext.realmOfZoneId(nil)).to.equal("base")
            expect(WorldContext.realmOfZoneId(123)).to.equal("base")
        end)
    end)

    describe("WorldContext.difficultyFor", function()
        local CFG = { step = 0.5, realm_base = { base = 1.0, heaven = 1.0, hell = 1.0 } }

        it("is the realm base at depth 0", function()
            expect(WorldContext.difficultyFor("base", 0, CFG)).to.equal(1.0)
        end)

        it("ramps by step per depth", function()
            expect(WorldContext.difficultyFor("hell", 3, CFG)).to.equal(2.5)
            expect(WorldContext.difficultyFor("heaven", 5, CFG)).to.equal(3.5)
        end)

        it("honors a per-realm base offset", function()
            local cfg = { step = 1, realm_base = { hell = 2.0 } }
            expect(WorldContext.difficultyFor("hell", 2, cfg)).to.equal(4.0)
        end)

        it("defaults safely with no config (1.0 + 0.5/depth)", function()
            expect(WorldContext.difficultyFor("heaven", 2)).to.equal(2.0)
        end)
    end)
end
