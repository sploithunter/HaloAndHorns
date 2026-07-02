--[[
    Client-coordinated Studio smoke test for egg proximity and hatching.

    Run in play mode through Studio MCP / command bar:

    return require(game:GetService("ReplicatedStorage").Tests.studio.EggProximitySmoke).runText()

    The server-side setup/assertion bridge is `StudioSmokeTestService`, exposed
    only while running in Studio.
]]

local EggProximitySmoke = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DEFAULT_TIMEOUT_SECONDS = 20
local REMOTE_NAME = "StudioSmokeTest"
local EggInteractionService = require(ReplicatedStorage.Shared.Services.EggInteractionService)

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

local function invoke(remote, action, payload)
    local response = remote:InvokeServer(action, payload or {})
    if type(response) ~= "table" then
        error("Studio smoke bridge returned non-table response")
    end
    if response.ok ~= true then
        error(response.error or ("Studio smoke bridge action failed: " .. tostring(action)))
    end
    return response
end

local function getCurrentTarget(player)
    local gui = player:FindFirstChild("PlayerGui")
    local targetGui = gui and gui:FindFirstChild("EggCurrentTarget")
    local frame = targetGui and targetGui:FindFirstChild("PreviewFrame")
    local target = frame and frame:FindFirstChild("CurrentTarget")

    return target and target.Value or nil, frame
end

local function getHatchPanel(player)
    local gui = player:FindFirstChild("PlayerGui")
    local panelGui = gui and gui:FindFirstChild("EggHatchPanel")
    local panel = panelGui and panelGui:FindFirstChild("Panel")
    return panel
end

local function waitForTarget(player, expectedValue, timeoutSeconds)
    return waitFor("egg current target " .. tostring(expectedValue), timeoutSeconds, function()
        local currentTarget, frame = getCurrentTarget(player)
        if currentTarget == expectedValue then
            return {
                currentTarget = currentTarget,
                visible = frame and frame.Visible or false,
                frame = frame,
            }
        end
        return nil
    end)
end

local function waitForHatchPanel(player, expectedVisible, timeoutSeconds)
    return waitFor(
        "egg hatch panel visibility " .. tostring(expectedVisible),
        timeoutSeconds,
        function()
            local panel = getHatchPanel(player)
            if panel and panel.Visible == expectedVisible then
                return panel
            end
            if expectedVisible == false and not panel then
                return true
            end
            return nil
        end
    )
end

local function waitForHatchSelectedCount(player, expectedCount, timeoutSeconds)
    return waitFor(
        "persisted hatch selected count " .. tostring(expectedCount),
        timeoutSeconds,
        function()
            local settingsFolder = player:FindFirstChild("Settings")
            local autoFolder = settingsFolder and settingsFolder:FindFirstChild("AutoSystems")
            local hatchFolder = autoFolder and autoFolder:FindFirstChild("Hatch")
            local selected = hatchFolder and hatchFolder:FindFirstChild("SelectedCount")
            if selected and selected.Value == expectedCount then
                return selected.Value
            end
            return nil
        end
    )
end

local function waitForHatchActionMode(player, expectedMode, timeoutSeconds)
    return waitFor(
        "persisted hatch action mode " .. tostring(expectedMode),
        timeoutSeconds,
        function()
            local settingsFolder = player:FindFirstChild("Settings")
            local autoFolder = settingsFolder and settingsFolder:FindFirstChild("AutoSystems")
            local hatchFolder = autoFolder and autoFolder:FindFirstChild("Hatch")
            local actionMode = hatchFolder and hatchFolder:FindFirstChild("ActionMode")
            if actionMode and actionMode.Value == expectedMode then
                return actionMode.Value
            end
            return nil
        end
    )
end

local function readHatchActionMode(player)
    local settingsFolder = player:FindFirstChild("Settings")
    local autoFolder = settingsFolder and settingsFolder:FindFirstChild("AutoSystems")
    local hatchFolder = autoFolder and autoFolder:FindFirstChild("Hatch")
    local actionMode = hatchFolder and hatchFolder:FindFirstChild("ActionMode")
    return actionMode and actionMode.Value or "single"
end

local function waitForHatchMode(player, optionName, expectedEnabled, timeoutSeconds)
    return waitFor(
        "persisted hatch mode " .. tostring(optionName) .. "=" .. tostring(expectedEnabled),
        timeoutSeconds,
        function()
            local settingsFolder = player:FindFirstChild("Settings")
            local autoFolder = settingsFolder and settingsFolder:FindFirstChild("AutoSystems")
            local hatchFolder = autoFolder and autoFolder:FindFirstChild("Hatch")
            local modesFolder = hatchFolder and hatchFolder:FindFirstChild("Modes")
            local modeValue = modesFolder and modesFolder:FindFirstChild(optionName)
            if modeValue and modeValue.Value == expectedEnabled then
                return true
            end
            return nil
        end
    )
