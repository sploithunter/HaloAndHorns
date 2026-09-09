-- Authored arrival markers; ZoneService retains travel and prologue authority.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlaceRuntime = require(ReplicatedStorage.Shared.Game.PlaceRuntime)
local places = require(ReplicatedStorage.Configs.places)
local PlayerSpawnSpread = require(ReplicatedStorage.Shared.Game.PlayerSpawnSpread)
local CrossroadsArrival = {}
CrossroadsArrival.__index = CrossroadsArrival

local function resolve(root, path)
    for _, name in ipairs(path) do
        root = root and root:FindFirstChild(name)
    end
    return root
end

function CrossroadsArrival.new(zone, config)
    return setmetatable(
        { zone = zone, cfg = config, assigned = {}, busy = {}, lastTravel = {} },
        CrossroadsArrival
    )
end

function CrossroadsArrival:IsEnabled()
    return self.cfg
        and self.cfg.enabled == true
        and not PlaceRuntime.isMerge(game.PlaceId, places)
        and workspace:FindFirstChild(self.cfg.root_name) ~= nil
end

function CrossroadsArrival:_markers()
    local root = workspace:FindFirstChild(self.cfg.root_name)
    return root,
        root and root:FindFirstChild(self.cfg.spawn_name, true),
        root and root:FindFirstChild(self.cfg.slots_folder)
end

function CrossroadsArrival:ConfigurePlayer(player)
    if not self:IsEnabled() or player:GetAttribute("CrossroadsFarmEntered") == true then
        return
    end
    local _, anchor, slots = self:_markers()
    if not (anchor and slots) then
        return
    end
    local occupied = {}
    for other, pad in pairs(self.assigned) do
        if other ~= player and other.Parent and pad.Parent then
            local p = anchor.CFrame:PointToObjectSpace(pad.Position)
            table.insert(occupied, { x = p.X, z = p.Z })
        end
    end
    for _, other in ipairs(Players:GetPlayers()) do
        local hrp = other.Character and other.Character:FindFirstChild("HumanoidRootPart")
        if other ~= player and hrp then
            local p = anchor.CFrame:PointToObjectSpace(hrp.Position)
            if math.abs(p.Y) < self.zone._spawnSpreadConfig.vertical_tolerance then
                table.insert(occupied, { x = p.X, z = p.Z })
            end
        end
    end
    local _, index = PlayerSpawnSpread.choose(player.UserId, occupied, self.zone._spawnSpreadConfig)
    local pad = slots:FindFirstChild(self.cfg.slot_prefix .. index)
    if not (pad and pad:IsA("SpawnLocation")) then
        return
    end
    self.assigned[player] = pad
    player.RespawnLocation = pad
end

function CrossroadsArrival:Place(player)
    local character = player.Character
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    if not hrp then
        return false, "character_not_ready"
    end
    if player:GetAttribute("InMission") or player:GetAttribute("InPrologue") then
        return false, "placement_owned"
    end
    self:ConfigurePlayer(player)
    local pad = self.assigned[player]
    if not pad then
        return false, "missing_crossroads_slot"
    end
    hrp.CFrame = pad.CFrame + Vector3.new(0, self.cfg.spawn_clearance, 0)
    hrp.AssemblyLinearVelocity = Vector3.zero
    hrp.AssemblyAngularVelocity = Vector3.zero
    self.zone._worldBindingService:SetActiveArea(player, self.cfg.context_area)
    player:SetAttribute("InCrossroads", true)
    return true, nil, self.cfg.area_id
end

function CrossroadsArrival:Travel(player)
    local character = player.Character
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not self:IsEnabled() or not self.gate or not hrp or not humanoid or humanoid.Health <= 0 then
        return false
    end
    if player:GetAttribute("InMission") or player:GetAttribute("InPrologue") then
        return false
    end
    if (hrp.Position - self.gate.Position).Magnitude > self.cfg.prompt_distance then
        return false
    end
    if
        self.busy[player]
        or os.clock() - (self.lastTravel[player] or -math.huge) < self.cfg.cooldown_seconds
    then
        return false
    end
    if
        require(script.Parent.CrossroadsDialogue).defer(player, function()
            self:Travel(player)
        end)
    then
        return false
    end
    local destination =
        self.zone._worldBindingService:GetSpawnCFrameForZone(self.cfg.destination_area)
    if not destination then
        return false
    end
    self.busy[player] = true
    local ok, result = pcall(function()
        pcall(function()
            player:RequestStreamAroundAsync(destination.Position, self.cfg.stream_timeout)
        end)
        if
            player.Character ~= character
            or not hrp.Parent
            or humanoid.Health <= 0
            or player:GetAttribute("InMission")
            or player:GetAttribute("InPrologue")
            or (hrp.Position - self.gate.Position).Magnitude > self.cfg.prompt_distance
        then
            return { ok = false }
        end
        return self.zone:TravelToZone(player, self.cfg.destination_area, self.gate)
    end)
    self.busy[player] = nil
    if not ok or not result.ok then
        return false
    end
    self.lastTravel[player] = os.clock()
    player:SetAttribute("CrossroadsFarmEntered", true)
    player:SetAttribute("InCrossroads", false)
    player.RespawnLocation = resolve(workspace, self.cfg.home_spawn_path)
    self.assigned[player] = nil
    return true
