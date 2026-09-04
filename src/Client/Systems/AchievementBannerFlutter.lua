--!strict

-- Client-only flutter for the authored banner bone chain. It never guesses by name: only instances
-- with the AchievementBanner collection tag enter this system, preventing décor/flora cross-talk.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Locations = require(ReplicatedStorage.Shared.Locations)
local ConfigLoader = require(Locations.ConfigLoader)
local BannerMotion = require(ReplicatedStorage.Shared.Game.AchievementBannerMotion)

local AchievementBannerFlutter = {}

type Tracked = {
    host: Instance,
    cloth: MeshPart,
    bones: { Bone },
    phase: number,
    active: boolean,
}

local started = false
local config: any = nil
local tracked: { [Instance]: Tracked } = {}

local function observerPosition(): Vector3?
    local camera = Workspace.CurrentCamera
    if camera then
        return camera.CFrame.Position
    end
    local character = Players.LocalPlayer and Players.LocalPlayer.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    return if root and root:IsA("BasePart") then root.Position else nil
end

local function locateCloth(host: Instance): MeshPart?
    if host:IsA("MeshPart") and host.Name == config.model.cloth_name then
        return host
    end
    local child = host:FindFirstChild(config.model.cloth_name, true)
    return if child and child:IsA("MeshPart") then child else nil
end

local function restore(entry: Tracked)
    if not entry.active then
        return
    end
    for _, bone in entry.bones do
        if bone.Parent then
            bone.Transform = CFrame.identity
        end
    end
    entry.active = false
end

local function forget(host: Instance)
    local entry = tracked[host]
    if entry then
        restore(entry)
    end
    tracked[host] = nil
end

local function remember(host: Instance)
    if host:GetAttribute("AchievementFlutter") == false then
        forget(host)
        return
    end
    local cloth = locateCloth(host)
    if not cloth then
        return
    end
    local bones = {}
    for _, name in config.model.deform_bones do
        -- Roblox's FBX importer parents the armature chain under a generated RootPart sibling of
        -- the skinned Cloth MeshPart. Search the explicitly tagged host, not the cloth subtree.
        local bone = host:FindFirstChild(name, true)
        if not bone or not bone:IsA("Bone") then
            return
        end
        table.insert(bones, bone)
    end
    tracked[host] = {
        host = host,
        cloth = cloth,
        bones = bones,
        phase = BannerMotion.phase(cloth.Position.X, cloth.Position.Z),
        active = false,
    }
end

local function rescan()
    local seen: { [Instance]: boolean } = {}
    for _, host in CollectionService:GetTagged(config.tag) do
        seen[host] = true
        if not tracked[host] then
            remember(host)
        end
    end
    for host in tracked do
        if not seen[host] or not host.Parent then
            forget(host)
        end
    end
end

function AchievementBannerFlutter.start()
    if started then
        return
    end
    started = true
    config = ConfigLoader:LoadConfig("achievement_banners")
    if not config.motion.enabled then
        return
    end
    CollectionService:GetInstanceAddedSignal(config.tag):Connect(function(host)
        task.defer(remember, host)
    end)
    CollectionService:GetInstanceRemovedSignal(config.tag):Connect(forget)
    rescan()

    local elapsed = config.motion.rescan_seconds
    RunService.RenderStepped:Connect(function(dt)
        elapsed += dt
        if elapsed >= config.motion.rescan_seconds then
            elapsed = 0
            rescan()
        end
        local observer = observerPosition()
        if not observer then
            return
        end
        local radius = BannerMotion.radius(config.motion)
        local radiusSquared = radius * radius
        local now = os.clock()
        for host, entry in tracked do
            if not host.Parent or not entry.cloth.Parent then
                forget(host)
                continue
            end
            local delta = entry.cloth.Position - observer
            if
                delta:Dot(delta) > radiusSquared
                or host:GetAttribute("AchievementFlutter") == false
            then
                restore(entry)
                continue
            end
            for index, bone in entry.bones do
                local sample = BannerMotion.sample(now, entry.phase, index, config.motion)
                bone.Transform = CFrame.Angles(sample.pitch, sample.yaw, sample.roll)
            end
            entry.active = true
        end
    end)
end

return AchievementBannerFlutter
