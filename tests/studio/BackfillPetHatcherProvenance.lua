--[[
    Studio command bar:
    return require(game:GetService("ReplicatedStorage").Tests.studio.BackfillPetHatcherProvenance).runText()

    Adds hatcher provenance to existing valuable pets for the current player.
]]

local BackfillPetHatcherProvenance = {}

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

function BackfillPetHatcherProvenance.run(options)
    options = options or {}
    local remote = waitForRemote(options.timeoutSeconds)
    local result = remote:InvokeServer("BackfillPetHatcherProvenance", {
        overwrite = options.overwrite == true,
        clearLegacySource = options.clearLegacySource ~= false,
    })

    assert(result and result.ok, result and result.error or "BackfillPetHatcherProvenance failed")
    return result
end

function BackfillPetHatcherProvenance.runText(options)
    local result = BackfillPetHatcherProvenance.run(options)
    return string.format(
        "BackfillPetHatcherProvenance complete: player=%s eligible=%d changed=%d skippedExisting=%d",
        tostring(result.player),
        tonumber(result.eligible) or 0,
        tonumber(result.changed) or 0,
        tonumber(result.skippedExisting) or 0
    )
end

return BackfillPetHatcherProvenance
