--[[
    PetSerialService

    Allocates global serial numbers for rare unique pets. Serial allocation must
    happen before the pet is inserted into player inventory so two live servers
    cannot grant the same numbered Huge pet.
]]

local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Retry = require(ReplicatedStorage.Shared.Utils.Retry)

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
    self._serialConfig = {}
    self._studioMemoryOnly = false
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
        self._serialConfig = petsConfig.serials
        self._storeName = petsConfig.serials.store_name
    end

    -- Studio sessions are isolated from the production-wide serial namespace by default. This is
    -- a real operating mode, not an error fallback: it prevents boot-time census reads and test
    -- hatches from consuming budget or mutating live counters when Studio API access is enabled.
    if RunService:IsStudio() and self._serialConfig.live_datastore_in_studio ~= true then
        self._studioMemoryOnly = true
        self._logger:Info("PetSerialService using isolated Studio serial counters", {
            context = "PetSerialService",
            storeName = self._storeName,
        })
        return
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
        self._logger:Warn(
            "PetSerialService DataStore unavailable; global serial allocation disabled",
            {
                context = "PetSerialService",
                storeName = self._storeName,
                error = tostring(storeOrErr),
                studioFallback = RunService:IsStudio(),
            }
        )
    end
end

function PetSerialService:UsesGlobalStore()
    return self._store ~= nil and not self._studioMemoryOnly
end

function PetSerialService:ShouldRunCensus()
    return self:UsesGlobalStore() and self._serialConfig.census_enabled ~= false
end

function PetSerialService:_nextMemorySerial(key)
    self._memoryCounters[key] = (self._memoryCounters[key] or 0) + 1
    return self._memoryCounters[key],
        {
            key = key,
            source = "studio_memory",
            store = self._storeName,
        }
end

function PetSerialService:_serialKey(serialType, petType, variant)
    serialType = tostring(serialType or "huge"):lower()
    petType = tostring(petType or "unknown"):lower()
    variant = tostring(variant or "basic"):lower()
    return table.concat({ serialType, petType, variant }, ":")
end

function PetSerialService:NextSerial(serialType, petType, variant)
    local key = self:_serialKey(serialType, petType, variant)
    if self._studioMemoryOnly then
        return self:_nextMemorySerial(key)
    end
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
        local serial, info = self:_nextMemorySerial(key)
        self._logger:Warn("Pet serial DataStore allocation failed; using Studio-only fallback", {
            context = "PetSerialService",
            key = key,
            error = tostring(result),
            fallbackSerial = serial,
        })
        info.source = "studio_fallback"
        info.error = tostring(result)
        return serial, info
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
-- the index semantics — "has one ever existed in the realm". 0 = confirmed never minted;
-- nil = the global store remained unavailable after bounded retry. Those states must not collapse.
function PetSerialService:PeekSerial(serialType, petType, variant)
    local key = self:_serialKey(serialType, petType, variant)
    if self._studioMemoryOnly then
        return self._memoryCounters[key] or 0, key, { source = "studio_memory", attempts = 0 }
    end
    if self._store then
        local retry = self._serialConfig.read_retry or {}
        local ok, value, attempts = Retry.run(function()
            return pcall(function()
                return self._store:GetAsync(key)
            end)
        end, {
            attempts = retry.attempts or 3,
            backoff_seconds = retry.backoff_seconds or { 0.5, 1.5 },
            wait = task.wait,
        })
        if ok then
            return tonumber(value) or 0, key, { source = "datastore", attempts = attempts }
        end
        return nil,
            key,
            {
                source = "unavailable",
                attempts = attempts,
                error = tostring(value),
            }
    end
    return nil,
        key,
        {
            source = "unavailable",
            attempts = 0,
            error = "serial datastore unavailable",
        }
end

return PetSerialService
