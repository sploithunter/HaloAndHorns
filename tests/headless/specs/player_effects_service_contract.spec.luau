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
    end)
end
