-- Hides the unreleased Merge-place prompt from public players.
-- The server repeats the same ID check and remains authoritative if a client is modified.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ConfigLoader = require(ReplicatedStorage.Shared.ConfigLoader)
local MergeEggGateAccess = require(ReplicatedStorage.Shared.Game.MergeEggGateAccess)

local RestrictedMergeGate = {}
local started = false

function RestrictedMergeGate.start()
    if started then
        return
    end
    started = true

    local mergeConfig = ConfigLoader:LoadConfig("merge_egg_prototype") or {}
    local internalAccounts = ConfigLoader:LoadConfig("internal_accounts") or {}
    local gate = mergeConfig.gate or {}
    local access = gate.access or {}
    local player = Players.LocalPlayer
    local allowed = (RunService:IsStudio() and access.studio_bypass == true)
        or MergeEggGateAccess.allows(access, internalAccounts, player.UserId)
    local promptName = tostring(gate.prompt_name or "MergeEggPrototypeEnterPrompt")

    local function apply(instance)
        if instance:IsA("ProximityPrompt") and instance.Name == promptName then
            instance.Enabled = allowed
        end
    end

    for _, instance in ipairs(Workspace:GetDescendants()) do
        apply(instance)
    end
    Workspace.DescendantAdded:Connect(apply)
end

return RestrictedMergeGate
