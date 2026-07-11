local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local PetRuntimeBridge = require(ReplicatedStorage.Shared.Services.PetRuntimeBridge)

local PetEquipmentBridge = {}
PetEquipmentBridge.__index = PetEquipmentBridge

local function parseSlotValue(value)
    if typeof(value) ~= "string" or value == "" then
        return { kind = "none" }
    end
    local parts = string.split(value, "|")
    if #parts >= 2 and parts[1] == "special" then
        return { kind = "special", uid = parts[2] }
    elseif #parts >= 2 and parts[1] == "stack" then
        return { kind = "stack", stackKey = parts[2], eph = parts[3] or parts[2] }
    elseif string.find(value, ":") then
        return { kind = "stack", stackKey = value, eph = value }
    end
    return { kind = "legacy", uid = value }
end

local function clearEquipFolders(petsFolder)
    for _, child in ipairs(petsFolder:GetChildren()) do
        if child:IsA("Folder") and string.sub(child.Name, 1, 6) == "equip_" then
            child:Destroy()
        end
    end
end

local function ensureEquipFolder(petsFolder, stackKey, eph)
    local equipName = "equip_" .. tostring(eph or stackKey)
    local equipFolder = petsFolder:FindFirstChild(equipName)
    if not equipFolder then
        equipFolder = Instance.new("Folder")
        equipFolder.Name = equipName

        local id, variant = stackKey:match("([^:]+):([^:]+)")
        id = id or stackKey
        variant = variant or "basic"

        local itemId = Instance.new("StringValue")
        itemId.Name = "ItemId"
        itemId.Value = id
        itemId.Parent = equipFolder

        local variantValue = Instance.new("StringValue")
        variantValue.Name = "Variant"
        variantValue.Value = variant
        variantValue.Parent = equipFolder

        local petId = Instance.new("NumberValue")
        petId.Name = "PetID"
        petId.Value = math.abs(string.len(equipName) * 9176 + (#id * 131) + (#variant * 97))
        petId.Parent = equipFolder

        equipFolder.Parent = petsFolder
    end

    local equipped = equipFolder:FindFirstChild("Equipped")
    if not equipped then
        equipped = Instance.new("BoolValue")
        equipped.Name = "Equipped"
        equipped.Parent = equipFolder
    end
    equipped.Value = true
end

local function setEquipped(folder, equippedUids)
    if not folder:IsA("Folder") then
        return
    end
    local equipped = folder:FindFirstChild("Equipped")
    if not equipped then
        equipped = Instance.new("BoolValue")
        equipped.Name = "Equipped"
        equipped.Parent = folder
    end
    local uid = folder:GetAttribute("uid") or folder.Name
    equipped.Value = string.sub(folder.Name, 1, 6) == "equip_" or equippedUids[uid] == true
end

function PetEquipmentBridge:Init()
    self._inventoryService = self._modules.InventoryService
    self._logger = self._modules.Logger
    self._connection = self._inventoryService.EquipmentChanged:Connect(function(player)
        self:Reconcile(player)
    end)
    self._playerRemovingConnection = Players.PlayerRemoving:Connect(function(player)
        PetRuntimeBridge.ClearPlayer(player)
    end)
end

function PetEquipmentBridge:Reconcile(player)
    local equippedRoot = player:FindFirstChild("Equipped")
    local equippedPets = equippedRoot and equippedRoot:FindFirstChild("pets")
    local inventoryRoot = player:FindFirstChild("Inventory")
    local inventoryPets = inventoryRoot and inventoryRoot:FindFirstChild("pets")
    if not equippedPets or not inventoryPets then
        self._logger:Warn("Pet equipment projection is incomplete", { player = player.Name })
        return false
    end

    clearEquipFolders(inventoryPets)
    local equippedUids = {}
    for _, slot in ipairs(equippedPets:GetChildren()) do
        if slot:IsA("StringValue") and slot.Value ~= "" then
            local parsed = parseSlotValue(slot.Value)
            if parsed.kind == "stack" then
                ensureEquipFolder(inventoryPets, parsed.stackKey, parsed.eph)
            elseif parsed.kind == "special" or parsed.kind == "legacy" then
                equippedUids[parsed.uid] = true
            end
        end
    end

    for _, child in ipairs(inventoryPets:GetChildren()) do
        if child:IsA("Folder") then
            if child.Name == "Special" then
                for _, specialPet in ipairs(child:GetChildren()) do
                    setEquipped(specialPet, equippedUids)
                end
            elseif child.Name ~= "Info" and child.Name ~= "Stacks" then
                setEquipped(child, equippedUids)
            end
        end
    end

    PetRuntimeBridge.RequestRebuild(player)
    return true
end

function PetEquipmentBridge:Destroy()
    if self._connection then
        self._connection:Disconnect()
        self._connection = nil
    end
    if self._playerRemovingConnection then
        self._playerRemovingConnection:Disconnect()
        self._playerRemovingConnection = nil
    end
end

return PetEquipmentBridge
