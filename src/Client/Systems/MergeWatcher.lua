-- Sparse, local-only Hell encounters. No remotes, camera ownership, input locks or gameplay changes.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local ContentProvider = game:GetService("ContentProvider")

local ConfigLoader = require(ReplicatedStorage.Shared.ConfigLoader)
local Director = require(ReplicatedStorage.Shared.Game.MergeWatcherDirector)
local PlaceRuntime = require(ReplicatedStorage.Shared.Game.PlaceRuntime)
local SoundGroups = require(ReplicatedStorage.Shared.Effects.SoundGroups)

local Watcher = {}
local started = false

local function color(value)
    return Color3.fromRGB(value[1], value[2], value[3])
end

function Watcher.start()
    if started then
        return
    end
    started = true
    if not PlaceRuntime.isMerge(game.PlaceId, ConfigLoader:LoadConfig("places")) then
        return
    end
    local config = ConfigLoader:LoadConfig("merge_egg_prototype")
    local cfg = config.watcher
    if not cfg or not cfg.enabled then
        return
    end
    local player = Players.LocalPlayer
    local director = Director.new()
    local random = Random.new()
    local world, bayId, apparition
    local elapsed = cfg.scan_seconds
    local voicePreloadStarted = false

    local function preloadVoices()
        if voicePreloadStarted or not cfg.voice.enabled then
            return
        end
        voicePreloadStarted = true
        local ids = {}
        for _, clips in pairs(cfg.voice.clips[cfg.side] or {}) do
            for _, clip in ipairs(clips) do
                table.insert(ids, "rbxassetid://" .. tostring(clip.asset_id))
            end
        end
        -- Small, side-specific preload; failures leave the text/visual encounter usable.
        task.spawn(function()
            pcall(function()
                ContentProvider:PreloadAsync(ids)
            end)
        end)
    end

    local function clear()
        if apparition then
            if apparition.atmosphere then
                apparition.atmosphere:Destroy()
            end
            apparition.face:Destroy()
            apparition = nil
        end
    end

    local function rootPart()
        local character = player.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if humanoid and humanoid.Health > 0 then
            return character:FindFirstChild("HumanoidRootPart")
        end
        return nil
    end

    local function suppressed()
        local camera = Workspace.CurrentCamera
        return GuiService.MenuIsOpen
            or player:GetAttribute("InCombatTutorial") == true
            or player:GetAttribute("InPrologue") == true
            or player:GetAttribute("LargeMenuOpen") == true
            or player:GetAttribute("TutorialHandoffOpen") == true
            or player:GetAttribute("MergePortalTransitActive") == true
            or not camera
            or camera.CameraType == Enum.CameraType.Scriptable
    end

    local function findWorld()
        local id = player:GetAttribute("MergeEggBayId")
        if bayId == id and world and world.Parent then
            return world
        end
        clear()
        bayId, world = id, nil
        if not id then
            return nil
        end
        local maps = Workspace:FindFirstChild(config.world.maps_root)
        for _, candidate in ipairs(maps and maps:GetDescendants() or {}) do
            if
                candidate:IsA("Model")
                and candidate:GetAttribute("MergeEggBayId") == id
                and candidate:FindFirstChild(config.world.hatcher_spawn, true)
            then
                world = candidate
                break
            end
        end
        return world
    end

    local function show(event, root, now)
        local template = ReplicatedStorage:FindFirstChild(cfg.template_name)
        if not template then
            return
        end
        clear()
        local face = template:Clone()
        face.Name = "MergeWatcherApparition"
        face:SetAttribute("WatcherEvent", event)
        face.Size = template.Size
            * (cfg.size / math.max(template.Size.X, template.Size.Y, template.Size.Z))
        face.Transparency = 1
        local camera = Workspace.CurrentCamera
        local forward = Vector3.new(camera.CFrame.LookVector.X, 0, camera.CFrame.LookVector.Z)
        if forward.Magnitude == 0 then
            forward = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
        end
        forward = forward.Unit
        -- Fix the world bearing for this encounter, not the camera. Looking away remains possible.
        local offset = forward * cfg.distance
            + Vector3.new(-forward.Z, 0, forward.X) * cfg.side_offset
        local position = root.Position + offset + Vector3.yAxis * (cfg.height + cfg.entrance_height)
        face.CFrame = CFrame.lookAt(position, root.Position)
        local eyes = {}
        local scale = cfg.size / math.max(template.Size.X, template.Size.Y, template.Size.Z)
        for _, part in ipairs(face:GetChildren()) do
            local relative = part:GetAttribute("WatcherLocalCFrame")
            if part:IsA("BasePart") and typeof(relative) == "CFrame" then
                local offsetCf = CFrame.new(relative.Position * scale) * relative.Rotation
                part.Size = part.Size * scale
                part.CFrame = face.CFrame * offsetCf
                part.Color = color(cfg.eyes.color)
                part.Material = Enum.Material.Neon
                part.Transparency = 1
                table.insert(eyes, { part = part, offset = offsetCf })
            end
        end
        local light = Instance.new("PointLight")
        light.Color = color(cfg.light_color)
        light.Range = cfg.light_range
        light.Brightness = 0
        light.Shadows = false
        light.Parent = face
        local gui = Instance.new("BillboardGui")
        gui.Name = "WatcherDialogue"
        gui.Size = UDim2.fromOffset(cfg.dialogue.width, cfg.dialogue.height)
        gui.StudsOffsetWorldSpace = Vector3.yAxis * cfg.dialogue.offset_y
        gui.MaxDistance = cfg.dialogue.max_distance
        gui.AlwaysOnTop = false
        gui.Adornee = face
        gui.Parent = face
        local label = Instance.new("TextLabel")
        label.Size = UDim2.fromScale(1, 1)
        label.BackgroundTransparency = 1
        label.TextWrapped = true
        label.Font = Enum.Font[cfg.dialogue.font]
        label.TextSize = cfg.dialogue.text_size
        label.TextColor3 = color(cfg.dialogue.color)
        label.TextStrokeColor3 = color(cfg.dialogue.stroke_color)
        label.TextTransparency = 1
        label.TextStrokeTransparency = 1
        local lines = cfg.lines[cfg.side]
        local choices = lines[event]
        local variant = random:NextInteger(1, #choices)
        label.Text = choices[variant]
        if event == "quartermaster" then
            label.Text = label.Text .. "\n\n" .. lines.quartermaster_hint
        end
        label.Parent = gui
        local voice, clip
        local sideClips = cfg.voice.clips[cfg.side]
        if cfg.voice.enabled and sideClips and sideClips[event] then
            clip = sideClips[event][variant]
            if clip then
                voice = Instance.new("Sound")
                voice.Name = "WatcherVoice"
                voice.SoundId = "rbxassetid://" .. tostring(clip.asset_id)
                voice.Volume = cfg.voice.volume
                voice.RollOffMinDistance = cfg.voice.rolloff_min_distance
                voice.RollOffMaxDistance = cfg.voice.rolloff_max_distance
                SoundGroups.assign(voice, cfg.voice.bus)
                voice.Parent = face
            end
        end
        -- A private effect avoids racing realm/weather systems when restoring lighting.
        local atmosphere
        if cfg.atmosphere.enabled then
            atmosphere = Instance.new("ColorCorrectionEffect")
            atmosphere.Name = "MergeWatcherAtmosphere"
            atmosphere.Parent = Lighting
        end
        face.Parent = Workspace
        apparition = {
            face = face,
            light = light,
            label = label,
            offset = offset,
            startedAt = now,
            atmosphere = atmosphere,
            eyes = eyes,
            voice = voice,
            clip = clip,
            duration = cfg.duration_seconds,
        }
    end

    RunService.Heartbeat:Connect(function(dt)
        local now = os.clock()
        local root = rootPart()
        local eligible = player:GetAttribute("InMergeEggPrototype") == true
            and player:GetAttribute("MergeEggBaySide") == cfg.side
            and root ~= nil
        local blocked = suppressed()
        if not eligible or blocked then
            clear()
        end
        elapsed = elapsed + dt
        if elapsed >= cfg.scan_seconds then
            elapsed = 0
            if eligible then
                preloadVoices()
            end
            local bay = eligible and findWorld() or nil
            local unlocked = player:GetAttribute("CombatTutorialDone") == true
                or player:GetAttribute("MergeEggPlayerCombatMode") == "full"
            local quartermaster = bay and bay:FindFirstChild("MergeQuartermaster", true)
            local nearQuartermaster = quartermaster
                and quartermaster:IsA("Model")
                and root
                and (quartermaster:GetPivot().Position - root.Position).Magnitude
                    <= cfg.quartermaster_radius
            local snapshot = Director.snapshot(bay)
            snapshot.blocked = blocked
                or apparition ~= nil
                or not ReplicatedStorage:FindFirstChild(cfg.template_name)
            snapshot.run = player:GetAttribute("MergeEggRunId")
            snapshot.quartermaster = not unlocked
                and snapshot.eligible
                and (nearQuartermaster == true or snapshot.tutorialStep == "talk_quartermaster")
            local event = Director.step(director, snapshot, now, cfg)
            if event and root then
                show(event, root, now)
            end
        end
        local current = apparition
        if not current or not root then
            return
        end
        local age = now - current.startedAt
        if current.voice and not current.voiceResolved and age >= cfg.voice.start_seconds then
            if age > cfg.voice.load_deadline_seconds then
                -- Never start a late line over a different tutorial/encounter.
                current.voiceResolved = true
            elseif current.voice.IsLoaded then
                current.voiceResolved = true
                current.duration = Director.duration(cfg, current.clip, age)
                current.voice:Play()
            end
        end
        if
            age >= current.duration
            or (current.face.Position - root.Position).Magnitude > cfg.teleport_distance
        then
            clear()
            return
        end
        local opacity = math.clamp(
            math.min(age / cfg.fade_seconds, (current.duration - age) / cfg.fade_seconds),
            0,
            1
        )
        current.face.Transparency = 1 - opacity
        if current.voice then
            current.voice.Volume = cfg.voice.volume
                * math.clamp((current.duration - age) / cfg.fade_seconds, 0, 1)
        end
        if current.atmosphere then
            current.atmosphere.Brightness = cfg.atmosphere.brightness * opacity
            current.atmosphere.Contrast = cfg.atmosphere.contrast * opacity
            current.atmosphere.Saturation = cfg.atmosphere.saturation * opacity
        end
        local pulse = 0
        for _, pulseAt in ipairs(cfg.eyes.pulse_at_seconds) do
            local phase = (age - pulseAt) / cfg.eyes.pulse_seconds
            if phase >= 0 and phase <= 1 then
                pulse = math.max(pulse, math.sin(phase * math.pi) ^ 2)
            end
        end
        current.light.Brightness = (cfg.light_brightness + cfg.eyes.light_boost * pulse) * opacity
        current.label.TextTransparency = 1 - opacity
        current.label.TextStrokeTransparency = 1 - opacity * (1 - cfg.dialogue.stroke_transparency)
        local entrance = cfg.entrance_height * math.max(0, 1 - age / cfg.fade_seconds)
        local target = root.Position
            + current.offset
            + Vector3.yAxis
                * (cfg.height + entrance + math.sin(age * cfg.bob_rate) * cfg.bob_height)
        local delta = target - current.face.Position
        local position = current.face.Position
        if delta.Magnitude > 0 then
            position = position
                + delta.Unit
                    * math.min(
                        delta.Magnitude * (1 - math.exp(-cfg.follow_rate * dt)),
                        cfg.max_speed * dt
                    )
        end
        local rotation = current.face.CFrame.Rotation:Lerp(
            CFrame.lookAt(position, root.Position).Rotation,
            1 - math.exp(-cfg.turn_rate * dt)
        )
        current.face.CFrame = CFrame.new(position) * rotation
        for _, eye in ipairs(current.eyes) do
            eye.part.CFrame = current.face.CFrame * eye.offset
            eye.part.Transparency = 1
                - opacity * (cfg.eyes.idle_opacity + (1 - cfg.eyes.idle_opacity) * pulse)
        end
    end)
end

return Watcher
