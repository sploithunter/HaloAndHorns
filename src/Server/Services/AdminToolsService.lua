local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Signals = require(ReplicatedStorage.Shared.Network.Signals)
local PetInventoryView = require(ReplicatedStorage.Shared.Inventory.PetInventoryView)

local AdminToolsService = {}
AdminToolsService.__index = AdminToolsService

function AdminToolsService.new()
    local self = setmetatable({}, AdminToolsService)
    self._logger = nil
    self._adminService = nil
    self._dataService = nil
    self._inventoryService = nil
    self._configLoader = nil
    self._eventService = nil
    self._zoneService = nil
    self._petGrantService = nil
    self._hatchEntitlementService = nil
    self._petsConfig = nil
    self._inventoryConfig = nil
    self._eggSystemConfig = nil
    return self
end

function AdminToolsService:Init()
    self._logger = self._modules.Logger
    self._adminService = self._modules.AdminService
    self._dataService = self._modules.DataService
    self._inventoryService = self._modules.InventoryService
    self._configLoader = self._modules.ConfigLoader
    self._eventService = self._modules.EventService
    self._zoneService = self._modules.ZoneService
    self._petGrantService = self._modules.PetGrantService
    self._hatchEntitlementService = self._modules.HatchEntitlementService

    self._petsConfig = self._configLoader:LoadConfig("pets")
    self._inventoryConfig = self._configLoader:LoadConfig("inventory")
    self._eggSystemConfig = self._configLoader:LoadConfig("egg_system")

    Signals.Admin_GetPlayerSnapshot.OnServerEvent:Connect(function(player, data)
        self:_handleSnapshot(player, data)
    end)

    Signals.Admin_ForceSave.OnServerEvent:Connect(function(player, data)
        self:_handleForceSave(player, data)
    end)

    Signals.Admin_GrantPet.OnServerEvent:Connect(function(player, data)
        self:_handleGrantPet(player, data)
    end)
    Signals.Admin_RetirePet.OnServerEvent:Connect(function(player, data)
        self:_handleRetirePet(player, data)
    end)

    Signals.Admin_ResetPets.OnServerEvent:Connect(function(player, data)
        self:_handleResetPets(player, data)
    end)

    Signals.Admin_ResetToBeginning.OnServerEvent:Connect(function(player, data)
        self:_handleResetToBeginning(player, data)
    end)

    Signals.Admin_SetZoneLock.OnServerEvent:Connect(function(player, data)
        self:_handleSetZoneLock(player, data)
    end)

    Signals.Admin_SetHatchEntitlement.OnServerEvent:Connect(function(player, data)
        self:_handleSetHatchEntitlement(player, data)
    end)

    Signals.Admin_SpawnEnemy.OnServerEvent:Connect(function(player, data)
        self:_handleSpawnEnemy(player, data)
    end)

    Signals.Admin_RequestHatchHistory.OnServerEvent:Connect(function(player, data)
        self:_handleHatchHistory(player, data)
    end)

    Signals.Admin_RequestHatchSimulation.OnServerEvent:Connect(function(player, data)
        self:_handleHatchSimulation(player, data)
    end)

    Signals.Admin_EventCommand.OnServerEvent:Connect(function(player, data)
        self:_handleEventCommand(player, data)
    end)

    self._logger:Info("AdminToolsService initialized")
end

function AdminToolsService:_handleSpawnEnemy(adminPlayer, data)
    data = type(data) == "table" and data or {}
    local targetPlayer, errorMessage = self:_resolveTarget(adminPlayer, "globalEffects", data)
    if not targetPlayer then
        self:_sendResult(
            adminPlayer,
            { kind = "spawn_enemy", success = false, message = errorMessage }
        )
        return
    end

    local enemyService = _G.RBXTemplateServices and _G.RBXTemplateServices:Get("EnemyService")
    if not enemyService then
        self:_sendResult(
            adminPlayer,
            { kind = "spawn_enemy", success = false, message = "EnemyService unavailable" }
        )
        return
    end

    local result = enemyService:SpawnEnemy(targetPlayer, data.enemy or data.enemyId)
    local ok = result and result.ok == true
    self:_sendResult(adminPlayer, {
        kind = "spawn_enemy",
        success = ok,
        message = ok
                and ("Spawned " .. tostring(result.enemyId) .. " (hp " .. tostring(result.hp) .. ")")
            or ("Spawn failed: " .. tostring(result and result.reason or "no result")),
    })
end

