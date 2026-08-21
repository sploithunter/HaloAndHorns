--[[
    AwardPodium — client visualization of a 1st / 2nd / 3rd stand.

    Builds the parts locally, then stands the top snapshot characters on them.
    Scores stay server-authoritative via LeaderboardUpdated.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HOOK_TAG = "AwardPodium"

local AwardPodiumLogic = require(ReplicatedStorage.Shared.Game.AwardPodiumLogic)
local BlockLetterSign = require(ReplicatedStorage.Shared.Assets.BlockLetterSign)
local LeaderboardController = require(script.Parent.LeaderboardController)

local R15_IDLE = "rbxassetid://507766388"
local DEFAULT_DANCES = {
    "rbxassetid://507771019",
    "rbxassetid://507776043",
    "rbxassetid://507776720",
}
local RANK_COLORS = {
    Color3.fromRGB(255, 204, 64),
    Color3.fromRGB(196, 204, 214),
    Color3.fromRGB(184, 112, 62),
}

local AwardPodium = {}
local started = false
local stands = {}

local function loadConfig()
    local ok, cfg = pcall(function()
        return require(ReplicatedStorage.Configs.leaderboards)
    end)
    if ok and type(cfg) == "table" then
        return cfg
    end
    return nil
end

local function findHook(definition)
    for _, hook in ipairs(CollectionService:GetTagged(HOOK_TAG)) do
        if
            hook:GetAttribute("PodiumId") == definition.id
            or hook:GetAttribute("BoardId") == definition.board_id
        then
            return hook
        end
    end
    return nil
end

local function waitHook(definition)
    local hook = findHook(definition)
    if hook then
        return hook
    end
    local deadline = os.clock() + 30
    while os.clock() < deadline do
        task.wait(0.2)
        hook = findHook(definition)
        if hook then
            return hook
        end
    end
    return nil
end

local function part(parent, name, size, cframe, color)
    local item = Instance.new("Part")
    item.Name = name
    item.Anchored = true
    item.CanCollide = true
    item.CanQuery = false
    item.CastShadow = true
    item.Material = Enum.Material.SmoothPlastic
    item.Color = color
    item.Size = size
    item.CFrame = cframe
    item.Parent = parent
    return item
end

local function requestSnapshot(boardId)
    local remote = ReplicatedStorage:FindFirstChild("GameAPICommand")
    if not remote then
        return nil
    end
    local ok, envelope = pcall(function()
        return remote:InvokeServer("leaderboard.snapshot", { boardId = boardId })
    end)
    if not ok or type(envelope) ~= "table" then
        return nil
    end
    return envelope.result or envelope
end

local function playDance(model, dances)
    local humanoid = model:FindFirstChildOfClass("Humanoid")
    if not humanoid then
        return
    end
    local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
    animator.Parent = humanoid
    local pool = {}
    for _, id in ipairs(type(dances) == "table" and dances or DEFAULT_DANCES) do
        if type(id) == "string" and id ~= "" then
            table.insert(pool, id)
        end
    end
    if #pool == 0 then
        pool = DEFAULT_DANCES
    end

    local lastId = nil
    local function playNext()
        if not model.Parent then
            return
        end
        local id = AwardPodiumLogic.pickClip(pool, lastId) or R15_IDLE
        lastId = id
        local animation = Instance.new("Animation")
        animation.Name = "PodiumDance"
        animation.AnimationId = id
        animation.Parent = model
        local ok, track = pcall(function()
            return animator:LoadAnimation(animation)
        end)
        if not (ok and track) then
            return
        end
        track.Looped = false
        track.Priority = Enum.AnimationPriority.Action
        track.Stopped:Connect(function()
            animation:Destroy()
            playNext()
        end)
        track:Play()
    end
    playNext()
end

local function mannequin(model)
    local humanoid = model:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid.AutoRotate = false
        humanoid.PlatformStand = false
        humanoid.WalkSpeed = 0
        humanoid.JumpPower = 0
        humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
        humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
        humanoid.NameDisplayDistance = 0
        humanoid.HealthDisplayDistance = 0
        pcall(function()
            humanoid.EvaluateStateMachine = false
        end)
    end
    for _, descendant in ipairs(model:GetDescendants()) do
        if descendant:IsA("BasePart") then
            descendant.CanCollide = false
            descendant.Massless = true
        elseif descendant:IsA("BillboardGui") or descendant:IsA("ProximityPrompt") then
            descendant:Destroy()
        end
    end
    -- Anchor only the root. Anchoring every limb/accessory breaks welds and
    -- leaves hats and heads behind when the body is PivotTo'd.
    local root = model:FindFirstChild("HumanoidRootPart")
    if root and root:IsA("BasePart") then
        root.Anchored = true
    end
end

local function standCFrameOnTop(model, standCFrame)
    local humanoid = model:FindFirstChildOfClass("Humanoid")
    local root = model:FindFirstChild("HumanoidRootPart")
    if humanoid and root then
        local ground = standCFrame.Position.Y
        local rootY = ground + humanoid.HipHeight + root.Size.Y * 0.5
        return CFrame.new(standCFrame.Position.X, rootY, standCFrame.Position.Z)
            * (standCFrame - standCFrame.Position)
    end
    model:PivotTo(standCFrame)
    local cf, size = model:GetBoundingBox()
    local bottom = cf.Position.Y - size.Y * 0.5
    return model:GetPivot() + Vector3.new(0, standCFrame.Position.Y - bottom, 0)
end

local function standCharacter(model, standCFrame, dances)
    mannequin(model)
    local posed = standCFrameOnTop(model, standCFrame)
    model:PivotTo(posed)
    playDance(model, dances)
    mannequin(model)
    model:PivotTo(posed)
end

local function formatScore(value)
    local text = tostring(math.floor(tonumber(value) or 0))
    local sign, digits = text:match("^([%-]?)(%d+)$")
    if not digits then
        return text
    end
    return sign .. digits:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
end

local function paintPlate(plate, playerName, score)
    local nameLabel = plate:FindFirstChild("PlayerName", true)
    local scoreLabel = plate:FindFirstChild("Score", true)
    if nameLabel and nameLabel:IsA("TextLabel") then
        nameLabel.Text = playerName
    end
    if scoreLabel and scoreLabel:IsA("TextLabel") then
        scoreLabel.Text = score
    end
end

local function makePlate(parent, name, cframe, size)
    local plate = part(parent, name, size, cframe, Color3.fromRGB(18, 20, 28))
    plate.CanCollide = false
    plate.Material = Enum.Material.SmoothPlastic

    local gui = Instance.new("SurfaceGui")
    gui.Name = "PlateSurface"
    gui.Face = Enum.NormalId.Front
    gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
    gui.CanvasSize = Vector2.new(400, 180)
    gui.LightInfluence = 0
    gui.Brightness = 1.8
    gui.AlwaysOnTop = false
    gui.Parent = plate

    local root = Instance.new("Frame")
    root.Name = "Root"
    root.Size = UDim2.fromScale(1, 1)
    root.BackgroundColor3 = Color3.fromRGB(18, 20, 28)
    root.BorderSizePixel = 0
    root.Parent = gui

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(236, 228, 196)
    stroke.Thickness = 8
    stroke.Parent = root

    local playerName = Instance.new("TextLabel")
    playerName.Name = "PlayerName"
    playerName.BackgroundTransparency = 1
    playerName.Position = UDim2.fromOffset(12, 8)
    playerName.Size = UDim2.new(1, -24, 0, 96)
    playerName.Font = Enum.Font.GothamBold
    playerName.Text = "—"
    playerName.TextColor3 = Color3.fromRGB(255, 255, 255)
    playerName.TextScaled = true
    playerName.TextTruncate = Enum.TextTruncate.AtEnd
    playerName.Parent = root
    local nameSize = Instance.new("UITextSizeConstraint")
    nameSize.MinTextSize = 36
    nameSize.MaxTextSize = 80
    nameSize.Parent = playerName

    local score = Instance.new("TextLabel")
    score.Name = "Score"
    score.BackgroundTransparency = 1
    score.Position = UDim2.fromOffset(12, 104)
    score.Size = UDim2.new(1, -24, 0, 64)
    score.Font = Enum.Font.GothamBold
    score.Text = ""
    score.TextColor3 = Color3.fromRGB(255, 214, 110)
    score.TextScaled = true
    score.Parent = root
    local scoreSize = Instance.new("UITextSizeConstraint")
    scoreSize.MinTextSize = 32
    scoreSize.MaxTextSize = 64
    scoreSize.Parent = score

    return plate
end

local function buildStand(definition)
    local hook = waitHook(definition)
    if not hook then
        return nil
    end
    local existing = hook:FindFirstChild("AwardPodium_" .. definition.id)
    if existing then
        existing:Destroy()
    end
    for _, child in ipairs(hook:GetChildren()) do
        if
            child.Name:match("^AwardPodium_")
            or child.Name:match("^Figure")
            or child:IsA("Accessory")
        then
            child:Destroy()
        end
    end

    local origin = hook:IsA("Model") and hook:GetPivot() or hook.CFrame
    local _, yaw = origin:ToEulerAnglesYXZ()
    local yawDegrees = math.deg(yaw)

    local step = definition.step or {}
    local width = tonumber(step.width) or 4.4
    local depth = tonumber(step.depth) or 4.4
    local gap = tonumber(step.gap) or 0.4
    local model = Instance.new("Model")
    model.Name = "AwardPodium_" .. definition.id
    model.Parent = hook

    local span = (width + gap) * 2 + width
    part(
        model,
        "Base",
        Vector3.new(span + 1.6, 0.6, depth + 1.8),
        origin * CFrame.new(0, 0.3, 0.2),
        Color3.fromRGB(28, 30, 38)
    )

    local plateCfg = definition.plate or {}
    local plateWidth = tonumber(plateCfg.width) or 3.7
    local plateHeight = tonumber(plateCfg.height) or 1.15
    local plateDepth = tonumber(plateCfg.thickness) or 0.14
    local plateFromTop = tonumber(plateCfg.from_top) or 0.78
    local steps = {}
    local plates = {}
    for rank = 1, 3 do
        local height = AwardPodiumLogic.stepHeight(rank, step.heights)
        local x = AwardPodiumLogic.stepX(rank, width, gap)
        local color = RANK_COLORS[rank]
        local block = part(
            model,
            "Step" .. rank,
            Vector3.new(width, height, depth),
            origin * CFrame.new(x, 0.6 + height * 0.5, 0),
            color
        )
        block.Material = Enum.Material.Metal
        local plateY = 0.6 + height - plateFromTop
        -- Hook LookVector is front (white arrow). Plates sit on that face.
        local plateZ = -(depth * 0.5 + plateDepth * 0.5 + 0.03)
        plates[rank] = makePlate(
            model,
            "Plate" .. rank,
            origin * CFrame.new(x, plateY, plateZ),
            Vector3.new(plateWidth, plateHeight, plateDepth)
        )
        local faceYaw = math.rad(tonumber(definition.figure_yaw_degrees) or 0)
        local top = origin * CFrame.new(x, 0.6 + height, 0) * CFrame.Angles(0, faceYaw, 0)
        steps[rank] = top
    end

    local titleLines = definition.title
    if type(titleLines) == "table" and #titleLines > 0 then
        local titleAt = origin
            * CFrame.new(
                0,
                tonumber(definition.title_height) or 17.5,
                -(tonumber(definition.title_back) or 3.4)
            )
        BlockLetterSign.build(model, {
            name = "PodiumTitle",
            lines = titleLines,
            x = titleAt.Position.X,
            y = titleAt.Position.Y,
            z = titleAt.Position.Z,
            -- Letters read correctly when you look along their LookVector.
            -- The audience faces the hook, so the title needs the opposite yaw.
            yaw_degrees = yawDegrees + 180,
            cell = tonumber(definition.title_cell) or 0.55,
            depth = 0.8,
            color = definition.title_color or { 255, 77, 55 },
            backing = false,
            light = false,
            material = "Neon",
        })
    end

    return {
        definition = definition,
        model = model,
        steps = steps,
        plates = plates,
        figures = {},
    }
end

local function clearFigures(stand)
    stand.placeGeneration = (stand.placeGeneration or 0) + 1
    for _, figure in pairs(stand.figures) do
        if figure then
            figure:Destroy()
        end
    end
    stand.figures = {}
    if stand.model then
        for _, child in ipairs(stand.model:GetChildren()) do
            if child.Name:match("^Figure") or child:FindFirstChildOfClass("Humanoid") then
                child:Destroy()
            end
        end
    end
end

local function paintPlates(stand, slots)
    local byRank = {}
    for _, slot in ipairs(slots) do
        byRank[slot.rank] = slot
    end
    for rank = 1, 3 do
        local plate = stand.plates and stand.plates[rank]
        if plate then
            local slot = byRank[rank]
            if slot then
                paintPlate(plate, slot.name, formatScore(slot.value))
            else
                paintPlate(plate, "—", "")
            end
        end
    end
end

local function placeFigures(stand, slots)
    clearFigures(stand)
    local generation = stand.placeGeneration
    local byRank = {}
    for _, slot in ipairs(slots) do
        byRank[slot.rank] = slot
    end
    for rank = 1, 3 do
        local slot = byRank[rank]
        local standCFrame = stand.steps[rank]
        if slot and standCFrame then
            task.spawn(function()
                local ok, desc = pcall(function()
                    return Players:GetHumanoidDescriptionFromUserId(slot.userId)
                end)
                if not (ok and desc) or generation ~= stand.placeGeneration then
                    return
                end
                local okModel, model = pcall(function()
                    return Players:CreateHumanoidModelFromDescription(
                        desc,
                        Enum.HumanoidRigType.R15
                    )
                end)
                if not (okModel and model) then
                    return
                end
                if generation ~= stand.placeGeneration or not stand.model.Parent then
                    model:Destroy()
                    return
                end
                model.Name = "Figure" .. rank
                model.Parent = stand.model
                standCharacter(model, standCFrame, stand.definition.dances)
                if generation ~= stand.placeGeneration then
                    model:Destroy()
                    return
                end
                stand.figures[rank] = model
            end)
        end
    end
end

local function refreshStand(stand, snapshot)
    snapshot = snapshot or LeaderboardController.Get(stand.definition.board_id)
    local slots = AwardPodiumLogic.slots(snapshot and snapshot.entries, nil, 3)
    local scoreKey = AwardPodiumLogic.scoreKey(slots)
    if scoreKey == stand.scoreKey then
        return
    end
    stand.scoreKey = scoreKey
    paintPlates(stand, slots)

    local occupantKey = AwardPodiumLogic.occupantKey(slots)
    if occupantKey == stand.occupantKey then
        return
    end
    stand.occupantKey = occupantKey
    placeFigures(stand, slots)
end

local function spawnPodiums()
    local config = loadConfig()
    for _, definition in ipairs((config and config.podiums) or {}) do
        if type(definition) == "table" and type(definition.board_id) == "string" then
            local stand = buildStand(definition)
            if stand then
                stands[definition.id] = stand
                local snapshot = requestSnapshot(definition.board_id)
                if type(snapshot) == "table" and snapshot.ok == true then
                    LeaderboardController.GetAll()[definition.board_id] = snapshot
                    refreshStand(stand, snapshot)
                else
                    refreshStand(stand)
                end
            end
        end
    end
end

function AwardPodium.start()
    if started then
        return
    end
    started = true
    LeaderboardController.OnUpdate(function(boardId)
        for _, stand in pairs(stands) do
            if stand.definition.board_id == boardId then
                refreshStand(stand)
            end
        end
    end)
    task.spawn(spawnPodiums)
end

return AwardPodium