end

-- The existing Home doorway keeps one owner; Merge delegates its binding here.
function CrossroadsArrival:BindHomeGate(hook, gateConfig)
    local prompt = hook:FindFirstChild(gateConfig.prompt_name)
    if not prompt then
        prompt = Instance.new("ProximityPrompt")
        prompt.Name = gateConfig.prompt_name
        prompt.Parent = hook
    end
    prompt.ActionText = self.cfg.home_gate_action
    prompt.ObjectText = self.cfg.home_gate_title
    prompt.MaxActivationDistance = self.cfg.prompt_distance
    prompt.HoldDuration = self.cfg.prompt_hold
    prompt.RequiresLineOfSight = false
    prompt.Enabled = true
    local title = hook.Parent:FindFirstChild("HallOfWorldsGateTitle")
    if title then
        for _, label in ipairs(title:GetDescendants()) do
            if label:IsA("TextLabel") or label:IsA("TextButton") then
                label.Text = self.cfg.home_gate_title .. "\n" .. self.cfg.home_gate_subtitle
            end
        end
    end
    prompt.Triggered:Connect(function(player)
        self:ReturnFromHome(player, hook)
    end)
    return prompt
end

function CrossroadsArrival:ReturnFromHome(player, hook)
    local character = player.Character
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local function valid()
        return self:IsEnabled()
            and player.Character == character
            and hrp
            and hrp.Parent
            and humanoid
            and humanoid.Health > 0
            and not player:GetAttribute("InMission")
            and not player:GetAttribute("InPrologue")
            and (hrp.Position - hook.Position).Magnitude <= self.cfg.prompt_distance
    end
    if
        not valid()
        or self.busy[player]
        or os.clock() - (self.lastTravel[player] or -math.huge) < self.cfg.cooldown_seconds
    then
        return false
    end
    local _, anchor, slots = self:_markers()
    if not anchor or not slots then
        return false
    end
    self.busy[player] = true
    local ok, result = pcall(function()
        pcall(function()
            player:RequestStreamAroundAsync(anchor.Position, self.cfg.stream_timeout)
        end)
        if not valid() then
            return { ok = false }
        end
        return self.zone:TravelToZone(player, self.cfg.area_id, hook)
    end)
    self.busy[player] = nil
    if ok and result.ok then
        self.lastTravel[player] = os.clock()
        return true
    end
    return false
end

function CrossroadsArrival:Start()
    if not self:IsEnabled() then
        return
    end
    local root = workspace[self.cfg.root_name]
    self.gate = resolve(root, self.cfg.gate_path)
    if not (self.gate and self.gate:IsA("BasePart")) then
        return
    end
    local prompt = self.gate:FindFirstChild(self.cfg.prompt_name)
    if not (prompt and prompt:IsA("ProximityPrompt")) then
        return
    end
    prompt.ActionText, prompt.ObjectText = self.cfg.prompt_action, self.cfg.prompt_title
    prompt.MaxActivationDistance, prompt.HoldDuration =
        self.cfg.prompt_distance, self.cfg.prompt_hold
    prompt.Enabled = true
    self.gate:SetAttribute("GameplayConnected", true)
    prompt.Triggered:Connect(function(player)
        self:Travel(player)
    end)
    self.gate.Touched:Connect(function(part)
        local character = part:FindFirstAncestorOfClass("Model")
        local player = character and Players:GetPlayerFromCharacter(character)
        local hrp = character and character:FindFirstChild("HumanoidRootPart")
        if
            player
            and hrp
            and (hrp.Position - self.gate.Position).Magnitude <= self.cfg.touch_distance
        then
            self:Travel(player)
        end
    end)
    Players.PlayerRemoving:Connect(function(player)
        self.assigned[player], self.busy[player], self.lastTravel[player] = nil, nil, nil
    end)
end

return CrossroadsArrival
