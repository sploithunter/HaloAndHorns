local CollectionService = game:GetService("CollectionService")

local TAG = "LeaderboardBoard"
local GUIDE_TAG = "ChallengeGuide"
-- Screen parts are larger than the wooden opening; keep the card inside the frame.
local ROOT_SCALE = Vector2.new(0.72, 0.86)

local LeaderboardBoardService = {}
LeaderboardBoardService.__index = LeaderboardBoardService

local function color(rgb, fallback)
    if type(rgb) ~= "table" then
        return fallback
    end
    return Color3.fromRGB(rgb[1] or 255, rgb[2] or 255, rgb[3] or 255)
end

local function formatNumber(value)
    local text = tostring(math.floor(tonumber(value) or 0))
    local sign, digits = text:match("^([%-]?)(%d+)$")
    if not digits then
        return text
    end
    local formatted = digits:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
    return sign .. formatted
end

local function label(parent, name, position, size, text, textSize, alignment)
    local item = Instance.new("TextLabel")
    item.Name = name
    item.BackgroundTransparency = 1
    item.Position = position
    item.Size = size
    item.Font = Enum.Font.GothamBold
    item.Text = text
    item.TextColor3 = Color3.fromRGB(244, 246, 255)
    item.TextSize = textSize
    item.TextXAlignment = alignment or Enum.TextXAlignment.Left
    item.Parent = parent
    return item
end

local function insetRoot(gui)
    local root = Instance.new("Frame")
    root.Name = "Root"
    root.AnchorPoint = Vector2.new(0.5, 0.5)
    root.Position = UDim2.fromScale(0.5, 0.5)
    root.Size = UDim2.fromScale(ROOT_SCALE.X, ROOT_SCALE.Y)
    root.BackgroundColor3 = Color3.fromRGB(17, 19, 27)
    root.BorderSizePixel = 0
    root.ClipsDescendants = true
    root.Parent = gui
    return root
end

function LeaderboardBoardService:Init()
    self._logger = self._modules.Logger
    self._config = self._modules.ConfigLoader:LoadConfig("leaderboards")
    self._leaderboards = self._modules.LeaderboardService
    self._challengeConfig = nil
    pcall(function()
        self._challengeConfig = self._modules.ConfigLoader:LoadConfig("challenge_runs")
    end)
    self._boardsById = {}
    self._bindings = {}
    for _, board in ipairs(self._config.boards or {}) do
        self._boardsById[board.id] = board
    end
end

function LeaderboardBoardService:Start()
    for _, host in ipairs(CollectionService:GetTagged(TAG)) do
        self:_bind(host)
    end
    CollectionService:GetInstanceAddedSignal(TAG):Connect(function(host)
        self:_bind(host)
    end)
    CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(host)
        self._bindings[host] = nil
    end)
    for _, host in ipairs(CollectionService:GetTagged(GUIDE_TAG)) do
        self:_bindGuide(host)
    end
    CollectionService:GetInstanceAddedSignal(GUIDE_TAG):Connect(function(host)
        self:_bindGuide(host)
    end)
    self._leaderboards.SnapshotChanged:Connect(function(boardId, snapshot)
        self:_renderBoard(boardId, snapshot)
    end)
end

function LeaderboardBoardService:_screenOf(host)
    if host:IsA("BasePart") then
        return host
    end
    if host:IsA("Model") then
        local named = host:FindFirstChild("Screen", true)
        if named and named:IsA("BasePart") then
            return named
        end
        return host:FindFirstChildWhichIsA("BasePart", true)
    end
    return nil
end

function LeaderboardBoardService:_bind(host)
    if self._bindings[host] then
        return
    end
    local boardId = host:GetAttribute("BoardId")
    local definition = self._boardsById[boardId]
    local screen = self:_screenOf(host)
    if not definition or not screen then
        self._logger:Warn("Leaderboard board hook is incomplete", {
            context = "LeaderboardBoardService",
            host = host:GetFullName(),
            boardId = boardId,
        })
        return
    end

    local old = screen:FindFirstChild("LeaderboardSurface")
    if old then
        old:Destroy()
    end
    local gui = self:_makeBoardGui(screen, host)
    local root = insetRoot(gui)

    local stroke = Instance.new("UIStroke")
    stroke.Color = color(definition.style and definition.style.accent, Color3.new(1, 1, 1))
    stroke.Thickness = 8
    stroke.Parent = root

    local header = Instance.new("Frame")
    header.Name = "Header"
    header.Size = UDim2.new(1, 0, 0, 104)
    header.BackgroundColor3 =
        color(definition.style and definition.style.header, Color3.fromRGB(38, 49, 75))
    header.BorderSizePixel = 0
    header.Parent = root

    label(
        header,
        "Title",
        UDim2.fromOffset(32, 10),
        UDim2.new(1, -64, 0, 54),
        definition.display_name,
        42
    )
    local subtitle = label(
        header,
        "Subtitle",
        UDim2.fromOffset(34, 60),
        UDim2.new(1, -68, 0, 32),
        definition.subtitle or "Global leaders",
        21
    )
    subtitle.Font = Enum.Font.Gotham
    subtitle.TextColor3 = Color3.fromRGB(208, 215, 232)

    local rows = Instance.new("Frame")
    rows.Name = "Rows"
    rows.BackgroundTransparency = 1
    rows.Position = UDim2.fromOffset(0, 104)
    rows.Size = UDim2.new(1, 0, 0, 455)
    rows.Parent = root

    for index = 1, 10 do
        local row = Instance.new("Frame")
        row.Name = "Row" .. index
        row.Position = UDim2.fromOffset(0, (index - 1) * 45)
        row.Size = UDim2.new(1, 0, 0, 40)
        row.BackgroundColor3 = if index % 2 == 0
            then Color3.fromRGB(33, 36, 49)
            else Color3.fromRGB(26, 29, 40)
        row.BorderSizePixel = 0
        row.Parent = rows
        label(row, "Rank", UDim2.fromOffset(14, 0), UDim2.fromOffset(64, 40), tostring(index), 23)
        local playerName =
            label(row, "PlayerName", UDim2.fromOffset(78, 0), UDim2.new(1, -300, 1, 0), "—", 22)
        playerName.TextTruncate = Enum.TextTruncate.AtEnd
        label(
            row,
            "Value",
            UDim2.new(1, -220, 0, 0),
            UDim2.fromOffset(204, 40),
            "—",
            22,
            Enum.TextXAlignment.Right
        )
    end

    local footer = label(
        root,
        "Footer",
        UDim2.new(0, 0, 1, -39),
        UDim2.new(1, 0, 0, 28),
        "GLOBAL TOP 10  •  REFRESHING…",
        17,
        Enum.TextXAlignment.Center
    )
    footer.Font = Enum.Font.Gotham
    footer.TextColor3 = Color3.fromRGB(154, 164, 187)

    self._bindings[host] = { boardId = boardId, root = root }
    self:_renderBinding(self._bindings[host], self._leaderboards:GetSnapshot(boardId))
