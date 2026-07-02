--[[
    EnchantService

    Rolls and resolves pet enchants. Enchants live on unique pet inventory
    records and contribute to the shared modifier pipeline through the
    "enchants" stage.
]]

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PetInventoryView = require(ReplicatedStorage.Shared.Inventory.PetInventoryView)

local EnchantService = {}
EnchantService.__index = EnchantService

local ENCHANT_PROMPT_NAME = "EnchantStationPrompt"
local DEFAULT_STATION_ID = "basic_enchanter"
local TOUCH_DEBOUNCE_SECONDS = 1.5

local function getPrimaryPartOrSelf(instance)
    if not instance then
        return nil
    end
    if instance:IsA("BasePart") then
        return instance
    end
    if instance:IsA("Model") then
        return instance.PrimaryPart or instance:FindFirstChildWhichIsA("BasePart", true)
    end
    return nil
end

function EnchantService.new()
    local self = setmetatable({}, EnchantService)
    self._logger = nil
    self._configLoader = nil
    self._dataService = nil
    self._inventoryService = nil
    self._modifierService = nil
    self._worldBindingService = nil
    self._petProgressionService = nil
    self._enchantLightning = nil
    self._signals = nil
    self._config = nil
    self._petsConfig = nil
    self._stationAccessByPlayer = {}
    self._stationTouchCounts = {}
    self._stationTouchDebounce = {}
    return self
end

function EnchantService:Init()
    self._logger = self._modules.Logger
    self._configLoader = self._modules.ConfigLoader
    self._dataService = self._modules.DataService
    self._inventoryService = self._modules.InventoryService
    self._modifierService = self._modules.ModifierService
    self._worldBindingService = self._modules.WorldBindingService
    self._petProgressionService = self._modules.PetProgressionService
    self._config = self._configLoader:LoadConfig("enchants")
    self._petsConfig = self._configLoader:LoadConfig("pets")
    self._enchantLightning = require(ReplicatedStorage.Shared.Effects.EnchantLightning)

    if self:IsEnabled() and self._modifierService and self._modifierService.RegisterProvider then
        self._modifierService:RegisterProvider("enchants", function(context)
            return self:_getModifierContributions(context)
        end)
    end

    self._logger:Info("EnchantService initialized", {
        context = "EnchantService",
        enabled = self:IsEnabled(),
    })
end

-- FOREGROUND fold-in (Jason: the Buff HUD needs one honest number per axis): stamp the
-- player's aggregate enchant bonuses as attributes on a slow heartbeat, summed across
-- EQUIPPED pets per modifier kind — the same math the per-break resolution does, made
-- visible. Attribute per surfaced kind; only-on-change writes.
local STAMPED_KINDS = {
    breakable_reward = "EnchantCoinBonus",
    pet_xp = "EnchantPetXpBonus",
    hatch_luck = "EnchantHatchLuck",
    secret_hatch_luck = "EnchantSecretLuck",
    pet_damage = "EnchantPetDamage",
    team_power = "EnchantTeamPower",
    pet_efficiency = "EnchantEfficiency",
}

function EnchantService:_stampAggregates(player)
    local totals = {}
    for _, pet in ipairs(self:_getEquippedUniquePets(player)) do
        for _, enchant in ipairs(pet.data.enchantments or {}) do
            local enchantConfig = self._config.effects and self._config.effects[enchant.id]
            local modifier = enchantConfig and enchantConfig.modifier
            local kind = modifier and modifier.kind
            if kind and STAMPED_KINDS[kind] then
                local strength = tonumber(enchant.strength or enchant.value) or 0
                local typeMult = self:_typeMultiplier(self:_petTierId(pet.data))
                totals[kind] = (totals[kind] or 0)
                    + strength * (tonumber(modifier.amount_per_strength) or 0) * typeMult
            end
        end
    end
    -- STACK ENCHANTS (Storage v2): equipped mythic stacks contribute their effect at
    -- the flat "Mythic Strength" — one contribution per equipped slot referencing the
    -- stack (each equipped copy is a working pet, same as uniques).
    local stackStrength = self:GetStackEnchantStrength()
    for _, s in ipairs(self:_getEquippedEnchantStacks(player)) do
        local enchantConfig = self._config.effects and self._config.effects[s.effect]
        local modifier = enchantConfig and enchantConfig.modifier
        local kind = modifier and modifier.kind
        if kind and STAMPED_KINDS[kind] then
            totals[kind] = (totals[kind] or 0)
                + stackStrength
                    * (tonumber(modifier.amount_per_strength) or 0)
                    * self:_typeMultiplier(s.rarity)
        end
    end
    for kind, attr in pairs(STAMPED_KINDS) do
        local value = totals[kind] or 0
        if (player:GetAttribute(attr) or 0) ~= value then
            player:SetAttribute(attr, value)
        end
        -- `Until` sentinel drives the player-bar badge pile (PlayerPowerBadges shows a
        -- buff only while <Attr>Until > now): far-future while active -> permanent "ON"
        -- badge, 0 when the last enchanted pet is unequipped.
        local untilValue = value > 0 and (os.time() + 86400 * 3650) or 0
        if (player:GetAttribute(attr .. "Until") or 0) ~= untilValue then
            player:SetAttribute(attr .. "Until", untilValue)
        end
    end
