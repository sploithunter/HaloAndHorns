--[[
    Studio command bar:
    return require(game:GetService("ReplicatedStorage").Tests.studio.SyntheticExpansionSmoke).runText()
]]

local SyntheticExpansionSmoke = {}

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

function SyntheticExpansionSmoke.run(options)
    options = options or {}
    local remote = waitForRemote(options.timeoutSeconds)
    local result = remote:InvokeServer("RunSyntheticExpansionSmoke", {})

    assert(result and result.ok, result and result.error or "Synthetic expansion smoke failed")
    assert(result.restored == true, "Synthetic expansion smoke did not restore map/profile state")
    assert(result.targetZoneId == "crystal_world", "Synthetic portal targeted wrong world")
    assert(result.targetAreaId == "CrystalCavern", "Synthetic portal reached wrong area")
    assert(result.spawnZoneCount > 0, "Synthetic expanded area did not create a SpawnZone")

    return result
end

function SyntheticExpansionSmoke.runText(options)
    local result = SyntheticExpansionSmoke.run(options)
    return string.format(
        "SyntheticExpansionSmoke passed: %s->%s area=%s spawnZones=%d restored=%s",
        result.sourceZoneId,
        result.targetZoneId,
        result.targetAreaId,
        result.spawnZoneCount,
        tostring(result.restored)
    )
end

return SyntheticExpansionSmoke
