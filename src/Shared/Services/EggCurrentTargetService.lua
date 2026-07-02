--[[
    EggCurrentTargetService - Following working game's CurrentTarget pattern
    
    Implements the VisibleHandler pattern from the working game:
    - Continuously scans for nearby eggs
    - Sets CurrentTarget.Value 
    - Positions UI at egg's world position
    - Calls setLastEgg server for persistence
--]]

local EggCurrentTargetService = {}

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Dependencies
local Locations = require(ReplicatedStorage.Shared.Locations)
local eggSystemConfig = Locations.getConfig("egg_system")
local petConfig = Locations.getConfig("pets")
local EggWorldQuery = require(ReplicatedStorage.Shared.Services.EggWorldQuery)

-- Services
local eggPetPreviewService = nil

-- Get player and camera
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- Configuration from config file
local MAX_MAGNITUDE = eggSystemConfig.proximity.max_distance
local UPDATE_INTERVAL = eggSystemConfig.performance.update_interval
local SERVER_UPDATE_THRESHOLD = eggSystemConfig.performance.server_update_threshold

-- Variables
local timecounter = 0
local counter = 0
local currentTargetUI = nil
local currentTarget = "None"
local heartbeatConnection = nil
local serviceInitialized = false

-- Logger setup using singleton pattern
local Logger
local loggerSuccess, loggerResult = pcall(function()
    return require(Locations.Logger)
end)

if loggerSuccess and loggerResult then
    Logger = loggerResult -- Use singleton directly
else
    Logger = {
        Info = function(_self, message, context)
            print("[INFO]", message, context)
        end,
        Warn = function(_self, message, context)
            warn("[WARN]", message, context)
        end,
        Error = function(_self, message, context)
            warn("[ERROR]", message, context)
        end,
        Debug = function(_self, message, context)
            print("[DEBUG]", message, context)
        end,
    }
end

-- === HELPER FUNCTIONS ===

local function safeFormat(template, ...)
    template = tostring(template or "%s")
    local ok, text = pcall(function(...)
        return string.format(template, ...)
    end, ...)
    if ok then
        return text
    end
    return table.concat({ ... }, " ")
end

local function getHatchActionPrompt()
    local promptConfig = eggSystemConfig.ui.interaction_prompt or {}
    local interactionKey = eggSystemConfig.proximity.interaction_key.Name
    local maxKey = eggSystemConfig.proximity.hatch_max_key.Name
    local autoKey = eggSystemConfig.proximity.auto_hatch_key.Name

    if promptConfig.mode == "advertised_hotkeys" then
        return safeFormat(
            promptConfig.advertised_text or "%s Hatch | %s Max | %s Auto",
            interactionKey,
            maxKey,
            autoKey
        )
    end

    local settingsFolder = player:FindFirstChild("Settings")
    local autoFolder = settingsFolder and settingsFolder:FindFirstChild("AutoSystems")
    local hatchFolder = autoFolder and autoFolder:FindFirstChild("Hatch")
    local actionModeValue = hatchFolder and hatchFolder:FindFirstChild("ActionMode")
    local actionMode = actionModeValue
            and actionModeValue:IsA("StringValue")
            and actionModeValue.Value
        or eggSystemConfig.ui.hatch_panel.default_action_mode
        or "single"
    actionMode = tostring(actionMode):lower()

    if actionMode == "max" then
        return safeFormat(promptConfig.clean_max_text or "%s Max Hatch", interactionKey)
    elseif actionMode == "auto" then
        return safeFormat(promptConfig.clean_auto_text or "%s Auto Hatch", interactionKey)
    end

    return safeFormat(promptConfig.clean_text or "%s Hatch", interactionKey)
end

local function titleCaseId(value)
    return tostring(value or ""):gsub("(%l)(%w*)", function(a, b)
        return string.upper(a) .. b
    end)
end

local function getCurrencyIcon(currency)
    if currency == "gems" then
        return "💎"
    elseif currency == "crystals" then
        return "🔮"
    end
    return "💰"
end

local function getCurrencyAttributeName(currency)
    return tostring(currency or ""):gsub("^%l", string.upper)
end