end

function EnchantService:Start()
    self._signals = require(game:GetService("ReplicatedStorage").Shared.Network.Signals)
    -- aggregate heartbeat (cheap: equips change rarely; 5s keeps the HUD honest)
    task.spawn(function()
        local Players = game:GetService("Players")
        while true do
            for _, player in ipairs(Players:GetPlayers()) do
                pcall(function()
                    self:_stampAggregates(player)
                end)
            end
            task.wait(5)
        end
    end)
    local fireGameEvent = require(game:GetService("ReplicatedStorage").Shared.Network.FireGameEvent)
    self._signals.EnchantPetRequest.OnServerEvent:Connect(function(player, payload)
        local result = self:RerollPetEnchant(player, payload)
        local revealDelay = result
                and result.ok == true
                and math.max(0, tonumber(result.reveal_delay_seconds) or 0)
            or 0
        if revealDelay > 0 then
            task.delay(revealDelay, function()
                if player and player.Parent then
                    self._signals.EnchantPetResult:FireClient(player, result)
                    if result.ok == true then
                        fireGameEvent(player, "enchant_success", { enchant = result.enchant })
                    end
                end
            end)
        else
            self._signals.EnchantPetResult:FireClient(player, result)
            if result and result.ok == true then
                fireGameEvent(player, "enchant_success", { enchant = result.enchant })
            end
        end
    end)

    self:_connectEnchanterStations()
    Players.PlayerRemoving:Connect(function(player)
        self._stationAccessByPlayer[player] = nil
        self._stationTouchDebounce[player] = nil
    end)
end

function EnchantService:IsEnabled()
    return self._config and self._config.enabled ~= false
end

function EnchantService:_chooseWeighted(entries)
    if type(entries) ~= "table" then
        return nil
    end

    local totalWeight = 0
    for _, entry in ipairs(entries) do
        totalWeight += math.max(0, tonumber(entry.weight) or 0)
    end
    if totalWeight <= 0 then
        return nil
    end

    local roll = math.random() * totalWeight
    local cursor = 0
    for _, entry in ipairs(entries) do
        cursor += math.max(0, tonumber(entry.weight) or 0)
        if roll <= cursor then
            return entry
        end
    end

    return entries[#entries]
end

-- TYPE multiplier (Jason "base * type multiplier — no shift"): a pet's TIER scales every enchant's
-- per-strength base at READ time. Tier = the huge/titanic/colossal size trait if present, else the
-- pet's rarity (mirrors _getMaxEnchantmentsForRarity's huge-first resolution). Never stored on the
-- record, so a traded pet re-resolves on the new owner. Unknown tier -> 1.0 (legendary-equivalent).
function EnchantService:_petTierId(petData)
    if type(petData) ~= "table" then
        return nil
    end
    if petData.huge == true then
        return "huge"
    end
    -- (titanic/colossal size traits resolve here too once those tiers ship)
    return petData.rarity_id or petData.rarity_override
end

function EnchantService:_typeMultiplier(tier)
    local mults = self._config and self._config.type_multipliers
    if type(mults) ~= "table" or type(tier) ~= "string" then
        return 1
    end
    return tonumber(mults[tier]) or 1
end

function EnchantService:_getRollProfileForRarity(rarityId)
    local profileId = self._config.rarity_profiles and self._config.rarity_profiles[rarityId]
    if type(profileId) ~= "string" then
        return nil, nil
    end
    local profile = self._config.roll_profiles and self._config.roll_profiles[profileId]
    if type(profile) ~= "table" then
        return nil, profileId
    end
    return profile, profileId
end

function EnchantService:_rollStrength(strengthConfig)
    strengthConfig = type(strengthConfig) == "table" and strengthConfig or {}
    local low = math.floor(tonumber(strengthConfig.low) or 1)
    local high = math.floor(tonumber(strengthConfig.high) or low)
    local scale = math.max(1, math.floor(tonumber(strengthConfig.scale) or 1))
    if high < low then
        high = low
    end

    local strength = low
    while strength < high and math.random(1, scale) == scale do
        strength += 1
    end
    return strength
end

function EnchantService:_buildEnchant(entry, profileId)
    if type(entry) ~= "table" then
        return nil
    end

    local enchantId = entry.effect
    local enchantConfig = self._config.effects and self._config.effects[enchantId]
    if type(enchantConfig) ~= "table" then
        return nil
    end

    -- Strength rolls from the EFFECT's `roll` ({low,high,scale}, +1..+5, rarity-independent);
    -- entry.strength is the legacy per-profile fallback (profiles no longer carry it).
    return {
        id = enchantId,
        display_name = enchantConfig.display_name or enchantId,
        strength = self:_rollStrength(enchantConfig.roll or entry.strength),
        roll_profile = profileId,
        rolled_at = tick(),
    }
