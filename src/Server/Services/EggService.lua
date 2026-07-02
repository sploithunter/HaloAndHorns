--[[
    EggService - Following working game pattern
    
    Simple egg purchase handling using RemoteFunction like the working game.
    Matches their EggHandler pattern exactly.
--]]

local EggService = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Dependencies
local Locations = require(ReplicatedStorage.Shared.Locations)
local petConfig = Locations.getConfig("pets")
local eggSystemConfig = Locations.getConfig("egg_system")

-- "Secret and above" = the UNIQUE rarities (Storage-v2 SSOT: inventory.buckets.pets.special_rarities
-- = secret/exclusive/huge/creator; mythic is stackable, NOT counted). Hatching one fires the
-- fireworks celebration (egg_hatch_secret game event).
local SECRET_RARITIES = {}
do
    local invCfg = Locations.getConfig("inventory")
    local list = invCfg
        and invCfg.buckets
        and invCfg.buckets.pets
        and invCfg.buckets.pets.special_rarities
    for _, r in ipairs(list or {}) do
        SECRET_RARITIES[r] = true
    end
end
-- A huge pet's EFFECTIVE rarity is the HUGE tier, not its species rarity — so the reveal box, the
-- rarity label, and the celebration all treat it as "huge" (huge ∈ special_rarities). Without this
-- a huge Lightleaf Hare reveals as its species (uncommon → green box, no fireworks). Creator (the
-- apex) also resolves to "huge" for celebration purposes. Non-huge pets keep their species rarity.
-- (Titanic/colossal will slot in here via a huge_class field once such pets exist.)
local function effectiveRarityIds(hatchResult)
    local rid
    if hatchResult and (hatchResult.huge == true or hatchResult.creator == true) then
        rid = "huge"
    elseif hatchResult and hatchResult.petData then
        rid = hatchResult.petData.rarity_id
    end
    local rname = rid
    local rdef = petConfig and petConfig.rarities and rid and petConfig.rarities[rid]
    if rdef and rdef.name then
        rname = rdef.name
    end
    return rid, rname
end
local EggWorldQuery = require(ReplicatedStorage.Shared.Services.EggWorldQuery)
local fireGameEvent = require(ReplicatedStorage.Shared.Network.FireGameEvent)
local PetInventoryView = require(ReplicatedStorage.Shared.Inventory.PetInventoryView)
local OpsAlert = require(script.Parent.Parent.OpsAlert)
local HatchTiming = require(ReplicatedStorage.Shared.Game.HatchTiming)
local HttpService = game:GetService("HttpService")
-- Area config for the zone-unlock hatch gate: a gated area's egg stand can only be hatched once the
-- AREA is unlocked (same gate as its crystals). Mirrors ZoneService/ZoneUnlockPrompt membership.
local areasConfig = require(ReplicatedStorage:WaitForChild("Configs"):WaitForChild("areas"))

-- Egg-hatch animation timing (not registered in Locations.ConfigFiles; require directly like
-- the client does). Used to size the post-success cooldown so it tracks the client animation.
local eggHatchingConfig
do
    local ok, cfg = pcall(function()
        return require(ReplicatedStorage.Configs.egg_hatching)
    end)
    if ok then
        eggHatchingConfig = cfg
    end
end

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

-- Per-player hatch state. The post-success cooldown is enforced via playerHatchLocks
-- (AcquireHatchLock / ReleaseHatchLock); the older tick()-based IsOnCooldown was superseded
-- and removed.
local playerHatchLocks = {}
local playerHatchHistory = {}
local hatchHistorySequence = 0

-- RemoteFunction for egg purchases
local eggRemoteFunction = nil

-- Player current egg tracking (for persistence)
local playerCurrentEggs = {}

-- === HELPER FUNCTIONS ===

function EggService:GetHatchingConfig()
    return eggSystemConfig.hatching or {}
end

function EggService:GetMaxHatchCount()
    local hatching = self:GetHatchingConfig()
    return math.clamp(math.floor(tonumber(hatching.max_count) or 99), 1, 99)
end

function EggService:GetDebugConfig()
    local hatching = self:GetHatchingConfig()
    return hatching.debug or {}
end

function EggService:GetUnlockCounterValue(player, counterId)
    if counterId == "pets_hatched" then
        counterId = "eggs_hatched"
    end

    if self._statsService and self._statsService.Get then
        local ok, value = pcall(function()
            return self._statsService:Get(player, counterId)
        end)
        if ok then
            return tonumber(value) or 0
        end
    end

    if self._dataService and self._dataService.GetCounter then
        return tonumber(self._dataService:GetCounter(player, counterId)) or 0
    end

    return tonumber(player:GetAttribute(counterId)) or 0
end

function EggService:GetEggUnlockStatus(player, eggType, eggData)
    eggData = eggData or (petConfig.egg_sources and petConfig.egg_sources[eggType])
    local requirement = eggData and eggData.unlock_requirement
    if requirement == nil then
        return true, nil
    end

    if type(requirement) ~= "table" then
        return false,
            {
                type = "invalid",
                current = 0,
                required = 1,
                message = "Invalid egg unlock requirement",
            }
    end

    local requirementType = tostring(requirement.type or "")
    local requiredAmount = math.max(0, tonumber(requirement.amount) or 0)
    if requirementType == "" or requiredAmount <= 0 then
        return true,
            {
                type = requirementType,
                current = 0,
                required = requiredAmount,
            }
    end

    local counterId = requirement.counter or requirement.stat or requirementType
    local currentAmount = self:GetUnlockCounterValue(player, counterId)
    local unlocked = currentAmount >= requiredAmount

    return unlocked,
        {
            type = requirementType,
            counter = counterId,
            current = currentAmount,
            required = requiredAmount,
        }
end

function EggService:GetHatchHistoryLimit()
    local debugConfig = self:GetDebugConfig()
    return math.clamp(math.floor(tonumber(debugConfig.history_limit) or 12), 1, 50)
end

function EggService:GetHatchHistoryResultSampleLimit()
    local debugConfig = self:GetDebugConfig()
    return math.clamp(math.floor(tonumber(debugConfig.result_sample_limit) or 20), 1, 99)
end

function EggService:CloneHatchOptions(options)
    options = type(options) == "table" and options or {}
    return {
        showHatch = options.showHatch ~= false,
        goldenMode = options.goldenMode == true,
        chargedMode = options.chargedMode == true,
        fastHatch = options.fastHatch == true,
        skipHatch = options.skipHatch == true,
        silentHatch = options.silentHatch == true,
        costMultiplier = tonumber(options.costMultiplier) or nil,
    }
end

function EggService:CloneHatchEntitlements(entitlements)
    entitlements = type(entitlements) == "table" and entitlements or {}
    return {
        maxHatchCount = entitlements.maxHatchCount,
        autoHatch = entitlements.autoHatch == true,
        fastHatch = entitlements.fastHatch == true,
        skipHatch = entitlements.skipHatch == true,
        goldenMode = entitlements.goldenMode == true,
        chargedMode = entitlements.chargedMode == true,
        luckBonus = tonumber(entitlements.luckBonus) or 0,
        secretLuckBonus = tonumber(entitlements.secretLuckBonus) or 0,
    }
end

