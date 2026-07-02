--[[
    StudioSmokeTestService

    Studio-only RemoteFunction bridge used by MCP smoke tests. This lets tests
    coordinate real client UI behavior while keeping currency, inventory, and
    server-authoritative gameplay assertions on the server.
]]

local StudioSmokeTestService = {}
StudioSmokeTestService.__index = StudioSmokeTestService

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local REMOTE_NAME = "StudioSmokeTest"
local Locations = require(ReplicatedStorage.Shared.Locations)
local EggWorldQuery = require(ReplicatedStorage.Shared.Services.EggWorldQuery)

-- SSOT: pet records no longer carry `_kind`. A special (unique-per-instance) pet is
-- identified by huge / serial / per-copy progression. Commons carry none of these.
local function isSpecialPetRecord(item)
    if type(item) ~= "table" then
        return false
    end
    if item.huge == true or item.serial ~= nil then
        return true
    end
    if (tonumber(item.level) or 1) > 1 or (tonumber(item.exp) or 0) > 0 then
        return true
    end
    return type(item.enchantments) == "table" and next(item.enchantments) ~= nil
end

local logger
local configLoader
local dataService
local statsService
local inventoryService
local economyService
local worldBindingService
local zoneService
local upgradeService
local breakableSpawner
local petIndexService
local achievementsService
local leaderboardService
local petGrantService
local petProgressionService
local enchantService
local modifierService
local playerProgressionService
local autoTargetService
local settingsService

local sessions = {}
local travelSessions = {}

local function deepCopy(value)
    if type(value) ~= "table" then
        return value
    end

    local copy = {}
    for key, child in pairs(value) do
        copy[key] = deepCopy(child)
    end
    return copy
end

local function countPets(petsBucket)
    local total = 0
    local items = petsBucket and petsBucket.items
    if type(items) ~= "table" then
        return total
    end

    for _, item in pairs(items) do
        total += tonumber(item.quantity) or 1
    end

    return total
end

local function findEggByType(eggType)
    return EggWorldQuery.FindEggByType(eggType)
end

local function getEggAnchor(egg)
    return EggWorldQuery.GetAnchor(egg)
end

local getRootPart

local function createTemporaryEggStand(player, eggType)
    local folder = Workspace:FindFirstChild("StudioSmokeTemp")
    if not folder then
        folder = Instance.new("Folder")
        folder.Name = "StudioSmokeTemp"
        folder.Parent = Workspace
    end

    local rootPart = getRootPart(player)
    local basePosition = rootPart and rootPart.Position or Vector3.new(0, 10, 0)
    local stand = Instance.new("Part")
    stand.Name = "TemporaryEggStand_" .. tostring(eggType)
    stand.Anchored = true
    stand.CanCollide = false
    stand.CanTouch = false
    stand.CanQuery = true
    stand.Transparency = 1
    stand.Size = Vector3.new(4, 1, 4)
    stand.Position = basePosition + Vector3.new(12, 0, 0)
    stand:SetAttribute("EggType", eggType)
    stand:SetAttribute("StudioSmokeTemporary", true)
    stand.Parent = folder
    CollectionService:AddTag(stand, "EggStand")

    return stand
end

function getRootPart(player)
    local character = player.Character
    return character and character:FindFirstChild("HumanoidRootPart")
end

local function movePlayer(player, position)
    local rootPart = getRootPart(player)
    if not rootPart then
        return false, "HumanoidRootPart not ready"
    end

    rootPart.CFrame = CFrame.new(position)
    rootPart.AssemblyLinearVelocity = Vector3.zero
    rootPart.AssemblyAngularVelocity = Vector3.zero
    return true
end

function StudioSmokeTestService:Init()
    logger = self._modules.Logger
    configLoader = self._modules.ConfigLoader
    dataService = self._modules.DataService
    statsService = self._modules.StatsService
    inventoryService = self._modules.InventoryService
    economyService = self._modules.EconomyService
    worldBindingService = self._modules.WorldBindingService
    zoneService = self._modules.ZoneService
    upgradeService = self._modules.UpgradeService
    breakableSpawner = self._modules.BreakableSpawner
    petIndexService = self._modules.PetIndexService
    achievementsService = self._modules.AchievementsService
    leaderboardService = self._modules.LeaderboardService
    petGrantService = self._modules.PetGrantService
    petProgressionService = self._modules.PetProgressionService
    enchantService = self._modules.EnchantService
    modifierService = self._modules.ModifierService
    playerProgressionService = self._modules.PlayerProgressionService
    autoTargetService = self._modules.AutoTargetService
    settingsService = self._modules.SettingsService
end

function StudioSmokeTestService:Start()
    if not RunService:IsStudio() then
        return
    end

    local existing = ReplicatedStorage:FindFirstChild(REMOTE_NAME)
    if existing then
        existing:Destroy()
    end

    local remote = Instance.new("RemoteFunction")
    remote.Name = REMOTE_NAME
    remote.OnServerInvoke = function(player, action, payload)
        return self:_handleRequest(player, action, payload or {})
    end
    remote.Parent = ReplicatedStorage

    Players.PlayerRemoving:Connect(function(player)
        sessions[player.UserId] = nil
        travelSessions[player.UserId] = nil
    end)

    logger:Info("Studio smoke test bridge ready", {
        context = "StudioSmokeTestService",
        remote = REMOTE_NAME,
    })
end

function StudioSmokeTestService:_handleRequest(player, action, payload)
    if not RunService:IsStudio() then
        return {
            ok = false,
            error = "Studio smoke bridge is disabled outside Studio",
        }
    end

    if action == "BeginEggProximity" then
        return self:_beginEggProximity(player, payload)
    elseif action == "MoveEggProximity" then
        return self:_moveEggProximity(player, payload)
    elseif action == "HatchEggProximity" then
        return self:_hatchEggProximity(player, payload)
    elseif action == "RestoreEggProximity" then
        return self:_restoreEggProximity(player)
    elseif action == "GetEggHatchHistory" then
        return self:_getEggHatchHistory(player, payload)
    elseif action == "SimulateEggHatch" then
        return self:_simulateEggHatch(player, payload)
    elseif action == "BeginTravelSmoke" then
        return self:_beginTravelSmoke(player, payload)
    elseif action == "UseTravelSmoke" then
        return self:_useTravelSmoke(player)
    elseif action == "UnlockTravelSmoke" then
        return self:_unlockTravelSmoke(player)
    elseif action == "RestoreTravelSmoke" then
        return self:_restoreTravelSmoke(player)
    elseif action == "CheckSpawnSafetySmoke" then
        return self:_checkSpawnSafetySmoke(player, payload)
    elseif action == "RunPhase2ProgressionSmoke" then
        return self:_runPhase2ProgressionSmoke(player, payload)
    elseif action == "RunMeadowBreakableSmoke" then
        return self:_runMeadowBreakableSmoke(player, payload)
    elseif action == "RunSyntheticExpansionSmoke" then
        return self:_runSyntheticExpansionSmoke(player, payload)
    elseif action == "RunPhase3StatsSmoke" then
        return self:_runPhase3StatsSmoke(player, payload)
    elseif action == "GrantColoradoTestPets" then
        return self:_grantColoradoTestPets(player, payload)
    elseif action == "BackfillPetHatcherProvenance" then
        return self:_backfillPetHatcherProvenance(player, payload)
    elseif action == "BackfillPetPowerSourceOfTruth" then
        return self:_backfillPetPowerSourceOfTruth(player, payload)
    elseif action == "CheckEternalPowerSmoke" then
        return self:_checkEternalPowerSmoke(player)
    elseif action == "RunPhase4PetProgressionSmoke" then
        return self:_runPhase4PetProgressionSmoke(player, payload)
    elseif action == "RunPhase5AutoSystemsSmoke" then
        return self:_runPhase5AutoSystemsSmoke(player, payload)
    elseif action == "CleanupColoradoGrantOrphans" then
        return self:_cleanupColoradoGrantOrphans(player)
    end

    return {
        ok = false,
        error = "Unknown smoke action: " .. tostring(action),
    }
end

local function ensureFolder(parent, name)
    local folder = parent:FindFirstChild(name)
    if not folder then
        folder = Instance.new("Folder")
        folder.Name = name
        folder.Parent = parent
    end
    return folder
end

local function createSmokeBreakable(parent, name, id, position, hp, maxHp, value, currency)
    local model = Instance.new("Model")
    model.Name = name

    local part = Instance.new("Part")
    part.Name = "Primary"
    part.Size = Vector3.new(2, 2, 2)
    part.Anchored = true
    part.Position = position
    part.Parent = model
    model.PrimaryPart = part

    local idValue = Instance.new("NumberValue")
    idValue.Name = "BreakableID"
    idValue.Value = id
    idValue.Parent = model

    model:SetAttribute("HP", hp)
    model:SetAttribute("MaxHP", maxHp)
    model:SetAttribute("Value", value)
    model:SetAttribute("Currency", currency)
    model.Parent = parent

    return model
end