end

-- STACK ENCHANT ROLL (Storage v2 D2-D4): one effect id (or nil) for a STACKABLE
-- rarity, from the SAME per-rarity pool the unique hatch rolls use (the mythical
-- profile: initial_roll_chance gate + weighted effects) — but effect-only. Strength
-- is never rolled or stored: it resolves at read time from the flat config value
-- (enchants.stack_enchants.strength — "Mythic Strength").
function EnchantService:RollStackEnchant(rarityId)
    if not self:IsEnabled() then
        return nil
    end
    local cfg = self._config.stack_enchants
    if not (cfg and cfg.rarities and rarityId and cfg.rarities[rarityId] == true) then
        return nil
    end
    local profile = self:_getRollProfileForRarity(rarityId)
    if not profile then
        return nil
    end
    local rollChance = tonumber(profile.initial_roll_chance) or 1
    if math.random() > rollChance then
        return nil
    end
    local entry = self:_chooseWeighted(profile.chances or {})
    return entry and entry.effect or nil
end

-- The flat strength every STACK enchant resolves at ("Mythic Strength" — one knob,
-- applies live to every mythic enchant in the world).
function EnchantService:GetStackEnchantStrength()
    local cfg = self._config.stack_enchants
    return (cfg and tonumber(cfg.strength)) or 1
end

function EnchantService:RollEnchant(rarityId, excludedEffects)
    if not self:IsEnabled() then
        return nil, "disabled"
    end

    local profile, profileId = self:_getRollProfileForRarity(rarityId)
    if not profile then
        return nil, "missing_roll_profile"
    end

    local entries = profile.chances or {}
    if type(excludedEffects) == "table" and profile.prevent_duplicate_effects ~= false then
        local filtered = {}
        for _, entry in ipairs(entries) do
            if not excludedEffects[entry.effect] then
                table.insert(filtered, entry)
            end
        end
        if #filtered > 0 then
            entries = filtered
        end
    end

    local entry = self:_chooseWeighted(entries)
    if not entry then
        return nil, "empty_roll_profile"
    end

    local enchant = self:_buildEnchant(entry, profileId)
    if not enchant then
        return nil, "invalid_enchant_entry"
    end

    return enchant
end

-- PERMANENT ENCHANTS (Jason): huge trait or creator-category species — fated rolls,
-- no station access, ever.
function EnchantService:IsPermanentEnchantPet(petData)
    local perm = self._config and self._config.permanent
    if type(perm) ~= "table" or type(petData) ~= "table" then
        return false
    end
    if perm.huge == true and petData.huge == true then
        return true
    end
    local cats = perm.categories
    if type(cats) == "table" then
        local cfg = self:_getPetConfigForRecord(petData)
        if cfg and cfg.category and cats[cfg.category] == true then
            return true
        end
    end
    return false
end

-- Auto-roll any newly unlocked, still-empty slots on a PERMANENT pet (called from the
-- pet level-up path — these pets can't visit the station, so the level-up is the
-- reveal). Rolls lock by existing; returns the list of new enchants (or nil).
function EnchantService:FillPermanentSlots(player, petData)
    if not self:IsEnabled() or not self:IsPermanentEnchantPet(petData) then
        return nil
    end
    local unlocked = math.max(0, math.floor(tonumber(petData.unlocked_enchant_slots) or 0))
    petData.enchantments = petData.enchantments or {}
    if #petData.enchantments >= unlocked then
        return nil
    end
    local rarityId = petData.rarity_id
    local excluded = {}
    for _, e in ipairs(petData.enchantments) do
        if e.id then
            excluded[e.id] = true
        end
    end
    local added = {}
    while #petData.enchantments < unlocked do
        local enchant = self:RollEnchant(rarityId, excluded)
        if not enchant then
            break
        end
        if enchant.id then
            excluded[enchant.id] = true
        end
        table.insert(petData.enchantments, enchant)
        table.insert(added, enchant)
    end
    return #added > 0 and added or nil
end

