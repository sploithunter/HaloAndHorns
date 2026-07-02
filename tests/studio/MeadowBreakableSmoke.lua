--[[
    Studio command bar:
    return require(game:GetService("ReplicatedStorage").Tests.studio.MeadowBreakableSmoke).runText()
]]

local MeadowBreakableSmoke = {}

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

function MeadowBreakableSmoke.run(options)
    options = options or {}
    local remote = waitForRemote(options.timeoutSeconds)
    local result = remote:InvokeServer("RunMeadowBreakableSmoke", {
        sourceAreaId = options.sourceAreaId or "Spawn",
        targetZoneId = options.targetZoneId or "Meadow",
        breakableId = options.breakableId or "BigBlueCrystal",
    })

    assert(result and result.ok, result and result.error or "Meadow breakable smoke failed")
    assert(result.restored == true, "Meadow breakable smoke did not restore profile state")
    assert(result.targetAreaId == "Meadow", "Smoke did not target Meadow")
    assert(result.breakableId == "BigBlueCrystal", "Smoke did not use BigBlueCrystal")
    assert(result.currency == "crystals", "Meadow breakable did not pay crystals")
    assert(
        result.currencyDelta == result.expectedReward,
        "Currency delta did not match expected reward"
    )
    assert(
        result.counterAfter == result.counterBefore + 1,
        "breakables_broken counter did not increment"
    )

    return result
end

function MeadowBreakableSmoke.runText(options)
    local result = MeadowBreakableSmoke.run(options)
    return string.format(
        "MeadowBreakableSmoke passed: area=%s breakable=%s reward=%d %s counter=%d->%d restored=%s",
        result.targetAreaId,
        result.breakableId,
        result.currencyDelta,
        result.currency,
        result.counterBefore,
        result.counterAfter,
        tostring(result.restored)
    )
end

return MeadowBreakableSmoke
