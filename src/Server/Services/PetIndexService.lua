local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Shared.Libraries.Signal)
local Signals = require(ReplicatedStorage.Shared.Network.Signals)
local fireGameEvent = require(ReplicatedStorage.Shared.Network.FireGameEvent)

local PetIndexService = {}
PetIndexService.__index = PetIndexService

-- Huge pets are their own index entries (Jason: the collection denominator counts
-- "all variants ... huges and exclusives included"), so a huge bear is a separate
-- discovery from a basic bear. Pre-huge-aware discoveries (plain id:variant keys)
-- stay valid — they just count as the non-huge entry.
local function petKey(petId, variant, huge)
    local key = tostring(petId) .. ":" .. tostring(variant or "basic")
    if huge == true then
        key = key .. ":huge"
    end
    return key
end

local function countMapEntries(map)
    local count = 0
    for _ in pairs(map or {}) do
        count += 1
    end
    return count
end

-- Variants an egg can roll (shared by the obtainable count and the huge census).
local function allowedVariants(egg)
    local vr = egg.variant_rolls or {}
    if vr.enabled == false then
        return { "basic" }
    end
    local allowed = {}
    if vr.allow_basic ~= false then
        table.insert(allowed, "basic")
    end
    if vr.allow_golden ~= false then
        table.insert(allowed, "golden")
    end
    if vr.allow_rainbow ~= false then
        table.insert(allowed, "rainbow")
    end
    return allowed
end