function EnchantService:RollInitialEnchantments(player, petData, petConfig, source)
    if not self:IsEnabled() or type(petData) ~= "table" then
        return petData
    end

    local hatchRolls = self._config.hatch_rolls or {}
    if hatchRolls.enabled ~= true then
        return petData
    end

    local rarityId = petData.rarity_id or (petConfig and petConfig.rarity_id)
    local maxEnchantments = math.max(0, math.floor(tonumber(petData.max_enchantments) or 0))
    local unlockedSlots =
        math.max(0, math.floor(tonumber(petData.unlocked_enchant_slots) or maxEnchantments))
    if maxEnchantments <= 0 then
        return petData
    end
    if hatchRolls.require_unlocked_slot ~= false and unlockedSlots <= 0 then
        return petData
    end

    local profile = self:_getRollProfileForRarity(rarityId)
    if not profile then
        return petData
    end

    local existing = type(petData.enchantments) == "table" and #petData.enchantments or 0
    local availableSlots = math.max(
        0,
        math.min(maxEnchantments, unlockedSlots > 0 and unlockedSlots or maxEnchantments) - existing
    )
    local minRolls = math.max(0, math.floor(tonumber(profile.min_rolls) or 0))
    local maxRolls = math.max(minRolls, math.floor(tonumber(profile.max_rolls) or minRolls))
    local targetRolls = math.random(minRolls, maxRolls)
    local rolls = math.min(availableSlots, targetRolls)
    if rolls <= 0 then
        return petData
    end

    local chance = math.clamp(tonumber(profile.initial_roll_chance) or 0, 0, 1)
    petData.enchantments = petData.enchantments or {}
    local excludedEffects = {}
    for _, existingEnchant in ipairs(petData.enchantments) do
        if type(existingEnchant) == "table" and type(existingEnchant.id) == "string" then
            excludedEffects[existingEnchant.id] = true
        end
    end
    local added = 0
    for _ = 1, rolls do
        if math.random() <= chance then
            local enchant = self:RollEnchant(rarityId, excludedEffects)
            if enchant then
                enchant.source = source or petData.grant_source or "pet_grant"
                table.insert(petData.enchantments, enchant)
                excludedEffects[enchant.id] = true
                added += 1
            end
        end
    end

    if added > 0 and self._logger then
        self._logger:Info("Initial pet enchants rolled", {
            context = "EnchantService",
            player = player and player.Name or nil,
            pet = petData.id,
            variant = petData.variant,
            rarity = rarityId,
            added = added,
        })
    end

    return petData
end

function EnchantService:_petCapability()
    if self._inventoryService and self._inventoryService.GetPetCapability then
        return self._inventoryService:GetPetCapability()
    end
    return {}
end

function EnchantService:_getPetRecord(player, petUid)
    local data = self._dataService and self._dataService:GetData(player)
    local items = data and data.Inventory and data.Inventory.pets and data.Inventory.pets.items
    local petData = items and items[petUid]
    if type(petData) ~= "table" then
        return nil, "pet_not_found"
    end
    if not PetInventoryView.isEnchantable(petData, self:_petCapability()) then
        return nil, "pet_not_enchantable"
    end
    self:_normalizePetEnchantMetadata(petData)
    return petData, nil
end

function EnchantService:_getPetConfigForRecord(petData)
    if type(petData) ~= "table" or not (self._petsConfig and self._petsConfig.getPet) then
        return nil
    end
    return self._petsConfig.getPet(petData.id, petData.variant or "basic")
end

function EnchantService:_getMaxEnchantmentsForRarity(rarityId)
    local enchanting = self._petsConfig and self._petsConfig.enchanting
    if type(rarityId) ~= "string" or type(enchanting) ~= "table" then
        return 0
    end

    local byRarity = enchanting.max_enchantments_by_rarity
    local maxEnchantments = type(byRarity) == "table" and byRarity[rarityId]
    if maxEnchantments == nil then
        maxEnchantments = enchanting.default_max_enchantments
    end
    return math.max(0, math.floor(tonumber(maxEnchantments) or 0))
end

function EnchantService:_normalizePetEnchantMetadata(petData)
    if type(petData) ~= "table" then
        return
    end

    local petConfig = self:_getPetConfigForRecord(petData)
    local rarityId = petData.huge == true and "huge"
        or petData.rarity_id
        or petData.rarity_override
        or (petConfig and petConfig.rarity_id)
    if type(rarityId) == "string" and rarityId ~= "" and petData.rarity_id == nil then
        petData.rarity_id = rarityId
    end

    local maxEnchantments = math.max(0, math.floor(tonumber(petData.max_enchantments) or 0))
    if maxEnchantments <= 0 then
        maxEnchantments = self:_getMaxEnchantmentsForRarity(rarityId)
    end
    if maxEnchantments <= 0 then
        return
    end

    petData.enchantable = true
    petData.max_enchantments = maxEnchantments
    petData.enchantments = type(petData.enchantments) == "table" and petData.enchantments or {}

    if self._petProgressionService and self._petProgressionService.ApplyProgression then
        self._petProgressionService:ApplyProgression(petData, petConfig)
    elseif petData.unlocked_enchant_slots == nil then
        petData.unlocked_enchant_slots = 1
    end
end

function EnchantService:_chargeRerollCost(player)
    local reroll = self._config.reroll or {}
    local cost = reroll.cost or {}
    local amount = math.max(0, math.floor(tonumber(cost.amount) or 0))
    local currency = cost.currency
    if amount <= 0 then
        return true
    end
    if type(currency) ~= "string" or currency == "" then
        return false, "invalid_reroll_cost"
    end
    if not self._dataService:CanAfford(player, currency, amount) then
        return false,
            "insufficient_currency",
            {
                currency = currency,
                cost = amount,
            }
    end
    self._dataService:RemoveCurrency(player, currency, amount, "pet_enchant_reroll")
    return true, nil, {
        currency = currency,
        cost = amount,
    }
