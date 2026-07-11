local ShopPurchaseTransaction = loadModule("src/Shared/Game/ShopPurchaseTransaction.lua")

local function harness(options)
    options = options or {}
    local calls = {}
    local result = ShopPurchaseTransaction.execute({
        costs = options.costs or { coins = 100, gems = 5 },
        debit = function(currency, amount)
            calls[#calls + 1] = "debit:" .. currency .. ":" .. amount
            return options.debitFails ~= currency
        end,
        grant = function()
            calls[#calls + 1] = "grant"
            if options.grantThrows then
                error("grant exploded")
            end
            return options.grantResult or { ok = true, granted = { items = { "potion" } } }
        end,
        refund = function(currency, amount)
            calls[#calls + 1] = "refund:" .. currency .. ":" .. amount
            return options.refundFails ~= currency
        end,
    })
    return result, calls
end

return function()
    describe("ShopPurchaseTransaction", function()
        it("debits in stable order and grants once", function()
            local result, calls = harness()
            expect(result.ok).to.equal(true)
            expect(result.granted.granted.items[1]).to.equal("potion")
            expect(table.concat(calls, ",")).to.equal("debit:coins:100,debit:gems:5,grant")
        end)

        it("stops before grant when the first debit fails", function()
            local result, calls = harness({ debitFails = "coins" })
            expect(result.reason).to.equal("debit_failed")
            expect(result.currency).to.equal("coins")
            expect(table.concat(calls, ",")).to.equal("debit:coins:100")
        end)

        it("refunds prior debits when a later debit fails", function()
            local result, calls = harness({ debitFails = "gems" })
            expect(result.reason).to.equal("debit_failed")
            expect(table.concat(calls, ",")).to.equal(
                "debit:coins:100,debit:gems:5,refund:coins:100"
            )
        end)

        it("refunds every debit when grant reports failure", function()
            local result, calls = harness({ grantResult = { ok = false } })
            expect(result.reason).to.equal("grant_failed")
            expect(table.concat(calls, ",")).to.equal(
                "debit:coins:100,debit:gems:5,grant,refund:gems:5,refund:coins:100"
            )
        end)

        it("reports rollback failure without hiding the original cause", function()
            local result = harness({ grantThrows = true, refundFails = "gems" })
            expect(result.reason).to.equal("rollback_failed")
            expect(result.cause).to.equal("grant_failed")
        end)
    end)
end
