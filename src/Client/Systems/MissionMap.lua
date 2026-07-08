--[[
    MissionMap — CoH-style mission minimap (Jason ask, 2026-07-08).

    Pure function of the LocalPlayer attribute `MissionMapData` (JSON payload
    published by MissionInstanceService from the SAME LayoutSpec that stamped
    the map): rooms fog-of-war'd until someone stands in them, walkable
    doorways drawn as bright ticks on the edges of revealed rooms (sealed/cap
    doorways never appear), a marker per player inside the mission (you =
    white, teammates = cyan), objective room glows once the clear-gate opens
    (MissionObjectiveCount == "★").

    Minimizable (— / + collapses to the title bar) and DRAGGABLE anywhere
    (UI.DragHandle — the reusable drag helper other panels adopt later).
    Panel is scale-sized; the room rects use pixel math INSIDE the canvas
    only to keep the map aspect-correct at any panel size.
]]

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local CLASS_COLOR = {
    entrance = Color3.fromRGB(85, 255, 127),
    corridor = Color3.fromRGB(150, 150, 155),
    room = Color3.fromRGB(99, 128, 160),
    junction = Color3.fromRGB(222, 178, 72),
    objective = Color3.fromRGB(130, 40, 34), -- dim until the gate opens
}
local OBJECTIVE_ACTIVE = Color3.fromRGB(255, 60, 40)
local REVEAL_MARGIN = 4 -- studs of slack when deciding "I'm in this room"

local MissionMap = {}

