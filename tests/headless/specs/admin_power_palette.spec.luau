--[[
    AdminPowerPalette — pure grouping of powers into the admin power-bar layout (origin tabs;
    castable vs always-on). Run: mise run test-headless
]]

local Palette = loadModule("src/Shared/Game/AdminPowerPalette.lua")

-- Synthetic powers config: two archetypes + the shared generic pool, mixing castable / passive /
-- toggle so the classifier and grouping are exercised without depending on configs/powers.lua churn.
local CFG = {
    effect_kinds = {
        aoe_blind = { family = "vulnerable", magnitude = 1.5, duration = 6 }, -- castable
        eruption = { family = "burn_spread" }, -- castable
        recharge = { family = "recharge", magnitude = 0.5, passive = true }, -- ALWAYS-ON (Hasten)
        rage = { family = "rage", magnitude = 0.5, toggle = true }, -- ALWAYS-ON (toggle)
        coin_yield = { family = "coin_yield", magnitude = 0.25, duration = 30 }, -- castable
    },
    powers = {
        sandstorm = { archetype = "sandwalker", effect = "aoe_blind" },
        simoom = { archetype = "sandwalker", effect = "eruption" },
        cataclysm = { archetype = "pyromancer", effect = "eruption" },
        wrath = { archetype = "pyromancer", effect = "rage" }, -- always-on in an archetype tab
        hasten = { generic = true, effect = "recharge" }, -- always-on, generic tab
        prospector = { generic = true, effect = "coin_yield" }, -- castable, generic tab
    },
}

-- Minimal enhancement config: potency (universal magnitude, covers passives), damage (an AoE-only
-- fallthrough family), and recharge (passive-excluded).
local ENH = {
    types = {
        potency = {
            axis = "magnitude",
            families = { vulnerable = true, recharge = true, move_speed = true },
        },
        damage = { axis = "damage", families = { vulnerable = true, burn_spread = true } },
        recharge = { axis = "recharge", families = "*", excludes_passive = true },
    },
}

return function()
    describe("AdminPowerPalette.originOf", function()
        it("uses the archetype as the origin", function()
            expect(Palette.originOf({ archetype = "pyromancer" })).to.equal("pyromancer")
        end)

        it("maps generic-pool powers to GENERIC", function()
            expect(Palette.originOf({ generic = true })).to.equal(Palette.GENERIC)
            expect(Palette.originOf({})).to.equal(Palette.GENERIC) -- no archetype = generic
        end)
    end)

    describe("AdminPowerPalette.group", function()
        local result = Palette.group(CFG, { "geomancer", "sandwalker", "cryomancer", "pyromancer" })

        it("splits castable vs always-on by the effect_kind passive/toggle flag", function()
            local sw = result.groups.sandwalker
            expect(#sw.castable).to.equal(2) -- sandstorm + simoom
            expect(#sw.always_on).to.equal(0)

            local pyro = result.groups.pyromancer
            expect(#pyro.castable).to.equal(1) -- cataclysm
            expect(#pyro.always_on).to.equal(1) -- wrath (rage toggle)
            expect(pyro.always_on[1]).to.equal("wrath")
        end)

        it("routes generic-pool powers to the GENERIC tab, Hasten as always-on", function()
            local gen = result.groups[Palette.GENERIC]
            expect(#gen.always_on).to.equal(1) -- hasten (passive recharge)
            expect(gen.always_on[1]).to.equal("hasten")
            expect(#gen.castable).to.equal(1) -- prospector
            expect(gen.castable[1]).to.equal("prospector")
        end)

        it("sorts each bucket for a stable bar", function()
            -- sandwalker castable = {sandstorm, simoom} sorted alphabetically
            expect(result.groups.sandwalker.castable[1]).to.equal("sandstorm")
            expect(result.groups.sandwalker.castable[2]).to.equal("simoom")
        end)

        it("orders tabs: pinned archetypes present first, GENERIC always last", function()
            local order = result.order
            -- geomancer/cryomancer have no powers here, so they're dropped; sandwalker + pyromancer
            -- lead (pinned order), generic trails.
            expect(order[1]).to.equal("sandwalker")
            expect(order[2]).to.equal("pyromancer")
            expect(order[#order]).to.equal(Palette.GENERIC)
        end)
    end)

    describe("AdminPowerPalette.maxSlots", function()
        it("fills every slot with the power's single-origin POTENCY enhancement", function()
            local slots = Palette.maxSlots(CFG, ENH, "sandstorm", { maxSlots = 6 })
            expect(#slots).to.equal(6)
            expect(slots[1].type).to.equal("potency") -- potency leads (covers vulnerable)
            expect(slots[1].origins[1]).to.equal("sandwalker") -- the power's archetype
            expect(#slots[1].origins).to.equal(1) -- SINGLE-origin (strongest grade)
        end)

        it("enhances always-on Hasten via potency (it scales the recharge buff)", function()
            -- potency covers the recharge family with no excludes_passive → Hasten IS enhanceable.
            local slots = Palette.maxSlots(CFG, ENH, "hasten")
            expect(#slots).to.equal(6)
            expect(slots[1].type).to.equal("potency")
            expect(#slots[1].origins).to.equal(0) -- generic power → origin-less (natural) single
        end)

        it("falls through to a specific type when potency doesn't cover the family", function()
            -- cataclysm is burn_spread (not in potency) → damage; right archetype.
            local slots = Palette.maxSlots(CFG, ENH, "cataclysm", { maxSlots = 3 })
            expect(#slots).to.equal(3)
            expect(slots[1].type).to.equal("damage")
            expect(slots[1].origins[1]).to.equal("pyromancer")
        end)

        it("returns {} for an unknown power", function()
            expect(#Palette.maxSlots(CFG, ENH, "nope")).to.equal(0)
        end)
    end)
end
