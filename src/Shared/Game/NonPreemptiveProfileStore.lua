-- Adapter for the pinned ProfileStore backend. Background work may acquire an existing,
-- unlocked account, but may NEVER request force-load or steal another session.
local Adapter = {}

function Adapter.wrap(backend)
    local expected, denied = {}, {}
    local proxy = {}
    function proxy:canAcquire(key, eligible)
        -- Cheap read-only screening avoids treating nonexistent pool accounts as API failures.
        -- This is only a hint: UpdateAsync below still makes the authoritative lock decision.
        local current = backend:GetAsync(key)
        return type(current) == "table"
            and type(current.Data) == "table"
            and type(current.MetaData) == "table"
            and current.MetaData.ActiveSession == nil
            and (eligible == nil or eligible(current.Data))
    end
    function proxy:UpdateAsync(key, transform)
        local value, info = backend:UpdateAsync(key, function(current, keyInfo)
            local session = current and current.MetaData and current.MetaData.ActiveSession
            local token = session and session[3]
            if expected[key] and current and token ~= expected[key] then
                -- Let ProfileStore observe the replacement owner's session and terminate its
                -- release retry loop. Do not run the stale writer's transform or alter metadata.
                return current, keyInfo and keyInfo:GetUserIds(), keyInfo and keyInfo:GetMetadata()
            end
            if not current then
                denied[key] = true
                return nil
            end
            if not expected[key] and session ~= nil then
                denied[key] = true
                return nil
            end
            return transform(current, keyInfo)
        end)
        if denied[key] then
            -- Transport-only cancellation result; NEVER written to storage. ProfileStore
            -- recognizes no active session and Cancel=true without an artificial API error.
            -- Do not return another owner's session: the pinned library compares place/job
            -- (not unique token) while constructing a loaded profile in the same server.
            return { MetaData = {} }, info
        end
        local session = value and value.MetaData and value.MetaData.ActiveSession
        if value and not denied[key] and not expected[key] and session then
            expected[key] = session[3]
        end
        return value, info
    end
    function proxy:begin(key)
        expected[key], denied[key] = nil, nil
    end
    function proxy:denied(key)
        return denied[key] == true
    end
    return proxy
end

return Adapter
