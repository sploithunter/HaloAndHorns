-- Pure access policy for the unreleased Merge place.
--
-- The canonical internal-account registry remains the source for Jason's creator/test alts.
-- A tiny additional list covers collaborators who need preview access without changing their
-- leaderboard/retention classification.

local InternalAccounts = require(script.Parent.InternalAccounts)

local MergeEggGateAccess = {}

local function listed(ids, userId)
    local target = tonumber(userId)
    if not target then
        return false
    end
    for _, configuredId in ipairs(type(ids) == "table" and ids or {}) do
        if tonumber(configuredId) == target then
            return true
        end
    end
    return false
end

function MergeEggGateAccess.allows(access, internalAccounts, userId)
    access = type(access) == "table" and access or {}
    if
        access.internal_accounts ~= false and InternalAccounts.isUserId(internalAccounts, userId)
    then
        return true
    end
    return listed(access.additional_user_ids, userId)
end

return MergeEggGateAccess
