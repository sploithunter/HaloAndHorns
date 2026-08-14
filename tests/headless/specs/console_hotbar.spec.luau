local ConsoleHotbar = loadModule("src/Shared/Game/ConsoleHotbar.lua")

return function()
    describe("ConsoleHotbar", function()
        local hotbar = { [1] = "rally", [4] = "resonance", [20] = "brew" }

        it("selects only bound slots and wraps in both directions", function()
            expect(ConsoleHotbar.step(hotbar, nil, 1, 20)).to.equal(1)
            expect(ConsoleHotbar.step(hotbar, 1, 1, 20)).to.equal(4)
            expect(ConsoleHotbar.step(hotbar, 20, 1, 20)).to.equal(1)
            expect(ConsoleHotbar.step(hotbar, 1, -1, 20)).to.equal(20)
        end)

        it("returns nil for an empty bar", function()
            expect(ConsoleHotbar.step({}, nil, 1, 20)).to.equal(nil)
        end)

        it("recovers deterministically when the selected binding disappears", function()
            expect(ConsoleHotbar.step(hotbar, 8, 1, 20)).to.equal(1)
            expect(ConsoleHotbar.step(hotbar, 8, -1, 20)).to.equal(20)
        end)
    end)
end
