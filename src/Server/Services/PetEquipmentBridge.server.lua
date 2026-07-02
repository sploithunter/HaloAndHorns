--[[
    PetEquipmentBridge Server Script
    
    This server script bridges between our Equipped/pets folder system and the boolean-based
    system from the imported pet mechanics. It converts folder changes to the loadEquipped()
    calls expected by the imported system.
    
    Our System: Player/Equipped/pets/slot_X (StringValue with pet UID)
    Their System: Pet.Equipped.Value = true/false (BoolValue on each pet)
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Silence verbose prints unless enabled
local __RAW_PRINT = print
local __PRINT_ENABLED = false -- default silent
local function print(...)
    if __PRINT_ENABLED then
        __RAW_PRINT(...)
    end
end
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- This will be populated when ImportedPetHandler initializes
local loadEquippedFunctions = {}

-- Cache for tracking equipped pets per player
local equippedPets = {}
local playerConnections = {}
local loadDebounce = {}

-- Function to set the loadEquipped function from ImportedPetHandler
_G.SetPetLoadEquippedFunction = function(func)
    table.insert(loadEquippedFunctions, func)
    print("✅ PetEquipmentBridge: LoadEquipped function registered")
end

local function getEquippedCount(player)
    local count = 0
    for _ in pairs(equippedPets[player] or {}) do
        count = count + 1
    end
    return count
end

local function updatePetBooleanStates(player)
    -- This function updates the boolean Equipped values on pets to match our folder system
    -- It acts as the bridge between the two systems

    local equippedFolder = player:FindFirstChild("Equipped")
    if not equippedFolder then
        return
    end

    local petsFolder = equippedFolder:FindFirstChild("pets")
    if not petsFolder then
        return
    end

    -- Build a set of currently equipped pet UIDs
    local equippedUids = {}
    for _, slotValue in ipairs(petsFolder:GetChildren()) do
        if slotValue:IsA("StringValue") and slotValue.Value ~= "" then
            equippedUids[slotValue.Value] = true
        end
    end

    -- Now update the boolean values on the actual pet data in Inventory/pets
    local inventoryFolder = player:FindFirstChild("Inventory")
    if not inventoryFolder then
        warn("PetEquipmentBridge: No Inventory folder found for", player.Name)
        return
    end

    local petsDataFolder = inventoryFolder:FindFirstChild("pets")
    if petsDataFolder then
        local function ensureAndSet(folder)
            if not folder or not folder:IsA("Folder") then
                return
            end
            local equippedValue = folder:FindFirstChild("Equipped")
            if not equippedValue then
                equippedValue = Instance.new("BoolValue")
                equippedValue.Name = "Equipped"
                equippedValue.Parent = folder
            end
            local petUid = folder:GetAttribute("uid") or folder.Name
            if string.sub(folder.Name, 1, 6) == "equip_" then
                equippedValue.Value = true
            else
                equippedValue.Value = equippedUids[petUid] == true
            end
        end

        for _, child in ipairs(petsDataFolder:GetChildren()) do
            if child:IsA("Folder") then
                if child.Name == "Special" then
                    for _, specialPet in ipairs(child:GetChildren()) do
                        if specialPet:IsA("Folder") then
                            ensureAndSet(specialPet)
                        end
                    end
                elseif child.Name == "Info" or child.Name == "Stacks" then
                    -- Containers, not pets — skip. (Equipped commons spawn via equip_* folders,
                    -- handled by the else branch; the Stacks display folders are not spawn
                    -- sources and must not get a stray Equipped flag.)
                else
                    ensureAndSet(child) -- equip_* instances + any legacy direct-uid pet folder
                end
            end
        end
    else
        warn("PetEquipmentBridge: No pets folder found in Inventory for", player.Name)
    end
end

-- Helpers for stack-backed equips
local function parseSlotValue(value)
    -- Patterns:
    -- special|<uid>
    -- stack|<id:variant>|<ephemeralUid>
    if typeof(value) ~= "string" or value == "" then
        return { kind = "none" }
    end
    local parts = string.split(value, "|")
    if #parts >= 2 and parts[1] == "special" then
        return { kind = "special", uid = parts[2] }
    elseif #parts >= 3 and parts[1] == "stack" then
        return { kind = "stack", stackKey = parts[2], eph = parts[3] }
    elseif string.find(value, ":") then
        -- Legacy mixed: slot directly stores id:variant
        return { kind = "stack", stackKey = value, eph = value }
    else
        return { kind = "legacy", raw = value }
    end
end

local function ensureEquipFolderForStack(player, stackKey, eph)
    local inventoryFolder = player:FindFirstChild("Inventory")
    if not inventoryFolder then
        return nil
    end
    local petsFolder = inventoryFolder:FindFirstChild("pets")
    if not petsFolder then
        return nil
    end
    local equipName = "equip_" .. tostring(eph or stackKey)
    local equipFolder = petsFolder:FindFirstChild(equipName)
    if not equipFolder then
        equipFolder = Instance.new("Folder")
        equipFolder.Name = equipName
        equipFolder.Parent = petsFolder
        -- Derive itemId and variant from stackKey
        local id, variant = stackKey:match("([^:]+):([^:]+)")
        id = id or stackKey
        variant = variant or "basic"
        print("🧩 Bridge: creating equip folder for stack", id, variant, "->", equipName)
        local itemId = Instance.new("StringValue")
        itemId.Name = "ItemId"
        itemId.Value = id
        itemId.Parent = equipFolder
        local variantVal = Instance.new("StringValue")
        variantVal.Name = "Variant"
        variantVal.Value = variant
        variantVal.Parent = equipFolder
        -- Add PetID for compatibility
        local petId = Instance.new("NumberValue")
        petId.Name = "PetID"
        petId.Value = math.abs(string.len(equipName) * 9176 + (#id * 131) + (#variant * 97))
        petId.Parent = equipFolder
    end
    -- Ensure Equipped bool exists and true
    local eq = equipFolder:FindFirstChild("Equipped")
    if not eq then
        eq = Instance.new("BoolValue")
        eq.Name = "Equipped"
        eq.Parent = equipFolder
    end
    eq.Value = true
    return equipFolder
end

local function clearEquipFolders(player)
    local inventoryFolder = player:FindFirstChild("Inventory")
    if not inventoryFolder then
        return
    end
    local petsFolder = inventoryFolder:FindFirstChild("pets")
    if not petsFolder then
        return
    end
    for _, child in ipairs(petsFolder:GetChildren()) do
        if child:IsA("Folder") and string.sub(child.Name, 1, 6) == "equip_" then
            child:Destroy()
        end
    end
end

local function triggerLoadEquipped(player)
    -- Debounce rapid changes
    if loadDebounce[player] then
        return
    end

    loadDebounce[player] = true

    task.spawn(function()
        task.wait(0.1) -- Small debounce
        loadDebounce[player] = nil

        print(
            "🔄 PetEquipmentBridge: Triggering loadEquipped for",
            player.Name,
            "with",
            getEquippedCount(player),
            "pets"
        )
        -- Snapshot what's in Inventory/pets
        local inv = player:FindFirstChild("Inventory")
        if inv and inv:FindFirstChild("pets") then
            local pf = inv.pets
            local names = {}
            for _, c in ipairs(pf:GetChildren()) do
                if c:IsA("Folder") then
                    local eq = c:FindFirstChild("Equipped")
                    table.insert(
                        names,
                        string.format("%s(eq=%s)", c.Name, eq and tostring(eq.Value) or "nil")
                    )
                    if c.Name == "Special" then
                        for _, sp in ipairs(c:GetChildren()) do
                            if sp:IsA("Folder") then
                                local eqs = sp:FindFirstChild("Equipped")
                                table.insert(
                                    names,
                                    string.format(
                                        "  └─%s(eq=%s)",
                                        sp.Name,
                                        eqs and tostring(eqs.Value) or "nil"
                                    )
                                )
                            end
                        end
                    end
                end
            end
            print("📦 Bridge: Inventory/pets contains:", table.concat(names, ", "))
        else
            print("⚠️ Bridge: Inventory/pets not found for", player.Name)
        end

        -- Call all registered loadEquipped functions (native + fallback if present)
        if #loadEquippedFunctions > 0 then
            -- The imported function expects pets to have Equipped.Value set
            -- We need to update pet data before calling
            updatePetBooleanStates(player)

            for idx, f in ipairs(loadEquippedFunctions) do
                print("🚚 Bridge: Calling loadEquippedFunction #" .. idx .. "...")
                local success, err = pcall(f, player)
                if not success then
                    warn(
                        "❌ PetEquipmentBridge: Failed to call loadEquipped #" .. idx .. " -",
                        err
                    )
                else
                    print("✅ Bridge: loadEquippedFunction #" .. idx .. " completed")
                end
            end
        else
            warn("⚠️ PetEquipmentBridge: No loadEquipped function set! Waiting for handler...")
            if _G.SetPetLoadEquippedFunction then
                print("🔁 Bridge: registering handler lazily now")
                _G.SetPetLoadEquippedFunction(function(plr)
                    if workspace:FindFirstChild("PlayerPets") == nil then
                        local f = Instance.new("Folder")
                        f.Name = "PlayerPets"
                        f.Parent = workspace
                    end
                    print("🧪 Lazy handler: (no-op) received call for", plr.Name)
                    return "Success"
                end)
            end
        end
    end)
end

-- Is the pet a slot points at still owned? A slot is BACKED when its inventory
-- entry still EXISTS — NOT when quantity > 0. Equipping a stack pet decrements its
-- available quantity (an equipped last copy sits at quantity 0 with the entry still
-- present), so existence is the correct signal; only a traded/removed pet deletes
-- the entry. FAIL OPEN: return true whenever the inventory mirror isn't built yet,
-- so a load-timing race can never wrongly unequip a real pet.
local function slotHasBacking(player, parsed)
    local inv = player:FindFirstChild("Inventory")
    local petsFolder = inv and inv:FindFirstChild("pets")
    if not petsFolder then
        return true
    end
    if parsed.kind == "stack" then
        local stacks = petsFolder:FindFirstChild("Stacks")
        if not stacks then
            return true
        end
        return stacks:FindFirstChild(parsed.stackKey) ~= nil
    elseif parsed.kind == "special" then
        local special = petsFolder:FindFirstChild("Special")
        if not special then
            return true
        end
        return special:FindFirstChild(parsed.uid) ~= nil
    elseif parsed.kind == "legacy" then
        local special = petsFolder:FindFirstChild("Special")
        if not special then
            return true
        end
        return special:FindFirstChild(parsed.raw) ~= nil
            or petsFolder:FindFirstChild(parsed.raw) ~= nil
    end
    return true
end

local function setupSlotListener(player, slotValue)
    local connections = playerConnections[player]
    if not connections then
        return
    end

    -- Create a unique key for this connection
    local connectionKey = "slot_" .. slotValue.Name .. "_changed"

    -- Clean up old connection if it exists
    if connections[connectionKey] then
        connections[connectionKey]:Disconnect()
    end

    -- Listen for value changes on this slot
    connections[connectionKey] = slotValue:GetPropertyChangedSignal("Value"):Connect(function()
        print("🔄 PetEquipmentBridge: Slot value changed -", slotValue.Name, "=", slotValue.Value)

        -- Update equipped pets cache
        equippedPets[player] = equippedPets[player] or {}

        -- Clear all pets first (we'll rebuild from current slots)
        for uid in pairs(equippedPets[player]) do
            equippedPets[player][uid] = nil
        end

        -- Rebuild from all current slots and construct temp equip folders for stacks
        clearEquipFolders(player)
        local petsFolder = slotValue.Parent
        for _, slot in ipairs(petsFolder:GetChildren()) do
            if slot:IsA("StringValue") and slot.Value ~= "" then
                local parsed = parseSlotValue(slot.Value)
                if not slotHasBacking(player, parsed) then
                    warn("🧹 Bridge: skipping orphaned equip slot", slot.Name, "=", slot.Value)
                elseif parsed.kind == "special" then
                    equippedPets[player][parsed.uid] = true
                elseif parsed.kind == "stack" then
                    print(
                        "🔗 Bridge: slot",
                        slot.Name,
                        "stack equip",
                        parsed.stackKey,
                        parsed.eph
                    )
                    ensureEquipFolderForStack(player, parsed.stackKey, parsed.eph)
                else
                    equippedPets[player][slot.Value] = true
                end
            end
        end

        triggerLoadEquipped(player)
    end)
end

local function setupPetsFolder(player, petsFolder)
    print("📁 PetEquipmentBridge: Setting up pets folder listeners for", player.Name)

    local connections = playerConnections[player]
    if not connections then
        return
    end

    -- Initial scan of equipped pets
    equippedPets[player] = {}
    clearEquipFolders(player)
    for _, slotValue in ipairs(petsFolder:GetChildren()) do
        if slotValue:IsA("StringValue") and slotValue.Value ~= "" then
            local parsed = parseSlotValue(slotValue.Value)
            if not slotHasBacking(player, parsed) then
                warn(
                    "🧹 Bridge: skipping orphaned equip slot",
                    slotValue.Name,
                    "=",
                    slotValue.Value
                )
            elseif parsed.kind == "special" then
                equippedPets[player][parsed.uid] = true
            elseif parsed.kind == "stack" then
                ensureEquipFolderForStack(player, parsed.stackKey, parsed.eph)
            else
                equippedPets[player][slotValue.Value] = true
            end
        end
    end

    -- Trigger initial load
    triggerLoadEquipped(player)

    -- Listen for new slots being added
    connections.slotAdded = petsFolder.ChildAdded:Connect(function(child)
        if child:IsA("StringValue") then
            print("➕ PetEquipmentBridge: Slot added -", child.Name)
            setupSlotListener(player, child)

            -- If slot has a value, update and trigger
            if child.Value ~= "" then
                equippedPets[player][child.Value] = true
                triggerLoadEquipped(player)
            end
        end
    end)

    -- Listen for slots being removed
    connections.slotRemoved = petsFolder.ChildRemoved:Connect(function(child)
        if child:IsA("StringValue") then
            print("➖ PetEquipmentBridge: Slot removed -", child.Name)

            -- Clean up the connection for this slot
            local connectionKey = "slot_" .. child.Name .. "_changed"
            if connections[connectionKey] then
                connections[connectionKey]:Disconnect()
                connections[connectionKey] = nil
            end

            -- If slot had a value, update and trigger
            if child.Value ~= "" then
                equippedPets[player][child.Value] = nil
                triggerLoadEquipped(player)
            end
        end
    end)

    -- Set up listeners for existing slots
    for _, slotValue in ipairs(petsFolder:GetChildren()) do
        if slotValue:IsA("StringValue") then
            setupSlotListener(player, slotValue)
        end
    end
end

local function onCharacterAdded(player, character)
    print("👤 PetEquipmentBridge: Character added for", player.Name)

    -- Wait for equipped folder
    local equippedFolder = player:WaitForChild("Equipped", 10)
    if not equippedFolder then
        warn("❌ PetEquipmentBridge: No equipped folder found for", player.Name)
        return
    end

    -- Wait for pets folder
    local petsFolder = equippedFolder:FindFirstChild("pets")
    if not petsFolder then
        -- Wait for it to be created
        local connection
        connection = equippedFolder.ChildAdded:Connect(function(child)
            if child.Name == "pets" and child:IsA("Folder") then
                connection:Disconnect()
                setupPetsFolder(player, child)
            end
        end)

        -- Store this connection
        if playerConnections[player] then
            playerConnections[player].waitingForPets = connection
        end
    else
        setupPetsFolder(player, petsFolder)
    end
end

local function setupPlayer(player)
    print("🎮 PetEquipmentBridge: Setting up equipment bridge for", player.Name)

    -- Initialize connections storage
    playerConnections[player] = {}
    equippedPets[player] = {}

    -- Connect character events
    playerConnections[player].characterAdded = player.CharacterAdded:Connect(function(character)
        onCharacterAdded(player, character)
    end)

    -- If character already exists
    if player.Character then
        onCharacterAdded(player, player.Character)
    end
end

local function cleanupPlayer(player)
    print("🧹 PetEquipmentBridge: Cleaning up", player.Name)

    -- Clean up all connections
    if playerConnections[player] then
        for key, connection in pairs(playerConnections[player]) do
            if typeof(connection) == "RBXScriptConnection" then
                connection:Disconnect()
            end
        end
        playerConnections[player] = nil
    end

    -- Clear equipped cache
    equippedPets[player] = nil
    loadDebounce[player] = nil
end

-- Initialize
print("🌉 PetEquipmentBridge: Initializing...")

-- Connect existing players
for _, player in ipairs(Players:GetPlayers()) do
    setupPlayer(player)
end

-- Connect future players
Players.PlayerAdded:Connect(setupPlayer)

-- Cleanup on player removal
Players.PlayerRemoving:Connect(cleanupPlayer)

print("✅ PetEquipmentBridge: Initialized and waiting for ImportedPetHandler...")
