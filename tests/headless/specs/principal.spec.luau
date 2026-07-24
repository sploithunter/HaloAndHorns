--[[
    Principal — [unit]. The player-or-NPC abstraction that lets the Creator summon own pets and
    anchor a real alliance (docs/CREATOR_SUMMON.md). Run: mise run test-headless
]]

local Principal = loadModule("src/Shared/Game/Principal.lua")

-- Fake Roblox surface: the module takes every lookup through ctx precisely so this works.
local function fakePlayer(name, character)
    return { Name = name, Character = character or { fake = "character" } }
end

local function ctxWith(players, levels)
    local byName = {}
    for _, p in ipairs(players) do
        byName[p.Name] = p
    end
    return {
        findPlayer = function(name)
            return byName[name]
        end,
        earnedLevel = function(player)
            return levels and levels[player.Name]
        end,
        players = function()
            return players
        end,
    }
end

return function()
    describe("Principal.resolve", function()
        it("resolves a live player, carrying the Player through as .instance", function()
            Principal.reset()
            local alice = fakePlayer("Alice")
            local p = Principal.resolve("Alice", ctxWith({ alice }, { Alice = 27 }))
            expect(p).to.be.ok()
            expect(p.kind).to.equal(Principal.KIND_PLAYER)
            expect(p.level).to.equal(27)
            -- the migration contract: mid-migration call sites still want the Player object
            expect(p.instance).to.equal(alice)
        end)

        it("resolves a registered NPC by the same name-based reference", function()
            Principal.reset()
            Principal.register({ name = "Colorado", level = 50 })
            local p = Principal.resolve("Colorado", ctxWith({}, {}))
            expect(p).to.be.ok()
            expect(p.kind).to.equal(Principal.KIND_NPC)
            expect(p.level).to.equal(50)
        end)

        it("returns nil for an unknown name, and for an empty one", function()
            Principal.reset()
            local ctx = ctxWith({}, {})
            expect(Principal.resolve("Nobody", ctx)).to.equal(nil)
            expect(Principal.resolve("", ctx)).to.equal(nil)
            expect(Principal.resolve(nil, ctx)).to.equal(nil)
        end)

        it("a real PLAYER always wins a name collision with an NPC", function()
            -- AllianceAnchor / AllianceWith are name-based; if an NPC could shadow a player,
            -- a reference would silently mis-resolve to the wrong entity.
            Principal.reset()
            Principal.register({ name = "Colorado", level = 50 })
            local realColorado = fakePlayer("Colorado")
            local p = Principal.resolve("Colorado", ctxWith({ realColorado }, { Colorado = 8 }))
            expect(p.kind).to.equal(Principal.KIND_PLAYER)
            expect(p.level).to.equal(8)
        end)
    end)

    describe("Principal.all — who gets ticked", function()
        it("includes registered NPCs alongside live players", function()
            -- The whole point: PetFollowService:_tick used Players:GetPlayers(), so an NPC's
            -- pet folder was never driven — no movement, no combat.
            Principal.reset()
            Principal.register({ name = "Colorado", level = 50 })
            local all = Principal.all(ctxWith({ fakePlayer("Alice") }, { Alice = 6 }))
            expect(#all).to.equal(2)
            local names = {}
            for _, p in ipairs(all) do
                names[p.name] = p.kind
            end
            expect(names.Alice).to.equal(Principal.KIND_PLAYER)
            expect(names.Colorado).to.equal(Principal.KIND_NPC)
        end)

        it("is just the players when nothing is registered", function()
            Principal.reset()
            local all = Principal.all(ctxWith({ fakePlayer("Alice") }, { Alice = 6 }))
            expect(#all).to.equal(1)
        end)
    end)

    describe("Principal.register / unregister", function()
        it("defaults the pet folder to the principal's own name (player convention)", function()
            Principal.reset()
            local rec = Principal.register({ name = "Colorado", level = 50 })
            expect(Principal.petFolderName(rec)).to.equal("Colorado")
        end)

        it("honours an explicit pet folder name", function()
            Principal.reset()
            local rec = Principal.register({ name = "Colorado", petFolderName = "Colorado_NPC" })
            expect(Principal.petFolderName(rec)).to.equal("Colorado_NPC")
        end)

        it("rejects a nameless record instead of registering a ghost", function()
            Principal.reset()
            local ok, err = Principal.register({ level = 50 })
            expect(ok).to.equal(nil)
            expect(err).to.be.ok()
        end)

        it("unregister removes it from resolution and from the tick set", function()
            Principal.reset()
            Principal.register({ name = "Colorado", level = 50 })
            expect(Principal.unregister("Colorado")).to.equal(true)
            expect(Principal.resolve("Colorado", ctxWith({}, {}))).to.equal(nil)
            expect(#Principal.all(ctxWith({}, {}))).to.equal(0)
            -- second unregister is a no-op, not an error (despawn paths can be re-entrant)
            expect(Principal.unregister("Colorado")).to.equal(false)
        end)
    end)

    describe("Principal.levelOf — the anchor seam", function()
        it("reads an NPC's authored level, so a level-50 Creator can anchor", function()
            Principal.reset()
            local rec = Principal.register({ name = "Colorado", level = 50 })
            expect(Principal.levelOf(rec)).to.equal(50)
        end)

        it("floors at 1 and survives junk", function()
            Principal.reset()
            expect(Principal.levelOf(Principal.register({ name = "X", level = 0 }))).to.equal(1)
            expect(Principal.levelOf(Principal.register({ name = "Y", level = -5 }))).to.equal(1)
            expect(Principal.levelOf(nil)).to.equal(1)
        end)
    end)
end
