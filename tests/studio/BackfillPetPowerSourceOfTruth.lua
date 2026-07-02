--[[
    Studio command bar:
    return require(game:GetService("ReplicatedStorage").Tests.studio.BackfillPetPowerSourceOfTruth).runText()

    Removes legacy saved pet power/stat fields from the current player's pet
    inventory so power is resolved from config + level at runtime.
]]

local BackfillPetPowerSourceOfTruth = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local REMOTE_NAME = "StudioSmokeTest"

local function waitForRemote(timeoutSeconds)
    local deadline = os.clock() + (timeoutSeconds or 20)
    repeat
        local instance = ReplicatedStorage:FindFirstChild(REMOTE_NAME)
        if instance then
            return instance
        end
        task.wait(0.1)
    until os.clock() >= deadline

    error("Timed out waiting for " .. REMOTE_NAME)
end

function BackfillPetPowerSourceOfTruth.run(options)
    options = options or {}
    local remote = waitForRemote(options.timeoutSeconds)
    local result = remote:InvokeServer("BackfillPetPowerSourceOfTruth", {})

    assert(result and result.ok, result and result.error or "BackfillPetPowerSourceOfTruth failed")
    return result
end

function BackfillPetPowerSourceOfTruth.runText(options)
    local result = BackfillPetPowerSourceOfTruth.run(options)
    return string.format(
        "BackfillPetPowerSourceOfTruth complete: player=%s inspected=%d changed=%d missingConfig=%d",
        tostring(result.player),
        tonumber(result.inspected) or 0,
        tonumber(result.changed) or 0,
        type(result.missingConfig) == "table" and #result.missingConfig or 0
    )
end

return BackfillPetPowerSourceOfTruth
