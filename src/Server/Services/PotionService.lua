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

    Enemy-target debuff meters (target = "enemy") are recognized but applied at throw time — that's
    S2b; this slice ships the self-buffs (damage / luck / speed).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local BrewMeter = require(ReplicatedStorage.Shared.Game.BrewMeter)

local PotionService = {}
PotionService.__index = PotionService

local BUCKET = "potions" -- InventoryService bucket (trade-ready, like enhancements)
local UPDATE_REMOTE = "PotionUpdate"
local SIP_LOCK = 0.4 -- anti-spam seconds between drinks of the SAME potion (not the duration)

function PotionService:Init()
    self._logger = self._modules and self._modules.Logger
    self._configLoader = self._modules and self._modules.ConfigLoader
    self._dataService = self._modules and self._modules.DataService
    self._config = self._configLoader:LoadConfig("potions")
    self._meters = {} -- [userId][meterId] = charge (0..1), transient
    self._lastDrink = {} -- [userId][potionId] = os.clock()

    local existing = ReplicatedStorage:FindFirstChild(UPDATE_REMOTE)
    if existing then
        existing:Destroy()
    end
    local remote = Instance.new("RemoteEvent")
    remote.Name = UPDATE_REMOTE
    remote.Parent = ReplicatedStorage
    self._remote = remote
end

function PotionService:_inventoryService()
    local locator = _G.RBXTemplateServices
    local ok, svc = pcall(function()
        return locator and locator:Get("InventoryService")
    end)
    return ok and svc or nil
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
    end)
    Players.PlayerRemoving:Connect(function(player)
        self._meters[player.UserId] = nil
        self._lastDrink[player.UserId] = nil
    end)
end

function PotionService:_potionCfg(potionId)
    return self._config.potions and self._config.potions[potionId]
end
function PotionService:_meterCfg(meterId)
    return self._config.meters and self._config.meters[meterId]
end

-- Total owned count of a potion id (sum stacked quantities in the bucket).
function PotionService:_count(player, potionId)
    local inv = self:_inventoryService()
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
    local inv = self:_inventoryService()
    if not inv then
        return { ok = false, reason = "service_unavailable" }
    end
    for _ = 1, count do
        inv:AddItem(player, BUCKET, { id = potionId, category = "potions" })
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
        return { ok = false, reason = "throwable_not_supported" } -- S2b
    end

    local uid = player.UserId
    self._lastDrink[uid] = self._lastDrink[uid] or {}
    if (os.clock() - (self._lastDrink[uid][potionId] or 0)) < SIP_LOCK then
        return { ok = false, reason = "too_fast" }
    end

    self._meters[uid] = self._meters[uid] or {}
    local charge = self._meters[uid][meterId] or 0
    if BrewMeter.isFull(charge, m.full_threshold) then
        return { ok = false, reason = "meter_full" } -- a sip would be wasted; don't consume
    end

    local inv = self:_inventoryService()
    if not inv then
        return { ok = false, reason = "service_unavailable" }
    end
    local bucket = inv:GetInventory(player, BUCKET)
    local targetUid
    for u, rec in pairs((bucket and bucket.items) or {}) do
        if rec.id == potionId and (tonumber(rec.quantity) or 1) > 0 then
            targetUid = u
            break
        end
    end
    if not targetUid then
        return { ok = false, reason = "none_left" }
    end
    inv:RemoveItem(player, BUCKET, targetUid, 1)

    self._lastDrink[uid][potionId] = os.clock()
    -- sip_fraction lives on the POTION (pcfg), not the meter — m.sip_fraction was nil, so the sip
    -- returned 0 and the buff was written at zero magnitude (drink consumed, nothing happened).
    charge = BrewMeter.sip(charge, pcfg.sip_fraction)
    self._meters[uid][meterId] = charge
    self:_applyMeter(player, meterId, charge)
    self:_push(player)
    return { ok = true, charge = charge, count = self:_count(player, potionId) }
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

-- Client state for the hotbar potion strip: potions owned (counts) + live meters.
function PotionService:GetState(player)
    local inv = self:_inventoryService()
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
