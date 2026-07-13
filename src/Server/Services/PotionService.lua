--[[
    PotionService — the "brew charge" potion engine (Potions S2; see configs/potions.lua + the
    pure math in src/Shared/Game/BrewMeter.lua).

    ONE METER PER AXIS. Drinking a potion consumes one from the "potions" inventory bucket and
    SIPS its meter (diminishing → asymptotes to the cap); a Heartbeat loop DRAINS every active
    meter, re-writing the BuffStack axis attribute as the magnitude tapers, and clears it at empty.
    The buff attribute write mirrors PowerService:_setAxisBuff (single `<attr>` + `<attr>Until`),
    so the existing buff consumers (mining/combat/luck/speed) pick potions up with no other change.

    Meter charge is TRANSIENT (in-memory): combat consumables reset on rejoin, by design. The
    inventory potions persist (they're real items — tradeable later). State is pushed to the
    client via the PotionUpdate RemoteEvent for the hotbar potion strip (SSOT render).

    Enemy-target debuff meters keep their charge on the target and use EnemyService's shared squad
    focus resolver. Their vulnerability rides VulnMark's additive source channels, so a potion never
    clobbers a power mark. Throw range and presentation are potion configuration.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local fireGameEvent = require(game:GetService("ReplicatedStorage").Shared.Network.FireGameEvent)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local BrewMeter = require(ReplicatedStorage.Shared.Game.BrewMeter)
local VulnMark = require(ReplicatedStorage.Shared.Game.VulnMark)
local Signals = require(ReplicatedStorage.Shared.Network.Signals)

local PotionService = {}
PotionService.__index = PotionService

local BUCKET = "potions" -- InventoryService bucket (trade-ready, like enhancements)
local SIP_LOCK = 0.4 -- anti-spam seconds between drinks of the SAME potion (not the duration)

function PotionService:Init()
    self._logger = self._modules and self._modules.Logger
    self._configLoader = self._modules and self._modules.ConfigLoader
    self._dataService = self._modules and self._modules.DataService
    self._inventoryService = self._modules and self._modules.InventoryService
    self._config = self._configLoader:LoadConfig("potions")
    self._meters = {} -- [userId][meterId] = charge (0..1), transient
    self._enemyMeters = setmetatable({}, { __mode = "k" }) -- [enemy Model][meterId] = charge
    self._lastDrink = {} -- [userId][potionId] = os.clock()

    self._remote = Signals.PotionUpdate
end

-- Explicit peer binding (audit architecture — no global locator).
function PotionService:BindPeerServices(services)
    self._hotbarService = services.HotbarService
    self._enemyService = services.EnemyService
end

function PotionService:Start()
    local accum = 0
    local tick = tonumber(self._config.tick_seconds) or 1
    RunService.Heartbeat:Connect(function(dt)
        accum += dt
        if accum < tick then
            return
        end
        local step = accum
        accum = 0
        self:_drainAll(step)
        self:_drainEnemyMeters(step)
    end)
    Players.PlayerRemoving:Connect(function(player)
        self._meters[player.UserId] = nil
        self._lastDrink[player.UserId] = nil
    end)
end

function PotionService:_canUse(player, potionId)
    local uid = player.UserId
    self._lastDrink[uid] = self._lastDrink[uid] or {}
    if (os.clock() - (self._lastDrink[uid][potionId] or 0)) < SIP_LOCK then
        return false, "too_fast"
    end
    return true
end

-- Consume exactly one matching stack entry. InventoryService owns stack mutation + persistence;
-- this service only resolves which entry backs the configured potion id.
function PotionService:_consumeOne(player, potionId)
    local inv = self._inventoryService
    if not inv then
        return false, "service_unavailable"
    end
    local bucket = inv:GetInventory(player, BUCKET)
    for uid, rec in pairs((bucket and bucket.items) or {}) do
        if rec.id == potionId and (tonumber(rec.quantity) or 1) > 0 then
            local ok = inv:RemoveItem(player, BUCKET, uid, 1)
            return ok == true, ok == true and nil or "consume_failed"
        end
    end
    return false, "none_left"
end

function PotionService:_finishUse(player, potionId)
    self._lastDrink[player.UserId][potionId] = os.clock()
    self:_push(player)
    fireGameEvent(player, "potion_used", { potion = potionId })
end

function PotionService:_potionCfg(potionId)
    return self._config.potions and self._config.potions[potionId]
end
function PotionService:_meterCfg(meterId)
    return self._config.meters and self._config.meters[meterId]
end

-- Total owned count of a potion id (sum stacked quantities in the bucket).
function PotionService:_count(player, potionId)
    local inv = self._inventoryService
    local bucket = inv and inv:GetInventory(player, BUCKET)
    local n = 0
    for _, rec in pairs((bucket and bucket.items) or {}) do
        if rec.id == potionId then
            n += math.max(1, math.floor(tonumber(rec.quantity) or 1))
        end
    end
    return n
end

-- Weighted-random pick of which potion a world drop yields (configs/potions.lua drops.weights).
-- Returns a potionId, or nil when drops are disabled / no valid weights. DropService calls this.
function PotionService:RollDrop()
    local drops = self._config and self._config.drops
    if not (drops and drops.enabled) then
        return nil
    end
    local weights = drops.weights or {}
    local total = 0
    for id, w in pairs(weights) do
        if self:_potionCfg(id) and (tonumber(w) or 0) > 0 then
            total += tonumber(w)
        end
    end
    if total <= 0 then
        return nil
    end
    local roll = math.random() * total
    local acc = 0
    for id, w in pairs(weights) do
        if self:_potionCfg(id) and (tonumber(w) or 0) > 0 then
            acc += tonumber(w)
            if roll <= acc then
                return id
            end
        end
    end
    return nil
end

-- Grant N of a potion into the bucket (drops / admin / test). Returns the new owned count.
function PotionService:Grant(player, potionId, count)
    count = math.max(1, math.floor(tonumber(count) or 1))
    if not self:_potionCfg(potionId) then
        return { ok = false, reason = "unknown_potion" }
    end
    local inv = self._inventoryService
    if not inv then
        return { ok = false, reason = "service_unavailable" }
    end
    for _ = 1, count do
        inv:AddItem(player, BUCKET, { id = potionId, category = "potions" })
    end
    -- potions fill from the TOP RIGHT of the hotbar (Jason) — usable immediately
    if self._hotbarService and self._hotbarService.AutoBindPotion then
        pcall(function()
            self._hotbarService:AutoBindPotion(player, potionId)
        end)
    end
    self:_push(player)
    return { ok = true, count = self:_count(player, potionId) }
end

-- Write (or clear) a meter's buff contribution.
--
-- A potion is its OWN buff source — it writes "<buff_attr>Potion" (NOT the power's "<buff_attr>"),
-- so a permanent power and a draining potion ADD on the axis instead of clobbering each other
-- (single attr + single Until can't hold both). Consumers sum the power attr + the Potion attr:
-- move_speed (init.client + PetFollowController), pet_damage (PetFollowService BuffStack list),
-- luck (EggService). The value is a RAW FRACTION (magnitude = charge × cap) for every axis — the
-- consumers add it directly (no -1), so it's correct on fraction- AND multiplier-convention axes.
function PotionService:_applyMeter(player, meterId, charge)
    local m = self:_meterCfg(meterId)
    if not m or m.target == "enemy" then
        return -- enemy debuffs apply at throw time (S2b)
    end
    local base = m.buff_attr
    if not base then
        return
    end
    local attr = base .. "Potion" -- potion's own source, summed alongside the power's <base>
    if charge and charge > 0 then
        player:SetAttribute(attr, BrewMeter.magnitude(charge, m.cap))
        player:SetAttribute(
            attr .. "Until",
            os.time() + BrewMeter.remainingSeconds(charge, m.drain_seconds)
        )
        -- Tag with a potion power-id so the unified badge (PetBadge.forPotion) resolves on the
        -- squad cards / player bar that key off "<attr>PowerId".
        player:SetAttribute(attr .. "PowerId", "potion_" .. meterId)
        player:SetAttribute("Brew_" .. meterId, charge) -- live pie source for the hotbar
    else
        player:SetAttribute(attr, nil)
        player:SetAttribute(attr .. "Until", 0)
        player:SetAttribute(attr .. "PowerId", nil)
        player:SetAttribute("Brew_" .. meterId, nil)
    end
end

-- Apply one enemy meter through the canonical additive vulnerability writer. Charge belongs to the
-- enemy, not the thrower: several vials top up the same target and the meter drains on that target.
function PotionService:_applyEnemyMeter(target, meterId, charge)
    local m = self:_meterCfg(meterId)
    if not (m and m.target == "enemy" and target and target.Parent) then
        return
    end
    local powerId = "potion_" .. meterId
    if charge and charge > 0 then
        local untilTime = os.time() + BrewMeter.remainingSeconds(charge, m.drain_seconds)
        VulnMark.apply(target, powerId, 1 + BrewMeter.magnitude(charge, m.cap), untilTime)
        target:SetAttribute("DebuffPowerId", powerId)
        target:SetAttribute("DebuffUntil", untilTime)
        target:SetAttribute("Brew_" .. meterId, charge)
    else
        VulnMark.apply(target, powerId, 1, 0)
        target:SetAttribute("Brew_" .. meterId, nil)
        if target:GetAttribute("DebuffPowerId") == powerId then
            target:SetAttribute("DebuffPowerId", nil)
            target:SetAttribute("DebuffUntil", 0)
        end
    end
end

-- Single public activation path for every potion. Callers do not need to know whether the item is
-- drunk or thrown; that adaptation is entirely described by its meter configuration.
function PotionService:Use(player, potionId)
    local pcfg = self:_potionCfg(potionId)
    local meter = pcfg and self:_meterCfg(pcfg.meter)
    if meter and meter.target == "enemy" then
        return self:Throw(player, potionId)
    end
    return self:Drink(player, potionId)
end

-- Drink one potion: consume from inventory, sip the meter (diminishing), write the buff.
function PotionService:Drink(player, potionId)
    local pcfg = self:_potionCfg(potionId)
    if not pcfg then
        return { ok = false, reason = "unknown_potion" }
    end
    local meterId = pcfg.meter
    local m = self:_meterCfg(meterId)
    if not m then
        return { ok = false, reason = "no_meter" }
    end
    if m.target == "enemy" then
        return { ok = false, reason = "enemy_target_requires_throw" }
    end

    local canUse, useReason = self:_canUse(player, potionId)
    if not canUse then
        return { ok = false, reason = useReason }
    end

    local uid = player.UserId
    self._meters[uid] = self._meters[uid] or {}
    local charge = self._meters[uid][meterId] or 0
    if BrewMeter.isFull(charge, m.full_threshold) then
        return { ok = false, reason = "meter_full" } -- a sip would be wasted; don't consume
    end

    local consumed, consumeReason = self:_consumeOne(player, potionId)
    if not consumed then
        return { ok = false, reason = consumeReason }
    end

    -- sip_fraction lives on the POTION (pcfg), not the meter — m.sip_fraction was nil, so the sip
    -- returned 0 and the buff was written at zero magnitude (drink consumed, nothing happened).
    charge = BrewMeter.sip(charge, pcfg.sip_fraction)
    self._meters[uid][meterId] = charge
    self:_applyMeter(player, meterId, charge)
    self:_finishUse(player, potionId)
    return { ok = true, charge = charge, count = self:_count(player, potionId) }
end

-- Throw one enemy-target potion at the squad's shared focus target. Explicit HUD focus wins, then
-- the target most pets are attacking, then the nearest enemy already aggro'd on the squad.
function PotionService:Throw(player, potionId)
    local pcfg = self:_potionCfg(potionId)
    if not pcfg then
        return { ok = false, reason = "unknown_potion" }
    end
    local meterId = pcfg.meter
    local m = self:_meterCfg(meterId)
    if not (m and m.target == "enemy") then
        return { ok = false, reason = "not_throwable" }
    end
    local throwCfg = type(pcfg.throw) == "table" and pcfg.throw or {}
    local enemyService = self._enemyService
    local target = enemyService
        and enemyService.GetFocusEnemy
        and enemyService:GetFocusEnemy(player)
    if not target then
        return { ok = false, reason = "no_enemy_target" }
    end
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local targetPart = target.PrimaryPart or target:FindFirstChildWhichIsA("BasePart")
    if not (root and targetPart) then
        return { ok = false, reason = "target_unavailable" }
    end
    local range = math.max(1, tonumber(throwCfg.range) or 100)
    if (targetPart.Position - root.Position).Magnitude > range then
        return { ok = false, reason = "target_out_of_range" }
    end
    local canUse, useReason = self:_canUse(player, potionId)
    if not canUse then
        return { ok = false, reason = useReason }
    end

    self._enemyMeters[target] = self._enemyMeters[target] or {}
    local charge = self._enemyMeters[target][meterId] or 0
    if BrewMeter.isFull(charge, m.full_threshold) then
        return { ok = false, reason = "meter_full" }
    end
    local consumed, consumeReason = self:_consumeOne(player, potionId)
    if not consumed then
        return { ok = false, reason = consumeReason }
    end

    charge = BrewMeter.sip(charge, pcfg.sip_fraction)
    self._enemyMeters[target][meterId] = charge
    self:_applyEnemyMeter(target, meterId, charge)
    Signals.Power_AreaFx:FireAllClients({
        primId = throwCfg.primitive or "ranged_bolt",
        element = throwCfg.element or "lava",
        kind = "target",
        caster = character,
        target = target,
    })
    self:_finishUse(player, potionId)
    return {
        ok = true,
        charge = charge,
        count = self:_count(player, potionId),
        target = target.Name,
    }
end

function PotionService:_drainAll(dt)
    for _, player in ipairs(Players:GetPlayers()) do
        local meters = self._meters[player.UserId]
        if meters then
            local changed = false
            for meterId, charge in pairs(meters) do
                if charge > 0 then
                    local m = self:_meterCfg(meterId)
                    local nc = BrewMeter.drain(charge, dt, m and m.drain_seconds)
                    meters[meterId] = nc
                    self:_applyMeter(player, meterId, nc)
                    if BrewMeter.isEmpty(nc) then
                        meters[meterId] = nil
                    end
                    changed = true
                end
            end
            if changed then
                self:_push(player)
            end
        end
    end
end

function PotionService:_drainEnemyMeters(dt)
    for target, meters in pairs(self._enemyMeters) do
        if not target.Parent or (tonumber(target:GetAttribute("HP")) or 0) <= 0 then
            self._enemyMeters[target] = nil
        else
            for meterId, charge in pairs(meters) do
                local m = self:_meterCfg(meterId)
                local nextCharge = BrewMeter.drain(charge, dt, m and m.drain_seconds)
                meters[meterId] = nextCharge
                self:_applyEnemyMeter(target, meterId, nextCharge)
                if BrewMeter.isEmpty(nextCharge) then
                    meters[meterId] = nil
                end
            end
            if next(meters) == nil then
                self._enemyMeters[target] = nil
            end
        end
    end
end

-- Client state for the hotbar potion strip: potions owned (counts) + live meters.
function PotionService:GetState(player)
    local inv = self._inventoryService
    local bucket = inv and inv:GetInventory(player, BUCKET)
    local counts = {}
    for _, rec in pairs((bucket and bucket.items) or {}) do
        if rec.id then
            counts[rec.id] = (counts[rec.id] or 0)
                + math.max(1, math.floor(tonumber(rec.quantity) or 1))
        end
    end
    local potions = {}
    for id, count in pairs(counts) do
        local p = self:_potionCfg(id)
        if p then
            potions[#potions + 1] =
                { id = id, count = count, meter = p.meter, icon = p.icon, name = p.display_name }
        end
    end
    table.sort(potions, function(a, b)
        return tostring(a.id) < tostring(b.id)
    end)

    local meters = {}
    local mstate = self._meters[player.UserId] or {}
    for meterId, m in pairs(self._config.meters or {}) do
        local charge = mstate[meterId] or 0
        meters[meterId] = {
            charge = charge,
            cap = m.cap,
            drain_seconds = m.drain_seconds,
            remaining = BrewMeter.remainingSeconds(charge, m.drain_seconds),
            color = m.color,
            icon = m.icon,
            display_name = m.display_name,
            target = m.target,
            maintain_at = m.maintain_at, -- lock auto-drink threshold (nil = no auto-maintain)
        }
    end
    return { ok = true, potions = potions, meters = meters, serverTime = os.time() }
end

function PotionService:_push(player)
    if self._remote then
        self._remote:FireClient(player, self:GetState(player))
    end
end

return PotionService