end

function EnchantService:_getStationConfig(stationId)
    local stations = self._config and self._config.stations or {}
    local id = type(stationId) == "string" and stationId ~= "" and stationId or DEFAULT_STATION_ID
    return stations[id] or stations[DEFAULT_STATION_ID] or {}, id
end

function EnchantService:_resolveStationTouchPart(station, stationConfig)
    if not station then
        return nil
    end
    if station:IsA("BasePart") then
        return station
    end

    local touchPartName = station:GetAttribute("TouchPartName")
        or stationConfig.touch_part_name
        or "EnchantTouchPart"
    local touchPart = station:FindFirstChild(touchPartName, true)
    if touchPart and touchPart:IsA("BasePart") then
        return touchPart
    end

    return getPrimaryPartOrSelf(station)
end

function EnchantService:_getStationAnimationRoot(station, stationConfig)
    if not station then
        return nil
    end

    local animationRootName = station:GetAttribute("AnimationRootName")
        or (stationConfig.animation and stationConfig.animation.root_name)
    if type(animationRootName) == "string" and animationRootName ~= "" then
        return station:FindFirstChild(animationRootName, true) or station
    end

    return station
end

function EnchantService:_setStationAnimationEnabled(station, stationConfig, enabled)
    local animation = stationConfig.animation or {}
    if animation.enabled == false then
        return
    end

    local root = self:_getStationAnimationRoot(station, stationConfig)
    if not root then
        return
    end

    local scriptName = animation.script_name or "FloatingCoinScript"
    for _, descendant in ipairs(root:GetDescendants()) do
        if descendant:IsA("BaseScript") and descendant.Name == scriptName then
            descendant.Enabled = enabled
        end
    end
end

function EnchantService:_hasStationAccess(player)
    local access = self._stationAccessByPlayer[player]
    return type(access) == "table" and (tonumber(access.expiresAt) or 0) >= os.clock()
end

function EnchantService:_canBypassStationRequirement(payload)
    return RunService:IsStudio()
        and type(payload) == "table"
        and (payload.source == "studio_smoke" or payload.bypassStation == true)
end

function EnchantService:_requireStationAccess(player, payload)
    local reroll = self._config.reroll or {}
    if reroll.requires_station ~= true then
        return true
    end
    if self:_hasStationAccess(player) or self:_canBypassStationRequirement(payload) then
        return true
    end
    return false
end

function EnchantService:_activateStation(player, station, stationId, reason)
    if not player then
        return
    end

    local stationConfig = self:_getStationConfig(stationId)
    local reroll = self._config.reroll or {}
    local graceSeconds = math.max(1, tonumber(reroll.station_grace_seconds) or 12)
    local expiresAt = os.clock() + graceSeconds

    self._stationAccessByPlayer[player] = {
        stationId = stationId,
        station = station,
        expiresAt = expiresAt,
    }
    self:_setStationAnimationEnabled(station, stationConfig, true)

    if not self._signals then
        return
    end

    self._signals.EnchantStationOpened:FireClient(player, {
        stationId = stationId,
        displayName = stationConfig.display_name or "Enchanter",
        reason = reason,
        expiresAt = expiresAt,
        graceSeconds = graceSeconds,
        reroll = reroll,
    })
end

function EnchantService:_ensureStationPrompt(station, touchPart, stationId, stationConfig)
    local promptConfig = stationConfig.prompt or {}
    if promptConfig.enabled == false then
        return
    end

    local prompt = touchPart:FindFirstChild(ENCHANT_PROMPT_NAME)
    if prompt and not prompt:IsA("ProximityPrompt") then
        self._logger:Warn("Enchanter touch part has non-prompt child using reserved name", {
            touchPart = touchPart:GetFullName(),
            childClass = prompt.ClassName,
        })
        return
    end

    if not prompt then
        prompt = Instance.new("ProximityPrompt")
        prompt.Name = ENCHANT_PROMPT_NAME
        prompt.RequiresLineOfSight = false
        prompt.Parent = touchPart
    end

    local keyName = promptConfig.key or "E"
    local keyCode = Enum.KeyCode[keyName] or Enum.KeyCode.E
    prompt.KeyboardKeyCode = keyCode
    prompt.ActionText = promptConfig.action_text or "Enchant Pets"
    prompt.ObjectText = promptConfig.object_text or stationConfig.display_name or "Enchanter"
    prompt.MaxActivationDistance = tonumber(promptConfig.max_distance) or 14
    prompt.HoldDuration = tonumber(promptConfig.hold_duration) or 0
    prompt.Enabled = true
    prompt:SetAttribute("EnchanterId", stationId)

    if not prompt:GetAttribute("EnchantStationPromptConnected") then
        prompt:SetAttribute("EnchantStationPromptConnected", true)
        prompt.Triggered:Connect(function(player)
            self:_activateStation(player, station, stationId, "prompt")
        end)
    end
end

