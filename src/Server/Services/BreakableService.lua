--[[
    BreakableService
    - Handles c->s Breakables_Attack events from clients (auto-target or clicks)
    - Assigns player's pets to the target model by setting TargetType/World/ID
    - Applies damage by reducing target HP (death/awards handled by spawner)
]]

local BreakableService = {}
BreakableService.__index = BreakableService

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local CombatApplication = require(script.Parent.Parent.CombatApplication)

local logger
local configLoader

-- Debounce map: player -> last attack tick
local lastAttack = {}

local function findBreakableById(id)
    local gameFolder = workspace:FindFirstChild("Game")
    if not gameFolder then
        return nil
    end
    local breakables = gameFolder:FindFirstChild("Breakables")
    if not breakables then
        return nil
    end
    for _, typeFolder in ipairs(breakables:GetChildren()) do
        for _, worldFolder in ipairs(typeFolder:GetChildren()) do
            local items = worldFolder:FindFirstChild("Items")
            if items then
                for _, model in ipairs(items:GetChildren()) do
                    local bId = model:FindFirstChild("BreakableID")
                    if bId and bId.Value == id then
                        return model
                    end
                end
            end
        end
    end
    return nil
end

-- Combat outranks auto-mine: a pet currently locked on a LIVE enemy must not be
-- yanked back to a crystal by auto-targeting (otherwise pets scatter mid-fight
-- instead of attacking back). True only while that enemy still exists with HP > 0.
local function petLockedOnLiveEnemy(petInst)
    local tt = petInst:FindFirstChild("TargetType")
    local tid = petInst:FindFirstChild("TargetID")
    if not (tt and tt.Value == "Enemy" and tid and tid.Value ~= 0) then
        return false
    end
    local gameFolder = workspace:FindFirstChild("Game")
    local enemies = gameFolder and gameFolder:FindFirstChild("Enemies")
    if not enemies then
        return false
    end
    for _, m in ipairs(enemies:GetChildren()) do
        local bid = m:FindFirstChild("BreakableID")
        if bid and bid.Value == tid.Value and (m:GetAttribute("HP") or 0) > 0 then
            return true
        end
    end
    return false
end

local function assignPlayerPetsToTarget(player, breakableModel)
    if not player or not breakableModel then
        return
    end
    local petInstancesFolder = workspace:FindFirstChild("PlayerPets")
    if not petInstancesFolder then
        return
    end
    local playerPets = petInstancesFolder:FindFirstChild(player.Name)
    if not playerPets then
        return
    end

    -- Determine world name from ancestry: ...Breakables/<Type>/<World>/Items/<Model>
    local worldName = ""
    do
        local parent = breakableModel.Parent
        local worldFolder = parent and parent.Parent
        worldName = worldFolder and worldFolder.Name or ""
    end

    local targetId = breakableModel:FindFirstChild("BreakableID")
            and breakableModel.BreakableID.Value
        or 0
    for _, petInst in ipairs(playerPets:GetChildren()) do
        local petIdVal = petInst:FindFirstChild("PetID")
        local targetIdVal = petInst:FindFirstChild("TargetID")
        local targetTypeVal = petInst:FindFirstChild("TargetType")
        local targetWorldVal = petInst:FindFirstChild("TargetWorld")
        if petIdVal and targetIdVal and targetTypeVal and targetWorldVal then
            -- Skip pets locked on a live enemy (attack back) AND downed pets
            -- (they are out healing — must not be pulled into mining).
            if not petLockedOnLiveEnemy(petInst) and not petInst:GetAttribute("CombatDowned") then
                targetTypeVal.Value = "Crystals"
                targetWorldVal.Value = worldName
                targetIdVal.Value = targetId
            end
        end
    end

    -- Mirror MCP: add an entry to crystal's Pets folder (optional, helpful for effects)
    local petsFolder = breakableModel:FindFirstChild("Pets") or Instance.new("Folder")
    petsFolder.Name = "Pets"
    petsFolder.Parent = breakableModel
    -- Add a consolidated marker per player to avoid N duplicates
    local key = "P_" .. tostring(player.UserId)
    local existing = petsFolder:FindFirstChild(key)
    if not existing then
        existing = Instance.new("NumberValue")
        existing.Name = key
        existing.Value = 1
        existing.Parent = petsFolder
    end
end

function BreakableService:Init()
    logger = self._modules.Logger
    configLoader = self._modules.ConfigLoader

    local Signals = require(ReplicatedStorage.Shared.Network.Signals)
    Signals.Breakables_Attack.OnServerEvent:Connect(function(player, payload)
        local ok, err = pcall(function()
            -- NEVER trust client damage (payload.damage was applied verbatim - an
            -- exploit hole). Clients cannot deal breakable damage AT ALL (the
            -- design firewall: players amplify via Boost, pets deal) - a client
            -- request only assigns pets to the node.
            local sanitized = type(payload) == "table" and { id = payload.id, damage = 0 }
                or payload
            self:_onAttack(player, sanitized)
        end)
        if not ok then
            logger:Warn("Breakables_Attack handler error", { error = tostring(err) })
        end
    end)

    logger:Info("BreakableService initialized")
end

function BreakableService:_onAttack(player, payload)
    if not player or not player:IsA("Player") then
        return
    end
    if type(payload) ~= "table" then
        return
    end
    local id = tonumber(payload.id)
    local dmg = tonumber(payload.damage) or 1

    -- basic rate limit
    local now = tick()
    if lastAttack[player] and now - lastAttack[player] < 0.05 then
        return
    end
    lastAttack[player] = now

    local target = findBreakableById(id)
    if not target or not target:GetAttribute("HP") then
        return
    end

    -- Ensure pets are assigned to this target for follow/damage behavior
    assignPlayerPetsToTarget(player, target)

    -- The client path is sanitized to zero damage above; any future server-owned direct strike still
    -- uses the authoritative damage + contribution + combat-result contract.
    CombatApplication.ApplyDamage(target, dmg, {
        sourcePlayer = player,
        kind = "breakable_attack",
    })

    -- Do not destroy here; BreakableSpawner listens to HP attribute and handles death/awards
end

function BreakableService:Attack(player, payload)
    return self:_onAttack(player, payload)
end

return BreakableService