function AdminToolsService:_handleEventCommand(adminPlayer, data)
    data = type(data) == "table" and data or {}

    local authorized, reason =
        self._adminService:ValidateAdminAction(adminPlayer, "globalEffects", data, "client")
    if not authorized then
        self:_sendResult(adminPlayer, {
            kind = "event_command",
            success = false,
            message = reason or "Not authorized",
        })
        return
    end

    if not self._eventService then
        self:_sendResult(adminPlayer, {
            kind = "event_command",
            success = false,
            message = "EventService unavailable",
        })
        return
    end

    local command = tostring(data.command or "")
    local eventId = tostring(data.eventId or "")
    local success = false
    local message = "Unknown event command"

    if command == "start" then
        success, message = self._eventService:StartGlobalEvent(eventId, {
            durationSeconds = tonumber(data.durationSeconds),
            reason = data.reason or ("Admin: " .. adminPlayer.Name),
        })
        if success then
            message = "Started global event: " .. eventId
        end
    elseif command == "stop" then
        success, message = self._eventService:StopGlobalEvent(eventId)
        if success then
            message = "Stopped global event: " .. eventId
        end
    elseif command == "clear" then
        local cleared = self._eventService:ClearGlobalEvents()
        success = true
        message = "Cleared " .. tostring(cleared) .. " global events"
    elseif command == "snapshot" then
        success = true
        message = "Global event snapshot loaded"
    end

    self:_sendResult(adminPlayer, {
        kind = "event_command",
        success = success == true,
        message = message,
        events = self._eventService:GetActiveGlobalEvents(),
        modifiers = self._eventService:GetAllModifiers(),
    })
end

function AdminToolsService:Start() end

function AdminToolsService:_sendResult(adminPlayer, payload)
    Signals.AdminToolResult:FireClient(adminPlayer, payload)
end

function AdminToolsService:_resolveTarget(adminPlayer, actionName, data)
    data = type(data) == "table" and data or {}

    local authorized, reason, targetPlayer =
        self._adminService:ValidateAdminAction(adminPlayer, actionName, data, "client")
    if not authorized then
        return nil, reason or "Not authorized"
    end

    return targetPlayer or adminPlayer, nil
end

function AdminToolsService:_countPets(playerData)
    local petsBucket = playerData.Inventory and playerData.Inventory.pets
    local totalPets = 0
    local uniqueEntries = 0

    if petsBucket and petsBucket.items then
        for _, item in pairs(petsBucket.items) do
            uniqueEntries += 1
            totalPets += tonumber(item.quantity) or 1
        end
    end

    return totalPets, uniqueEntries
end

function AdminToolsService:_countEquippedPets(playerData)
    local equippedPets = playerData.Equipped and playerData.Equipped.pets
    local count = 0

    if equippedPets then
        for _, uid in pairs(equippedPets) do
            if uid ~= nil and uid ~= "" then
                count += 1
            end
        end
    end

    return count
end

function AdminToolsService:_getPetEquipLimit(targetPlayer)
    local configured = self._inventoryConfig.equipped and self._inventoryConfig.equipped.pets
    local configuredSlots = configured and configured.slots or 3

    if self._inventoryService and self._inventoryService._getMaxEquippedSlots then
        return self._inventoryService:_getMaxEquippedSlots(targetPlayer, "pets", configuredSlots)
    end

    return configuredSlots
end

function AdminToolsService:_buildSnapshot(targetPlayer)
    local playerData = self._dataService:GetData(targetPlayer)
    local saveState = self._dataService.SaveRequests
        and self._dataService.SaveRequests[targetPlayer]
    local totalPets, petEntries = self:_countPets(playerData or {})
    local equippedPets = self:_countEquippedPets(playerData or {})
    local freeTarget = targetPlayer:FindFirstChild("FreeTarget")
    local paidTarget = targetPlayer:FindFirstChild("PaidTarget")

    return {
        userId = targetPlayer.UserId,
        name = targetPlayer.Name,
        displayName = targetPlayer.DisplayName,
        dataLoaded = self._dataService:IsDataLoaded(targetPlayer),
        persistenceEnabled = ReplicatedStorage:GetAttribute("ProfilePersistenceEnabled") == true,
        dataStoreState = ReplicatedStorage:GetAttribute("ProfileStoreDataState") or "Unknown",
        currencies = playerData and playerData.Currencies or {},
        petCount = totalPets,
        petEntryCount = petEntries,
        equippedPetCount = equippedPets,
        equippedPetLimit = self:_getPetEquipLimit(targetPlayer),
        extraPetSlots = playerData and playerData.Perks and playerData.Perks.extra_pet_slots or 0,
        hatchEntitlements = self:_buildHatchEntitlementSnapshot(targetPlayer),
        autoTarget = {
            low = freeTarget and freeTarget.Value == true or false,
            high = paidTarget and paidTarget.Value == true or false,
        },
        save = {
            dirty = saveState and saveState.dirty == true or false,
            scheduled = saveState and saveState.scheduled == true or false,
            inFlight = saveState and saveState.inFlight == true or false,
            lastReason = saveState and saveState.lastReason or "none",
            lastRequestedAt = saveState and saveState.lastRequestedAt or nil,
            lastConfirmedAt = saveState and saveState.lastConfirmedAt or nil,
        },
    }
