-- Per-listener delivery for shared world hosts. Speech remains private and respects Voices/mute.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local config = require(ReplicatedStorage.Configs.crossroads_hosts)
local Client = {}
Client.__index = Client
local function resolve(path)
    local node = workspace
    for _, name in ipairs(path) do
        node = node and node:FindFirstChild(name)
    end
    return node
end
local function inField(part, root, padding)
    if not part then
        return false
    end
    local p = part.CFrame:PointToObjectSpace(root.Position)
    return math.abs(p.Y) <= config.vertical_range
        and math.abs(p.X) <= part.Size.X / 2 + padding
        and math.abs(p.Z) <= part.Size.Z / 2 + padding
end
function Client.new()
    return setmetatable({ states = {} }, Client)
end
function Client:face(speaker)
    return resolve(config.hosts[speaker].face_path)
end
function Client:_snapshot(speaker)
    local player = Players.LocalPlayer
    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    local cfg = config.hosts[speaker]
    if player:GetAttribute(cfg.visited_attribute) == true then
        return nil
    end
    local face, gate, area = self:face(speaker), resolve(cfg.gate_path), resolve(cfg.activity_path)
    if not (root and face and gate and area and face:GetAttribute("HostReady")) then
        return
    end
    local field = cfg.activity_part and area:FindFirstChild(cfg.activity_part) or area
    local egg = cfg.egg_part and area:FindFirstChild(cfg.egg_part)
    local activity = face:GetAttribute("HostActivity")
    local gateDistance = (root.Position - gate.Position).Magnitude
    local relevant = (
        (activity == "gate" and gateDistance <= config.gate_exit_radius)
        or (activity == "egg" and egg and (root.Position - egg.Position).Magnitude <= config.egg_enter_radius)
        or (activity == cfg.activity and inField(field, root, config.activity_exit_radius))
    )
    return {
        face = face,
        cfg = cfg,
        activity = activity,
        relevant = relevant,
        inActivity = inField(field, root, config.activity_exit_radius),
        gateDistance = gateDistance,
        ready = workspace:GetServerTimeNow() >= (face:GetAttribute("HostReadyAt") or 0),
    }
end
function Client:valid(request)
    local s = request and self:_snapshot(request.speaker)
    return s and s.relevant and s.activity == request.activity
end
function Client:gatePriority()
    for speaker in pairs(config.hosts) do
        local s = self:_snapshot(speaker)
        local state = self.states[speaker]
        if s and s.relevant and s.activity == "gate" and not (state and state.greeted) then
            return true
        end
    end
    return false
end
function Client:nextRequest(now, blocked)
    local requests = {}
    for speaker in pairs(config.hosts) do
        local s = self:_snapshot(speaker)
        local state = self.states[speaker] or { count = 0, nextAt = 0, rotation = 0 }
        self.states[speaker] = state
        if s then
            state.playedThisVisit = state.playedThisVisit or {}
            if s.inActivity == false then
                state.playedThisVisit = {}
            end
            if s.gateDistance > config.gate_exit_radius then
                state.greeted = false
            end
            if not s.relevant then
                state.context, state.approached = nil, false
            else
                if state.context ~= s.activity then
                    state.context, state.count, state.approached = s.activity, 0, false
                    state.reaction = s.face:GetAttribute("HostReactionToken")
                    state.nextAt = now
                end
                local cues, priority, reaction
                if s.activity == "gate" and not state.greeted then
                    cues = {}
                    if s.face:GetAttribute("HostRushed") then
                        table.insert(cues, s.cfg.return_cue)
                    else
                        table.insert(cues, s.cfg.greeting[1])
                    end
                    table.insert(cues, s.cfg.greeting[2])
                    priority = 1
                elseif
                    s.activity ~= "gate" and state.count < config.max_activity_lines_per_visit
                then
                    local token = s.face:GetAttribute("HostReactionToken")
                    local recipient = s.face:GetAttribute("HostReactionUserId")
                    local reactionAt = s.face:GetAttribute("HostReactionAt")
                    local cue = s.face:GetAttribute("HostReaction")
                    local repeated = s.cfg.once_per_visit
                        and s.cfg.once_per_visit[cue]
                        and state.playedThisVisit[cue]
                    if
                        token ~= state.reaction
                        and not repeated
                        and reactionAt
                        and workspace:GetServerTimeNow() - reactionAt <= config.reaction_expiry_seconds
                        and (recipient == 0 or recipient == Players.LocalPlayer.UserId)
                    then
                        cues, priority, reaction = { cue }, 2, token
                    elseif not state.approached then
                        cues, priority =
                            { s.activity == "egg" and s.cfg.egg_cue or s.cfg.approach_cue }, 3
                    elseif
                        now >= state.nextAt
                        and (
                            s.activity == "arena" and s.face:GetAttribute("HostFightActive")
                            or s.activity == "garden"
                                and s.face:GetAttribute("HostWorkingAt")
                                and workspace:GetServerTimeNow() - s.face:GetAttribute(
                                    "HostWorkingAt"
                                ) <= config.comment_interval_seconds
                        )
                    then
                        cues, priority = { s.cfg.comments[state.rotation % #s.cfg.comments + 1] }, 4
                    end
                end
                local entryAt = Players.LocalPlayer:GetAttribute(
                    require(ReplicatedStorage.Configs.crossroads_arena).entry_audio.cue_attribute
                )
                local entryVoice = speaker == "demon"
                    and entryAt
                    and workspace:GetServerTimeNow() - entryAt
                        < config.arena_entry_voice_grace_seconds
                if cues and s.ready and not blocked and not entryVoice then
                    table.insert(requests, {
                        cues = cues,
                        priority = priority,
                        speaker = speaker,
                        activity = s.activity,
                        state = state,
                        reaction = reaction,
                    })
                end
            end
        end
    end
    table.sort(requests, function(a, b)
        if a.priority ~= b.priority then
            return a.priority < b.priority
        end
        return a.speaker < b.speaker
    end)
    local request = requests[1]
    if request then
        local state = request.state
        if request.activity == "gate" then
            state.greeted = true
        else
            state.playedThisVisit[request.cues[1]] = true
            state.approached = true
            state.count += 1
            state.rotation += 1
            state.nextAt = now + config.comment_interval_seconds
            if request.reaction then
                state.reaction = request.reaction
            end
        end
    end
    return request
end
return Client