function EnchantService:_connectStationTouch(station, touchPart, stationId, stationConfig)
    touchPart.CanTouch = true
    touchPart:SetAttribute("EnchanterId", stationId)

    if stationConfig.animation and stationConfig.animation.active_when_near == true then
        self:_setStationAnimationEnabled(station, stationConfig, false)
    end

    self:_ensureStationPrompt(station, touchPart, stationId, stationConfig)

    if touchPart:GetAttribute("EnchantStationTouchConnected") then
        return
    end
    touchPart:SetAttribute("EnchantStationTouchConnected", true)

    touchPart.Touched:Connect(function(hit)
        local character = hit and hit.Parent
        local player = character and Players:GetPlayerFromCharacter(character)
        if not player then
            return
        end

        local now = os.clock()
        self._stationTouchDebounce[player] = self._stationTouchDebounce[player] or {}
        local playerDebounce = self._stationTouchDebounce[player]
        if
            playerDebounce[touchPart]
            and now - playerDebounce[touchPart] < TOUCH_DEBOUNCE_SECONDS
        then
            return
        end
        playerDebounce[touchPart] = now

        self._stationTouchCounts[touchPart] = (self._stationTouchCounts[touchPart] or 0) + 1
        self:_activateStation(player, station, stationId, "touch")
    end)

    touchPart.TouchEnded:Connect(function(hit)
        local character = hit and hit.Parent
        local player = character and Players:GetPlayerFromCharacter(character)
        if not player then
            return
        end

        self._stationTouchCounts[touchPart] =
            math.max(0, (self._stationTouchCounts[touchPart] or 1) - 1)
        if stationConfig.animation and stationConfig.animation.active_when_near == true then
            task.delay(0.25, function()
                if (self._stationTouchCounts[touchPart] or 0) <= 0 then
                    self:_setStationAnimationEnabled(station, stationConfig, false)
                end
            end)
        end
    end)
end

function EnchantService:_connectEnchanterStations()
    if not self:IsEnabled() or not self._worldBindingService then
        return
    end

    local stations = self._worldBindingService:GetBound("EnchanterStation")
    for _, station in ipairs(stations) do
        local stationId = station:GetAttribute("EnchanterId") or DEFAULT_STATION_ID
        local stationConfig = self:_getStationConfig(stationId)
        local touchPart = self:_resolveStationTouchPart(station, stationConfig)
        if touchPart then
            self:_connectStationTouch(station, touchPart, stationId, stationConfig)
        else
            self._logger:Warn("EnchanterStation has no touch part", {
                station = station:GetFullName(),
                enchanterId = stationId,
            })
        end
    end
end

function EnchantService:_findStationById(stationId)
    if not self._worldBindingService then
        return nil
    end

    for _, station in ipairs(self._worldBindingService:GetBound("EnchanterStation")) do
        local id = station:GetAttribute("EnchanterId") or DEFAULT_STATION_ID
        if id == stationId then
            return station
        end
    end

    return nil
end

function EnchantService:_getPetModelTemplate(petData)
    if type(petData) ~= "table" then
        return nil
    end

    local assets = ReplicatedStorage:FindFirstChild("Assets")
    local models = assets and assets:FindFirstChild("Models")
    local pets = models and models:FindFirstChild("Pets")
    local petFolder = pets and pets:FindFirstChild(tostring(petData.id or ""))
    local variant = tostring(petData.variant or "basic")
    local template = petFolder and petFolder:FindFirstChild(variant)
    if template and template:IsA("Model") then
        return template
    end
    return nil
end

function EnchantService:_prepareDisplayPet(model)
    for _, descendant in ipairs(model:GetDescendants()) do
        if descendant:IsA("BasePart") then
            descendant.Anchored = true
            descendant.CanCollide = false
            descendant.CanTouch = false
            descendant.CanQuery = false
            descendant.Massless = true
            descendant.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
            descendant.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
        elseif descendant:IsA("Script") or descendant:IsA("LocalScript") then
            descendant.Enabled = false
        end
    end
end

function EnchantService:_createEnchantDisplayPet(station, petData, lightningConfig)
    local displayConfig = lightningConfig.display_pet or {}
    if displayConfig.enabled == false then
        return nil
    end

    local template = self:_getPetModelTemplate(petData)
    if not template then
        return nil
    end

    local centerPart = self:_resolveStationTouchPart(station, {
        touch_part_name = lightningConfig.center_part_name or "EnchantTouchPart",
    })
    if not centerPart then
        return nil
    end

    local clone = template:Clone()
    clone.Name = "EnchantPreviewPet"
    self:_prepareDisplayPet(clone)

    local scale = tonumber(displayConfig.scale) or 1
    if petData.huge == true then
        scale = tonumber(displayConfig.huge_scale) or scale
    end
    if scale > 0 then
        pcall(function()
            clone:ScaleTo(scale)
        end)
    end

    local offset = displayConfig.offset
    if typeof(offset) ~= "Vector3" then
        offset = Vector3.new(0, 0, 0)
    end
    local yaw = math.rad(tonumber(displayConfig.yaw_degrees) or 0)
    clone:PivotTo(CFrame.new(centerPart.Position + offset) * CFrame.Angles(0, yaw, 0))

    local effects = workspace:FindFirstChild("Effects")
    if not effects then
        effects = Instance.new("Folder")
        effects.Name = "Effects"
        effects.Parent = workspace
    end
    clone.Parent = effects

    local lifetime = math.max(
        tonumber(lightningConfig.result_delay_seconds)
            or tonumber(displayConfig.lifetime_seconds)
            or tonumber(lightningConfig.duration)
            or 1,
        0.2
    )
    Debris:AddItem(clone, lifetime + 0.35)
    return clone
