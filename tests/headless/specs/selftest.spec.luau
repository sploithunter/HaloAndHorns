--[[
	Self-test for the headless runner. Proves the framework + reporting +
	exit-code loop work before any real game logic exists. Safe to delete
	once Phase 0 specs land.
]]

return function()
    describe("headless runner self-test", function()
        local counter

        beforeEach(function()
            counter = 0
        end)

        it("runs beforeEach before each it", function()
            counter += 1
            expect(counter).to.equal(1)
        end)

        it("isolates state across it blocks", function()
            expect(counter).to.equal(0)
        end)

        it("supports equal / ok / near / a matchers", function()
            expect(5).to.equal(5)
            expect("x").to.be.ok()
            expect(0.1 + 0.2).to.be.near(0.3, 1e-9)
            expect(42).to.be.a("number")
        end)

        it("supports negation via never", function()
            expect(1).never.to.equal(2)
        end)
    end)
end
