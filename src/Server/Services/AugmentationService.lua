--[[
    AugmentationService — Feature 15 (Augmentation Slots).

    Owns profile.Slots (powerId -> array of slot types). Slots are earned at
    slot-grant levels and placed on unlocked (selected) powers; matching types
    trigger set bonuses. Pure rules: `src/Shared/Game/Augmentation.lua`. Respec
    (ArchetypeService) clears profile.Slots.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Augmentation = require(ReplicatedStorage.Shared.Game.Augmentation)

local AugmentationService = {}
AugmentationService.__index = AugmentationService

function AugmentationService:Init()
    self._logger = self._modules and self._modules.Logger
    self._configLoader = self._modules and self._modules.ConfigLoader
    self._dataService = self._modules and self._modules.DataService
    self._config = self._configLoader:LoadConfig("augmentation")
    self._powersConfig = self._configLoader:LoadConfig("powers") -- innate-power check (slottable w/o being in data.Powers)
end

function AugmentationService:_level(player, override)
    if override then
        return math.max(1, math.floor(override))
    end
    local locator = _G.RBXTemplateServices
    local ok, progression = pcall(function()
        return locator and locator:Get("PlayerProgressionService")
    end)
    if ok and progression and progression.GetLevel then
        return progression:GetLevel(player)
    end
    return 1
end

local function slotsMap(data)
    if type(data.Slots) ~= "table" then
        data.Slots = {}
    end
    return data.Slots
end

-- A slot is "inherent" (free with the power pick) if it's a record flagged so. Inherent slots do
-- NOT draw from the granted pool, so the allocated count (vs grants) excludes them.
local function isInherent(slot)
    return type(slot) == "table" and slot.inherent == true
end

local function allocatedCount(slots)
    local total = 0
    for _, list in pairs(slots) do
        for _, slot in ipairs(list) do
            if not isInherent(slot) then
                total += 1
            end
        end
    end
    return total
end

local function isPowerUnlocked(data, powerId, powersConfig)
    -- INNATE powers (Resonance) are owned by everyone from spawn but NOT written to data.Powers (so
    -- they don't cost a level-up pick) — they're still slottable, so treat them as unlocked.
    local def = powersConfig and powersConfig.powers and powersConfig.powers[tostring(powerId)]
    if def and def.innate then
        return true
    end
    for _, id in ipairs(data.Powers or {}) do
        if id == powerId then
            return true
        end
    end
    return false
end

function AugmentationService:GetState(player, levelOverride)
    local data = self._dataService:GetData(player)
    if not data then
        return { ok = false, reason = "data_not_loaded" }
    end
    local slots = slotsMap(data)
    local level = self:_level(player, levelOverride)
    return {
        ok = true,
        slots = slots,
        granted = Augmentation.slotsGranted(
            level,
            self._config.slot_grant_levels,
            self._config.slots_per_grant
        ),
        unallocated = Augmentation.unallocatedSlots(
            level,
            allocatedCount(slots),
            self._config.slot_grant_levels,
            self._config.slots_per_grant
        ),
    }
end

-- Place one EMPTY slot on an unlocked power. Slots are untyped capacity now; typed enhancements
-- (a later layer) drop into them. `slotType` is accepted-but-ignored for forward compatibility.
function AugmentationService:Place(player, powerId, _slotType, levelOverride)
    local data = self._dataService:GetData(player)
    if not data then
        return { ok = false, reason = "data_not_loaded" }
    end
    local slots = slotsMap(data)
    local onPower = slots[powerId] or {}
    local level = self:_level(player, levelOverride)
    local unallocated = Augmentation.unallocatedSlots(
        level,
        allocatedCount(slots),
        self._config.slot_grant_levels,
        self._config.slots_per_grant
    )

    local decision = Augmentation.canPlace(
        isPowerUnlocked(data, powerId, self._powersConfig),
        onPower,
        unallocated,
        self._config
    )
    if not decision.ok then
        return { ok = false, reason = decision.reason }
    end

    table.insert(onPower, {}) -- an empty slot record (future: { enhancement = ..., type = ... })
    slots[powerId] = onPower
    self._dataService:RequestSave(player, "augment_place", { critical = true })
    return { ok = true, slots = onPower, count = #onPower }
end

return AugmentationService
