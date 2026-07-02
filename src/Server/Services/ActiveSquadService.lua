--[[
    ActiveSquadService — Feature 9 (Halo & Horns).

    Owns profile.ActiveSquad (an array of pet refs: unique uids or stack keys).
    Deploy/remove/swap go through the pure ActiveSquad rules (max size; in-combat
    swap cooldown — session-only, resets on rejoin). A stacked pet occupies one
    slot. Lazy-init/persist.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ActiveSquad = require(ReplicatedStorage.Shared.Game.ActiveSquad)

local ActiveSquadService = {}
ActiveSquadService.__index = ActiveSquadService

function ActiveSquadService:Init()
    self._logger = self._modules and self._modules.Logger
    self._configLoader = self._modules and self._modules.ConfigLoader
    self._dataService = self._modules and self._modules.DataService
    self._inventoryService = self._modules and self._modules.InventoryService
    self._config = self._configLoader:LoadConfig("squad")
    self._lastSwap = {} -- userId -> last swap os.time() (session-only)
end

local function squadOf(data)
    if type(data.ActiveSquad) ~= "table" then
        data.ActiveSquad = {}
    end
    return data.ActiveSquad
end

local function indexOf(squad, ref)
    for i, v in ipairs(squad) do
        if v == ref then
            return i
        end
    end
    return nil
end

-- Runtime lookup of SpiritFormService (locator, not a boot dep — SpiritFormService
-- depends on this service for auto-return, so we avoid a registration cycle).
local function spiritFormService()
    local locator = _G.RBXTemplateServices
    if not locator then
        return nil
    end
    local ok, service = pcall(function()
        return locator:Get("SpiritFormService")
    end)
    return ok and service or nil
end

function ActiveSquadService:Get(player)
    local data = self._dataService:GetData(player)
    return data and squadOf(data) or {}
end

function ActiveSquadService:Deploy(player, ref)
    local data = self._dataService:GetData(player)
    if not data then
        return { ok = false, reason = "data_not_loaded" }
    end
    if self._inventoryService and not self._inventoryService:GetItem(player, "pets", ref) then
        return { ok = false, reason = "pet_not_owned" }
    end
    -- A unique pet in Spirit Form cannot be deployed during cooldown (Feature 7).
    local spirit = spiritFormService()
    if spirit then
        local status = spirit:Status(player, ref)
        if status.ok and status.deployable == false then
            return { ok = false, reason = "pet_in_spirit_form" }
        end
    end
    local squad = squadOf(data)
    if indexOf(squad, ref) then
        return { ok = true, squad = squad, alreadyDeployed = true }
    end
    local decision = ActiveSquad.canDeploy(#squad, self._config.limits.active_squad)
    if not decision.ok then
        return { ok = false, reason = decision.reason }
    end
    table.insert(squad, ref)
    self._dataService:RequestSave(player, "squad_deploy", { critical = true })
    return { ok = true, squad = squad }
end

function ActiveSquadService:Remove(player, ref)
    local data = self._dataService:GetData(player)
    if not data then
        return { ok = false, reason = "data_not_loaded" }
    end
    local squad = squadOf(data)
    local i = indexOf(squad, ref)
    if not i then
        return { ok = true, squad = squad, removed = false }
    end
    table.remove(squad, i)
    self._dataService:RequestSave(player, "squad_remove", { critical = true })
    return { ok = true, squad = squad, removed = true }
end

function ActiveSquadService:Swap(player, outRef, inRef, inCombat)
    local now = os.time()
    local decision = ActiveSquad.canSwap(
        inCombat == true,
        self._lastSwap[player.UserId],
        now,
        self._config.swap_cooldown_seconds
    )
    if not decision.ok then
        return { ok = false, reason = decision.reason, remaining = decision.remaining }
    end
    self:Remove(player, outRef)
    local deploy = self:Deploy(player, inRef)
    if not deploy.ok then
        return deploy
    end
    self._lastSwap[player.UserId] = now
    return { ok = true, squad = deploy.squad }
end

return ActiveSquadService
