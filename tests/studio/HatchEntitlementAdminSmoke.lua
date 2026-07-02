--[[
    Studio smoke test for admin-managed hatch entitlement stubs.

    Run in play mode:

    return require(game:GetService("ReplicatedStorage").Tests.studio.HatchEntitlementAdminSmoke).runText()
]]

local HatchEntitlementAdminSmoke = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signals = require(ReplicatedStorage.Shared.Network.Signals)

local DEFAULT_TIMEOUT_SECONDS = 20

local ENTITLEMENTS = {
    autoHatch = "AutoHatchUnlocked",
    goldenMode = "GoldenHatchUnlocked",
    chargedMode = "ChargedHatchUnlocked",
    fastHatch = "FastHatchUnlocked",
    skipHatch = "SkipHatchUnlocked",
    maxHatchCount = "MaxEggHatchCount",
    luckBonus = "HatchLuckBonus",
    secretLuckBonus = "SecretHatchLuckBonus",
}

local NUMERIC_ENTITLEMENTS = {
    maxHatchCount = true,
    luckBonus = true,
    secretLuckBonus = true,
}

local function waitFor(description, timeoutSeconds, predicate)
    local deadline = os.clock() + (timeoutSeconds or DEFAULT_TIMEOUT_SECONDS)
    while os.clock() < deadline do
        local result = predicate()
        if result then
            return result
        end
        task.wait(0.1)
    end
    error("Timed out waiting for " .. description)
end

local function getPlayer(options)
    if options.player then
        return options.player
    end

    return Players.LocalPlayer
        or Players:GetPlayers()[1]
        or waitFor("a player", options.timeoutSeconds, function()
            return Players.LocalPlayer or Players:GetPlayers()[1]
        end)
end

local function cloneAttributes(player)
    local snapshot = {}
    for entitlementId, attributeName in pairs(ENTITLEMENTS) do
        snapshot[entitlementId] = player:GetAttribute(attributeName)
    end
    return snapshot
end

local function invokeAdminEntitlement(payload, timeoutSeconds)
    local result
    local connection
    connection = Signals.AdminToolResult.OnClientEvent:Connect(function(response)
        if type(response) == "table" and response.kind == "hatch_entitlement" then
            result = response
        end
    end)

    Signals.Admin_SetHatchEntitlement:FireServer(payload)
    local ok, response = pcall(waitFor, "hatch entitlement admin result", timeoutSeconds, function()
        return result
    end)

    if connection then
        connection:Disconnect()
    end
    if not ok then
        error(response)
    end
    if response.success ~= true then
        error(response.message or "Hatch entitlement admin command failed")
    end
    return response
end

local function assertBooleanEntitlements(player, expectedValue)
    for entitlementId, attributeName in pairs(ENTITLEMENTS) do
        if not NUMERIC_ENTITLEMENTS[entitlementId] then
            assert(
                player:GetAttribute(attributeName) == expectedValue,
                entitlementId .. " attribute mismatch"
            )
        end
    end
end

local function restoreAttributes(original, timeoutSeconds)
    for entitlementId in pairs(ENTITLEMENTS) do
        local originalValue = original[entitlementId]
        if originalValue == nil then
            invokeAdminEntitlement({
                entitlement = entitlementId,
                mode = "reset",
            }, timeoutSeconds)
        else
            invokeAdminEntitlement({
                entitlement = entitlementId,
                value = originalValue,
            }, timeoutSeconds)
        end
    end
end

function HatchEntitlementAdminSmoke.run(options)
    options = options or {}
    local timeoutSeconds = options.timeoutSeconds or DEFAULT_TIMEOUT_SECONDS
    local player = getPlayer(options)
    local originalAttributes = cloneAttributes(player)
    local restored = false

    local success, result = pcall(function()
        local status = invokeAdminEntitlement({
            mode = "status",
        }, timeoutSeconds)
        assert(status.hatchEntitlements, "Status response missing hatch entitlements")

        invokeAdminEntitlement({
            mode = "lock_all_modes",
        }, timeoutSeconds)
        assertBooleanEntitlements(player, false)

        invokeAdminEntitlement({
            mode = "unlock_all_modes",
        }, timeoutSeconds)
        assertBooleanEntitlements(player, true)

        local maxResult = invokeAdminEntitlement({
            entitlement = "maxHatchCount",
            value = 25,
        }, timeoutSeconds)
        assert(player:GetAttribute("MaxEggHatchCount") == 25, "Max hatch count not set")
        assert(
            maxResult.hatchEntitlements
                and maxResult.hatchEntitlements.maxHatchCount
                and maxResult.hatchEntitlements.maxHatchCount.effective == 25,
            "Max hatch count not reflected in result"
        )

        local luckResult = invokeAdminEntitlement({
            entitlement = "luckBonus",
            value = 2.5,
        }, timeoutSeconds)
        assert(player:GetAttribute("HatchLuckBonus") == 2.5, "Hatch luck bonus not set")
        assert(
            luckResult.hatchEntitlements
                and luckResult.hatchEntitlements.luckBonus
                and luckResult.hatchEntitlements.luckBonus.effective == 2.5,
            "Hatch luck bonus not reflected in result"
        )

        local secretLuckResult = invokeAdminEntitlement({
            entitlement = "secretLuckBonus",
            value = 0.5,
        }, timeoutSeconds)
        assert(
            player:GetAttribute("SecretHatchLuckBonus") == 0.5,
            "Secret hatch luck bonus not set"
        )
        assert(
            secretLuckResult.hatchEntitlements
                and secretLuckResult.hatchEntitlements.secretLuckBonus
                and secretLuckResult.hatchEntitlements.secretLuckBonus.effective == 0.5,
            "Secret hatch luck bonus not reflected in result"
        )

        invokeAdminEntitlement({
            mode = "reset_all",
        }, timeoutSeconds)
        for _, attributeName in pairs(ENTITLEMENTS) do
            assert(player:GetAttribute(attributeName) == nil, attributeName .. " did not reset")
        end

        return {
            player = player.Name,
            checked = 8,
        }
    end)

    local restoreOk, restoreError = pcall(function()
        restoreAttributes(originalAttributes, timeoutSeconds)
        restored = true
    end)

    if not success then
        error(result)
    end
    if not restoreOk then
        error(restoreError)
    end

    result.restored = restored
    return result
end

function HatchEntitlementAdminSmoke.runText(options)
    local result = HatchEntitlementAdminSmoke.run(options)
    return string.format(
        "HatchEntitlementAdminSmoke passed: player=%s checked=%d restored=%s",
        result.player,
        result.checked,
        tostring(result.restored)
    )
end

return HatchEntitlementAdminSmoke
