local RangeCatalogView = loadModule("src/Shared/Game/RangeCatalogView.lua")
local PetPower = loadModule("src/Shared/Game/PetPower.lua")
local BestPetSelector = loadModule("src/Shared/Inventory/BestPetSelector.lua")
local pets = loadModule("configs/pets.lua")
local roles = loadModule("configs/pet_roles.lua")
local progression = loadModule("configs/pet_progression.lua")
local challengeRuns = loadModule("configs/challenge_runs.lua")

return function()
    describe("RangeCatalogView", function()
        it("projects the Range catalog into inventory card records", function()
            local catalog = challengeRuns.modes.range.catalog
            local built = RangeCatalogView.build(catalog, pets, progression, PetPower)
            expect(#built.items > 0).to.equal(true)
            expect(built.petSlots).to.equal(5)
            expect(#built.defaultRefs).to.equal(5)

            local byType = {}
            for _, item in ipairs(built.items) do
                expect(item.folder_source).to.equal("pets")
                expect(item.category).to.equal("Pets")
                expect(item.use3DModel).to.equal(true)
                expect(type(item.petType)).to.equal("string")
                expect(type(item.uid)).to.equal("string")
                expect(item.power > 0).to.equal(true)
                expect(item.variant == "gold").to.equal(false)
                byType[item.petType] = item
            end

            expect(byType.colorado.huge).to.equal(false)
            expect(byType.colorado.variant).to.equal("basic")
            expect(byType.kade.variant).to.equal("basic")
            expect(byType.colorado_creator).to.equal(nil)
            expect(byType.portal_drake.variant).to.equal("golden")
            expect(byType.atlas_golem.variant).to.equal("golden")
            expect(byType.fortune_wisp.variant).to.equal("golden")
            for _, item in ipairs(built.items) do
                expect(item.huge).to.equal(false)
                expect(item.creator).to.equal(false)
            end
        end)

        it("lets Best Pets rank catalog cards by the same role rules", function()
            local catalog = challengeRuns.modes.range.catalog
            local built = RangeCatalogView.build(catalog, pets, progression, PetPower)
            local ranged, tanks = {}, {}
            for _, item in ipairs(built.items) do
                local role = roles.by_type and roles.by_type[item.petType]
                local candidate = {
                    key = item.uid,
                    role = role,
                    damage = item.power,
                    health = item.power * 10,
                    abilities = {},
                    available = true,
                    item = item,
                }
                if role == "ranged" then
                    table.insert(ranged, candidate)
                elseif role == "tank" then
                    table.insert(tanks, candidate)
                end
            end
            expect(#ranged > 0).to.equal(true)
            expect(BestPetSelector.best(ranged, "ranged").item.petType).to.be.ok()
            expect(BestPetSelector.best(tanks, "tank").item.petType).to.equal("kade")
            local support = {}
            for _, item in ipairs(built.items) do
                if roles.by_type and roles.by_type[item.petType] == "support" then
                    table.insert(support, {
                        key = item.uid,
                        role = "support",
                        damage = item.power,
                        health = item.power * 10,
                        abilities = { { kind = "luck", scope = "aura" } },
                        available = true,
                        item = item,
                    })
                end
            end
            expect(#support > 0).to.equal(true)
            expect(BestPetSelector.best(support, "support").item.petType).to.be.ok()
        end)

        it("maps draft refs back to sanitized catalog picks", function()
            local built = RangeCatalogView.build({
                pet_slots = 2,
                pets = {
                    { pet = "blade_lynx", variant = "gold", default = true },
                    { pet = "atlas_golem", variant = "golden" },
                },
            }, pets, progression, PetPower)
            local picks = RangeCatalogView.picksFromRefs(built.byRef, built.defaultRefs)
            expect(#picks).to.equal(1)
            expect(picks[1].pet).to.equal("blade_lynx")
            expect(picks[1].variant).to.equal("golden")
            expect(RangeCatalogView.refsFromPicks(picks)[1]).to.equal("range|blade_lynx")
        end)
    end)
end