function PetIndexService:Init()
    self._logger = self._modules.Logger
    self._configLoader = self._modules.ConfigLoader
    self._dataService = self._modules.DataService
    self._statsService = self._modules.StatsService
    self._economyService = self._modules.EconomyService

    self._config = self._configLoader:LoadConfig("pet_index")
    self._petsConfig = self._configLoader:LoadConfig("pets")
    self.IndexChanged = Signal.new()

    -- GLOBAL HUGE CENSUS (Jason: "can we peek to see if there is any in existence
    -- without triggering the counter? ... it's gonna grow and we want to grow
    -- dynamically" + "if the index updates you basically get a global announcement
    -- that there's a new huge in the realm"): any_pet huge index entries exist only
    -- once the FIRST one has been minted ANYWHERE (PeekSerial reads the global
    -- counter without incrementing). The census fills the set at boot; live growth
    -- arrives on the PetWorldFirst topic (a same-server publish delivers here too,
    -- so the minting server uses the SAME path as everyone else — no double banner).
    self._globalHuges = {}
    task.delay(5, function()
        self:_runHugeCensus()
    end)
    task.spawn(function()
        pcall(function()
            game:GetService("MessagingService"):SubscribeAsync("PetWorldFirst", function(message)
                local d = message and message.Data
                if type(d) == "table" and d.t then
                    self:NotifyWorldFirst(d.t, d.v, d.p, true)
                end
            end)
        end)
    end)

    self._logger:Info("PetIndexService initialized", {
        context = "PetIndexService",
        milestones = #(self._config.milestones or {}),
    })
end

-- Peek every any_pet huge combo's global serial counter; combos with at least one
-- mint anywhere enter the obtainable index. Throttled GetAsyncs; lazy denominator
-- recount after. Combos discovered later (other servers) arrive via PetWorldFirst.
function PetIndexService:_runHugeCensus()
    local locator = _G.RBXTemplateServices
    local ok, serials = pcall(function()
        return locator and locator:Get("PetSerialService")
    end)
    if not (ok and serials and serials.PeekSerial) then
        return
    end
    local grew = false
    for _, egg in pairs(self._petsConfig.egg_sources or {}) do
        local huge = egg.huge
        if huge and (tonumber(huge.chance) or 0) > 0 and huge.any_pet == true then
            for petId in pairs(egg.pet_weights or {}) do
                for _, v in ipairs(allowedVariants(egg)) do
                    local comboKey = petId .. ":" .. v
                    if not self._globalHuges[comboKey] then
                        local count = serials:PeekSerial("huge", petId, v)
                        if (tonumber(count) or 0) > 0 then
                            self._globalHuges[comboKey] = true
                            grew = true
                        end
                        task.wait(0.1) -- budget the DataStore reads
                    end
                end
            end
        end
    end
    if grew then
        self._obtainableTotal = nil
    end
end

-- A huge species:variant just minted serial #1 SOMEWHERE (this server publishes,
-- every server's subscriber lands here): grow the index and, when announce is set,
-- show the realm-wide banner — the index updating IS the global announcement.
function PetIndexService:NotifyWorldFirst(petType, variant, playerName, announce)
    local comboKey = tostring(petType) .. ":" .. tostring(variant or "basic")
    if self._globalHuges[comboKey] then
        return -- already known (duplicate message / census raced the mint)
    end
    self._globalHuges[comboKey] = true
    self._obtainableTotal = nil -- the realm's index GREW; the denominator recounts lazily
    if announce ~= true then
        return
    end
    local family = self._petsConfig.pets and self._petsConfig.pets[petType]
    local display = (family and family.display_name) or tostring(petType)
    local vLabel = (variant and variant ~= "basic") and (string.upper(tostring(variant)) .. " ")
        or ""
    local name = string.format(
        "🌍 FIRST HUGE %s%s EVER — hatched by %s!",
        vLabel,
        string.upper(display),
        tostring(playerName or "someone")
    )
    for _, plr in ipairs(game:GetService("Players"):GetPlayers()) do
        pcall(fireGameEvent, plr, "huge_world_first", {
            name = name,
            petType = petType,
            variant = variant,
        })
    end
end

function PetIndexService:_ensureIndex(data)
    data.PetIndex = data.PetIndex or {}
    data.PetIndex.Discovered = data.PetIndex.Discovered or {}
    data.PetIndex.Milestones = data.PetIndex.Milestones or {}
    return data.PetIndex
end

function PetIndexService:_grantReward(player, reward, source)
    if type(reward) ~= "table" or reward.type ~= "currency" then
        return false, "Unsupported reward type"
    end

    local amount = tonumber(reward.amount) or 0
    if amount <= 0 then
        return false, "Invalid reward amount"
    end

    if self._economyService and self._economyService.AddCurrency then
        return self._economyService:AddCurrency(
            player,
            reward.currency,
            amount,
            source or "pet_index_reward"
        )
    end

    if self._dataService and self._dataService.AddCurrency then
        return self._dataService:AddCurrency(
            player,
            reward.currency,
            amount,
            source or "pet_index_reward"
        )
    end

    return false, "No reward grant service available"
end

function PetIndexService:_evaluateMilestones(player, index)
    local count = countMapEntries(index.Discovered)
    local granted = {}

    for _, milestone in ipairs(self._config.milestones or {}) do
        if count >= milestone.goal and not index.Milestones[milestone.id] then
            local ok, reason =
                self:_grantReward(player, milestone.reward, "pet_index_" .. milestone.id)
            if ok then
                index.Milestones[milestone.id] = {
                    completed_at = os.time(),
                    goal = milestone.goal,
                }
                table.insert(granted, milestone.id)
            else
                self._logger:Warn("Failed to grant pet index milestone reward", {
                    context = "PetIndexService",
                    player = player.Name,
                    milestone = milestone.id,
                    reason = reason,
                })
            end
        end
    end

    return granted
end

function PetIndexService:_syncDistinctCounter(player, count)
    if self._statsService and self._statsService.Set then
        self._statsService:Set(player, "distinct_pets", count)
    elseif self._dataService and self._dataService.SetCounter then
        self._dataService:SetCounter(player, "distinct_pets", count)
    end
end

function PetIndexService:RecordPetObtained(player, petData)
    if type(petData) ~= "table" or type(petData.id) ~= "string" then
        return {
            ok = false,
            error = "Invalid pet data",
        }
    end

    local data = self._dataService:GetData(player)
    if not data then
        return {
            ok = false,
            error = "Player data not loaded",
        }
    end

    local variant = petData.variant or self._config.default_variant or "basic"
    local huge = petData.huge == true
    local key = petKey(petData.id, variant, huge)
    local index = self:_ensureIndex(data)
    local entry = index.Discovered[key]
    local isNew = entry == nil

    if isNew then
        index.Discovered[key] = {
            id = petData.id,
            variant = variant,
            huge = huge or nil,
            discovered_at = os.time(),
        }
    end

    local count = countMapEntries(index.Discovered)
    local granted = {}
    if isNew then
        self:_syncDistinctCounter(player, count)
        granted = self:_evaluateMilestones(player, index)
        self._dataService:RequestSave(player, "pet_index_discovered", { critical = true })
    end

    local snapshot = self:GetIndex(player)
    if isNew then
        self.IndexChanged:Fire(player, snapshot)
        Signals.PetIndexUpdated:FireClient(player, snapshot)
        fireGameEvent(player, "new_species", { key = key, count = count }) -- first discovery
    end

    return {
        ok = true,
        isNew = isNew,
        key = key,
        count = count,
        granted = granted,
    }
end

-- The collection DENOMINATOR: every entry a player can actually obtain, derived
-- from the egg defs (not the raw pets table, which includes unobtainable entries
-- like the creator-class pet). For each egg: its species x the variants its rolls
-- allow, plus a separate huge entry per huge-capable species. Adding an egg or a
-- species to a config grows the denominator automatically. Cached per boot.
function PetIndexService:_countObtainable()
    if self._obtainableTotal then
        return self._obtainableTotal
    end
    local entries = {}
    for _, egg in pairs(self._petsConfig.egg_sources or {}) do
        local allowed = allowedVariants(egg)
        for petId in pairs(egg.pet_weights or {}) do
            for _, v in ipairs(allowed) do
                entries[petKey(petId, v, false)] = true
            end
        end
        local huge = egg.huge
        if huge and (tonumber(huge.chance) or 0) > 0 then
            if huge.any_pet == true then
                -- ORTHOGONAL huges are CENSUS-GATED (Jason): an entry joins the
                -- obtainable index only once the FIRST one is minted anywhere in
                -- the realm — the index grows dynamically with global discovery
                -- (and index-completion luck self-adjusts as it does).
                for petId in pairs(egg.pet_weights or {}) do
                    for _, v in ipairs(allowed) do
                        if self._globalHuges[petId .. ":" .. v] then
                            entries[petKey(petId, v, true)] = true
                        end
                    end
                end
            else
                -- curated lists (colorado meet egg) stay statically obtainable
                for petId in pairs(huge.pets or {}) do
                    entries[petKey(petId, "basic", true)] = true
                end
            end
        end
    end
    local total = 0
    for _ in pairs(entries) do
        total += 1
    end
    self._obtainableTotal = math.max(total, 1)
    return self._obtainableTotal
end

-- Collection completion (0..1) — the input to hatch luck (configs/pets.lua
-- index_luck): discovered entries over obtainable entries. A natural cap: 100%
-- collection = the full configured bonus, and parking on one egg stops paying
-- the moment its entries are found.
function PetIndexService:GetCompletion(player)
    local total = self:_countObtainable()
    local data = self._dataService:GetData(player)
    local count = 0
    if data then
        count = countMapEntries(self:_ensureIndex(data).Discovered)
    end
    return {
        count = count,
        total = total,
        fraction = math.clamp(count / total, 0, 1),
    }
end

function PetIndexService:GetIndex(player)
    local data = self._dataService:GetData(player)
    if not data then
        return {
            count = 0,
            total = self:_countObtainable(),
            discovered = {},
            milestones = {},
        }
    end

    local index = self:_ensureIndex(data)
    return {
        count = countMapEntries(index.Discovered),
        total = self:_countObtainable(),
        discovered = index.Discovered,
        milestones = index.Milestones,
    }
end

return PetIndexService
