--[[
    PetAbilityService

    Bridges configured pet-variant abilities into the shared modifier pipeline
    and publishes the passive world-facing values used by loot collection and
    pet movement/survival. Active combat procs are executed by
    PetFollowService; this service owns equipped-squad aggregation.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local PetAbilityRuntime = require(ReplicatedStorage.Shared.Game.PetAbilityRuntime)

local PetAbilityService = {}
PetAbilityService.__index = PetAbilityService

local function petFolder(player)
    local root = Workspace:FindFirstChild("PlayerPets")
    return root and player and root:FindFirstChild(player.Name)
end

function PetAbilityService:Init()
    self._logger = self._modules.Logger
    self._configLoader = self._modules.ConfigLoader
    self._modifierService = self._modules.ModifierService
    self._petsConfig = self._configLoader:LoadConfig("pets")
    self._profiles = setmetatable({}, { __mode = "k" })

    self._modifierService:RegisterProvider("pet_stats", function(context)
        return self:_modifierContributions(context)
    end)
end

function PetAbilityService:_profile(pet)
    local profile = self._profiles[pet]
    if not profile then
        profile = PetAbilityRuntime.resolve(
            self._petsConfig,
            pet:GetAttribute("PetType"),
            pet:GetAttribute("PetVariant") or "basic"
        )
        self._profiles[pet] = profile
    end
    return profile
end

function PetAbilityService:_pets(player)
    local folder = petFolder(player)
    return folder and folder:GetChildren() or {}
end

function PetAbilityService:_modifierContributions(context)
    if type(context) ~= "table" or not context.player then
        return {}
    end

    local best = nil
    for _, pet in ipairs(self:_pets(context.player)) do
        if not pet:GetAttribute("CombatDowned") then
            local passive = self:_profile(pet).passive or {}
            local amount
            local combine
            if context.kind == "hatch_luck" then
                amount = (tonumber(passive.luck_boost) or 0)
                    + math.max(0, (tonumber(passive.party_luck_boost) or 1) - 1)
                combine = "add"
            elseif context.kind == "breakable_reward" then
                amount = math.max(
                    0,
                    (tonumber(passive.coin_bonus) or 1) * (tonumber(passive.all_bonus) or 1) - 1
                )
                combine = "multiply"
                amount = 1 + amount
            elseif
                context.kind == "pet_efficiency"
                and context.petId == pet:GetAttribute("PetType")
                and (context.variant or "basic") == (pet:GetAttribute("PetVariant") or "basic")
            then
                local speed = tonumber(passive.attack_speed_multiplier)
                if speed and speed > 0 then
                    amount = speed
                    combine = "multiply"
                end
            end

            -- Equipped copies of the same economy aura do not multiply into an
            -- unbounded stack. The strongest live pet supplies the party passive.
            if amount and (not best or amount > best.amount) then
                best = {
                    id = "pet_ability:" .. tostring(pet:GetAttribute("PetType")),
                    label = "Pet ability",
                    amount = amount,
                    combine = combine,
                }
            end
        end
    end

    return best and { best } or {}
end

function PetAbilityService:_stampPlayer(player)
    local collectRange = 0
    local rareDropBonus = 0
    local rareDropPull = false
    for _, pet in ipairs(self:_pets(player)) do
        local passive = self:_profile(pet).passive or {}
        collectRange = math.max(collectRange, tonumber(passive.coin_attraction_range) or 0)
        rareDropBonus =
            math.max(rareDropBonus, math.max(0, (tonumber(passive.rare_drop_chance) or 1) - 1))
        rareDropPull = rareDropPull or passive.rare_drop_pull == true

        local moveMult = (tonumber(passive.movement_speed) or 1)
            * (tonumber(passive.speed_boost) or 1)
        pet:SetAttribute("MoveSpeedMult", moveMult)
        pet:SetAttribute("AbilityDodgeChance", tonumber(passive.dodge_chance) or 0)
        pet:SetAttribute("AbilityMaxRevives", tonumber(passive.max_revives) or 0)
        pet:SetAttribute("AbilityNeverAbandons", passive.never_abandons_owner == true)
        pet:SetAttribute("AbilityCanFly", passive.can_fly == true)
        pet:SetAttribute("AbilityPhaseThroughWalls", passive.phase_through_walls == true)
        pet:SetAttribute("AbilityTeleportToEnemies", passive.teleport_to_enemies == true)
    end
    player:SetAttribute("PetAbilityCollectRange", collectRange)
    player:SetAttribute("PetAbilityDropRate", rareDropBonus)
    player:SetAttribute("PetAbilityRareDropPull", rareDropPull)
end

function PetAbilityService:Start()
    local elapsed = 2
    RunService.Heartbeat:Connect(function(dt)
        elapsed += dt
        if elapsed >= 2 then
            elapsed = 0
            for _, player in ipairs(Players:GetPlayers()) do
                pcall(function()
                    self:_stampPlayer(player)
                end)
            end
        end
    end)
    self._logger:Info("PetAbilityService active", { context = "PetAbilityService" })
end

return PetAbilityService
