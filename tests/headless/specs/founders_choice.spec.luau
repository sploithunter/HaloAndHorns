local FoundersChoice = loadModule("src/Shared/Game/FoundersChoice.lua")

return function()
    local config = {
        founders_choice = {
            eligible_passes = { "speed_boost", "pet_slot_pass" },
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

        it("supports the creator no-pass balance gate", function()
            local effective = FoundersChoice.effectivePasses(passes, {
                marketplace = { speed_boost = true },
            }, "pet_slot_pass", true)
            expect(#effective).to.equal(0)
        end)

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

        it("ships the exact first-10k allowlist without bundled VIP", function()
            local shipped = loadModule("configs/monetization.lua")
            local feature = shipped.founders_choice
            expect(feature.player_limit).to.equal(10000)
            expect(#feature.eligible_passes).to.equal(7)
            expect(FoundersChoice.isEligiblePass(shipped, "vip_pass")).to.equal(false)
            expect(FoundersChoice.isEligiblePass(shipped, "pet_slot_pass")).to.equal(true)
        end)

        it("wires profile state, purchase reconciliation, and the chooser", function()
            local data = readFile("src/Server/Services/DataService.lua")
            local server = readFile("src/Server/Services/MonetizationService.lua")
            local cohort = readFile("src/Server/Services/FoundersChoiceService.lua")
            local client = readFile("src/Client/Systems/FoundersChoiceController.lua")
            expect(data:find("CURRENT_SCHEMA_VERSION = 13", 1, true)).to.be.ok()
            expect(cohort:find("UpdateAsync", 1, true)).to.be.ok()
            expect(server:find("ReleaseForMarketplaceOwnership", 1, true)).to.be.ok()
            expect(server:find("FoundersChoice.effectivePasses", 1, true)).to.be.ok()
            expect(client:find("YES — CLAIM", 1, true)).to.be.ok()
            expect(client:find("PanelChrome.build", 1, true)).to.be.ok()
            expect(client:find('title = "🎁 FOUNDER\'S CHOICE"', 1, true)).to.be.ok()
            expect(client:find('closeButton.Text = "✕"', 1, true)).to.equal(nil)
            expect(client:find("choose.ZIndex = 107", 1, true)).to.be.ok()
            expect(client:find("scroll.ClipsDescendants = true", 1, true)).to.be.ok()
            expect(client:find("R$", 1, true)).to.equal(nil)
        end)
    end)
end
