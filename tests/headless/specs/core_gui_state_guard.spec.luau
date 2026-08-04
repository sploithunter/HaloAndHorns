local CoreGuiStateGuard = loadModule("src/Client/UI/CoreGuiStateGuard.lua")

return function()
    describe("CoreGuiStateGuard", function()
        it("restores an enabled CoreGui after suppression", function()
            local enabled = true
            local writes = {}
            local guard = CoreGuiStateGuard.new(function()
                return enabled
            end, function(value)
                enabled = value
                table.insert(writes, value)
            end)

            expect(guard:Suppress()).to.equal(true)
            expect(enabled).to.equal(false)
            expect(guard:Restore()).to.equal(true)
            expect(enabled).to.equal(true)
            expect(#writes).to.equal(2)
        end)

        it("restores a CoreGui that was already disabled without enabling it", function()
            local enabled = false
            local guard = CoreGuiStateGuard.new(function()
                return enabled
            end, function(value)
                enabled = value
            end)

            expect(guard:Suppress()).to.equal(true)
            expect(guard:Restore()).to.equal(true)
            expect(enabled).to.equal(false)
        end)

        it("does not overwrite the captured state when suppressed twice", function()
            local enabled = true
            local guard = CoreGuiStateGuard.new(function()
                return enabled
            end, function(value)
                enabled = value
            end)

            expect(guard:Suppress()).to.equal(true)
            expect(guard:Suppress()).to.equal(true)
            expect(guard:Restore()).to.equal(true)
            expect(enabled).to.equal(true)
        end)

        it("retains the captured state when restoration fails so it can retry", function()
            local enabled = true
            local failRestore = true
            local guard = CoreGuiStateGuard.new(function()
                return enabled
            end, function(value)
                if value and failRestore then
                    error("CoreGui unavailable")
                end
                enabled = value
            end)

            expect(guard:Suppress()).to.equal(true)
            expect(guard:Restore()).to.equal(false)
            failRestore = false
            expect(guard:Restore()).to.equal(true)
            expect(enabled).to.equal(true)
        end)
    end)
end
