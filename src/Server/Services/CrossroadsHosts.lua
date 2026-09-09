-- Two authored heads, shared across all players. Cosmetic observations never grant rewards.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Policy = require(ReplicatedStorage.Shared.Game.CrossroadsHostPolicy)
local PlaceRuntime = require(ReplicatedStorage.Shared.Game.PlaceRuntime)
local Events = require(ReplicatedStorage.Shared.Network.FireGameEvent)
local Hosts = {}
Hosts.__index = Hosts
local function resolve(path)
    local node = workspace
    for _, name in ipairs(path) do
        node = node and node:FindFirstChild(name)
    end
    return node
end
local function vector(value)
    return Vector3.new(table.unpack(value))
end
local function distanceToField(part, position, vertical)
    local p = part.CFrame:PointToObjectSpace(position)
    if math.abs(p.Y) > vertical then
        return math.huge
    end
    return Vector2.new(
        math.max(0, math.abs(p.X) - part.Size.X / 2),
        math.max(0, math.abs(p.Z) - part.Size.Z / 2)
    ).Magnitude
end
function Hosts:Init()
    self.cfg = self._modules.ConfigLoader:LoadConfig("crossroads_hosts")
    self.places = self._modules.ConfigLoader:LoadConfig("places")
    self.actors = {}
end
function Hosts:_bind(speaker, cfg)
    local face, gate, area =
        resolve(cfg.face_path), resolve(cfg.gate_path), resolve(cfg.activity_path)
    local field = cfg.activity_part and area and area:FindFirstChild(cfg.activity_part) or area
    if not (face and face:IsA("BasePart") and gate and field and field:IsA("BasePart")) then
        return
    end
    local actor = {
        face = face,
        gate = gate,
        field = field,
        egg = cfg.egg_part and area:FindFirstChild(cfg.egg_part),
        cfg = cfg,
        home = face.CFrame,
        served = {},
        visit = 0,
        reaction = 0,
    }
    face.Anchored, face.CanCollide, face.CanTouch, face.CanQuery = true, false, false, false
    face:SetAttribute("CrossroadsHost", speaker)
    face:SetAttribute("HostActivity", "idle")
    face:SetAttribute("HostReady", true)
    self.actors[speaker] = actor
    return actor
end
function Hosts:_reaction(actor, cue, userId, urgent)
    local now = workspace:GetServerTimeNow()
    if
        not cue
        or (
            not urgent
            and actor.lastReaction
            and now - actor.lastReaction < self.cfg.reaction_interval_seconds
        )
    then
        return
    end
    actor.lastReaction, actor.reaction = now, actor.reaction + 1
    actor.face:SetAttribute("HostReaction", cue)
    actor.face:SetAttribute("HostReactionUserId", userId)
    actor.face:SetAttribute("HostReactionAt", now)
    actor.face:SetAttribute("HostReactionToken", actor.reaction)