function EggService:SummarizeHatchResults(resultEntries)
    local summary = {}
    local autoDeletedCount = 0
    local specialCount = 0
    -- Per-TIER unique counts drive the tiered celebration (Jason: a huge should out-party a secret).
    -- RarityId here is already the EFFECTIVE rarity (a huge reads "huge", not its species).
    local secretCount = 0 -- SECRET tier → secret fireworks (kept, "it's fun")
    local exclusiveCount = 0 -- EXCLUSIVE tier → a bigger cyan burst
    local hugeCount = 0 -- HUGE tier (huge + creator apex) → the grandest fireworks + huge sound
    local sampleLimit = self:GetHatchHistoryResultSampleLimit()

    for index, entry in ipairs(resultEntries or {}) do
        if entry.AutoDeleted == true or entry.autoDeleted == true then
            autoDeletedCount += 1
        end
        if entry.SpecialHatch == true or entry.specialHatch == true then
            specialCount += 1
        end
        local rid = entry.RarityId or entry.rarityId
        if rid == "huge" or rid == "creator" then
            hugeCount += 1
        elseif rid == "exclusive" then
            exclusiveCount += 1
        elseif type(rid) == "string" and SECRET_RARITIES[rid] then
            secretCount += 1 -- remaining unique tier = secret
        end
        if index <= sampleLimit then
            table.insert(summary, {
                pet = entry.Pet or entry.pet,
                variant = entry.Type or entry.variant,
                rarityId = entry.RarityId or entry.rarityId,
                specialHatch = entry.SpecialHatch == true or entry.specialHatch == true,
                autoDeleted = entry.AutoDeleted == true or entry.autoDeleted == true,
                autoDeleteReason = entry.AutoDeleteReason or entry.autoDeleteReason,
                uid = entry.uid,
            })
        end
    end

    return summary, autoDeletedCount, specialCount, secretCount, exclusiveCount, hugeCount
end

function EggService:RecordHatchHistory(player, entry)
    if not player then
        return nil
    end

    hatchHistorySequence += 1
    local userId = player.UserId
    local history = playerHatchHistory[userId]
    if not history then
        history = {}
        playerHatchHistory[userId] = history
    end

    entry = type(entry) == "table" and entry or {}
    entry.id = hatchHistorySequence
    entry.createdAt = os.time()
    entry.createdClock = os.clock()
    entry.playerName = player.Name
    entry.playerUserId = userId

    table.insert(history, 1, entry)
    local limit = self:GetHatchHistoryLimit()
    while #history > limit do
        table.remove(history)
    end

    return entry
end

function EggService:RecordHatchError(player, request, message, code, details)
    return self:RecordHatchHistory(player, {
        ok = false,
        success = false,
        code = code or "error",
        message = message,
        details = details or {},
        eggType = request and request.eggType or nil,
        purchaseType = request and request.purchaseType or nil,
        requestedCount = request and request.requestedCount or nil,
        autoSessionId = request and request.autoSessionId or nil,
        resultCount = 0,
        hatchCount = 0,
        totalCost = 0,
    })
end

function EggService:ReturnHatchError(player, request, message, code, details)
    self:RecordHatchError(player, request, message, code, details)
    return self:FormatError(request, message, code, details)
end

function EggService:RecordHatchSuccess(player, request, response)
    local results, autoDeletedCount, specialCount, secretCount, exclusiveCount, hugeCount =
        self:SummarizeHatchResults(response.results)
    fireGameEvent(player, "egg_hatch", { count = response.hatchCount }) -- reactions config-optional
    -- XP per egg (configs/egg_system.lua xp_per_hatch; Jason: 1/egg) — per batch
    local xpPer = tonumber(eggSystemConfig and eggSystemConfig.xp_per_hatch) or 0
    local count = tonumber(response.hatchCount) or 0
    if xpPer > 0 and count > 0 then
        pcall(function()
            _G.RBXTemplateServices
                :Get("PlayerProgressionService")
                :AddExperience(player, xpPer * count)
        end)
    end
    if specialCount > 0 then
        -- ONE rare-hatch celebration per batch (not per pet) — golden/rainbow/special reveals.
        fireGameEvent(player, "egg_hatch_rare", { count = specialCount })
    end
    -- TIERED unique-hatch celebration (Jason: a huge should out-party a secret). Each tier fires
    -- once per batch with its own fireworks + sound; a mixed batch can fire more than one.
    if secretCount > 0 then
        fireGameEvent(player, "egg_hatch_secret", { count = secretCount })
    end
    if exclusiveCount > 0 then
        fireGameEvent(player, "egg_hatch_exclusive", { count = exclusiveCount })
    end
    if hugeCount > 0 then
        -- The apex: grandest fireworks + the dedicated huge_fireworks sound. Once per batch.
        fireGameEvent(player, "egg_hatch_huge", { count = hugeCount })
    end
    return self:RecordHatchHistory(player, {
        ok = true,
        success = true,
        eggType = response.EggType,
        purchaseType = request and request.purchaseType or nil,
        requestedCount = response.requestedCount,
        hatchCount = response.hatchCount,
        stopReason = response.stopReason,
        currency = response.Currency,
        costEach = response.Cost,
        totalCost = response.TotalCost,
        autoSessionId = response.autoSessionId,
        options = self:CloneHatchOptions(response.options),
        entitlements = self:CloneHatchEntitlements(response.entitlements),
        resultCount = response.hatchCount,
        resultSampleLimit = self:GetHatchHistoryResultSampleLimit(),
        results = results,
        autoDeletedCount = autoDeletedCount,
        specialHatchCount = specialCount,
        animation = {
            eggType = response.animation and response.animation.eggType or nil,
            useAuthoredEggVisual = response.animation
                    and response.animation.useAuthoredEggVisual == true
                or false,
            modelName = response.animation and response.animation.modelName or nil,
            anchorName = response.animation and response.animation.anchorName or nil,
            specialReveal = response.animation and response.animation.specialReveal == true
                or false,
            specialRevealCount = response.animation and response.animation.specialRevealCount or 0,
        },
    })
end