end

function EnchantService:_playEnchantSuccessEffect(player, petData)
    if not (self._enchantLightning and self._enchantLightning.Play) then
        return 0
    end

    local access = self._stationAccessByPlayer[player]
    local stationId = type(access) == "table" and access.stationId or DEFAULT_STATION_ID
    local station = type(access) == "table" and access.station or nil
    if not (station and station.Parent) then
        station = self:_findStationById(stationId)
    end

    if not station then
        return 0
    end

    local stationConfig = self:_getStationConfig(stationId)
    local animation = stationConfig.animation or {}
    local lightning = animation.lightning or {}
    if lightning.enabled == false then
        return 0
    end
    local displayPet = self:_createEnchantDisplayPet(station, petData, lightning)

    local ok, err = pcall(function()
        self._enchantLightning.Play(station, lightning, displayPet)
    end)
    if not ok then
        self._logger:Warn("Failed to play enchanter lightning effect", {
            context = "EnchantService",
            station = station:GetFullName(),
            error = tostring(err),
        })
        return 0
    end

    return math.max(
        0,
        tonumber(lightning.result_delay_seconds) or tonumber(lightning.duration) or 0
    )
end

function EnchantService:RerollPetEnchant(player, payload)
    if not self:IsEnabled() then
        return {
            ok = false,
            reason = "enchants_disabled",
        }
    end

    local reroll = self._config.reroll or {}
    if reroll.enabled ~= true then
        return {
            ok = false,
            reason = "reroll_disabled",
        }
    end

    payload = type(payload) == "table" and payload or {}
    if not self:_requireStationAccess(player, payload) then
        return {
            ok = false,
            reason = "requires_station",
        }
    end

    local petUid = tostring(payload.petUid or payload.uid or "")
    local slot =
        math.max(1, math.floor(tonumber(payload.slot) or tonumber(reroll.default_slot) or 1))
    local petData, petError = self:_getPetRecord(player, petUid)
    if not petData then
        return {
            ok = false,
            reason = petError,
            petUid = petUid,
        }
    end

    -- PERMANENT classes (huge+/creator): fated — the station refuses them outright
    if self:IsPermanentEnchantPet(petData) then
        return {
            ok = false,
            reason = "enchants_permanent",
            petUid = petUid,
        }
    end

    local maxEnchantments = math.max(0, math.floor(tonumber(petData.max_enchantments) or 0))
    local unlockedSlots =
        math.max(0, math.floor(tonumber(petData.unlocked_enchant_slots) or maxEnchantments))
    if maxEnchantments <= 0 or slot > unlockedSlots then
        return {
            ok = false,
            reason = "slot_locked",
            petUid = petUid,
            slot = slot,
            unlockedSlots = unlockedSlots,
            maxEnchantments = maxEnchantments,
        }
    end

    petData.enchantments = type(petData.enchantments) == "table" and petData.enchantments or {}
    local excluded = {}
    for index, existingEnchant in ipairs(petData.enchantments) do
        if index ~= slot and type(existingEnchant) == "table" then
            excluded[existingEnchant.id] = true
        end
    end

    local rarityId = petData.rarity_id
    local enchant, rollError = self:RollEnchant(rarityId, excluded)
    if not enchant then
        return {
            ok = false,
            reason = rollError,
            petUid = petUid,
            slot = slot,
        }
    end

    local paid, payReason, costInfo = self:_chargeRerollCost(player)
    if not paid then
        return {
            ok = false,
            reason = payReason,
            petUid = petUid,
            currency = costInfo and costInfo.currency,
            cost = costInfo and costInfo.cost,
        }
    end

    enchant.source = payload.source or "manual_reroll"
    petData.enchantments[slot] = enchant

    -- Enchanting changes a special's enchant data, never equip — light refresh.
    if self._inventoryService and self._inventoryService.RefreshPetInventory then
        self._inventoryService:RefreshPetInventory(player)
    elseif self._inventoryService and self._inventoryService._updateBucketFolders then
        self._inventoryService:_updateBucketFolders(player, "pets")
    end
    local revealDelay = self:_playEnchantSuccessEffect(player, petData)
    self._dataService:RequestSave(player, "pet_enchant_reroll", { critical = true })

    return {
        ok = true,
        petUid = petUid,
        slot = slot,
        enchant = enchant,
        currency = costInfo and costInfo.currency,
        cost = costInfo and costInfo.cost,
        reveal_delay_seconds = revealDelay,
    }