end

function AdminToolsService:_getHatchEntitlementDefinitions()
    return self._hatchEntitlementService:GetDefinitions()
end

function AdminToolsService:_getDefaultHatchEntitlement(entitlementId)
    return self._hatchEntitlementService:GetDefault(entitlementId)
end

function AdminToolsService:_buildHatchEntitlementSnapshot(targetPlayer)
    return self._hatchEntitlementService:BuildSnapshot(targetPlayer)
end

function AdminToolsService:_setHatchEntitlement(targetPlayer, entitlementId, value)
    return self._hatchEntitlementService:SetPlayerOverride(targetPlayer, entitlementId, value)
end

function AdminToolsService:_handleSetHatchEntitlement(adminPlayer, data)
    local targetPlayer, errorMessage =
        self:_resolveTarget(adminPlayer, "manageHatchEntitlements", data)
    if not targetPlayer then
        self:_sendResult(adminPlayer, {
            kind = "hatch_entitlement",
            success = false,
            message = errorMessage,
        })
        return
    end

    data = type(data) == "table" and data or {}
    local mode = tostring(data.mode or "set")
    local entitlementId = data.entitlement and tostring(data.entitlement) or nil
    local success = true
    local messages = {}

    if mode == "status" then
        table.insert(messages, "Hatch entitlement status loaded for " .. targetPlayer.Name)
    elseif mode == "reset_all" then
        for id in pairs(self:_getHatchEntitlementDefinitions()) do
            local ok, message = self:_setHatchEntitlement(targetPlayer, id, nil)
            success = success and ok
            table.insert(messages, message)
        end
    elseif mode == "unlock_all_modes" or mode == "lock_all_modes" then
        local enabled = mode == "unlock_all_modes"
        for _, id in ipairs({ "autoHatch", "goldenMode", "chargedMode", "fastHatch", "skipHatch" }) do
            local ok, message = self:_setHatchEntitlement(targetPlayer, id, enabled)
            success = success and ok
            table.insert(messages, message)
        end
    elseif entitlementId then
        local value = data.value
        if mode == "reset" then
            value = nil
        elseif mode == "toggle" then
            local definitions = self:_getHatchEntitlementDefinitions()
            local definition = definitions[entitlementId]
            if definition and definition.type == "number" then
                value = data.value
            elseif definition then
                local current = targetPlayer:GetAttribute(definition.attribute)
                local effective = current
                if effective == nil then
                    effective = self:_getDefaultHatchEntitlement(entitlementId)
                end
                value = not (effective == true)
            end
        end

        local ok, message = self:_setHatchEntitlement(targetPlayer, entitlementId, value)
        success = ok == true
        table.insert(messages, message)
    else
        success = false
        table.insert(messages, "Missing hatch entitlement id")
    end

    self:_sendResult(adminPlayer, {
        kind = "hatch_entitlement",
        success = success,
        message = table.concat(messages, "; "),
        hatchEntitlements = self:_buildHatchEntitlementSnapshot(targetPlayer),
        snapshot = self:_buildSnapshot(targetPlayer),
    })
end

function AdminToolsService:_handleHatchHistory(adminPlayer, data)
    local targetPlayer, errorMessage = self:_resolveTarget(adminPlayer, "viewDebugInfo", data)
    if not targetPlayer then
        self:_sendResult(adminPlayer, {
            kind = "hatch_history",
            success = false,
            message = errorMessage,
        })
        return
    end

    local EggService = require(ServerScriptService.Server.Services.EggService)
    local history = EggService:GetHatchHistory(targetPlayer, data and data.limit or nil)
    self:_sendResult(adminPlayer, {
        kind = "hatch_history",
        success = true,
        message = string.format(
            "Loaded %d recent hatch transaction%s for %s",
            #history,
            #history == 1 and "" or "s",
            targetPlayer.Name
        ),
        hatchHistory = history,
        snapshot = self:_buildSnapshot(targetPlayer),
    })
