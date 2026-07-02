--[[
    PetGrantService

    Single boundary for turning a selected pet outcome into durable inventory.
    Egg rolls, admin tools, creator rewards, and scripts should call this service
    instead of writing pet inventory records directly.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PetElement = require(ReplicatedStorage.Shared.Game.PetElement)

local PetGrantService = {}
PetGrantService.__index = PetGrantService

function PetGrantService.new()
    local self = setmetatable({}, PetGrantService)
    self._logger = nil
    self._configLoader = nil
    self._dataService = nil
    self._inventoryService = nil
    self._petSerialService = nil
    self._petProgressionService = nil
    self._enchantService = nil
    self._petsConfig = nil
    return self
end

function PetGrantService:Init()
    self._logger = self._modules.Logger
    self._configLoader = self._modules.ConfigLoader
    self._dataService = self._modules.DataService
    self._inventoryService = self._modules.InventoryService
    self._petSerialService = self._modules.PetSerialService
    self._petProgressionService = self._modules.PetProgressionService
    self._enchantService = self._modules.EnchantService
    self._petsConfig = self._configLoader:LoadConfig("pets")
    self._layersConfig = self._configLoader:LoadConfig("layers")

    self._logger:Info("PetGrantService initialized", {
        context = "PetGrantService",
    })
end

function PetGrantService:_getMaxEnchantmentsForRarity(rarityId)
    local enchanting = self._petsConfig and self._petsConfig.enchanting
    if type(rarityId) ~= "string" or type(enchanting) ~= "table" then
        return 0
    end

    local byRarity = enchanting.max_enchantments_by_rarity
    local maxEnchantments = type(byRarity) == "table" and byRarity[rarityId]
    if maxEnchantments == nil then
        maxEnchantments = enchanting.default_max_enchantments
    end
    return tonumber(maxEnchantments) or 0
end

function PetGrantService:_applyEnchantDefaults(petData)
    local rarityId = petData.rarity_id or petData.rarity_override
    local maxEnchantments = self:_getMaxEnchantmentsForRarity(rarityId)
    if maxEnchantments <= 0 then
        return
    end

    petData.enchantable = true
    petData.max_enchantments = maxEnchantments
    petData.enchantments = petData.enchantments or {}
end

function PetGrantService:_shouldAttachHatcherSource(rarityId, maxEnchantments)
    local provenance = self._petsConfig and self._petsConfig.provenance
    if type(provenance) ~= "table" then
        return false
    end

    local explicitRarities = provenance.hatcher_source_rarities
    if type(rarityId) == "string" and type(explicitRarities) == "table" then
        for _, explicitRarity in ipairs(explicitRarities) do
            if explicitRarity == rarityId then
                return true
            end
        end
    end

    local threshold = tonumber(provenance.hatcher_source_min_enchantments) or 0
    return threshold > 0 and (tonumber(maxEnchantments) or 0) >= threshold
end

function PetGrantService:_applyProvenance(petData, player)
    local rarityId = petData.rarity_id or petData.rarity_override
    local maxEnchantments = tonumber(petData.max_enchantments)
        or self:_getMaxEnchantmentsForRarity(rarityId)
    if not self:_shouldAttachHatcherSource(rarityId, maxEnchantments) then
        return
    end
    if not player then
        return
    end

    local hatcherName = tostring(player.Name or "")
    if hatcherName == "" then
        return
    end

    petData.hatcher_name = hatcherName
    petData.hatcher_user_id = player.UserId
end

function PetGrantService:_normalizeGrant(request)
    request = type(request) == "table" and request or {}
    return {
        petType = tostring(request.petType or request.id or ""):lower(),
        variant = tostring(request.variant or "basic"):lower(),
        quantity = math.clamp(math.floor(tonumber(request.quantity) or 1), 1, 99),
        huge = request.huge == true,
        creator = request.creator == true,
        locked = request.locked,
        nickname = request.nickname,
        source = request.source or "pet_grant",
        element = request.element and tostring(request.element):lower() or nil,
    }
end

function PetGrantService:BuildPetData(request, player)
    local grant = self:_normalizeGrant(request)
    local petConfig = self._petsConfig.getPet
        and self._petsConfig.getPet(grant.petType, grant.variant)
    if not petConfig then
        return nil, "Unknown pet: " .. tostring(grant.petType) .. ":" .. tostring(grant.variant)
    end

    local petData = {
        id = grant.petType,
        variant = grant.variant,
        quantity = grant.huge and 1 or grant.quantity,
        obtained_at = tick(),
        level = 1,
        exp = 0,
        nickname = grant.nickname or "",
        -- creator-CLASS pets are ALWAYS locked (untradeable apex — Jason); huges and
        -- regular exclusives are tradeable ("I just tried to trade a huge bear and I
        -- couldn't") — only an explicit lock applies otherwise
        locked = grant.creator or grant.locked == true,
        grant_source = grant.source,
    }

    -- Element at hatch (Feature 5): from the layer the hatch happens on
    -- (base -> neutral; Heaven -> light; Hell -> shadow once LayerService exists).
    -- An explicit request.element overrides (test/fusion). Chaotic is fusion-only.
    local hatchLayer = "base"
    if self._dataService then
        local data = self._dataService:GetData(player)
        hatchLayer = (data and data.CurrentLayer) or "base"
    end
    petData.element = grant.element or PetElement.elementForLayer(hatchLayer, self._layersConfig)

    if petConfig.rarity_id then
        petData.rarity_id = petConfig.rarity_id
    end

    if type(petConfig.eternal) == "table" and petConfig.eternal.enabled == true then
        petData.eternal = true
        petData.eternal_percent = tonumber(petConfig.eternal.power_percent) or 0
    end

    if grant.huge or grant.creator then
        -- CREATOR pets serialize in their OWN chain (creator:<pet>:<variant>) — the
        -- apex ledger is separate from natural huges, so a wild-hatched huge
        -- colorado (slim odds, NOT a creator pet) numbers independently.
        local serialType = grant.creator and "creator" or "huge"
        local serial, serialInfo =
            self._petSerialService:NextSerial(serialType, grant.petType, grant.variant)
        if not serial then
            return nil,
                "Failed to allocate " .. serialType .. " serial: " .. tostring(
                    serialInfo and serialInfo.error or "unknown"
                )
        end

        petData.huge = grant.huge == true
        petData.creator = grant.creator == true or nil
        petData.serial = serial
        petData.serial_key = serialInfo.key
        petData.serial_source = serialInfo.source
        petData.rarity_id = grant.creator and "creator" or "huge"

        -- WORLD FIRST (Jason: "if the index updates you basically get a global
        -- announcement that there's a new huge in the realm"): serial #1 means this
        -- exact huge species:variant has NEVER existed anywhere. Detected for free
        -- at mint; announced realm-wide. Creator chain excluded (the apex ledger is
        -- Jason's own). pcall'd celebration — never breaks the grant.
        if serial == 1 and grant.huge and not grant.creator then
            task.spawn(function()
                self:_announceWorldFirst(player, grant.petType, grant.variant)
            end)
        end
    end

    self:_applyEnchantDefaults(petData)
    if petData.enchantable == true then
        petData.quantity = 1
    end
    if self._petProgressionService then
        self._petProgressionService:ApplyProgression(petData, petConfig)
    end
    if
        self._enchantService
        and self._enchantService.RollInitialEnchantments
        and self._petsConfig.enchanting
        and self._petsConfig.enchanting.hatch_rolls_enabled == true
    then
        self._enchantService:RollInitialEnchantments(player, petData, petConfig, grant.source)
    end
    -- STACK ENCHANT (Storage v2 D2-D4): stackable rarities (mythic) roll ONE effect at
    -- hatch that becomes part of the STACK KEY (id:variant:enchant) — the pet stays
    -- stackable; strength is the flat "Mythic Strength" config value resolved at READ
    -- time (never stored). A trade/grant that already carries .enchant keeps it.
    if
        petData.enchantable ~= true
        and petData.enchant == nil
        and self._enchantService
        and self._enchantService.RollStackEnchant
        and self._petsConfig.enchanting
        and self._petsConfig.enchanting.hatch_rolls_enabled == true
    then
        local effect =
            self._enchantService:RollStackEnchant(petData.rarity_id or petConfig.rarity_id)
        if effect then
            petData.enchant = effect
        end
    end
    self:_applyProvenance(petData, player)

    return petData, nil, petConfig
end

-- Publish a huge world-first to EVERY server: each server's PetIndexService
-- subscriber (PetWorldFirst topic) grows its index and shows the realm banner —
-- including THIS server (a same-server publish delivers to its own subscriber, so
-- there's exactly one announcement path and no double banner). Offline fallback
-- (Studio without API access): notify the local index service directly so testing
-- still shows the moment.
function PetGrantService:_announceWorldFirst(player, petType, variant)
    local payload = { t = petType, v = variant or "basic", p = player and player.Name or "?" }
    local ok = pcall(function()
        game:GetService("MessagingService"):PublishAsync("PetWorldFirst", payload)
    end)
    if ok then
        return
    end
    local locator = _G.RBXTemplateServices
    local okIdx, indexService = pcall(function()
        return locator and locator:Get("PetIndexService")
    end)
    if okIdx and indexService and indexService.NotifyWorldFirst then
        indexService:NotifyWorldFirst(petType, variant, payload.p, true)
    end
end

function PetGrantService:GrantPet(player, request)
    if not player or not player.Parent then
        return {
            ok = false,
            error = "Invalid player",
        }
    end

    local petData, errorMessage, petConfig = self:BuildPetData(request, player)
    if not petData then
        return {
            ok = false,
            error = errorMessage,
        }
    end

    local uid, addError = self._inventoryService:AddItem(player, "pets", petData)
    if not uid then
        return {
            ok = false,
            error = addError or "Failed to add pet",
            petData = petData,
        }
    end

    self._dataService:RequestSave(
        player,
        "pet_grant_" .. tostring(request and request.source or "generic"),
        { critical = true }
    )

    self._logger:Info("Pet granted", {
        context = "PetGrantService",
        player = player.Name,
        uid = uid,
        petType = petData.id,
        variant = petData.variant,
        quantity = petData.quantity,
        huge = petData.huge == true,
        serial = petData.serial,
        source = petData.grant_source,
    })

    return {
        ok = true,
        uid = uid,
        petData = petData,
        petConfig = petConfig,
    }
end

return PetGrantService
