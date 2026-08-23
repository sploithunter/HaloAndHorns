local ChallengeRun = loadModule("src/Shared/Game/ChallengeRun.lua")
local Enhancements = loadModule("src/Shared/Game/Enhancements.lua")
local enhCfg = loadModule("configs/enhancements.lua")
local challengeCfg = loadModule("configs/challenge_runs.lua")

local RANGE = {
    rooms = 99,
    hp_growth = 1.07,
    dmg_growth = 1.045,
    count_every = 6,
    count_cap = 8,
    lieutenant_at = 10,
    boss_at = 25,
}

local TRAINING = {
    rooms = 99,
    hp_growth = 1.04,
    dmg_growth = 1.025,
    count_every = 10,
    count_cap = 5,
    lieutenant_at = 16,
    boss_at = 40,
}

return function()
    describe("ChallengeRun", function()
        it("exclusive-allows only the picked catalog powers", function()
            expect(ChallengeRun.allowsPower(nil, "swift")).to.equal(true)
            expect(ChallengeRun.allowsPower({ "sunder", "hasten" }, "hasten")).to.equal(true)
            expect(ChallengeRun.allowsPower({ "sunder", "hasten" }, "swift")).to.equal(false)
            expect(ChallengeRun.allowsPower({}, "magnet")).to.equal(false)
        end)

        it("auto-slots Hasten with 6 recharge and others 3/3", function()
            local slotting = challengeCfg.modes.range.catalog.slotting
            local hasten = ChallengeRun.defaultSlots("hasten", slotting, "sandwalker")
            expect(#hasten).to.equal(6)
            for i = 1, 6 do
                expect(hasten[i].enh.type).to.equal("recharge")
            end
            local axes = Enhancements.aggregate(enhCfg, hasten, 50)
            expect(axes.recharge >= 1.9).to.equal(true)

            local sunder = ChallengeRun.defaultSlots("sunder", slotting, "sandwalker")
            expect(#sunder).to.equal(6)
            expect(sunder[1].enh.type).to.equal("recharge")
            expect(sunder[4].enh.type).to.equal("focus")
            local mixed = Enhancements.aggregate(enhCfg, sunder, 50)
            expect(mixed.recharge >= 0.9).to.equal(true)
            expect(mixed.focus >= 0.9).to.equal(true)
        end)

        it("names every room's layout context without player salt", function()
            expect(ChallengeRun.layoutContext(1)).to.equal("room#1")
            expect(ChallengeRun.layoutContext("12")).to.equal("room#12")
            expect(ChallengeRun.layoutContext(0)).to.equal("room#1")
            expect(ChallengeRun.layoutContext(nil)).to.equal("room#1")
            expect(ChallengeRun.layoutContext(1, "range")).to.equal("room#1")
            expect(ChallengeRun.layoutContext(1, "training_ground")).to.equal("train#1")
            expect(ChallengeRun.layoutContext(4, "training_ground")).never.to.equal(
                ChallengeRun.layoutContext(4, "range")
            )
        end)

        it("teaches on Room 1 with one chamber and two trash", function()
            local range = challengeCfg.modes.range.curve
            local room1 = ChallengeRun.packForRoom(range, 1)
            expect(room1.intro_only).to.equal(true)
            expect(room1.tile_budget).to.equal(2)
            expect(room1.target_depth.min).to.equal(1)
            expect(room1.add_lieutenant).to.equal(false)
            expect(room1.add_boss).to.equal(false)
            expect(room1.hp_mult).to.equal(1)
            expect(room1.dmg_mult).to.equal(1)
            local packs = ChallengeRun.filterPacks({
                { weight = 10, intro = true, units = { { enemy = "lava_imp", count = 2 } } },
                { weight = 10, units = { { enemy = "lava_imp", count = 3 } } },
                { weight = 4, lieutenant = true, units = { { enemy = "ember_brute", count = 1 } } },
                { weight = 2, boss = true, units = { { enemy = "infernal_boss", count = 1 } } },
            }, room1)
            expect(#packs).to.equal(1)
            expect(packs[1].intro).to.equal(true)
            expect(packs[1].units[1].count).to.equal(2)
            local train = challengeCfg.modes.training_ground.curve
            local room2 = ChallengeRun.packForRoom(train, 2)
            expect(room2.intro_only).to.equal(true)
            expect(room2.tile_budget).to.equal(3)
            local room3 = ChallengeRun.packForRoom(train, 3)
            expect(room3.intro_only).to.equal(false)
            expect(room3.tile_budget).to.equal(3)
        end)

        it("keeps Magma Wyrm and lieutenants out of early rooms", function()
            local packs = {
                { weight = 10, units = { { enemy = "lava_imp", count = 3 } } },
                { weight = 4, lieutenant = true, units = { { enemy = "ember_brute", count = 1 } } },
                { weight = 2, boss = true, units = { { enemy = "infernal_boss", count = 1 } } },
            }
            local room1 = ChallengeRun.filterPacks(packs, ChallengeRun.packForRoom(RANGE, 1))
            expect(#room1).to.equal(1)
            expect(room1[1].units[1].enemy).to.equal("lava_imp")
            local mid = ChallengeRun.filterPacks(packs, ChallengeRun.packForRoom(RANGE, 10))
            expect(#mid).to.equal(2)
            local late = ChallengeRun.filterPacks(packs, ChallengeRun.packForRoom(RANGE, 25))
            expect(#late).to.equal(3)
            expect(late[3].boss).to.equal(true)
        end)

        it("is deterministic and starts at identity multipliers", function()
            local a = ChallengeRun.packForRoom(RANGE, 1)
            local b = ChallengeRun.packForRoom(RANGE, 1)
            expect(a.hp_mult).to.equal(1)
            expect(a.dmg_mult).to.equal(1)
            expect(a.count_mult).to.equal(1)
            expect(a.hp_mult).to.equal(b.hp_mult)
            expect(a.add_boss).to.equal(false)
        end)

        it("makes elite/Colorado rooms lethal well before 99", function()
            local mid = ChallengeRun.packForRoom(RANGE, 30)
            local wall = ChallengeRun.packForRoom(RANGE, 99)
            expect(mid.hp_mult > 6).to.equal(true)
            expect(mid.dmg_mult > 3).to.equal(true)
            expect(mid.count_mult >= 5).to.equal(true)
            expect(mid.add_lieutenant).to.equal(true)
            expect(mid.add_boss).to.equal(true)
            expect(wall.hp_mult > 200).to.equal(true)
            expect(wall.dmg_mult > 50).to.equal(true)
            expect(wall.count_mult).to.equal(8)
        end)

        it("keeps Training Ground easier than Range at the same room", function()
            local range40 = ChallengeRun.packForRoom(RANGE, 40)
            local train40 = ChallengeRun.packForRoom(TRAINING, 40)
            expect(train40.hp_mult < range40.hp_mult).to.equal(true)
            expect(train40.dmg_mult < range40.dmg_mult).to.equal(true)
            expect(train40.count_mult < range40.count_mult).to.equal(true)
            expect(ChallengeRun.packForRoom(TRAINING, 39).add_boss).to.equal(false)
        end)

        it("persists only a higher best room", function()
            expect(ChallengeRun.bestRoom(12, 8)).to.equal(12)
            expect(ChallengeRun.bestRoom(12, 19)).to.equal(19)
            expect(ChallengeRun.bestRoom(nil, 3)).to.equal(3)
            expect(ChallengeRun.bestRoom(4, 0)).to.equal(4)
        end)

        it("ranks the best room inside the configured release window", function()
            local window, cap, sweep, boundary = ChallengeRun.leaderboardWindow(challengeCfg)
            expect(window).to.equal(24 * 60 * 60)
            expect(cap >= 1).to.equal(true)
            expect(sweep).to.equal(5 * 60)
            expect(boundary).to.equal("mountain_midnight")
            expect(ChallengeRun.recentChanged({ { room = 12, at = 1 } }, { { room = 12, at = 1 } })).to.equal(
                false
            )
            expect(ChallengeRun.recentChanged({ { room = 12, at = 1 } }, {})).to.equal(true)

            local now = 2_000_000
            local first = ChallengeRun.writeWindowAttempt(nil, 12, now - 900, {
                window_seconds = window,
                recent_cap = cap,
            })
            expect(first.best_room).to.equal(12)
            expect(ChallengeRun.windowBest(first.recent, now, window)).to.equal(12)

            local second = ChallengeRun.writeWindowAttempt(first, 8, now - 60, {
                window_seconds = window,
                recent_cap = cap,
            })
            expect(second.best_room).to.equal(12)
            expect(ChallengeRun.windowBest(second.recent, now, window)).to.equal(12)
            expect(ChallengeRun.windowBest(second.recent, now + window, window)).to.equal(0)

            local expired = ChallengeRun.writeWindowAttempt({
                best_room = 20,
                recent = { { room = 20, at = now - window } },
            }, 0, now, { window_seconds = window, recent_cap = cap })
            expect(expired.best_room).to.equal(20)
            expect(ChallengeRun.windowBest(expired.recent, now, window)).to.equal(0)
        end)

        it("keeps fixed leaderboard rounds clock-aligned and excludes the prior round", function()
            local window = 30 * 60
            local now = 3 * window + 120
            expect(ChallengeRun.fixedWindowStart(now, window)).to.equal(3 * window)

            local best, startedAt = ChallengeRun.fixedWindowBest({
                { room = 30, at = 3 * window - 1 },
                { room = 12, at = 3 * window },
                { room = 18, at = now },
            }, now, window)
            expect(startedAt).to.equal(3 * window)
            expect(best).to.equal(18)
        end)

        it("aligns release rounds to Mountain midnight across DST", function()
            local window = 24 * 60 * 60
            local boundary = "mountain_midnight"
            local now = 1787409863
            expect(ChallengeRun.fixedWindowStart(now, window, boundary)).to.equal(1787378400)
            expect(ChallengeRun.fixedWindowEnd(1787378400, window, boundary)).to.equal(1787464800)

            local best, startedAt = ChallengeRun.fixedWindowBest({
                { room = 99, at = 1787378399 },
                { room = 21, at = 1787378400 },
                { room = 34, at = now },
            }, now, window, boundary)
            expect(startedAt).to.equal(1787378400)
            expect(best).to.equal(34)

            expect(ChallengeRun.fixedWindowEnd(1772953200, window, boundary)).to.equal(1773036000)
            expect(ChallengeRun.fixedWindowEnd(1793512800, window, boundary)).to.equal(1793602800)
        end)

        it("retains the full 25-hour fall-back round when pruning attempts", function()
            local window = 24 * 60 * 60
            local boundary = "mountain_midnight"
            local nearFallRoundEnd = 1793602799
            local recent = ChallengeRun.pruneWindow({
                { room = 80, at = 1793512799 },
                { room = 60, at = 1793512800 },
                { room = 50, at = nearFallRoundEnd },
            }, nearFallRoundEnd, window, 48, boundary)
            expect(#recent).to.equal(2)
            expect(recent[1].at).to.equal(1793512800)
            expect(recent[2].at).to.equal(nearFallRoundEnd)
        end)

        it("treats a fully downed squad as a wipe and blocks revives", function()
            expect(ChallengeRun.squadWiped({})).to.equal(false)
            expect(ChallengeRun.squadWiped({ { downed = true }, { downed = false } })).to.equal(
                false
            )
            expect(ChallengeRun.squadWiped({ { downed = true }, { downed = true } })).to.equal(true)
            expect(ChallengeRun.canRevive({ no_pet_revives = true })).to.equal(false)
            expect(ChallengeRun.canRevive({})).to.equal(true)
            expect(ChallengeRun.canResummon({ no_pet_revives = true })).to.equal(false)
            expect(ChallengeRun.canResummon({})).to.equal(true)
        end)

        it("allows roster swaps in the entrance tile and locks them past it", function()
            local map = {
                ox = 100,
                oz = 200,
                rooms = {
                    { class = "entrance", x = 0, z = 0, hx = 48, hz = 48 },
                    { class = "room", x = 96, z = 0, hx = 48, hz = 48 },
                },
            }
            expect(ChallengeRun.inEntryRoom(map, 100, 200)).to.equal(true)
            expect(ChallengeRun.inEntryRoom(map, 196, 200)).to.equal(false)
            expect(ChallengeRun.gauntletRosterLocked(true, map, 100, 200)).to.equal(false)
            expect(ChallengeRun.gauntletRosterLocked(true, map, 196, 200)).to.equal(true)
            expect(ChallengeRun.gauntletRosterLocked(false, map, 196, 200)).to.equal(false)
            expect(ChallengeRun.gauntletRosterLocked(true, nil, 196, 200)).to.equal(false)
        end)

        it("sanitizes catalog picks and falls back to defaults", function()
            local catalog = {
                pet_slots = 3,
                power_slots = 2,
                pets = {
                    { pet = "colorado", variant = "rainbow", huge = true, default = true },
                    { pet = "portal_drake", variant = "gold", default = true },
                    { pet = "blade_lynx", variant = "basic" },
                },
                powers = { "sunder", "taunt", "revive" },
                default_powers = { "sunder", "taunt" },
            }
            local picked = ChallengeRun.sanitizeLoadout(catalog, {
                { pet = "blade_lynx" },
                { pet = "not_real" },
                { pet = "colorado" },
                { pet = "colorado" },
            }, { "taunt", "hack", "sunder", "sunder" })
            expect(#picked.pets).to.equal(3)
            expect(picked.pets[1].pet).to.equal("blade_lynx")
            expect(picked.pets[2].pet).to.equal("colorado")
            expect(picked.pets[2].variant).to.equal("rainbow")
            expect(picked.pets[2].huge).to.equal(true)
            expect(picked.pets[3].pet).to.equal("portal_drake")
            expect(#picked.powers).to.equal(2)
            expect(picked.powers[1]).to.equal("taunt")
            expect(picked.powers[2]).to.equal("sunder")

            local fallback = ChallengeRun.sanitizeLoadout(catalog, {}, {})
            expect(#fallback.pets).to.equal(2)
            expect(fallback.pets[1].pet).to.equal("colorado")
            expect(fallback.powers[1]).to.equal("sunder")
            expect(fallback.pets[2].variant).to.equal("golden")

            local migrated = ChallengeRun.sanitizeLoadout(challengeCfg.modes.range.catalog, {
                { pet = "colorado", variant = "rainbow", huge = true },
                { pet = "colorado_creator", variant = "rainbow", huge = true },
                { pet = "portal_drake", variant = "golden", huge = true },
            }, {})
            local migratedIds = {}
            for _, row in ipairs(migrated.pets) do
                migratedIds[row.pet] = row
                expect(row.huge).to.equal(false)
            end
            expect(migratedIds.colorado.variant).to.equal("basic")
            expect(migratedIds.kade).to.be.ok()
            expect(migratedIds.portal_drake.variant).to.equal("golden")
            expect(migratedIds.colorado_creator).to.equal(nil)
            expect(#migrated.pets).to.equal(5)

            local open = ChallengeRun.sanitizeLoadout({
                pet_slots = 1,
                power_slots = 6,
                pets = { { pet = "colorado", default = true } },
                powers = "all",
                default_powers = { "sunder" },
            }, {}, { "fear", "sunder", "not_a_list_gate" })
            expect(#open.powers).to.equal(3)
            expect(open.powers[1]).to.equal("fear")
        end)

        it("keeps one Range kit per origin and remembers the last used", function()
            local catalog = challengeCfg.modes.range.catalog
            expect(ChallengeRun.soloOnly(challengeCfg.modes.range)).to.equal(true)
            expect(ChallengeRun.soloOnly(challengeCfg.modes.training_ground)).to.equal(false)
            expect(ChallengeRun.effectiveLevel(challengeCfg.modes.range)).to.equal(50)
            expect(ChallengeRun.xpYieldLevel(challengeCfg.modes.range, 3, 50)).to.equal(3)
            expect(ChallengeRun.xpYieldLevel(challengeCfg.modes.range, 50, 50)).to.equal(50)
            expect(ChallengeRun.xpYieldMult(challengeCfg.modes.range)).to.equal(1)
            expect(ChallengeRun.xpYieldLevel(challengeCfg.modes.training_ground, 3, 8)).to.equal(8)
            expect(ChallengeRun.xpYieldLevel(nil, 3, 50)).to.equal(50)
            expect(ChallengeRun.xpYieldLevel({ xp_from = "earned_level" }, nil, 50)).to.equal(1)
            expect(ChallengeRun.xpYieldMult(nil)).to.equal(1)
            expect(ChallengeRun.xpYieldMult({ xp_mult = -1 })).to.equal(1)
            expect(ChallengeRun.xpYieldMult({ xp_mult = 0.25 })).to.equal(0.25)
            expect(ChallengeRun.effectiveLevel(challengeCfg.modes.training_ground)).to.equal(nil)
            expect(ChallengeRun.effectiveLevel(nil)).to.equal(nil)
            expect(ChallengeRun.effectiveLevel({ effective_level = 0 })).to.equal(nil)
            expect(ChallengeRun.effectiveLevel({ effective_level = "50" })).to.equal(50)
            expect(ChallengeRun.passesEngageGate(50, 3, 5)).to.equal(true)
            expect(ChallengeRun.passesEngageGate(3, 3, 5)).to.equal(false)
            expect(ChallengeRun.passesEngageGate(nil, 5, 5)).to.equal(true)
            expect(ChallengeRun.passesEngageGate(nil, 4, 5)).to.equal(false)
            expect(ChallengeRun.passesEngageGate(50, 3, 1)).to.equal(true)
            expect(ChallengeRun.skipsEngageGate(challengeCfg.modes.training_ground)).to.equal(true)
            expect(ChallengeRun.skipsEngageGate(challengeCfg.modes.range)).to.equal(false)
            expect(ChallengeRun.usesHallCurrencyHud(challengeCfg.modes.range)).to.equal(false)
            expect(ChallengeRun.usesHallCurrencyHud(challengeCfg.modes.training_ground)).to.equal(
                false
            )
            expect(ChallengeRun.usesHallCurrencyHud(nil)).to.equal(false)
            expect(ChallengeRun.passesEngageGate(3, 3, 5, challengeCfg.modes.training_ground)).to.equal(
                true
            )
            expect(ChallengeRun.canonicalOrigin("pyromancer", ChallengeRun.knownOrigins(catalog))).to.equal(
                "pyromancer"
            )
            expect(ChallengeRun.canonicalOrigin("wizard", ChallengeRun.knownOrigins(catalog))).to.equal(
                nil
            )

            local first = ChallengeRun.writeRangeDefaults(nil, catalog, {
                origin = "pyromancer",
                pets = { { pet = "blade_lynx", variant = "golden" } },
                powers = { "strike", "scorch", "genie_dunes", "strike" },
            })
            expect(first.last_origin).to.equal("pyromancer")
            expect(first.pets[1].pet).to.equal("blade_lynx")
            expect(first.by_origin.pyromancer.powers[1]).to.equal("strike")
            expect(first.by_origin.pyromancer.powers[2]).to.equal("scorch")
            expect(first.by_origin.geomancer).to.equal(nil)

            local second = ChallengeRun.writeRangeDefaults(first, catalog, {
                origin = "geomancer",
                pets = { { pet = "atlas_golem", variant = "golden" } },
                powers = { "sunder", "taunt" },
            })
            expect(second.last_origin).to.equal("geomancer")
            expect(second.pets[1].pet).to.equal("atlas_golem")
            expect(second.by_origin.pyromancer.powers[1]).to.equal("strike")
            expect(second.by_origin.geomancer.powers[1]).to.equal("sunder")

            local read = ChallengeRun.readRangeDefaults({
                last_origin = "not_real",
                pets = { { pet = "not_a_pet" } },
                by_origin = {
                    pyromancer = { powers = { "genie_dunes", "strike" } },
                    wizard = { powers = { "strike" } },
                },
            }, catalog)
            expect(read.last_origin).to.equal(nil)
            expect(read.by_origin.wizard).to.equal(nil)
            expect(read.by_origin.pyromancer.powers[1]).to.equal("strike")
            expect(ChallengeRun.powersForOrigin(second, "pyromancer", catalog)[1]).to.equal(
                "strike"
            )
        end)
    end)
end
