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
    local function synchronize()
        local root = resolve(workspace, cfg.root_path)
        local bays = root and root:FindFirstChild(cfg.alcoves_name)
        local anchors = root and root:FindFirstChild(cfg.anchors_name)
        for _, definition in ipairs(cfg.boards) do
            local bay = bays and bays:FindFirstChild(definition.alcove)
            local state = states[definition.board_id]
            if
                state and (state.bay ~= bay or not state.slots[1].anchor:IsDescendantOf(workspace))
            then
                remove(state)
                states[definition.board_id] = nil
                state = nil
            end
            if not state and bay and anchors then
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
                    state = { bay = bay, definition = definition, slots = slots, retryAt = 0 }
                    state.snapshot = Controller.Get(definition.board_id)
                    states[definition.board_id] = state
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
                    local placed = pcall(
                        Podium.standCharacter,
                        model,
                        slot.anchor.WorldCFrame
                            * CFrame.Angles(0, math.rad(cfg.figure_yaw_degrees), 0),
                        config.podiums[1].dances
                    )
                    if placed then
                        slot.figure = model
                    else
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
        local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        local candidates = {}
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
        for i = 1, math.min(cfg.max_figures, #candidates) do
            local item = candidates[i]
            if not item.slot.figure then
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