end

function AdminToolsService:_handleHatchSimulation(adminPlayer, data)
    local targetPlayer, errorMessage = self:_resolveTarget(adminPlayer, "viewDebugInfo", data)
    if not targetPlayer then
        self:_sendResult(adminPlayer, {
            kind = "hatch_simulation",
            success = false,
            message = errorMessage,
        })
        return
    end

    data = type(data) == "table" and data or {}
    local EggService = require(ServerScriptService.Server.Services.EggService)
    local simulation = EggService:SimulateHatchBatch(targetPlayer, {
        eggType = data.eggType or "basic_egg",
        requestedCount = data.requestedCount or data.count or 25,
        purchaseType = "AdminSimulation",
        options = type(data.options) == "table" and data.options or {},
    })

    local success = type(simulation) == "table" and simulation.ok == true
    self:_sendResult(adminPlayer, {
        kind = "hatch_simulation",
        success = success,
        message = success and string.format(
            "Simulated %d/%d %s hatch%s for %s without spending currency",
            simulation.hatchCount or 0,
            simulation.requestedCount or 0,
            tostring(simulation.eggType or simulation.EggType or "egg"),
            (simulation.hatchCount or 0) == 1 and "" or "es",
            targetPlayer.Name
        ) or (simulation and simulation.message or "Hatch simulation failed"),
        simulation = simulation,
        snapshot = self:_buildSnapshot(targetPlayer),
    })
end

function AdminToolsService:_handleSnapshot(adminPlayer, data)
    local targetPlayer, errorMessage = self:_resolveTarget(adminPlayer, "viewDebugInfo", data)
    if not targetPlayer then
        self:_sendResult(adminPlayer, {
            kind = "snapshot",
            success = false,
            message = errorMessage,
        })
        return
    end

    self:_sendResult(adminPlayer, {
        kind = "snapshot",
        success = true,
        message = "Snapshot loaded for " .. targetPlayer.Name,
        snapshot = self:_buildSnapshot(targetPlayer),
    })
end

-- Wipe a player's pet inventory + equips back to empty (a clean slate for testing). Uses the
-- resetData / resetDataOthers permission (Studio-gated). Re-replicates from the empty truth.
function AdminToolsService:_handleResetPets(adminPlayer, data)
    local targetPlayer, errorMessage = self:_resolveTarget(adminPlayer, "resetData", data)
    if not targetPlayer then
        self:_sendResult(adminPlayer, {
            kind = "reset_pets",
            success = false,
            message = errorMessage,
        })
        return
    end

    local playerData = self._dataService:GetData(targetPlayer)
    local pets = playerData and playerData.Inventory and playerData.Inventory.pets
    if type(pets) ~= "table" then
        self:_sendResult(adminPlayer, {
            kind = "reset_pets",
            success = false,
            message = "No pet inventory for " .. targetPlayer.Name,
        })
        return
    end

    -- Reset COMMON ownership — but NEVER huges/exclusives/uniques. THE HUGE GUARD: a reset wipes the
    -- common stacks only; protected (special) records always survive (PetInventoryView.keepProtected).
    local capability = self._dataService._petCapabilityFromConfig
            and self._dataService:_petCapabilityFromConfig()
        or {}
    local kept, removedCommons = PetInventoryView.keepProtected(pets.items, capability)
    pets.items = kept
    local slots = 0
    for _ in pairs(kept) do
        slots = slots + 1 -- one slot per surviving stack/special entry
    end
    pets.used_slots = slots
    -- Equip layer: keep only equips that still resolve to a SURVIVING special; drop commons (gone).
    if playerData.Equipped and type(playerData.Equipped.pets) == "table" then
        local newEquipped = {}
        for slot, ref in pairs(playerData.Equipped.pets) do
            local ok, parsed = pcall(PetInventoryView.parseRef, ref)
            local uid = ok and parsed and parsed.kind == "special" and parsed.uid or nil
            if (uid and kept[uid]) or kept[ref] then
                newEquipped[slot] = ref
            end
        end
        playerData.Equipped.pets = newEquipped
    end
    self._logger:Warn("Admin reset pets: common stacks cleared, huges/specials preserved", {
        removedCommonStacks = removedCommons,
        keptSpecials = slots,
    })

    -- Re-replicate from the now-empty truth, then despawn any world follow models.
    if self._inventoryService and self._inventoryService.RebuildPetProjections then
        self._inventoryService:RebuildPetProjections(targetPlayer)
    end
    if type(_G.RBXReloadEquippedPets) == "function" then
        pcall(function()
            _G.RBXReloadEquippedPets(targetPlayer)
        end)
    end

    self._dataService:RequestSave(targetPlayer, "admin_reset_pets", {
        critical = true,
        debounceSeconds = 0,
    })

    self._logger:Warn("🗑️ ADMIN RESET PETS", {
        admin = adminPlayer.Name,
        target = targetPlayer.Name,
    })

    self:_sendResult(adminPlayer, {
        kind = "reset_pets",
        success = true,
        message = "Pets reset for " .. targetPlayer.Name,
        snapshot = self:_buildSnapshot(targetPlayer),
    })
