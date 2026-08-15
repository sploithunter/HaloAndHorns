return function()
    describe("PlayerEffectsService client update contract", function()
        it("defines the broadcaster used by every effect-removal path", function()
            local source = readFile("src/Server/Services/PlayerEffectsService.lua")
            expect(source:find("function PlayerEffectsService:_sendUnifiedEffectsUpdate", 1, true)).never.to.equal(
                nil
            )
            expect(source:find("Signals.ActiveEffects:FireClient", 1, true)).never.to.equal(nil)
            expect(source:find("function PlayerEffectsService:RemoveEffect", 1, true)).never.to.equal(
                nil
            )
            expect(source:find("function PlayerEffectsService:RemovePermanentEffect", 1, true)).never.to.equal(
                nil
            )
        end)

        it("projects Titan runtime state and rebuilds pets only on state transitions", function()
            local effectsSource = readFile("src/Server/Services/PlayerEffectsService.lua")
            local petSource = readFile("src/Server/Services/PetHandler.server.lua")
            local followSource = readFile("src/Client/Systems/PetFollowController.lua")

            expect(
                effectsSource:find("function PlayerEffectsService:_setRuntimeEffectState", 1, true)
            ).to.be.ok()
            expect(effectsSource:find("PetRuntimeBridge.RequestRebuild(player)", 1, true)).to.be.ok()
            expect(petSource:find("applyTemporaryTitanScale", 1, true)).to.be.ok()
            expect(petSource:find('petModel:SetAttribute("TemporaryTitan", true)', 1, true)).to.be.ok()
            expect(followSource:find('pet:GetAttribute("TemporaryTitan") == true', 1, true)).to.be.ok()
        end)
    end)
end