function EggService:GetHatchHistory(player, limit)
    if not player then
        return {}
    end

    local history = playerHatchHistory[player.UserId] or {}
    local count =
        math.clamp(math.floor(tonumber(limit) or #history), 0, self:GetHatchHistoryLimit())
    local result = {}
    for index = 1, math.min(count, #history) do
        table.insert(result, history[index])
    end
    return result
end

function EggService:ClearHatchHistory(player)
    if player then
        playerHatchHistory[player.UserId] = {}
    end
end

function EggService:AddSimulationCount(bucket, key, amount)
    key = tostring(key or "")
    if key == "" then
        key = "unknown"
    end
    bucket[key] = (bucket[key] or 0) + (amount or 1)
end

function EggService:SimulateHatchBatch(player, rawRequest)
    rawRequest = type(rawRequest) == "table" and rawRequest or {}
    local request = self:NormalizeHatchRequest({
        eggType = rawRequest.eggType or rawRequest.eggId or "basic_egg",
        requestedCount = rawRequest.requestedCount or rawRequest.count or rawRequest.quantity or 1,
        purchaseType = rawRequest.purchaseType or "Simulation",
        options = rawRequest.options or {},
        legacy = false,
    })

    local eggData = petConfig.egg_sources[request.eggType]
    if not eggData then
        return self:FormatError(request, "Invalid egg type", "invalid_egg")
    end
    local unlocked, unlockDetails = self:GetEggUnlockStatus(player, request.eggType, eggData)
    if not unlocked then
        return self:FormatError(request, "Egg locked", "egg_locked", unlockDetails)
    end

    local entitlements = self:ResolveHatchEntitlements(player)
    local hatchOptions, optionMessage, optionCode, optionDetails =
        self:ResolveHatchOptions(player, request, entitlements)
    if not hatchOptions then
        return self:FormatError(
            request,
            optionMessage or "Hatch mode locked",
            optionCode or "feature_locked",
            optionDetails
        )
    end

    local eggCost = (petConfig.getEggCost and petConfig.getEggCost(request.eggType)) or eggData.cost
    eggCost = math.max(0, tonumber(eggCost) or 0)
    eggCost = math.floor((eggCost * (hatchOptions.costMultiplier or 1)) + 0.5)

    local hatchCount = math.min(request.requestedCount, entitlements.maxHatchCount)
    local playerData = self:BuildPlayerHatchData(player, request.eggType, eggData, hatchOptions)
    playerData.hatchOptions = hatchOptions

    local results = {}
    local counts = {
        pets = {},
        variants = {},
        rarities = {},
        autoDeleteReasons = {},
    }
    local autoDeletedCount = 0
    local specialHatchCount = 0
    for _ = 1, hatchCount do
        local hatchResult = self:GetForcedHatchOutcome(player, request.eggType)
            or petConfig.simulateHatch(request.eggType, playerData)
        if not hatchResult then
            return self:FormatError(request, "Hatching failed", "hatch_failed")
        end

        local autoDeleted = false
        local autoDeleteReason = nil
        if self._autoTargetService and self._autoTargetService.ShouldAutoDeleteHatch then
            autoDeleted, autoDeleteReason =
                self._autoTargetService:ShouldAutoDeleteHatch(player, hatchResult)
        end
        if autoDeleted then
            autoDeletedCount += 1
            self:AddSimulationCount(counts.autoDeleteReasons, autoDeleteReason or "matched", 1)
        end

        -- EFFECTIVE rarity: a huge resolves to the "huge" tier (not its species) so the reveal +
        -- celebration treat it correctly. Non-huge keeps its species rarity.
        local rarityId, rarityName = effectiveRarityIds(hatchResult)
        local specialHatch = self:IsSpecialRevealOutcome(hatchResult)
        if specialHatch then
            specialHatchCount += 1
        end

        self:AddSimulationCount(counts.pets, hatchResult.pet, 1)
        self:AddSimulationCount(counts.variants, hatchResult.variant or "basic", 1)
        self:AddSimulationCount(counts.rarities, rarityId or "unknown", 1)

        table.insert(results, {
            Pet = hatchResult.pet,
            Type = hatchResult.variant,
            Power = hatchResult.petData and hatchResult.petData.power or 0,
            RarityId = rarityId,
            RarityName = rarityName,
            SpecialHatch = specialHatch,
            FinalGoldenChance = hatchResult.finalGoldenChance,
            FinalRainbowChance = hatchResult.finalRainbowChance,
            LuckMultiplier = hatchResult.luckMultiplier,
            EggType = request.eggType,
            Cost = eggCost,
            AutoDeleted = autoDeleted,
            AutoDeleteReason = autoDeleteReason,
            pet = hatchResult.pet,
            variant = hatchResult.variant,
            power = hatchResult.petData and hatchResult.petData.power or 0,
            rarityId = rarityId,
            rarityName = rarityName,
            specialHatch = specialHatch,
            autoDeleted = autoDeleted,
            autoDeleteReason = autoDeleteReason,
        })
    end

    local animationPayload = self:GetEggAnimationPayload(request.eggType, eggData)
    animationPayload.specialReveal = specialHatchCount > 0
    animationPayload.specialRevealCount = specialHatchCount

    return {
        ok = true,
        success = true,
        simulated = true,
        EggType = request.eggType,
        eggType = request.eggType,
        requestedCount = request.requestedCount,
        hatchCount = hatchCount,
        stopReason = hatchCount < request.requestedCount and "entitlement" or nil,
        Cost = eggCost,
        costEach = eggCost,
        TotalCost = eggCost * hatchCount,
        totalCost = eggCost * hatchCount,
        Currency = eggData.currency,
        currency = eggData.currency,
        options = hatchOptions,
        entitlements = entitlements,
        results = results,
        counts = counts,
        autoDeletedCount = autoDeletedCount,
        specialHatchCount = specialHatchCount,
        animation = animationPayload,
    }
end

function EggService:GetRequestedCountForPurchaseType(purchaseType)
    local hatching = self:GetHatchingConfig()
    local compat = hatching.compat_purchase_types or {}
    local defaultCount = tonumber(hatching.default_requested_count) or 1
    local configured = compat[tostring(purchaseType or "Single")]
    return tonumber(configured) or defaultCount
end

function EggService:NormalizeHatchRequest(rawEggType, purchaseType)
    local isBatchRequest = type(rawEggType) == "table"
    local request = {
        legacy = not isBatchRequest,
        purchaseType = purchaseType or "Single",
        requestedCount = self:GetRequestedCountForPurchaseType(purchaseType),
        options = {},
    }

    if isBatchRequest then
        local payload = rawEggType
        request.legacy = payload.legacy == true
        request.eggType = payload.eggType or payload.eggId or payload.EggType
        request.purchaseType = payload.purchaseType
            or payload.PurchaseType
            or purchaseType
            or "Batch"
        request.requestedCount = payload.requestedCount
            or payload.count
            or payload.Count
            or payload.quantity
            or self:GetRequestedCountForPurchaseType(request.purchaseType)
        request.options = type(payload.options) == "table" and payload.options or {}
        request.autoSessionId = payload.autoSessionId
    else
        request.eggType = rawEggType
    end

    request.eggType = tostring(request.eggType or "")
    request.requestedCount = math.floor(tonumber(request.requestedCount) or 1)
    request.requestedCount = math.clamp(request.requestedCount, 1, self:GetMaxHatchCount())
    return request
end

function EggService:FormatError(request, message, code, details)
    if request and request.legacy then
        return "Error", message
    end

    details = details or {}
    if request and request.autoSessionId ~= nil and details.autoSessionId == nil then
        details.autoSessionId = request.autoSessionId
    end

    return {
        ok = false,
        success = false,
        code = code or "error",
        message = message,
        details = details,
    }
end

function EggService:AcquireHatchLock(player)
    local playerId = player.UserId
    local currentTime = os.clock()
    local existing = playerHatchLocks[playerId]
    if existing and existing.expiresAt and existing.expiresAt > currentTime then
        return false, existing.expiresAt - currentTime
    end

    local hatching = self:GetHatchingConfig()
    local lockSeconds = tonumber(hatching.transaction_lock_seconds) or 0.35
    playerHatchLocks[playerId] = {
        expiresAt = currentTime + math.max(0.05, lockSeconds),
    }
    return true, 0
end

-- Expected client-side animation/lock duration for a hatch, from the shared HatchTiming SSOT.
-- Server-authoritative pacing: the post-success cooldown is held at least this long so an
-- injected client that skips the client-side lock still can't out-pace the animation. Returns 0
-- when the timing config is unavailable or the hatch is skipped (auto/skip-hatch), letting the
-- purchase_cooldown floor apply.
function EggService:ExpectedHatchSeconds(context)
    if type(context) ~= "table" or not eggHatchingConfig then
        return 0
    end
    local count = tonumber(context.count) or 1
    local animation = eggSystemConfig.hatching and eggSystemConfig.hatching.animation
    local fastScale = animation and tonumber(animation.fast_hatch_speed_scale) or nil
    local timing = HatchTiming.resolve(eggHatchingConfig, context.options, {
        fastHatchSpeedScale = fastScale,
    })
    return HatchTiming.expectedSeconds(count, timing)
end

function EggService:ReleaseHatchLock(player, success, context)
    local playerId = player.UserId
    local hatching = self:GetHatchingConfig()
    local holdSeconds
    if success then
        holdSeconds = tonumber(eggSystemConfig.cooldowns.purchase_cooldown) or 0
        -- Never let the cooldown fall below the client's expected animation duration.
        local expected = self:ExpectedHatchSeconds(context)
        if expected and expected > holdSeconds then
            holdSeconds = expected
        end
    else
        holdSeconds = tonumber(hatching.failed_request_lock_seconds) or 0.2
    end

    if holdSeconds <= 0 then
        playerHatchLocks[playerId] = nil
        return
    end

    playerHatchLocks[playerId] = {
        expiresAt = os.clock() + holdSeconds,
    }
end

-- Zone-unlock hatch gate. The player is confirmed at the egg's stand (IsPlayerNearEgg), so their
-- CurrentArea is that stand's zone. If that zone is gated and the player hasn't unlocked it, return
-- the lock info (so hatching is blocked until they buy the unlock via the ZoneUnlockPrompt); nil if
-- the area is free/unlocked. Membership mirrors ZoneService (UnlockedAreasJson SSOT) exactly.
function EggService:GetAreaHatchLock(player)
    local areaId = player:GetAttribute("CurrentArea")
    if not areaId then
        return nil
    end
    local zone = areasConfig and areasConfig.zones and areasConfig.zones[areaId]
    local req = zone and zone.kind == "area" and zone.unlock
    if type(req) ~= "table" or req.unlocked_by_default == true or not req.cost or req.cost <= 0 then
        return nil -- free / starter / non-gated area
    end
    local raw = player:GetAttribute("UnlockedAreasJson")
    if type(raw) == "string" and raw ~= "" then
        local ok, list = pcall(function()
            return HttpService:JSONDecode(raw)
        end)
        if ok and type(list) == "table" then
            for _, id in ipairs(list) do
                if id == areaId then
                    return nil -- already unlocked
                end
            end
        end
    end
    return {
        areaId = areaId,
        displayName = zone.display_name or areaId,
        cost = req.cost,
        currency = req.currency,
    }
end

function EggService:HasEnoughCurrency(player, currency, cost)
    if self._dataService then
        return self._dataService:CanAfford(player, currency, cost),
            self._dataService:GetCurrency(player, currency)
    else
        -- Fallback to attributes if DataService not available
        local currentAmount = player:GetAttribute(currency) or 0
        return currentAmount >= cost, currentAmount
    end
end

function EggService:GetCurrencyBalance(player, currency)
    if self._dataService then
        return self._dataService:GetCurrency(player, currency)
    end
    return player:GetAttribute(currency) or 0
end

function EggService:DeductCurrency(player, currency, cost)
    if self._dataService then
        return self._dataService:RemoveCurrency(player, currency, cost, "egg_hatch")
    else
        -- Fallback to attributes if DataService not available
        local currentAmount = player:GetAttribute(currency) or 0
        if currentAmount >= cost then
            player:SetAttribute(currency, currentAmount - cost)
            return true
        end
        return false
    end
end

function EggService:AddCurrency(player, currency, amount, source)
    if amount <= 0 then
        return true
    end

    if self._dataService then
        return self._dataService:AddCurrency(player, currency, amount, source or "egg_hatch_refund")
    end

    local currentAmount = player:GetAttribute(currency) or 0
    player:SetAttribute(currency, currentAmount + amount)
    return true
end

function EggService:IsPlayerNearEgg(player, eggType)
    if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
        return false
    end

    local playerPosition = player.Character.HumanoidRootPart.Position

    local isNear =
        EggWorldQuery.IsNearEggType(eggType, playerPosition, eggSystemConfig.proximity.max_distance)
    return isNear == true
end

function EggService:ResolveHatchEntitlements(player)
    if self._hatchEntitlementService and self._hatchEntitlementService.Resolve then
        return self._hatchEntitlementService:Resolve(player)
    end

    local hatching = self:GetHatchingConfig()
    local shopStubs = hatching.shop_stubs or {}
    local maxStub = shopStubs.max_hatch_count or {}
    local defaultMax = tonumber(maxStub.default_value)
        or tonumber(hatching.default_max_entitled_count)
        or self:GetMaxHatchCount()
    local attributeMax = tonumber(player:GetAttribute("MaxEggHatchCount"))
    local maxHatchCount = attributeMax or defaultMax
    local function resolveBooleanEntitlement(attributeName, stubConfig)
        local attributeValue = player:GetAttribute(attributeName)
        if attributeValue ~= nil then
            return attributeValue == true
        end
        return stubConfig and stubConfig.owned_by_default == true
    end

    return {
        maxHatchCount = math.clamp(math.floor(maxHatchCount), 1, self:GetMaxHatchCount()),
        autoHatch = resolveBooleanEntitlement("AutoHatchUnlocked", shopStubs.auto_hatch),
        fastHatch = resolveBooleanEntitlement("FastHatchUnlocked", shopStubs.fast_hatch),
        skipHatch = resolveBooleanEntitlement("SkipHatchUnlocked", shopStubs.skip_hatch),
        goldenMode = resolveBooleanEntitlement("GoldenHatchUnlocked", shopStubs.golden_mode),
        chargedMode = resolveBooleanEntitlement("ChargedHatchUnlocked", shopStubs.charged_mode),
        luckBonus = tonumber((shopStubs.luck_bonus or {}).default_multiplier) or 0,
        secretLuckBonus = tonumber((shopStubs.secret_luck_bonus or {}).default_multiplier) or 0,
    }
end

function EggService:ResolveHatchOptions(_player, request, entitlements)
    local options = request.options or {}
    local hatching = self:GetHatchingConfig()
    local shopStubs = hatching.shop_stubs or {}
    local goldenStub = shopStubs.golden_mode or {}
    local chargedStub = shopStubs.charged_mode or {}

    if
        (request.purchaseType == "Auto" or request.autoSessionId ~= nil)
        and entitlements.autoHatch ~= true
    then
        return nil,
            "Auto hatch is locked",
            "feature_locked",
            {
                mode = "autoHatch",
            }
    end

    local resolved = {
        showHatch = options.showHatch ~= false,
        goldenMode = false,
        chargedMode = false,
        fastHatch = options.fastHatch == true and entitlements.fastHatch == true,
        skipHatch = options.skipHatch == true and entitlements.skipHatch == true,
        silentHatch = options.silentHatch == true,
        luckBonus = tonumber(entitlements.luckBonus) or 0,
        secretLuckBonus = tonumber(entitlements.secretLuckBonus) or 0,
        costMultiplier = 1,
    }

    if options.goldenMode == true then
        if entitlements.goldenMode ~= true then
            return nil,
                "Golden hatch mode is locked",
                "feature_locked",
                {
                    mode = "goldenMode",
                }
        end
        resolved.goldenMode = true
        resolved.costMultiplier *= math.max(1, tonumber(goldenStub.cost_multiplier) or 20)
    end

    if options.chargedMode == true then
        if entitlements.chargedMode ~= true then
            return nil,
                "Charged hatch mode is locked",
                "feature_locked",
                {
                    mode = "chargedMode",
                }
        end
        resolved.chargedMode = true
        resolved.costMultiplier *= math.max(1, tonumber(chargedStub.cost_multiplier) or 5)
    end

    return resolved
end

function EggService:BuildPlayerHatchData(player, eggType, eggData, hatchOptions)
    -- Collection-completion luck input (Jason: "not raw count — index"): fraction
    -- of obtainable index entries discovered. Parking on one egg stops paying luck
    -- once its entries are found; collection breadth is the only way up.
    local indexCompletion = 0
    if self._petIndexService and self._petIndexService.GetCompletion then
        local ok, completion = pcall(function()
            return self._petIndexService:GetCompletion(player)
        end)
        if ok and type(completion) == "table" then
            indexCompletion = tonumber(completion.fraction) or 0
        end
    end

    local playerData = {
        level = player:GetAttribute("Level") or 1,
        indexCompletion = indexCompletion,
        hasLuckGamepass = false,
        hasGoldenGamepass = false,
        hasRainbowGamepass = false,
        isVIP = false,
    }

    if self._eventService then
        playerData.luckBoost = self._eventService:GetModifier("egg_luck", 0)
    end

    if self._modifierService and self._modifierService.Resolve then
        local baseLuckBoost = tonumber(playerData.luckBoost) or 0
        local hatchLuck = self._modifierService:Resolve(baseLuckBoost, {
            player = player,
            kind = "hatch_luck",
            eggType = eggType,
            currency = eggData.currency,
            source = "EggService",
        })
        local secretLuck = self._modifierService:Resolve(0, {
            player = player,
            kind = "secret_hatch_luck",
            eggType = eggType,
            currency = eggData.currency,
            source = "EggService",
        })
        playerData.luckBoost = tonumber(hatchLuck) or baseLuckBoost
        playerData.secretLuckBoost = tonumber(secretLuck) or 0
        -- per-VARIANT luck channels (Jason: staged + dynamic — a "2x rainbow event"
        -- registers a modifier on ONE kind and nothing else moves). Base 1 = neutral.
        for kind, meta in pairs({
            golden_hatch_luck = { field = "goldenLuckBoost", attr = "GoldenLuckBuff" },
            rainbow_hatch_luck = { field = "rainbowLuckBoost", attr = "RainbowLuckBuff" },
        }) do
            local v = self._modifierService:Resolve(1, {
                player = player,
                kind = kind,
                eggType = eggType,
                currency = eggData.currency,
                source = "EggService",
            })
            local mult = tonumber(v) or 1
            -- attribute form (powers/events/admin can set <X>LuckBuff + Until directly,
            -- and the Active Buffs panel reads the same attributes)
            if (player:GetAttribute(meta.attr .. "Until") or 0) > os.time() then
                mult = mult * (tonumber(player:GetAttribute(meta.attr)) or 1)
            end
            playerData[meta.field] = mult
        end
        -- huge luck: a MULTIPLE (1 = one jackpot attempt, 3 = three — Jason's reroll
        -- model). Sources hook in via the modifier kind below (gamepass/power later).
        local hugeLuck = self._modifierService:Resolve(1, {
            player = player,
            kind = "huge_hatch_luck",
            eggType = eggType,
            currency = eggData.currency,
            source = "EggService",
        })
        local hugeMult = tonumber(hugeLuck) or 1
        if (player:GetAttribute("HugeLuckBuffUntil") or 0) > os.time() then
            hugeMult = hugeMult * (tonumber(player:GetAttribute("HugeLuckBuff")) or 1)
        end
        playerData.hugeLuckBoost = hugeMult
    end

    -- Fortune / Huge Fortune (luck axis): the player's active luck POWER adds to the hatch luck
    -- (a fraction, +0.5 = +50%). Stacks additively with event/gamepass luck above. This is what
    -- makes the marquee luck powers actually change your odds.
    if (player:GetAttribute("LuckBuffUntil") or 0) > os.time() then
        playerData.luckBoost = (tonumber(playerData.luckBoost) or 0)
            + (player:GetAttribute("LuckBuff") or 0)
    end
    -- Fortune POTION (luck axis): its own source (LuckBuffPotion), so it ADDS to the luck power
    -- instead of clobbering it. Raw fraction, same convention as LuckBuff above.
    if (player:GetAttribute("LuckBuffPotionUntil") or 0) > os.time() then
        playerData.luckBoost = (tonumber(playerData.luckBoost) or 0)
            + (player:GetAttribute("LuckBuffPotion") or 0)
    end

    -- Bunny support aura (lucky rabbit): HatchLuckBuff is a multiplier attribute
    -- (1.25 = +0.25); contributes its fraction while the buffer is deployed.
    if (player:GetAttribute("HatchLuckBuffUntil") or 0) > os.time() then
        local auraMult = tonumber(player:GetAttribute("HatchLuckBuff")) or 1
        playerData.luckBoost = (tonumber(playerData.luckBoost) or 0) + math.max(0, auraMult - 1)
    end

    -- LUCKY SERVER (configs/creators.lua server_luck): a registered creator is in the server, so
    -- everyone EXCEPT creators hatches luckier (MeetCreatorService stamps ServerLuckBuff). DEVLUCK is
    -- MULTIPLICATIVE (Jason): instead of folding into the additive luck, pass the multiplier through
    -- as playerData.devLuck — simulateHatch rolls the whole hatch that many times (fractional: 2.5 =
    -- 2 rolls + a 50% chance of a 3rd) and keeps the rarest.
    if (player:GetAttribute("ServerLuckBuffUntil") or 0) > os.time() then
        playerData.devLuck = tonumber(player:GetAttribute("ServerLuckBuff")) or 1
    end

    -- FIRST EGG EVER: arm the one-roll mega-luck (configs/egg_system.lua
    -- first_hatch_luck_multiplier; simulateHatch consumes it on the batch's first roll)
    local firstLuck = tonumber(eggSystemConfig and eggSystemConfig.first_hatch_luck_multiplier) or 1
    if firstLuck > 1 then
        local hatchedEver = 0
        pcall(function()
            hatchedEver = self._dataService:GetCounter(player, "eggs_hatched") or 0
        end)
        if hatchedEver == 0 then
            playerData.firstHatchLuck = firstLuck
        end
    end

    -- Recall power: stamp where the player is hatching, so Recall (default target = last hatched
    -- egg) brings an AFK farmer back here after a server reboot.
    local recallChar = player.Character
    local recallHrp = recallChar and recallChar:FindFirstChild("HumanoidRootPart")
    if recallHrp then
        player:SetAttribute("RecallPoint", recallHrp.Position)
    end

    hatchOptions = type(hatchOptions) == "table" and hatchOptions or {}
    if hatchOptions.chargedMode == true then
        local hatching = self:GetHatchingConfig()
        local chargedStub = hatching.shop_stubs and hatching.shop_stubs.charged_mode or {}
        playerData.luckBoost = (tonumber(playerData.luckBoost) or 0)
            + (tonumber(chargedStub.luck_bonus) or 0)
        playerData.secretLuckBoost = (tonumber(playerData.secretLuckBoost) or 0)
            + (tonumber(chargedStub.secret_luck_bonus) or 0)
    end
    playerData.luckBoost = (tonumber(playerData.luckBoost) or 0)
        + (tonumber(hatchOptions.luckBonus) or 0)
    playerData.secretLuckBoost = (tonumber(playerData.secretLuckBoost) or 0)
        + (tonumber(hatchOptions.secretLuckBonus) or 0)

    -- EVENT secret luck (e.g. "Secret Luck Day", Fridays): the event modifier is named "secret_luck".
    -- General luck reads its event up front (egg_luck, ~line 840) but secret luck never did, so a
    -- scheduled secret-luck event activated yet never reached the hatch. Fold it in the same way —
    -- additive with enchant/shop secret luck (kind secret_hatch_luck).
    if self._eventService then
        playerData.secretLuckBoost = (tonumber(playerData.secretLuckBoost) or 0)
            + (tonumber(self._eventService:GetModifier("secret_luck", 0)) or 0)
    end

    return playerData
end

function EggService:SetTestHatchOverride(player, forcedPet, forcedVariant)
    petConfig.test_mode = petConfig.test_mode or {}
    if forcedPet or forcedVariant then
        petConfig.test_mode.enabled = true
        petConfig.test_mode.force_pet = forcedPet
        petConfig.test_mode.force_variant = forcedVariant or "basic"
        petConfig.test_mode._force_source_user_id = player and player.UserId or nil
        return
    end

    if
        player
        and petConfig.test_mode._force_source_user_id ~= nil
        and petConfig.test_mode._force_source_user_id ~= player.UserId
    then
        return
    end

    petConfig.test_mode.force_pet = nil
    petConfig.test_mode.force_variant = nil
    petConfig.test_mode._force_source_user_id = nil
    if
        not petConfig.test_mode.super_luck
        and not petConfig.test_mode.pet_weight_overrides
        and not petConfig.test_mode.rarity_overrides
    then
        petConfig.test_mode.enabled = false
    end
end

function EggService:ApplyTestOverrides(player)
    local attrForcePet = player:GetAttribute("ForcePet")
    local attrForceVariant = player:GetAttribute("ForceVariant")
    if attrForcePet or attrForceVariant then
        self:SetTestHatchOverride(player, attrForcePet, attrForceVariant)
        Logger:Info("Hatch override active", {
            player = player.Name,
            force_pet = attrForcePet,
            force_variant = attrForceVariant,
        })
        return
    end

    if not (petConfig.test_mode and petConfig.test_mode.enabled) then
        Logger:Debug("No hatch override attributes set", { player = player.Name })
    end
end

function EggService:GetForcedHatchOutcome(player, eggType)
    local forcedPet = player and player:GetAttribute("ForcePet") or nil
    local forcedVariant = player and player:GetAttribute("ForceVariant") or nil
    if not forcedPet and not forcedVariant then
        return nil
    end

    local eggData = petConfig.egg_sources[eggType]
    if not eggData then
        return nil
    end

    local pet = tostring(forcedPet or next(eggData.pet_weights or {}) or "")
    local variant = tostring(forcedVariant or "basic")
    if pet == "" then
        return nil
    end

    return {
        pet = pet,
        variant = variant,
        huge = player:GetAttribute("ForceHuge") == true, -- test hook for the huge path
        finalGoldenChance = 0,
        finalRainbowChance = 0,
        luckMultiplier = 1,
        petData = petConfig.getPet and petConfig.getPet(pet, variant) or nil,
    }
end

function EggService:IsSpecialPetOutcome(hatchResult)
    if hatchResult.huge == true then
        return true
    end
    if self._inventoryService and self._inventoryService._isSpecialPet then
        return self._inventoryService:_isSpecialPet(hatchResult.pet, hatchResult.variant)
    end

    local petData = hatchResult.petData
        or (petConfig.getPet and petConfig.getPet(hatchResult.pet, hatchResult.variant))
    local rarityId = petData and petData.rarity_id
    return rarityId == "mythic"
        or rarityId == "secret"
        or rarityId == "exclusive"
        or rarityId == "huge"
end

function EggService:IsSpecialRevealOutcome(hatchResult)
    local hatching = self:GetHatchingConfig()
    local animation = hatching.animation or {}
    if animation.special_reveal_enabled == false then
        return false
    end
    if hatchResult.huge == true then
        return true
    end

    local petData = hatchResult.petData
        or (petConfig.getPet and petConfig.getPet(hatchResult.pet, hatchResult.variant))
    local rarityId = petData and petData.rarity_id
    local specialRarities = animation.special_rarities or {}
    return type(rarityId) == "string" and specialRarities[rarityId] == true
end

-- STORAGE V2: only UNIQUE records (secret+) consume slots — stacks are self-bounding
-- (the catalog is their cap), so commons AND mythics never truncate a batch. The
-- special check here is the CAPABILITY one (storage truth, mythic excluded), NOT
-- IsSpecialPetOutcome (which keeps mythic for reveal flair).
function EggService:ResolveStorageLimitedOutcomes(player, outcomes)
    if not self._inventoryService then
        return outcomes, nil
    end

    local bucket = self._inventoryService:GetInventory(player, "pets")
    if not bucket then
        return outcomes, nil
    end

    local totalSlots = tonumber(bucket.total_slots) or 0
    local usedSlots = tonumber(bucket.used_slots) or 0
    local availableSlots = math.max(0, totalSlots - usedSlots)
    local capability = self._inventoryService.GetPetCapability
            and self._inventoryService:GetPetCapability()
        or {}
    local usedNewSlots = 0
    local accepted = {}

    for _, outcome in ipairs(outcomes) do
        local requiresSlot = false
        if not outcome.autoDeleted then
            local hr = outcome.hatchResult or {}
            requiresSlot = PetInventoryView.isSpecial({
                huge = hr.huge == true,
                rarity_id = hr.petData and hr.petData.rarity_id,
            }, capability)
        end

        if requiresSlot and usedNewSlots >= availableSlots then
            -- OPS TELEMETRY (Storage v2 D8): a real player just hit the unique cap —
            -- the evidence ships itself instead of needing an alt-account stakeout.
            OpsAlert.send("storage_truncated", {
                player = player and player.Name or "?",
                used = usedSlots,
                total = totalSlots,
                requested = #outcomes,
                accepted = #accepted,
            })
            return accepted, "storage"
        end

        if requiresSlot then
            usedNewSlots += 1
        end
        table.insert(accepted, outcome)
    end

    return accepted, nil
end

function EggService:GetEggAnimationPayload(eggType, eggData)
    local payload = {
        eggType = eggType,
        eggId = eggType,
        displayName = eggData and eggData.name or eggType,
        useAuthoredEggVisual = true,
    }

    local eggInstance = EggWorldQuery.FindEggByType(eggType)
    if eggInstance then
        payload.worldPath = eggInstance:GetFullName()
        payload.modelName = eggInstance.Name
        local anchor = EggWorldQuery.GetAnchor(eggInstance)
        if anchor then
            payload.anchorName = anchor.Name
        end
    end

    return payload
end

-- === MAIN HANDLER (following working game pattern) ===

function EggService:HandleEggPurchase(player, eggType, purchaseType)
    local request = self:NormalizeHatchRequest(eggType, purchaseType)
    Logger:Info("Egg purchase request", {
        player = player.Name,
        eggType = request.eggType,
        purchaseType = request.purchaseType,
        requestedCount = request.requestedCount,
    })

    local lockAcquired, lockRemaining = self:AcquireHatchLock(player)
    if not lockAcquired then
        Logger:Debug("Player hatch transaction locked", {
            player = player.Name,
            remainingTime = lockRemaining,
        })
        return self:ReturnHatchError(
            player,
            request,
            "Please wait before hatching again",
            "hatch_locked",
            {
                remainingTime = lockRemaining,
            }
        )
    end

    -- Validate egg type
    local eggData = petConfig.egg_sources[request.eggType]
    if not eggData then
        Logger:Warn("Invalid egg type", { player = player.Name, eggType = request.eggType })
        self:ReleaseHatchLock(player, false)
        return self:ReturnHatchError(player, request, "Invalid egg type", "invalid_egg")
    end
    local unlocked, unlockDetails = self:GetEggUnlockStatus(player, request.eggType, eggData)
    if not unlocked then
        Logger:Warn("Player tried to hatch locked egg", {
            player = player.Name,
            eggType = request.eggType,
            requirement = unlockDetails,
        })
        self:ReleaseHatchLock(player, false)
        return self:ReturnHatchError(player, request, "Egg locked", "egg_locked", unlockDetails)
    end
    local eggCost = (petConfig.getEggCost and petConfig.getEggCost(request.eggType)) or eggData.cost
    eggCost = math.max(0, tonumber(eggCost) or 0)

    -- Check distance (server-side validation)
    if not self:IsPlayerNearEgg(player, request.eggType) then
        Logger:Warn("Player too far from egg", { player = player.Name, eggType = request.eggType })
        self:ReleaseHatchLock(player, false)
        return self:ReturnHatchError(player, request, "Too far away", "too_far")
    end

    -- Gated-area lock: you must UNLOCK the area (via the ZoneUnlockPrompt) before you can hatch its
    -- egg — same gate as the area's crystals. The proximity check above guarantees CurrentArea is
    -- this stand's zone.
    local areaLock = self:GetAreaHatchLock(player)
    if areaLock then
        Logger:Warn("Player tried to hatch in a locked area", {
            player = player.Name,
            eggType = request.eggType,
            area = areaLock.areaId,
        })
        self:ReleaseHatchLock(player, false)
        return self:ReturnHatchError(
            player,
            request,
            "Unlock " .. areaLock.displayName .. " first",
            "area_locked",
            areaLock
        )
    end

    local entitlements = self:ResolveHatchEntitlements(player)
    local hatchOptions, optionMessage, optionCode, optionDetails =
        self:ResolveHatchOptions(player, request, entitlements)
    if not hatchOptions then
        self:ReleaseHatchLock(player, false)
        return self:ReturnHatchError(
            player,
            request,
            optionMessage or "Hatch mode locked",
            optionCode or "feature_locked",
            optionDetails
        )
    end
    eggCost = math.floor((eggCost * (hatchOptions.costMultiplier or 1)) + 0.5)

    local hatching = self:GetHatchingConfig()
    local allowPartial = hatching.allow_partial ~= false
    local entitledCount = math.min(request.requestedCount, entitlements.maxHatchCount)
    local currentAmount = self:GetCurrencyBalance(player, eggData.currency)
    local affordableCount = entitledCount
    if eggCost > 0 then
        affordableCount = math.floor(currentAmount / eggCost)
    end

    local preliminaryCount = math.min(entitledCount, affordableCount)

    Logger:Info("🪙 EGG PURCHASE - Currency check", {
        player = player.Name,
        eggType = request.eggType,
        currency = eggData.currency,
        costEach = eggCost,
        current = currentAmount,
        requestedCount = request.requestedCount,
        entitledCount = entitledCount,
        affordableCount = affordableCount,
        dataServiceAvailable = self._dataService ~= nil,
    })

    if preliminaryCount <= 0 then
        Logger:Warn("🚫 INSUFFICIENT CURRENCY", {
            player = player.Name,
            currency = eggData.currency,
            required = eggCost,
            current = currentAmount,
        })
        self:ReleaseHatchLock(player, false)
        return self:ReturnHatchError(
            player,
            request,
            "Insufficient " .. eggData.currency,
            "insufficient_currency",
            {
                current = currentAmount,
                costEach = eggCost,
            }
        )
    end

    if preliminaryCount < request.requestedCount and not allowPartial then
        self:ReleaseHatchLock(player, false)
        return self:ReturnHatchError(
            player,
            request,
            "Cannot hatch requested amount",
            "partial_not_allowed",
            {
                requestedCount = request.requestedCount,
                availableCount = preliminaryCount,
            }
        )
    end

    local playerData = self:BuildPlayerHatchData(player, request.eggType, eggData, hatchOptions)
    playerData.hatchOptions = hatchOptions
    self:ApplyTestOverrides(player)

    local outcomes = {}
    for _ = 1, preliminaryCount do
        local hatchResult = self:GetForcedHatchOutcome(player, request.eggType)
            or petConfig.simulateHatch(request.eggType, playerData)
        if not hatchResult then
            Logger:Error("Hatching failed", { player = player.Name, eggType = request.eggType })
            self:ReleaseHatchLock(player, false)
            return self:ReturnHatchError(player, request, "Hatching failed", "hatch_failed")
        end

        local autoDeleted = false
        local autoDeleteReason = nil
        if self._autoTargetService and self._autoTargetService.ShouldAutoDeleteHatch then
            autoDeleted, autoDeleteReason =
                self._autoTargetService:ShouldAutoDeleteHatch(player, hatchResult)
        end

        table.insert(outcomes, {
            hatchResult = hatchResult,
            autoDeleted = autoDeleted,
            autoDeleteReason = autoDeleteReason,
        })
    end

    local storageLimitedOutcomes, storageStop = self:ResolveStorageLimitedOutcomes(player, outcomes)
    if #storageLimitedOutcomes <= 0 then
        self:ReleaseHatchLock(player, false)
        return self:ReturnHatchError(player, request, "No pet storage available", "no_storage")
    end
    if #storageLimitedOutcomes < #outcomes and not allowPartial then
        self:ReleaseHatchLock(player, false)
        return self:ReturnHatchError(player, request, "No pet storage available", "no_storage")
    end
    outcomes = storageLimitedOutcomes

    local totalCost = eggCost * #outcomes
    local deductSuccess = self:DeductCurrency(player, eggData.currency, totalCost)
    if not deductSuccess then
        Logger:Error("Failed to deduct currency", { player = player.Name })
        self:ReleaseHatchLock(player, false)
        return self:ReturnHatchError(player, request, "Transaction failed", "deduct_failed")
    end

    local resultEntries = {}
    local processedCount = 0
    local grantFailed = nil
    local specialRevealCount = 0
    for _, outcome in ipairs(outcomes) do
        local hatchResult = outcome.hatchResult
        local grantResult = nil

        if outcome.autoDeleted then
            Logger:Info("Hatched pet auto-deleted by player filter", {
                player = player.Name,
                pet = hatchResult.pet,
                variant = hatchResult.variant,
                reason = outcome.autoDeleteReason,
            })
        elseif self._petGrantService then
            grantResult = self._petGrantService:GrantPet(player, {
                petType = hatchResult.pet,
                variant = hatchResult.variant,
                huge = hatchResult.huge == true, -- BuildPetData serials it (NextHugeSerial)
                source = "egg_hatch",
            })
            if grantResult.ok then
                Logger:Info("Pet granted from egg hatch", {
                    player = player.Name,
                    uid = grantResult.uid,
                    pet = hatchResult.pet,
                    variant = hatchResult.variant,
                })
            else
                grantFailed = grantResult.error or "Failed to grant pet"
                Logger:Error("Failed to grant hatched pet", {
                    player = player.Name,
                    pet = hatchResult.pet,
                    variant = hatchResult.variant,
                    error = grantFailed,
                })
                break
            end
        else
            Logger:Warn("PetGrantService not available - pet not saved to inventory", {
                player = player.Name,
                pet = hatchResult.pet,
            })
        end

        processedCount += 1
        -- EFFECTIVE rarity: a huge resolves to the "huge" tier (not its species) so the reveal box
        -- is pink + labeled HUGE and the celebration fires the huge tier. Non-huge keeps its species.
        local rarityId, rarityName = effectiveRarityIds(hatchResult)
        local specialHatch = self:IsSpecialRevealOutcome(hatchResult)
        if specialHatch then
            specialRevealCount += 1
        end
        table.insert(resultEntries, {
            Pet = hatchResult.pet,
            PetNum = hatchResult.pet,
            Type = hatchResult.variant,
            Power = hatchResult.petData and hatchResult.petData.power or 0,
            RarityId = rarityId,
            RarityName = rarityName,
            SpecialHatch = specialHatch,
            FinalGoldenChance = hatchResult.finalGoldenChance,
            FinalRainbowChance = hatchResult.finalRainbowChance,
            LuckMultiplier = hatchResult.luckMultiplier,
            EggType = request.eggType,
            Cost = eggCost,
            AutoDeleted = outcome.autoDeleted,
            AutoDeleteReason = outcome.autoDeleteReason,
            uid = grantResult and grantResult.uid or nil,
            pet = hatchResult.pet,
            variant = hatchResult.variant,
            power = hatchResult.petData and hatchResult.petData.power or 0,
            rarityId = rarityId,
            rarityName = rarityName,
            specialHatch = specialHatch,
            finalGoldenChance = hatchResult.finalGoldenChance,
            finalRainbowChance = hatchResult.finalRainbowChance,
            luckMultiplier = hatchResult.luckMultiplier,
            autoDeleted = outcome.autoDeleted,
            autoDeleteReason = outcome.autoDeleteReason,
        })
    end

    if processedCount < #outcomes then
        local refund = (#outcomes - processedCount) * eggCost
        self:AddCurrency(player, eggData.currency, refund, "egg_hatch_partial_refund")
    end

    if processedCount <= 0 then
        self:AddCurrency(player, eggData.currency, totalCost, "egg_hatch_refund")
        self:ReleaseHatchLock(player, false)
        return self:ReturnHatchError(
            player,
            request,
            grantFailed or "Failed to grant pet",
            "grant_failed"
        )
    end

    if self._statsService then
        pcall(function()
            self._statsService:Increment(player, "eggs_hatched", processedCount)
        end)
    end

    local stopReason = nil
    if processedCount < request.requestedCount then
        if storageStop then
            stopReason = storageStop
        elseif affordableCount < entitledCount then
            stopReason = "currency"
        elseif entitledCount < request.requestedCount then
            stopReason = "entitlement"
        elseif grantFailed then
            stopReason = "grant_failed"
        else
            stopReason = "partial"
        end
    end

    local first = resultEntries[1]
    local animationPayload = self:GetEggAnimationPayload(request.eggType, eggData)
    animationPayload.specialReveal = specialRevealCount > 0
    animationPayload.specialRevealCount = specialRevealCount

    local response = {
        ok = true,
        success = true,
        Pet = first.Pet,
        PetNum = first.PetNum,
        Type = first.Type,
        Power = first.Power,
        EggType = request.eggType,
        Cost = eggCost,
        TotalCost = eggCost * processedCount,
        Currency = eggData.currency,
        AutoDeleted = first.AutoDeleted,
        AutoDeleteReason = first.AutoDeleteReason,
        requestedCount = request.requestedCount,
        hatchCount = processedCount,
        results = resultEntries,
        stopReason = stopReason,
        entitlements = entitlements,
        options = hatchOptions,
        autoSessionId = request.autoSessionId,
        animation = animationPayload,
    }

    Logger:Info("Egg hatch transaction complete", {
        player = player.Name,
        eggType = request.eggType,
        requestedCount = request.requestedCount,
        hatchCount = processedCount,
        stopReason = stopReason,
        totalCost = response.TotalCost,
    })

    self:RecordHatchSuccess(player, request, response)
    self:ReleaseHatchLock(player, true, { count = processedCount, options = hatchOptions })
    return response
end

-- === CURRENT EGG TRACKING (for persistence) ===

function EggService:SetLastEgg(player, eggType)
    local playerId = player.UserId
    playerCurrentEggs[playerId] = eggType

    Logger:Debug("Set last egg for player", {
        player = player.Name,
        eggType = eggType or "nil",
    })

    -- TODO: Save to player data for persistence across sessions
    -- This would integrate with your DataService to save the current egg

    return true
end

function EggService:GetLastEgg(player)
    local playerId = player.UserId
    return playerCurrentEggs[playerId]
end

-- === INITIALIZATION ===

function EggService:Initialize(moduleLoader)
    Logger:Info("EggService initializing...")

    -- Get services from the module loader
    if moduleLoader then
        self._inventoryService = moduleLoader:Get("InventoryService")
        self._dataService = moduleLoader:Get("DataService")
        self._eventService = moduleLoader:Get("EventService")
        self._statsService = moduleLoader:Get("StatsService")
        self._petGrantService = moduleLoader:Get("PetGrantService")
        self._modifierService = moduleLoader:Get("ModifierService")
        self._autoTargetService = moduleLoader:Get("AutoTargetService")
        self._hatchEntitlementService = moduleLoader:Get("HatchEntitlementService")
        self._petIndexService = moduleLoader:Get("PetIndexService")

        if self._inventoryService then
            Logger:Info("EggService: InventoryService connection established")
        else
            Logger:Warn("EggService: InventoryService not available in module loader")
        end

        if self._dataService then
            Logger:Info("EggService: DataService connection established")
        else
            Logger:Warn("EggService: DataService not available in module loader")
        end

        if self._eventService then
            Logger:Info("EggService: EventService connection established")
        else
            Logger:Warn("EggService: EventService not available in module loader")
        end

        if self._statsService then
            Logger:Info("EggService: StatsService connection established")
        else
            Logger:Warn("EggService: StatsService not available in module loader")
        end

        if self._petGrantService then
            Logger:Info("EggService: PetGrantService connection established")
        else
            Logger:Warn("EggService: PetGrantService not available in module loader")
        end

        if self._modifierService then
            Logger:Info("EggService: ModifierService connection established")
        else
            Logger:Warn("EggService: ModifierService not available in module loader")
        end

        if self._autoTargetService then
            Logger:Info("EggService: AutoTargetService connection established")
        else
            Logger:Warn("EggService: AutoTargetService not available in module loader")
        end

        if self._hatchEntitlementService then
            Logger:Info("EggService: HatchEntitlementService connection established")
        else
            Logger:Warn("EggService: HatchEntitlementService not available in module loader")
        end
    else
        Logger:Warn("EggService: No module loader provided")
    end

    -- Create RemoteFunction (like working game)
    eggRemoteFunction = Instance.new("RemoteFunction")
    eggRemoteFunction.Name = "EggOpened"
    eggRemoteFunction.Parent = ReplicatedStorage

    -- Create setLastEgg RemoteFunction (like working game)
    local setLastEggRemote = Instance.new("RemoteFunction")
    setLastEggRemote.Name = "setLastEgg"
    setLastEggRemote.Parent = eggRemoteFunction

    -- Set up the handlers
    eggRemoteFunction.OnServerInvoke = function(player, eggType, purchaseType)
        return self:HandleEggPurchase(player, eggType, purchaseType)
    end

    setLastEggRemote.OnServerInvoke = function(player, eggType)
        return self:SetLastEgg(player, eggType)
    end

    -- Clean up when players leave
    Players.PlayerRemoving:Connect(function(player)
        playerHatchLocks[player.UserId] = nil
        playerHatchHistory[player.UserId] = nil
        playerCurrentEggs[player.UserId] = nil
    end)

    Logger:Info("EggService initialized with RemoteFunction and setLastEgg tracking")
end

return EggService