function StudioSmokeTestService:_runPhase5AutoSystemsSmoke(player, payload)
    payload = type(payload) == "table" and payload or {}
    if not dataService:IsDataLoaded(player) then
        return {
            ok = false,
            error = "Player data is not loaded",
        }
    end
    if not autoTargetService then
        return {
            ok = false,
            error = "AutoTargetService unavailable",
        }
    end

    local data = dataService:GetData(player)
    local snapshot = {
        Settings = deepCopy(data.Settings),
    }

    local currentWorld = player:FindFirstChild("CurrentWorld")
    local oldCurrentWorldValue = currentWorld and currentWorld.Value or nil
    if not currentWorld then
        currentWorld = Instance.new("StringValue")
        currentWorld.Name = "CurrentWorld"
        currentWorld.Parent = player
    end

    local root = workspace:FindFirstChild("Game") or ensureFolder(workspace, "Game")
    local breakables = ensureFolder(root, "Breakables")
    local crystals = ensureFolder(breakables, "Crystals")
    local smokeWorld = ensureFolder(crystals, "Phase5Smoke")
    local oldSmokeWorld = {}
    for _, child in ipairs(smokeWorld:GetChildren()) do
        table.insert(oldSmokeWorld, child)
        child.Parent = nil
    end
    local items = ensureFolder(smokeWorld, "Items")

    local function restore()
        data.Settings = snapshot.Settings
        if oldCurrentWorldValue == nil then
            currentWorld:Destroy()
        else
            currentWorld.Value = oldCurrentWorldValue
        end
        smokeWorld:ClearAllChildren()
        for _, child in ipairs(oldSmokeWorld) do
            child.Parent = smokeWorld
        end
    end

    local ok, result = pcall(function()
        currentWorld.Value = "Phase5Smoke"
        createSmokeBreakable(items, "NearLow", 5101, Vector3.new(0, 3, 0), 20, 100, 10, "crystals")
        createSmokeBreakable(
            items,
            "FarHighValue",
            5102,
            Vector3.new(80, 3, 0),
            80,
            100,
            500,
            "crystals"
        )
        createSmokeBreakable(
            items,
            "StrongCoin",
            5103,
            Vector3.new(40, 3, 0),
            900,
            1000,
            250,
            "coins"
        )

        local modeResults = {}
        local function expectMode(mode, expectedId, payloadForMode)
            autoTargetService:SetAutoTargetMode(player, payloadForMode or {
                enabled = true,
                mode = mode,
            })
            local _, info = autoTargetService:SelectTarget(player, mode)
            if not info or info.id ~= expectedId then
                error(
                    string.format(
                        "mode %s expected %s got %s",
                        tostring(mode),
                        tostring(expectedId),
                        tostring(info and info.id)
                    )
                )
            end
            modeResults[mode] = info.id
        end

        expectMode("nearest", 5101)
        expectMode("highest_value", 5102)
        expectMode("weakest", 5101)
        expectMode("strongest", 5103)
        expectMode("selected_currency", 5103, {
            enabled = true,
            mode = "selected_currency",
            selected_currency = "coins",
        })

        local settings = data.Settings.AutoSystems
        if
            not settings
            or not settings.auto_target
            or settings.auto_target.mode ~= "selected_currency"
            or settings.auto_target.selected_currency ~= "coins"
        then
            error("Expected auto-target mode settings to persist in profile data")
        end

        autoTargetService:SetAutoDeleteFilters(player, {
            enabled = true,
            rarities = {
                common = true,
            },
            pet_types = {
                doggy = true,
            },
            variants = {
                golden = true,
            },
        })

        local deleteBear = autoTargetService:ShouldAutoDeleteHatch(player, {
            pet = "bear",
            variant = "basic",
        })
        local deleteDoggy = autoTargetService:ShouldAutoDeleteHatch(player, {
            pet = "doggy",
            variant = "basic",
        })
        local deleteGolden = autoTargetService:ShouldAutoDeleteHatch(player, {
            pet = "bunny",
            variant = "golden",
        })
        local deleteProtected = autoTargetService:ShouldAutoDeleteHatch(player, {
            pet = "colorado",
            variant = "basic",
        })
        if deleteBear ~= true or deleteDoggy ~= true or deleteGolden ~= true then
            error("Expected common/type/variant auto-delete filters to match")
        end
        if deleteProtected == true then
            error("Expected protected exclusive pet not to auto-delete")
        end

        return {
            modeResults = modeResults,
            autoDelete = {
                commonBear = deleteBear,
                doggy = deleteDoggy,
                goldenBunny = deleteGolden,
                protectedColorado = deleteProtected,
            },
        }
    end)

    restore()

    if not ok then
        return {
            ok = false,
            error = tostring(result),
        }
    end

    return {
        ok = true,
        restored = true,
        result = result,
    }
end

function StudioSmokeTestService:_cleanupColoradoGrantOrphans(player)
    if not dataService:IsDataLoaded(player) then
        return {
            ok = false,
            error = "Player data is not loaded",
        }
    end

    local data = dataService:GetData(player)
    local bucket = data and data.Inventory and data.Inventory.pets
    local removed = {}
    if bucket and bucket.items then
        for key, item in pairs(bucket.items) do
            if
                type(key) == "string"
                and string.match(key, "^colorado_")
                and type(item) == "table"
                and item.id == "colorado"
                and not isSpecialPetRecord(item)
            then
                bucket.items[key] = nil
                bucket.used_slots = math.max(0, (bucket.used_slots or 1) - 1)
                table.insert(removed, key)
            end
        end
    end

    if #removed > 0 then
        if inventoryService and inventoryService._updateBucketFolders then
            inventoryService:_updateBucketFolders(player, "pets")
        end
        dataService:RequestSave(player, "cleanup_colorado_grant_orphans", {
            critical = true,
        })
    end

    return {
        ok = true,
        removed = removed,
    }
end

function StudioSmokeTestService:_runPhase4PetProgressionSmoke(player, payload)
    payload = type(payload) == "table" and payload or {}
    if not dataService:IsDataLoaded(player) then
        return {
            ok = false,
            error = "Player data is not loaded",
        }
    end
    if
        not petGrantService
        or not petProgressionService
        or not enchantService
        or not modifierService
        or not playerProgressionService
    then
        return {
            ok = false,
            error = "Phase 4 services unavailable",
        }
    end

    local data = dataService:GetData(player)
    local snapshot = {
        Inventory = deepCopy(data.Inventory),
        Equipped = deepCopy(data.Equipped),
        Currencies = deepCopy(data.Currencies),
        Stats = deepCopy(data.Stats),
    }

    local function restore()
        data.Inventory = snapshot.Inventory
        data.Equipped = snapshot.Equipped
        data.Currencies = snapshot.Currencies
        data.Stats = snapshot.Stats
        player:SetAttribute("Level", data.Stats and data.Stats.Level or 1)
        if inventoryService and inventoryService._updateBucketFolders then
            inventoryService:_updateBucketFolders(player, "pets")
        end
        if inventoryService and inventoryService._updateEquippedFolders then
            inventoryService:_updateEquippedFolders(player, "pets")
        end
    end

    local ok, result = pcall(function()
        local grant = petGrantService:GrantPet(player, {
            petType = payload.petType or "colorado",
            variant = payload.variant or "rainbow",
            huge = payload.huge ~= false,
            source = "phase4_pet_progression_smoke",
        })
        if not grant.ok then
            error(grant.error or "grant_failed")
        end

        local petData = data.Inventory.pets.items[grant.uid]
        if type(petData) ~= "table" then
            error("Granted pet missing from inventory")
        end

        local enchantCount = type(petData.enchantments) == "table" and #petData.enchantments or 0
        if enchantCount <= 0 then
            error("Expected granted pet to roll at least one hatch enchant")
        end

        data.Equipped = data.Equipped or {}
        data.Equipped.pets = data.Equipped.pets or {}
        data.Equipped.pets.slot_1 = grant.uid
        if inventoryService and inventoryService._updateEquippedFolders then
            inventoryService:_updateEquippedFolders(player, "pets")
        end

        data.Stats = data.Stats or {}
        data.Stats.Level = 15
        player:SetAttribute("Level", 15)

        petData.enchantments = {
            { id = "luck", display_name = "Luck", strength = 10 },
            { id = "secret_luck", display_name = "Secret Luck", strength = 10 },
            { id = "tactics", display_name = "Tactics", strength = 10 },
            { id = "leadership", display_name = "Leadership", strength = 10 },
            { id = "efficiency", display_name = "Efficiency", strength = 10 },
        }

        local slotBonus = playerProgressionService:GetEquippedPetSlotBonus(player)
        if slotBonus < 1 then
            error("Expected player level reward to grant at least one pet slot bonus at level 15")
        end

        local hatchLuck = modifierService:Resolve(0, {
            player = player,
            kind = "hatch_luck",
            source = "Phase4PetProgressionSmoke",
        })
        local secretLuck = modifierService:Resolve(0, {
            player = player,
            kind = "secret_hatch_luck",
            source = "Phase4PetProgressionSmoke",
        })
        local petDamage = modifierService:Resolve(100, {
            player = player,
            kind = "pet_damage",
            source = "Phase4PetProgressionSmoke",
        })
        local teamPower = modifierService:Resolve(100, {
            player = player,
            kind = "team_power",
            source = "Phase4PetProgressionSmoke",
        })
        local petEfficiency = modifierService:Resolve(1, {
            player = player,
            kind = "pet_efficiency",
            source = "Phase4PetProgressionSmoke",
        })
        if hatchLuck <= 0 or secretLuck <= 0 then
            error("Expected hatch luck enchant modifiers to resolve above zero")
        end
        if petDamage <= 100 or teamPower <= 100 or petEfficiency <= 1 then
            error("Expected damage/team/efficiency enchant modifiers to increase base values")
        end

        local xpResult = petProgressionService:AwardBreakableDestroyed(player, {
            world = "Spawn",
            crystalName = "BigBlueCrystal",
            currency = "crystals",
            source = "Phase4PetProgressionSmoke",
        })
        if not xpResult.ok or (xpResult.awarded or 0) <= 0 then
            error("Expected breakable XP to award to equipped unique pet")
        end
        if (tonumber(petData.exp) or 0) <= 0 and (tonumber(petData.level) or 1) <= 1 then
            error("Expected pet XP or level to increase")
        end

        data.Currencies = data.Currencies or {}
        data.Currencies.gems = math.max(tonumber(data.Currencies.gems) or 0, 5)
        local reroll = enchantService:RerollPetEnchant(player, {
            petUid = grant.uid,
            slot = 1,
            source = "studio_smoke",
        })
        if not reroll.ok then
            error("Expected enchant reroll to succeed: " .. tostring(reroll.reason))
        end

        return {
            uid = grant.uid,
            enchantCount = enchantCount,
            firstEnchant = petData.enchantments[1],
            rerolledEnchant = reroll.enchant,
            xp = xpResult.xp,
            level = petData.level,
            exp = petData.exp,
            unlockedEnchantSlots = petData.unlocked_enchant_slots,
            maxEnchantments = petData.max_enchantments,
            slotBonus = slotBonus,
            hatchLuck = hatchLuck,
            secretLuck = secretLuck,
            petDamage = petDamage,
            teamPower = teamPower,
            petEfficiency = petEfficiency,
        }
    end)

    restore()

    if not ok then
        return {
            ok = false,
            error = tostring(result),
        }
    end

    return {
        ok = true,
        restored = true,
        result = result,
    }