end
function Hosts:_stepActor(actor, snapshots, now)
    local cfg, candidates = self.cfg, {}
    for _, s in ipairs(snapshots) do
        local gateDistance = (s.position - actor.gate.Position).Magnitude
        if gateDistance > cfg.gate_exit_radius then
            actor.served[s.id] = nil
        end
        table.insert(candidates, {
            id = s.id,
            position = s.position,
            alive = s.alive,
            inCrossroads = s.inCrossroads,
            gateDistance = gateDistance,
            served = actor.served[s.id] == true,
            activityDistance = distanceToField(actor.field, s.position, cfg.vertical_range),
            eggDistance = actor.egg and (s.position - actor.egg.Position).Magnitude or math.huge,
        })
    end
    if actor.current and actor.current.activity == "gate" and now >= actor.servedAt then
        actor.served[actor.current.id] = true
    end
    local chosen = Policy.choose(candidates, actor.current, cfg, actor.egg ~= nil)
    local activity = chosen and chosen.activity or "idle"
    local changed = not actor.current
        or not chosen
        or actor.current.id ~= chosen.id
        or actor.current.activity ~= activity
    if changed and (actor.current or chosen) then
        local previous = actor.current and actor.current.activity
        actor.visit += 1
        actor.servedAt = now + cfg.gate_service_seconds
        actor.face:SetAttribute(
            "HostRushed",
            activity == "gate" and (previous == "activity" or previous == "egg")
        )
        actor.face:SetAttribute(
            "HostActivity",
            activity == "activity" and actor.cfg.activity or activity
        )
        actor.face:SetAttribute("HostTargetUserId", chosen and chosen.id or 0)
        actor.face:SetAttribute("HostVisit", actor.visit)
    end
    actor.current = chosen
    local position, look = actor.home.Position, actor.home.Position + actor.home.LookVector
    if chosen then
        if activity == "activity" then
            position = actor.field.Position + vector(actor.cfg.watch_offset)
        elseif activity == "egg" then
            position = actor.egg.Position + vector(actor.cfg.egg_offset)
        end
        look = chosen.candidate.position
    end
    if (position - look).Magnitude == 0 then
        look = position + actor.home.LookVector
    end
    local target = CFrame.lookAt(position, look)
    if
        not actor.target
        or (actor.target.Position - position).Magnitude > cfg.position_threshold
        or (actor.look - look).Magnitude > cfg.look_threshold
    then
        if actor.tween then
            actor.tween:Cancel()
        end
        local speed = actor.face:GetAttribute("HostRushed") and cfg.rush_speed or cfg.normal_speed
        local duration = math.clamp(
            (actor.face.Position - position).Magnitude / speed,
            cfg.minimum_travel_seconds,
            cfg.maximum_travel_seconds
        )
        actor.face:SetAttribute("HostReadyAt", workspace:GetServerTimeNow() + duration)
        actor.target, actor.look = target, look
        actor.tween = TweenService:Create(
            actor.face,
            TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
            { CFrame = target }
        )
        actor.tween:Play()
    end
    if actor.cfg.activity == "arena" then
        local state, enemies =
            actor.field:GetAttribute("ArenaState"), actor.field:GetAttribute("ArenaEnemies")
        actor.face:SetAttribute("HostFightActive", state == "fighting")
        if chosen and activity == "activity" then
            if state == "cleared" and actor.lastArenaState == "fighting" then
                self:_reaction(actor, actor.cfg.victory_cue, 0, true)
            elseif state == "abandoned" and actor.lastArenaState == "fighting" then
                self:_reaction(actor, actor.cfg.retreat_cue, 0, true)
            elseif
                state == "fighting"
                and actor.lastEnemies
                and enemies
                and enemies > 0
                and enemies < actor.lastEnemies
            then
                self:_reaction(actor, actor.cfg.defeated_cue, 0)
            end
        end
        actor.lastArenaState, actor.lastEnemies = state, enemies
    end
end
function Hosts:_tick()
    local snapshots, now = {}, os.clock()
    for _, player in ipairs(Players:GetPlayers()) do
        local character = player.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if root then
            table.insert(snapshots, {
                id = player.UserId,
                position = root.Position,
                alive = humanoid
                    and humanoid.Health > 0
                    and player:GetAttribute("DataLoaded") == true,
                inCrossroads = player:GetAttribute("InCrossroads") == true
                    and not player:GetAttribute("InMission")
                    and not player:GetAttribute("InPrologue"),
            })
        end
    end
    for speaker, cfg in pairs(self.cfg.hosts) do
        local actor = self.actors[speaker]
        if actor and (not actor.face.Parent or not actor.gate.Parent or not actor.field.Parent) then
            if actor.tween then
                actor.tween:Cancel()
            end
            self.actors[speaker], actor = nil, nil
        end
        actor = actor or self:_bind(speaker, cfg)
        if actor then
            self:_stepActor(actor, snapshots, now)
        end
    end
end
function Hosts:Start()
    if not self.cfg.enabled or not PlaceRuntime.isRole(game.PlaceId, self.places, "main") then
        return
    end
    Events.tap(function(player, name, context)
        local actor = self.actors.angel
        local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        if
            name == "coin_payout"
            and actor
            and root
            and player:GetAttribute("InCrossroads") == true
            and type(context) == "table"
            and typeof(context.position) == "Vector3"
            and distanceToField(actor.field, context.position, self.cfg.vertical_range) == 0
        then
            actor.face:SetAttribute("HostWorkingAt", workspace:GetServerTimeNow())
        end
        if
            name == "egg_hatch"
            and actor
            and actor.egg
            and root
            and player:GetAttribute("InCrossroads") == true
            and (root.Position - actor.egg.Position).Magnitude <= self.cfg.egg_enter_radius
        then
            self:_reaction(actor, actor.cfg.hatch_cue, player.UserId)
        end
    end)
    Players.PlayerRemoving:Connect(function(player)
        for _, actor in pairs(self.actors) do
            actor.served[player.UserId] = nil
        end
    end)
    local elapsed = 0
    RunService.Heartbeat:Connect(function(dt)
        elapsed += dt
        if elapsed >= self.cfg.poll_seconds then
            elapsed = 0
            self:_tick()
        end
    end)
end
return Hosts