local function getPlayerCurrencyBalance(currency)
    local value = player:GetAttribute(getCurrencyAttributeName(currency))
    if value == nil then
        return nil
    end
    return math.max(0, tonumber(value) or 0)
end

local function getEffectiveMaxHatchCount()
    local hatching = eggSystemConfig.hatching or {}
    local stubs = hatching.shop_stubs or {}
    local maxStub = stubs.max_hatch_count or {}
    local maxCount = math.clamp(math.floor(tonumber(hatching.max_count) or 99), 1, 99)
    local configuredDefault = tonumber(maxStub.default_value)
        or tonumber(hatching.default_max_entitled_count)
        or maxCount
    local attributeMax = tonumber(player:GetAttribute("MaxEggHatchCount"))
    local effective = attributeMax or configuredDefault
    return math.clamp(math.floor(tonumber(effective) or 1), 1, maxCount)
end

local function getHatchActionMode()
    local settingsFolder = player:FindFirstChild("Settings")
    local autoFolder = settingsFolder and settingsFolder:FindFirstChild("AutoSystems")
    local hatchFolder = autoFolder and autoFolder:FindFirstChild("Hatch")
    local actionModeValue = hatchFolder and hatchFolder:FindFirstChild("ActionMode")
    local actionMode = actionModeValue
            and actionModeValue:IsA("StringValue")
            and actionModeValue.Value
        or eggSystemConfig.ui.hatch_panel.default_action_mode
        or "single"
    actionMode = tostring(actionMode):lower()
    if actionMode == "max" or actionMode == "auto" then
        return actionMode
    end
    return "single"
end

local function getHatchDisplayCount()
    local actionMode = getHatchActionMode()
    if actionMode == "max" or actionMode == "auto" then
        return getEffectiveMaxHatchCount(), actionMode
    end
    return 1, actionMode
end

function EggCurrentTargetService:DetermineClosest(inRangeEggs)
    local closest = inRangeEggs[1]
    for index = 2, #inRangeEggs do
        if inRangeEggs[index].distance < closest.distance then
            closest = inRangeEggs[index]
        end
    end

    return closest
end

