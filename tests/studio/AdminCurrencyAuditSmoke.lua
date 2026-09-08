-- Run in Studio Server. Calls the real remote handler with fake accounts/services only.
local Smoke = {}
function Smoke.run()
    assert(game:GetService("RunService"):IsStudio(), "Audit assertion at 4")
    local Economy = require(game:GetService("ServerScriptService").Server.Services.EconomyService)
    local admin, other = { UserId = 1 }, { UserId = 2 }
    local calls, errors = {}, {}
    local allowed, resolved = true, other
    local fake = {
        _adminService = {
            ValidateAdminAction = function(_, actor, action, data, source)
                assert(actor == admin and source == "client", "Audit assertion at 12")
                assert(
                    action == (data.reset and "setCurrency" or "adjustCurrency"),
                    "Audit assertion at 13"
                )
                return allowed, "denied", resolved
            end,
        },
        _dataService = {
            GetCurrencies = function(_, target)
                assert(target == other, "Audit assertion at 19")
                return { coins = 100, gems = 0 }
            end,
        },
        AddCurrency = function(_, target, currency, amount)
            table.insert(calls, { "add", target, currency, amount })
        end,
        RemoveCurrency = function(_, target, currency, amount)
            table.insert(calls, { "remove", target, currency, amount })
        end,
        _sendError = function(_, _, reason)
            table.insert(errors, reason)
        end,
    }
    local function run(data)
        Economy._handleAdminCurrencyRequest(fake, admin, data)
    end
    run({ currency = "coins", amount = 25, targetPlayerId = 2 })
    run({ currency = "coins", amount = -10, targetPlayerId = 2 })
    run({ reset = true, targetPlayerId = 2 })
    assert(#calls == 3, "Audit assertion at 39")
    assert(
        calls[1][1] == "add" and calls[1][2] == other and calls[1][4] == 25,
        "Audit assertion at 40"
    )
    assert(
        calls[2][1] == "remove" and calls[2][2] == other and calls[2][4] == 10,
        "Audit assertion at 41"
    )
    assert(
        calls[3][1] == "remove" and calls[3][2] == other and calls[3][4] == 100,
        "Audit assertion at 42"
    )
    resolved = nil
    run({ currency = "coins", amount = 1 })
    assert(calls[4][2] == admin, "Audit assertion at 45")
    for _, amount in { math.huge, -math.huge, 0 / 0, "100" } do
        run({ currency = "coins", amount = amount })
    end
    allowed = false
    run({ currency = "coins", amount = 10 })
    fake._adminService = nil
    run({ reset = true })
    assert(#calls == 4 and #errors == 2, "Audit assertion at 53")
    return {
        targetAdjust = true,
        targetRemove = true,
        targetReset = true,
        selfFallback = true,
        invalidAmountsBlocked = true,
        authorizationRequired = true,
    }
end
return Smoke