end

function EnchantService:_matchesModifierContext(modifier, context)
    if type(modifier) ~= "table" or type(context) ~= "table" then
        return false
    end
    if modifier.kind ~= nil and modifier.kind ~= context.kind then
        return false
    end
    if modifier.currency ~= nil and modifier.currency ~= context.currency then
        return false
    end
    return true
end

function EnchantService:_getEquippedUniquePets(player)
    local data = self._dataService and self._dataService:GetData(player)
    local items = data and data.Inventory and data.Inventory.pets and data.Inventory.pets.items
    local equipped = data and data.Equipped and data.Equipped.pets
    if type(items) ~= "table" or type(equipped) ~= "table" then
        return {}
    end

    -- Equip lives in the separate Equipped.pets layer; an equipped enchantable pet qualifies.
    -- Validate refs against inventory (ignore dangling), dedupe.
    local capability = self:_petCapability()
    local seen, pets = {}, {}
    for _, ref in pairs(equipped) do
        local desc = PetInventoryView.parseRef(ref)
        if desc and desc.kind == "special" and not seen[desc.uid] then
            local petData = items[desc.uid]
            if type(petData) == "table" and PetInventoryView.isEnchantable(petData, capability) then
                seen[desc.uid] = true
                table.insert(pets, { uid = desc.uid, data = petData })
            end
        end
    end
    return pets
end

-- Equipped STACKS carrying a stack enchant (Storage v2): resolve Equipped.pets refs
-- of kind "stack" to their inventory records; each equipped slot referencing an
-- enchanted stack yields one entry { key, effect }.
function EnchantService:_getEquippedEnchantStacks(player)
    local data = self._dataService and self._dataService:GetData(player)
    local items = data and data.Inventory and data.Inventory.pets and data.Inventory.pets.items
    local equipped = data and data.Equipped and data.Equipped.pets
    if type(items) ~= "table" or type(equipped) ~= "table" then
        return {}
    end
    local list = {}
    for _, ref in pairs(equipped) do
        local desc = PetInventoryView.parseRef(ref)
        if desc and desc.kind == "stack" then
            local rec = items[desc.stackKey]
            if type(rec) == "table" and rec.enchant ~= nil then
                -- rarity drives the enchant type_multiplier (stacks are legendary/mythic); resolve
                -- from the pet config by id, falling back to any stored rarity_id.
                local petCfg = self._petsConfig
                    and self._petsConfig.pets
                    and rec.id
                    and self._petsConfig.pets[rec.id]
                local rarity = (petCfg and petCfg.rarity_id) or rec.rarity_id
                table.insert(list, { key = desc.stackKey, effect = rec.enchant, rarity = rarity })
            end
        end
    end
    return list
end

function EnchantService:_getModifierContributions(context)
    if type(context) ~= "table" or not context.player then
        return {}
    end

    local contributions = {}
    for _, pet in ipairs(self:_getEquippedUniquePets(context.player)) do
        for _, enchant in ipairs(pet.data.enchantments or {}) do
            local enchantConfig = self._config.effects and self._config.effects[enchant.id]
            local modifier = enchantConfig and enchantConfig.modifier
            if self:_matchesModifierContext(modifier, context) then
                local strength = tonumber(enchant.strength or enchant.value) or 0
                local typeMult = self:_typeMultiplier(self:_petTierId(pet.data))
                local value = strength * (tonumber(modifier.amount_per_strength) or 0) * typeMult
                local combine = modifier.combine or "add"
                local amount = value
                if combine == "multiply" then
                    amount = 1 + value
                end
                table.insert(contributions, {
                    id = tostring(pet.uid) .. ":" .. tostring(enchant.id),
                    label = enchant.display_name or enchantConfig.display_name or enchant.id,
                    amount = amount,
                    combine = combine,
                })
            end
        end
    end

    -- STACK ENCHANTS (Storage v2): equipped mythic stacks contribute at the flat
    -- "Mythic Strength" through the same modifier-context matching as uniques.
    local stackStrength = self:GetStackEnchantStrength()
    for _, s in ipairs(self:_getEquippedEnchantStacks(context.player)) do
        local enchantConfig = self._config.effects and self._config.effects[s.effect]
        local modifier = enchantConfig and enchantConfig.modifier
        if modifier and self:_matchesModifierContext(modifier, context) then
            local value = stackStrength
                * (tonumber(modifier.amount_per_strength) or 0)
                * self:_typeMultiplier(s.rarity)
            local combine = modifier.combine or "add"
            table.insert(contributions, {
                id = tostring(s.key) .. ":" .. tostring(s.effect),
                label = enchantConfig.display_name or s.effect,
                amount = combine == "multiply" and (1 + value) or value,
                combine = combine,
            })
        end
    end

    return contributions
end

return EnchantService
