-- Authored podium adapter. Only authoritative filtered snapshots select winners.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Controller = require(script.Parent.LeaderboardController)
local Podium = require(script.Parent.AwardPodium)
local Logic = require(ReplicatedStorage.Shared.Game.AwardPodiumLogic)
local Display = {}
local started = false

local function resolve(root, path)
    for _, name in ipairs(path) do
        root = root and root:FindFirstChild(name)
    end
    return root
end

function Display.start()
    if started then
        return
    end
    started = true
    local config = require(ReplicatedStorage.Configs.leaderboards)
    local cfg = config.crossroads_podiums
    if not cfg.enabled then
        return
    end
    local player = Players.LocalPlayer
    local states, cache, cacheOrder = {}, {}, {}
    local audienceSlots = {}
    local audience = cfg.audience
    local runtime = Instance.new("Folder")
    runtime.Name = cfg.runtime_name
    runtime.Parent = workspace
    local function label(plate)
        local gui = Instance.new("SurfaceGui")
        gui.Name = cfg.gui_name
        gui.Face = Enum.NormalId[cfg.face]
        gui.CanvasSize = Vector2.new(unpack(cfg.canvas))
        gui.LightInfluence = cfg.light_influence
        gui.Brightness = cfg.brightness
        gui.Parent = plate
        local text = Instance.new("TextLabel")
        text.Name = "Winner"
        text.BackgroundTransparency = 1
        text.Size = UDim2.fromScale(1, 1)
        text.Font = Enum.Font[cfg.font]
        text.TextColor3 = Color3.fromRGB(unpack(cfg.text_color))
        text.TextScaled = true
        text.Text = cfg.loading_text
        text.Parent = gui
        return text
    end
    local function clearFigure(slot)
        slot.wanted = false
        slot.userId = nil
        if slot.figure then
            slot.figure:Destroy()
            slot.figure = nil
        end
    end
    local function remove(state)
        for _, slot in ipairs(state.slots) do
            clearFigure(slot)
            if slot.label.Parent then
                slot.label.Parent:Destroy()
            end
        end
    end
    local function request(state)
        if state.requesting or os.clock() < state.retryAt then
            return
        end
        state.requesting = true
        state.retryAt = os.clock()
            + (state.snapshot and config.publication.refresh_seconds or cfg.retry_seconds)
        task.spawn(function()
            local remote = ReplicatedStorage:FindFirstChild("GameAPICommand")
            local ok, envelope = pcall(function()
                return remote
                    and remote:InvokeServer(
                        "leaderboard.snapshot",
                        { boardId = state.definition.board_id }
                    )
            end)
            local snapshot = ok and type(envelope) == "table" and (envelope.result or envelope)
            if snapshot and snapshot.ok then
                state.snapshot = snapshot
            elseif not state.snapshot then
                state.failed = true
            end
            state.requesting = false
        end)
    end
    local function synchronizeAudience()
        if not audience or not audience.enabled then
            return
        end
        -- Old imported maps may still contain preview rigs. Suppress only the owned preview.
        local preview = resolve(workspace, audience.preview_path)
        if preview then
            for _, part in ipairs(preview:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.LocalTransparencyModifier = 1
                end
            end
        end
        local stands = resolve(workspace, audience.root_path)
        local seats = {}
        for _, seat in ipairs(stands and stands:GetChildren() or {}) do
            if seat:IsA("Seat") then
                local id = seat:GetAttribute(audience.slot_attribute)
                if id then
                    seats[id] = seat
                end
            end
        end
        for index, seatId in ipairs(audience.reserved_slots) do
            local seat = seats[seatId]
            local slot = audienceSlots[index]
            if slot and slot.anchor ~= seat then
                clearFigure(slot)
                audienceSlots[index] = nil
                slot = nil
            end
            -- Enabled and occupied Seats are always owned by visiting players.
            if seat and seat.Disabled and not seat.Occupant and not slot then
                audienceSlots[index] = { anchor = seat, seated = true, retryAt = 0 }
            end
        end
    end
    local function synchronize()
        local root = resolve(workspace, cfg.root_path)
        local bays = root and root:FindFirstChild(cfg.alcoves_name)
        local anchors = root and root:FindFirstChild(cfg.anchors_name)
        for _, definition in ipairs(cfg.boards) do
            local bay = bays and bays:FindFirstChild(definition.alcove)
            local state = states[definition.board_id]
            if not state then
                state = {
                    definition = definition,
                    slots = {},
                    retryAt = 0,
                    snapshot = Controller.Get(definition.board_id),
                }
                states[definition.board_id] = state
            end
            local stale = state.bay ~= bay
            for _, slot in ipairs(state.slots) do
                stale = stale
                    or not slot.anchor:IsDescendantOf(workspace)
                    or not slot.plate:IsDescendantOf(workspace)
            end
            if stale then
                remove(state)
                state.slots = {}
            end
            state.bay = bay
            if #state.slots == 0 and bay and anchors then
                local slots = {}
                for rank = 1, cfg.ranks do
                    local name = definition.alcove .. "_Rank" .. rank .. "Anchor"
                    local host = anchors:FindFirstChild(name .. "Host")
                    local anchor = host and host:FindFirstChild(name)
                    local plate = bay:FindFirstChild(cfg.plate_prefix .. rank)
                    if anchor and plate then
                        slots[rank] = { anchor = anchor, plate = plate, retryAt = 0 }
                    end
                end
                if #slots == cfg.ranks then
                    for _, slot in ipairs(slots) do
                        slot.label = label(slot.plate)
                    end
                    state.slots = slots
                end
            end
            if state then
                request(state)
            end
        end
    end
    Controller.OnUpdate(function(boardId, snapshot)
        if states[boardId] then
            states[boardId].snapshot = snapshot
        end
    end)
    local function sitCharacter(model, seat)
        model:ScaleTo(audience.scale)
        local root = assert(model:FindFirstChild("HumanoidRootPart"))
        local lower = assert(model:FindFirstChild("LowerTorso"))
        local joints = {}
        for _, item in ipairs(model:GetDescendants()) do
            if item:IsA("BasePart") then
                item.Anchored = true
                item.CanCollide, item.CanTouch, item.CanQuery = false, false, false
            elseif item:IsA("Motor6D") then
                table.insert(joints, {
                    Name = item.Name,
                    Part0 = item.Part0,
                    Part1 = item.Part1,
                    C0 = item.C0,
                    C1 = item.C1,
                    instance = item,
                })
            elseif item:IsA("AnimationConstraint") and item.Attachment0 and item.Attachment1 then
                table.insert(joints, {
                    Name = item.Name,
                    Part0 = item.Attachment0.Parent,
                    Part1 = item.Attachment1.Parent,
                    C0 = item.Attachment0.CFrame,
                    C1 = item.Attachment1.CFrame,
                    instance = item,
                })
            elseif item:IsA("Humanoid") then
                -- Roblox requires the Humanoid to render the member's clothing/body appearance.
                item.EvaluateStateMachine = false
                item.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
                item.BreakJointsOnDeath = false
            elseif item:IsA("BaseScript") or item:IsA("Animator") then
                item:Destroy()
            end
        end
        -- Resolve the R15 joint tree once, then freeze it; accessories follow via their welds.
        local frames = { [root] = seat.CFrame }
        for _ = 1, #joints do
            for _, joint in ipairs(joints) do
                if frames[joint.Part0] and not frames[joint.Part1] then
                    local angles = audience.joint_degrees[joint.Name] or {}
                    frames[joint.Part1] = frames[joint.Part0]
                        * joint.C0
                        * CFrame.Angles(
                            math.rad(angles[1] or 0),
                            math.rad(angles[2] or 0),
                            math.rad(angles[3] or 0)
                        )
                        * joint.C1:Inverse()
                end
            end
        end
        local lowerFrame = assert(frames[lower], "Missing R15 lower torso joint")
        local desired = seat.CFrame:PointToWorldSpace(
            Vector3.new(0, seat.Size.Y / 2 + lower.Size.Y / 2 + audience.hip_clearance, 0)
        )
        local offset = desired - lowerFrame.Position
        for part, frame in pairs(frames) do
            part.CFrame = frame + offset
        end
        -- AccessoryWeld endpoints can still be unset immediately after async avatar creation.
        -- Match the authored attachment pairs directly, including layered clothing handles.
        for _, accessory in ipairs(model:GetChildren()) do
            if accessory:IsA("Accessory") then
                local handle = accessory:FindFirstChild("Handle")
                local attachment = handle and handle:FindFirstChildOfClass("Attachment")
                if attachment then
                    for part in pairs(frames) do
                        local target = part:FindFirstChild(attachment.Name)
                        if target and target:IsA("Attachment") then
                            handle.CFrame = part.CFrame
                                * target.CFrame
                                * attachment.CFrame:Inverse()
                            break
                        end
                    end
                end
            end
        end
        for _, joint in ipairs(joints) do
            joint.instance:Destroy()
        end
    end
    -- One appearance request at a time; cache descriptions, not hidden live rigs.
    local loading = false
    local function loadFigure(slot, winner)
        if loading or os.clock() < slot.retryAt then
            return
        end
        loading = true
        slot.userId = winner.userId
        slot.retryAt = os.clock() + cfg.retry_seconds
        task.spawn(function()
            local ok, model = pcall(function()
                local desc = cache[winner.userId]
                if not desc then
                    desc = Players:GetHumanoidDescriptionFromUserIdAsync(winner.userId)
                    cache[winner.userId] = desc
                    table.insert(cacheOrder, winner.userId)
                    if #cacheOrder > cfg.cache_size then
                        local id = table.remove(cacheOrder, 1)
                        cache[id]:Destroy()
                        cache[id] = nil
                    end
                end
                return Players:CreateHumanoidModelFromDescriptionAsync(
                    desc,
                    Enum.HumanoidRigType.R15
                )
            end)
            if ok and model then
                if
                    slot.userId == winner.userId
                    and slot.wanted
                    and slot.anchor:IsDescendantOf(workspace)
                    and (not slot.seated or (slot.anchor.Disabled and not slot.anchor.Occupant))
                then
                    model.Name = "Winner_" .. winner.userId
                    model:SetAttribute("BoardId", slot.boardId)
                    model:SetAttribute("Rank", winner.rank)
                    model:SetAttribute("UserId", winner.userId)
                    model.Parent = runtime
                    for _, part in ipairs(model:GetDescendants()) do
                        if part:IsA("BasePart") then
                            part.CanTouch, part.CanQuery = false, false
                        end
                    end
                    local placed, placementError
                    if slot.seated then
                        model:SetAttribute(
                            "SpectatorSlot",
                            slot.anchor:GetAttribute(audience.slot_attribute)
                        )
                        placed, placementError = pcall(sitCharacter, model, slot.anchor)
                    else
                        placed, placementError = pcall(
                            Podium.standCharacter,
                            model,
                            slot.anchor.WorldCFrame
                                * CFrame.Angles(0, math.rad(cfg.figure_yaw_degrees), 0),
                            config.podiums[1].dances
                        )
                    end
                    if placed then
                        slot.figure = model
                    else
                        warn("Crossroads winner placement failed: " .. tostring(placementError))
                        model:Destroy()
                    end
                else
                    model:Destroy()
                end
            end
            loading = false
        end)
    end
    local function update()
        synchronize()
        synchronizeAudience()
        local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        local candidates = {}
        local seatedCandidates = {}
        for boardId, state in pairs(states) do
            local snapshot = state.snapshot
            local winners = Logic.slots(snapshot and snapshot.entries, nil, cfg.ranks)
            for rank, slot in ipairs(state.slots) do
                local winner = winners[rank]
                slot.boardId = boardId
                slot.wanted = false
                if winner then
                    slot.label.Text = winner.name
                        .. "  •  "
                        .. Podium.formatScore(winner.value)
                        .. "\n#"
                        .. rank
                        .. "  "
                        .. (cfg.source_labels[snapshot.source] or "")
                    if slot.userId ~= winner.userId then
                        clearFigure(slot)
                    end
                    local distance = root and (root.Position - slot.anchor.WorldPosition).Magnitude
                        or math.huge
                    if distance <= cfg.distance then
                        table.insert(
                            candidates,
                            { slot = slot, winner = winner, distance = distance }
                        )
                    end
                else
                    clearFigure(slot)
                    slot.label.Text = snapshot
                            and (cfg.empty_text .. "\n" .. (cfg.source_labels[snapshot.source] or ""))
                        or (state.failed and cfg.unavailable_text or cfg.loading_text)
                end
            end
        end
        for index, slot in pairs(audienceSlots) do
            local definition = cfg.boards[math.floor((index - 1) / cfg.ranks) + 1]
            local rank = (index - 1) % cfg.ranks + 1
            local state = states[definition.board_id]
            local snapshot = state and state.snapshot or Controller.Get(definition.board_id)
            local winner = Logic.slots(snapshot and snapshot.entries, nil, cfg.ranks)[rank]
            slot.boardId = definition.board_id
            slot.wanted = false
            if not winner or slot.userId ~= winner.userId then
                clearFigure(slot)
            end
            local distance = root and (root.Position - slot.anchor.Position).Magnitude or math.huge
            if
                winner
                and slot.anchor.Disabled
                and not slot.anchor.Occupant
                and distance <= audience.distance
            then
                table.insert(
                    seatedCandidates,
                    { slot = slot, winner = winner, distance = distance }
                )
            end
        end
        table.sort(seatedCandidates, function(a, b)
            return a.distance < b.distance
        end)
        for i = 1, math.min(audience and audience.max_figures or 0, #seatedCandidates) do
            seatedCandidates[i].slot.wanted = true
        end
        for _, slot in pairs(audienceSlots) do
            if not slot.wanted then
                clearFigure(slot)
            end
        end
        table.sort(candidates, function(a, b)
            return a.distance < b.distance
        end)
        for i = 1, math.min(cfg.max_figures, #candidates) do
            candidates[i].slot.wanted = true
        end
        for _, state in pairs(states) do
            for _, slot in ipairs(state.slots) do
                if not slot.wanted then
                    clearFigure(slot)
                end
            end
        end
        -- Load whichever visible placement is closest first, sharing the serial request budget.
        for _, item in ipairs(seatedCandidates) do
            if item.slot.wanted then
                table.insert(candidates, item)
            end
        end
        table.sort(candidates, function(a, b)
            return a.distance < b.distance
        end)
        for _, item in ipairs(candidates) do
            if item.slot.wanted and not item.slot.figure then
                loadFigure(item.slot, item.winner)
            end
        end
    end
    local elapsed = 0
    RunService.Heartbeat:Connect(function(dt)
        elapsed += dt
        if elapsed >= cfg.poll_seconds then
            elapsed = 0
            update()
        end
    end)
end

return Display
