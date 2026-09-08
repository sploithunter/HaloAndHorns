-- Offline authoring only: require this module in an isolated local Studio place, in Edit.
-- Never call in gameplay. The baked Terrain, meshes, and markers belong to the place file.
return function()
    local function newInstance(className, parent)
        local instance = Instance.new(className)
        if parent then
            instance.Parent = parent
        end
        return instance
    end
    assert(not game:GetService("RunService"):IsRunning(), "R4 terrain bake requires Edit mode")
    assert(game.PlaceId == 0, "R4 preview bake refuses a published place")
    assert(
        not workspace:FindFirstChild("RealmCrossroadsR4"),
        "R4 already baked; preserve this revision"
    )
    local cfg = game:GetService("HttpService")
        :JSONDecode(game.ServerStorage.CrossroadsTerrainConfig.Value)
    local V, C = Vector3, CFrame
    local colors = {}
    for name, rgb in pairs(cfg.palette) do
        colors[name] = Color3.fromRGB(unpack(rgb))
    end
    local function between(v, a, b)
        return v >= math.min(a, b) and v <= math.max(a, b)
    end
    local function heightAt(x, z)
        local v = cfg.voxel
        local ax, az = math.abs(x), math.abs(z)
        if
            ax > v.island_half[1]
            or az > v.island_half[2]
            or ax + az > v.island_half[1] + v.island_half[2] - v.corner_cut
        then
            return nil
        end
        local h = cfg.levels.court
        local side = cfg.side_terrace
        if ax >= side.inner and between(z, side.z_min, side.z_max) then
            h = cfg.levels.gardens
        end
        if ax >= side.outer then
            h = cfg.levels.gardens
                + (cfg.levels.rim - cfg.levels.gardens)
                    * math.clamp((ax - side.outer) / (side.slope_end - side.outer), 0, 1)
        end
        local g = cfg.gallery_terrace
        if ax <= g.half_width and z <= g.front then
            h = cfg.levels.gallery
        end
        if z < g.back then
            h = cfg.levels.gallery
                + (cfg.levels.rim - cfg.levels.gallery)
                    * math.clamp((g.back - z) / (g.back - g.slope_end), 0, 1)
        end
        local o = cfg.overlook
        if ax <= o.half_width and between(z, o.back, o.front) then
            h = cfg.levels.overlook
        end
        for _, t in ipairs(cfg.transitions) do
            local along = t.axis == "x" and x or z
            local across = t.axis == "x" and z or x
            if between(along, t.start, t.finish) and between(across, t.cross_min, t.cross_max) then
                h = t.from + (t.to - t.from) * (along - t.start) / (t.finish - t.start)
            end
        end
        return h
    end
    game:GetService("ChangeHistoryService"):SetWaypoint("Before Crossroads R4 terrain bake")
    local root = newInstance("Model", workspace)
    root.Name = cfg.root
    root:SetAttribute("TerrainRevision", cfg.revision)
    root:SetAttribute("PreviewOnly", true)
    local function group(name)
        local g = newInstance("Model", root)
        g.Name = name
        return g
    end
    local function part(parent, name, size, cf, color, mat, collide)
        local p = newInstance("Part")
        p.Name = name
        p.Size = V.new(unpack(size))
        p.CFrame = cf
        p.Anchored = true
        p.CanCollide = collide ~= false
        p.TopSurface = Enum.SurfaceType.Smooth
        p.BottomSurface = Enum.SurfaceType.Smooth
        p.Color = colors[color]
        p.Material = Enum.Material[mat or "SmoothPlastic"]
        p.Parent = parent
        return p
    end
    local function label(parent, name, text, size, cf)
        local p = part(parent, name, size, cf, "board", nil, false)
        local s = newInstance("SurfaceGui", p)
        s.Face = Enum.NormalId.Back
        s.CanvasSize = Vector2.new(1000, 240)
        s.LightInfluence = 0
        local l = newInstance("TextLabel", s)
        l.Size = UDim2.fromScale(1, 1)
        l.BackgroundTransparency = 1
        l.TextScaled = true
        l.TextColor3 = colors.trim
        l.Font = Enum.Font.GothamBold
        l.Text = text
        return p
    end
    -- Real Terrain occupies all tiers. Surface occupancy follows the same grading function
    -- used to build the architectural stairs/ramps, including below every raised landing.
    local terrain = workspace.Terrain
    local v = cfg.voxel
    local res = v.resolution
    local lo, hi = V.new(unpack(v.region_min)), V.new(unpack(v.region_max))
    local region = Region3.new(lo, hi):ExpandToGrid(res)
    local dims = (hi - lo) / res
    local mats, occ = {}, {}
    local solid = 0
    for ix = 1, dims.X do
        mats[ix] = {}
        occ[ix] = {}
        local x = lo.X + (ix - 0.5) * res
        for iy = 1, dims.Y do
            mats[ix][iy] = {}
            occ[ix][iy] = {}
        end
        for iz = 1, dims.Z do
            local z = lo.Z + (iz - 0.5) * res
            local h = heightAt(x, z)
            for iy = 1, dims.Y do
                local bottom = lo.Y + (iy - 1) * res
                -- Roblox reconstructs the surface from voxel centers. Subtract half a cell
                -- so a design Y=0 terrace raycasts at Y=0 instead of burying the paths at +2.
                local amount = h and math.clamp((h - res / 2 - bottom) / res, 0, 1) or 0
                if bottom < v.bottom then
                    amount = 0
                end
                local m = Enum.Material.Air
                if amount > 0 then
                    solid += 1
                    m = bottom + res >= h - v.soil_depth and Enum.Material.Grass
                        or Enum.Material.Rock
                    if
                        math.abs(x) >= cfg.side_terrace.slope_end
                        or z <= cfg.gallery_terrace.slope_end
                    then
                        m = Enum.Material.Rock
                    end
                end
                mats[ix][iy][iz] = m
                occ[ix][iy][iz] = amount
            end
        end
    end
    terrain:WriteVoxels(region, res, mats, occ)
    terrain:SetMaterialColor(Enum.Material.Grass, colors.grass)
    terrain:SetMaterialColor(Enum.Material.Rock, colors.rock)
    local stairs = group("GradedStairsAndRamps")
    for _, t in ipairs(cfg.transitions) do
        local width = t.cross_max - t.cross_min
        local cross = (t.cross_min + t.cross_max) / 2
        if t.kind == "stairs" then
            local run = (t.finish - t.start) / t.steps
            for n = 1, t.steps do
                local along = t.start + (n - 0.5) * run
                local level = t.from + (t.to - t.from) * (t.to > t.from and n or n - 1) / t.steps
                local bottom = math.min(t.from, t.to) - 1
                local size = t.axis == "x" and { math.abs(run), level - bottom, width }
                    or { width, level - bottom, math.abs(run) }
                local x = t.axis == "x" and along or cross
                local z = t.axis == "x" and cross or along
                part(
                    stairs,
                    t.name .. "_" .. n,
                    size,
                    C.new(x, (level + bottom) / 2 + cfg.paths.surface_offset, z),
                    "trim",
                    "Limestone"
                )
            end
        else
            local a = t.axis == "x" and V.new(t.start, t.from, cross)
                or V.new(cross, t.from, t.start)
            local b = t.axis == "x" and V.new(t.finish, t.to, cross) or V.new(cross, t.to, t.finish)
            part(
                stairs,
                t.name,
                { width, cfg.paths.thickness, (b - a).Magnitude },
                C.lookAt(
                    (a + b) / 2 + V.new(0, cfg.paths.surface_offset, 0),
                    b + V.new(0, cfg.paths.surface_offset, 0)
                ),
                "stone",
                "Limestone"
            )
        end
    end
    local walls = group("RetainingWalls")
    local rs = cfg.retaining_segments
    for _, sign in ipairs({ -1, 1 }) do
        for _, range in ipairs(rs.side_z) do
            local z = (range[1] + range[2]) / 2
            local len = range[2] - range[1]
            part(
                walls,
                "GardenRetain",
                { rs.thickness, 4, len },
                C.new(sign * cfg.side_terrace.inner, 2, z),
                "stone",
                "Limestone"
            )
            part(
                walls,
                "GardenCap",
                { rs.cap_width, 0.4, len },
                C.new(sign * cfg.side_terrace.inner, 4, z),
                "trim",
                "Limestone"
            )
        end
    end
    for _, range in ipairs(rs.gallery_x) do
        local x = (range[1] + range[2]) / 2
        local len = range[2] - range[1]
        part(
            walls,
            "GalleryRetain",
            { len, 4, rs.thickness },
            C.new(x, 2, cfg.gallery_terrace.front),
            "stone",
            "Limestone"
        )
        part(
            walls,
            "GalleryCap",
            { len, 0.4, rs.cap_width },
            C.new(x, 4, cfg.gallery_terrace.front),
            "trim",
            "Limestone"
        )
    end
    for _, range in ipairs(rs.overlook_x) do
        local x = (range[1] + range[2]) / 2
        part(
            walls,
            "OverlookRetain",
            { range[2] - range[1], 4, rs.thickness },
            C.new(x, -2, cfg.overlook.back),
            "stone",
            "Limestone"
        )
    end
    local paths = group("PathsAndLandings")
    local function path(name, a, b, width)
        local offset = V.new(0, cfg.paths.surface_offset, 0)
        part(
            paths,
            name,
            { width or cfg.paths.width, cfg.paths.thickness, (b - a).Magnitude },
            C.lookAt((a + b) / 2 + offset, b + offset),
            "stone",
            "Limestone"
        )
    end
    local layout = cfg.study.layout_proposal
    local spawnAt = V.new(layout.spawn[1], 0, layout.spawn[2])
    local spawn = newInstance("SpawnLocation", paths)
    spawn.Name = "PreviewSpawn"
    spawn.Size = V.new(12, 0.4, 12)
    spawn.CFrame = C.new(spawnAt + V.new(0, 0.3, 0))
    spawn.Anchored = true
    spawn.Neutral = true
    spawn.Duration = 0
    spawn.Material = Enum.Material.Limestone
    spawn.Color = colors.trim
    for n, g in ipairs(layout.gates) do
        local at = V.new(g[1], 0, g[2])
        path("ModeApproach" .. n, spawnAt, at)
        path(
            "GalleryWalk" .. n,
            V.new(g[1], 0, g[2]),
            V.new(n == 1 and -cfg.paths.gallery_lane_x or cfg.paths.gallery_lane_x, 0, -72)
        )
    end
    for _, sign in ipairs({ -1, 1 }) do
        path("GardenConnection", V.new(sign * 28, 0, -18), V.new(sign * 64, 0, -18), 24)
        path("GardenRampConnection", V.new(sign * 20, 0, 80), V.new(sign * 48, 0, 80), 16)
        path("GalleryRampConnection", V.new(sign * 28, 0, -56), V.new(sign * 72, 0, -56), 16)
        path("GalleryRampTop", V.new(sign * 72, 4, -90), V.new(sign * 56, 4, -90), 18)
    end
    part(paths, "GalleryLanding", { 192, 0.4, 44 }, C.new(0, 4.22, -110), "stone", "Limestone")
    part(paths, "OverlookLanding", { 128, 0.4, 16 }, C.new(0, -3.78, 144), "stone", "Limestone")
    path("OverlookApproach", spawnAt, V.new(0, 0, 120), 32)
    local rail = group("OverlookRail")
    for x = -60, 60, 12 do
        part(rail, "Post", { 1, 3, 1 }, C.new(x, -2.1, 151), "stone", "Limestone")
    end
    part(rail, "TopRail", { 124, 0.6, 1 }, C.new(0, -0.8, 151), "trim", "Limestone")
    local gates = group("ExistingMergeArches")
    for n, g in ipairs(layout.gates) do
        local source = cfg.study.candidates[n]
        local name = n == 1 and "FarmAndFight" or "Merge"
        local model = newInstance("Model", gates)
        model.Name = name
        local size = V.new(unpack(source.size)) * cfg.gate.scale
        local base = C.new(g[1], 0, g[2]) * C.Angles(0, math.rad(layout.gate_yaw[n]), 0)
        local mesh = game:GetService("AssetService"):CreateMeshPartAsync(
            source.mesh,
            { CollisionFidelity = Enum.CollisionFidelity.Default }
        )
        mesh.Name = "Arch"
        mesh.Size = size
        mesh.CFrame = base * C.new(0, size.Y / 2, 0)
        mesh.Anchored = true
        local surf = newInstance("SurfaceAppearance", mesh)
        surf.ColorMap = source.surface.color
        surf.NormalMap = source.surface.normal
        surf.RoughnessMap = source.surface.rough
        surf.MetalnessMap = source.surface.metal
        mesh.Parent = model
        part(
            paths,
            name .. "Landing",
            { cfg.gate.landing_width, 0.4, cfg.gate.landing_depth },
            base * C.new(0, 0.22, 0),
            "trim",
            "Limestone"
        )
        label(
            model,
            "ModeSign",
            n == 1 and "FARM & FIGHT" or "MERGE",
            { 24, 3, 0.5 },
            base * C.new(0, 17, 7)
        )
        local f = cfg.faces[n == 1 and "angel" or "demon"]
        local face =
            game:GetService("AssetService")
                :CreateMeshPartAsync(f.mesh, { CollisionFidelity = Enum.CollisionFidelity.Box })
        local rot = C.new(0, 0, 0, unpack(f.rotation))
        local raw = V.new(unpack(f.size))
        local height = math.abs(rot.XVector.Y) * raw.X
            + math.abs(rot.YVector.Y) * raw.Y
            + math.abs(rot.ZVector.Y) * raw.Z
        face.Name = "Face"
        face.Size = raw * (cfg.gate.face_height / height)
        face.TextureID = f.texture
        face.CFrame = base
            * C.new(0, cfg.gate.face_y, 0)
            * C.Angles(0, math.rad(f.facing_yaw), 0)
            * rot
        face.Anchored = true
        face.CanCollide = false
        face.CanTouch = false
        face.Parent = model
        model:SetAttribute("TravelEnabled", false)
    end
    local hall = group("GalleryMassing")
    local gh = cfg.gallery
    local floor = cfg.levels.gallery
    part(
        hall,
        "RearWall",
        { gh.width, gh.height, 2 },
        C.new(0, floor + gh.height / 2, gh.center[2] - gh.depth / 2),
        "stone",
        "Limestone"
    )
    part(
        hall,
        "Roof",
        { gh.width + 4, 2, gh.depth + 4 },
        C.new(0, floor + gh.height, gh.center[2]),
        "trim",
        "Limestone"
    )
    for _, x in ipairs(gh.column_x) do
        part(
            hall,
            "Column",
            { 2, gh.height, 2 },
            C.new(x, floor + gh.height / 2, gh.center[2] + gh.depth / 2 + 1),
            "stone",
            "Limestone"
        )
    end
    for _, x in ipairs(gh.alcove_centers) do
        for k, rank in ipairs(gh.ranks) do
            local h = gh.podium_heights[k]
            local px = x + (k - 2) * gh.podium_spacing
            part(
                hall,
                "Podium" .. rank,
                { 6, h, 6 },
                C.new(px, floor + h / 2, gh.center[2]),
                "gold"
            )
            label(
                hall,
                "Rank",
                tostring(rank),
                { 4, 1, 0.2 },
                C.new(px, floor + 0.7, gh.center[2] + 3.2)
            )
        end
    end
    label(
        hall,
        "Title",
        "CHAMPIONS / +4 TERRACE",
        { 62, 4, 1 },
        C.new(0, floor + gh.height + 1, gh.center[2] + gh.depth / 2 + 1)
    )
    local landmark = group("LandmarkEnvelope")
    local l = cfg.landmark
    for n = 1, l.segments do
        local a = n * math.pi * 2 / l.segments
        part(
            landmark,
            "Ring",
            { 2 * l.radius * math.tan(math.pi / l.segments), 0.35, 0.7 },
            C.new(0, 0.3, 0) * C.Angles(0, a, 0) * C.new(0, 0, l.radius),
            "gold",
            nil,
            false
        )
    end
    part(
        landmark,
        "HeightReference",
        { 3, l.height, 3 },
        C.new(0, l.height / 2, 0),
        "trim",
        "Limestone"
    )
    local markers = group("ElevationMarkers")
    for _, m in ipairs(cfg.markers) do
        local p = V.new(unpack(m.position))
        local marker =
            part(markers, m.name, { 2, 0.2, 2 }, C.new(p + V.new(0, 0.5, 0)), "gold", nil, false)
        marker:SetAttribute("DesignElevation", p.Y)
        if m.name ~= "Spawn" then
            label(
                markers,
                m.name .. "Label",
                m.name .. " / " .. string.format("%+d", p.Y),
                { 16, 2, 0.3 },
                C.new(p + V.new(0, 3, 0))
            )
        end
    end
    local light = game:GetService("Lighting")
    light.ClockTime = cfg.lighting.clock_time
    light.Brightness = cfg.lighting.brightness
    light.Ambient = Color3.fromRGB(unpack(cfg.lighting.ambient))
    light.OutdoorAmbient = light.Ambient
    game.StarterPlayer.CharacterWalkSpeed = cfg.walk_speed
    local preview = newInstance("ScreenGui", game.StarterGui)
    preview.Name = "CrossroadsTerrainPreview"
    preview.ResetOnSpawn = false
    local info = newInstance("TextLabel", preview)
    info.Size = UDim2.new(1, -32, 0, 44)
    info.Position = UDim2.fromOffset(16, 8)
    info.BackgroundColor3 = colors.board
    info.BackgroundTransparency = 0.15
    info.TextColor3 = colors.trim
    info.TextSize = 16
    info.Text = cfg.preview_title .. " / " .. cfg.walk_speed .. " STUDS/SEC\n" .. cfg.preview_note
    -- Preview-only scripts are restricted to the standalone place. They never build geometry.
    local configCopy = newInstance("StringValue", game.ReplicatedStorage)
    configCopy.Name = "CrossroadsPreviewConfig"
    configCopy.Value = game.ServerStorage.CrossroadsTerrainConfig.Value
    local client = newInstance("LocalScript", preview)
    client.Name = "LocalApproachLighting"
    client.Source = [[
local cfg=game:GetService("HttpService"):JSONDecode(game.ReplicatedStorage.CrossroadsPreviewConfig.Value)
local player=game.Players.LocalPlayer
local light=game:GetService("Lighting")
local effect=Instance.new("ColorCorrectionEffect",light);effect.Name="CrossroadsPreviewTint"
local current=0
local function configure(character) character:WaitForChild("Humanoid").WalkSpeed=cfg.walk_speed end
player.CharacterAdded:Connect(configure);if player.Character then configure(player.Character) end
game:GetService("RunService").RenderStepped:Connect(function(dt)
    local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    local target=0
    if root then
        local layout=cfg.study.layout_proposal
        for i,g in ipairs(layout.gates) do
            local distance=(Vector2.new(root.Position.X,root.Position.Z)-Vector2.new(g[1],g[2])).Magnitude
            local t=math.clamp((layout.gate_outer_lighting_radius-distance)/(layout.gate_outer_lighting_radius-layout.gate_full_lighting_radius),0,1)
            if root.Position.Y > 20 or root.Position.Y < -8 then t=0 end
            if t>0 then target=t*t*(3-2*t)*(i==1 and 1 or -1) end
        end
    end
    current+=(target-current)*(1-math.exp(-dt/cfg.lighting.smoothing_seconds))
    local t=math.abs(current)
    local rgb=current>=0 and cfg.lighting.heaven_tint or cfg.lighting.hell_tint
    effect.TintColor=Color3.new(1,1,1):Lerp(Color3.fromRGB(unpack(rgb)),t)
    effect.Brightness=t*(current>=0 and cfg.lighting.heaven_brightness or cfg.lighting.hell_brightness)
    effect.Contrast=current<0 and t*cfg.lighting.hell_contrast or 0
end)
]]
    local old = workspace:FindFirstChild("RunEditBakeFirst")
    if old then
        old:Destroy()
    end
    workspace.CurrentCamera.CFrame =
        C.lookAt(V.new(unpack(cfg.camera.position)), V.new(unpack(cfg.camera.target)))
    game:GetService("Selection"):Set({ root })
    game:GetService("ChangeHistoryService"):SetWaypoint("Crossroads R4 terrain baked")
    return {
        revision = cfg.revision,
        solidVoxels = solid,
        instances = #root:GetDescendants(),
        walkSpeed = cfg.walk_speed,
        saveRequired = true,
    }
end
