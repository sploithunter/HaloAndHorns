-- Standalone preview place only; never mapped into the production project.
local RunService = game:GetService("RunService")
if not RunService:IsStudio() then
    return
end
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
Players.CharacterAutoLoads = false
local lab = require(ReplicatedStorage.Configs.vfx.lab)
local schema = require(ReplicatedStorage.Configs.vfx.crystal_schema)
local timeline = require(ReplicatedStorage.Shared.Effects.CrystalTimeline)
local remote = Instance.new("RemoteFunction")
remote.Name = "VFXLabSave"
local lastSave = {}
remote.OnServerInvoke = function(player, preset)
    local now = os.clock()
    if lastSave[player] and now - lastSave[player] < lab.save_cooldown then
        return false, "Please wait before saving again."
    end
    lastSave[player] = now
    local valid, message = timeline.validate(preset, schema)
    if not valid then
        return false, message
    end
    local encoded = HttpService:JSONEncode(preset)
    if #encoded > lab.max_save_bytes then
        return false, "Preset is too large."
    end
    local ok, result = pcall(function()
        return HttpService:RequestAsync({
            Url = lab.save_url,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = encoded,
        })
    end)
    if not ok then
        return false, "Start scripts/vfx_lab/serve.py; check Studio HTTP access."
    end
    if not result.Success then
        return false, "Save rejected: " .. result.Body
    end
    return true, "Saved to configs/vfx/crystal_eruption.lua"
end
Players.PlayerRemoving:Connect(function(player)
    lastSave[player] = nil
end)
remote.Parent = ReplicatedStorage
