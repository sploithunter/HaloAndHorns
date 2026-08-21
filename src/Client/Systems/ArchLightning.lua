--[[
    ArchLightning (client) — ambient dragon bolts on Hall gate arches.

    Authored lightning1… parts are optional. Loose Workspace cubes vanish on
    Play if they are unanchored, so each named host is sampled and stamped
    with anchored invisible markers when fewer than two live points exist.
]]

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ConfigLoader = require(ReplicatedStorage.Shared.ConfigLoader)
local EnchantLightning = require(ReplicatedStorage.Shared.Effects.EnchantLightning)
local SoundGroups = require(ReplicatedStorage.Shared.Effects.SoundGroups)
local Logic = require(ReplicatedStorage.Shared.Game.ArchLightning)

local ArchLightning = {}

local started = false
local FOLDER_NAME = "ArchLightningRuntime"
local STAMP_VERSION = 3
local GROUP_NAME = Logic.GROUP_NAME

local function asVector3(value)
    if typeof(value) == "Vector3" then
        return value
    end
    if type(value) == "table" then
        return Vector3.new(value[1] or 0, value[2] or 0, value[3] or 0)
    end
    return Vector3.zero
end

local function hideMarker(part, hide)
    if hide == false or not part:IsA("BasePart") then
        return
    end
    part.Anchored = true
    part.Transparency = 1
    part.CanCollide = false
    part.CanQuery = false
    part.CanTouch = false
    part.CastShadow = false
end

local function hostOf(part, hostNames, hostTag)
    local inst = part
    while inst and inst ~= Workspace do
        if hostNames[inst.Name] then
            return inst
        end
        if hostTag ~= "" and CollectionService:HasTag(inst, hostTag) then
            return inst
        end
        inst = inst.Parent
    end
    return nil
end

local function findHosts(hostNames, hostTag)
    local hosts = {}
    local seen = {}
    for _, desc in ipairs(Workspace:GetDescendants()) do
        if hostNames[desc.Name] or (hostTag ~= "" and CollectionService:HasTag(desc, hostTag)) then
            if not seen[desc] then
                seen[desc] = true
                table.insert(hosts, desc)
            end
        end
    end
    return hosts
end

local function hostGroup(host)
    local group = host:FindFirstChild(GROUP_NAME)
    if group then
        return group
    end
    group = Instance.new("Model")
    group.Name = GROUP_NAME
    group.Parent = host
    return group
end

local function stampHost(host, cfg, siteId)
    local group = hostGroup(host)
    local existing = {}
    for _, child in ipairs(group:GetChildren()) do
        if
            child:IsA("BasePart") and Logic.isMarkerName(child.Name, cfg.part_prefix or "lightning")
        then
            table.insert(existing, child)
        end
    end
    if #existing >= 2 then
        return existing
    end
    for _, part in ipairs(existing) do
        part:Destroy()
    end

    local cf, size
    if host:IsA("Model") then
        cf, size = host:GetBoundingBox()
    elseif host:IsA("BasePart") then
        cf, size = host.CFrame, host.Size
    else
        return {}
    end

    local localPoints = Logic.sampleArchPoints(Logic.openingWidth(size), size.Y, cfg.sample_rows)
    local prefix = cfg.part_prefix or "lightning"
    local parts = {}
    for index, localPos in ipairs(localPoints) do
        local part = Instance.new("Part")
        part.Name = prefix .. tostring(index)
        part.Size = Vector3.new(0.4, 0.4, 0.4)
        part.CFrame = CFrame.new(Logic.worldFromLocal(cf, size, localPos))
        part:SetAttribute("ArchLightningSite", siteId)
        part:SetAttribute("StampVersion", STAMP_VERSION)
        hideMarker(part, cfg.hide_markers)
        part.Parent = group
        table.insert(parts, part)
    end
    return parts
end

local function collectMarkers(cfg)
    local prefix = cfg.part_prefix or "lightning"
    local hostNames = {}
    for _, name in ipairs(cfg.host_names or {}) do
        if type(name) == "string" and name ~= "" then
            hostNames[name] = true
        end
    end
    local hostTag = tostring(cfg.host_tag or "")
    local hosted = {}
    local loose = {}

    local function consider(part)
        if not part:IsA("BasePart") or not Logic.isMarkerName(part.Name, prefix) then
            return
        end
        if part.Parent and part.Parent.Name == FOLDER_NAME then
            part:Destroy()
            return
        end
        hideMarker(part, cfg.hide_markers)
        local host = hostOf(part, hostNames, hostTag)
        if host then
            local group = hosted[host]
            if not group then
                group = {}
                hosted[host] = group
            end
            table.insert(group, part)
            return
        end
        if cfg.adopt_workspace_parts ~= false then
            table.insert(loose, part)
        end
    end

    for _, desc in ipairs(Workspace:GetDescendants()) do
        consider(desc)
    end

    for _, host in ipairs(findHosts(hostNames, hostTag)) do
        local group = hosted[host]
        if not group or #group < 2 then
            hosted[host] = stampHost(host, cfg, host.Name)
        end
    end

    local groups = {}
    for _, parts in pairs(hosted) do
        if #parts >= 2 then
            table.insert(groups, parts)
        end
    end

    local points = {}
    for index, part in ipairs(loose) do
        local pos = part.Position
        table.insert(points, { id = index, x = pos.X, y = pos.Y, z = pos.Z })
    end
    for _, cluster in ipairs(Logic.clusterLoose(points, cfg.cluster_radius)) do
        local parts = {}
        for _, point in ipairs(cluster) do
            table.insert(parts, loose[point.id])
        end
        if #parts >= 2 then
            table.insert(groups, parts)
        end
    end

    return groups
