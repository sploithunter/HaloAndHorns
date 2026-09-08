-- Authored preview addition; run after terrain, activities, landscape and paving.
return function(cfg)
    assert(
        game.PlaceId == 0 and not game:GetService("RunService"):IsRunning(),
        "Local Edit preview only"
    )
    local V, C = Vector3, CFrame
    local world = workspace.RealmCrossroadsR4
    assert(not world:FindFirstChild(cfg.root), "Restore the pre-leisure preview before rebaking")
    local root = Instance.new("Model")
    root.Name = cfg.root
    root.Parent = world
    root:SetAttribute("GameplayConnected", false)
    local function group(name)
        local g = Instance.new("Model")
        g.Name = name
        g.Parent = root
        return g
    end
    local colors = {}
    for k, v in pairs(cfg.palette) do
        if k ~= "dummy_colors" then
            colors[k] = Color3.fromRGB(unpack(v))
        end
    end
    local function part(parent, name, size, cf, color, material, class)
        local p = Instance.new(class or "Part")
        p.Name = name
        p.Size = V.new(unpack(size))
        p.CFrame = cf
        p.Anchored = true
        p.Color = colors[color]
        p.Material = Enum.Material[material or "Slate"]
        p.TopSurface = Enum.SurfaceType.Smooth
        p.BottomSurface = Enum.SurfaceType.Smooth
        p.Parent = parent
        return p
    end
    local e = cfg.extension
    local pond = cfg.pond
    local terrain = workspace.Terrain
    for _, side in ipairs({ -1, 1 }) do
        local region = Region3.new(
            V.new(side < 0 and -e.outer_x or e.inner_x, e.bottom, e.z_min),
            V.new(side < 0 and -e.inner_x or e.outer_x, 24, e.z_max)
        ):ExpandToGrid(4)
        local min = region.CFrame.Position - region.Size / 2
        local max = min + region.Size
        local backup = terrain:CopyRegion(
            Region3int16.new(
                Vector3int16.new(min.X / 4, min.Y / 4, min.Z / 4),
                Vector3int16.new(max.X / 4 - 1, max.Y / 4 - 1, max.Z / 4 - 1)
            )
        )
        backup.Name = side < 0 and "LeisureTerrainWestBefore" or "LeisureTerrainEastBefore"
        backup.Parent = game.ServerStorage
        local mats, occ = terrain:ReadVoxels(region, 4)
        for ix = 1, #mats do
            for iz = 1, #mats[ix][1] do
                local x = min.X + (ix - 0.5) * 4
                local z = min.Z + (iz - 0.5) * 4
                local edge = e.outer_x - math.max(0, math.abs(z - 8) - 64) * 1.5
                local height = e.floor
                    + (e.rim - e.floor)
                        * math.clamp((math.abs(x) - e.flat_x) / (e.outer_x - e.flat_x), 0, 1)
                local inPond = side < 0
                    and ((x - pond.center[1]) / pond.radii[1]) ^ 2 + ((z - pond.center[2]) / pond.radii[2]) ^ 2 < 1
                for iy = 1, #mats[ix] do
                    local y = min.Y + (iy - 1) * 4
                    if math.abs(x) < edge then
                        local top = inPond and pond.bottom or height
                        occ[ix][iy][iz] = math.clamp((top - 2 - y) / 4, 0, 1)
                        mats[ix][iy][iz] = side < 0 and Enum.Material.LeafyGrass
                            or Enum.Material.Ground
                        if inPond and y >= pond.bottom - 2 and y < pond.surface - 2 then
                            occ[ix][iy][iz] = math.clamp((pond.surface - 2 - y) / 4, 0, 1)
                            mats[ix][iy][iz] = Enum.Material.Water
                        end
                        if occ[ix][iy][iz] == 0 then
                            mats[ix][iy][iz] = Enum.Material.Air
                        end
                    end
                end
            end
        end
        terrain:WriteVoxels(region, 4, mats, occ)
    end
    local s = cfg.stands
    local stand = group("ArenaSpectatorStands")
    local chairs = {}
    for row, x in ipairs(s.row_x) do
        local top = s.row_height[row]
        for _, sign in ipairs({ -1, 1 }) do
            local length = s.half_length - s.aisle / 2
            part(
                stand,
                "Tier" .. row,
                { s.row_depth, top - e.floor, length },
                C.new(x, (top + e.floor) / 2, s.center_z + sign * (s.aisle / 2 + length / 2)),
                "stone"
            )
        end
        for col, z in ipairs(s.seat_z) do
            local cf = C.lookAt(V.new(x, top, s.center_z + z), V.new(x - 1, top, s.center_z + z))
            local seat = part(
                stand,
                string.format("Seat_%02d_%02d", row, col),
                s.seat_size,
                cf * C.new(0, s.seat_height, 0),
                "seat",
                "Wood",
                "Seat"
            )
            seat:SetAttribute("PodiumSpectatorSlot", (row - 1) * #s.seat_z + col)
            part(
                stand,
                "ChairBack",
                { 3.2, s.back_height, 0.35 },
                cf * C.new(0, s.seat_height + s.back_height / 2, 1.45),
                "seat",
                "Wood"
            )
            for _, sx in ipairs({ -1.3, 1.3 }) do
                part(
                    stand,
                    "ChairLeg",
                    { 0.25, s.seat_height, 0.25 },
                    cf * C.new(sx, s.seat_height / 2, 0.9),
                    "metal",
                    "Metal"
                )
                part(
                    stand,
                    "ArmRest",
                    { 0.3, 0.3, 2.6 },
                    cf * C.new(sx, s.seat_height + 0.9, 0),
                    "trim",
                    "Metal"
                )
            end
            table.insert(chairs, { seat = seat, cf = cf, top = top, row = row, col = col })
        end
    end
    local start = s.row_x[1] - s.row_depth / 2
    local finish = s.row_x[#s.row_x] + s.row_depth / 2
    local steps = (s.row_height[#s.row_height] - e.floor) / s.stair_rise
    for n = 1, steps do
        local depth = (finish - start) / steps
        local top = e.floor + n * s.stair_rise
        part(
            stand,
            "AisleStep" .. n,
            { depth, top - e.floor, s.aisle },
            C.new(start + (n - 0.5) * depth, (top + e.floor) / 2, s.center_z),
            "stone"
        )
    end
    -- Rear and end guard rails, leaving the front and central aisle open.
    for _, z in ipairs({ s.center_z - s.half_length, s.center_z + s.half_length }) do
        for row, x in ipairs(s.row_x) do
            local top = s.row_height[row]
            part(stand, "EndRail", { s.row_depth, 0.3, 0.3 }, C.new(x, top + 3, z), "trim", "Metal")
            part(
                stand,
                "RailPost",
                { 0.3, 3, 0.3 },
                C.new(x + s.row_depth / 2 - 0.2, top + 1.5, z),
                "metal",
                "Metal"
            )
        end
    end
    local rear = finish - 0.3
    part(
        stand,
        "RearRail",
        { 0.3, 0.3, s.half_length * 2 },
        C.new(rear, s.row_height[#s.row_height] + 3, s.center_z),
        "trim",
        "Metal"
    )
    for z = -s.half_length, s.half_length, 12 do
        part(
            stand,
            "RearPost",
            { 0.3, 3, 0.3 },
            C.new(rear, s.row_height[#s.row_height] + 1.5, s.center_z + z),
            "metal",
            "Metal"
        )
    end
    -- Static seated copies of the existing R15 height references; no NPC or ranking code.
    local dummies = group("SeatedPodiumPreview")
    local source = world.BraggRotundaR6.PodiumHeightDummies:GetChildren()
    table.sort(source, function(a, b)
        return a.Name < b.Name
    end)
    local used = 0
    for _, entry in ipairs(chairs) do
        if entry.col ~= 4 and entry.col ~= 5 and used < cfg.stands.dummy_count then
            used += 1
            local model = source[(used - 1) % #source + 1]:Clone()
            model.Name = "Spectator_" .. used
            model.Parent = dummies
            local base = entry.cf * C.new(0, s.seat_height + 0.5, 0)
            local tint = Color3.fromRGB(
                unpack(cfg.palette.dummy_colors[(entry.row - 1) % #cfg.palette.dummy_colors + 1])
            )
            for _, p in ipairs(model:GetDescendants()) do
                if
                    p:IsA("Humanoid")
                    or p:IsA("BodyColors")
                    or p:IsA("Script")
                    or p:IsA("LocalScript")
                then
                    p:Destroy()
                elseif p:IsA("BasePart") then
                    p.Anchored = true
                    p.CanCollide = false
                    p.CanTouch = false
                    p.CanQuery = false
                    p.Color = tint
                end
            end
            local poses = {
                HumanoidRootPart = { 0, 0.4, 0 },
                LowerTorso = { 0, 0.2, 0 },
                UpperTorso = { 0, 1.18, 0 },
                Head = { 0, 2.65, 0 },
                LeftUpperLeg = { -0.5, 0, -0.6, 90 },
                RightUpperLeg = { 0.5, 0, -0.6, 90 },
                LeftLowerLeg = { -0.5, -0.75, -1.2 },
                RightLowerLeg = { 0.5, -0.75, -1.2 },
                LeftFoot = { -0.5, -1.5, -1.4 },
                RightFoot = { 0.5, -1.5, -1.4 },
                LeftUpperArm = { -1.45, 1.05, 0 },
                RightUpperArm = { 1.45, 1.05, 0 },
                LeftLowerArm = { -1.45, 0.48, -0.55, 90 },
                RightLowerArm = { 1.45, 0.48, -0.55, 90 },
                LeftHand = { -1.45, 0.48, -1.17 },
                RightHand = { 1.45, 0.48, -1.17 },
            }
            for name, v in pairs(poses) do
                local p = model:FindFirstChild(name)
                if p then
                    p.CFrame = base * C.new(v[1], v[2], v[3]) * C.Angles(math.rad(v[4] or 0), 0, 0)
                end
            end
            entry.seat.Disabled = true
            entry.seat:SetAttribute("StaticPreviewOccupied", true)
        end
    end
    local fishing = group("HeavenFishingPond")
    fishing:SetAttribute("FishingConnected", false)
    for n, z in ipairs(pond.dock_z) do
        local dock = part(
            fishing,
            "FishingPlatform" .. n,
            pond.dock_size,
            C.new(pond.dock_x, 4.3, z),
            "wood",
            "WoodPlanks"
        )
        dock:SetAttribute("FutureFishingPosition", true)
        for _, x in ipairs({ pond.dock_x - 7, pond.dock_x + 7 }) do
            for _, dz in ipairs({ -3, 3 }) do
                part(fishing, "DockPost", { 0.65, 8, 0.65 }, C.new(x, 0.6, z + dz), "wood", "Wood")
            end
        end
    end
    -- Relocate established flora out of the new seating and pond footprints.
    local flora = world.CrossroadsLandscapeR8.PerimeterFlora
    local moved = 0
    for _, m in ipairs(flora:GetChildren()) do
        if m:IsA("Model") then
            local cf = m:GetPivot()
            local p = cf.Position
            if
                math.abs(p.X) > cfg.flora_move.threshold_x
                and p.Z > cfg.flora_move.z_min
                and p.Z < cfg.flora_move.z_max
            then
                local side = p.X < 0 and -1 or 1
                moved += 1
                local x = cfg.flora_move.outer_rows[(moved - 1) % #cfg.flora_move.outer_rows + 1]
                local z = math.clamp(p.Z, -52, 68)
                m:PivotTo(cf + V.new(side * x - p.X, 0, z - p.Z))
            end
        end
    end
    local fence = world.CrossroadsLandscapeR8.InvisibleIslandBoundary
    fence.Name = "IslandBoundaryBeforeLeisure"
    fence.Parent = game.ServerStorage
    local f = Instance.new("Folder")
    f.Name = "InvisibleIslandBoundary"
    f.Parent = root
    local template = fence:GetChildren()[1]
    for i, a in ipairs(cfg.boundary) do
        local b = cfg.boundary[i % #cfg.boundary + 1]
        local p = template:Clone()
        local y = p.Position.Y
        local av, bv = V.new(a[1], y, a[2]), V.new(b[1], y, b[2])
        p.Name = "OuterSafetyWall" .. i
        p.Size = V.new(template.Size.X, template.Size.Y, (av - bv).Magnitude + template.Size.X)
        p.CFrame = C.lookAt((av + bv) / 2, bv)
        p.Parent = f
    end
    return { seats = #chairs, dummies = used, relocatedFlora = moved, boundarySegments = #cfg.boundary }
end
