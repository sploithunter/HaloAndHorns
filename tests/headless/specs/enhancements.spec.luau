--[[
    Enhancements (pure core) — [unit] grades, usability, compatibility, aggregation.
    Run: mise run test-headless
]]

local Enhancements = loadModule("src/Shared/Game/Enhancements.lua")
local PowerStats = loadModule("src/Shared/Game/PowerStats.lua")
local cfg = loadModule("configs/enhancements.lua")
local powersCfg = loadModule("configs/powers.lua")

local PYRO_DMG = { type = "damage", origins = { "pyromancer" } }
local GEO_CRYO_RCH = { type = "recharge", origins = { "geomancer", "cryomancer" } }

return function()
    describe("Enhancement records (grades + validity)", function()
        it("classifies single vs dual", function()
            expect(Enhancements.isSingle(PYRO_DMG)).to.equal(true)
            expect(Enhancements.isDual(PYRO_DMG)).to.equal(false)
            expect(Enhancements.isDual(GEO_CRYO_RCH)).to.equal(true)
        end)

        it(
            "natural grade: origin-less, usable by anyone (incl. pre-origin), weakest value",
            function()
                local nat = { type = "damage", origins = {}, level = 1 }
                expect(Enhancements.isNatural(nat)).to.equal(true)
                expect(Enhancements.usableBy(nat, nil)).to.equal(true) -- level 4, no origin chosen
                expect(Enhancements.usableBy(nat, "pyromancer")).to.equal(true)
                expect(Enhancements.value(cfg, nat)).to.equal(0.15)
                expect(Enhancements.displayName(cfg, nat)).to.equal("Natural Damage")
                -- origined gear still gated: nil archetype can't use it
                expect(Enhancements.usableBy({ type = "damage", origins = { "pyromancer" } }, nil)).to.equal(
                    false
                )
            end
        )

        it("rejects malformed records", function()
            -- origins = {} is the NATURAL grade now (origin-less generic), not malformed
            expect(Enhancements.isValid(cfg, { type = "damage", origins = {} })).to.equal(true)
            expect(Enhancements.isValid(cfg, { type = "damage" })).to.equal(false) -- no origins table
            expect(Enhancements.isValid(cfg, { type = "nope", origins = { "pyromancer" } })).to.equal(
                false
            )
            expect(
                Enhancements.isValid(
                    cfg,
                    { type = "damage", origins = { "pyromancer", "pyromancer" } }
                )
            ).to.equal(false)
            expect(Enhancements.isValid(cfg, { type = "damage", origins = { "not_an_origin" } })).to.equal(
                false
            )
        end)

        it("single-origin is worth MORE than dual-origin (Jason's rule)", function()
            local single = Enhancements.value(cfg, PYRO_DMG)
            local dual = Enhancements.value(cfg, GEO_CRYO_RCH)
            expect(single > dual).to.equal(true)
            expect(single).to.equal(cfg.values.single)
            expect(dual).to.equal(cfg.values.dual)
        end)
    end)

    describe("Usability (player origin must be among the enhancement's origins)", function()
        it("single: only the matching origin", function()
            expect(Enhancements.usableBy(PYRO_DMG, "pyromancer")).to.equal(true)
            expect(Enhancements.usableBy(PYRO_DMG, "cryomancer")).to.equal(false)
        end)

        it("dual: either of its two origins", function()
            expect(Enhancements.usableBy(GEO_CRYO_RCH, "geomancer")).to.equal(true)
            expect(Enhancements.usableBy(GEO_CRYO_RCH, "cryomancer")).to.equal(true)
            expect(Enhancements.usableBy(GEO_CRYO_RCH, "sandwalker")).to.equal(false)
        end)
    end)

    describe("Type-vs-power compatibility", function()
        local kinds = powersCfg.effect_kinds

        it("healing fits a heal power, not a shield power", function()
            -- restoring_sands = heal family; dune_shield = absorb family (live config)
            local heal = powersCfg.powers.restoring_sands
            local shield = powersCfg.powers.dune_shield
            expect((Enhancements.compatibleWith(cfg, "healing", heal, kinds))).to.equal(true)
            local ok, reason = Enhancements.compatibleWith(cfg, "healing", shield, kinds)
            expect(ok).to.equal(false)
            expect(reason).to.equal("wrong_family")
        end)

        it("range is BLOCKED on a single-target shield (not a radius family)", function()
            -- range now lists only radius-consuming families (magnet/burst/cleave/spread); a
            -- single-target shield isn't one, so it's gated out (was the melee/AoE rule before).
            local singleTarget = powersCfg.powers.dune_shield -- absorb family, target = single_pet
            local ok, reason = Enhancements.compatibleWith(cfg, "range", singleTarget, kinds)
            expect(ok).to.equal(false)
            expect(reason).to.equal("wrong_family")
        end)
        it("range fits a radius family (Wildfire's spread)", function()
            local wildfire = powersCfg.powers.wildfire -- burn_spread, AoE
            expect((Enhancements.compatibleWith(cfg, "range", wildfire, kinds))).to.equal(true)
        end)

        it("recharge fits anything (families = *)", function()
            expect(
                (Enhancements.compatibleWith(cfg, "recharge", powersCfg.powers.dune_shield, kinds))
            ).to.equal(true)
            expect(
                (
                    Enhancements.compatibleWith(
                        cfg,
                        "recharge",
                        powersCfg.powers.restoring_sands,
                        kinds
                    )
                )
            ).to.equal(true)
        end)

        it("Windfall (drop_rate) accepts recharge, duration AND potency", function()
            -- Jason: Windfall has magnitude=2.0 + duration=10, so all three axes should apply,
            -- not just recharge. Guards the drop_rate family staying in duration/potency.families.
            local windfall = powersCfg.powers.windfall
            expect((Enhancements.compatibleWith(cfg, "recharge", windfall, kinds))).to.equal(true)
            expect((Enhancements.compatibleWith(cfg, "duration", windfall, kinds))).to.equal(true)
            expect((Enhancements.compatibleWith(cfg, "potency", windfall, kinds))).to.equal(true)
        end)

        it("focus fits always-on toggles (the opposite of recharge)", function()
            -- recharge EXCLUDES passives (nothing to shorten); focus is exactly FOR them — their
            -- per-second upkeep is the drain a Focus enhancement lowers. (Swift = an always-on toggle;
            -- Hasten is no longer one — it's a timed click now, so recharge DOES apply to it.)
            local swift = powersCfg.powers.swift
            expect((Enhancements.compatibleWith(cfg, "recharge", swift, kinds))).to.equal(false)
            expect((Enhancements.compatibleWith(cfg, "focus", swift, kinds))).to.equal(true)
        end)
    end)

    describe("Aggregation (per-axis additive)", function()
        it("sums same-axis values and skips empty/inherent slots", function()
            local slots = {
                { inherent = true },
                { enh = PYRO_DMG },
                {},
                { enh = { type = "damage", origins = { "geomancer", "pyromancer" } } },
                { enh = GEO_CRYO_RCH },
            }
            local axes = Enhancements.aggregate(cfg, slots)
            -- damage: single (0.33) + dual (0.20) = 0.53; recharge: dual (0.20)
            expect(math.abs(axes.damage - (cfg.values.single + cfg.values.dual)) < 1e-9).to.equal(
                true
            )
            expect(math.abs(axes.recharge - cfg.values.dual) < 1e-9).to.equal(true)
        end)

        it("returns empty for no slots", function()
            expect(next(Enhancements.aggregate(cfg, {}))).to.equal(nil)
        end)

        it("focus aggregates on its own axis (drives upkeep + cast-cost reduction)", function()
            local slots = { { enh = { type = "focus", origins = { "geomancer" } } } }
            expect(math.abs(Enhancements.aggregate(cfg, slots).focus - cfg.values.single) < 1e-9).to.equal(
                true
            )
        end)
    end)

    describe("Display + badge", function()
        it("names singles and duals", function()
            expect(Enhancements.displayName(cfg, PYRO_DMG)).to.equal("Pyro Damage")
            expect(Enhancements.displayName(cfg, GEO_CRYO_RCH)).to.equal("Geo/Cryo Recharge")
        end)

        it("badge: single = same color group, dual = mixed", function()
            local s = Enhancements.badgeSpec(cfg, PYRO_DMG)
            expect(s.discOrigin).to.equal("pyromancer")
            expect(s.ringOrigin).to.equal("pyromancer")
            expect(s.single).to.equal(true)
            local d = Enhancements.badgeSpec(cfg, GEO_CRYO_RCH)
            expect(d.discOrigin).to.equal("geomancer")
            expect(d.ringOrigin).to.equal("cryomancer")
            expect(d.single).to.equal(false)
        end)
    end)

    describe("Effects at cast (PowerStats ctx.enhancements)", function()
        it("damage multiplies, recharge divides; unboosted axes untouched", function()
            local power = { rechargeBase = 300, damageBase = 100, durationBase = 60 }
            local eff = PowerStats.resolveEffective(power, {
                enhancements = { damage = 0.33, recharge = 0.33 },
            })
            expect(math.abs(eff.damage - 133) < 1e-9).to.equal(true)
            expect(math.abs(eff.recharge - 300 / 1.33) < 1e-6).to.equal(true)
            expect(eff.duration).to.equal(60) -- no duration enhancement slotted
        end)

        it("two singles on one axis stack additively (x1.66)", function()
            local eff = PowerStats.resolveEffective(
                { damageBase = 100 },
                { enhancements = { damage = 0.66 } }
            )
            expect(math.abs(eff.damage - 166) < 1e-9).to.equal(true)
        end)

        it("accuracy boost applies but stays clamped to 1", function()
            local eff = PowerStats.resolveEffective(
                { accuracyBase = 0.9 },
                { enhancements = { accuracy = 0.33 } }
            )
            expect(eff.accuracy).to.equal(1) -- 0.9 * 1.33 clamped
            local eff2 = PowerStats.resolveEffective(
                { accuracyBase = 0.6 },
                { enhancements = { accuracy = 0.33 } }
            )
            expect(math.abs(eff2.accuracy - 0.6 * 1.33) < 1e-9).to.equal(true)
        end)
    end)

    describe("Drop levels (area band + jitter)", function()
        it("stays within band +/- jitter, floored at 1 (home-world default 1-5 j2)", function()
            local rng = {
                NextInteger = function(_, lo, hi)
                    return lo -- deterministic: lowest of every roll
                end,
            }
            -- lowest possible: band lo (1) + jitter low (-2) -> clamped to 1
            expect(Enhancements.rollLevel(cfg, nil, rng)).to.equal(1)
            local rngHi = {
                NextInteger = function(_, lo, hi)
                    return hi -- highest of every roll
                end,
            }
            local band = cfg.drops.levels.bands.default
            local maxLvl = band[2] + cfg.drops.levels.jitter
            expect(Enhancements.rollLevel(cfg, nil, rngHi)).to.equal(maxLvl)
        end)

        it("unknown area falls back to the default band", function()
            local rng = {
                NextInteger = function(_, lo)
                    return lo
                end,
            }
            expect(Enhancements.rollLevel(cfg, "NoSuchArea", rng)).to.equal(1)
        end)

        -- FOLLOW-PLAYER (Jason: "level 8 and no new world to get higher ones"): past
        -- the band top the band slides with the player — { player-span .. player }.
        it("band follows a player past the area top", function()
            local rngLo = {
                NextInteger = function(_, lo)
                    return lo
                end,
            }
            local rngHi = {
                NextInteger = function(_, _, hi)
                    return hi
                end,
            }
            local span = cfg.drops.levels.follow_player.span
            local jitter = cfg.drops.levels.jitter
            -- L8 on the 1-5 homeworld: low roll = (8-span) - jitter, high = 8 + jitter
            expect(Enhancements.rollLevel(cfg, nil, rngLo, 8)).to.equal(8 - span - jitter)
            expect(Enhancements.rollLevel(cfg, nil, rngHi, 8)).to.equal(8 + jitter)
            -- L50 endgame: hunts band-top + jitter (the +2s)
            expect(Enhancements.rollLevel(cfg, nil, rngHi, 50)).to.equal(50 + jitter)
        end)

        it("below the band top the player level changes nothing", function()
            local rngHi = {
                NextInteger = function(_, _, hi)
                    return hi
                end,
            }
            local band = cfg.drops.levels.bands.default
            local maxLvl = band[2] + cfg.drops.levels.jitter
            expect(Enhancements.rollLevel(cfg, nil, rngHi, 3)).to.equal(maxLvl)
            expect(Enhancements.rollLevel(cfg, nil, rngHi, nil)).to.equal(maxLvl)
        end)
    end)

    describe("CoH level scaling (Jason's rules)", function()
        local sc = cfg.drops.levels.scaling

        it("within the window: above = stronger, below = weaker, even = base", function()
            expect(Enhancements.levelFactor(cfg, 12, 12)).to.equal(1)
            expect(Enhancements.levelFactor(cfg, 14, 12)).to.equal(1 + sc.per_level * 2)
            expect(Enhancements.levelFactor(cfg, 10, 12)).to.equal(1 - sc.per_level * 2)
        end)

        it("more than window BELOW the player: slotted but DEAD (factor 0)", function()
            expect(Enhancements.levelFactor(cfg, 9, 12)).to.equal(0)
            expect(Enhancements.levelFactor(cfg, 1, 50)).to.equal(0)
        end)

        it("placement gate: max player+window; legacy no-level records pass", function()
            expect(Enhancements.canSlotAtLevel(cfg, 52, 50)).to.equal(true) -- the L50 chase
            expect(Enhancements.canSlotAtLevel(cfg, 53, 50)).to.equal(false)
            expect(Enhancements.canSlotAtLevel(cfg, nil, 50)).to.equal(true)
        end)

        it("aggregate scales by level and drops dead boosts", function()
            local slots = {
                { enh = { type = "damage", origins = { "pyromancer" }, level = 14 } }, -- +2
                { enh = { type = "damage", origins = { "pyromancer" }, level = 5 } }, -- dead
                { enh = { type = "recharge", origins = { "geomancer", "cryomancer" } } }, -- legacy: x1
            }
            local axes = Enhancements.aggregate(cfg, slots, 12)
            local want = cfg.values.single * (1 + sc.per_level * 2)
            expect(math.abs(axes.damage - want) < 1e-9).to.equal(true)
            expect(math.abs(axes.recharge - cfg.values.dual) < 1e-9).to.equal(true)
        end)

        it("aggregate without a player level stays unscaled (back-compat)", function()
            local slots = { { enh = { type = "damage", origins = { "pyromancer" }, level = 99 } } }
            local axes = Enhancements.aggregate(cfg, slots)
            expect(math.abs(axes.damage - cfg.values.single) < 1e-9).to.equal(true)
        end)
    end)

    describe("Config integrity", function()
        it("every type's symbol + axis are present and axis is a PowerStats axis", function()
            local axes = {
                damage = true,
                accuracy = true,
                recharge = true, -- applied in PowerService (cooldown), not PowerStats
                duration = true,
                radius = true,
                magnitude = true,
                heal = true,
                shield = true,
                focus = true, -- applied in PowerService (toggle upkeep + cast-cost reduction)
            }
            for name, def in pairs(cfg.types) do
                expect(type(def.symbol)).to.equal("string")
                -- a type contributes EITHER an axis (multiplier) OR a proc (chance-on-
                -- trigger, e.g. spark) — both is allowed, neither is a config error
                local hasProc = type(def.proc) == "table" and (tonumber(def.proc.chance) or 0) > 0
                if not (axes[def.axis] or hasProc) then
                    error(("type '%s' has unknown axis '%s'"):format(name, tostring(def.axis)))
                end
            end
        end)
    end)
end
