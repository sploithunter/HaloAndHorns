-- Standalone, authored map bake. Never runs in a published game.
-- mise exec -- lune run tools/realm_crossroads/build.luau
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local roblox = require("@lune/roblox")
local cfg = serde.decode("json", fs.readFile("configs/realm_crossroads.json"))
local V, C, E = roblox.Vector3, roblox.CFrame, roblox.Enum
local I = {}
function I.new(className, parent)
    local instance = roblox.Instance.new(className)
    if parent then
        instance.Parent = parent
    end
    return instance
end
local colors = {}
for key, rgb in cfg.palette do
    colors[key] = roblox.Color3.fromRGB(table.unpack(rgb))
end
local game = I.new("DataModel")
local workspace = I.new("Workspace", game)
workspace.Name = "Workspace"
workspace.FallenPartsDestroyHeight = -100
local root = I.new("Model", workspace)
root.Name = cfg.root_name
root:SetAttribute("CrossroadsBlockoutVersion", cfg.version)
root:SetAttribute("PreviewOnly", true)
root:SetAttribute("FootprintX", cfg.footprint[1])
root:SetAttribute("FootprintZ", cfg.footprint[2])
local function group(name)
    local m = I.new("Model", root)
    m.Name = name
    return m
end
local function part(parent, name, size, cf, color, material, collide)
    local p = I.new("Part", parent)
    p.Name, p.Size, p.CFrame = name, V.new(table.unpack(size)), cf
    p.Anchored, p.CanCollide = true, collide ~= false
    p.TopSurface, p.BottomSurface = E.SurfaceType.Smooth, E.SurfaceType.Smooth
    p.Color = colors[color]
    p.Material = E.Material[material or "SmoothPlastic"]
    return p
end
local function label(parent, name, text, size, cf)
    local p = part(parent, name, size, cf, "board")
    local gui = I.new("SurfaceGui", p)
    gui.Face, gui.CanvasSize = E.NormalId.Back, roblox.Vector2.new(1000, 220)
    gui.LightInfluence = 0
    local t = I.new("TextLabel", gui)
    t.Size = roblox.UDim2.fromScale(1, 1)
    t.BackgroundTransparency, t.TextScaled = 1, true
    t.TextColor3, t.Text = colors.trim, text
    return p
end
local function ring(parent, name, center, radius, thickness, height, color, segments)
    for n = 1, segments do
        local angle = (n - 1) * math.pi * 2 / segments
        local cf = C.new(center) * C.Angles(0, angle, 0) * C.new(0, 0, radius)
        part(
            parent,
            name .. n,
            { 2 * radius * math.tan(math.pi / segments) + 0.1, height, thickness },
            cf,
            color
        )
    end
end
local function path(parent, name, a, b)
    local mid = (a + b) / 2
    local length = (a - b).Magnitude
    part(
        parent,
        name,
        { cfg.paths.width, cfg.paths.thickness, length },
        C.lookAt(mid, b),
        "trim",
        "Limestone"
    )
end
local terrain = group("VoxelTerrain")
local cell = cfg.terrain.cell
for x = -cfg.footprint[1] / 2 + cell / 2, cfg.footprint[1] / 2 - cell / 2, cell do
    for z = -cfg.footprint[2] / 2 + cell / 2, cfg.footprint[2] / 2 - cell / 2, cell do
        local edge = math.abs(x) > cfg.footprint[1] / 2 - cell * 1.5
        local back = z < -cfg.footprint[2] / 2 + cell
        local h = if back then cfg.terrain.back_height elseif edge then cfg.terrain.rim_height else 0
        local depth = cfg.terrain.base_depth + h
        part(
            terrain,
            "Rock",
            { cell, depth, cell },
            C.new(x, h - depth / 2 - 0.8, z),
            "rock",
            "Slate"
        )
        part(terrain, "GrassCap", { cell, 0.8, cell }, C.new(x, h - 0.4, z), "grass", "Grass")
    end
