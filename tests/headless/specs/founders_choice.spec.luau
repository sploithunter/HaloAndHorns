local FoundersChoice = loadModule("src/Shared/Game/FoundersChoice.lua")

return function()
    local config = {
        founders_choice = {
            eligible_passes = { "speed_boost", "pet_slot_pass" },
            test_user_ids = { 864785140, 913292269 },
            legacy = { enabled = true, catalog_version = 1 },
        },
    }
    local passes = {
        { id = "vip_pass" },
        { id = "speed_boost" },
        { id = "pet_slot_pass" },
    }

    describe("FoundersChoice", function()
        it("allowlists only configured single-purpose passes", function()
            expect(FoundersChoice.isEligiblePass(config, "speed_boost")).to.equal(true)
            expect(FoundersChoice.isEligiblePass(config, "vip_pass")).to.equal(false)
        end)

        it("unions source entitlements and applies a founder pass once", function()
            local effective, sources = FoundersChoice.effectivePasses(passes, {
                marketplace = { speed_boost = true },
            }, "speed_boost", false)
            expect(#effective).to.equal(1)
            expect(effective[1]).to.equal("speed_boost")
            expect(sources.speed_boost.marketplace).to.equal(true)
            expect(sources.speed_boost.founder).to.equal(true)
        end)

        it("adds a distinct founder benefit beside a purchased pass", function()
            local effective, sources = FoundersChoice.effectivePasses(passes, {
                marketplace = { speed_boost = true },
            }, "pet_slot_pass", false)
            expect(#effective).to.equal(2)
            expect(sources.speed_boost.marketplace).to.equal(true)
            expect(sources.pet_slot_pass.founder).to.equal(true)
        end)

        it(
            "the creator gate suppresses automatic passes but retains one selected Founder benefit",
            function()
                local effective, sources = FoundersChoice.effectivePasses(passes, {
                    marketplace = { speed_boost = true },
                }, "pet_slot_pass", true)
                expect(#effective).to.equal(1)
                expect(effective[1]).to.equal("pet_slot_pass")
                expect(sources.pet_slot_pass.founder).to.equal(true)

                local reset = FoundersChoice.effectivePasses(passes, {
                    marketplace = { speed_boost = true },
                }, "", true)
                expect(#reset).to.equal(0)
            end
        )

        it("normalizes legacy and corrupt profile state", function()
            local state = FoundersChoice.normalizeState({
                eligible = true,
                claimNumber = 7.9,
                reselections = -2,
            }, "launch_10k")
            expect(state.cohortId).to.equal("launch_10k")
            expect(state.claimNumber).to.equal(7)
            expect(state.reselections).to.equal(0)
            expect(FoundersChoice.canChoose(state)).to.equal(true)
        end)

        it(
            "unlocks Legacy only for an eligible Founder who owns the full versioned catalog",
            function()
                local state = FoundersChoice.normalizeState({ eligible = true }, "launch_10k")
                expect(FoundersChoice.canUnlockLegacy(config, state, {
                    speed_boost = true,
                    pet_slot_pass = true,
                })).to.equal(true)
                expect(FoundersChoice.canUnlockLegacy(config, state, {
                    speed_boost = true,
                })).to.equal(false)
                state.legacyUnlocked = true
                expect(FoundersChoice.canChoose(state)).to.equal(false)
                expect(FoundersChoice.canUnlockLegacy(config, state, {
                    speed_boost = true,
                    pet_slot_pass = true,
                })).to.equal(false)
            end
        )

        it("uses explicit immutable IDs for test reservations", function()
            expect(FoundersChoice.isTestUser(config, 864785140)).to.equal(true)
            expect(FoundersChoice.isTestUser(config, "913292269")).to.equal(true)
            expect(FoundersChoice.isTestUser(config, 123)).to.equal(false)
        end)

        it("re-arms a test choice without carrying a cohort number or entitlement", function()
            local state = FoundersChoice.resetTestState("launch_10k")
            expect(state.cohortId).to.equal("launch_10k")
            expect(state.eligibilityDecided).to.equal(false)
            expect(state.eligible).to.equal(false)
            expect(state.claimNumber).to.equal(0)
            expect(state.selectedPassId).to.equal("")
            expect(state.legacyUnlocked).to.equal(false)
            expect(FoundersChoice.canChoose(state)).to.equal(false)
        end)

        it("ships the exact first-10k allowlist without bundled VIP", function()
            local shipped = loadModule("configs/monetization.lua")
            local feature = shipped.founders_choice
            expect(feature.player_limit).to.equal(10000)
            expect(#feature.eligible_passes).to.equal(7)
            expect(FoundersChoice.isEligiblePass(shipped, "vip_pass")).to.equal(false)
            expect(FoundersChoice.isEligiblePass(shipped, "pet_slot_pass")).to.equal(true)
            expect(FoundersChoice.isTestUser(shipped, 3200870803)).to.equal(true)
            expect(FoundersChoice.isTestUser(shipped, 873359641)).to.equal(true)
            expect(FoundersChoice.isTestUser(shipped, 864785140)).to.equal(true)
            expect(FoundersChoice.isTestUser(shipped, 913292269)).to.equal(true)
            expect(feature.legacy.catalog_version).to.equal(1)
            expect(feature.legacy.server_luck.mult).to.equal(1.5)
        end)

        it("wires profile state, purchase reconciliation, and the chooser", function()
            local data = readFile("src/Server/Services/DataService.lua")
            local server = readFile("src/Server/Services/MonetizationService.lua")
            local cohort = readFile("src/Server/Services/FoundersChoiceService.lua")
            local bootstrap = readFile("src/Server/init.server.lua")
            local client = readFile("src/Client/Systems/FoundersChoiceController.lua")
            expect(data:find("CURRENT_SCHEMA_VERSION = 14", 1, true)).to.be.ok()
            expect(cohort:find("UpdateAsync", 1, true)).to.be.ok()
            expect(cohort:find("ResetForAdminTesting", 1, true)).to.be.ok()
            expect(
                bootstrap:find(
                    'FoundersChoiceService = modules:Get("FoundersChoiceService")',
                    1,
                    true
                )
            ).to.be.ok()
            expect(server:find("ReleaseForMarketplaceOwnership", 1, true)).to.be.ok()
            expect(server:find("TryUnlockLegacy", 1, true)).to.be.ok()
            expect(cohort:find('player:SetAttribute("FounderLegacyActive"', 1, true)).to.be.ok()
            expect(server:find("FoundersChoice.effectivePasses", 1, true)).to.be.ok()
            expect(server:find('Readiness.awaitAttribute(player, "DataLoaded", true, 30)', 1, true)).to.be.ok()
            expect(client:find("YES — CLAIM", 1, true)).to.be.ok()
            expect(client:find("PanelChrome.build", 1, true)).to.be.ok()
            expect(client:find('title = "🎁 FOUNDER\'S CHOICE"', 1, true)).to.be.ok()
            expect(client:find('closeButton.Text = "✕"', 1, true)).to.equal(nil)
            expect(client:find("choose.ZIndex = 107", 1, true)).to.be.ok()
            expect(client:find("scroll.ClipsDescendants = true", 1, true)).to.be.ok()
            expect(client:find("Launch Founder Test", 1, true)).to.be.ok()
            expect(client:find("R$", 1, true)).to.equal(nil)
        end)
    end)
end