end

function LeaderboardBoardService:_surfaceFace(screen, host)
    local named = host:GetAttribute("SurfaceFace") or screen:GetAttribute("SurfaceFace")
    if type(named) == "string" and named ~= "" then
        local ok, id = pcall(function()
            return Enum.NormalId[named]
        end)
        if ok and typeof(id) == "EnumItem" then
            return id
        end
    end
    return Enum.NormalId.Front
end

function LeaderboardBoardService:_makeBoardGui(screen, host)
    local gui = Instance.new("SurfaceGui")
    gui.Name = "LeaderboardSurface"
    gui.Face = self:_surfaceFace(screen, host)
    gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
    gui.CanvasSize = Vector2.new(900, 620)
    gui.LightInfluence = 0
    gui.Brightness = 2
    gui.AlwaysOnTop = false
    gui.Parent = screen
    return gui
end

function LeaderboardBoardService:_bindGuide(host)
    local mode = host:GetAttribute("GuideMode")
    local modes = self._challengeConfig and self._challengeConfig.modes
    local guide = type(modes) == "table" and type(modes[mode]) == "table" and modes[mode].guide
    local screen = self:_screenOf(host)
    if type(guide) ~= "table" or not screen then
        self._logger:Warn("Challenge guide hook is incomplete", {
            context = "LeaderboardBoardService",
            host = host:GetFullName(),
            mode = mode,
        })
        return
    end
    local old = screen:FindFirstChild("LeaderboardSurface")
    if old then
        old:Destroy()
    end
    local gui = self:_makeBoardGui(screen, host)
    local root = insetRoot(gui)
    label(
        root,
        "Title",
        UDim2.fromOffset(32, 28),
        UDim2.new(1, -64, 0, 64),
        tostring(guide.title or mode),
        42
    )
    local body = table.concat(guide.lines or {}, "\n\n")
    local lines = label(
        root,
        "Body",
        UDim2.fromOffset(36, 110),
        UDim2.new(1, -72, 1, -160),
        body,
        26
    )
    lines.Font = Enum.Font.Gotham
    lines.TextWrapped = true
    lines.TextYAlignment = Enum.TextYAlignment.Top
    lines.TextColor3 = Color3.fromRGB(208, 215, 232)
end

function LeaderboardBoardService:_renderBoard(boardId, snapshot)
    for host, binding in pairs(self._bindings) do
        if not host.Parent then
            self._bindings[host] = nil
        elseif binding.boardId == boardId then
            self:_renderBinding(binding, snapshot)
        end
    end
end

function LeaderboardBoardService:_renderBinding(binding, snapshot)
    local rows = binding.root:FindFirstChild("Rows")
    local entries = snapshot and snapshot.entries or {}
    local medalColors = {
        Color3.fromRGB(255, 216, 80),
        Color3.fromRGB(213, 220, 232),
        Color3.fromRGB(216, 140, 74),
    }
    for index = 1, 10 do
        local row = rows and rows:FindFirstChild("Row" .. index)
        local entry = entries[index]
        if row then
            row.PlayerName.Text = entry and (entry.displayName or entry.name) or "—"
            row.Value.Text = entry and formatNumber(entry.value) or "—"
            row.Rank.TextColor3 = medalColors[index] or Color3.fromRGB(195, 202, 220)
        end
    end
    local footer = binding.root:FindFirstChild("Footer")
    if footer then
        local source = snapshot and snapshot.source == "global" and "GLOBAL TOP 10"
            or "SERVER PREVIEW"
        footer.Text = source .. "  •  UPDATED " .. os.date("!%H:%M UTC")
    end
end

return LeaderboardBoardService
