-- Cosmetic lightning at server-authored arrival markers; it never spawns or damages an enemy.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local Lightning = require(ReplicatedStorage.Shared.Effects.EnchantLightning)
local FX = {}
local started = false
function FX.start()
    if started then
        return
    end
    started = true
    local cfg = require(ReplicatedStorage.Configs.crossroads_arena).arrival_fx
    if not cfg.enabled then
        return
    end
    local seen = setmetatable({}, { __mode = "k" })
    local elapsed = 0
    RunService.Heartbeat:Connect(function(dt)
        elapsed += dt
        if elapsed < cfg.poll_seconds then
            return
        end
        elapsed = 0
        local folder = workspace:FindFirstChild(cfg.runtime_name)
        local camera = workspace.CurrentCamera
        for _, marker in ipairs(folder and folder:GetChildren() or {}) do
            local at = marker:GetAttribute("ArrivalAt")
            local now = workspace:GetServerTimeNow()
            if
                marker:IsA("BasePart")
                and type(at) == "number"
                and not seen[marker]
                and now >= at
            then
                seen[marker] = true
                if
                    camera
                    and now - at <= cfg.late_seconds
                    and (camera.CFrame.Position - marker.Position).Magnitude <= cfg.distance
                then
                    local origin = Instance.new("Part")
                    origin.Name = "ArenaLightningOrigin"
                    origin.Anchored, origin.CanCollide, origin.CanTouch, origin.CanQuery =
                        true, false, false, false
                    origin.Transparency = 1
                    origin.Position = marker.Position + Vector3.new(0, cfg.height, 0)
                    origin.Parent = workspace
                    local lightning = table.clone(cfg.lightning)
                    if Players.LocalPlayer:GetAttribute(cfg.reduced_motion_attribute) == true then
                        lightning.strands_per_origin = 0
                        lightning.center_flash = false
                        -- Reduced motion omits the animated strike; enemies still arrive normally.
                        origin:Destroy()
                    else
                        Lightning.Play(origin, lightning, marker)
                        Debris:AddItem(origin, lightning.duration)
                    end
                end
            end
        end
    end)
end
return FX
