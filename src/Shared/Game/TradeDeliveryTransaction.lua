-- Pure grant/rollback orchestration for escrow delivery. Runtime services own
-- mutations; this module guarantees stable ordering and reverse-order undo.

local TradeDeliveryTransaction = {}

local function orderedDescriptors(escrow)
    local descriptors = {}
    for _, descriptor in pairs(escrow or {}) do
        table.insert(descriptors, descriptor)
    end
    table.sort(descriptors, function(a, b)
        return tostring(a.uid) < tostring(b.uid)
    end)
    return descriptors
end

local function orderedOperations(legs)
    local operations = {}
    for legIndex, leg in ipairs(legs or {}) do
        for _, descriptor in ipairs(orderedDescriptors(leg.escrow)) do
            table.insert(operations, {
                recipient = leg.recipient,
                descriptor = descriptor,
                legIndex = legIndex,
                rank = descriptor.category == "currencies" and 2 or 1,
            })
        end
    end
    table.sort(operations, function(a, b)
        if a.rank ~= b.rank then
            return a.rank < b.rank
        end
        if a.legIndex ~= b.legIndex then
            return a.legIndex < b.legIndex
        end
        return tostring(a.descriptor.uid) < tostring(b.descriptor.uid)
    end)
    return operations
end

function TradeDeliveryTransaction.execute(options)
    options = options or {}
    local receipts = {}

    local function rollback(cause)
        local rollbackOk = true
        for index = #receipts, 1, -1 do
            local called, undone = pcall(options.revoke, receipts[index])
            rollbackOk = rollbackOk and called and undone == true
        end
        return {
            ok = false,
            reason = rollbackOk and "grant_failed" or "rollback_failed",
            cause = cause,
        }
    end

    for _, operation in ipairs(orderedOperations(options.legs)) do
        local called, receipt = pcall(options.grant, operation.recipient, operation.descriptor)
        if not called or type(receipt) ~= "table" then
            return rollback(called and "grant_rejected" or tostring(receipt))
        end
        table.insert(receipts, receipt)
    end

    return { ok = true, receipts = receipts }
end

return TradeDeliveryTransaction
