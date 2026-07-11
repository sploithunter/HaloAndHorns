-- Pure multi-currency mutation orchestration. Runtime services provide balance
-- checks and mutation callbacks; this module owns ordering and compensation.

local CurrencyTransaction = {}

local function orderedEntries(values)
    local entries = {}
    for currency, amount in pairs(values or {}) do
        amount = math.floor(tonumber(amount) or 0)
        if amount > 0 then
            table.insert(entries, { currency = currency, amount = amount })
        end
    end
    table.sort(entries, function(a, b)
        return tostring(a.currency) < tostring(b.currency)
    end)
    return entries
end

function CurrencyTransaction.execute(options)
    options = options or {}
    local debits = orderedEntries(options.debits)
    local credits = orderedEntries(options.credits)
    local applied = {}

    for _, entry in ipairs(debits) do
        local called, affordable = pcall(options.canDebit, entry.currency, entry.amount)
        if not called or affordable ~= true then
            return { ok = false, reason = "precondition_failed", currency = entry.currency }
        end
    end

    local function rollback(cause, failedCurrency)
        local rollbackOk = true
        for index = #applied, 1, -1 do
            local entry = applied[index]
            local callback = entry.kind == "debit" and options.reverseDebit or options.reverseCredit
            local called, reversed = pcall(callback, entry.currency, entry.amount)
            rollbackOk = rollbackOk and called and reversed == true
        end
        return {
            ok = false,
            reason = rollbackOk and cause or "rollback_failed",
            cause = rollbackOk and nil or cause,
            currency = failedCurrency,
        }
    end

    for _, entry in ipairs(debits) do
        local called, appliedDebit = pcall(options.debit, entry.currency, entry.amount)
        if not called or appliedDebit ~= true then
            return rollback("debit_failed", entry.currency)
        end
        table.insert(applied, { kind = "debit", currency = entry.currency, amount = entry.amount })
    end

    for _, entry in ipairs(credits) do
        local called, appliedCredit = pcall(options.credit, entry.currency, entry.amount)
        if not called or appliedCredit ~= true then
            return rollback("credit_failed", entry.currency)
        end
        table.insert(applied, { kind = "credit", currency = entry.currency, amount = entry.amount })
    end

    if options.commit then
        local called, committed = pcall(options.commit)
        if not called or committed ~= true then
            return rollback("commit_failed")
        end
    end

    return { ok = true, applied = applied }
end

return CurrencyTransaction
