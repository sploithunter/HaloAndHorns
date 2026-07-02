--[[
    PetSerialService

    Allocates global serial numbers for rare unique pets. Serial allocation must
    happen before the pet is inserted into player inventory so two live servers
    cannot grant the same numbered Huge pet.
]]

local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local PetSerialService = {}
PetSerialService.__index = PetSerialService

local DEFAULT_STORE_NAME = "PetSerials_v1"

function PetSerialService.new()
    local self = setmetatable({}, PetSerialService)
    self._logger = nil
    self._configLoader = nil
    self._store = nil
    self._storeName = DEFAULT_STORE_NAME
    self._memoryCounters = {}
    return self
end

function PetSerialService:Init()
    self._logger = self._modules.Logger
    self._configLoader = self._modules.ConfigLoader

    local ok, petsConfig = pcall(function()
        return self._configLoader:LoadConfig("pets")
    end)
    if
        ok
        and type(petsConfig.serials) == "table"
        and type(petsConfig.serials.store_name) == "string"
    then
        self._storeName = petsConfig.serials.store_name
    end

    -- GetDataStore THROWS when API access is unavailable (unpublished place / AutoRecovery copy /
    -- Studio API access off). That must never kill the boot loader — DataService already degrades to
    -- mock data in this state, and NextSerial pcalls + falls back to in-memory counters in Studio.
    local storeOk, storeOrErr = pcall(function()
        return DataStoreService:GetDataStore(self._storeName)
    end)
    self._store = storeOk and storeOrErr or nil
    if storeOk then
        self._logger:Info("PetSerialService initialized", {
            context = "PetSerialService",
            storeName = self._storeName,
        })
    else
        self._logger:Warn("PetSerialService: DataStore unavailable; serials use Studio fallback", {
            context = "PetSerialService",
            storeName = self._storeName,
            error = tostring(storeOrErr),
        })
    end
end

function PetSerialService:_serialKey(serialType, petType, variant)
    serialType = tostring(serialType or "huge"):lower()
    petType = tostring(petType or "unknown"):lower()
    variant = tostring(variant or "basic"):lower()
    return table.concat({ serialType, petType, variant }, ":")
end

function PetSerialService:NextSerial(serialType, petType, variant)
    local key = self:_serialKey(serialType, petType, variant)
    local success, result = pcall(function()
        return self._store:UpdateAsync(key, function(current)
            current = tonumber(current) or 0
            return current + 1
        end)
    end)

    if success and tonumber(result) then
        return tonumber(result),
            {
                key = key,
                source = "datastore",
                store = self._storeName,
            }
    end

    if RunService:IsStudio() then
        self._memoryCounters[key] = (self._memoryCounters[key] or 0) + 1
        self._logger:Warn("Pet serial DataStore allocation failed; using Studio-only fallback", {
            context = "PetSerialService",
            key = key,
            error = tostring(result),
            fallbackSerial = self._memoryCounters[key],
        })
        return self._memoryCounters[key],
            {
                key = key,
                source = "studio_fallback",
                store = self._storeName,
                error = tostring(result),
            }
    end

    return nil,
        {
            key = key,
            source = "failed",
            store = self._storeName,
            error = tostring(result),
        }
end

function PetSerialService:NextHugeSerial(petType, variant)
    return self:NextSerial("huge", petType, variant)
end

-- PEEK a serial counter WITHOUT minting (Jason: "can we peek to see if there is any in
-- existence without triggering the counter?"). GetAsync reads the count and never
-- increments; the counter is EVER-MINTED (deleted huges stay counted), which is exactly
-- the index semantics — "has one ever existed in the realm". 0 = never minted (or the
-- store is unreachable — callers treat unknown as not-yet-discovered, never the reverse).
function PetSerialService:PeekSerial(serialType, petType, variant)
    local key = self:_serialKey(serialType, petType, variant)
    if self._store then
        local ok, value = pcall(function()
            return self._store:GetAsync(key)
        end)
        if ok and tonumber(value) then
            return tonumber(value), key
        end
    end
    -- Studio fallback mirrors NextSerial's memory counters (so census tests work offline)
    return self._memoryCounters[key] or 0, key
end

return PetSerialService