end

-- "Reset to beginning, keep HUGE pets" (resetData permission, Studio-gated). Deletes every pet
-- that is NOT huge (record.huge == true is the sole keep-flag), resets currencies to 100
-- grass_coins + 0 everything else, and re-locks all gated zones. Pass { dryRun = true } to get a
-- preview of exactly what would be kept/deleted WITHOUT mutating anything.
function AdminToolsService:_handleResetToBeginning(adminPlayer, data)
    local targetPlayer, errorMessage = self:_resolveTarget(adminPlayer, "resetData", data)
    if not targetPlayer then
        self:_sendResult(
            adminPlayer,
            { kind = "reset_to_beginning", success = false, message = errorMessage }
        )
        return
    end

    local playerData = self._dataService:GetData(targetPlayer)
    local pets = playerData and playerData.Inventory and playerData.Inventory.pets
    if type(pets) ~= "table" or type(pets.items) ~= "table" then
        self:_sendResult(adminPlayer, {
            kind = "reset_to_beginning",
            success = false,
            message = "No pet inventory for " .. targetPlayer.Name,
        })
        return
    end

    -- Classify: keep only records explicitly flagged huge == true.
    local function describe(rec)
        local s = tostring(rec.id) .. ":" .. tostring(rec.variant)
        if rec.serial then
            s = s .. " #" .. tostring(rec.serial)
        end
        return s
    end
    -- THE HUGE GUARD (shared with _handleResetPets): protect huges/exclusives/uniques, not just the
    -- `huge` flag — so a huge that somehow lacks the flag (special rarity / per-uid) still survives.
    local capability = self._dataService._petCapabilityFromConfig
            and self._dataService:_petCapabilityFromConfig()
        or {}
    local kept, keptKeys, deleteCount = {}, {}, 0
    for key, rec in pairs(pets.items) do
        if PetInventoryView.isProtectedFromReset(rec, capability) then
            kept[#kept + 1] = describe(rec)
            keptKeys[key] = rec
        else
            deleteCount += 1
        end
    end

    local dryRun = type(data) == "table" and data.dryRun == true
    if dryRun then
        self:_sendResult(adminPlayer, {
            kind = "reset_to_beginning",
            success = true,
            dryRun = true,
            message = string.format(
                "DRY RUN for %s — KEEP %d huge [%s], DELETE %d others",
                targetPlayer.Name,
                #kept,
                table.concat(kept, ", "),
                deleteCount
            ),
        })
        return
    end

    -- 1) Pets: replace the SSOT with only the huge survivors. Equip refs to deleted pets are
    --    dropped by RebuildPetProjections below.
    pets.items = keptKeys
    pets.used_slots = #kept

    -- 1b) DEPLOYED SQUAD: a true new player has nothing deployed. Clear the equip projection so the
    --     reset can't leave slots pointing at the just-deleted pets — those orphaned slots ("Bridge:
    --     skipping orphaned equip slot ... stack|meerkat:rainbow|3") are a dev-only artifact that can
    --     surface as phantom/empty-slot squad bugs. RebuildPetProjections re-replicates the now-empty
    --     squad. (Jason: reset-to-beginning wasn't clearing equip slots.)
    if type(playerData.Equipped) == "table" then
        playerData.Equipped.pets = {}
    end

    -- 2) Currencies: 100 grass_coins (the starter), 0 for every other defined currency.
    local okCur, currencies = pcall(function()
        return self._configLoader:LoadConfig("currencies")
    end)
    if okCur and type(currencies) == "table" then
        for _, c in ipairs(currencies) do
            local amt = (c.id == "grass_coins") and 100 or 0
            self._dataService:SetCurrency(targetPlayer, c.id, amt, "admin_reset_to_beginning")
        end
    end

    -- 3) Zones: relock everything (defaults re-merge to Spawn). Republish so the spawn-gate +
    --    client prompt update immediately.
    playerData.GameData = playerData.GameData or {}
    playerData.GameData.UnlockedAreas = { "Spawn" }
    if self._zoneService and self._zoneService._getUnlockSet then
        pcall(function()
            self._zoneService:_getUnlockSet(targetPlayer)
        end)
    end

    -- 4) Progression: Level 1 / XP 0 (Level is derived from data.Stats.Experience). SetLevel
    --    writes the level-1 threshold XP and republishes the Level/XP/XPForNext attributes.
    local prog = _G.RBXTemplateServices and _G.RBXTemplateServices:Get("PlayerProgressionService")
    if prog and prog.SetLevel then
        pcall(function()
            prog:SetLevel(targetPlayer, 1)
        end)
    else
        if self._dataService.SetStat then
            self._dataService:SetStat(targetPlayer, "Experience", 0)
        end
        playerData.Stats = playerData.Stats or {}
        playerData.Stats.Level = 1
        playerData.Stats.Experience = 0
        targetPlayer:SetAttribute("Level", 1)
        targetPlayer:SetAttribute("XP", 0)
    end

    -- 5) Pet slots back to the base 3: clear the extra-slot sources (the level-derived bonus
    --    already drops to 0 at level 1). Perks + the ExtraPetSlots attribute are the rest.
    playerData.Perks = playerData.Perks or {}
    playerData.Perks.extra_pet_slots = nil
    targetPlayer:SetAttribute("ExtraPetSlots", 0)

    -- 5b) Powers + enhancement slots + ORIGIN: full respec to a true new-player state (origin is
    --     re-chosen at L5). Clears Powers/Slots/Hotbar/Archetype so the bar starts empty.
    local arche = _G.RBXTemplateServices and _G.RBXTemplateServices:Get("ArchetypeService")
    if arche and arche.Respec then
        pcall(function()
            arche:Respec(targetPlayer, nil)
        end)
    end
    -- 5c) Clear the always-on PASSIVE buff attributes (Magnet/Swift/Hasten/XP) — respec wipes the
    --     owned powers but those buffs live on player ATTRIBUTES; ReapplyPassives clears + re-stamps
    --     from the now-empty owned set, so a reset player truly has none.
    local pwr = _G.RBXTemplateServices and _G.RBXTemplateServices:Get("PowerService")
    if pwr and pwr.ReapplyPassives then
        pcall(function()
            pwr:ReapplyPassives(targetPlayer)
        end)
    end

    -- 5c2) PROGRESS COUNTERS + claim ledgers back to zero (Jason: reset left eggs_hatched/
    --      coins_earned_lifetime intact, so the post-tutorial missions were instantly
    --      claimable). Counters re-seed from configs/stats.lua defaults; quest +
    --      achievement claim ledgers clear. PetIndex is deliberately KEPT — the kept
    --      huges remain legitimately discovered; EnhancementIndex clears with the
    --      wiped enhancement inventory.
    playerData.Stats = playerData.Stats or {}
    playerData.Stats.Counters = {}
    pcall(function()
        local statsCfg = self._configLoader and self._configLoader:LoadConfig("stats")
        for counterId, counterConfig in pairs((statsCfg and statsCfg.counters) or {}) do
            playerData.Stats.Counters[counterId] = counterConfig.default or 0
        end
    end)
    playerData.QuestClaims = {}
    -- Grind quests (condition.since_start) measure FORWARD progress = banked + (counter - baseline).
    -- Wiping QuestClaims + the counter isn't enough: stale QuestBaselines/QuestBanked windows make the
    -- bar read full, so "Hatch 500 Eggs" was instantly claimable after a reset (Jason). Clear the
    -- windows too — each quest re-baselines to the now-zero counter when it next activates.
    playerData.QuestBaselines = {}
    playerData.QuestBanked = {}
    -- Clear the active focus + the "tracks seen" set so a reset player falls cleanly back into the
    -- First Steps onramp (not a stale Warpath focus) and re-announces tracks as they re-cross levels.
    playerData.QuestActiveTrack = nil
    playerData.QuestTracksSeen = nil
    -- MetCreators is deliberately KEPT (like PetIndex): the once-ever Meet-The-Creator
    -- must NOT re-fire on every playtest reset (Jason: "don't reset the flag when I
    -- reset — that way I don't have a whole inventory full of them"). The exclusives
    -- the guard keeps were legitimately met/hatched; meet.reset is the explicit re-arm.
    playerData.Achievements = nil
    playerData.Ledger = nil
    playerData.EnhancementIndex = nil

    -- 5d) Tutorial restarts + enhancements wiped — "reset to beginning" means the NEW-PLAYER
    --     experience (Jason hit this: his tutorial stayed done=true through this reset because
    --     only levelup.resetRun knew about it).
    local tut = _G.RBXTemplateServices and _G.RBXTemplateServices:Get("TutorialService")
    if tut and tut.Reset then
        pcall(function()
            tut:Reset(targetPlayer)
        end)
    end
    local enh = _G.RBXTemplateServices and _G.RBXTemplateServices:Get("EnhancementService")
    if enh and enh.WipeAll then
        pcall(function()
            enh:WipeAll(targetPlayer)
        end)
    end

    -- 6) Re-replicate pet projections (drops stale equips + despawns removed follow models) + save.
    if self._inventoryService and self._inventoryService.RebuildPetProjections then
        self._inventoryService:RebuildPetProjections(targetPlayer)
    end
    if type(_G.RBXReloadEquippedPets) == "function" then
        pcall(function()
            _G.RBXReloadEquippedPets(targetPlayer)
        end)
    end
    self._dataService:RequestSave(
        targetPlayer,
        "admin_reset_to_beginning",
        { critical = true, debounceSeconds = 0 }
    )

    self._logger:Warn("🔄 ADMIN RESET TO BEGINNING (KEEP HUGE)", {
        admin = adminPlayer.Name,
        target = targetPlayer.Name,
        keptHuge = #kept,
        deleted = deleteCount,
        kept = kept,
    })

    self:_sendResult(adminPlayer, {
        kind = "reset_to_beginning",
        success = true,
        message = string.format(
            "Reset %s — kept %d huge [%s], deleted %d; currencies/zones/level/XP/slots/powers/origin reset",
            targetPlayer.Name,
            #kept,
            table.concat(kept, ", "),
            deleteCount
        ),
        snapshot = self:_buildSnapshot(targetPlayer),
    })
