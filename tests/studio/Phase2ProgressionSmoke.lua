--[[
    Studio command bar:
    return require(game:GetService("ReplicatedStorage").Tests.studio.Phase2ProgressionSmoke).runText()
]]

local Phase2ProgressionSmoke = {}

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

function Phase2ProgressionSmoke.run(options)
    options = options or {}
    local remote = waitForRemote(options.timeoutSeconds)
    local result = remote:InvokeServer("RunPhase2ProgressionSmoke", {
        targetZoneId = options.targetZoneId or "Meadow",
    })

    assert(result and result.ok, result and result.error or "Phase 2 smoke failed")
    assert(result.restored == true, "Phase 2 smoke did not restore profile state")
    assert(result.paidUnlock and result.paidUnlock.ok == true, "Paid zone unlock did not succeed")
    assert(result.equipLevel == 1, "Pet equip upgrade did not reach level 1")
    assert(result.storageLevel == 1, "Pet storage upgrade did not reach level 1")
    assert(result.afterStorageSlots > result.beforeStorageSlots, "Storage slots did not increase")
    assert(result.crystalValueLevel == 1, "Crystal value upgrade did not reach level 1")
    assert(
        result.resolvedCrystalReward > result.baseCrystalReward,
        "Crystal value upgrade did not increase resolved reward"
    )

    return result
end

function Phase2ProgressionSmoke.runText(options)
    local result = Phase2ProgressionSmoke.run(options)
    return string.format(
        "Phase2ProgressionSmoke passed: zone=%s unlock=%d %s equipLevel=%d maxPetSlots=%d storage=%d->%d crystalReward=%d->%d restored=%s",
        result.targetZoneId,
        result.unlockCost,
        result.unlockCurrency,
        result.equipLevel,
        result.maxPetSlots,
        result.beforeStorageSlots,
        result.afterStorageSlots,
        result.baseCrystalReward,
        result.resolvedCrystalReward,
        tostring(result.restored)
    )
end

return Phase2ProgressionSmoke
