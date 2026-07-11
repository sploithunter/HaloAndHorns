local CurrencyTransaction = loadModule("src/Shared/Game/CurrencyTransaction.lua")

local function harness(options)
    options = options or {}
    local calls = {}
    local result = CurrencyTransaction.execute({
        debits = options.debits or { gems = 5, coins = 10 },
        credits = options.credits or { crystals = 3 },
        canDebit = function(currency, amount)
            table.insert(calls, "can:" .. currency .. ":" .. amount)
            return options.unaffordable ~= currency
        end,
        debit = function(currency, amount)
            table.insert(calls, "debit:" .. currency .. ":" .. amount)
            return options.debitFails ~= currency
        end,
        credit = function(currency, amount)
            table.insert(calls, "credit:" .. currency .. ":" .. amount)
            return options.creditFails ~= currency
        end,
        reverseDebit = function(currency, amount)
            table.insert(calls, "refund:" .. currency .. ":" .. amount)
            return options.reverseDebitFails ~= currency
        end,
        reverseCredit = function(currency, amount)
            table.insert(calls, "revoke:" .. currency .. ":" .. amount)
            return options.reverseCreditFails ~= currency
        end,
        commit = function()
            table.insert(calls, "commit")
            return options.commitFails ~= true
        end,
    })
    return result, calls
end

return function()
    describe("CurrencyTransaction", function()
        it("preflights and mutates currencies in stable order", function()
            local result, calls = harness()
            expect(result.ok).to.equal(true)
            expect(table.concat(calls, ",")).to.equal(
                "can:coins:10,can:gems:5,debit:coins:10,debit:gems:5,credit:crystals:3,commit"
            )
        end)

        it("stops before mutation when any debit is unaffordable", function()
            local result, calls = harness({ unaffordable = "gems" })
            expect(result.reason).to.equal("precondition_failed")
            expect(table.concat(calls, ",")).to.equal("can:coins:10,can:gems:5")
        end)

        it("reverses credits and debits when commit rejects", function()
            local result, calls = harness({ commitFails = true })
            expect(result.reason).to.equal("commit_failed")
            expect(table.concat(calls, ",")).to.equal(
                "can:coins:10,can:gems:5,debit:coins:10,debit:gems:5,credit:crystals:3,commit,revoke:crystals:3,refund:gems:5,refund:coins:10"
            )
        end)

        it("reports rollback failure with the original cause", function()
            local result = harness({ creditFails = "crystals", reverseDebitFails = "gems" })
            expect(result.reason).to.equal("rollback_failed")
            expect(result.cause).to.equal("credit_failed")
        end)
    end)
end
