--[[
    Studio command bar:
    return require(game:GetService("ReplicatedStorage").Tests.studio.Phase3StatsSmoke).runText()
]]

local Phase3StatsSmoke = {}

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

function Phase3StatsSmoke.run(options)
    options = options or {}
    local remote = waitForRemote(options.timeoutSeconds)
    local result = remote:InvokeServer("RunPhase3StatsSmoke", {
        firstPet = options.firstPet or "bear",
        secondPet = options.secondPet or "bunny",
        variant = options.variant or "basic",
    })

    assert(result and result.ok, result and result.error or "Phase 3 stats smoke failed")
    assert(result.restored == true, "Phase 3 smoke did not restore profile state")
    assert(result.indexCount == 2, "Pet index did not record two distinct pets")
    assert(result.distinctPets == 2, "distinct_pets counter did not mirror pet index")
    assert(result.indexMilestone == true, "Pet index milestone did not complete")
    assert(result.eggsAchievement == true, "Egg achievement did not complete")
    assert(result.gemsAfterAchievements > result.gemsAfterIndex, "Achievement did not grant gems")
    assert(result.leaderboardEntries >= 1, "Live leaderboard did not include entries")

    return result
end

function Phase3StatsSmoke.runText(options)
    local result = Phase3StatsSmoke.run(options)
    return string.format(
        "Phase3StatsSmoke passed: pets=%s/%s index=%d distinct=%d gems=%d->%d leaderboardEntries=%d restored=%s",
        result.firstPet,
        result.secondPet,
        result.indexCount,
        result.distinctPets,
        result.gemsAfterIndex,
        result.gemsAfterAchievements,
        result.leaderboardEntries,
        tostring(result.restored)
    )
end

return Phase3StatsSmoke