end
local court = group("ChoiceCourt")
part(court, "LevelCourt", { 172, 0.2, 180 }, C.new(0, 0, 0), "stone", "Limestone")
local spawnPos = V.new(table.unpack(cfg.spawn))
local spawn = I.new("SpawnLocation", court)
spawn.Name, spawn.Size, spawn.CFrame = "PreviewSpawn", V.new(12, 0.4, 12), C.new(spawnPos)
spawn.Anchored, spawn.Neutral, spawn.Duration = true, true, 0
spawn.Material, spawn.Color = E.Material.Limestone, colors.trim
spawn:SetAttribute("IntendedAreaId", "RealmCrossroads")
ring(
    court,
    "SpawnRing",
    V.new(spawnPos.X, 0.4, spawnPos.Z),
    cfg.spawn_disk.radius,
    0.6,
    0.3,
    "gold",
    cfg.spawn_disk.segments
)
local gates = group("ModeEntrances")
for _, gate in cfg.gates do
    local g = I.new("Model", gates)
    g.Name = gate.key
    g:SetAttribute("ModeKey", gate.key)
    g:SetAttribute("RoutingEnabled", false)
    local pos = V.new(table.unpack(gate.position))
    local base = C.new(pos) * C.Angles(0, math.rad(gate.yaw), 0)
    local s = cfg.gate_geometry
    local width = s.opening_width + s.pillar_width * 2
    part(
        g,
        "Landing",
        { width + 8, 0.4, s.landing_depth },
        base * C.new(0, 0.3, 0),
        "trim",
        "Limestone"
    )
    for _, side in { -1, 1 } do
        local x = side * (s.opening_width + s.pillar_width) / 2
        part(
            g,
            "Pillar",
            { s.pillar_width, s.opening_height, s.depth },
            base * C.new(x, s.opening_height / 2, 0),
            "stone",
            "Limestone"
        )
        part(
            g,
            "Plinth",
            { s.pillar_width + 2, 2, s.depth + 2 },
            base * C.new(x, 1, 0),
            "trim",
            "Limestone"
        )
        part(
            g,
            "Capital",
            { s.pillar_width + 2, 2, s.depth + 2 },
            base * C.new(x, s.opening_height, 0),
            "gold"
        )
    end
    label(
        g,
        "ModeSign",
        gate.label,
        { width, s.sign_height, 1 },
        base * C.new(0, s.opening_height + s.sign_height / 2, s.depth / 2)
    )
    label(
        g,
        "Description",
        gate.subtitle,
        { width, 2, 0.5 },
        base * C.new(0, s.opening_height - 1, s.depth / 2 + 0.1)
    )
    part(
        g,
        "Lintel",
        { width + 2, 2, s.depth + 2 },
        base * C.new(0, s.opening_height + s.sign_height + 1, 0),
        "trim",
        "Limestone"
    )
    local pane = part(
        g,
        "PreviewPortal",
        { s.opening_width, s.opening_height - 2, 0.3 },
        base * C.new(0, s.opening_height / 2, 0),
        gate.color,
        "Neon",
        false
    )
    pane.Transparency = 0.7
    label(
        g,
        "PreviewNotice",
        "MODE ENTRANCE · PREVIEW",
        { s.opening_width, 1.7, 0.2 },
        base * C.new(0, 2, 0.4)
    )
    local marker =
        part(g, "ArrivalMarker", { 2, 0.2, 2 }, base * C.new(0, 0.8, 6), gate.color, "Neon", false)
    marker:SetAttribute("IntendedDestination", gate.key)
    local art = cfg.avatars[gate.avatar]
    local mesh = I.new("MeshPart", g)
    mesh.Name, mesh.MeshId, mesh.TextureID = gate.avatar, art.mesh, art.texture
    local rot = C.new(0, 0, 0, table.unpack(art.rotation))
    local raw = V.new(table.unpack(art.size))
    local boundsY = math.abs(rot.XVector.Y) * raw.X
        + math.abs(rot.YVector.Y) * raw.Y
        + math.abs(rot.ZVector.Y) * raw.Z
    mesh.Size = raw * (s.avatar_height / boundsY)
    mesh.CFrame = base
        * C.new(0, s.opening_height + s.sign_height + 2 + s.avatar_height / 2, 0)
        * rot
    mesh.Anchored, mesh.CanCollide, mesh.CanTouch = true, false, false
    mesh.Color = roblox.Color3.fromRGB(table.unpack(art.color))
    path(
        court,
        "SpawnTo" .. gate.key,
        V.new(spawnPos.X, 0.25, spawnPos.Z),
        V.new(pos.X, 0.25, pos.Z)
    )
