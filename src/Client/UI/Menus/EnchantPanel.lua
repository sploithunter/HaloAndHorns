--[[
    EnchantPanel

    Station-focused pet enchant UI. Shows only enchantable unique pets and sends
    server-authoritative reroll requests through EnchantService.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ConfigLoader = require(ReplicatedStorage.Shared.ConfigLoader)
local Locations = require(ReplicatedStorage.Shared.Locations)
local CloseButton = require(script.Parent.Parent.Components.CloseButton)

local LoggerWrapper
local loggerSuccess, loggerResult = pcall(function()
    return require(Locations.Logger)
end)

if loggerSuccess and loggerResult then
    LoggerWrapper = {
        new = function(name)
            return {
                info = function(self, ...)
                    loggerResult:Info("[" .. name .. "] " .. tostring((...)), { context = name })
                end,
                warn = function(self, ...)
                    loggerResult:Warn("[" .. name .. "] " .. tostring((...)), { context = name })
                end,
                error = function(self, ...)
                    loggerResult:Error("[" .. name .. "] " .. tostring((...)), { context = name })
                end,
                debug = function(self, ...)
                    loggerResult:Debug("[" .. name .. "] " .. tostring((...)), { context = name })
                end,
            }
        end,
    }
else
    LoggerWrapper = {
        new = function(name)
            return {
                info = function(self, ...)
                    print("[" .. name .. "] INFO:", ...)
                end,
                warn = function(self, ...)
                    warn("[" .. name .. "] WARN:", ...)
                end,
                error = function(self, ...)
                    warn("[" .. name .. "] ERROR:", ...)
                end,
                debug = function(self, ...)
                    print("[" .. name .. "] DEBUG:", ...)
                end,
            }
        end,
    }
end

local EnchantPanel = {}
EnchantPanel.__index = EnchantPanel

local PANEL_BG = Color3.fromRGB(22, 24, 31)
local SURFACE = Color3.fromRGB(33, 36, 47)
local SURFACE_2 = Color3.fromRGB(43, 47, 62)
local ACCENT = Color3.fromRGB(65, 220, 210)
local WARNING = Color3.fromRGB(220, 88, 68)
local TEXT = Color3.fromRGB(245, 247, 255)
local MUTED = Color3.fromRGB(174, 180, 196)

local function readStringValue(folder, names)
    for _, name in ipairs(names) do
        local value = folder and folder:FindFirstChild(name)
        if value and value:IsA("StringValue") then
            return value.Value
        end
    end
    return nil
end

local function readNumberValue(folder, names)
    for _, name in ipairs(names) do
        local value = folder and folder:FindFirstChild(name)
        if value and (value:IsA("NumberValue") or value:IsA("IntValue")) then
            return tonumber(value.Value)
        end
    end
    return nil
end

local function readBoolValue(folder, names)
    for _, name in ipairs(names) do
        local value = folder and folder:FindFirstChild(name)
        if value and value:IsA("BoolValue") then
            return value.Value
        end
    end
    return nil
end

local function addCorner(parent, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius or 8)
    corner.Parent = parent
    return corner
end

local function addStroke(parent, color, thickness, transparency)
    local stroke = Instance.new("UIStroke")
    stroke.Color = color or ACCENT
    stroke.Thickness = thickness or 1
    stroke.Transparency = transparency or 0
    stroke.Parent = parent
    return stroke
end

local function formatNumber(value)
    local numberValue = tonumber(value)
    if not numberValue then
        return "-"
    end
    if math.abs(numberValue - math.floor(numberValue)) < 0.001 then
        return tostring(math.floor(numberValue))
    end
    return string.format("%.1f", numberValue)
end

function EnchantPanel.new()
    local self = setmetatable({}, EnchantPanel)
    self.logger = LoggerWrapper.new("EnchantPanel")
    self.player = Players.LocalPlayer
    self.signals = require(ReplicatedStorage.Shared.Network.Signals)
    self.petConfig = ConfigLoader:LoadConfig("pets")
    self.enchantConfig = ConfigLoader:LoadConfig("enchants")
    self.isVisible = false
    self.frame = nil
    self.petList = nil
    self.detailPanel = nil
    self.statusLabel = nil
    self.enchantButton = nil
    self.slotButtons = {}
    self.petCards = {}
    self.pets = {}
    self.selectedPetUid = nil
    self.selectedSlot = 1
    self.stationContext = nil
    self.parent = nil
    self.pendingEnchant = nil
    self.revealGui = nil
    return self
end

function EnchantPanel:Show(parent)
    if self.isVisible then
        return
    end

    self:_createUI(parent)
    self.parent = parent
    self.isVisible = true
    self:RefreshFromRealData()
    self.logger:info("Enchant panel shown")
end

function EnchantPanel:Hide()
    if not self.isVisible then
        return
    end

    if self.frame then
        self.frame:Destroy()
        self.frame = nil
    end

    table.clear(self.petCards)
    table.clear(self.slotButtons)
    self.isVisible = false
    self.logger:info("Enchant panel hidden")
end

function EnchantPanel:GetFrame()
    return self.frame
end

function EnchantPanel:IsVisible()
    return self.isVisible
end

function EnchantPanel:SetStationContext(data)
    self.stationContext = type(data) == "table" and data or nil
    if self.isVisible then
        self:_updateStatus()
    end
end

function EnchantPanel:HandleEnchantResult(data)
    if data and data.ok == true then
        self.pendingEnchant = nil
        self:RefreshFromRealData()
        self:_showReveal(data)
        return
    end

    if not self.isVisible and self.parent then
        self:Show(self.parent)
    end
    self.pendingEnchant = nil

    local reason = data and data.reason or "unknown"
    if reason == "requires_station" then
        self:_setStatus("Use the enchanter again to activate rerolls.", true)
    elseif reason == "insufficient_currency" then
        self:_setStatus(
            string.format(
                "Need %d %s.",
                tonumber(data.cost) or self:_getRerollCostAmount(),
                tostring(data.currency or self:_getRerollCostCurrency())
            ),
            true
        )
    elseif reason == "slot_locked" then
        self:_setStatus("That slot is locked.", true)
    else
        self:_setStatus("Enchant failed: " .. tostring(reason), true)
    end
end

function EnchantPanel:RefreshFromRealData()
    self.pets = self:_loadEnchantablePets()
    if #self.pets == 0 then
        self.selectedPetUid = nil
    elseif not self:_getSelectedPet() then
        self.selectedPetUid = self.pets[1].uid
        self.selectedSlot = 1
    end

    if self.isVisible then
        self:_renderPetList()
        self:_renderDetails()
        self:_updateStatus()
    end
end

function EnchantPanel:_createUI(parent)
    self.frame = Instance.new("Frame")
    self.frame.Name = "EnchantPanel"
    self.frame.Size = UDim2.new(0.72, 0, 0.76, 0)
    self.frame.Position = UDim2.new(0.5, 0, 0.5, 0)
    self.frame.AnchorPoint = Vector2.new(0.5, 0.5)
    self.frame.BackgroundColor3 = PANEL_BG
    self.frame.BorderSizePixel = 0
    self.frame.ZIndex = 100
    self.frame.Parent = parent
    addCorner(self.frame, 10)
    addStroke(self.frame, ACCENT, 2, 0.12)

    local header = Instance.new("Frame")
    header.Name = "Header"
    header.Size = UDim2.new(1, 0, 0, 68)
    header.BackgroundColor3 = Color3.fromRGB(25, 29, 38)
    header.BorderSizePixel = 0
    header.ZIndex = 101
    header.Parent = self.frame
    addCorner(header, 10)

    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(0.55, 0, 1, 0)
    title.Position = UDim2.new(0, 24, 0, 0)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.Text = "Enchanter"
    title.TextColor3 = TEXT
    title.TextSize = 28
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.ZIndex = 102
    title.Parent = header

    local cost = Instance.new("TextLabel")
    cost.Name = "Cost"
    cost.Size = UDim2.new(0.32, 0, 1, 0)
    cost.Position = UDim2.new(0.58, 0, 0, 0)
    cost.BackgroundTransparency = 1
    cost.Font = Enum.Font.GothamMedium
    cost.Text = self:_formatCostText()
    cost.TextColor3 = MUTED
    cost.TextSize = 18
    cost.TextXAlignment = Enum.TextXAlignment.Right
    cost.ZIndex = 102
    cost.Parent = header

    -- THE standard close X (shared component; replaces the hand-styled text "X")
    CloseButton.attach(header, {
        zindex = 102,
        onClick = function()
            self:Hide()
        end,
    })

    self.petList = Instance.new("ScrollingFrame")
    self.petList.Name = "PetList"
    self.petList.Size = UDim2.new(0.58, -28, 1, -104)
    self.petList.Position = UDim2.new(0, 24, 0, 88)
    self.petList.BackgroundColor3 = Color3.fromRGB(18, 20, 27)
    self.petList.BorderSizePixel = 0
    self.petList.ScrollBarThickness = 6
    self.petList.CanvasSize = UDim2.new(0, 0, 0, 0)
    self.petList.ZIndex = 101
    self.petList.Parent = self.frame
    addCorner(self.petList, 8)

    local grid = Instance.new("UIGridLayout")
    grid.Name = "PetGrid"
    grid.CellSize = UDim2.new(0, 104, 0, 124)
    grid.CellPadding = UDim2.new(0, 10, 0, 10)
    grid.SortOrder = Enum.SortOrder.LayoutOrder
    grid.Parent = self.petList
    grid:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        self.petList.CanvasSize = UDim2.new(0, 0, 0, grid.AbsoluteContentSize.Y + 16)
    end)

    local padding = Instance.new("UIPadding")
    padding.PaddingTop = UDim.new(0, 12)
    padding.PaddingLeft = UDim.new(0, 12)
    padding.PaddingRight = UDim.new(0, 12)
    padding.PaddingBottom = UDim.new(0, 12)
    padding.Parent = self.petList

    self.detailPanel = Instance.new("Frame")
    self.detailPanel.Name = "Details"
    self.detailPanel.Size = UDim2.new(0.42, -20, 1, -104)
    self.detailPanel.Position = UDim2.new(0.58, 0, 0, 88)
    self.detailPanel.BackgroundColor3 = SURFACE
    self.detailPanel.BorderSizePixel = 0
    self.detailPanel.ZIndex = 101
    self.detailPanel.Parent = self.frame
    addCorner(self.detailPanel, 8)
    addStroke(self.detailPanel, Color3.fromRGB(84, 92, 112), 1, 0.55)
end

function EnchantPanel:_loadEnchantablePets()
    local inventory = self.player:FindFirstChild("Inventory")
    local petsFolder = inventory and inventory:FindFirstChild("pets")
    local specialFolder = petsFolder and petsFolder:FindFirstChild("Special")
    if not specialFolder then
        return {}
    end

    local pets = {}
    for _, folder in ipairs(specialFolder:GetChildren()) do
        if folder:IsA("Folder") then
            local pet = self:_readPet(folder)
            if pet and pet.enchantable and pet.unlockedEnchantSlots > 0 then
                table.insert(pets, pet)
            end
        end
    end

    table.sort(pets, function(a, b)
        if (a.rarityOrder or 0) == (b.rarityOrder or 0) then
            return a.name < b.name
        end
        return (a.rarityOrder or 0) > (b.rarityOrder or 0)
    end)
    return pets
end

function EnchantPanel:_readPet(folder)
    local itemId = readStringValue(folder, { "ItemId", "id" })
    if not itemId then
        return nil
    end

    local variant = readStringValue(folder, { "Variant", "variant" }) or "basic"
    local isHuge = readBoolValue(folder, { "huge", "Huge" }) == true
    local configData = self.petConfig.getPet and self.petConfig.getPet(itemId, variant) or nil
    local rarityId = isHuge and "huge"
        or (configData and configData.rarity_id)
        or readStringValue(folder, { "rarity_id", "rarity_override" })
        or "common"
    local maxEnchantments = self:_getMaxEnchantmentsForRarity(rarityId)
    local storedMax = readNumberValue(folder, { "max_enchantments", "MaxEnchantments" })
    if maxEnchantments <= 0 then
        maxEnchantments = storedMax or 0
    end
    local unlockedSlots = readNumberValue(
        folder,
        { "unlocked_enchant_slots", "UnlockedEnchantSlots" }
    ) or math.min(1, maxEnchantments)
    unlockedSlots = math.clamp(math.floor(unlockedSlots), 0, maxEnchantments)
    if maxEnchantments <= 0 then
        return nil
    end

    local serial = readNumberValue(folder, { "serial", "Serial" })
    local displayName = (configData and (configData.family_display_name or configData.name))
        or itemId:gsub("^%l", string.upper)
    if isHuge then
        displayName = "Huge " .. displayName
    end
    if serial then
        displayName ..= " #" .. tostring(serial)
    end

    return {
        uid = folder.Name,
        itemId = itemId,
        petType = itemId,
        variant = variant,
        name = displayName,
        icon = self:_getPetIcon(itemId),
        rarityId = rarityId,
        rarity = self:_getRarityName(rarityId),
        rarityColor = self:_getRarityColor(rarityId),
        rarityOrder = self:_getRarityOrder(rarityId),
        level = readNumberValue(folder, { "level", "Level" }) or 1,
        power = readNumberValue(folder, { "EffectivePower", "Power", "power" })
            or (configData and configData.power)
            or 0,
        enchantable = true,
        maxEnchantments = maxEnchantments,
        unlockedEnchantSlots = unlockedSlots,
        enchantments = self:_readEnchantments(folder),
        huge = isHuge,
        serial = serial,
        folder = folder,
    }
end

function EnchantPanel:_readEnchantments(folder)
    local results = {}
    local enchantFolder = folder:FindFirstChild("enchantments")
        or folder:FindFirstChild("Enchantments")
    if not enchantFolder or not enchantFolder:IsA("Folder") then
        return results
    end

    local children = enchantFolder:GetChildren()
    table.sort(children, function(a, b)
        return tostring(a.Name) < tostring(b.Name)
    end)
    for _, child in ipairs(children) do
        if child:IsA("Folder") then
            local id = readStringValue(child, { "id", "Id" }) or child.Name
            local config = self.enchantConfig.effects and self.enchantConfig.effects[id]
            table.insert(results, {
                id = id,
                displayName = readStringValue(child, { "display_name", "DisplayName" })
                    or (config and config.display_name)
                    or id,
                strength = readNumberValue(child, { "strength", "Strength", "value", "Value" })
                    or 0,
                description = config and config.description or nil,
            })
        end
    end
    return results
end

function EnchantPanel:_getMaxEnchantmentsForRarity(rarityId)
    local enchanting = self.petConfig.enchanting or {}
    local byRarity = enchanting.max_enchantments_by_rarity or {}
    return tonumber(byRarity[rarityId] or enchanting.default_max_enchantments) or 0
end

function EnchantPanel:_getRarityName(rarityId)
    local rarity = self.petConfig.rarities and self.petConfig.rarities[rarityId]
    return (rarity and rarity.name) or tostring(rarityId):gsub("^%l", string.upper)
end

function EnchantPanel:_getRarityColor(rarityId)
    local rarity = self.petConfig.rarities and self.petConfig.rarities[rarityId]
    if rarity and typeof(rarity.color) == "Color3" then
        return rarity.color
    end
    return ACCENT
end

function EnchantPanel:_getRarityOrder(rarityId)
    local order = {
        common = 1,
        uncommon = 2,
        rare = 3,
        epic = 4,
        legendary = 5,
        mythic = 6,
        secret = 7,
        exclusive = 8,
        huge = 9,
        colossal = 10,
    }
    return order[rarityId] or 0
end

function EnchantPanel:_getPetIcon(petType)
    local icons = {
        bear = "B",
        bunny = "B",
        doggy = "D",
        dragon = "D",
        colorado = "C",
    }
    return icons[petType] or "P"
end

function EnchantPanel:_getSelectedPet()
    for _, pet in ipairs(self.pets) do
        if pet.uid == self.selectedPetUid then
            return pet
        end
    end
    return nil
end

function EnchantPanel:_renderPetList()
    if not self.petList then
        return
    end

    for _, child in ipairs(self.petList:GetChildren()) do
        if child:IsA("GuiObject") then
            child:Destroy()
        end
    end
    table.clear(self.petCards)

    if #self.pets == 0 then
        local empty = Instance.new("TextLabel")
        empty.Name = "Empty"
        empty.Size = UDim2.new(1, -24, 0, 72)
        empty.BackgroundTransparency = 1
        empty.Font = Enum.Font.GothamMedium
        empty.Text = "No enchantable pets"
        empty.TextColor3 = MUTED
        empty.TextSize = 18
        empty.ZIndex = 102
        empty.Parent = self.petList
        return
    end

    for index, pet in ipairs(self.pets) do
        self:_createPetCard(pet, index)
    end
end

function EnchantPanel:_createPetCard(pet, layoutOrder)
    local button = Instance.new("TextButton")
    button.Name = "Pet_" .. pet.uid
    button.Size = UDim2.new(0, 104, 0, 124)
    button.BackgroundColor3 = self.selectedPetUid == pet.uid and Color3.fromRGB(42, 58, 68)
        or SURFACE_2
    button.BorderSizePixel = 0
    button.Text = ""
    button.LayoutOrder = layoutOrder
    button.ZIndex = 102
    button.Parent = self.petList
    addCorner(button, 8)
    local stroke = addStroke(
        button,
        self.selectedPetUid == pet.uid and ACCENT or pet.rarityColor,
        self.selectedPetUid == pet.uid and 3 or 2,
        self.selectedPetUid == pet.uid and 0 or 0.25
    )

    local iconFrame = Instance.new("Frame")
    iconFrame.Name = "Icon"
    iconFrame.Size = UDim2.new(0, 72, 0, 72)
    iconFrame.Position = UDim2.new(0.5, -36, 0, 8)
    iconFrame.BackgroundColor3 = Color3.fromRGB(18, 20, 28)
    iconFrame.BorderSizePixel = 0
    iconFrame.ClipsDescendants = true
    iconFrame.ZIndex = 103
    iconFrame.Parent = button
    addCorner(iconFrame, 8)
    self:_addPetThumbnail(iconFrame, pet)

    local name = Instance.new("TextLabel")
    name.Name = "Name"
    name.Size = UDim2.new(1, -10, 0, 28)
    name.Position = UDim2.new(0, 5, 0, 82)
    name.BackgroundTransparency = 1
    name.Font = Enum.Font.GothamBold
    name.Text = pet.name
    name.TextColor3 = TEXT
    name.TextScaled = true
    name.TextWrapped = true
    name.ZIndex = 103
    name.Parent = button

    local power = Instance.new("TextLabel")
    power.Name = "Power"
    power.Size = UDim2.new(1, -10, 0, 16)
    power.Position = UDim2.new(0, 5, 1, -19)
    power.BackgroundTransparency = 1
    power.Font = Enum.Font.GothamBold
    power.Text = formatNumber(pet.power)
    power.TextColor3 = Color3.fromRGB(255, 220, 82)
    power.TextSize = 13
    power.ZIndex = 103
    power.Parent = button

    button.Activated:Connect(function()
        self.selectedPetUid = pet.uid
        self.selectedSlot = math.clamp(self.selectedSlot, 1, math.max(1, pet.unlockedEnchantSlots))
        self:_renderPetList()
        self:_renderDetails()
        self:_updateStatus()
    end)

    self.petCards[pet.uid] = {
        button = button,
        stroke = stroke,
    }
end

function EnchantPanel:_addPetThumbnail(parent, pet)
    local viewport = self:_getPetImageFromAssets(pet.petType, pet.variant)
    if viewport then
        viewport.Size = UDim2.new(1, 0, 1, 0)
        viewport.BackgroundTransparency = 1
        viewport.ZIndex = 104
        viewport.Parent = parent
        return
    end

    local fallback = Instance.new("TextLabel")
    fallback.Name = "Fallback"
    fallback.Size = UDim2.new(1, 0, 1, 0)
    fallback.BackgroundTransparency = 1
    fallback.Font = Enum.Font.GothamBold
    fallback.Text = pet.icon
    fallback.TextColor3 = pet.rarityColor or TEXT
    fallback.TextSize = 34
    fallback.ZIndex = 104
    fallback.Parent = parent
end

function EnchantPanel:_getPetImageFromAssets(petType, variant)
    local assets = ReplicatedStorage:FindFirstChild("Assets")
    local images = assets and assets:FindFirstChild("Images")
    local pets = images and images:FindFirstChild("Pets")
    local petFolder = pets and pets:FindFirstChild(petType)
    local viewport = petFolder and petFolder:FindFirstChild(variant)
    if viewport and viewport:IsA("ViewportFrame") then
        return viewport:Clone()
    end
    return nil
end

function EnchantPanel:_renderDetails()
    if not self.detailPanel then
        return
    end
    for _, child in ipairs(self.detailPanel:GetChildren()) do
        if child:IsA("GuiObject") then
            child:Destroy()
        end
    end
    table.clear(self.slotButtons)

    local pet = self:_getSelectedPet()
    if not pet then
        local empty = Instance.new("TextLabel")
        empty.Size = UDim2.new(1, -32, 1, -32)
        empty.Position = UDim2.new(0, 16, 0, 16)
        empty.BackgroundTransparency = 1
        empty.Font = Enum.Font.GothamMedium
        empty.Text = "No pet selected"
        empty.TextColor3 = MUTED
        empty.TextSize = 18
        empty.ZIndex = 102
        empty.Parent = self.detailPanel
        return
    end

    local title = Instance.new("TextLabel")
    title.Name = "PetName"
    title.Size = UDim2.new(1, -32, 0, 34)
    title.Position = UDim2.new(0, 16, 0, 16)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.Text = pet.name
    title.TextColor3 = TEXT
    title.TextSize = 22
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.ZIndex = 102
    title.Parent = self.detailPanel

    local meta = Instance.new("TextLabel")
    meta.Name = "Meta"
    meta.Size = UDim2.new(1, -32, 0, 54)
    meta.Position = UDim2.new(0, 16, 0, 52)
    meta.BackgroundTransparency = 1
    meta.Font = Enum.Font.Gotham
    meta.Text = string.format(
        "%s  |  %s  |  Level %s\nPower %s",
        pet.rarity,
        pet.variant,
        formatNumber(pet.level),
        formatNumber(pet.power)
    )
    meta.TextColor3 = MUTED
    meta.TextSize = 16
    meta.TextXAlignment = Enum.TextXAlignment.Left
    meta.TextYAlignment = Enum.TextYAlignment.Top
    meta.ZIndex = 102
    meta.Parent = self.detailPanel

    local slotLabel = Instance.new("TextLabel")
    slotLabel.Name = "SlotLabel"
    slotLabel.Size = UDim2.new(1, -32, 0, 24)
    slotLabel.Position = UDim2.new(0, 16, 0, 118)
    slotLabel.BackgroundTransparency = 1
    slotLabel.Font = Enum.Font.GothamBold
    slotLabel.Text = "Enchant Slots"
    slotLabel.TextColor3 = TEXT
    slotLabel.TextSize = 17
    slotLabel.TextXAlignment = Enum.TextXAlignment.Left
    slotLabel.ZIndex = 102
    slotLabel.Parent = self.detailPanel

    local slotContainer = Instance.new("Frame")
    slotContainer.Name = "Slots"
    slotContainer.Size = UDim2.new(1, -32, 0, 148)
    slotContainer.Position = UDim2.new(0, 16, 0, 150)
    slotContainer.BackgroundTransparency = 1
    slotContainer.ZIndex = 102
    slotContainer.Parent = self.detailPanel

    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Vertical
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 8)
    layout.Parent = slotContainer

    for slot = 1, pet.maxEnchantments do
        self:_createSlotButton(slotContainer, pet, slot)
    end

    local description = Instance.new("TextLabel")
    description.Name = "EffectDescription"
    description.Size = UDim2.new(1, -32, 0, 72)
    description.Position = UDim2.new(0, 16, 0, 306)
    description.BackgroundTransparency = 1
    description.Font = Enum.Font.Gotham
    description.Text = self:_formatSelectedEnchantDescription(pet)
    description.TextColor3 = MUTED
    description.TextSize = 15
    description.TextWrapped = true
    description.TextXAlignment = Enum.TextXAlignment.Left
    description.TextYAlignment = Enum.TextYAlignment.Top
    description.ZIndex = 102
    description.Parent = self.detailPanel

    self.statusLabel = Instance.new("TextLabel")
    self.statusLabel.Name = "Status"
    self.statusLabel.Size = UDim2.new(1, -32, 0, 44)
    self.statusLabel.Position = UDim2.new(0, 16, 1, -112)
    self.statusLabel.BackgroundTransparency = 1
    self.statusLabel.Font = Enum.Font.GothamMedium
    self.statusLabel.TextColor3 = MUTED
    self.statusLabel.TextSize = 15
    self.statusLabel.TextWrapped = true
    self.statusLabel.TextXAlignment = Enum.TextXAlignment.Left
    self.statusLabel.ZIndex = 102
    self.statusLabel.Parent = self.detailPanel

    self.enchantButton = Instance.new("TextButton")
    self.enchantButton.Name = "EnchantButton"
    self.enchantButton.Size = UDim2.new(1, -32, 0, 50)
    self.enchantButton.Position = UDim2.new(0, 16, 1, -58)
    self.enchantButton.BackgroundColor3 = ACCENT
    self.enchantButton.BorderSizePixel = 0
    self.enchantButton.Font = Enum.Font.GothamBold
    self.enchantButton.Text = "Enchant"
    self.enchantButton.TextColor3 = Color3.fromRGB(10, 18, 22)
    self.enchantButton.TextSize = 20
    self.enchantButton.ZIndex = 102
    self.enchantButton.Parent = self.detailPanel
    addCorner(self.enchantButton, 8)
    self.enchantButton.Activated:Connect(function()
        self:_requestEnchant()
    end)

    self:_updateStatus()
