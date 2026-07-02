--[[
    InventoryService - Universal Inventory Management System
    
    Features:
    - Unique ID generation for items
    - Bucket-based storage (stackable vs unique items)
    - Folder-based replication to client
    - Type-safe operations with comprehensive validation
    - Real-time client updates via Value objects
    
    Usage:
    local uid = InventoryService:AddItem(player, "pets", petData)
    local success = InventoryService:EquipItem(player, "pets", uid, "slot_1")
    local inventory = InventoryService:GetInventory(player, "pets")
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local fireGameEvent = require(ReplicatedStorage.Shared.Network.FireGameEvent)
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local Locations = require(ReplicatedStorage.Shared.Locations)
local PetInventoryView = require(ReplicatedStorage.Shared.Inventory.PetInventoryView)

local InventoryService = {}
InventoryService.__index = InventoryService

-- Honor the configured "warn" log level: silence the raw boot/admin print() banners that
-- bypassed the Logger. Warnings/errors still surface via warn(). Toggle for local debugging.
local __RAW_PRINT = print
local __PRINT_ENABLED = false
local function print(...)
    if __PRINT_ENABLED then
        __RAW_PRINT(...)
    end
end

-- Helper to safely require configs
local function tryLoadConfig(configLoader, name)
    local ok, result = pcall(function()
        return configLoader:LoadConfig(name)
    end)
    if ok then
        return result
    end
    return nil
end

function InventoryService:Init()
    print("🚀 InventoryService:Init() called")

    -- Get injected dependencies
    self._logger = self._modules.Logger
    self._dataService = self._modules.DataService
    self._configLoader = self._modules.ConfigLoader
    self._upgradeService = self._modules.UpgradeService
    self._playerProgressionService = self._modules.PlayerProgressionService
    self._petIndexService = nil

    print("📦 InventoryService dependencies injected")

    -- Load inventory configuration
    self._inventoryConfig = self._configLoader:LoadConfig("inventory")
    -- Pets config (for rarity lookup)
    self._petsConfig = tryLoadConfig(self._configLoader, "pets")

    print("📋 InventoryService config loaded")

    -- Track player inventory folders for replication
    self._playerInventoryFolders = {}
    self._playerEquippedFolders = {}
    self._playerLevelConnections = {}

    self._logger:Info("📦 InventoryService initializing", {
        enabledBuckets = self._inventoryConfig.enabled_buckets,
        settingsDebug = self._inventoryConfig.settings.debug_logging,
    })

    -- Connect to player events for folder management
    Players.PlayerAdded:Connect(function(player)
        self:_onPlayerAdded(player)
    end)

    Players.PlayerRemoving:Connect(function(player)
        self:_onPlayerRemoving(player)
    end)

    -- Setup Network Signals for inventory operations
    self:_setupNetworkSignals()

    self._logger:Info("✅ InventoryService initialized successfully")
end

function InventoryService:Start()
    print("🚀 InventoryService:Start() called")

    -- Create folders for any players already in game
    for _, player in pairs(Players:GetPlayers()) do
        if self._dataService:IsDataLoaded(player) then
            print("📂 Creating folders for existing player:", player.Name)
            self:_createInventoryFolders(player)
            self:_connectPlayerLevelRewards(player)
        end
    end

    self._logger:Info("🚀 InventoryService started")
    print("✅ InventoryService fully started and ready")
end

-- ═══════════════════════════════════════════════════════════════════════════════════
-- 🆔 UID GENERATION SYSTEM
-- ═══════════════════════════════════════════════════════════════════════════════════

function InventoryService:GenerateUID(itemType)
    local timestamp = math.floor(tick())
    local randomSuffix = HttpService:GenerateGUID(false)
        :sub(1, self._inventoryConfig.settings.uid_prefix_length)

    local uid = string.format("%s_%d_%s", itemType or "item", timestamp, randomSuffix)

    if self._inventoryConfig.settings.trace_operations then
        self._logger:Debug("🆔 UID GENERATED", {
            uid = uid,
            itemType = itemType,
            timestamp = timestamp,
            randomSuffix = randomSuffix,
        })
    end

    return uid
end

-- ═══════════════════════════════════════════════════════════════════════════════════
-- 📦 CORE INVENTORY OPERATIONS
-- ═══════════════════════════════════════════════════════════════════════════════════

function InventoryService:AddItem(player, bucketName, itemData)
    if self._inventoryConfig.settings.trace_operations then
        self._logger:Info("📦 ADD ITEM - Starting", {
            player = player.Name,
            bucket = bucketName,
            itemId = itemData.id,
            itemType = type(itemData),
        })
    end

    -- Validate inputs
    local isValid, errorMsg = self:_validateAddItem(player, bucketName, itemData)
    if not isValid then
        self._logger:Error("❌ ADD ITEM FAILED - Validation error", {
            player = player.Name,
            bucket = bucketName,
            error = errorMsg,
        })
        return nil, errorMsg
    end

    -- Get player data
    local data = self._dataService:GetData(player)
    if not data or not data.Inventory or not data.Inventory[bucketName] then
        self._logger:Error("❌ ADD ITEM FAILED - Bucket not found", {
            player = player.Name,
            bucket = bucketName,
        })
        return nil, "Bucket not found: " .. bucketName
    end

    local bucket = data.Inventory[bucketName]
    local bucketConfig = self._inventoryConfig.buckets[bucketName]

    -- Check if bucket has space. Existing stacks do not consume a new slot.
    local requiredSlots = self:_getRequiredSlotsForAdd(bucketName, itemData, bucket, bucketConfig)
    if requiredSlots > 0 and not self:HasSpace(player, bucketName, requiredSlots) then
        self._logger:Warn("⚠️ ADD ITEM FAILED - No space", {
            player = player.Name,
            bucket = bucketName,
            usedSlots = bucket.used_slots,
            totalSlots = bucket.total_slots,
            requiredSlots = requiredSlots,
        })
        return nil, "No space in " .. bucketConfig.display_name
    end

    local uid = nil
    local success = false

    -- SSOT: every pet instance is its own uid record (no stacking in storage). A
    -- quantity>1 add mints that many common records; specials are always singletons.
    if bucketName == "pets" then
        uid, success = self:_addPetRecords(player, itemData, bucket)
    else
        if bucketConfig.storage_type == "stackable" then
            uid, success =
                self:_addStackableItem(player, bucketName, itemData, bucket, bucketConfig)
        else
            uid, success = self:_addUniqueItem(player, bucketName, itemData, bucket, bucketConfig)
        end
    end

    if success then
        -- Update folder replication. Adding a pet only INCREASES ownership — it can never
        -- invalidate an equip ref — so refresh the inventory folder only (no equip re-validate
        -- / equipped-folder churn). This keeps mass hatching cheap.
        if bucketName == "pets" then
            self:RefreshPetInventory(player)
        else
            self:_updateBucketFolders(player, bucketName)
        end

        self._logger:Info("✅ ADD ITEM SUCCESS", {
            player = player.Name,
            bucket = bucketName,
            uid = uid,
            itemId = itemData.id,
            storageType = bucketConfig.storage_type,
        })

        self._dataService:RequestSave(player, "inventory_add_" .. tostring(bucketName), {
            critical = bucketName == "pets",
        })

        if bucketName == "pets" then
            self:_recordPetIndex(player, itemData)
        end

        return uid
    else
        self._logger:Error("❌ ADD ITEM FAILED - Storage error", {
            player = player.Name,
            bucket = bucketName,
            itemId = itemData.id,
        })
        return nil, "Failed to add item"
    end
end

function InventoryService:_getRequiredSlotsForAdd(bucketName, itemData, bucket, bucketConfig)
    if bucketName == "pets" then
        -- STORAGE V2: only UNIQUE records (secret+) consume slots. Stacks are
        -- self-bounding (the catalog is their cap) — commons AND mythics never
        -- fail on space, which kills the silent auto-hatch truncation for good.
        return self:_isSpecialPetData(itemData) and 1 or 0
    end

    -- UNIFIED MODEL (Jason): any bucket flagged stacks_count_toward_limit = false
    -- follows the pet rule — stackable items are FREE, only unique-tier items count
    -- toward base_limit. These buckets (enhancements/eggs/consumables/resources)
    -- have no unique tier today, so a stackable add never consumes a slot.
    if
        bucketConfig.stacks_count_toward_limit == false
        and bucketConfig.storage_type == "stackable"
    then
        return 0
    end

    if bucketConfig.storage_type == "stackable" and bucket.items and bucket.items[itemData.id] then
        return 0
    end

    return 1
end

function InventoryService:_recordPetIndex(player, itemData)
    if self._petIndexService == nil and self._moduleLoader then
        local ok, service = pcall(function()
            return self._moduleLoader:Get("PetIndexService")
        end)
        self._petIndexService = ok and service or false
    end

    if self._petIndexService and self._petIndexService.RecordPetObtained then
        local ok, result = pcall(function()
            return self._petIndexService:RecordPetObtained(player, itemData)
        end)
        if not ok then
            self._logger:Warn("Pet index update failed after pet add", {
                context = "InventoryService",
                player = player.Name,
                itemId = itemData.id,
                error = tostring(result),
            })
        end
    end
end

function InventoryService:_addStackableItem(player, bucketName, itemData, bucket, bucketConfig)
    local itemId = itemData.id

    -- Check if item already exists in bucket
    if bucket.items[itemId] then
        -- Stack with existing item
        local existingItem = bucket.items[itemId]
        local newQuantity = existingItem.quantity + (itemData.quantity or 1)

        -- Check stack limit
        if newQuantity > bucketConfig.stack_size then
            self._logger:Warn("⚠️ STACKABLE ADD - Stack limit exceeded", {
                player = player.Name,
                itemId = itemId,
                currentQuantity = existingItem.quantity,
                addingQuantity = itemData.quantity or 1,
                stackLimit = bucketConfig.stack_size,
            })
            return nil, false
        end

        existingItem.quantity = newQuantity

        self._logger:Debug("📦 STACKABLE ADD - Stacked with existing", {
            player = player.Name,
            itemId = itemId,
            newQuantity = newQuantity,
        })

        return itemId, true
    else
        -- Create new stack
        bucket.items[itemId] = {
            id = itemId,
            quantity = itemData.quantity or 1,
            obtained_at = os.time(),
        }

        -- Copy any optional properties
        for _, optionalField in ipairs(bucketConfig.item_schema.optional or {}) do
            if itemData[optionalField] then
                bucket.items[itemId][optionalField] = itemData[optionalField]
            end
        end

        -- UNIFIED MODEL: stacks-free buckets don't grow used_slots (it tracks
        -- UNIQUES only, like pets) so the 80% OpsAlert telemetry stays honest.
        if bucketConfig.stacks_count_toward_limit ~= false then
            bucket.used_slots = bucket.used_slots + 1
        end

        self._logger:Debug("📦 STACKABLE ADD - Created new stack", {
            player = player.Name,
            itemId = itemId,
            quantity = itemData.quantity or 1,
            newUsedSlots = bucket.used_slots,
        })

        return itemId, true
    end
end

function InventoryService:_addUniqueItem(player, bucketName, itemData, bucket, bucketConfig)
    local uid = self:GenerateUID(itemData.id or "item")

    -- Create unique item entry
    bucket.items[uid] = {
        id = itemData.id,
        obtained_at = os.time(),
    }

    -- Copy all provided data
    for key, value in pairs(itemData) do
        if key ~= "id" then -- id already set
            bucket.items[uid][key] = value
        end
    end

    -- Apply defaults for missing optional fields
    local defaults = self._inventoryConfig.defaults[bucketName] or {}
    local schema = bucketConfig.item_schema
        or (bucketConfig.schema and bucketConfig.schema.special)
        or {}
    for _, optionalField in ipairs(schema.optional or {}) do
        if bucket.items[uid][optionalField] == nil and defaults[optionalField] ~= nil then
            bucket.items[uid][optionalField] = defaults[optionalField]
        end
    end

    bucket.used_slots = bucket.used_slots + 1

    self._logger:Debug("📦 UNIQUE ADD - Created unique item", {
        player = player.Name,
        uid = uid,
        itemId = itemData.id,
        newUsedSlots = bucket.used_slots,
    })

    return uid, true
end

-- Determine if a pet should be treated as special (unique)
function InventoryService:_isSpecialPet(petId, variant)
    if not self._petsConfig then
        return false
    end
    local petData = self._petsConfig.getPet and self._petsConfig.getPet(petId, variant) or nil
    if not petData then
        return false
    end
    local rarityId = petData.rarity_id
        or (petData.rarity and petData.rarity.name and string.lower(petData.rarity.name))
    if not rarityId then
        return false
    end
    local specialList = (
        self._inventoryConfig
        and self._inventoryConfig.buckets
        and self._inventoryConfig.buckets.pets
        and self._inventoryConfig.buckets.pets.special_rarities
    ) or { "secret", "exclusive" }
    for _, r in ipairs(specialList) do
        if r == rarityId then
            return true
        end
    end

    local maxByRarity = self._petsConfig.enchanting
        and self._petsConfig.enchanting.max_enchantments_by_rarity
    if type(maxByRarity) == "table" and tonumber(maxByRarity[rarityId] or 0) > 0 then
        return true
    end

    return false
end

-- Compute stack key for pets: id:variant:enchant (Storage v2 — the enchant is part of
-- a stack's IDENTITY; "" component for enchantless stacks). MUST stay byte-identical
-- to PetInventoryView.stackKey over the configured stack_key_fields.
function InventoryService:_petStackKey(petId, variant, enchant)
    return table.concat({
        tostring(petId),
        tostring(variant or "basic"),
        tostring(enchant or ""),
    }, ":")
end

-- ═══════════════════════════════════════════════════════════════════════════════════
-- 🐾 SSOT PET HELPERS (capability + view config + selector resolution)
-- ═══════════════════════════════════════════════════════════════════════════════════
-- The capability ({specialRarities=set}) is THE classifier PetInventoryView uses to
-- decide "is this pet unique-per-instance (special) or stackable (common)". Built once
-- from config so server slot-accounting and the projection agree by construction.
function InventoryService:_petCapability()
    if self._petCapabilityCache then
        return self._petCapabilityCache
    end
    local specialRarities = {}
    local petsCfg = self._inventoryConfig.buckets and self._inventoryConfig.buckets.pets
    if petsCfg and type(petsCfg.special_rarities) == "table" then
        for _, rarity in ipairs(petsCfg.special_rarities) do
            specialRarities[rarity] = true
        end
    end
    if
        self._petsConfig
        and self._petsConfig.enchanting
        and type(self._petsConfig.enchanting.max_enchantments_by_rarity) == "table"
    then
        for rarity, maxEnch in pairs(self._petsConfig.enchanting.max_enchantments_by_rarity) do
            if (tonumber(maxEnch) or 0) > 0 then
                specialRarities[rarity] = true
            end
        end
    end
    self._petCapabilityCache = { specialRarities = specialRarities }
    return self._petCapabilityCache
end

function InventoryService:_petViewConfig()
    if self._petViewConfigCache then
        return self._petViewConfigCache
    end
    local fields = { "id", "variant" }
    local petsCfg = self._inventoryConfig.buckets and self._inventoryConfig.buckets.pets
    if petsCfg and type(petsCfg.stack_key_fields) == "table" and #petsCfg.stack_key_fields > 0 then
        fields = petsCfg.stack_key_fields
    end
    self._petViewConfigCache = {
        stack_key_fields = fields,
        count_stacks_as_single = (petsCfg and petsCfg.count_stacks_as_single) ~= false,
        -- Storage v2: false => only UNIQUE records count toward the bucket limit
        stacks_count_toward_limit = not (
                    petsCfg and petsCfg.stacks_count_toward_limit == false
                )
                and true
            or false,
    }
    return self._petViewConfigCache
end

-- Public accessor so other services classify pets with the EXACT same capability the
-- inventory projection uses (no divergent "is this special" logic across services).
function InventoryService:GetPetCapability()
    return self:_petCapability()
end

-- Public selector resolver for services that receive legacy client identifiers
-- (e.g. TradeService). Returns a target descriptor (see _resolvePetTarget).
function InventoryService:ResolvePetTarget(player, selector)
    return self:_resolvePetTarget(player, selector)
end

-- Is this record/itemData a special (unique-per-instance) pet? Combines the record-field
-- classifier (what the projection uses) with the config lookup (catches specials whose
-- itemData hasn't carried rarity_id yet).
function InventoryService:_isSpecialPetData(data)
    if type(data) ~= "table" then
        return false
    end
    if PetInventoryView.isSpecial(data, self:_petCapability()) then
        return true
    end
    return self:_isSpecialPet(data.id, data.variant)
end

-- First equip slot in [1..maxSlots] not occupied by ANY pet (common or special).
function InventoryService:_freePetSlot(items, equipped, maxSlots)
    local slotMap = PetInventoryView.resolveEquipped(items, equipped, maxSlots)
    for slot = 1, maxSlots do
        if slotMap[slot] == nil then
            return slot
        end
    end
    return nil
end

-- Translate a client identifier into a concrete target:
--   { kind = "special", uid = <uid> }   for a unique pet
--   { kind = "stack",   stackKey = <id:variant>, slot = <n>? }  for a common stack
-- `slot` is only set when the selector names a specific equipped common copy (the equipped
-- ghost card sends "stack|id:variant|<slot>"), so unequip can target the right slot.
function InventoryService:_resolvePetTarget(player, selector)
    if type(selector) ~= "string" or selector == "" then
        return nil
    end
    local data = self._dataService:GetData(player)
    local items = data and data.Inventory and data.Inventory.pets and data.Inventory.pets.items
    if type(items) ~= "table" then
        return nil
    end

    local entry = items[selector]
    if entry then
        if PetInventoryView.isStackEntry(entry, selector) then
            return { kind = "stack", stackKey = selector }
        end
        return { kind = "special", uid = selector }
    end

    local parts = string.split(selector, "|")
    if parts[1] == "special" and parts[2] then
        return items[parts[2]] and { kind = "special", uid = parts[2] } or nil
    elseif parts[1] == "stack" and parts[2] then
        -- Legacy eph could be a special uid; otherwise it encodes the equipped slot number.
        if
            parts[3]
            and items[parts[3]]
            and not PetInventoryView.isStackEntry(items[parts[3]], parts[3])
        then
            return { kind = "special", uid = parts[3] }
        end
        if not items[parts[2]] then
            return nil
        end
        return { kind = "stack", stackKey = parts[2], slot = tonumber(parts[3]) }
    elseif #parts == 1 and string.find(selector, ":") then
        return items[selector] and { kind = "stack", stackKey = selector } or nil
    end
    return nil
end

-- SSOT pet add (hybrid). Specials mint one uid record per instance (they carry per-instance
-- state). Commons increment a single compact stack entry keyed by id:variant (one entry per
-- kind regardless of count). Equip state is never touched here. used_slots is recomputed by
-- the projection rebuild.
function InventoryService:_addPetRecords(player, itemData, bucket)
    local count = math.max(1, math.floor(tonumber(itemData.quantity) or 1))

    if self:_isSpecialPetData(itemData) then
        local lastUid
        -- provenance (Jason): every UNIQUE pet records who hatched it and the
        -- hatcher's PLAYER CLASS (1 = base; rebirth raises it). Class-gated hatches
        -- (dragons) check the HATCHER's class, so progress can't be bought/traded —
        -- a class-1 hatched dragon never counts toward a class-2 ladder.
        local hatcherClass = 1
        do
            local data = self._dataService and self._dataService:GetData(player)
            hatcherClass = (data and tonumber(data.PlayerClass)) or 1
        end
        for _ = 1, count do
            local uid = self:GenerateUID(itemData.id or "pet")
            local record = {
                id = itemData.id,
                obtained_at = os.time(),
                uid = uid,
                equipped_slot = nil,
                hatched_by = player.UserId,
                player_class = hatcherClass,
            }
            for key, value in pairs(itemData) do
                if
                    key ~= "id"
                    and key ~= "quantity"
                    and key ~= "_kind"
                    and key ~= "uid"
                    and key ~= "obtained_at"
                    and key ~= "equipped_slot"
                    and key ~= "equipped_slots"
                then
                    record[key] = value
                end
            end
            record.variant = record.variant or "basic"
            -- Self-describe specials with rarity_id so the projection classifies them the
            -- same way the server does (no config lookup at render time).
            if record.rarity_id == nil and self:_isSpecialPet(record.id, record.variant) then
                local cfg = self._petsConfig
                    and self._petsConfig.getPet
                    and self._petsConfig.getPet(record.id, record.variant)
                if cfg and cfg.rarity_id then
                    record.rarity_id = cfg.rarity_id
                end
            end
            bucket.items[uid] = record
            lastUid = uid
        end
        self._logger:Debug("📦 PET SPECIAL ADD", {
            player = player.Name,
            itemId = itemData.id,
            minted = count,
        })
        return lastUid, true
    end

    -- Common: increment the compact stack (key includes the stack enchant — Storage v2).
    local stackKey = self:_petStackKey(itemData.id, itemData.variant or "basic", itemData.enchant)
    local stack = bucket.items[stackKey]
    if not stack then
        stack = {
            id = itemData.id,
            variant = itemData.variant or "basic",
            quantity = 0,
            obtained_at = os.time(),
        }
        if itemData.element ~= nil then
            stack.element = itemData.element
        end
        if itemData.enchant ~= nil then
            stack.enchant = itemData.enchant
        end
        bucket.items[stackKey] = stack
    end
    stack.quantity = math.max(0, math.floor(tonumber(stack.quantity) or 0)) + count

    self._logger:Debug("📦 PET STACK ADD", {
        player = player.Name,
        stackKey = stackKey,
        added = count,
        quantity = stack.quantity,
    })
    return stackKey, true
end

function InventoryService:RemoveItem(player, bucketName, uid, quantity)
    if self._inventoryConfig.settings.trace_operations then
        self._logger:Info("📦 REMOVE ITEM - Starting", {
            player = player.Name,
            bucket = bucketName,
            uid = uid,
            quantity = quantity,
        })
    end

    -- Get player data and bucket
    local data = self._dataService:GetData(player)
    if not data or not data.Inventory or not data.Inventory[bucketName] then
        return false, "Bucket not found"
    end

    local bucket = data.Inventory[bucketName]
    local bucketConfig = self._inventoryConfig.buckets[bucketName]
    local success = false

    if bucketName == "pets" then
        -- Resolve the client identifier; specials remove the uid record, commons decrement
        -- the compact stack (toSlotArray re-clamps equipped_slots so an over-equipped stack
        -- drops an equip automatically).
        local target = self:_resolvePetTarget(player, uid)
        if not target then
            self._logger:Warn(
                "⚠️ REMOVE ITEM - Pet not found",
                { player = player.Name, uid = uid }
            )
            return false, "Item not found"
        end
        if target.kind == "special" then
            bucket.items[target.uid] = nil
            success = true
        else
            local stack = bucket.items[target.stackKey]
            if stack and (tonumber(stack.quantity) or 0) > 0 then
                local removeQty = math.max(1, math.floor(tonumber(quantity) or 1))
                stack.quantity = math.max(0, math.floor(stack.quantity) - removeQty)
                if stack.quantity <= 0 then
                    bucket.items[target.stackKey] = nil
                end
                -- Equip lives in Equipped.pets; RebuildPetProjections re-validates it, so any
                -- now-over-cap equip refs for this kind are dropped automatically.
                success = true
            end
        end
        if not success then
            return false, "Item not found"
        end
    else
        if not bucket.items[uid] then
            self._logger:Warn("⚠️ REMOVE ITEM - Item not found", {
                player = player.Name,
                bucket = bucketName,
                uid = uid,
            })
            return false, "Item not found"
        end
        local item = bucket.items[uid]
        if bucketConfig.storage_type == "stackable" then
            success =
                self:_removeStackableItem(player, bucketName, uid, quantity or 1, bucket, item)
        else
            success = self:_removeUniqueItem(player, bucketName, uid, bucket)
        end
    end

    if success then
        -- Update folder replication. For pets, rebuild BOTH mirrors (a removed pet may
        -- have been equipped — the equipped slot must clear too).
        if bucketName == "pets" then
            self:RebuildPetProjections(player)
        else
            self:_updateBucketFolders(player, bucketName)
        end

        self._logger:Info("✅ REMOVE ITEM SUCCESS", {
            player = player.Name,
            bucket = bucketName,
            uid = uid,
            storageType = bucketConfig.storage_type,
        })

        self._dataService:RequestSave(player, "inventory_remove_" .. tostring(bucketName), {
            critical = bucketName == "pets",
        })
    end

    return success
end

function InventoryService:_removeStackableItem(player, bucketName, uid, quantity, bucket, item)
    if item.quantity <= quantity then
        -- Remove entire stack
        bucket.items[uid] = nil
        bucket.used_slots = bucket.used_slots - 1

        self._logger:Debug("📦 STACKABLE REMOVE - Removed entire stack", {
            player = player.Name,
            uid = uid,
            removedQuantity = item.quantity,
            newUsedSlots = bucket.used_slots,
        })
    else
        -- Reduce stack
        item.quantity = item.quantity - quantity

        self._logger:Debug("📦 STACKABLE REMOVE - Reduced stack", {
            player = player.Name,
            uid = uid,
            removedQuantity = quantity,
            remainingQuantity = item.quantity,
        })
    end

    return true
end

function InventoryService:_removeUniqueItem(player, bucketName, uid, bucket)
    bucket.items[uid] = nil
    bucket.used_slots = bucket.used_slots - 1

    self._logger:Debug("📦 UNIQUE REMOVE - Removed unique item", {
        player = player.Name,
        uid = uid,
        newUsedSlots = bucket.used_slots,
    })

    return true
end

-- ═══════════════════════════════════════════════════════════════════════════════════
-- 📂 FOLDER-BASED REPLICATION SYSTEM
-- ═══════════════════════════════════════════════════════════════════════════════════

function InventoryService:_onPlayerAdded(player)
    -- Wait for DataService to load player profile
    task.spawn(function()
        local maxWait = 10 -- seconds
        local waited = 0

        while not self._dataService:IsDataLoaded(player) and waited < maxWait do
            task.wait(0.1)
            waited = waited + 0.1
        end

        if self._dataService:IsDataLoaded(player) then
            -- RETROFIT (Jason): unique pets minted before provenance existed (the
            -- huges) get player_class = 1. hatched_by stays unset for legacy records
            -- (unknowable after trades) — only new mints carry it.
            do
                local data = self._dataService:GetData(player)
                local pets = data and data.Inventory and data.Inventory.pets
                local changed = false
                for _, rec in pairs((pets and pets.items) or {}) do
                    if rec.uid and rec.player_class == nil then
                        rec.player_class = 1
                        changed = true
                    end
                end
                if changed then
                    self._dataService:RequestSave(player, "pet_player_class_backfill")
                end
            end
            self:_createInventoryFolders(player)
            self:_connectPlayerLevelRewards(player)
        else
            self._logger:Warn("⚠️ REPLICATION - Player data not loaded in time", {
                player = player.Name,
                waitedSeconds = waited,
            })
        end
    end)
end

function InventoryService:_onPlayerRemoving(player)
    local levelConnection = self._playerLevelConnections[player]
    if levelConnection then
        levelConnection:Disconnect()
        self._playerLevelConnections[player] = nil
    end

    -- Cleanup folder references
    self._playerInventoryFolders[player] = nil
    self._playerEquippedFolders[player] = nil

    self._logger:Debug("🧹 REPLICATION - Cleaned up folder references", {
        player = player.Name,
    })
end

function InventoryService:_connectPlayerLevelRewards(player)
    if self._playerLevelConnections[player] then
        return
    end

    self._playerLevelConnections[player] = player
        :GetAttributeChangedSignal("Level")
        :Connect(function()
            self:_updateEquippedFolders(player, "pets")
        end)
end

function InventoryService:_createInventoryFolders(player)
    self._logger:Info("📂 REPLICATION - Creating inventory folders", {
        player = player.Name,
    })

    local data = self._dataService:GetData(player)
    if not data or not data.Inventory then
        self._logger:Error("❌ REPLICATION - No inventory data found", {
            player = player.Name,
        })
        return
    end

    local existingInventory = player:FindFirstChild("Inventory")
    if existingInventory then
        existingInventory:Destroy()
    end

    local existingEquipped = player:FindFirstChild("Equipped")
    if existingEquipped then
        existingEquipped:Destroy()
    end

    -- Create main Inventory folder
    local inventoryFolder = Instance.new("Folder")
    inventoryFolder.Name = "Inventory"
    inventoryFolder.Parent = player

    -- Create main Equipped folder
    local equippedFolder = Instance.new("Folder")
    equippedFolder.Name = "Equipped"
    equippedFolder.Parent = player

    -- Store references
    self._playerInventoryFolders[player] = inventoryFolder
    self._playerEquippedFolders[player] = equippedFolder

    -- Create bucket folders
    for bucketName, bucket in pairs(data.Inventory) do
        if type(bucket) == "table" and bucket.total_slots then
            self:_createBucketFolder(player, bucketName, inventoryFolder)
        end
    end

    -- Create equipped folders
    for category, slots in pairs(data.Equipped or {}) do
        self:_createEquippedFolder(player, category, equippedFolder)
    end

    -- Pets: rebuild from records so the freshly-created folders + equipped mirror are
    -- correct regardless of the order the skeleton folders were built above.
    if data.Inventory and data.Inventory.pets then
        self:RebuildPetProjections(player)
    end

    self._logger:Info("✅ REPLICATION - Inventory folders created successfully", {
        player = player.Name,
        inventoryBuckets = self:_getBucketNames(data.Inventory),
        equippedCategories = self:_getBucketNames(data.Equipped or {}),
    })
end

function InventoryService:_createBucketFolder(player, bucketName, parentFolder)
    local data = self._dataService:GetData(player)
    local bucket = data.Inventory[bucketName]
    local bucketConfig = self._inventoryConfig.buckets[bucketName]

    -- Create bucket folder
    local bucketFolder = Instance.new("Folder")
    bucketFolder.Name = bucketName
    bucketFolder.Parent = parentFolder

    -- Create info subfolder with slot information
    local infoFolder = Instance.new("Folder")
    infoFolder.Name = "Info"
    infoFolder.Parent = bucketFolder

    local slotsUsed = Instance.new("IntValue")
    slotsUsed.Name = "SlotsUsed"
    slotsUsed.Value = bucket.used_slots or 0
    slotsUsed.Parent = infoFolder

    local slotsTotal = Instance.new("IntValue")
    slotsTotal.Name = "SlotsTotal"
    slotsTotal.Value = bucket.total_slots or 0
    slotsTotal.Parent = infoFolder

    local storageType = Instance.new("StringValue")
    storageType.Name = "StorageType"
    storageType.Value = bucketConfig and bucketConfig.storage_type or "unique"
    storageType.Parent = infoFolder

    -- Pets use mixed replication (Stacks + Special), now PROJECTED from uid records via
    -- PetInventoryView. RebuildPetProjections (called after folder creation) fills these.
    if bucketName == "pets" then
        self:_buildPetBucketFolders(bucketFolder, bucket.items or {})
    else
        -- Create item folders (legacy buckets)
        for uid, itemData in pairs(bucket.items or {}) do
            self:_createItemFolder(bucketFolder, uid, itemData, bucketConfig)
        end
    end

    self._logger:Debug("📂 REPLICATION - Created bucket folder", {
        player = player.Name,
        bucket = bucketName,
        usedSlots = bucket.used_slots,
        totalSlots = bucket.total_slots,
        itemCount = self:_countItems(bucket.items or {}),
    })
end

function InventoryService:_createItemFolder(parentFolder, uid, itemData, bucketConfig)
    local itemFolder = Instance.new("Folder")
    itemFolder.Name = uid
    itemFolder.Parent = parentFolder

    -- Add basic item information
    local itemId = Instance.new("StringValue")
    itemId.Name = "ItemId"
    itemId.Value = itemData.id or "unknown"
    itemId.Parent = itemFolder

    local obtainedAt = Instance.new("NumberValue")
    obtainedAt.Name = "ObtainedAt"
    obtainedAt.Value = itemData.obtained_at or 0
    obtainedAt.Parent = itemFolder

    -- Add storage-type specific data
    if bucketConfig and bucketConfig.storage_type == "stackable" then
        local quantity = Instance.new("IntValue")
        quantity.Name = "Quantity"
        quantity.Value = itemData.quantity or 1
        quantity.Parent = itemFolder
        -- stacks carry their item PROPERTIES too (type/origins/level/name…) — without
        -- these the client renders faceless cards (Jason: "42 enhancements with no
        -- description whatsoever")
        for key, value in pairs(itemData) do
            if key ~= "id" and key ~= "obtained_at" and key ~= "quantity" then
                local valueObj = self:_createValueObject(key, value)
                if valueObj then
                    valueObj.Parent = itemFolder
                end
            end
        end
    else
        -- Unique item properties
        for key, value in pairs(itemData) do
            if key ~= "id" and key ~= "obtained_at" then
                local valueObj = self:_createValueObject(key, value)
                if valueObj then
                    valueObj.Parent = itemFolder
                end
            end
        end
    end
end

function InventoryService:_createEquippedFolder(player, category, parentFolder)
    local data = self._dataService:GetData(player)
    local slots = data.Equipped[category]
    local configured = self._inventoryConfig.equipped[category]
    local configuredSlots = (configured and type(configured.slots) == "number") and configured.slots
        or nil

    local categoryFolder = Instance.new("Folder")
    categoryFolder.Name = category
    categoryFolder.Parent = parentFolder

    local createdCount = 0
    if configuredSlots then
        local maxSlots = self:_getMaxEquippedSlots(player, category, configuredSlots)
        local pruned = self:_pruneEquippedSlots(player, category, maxSlots)
        if pruned and category == "pets" then
            self:_updateBucketFolders(player, "pets")
        end

        for i = 1, maxSlots do
            local slotName = "slot_" .. i
            local itemUid = slots and slots[slotName] or nil
            local slotValue = Instance.new("StringValue")
            slotValue.Name = slotName
            slotValue.Value = itemUid or ""
            slotValue.Parent = categoryFolder
            createdCount = createdCount + 1
        end
    else
        -- Fallback: create only declared keys
        for slotName, itemUid in pairs(slots or {}) do
            local slotValue = Instance.new("StringValue")
            slotValue.Name = slotName
            slotValue.Value = itemUid or ""
            slotValue.Parent = categoryFolder
            createdCount = createdCount + 1
        end
    end

    self._logger:Debug("⚔️ REPLICATION - Created equipped folder", {
        player = player.Name,
        category = category,
        slots = createdCount,
    })
end

function InventoryService:_updateBucketFolders(player, bucketName)
    local inventoryFolder = self._playerInventoryFolders[player]
    if not inventoryFolder then
        self._logger:Warn("⚠️ REPLICATION - No inventory folder found for update", {
            player = player.Name,
            bucket = bucketName,
        })
        return
    end

    local bucketFolder = inventoryFolder:FindFirstChild(bucketName)
    if not bucketFolder then
        self._logger:Warn("⚠️ REPLICATION - No bucket folder found for update", {
            player = player.Name,
            bucket = bucketName,
        })
        return
    end

    -- Update slot counts
    local data = self._dataService:GetData(player)
    local bucket = data.Inventory[bucketName]

    local infoFolder = bucketFolder:FindFirstChild("Info")
    if infoFolder then
        local slotsUsed = infoFolder:FindFirstChild("SlotsUsed")
        if slotsUsed then
            slotsUsed.Value = bucket.used_slots or 0
        end
    end

    -- Remove old item folders (preserve Info). For pets, also preserve any `equip_*`
    -- folders that PetEquipmentBridge owns for spawning equipped-common follow models —
    -- wiping them would desync the world pets. The bridge manages their lifecycle.
    for _, child in pairs(bucketFolder:GetChildren()) do
        local isInfo = child.Name == "Info"
        local isBridgeEquip = bucketName == "pets" and string.sub(child.Name, 1, 6) == "equip_"
        if not isInfo and not isBridgeEquip then
            child:Destroy()
        end
    end

    local bucketConfig = self._inventoryConfig.buckets[bucketName]
    if bucketName == "pets" then
        -- Equipped.pets is already validated (RebuildPetProjections ran _validateEquippedTable);
        -- compute the per-kind equipped overlay so common Quantity = unequipped count.
        local configuredSlots = self._inventoryConfig.equipped
            and self._inventoryConfig.equipped.pets
            and self._inventoryConfig.equipped.pets.slots
        local maxSlots = self:_getMaxEquippedSlots(player, "pets", configuredSlots)
        local _, equippedByKey = PetInventoryView.resolveEquipped(
            bucket.items or {},
            (data.Equipped and data.Equipped.pets) or {},
            maxSlots
        )
        self:_buildPetBucketFolders(bucketFolder, bucket.items or {}, equippedByKey)
    else
        for uid, itemData in pairs(bucket.items or {}) do
            self:_createItemFolder(bucketFolder, uid, itemData, bucketConfig)
        end
    end

    if self._inventoryConfig.settings.trace_operations then
        self._logger:Debug("🔄 REPLICATION - Updated bucket folder", {
            player = player.Name,
            bucket = bucketName,
            usedSlots = bucket.used_slots,
            itemCount = self:_countItems(bucket.items or {}),
        })
    end
end

-- Project uid records into the legacy-shaped Stacks/Special folders the client reads.
-- Commons group by id:variant (Quantity = UNEQUIPPED count; equipped commons surface via
-- the equipped mirror as ghost cards). Each special is its own Special/<uid> folder. This
-- is the ONLY place the pets bucket folder is built, derived purely from PetInventoryView.
function InventoryService:_buildPetBucketFolders(bucketFolder, items, equippedByKey)
    local stacksFolder = Instance.new("Folder")
    stacksFolder.Name = "Stacks"
    stacksFolder.Parent = bucketFolder

    local specialFolder = Instance.new("Folder")
    specialFolder.Name = "Special"
    specialFolder.Parent = bucketFolder

    local config = self:_petViewConfig()
    local capability = self:_petCapability()
    for _, group in ipairs(PetInventoryView.groups(items, config, capability, equippedByKey)) do
        if group.isSpecial then
            for _, uid in ipairs(group.uids) do
                self:_createPetSpecialFolder(specialFolder, uid, items[uid])
            end
        else
            local sample = group.sampleRecord
            self:_createPetStackFolder(stacksFolder, group.key, {
                id = sample.id,
                variant = sample.variant,
                quantity = group.unequippedCount,
                enchant = sample.enchant, -- Storage v2: the stack's identity enchant
            })
        end
    end
end

-- Create a stack folder for a normal pet
function InventoryService:_createPetStackFolder(parentFolder, stackKey, itemData)
    local stackFolder = Instance.new("Folder")
    stackFolder.Name = stackKey
    stackFolder.Parent = parentFolder

    local itemId = Instance.new("StringValue")
    itemId.Name = "ItemId"
    itemId.Value = itemData.id or "unknown"
    itemId.Parent = stackFolder

    local variant = Instance.new("StringValue")
    variant.Name = "Variant"
    variant.Value = itemData.variant or "basic"
    variant.Parent = stackFolder

    local qty = Instance.new("IntValue")
    qty.Name = "Quantity"
    qty.Value = itemData.quantity or 1
    qty.Parent = stackFolder

    -- Storage v2: enchant-keyed stacks surface their effect for the card badge
    if itemData.enchant ~= nil then
        local enchant = Instance.new("StringValue")
        enchant.Name = "Enchant"
        enchant.Value = tostring(itemData.enchant)
        enchant.Parent = stackFolder
    end
end

-- Create a folder for a special pet (unique)
function InventoryService:_createPetSpecialFolder(parentFolder, uid, itemData)
    local itemFolder = Instance.new("Folder")
    itemFolder.Name = uid
    itemFolder.Parent = parentFolder

    local itemId = Instance.new("StringValue")
    itemId.Name = "ItemId"
    itemId.Value = itemData.id or "unknown"
    itemId.Parent = itemFolder

    local obtainedAt = Instance.new("NumberValue")
    obtainedAt.Name = "ObtainedAt"
    obtainedAt.Value = itemData.obtained_at or 0
    obtainedAt.Parent = itemFolder

    -- Legacy special folders carried Quantity=1; keep it so client counts are unchanged.
    local qty = Instance.new("IntValue")
    qty.Name = "Quantity"
    qty.Value = 1
    qty.Parent = itemFolder

    -- Copy remaining fields. Exclude internal SSOT fields (uid/equipped_slot/_kind/quantity)
    -- — equip state is read from the equipped mirror, not the item folder.
    for key, value in pairs(itemData) do
        if
            key ~= "id"
            and key ~= "obtained_at"
            and key ~= "_kind"
            and key ~= "uid"
            and key ~= "equipped_slot"
            and key ~= "quantity"
        then
            local valueObj = self:_createValueObject(key, value)
            if valueObj then
                valueObj.Parent = itemFolder
            end
        end
    end
end

-- ═══════════════════════════════════════════════════════════════════════════════════
-- 🔍 QUERY OPERATIONS
-- ═══════════════════════════════════════════════════════════════════════════════════

function InventoryService:GetInventory(player, bucketName)
    local data = self._dataService:GetData(player)
    if not data or not data.Inventory then
        return nil
    end

    if bucketName then
        return data.Inventory[bucketName]
    else
        return data.Inventory
    end
end

function InventoryService:GetItem(player, bucketName, uid)
    local bucket = self:GetInventory(player, bucketName)
    if not bucket or not bucket.items then
        return nil
    end

    return bucket.items[uid]
end

function InventoryService:HasSpace(player, bucketName, amount)
    amount = amount or 1

    local bucket = self:GetInventory(player, bucketName)
    if not bucket then
        return false
    end

    local availableSlots = bucket.total_slots - bucket.used_slots
    return availableSlots >= amount
end

function InventoryService:GetUsedSlots(player, bucketName)
    local bucket = self:GetInventory(player, bucketName)
    return bucket and bucket.used_slots or 0
end

function InventoryService:GetTotalSlots(player, bucketName)
    local bucket = self:GetInventory(player, bucketName)
    return bucket and bucket.total_slots or 0
end

-- ═══════════════════════════════════════════════════════════════════════════════════
-- 🛡️ VALIDATION HELPERS
-- ═══════════════════════════════════════════════════════════════════════════════════

function InventoryService:_validateAddItem(player, bucketName, itemData)
    if not player or not player.Parent then
        return false, "Invalid player"
    end

    if not bucketName or type(bucketName) ~= "string" then
        return false, "Invalid bucket name"
    end

    if not self._inventoryConfig.enabled_buckets[bucketName] then
        return false, "Bucket not enabled: " .. bucketName
    end

    if not itemData or type(itemData) ~= "table" then
        return false, "Invalid item data"
    end

    if not itemData.id or type(itemData.id) ~= "string" then
        return false, "Item missing required 'id' field"
    end

    local bucketConfig = self._inventoryConfig.buckets[bucketName]
    if not bucketConfig then
        return false, "Bucket configuration not found: " .. bucketName
    end

    -- Validate required fields
    if bucketConfig.storage_type == "mixed" and bucketName == "pets" then
        -- Mixed pets require id and variant
        if not itemData.id then
            return false, "Item missing required field: id"
        end
        if not itemData.variant then
            return false, "Item missing required field: variant"
        end
    else
        for _, requiredField in
            ipairs(bucketConfig.item_schema and bucketConfig.item_schema.required or {})
        do
            if requiredField ~= "obtained_at" and not itemData[requiredField] then
                return false, "Item missing required field: " .. requiredField
            end
        end
    end

    return true
end

-- ═══════════════════════════════════════════════════════════════════════════════════
-- 🔧 UTILITY HELPERS
-- ═══════════════════════════════════════════════════════════════════════════════════

function InventoryService:_createValueObject(name, value)
    local valueType = type(value)
    local valueObj = nil

    if valueType == "string" then
        valueObj = Instance.new("StringValue")
        valueObj.Value = value
    elseif valueType == "number" then
        if math.floor(value) == value then
            valueObj = Instance.new("IntValue")
        else
            valueObj = Instance.new("NumberValue")
        end
        valueObj.Value = value
    elseif valueType == "boolean" then
        valueObj = Instance.new("BoolValue")
        valueObj.Value = value
    elseif valueType == "table" then
        -- For complex data like stats or enchantments, create a folder
        valueObj = Instance.new("Folder")
        for key, subValue in pairs(value) do
            local subObj = self:_createValueObject(key, subValue)
            if subObj then
                subObj.Parent = valueObj
            end
        end
    end

    if valueObj then
        valueObj.Name = tostring(name)
    end

    return valueObj
end

function InventoryService:_getBucketNames(buckets)
    local names = {}
    for name in pairs(buckets) do
        table.insert(names, name)
    end
    return names
end

function InventoryService:_countItems(items)
    local count = 0
    for _ in pairs(items) do
        count = count + 1
    end
    return count
end

-- Obsolete under the SSOT model: equipping a pet no longer decrements a stack quantity, so
-- there is nothing to "restore" when an equipped slot is pruned. Kept as a no-op (callers
-- still invoke it) to avoid ever writing a `quantity` field back onto a uid record.
function InventoryService:_restoreStackQuantityForEquippedValue(
    _playerData,
    _category,
    _equippedValue
)
    return false
end

function InventoryService:_pruneEquippedSlots(player, category, maxSlots)
    local playerData = self._dataService:GetData(player)
    local equipped = playerData and playerData.Equipped and playerData.Equipped[category]
    if not equipped then
        return false
    end

    local changed = false
    for slotName, equippedValue in pairs(equipped) do
        local slotNumber = tonumber(tostring(slotName):match("^slot_(%d+)$"))
        if slotNumber and slotNumber > maxSlots and equippedValue ~= nil then
            self:_restoreStackQuantityForEquippedValue(playerData, category, equippedValue)
            equipped[slotName] = nil
            changed = true
        end
    end

    if changed then
        self._logger:Info("Pruned equipped slots over configured cap", {
            player = player.Name,
            category = category,
            maxSlots = maxSlots,
        })

        self._dataService:RequestSave(player, "equipped_slot_cap_" .. tostring(category), {
            critical = category == "pets",
        })
    end

    return changed
end

-- Determine maximum equipped slots for a category.
function InventoryService:_getMaxEquippedSlots(player, category, configuredSlots)
    local baseSlots = configuredSlots or 1

    if category ~= "pets" then
        return baseSlots
    end

    local petConfig = self._inventoryConfig.equipped and self._inventoryConfig.equipped.pets or {}
    local data = self._dataService:GetData(player)
    local extraSlots = 0
    local perkName = petConfig.extra_slots_perk or "extra_pet_slots"

    if data and data.Perks then
        extraSlots = tonumber(data.Perks[perkName]) or 0
    end

    if self._upgradeService and self._upgradeService.GetUpgradeEffectTotal then
        extraSlots += self._upgradeService:GetUpgradeEffectTotal(player, "equip_slots", category)
    end

    if
        self._playerProgressionService
        and self._playerProgressionService.GetEquippedPetSlotBonus
    then
        extraSlots += self._playerProgressionService:GetEquippedPetSlotBonus(player)
    end

    local attributeSlots = tonumber(player:GetAttribute("ExtraPetSlots")) or 0
    extraSlots = math.max(extraSlots, attributeSlots)

    local maxSlots = tonumber(petConfig.max_slots) or (baseSlots + extraSlots)
    local finalSlots = math.clamp(baseSlots + extraSlots, 1, maxSlots)
    -- Replicate the UNLOCKED equip-slot count so the Pets-window can draw one ring per slot
    -- (#179: blank rings show how many slots you have at a glance, even when not all are filled).
    player:SetAttribute("PetEquipSlots", finalSlots)
    return finalSlots
end

-- ═══════════════════════════════════════════════════════════════════════════════════
-- 🌐 NETWORK SIGNAL HANDLERS
-- ═══════════════════════════════════════════════════════════════════════════════════

function InventoryService:_setupNetworkSignals()
    local Signals = require(ReplicatedStorage.Shared.Network.Signals)

    -- Player deletes item from their inventory
    Signals.DeleteInventoryItem.OnServerEvent:Connect(function(player, data)
        self:_handleDeleteInventoryItem(player, data)
    end)

    -- Admin cleanup commands
    Signals.CleanupInventory.OnServerEvent:Connect(function(player, data)
        print("🛠️ SERVER RECEIVED: CleanupInventory from", player.Name)
        print("🔍 CLEANUP DATA:", data)
        self._logger:Warn("🚨 ADMIN CLEANUP TRIGGERED", {
            admin = player.Name,
            data = data,
            stackTrace = debug.traceback("Admin cleanup call stack:"),
        })
        self:_handleCleanupInventory(player, data)
    end)

    Signals.FixItemCategories.OnServerEvent:Connect(function(player, data)
        print("🛠️ SERVER RECEIVED: FixItemCategories from", player.Name)
        self:_handleFixItemCategories(player, data)
    end)

    Signals.CleanOrphanedBuckets.OnServerEvent:Connect(function(player, data)
        print("🛠️ SERVER RECEIVED: CleanOrphanedBuckets from", player.Name)
        self:_handleCleanOrphanedBuckets(player, data)
    end)

    -- Pet equipping
    Signals.TogglePetEquipped.OnServerEvent:Connect(function(player, data)
        self:_handleTogglePetEquipped(player, data)
    end)

    -- Draft commit: replace the whole equipped squad at once (the team-draft Activate). One
    -- RebuildPetProjections → one deploy, atomic — no per-pet toggle race. See task #240.
    Signals.SetEquippedPets.OnServerEvent:Connect(function(player, data)
        self:_handleSetEquippedPets(player, data)
    end)

    -- Tool equipping
    Signals.ToggleToolEquipped.OnServerEvent:Connect(function(player, data)
        self:_handleToggleToolEquipped(player, data)
    end)

    self._logger:Info("📡 Inventory Network Signals connected")
end

-- DELETION POLICY (configs/pets.lua `deletion`): protected classes are undeletable —
-- huge/creator flags on the record, plus denied rarities (exclusive, creator, future
-- titans/colossals). Rarity falls back to the family config when the record predates
-- rarity stamping.
function InventoryService:_isDeletionDenied(record)
    if self._petsConfigCache == nil then
        local ok, cfg = pcall(function()
            return self._configLoader:LoadConfig("pets")
        end)
        self._petsConfigCache = (ok and cfg) or false
    end
    local pets = self._petsConfigCache
    local policy = pets and pets.deletion
    if not policy then
        return false
    end
    if policy.deny_huge ~= false and record.huge == true then
        return true
    end
    if policy.deny_creator ~= false and record.creator == true then
        return true
    end
    local rarity = record.rarity_id
    if rarity == nil and pets.pets and record.id then
        local family = pets.pets[record.id]
        rarity = family and (family.rarity_id or family.rarity)
    end
    return (policy.denied_rarities and rarity and policy.denied_rarities[rarity] == true) or false
end

function InventoryService:_handleDeleteInventoryItem(player, data)
    self._logger:Info("🗑️ DELETE ITEM REQUEST", {
        player = player.Name,
        bucket = data.bucket,
        itemUid = data.itemUid,
        itemId = data.itemId,
        quantity = data.quantity or 1,
        reason = data.reason,
    })

    -- Validate player is deleting their own item (security check)
    if not player or not data.bucket or not data.itemUid then
        self._logger:Warn("❌ Invalid delete request", {
            player = player and player.Name or "nil",
            data = data,
        })
        return
    end

    -- Get player's profile
    local profile = self._dataService:GetProfile(player)
    if not profile then
        self._logger:Warn("❌ No profile found for player", { player = player.Name })
        return
    end

    -- Check if item exists in the specified bucket
    local inventoryData = profile.Data.Inventory or {}
    local bucketData = inventoryData[data.bucket]
    if not bucketData or not bucketData.items then
        self._logger:Warn("❌ Bucket not found", { bucket = data.bucket })
        return
    end

    -- Pets: resolve the identifier; a special deletes its uid record, a common decrements its
    -- stack by `quantity` (RemoveItem handles equipped_slots re-clamping + stack cleanup).
    if data.bucket == "pets" then
        -- DELETION POLICY (Jason: huges/exclusives/creator+ deletion is "simply
        -- denied"): the guard lives on the DELETE INTENT, not RemoveItem — trades
        -- and fusion route through RemoveItem and must stay open (huges trade).
        local record = bucketData.items[data.itemUid]
        if record and self:_isDeletionDenied(record) then
            self._logger:Warn("⛔ Delete DENIED (protected class)", {
                player = player.Name,
                itemUid = data.itemUid,
                petId = record.id,
                huge = record.huge == true,
                creator = record.creator == true,
                rarity = record.rarity_id,
            })
            return
        end
        local deleteQuantity = math.max(1, math.floor(tonumber(data.quantity) or 1))
        local ok = self:RemoveItem(player, "pets", data.itemUid, deleteQuantity)
        if not ok then
            self._logger:Warn(
                "❌ Pet not found for delete",
                { itemUid = data.itemUid, bucket = data.bucket }
            )
            return
        end
        self._logger:Info("✅ Pet(s) deleted", {
            player = player.Name,
            itemUid = data.itemUid,
            quantity = deleteQuantity,
        })
        -- RemoveItem already rebuilt projections + requested a critical save.
        return
    end

    local item = bucketData.items[data.itemUid]
    if not item then
        self._logger:Warn("❌ Item not found", { itemUid = data.itemUid, bucket = data.bucket })
        return
    end

    local deleteQuantity = data.quantity or 1
    local currentQuantity = item.quantity or 1

    if deleteQuantity >= currentQuantity then
        -- Delete entire item
        bucketData.items[data.itemUid] = nil
        bucketData.used_slots = math.max(0, (bucketData.used_slots or 0) - 1)

        self._logger:Info("✅ Item completely deleted", {
            player = player.Name,
            itemId = data.itemId,
            itemUid = data.itemUid,
            bucket = data.bucket,
            deletedQuantity = currentQuantity,
            newUsedSlots = bucketData.used_slots,
        })
    else
        -- Reduce quantity
        item.quantity = currentQuantity - deleteQuantity

        self._logger:Info("✅ Item quantity reduced", {
            player = player.Name,
            itemId = data.itemId,
            itemUid = data.itemUid,
            bucket = data.bucket,
            deletedQuantity = deleteQuantity,
            remainingQuantity = item.quantity,
        })
    end

    -- Update replication folders immediately. For pets, rebuild BOTH mirrors so a
    -- deleted equipped pet also clears its equipped slot.
    if data.bucket == "pets" then
        self:RebuildPetProjections(player)
    else
        self:_updateBucketFolders(player, data.bucket)
    end
end

function InventoryService:_handleCleanupInventory(player, data)
    self._logger:Info("🧹 ADMIN CLEANUP REQUEST", {
        admin = player.Name,
        targetPlayerId = data.targetPlayerId,
        action = data.action,
    })

    -- Validate admin permissions (you may want to add AdminService check here)
    local targetPlayer = Players:GetPlayerByUserId(data.targetPlayerId)
    if not targetPlayer then
        self._logger:Warn("❌ Target player not found", { targetPlayerId = data.targetPlayerId })
        return
    end

    -- Get target player's profile
    local profile = self._dataService:GetProfile(targetPlayer)
    if not profile then
        self._logger:Warn("❌ No profile found for target player", { player = targetPlayer.Name })
        return
    end

    -- Use the unified orphaned bucket removal logic
    self:_removeOrphanedBuckets(player, data)
end

-- Helper function to count items in a table
function InventoryService:_countTableItems(items)
    local count = 0
    for _ in pairs(items or {}) do
        count = count + 1
    end
    return count
end

function InventoryService:_handleFixItemCategories(player, data)
    self._logger:Info("🔧 ADMIN FIX CATEGORIES REQUEST", {
        admin = player.Name,
        targetPlayerId = data.targetPlayerId,
        action = data.action,
    })

    -- Validate admin permissions
    local targetPlayer = Players:GetPlayerByUserId(data.targetPlayerId)
    if not targetPlayer then
        self._logger:Warn("❌ Target player not found", { targetPlayerId = data.targetPlayerId })
        return
    end

    -- Get target player's profile
    local profile = self._dataService:GetProfile(targetPlayer)
    if not profile then
        self._logger:Warn("❌ No profile found for target player", { player = targetPlayer.Name })
        return
    end

    -- This would implement item migration logic
    -- For now, just log that it was called
    self._logger:Info("✅ Category fix completed", {
        admin = player.Name,
        targetPlayer = targetPlayer.Name,
        note = "Migration logic would go here",
    })
end

function InventoryService:_handleCleanOrphanedBuckets(player, data)
    self._logger:Info("🗑️ ADMIN CLEAN ORPHANED BUCKETS REQUEST", {
        admin = player.Name,
        targetPlayerId = data.targetPlayerId,
        action = data.action,
    })

    -- Use the same logic as the safe cleanup - remove buckets not in config
    self:_removeOrphanedBuckets(player, data)
end

-- Unified orphaned bucket removal logic
function InventoryService:_removeOrphanedBuckets(player, data)
    -- Validate admin permissions
    local targetPlayer = Players:GetPlayerByUserId(data.targetPlayerId)
    if not targetPlayer then
        self._logger:Warn("❌ Target player not found", { targetPlayerId = data.targetPlayerId })
        return
    end

    -- Get target player's profile
    local profile = self._dataService:GetProfile(targetPlayer)
    if not profile then
        self._logger:Warn("❌ No profile found for target player", { player = targetPlayer.Name })
        return
    end

    if not profile.Data or not profile.Data.Inventory then
        self._logger:Info("✅ No inventory data to clean", { player = targetPlayer.Name })
        return
    end

    -- Get list of buckets that SHOULD exist (from configuration)
    local validBuckets = {}
    for _, bucketConfig in ipairs(self._inventoryConfig.enabled_buckets or {}) do
        validBuckets[bucketConfig.name] = true
    end

    self._logger:Info("📋 VALID BUCKETS FROM CONFIG", {
        validBuckets = validBuckets,
        configuredCount = #(self._inventoryConfig.enabled_buckets or {}),
    })

    local cleaned = {}
    local bucketsCleaned = 0
    local itemsCleaned = 0

    -- Remove everything that is NOT supposed to be there
    for bucketName, bucketData in pairs(profile.Data.Inventory) do
        if not validBuckets[bucketName] then
            -- This bucket shouldn't exist - remove it
            local itemCount = 0
            if type(bucketData) == "table" and bucketData.items then
                itemCount = self:_countTableItems(bucketData.items)
            end

            self._logger:Info("🗑️ REMOVING INVALID BUCKET", {
                bucketName = bucketName,
                itemCount = itemCount,
                targetPlayer = targetPlayer.Name,
                reason = "Not in enabled_buckets configuration",
            })

            profile.Data.Inventory[bucketName] = nil
            table.insert(cleaned, bucketName .. " (" .. itemCount .. " items)")
            bucketsCleaned = bucketsCleaned + 1
            itemsCleaned = itemsCleaned + itemCount
        end
    end

    if bucketsCleaned > 0 then
        -- Recreate all inventory folders to reflect the cleanup
        -- First, destroy existing folders
        if self._playerInventoryFolders[targetPlayer] then
            self._playerInventoryFolders[targetPlayer]:Destroy()
        end
        if self._playerEquippedFolders[targetPlayer] then
            self._playerEquippedFolders[targetPlayer]:Destroy()
        end

        -- Clear references and recreate
        self._playerInventoryFolders[targetPlayer] = nil
        self._playerEquippedFolders[targetPlayer] = nil
        self:_createInventoryFolders(targetPlayer)

        self._logger:Info("✅ Orphaned buckets cleaned", {
            admin = player.Name,
            targetPlayer = targetPlayer.Name,
            bucketsRemoved = bucketsCleaned,
            itemsRemoved = itemsCleaned,
            cleanedBuckets = cleaned,
        })
    else
        self._logger:Info("✅ No orphaned buckets found to clean", {
            admin = player.Name,
            targetPlayer = targetPlayer.Name,
        })
    end
end

-- ═══════════════════════════════════════════════════════════════════════════════════
-- 🎽 EQUIPMENT HANDLERS
-- ═══════════════════════════════════════════════════════════════════════════════════

function InventoryService:_handleTogglePetEquipped(player, data)
    self._logger:Info("🐾 PET EQUIP REQUEST", {
        player = player.Name,
        bucket = data.bucket,
        itemUid = data.itemUid,
        itemId = data.itemId,
        action = data.action or "toggle",
    })

    -- Validate request
    if not data.bucket or not data.itemUid or data.bucket ~= "pets" then
        self._logger:Warn("❌ Invalid pet equip request", {
            player = player.Name,
            bucket = data.bucket,
            itemUid = data.itemUid,
        })
        return
    end

    local playerData = self._dataService:GetData(player)
    if not playerData or not playerData.Inventory or not playerData.Inventory.pets then
        self._logger:Warn("❌ No pet inventory found", { player = player.Name })
        return
    end

    local items = playerData.Inventory.pets.items
    local petSlots = self._inventoryConfig.equipped.pets
    local maxSlots = self:_getMaxEquippedSlots(player, "pets", petSlots.slots)
    playerData.Equipped = playerData.Equipped or {}
    playerData.Equipped.pets = playerData.Equipped.pets or {}
    local equipped = playerData.Equipped.pets

    -- Resolve the client identifier. Equip mutates the SEPARATE Equipped.pets layer (never the
    -- ownership record). A special toggles its single slot. A common: the equipped ghost card
    -- sends a specific slot ("stack|id:variant|<slot>") → unequip that slot; an inventory stack
    -- card sends no slot → equip one more copy (if an unequipped copy exists).
    local target = self:_resolvePetTarget(player, data.itemUid)
    if not target then
        self._logger:Warn(
            "❌ Pet not found in inventory",
            { player = player.Name, itemUid = data.itemUid }
        )
        return
    end

    local _, equippedByKey = PetInventoryView.resolveEquipped(items, equipped, maxSlots)
    local success, result = false, nil

    if target.kind == "special" then
        -- Is this special already equipped (in some slot)?
        local currentSlot
        for slotName, ref in pairs(equipped) do
            local desc = PetInventoryView.parseRef(ref)
            if desc and desc.kind == "special" and desc.uid == target.uid then
                currentSlot = slotName
                break
            end
        end
        if currentSlot then
            equipped[currentSlot] = nil
            success, result = true, { action = "unequipped" }
        else
            local slot = self:_freePetSlot(items, equipped, maxSlots)
            if slot then
                equipped["slot_" .. slot] = target.uid
                success, result = true, { action = "equipped", slot = slot }
            else
                result = { reason = "no_slots", maxSlots = maxSlots }
            end
        end
    else
        local stack = items[target.stackKey]
        if not stack then
            self._logger:Warn(
                "❌ Stack not found for equip",
                { player = player.Name, key = target.stackKey }
            )
            return
        end
        local slotName = target.slot and ("slot_" .. target.slot) or nil
        if
            slotName
            and equipped[slotName]
            and PetInventoryView.parseRef(equipped[slotName]).stackKey == target.stackKey
        then
            -- Unequip that specific slot.
            equipped[slotName] = nil
            success, result = true, { action = "unequipped", slot = target.slot }
        elseif (equippedByKey[target.stackKey] or 0) < (tonumber(stack.quantity) or 0) then
            -- Equip one more copy.
            local slot = self:_freePetSlot(items, equipped, maxSlots)
            if slot then
                equipped["slot_" .. slot] = "stack|" .. target.stackKey
                success, result = true, { action = "equipped", slot = slot }
            else
                result = { reason = "no_slots", maxSlots = maxSlots }
            end
        else
            result = { reason = "no_unequipped_copy" }
        end
    end

    if success then
        -- equip state changed → rebuild every projection from the records.
        self:RebuildPetProjections(player)
        -- bus source (no default reactions): the tutorial's "equip your pet" step listens.
        -- Fired on BOTH directions so full-slot players (kept huges) can still complete it.
        fireGameEvent(player, "pet_equipped", { action = result.action })
        if result.action == "equipped" then
            -- mission counter (quest chain "Equip a pet"); equips only, not unequips
            pcall(function()
                _G.RBXTemplateServices:Get("StatsService"):Increment(player, "pets_equipped", 1)
            end)
        end
        self._logger:Info("✅ Pet equip toggled", {
            player = player.Name,
            itemUid = data.itemUid,
            slot = result.slot,
            action = result.action,
        })
        self._dataService:RequestSave(player, "pet_equip_toggle", { critical = true })
    else
        self._logger:Warn("❌ Pet equip rejected", {
            player = player.Name,
            itemUid = data.itemUid,
            reason = result and result.reason or "unknown",
            maxSlots = result and result.maxSlots or nil,
        })
    end
end

-- Commit a draft squad: replace Equipped.pets with `data.refs` (clear + set) in one shot, then ONE
-- RebuildPetProjections → one atomic deploy (no per-pet toggle race). Each ref is the equipped-layer
-- format: "stack|<stackKey>" for a common copy, or a unique uid for a special. Ownership, stack
-- quantity, and the slot cap are validated via _resolvePetTarget; unknown/over-quantity refs drop.
function InventoryService:_handleSetEquippedPets(player, data)
    local refs = data and data.refs
    if type(refs) ~= "table" then
        return
    end
    local playerData = self._dataService:GetData(player)
    if not playerData or not playerData.Inventory or not playerData.Inventory.pets then
        return
    end
    local items = playerData.Inventory.pets.items
    local petSlots = self._inventoryConfig.equipped.pets
    local maxSlots = self:_getMaxEquippedSlots(player, "pets", petSlots.slots)
    playerData.Equipped = playerData.Equipped or {}

    local newEquipped = {}
    local slot = 1
    local usedByKey = {}
    for _, ref in ipairs(refs) do
        if slot > maxSlots then
            break
        end
        local target = self:_resolvePetTarget(player, ref)
        if target then
            if target.kind == "special" then
                newEquipped["slot_" .. slot] = target.uid
                slot += 1
            else
                local stack = items[target.stackKey]
                local owned = stack and (tonumber(stack.quantity) or 0) or 0
                local used = usedByKey[target.stackKey] or 0
                if used < owned then
                    newEquipped["slot_" .. slot] = "stack|" .. target.stackKey
                    usedByKey[target.stackKey] = used + 1
                    slot += 1
                end
            end
        end
    end

    playerData.Equipped.pets = newEquipped
    self:RebuildPetProjections(player)
    fireGameEvent(player, "pet_equipped", { action = "equipped" })
    self._dataService:RequestSave(player, "squad_set", { critical = true })
    self._logger:Info("✅ Draft squad committed", { player = player.Name, count = slot - 1 })
end

function InventoryService:_handleToggleToolEquipped(player, data)
    self._logger:Info("🔧 TOOL EQUIP REQUEST", {
        player = player.Name,
        bucket = data.bucket,
        itemUid = data.itemUid,
        itemId = data.itemId,
        action = data.action or "toggle",
    })

    -- Validate request
    if not data.bucket or not data.itemUid or data.bucket ~= "tools" then
        self._logger:Warn("❌ Invalid tool equip request", {
            player = player.Name,
            bucket = data.bucket,
            itemUid = data.itemUid,
        })
        return
    end

    -- Get player data
    local playerData = self._dataService:GetData(player)
    if not playerData or not playerData.Inventory or not playerData.Inventory.tools then
        self._logger:Warn("❌ No tool inventory found", { player = player.Name })
        return
    end

    -- Verify tool exists in inventory
    local tool = playerData.Inventory.tools.items[data.itemUid]
    if not tool then
        self._logger:Warn("❌ Tool not found in inventory", {
            player = player.Name,
            itemUid = data.itemUid,
        })
        return
    end

    -- Initialize equipped tools if needed
    if not playerData.Equipped then
        playerData.Equipped = {}
    end
    if not playerData.Equipped.tools then
        playerData.Equipped.tools = {}
    end

    local success, result = self:_toggleToolEquipment(player, data.itemUid, tool, playerData)

    if success then
        -- Update equipped folder replication
        self:_updateEquippedFolders(player, "tools")

        self._logger:Info("✅ Tool equipped successfully", {
            player = player.Name,
            toolId = tool.id,
            toolUid = data.itemUid,
            slot = result.slot,
            action = result.action,
        })
    end
end

function InventoryService:_toggleToolEquipment(player, toolUid, tool, playerData)
    local equippedTools = playerData.Equipped.tools
    local toolSlots = self._inventoryConfig.equipped.tools

    -- Check if tool is already equipped
    local currentSlot = nil
    for slotName, equippedUid in pairs(equippedTools) do
        if equippedUid == toolUid then
            currentSlot = slotName
            break
        end
    end

    if currentSlot then
        -- Unequip the tool
        equippedTools[currentSlot] = nil
        return true, { action = "unequipped", slot = currentSlot }
    else
        -- Find an empty slot to equip the tool
        for i = 1, toolSlots.slots do
            local slotName = "slot_" .. i
            if not equippedTools[slotName] then
                equippedTools[slotName] = toolUid
                return true, { action = "equipped", slot = slotName }
            end
        end

        -- No empty slots - replace the first slot
        equippedTools["slot_1"] = toolUid
        return true, { action = "equipped", slot = "slot_1", replaced = true }
    end
end

-- FULL rebuild — use ONLY on paths that can invalidate equip (remove / delete / trade /
-- equip-toggle / load). Re-validates the equip layer against inventory ("re-equip from
-- truth": rewrites Equipped.pets to the valid Equipped ∩ inventory set, dropping dangling/
-- over-cap refs) then rebuilds both the inventory and equipped folders. This is also the
-- reboot self-heal: on load the equipped state is reconstructed from saved inventory, never
-- trusted blindly.
function InventoryService:RebuildPetProjections(player)
    self:_recomputePetUsedSlots(player)
    self:_validateEquippedTable(player)
    self:_updateBucketFolders(player, "pets")
    self:_updateEquippedFolders(player, "pets")
end

-- LIGHT refresh — use on ownership-only changes that CANNOT invalidate equip (add/hatch,
-- XP, enchant). Refreshes the inventory folder + slot count only; never touches the equip
-- layer or the equipped folder. Keeps mass hatching / per-breakable XP awards cheap.
function InventoryService:RefreshPetInventory(player)
    self:_recomputePetUsedSlots(player)
    self:_updateBucketFolders(player, "pets")
end

-- The "re-equip from truth" pass: live equipped = Equipped ∩ inventory. Rewrites Equipped.pets
-- to ONLY valid, in-cap refs (clean form: special → "<uid>", common → "stack|id:variant").
-- Dangling/over-cap refs (from a trade, delete, or crash before teardown) are simply dropped —
-- no phantom, no dup. Returns the validated slotMap + equippedByKey for the folder builders.
function InventoryService:_validateEquippedTable(player)
    local data = self._dataService:GetData(player)
    local pets = data and data.Inventory and data.Inventory.pets
    if type(pets) ~= "table" or type(pets.items) ~= "table" then
        return {}, {}
    end
    PetInventoryView.normalize(pets.items)

    local configuredSlots = self._inventoryConfig.equipped
        and self._inventoryConfig.equipped.pets
        and self._inventoryConfig.equipped.pets.slots
    local maxSlots = self:_getMaxEquippedSlots(player, "pets", configuredSlots)

    data.Equipped = data.Equipped or {}
    local slotMap, equippedByKey =
        PetInventoryView.resolveEquipped(pets.items, data.Equipped.pets or {}, maxSlots)

    local clean = {}
    for slotNumber, desc in pairs(slotMap) do
        if desc.kind == "special" then
            clean["slot_" .. slotNumber] = desc.uid
        else
            clean["slot_" .. slotNumber] = "stack|" .. desc.stackKey
        end
    end
    data.Equipped.pets = clean
    return slotMap, equippedByKey
end

-- used_slots is a pure function of the records (one slot per common group + per special).
function InventoryService:_recomputePetUsedSlots(player)
    local data = self._dataService:GetData(player)
    local pets = data and data.Inventory and data.Inventory.pets
    if type(pets) ~= "table" or type(pets.items) ~= "table" then
        return
    end
    pets.used_slots =
        PetInventoryView.usedSlots(pets.items, self:_petViewConfig(), self:_petCapability())
end

function InventoryService:_updateEquippedFolders(player, category)
    local equippedFolder = self._playerEquippedFolders[player]
    if not equippedFolder then
        self._logger:Warn("⚠️ No equipped folder found for update", {
            player = player.Name,
            category = category,
        })
        return
    end

    local categoryFolder = equippedFolder:FindFirstChild(category)
    if not categoryFolder then
        -- Create category folder if it doesn't exist
        categoryFolder = Instance.new("Folder")
        categoryFolder.Name = category
        categoryFolder.Parent = equippedFolder
    end

    -- Incrementally update slot values up to runtime max slots
    local playerData = self._dataService:GetData(player)
    local slots = playerData.Equipped[category] or {}
    local configured = self._inventoryConfig.equipped[category]
    local configuredSlots = (configured and type(configured.slots) == "number") and configured.slots
        or 0
    local maxSlots = self:_getMaxEquippedSlots(player, category, configuredSlots)
    local pruned = self:_pruneEquippedSlots(player, category, maxSlots)
    if pruned and category == "pets" then
        self:_updateBucketFolders(player, "pets")
    end

    local createdCount = 0
    local updatedCount = 0
    for i = 1, maxSlots do
        local slotName = "slot_" .. i
        local desiredValue = slots[slotName] or ""
        -- Client-facing form: bake the slot number into a common ref ("stack|id:variant" ->
        -- "stack|id:variant|<slot>") so the equipped ghost card can round-trip an unequip to
        -- this exact slot. Specials (bare uid) are emitted as-is.
        if category == "pets" and string.sub(desiredValue, 1, 6) == "stack|" then
            local parts = string.split(desiredValue, "|")
            if #parts == 2 then
                desiredValue = desiredValue .. "|" .. tostring(i)
            end
        end
        local slotValue = categoryFolder:FindFirstChild(slotName)
        if not slotValue then
            slotValue = Instance.new("StringValue")
            slotValue.Name = slotName
            slotValue.Value = desiredValue
            slotValue.Parent = categoryFolder
            createdCount = createdCount + 1
        else
            if slotValue.Value ~= desiredValue then
                slotValue.Value = desiredValue
                updatedCount = updatedCount + 1
            end
        end
    end

    local removedCount = 0
    for _, child in ipairs(categoryFolder:GetChildren()) do
        if child:IsA("StringValue") then
            local slotNumber = tonumber(child.Name:match("^slot_(%d+)$"))
            if slotNumber and slotNumber > maxSlots then
                child:Destroy()
                removedCount = removedCount + 1
            end
        end
    end

    self._logger:Debug("⚔️ Updated equipped folder", {
        player = player.Name,
        category = category,
        createdSlots = createdCount,
        updatedSlots = updatedCount,
        removedSlots = removedCount,
        maxSlots = maxSlots,
    })
end

return InventoryService