function EggCurrentTargetService:CreateEggUI()
    for _, child in ipairs(player.PlayerGui:GetChildren()) do
        if child.Name == "EggCurrentTarget" then
            child:Destroy()
        end
    end
    currentTargetUI = nil

    -- Create UI similar to working game's EggPreview
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "EggCurrentTarget"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = player.PlayerGui

    local frame = Instance.new("Frame")
    frame.Name = "PreviewFrame"
    frame.Active = true -- the whole card is tappable (see CardButton below)
    frame.Size = UDim2.new(
        0,
        eggSystemConfig.ui.preview_size.width,
        0,
        eggSystemConfig.ui.preview_size.height
    )
    frame.BackgroundColor3 = eggSystemConfig.ui.colors.background
    frame.BorderSizePixel = 0
    frame.Visible = false -- Start hidden until an egg is in range
    frame.Parent = screenGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, eggSystemConfig.ui.corner_radius)
    corner.Parent = frame

    local stroke = Instance.new("UIStroke")
    stroke.Thickness = eggSystemConfig.ui.border_thickness
    stroke.Color = eggSystemConfig.ui.colors.border
    stroke.Parent = frame

    -- the ENTIRE card is the hatch button (Jason: "you just click the entire
    -- [card]" — biggest possible touch target, right where the player is looking).
    -- EggInteractionService registers the actual handler via SetCardActivatedHandler.
    local cardBtn = Instance.new("TextButton")
    cardBtn.Name = "CardButton"
    cardBtn.Size = UDim2.fromScale(1, 1)
    cardBtn.BackgroundTransparency = 1
    cardBtn.Text = ""
    cardBtn.ZIndex = 5
    cardBtn.Parent = frame
    cardBtn.Activated:Connect(function()
        if self._cardActivatedHandler then
            self._cardActivatedHandler()
        end
    end)

    local eggNameLabel = Instance.new("TextLabel")
    eggNameLabel.Name = "EggName"
    eggNameLabel.Size = UDim2.new(1, -10, 0.32, 0)
    eggNameLabel.Position = UDim2.new(0, 5, 0, 2)
    eggNameLabel.BackgroundTransparency = 1
    eggNameLabel.Text = "Basic Egg"
    eggNameLabel.TextColor3 = eggSystemConfig.ui.colors.text_primary
    eggNameLabel.TextScaled = true
    eggNameLabel.Font = eggSystemConfig.ui.fonts.title
    eggNameLabel.Parent = frame

    -- Price display
    local priceLabel = Instance.new("TextLabel")
    priceLabel.Name = "Price"
    priceLabel.Size = UDim2.new(1, -10, 0.25, 0)
    priceLabel.Position = UDim2.new(0, 5, 0.32, 0)
    priceLabel.BackgroundTransparency = 1
    priceLabel.Text = "💰 100 Coins" -- Will be dynamically set
    priceLabel.TextColor3 = eggSystemConfig.ui.colors.text_secondary
    priceLabel.TextScaled = true
    priceLabel.Font = eggSystemConfig.ui.fonts.prompt
    priceLabel.Parent = frame

    local costDetailLabel = Instance.new("TextLabel")
    costDetailLabel.Name = "CostDetail"
    costDetailLabel.Size = UDim2.new(1, -10, 0.18, 0)
    costDetailLabel.Position = UDim2.new(0, 5, 0.56, 0)
    costDetailLabel.BackgroundTransparency = 1
    costDetailLabel.Text = "100 each"
    costDetailLabel.TextColor3 = eggSystemConfig.ui.colors.text_secondary
    costDetailLabel.TextScaled = true
    costDetailLabel.Font = eggSystemConfig.ui.fonts.prompt
    costDetailLabel.Parent = frame

    local promptLabel = Instance.new("TextLabel")
    promptLabel.Name = "Prompt"
    promptLabel.Size = UDim2.new(1, -10, 0.25, 0)
    promptLabel.Position = UDim2.new(0, 5, 0.74, 0)
    promptLabel.BackgroundTransparency = 1
    promptLabel.Text = getHatchActionPrompt()
    promptLabel.TextColor3 = eggSystemConfig.ui.colors.text_secondary
    promptLabel.TextScaled = true
    promptLabel.Font = eggSystemConfig.ui.fonts.prompt
    promptLabel.Parent = frame

    -- Store CurrentTarget value
    local currentTargetValue = Instance.new("StringValue")
    currentTargetValue.Name = "CurrentTarget"
    currentTargetValue.Value = "None"
    currentTargetValue.Parent = frame

    currentTargetUI = screenGui
    return frame
end

function EggCurrentTargetService:GetEggDisplayData(eggType)
    local eggConfig = self:GetEggConfig(eggType)
    if not eggConfig then
        return nil
    end

    local displayCost = tonumber(
        (petConfig.getEggCost and petConfig.getEggCost(eggType)) or eggConfig.cost
    ) or 0
    local displayName = eggConfig.name or titleCaseId(eggType:gsub("_", " "))
    local currency = eggConfig.currency or "coins"
    local displayCount = getHatchDisplayCount()
    local costEach = math.max(1, math.floor(displayCost + 0.5))
    local totalCost = costEach * displayCount
    local balance = getPlayerCurrencyBalance(currency)
    local affordableCount = balance and math.floor(balance / costEach) or nil

    local detailParts = {
        self:FormatNumber(costEach) .. " each",
    }
    if displayCount > 1 then
        table.insert(detailParts, "max " .. tostring(displayCount))
    end
    if affordableCount then
        table.insert(
            detailParts,
            "afford "
                .. tostring(math.min(displayCount, affordableCount))
                .. "/"
                .. tostring(displayCount)
        )
    end

    return {
        name = displayName,
        currency = currency,
        costEach = costEach,
        displayCount = displayCount,
        totalCost = totalCost,
        affordableCount = affordableCount,
        priceText = getCurrencyIcon(currency)
            .. " "
            .. self:FormatNumber(totalCost)
            .. " "
            .. titleCaseId(currency),
        detailText = table.concat(detailParts, " • "),
    }
end

function EggCurrentTargetService:UpdateEggUI(egg, eggType)
    if not currentTargetUI then
        self:CreateEggUI()
    end

    local frame = currentTargetUI.PreviewFrame
    local currentTargetValue = frame.CurrentTarget

    if egg and eggType then
        -- Only update if target has changed
        if currentTarget ~= eggType then
            if eggSystemConfig.debug.log_proximity_changes then
                Logger:Info(
                    "Now targeting egg",
                    { context = "EggCurrentTargetService", eggType = eggType }
                )
            end
            currentTarget = eggType
            currentTargetValue.Value = eggType

            -- Update name only when target changes; dynamic cost details refresh below.
            local displayData = self:GetEggDisplayData(eggType)
            frame.EggName.Text = displayData and displayData.name or "Basic Egg"
            frame.Visible = true

            -- Show pet preview for new egg
            if eggPetPreviewService then
                local anchor = self:GetEggAnchor(egg)
                if anchor then
                    eggPetPreviewService:ShowPetPreview(eggType, anchor)
                end
            end
        end

        local displayData = self:GetEggDisplayData(eggType)
        if displayData then
            frame.Price.Text = displayData.priceText
            frame.CostDetail.Text = displayData.detailText
            frame:SetAttribute("HatchCurrency", displayData.currency)
            frame:SetAttribute("EstimatedCostEach", displayData.costEach)
            frame:SetAttribute("EstimatedTotalCost", displayData.totalCost)
            frame:SetAttribute("EstimatedDisplayCount", displayData.displayCount)
            frame:SetAttribute("EstimatedAffordableCount", displayData.affordableCount)
            frame:SetAttribute("MaxEntitledHatchCount", getEffectiveMaxHatchCount())
        end
        frame.Prompt.Text = getHatchActionPrompt()

        -- Always update position (player might be moving around the egg)
        local anchor = self:GetEggAnchor(egg)

        if anchor then
            local screenPos = camera:WorldToScreenPoint(anchor.Position)
            frame.Position = UDim2.new(
                0,
                screenPos.X + eggSystemConfig.ui.position_offset.x,
                0,
                screenPos.Y + eggSystemConfig.ui.position_offset.y
            )

            -- Update pet preview position
            if eggPetPreviewService then
                eggPetPreviewService:UpdatePreviewPosition(anchor)
            end
        end
    else
        -- No egg in range - only update if we had a target before
        if currentTarget ~= "None" then
            if eggSystemConfig.debug.log_proximity_changes then
                Logger:Info("No longer targeting egg", { context = "EggCurrentTargetService" })
            end
            currentTarget = "None"
            currentTargetValue.Value = "None"
            frame.Visible = false

            -- Hide pet preview
            if eggPetPreviewService then
                eggPetPreviewService:HidePetPreview()
            end
        end
    end
end

function EggCurrentTargetService:CallSetLastEgg(eggType)
    -- Call server to set last egg (for persistence like working game)
    local success, result = pcall(function()
        local eggRemote = ReplicatedStorage:FindFirstChild("EggOpened")
        if eggRemote and eggRemote:FindFirstChild("setLastEgg") then
            return eggRemote.setLastEgg:InvokeServer(eggType)
        end
    end)

    if success then
        Logger:Debug("Set last egg on server", { eggType = eggType or "nil" })
    else
        Logger:Warn("Failed to set last egg on server", { error = tostring(result) })
    end
end

-- === MAIN UPDATE LOOP (following working game pattern) ===

function EggCurrentTargetService:UpdateTargeting(step)
    timecounter = timecounter + step

    if timecounter >= UPDATE_INTERVAL then
        timecounter = timecounter - UPDATE_INTERVAL

        if not player.Character or not player.Character:FindFirstChild("Humanoid") then
            return
        end

        if player.Character.Humanoid.Health == 0 then
            return
        end

        local inRangeByType = {}
        local rootPart = player.Character:FindFirstChild("HumanoidRootPart")
        if not rootPart then
            return
        end

        for _, egg in ipairs(EggWorldQuery.GetEggs()) do
            if egg.anchor and egg.eggType then
                local distance = (egg.anchor.Position - rootPart.Position).Magnitude
                if distance <= MAX_MAGNITUDE then
                    local current = inRangeByType[egg.eggType]
                    if not current or distance < current.distance then
                        inRangeByType[egg.eggType] = {
                            instance = egg.instance,
                            eggType = egg.eggType,
                            distance = distance,
                        }
                    end
                end
            end
        end

        local inRangeEggs = {}
        for _, entry in pairs(inRangeByType) do
            inRangeEggs[#inRangeEggs + 1] = entry
        end

        counter = counter + 1

        if #inRangeEggs == 1 then
            local target = inRangeEggs[1]
            self:UpdateEggUI(target.instance, target.eggType)

            if counter > SERVER_UPDATE_THRESHOLD then
                counter = 0
                self:CallSetLastEgg(target.eggType)
            end
        elseif #inRangeEggs > 1 then
            local target = self:DetermineClosest(inRangeEggs)
            if target then
                self:UpdateEggUI(target.instance, target.eggType)

                if counter > SERVER_UPDATE_THRESHOLD then
                    counter = 0
                    self:CallSetLastEgg(target.eggType)
                end
            end
        elseif #inRangeEggs == 0 then
            -- No eggs in range
            self:UpdateEggUI(nil, nil)

            if counter > 100 then -- Less frequent server calls when no eggs
                counter = 0
                self:CallSetLastEgg(nil)
            end
        end
    end
end

function EggCurrentTargetService:FindEggByType(eggType)
    return EggWorldQuery.FindEggByType(eggType)
end

-- Helper function to get egg anchor position
function EggCurrentTargetService:GetEggAnchor(egg)
    return EggWorldQuery.GetAnchor(egg)
end

function EggCurrentTargetService:GetCurrentTarget()
    return currentTarget
end

-- === INITIALIZATION ===

function EggCurrentTargetService:Initialize()
    if serviceInitialized then
        return
    end
    serviceInitialized = true

    Logger:Info("EggCurrentTargetService initializing...", { context = "EggCurrentTargetService" })

    -- Load pet preview service
    local success, petPreviewService = pcall(function()
        return require(ReplicatedStorage.Shared.Services.EggPetPreviewService)
    end)

    if success then
        eggPetPreviewService = petPreviewService
        eggPetPreviewService:Initialize()
        Logger:Info(
            "Pet preview service loaded successfully",
            { context = "EggCurrentTargetService" }
        )
    else
        Logger:Warn(
            "Failed to load pet preview service",
            { error = tostring(petPreviewService), context = "EggCurrentTargetService" }
        )
    end

    if heartbeatConnection then
        heartbeatConnection:Disconnect()
        heartbeatConnection = nil
    end

    -- Start the targeting update loop (like working game's VisibleHandler)
    heartbeatConnection = RunService.Heartbeat:Connect(function(step)
        self:UpdateTargeting(step)
    end)

    Logger:Info(
        "EggCurrentTargetService initialized - targeting system active",
        { context = "EggCurrentTargetService" }
    )
end

function EggCurrentTargetService:Destroy()
    serviceInitialized = false

    if heartbeatConnection then
        heartbeatConnection:Disconnect()
        heartbeatConnection = nil
    end

    if currentTargetUI then
        currentTargetUI:Destroy()
        currentTargetUI = nil
    end

    if eggPetPreviewService then
        eggPetPreviewService:Destroy()
        eggPetPreviewService = nil
    end

    Logger:Info("EggCurrentTargetService destroyed", {})
end

-- === HELPER FUNCTIONS FOR PRICE DISPLAY ===

function EggCurrentTargetService:GetEggConfig(eggType)
    if petConfig and petConfig.egg_sources then
        return petConfig.egg_sources[eggType]
    end

    return nil
end

function EggCurrentTargetService:FormatNumber(number)
    if not number then
        return "0"
    end

    if number >= 1000000000 then
        return string.format("%.1fB", number / 1000000000)
    elseif number >= 1000000 then
        return string.format("%.1fM", number / 1000000)
    elseif number >= 1000 then
        return string.format("%.1fK", number / 1000)
    else
        return tostring(number)
    end
end

-- The proximity card's tap handler (the whole card is a button). Registered by
-- EggInteractionService so a tap == pressing E.
function EggCurrentTargetService:SetCardActivatedHandler(fn)
    self._cardActivatedHandler = fn
end

return EggCurrentTargetService
