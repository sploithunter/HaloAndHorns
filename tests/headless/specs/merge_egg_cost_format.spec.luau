local CostFormat = loadModule("src/Shared/Game/MergeEggCostFormat.lua")

return function()
    describe("Merge Egg compact cost notation", function()
        it("keeps sub-million costs exact and comma-separated", function()
            expect(CostFormat.format(0)).to.equal("0")
            expect(CostFormat.format(50000)).to.equal("50,000")
            expect(CostFormat.format(999999)).to.equal("999,999")
        end)

        it("uses M for million-scale costs", function()
            expect(CostFormat.format(1000000)).to.equal("1M")
            expect(CostFormat.format(10000000)).to.equal("10M")
            expect(CostFormat.format(125000000)).to.equal("125M")
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

        it("uses the shared notation in both Merge management menus", function()
            local cannon = readFile("src/Client/UI/Components/MergeCannonMenu.lua")
            local bulwark = readFile("src/Client/UI/Components/MergeBulwarkMenu.lua")
            for _, menu in ipairs({ cannon, bulwark }) do
                expect(menu:find("MergeEggCostFormat.format(costAmount)", 1, true)).to.be.ok()
                expect(menu:find("MergeEggCostFormat.format(wallet)", 1, true)).to.be.ok()
            end
        end)
    end)
end