end

function AdminToolsService:_handleForceSave(adminPlayer, data)
    local targetPlayer, errorMessage = self:_resolveTarget(adminPlayer, "forceSaveData", data)
    if not targetPlayer then
        self:_sendResult(adminPlayer, {
            kind = "force_save",
            success = false,
            message = errorMessage,
        })
        return
    end

    local ok = self._dataService:RequestSave(targetPlayer, "admin_force_save", {
        debounceSeconds = 0,
        critical = true,
    })

    self:_sendResult(adminPlayer, {
        kind = "force_save",
        success = ok == true,
        message = ok and ("Force save requested for " .. targetPlayer.Name)
            or ("Force save failed for " .. targetPlayer.Name),
        snapshot = self:_buildSnapshot(targetPlayer),
    })
end

-- Remove a single pet RECORD by uid (admin tooling — e.g. retiring a mis-granted
-- special). Deliberately works on specials too: this is the scalpel the reset's
-- huge-guard intentionally refuses to be.
function AdminToolsService:_handleRetirePet(adminPlayer, data)
    local targetPlayer, errorMessage = self:_resolveTarget(adminPlayer, "giveItems", data)
    if not targetPlayer then
        self:_sendResult(
            adminPlayer,
            { kind = "retire_pet", success = false, message = errorMessage }
        )
        return
    end
    local uid = type(data) == "table" and tostring(data.uid or "") or ""
    local playerData = self._dataService:GetData(targetPlayer)
    local pets = playerData and playerData.Inventory and playerData.Inventory.pets
    local rec = pets and pets.items and pets.items[uid]
    if not rec then
        self:_sendResult(
            adminPlayer,
            { kind = "retire_pet", success = false, message = "No pet record: " .. uid }
        )
        return
    end
    pets.items[uid] = nil
    pets.used_slots = math.max(0, (pets.used_slots or 1) - 1)
    self._dataService:RequestSave(targetPlayer, "admin_retire_pet", { critical = true })
    pcall(function()
        self._inventoryService:_updateBucketFolders(targetPlayer, "pets")
    end)
    self._logger:Warn("Admin retired pet record", {
        admin = adminPlayer.Name,
        target = targetPlayer.Name,
        uid = uid,
        id = rec.id,
    })
    self:_sendResult(adminPlayer, {
        kind = "retire_pet",
        success = true,
        message = ("Retired %s (%s) from %s"):format(uid, tostring(rec.id), targetPlayer.Name),
    })
