-- Final Edit-time fishing landscape pass on the isolated Crossroads preview.
return function(cfg)
    assert(
        game.PlaceId == 0 and not game:GetService("RunService"):IsRunning(),
        "Local Edit preview only"
    )
    local V, C = Vector3, CFrame
    local world = workspace.RealmCrossroadsR4
    assert(not world:FindFirstChild(cfg.root), "Restore pre-fishing terrain before rebaking")
    local root = Instance.new("Model")
    root.Name = cfg.root
    root.Parent = world
    root:SetAttribute("FishingConnected", false)
    local old = world.CrossroadsLeisureR9.HeavenFishingPond
    old.Name = "FishingPondBeforeR10"
    old.Parent = game.ServerStorage
    local terrain = workspace.Terrain
    local e = cfg.extension
    for index, pond in ipairs(cfg.ponds) do
        local side = index == 1 and -1 or 1
        local region = Region3.new(
            V.new(side < 0 and -e.outer or e.inner, e.bottom, e.z_min),
            V.new(side < 0 and -e.inner or e.outer, 24, e.z_max)
        ):ExpandToGrid(4)
        local min = region.CFrame.Position - region.Size / 2
        local max = min + region.Size
        local backup = terrain:CopyRegion(
            Region3int16.new(
                Vector3int16.new(min.X / 4, min.Y / 4, min.Z / 4),
                Vector3int16.new(max.X / 4 - 1, max.Y / 4 - 1, max.Z / 4 - 1)
            )
        )
        backup.Name = "FishingTerrainBefore" .. index
        backup.Parent = game.ServerStorage
        local mats, occ = terrain:ReadVoxels(region, 4)
        for ix = 1, #mats do
            for iz = 1, #mats[ix][1] do
                local x = min.X + (ix - 0.5) * 4
                local z = min.Z + (iz - 0.5) * 4
                local edge = e.outer - math.max(0, math.abs(z - 8) - 96) * 2.6
                local distance = ((x - pond.center[1]) / pond.radii[1]) ^ 2
                    + ((z - pond.center[2]) / pond.radii[2]) ^ 2
                local inside = distance < 1
                local height = e.floor
                    + (e.rim - e.floor)
                        * math.clamp((math.abs(x) - e.flat) / (e.outer - e.flat), 0, 1)
                for iy = 1, #mats[ix] do
                    local y = min.Y + (iy - 1) * 4
                    if math.abs(x) < edge then
                        local top = inside and pond.bottom or height
                        occ[ix][iy][iz] = math.clamp((top - 2 - y) / 4, 0, 1)
                        mats[ix][iy][iz] = Enum.Material[pond.terrain]
                        if inside and y >= pond.bottom - 2 and y < pond.surface - 2 then
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
        -- Clear old solid/fluid channels before replacing a former solid bed with water.
        terrain:FillRegion(region, 4, Enum.Material.Air)
        terrain:WriteVoxels(region, 4, mats, occ)
        local model = Instance.new("Model")
        model.Name = pond.name
        model.Parent = root
        model:SetAttribute("AnglerCapacity", pond.spots)
        local function part(name, size, cf, color, material)
            local p = Instance.new("Part")
            p.Name = name
            p.Anchored = true
            p.Size = size
            p.CFrame = cf
            p.Color = Color3.fromRGB(unpack(color))
            p.Material = Enum.Material[material]
            p.TopSurface = Enum.SurfaceType.Smooth
            p.BottomSurface = Enum.SurfaceType.Smooth
            p.Parent = model
            return p
        end
        for n = 1, pond.spots do
            local angle = (n - 1) * math.pi * 2 / pond.spots
            local outward = V.new(math.cos(angle), 0, math.sin(angle))
            local shore = V.new(
                pond.center[1] + math.cos(angle) * pond.radii[1],
                cfg.platform.top - cfg.platform.height / 2,
                pond.center[2] + math.sin(angle) * pond.radii[2]
            )
            local center = shore + outward * cfg.platform.radial_offset
            local cf = C.lookAt(center, center - outward)
            local deck = part(
                "FishingStation" .. n,
                V.new(cfg.platform.width, cfg.platform.height, cfg.platform.depth),
                cf,
                pond.color,
                pond.material
            )
            deck:SetAttribute("FutureFishingPosition", true)
            deck:SetAttribute("StationIndex", n)
            for _, x in ipairs({ -4, 4 }) do
                for _, z in ipairs({ -4, 4 }) do
                    part("PierPost", V.new(0.55, 8, 0.55), cf * C.new(x, -4, z), pond.color, "Wood")
                end
            end
            -- Decks remain clear; existing asset clusters sit between fishing stations.
            local a = angle + math.pi / pond.spots
            local at = V.new(
                pond.center[1] + math.cos(a) * (pond.radii[1] + 10),
                e.floor,
                pond.center[2] + math.sin(a) * (pond.radii[2] + 10)
            )
            local name = pond.decor[(n - 1) % #pond.decor + 1]
            local template = game.ServerStorage.CrossroadsLandscapeAssets:FindFirstChild(name)
            if template then
                local decor = template:Clone()
                decor.Name = name
                decor.Parent = model
                for _, p in ipairs(decor:GetDescendants()) do
                    if p:IsA("BasePart") then
                        p.Anchored = true
                        p.CanCollide = false
                        p.CanTouch = false
                        p.CanQuery = false
                        if index == 2 and name == "pearl_quartz" then
                            p.Color = Color3.fromRGB(unpack(cfg.hell_liquid.rim_color))
                        end
                    end
                end
                local _, sz = decor:GetBoundingBox()
                decor:ScaleTo(decor:GetScale() * (name == "bone_rock" and 3 or 2.4) / sz.Y)
                decor:PivotTo(C.new(at) * C.Angles(0, a, 0))
                local box, size = decor:GetBoundingBox()
                decor:PivotTo(
                    decor:GetPivot() + V.new(0, e.floor - (box.Position.Y - size.Y / 2), 0)
                )
            end
        end
    end
    local moved = 0
    for _, m in ipairs(world.CrossroadsLandscapeR8.PerimeterFlora:GetChildren()) do
        if m:IsA("Model") then
            local cf = m:GetPivot()
            local p = cf.Position
            if math.abs(p.X) > cfg.flora.old_min_x then
                moved += 1
                local side = p.X < 0 and -1 or 1
                local x = cfg.flora.outer_rows[(moved - 1) % #cfg.flora.outer_rows + 1]
                m:PivotTo(
                    cf
                        + V.new(
                            side * x - p.X,
                            0,
                            math.clamp(p.Z, cfg.flora.z_range[1], cfg.flora.z_range[2]) - p.Z
                        )
                )
            end
        end
    end
    local oldFence = world.CrossroadsLeisureR9.InvisibleIslandBoundary
    local template = oldFence:GetChildren()[1]
    oldFence.Name = "BoundaryBeforeFishingR10"
    oldFence.Parent = game.ServerStorage
    local fence = Instance.new("Folder")
    fence.Name = "InvisibleIslandBoundary"
    fence.Parent = root
    for n, a in ipairs(cfg.boundary) do
        local b = cfg.boundary[n % #cfg.boundary + 1]
        local y = template.Position.Y
        local av, bv = V.new(a[1], y, a[2]), V.new(b[1], y, b[2])
        local p = template:Clone()
        p.Name = "OuterSafetyWall" .. n
        p.Size = V.new(template.Size.X, template.Size.Y, (av - bv).Magnitude + template.Size.X)
        p.CFrame = C.lookAt((av + bv) / 2, bv)
        p.Parent = fence
    end
    return {
        heavenStations = cfg.ponds[1].spots,
        hellStations = cfg.ponds[2].spots,
        movedFlora = moved,
        boundarySegments = #cfg.boundary,
    }
end