end

function EnchantPanel:_createSlotButton(parent, pet, slot)
    local enchant = pet.enchantments[slot]
    local locked = slot > pet.unlockedEnchantSlots
    local selected = slot == self.selectedSlot
    local button = Instance.new("TextButton")
    button.Name = "Slot" .. tostring(slot)
    button.Size = UDim2.new(1, 0, 0, 40)
    button.BackgroundColor3 = selected and Color3.fromRGB(45, 78, 82) or Color3.fromRGB(25, 28, 38)
    button.BorderSizePixel = 0
    button.Font = Enum.Font.GothamMedium
    button.TextColor3 = locked and Color3.fromRGB(120, 124, 136) or TEXT
    button.TextSize = 15
    button.TextXAlignment = Enum.TextXAlignment.Left
    button.Text =
        string.format("  Slot %d  %s", slot, locked and "Locked" or self:_formatEnchant(enchant))
    button.AutoButtonColor = not locked
    button.ZIndex = 103
    button.LayoutOrder = slot
    button.Parent = parent
    addCorner(button, 8)
    addStroke(button, selected and ACCENT or Color3.fromRGB(70, 76, 92), selected and 2 or 1, 0.3)

    if not locked then
        button.Activated:Connect(function()
            self.selectedSlot = slot
            self:_renderDetails()
        end)
    end
    self.slotButtons[slot] = button