function MissionMap.start()
    local player = Players.LocalPlayer
    local playerGui = player:WaitForChild("PlayerGui")
    local DragHandle = require(script.Parent.Parent.UI.DragHandle)

    local gui = Instance.new("ScreenGui")
    gui.Name = "MissionMap"
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 40
    gui.Parent = playerGui

    -- ---- panel shell ------------------------------------------------------
    local panel = Instance.new("Frame")
    panel.Name = "Panel"
    panel.AnchorPoint = Vector2.new(1, 1)
    panel.Position = UDim2.fromScale(0.985, 0.8)
    panel.Size = UDim2.fromScale(0.19, 0.32)
    panel.BackgroundTransparency = 1
    panel.Visible = false
    panel.Parent = gui

    local header = Instance.new("TextButton") -- button = drag surface + sinks clicks
    header.Name = "Header"
    header.Size = UDim2.fromScale(1, 0.11)
    header.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
    header.BackgroundTransparency = 0.15
    header.Text = ""
    header.AutoButtonColor = false
    header.Parent = panel
    local headerCorner = Instance.new("UICorner")
    headerCorner.CornerRadius = UDim.new(0.35, 0)
    headerCorner.Parent = header

    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.BackgroundTransparency = 1
    title.Size = UDim2.fromScale(0.78, 0.9)
    title.Position = UDim2.fromScale(0.05, 0.05)
    title.Font = Enum.Font.GothamBold
    title.TextScaled = true
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.TextColor3 = Color3.fromRGB(255, 235, 170)
    title.Text = "MAP"
    title.Parent = header

    local minimize = Instance.new("TextButton")
    minimize.Name = "Minimize"
    minimize.AnchorPoint = Vector2.new(1, 0.5)
    minimize.Position = UDim2.fromScale(0.97, 0.5)
    minimize.Size = UDim2.fromScale(0.14, 0.8)
    minimize.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
    minimize.Font = Enum.Font.GothamBlack
    minimize.TextScaled = true
    minimize.TextColor3 = Color3.fromRGB(255, 255, 255)
    minimize.Text = "–"
    minimize.Parent = header
    local minCorner = Instance.new("UICorner")
    minCorner.CornerRadius = UDim.new(0.4, 0)
    minCorner.Parent = minimize

    local canvas = Instance.new("Frame")
    canvas.Name = "Canvas"
    canvas.Position = UDim2.fromScale(0, 0.12)
    canvas.Size = UDim2.fromScale(1, 0.88)
    canvas.BackgroundColor3 = Color3.fromRGB(12, 12, 18)
    canvas.BackgroundTransparency = 0.2
    canvas.ClipsDescendants = true
    canvas.Parent = panel
    local canvasCorner = Instance.new("UICorner")
    canvasCorner.CornerRadius = UDim.new(0.04, 0)
    canvasCorner.Parent = canvas

    local mapRoot = Instance.new("Frame")
    mapRoot.Name = "MapRoot"
    mapRoot.BackgroundTransparency = 1
    mapRoot.Size = UDim2.fromScale(1, 1)
    mapRoot.Parent = canvas

    DragHandle.attach(panel, header)

    -- ---- state ------------------------------------------------------------
    local data = nil -- decoded payload
    local roomFrames = {}
    local doorFrames = {}
    local revealed = {}
    local markers = {} -- [player] = Frame
    local FULL_SIZE = panel.Size
    local MIN_SIZE = UDim2.fromScale(0.19, 0.036)
    local minimized = false

    minimize.Activated:Connect(function()
        minimized = not minimized
        canvas.Visible = not minimized
        panel.Size = minimized and MIN_SIZE or FULL_SIZE
        header.Size = minimized and UDim2.fromScale(1, 1) or UDim2.fromScale(1, 0.11)
        minimize.Text = minimized and "+" or "–"
    end)

    local function clearMap()
        for _, f in ipairs(roomFrames) do
            f:Destroy()
        end
        for _, f in ipairs(doorFrames) do
            f:Destroy()
        end
        for _, m in pairs(markers) do
            m:Destroy()
        end
        roomFrames, doorFrames, revealed, markers = {}, {}, {}, {}
    end

    -- studs → canvas pixels, aspect-correct with letterboxing
    local function projector()
        local b = data.bbox
        local w, d = b.maxx - b.minx, b.maxz - b.minz
        local cw, ch = canvas.AbsoluteSize.X, canvas.AbsoluteSize.Y
        local pad = 6
        local scale = math.min((cw - pad * 2) / w, (ch - pad * 2) / d)
        local offX = (cw - w * scale) / 2
        local offZ = (ch - d * scale) / 2
        return function(x, z)
            return offX + (x - b.minx) * scale, offZ + (z - b.minz) * scale
        end,
            scale
    end

    local function rebuild()
        clearMap()
        if not data or canvas.AbsoluteSize.X < 20 then
            return
        end
        local toPx, scale = projector()

        for i, room in ipairs(data.rooms) do
            local px, pz = toPx(room.x - room.hx, room.z - room.hz)
            local f = Instance.new("Frame")
            f.Name = "Room_" .. i
            f.Position = UDim2.fromOffset(px, pz)
            f.Size = UDim2.fromOffset(room.hx * 2 * scale, room.hz * 2 * scale)
            f.BackgroundColor3 = CLASS_COLOR[room.class] or CLASS_COLOR.room
            f.BackgroundTransparency = 0.25
            f.BorderSizePixel = 0
            f.Visible = revealed[i] == true
            f.ZIndex = 2
            local stroke = Instance.new("UIStroke")
            stroke.Color = Color3.fromRGB(0, 0, 0)
            stroke.Thickness = 1
            stroke.Parent = f
            f.Parent = mapRoot
            roomFrames[i] = f
        end

        for _, door in ipairs(data.doors) do
            local px, pz = toPx(door.x, door.z)
            local len = math.max(6, 10 * scale)
            local thick = math.max(2, 2.5 * scale)
            local f = Instance.new("Frame")
            f.Name = "Door"
            f.AnchorPoint = Vector2.new(0.5, 0.5)
            f.Position = UDim2.fromOffset(px, pz)
            if door.ax == "z" then
                f.Size = UDim2.fromOffset(thick, len)
            else
                f.Size = UDim2.fromOffset(len, thick)
            end
            f.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            f.BorderSizePixel = 0
            f.ZIndex = 3
            f.Visible = false
            f.Parent = mapRoot
            table.insert(doorFrames, f)
            f:SetAttribute("RoomA", door.a)
            f:SetAttribute("RoomB", door.b)
        end
    end

    local function revealRoom(i)
        if revealed[i] then
            return
        end
        revealed[i] = true
        if roomFrames[i] then
            roomFrames[i].Visible = true
        end
        for _, f in ipairs(doorFrames) do
            if f:GetAttribute("RoomA") == i or f:GetAttribute("RoomB") == i then
                f.Visible = true
            end
        end
    end

    -- directional pointer, not a dot (Jason: orient which way you're FACING);
    -- ▲ at Rotation 0 = north (-Z), rotated to the character's heading
    local function markerFor(who)
        local m = markers[who]
        if not m then
            local isMe = who == player
            m = Instance.new("TextLabel")
            m.Name = "Marker_" .. who.Name
            m.AnchorPoint = Vector2.new(0.5, 0.5)
            m.Size = UDim2.fromOffset(isMe and 16 or 12, isMe and 16 or 12)
            m.BackgroundTransparency = 1
            m.Font = Enum.Font.GothamBlack
            m.Text = "▲"
            m.TextScaled = true
            m.TextColor3 = isMe and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(90, 220, 255)
            m.ZIndex = 5
            local stroke = Instance.new("UIStroke")
            stroke.Color = Color3.fromRGB(0, 0, 0)
            stroke.Thickness = 1.5
            stroke.Parent = m
            m.Parent = mapRoot
            markers[who] = m
        end
        return m
    end

    -- ---- data binding -------------------------------------------------------
    local function applyData()
        local raw = player:GetAttribute("MissionMapData")
        if type(raw) == "string" and raw ~= "" then
            local ok, decoded = pcall(function()
                return HttpService:JSONDecode(raw)
            end)
            data = ok and decoded or nil
        else
            data = nil
        end
        if data then
            title.Text = "MAP — " .. tostring(data.name or "Mission")
            panel.Visible = true
            rebuild()
            -- entrance is known from the start
            for i, room in ipairs(data.rooms) do
                if room.class == "entrance" then
                    revealRoom(i)
                end
            end
        else
            clearMap()
            panel.Visible = false
        end
    end

    -- CoH straggler pings: with ≤3 enemies left the server publishes their
    -- world positions (MissionEnemyPings JSON); draw pulsing red dots even in
    -- unexplored territory — hunting the last crow in the dark isn't gameplay
    local pingFrames = {}
    local function updatePings()
        for _, frame in ipairs(pingFrames) do
            frame:Destroy()
        end
        pingFrames = {}
        local raw = player:GetAttribute("MissionEnemyPings")
        if not (data and type(raw) == "string" and raw ~= "") then
            return
        end
        local ok, list = pcall(function()
            return HttpService:JSONDecode(raw)
        end)
        if not ok or type(list) ~= "table" then
            return
        end
        local toPx = projector()
        for _, ping in ipairs(list) do
            local px, pz = toPx(ping.x - data.ox, ping.z - data.oz)
            local dot = Instance.new("Frame")
            dot.Name = "EnemyPing"
            dot.AnchorPoint = Vector2.new(0.5, 0.5)
            dot.Position = UDim2.fromOffset(px, pz)
            dot.Size = UDim2.fromOffset(9, 9)
            dot.BackgroundColor3 = Color3.fromRGB(255, 70, 60)
            dot.ZIndex = 6
            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(1, 0)
            corner.Parent = dot
            local stroke = Instance.new("UIStroke")
            stroke.Color = Color3.fromRGB(0, 0, 0)
            stroke.Thickness = 1
            stroke.Parent = dot
            dot.Parent = mapRoot
            table.insert(pingFrames, dot)
        end
    end
    player:GetAttributeChangedSignal("MissionEnemyPings"):Connect(updatePings)

    player:GetAttributeChangedSignal("MissionMapData"):Connect(applyData)
    canvas:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        if data then
            local wasRevealed = revealed
            rebuild()
            for i in pairs(wasRevealed) do
                revealed[i] = nil -- re-run reveal so doors re-show too
                revealRoom(i)
            end
        end
    end)
    applyData()

    -- ---- live update loop ----------------------------------------------------
    task.spawn(function()
        while gui.Parent do
            if data and not minimized then
                local toPx = projector()
                -- everyone standing inside the mission gets a dot; walking
                -- into an unrevealed room reveals it (and its doorways)
                local seen = {}
                for _, p in ipairs(Players:GetPlayers()) do
                    local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
                    if root then
                        local mx = root.Position.X - data.ox
                        local mz = root.Position.Z - data.oz
                        local b = data.bbox
                        if
                            mx >= b.minx - 5
                            and mx <= b.maxx + 5
                            and mz >= b.minz - 5
                            and mz <= b.maxz + 5
                        then
                            seen[p] = true
                            local px, pz = toPx(mx, mz)
                            local m = markerFor(p)
                            m.Position = UDim2.fromOffset(px, pz)
                            -- map is world-aligned (screen up = -Z), so the
                            -- pointer's rotation is the raw XZ heading
                            local look = root.CFrame.LookVector
                            m.Rotation = math.deg(math.atan2(look.X, -look.Z))
                            for i, room in ipairs(data.rooms) do
                                if
                                    not revealed[i]
                                    and math.abs(mx - room.x) <= room.hx + REVEAL_MARGIN
                                    and math.abs(mz - room.z) <= room.hz + REVEAL_MARGIN
                                then
                                    revealRoom(i)
                                end
                            end
                        end
                    end
                end
                for who, m in pairs(markers) do
                    if not seen[who] then
                        m:Destroy()
                        markers[who] = nil
                    end
                end
                -- objective room lights up once the clear-gate opens
                local active = player:GetAttribute("MissionObjectiveCount") == "★"
                for i, room in ipairs(data.rooms) do
                    if room.class == "objective" and roomFrames[i] then
                        roomFrames[i].BackgroundColor3 = active and OBJECTIVE_ACTIVE
                            or CLASS_COLOR.objective
                    end
                end
            end
            task.wait(0.25)
        end
    end)
end

return MissionMap
