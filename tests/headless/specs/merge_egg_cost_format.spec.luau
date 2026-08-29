local CostFormat = loadModule("src/Shared/Game/MergeEggCostFormat.lua")

return function()
    describe("Merge Egg compact cost notation", function()
        it("keeps sub-billion costs exact and comma-separated", function()
            expect(CostFormat.format(0)).to.equal("0")
            expect(CostFormat.format(50000)).to.equal("50,000")
            expect(CostFormat.format(999999999)).to.equal("999,999,999")
        end)

        it("uses B for billion-scale costs", function()
            expect(CostFormat.format(1000000000)).to.equal("1B")
            expect(CostFormat.format(1250000000)).to.equal("1.25B")
            expect(CostFormat.format(12500000000)).to.equal("12.5B")
        end)

        it("uses T for trillion-scale costs", function()
            expect(CostFormat.format(1000000000000)).to.equal("1T")
            expect(CostFormat.format(2500000000000)).to.equal("2.5T")
        end)

        it("uses Q for quadrillion-scale costs and beyond", function()
            expect(CostFormat.format(1000000000000000)).to.equal("1Q")
            expect(CostFormat.format(3500000000000000)).to.equal("3.5Q")
            expect(CostFormat.format(1000000000000000000)).to.equal("1000Q")
        end)

        it("normalizes malformed and negative costs", function()
            expect(CostFormat.format(nil)).to.equal("0")
            expect(CostFormat.format(-100)).to.equal("0")
        end)
    end)
end
