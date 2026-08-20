--[[
    InternalAccounts — helpers over configs/internal_accounts.lua.
]]

local InternalAccounts = {}

function InternalAccounts.userIds(config)
    local ids = {}
    for _, account in ipairs((config and config.accounts) or {}) do
        local userId = tonumber(type(account) == "table" and account.id or account)
        if userId then
            table.insert(ids, userId)
        end
    end
    return ids
end

function InternalAccounts.userIdSet(config)
    local set = {}
    for _, userId in ipairs(InternalAccounts.userIds(config)) do
        set[userId] = true
    end
    return set
end

function InternalAccounts.namePrefixes(config)
    local prefixes = {}
    for _, prefix in ipairs((config and config.excluded_name_prefixes) or {}) do
        if type(prefix) == "string" and prefix ~= "" then
            table.insert(prefixes, prefix)
        end
    end
    return prefixes
end

function InternalAccounts.isUserId(config, userId)
    return InternalAccounts.userIdSet(config)[tonumber(userId)] == true
end

return InternalAccounts