end
local l = cfg.landmark
local landmark = group("ConvergenceLandmark")
local lp = V.new(table.unpack(l.position))
part(
    landmark,
    "Basin",
    { l.radius * 2, 1, l.radius * 2 },
    C.new(lp + V.new(0, 0.5, 0)),
    "water",
    "Glass",
    false
)
ring(landmark, "BasinEdge", lp + V.new(0, 0.8, 0), l.radius, 1, 1.6, "trim", l.segments)
part(
    landmark,
    "Pedestal",
    { 6, l.height, 6 },
    C.new(lp + V.new(0, l.height / 2, 0)),
    "stone",
    "Limestone"
)
ring(landmark, "Halo", lp + V.new(0, l.height + 4, 0), l.halo_radius, 0.6, 0.6, "gold", l.segments)
for _, side in { -1, 1 } do
    part(
        landmark,
        "Horn",
        { 2, 8, 2 },
        C.new(lp + V.new(side * 4, l.height, 0)) * C.Angles(0, 0, math.rad(side * -24)),
        if side == 1 then "ember" else "trim"
    )
end
for _, side in { -1, 1 } do
    path(court, "GalleryApproach", V.new(side * 30, 0.25, 36), V.new(side * 30, 0.25, -64))
end
local hall = group("ChampionsGallery")
local h = cfg.gallery
part(hall, "GalleryFloor", { h.width, 0.4, h.depth }, C.new(0, 0.3, h.z), "trim", "Limestone")
part(
    hall,
    "GalleryBack",
    { h.width, h.height, 2 },
    C.new(0, h.height / 2, h.z - h.depth / 2),
    "stone",
    "Limestone"
)
part(
    hall,
    "GalleryRoof",
    { h.width + 4, 2, h.depth + 4 },
    C.new(0, h.height, h.z),
    "trim",
    "Limestone"
)
label(
    hall,
    "GallerySign",
    "CHAMPIONS",
    { 64, 6, 1 },
    C.new(0, h.height + 2, h.z + h.depth / 2 + 0.2)
)
for n, x in h.alcove_centers do
    local alcove = I.new("Model", hall)
    alcove.Name = "Alcove" .. n
    alcove:SetAttribute("RankingCategory", "Unassigned")
    label(
        alcove,
        "RankingBoard",
        h.labels[n] .. "\nRANKING PREVIEW",
        { 34, 10, 1 },
        C.new(x, 20, h.z - h.depth / 2 + 1.1)
    )
    for k, rank in h.podium_ranks do
        local px, height = x + (k - 2) * h.podium_spacing, h.podium_heights[k]
        part(alcove, "Rank" .. rank, { 8, height, 8 }, C.new(px, height / 2 + 0.5, h.z), "gold")
        label(alcove, "RankLabel", tostring(rank), { 5, 2, 0.2 }, C.new(px, 1.6, h.z + 4.2))
        local y = height + 0.5
        part(alcove, "FigureBody", { 2.5, 3, 1.4 }, C.new(px, y + 3, h.z), "stone")
        part(alcove, "FigureHead", { 2, 2, 2 }, C.new(px, y + 5.5, h.z), "trim")
        for _, side in { -1, 1 } do
            part(alcove, "FigureLeg", { 1, 2, 1.4 }, C.new(px + side * 0.7, y + 1, h.z), "board")
            part(alcove, "FigureArm", { 1, 3, 1.4 }, C.new(px + side * 1.8, y + 3, h.z), "trim")
        end
    end
end
for x = -h.width / 2, h.width / 2, h.width / 4 do
    part(
        hall,
        "Column",
        { 3, h.height, 3 },
        C.new(x, h.height / 2, h.z + h.depth / 2),
        "stone",
        "Limestone"
    )