end

function StudioSmokeTestService:_grantColoradoTestPets(player, payload)
    payload = type(payload) == "table" and payload or {}
    if not dataService:IsDataLoaded(player) then
        return {
            ok = false,
            error = "Player data is not loaded",
        }
    end
    if not petGrantService then
        return {
            ok = false,
            error = "PetGrantService unavailable",
        }
    end

    local normalResult = petGrantService:GrantPet(player, {
        petType = "colorado",
        variant = "basic",
        source = "studio_colorado_test",
    })
    if not normalResult.ok then
        return normalResult
    end

    local hugeResult = petGrantService:GrantPet(player, {
        petType = "colorado",
        variant = "rainbow",
        huge = true,
        source = "studio_colorado_test",
    })
    if not hugeResult.ok then
        return hugeResult
    end

    local equip = payload.equip ~= false
    if equip then
        local data = dataService:GetData(player)
        data.Equipped = data.Equipped or {}
        data.Equipped.pets = data.Equipped.pets or {}
        data.Equipped.pets.slot_1 = normalResult.uid
        data.Equipped.pets.slot_2 = hugeResult.uid

        if inventoryService and inventoryService._updateEquippedFolders then
            inventoryService:_updateEquippedFolders(player, "pets")
        end
    end

    dataService:RequestSave(player, "studio_colorado_test_grant", {
        critical = true,
    })

    return {
        ok = true,
        equipped = equip,
        normal = {
            uid = normalResult.uid,
            petType = normalResult.petData.id,
            variant = normalResult.petData.variant,
            rarity = normalResult.petConfig and normalResult.petConfig.rarity_id or "exclusive",
        },
        huge = {
            uid = hugeResult.uid,
            petType = hugeResult.petData.id,
            variant = hugeResult.petData.variant,
            huge = hugeResult.petData.huge == true,
            serial = hugeResult.petData.serial,
            serialKey = hugeResult.petData.serial_key,
            serialSource = hugeResult.petData.serial_source,
            rarity = hugeResult.petData.rarity_id,
        },
    }
end

function StudioSmokeTestService:_backfillPetHatcherProvenance(player, payload)
    payload = type(payload) == "table" and payload or {}
    if not dataService:IsDataLoaded(player) then
        return {
            ok = false,
            error = "Player data is not loaded",
        }
    end

    local data = dataService:GetData(player)
    local bucket = data and data.Inventory and data.Inventory.pets
    local items = bucket and bucket.items
    if type(items) ~= "table" then
        return {
            ok = false,
            error = "Pet inventory is unavailable",
        }
    end

    local petsConfig = configLoader:LoadConfig("pets")
    local provenance = petsConfig.provenance or {}
    local threshold = tonumber(provenance.hatcher_source_min_enchantments) or 0
    local explicitRarities = {}
    for _, rarityId in ipairs(provenance.hatcher_source_rarities or {}) do
        explicitRarities[rarityId] = true
    end

    local enchanting = petsConfig.enchanting or {}
    local maxByRarity = enchanting.max_enchantments_by_rarity or {}
    local overwrite = payload.overwrite == true
    local clearLegacySource = payload.clearLegacySource ~= false
    local changed = 0
    local eligible = 0
    local skippedExisting = 0

    local function getRarityId(item)
        if item.huge == true then
            return "huge"
        end
        if type(item.rarity_id) == "string" and item.rarity_id ~= "" then
            return item.rarity_id
        end
        if type(item.rarity_override) == "string" and item.rarity_override ~= "" then
            return item.rarity_override
        end
        local petData = petsConfig.getPet and petsConfig.getPet(item.id, item.variant or "basic")
        return petData and petData.rarity_id or nil
    end

    local function isEligible(item)
        if type(item) ~= "table" or not isSpecialPetRecord(item) then
            return false
        end

        local rarityId = getRarityId(item)
        local maxEnchantments = tonumber(item.max_enchantments)
            or tonumber(maxByRarity[rarityId] or enchanting.default_max_enchantments)
            or 0
        return explicitRarities[rarityId] == true
            or (threshold > 0 and maxEnchantments >= threshold)
    end

    for _, item in pairs(items) do
        if isEligible(item) then
            eligible += 1
            if overwrite or type(item.hatcher_name) ~= "string" or item.hatcher_name == "" then
                item.hatcher_name = player.Name
                item.hatcher_user_id = player.UserId
                if clearLegacySource then
                    item.source = nil
                end
                changed += 1
            else
                skippedExisting += 1
            end
        end
    end

    if changed > 0 then
        if inventoryService and inventoryService._updateBucketFolders then
            inventoryService:_updateBucketFolders(player, "pets")
        end
        dataService:RequestSave(player, "backfill_pet_hatcher_provenance", {
            critical = true,
        })
    end

    return {
        ok = true,
        player = player.Name,
        eligible = eligible,
        changed = changed,
        skippedExisting = skippedExisting,
    }
end

function StudioSmokeTestService:_backfillPetPowerSourceOfTruth(player, payload)
    payload = type(payload) == "table" and payload or {}
    if not dataService:IsDataLoaded(player) then
        return {
            ok = false,
            error = "Player data is not loaded",
        }
    end

    local data = dataService:GetData(player)
    local bucket = data and data.Inventory and data.Inventory.pets
    local items = bucket and bucket.items
    if type(items) ~= "table" then
        return {
            ok = false,
            error = "Pet inventory is unavailable",
        }
    end

    local petsConfig = configLoader:LoadConfig("pets")
    local petProgressionConfig = configLoader:LoadConfig("pet_progression")
    local changed = 0
    local inspected = 0
    local missingConfig = {}

    local function clearField(item, key)
        if item[key] ~= nil then
            item[key] = nil
            return true
        end
        return false
    end

    local function stripPowerFields(item)
        local didChange = false
        for _, key in ipairs({
            "power",
            "Power",
            "health",
            "Health",
            "base_power",
            "BasePower",
            "base_health",
            "BaseHealth",
            "effective_power",
            "EffectivePower",
            "eternal_baseline_power",
            "EternalBaselinePower",
        }) do
            didChange = clearField(item, key) or didChange
        end

        if type(item.stats) == "table" then
            didChange = true
            item.stats = nil
        end
        if type(item.Stats) == "table" then
            didChange = true
            item.Stats = nil
        end

        return didChange
    end

    local function applyProgressionMetadata(item, petConfig)
        if type(item) ~= "table" or not isSpecialPetRecord(item) then
            if clearField(item, "level") then
                return true
            end
            local changedStack = false
            changedStack = clearField(item, "exp") or changedStack
            changedStack = clearField(item, "max_level") or changedStack
            changedStack = clearField(item, "xp_to_next_level") or changedStack
            return changedStack
        end

        local rarityId = item.huge == true and "huge" or item.rarity_id or petConfig.rarity_id
        local maxByRarity = petProgressionConfig.max_level_by_rarity or {}
        local maxLevel = math.max(
            1,
            math.floor(
                tonumber(maxByRarity[rarityId]) or petProgressionConfig.default_max_level or 1
            )
        )
        local oldLevel = item.level
        local oldExp = item.exp
        local oldMax = item.max_level
        local oldNext = item.xp_to_next_level
        item.level = math.clamp(math.floor(tonumber(item.level) or 1), 1, maxLevel)
        item.exp = math.max(0, math.floor(tonumber(item.exp) or 0))
        item.max_level = maxLevel
        if item.level < maxLevel then
            local curve = petProgressionConfig.xp_curve or {}
            local base = tonumber(curve.base) or 100
            local required
            if curve.type == "linear" then
                required = base + ((tonumber(curve.increment) or 0) * (item.level - 1))
            else
                required = base * ((tonumber(curve.growth) or 1) ^ (item.level - 1))
            end
            item.xp_to_next_level = math.max(1, math.floor(required))
        else
            item.xp_to_next_level = 0
        end

        return oldLevel ~= item.level
            or oldExp ~= item.exp
            or oldMax ~= item.max_level
            or oldNext ~= item.xp_to_next_level
    end

    for key, item in pairs(items) do
        if type(item) == "table" then
            inspected += 1
            local petData = petsConfig.getPet
                and petsConfig.getPet(item.id, item.variant or "basic")
            if not petData then
                table.insert(missingConfig, tostring(key))
            end

            local itemChanged = stripPowerFields(item)
            if petData then
                itemChanged = applyProgressionMetadata(item, petData) or itemChanged
                if item.rarity_id == nil and petData.rarity_id then
                    item.rarity_id = petData.rarity_id
                    itemChanged = true
                end
            end

            if itemChanged then
                changed += 1
            end
        end
    end

    if changed > 0 then
        if inventoryService and inventoryService._updateBucketFolders then
            inventoryService:_updateBucketFolders(player, "pets")
        end
        if inventoryService and inventoryService._updateEquippedFolders then
            inventoryService:_updateEquippedFolders(player, "pets")
        end
        dataService:RequestSave(player, "backfill_pet_power_source_of_truth", {
            critical = true,
        })
    end

    return {
        ok = true,
        player = player.Name,
        inspected = inspected,
        changed = changed,
        missingConfig = missingConfig,
    }
end

