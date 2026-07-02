--[[
    SpiritFormService — Feature 7 (Halo & Horns).

    Spirit Form state for unique pets: reads/writes lastDownedAt + cooldown_seconds
    on the pet's inventory record (by uid), using the pure SpiritForm core. When a
    pet is downed it auto-returns from the active squad (Feature 9). Real combat
    "down" triggers arrive in Phase 4; downing is exposed as a test command now.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SpiritForm = require(ReplicatedStorage.Shared.Game.SpiritForm)

local SpiritFormService = {}
SpiritFormService.__index = SpiritFormService

function SpiritFormService:Init()
    self._logger = self._modules and self._modules.Logger
    self._configLoader = self._modules and self._modules.ConfigLoader
    self._dataService = self._modules and self._modules.DataService
    self._inventoryService = self._modules and self._modules.InventoryService
    self._activeSquadService = self._modules and self._modules.ActiveSquadService
    self._config = self._configLoader:LoadConfig("spirit_form")
end

function SpiritFormService:Status(player, uid, inHeaven)
    local pet = self._inventoryService:GetItem(player, "pets", uid)
    if not pet then
        return { ok = false, reason = "pet_not_found" }
    end
    local s = SpiritForm.status(pet, os.time(), inHeaven == true, self._config)
    return { ok = true, state = s.state, deployable = s.deployable, remaining = s.remaining }
end

-- Down a unique pet (sets lastDownedAt + the tier cooldown) and auto-return it
-- from the active squad.
function SpiritFormService:Down(player, uid, tier)
    local pet = self._inventoryService:GetItem(player, "pets", uid)
    if not pet then
        return { ok = false, reason = "pet_not_found" }
    end
    pet.lastDownedAt = os.time()
    pet.cooldown_seconds = SpiritForm.cooldownForTier(tier, self._config)
    if self._activeSquadService then
        self._activeSquadService:Remove(player, uid) -- auto-return to bench
    end
    self._dataService:RequestSave(player, "pet_downed", { critical = true })
    return {
        ok = true,
        lastDownedAt = pet.lastDownedAt,
        cooldown_seconds = pet.cooldown_seconds,
    }
end

function SpiritFormService:InstantRecharge(player, uid)
    local pet = self._inventoryService:GetItem(player, "pets", uid)
    if not pet then
        return { ok = false, reason = "pet_not_found" }
    end
    pet.lastDownedAt = nil
    self._dataService:RequestSave(player, "pet_recharge", { critical = true })
    return { ok = true }
end

return SpiritFormService