end

function AdminToolsService:_parseGrantData(data)
    data = type(data) == "table" and data or {}
    local petType = tostring(data.petType or ""):lower()
    local variant = tostring(data.variant or "basic"):lower()
    local quantity = math.clamp(math.floor(tonumber(data.quantity) or 1), 1, 99)
    local traits = {
        huge = data.huge == true,
        creator = data.creator == true,
    }

    return petType, variant, quantity, traits
end

function AdminToolsService:_handleGrantPet(adminPlayer, data)
    local targetPlayer, errorMessage = self:_resolveTarget(adminPlayer, "giveItems", data)
    if not targetPlayer then
        self:_sendResult(adminPlayer, {
            kind = "grant_pet",
            success = false,
            message = errorMessage,
        })
        return
    end

    local petType, variant, quantity, traits = self:_parseGrantData(data)
    if not (self._petsConfig.getPet and self._petsConfig.getPet(petType, variant)) then
        self:_sendResult(adminPlayer, {
            kind = "grant_pet",
            success = false,
            message = "Unknown pet: " .. tostring(petType) .. ":" .. tostring(variant),
        })
        return
    end

    local result = self._petGrantService:GrantPet(targetPlayer, {
        petType = petType,
        variant = variant,
        quantity = traits.huge and 1 or quantity,
        huge = traits.huge,
        creator = traits.creator,
        source = "admin_grant_pet",
    })
    if not result.ok then
        self:_sendResult(adminPlayer, {
            kind = "grant_pet",
            success = false,
            message = result.error or "Failed to grant pet",
            snapshot = self:_buildSnapshot(targetPlayer),
        })
        return
    end

    local petData = result.petData

    self._logger:Info("Admin pet granted", {
        admin = adminPlayer.Name,
        target = targetPlayer.Name,
        petType = petType,
        variant = variant,
        quantity = quantity,
        huge = traits.huge == true,
        serial = petData.serial,
        serialKey = petData.serial_key,
        uid = result.uid,
    })

    self:_sendResult(adminPlayer, {
        kind = "grant_pet",
        success = true,
        message = string.format(
            "Granted %dx %s%s %s%s to %s",
            traits.huge and 1 or quantity,
            variant,
            traits.huge and " huge" or "",
            petType,
            petData.serial and (" #" .. tostring(petData.serial)) or "",
            targetPlayer.Name
        ),
        granted = {
            petType = petType,
            variant = variant,
            quantity = quantity,
            uid = result.uid,
            huge = traits.huge == true,
            serial = petData.serial,
            serialKey = petData.serial_key,
        },
        snapshot = self:_buildSnapshot(targetPlayer),
    })