function StudioSmokeTestService:_checkEternalPowerSmoke(player)
    local playerPetsFolder = workspace:FindFirstChild("PlayerPets")
        and workspace.PlayerPets:FindFirstChild(player.Name)
    if not playerPetsFolder then
        return {
            ok = false,
            error = "Player pet models are not spawned",
        }
    end

    local rows = {}
    local strongestBasePower = 1
    local topTeamAverageBasePower = 1
    local basePowerValues = {}
    for _, petModel in ipairs(playerPetsFolder:GetChildren()) do
        if petModel:IsA("Model") then
            local basePowerValue = petModel:FindFirstChild("BasePower")
            local effectivePowerValue = petModel:FindFirstChild("EffectivePower")
            local eternalPercentValue = petModel:FindFirstChild("EternalPercent")
            local eternalBaselineValue = petModel:FindFirstChild("EternalBaselinePower")
            local basePower = tonumber(basePowerValue and basePowerValue.Value)
                or tonumber(petModel:GetAttribute("BasePower"))
                or 0
            local effectivePower = tonumber(effectivePowerValue and effectivePowerValue.Value)
                or tonumber(petModel:GetAttribute("EffectivePower"))
                or 0
            local eternalPercent = tonumber(eternalPercentValue and eternalPercentValue.Value)
                or tonumber(petModel:GetAttribute("EternalPercent"))
                or 0
            local eternalBaselinePower = tonumber(
                eternalBaselineValue and eternalBaselineValue.Value
            ) or tonumber(petModel:GetAttribute("EternalBaselinePower")) or 0

            if basePower > 0 then
                strongestBasePower = math.max(strongestBasePower, basePower)
                table.insert(basePowerValues, basePower)
            end
            table.insert(rows, {
                name = petModel.Name,
                basePower = basePower,
                effectivePower = effectivePower,
                eternalPercent = eternalPercent,
                eternalBaselinePower = eternalBaselinePower,
            })
        end
    end
    table.sort(basePowerValues, function(a, b)
        return a > b
    end)
    local limit = math.min(#basePowerValues, #rows)
    if limit > 0 then
        local total = 0
        for index = 1, limit do
            total += basePowerValues[index] or 0
        end
        topTeamAverageBasePower = math.max(1, total / limit)
    end

    local eternalCount = 0
    for _, row in ipairs(rows) do
        if row.eternalPercent > 0 then
            eternalCount += 1
            local expected = math.max(
                row.basePower,
                math.floor((topTeamAverageBasePower * row.eternalPercent / 100) + 0.5)
            )
            if row.effectivePower ~= expected then
                return {
                    ok = false,
                    error = string.format(
                        "Expected %s effective power %d, got %d",
                        row.name,
                        expected,
                        row.effectivePower
                    ),
                    strongestBasePower = strongestBasePower,
                    topTeamAverageBasePower = topTeamAverageBasePower,
                    rows = rows,
                }
            end
        end
    end

    if eternalCount == 0 then
        return {
            ok = false,
            error = "No equipped eternal pets found",
            strongestBasePower = strongestBasePower,
            topTeamAverageBasePower = topTeamAverageBasePower,
            rows = rows,
        }
    end

    return {
        ok = true,
        strongestBasePower = strongestBasePower,
        topTeamAverageBasePower = topTeamAverageBasePower,
        eternalCount = eternalCount,
        rows = rows,
    }
end

function StudioSmokeTestService:_beginEggProximity(player, payload)
    local eggType = payload.eggType or "basic_egg"
    local petsConfig = Locations.getConfig("pets")
    local eggSystemConfig = configLoader:LoadConfig("egg_system")
    local eggData = petsConfig.egg_sources[eggType]
    if not eggData then
        return {
            ok = false,
            error = "Unknown egg type: " .. tostring(eggType),
        }
    end

    local temporaryEggStand = nil
    local egg = findEggByType(eggType)
    if not egg and payload.setupTemporaryEggStand == true then
        temporaryEggStand = createTemporaryEggStand(player, eggType)
        egg = temporaryEggStand
    end
    local anchor = getEggAnchor(egg)
    if not anchor then
        if temporaryEggStand then
            temporaryEggStand:Destroy()
        end
        return {
            ok = false,
            error = "Egg anchor not found for " .. tostring(eggType),
        }
    end

    local data = dataService:GetData(player)
    if not data or not data.Inventory then
        return {
            ok = false,
            error = "Player data not loaded",
        }
    end

    local originalCurrency = dataService:GetCurrency(player, eggData.currency)
    local originalPetsBucket = deepCopy(data.Inventory.pets or { items = {} })
    local originalAutoSystems = deepCopy(data.Settings and data.Settings.AutoSystems or nil)
    local originalCounters = deepCopy(data.Stats and data.Stats.Counters or {})
    if type(payload.setupCounters) == "table" then
        for counterId, value in pairs(payload.setupCounters) do
            if type(counterId) == "string" then
                dataService:SetCounter(player, counterId, tonumber(value) or 0)
            end
        end
    end
    local eggCost = (petsConfig.getEggCost and petsConfig.getEggCost(eggType)) or eggData.cost
    local setupHatchCount = math.max(1, math.floor(tonumber(payload.setupHatchCount) or 1))
    local requiredCurrency = payload.setupCurrencyAmount
        or ((eggCost * setupHatchCount) + math.max(25, math.floor(eggCost * 0.1)))

    dataService:SetCurrency(player, eggData.currency, requiredCurrency, "egg_smoke_setup")
    if payload.setupPetInventoryEmpty == true then
        data.Inventory.pets = {
            items = {},
            used_slots = 0,
            total_slots = 0,
        }
        if inventoryService and inventoryService._updateBucketFolders then
            inventoryService:_updateBucketFolders(player, "pets")
        end
    end
    if payload.setupPetStorageAvailableSlots ~= nil then
        local petsBucket = data.Inventory.pets
        if not petsBucket then
            petsBucket = {
                items = {},
                used_slots = 0,
                total_slots = 0,
            }
            data.Inventory.pets = petsBucket
        end
        local availableSlots =
            math.max(0, math.floor(tonumber(payload.setupPetStorageAvailableSlots) or 0))
        local usedSlots = math.max(0, tonumber(petsBucket.used_slots) or 0)
        petsBucket.total_slots = usedSlots + availableSlots
        if inventoryService and inventoryService._updateBucketFolders then
            inventoryService:_updateBucketFolders(player, "pets")
        end
    end
    if payload.setupAutoDeleteFilters then
        if not autoTargetService then
            return {
                ok = false,
                error = "AutoTargetService is unavailable",
            }
        end
        autoTargetService:SetAutoDeleteFilters(player, payload.setupAutoDeleteFilters)
    end
    local originalAttributes = {}
    for _, attributeName in ipairs({
        "ForcePet",
        "ForceVariant",
        "AutoHatchUnlocked",
        "GoldenHatchUnlocked",
        "ChargedHatchUnlocked",
        "FastHatchUnlocked",
        "SkipHatchUnlocked",
        "MaxEggHatchCount",
    }) do
        local value = player:GetAttribute(attributeName)
        originalAttributes[attributeName] = {
            hadValue = value ~= nil,
            value = value,
        }
    end
    if payload.setupForceHatchPet or payload.setupForceHatchVariant then
        player:SetAttribute("ForcePet", payload.setupForceHatchPet)
        player:SetAttribute("ForceVariant", payload.setupForceHatchVariant or "basic")

        local EggService = require(ServerScriptService.Server.Services.EggService)
        EggService:SetTestHatchOverride(
            player,
            payload.setupForceHatchPet,
            payload.setupForceHatchVariant or "basic"
        )
    end
    if payload.setupAutoHatchUnlocked ~= nil then
        player:SetAttribute("AutoHatchUnlocked", payload.setupAutoHatchUnlocked == true)
    end
    if payload.setupGoldenModeUnlocked ~= nil then
        player:SetAttribute("GoldenHatchUnlocked", payload.setupGoldenModeUnlocked == true)
    end
    if payload.setupChargedModeUnlocked ~= nil then
        player:SetAttribute("ChargedHatchUnlocked", payload.setupChargedModeUnlocked == true)
    end
    if payload.setupFastHatchUnlocked ~= nil then
        player:SetAttribute("FastHatchUnlocked", payload.setupFastHatchUnlocked == true)
    end
    if payload.setupSkipHatchUnlocked ~= nil then
        player:SetAttribute("SkipHatchUnlocked", payload.setupSkipHatchUnlocked == true)
    end
    if payload.setupMaxHatchCount ~= nil then
        player:SetAttribute(
            "MaxEggHatchCount",
            math.max(1, math.floor(tonumber(payload.setupMaxHatchCount) or 1))
        )
    end

    local maxDistance = eggSystemConfig.proximity.max_distance
    local anchorPosition = anchor.Position

    sessions[player.UserId] = {
        eggType = eggType,
        currency = eggData.currency,
        cost = eggCost,
        originalCurrency = originalCurrency,
        originalPetsBucket = originalPetsBucket,
        originalPetCount = countPets(originalPetsBucket),
        originalAttributes = originalAttributes,
        originalAutoSystems = originalAutoSystems,
        originalCounters = originalCounters,
        temporaryEggStand = temporaryEggStand,
        farPosition = anchorPosition + Vector3.new(maxDistance + 80, 4, 0),
        nearPosition = anchorPosition + Vector3.new(0, 4, 0),
        cooldown = eggSystemConfig.cooldowns.purchase_cooldown or 0,
    }

    return {
        ok = true,
        eggType = eggType,
        currency = eggData.currency,
        cost = eggCost,
        maxDistance = maxDistance,
        originalCurrency = originalCurrency,
        originalPetCount = sessions[player.UserId].originalPetCount,
        currentCurrency = dataService:GetCurrency(player, eggData.currency),
        setupHatchCount = setupHatchCount,
    }
end

function StudioSmokeTestService:_moveEggProximity(player, payload)
    local session = sessions[player.UserId]
    if not session then
        return {
            ok = false,
            error = "Egg proximity smoke session has not started",
        }
    end

    local placement = payload.placement or "near"
    local position = placement == "far" and session.farPosition or session.nearPosition
    local success, errorMessage = movePlayer(player, position)
    return {
        ok = success,
        error = errorMessage,
        placement = placement,
    }
end

function StudioSmokeTestService:_getEggHatchHistory(player, payload)
    local EggService = require(ServerScriptService.Server.Services.EggService)
    return {
        ok = true,
        history = EggService:GetHatchHistory(player, payload and payload.limit or nil),
    }
end

function StudioSmokeTestService:_simulateEggHatch(player, payload)
    payload = type(payload) == "table" and payload or {}
    local eggType = payload.eggType or "basic_egg"
    local petsConfig = Locations.getConfig("pets")
    local eggData = petsConfig.egg_sources[eggType]
    if not eggData then
        return {
            ok = false,
            error = "Unknown egg type: " .. tostring(eggType),
        }
    end

    local data = dataService:GetData(player)
    if not data or not data.Inventory then
        return {
            ok = false,
            error = "Player data not loaded",
        }
    end

    local oldForcePet = player:GetAttribute("ForcePet")
    local oldForceVariant = player:GetAttribute("ForceVariant")
    local oldHatchLuckBonus = player:GetAttribute("HatchLuckBonus")
    local oldSecretHatchLuckBonus = player:GetAttribute("SecretHatchLuckBonus")
    if payload.forcePet ~= nil then
        player:SetAttribute("ForcePet", payload.forcePet)
    end
    if payload.forceVariant ~= nil then
        player:SetAttribute("ForceVariant", payload.forceVariant)
    end
    if payload.setupHatchLuckBonus ~= nil then
        player:SetAttribute("HatchLuckBonus", tonumber(payload.setupHatchLuckBonus) or 0)
    end
    if payload.setupSecretHatchLuckBonus ~= nil then
        player:SetAttribute(
            "SecretHatchLuckBonus",
            tonumber(payload.setupSecretHatchLuckBonus) or 0
        )
    end

    local beforeCurrency = dataService:GetCurrency(player, eggData.currency)
    local beforePetCount = countPets(data.Inventory and data.Inventory.pets)
    local beforeEggsHatched = dataService:GetCounter(player, "eggs_hatched")
    local EggService = require(ServerScriptService.Server.Services.EggService)
    local ok, simulation = pcall(function()
        return EggService:SimulateHatchBatch(player, {
            eggType = eggType,
            requestedCount = payload.requestedCount or 25,
            purchaseType = "SmokeSimulation",
            options = payload.options or {},
        })
    end)

    player:SetAttribute("ForcePet", oldForcePet)
    player:SetAttribute("ForceVariant", oldForceVariant)
    player:SetAttribute("HatchLuckBonus", oldHatchLuckBonus)
    player:SetAttribute("SecretHatchLuckBonus", oldSecretHatchLuckBonus)

    if not ok then
        return {
            ok = false,
            error = tostring(simulation),
        }
    end

    local afterData = dataService:GetData(player)
    return {
        ok = true,
        simulation = simulation,
        beforeCurrency = beforeCurrency,
        afterCurrency = dataService:GetCurrency(player, eggData.currency),
        beforePetCount = beforePetCount,
        afterPetCount = countPets(afterData.Inventory and afterData.Inventory.pets),
        beforeEggsHatched = beforeEggsHatched,
        afterEggsHatched = dataService:GetCounter(player, "eggs_hatched"),
        currency = eggData.currency,
    }
end

function StudioSmokeTestService:_hatchEggProximity(player, payload)
    local session = sessions[player.UserId]
    if not session then
        return {
            ok = false,
            error = "Egg proximity smoke session has not started",
        }
    end
    payload = payload or {}

    local EggService = require(ServerScriptService.Server.Services.EggService)
    local beforeCurrency = dataService:GetCurrency(player, session.currency)
    local data = dataService:GetData(player)
    local beforePetCount = countPets(data.Inventory and data.Inventory.pets)
    local beforeEggsHatched = dataService:GetCounter(player, "eggs_hatched")
    local hatchResult, hatchMessage
    local requestedCount = math.max(1, math.floor(tonumber(payload.requestedCount) or 1))
    if
        payload.batch == true
        or requestedCount ~= 1
        or payload.purchaseType == "Auto"
        or payload.autoSessionId ~= nil
    then
        hatchResult, hatchMessage = EggService:HandleEggPurchase(player, {
            eggType = session.eggType,
            requestedCount = requestedCount,
            purchaseType = payload.purchaseType or "SmokeBatch",
            options = payload.options or payload.hatchOptions or {},
            autoSessionId = payload.autoSessionId,
        })
    else
        if payload.options or payload.hatchOptions then
            hatchResult, hatchMessage = EggService:HandleEggPurchase(player, {
                eggType = session.eggType,
                requestedCount = requestedCount,
                purchaseType = payload.purchaseType or "Single",
                options = payload.options or payload.hatchOptions or {},
            })
        else
            hatchResult, hatchMessage =
                EggService:HandleEggPurchase(player, session.eggType, "Single")
        end
    end
    local afterData = dataService:GetData(player)

    return {
        ok = true,
        resultType = type(hatchResult),
        result = hatchResult,
        message = hatchMessage,
        beforeCurrency = beforeCurrency,
        afterCurrency = dataService:GetCurrency(player, session.currency),
        beforePetCount = beforePetCount,
        afterPetCount = countPets(afterData.Inventory and afterData.Inventory.pets),
        beforeEggsHatched = beforeEggsHatched,
        afterEggsHatched = dataService:GetCounter(player, "eggs_hatched"),
        currency = session.currency,
        cost = session.cost,
        cooldown = session.cooldown,
    }
end

function StudioSmokeTestService:_restoreEggProximity(player)
    local session = sessions[player.UserId]
    if not session then
        return {
            ok = true,
            restored = false,
        }
    end

    dataService:SetCurrency(player, session.currency, session.originalCurrency, "egg_smoke_restore")

    local data = dataService:GetData(player)
    if data and data.Inventory then
        data.Inventory.pets = deepCopy(session.originalPetsBucket)
        if inventoryService and inventoryService._updateBucketFolders then
            inventoryService:_updateBucketFolders(player, "pets")
        end
    end
    if data then
        data.Settings = data.Settings or {}
        data.Settings.AutoSystems = deepCopy(session.originalAutoSystems)
        data.Stats = data.Stats or {}
        data.Stats.Counters = deepCopy(session.originalCounters)
    end
    if settingsService and settingsService.ReplicateAutoSystemSettings then
        settingsService:ReplicateAutoSystemSettings(player)
    end

    for attributeName, record in pairs(session.originalAttributes or {}) do
        if record.hadValue then
            player:SetAttribute(attributeName, record.value)
        else
            player:SetAttribute(attributeName, nil)
        end
    end

    local EggService = require(ServerScriptService.Server.Services.EggService)
    EggService:SetTestHatchOverride(player, nil, nil)

    if session.temporaryEggStand and session.temporaryEggStand.Parent then
        session.temporaryEggStand:Destroy()
    end

    dataService:RequestSave(player, "egg_smoke_restore", { critical = true })
    sessions[player.UserId] = nil

    return {
        ok = true,
        restored = true,
        currency = session.currency,
        restoredCurrency = session.originalCurrency,
        restoredPetCount = session.originalPetCount,
    }
end

local function removeArrayValue(values, target)
    if type(values) ~= "table" then
        return {}
    end

    local result = {}
    for key, value in pairs(values) do
        if type(key) == "number" then
            if value ~= target then
                table.insert(result, value)
            end
        elseif key ~= target then
            result[key] = value
        end
    end
    return result
end

local function findTravelPad(sourceAreaId, targetZoneId)
    if not worldBindingService then
        return nil
    end

    for _, pad in ipairs(worldBindingService:GetTeleportPadsForArea(sourceAreaId)) do
        if pad:GetAttribute("TargetZoneId") == targetZoneId then
            return pad
        end
    end
    return nil
end

function StudioSmokeTestService:_beginTravelSmoke(player, payload)
    if not worldBindingService or not zoneService then
        return {
            ok = false,
            error = "Zone smoke dependencies are not loaded",
        }
    end

    local sourceAreaId = payload.sourceAreaId or "Spawn"
    local targetZoneId = payload.targetZoneId or "Meadow"
    local targetAreaId = worldBindingService:GetPrimaryAreaForZone(targetZoneId)
    if not targetAreaId then
        return {
            ok = false,
            error = "Target zone has no primary area: " .. tostring(targetZoneId),
        }
    end

    local pad = findTravelPad(sourceAreaId, targetZoneId)
    if not pad then
        return {
            ok = false,
            error = "TeleportPad not found from " .. tostring(sourceAreaId) .. " to " .. tostring(
                targetZoneId
            ),
        }
    end

    local data = dataService:GetData(player)
    if not data or not data.GameData then
        return {
            ok = false,
            error = "Player data not loaded",
        }
    end

    local originalUnlockedAreas = deepCopy(data.GameData.UnlockedAreas or {})
    data.GameData.UnlockedAreas = removeArrayValue(data.GameData.UnlockedAreas, targetAreaId)
    zoneService:GetUnlockedZones(player)

    local sourceCFrame = worldBindingService:GetSpawnCFrameForZone(sourceAreaId)
    if sourceCFrame then
        movePlayer(player, sourceCFrame.Position)
        worldBindingService:SetActiveArea(player, sourceAreaId)
    end

    travelSessions[player.UserId] = {
        sourceAreaId = sourceAreaId,
        targetZoneId = targetZoneId,
        targetAreaId = targetAreaId,
        pad = pad,
        originalUnlockedAreas = originalUnlockedAreas,
    }

    return {
        ok = true,
        sourceAreaId = sourceAreaId,
        targetZoneId = targetZoneId,
        targetAreaId = targetAreaId,
        pad = pad:GetFullName(),
        unlockedAreas = zoneService:GetUnlockedZones(player),
        activeArea = worldBindingService:GetActiveArea(player),
    }
end

function StudioSmokeTestService:_useTravelSmoke(player)
    local session = travelSessions[player.UserId]
    if not session then
        return {
            ok = false,
            error = "Travel smoke session has not started",
        }
    end

    local result = zoneService:TravelViaHook(player, session.pad)
    local rootPart = getRootPart(player)
    result.activeArea = worldBindingService:GetActiveArea(player)
    result.rootPosition = rootPart and rootPart.Position or nil
    return result
end

function StudioSmokeTestService:_unlockTravelSmoke(player)
    local session = travelSessions[player.UserId]
    if not session then
        return {
            ok = false,
            error = "Travel smoke session has not started",
        }
    end

    local result =
        zoneService:UnlockZone(player, session.targetZoneId, { bypassRequirements = true })
    result.unlockedAreas = zoneService:GetUnlockedZones(player)
    return result
end

function StudioSmokeTestService:_restoreTravelSmoke(player)
    local session = travelSessions[player.UserId]
    if not session then
        return {
            ok = true,
            restored = false,
        }
    end

    local data = dataService:GetData(player)
    if data then
        data.GameData = data.GameData or {}
        data.GameData.UnlockedAreas = deepCopy(session.originalUnlockedAreas)
    end

    local sourceCFrame = worldBindingService:GetSpawnCFrameForZone(session.sourceAreaId)
    if sourceCFrame then
        movePlayer(player, sourceCFrame.Position)
        worldBindingService:SetActiveArea(player, session.sourceAreaId)
    end

    dataService:RequestSave(player, "travel_smoke_restore", { critical = true })
    travelSessions[player.UserId] = nil

    return {
        ok = true,
        restored = true,
        sourceAreaId = session.sourceAreaId,
        targetZoneId = session.targetZoneId,
    }
end

local function raycastDownFrom(position, excludeInstances)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = excludeInstances or {}
    params.IgnoreWater = true
    return workspace:Raycast(position, Vector3.new(0, -500, 0), params)
end

function StudioSmokeTestService:_checkSpawnSafetySmoke(player, payload)
    if not worldBindingService or not zoneService then
        return {
            ok = false,
            error = "Zone smoke dependencies are not loaded",
        }
    end

    local zoneId = payload.zoneId or "Spawn"
    local placed, placeError, areaId = zoneService:PlacePlayerAtZoneSpawn(player, zoneId)
    if not placed then
        return {
            ok = false,
            error = placeError or "Failed to place player at zone spawn",
        }
    end

    task.wait(0.2)

    local rootPart = getRootPart(player)
    if not rootPart then
        return {
            ok = false,
            error = "HumanoidRootPart not ready",
        }
    end

    local result = raycastDownFrom(rootPart.Position, { player.Character })
    if not result then
        return {
            ok = false,
            error = "No floor found below spawn position",
            areaId = areaId,
            rootPosition = rootPart.Position,
        }
    end

    local floorDistance = rootPart.Position.Y - result.Position.Y
    local verticalVelocity = rootPart.AssemblyLinearVelocity.Y

    return {
        ok = true,
        areaId = areaId,
        rootPosition = rootPart.Position,
        floorPosition = result.Position,
        floorDistance = floorDistance,
        verticalVelocity = verticalVelocity,
        activeArea = worldBindingService:GetActiveArea(player),
    }
end

function StudioSmokeTestService:_runPhase2ProgressionSmoke(player, payload)
    if not zoneService or not upgradeService then
        return {
            ok = false,
            error = "Phase 2 smoke dependencies are not loaded",
        }
    end

    local targetZoneId = payload.targetZoneId or "Meadow"
    local targetAreaId = worldBindingService:GetPrimaryAreaForZone(targetZoneId) or targetZoneId
    local areasConfig = configLoader:LoadConfig("areas")
    local inventoryConfig = configLoader:LoadConfig("inventory")
    local targetZone = areasConfig.zones[targetZoneId]
    local unlock = targetZone and targetZone.unlock or {}
    local unlockCurrency = unlock.currency or "crystals"
    local unlockCost = tonumber(unlock.cost) or 0

    local data = dataService:GetData(player)
    if not data then
        return {
            ok = false,
            error = "Player data not loaded",
        }
    end

    local original = {
        coins = dataService:GetCurrency(player, "coins"),
        crystals = dataService:GetCurrency(player, "crystals"),
        upgrades = deepCopy(data.Upgrades or {}),
        unlockedAreas = deepCopy(data.GameData and data.GameData.UnlockedAreas or {}),
        petsBucket = deepCopy(data.Inventory and data.Inventory.pets or nil),
    }

    local function restore()
        dataService:SetCurrency(player, "coins", original.coins, "phase2_smoke_restore")
        dataService:SetCurrency(player, "crystals", original.crystals, "phase2_smoke_restore")

        data.Upgrades = deepCopy(original.upgrades)
        data.GameData = data.GameData or {}
        data.GameData.UnlockedAreas = deepCopy(original.unlockedAreas)
        data.Inventory = data.Inventory or {}
        if original.petsBucket then
            data.Inventory.pets = deepCopy(original.petsBucket)
        end

        if inventoryService then
            if inventoryService._updateBucketFolders then
                inventoryService:_updateBucketFolders(player, "pets")
            end
            if inventoryService._updateEquippedFolders then
                inventoryService:_updateEquippedFolders(player, "pets")
            end
        end
        dataService:RequestSave(player, "phase2_smoke_restore", { critical = true })
    end

    local ok, result = pcall(function()
        data.GameData = data.GameData or {}
        data.GameData.UnlockedAreas = removeArrayValue(data.GameData.UnlockedAreas, targetAreaId)
        zoneService:GetUnlockedZones(player)

        dataService:SetCurrency(player, unlockCurrency, 0, "phase2_smoke_setup")
        local lockedUnlock = zoneService:UnlockZone(player, targetZoneId)
        if lockedUnlock.ok or lockedUnlock.reason ~= "insufficient_currency" then
            error("Expected insufficient currency before zone unlock")
        end
        if not lockedUnlock.unlock or lockedUnlock.unlock.cost ~= unlockCost then
            error("Expected locked zone response to include unlock requirement")
        end

        dataService:SetCurrency(player, unlockCurrency, unlockCost, "phase2_smoke_setup")
        local paidUnlock = zoneService:UnlockZone(player, targetZoneId)
        if not paidUnlock.ok then
            error("Expected paid zone unlock to succeed: " .. tostring(paidUnlock.reason))
        end

        local equipCost = upgradeService:GetUpgradeCost(player, "pet_equip_slots")
        dataService:SetCurrency(player, equipCost.currency, equipCost.amount, "phase2_smoke_setup")
        local equipPurchase = upgradeService:PurchaseUpgrade(player, "pet_equip_slots")
        if not equipPurchase.ok then
            error(
                "Expected pet equip upgrade purchase to succeed: " .. tostring(equipPurchase.reason)
            )
        end

        local basePetSlots = inventoryConfig.equipped.pets.slots
        local maxPetSlots = inventoryService:_getMaxEquippedSlots(player, "pets", basePetSlots)
        if maxPetSlots ~= basePetSlots + 1 then
            error("Expected pet equip slots to increase by 1")
        end

        local storageCost = upgradeService:GetUpgradeCost(player, "pet_storage")
        local beforeStorageSlots = data.Inventory.pets.total_slots
        dataService:SetCurrency(
            player,
            storageCost.currency,
            storageCost.amount,
            "phase2_smoke_setup"
        )
        local storagePurchase = upgradeService:PurchaseUpgrade(player, "pet_storage")
        if not storagePurchase.ok then
            error(
                "Expected pet storage upgrade purchase to succeed: "
                    .. tostring(storagePurchase.reason)
            )
        end

        local afterStorageSlots = data.Inventory.pets.total_slots
        if afterStorageSlots <= beforeStorageSlots then
            error("Expected pet storage slots to increase")
        end

        local crystalValueCost = upgradeService:GetUpgradeCost(player, "crystal_value")
        dataService:SetCurrency(
            player,
            crystalValueCost.currency,
            crystalValueCost.amount,
            "phase2_smoke_setup"
        )
        local crystalValuePurchase = upgradeService:PurchaseUpgrade(player, "crystal_value")
        if not crystalValuePurchase.ok then
            error(
                "Expected crystal value upgrade purchase to succeed: "
                    .. tostring(crystalValuePurchase.reason)
            )
        end

        local baseCrystalReward = 100
        local resolvedCrystalReward = economyService:ResolveRewardAmount(baseCrystalReward, {
            player = player,
            kind = "breakable_reward",
            currency = "crystals",
            source = "Phase2ProgressionSmoke",
        })
        if resolvedCrystalReward <= baseCrystalReward then
            error("Expected crystal value upgrade to increase resolved crystal rewards")
        end

        return {
            ok = true,
            targetZoneId = targetZoneId,
            targetAreaId = targetAreaId,
            unlockCurrency = unlockCurrency,
            unlockCost = unlockCost,
            paidUnlock = paidUnlock,
            equipLevel = upgradeService:GetUpgradeLevel(player, "pet_equip_slots"),
            maxPetSlots = maxPetSlots,
            storageLevel = upgradeService:GetUpgradeLevel(player, "pet_storage"),
            beforeStorageSlots = beforeStorageSlots,
            afterStorageSlots = afterStorageSlots,
            crystalValueLevel = upgradeService:GetUpgradeLevel(player, "crystal_value"),
            baseCrystalReward = baseCrystalReward,
            resolvedCrystalReward = resolvedCrystalReward,
        }
    end)

    restore()

    if not ok then
        return {
            ok = false,
            error = tostring(result),
            restored = true,
        }
    end

    result.restored = true
    return result
end

function StudioSmokeTestService:_runMeadowBreakableSmoke(player, payload)
    payload = payload or {}
    if not (zoneService and worldBindingService and breakableSpawner and economyService) then
        return {
            ok = false,
            error = "Meadow breakable smoke dependencies are not loaded",
        }
    end

    local sourceAreaId = payload.sourceAreaId or "Spawn"
    local targetZoneId = payload.targetZoneId or "Meadow"
    local targetAreaId = worldBindingService:GetPrimaryAreaForZone(targetZoneId) or targetZoneId
    local breakableId = payload.breakableId or "BigBlueCrystal"
    local data = dataService:GetData(player)
    if not data then
        return {
            ok = false,
            error = "Player data not loaded",
        }
    end

    local crystalsRoot = workspace:FindFirstChild("Game")
        and workspace.Game:FindFirstChild("Breakables")
        and workspace.Game.Breakables:FindFirstChild("Crystals")
    local worldFolder = crystalsRoot and crystalsRoot:FindFirstChild(targetAreaId)
    if not worldFolder then
        return {
            ok = false,
            error = "Missing breakable area folder: " .. tostring(targetAreaId),
        }
    end

    local currentItems = worldFolder:FindFirstChild("CurrentItems")
    local original = {
        coins = dataService:GetCurrency(player, "coins"),
        crystals = dataService:GetCurrency(player, "crystals"),
        upgrades = deepCopy(data.Upgrades or {}),
        unlockedAreas = deepCopy(data.GameData and data.GameData.UnlockedAreas or {}),
        activeArea = worldBindingService:GetActiveArea(player),
        breakablesBroken = dataService:GetCounter(player, "breakables_broken"),
        currentItems = currentItems and currentItems.Value or nil,
    }

    local spawnedModel
    local function restore()
        if spawnedModel and spawnedModel.Parent then
            spawnedModel:Destroy()
            task.wait(0.1)
        end

        dataService:SetCurrency(player, "coins", original.coins, "meadow_breakable_smoke_restore")
        dataService:SetCurrency(
            player,
            "crystals",
            original.crystals,
            "meadow_breakable_smoke_restore"
        )
        data.Upgrades = deepCopy(original.upgrades)
        data.GameData = data.GameData or {}
        data.GameData.UnlockedAreas = deepCopy(original.unlockedAreas)
        dataService:SetCounter(player, "breakables_broken", original.breakablesBroken)

        if currentItems and original.currentItems ~= nil then
            currentItems.Value = original.currentItems
        end

        zoneService:PlacePlayerAtZoneSpawn(player, original.activeArea or sourceAreaId)
        dataService:RequestSave(player, "meadow_breakable_smoke_restore", { critical = true })
    end

    local ok, result = pcall(function()
        data.GameData = data.GameData or {}
        data.GameData.UnlockedAreas = removeArrayValue(data.GameData.UnlockedAreas, targetAreaId)
        zoneService:GetUnlockedZones(player)

        local unlock = zoneService:UnlockZone(player, targetZoneId, { bypassRequirements = true })
        if not unlock.ok then
            error("Expected bypass zone unlock to succeed: " .. tostring(unlock.reason))
        end

        local placed = zoneService:PlacePlayerAtZoneSpawn(player, sourceAreaId)
        if not placed then
            error("Failed to place player at " .. tostring(sourceAreaId))
        end

        local pad = findTravelPad(sourceAreaId, targetZoneId)
        if not pad then
            error(
                "TeleportPad not found from "
                    .. tostring(sourceAreaId)
                    .. " to "
                    .. tostring(targetZoneId)
            )
        end

        local travel = zoneService:TravelViaHook(player, pad)
        if not travel.ok then
            error("Expected travel to Meadow to succeed: " .. tostring(travel.reason))
        end
        if travel.targetAreaId ~= targetAreaId then
            error("Travel reached wrong area: " .. tostring(travel.targetAreaId))
        end

        data.Upgrades = data.Upgrades or {}
        data.Upgrades.crystal_value = 1

        local model, spawnError =
            breakableSpawner:SpawnBreakableForStudioSmoke(targetAreaId, breakableId)
        if not model then
            error("Expected deterministic Meadow breakable spawn: " .. tostring(spawnError))
        end
        spawnedModel = model

        local currency = tostring(model:GetAttribute("Currency") or "crystals")
        local baseValue = tonumber(model:GetAttribute("Value")) or 0
        local maxHp = tonumber(model:GetAttribute("MaxHP")) or 0
        if model:GetAttribute("CrystalName") ~= breakableId then
            error("Spawned wrong breakable: " .. tostring(model:GetAttribute("CrystalName")))
        end
        if maxHp <= 0 or baseValue <= 0 then
            error("Spawned breakable has invalid gameplay attributes")
        end

        local beforeCurrency = dataService:GetCurrency(player, currency)
        local beforeCounter = dataService:GetCounter(player, "breakables_broken")
        local expectedReward = economyService:ResolveRewardAmount(baseValue, {
            player = player,
            kind = "breakable_reward",
            currency = currency,
            breakableId = model:GetAttribute("BreakableId"),
            source = "BreakableSpawner",
        })

        local contrib = model:FindFirstChild("Contrib")
        if not contrib then
            error("Spawned breakable is missing Contrib folder")
        end
        local contribution = Instance.new("NumberValue")
        contribution.Name = tostring(player.UserId)
        contribution.Value = maxHp
        contribution.Parent = contrib

        model:SetAttribute("HP", 0)
        local deadline = os.clock() + 8
        repeat
            task.wait(0.1)
        until not model.Parent or os.clock() >= deadline

        if model.Parent then
            error("Breakable did not destroy after HP reached zero")
        end
        spawnedModel = nil

        local afterCurrency = dataService:GetCurrency(player, currency)
        local afterCounter = dataService:GetCounter(player, "breakables_broken")
        local currencyDelta = afterCurrency - beforeCurrency
        if currencyDelta ~= expectedReward then
            error(
                string.format(
                    "Expected %d %s reward, got %d",
                    expectedReward,
                    currency,
                    currencyDelta
                )
            )
        end
        if afterCounter ~= beforeCounter + 1 then
            error(
                string.format(
                    "Expected breakables_broken %d -> %d, got %d",
                    beforeCounter,
                    beforeCounter + 1,
                    afterCounter
                )
            )
        end

        return {
            ok = true,
            sourceAreaId = sourceAreaId,
            targetZoneId = targetZoneId,
            targetAreaId = targetAreaId,
            breakableId = breakableId,
            currency = currency,
            baseValue = baseValue,
            expectedReward = expectedReward,
            currencyDelta = currencyDelta,
            beforeCurrency = beforeCurrency,
            afterCurrency = afterCurrency,
            counterBefore = beforeCounter,
            counterAfter = afterCounter,
            maxHp = maxHp,
            activeArea = worldBindingService:GetActiveArea(player),
        }
    end)

    restore()

    if not ok then
        return {
            ok = false,
            error = tostring(result),
            restored = true,
        }
    end

    result.restored = true
    return result
end

local function findPortalForZone(sourceZoneId, targetZoneId)
    if not worldBindingService then
        return nil
    end

    for _, portal in ipairs(worldBindingService:GetPortalsForZone(sourceZoneId)) do
        if portal:GetAttribute("TargetZoneId") == targetZoneId then
            return portal
        end
    end
    return nil
end

local function destroySyntheticExpansionArtifacts()
    local syntheticRoot = workspace:FindFirstChild("SyntheticMap")
    if syntheticRoot and syntheticRoot:GetAttribute("GeneratedByWorldBindingService") then
        syntheticRoot:Destroy()
    end

    local crystals = workspace:FindFirstChild("Game")
        and workspace.Game:FindFirstChild("Breakables")
        and workspace.Game.Breakables:FindFirstChild("Crystals")
    local testFolder = crystals and crystals:FindFirstChild("CrystalCavern")
    if testFolder then
        testFolder:Destroy()
    end
end

local function snapshotWorkspaceMarkers()
    local snapshots = {}
    for tagName in pairs(configLoader:LoadConfig("markers").tags or {}) do
        for _, instance in ipairs(CollectionService:GetTagged(tagName)) do
            if instance:IsDescendantOf(workspace) and not snapshots[instance] then
                local snapshot = {
                    attributes = instance:GetAttributes(),
                }
                if instance:IsA("BasePart") then
                    snapshot.basePart = {
                        CFrame = instance.CFrame,
                        Size = instance.Size,
                        Transparency = instance.Transparency,
                        CanCollide = instance.CanCollide,
                        CanTouch = instance.CanTouch,
                        CanQuery = instance.CanQuery,
                        Color = instance.Color,
                        Material = instance.Material,
                    }
                end
                snapshots[instance] = snapshot
            end
        end
    end
    return snapshots
end

local function restoreWorkspaceMarkers(snapshots)
    for instance, snapshot in pairs(snapshots or {}) do
        if instance.Parent then
            local currentAttributes = instance:GetAttributes()
            for key in pairs(currentAttributes) do
                if snapshot.attributes[key] == nil then
                    instance:SetAttribute(key, nil)
                end
            end
            for key, value in pairs(snapshot.attributes) do
                instance:SetAttribute(key, value)
            end

            if snapshot.basePart and instance:IsA("BasePart") then
                instance.CFrame = snapshot.basePart.CFrame
                instance.Size = snapshot.basePart.Size
                instance.Transparency = snapshot.basePart.Transparency
                instance.CanCollide = snapshot.basePart.CanCollide
                instance.CanTouch = snapshot.basePart.CanTouch
                instance.CanQuery = snapshot.basePart.CanQuery
                instance.Color = snapshot.basePart.Color
                instance.Material = snapshot.basePart.Material
            end
        end
    end
end

function StudioSmokeTestService:_runSyntheticExpansionSmoke(player, payload)
    payload = payload or {}
    if not worldBindingService or not zoneService then
        return {
            ok = false,
            error = "Synthetic expansion dependencies are not loaded",
        }
    end

    local data = dataService:GetData(player)
    if not data then
        return {
            ok = false,
            error = "Player data not loaded",
        }
    end

    local original = {
        areasConfig = worldBindingService._areasConfig,
        breakablesConfig = worldBindingService._breakablesConfig,
        mapMode = worldBindingService._mapMode,
        zoneAreasConfig = zoneService._areasConfig,
        unlockedAreas = deepCopy(data.GameData and data.GameData.UnlockedAreas or {}),
        activeArea = worldBindingService:GetActiveArea(player),
        markerSnapshots = snapshotWorkspaceMarkers(),
    }

    local extendedAreas = deepCopy(original.areasConfig)
    extendedAreas.zones = extendedAreas.zones or {}
    extendedAreas.zones.crystal_world = {
        id = "crystal_world",
        kind = "world",
        display_name = "Crystal World",
        order = 2,
        primary_area = "CrystalCavern",
    }
    extendedAreas.zones.crystal_island = {
        id = "crystal_island",
        kind = "island",
        parent = "crystal_world",
        display_name = "Crystal Island",
        order = 1,
        primary_area = "CrystalCavern",
    }
    extendedAreas.zones.CrystalCavern = {
        id = "CrystalCavern",
        kind = "area",
        parent = "crystal_island",
        display_name = "Crystal Cavern",
        order = 3,
        unlock = {
            required_zone = "Spawn",
            unlocked_by_default = false,
            currency = "crystals",
            cost = 250,
        },
        boosts = {
            crystals = 1.25,
        },
        synthetic = {
            center = { x = 440, y = 0, z = 0 },
            size = { x = 160, y = 4, z = 160 },
            floor_y = 0,
            spawn_position = { x = 440, y = 4, z = 0 },
            egg_stands = {},
        },
    }

    local extendedBreakables = deepCopy(original.breakablesConfig)
    extendedBreakables.worlds = extendedBreakables.worlds or {}
    extendedBreakables.worlds.CrystalCavern = {
        max = 3,
        interval = 30,
        spawn_area = {
            name = "SpawnArea",
            size = { x = 120, y = 1, z = 120 },
            position = { x = 440, y = 0, z = 0 },
        },
        spawn_settings = {
            upright = true,
            surface_y = 0,
            use_spawner_bounds = true,
            spawn_area_margin = 16,
            spawn_center = { x = 440, z = 0 },
            spawn_radius = 48,
            spawn_exclusion_radius = 20,
            embed_ratio = 0,
            min_distance = 18,
            spawn_attempts = 20,
            respawn_min_seconds = 15,
            respawn_max_seconds = 90,
        },
        spawn_table = {
            { name = "MediumBlueCrystal", weight = 4 },
            { name = "BigBlueCrystal", weight = 1 },
        },
    }

    local ok, result = pcall(function()
        destroySyntheticExpansionArtifacts()
        worldBindingService._areasConfig = extendedAreas
        worldBindingService._breakablesConfig = extendedBreakables
        worldBindingService._mapMode = "synthetic"
        zoneService._areasConfig = extendedAreas
        worldBindingService:RebuildBindings()

        local portal = findPortalForZone("spawn_world", "crystal_world")
        if not portal then
            error("Expected synthetic cross-world portal from spawn_world to crystal_world")
        end

        local spawnZones = worldBindingService:GetSpawnZonesForArea("CrystalCavern")
        if #spawnZones == 0 then
            error("Expected synthetic CrystalCavern SpawnZone")
        end

        local unlock =
            zoneService:UnlockZone(player, "crystal_world", { bypassRequirements = true })
        if not unlock.ok or unlock.areaId ~= "CrystalCavern" then
            error("Expected synthetic crystal_world unlock to target CrystalCavern")
        end

        local placed = zoneService:PlacePlayerAtZoneSpawn(player, "Spawn")
        if not placed then
            error("Failed to place player at Spawn before synthetic portal travel")
        end

        local travel = zoneService:TravelViaHook(player, portal)
        if not travel.ok then
            error(
                "Expected synthetic cross-world portal travel to succeed: "
                    .. tostring(travel.reason)
            )
        end
        if travel.targetAreaId ~= "CrystalCavern" then
            error("Synthetic portal reached wrong area: " .. tostring(travel.targetAreaId))
        end

        return {
            ok = true,
            sourceZoneId = "spawn_world",
            targetZoneId = "crystal_world",
            targetAreaId = travel.targetAreaId,
            portal = portal:GetFullName(),
            spawnZoneCount = #spawnZones,
            activeArea = worldBindingService:GetActiveArea(player),
        }
    end)

    data.GameData = data.GameData or {}
    data.GameData.UnlockedAreas = deepCopy(original.unlockedAreas)
    worldBindingService._areasConfig = original.areasConfig
    worldBindingService._breakablesConfig = original.breakablesConfig
    worldBindingService._mapMode = original.mapMode
    zoneService._areasConfig = original.zoneAreasConfig
    restoreWorkspaceMarkers(original.markerSnapshots)
    destroySyntheticExpansionArtifacts()
    worldBindingService:RebuildBindings()
    zoneService:PlacePlayerAtZoneSpawn(player, original.activeArea or "Spawn")
    dataService:RequestSave(player, "synthetic_expansion_smoke_restore", { critical = true })

    if not ok then
        return {
            ok = false,
            error = tostring(result),
            restored = true,
        }
    end

    result.restored = true
    return result
end

function StudioSmokeTestService:_runPhase3StatsSmoke(player, payload)
    payload = payload or {}
    if not (statsService and petIndexService and achievementsService and leaderboardService) then
        return {
            ok = false,
            error = "Phase 3 smoke dependencies are not loaded",
        }
    end

    local data = dataService:GetData(player)
    if not data then
        return {
            ok = false,
            error = "Player data not loaded",
        }
    end

    local firstPet = payload.firstPet or "bear"
    local secondPet = payload.secondPet or "bunny"
    local variant = payload.variant or "basic"

    local original = {
        coins = dataService:GetCurrency(player, "coins"),
        gems = dataService:GetCurrency(player, "gems"),
        crystals = dataService:GetCurrency(player, "crystals"),
        petsBucket = deepCopy(data.Inventory and data.Inventory.pets or nil),
        petIndex = deepCopy(data.PetIndex or nil),
        achievements = deepCopy(data.Achievements or nil),
        counters = deepCopy(data.Stats and data.Stats.Counters or {}),
    }

    local function restore()
        dataService:SetCurrency(player, "coins", original.coins, "phase3_smoke_restore")
        dataService:SetCurrency(player, "gems", original.gems, "phase3_smoke_restore")
        dataService:SetCurrency(player, "crystals", original.crystals, "phase3_smoke_restore")

        data.Inventory = data.Inventory or {}
        if original.petsBucket then
            data.Inventory.pets = deepCopy(original.petsBucket)
        end
        data.PetIndex = deepCopy(original.petIndex)
        data.Achievements = deepCopy(original.achievements)
        data.Stats = data.Stats or {}
        data.Stats.Counters = deepCopy(original.counters)

        if inventoryService and inventoryService._updateBucketFolders then
            inventoryService:_updateBucketFolders(player, "pets")
        end
        if leaderboardService then
            leaderboardService:RefreshPlayer(player)
        end

        dataService:RequestSave(player, "phase3_smoke_restore", { critical = true })
    end

    local ok, result = pcall(function()
        data.PetIndex = {
            Discovered = {},
            Milestones = {},
        }
        data.Achievements = {
            Completed = {},
        }
        data.Stats = data.Stats or {}
        data.Stats.Counters = data.Stats.Counters or {}
        data.Stats.Counters.distinct_pets = 0
        data.Stats.Counters.eggs_hatched = 0
        data.Stats.Counters.breakables_broken = 0

        local firstUid = inventoryService:AddItem(player, "pets", {
            id = firstPet,
            variant = variant,
            obtained_at = os.time(),
        })
        if not firstUid then
            error("Expected first pet add to succeed")
        end

        local duplicateUid = inventoryService:AddItem(player, "pets", {
            id = firstPet,
            variant = variant,
            obtained_at = os.time(),
        })
        if not duplicateUid then
            error("Expected duplicate pet stack add to succeed")
        end

        local secondUid = inventoryService:AddItem(player, "pets", {
            id = secondPet,
            variant = variant,
            obtained_at = os.time(),
        })
        if not secondUid then
            error("Expected second distinct pet add to succeed")
        end

        local indexSnapshot = petIndexService:GetIndex(player)
        if indexSnapshot.count ~= 2 then
            error("Expected pet index count to be 2, got " .. tostring(indexSnapshot.count))
        end
        if dataService:GetCounter(player, "distinct_pets") ~= 2 then
            error("Expected distinct_pets counter to be 2")
        end
        if not indexSnapshot.milestones.first_friend then
            error("Expected first pet index milestone to complete")
        end

        local gemsAfterIndex = dataService:GetCurrency(player, "gems")

        statsService:Set(player, "eggs_hatched", 1)
        achievementsService:EvaluateAll(player)

        local achievementState = achievementsService:GetAchievements(player)
        local eggAchievement = achievementState.eggs_hatched
        if not eggAchievement or not eggAchievement.completed.eggs_1 then
            error("Expected eggs_hatched achievement tier eggs_1 to complete")
        end

        leaderboardService:RefreshPlayer(player)
        local board = leaderboardService:GetLiveLeaderboard("eggs_hatched", 10)
        if not board or #board == 0 then
            error("Expected live eggs_hatched leaderboard entry")
        end

        local foundPlayer = false
        for _, entry in ipairs(board) do
            if entry.userId == player.UserId and entry.value == 1 then
                foundPlayer = true
                break
            end
        end
        if not foundPlayer then
            error("Expected player to appear on eggs_hatched leaderboard with value 1")
        end

        return {
            ok = true,
            firstPet = firstPet,
            secondPet = secondPet,
            variant = variant,
            indexCount = indexSnapshot.count,
            distinctPets = dataService:GetCounter(player, "distinct_pets"),
            indexMilestone = indexSnapshot.milestones.first_friend ~= nil,
            eggsAchievement = eggAchievement.completed.eggs_1 ~= nil,
            gemsAfterIndex = gemsAfterIndex,
            gemsAfterAchievements = dataService:GetCurrency(player, "gems"),
            leaderboardEntries = #board,
        }
    end)

    restore()

    if not ok then
        return {
            ok = false,
            error = tostring(result),
            restored = true,
        }
    end

    result.restored = true
    return result
end

return StudioSmokeTestService
