local PlayerSpawnSpread = loadModule("src/Shared/Game/PlayerSpawnSpread.lua")
local areas = loadModule("configs/areas.lua")

local function distance(a, b)
    local dx = a.x - b.x
    local dz = a.z - b.z
    return math.sqrt(dx * dx + dz * dz)
end

return function()
    describe("PlayerSpawnSpread", function()
        it("builds two staggered rings with room for a full public server", function()
            local candidates = PlayerSpawnSpread.candidates({
                ring_spacing = 8,
                ring_count = 2,
                slots_per_ring = 8,
            })
            expect(#candidates).to.equal(24)
            for i = 1, #candidates do
                for j = i + 1, #candidates do
                    expect(distance(candidates[i], candidates[j]) >= 6).to.equal(true)
                end
            end
        end)

        it("gives one user a stable preferred slot", function()
            local first, firstIndex = PlayerSpawnSpread.choose(12345, {})
            local second, secondIndex = PlayerSpawnSpread.choose(12345, {})
            expect(firstIndex).to.equal(secondIndex)
            expect(first.x).to.equal(second.x)
            expect(first.z).to.equal(second.z)
        end)

        it("moves a colliding user to the next clear slot", function()
            local preferred, preferredIndex = PlayerSpawnSpread.choose(7, {})
            local chosen, chosenIndex = PlayerSpawnSpread.choose(7, { preferred })
            expect(chosenIndex == preferredIndex).to.equal(false)
            expect(distance(chosen, preferred) >= 6).to.equal(true)
        end)

        it("treats negative Studio user ids the same as live ids", function()
            local live, liveIndex = PlayerSpawnSpread.choose(17, {})
            local studio, studioIndex = PlayerSpawnSpread.choose(-17, {})
            expect(studioIndex).to.equal(liveIndex)
            expect(studio.x).to.equal(live.x)
            expect(studio.z).to.equal(live.z)
        end)

        it("selects the least-crowded slot when every candidate is occupied", function()
            local candidates = PlayerSpawnSpread.candidates({
                ring_count = 1,
                slots_per_ring = 2,
            })
            local chosen = PlayerSpawnSpread.choose(0, candidates, {
                ring_count = 1,
                slots_per_ring = 2,
                minimum_separation = 100,
            })
            expect(chosen ~= nil).to.equal(true)
            expect(math.abs(chosen.x) > 0 or math.abs(chosen.z) > 0).to.equal(true)
        end)

        it("ships enough configured slots for a full public server", function()
            local config = areas.player_spawn_spread
            expect(config.enabled).to.equal(true)
            expect(#PlayerSpawnSpread.candidates(config)).to.equal(24)
            expect(config.minimum_separation).to.equal(6)
        end)

        it("is wired into canonical ZoneService placement", function()
            local source = readFile("src/Server/Services/ZoneService.lua")
            expect(source:find("PlayerSpawnSpread.choose", 1, true) ~= nil).to.equal(true)
            expect(source:find("options.spread == false", 1, true) ~= nil).to.equal(true)
        end)
    end)
end