end

function EnchantPanel:_formatEnchant(enchant)
    if type(enchant) ~= "table" then
        return "Empty"
    end
    local suffix = ""
    if tonumber(enchant.strength) and tonumber(enchant.strength) > 0 then
        suffix = " +" .. formatNumber(enchant.strength)
    end
    return tostring(enchant.displayName or enchant.id or "Enchant") .. suffix
end

function EnchantPanel:_formatSelectedEnchantDescription(pet)
    if not pet then
        return ""
    end
    local enchant = pet.enchantments[self.selectedSlot]
    if type(enchant) ~= "table" then
        if self.selectedSlot > pet.unlockedEnchantSlots then
            return "Level this pet to unlock this slot."
        end
        return "This slot is ready for a new enchant."
    end

    local config = self.enchantConfig.effects and self.enchantConfig.effects[enchant.id]
    local description = enchant.description or (config and config.description)
    local modifier = config and config.modifier
    local strength = tonumber(enchant.strength) or 0
    if type(modifier) == "table" and strength > 0 then
        local amount = strength * (tonumber(modifier.amount_per_strength) or 0)
        local percent = math.floor(amount * 1000 + 0.5) / 10
        local suffix = string.format(" (+%.1f%%)", percent)
        return tostring(description or "Configured enchant effect.") .. suffix
    end
    return tostring(description or "Configured enchant effect.")
