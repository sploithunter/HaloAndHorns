--[[
    RosterService — Feature 17 (Roster System).

    Owns profile.Rosters (name -> { name, ordered_pets, max_to_deploy, injury_rule }).
    Invoking a roster replaces the active squad with up to max_to_deploy pets chosen
    per the injury rule (using Spirit-Form readiness). Pet refs are removed from all
    rosters on delete/trade. Pure rules: `src/Shared/Game/RosterLogic.lua`.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RosterLogic = require(ReplicatedStorage.Shared.Game.RosterLogic)

local RosterService = {}
RosterService.__index = RosterService

function RosterService:Init()
    self._logger = self._modules and self._modules.Logger
    self._configLoader = self._modules and self._modules.ConfigLoader
    self._dataService = self._modules and self._modules.DataService
    self._config = self._configLoader:LoadConfig("rosters")
    local squad = self._configLoader:LoadConfig("squad")
    self._capacity = (squad and squad.limits and squad.limits.active_squad) or 5
end

function RosterService:_service(name)
    local locator = _G.RBXTemplateServices
    if not locator then
        return nil
    end
    local ok, service = pcall(function()
        return locator:Get(name)
    end)
    return ok and service or nil
end

local function rostersMap(data)
    if type(data.Rosters) ~= "table" then
        data.Rosters = {}
    end
    return data.Rosters
end

local function isValidRule(rule, config)
    for _, r in ipairs(config.injury_rules or {}) do
        if r == rule then
            return true
        end
    end
    return false
end

function RosterService:List(player)
    local data = self._dataService:GetData(player)
    if not data then
        return { ok = false, reason = "data_not_loaded" }
    end
    return { ok = true, rosters = rostersMap(data) }
end

function RosterService:Create(player, name, orderedPets, maxToDeploy, injuryRule)
    local data = self._dataService:GetData(player)
    if not data then
        return { ok = false, reason = "data_not_loaded" }
    end
    if type(name) ~= "string" or name == "" then
        return { ok = false, reason = "invalid_name" }
    end
    local rule = injuryRule or self._config.default_injury_rule
    if not isValidRule(rule, self._config) then
        return { ok = false, reason = "invalid_injury_rule" }
    end
    local roster = {
        name = name,
        ordered_pets = orderedPets or {},
        max_to_deploy = RosterLogic.clampMaxToDeploy(maxToDeploy or self._capacity, self._capacity),
        injury_rule = rule,
    }
    rostersMap(data)[name] = roster
    self._dataService:RequestSave(player, "roster_create", { critical = true })
    return { ok = true, roster = roster }
end

-- Build pet readiness states from Spirit Form (ready + recovery for sorting).
function RosterService:_petStates(player, orderedPets)
    local spirit = self:_service("SpiritFormService")
    local states = {}
    if not spirit then
        return states -- all treated as ready
    end
    for _, ref in ipairs(orderedPets or {}) do
        local status = spirit:Status(player, ref)
        if status.ok then
            states[ref] = {
                ready = status.deployable == true,
                recovery = -(tonumber(status.remaining) or 0), -- less remaining = more recovered
            }
        end
    end
    return states
end

function RosterService:Invoke(player, name)
    local data = self._dataService:GetData(player)
    if not data then
        return { ok = false, reason = "data_not_loaded" }
    end
    local roster = rostersMap(data)[name]
    if not roster then
        return { ok = false, reason = "roster_not_found" }
    end
    local states = self:_petStates(player, roster.ordered_pets)
    local deploy = RosterLogic.resolveDeploy(
        roster.ordered_pets,
        states,
        roster.max_to_deploy,
        roster.injury_rule
    )
    -- Replace the active squad (roster invocation is a replacement, not addition).
    data.ActiveSquad = deploy
    self._dataService:RequestSave(player, "roster_invoke", { critical = true })
    return { ok = true, squad = deploy }
end

-- Remove a pet ref from every roster (on permanent delete / trade-away).
function RosterService:RemovePetReference(player, petRef)
    local data = self._dataService:GetData(player)
    if not data then
        return { ok = false, reason = "data_not_loaded" }
    end
    local removed = false
    for _, roster in pairs(rostersMap(data)) do
        local before = #roster.ordered_pets
        roster.ordered_pets = RosterLogic.removeRef(roster.ordered_pets, petRef)
        if #roster.ordered_pets ~= before then
            removed = true
        end
    end
    if removed then
        self._dataService:RequestSave(player, "roster_remove_ref", { critical = true })
    end
    return { ok = true, removed = removed }
end

return RosterService
