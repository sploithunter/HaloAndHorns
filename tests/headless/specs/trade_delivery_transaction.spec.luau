local TradeDeliveryTransaction = loadModule("src/Shared/Game/TradeDeliveryTransaction.lua")

return function()
    describe("TradeDeliveryTransaction", function()
        it("grants each leg in stable descriptor order", function()
            local calls = {}
            local result = TradeDeliveryTransaction.execute({
                legs = {
                    { recipient = "b", escrow = { z = { uid = "z" }, a = { uid = "a" } } },
                    { recipient = "a", escrow = { m = { uid = "m" } } },
                },
                grant = function(recipient, descriptor)
                    table.insert(calls, "grant:" .. recipient .. ":" .. descriptor.uid)
                    return { uid = descriptor.uid }
                end,
                revoke = function()
                    return true
                end,
            })

            expect(result.ok).to.equal(true)
            expect(table.concat(calls, ",")).to.equal("grant:b:a,grant:b:z,grant:a:m")
        end)

        it("stages every inventory record before currency side effects", function()
            local calls = {}
            local result = TradeDeliveryTransaction.execute({
                legs = {
                    {
                        recipient = "b",
                        escrow = {
                            a = { uid = "a", category = "currencies" },
                            z = { uid = "z", category = "pets" },
                        },
                    },
                    {
                        recipient = "a",
                        escrow = { b = { uid = "b", category = "enhancements" } },
                    },
                },
                grant = function(_, descriptor)
                    table.insert(calls, descriptor.category)
                    return { uid = descriptor.uid }
                end,
                revoke = function()
                    return true
                end,
            })

            expect(result.ok).to.equal(true)
            expect(table.concat(calls, ",")).to.equal("pets,enhancements,currencies")
        end)

        it("undoes prior grants in reverse order when a later grant rejects", function()
            local calls = {}
            local result = TradeDeliveryTransaction.execute({
                legs = {
                    {
                        recipient = "b",
                        escrow = {
                            a = { uid = "a" },
                            b = { uid = "b" },
                            c = { uid = "c" },
                        },
                    },
                },
                grant = function(_, descriptor)
                    table.insert(calls, "grant:" .. descriptor.uid)
                    if descriptor.uid == "c" then
                        return nil
                    end
                    return { uid = descriptor.uid }
                end,
                revoke = function(receipt)
                    table.insert(calls, "revoke:" .. receipt.uid)
                    return true
                end,
            })

            expect(result.reason).to.equal("grant_failed")
            expect(table.concat(calls, ",")).to.equal("grant:a,grant:b,grant:c,revoke:b,revoke:a")
        end)

        it("rolls back when a grant throws", function()
            local revoked = false
            local result = TradeDeliveryTransaction.execute({
                legs = { { recipient = "b", escrow = { a = { uid = "a" }, b = { uid = "b" } } } },
                grant = function(_, descriptor)
                    if descriptor.uid == "b" then
                        error("injected failure")
                    end
                    return { uid = descriptor.uid }
                end,
                revoke = function()
                    revoked = true
                    return true
                end,
            })

            expect(result.reason).to.equal("grant_failed")
            expect(revoked).to.equal(true)
        end)

        it("reports rollback failure without hiding the grant cause", function()
            local result = TradeDeliveryTransaction.execute({
                legs = { { recipient = "b", escrow = { a = { uid = "a" }, b = { uid = "b" } } } },
                grant = function(_, descriptor)
                    return descriptor.uid == "a" and { uid = "a" } or nil
                end,
                revoke = function()
                    return false
                end,
            })

            expect(result.reason).to.equal("rollback_failed")
            expect(result.cause).to.equal("grant_rejected")
        end)
    end)
end