end
local gardens = group("ExpansionGardens")
for _, garden in cfg.gardens do
    local pos = V.new(table.unpack(garden.position))
    part(
        gardens,
        "ReservedGarden",
        { 23, 0.5, 26 },
        C.new(pos + V.new(0, 0.4, 0)),
        "grass",
        "Grass"
    )
    label(gardens, "FutureRealm", garden.label, { 18, 3, 1 }, C.new(pos + V.new(0, 3, -10)))
    part(gardens, "Bench", { 12, 2, 3 }, C.new(pos + V.new(0, 1, 5)), "bark", "Wood")
end
local trees = group("Trees")
local t = cfg.tree_geometry
for _, xyz in cfg.trees do
    local p = V.new(table.unpack(xyz))
    part(
        trees,
        "Trunk",
        { t.trunk_width, t.trunk_height, t.trunk_width },
        C.new(p + V.new(0, t.trunk_height / 2, 0)),
        "bark",
        "Wood"
    )
    part(
        trees,
        "Crown",
        { t.crown_width, t.crown_height, t.crown_width },
        C.new(p + V.new(0, t.trunk_height + t.crown_height / 2, 0)),
        "leaves",
        "Grass",
        false
    )
end
local lighting = I.new("Lighting", game)
lighting.ClockTime, lighting.Brightness = cfg.lighting.clock_time, cfg.lighting.brightness
lighting.Ambient = roblox.Color3.fromRGB(table.unpack(cfg.lighting.ambient))
lighting.OutdoorAmbient = roblox.Color3.fromRGB(table.unpack(cfg.lighting.outdoor_ambient))
lighting.GlobalShadows = true
local starter = I.new("StarterPlayer", game)
starter.CharacterWalkSpeed = cfg.walk_speed
local sss = I.new("ServerScriptService", game)
local server = I.new("Script", sss)
server.Name = "PreviewReset"
server.Source = [[
local Players = game:GetService("Players")
local event = Instance.new("RemoteEvent", game:GetService("ReplicatedStorage"))
event.Name = "CrossroadsPreviewReset"
event.OnServerEvent:Connect(function(player)
    local spawn = workspace.RealmCrossroads.ChoiceCourt.PreviewSpawn
    if player.Character then player.Character:PivotTo(spawn.CFrame + Vector3.new(0, 4, 0)) end
end)
]]
local guiRoot = I.new("StarterGui", game)
local gui = I.new("ScreenGui", guiRoot)
gui.Name, gui.ResetOnSpawn = "CrossroadsPreview", false
local notice = I.new("TextLabel", gui)
notice.Size, notice.Position = roblox.UDim2.new(1, -24, 0, 48), roblox.UDim2.fromOffset(12, 8)
notice.Text, notice.TextSize = cfg.preview.notice, 16
notice.BackgroundTransparency, notice.TextColor3 = 0.2, colors.white
notice.BackgroundColor3 = colors.board
local button = I.new("TextButton", gui)
button.Size, button.Position = roblox.UDim2.fromOffset(160, 44), roblox.UDim2.new(1, -172, 1, -60)
button.Text, button.TextSize = cfg.preview.reset_label, 16
button.BackgroundColor3, button.TextColor3 = colors.board, colors.white
local client = I.new("LocalScript", button)
client.Source = [[script.Parent.Activated:Connect(function()
    game:GetService("ReplicatedStorage"):WaitForChild("CrossroadsPreviewReset"):FireServer()
end)]]
local camera = I.new("Camera", workspace)
camera.CFrame = C.lookAt(
    V.new(table.unpack(cfg.preview.camera_position)),
    V.new(table.unpack(cfg.preview.camera_target))
)
camera.Focus = C.new(V.new(table.unpack(cfg.preview.camera_target)))
workspace.CurrentCamera = camera
fs.writeDir("output/realm_crossroads")
assert(#root:GetDescendants() > 100, "Map bake produced incomplete geometry")
fs.writeFile("output/realm_crossroads/RealmCrossroads-Preview.rbxl", roblox.serializePlace(game))
-- Export a spawn-neutral model; integration must deliberately bind the real spawn/routing.
spawn.Enabled = false
fs.writeFile("output/realm_crossroads/RealmCrossroads.rbxm", roblox.serializeModel({ root }))
print(
    "Built standalone preview and spawn-neutral import model; "
        .. #root:GetDescendants()
        .. " map instances"
)
