local StarterPetChoice = loadModule("src/Shared/Game/StarterPetChoice.lua")
local cfg = loadModule("configs/starter_pets.lua")

local function newData()
    return {
        Stats = { Level = 1, ClaimedLevel = 1 },
        Inventory = { pets = { items = {} } },
        Tutorial = { step = 1, count = 0, done = false },
        StarterPet = {},
    }
end

return function()
    describe("starter companion config", function()
        it("offers the four Earth archetypes as basic companions", function()
            expect(#cfg.choices).to.equal(4)
            expect(cfg.grant.variant).to.equal("basic")
            expect(cfg.grant.locked).to.equal(true)
            expect(cfg.grant.unique).to.equal(true)
            expect(StarterPetChoice.choiceById(cfg, "bunny").role).to.equal("support")
            expect(StarterPetChoice.choiceById(cfg, "bear").role).to.equal("tank")
            expect(StarterPetChoice.choiceById(cfg, "doggy").role).to.equal("melee")
            expect(StarterPetChoice.choiceById(cfg, "kitty").role).to.equal("ranged")
            expect(StarterPetChoice.choiceById(cfg, "dragon")).to.equal(nil)
        end)
    end)

    describe("eligibility", function()
        it("offers exactly a genuinely new profile", function()
            expect(StarterPetChoice.isEligible(cfg, newData())).to.equal(true)
        end)

        it("does not reoffer after selection or a recovered grant", function()
            local selected = newData()
            selected.StarterPet = { choice = "kitty" }
            expect(StarterPetChoice.isEligible(cfg, selected)).to.equal(false)

            local recovered = newData()
            recovered.Inventory.pets.items.starter = {
                uid = "starter",
                id = "bear",
                variant = "basic",
                grant_source = "starter_choice",
            }
            expect(StarterPetChoice.findGrantedStarter(recovered).id).to.equal("bear")
            expect(StarterPetChoice.isEligible(cfg, recovered)).to.equal(false)
        end)

        it("does not interrupt progressed players", function()
            local owned = newData()
            owned.Inventory.pets.items["bunny:basic"] =
                { id = "bunny", variant = "basic", quantity = 1 }
            expect(StarterPetChoice.isEligible(cfg, owned)).to.equal(false)

            local levelled = newData()
            levelled.Stats.ClaimedLevel = 2
            expect(StarterPetChoice.isEligible(cfg, levelled)).to.equal(false)

            local tutorialDone = newData()
            tutorialDone.Tutorial.done = true
            expect(StarterPetChoice.isEligible(cfg, tutorialDone)).to.equal(false)
        end)

        it("lets the explicit admin reset override protected retained pets", function()
            local reset = newData()
            reset.StarterPet.forceOffer = true
            reset.Inventory.pets.items.huge = { uid = "huge", id = "huge_bear", huge = true }
            expect(StarterPetChoice.isEligible(cfg, reset)).to.equal(true)
        end)
    end)

    describe("place ownership", function()
        it("prewarms only starter previews before publishing model readiness", function()
            local source = readFile("src/Server/Services/AssetPreloadService.lua")
            local warm = assert(source:find("self:_warmStarterPetPreviews()", 1, true))
            local ready = assert(source:find('BootReadiness.signal("models_ready")', 1, true))
            expect(warm < ready).to.equal(true)
            expect(cfg.preview.folder).to.equal("StarterPetPreviews")
            expect(cfg.preview.wait_timeout_seconds > 0).to.equal(true)
        end)

        it(
            "starts fetching before UI readiness and never waits for the removed global catalog",
            function()
                local source = readFile("src/Client/Systems/StarterPetController.lua")
                local start = assert(source:find("function StarterPetController.start()", 1, true))
                local warm = assert(source:find("prewarmStarterChoices()", start, true))
                local ready =
                    assert(source:find('player:GetAttribute("ClientUIReady")', start, true))
                expect(warm < ready).to.equal(true)
                expect(source:find('WaitForChild("Models"', 1, true)).to.equal(nil)
                expect(source:find("STARTER.preview.folder", 1, true)).to.be.ok()
            end
        )

        it("keeps the starter chooser in Farm and Fight rather than the Merge place", function()
            local service = readFile("src/Server/Services/StarterPetService.lua")

            expect(service:find("function StarterPetService:_isAvailableHere", 1, true)).to.be.ok()
            expect(
                service:find(
                    'return PlaceRuntime.isRole(game.PlaceId, self._placesConfig, "main")',
                    1,
                    true
                )
            ).to.be.ok()
            expect(service:find("if not self:_isAvailableHere() then", 1, true)).to.be.ok()
            expect(service:find("eligible = false", 1, true)).to.be.ok()
        end)
    end)
end