end

function EnchantPanel:_requestEnchant()
    local pet = self:_getSelectedPet()
    if not pet then
        self:_setStatus("Select a pet.", true)
        return
    end
    if self.selectedSlot > pet.unlockedEnchantSlots then
        self:_setStatus("That slot is locked.", true)
        return
    end

    self:_setStatus("Enchanting...", false)
    self.pendingEnchant = {
        petUid = pet.uid,
        slot = self.selectedSlot,
    }
    self.signals.EnchantPetRequest:FireServer({
        petUid = pet.uid,
        slot = self.selectedSlot,
        source = "enchanter_panel",
    })
    if _G.MenuManager and _G.MenuManager:GetCurrentPanel() == "Enchant" then
        _G.MenuManager:CloseCurrentPanel("fade")
    else
        self:Hide()
    end
end

function EnchantPanel:_destroyReveal()
    if self.revealGui then
        self.revealGui:Destroy()
        self.revealGui = nil
    end
end

function EnchantPanel:_showReveal(data)
    self:_destroyReveal()

    local enchant = data and data.enchant or {}
    local displayName = enchant.display_name or enchant.displayName or enchant.id or "Enchant"
    local strength = tonumber(enchant.strength or enchant.value)
    local strengthText = strength and (" +" .. formatNumber(strength)) or ""
    local slotText = data and data.slot and ("Slot " .. tostring(data.slot)) or "Enchant"

    local playerGui = self.player:FindFirstChildOfClass("PlayerGui")
    if not playerGui then
        return
    end

    local gui = Instance.new("ScreenGui")
    gui.Name = "EnchantRevealGui"
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = playerGui
    self.revealGui = gui

    local dim = Instance.new("Frame")
    dim.Name = "Dim"
    dim.Size = UDim2.fromScale(1, 1)
    dim.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    dim.BackgroundTransparency = 0.42
    dim.BorderSizePixel = 0
    dim.ZIndex = 180
    dim.Parent = gui

    local card = Instance.new("Frame")
    card.Name = "RevealCard"
    card.Size = UDim2.new(0, 390, 0, 230)
    card.Position = UDim2.fromScale(0.5, 0.5)
    card.AnchorPoint = Vector2.new(0.5, 0.5)
    card.BackgroundColor3 = PANEL_BG
    card.BorderSizePixel = 0
    card.ZIndex = 181
    card.Parent = gui
    addCorner(card, 8)
    addStroke(card, ACCENT, 2, 0)

    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, -40, 0, 42)
    title.Position = UDim2.new(0, 20, 0, 20)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.Text = "Enchant Complete"
    title.TextColor3 = TEXT
    title.TextSize = 26
    title.ZIndex = 182
    title.Parent = card

    local slot = Instance.new("TextLabel")
    slot.Name = "Slot"
    slot.Size = UDim2.new(1, -40, 0, 28)
    slot.Position = UDim2.new(0, 20, 0, 68)
    slot.BackgroundTransparency = 1
    slot.Font = Enum.Font.GothamMedium
    slot.Text = slotText
    slot.TextColor3 = MUTED
    slot.TextSize = 17
    slot.ZIndex = 182
    slot.Parent = card

    local result = Instance.new("TextLabel")
    result.Name = "Result"
    result.Size = UDim2.new(1, -40, 0, 58)
    result.Position = UDim2.new(0, 20, 0, 104)
    result.BackgroundTransparency = 1
    result.Font = Enum.Font.GothamBold
    result.Text = tostring(displayName) .. strengthText
    result.TextColor3 = ACCENT
    result.TextScaled = true
    result.TextWrapped = true
    result.ZIndex = 182
    result.Parent = card

    local effectConfig = self.enchantConfig.effects and self.enchantConfig.effects[enchant.id]
    local description = Instance.new("TextLabel")
    description.Name = "Description"
    description.Size = UDim2.new(1, -40, 0, 42)
    description.Position = UDim2.new(0, 20, 0, 162)
    description.BackgroundTransparency = 1
    description.Font = Enum.Font.Gotham
    description.Text = tostring(effectConfig and effectConfig.description or "")
    description.TextColor3 = MUTED
    description.TextSize = 15
    description.TextWrapped = true
    description.ZIndex = 182
    description.Parent = card

    local okButton = Instance.new("TextButton")
    okButton.Name = "OkButton"
    okButton.Size = UDim2.new(0, 150, 0, 42)
    okButton.Position = UDim2.new(0.5, -75, 1, -58)
    okButton.BackgroundColor3 = ACCENT
    okButton.BorderSizePixel = 0
    okButton.Font = Enum.Font.GothamBold
    okButton.Text = "OK"
    okButton.TextColor3 = Color3.fromRGB(10, 18, 22)
    okButton.TextSize = 18
    okButton.ZIndex = 182
    okButton.Parent = card
    addCorner(okButton, 8)
    okButton.Activated:Connect(function()
        self:_destroyReveal()
    end)

    task.delay(4.5, function()
        if self.revealGui == gui then
            self:_destroyReveal()
        end
    end)
end

function EnchantPanel:_formatCostText()
    local amount = self:_getRerollCostAmount()
    local currency = self:_getRerollCostCurrency()
    if amount <= 0 then
        return "Free"
    end
    return string.format("%d %s", amount, currency)
end

function EnchantPanel:_getRerollCostAmount()
    local cost = self.enchantConfig.reroll and self.enchantConfig.reroll.cost or {}
    return math.max(0, math.floor(tonumber(cost.amount) or 0))
end

function EnchantPanel:_getRerollCostCurrency()
    local cost = self.enchantConfig.reroll and self.enchantConfig.reroll.cost or {}
    return tostring(cost.currency or "currency")
end

function EnchantPanel:_updateStatus()
    if not self.statusLabel then
        return
    end

    local selected = self:_getSelectedPet()
    if not selected then
        self:_setStatus("No enchantable pets available.", true)
        return
    end

    self:_setStatus("Cost: " .. self:_formatCostText(), false)
end

function EnchantPanel:_setStatus(message, isWarning)
    if not self.statusLabel then
        return
    end

    self.statusLabel.Text = tostring(message or "")
    self.statusLabel.TextColor3 = isWarning and WARNING or MUTED
end

return EnchantPanel