end

local function centroid(parts)
    local sum = Vector3.zero
    local count = 0
    for _, part in ipairs(parts) do
        if part.Parent then
            sum += part.Position
            count += 1
        end
    end
    if count == 0 then
        return nil
    end
    return sum / count
end

local function playerPosition()
    local character = Players.LocalPlayer and Players.LocalPlayer.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    return root and root.Position
end

local function playBuzz(parent, cfg, catalog)
    local entry = catalog[tostring(cfg.name or "")]
    if type(entry) ~= "table" or type(entry.id) ~= "string" or entry.id == "" then
        return
    end

    local sound = Instance.new("Sound")
    sound.Name = "ArchLightningBuzz"
    sound.SoundId = entry.id
    sound.Volume = tonumber(cfg.volume) or tonumber(entry.volume) or 0.12
    sound.PlaybackSpeed = tonumber(entry.playback_speed) or 1
    sound.RollOffMode = Enum.RollOffMode.InverseTapered
    sound.RollOffMinDistance = math.max(0, tonumber(cfg.roll_off_min_distance) or 8)
    sound.RollOffMaxDistance =
        math.max(sound.RollOffMinDistance, tonumber(cfg.roll_off_max_distance) or 60)
    SoundGroups.assign(sound, entry.bus or "effects")
    sound.Parent = parent
    sound:Play()

    local duration = tonumber(entry.duration_seconds) or 0.48
    Debris:AddItem(sound, math.max(1, duration + 0.5))
end

function ArchLightning.start()
    if started then
        return
    end
    started = true

    local hall = ConfigLoader:LoadConfig("hall_of_worlds") or {}
    local cfg = hall.arch_lightning or {}
    if hall.enabled == false or cfg.enabled == false then
        return
    end

    local soundCatalog = ConfigLoader:LoadConfig("sounds") or {}
    local soundCfg = cfg.sound or {}
    local soundIntervalMin = math.max(0.1, tonumber(soundCfg.interval_min) or 0.65)
    local soundIntervalMax = math.max(soundIntervalMin, tonumber(soundCfg.interval_max) or 1.1)
    local soundDistance = math.max(1, tonumber(soundCfg.roll_off_max_distance) or 60)

    local boltCfg = table.clone(cfg.bolt or {})
    boltCfg.target_offset = asVector3(boltCfg.target_offset)
    -- Rapid bolts must not each spawn the catalog thunder. The ambient buzz
    -- below is positional and independently throttled.
    boltCfg.sound_name = "_silent"

    local intervalMin = math.max(0.03, tonumber(cfg.interval_min) or 0.05)
    local intervalMax = math.max(intervalMin, tonumber(cfg.interval_max) or 0.14)
    local viewDistance = math.max(20, tonumber(cfg.view_distance) or 180)
    local boltsPerPulse = math.max(1, math.floor(tonumber(cfg.bolts_per_pulse) or 1))
    local preferCross = cfg.prefer_cross ~= false

    local groups = collectMarkers(cfg)
    local visualWait = 0
    local rescanWait = 0
    local nextSoundAt = 0

    Workspace.DescendantAdded:Connect(function(inst)
        if inst.Name == FOLDER_NAME then
            return
        end
        if
            inst:IsA("BasePart") and Logic.isMarkerName(inst.Name, cfg.part_prefix or "lightning")
        then
            groups = collectMarkers(cfg)
        end
    end)

    RunService.Heartbeat:Connect(function(dt)
        rescanWait += dt
        if rescanWait >= 2 then
            rescanWait = 0
            groups = collectMarkers(cfg)
        end

        visualWait -= dt
        if visualWait > 0 then
            return
        end
        visualWait = intervalMin + math.random() * (intervalMax - intervalMin)

        local here = playerPosition()
        if not here then
            return
        end

        local closestSoundPart
        local closestSoundDistance = math.huge
        for _, parts in ipairs(groups) do
            local live = {}
            for _, part in ipairs(parts) do
                if part.Parent then
                    table.insert(live, part)
                end
            end
            if #live < 2 then
                continue
            end

            local center = centroid(live)
            if not center then
                continue
            end
            local distance = (center - here).Magnitude
            if distance > viewDistance then
                continue
            end

            local points = {}
            for _, part in ipairs(live) do
                local pos = part.Position
                table.insert(points, { x = pos.X, y = pos.Y, z = pos.Z })
            end
            for _ = 1, boltsPerPulse do
                local i, j = Logic.pickPair(points, preferCross, nil, cfg.min_cross_span or 8)
                if i and j then
                    EnchantLightning.Play(live[i], boltCfg, live[j])
                end
            end

            if distance <= soundDistance and distance < closestSoundDistance then
                closestSoundDistance = distance
                closestSoundPart = live[1]
            end
        end

        local now = os.clock()
        if closestSoundPart and now >= nextSoundAt then
            playBuzz(closestSoundPart, soundCfg, soundCatalog)
            nextSoundAt = now
                + soundIntervalMin
                + math.random() * (soundIntervalMax - soundIntervalMin)
        end
    end)
end

return ArchLightning
