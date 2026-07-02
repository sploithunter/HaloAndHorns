local ReplicatedStorage = game:GetService("ReplicatedStorage")

local M = {}

local function invoke(action, payload)
    local remote = ReplicatedStorage:WaitForChild("StudioSmokeTest", 10)
    assert(remote and remote:IsA("RemoteFunction"), "StudioSmokeTest remote not found")
    local result = remote:InvokeServer(action, payload or {})
    assert(type(result) == "table", "Expected table result")
    return result
end

function M.run()
    local result = invoke("CheckEternalPowerSmoke")
    assert(result.ok, result.error or "Eternal power smoke failed")
    return result
end

function M.runText()
    local result = M.run()
    local rows = {}
    for _, row in ipairs(result.rows or {}) do
        table.insert(
            rows,
            string.format(
                "%s base=%s effective=%s eternal=%s%%",
                tostring(row.name),
                tostring(row.basePower),
                tostring(row.effectivePower),
                tostring(row.eternalPercent)
            )
        )
    end

    return string.format(
        "EternalPowerSmoke passed: strongestBase=%s eternalCount=%s %s",
        tostring(result.topTeamAverageBasePower or result.strongestBasePower),
        tostring(result.eternalCount),
        table.concat(rows, "; ")
    )
end

return M