end

local function readHatchMode(player, optionName)
    local settingsFolder = player:FindFirstChild("Settings")
    local autoFolder = settingsFolder and settingsFolder:FindFirstChild("AutoSystems")
    local hatchFolder = autoFolder and autoFolder:FindFirstChild("Hatch")
    local modesFolder = hatchFolder and hatchFolder:FindFirstChild("Modes")
    local modeValue = modesFolder and modesFolder:FindFirstChild(optionName)
    return modeValue and modeValue.Value == true or false
end

function EggProximitySmoke.run(options)
    options = options or {}

    local eggType = options.eggType or "basic_egg"
    local timeoutSeconds = options.timeoutSeconds or DEFAULT_TIMEOUT_SECONDS
    local assertUi = options.assertUi ~= false
    local player = getPlayer(options)
    local remote = waitFor(REMOTE_NAME .. " RemoteFunction", timeoutSeconds, function()
        local instance = ReplicatedStorage:FindFirstChild(REMOTE_NAME)
        if instance and instance:IsA("RemoteFunction") then
            return instance
        end
        return nil
    end)

    local started = false
    local success, result = pcall(function()
        local begin = invoke(remote, "BeginEggProximity", {
            eggType = eggType,
            setupAutoHatchUnlocked = false,
            setupGoldenModeUnlocked = false,
            setupChargedModeUnlocked = false,
            setupFastHatchUnlocked = false,
            setupSkipHatchUnlocked = false,
            setupMaxHatchCount = 5,
            setupAutoDeleteFilters = {
                enabled = false,
                rarities = { "common" },
                pet_types = { "bear" },
                variants = { "golden" },
            },
        })
        started = true

        invoke(remote, "MoveEggProximity", { placement = "far" })
        task.wait(0.35)

        if assertUi then
            waitForTarget(player, "None", timeoutSeconds)
            waitForHatchPanel(player, false, timeoutSeconds)
        end

        local far = invoke(remote, "HatchEggProximity")
        assert(far.result == "Error", "Far hatch should be rejected")
        assert(
            tostring(far.message):find("Too far", 1, true),
            "Far hatch rejected for wrong reason"
        )
        assert(far.afterCurrency == far.beforeCurrency, "Far hatch changed currency")
        assert(far.afterPetCount == far.beforePetCount, "Far hatch changed pet count")

        task.wait((far.cooldown or 0) + 0.25)

        invoke(remote, "MoveEggProximity", { placement = "near" })
        task.wait(0.35)

        if assertUi then
            local targetState = waitForTarget(player, eggType, timeoutSeconds)
            assert(targetState.visible == true, "Egg target UI was not visible near the egg")
            waitForHatchPanel(player, false, timeoutSeconds)

            local targetFrame = targetState.frame
            assert(targetFrame, "Egg target UI frame missing")
            assert(targetFrame:FindFirstChild("CostDetail"), "Egg target UI missing cost detail")
            local originalActionMode = readHatchActionMode(player)
            EggInteractionService:SetHatchActionMode("single")
            waitForHatchActionMode(player, "single", timeoutSeconds)
            targetFrame = waitFor("single hatch target display", timeoutSeconds, function()
                local _, frame = getCurrentTarget(player)
                if frame and frame:GetAttribute("EstimatedDisplayCount") == 1 then
                    return frame
                end
                return nil
            end)
            assert(
                targetFrame:GetAttribute("MaxEntitledHatchCount") == 5,
                "Egg target UI did not expose effective max hatch entitlement"
            )
            assert(
                targetFrame:GetAttribute("EstimatedCostEach") == begin.cost,
                "Egg target UI estimated per-egg cost mismatch"
            )
            assert(
                targetFrame:GetAttribute("EstimatedTotalCost") == begin.cost,
                "Egg target UI should show single-hatch cost by default"
            )
            assert(
                tostring(targetFrame.CostDetail.Text):find("each", 1, true),
                "Egg target UI cost detail did not explain per-egg cost"
            )

            EggInteractionService:SubmitHatchCountInput("4")
            waitForHatchSelectedCount(player, 4, timeoutSeconds)
            local debugState = EggInteractionService:GetHatchPanelDebugState()
            assert(
                debugState.selectedHatchCount == 4,
                "Hatch interaction service did not keep selected count"
            )
            assert(
                debugState.persistedSelectedHatchCount == 4,
                "Hatch interaction service did not read persisted selected count"
            )

            EggInteractionService:SetSelectedHatchCount(1)
            waitForHatchSelectedCount(player, 1, timeoutSeconds)

            EggInteractionService:SetHatchActionMode("max")
            waitForHatchActionMode(player, "max", timeoutSeconds)
            local maxTargetFrame = waitFor("max hatch target display", timeoutSeconds, function()
                local _, frame = getCurrentTarget(player)
                if frame and frame:GetAttribute("EstimatedDisplayCount") == 5 then
                    return frame
                end
                return nil
            end)
            debugState = EggInteractionService:GetHatchPanelDebugState()
            assert(
                debugState.hatchActionMode == "max",
                "Hatch interaction service did not keep hatch action mode"
            )
            assert(
                maxTargetFrame:GetAttribute("EstimatedTotalCost") == begin.cost * 5,
                "Egg target UI did not estimate the effective max hatch count"
            )
            assert(
                tostring(maxTargetFrame.CostDetail.Text):find("max 5", 1, true),
                "Egg target UI did not explain max hatch count"
            )
            assert(
                debugState.persistedHatchActionMode == "max",
                "Hatch interaction service did not read persisted hatch action mode"
            )
            EggInteractionService:SetHatchActionMode(originalActionMode)
            waitForHatchActionMode(player, originalActionMode, timeoutSeconds)

            local originalSilentHatch = readHatchMode(player, "silentHatch")
            local targetSilentHatch = not originalSilentHatch
            EggInteractionService:SetHatchModeState("silentHatch", targetSilentHatch)
            waitForHatchMode(player, "silentHatch", targetSilentHatch, timeoutSeconds)
            debugState = EggInteractionService:GetHatchPanelDebugState()
            assert(
                debugState.hatchModes and debugState.hatchModes.silentHatch == targetSilentHatch,
                "Hatch interaction service did not keep silent hatch mode"
            )
            assert(
                debugState.persistedHatchModes
                    and debugState.persistedHatchModes.silentHatch == targetSilentHatch,
                "Hatch interaction service did not read persisted silent hatch mode"
            )
            EggInteractionService:SetHatchModeState("silentHatch", originalSilentHatch)
            waitForHatchMode(player, "silentHatch", originalSilentHatch, timeoutSeconds)

            local originalShowHatch = readHatchMode(player, "showHatch")
            local targetShowHatch = not originalShowHatch
            EggInteractionService:SetHatchModeState("showHatch", targetShowHatch)
            waitForHatchMode(player, "showHatch", targetShowHatch, timeoutSeconds)
            debugState = EggInteractionService:GetHatchPanelDebugState()
            assert(
                debugState.hatchModes and debugState.hatchModes.showHatch == targetShowHatch,
                "Hatch interaction service did not keep show hatch mode"
            )
            assert(
                debugState.persistedHatchModes
                    and debugState.persistedHatchModes.showHatch == targetShowHatch,
                "Hatch interaction service did not read persisted show hatch mode"
            )
            EggInteractionService:SetHatchModeState("showHatch", originalShowHatch)
            waitForHatchMode(player, "showHatch", originalShowHatch, timeoutSeconds)
        end

        local near = invoke(remote, "HatchEggProximity")
        assert(type(near.result) == "table" and near.result.success == true, tostring(near.message))
        local expectedTotalCost = tonumber(near.result.TotalCost)
            or ((tonumber(near.cost) or 0) * (tonumber(near.result.hatchCount) or 1))
        local actualSpent = near.beforeCurrency - near.afterCurrency
        assert(
            actualSpent > 0 and actualSpent <= expectedTotalCost,
            string.format(
                "Near hatch currency delta was outside expected range: before=%s after=%s spent=%s expectedCost=%s",
                tostring(near.beforeCurrency),
                tostring(near.afterCurrency),
                tostring(actualSpent),
                tostring(expectedTotalCost)
            )
        )
        assert(near.afterPetCount == near.beforePetCount + 1, "Near hatch did not add one pet")

        invoke(remote, "MoveEggProximity", { placement = "far" })
        task.wait(0.35)

        if assertUi then
            waitForTarget(player, "None", timeoutSeconds)
            waitForHatchPanel(player, false, timeoutSeconds)
        end

        return {
            player = player.Name,
            eggType = begin.eggType,
            currency = begin.currency,
            cost = begin.cost,
            originalCurrency = begin.originalCurrency,
            originalPetCount = begin.originalPetCount,
            hatchedPet = near.result.Pet,
            hatchedVariant = near.result.Type,
        }
    end)

    local restoreResponse
    if started then
        restoreResponse = remote:InvokeServer("RestoreEggProximity", {})
    end

    if not success then
        error(result)
    end

    result.restored = type(restoreResponse) == "table" and restoreResponse.restored == true
    return result
end

function EggProximitySmoke.runText(options)
    local result = EggProximitySmoke.run(options)
    return string.format(
        "EggProximitySmoke passed: player=%s egg=%s cost=%d %s hatched=%s/%s restored=%s",
        result.player,
        result.eggType,
        result.cost,
        result.currency,
        tostring(result.hatchedPet),
        tostring(result.hatchedVariant),
        tostring(result.restored)
    )
end

return EggProximitySmoke
