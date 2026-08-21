local EggHatchVisual = loadModule("src/Shared/Game/EggHatchVisual.lua")

local function fake(name, child)
    return {
        Name = name,
        FindFirstChild = function(_, wanted)
            if child and child.Name == wanted then
                return child
            end
            return nil
        end,
    }
end

return function()
    describe("EggHatchVisual.select", function()
        it("prefers PlacedEgg over a Hall stand with the same EggId", function()
            local placed = fake("PlacedEgg")
            local stand = fake("HallEggStand1", placed)
            expect(EggHatchVisual.select({
                { instance = stand },
                { instance = placed },
            })).to.equal(placed)
            expect(EggHatchVisual.select({
                { instance = stand },
            })).to.equal(placed)
        end)
    end)
end
