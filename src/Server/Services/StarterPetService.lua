--[[
    Server-authoritative one-time first-companion choice.

    The free companion is an individually tracked, locked BASIC pet. It is automatically
    deployed, but it does not consume or alter the existing lucky first Earth Egg hatch.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StarterPetChoice = require(ReplicatedStorage.Shared.Game.StarterPetChoice)
local Signals = require(ReplicatedStorage.Shared.Network.Signals)
local fireGameEvent = require(ReplicatedStorage.Shared.Network.FireGameEvent)
local Readiness = require(ReplicatedStorage.Shared.Utils.Readiness)

local StarterPetService = {}
StarterPetService.__index = StarterPetService

function StarterPetService:Init()
    self._logger = self._modules.Logger
    self._configLoader = self._modules.ConfigLoader
    self._dataService = self._modules.DataService
    self._inventoryService = self._modules.InventoryService
    self._petGrantService = self._modules.PetGrantService
    self._config = self._configLoader:LoadConfig("starter_pets")
    self._choosing = {}
    self._shown = {}
end

function StarterPetService:Start()
    Signals.StarterPetStateRequest.OnServerEvent:Connect(function(player)
        self:_push(player)
    end)
    Signals.StarterPetChoose.OnServerEvent:Connect(function(player, request)
        self:_choose(player, request)
    end)
    Players.PlayerRemoving:Connect(function(player)
        self._choosing[player] = nil
        self._shown[player] = nil
    end)
end

function StarterPetService:_reconcile(player, data)
    local granted = StarterPetChoice.findGrantedStarter(data)
    if not granted then
        return false
    end
    local saved = data.StarterPet
    if type(saved) == "table" and type(saved.choice) == "string" then
        return false
    end
    data.StarterPet = {
        choice = granted.id,
        chosenAt = tonumber(granted.obtained_at) or os.time(),
        version = tonumber(self._config.version) or 1,
        uid = granted.uid,
        recovered = true,
    }
    self._dataService:RequestSave(player, "starter_pet_reconciled", { critical = true })
    return true
end

function StarterPetService:_push(player, extra)
    if not self._dataService:IsDataLoaded(player) then
        task.spawn(function()
            if Readiness.awaitAttribute(player, "DataLoaded", true, 20) and player.Parent then
                self:_push(player, extra)
            end
        end)
        return
    end
    local data = self._dataService:GetData(player)
    if not data then
        return
    end
    self:_reconcile(player, data)
    local state = StarterPetChoice.stateFor(self._config, data)
    if type(extra) == "table" then
        for key, value in pairs(extra) do
            state[key] = value
        end
    end
    Signals.StarterPetState:FireClient(player, state)
    if state.eligible and not self._shown[player] then
        self._shown[player] = true
        fireGameEvent(player, "starter_pet_choice_shown", {
            version = state.version,
            choiceCount = #(state.choices or {}),
        })
    end
end

local function firstFreeSlot(equipped)
    for index = 1, 10 do
        local key = "slot_" .. tostring(index)
        if equipped[key] == nil then
            return key
        end
    end
    return nil
end

function StarterPetService:_choose(player, request)
    if self._choosing[player] then
        return
    end
    self._choosing[player] = true

    local function finish(extra)
        self._choosing[player] = nil
        if player.Parent then
            self:_push(player, extra)
        end
    end

    if not self._dataService:IsDataLoaded(player) then
        finish({ error = "Your data is still loading. Try again." })
        return
    end
    local data = self._dataService:GetData(player)
    self:_reconcile(player, data)
    if not StarterPetChoice.isEligible(self._config, data) then
        finish({ error = "Your starter companion was already chosen." })
        return
    end
    local petType = type(request) == "table" and request.petType or nil
    local choice = StarterPetChoice.choiceById(self._config, petType)
    if not choice then
        finish({ error = "Choose one of the four starter companions." })
        return
    end

    local grant = self._config.grant or {}
    local result = self._petGrantService:GrantPet(player, {
        petType = choice.id,
        variant = grant.variant or "basic",
        source = grant.source or "starter_choice",
        locked = grant.locked == true,
        unique = grant.unique == true,
    })
    if type(result) ~= "table" or result.ok ~= true then
        self._logger:Warn("Starter companion grant failed", {
            player = player.Name,
            petType = choice.id,
            err = type(result) == "table" and result.error or "unknown",
        })
        finish({ error = "That companion could not join you. Please try again." })
        return
    end

    data.StarterPet = {
        choice = choice.id,
        chosenAt = os.time(),
        version = tonumber(self._config.version) or 1,
        uid = result.uid,
    }
    if grant.auto_equip == true then
        data.Equipped = type(data.Equipped) == "table" and data.Equipped or {}
        data.Equipped.pets = type(data.Equipped.pets) == "table" and data.Equipped.pets or {}
        local slot = firstFreeSlot(data.Equipped.pets)
        if slot then
            data.Equipped.pets[slot] = result.uid
        end
    end
    self._inventoryService:RebuildPetProjections(player)
    self._dataService:RequestSave(player, "starter_pet_selected", {
        critical = true,
        debounceSeconds = 0,
    })
    fireGameEvent(player, "starter_pet_selected", {
        petType = choice.id,
        role = choice.role,
        variant = grant.variant or "basic",
    })
    self._logger:Info("Starter companion selected", {
        player = player.Name,
        petType = choice.id,
        role = choice.role,
        uid = result.uid,
    })
    finish({ granted = true, grantedPet = choice.id })
end

return StarterPetService
