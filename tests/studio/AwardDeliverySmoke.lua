--[[
    Live Studio proof for ProfileStore-message award delivery + client notification.

    Run in Play mode:
      return require(game:GetService("ReplicatedStorage").Tests.studio.AwardDeliverySmoke).runText()
]]

local AwardDeliverySmoke = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signals = require(ReplicatedStorage.Shared.Network.Signals)

local function waitFor(description, timeoutSeconds, predicate)
    local deadline = os.clock() + timeoutSeconds
    while os.clock() < deadline do
        local result = predicate()
        if result then
            return result
        end
        task.wait(0.1)
    end
    error("Timed out waiting for " .. description)
end

function AwardDeliverySmoke.run(options)
    options = options or {}
    local timeout = tonumber(options.timeoutSeconds) or 20
    local player = Players.LocalPlayer
        or waitFor("the local player", timeout, function()
            return Players.LocalPlayer
        end)
    local remote = waitFor("StudioSmokeTest", timeout, function()
        local candidate = ReplicatedStorage:FindFirstChild("StudioSmokeTest")
        return candidate and candidate:IsA("RemoteFunction") and candidate or nil
    end)

    local observed
    local connection = Signals.GameEvent.OnClientEvent:Connect(function(name, ctx)
        if name == "award_delivered" and type(ctx) == "table" then
            observed = ctx
        end
    end)

    local begin = remote:InvokeServer("BeginAwardDeliverySmoke", {})
    assert(type(begin) == "table" and begin.ok == true, begin and begin.error or "queue failed")
    waitFor("award_delivered GameEvent", timeout, function()
        return observed and observed.awardId == begin.awardId
    end)
    connection:Disconnect()

    local check = remote:InvokeServer("CheckAwardDeliverySmoke", {})
    local restored = remote:InvokeServer("RestoreAwardDeliverySmoke", {})
    assert(check and check.ok and check.claimed, "stable award id was not claimed")
    assert(check.granted, "the queued Gem was not granted")
    assert(restored and restored.ok and restored.restored, "smoke state was not restored")
    return {
        ok = true,
        awardId = begin.awardId,
        notification = observed.name,
        gems = string.format("%d -> %d -> %d", check.originalGems, check.gems, check.originalGems),
    }
end

function AwardDeliverySmoke.runText(options)
    local result = AwardDeliverySmoke.run(options)
    return string.format(
        "AwardDeliverySmoke passed: id=%s notification=%s gems=%s",
        result.awardId,
        result.notification,
        result.gems
    )
end

return AwardDeliverySmoke
