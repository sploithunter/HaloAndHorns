-- Pure spend/grant/refund orchestration for shop purchases. Runtime services
-- provide the mutation callbacks; this module owns ordering and rollback.

local ShopPurchaseTransaction = {}

local function invoke(callback, ...)
    local ok, result = pcall(callback, ...)
    return ok, result
end

local function orderedCosts(costs)
    local currencies = {}
    for currency in pairs(costs or {}) do
        table.insert(currencies, currency)
    end
    table.sort(currencies)
    return currencies
end

function ShopPurchaseTransaction.execute(options)
    options = options or {}
    local costs = options.costs or {}
    local spent = {}

    local function rollback(cause, failedCurrency)
        local rollbackOk = true
        for index = #spent, 1, -1 do
            local entry = spent[index]
            local called, refunded = invoke(options.refund, entry.currency, entry.amount)
            rollbackOk = rollbackOk and called and refunded == true
        end
        if not rollbackOk then
            return {
                ok = false,
                reason = "rollback_failed",
                cause = cause,
                currency = failedCurrency,
            }
        end
        return { ok = false, reason = cause, currency = failedCurrency }
    end

    for _, currency in ipairs(orderedCosts(costs)) do
        local amount = costs[currency]
        local called, debited = invoke(options.debit, currency, amount)
        if not called or debited ~= true then
            return rollback("debit_failed", currency)
        end
        table.insert(spent, { currency = currency, amount = amount })
    end

    local grantCalled, grantResult = invoke(options.grant)
    if not grantCalled or type(grantResult) ~= "table" or grantResult.ok ~= true then
        return rollback("grant_failed")
    end

    return { ok = true, granted = grantResult, spent = spent }
end

return ShopPurchaseTransaction