end

function AdminToolsService:_handleSetZoneLock(adminPlayer, data)
    local targetPlayer, errorMessage = self:_resolveTarget(adminPlayer, "unlockZones", data)
    if not targetPlayer then
        self:_sendResult(adminPlayer, {
            kind = "zone_lock",
            success = false,
            message = errorMessage,
        })
        return
    end

    if not self._zoneService then
        self:_sendResult(adminPlayer, {
            kind = "zone_lock",
            success = false,
            message = "ZoneService unavailable",
            snapshot = self:_buildSnapshot(targetPlayer),
        })
        return
    end

    data = type(data) == "table" and data or {}
    local zoneId = tostring(data.zoneId or "")
    if zoneId == "" then
        self:_sendResult(adminPlayer, {
            kind = "zone_lock",
            success = false,
            message = "Missing zone id",
            snapshot = self:_buildSnapshot(targetPlayer),
        })
        return
    end

    local currentUnlocked = self._zoneService:IsZoneUnlocked(targetPlayer, zoneId)
    local locked = data.locked
    if locked == nil then
        locked = currentUnlocked == true
    end

    local result = self._zoneService:SetZoneLocked(targetPlayer, zoneId, locked == true, {
        bypassRequirements = data.bypassRequirements == true,
    })

    local success = result and result.ok == true
    local unlockedAreas = self._zoneService:GetUnlockedZones(targetPlayer)
    local message
    if success then
        if locked == true then
            message = string.format("Locked %s for %s", zoneId, targetPlayer.Name)
        elseif result.alreadyUnlocked then
            message = string.format("%s already has %s unlocked", targetPlayer.Name, zoneId)
        else
            message = string.format("Unlocked %s for %s", zoneId, targetPlayer.Name)
        end
    else
        message = string.format(
            "Failed to unlock %s for %s: %s",
            zoneId,
            targetPlayer.Name,
            tostring(result and result.reason or "unknown")
        )
    end

    self:_sendResult(adminPlayer, {
        kind = "zone_lock",
        success = success,
        message = message,
        zoneLock = result,
        unlockedAreas = unlockedAreas,
        snapshot = self:_buildSnapshot(targetPlayer),
    })
end

return AdminToolsService
