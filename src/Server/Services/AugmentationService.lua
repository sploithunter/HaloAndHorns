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

-- PARTIAL RESPEC (Jason: "get rid of one of the resonance slots and put it
-- in huge fortune"): move ONE allocated slot between owned powers. Prefers
-- an EMPTY donor slot; a FILLED donor returns its enhancement to the
-- inventory FIRST (Grant = the fallible step before the pure removal — the
-- audited transaction order). Inherent slots never move. The receiving side
-- reuses Place, so the pool math and the 6-cap stay single-sourced.
function AugmentationService:Move(player, fromPowerId, toPowerId)
    local data = self._dataService:GetData(player)
    if not data then
        return { ok = false, reason = "data_not_loaded" }
    end
    if fromPowerId == toPowerId then
        return { ok = false, reason = "same_power" }
    end
    local slots = slotsMap(data)
    local donor = slots[fromPowerId]
    if type(donor) ~= "table" or #donor == 0 then
        return { ok = false, reason = "no_slots_on_power" }
    end
    -- pick the donor slot: last empty non-inherent, else last non-inherent
    local idx
    for i = #donor, 1, -1 do
        local s = donor[i]
        if type(s) == "table" and not s.inherent and s.enh == nil then
            idx = i
            break
        end
    end
    if not idx then
        for i = #donor, 1, -1 do
            local s = donor[i]
            if type(s) == "table" and not s.inherent then
                idx = i
                break
            end
        end
    end
    if not idx then
        return { ok = false, reason = "only_inherent_slots" }
    end
    local moving = donor[idx]
    local returned = false
    if type(moving) == "table" and moving.enh ~= nil then
        local okGrant, granted = pcall(function()
            local locator = _G.RBXTemplateServices
            local enhSvc = locator and locator:Get("EnhancementService")
            return enhSvc and enhSvc:Grant(player, moving.enh)
        end)
        if not (okGrant and type(granted) == "table" and granted.ok ~= false) then
            return { ok = false, reason = "enhancement_return_failed" }
        end
        returned = true
    end
    table.remove(donor, idx)
    local placed = self:Place(player, toPowerId)
    if not placed.ok then
        -- roll back the removal (a returned enhancement STAYS in inventory —
        -- strictly player-favorable; they can re-slot it)
        table.insert(donor, {})
        self._dataService:RequestSave(player, "augment_move_rollback", { critical = true })
        return { ok = false, reason = placed.reason }
    end
    self._dataService:RequestSave(player, "augment_move", { critical = true })
    -- passives re-stamp: a filled donor slot changed that power's aggregates
    pcall(function()
        local locator = _G.RBXTemplateServices
        local power = locator and locator:Get("PowerService")
        if power and power._applyOwnedPassives then
            power:_applyOwnedPassives(player)
        end
    end)
    return {
        ok = true,
        from = fromPowerId,
        to = toPowerId,
        fromCount = #donor,
        toCount = placed.count,
        returnedEnhancement = returned,
    }
end

return AugmentationService
