--[[
    EnhancementService — CoH-style enhancements (Jason's design; see configs/enhancements.lua).

    Owns profile.EnhancementInv (uid -> { type, origins }) and SLOTTING into the empty slot
    records of profile.Slots[powerId] (earned via AugmentationService). A filled slot becomes
    { enh = { type, origins } }; the inherent slot can be filled too (it's still a slot).

    Rules enforced here (pure logic in src/Shared/Game/Enhancements.lua):
      • player must own the power; the slot must exist
      • type must be compatible with the power (family / AoE gating)
      • the PLAYER's origin must be among the enhancement's origins (single = exact match,
        dual = either) — the single-vs-dual economy
      • replacing an occupied slot DESTROYS the old enhancement (config replace_destroys)

    Effects apply at cast time: PowerService aggregates the cast power's slots into per-axis
    multipliers (Enhancements.aggregate) and feeds PowerStats.resolveEffective.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Enhancements = require(ReplicatedStorage.Shared.Game.Enhancements)

local EnhancementService = {}
EnhancementService.__index = EnhancementService

function EnhancementService:Init()
    self._logger = self._modules and self._modules.Logger
    self._configLoader = self._modules and self._modules.ConfigLoader
    self._dataService = self._modules and self._modules.DataService
    self._config = self._configLoader:LoadConfig("enhancements")
    self._powersConfig = self._configLoader:LoadConfig("powers")
    -- areas: drop origins key by the zone's BIOME (element), resolved from the area
    -- id at RollDrop time (Jason: "in your origin's zone the cog interior is 100%
    -- that origin"). Every grass area maps to geomancer, not just a literal "Grass".
    self._areasConfig = self._configLoader:LoadConfig("areas")
end

local Players = game:GetService("Players")

local BUCKET = "enhancements" -- InventoryService bucket: visible in the Inventory UI, trade-ready

-- Records granted before the folder-mirror field existed have no origins_csv, so the
-- inventory FOLDER carries no origins and the client renders the neutral purple badge
-- (Jason: a wall of identical purple gears). Backfill on join: stamp the csv on the data
-- record, then rebuild the bucket folder so the mirror picks it up.
function EnhancementService:Start()
    local function backfill(player)
        local deadline = os.clock() + 20
        while
            player.Parent
            and not self._dataService:IsDataLoaded(player)
            and os.clock() < deadline
        do
            task.wait(0.2)
        end
        if not (player.Parent and self._dataService:IsDataLoaded(player)) then
            return
        end
        local invSvc = self:_inventoryService()
        local bucket = invSvc and invSvc:GetInventory(player, BUCKET)
        local changed = false
        for _, rec in pairs((bucket and bucket.items) or {}) do
            if rec.type and type(rec.origins) == "table" and not rec.origins_csv then
                rec.origins_csv = table.concat(rec.origins, ",")
                changed = true
            end
            if rec.type and not rec.level then
                -- legacy pre-level records: all dropped on the home world (default band)
                rec.level = Enhancements.rollLevel(self._config, nil, nil)
                changed = true
            end
        end
        -- SLOTTED legacy pieces predating the level system (survived the profile
        -- reset, which keeps Slots) get a default-band level — Jason: "we lost the
        -- numbers underneath" (label + aggregate both key off slot.enh.level)
        local data = self._dataService:GetData(player)
        for _, slots in pairs((data and data.Slots) or {}) do
            if type(slots) == "table" then
                for _, slot in ipairs(slots) do
                    if
                        type(slot) == "table"
                        and slot.enh
                        and slot.enh.type
                        and not slot.enh.level
                    then
                        slot.enh.level = Enhancements.rollLevel(self._config, nil, nil)
                        changed = true
                    end
                end
            end
        end
        -- STACK MIGRATION (Jason: uid-per-drop = save explosion): fold legacy
        -- uid-keyed records into identity stacks. One-time per profile.
        if bucket and bucket.items then
            local folds = {}
            for key, rec in pairs(bucket.items) do
                if rec.type and not key:find("^enh_") then
                    folds[#folds + 1] = key
                end
            end
            for _, key in ipairs(folds) do
                local rec = bucket.items[key]
                bucket.items[key] = nil
                local stackId = ("enh_%s_%s_L%d"):format(
                    rec.type,
                    (type(rec.origins) == "table" and #rec.origins > 0)
                            and table.concat(rec.origins, "+")
                        or "natural",
                    math.max(1, math.floor(tonumber(rec.level) or 1))
                )
                local stack = bucket.items[stackId]
                if stack then
                    stack.quantity = (tonumber(stack.quantity) or 1) + (tonumber(rec.quantity) or 1)
                else
                    rec.id = stackId
                    rec.quantity = tonumber(rec.quantity) or 1
                    bucket.items[stackId] = rec
                end
                changed = true
            end
            if #folds > 0 then
                -- recount used slots: stacks share one slot per identity
                local used = 0
                for _ in pairs(bucket.items) do
                    used += 1
                end
                bucket.used_slots = used
            end
        end
        if changed then
            self._dataService:RequestSave(player, "enhancement_csv_backfill")
            pcall(function()
                invSvc:_updateBucketFolders(player, BUCKET)
            end)
        end
    end
    Players.PlayerAdded:Connect(function(player)
        task.spawn(backfill, player)
    end)
    for _, player in ipairs(Players:GetPlayers()) do
        task.spawn(backfill, player)
    end
end

function EnhancementService:_inventoryService()
    local locator = _G.RBXTemplateServices
    local ok, svc = pcall(function()
        return locator and locator:Get("InventoryService")
    end)
    return ok and svc or nil
end

-- One-time migration: records granted into the old private store (data.EnhancementInv) move
-- into the InventoryService bucket so they show in the Inventory UI and can trade later.
function EnhancementService:_migrateLegacy(player, data)
    if type(data.EnhancementInv) ~= "table" or next(data.EnhancementInv) == nil then
        data.EnhancementInv = nil
        return
    end
    local invSvc = self:_inventoryService()
    if not invSvc then
        return -- bucket not reachable yet; retry on the next call
    end
    for _, rec in pairs(data.EnhancementInv) do
        pcall(function()
            invSvc:AddItem(player, BUCKET, {
                id = "enhancement",
                type = rec.type,
                origins = rec.origins,
                origins_csv = table.concat(rec.origins, ","), -- folder-mirror friendly
                name = Enhancements.displayName(self._config, rec),
            })
        end)
    end
    data.EnhancementInv = nil
    self._dataService:RequestSave(player, "enhancement_migrate", { critical = true })
end

local function ownsPower(data, powerId, powersConfig)
    -- INNATE powers (Resonance) are owned-free and NOT in data.Powers, but they're slottable.
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

-- Full client view: inventory (with usability for THIS player) + per-power slotted records.
function EnhancementService:GetState(player)
    local data = self._dataService:GetData(player)
    if not data then
        return { ok = false, reason = "data_not_loaded" }
    end
    self:_migrateLegacy(player, data)
    local items = {}
    local invSvc = self:_inventoryService()
    local bucket = invSvc and invSvc:GetInventory(player, BUCKET)
    for uid, rec in pairs((bucket and bucket.items) or {}) do
        if rec.type and rec.origins then
            -- backfill for records granted before the folder-mirror field existed
            if not rec.origins_csv then
                rec.origins_csv = table.concat(rec.origins, ",")
            end
            items[#items + 1] = {
                uid = uid,
                type = rec.type,
                origins = rec.origins,
                level = rec.level or 1,
                count = math.max(1, math.floor(tonumber(rec.quantity) or 1)),
                name = rec.name or Enhancements.displayName(self._config, rec),
                usable = Enhancements.usableBy(rec, data.Archetype),
                single = Enhancements.isSingle(rec),
            }
        end
    end
    table.sort(items, function(a, b)
        return a.name < b.name
    end)
    return {
        ok = true,
        inventory = items,
        slots = data.Slots or {},
        archetype = data.Archetype,
    }
end

-- Grant an enhancement into the inventory (drops + admin). Returns the uid.
function EnhancementService:Grant(player, record)
    local data = self._dataService:GetData(player)
    if not data then
        return { ok = false, reason = "data_not_loaded" }
    end
    if not Enhancements.isValid(self._config, record) then
        return { ok = false, reason = "invalid_record" }
    end
    self:_migrateLegacy(player, data)
    local invSvc = self:_inventoryService()
    if not invSvc then
        return { ok = false, reason = "service_unavailable" }
    end
    local name = Enhancements.displayName(self._config, record)
    -- the stack id IS the identity (Jason: stacks, not uids — DataStore size). Ordered
    -- origins: ring/interior arrangement is part of the identity (art preserved).
    local stackId = ("enh_%s_%s_L%d"):format(
        record.type,
        #record.origins > 0 and table.concat(record.origins, "+") or "natural",
        math.max(1, math.floor(tonumber(record.level) or 1))
    )
    local uid, err = invSvc:AddItem(player, BUCKET, {
        id = stackId,
        type = record.type,
        origins = record.origins,
        origins_csv = table.concat(record.origins, ","), -- folder-mirror friendly
        level = math.max(1, math.floor(tonumber(record.level) or 1)),
        name = name,
    })
    if not uid then
        return { ok = false, reason = err or "inventory_full" }
    end
    pcall(function() -- mission counter (quest chain "Find an enhancement")
        _G.RBXTemplateServices:Get("StatsService"):Increment(player, "enhancements_found", 1)
    end)
    -- ENHANCEMENT INDEX (Jason, PetIndex pattern): every enhancement identity ever
    -- obtained gets a permanent discovery record — count + first-obtained timestamp.
    -- Future "very special" enhancements are valuable precisely because this exists.
    do
        local sorted = table.clone(record.origins)
        table.sort(sorted)
        local key = record.type .. ":" .. table.concat(sorted, "+")
        data.EnhancementIndex = data.EnhancementIndex or { Discovered = {} }
        data.EnhancementIndex.Discovered = data.EnhancementIndex.Discovered or {}
        local entry = data.EnhancementIndex.Discovered[key]
        if entry then
            entry.count = (entry.count or 0) + 1
        else
            data.EnhancementIndex.Discovered[key] = { count = 1, first_at = os.time() }
            -- bus source (no default reactions yet): first-ever discovery of this identity
            local fireGameEvent =
                require(game:GetService("ReplicatedStorage").Shared.Network.FireGameEvent)
            fireGameEvent(player, "new_enhancement", { key = key, name = name })
        end
    end
    return { ok = true, uid = uid, name = name }
end

-- Slot an inventory enhancement into slot #slotIndex of an owned power.
function EnhancementService:Slot(player, powerId, slotIndex, uid)
    local data = self._dataService:GetData(player)
    if not data then
        return { ok = false, reason = "data_not_loaded" }
    end
    self:_migrateLegacy(player, data)
    local invSvc = self:_inventoryService()
    local rec = invSvc and invSvc:GetItem(player, BUCKET, uid)
    if not rec then
        return { ok = false, reason = "not_in_inventory" }
    end
    if not ownsPower(data, powerId, self._powersConfig) then
        return { ok = false, reason = "power_not_owned" }
    end
    local slots = type(data.Slots) == "table" and data.Slots[powerId]
    slotIndex = math.floor(tonumber(slotIndex) or 0)
    local slot = type(slots) == "table" and slots[slotIndex]
    if type(slot) ~= "table" then
        return { ok = false, reason = "no_such_slot" }
    end
    if not Enhancements.usableBy(rec, data.Archetype) then
        return { ok = false, reason = "wrong_origin" }
    end
    local powerDef = self._powersConfig.powers[powerId]
    local okType, why = Enhancements.compatibleWith(
        self._config,
        rec.type,
        powerDef,
        self._powersConfig.effect_kinds
    )
    if not okType then
        return { ok = false, reason = why or "incompatible" }
    end
    -- CoH placement gate: nothing more than `window` levels above the player
    local playerLevel = tonumber(player:GetAttribute("Level")) or 1
    if not Enhancements.canSlotAtLevel(self._config, rec.level, playerLevel) then
        return { ok = false, reason = "level_too_high" }
    end
    if slot.enh ~= nil and self._config.replace_destroys ~= true then
        return { ok = false, reason = "slot_occupied" }
    end
    -- Commit: fill the slot (replace destroys the old record) + consume from the bucket.
    -- Level rides along — aggregate() scales (or kills) the boost vs the player's level.
    slot.enh = { type = rec.type, origins = rec.origins, level = rec.level }
    invSvc:RemoveItem(player, BUCKET, uid, 1)
    self._dataService:RequestSave(player, "enhancement_slot", { critical = true })
    pcall(function() -- mission counter (Origin Story "Slot an Enhancement")
        _G.RBXTemplateServices:Get("StatsService"):Increment(player, "enhancements_slotted", 1)
    end)
    -- config-reactive event (sounds/VFX are a configs/game_events.lua row away — Jason)
    pcall(function()
        local fireGameEvent =
            require(game:GetService("ReplicatedStorage").Shared.Network.FireGameEvent)
        fireGameEvent(player, "enhancement_slotted", {
            type = rec.type,
            level = rec.level,
            powerId = powerId,
        })
    end)
    -- PASSIVES apply their magnitude at the ownership re-stamp — without this, a
    -- potency slotted into Swift/Magnet/XP Surge stays dormant until respawn (Jason:
    -- "it did not change my speed").
    pcall(function()
        local power = _G.RBXTemplateServices and _G.RBXTemplateServices:Get("PowerService")
        if power and power.ReapplyPassives then
            power:ReapplyPassives(player)
        end
    end)
    return {
        ok = true,
        powerId = powerId,
        slotIndex = slotIndex,
        name = Enhancements.displayName(self._config, slot.enh),
    }
end

-- Roll a random drop record (type by weight). Origins: primary = the area's own origin
-- (drops.area_origins — the disc color matches the land), ring = uniform random (ring ==
-- primary -> single-origin). Unmapped areas use the legacy uniform + single_chance roll.
-- `rng` = Random instance (injectable for tests/determinism).
function EnhancementService:RollDrop(rng, areaId, opts)
    rng = rng or Random.new()
    -- opts.natural: origin-less generic drop (rolled for PRE-ORIGIN players — they
    -- can't slot origined gear yet, so the land drops them trainer-tier scrap)
    local drops = self._config.drops or {}
    local weights = drops.type_weights or {}
    local total = 0
    for t in pairs(self._config.types) do
        total += tonumber(weights[t]) or 1
    end
    local pick, acc = nil, rng:NextNumber() * total
    for t in pairs(self._config.types) do
        acc -= tonumber(weights[t]) or 1
        if acc <= 0 then
            pick = t
            break
        end
    end
    local origins = self._config.origins or {}
    local level = Enhancements.rollLevel(self._config, areaId, rng, opts and opts.playerLevel)

    -- NATURAL drops: forced for pre-origin players (opts.natural), and otherwise a
    -- coin-flip share of ALL drops (drops.natural_chance) — the junk economy tier.
    if (opts and opts.natural) or rng:NextNumber() < (tonumber(drops.natural_chance) or 0) then
        return { type = pick, origins = {}, level = level }
    end

    -- PRIMARY origin = the zone's own (the disc color brands the land — Jason); the
    -- RING is uniform random. Ring == primary -> a SINGLE-origin drop, so pure singles
    -- only exist in their home world (~1/#origins of drops). Resolve the area id to its
    -- BIOME (element) first, then to the origin — so all grass areas map to geomancer.
    local zones = self._areasConfig and self._areasConfig.zones
    local areaDef = zones and areaId and zones[areaId]
    local element = areaDef and areaDef.element
    local zoneOrigin = element and (drops.area_origins or {})[element]
    if zoneOrigin then
        local ring = origins[rng:NextInteger(1, #origins)]
        if ring == zoneOrigin then
            return { type = pick, origins = { zoneOrigin }, level = level }
        end
        return { type = pick, origins = { zoneOrigin, ring }, level = level }
    end

    -- legacy roll for unmapped areas (events/realms until they get a mapping)
    local a = origins[rng:NextInteger(1, #origins)]
    if rng:NextNumber() < (tonumber(drops.single_chance) or 0.35) then
        return { type = pick, origins = { a }, level = level }
    end
    local b = a
    while b == a do
        b = origins[rng:NextInteger(1, #origins)]
    end
    return { type = pick, origins = { a, b }, level = level }
end

-- [admin] Empty the enhancements bucket (levelup.resetRun: a fresh L1 run starts with none).
function EnhancementService:WipeAll(player)
    local invSvc = self:_inventoryService()
    local bucket = invSvc and invSvc:GetInventory(player, BUCKET)
    if not bucket then
        return { ok = false, reason = "service_unavailable" }
    end
    local uids = {}
    for uid in pairs(bucket.items or {}) do
        uids[#uids + 1] = uid
    end
    for _, uid in ipairs(uids) do
        invSvc:RemoveItem(player, BUCKET, uid, 1)
    end
    return { ok = true, removed = #uids }
end

return EnhancementService
