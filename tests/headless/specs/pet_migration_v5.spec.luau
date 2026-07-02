--[[
    Phase 11 Stage 2: PetMigrationV5 — legacy MIXED storage -> SSOT uid-records.
    Conservation (no pet lost, no phantom resurrected as equipped) is the contract.
    Run: mise run test-headless
]]

local Migrate = loadModule("src/Shared/Inventory/PetMigrationV5.lua")

local function countItems(items)
    local n = 0
    for _ in pairs(items) do
        n += 1
    end
    return n
end

local function countEquipped(items)
    local n = 0
    for _, rec in pairs(items) do
        if rec.equipped_slot ~= nil then
            n += 1
        end
    end
    return n
end

return function()
    describe("PetMigrationV5 explosion + classification", function()
        it("explodes a common stack of N into N uid records with no quantity/_kind", function()
            local old = {
                ["bunny:basic"] = {
                    id = "bunny",
                    variant = "basic",
                    quantity = 3,
                    _kind = "stack",
                    obtained_at = 100,
                },
            }
            local result = Migrate.migrate(old, {})
            expect(countItems(result.items)).to.equal(3)
            for _, rec in pairs(result.items) do
                expect(rec.id).to.equal("bunny")
                expect(rec.variant).to.equal("basic")
                expect(rec.quantity).to.equal(nil)
                expect(rec._kind).to.equal(nil)
                expect(rec.uid).to.be.a("string")
                expect(rec.obtained_at).to.equal(100)
            end
        end)

        it("keeps a special record by uid, strips quantity/_kind, preserves fields", function()
            local old = {
                ["bear_123_abc"] = {
                    id = "bear",
                    variant = "basic",
                    _kind = "special",
                    quantity = 1,
                    huge = true,
                    level = 19,
                    serial = 10,
                    obtained_at = 200,
                },
            }
            local result = Migrate.migrate(old, {})
            local rec = result.items["bear_123_abc"]
            expect(rec).never.to.equal(nil)
            expect(rec.uid).to.equal("bear_123_abc")
            expect(rec.quantity).to.equal(nil)
            expect(rec._kind).to.equal(nil)
            expect(rec.huge).to.equal(true)
            expect(rec.level).to.equal(19)
            expect(rec.serial).to.equal(10)
        end)

        it("classifies pre-_kind data: huge/level/serial -> special, else stack", function()
            local old = {
                ["wolf_9_z"] = { id = "wolf", variant = "basic", level = 5 }, -- special by level
                ["cat:basic"] = { id = "cat", variant = "basic", quantity = 2 }, -- stack
            }
            local result = Migrate.migrate(old, {})
            expect(result.items["wolf_9_z"]).never.to.equal(nil) -- kept by uid
            expect(countItems(result.items)).to.equal(3) -- 1 special + 2 exploded cats
        end)
    end)

    describe("PetMigrationV5 equipped resolution", function()
        it("sets equipped_slot on an equipped special uid", function()
            local old = {
                ["bear_1_a"] = { id = "bear", _kind = "special", huge = true, obtained_at = 1 },
            }
            local result = Migrate.migrate(old, { slot_1 = "bear_1_a" })
            expect(result.items["bear_1_a"].equipped_slot).to.equal(1)
            expect(result.report.migratedEquipped).to.equal(1)
        end)

        it("re-mints an equipped common (stack|...) as an equipped record (+1 owned)", function()
            local old = {
                ["bunny:basic"] = {
                    id = "bunny",
                    variant = "basic",
                    quantity = 28,
                    _kind = "stack",
                    obtained_at = 50,
                },
            }
            local result = Migrate.migrate(old, { slot_4 = "stack|bunny:basic|08c1-eph" })
            -- 28 unequipped + 1 re-minted equipped = 29 owned, 1 equipped
            expect(countItems(result.items)).to.equal(29)
            expect(countEquipped(result.items)).to.equal(1)
            expect(#result.report.remintedStackSlots).to.equal(1)
            -- the re-minted copy carries the stack's obtained_at
            for _, rec in pairs(result.items) do
                if rec.equipped_slot == 4 then
                    expect(rec.id).to.equal("bunny")
                    expect(rec.obtained_at).to.equal(50)
                end
            end
        end)

        it("DROPS an equipped uid-slot with no backing record (traded-away phantom)", function()
            local old = {
                ["bear_real_x"] = { id = "bear", _kind = "special", huge = true, obtained_at = 1 },
            }
            local result = Migrate.migrate(old, {
                slot_1 = "bear_real_x",
                slot_2 = "bear_ghost_gone", -- no such record -> orphan, dropped
            })
            expect(result.items["bear_ghost_gone"]).to.equal(nil)
            expect(countEquipped(result.items)).to.equal(1) -- only the real one
            expect(#result.report.orphanSlots).to.equal(1)
            expect(result.report.orphanSlots[1].value).to.equal("bear_ghost_gone")
            expect(result.report.conserved).to.equal(true)
        end)
    end)

    describe("PetMigrationV5 conservation on a real-data-shaped fixture", function()
        -- Mirrors the live `coloradoplays` profile shape:
        --   commons: bunny:basic=28, doggy:basic=31, bear:golden=2, bunny:golden=4, bear:basic=80 (=145)
        --   13 huge specials (several sharing id:variant "bear:basic" with the common bear stack)
        --   equipped: slot_1/2/3 = special uids (valid), slot_4 = stack|bunny:basic|eph
        -- Expected: 145 + 13 + 1 = 159 owned, 4 equipped.
        local function build()
            local old = {
                ["bunny:basic"] = {
                    id = "bunny",
                    variant = "basic",
                    quantity = 28,
                    _kind = "stack",
                    obtained_at = 1,
                },
                ["doggy:basic"] = {
                    id = "doggy",
                    variant = "basic",
                    quantity = 31,
                    _kind = "stack",
                    obtained_at = 2,
                },
                ["bear:golden"] = {
                    id = "bear",
                    variant = "golden",
                    quantity = 2,
                    _kind = "stack",
                    obtained_at = 3,
                },
                ["bunny:golden"] = {
                    id = "bunny",
                    variant = "golden",
                    quantity = 4,
                    _kind = "stack",
                    obtained_at = 4,
                },
                ["bear:basic"] = {
                    id = "bear",
                    variant = "basic",
                    quantity = 80,
                    _kind = "stack",
                    obtained_at = 5,
                },
            }
            -- 13 huge specials, most are bear/basic (same id:variant as the common bear stack)
            for i = 1, 12 do
                old["bear_h_" .. i] = {
                    id = "bear",
                    variant = "basic",
                    _kind = "special",
                    huge = true,
                    rarity_id = "huge",
                    level = i,
                    obtained_at = 1000 + i,
                }
            end
            old["colorado_h_1"] = {
                id = "colorado",
                variant = "rainbow",
                _kind = "special",
                huge = true,
                rarity_id = "huge",
                level = 14,
                obtained_at = 2000,
            }
            return old
        end

        it("preserves owned + equipped counts (conserved == true)", function()
            local old = build()
            local equipped = {
                slot_1 = "bear_h_5", -- special uid
                slot_2 = "bear_h_1", -- special uid
                slot_3 = "colorado_h_1", -- special uid
                slot_4 = "stack|bunny:basic|08c108b3-eph", -- equipped common
            }
            local result = Migrate.migrate(old, equipped)
            expect(result.report.legacyOwned).to.equal(159)
            expect(result.report.migratedOwned).to.equal(159)
            expect(result.report.legacyEquipped).to.equal(4)
            expect(result.report.migratedEquipped).to.equal(4)
            expect(result.report.conserved).to.equal(true)
        end)

        it("is deterministic: same input yields the same item keys", function()
            local a = Migrate.migrate(build(), { slot_4 = "stack|bunny:basic|eph" })
            local b = Migrate.migrate(build(), { slot_4 = "stack|bunny:basic|eph" })
            local keysA = {}
            for k in pairs(a.items) do
                keysA[k] = true
            end
            for k in pairs(b.items) do
                expect(keysA[k]).to.equal(true)
            end
            expect(countItems(a.items)).to.equal(countItems(b.items))
        end)
    end)
end
