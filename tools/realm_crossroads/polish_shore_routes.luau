-- Material-only shore routes, with the explicitly approved Coin Garden pinch repair.
-- dry_run=true performs no datamodel mutation; geometry guards use the proposed wall position.
return function(world, cfg)
    assert(
        game.PlaceId == 0 and not game:GetService("RunService"):IsRunning(),
        "Isolated Edit preview only"
    )
    local V = Vector3
    local terrain, storage = workspace.Terrain, game:GetService("ServerStorage")
    local fishing = assert(world:FindFirstChild(cfg.fishing_root), "Missing fishing root")
    local p = cfg.parapet
    local garden = world[p.activity_root][p.garden]
    local parapet = assert(garden:FindFirstChild(p.name), "Missing Coin Garden parapet")
    assert(
        math.abs(parapet.CFrame.RightVector.X) > 0.999,
        "Parapet local X no longer matches world X"
    )
    local targetCF = parapet.CFrame + V.new(p.target_x - parapet.Position.X, 0, 0)
    local targetSize = V.new(p.target_width, parapet.Size.Y, parapet.Size.Z)
    local removed, ignored = {}, {}
    for _, item in ipairs(garden:GetChildren()) do
        local position
        if item:IsA("BasePart") and item.Name == p.edge_planter_name then
            position = item.Position
        elseif item:IsA("Model") and item.Name == p.associated_flower_name then
            position = item:GetPivot().Position
        end
        if position and math.abs(position.X - p.planter_x) < p.flower_radius then
            for _, z in ipairs(p.planter_z) do
                if math.abs(position.Z - z) < p.match_tolerance then
                    table.insert(removed, item)
                    ignored[item] = true
                    for _, child in ipairs(item:GetDescendants()) do
                        ignored[child] = true
                    end
                    break
                end
            end
        end
    end
    local function bounds(cf, size)
        local half = size / 2
        local extent = V.new(
            math.abs(cf.RightVector.X) * half.X
                + math.abs(cf.UpVector.X) * half.Y
                + math.abs(cf.LookVector.X) * half.Z,
            math.abs(cf.RightVector.Y) * half.X
                + math.abs(cf.UpVector.Y) * half.Y
                + math.abs(cf.LookVector.Y) * half.Z,
            math.abs(cf.RightVector.Z) * half.X
                + math.abs(cf.UpVector.Z) * half.Y
                + math.abs(cf.LookVector.Z) * half.Z
        )
        return cf.Position - extent, cf.Position + extent
    end
    local canopyRoots = {}
    for _, path in ipairs(cfg.noncolliding_canopy_exclusions or {}) do
        local object = world
        for _, name in ipairs(path) do
            object = object and object:FindFirstChild(name)
        end
        if object then
            table.insert(canopyRoots, object)
        end
    end
    local function isNoncollidingCanopy(item)
        if item.CanCollide then
            return false
        end
        for _, canopy in ipairs(canopyRoots) do
            if item:IsDescendantOf(canopy) then
                return true
            end
        end
        return false
    end
    local structures = {}
    for _, item in ipairs(world:GetDescendants()) do
        if
            item:IsA("BasePart")
            and not ignored[item]
            and not isNoncollidingCanopy(item)
            and (item.CanCollide or item.Transparency < 1)
        then
            local cf, size = item.CFrame, item.Size
            if item == parapet then
                cf, size = targetCF, targetSize
            end
            local low, high = bounds(cf, size)
            if high.Y >= cfg.ground_y_min and low.Y <= cfg.ground_y_max + cfg.structure_height then
                table.insert(
                    structures,
                    { low = low, high = high, path = item:GetFullName(), part = item }
                )
            end
        end
    end
    local function cross(a, b, c)
        return (b.X - a.X) * (c.Z - a.Z) - (b.Z - a.Z) * (c.X - a.X)
    end
    local function hull(points)
        table.sort(points, function(a, b)
            return a.X < b.X or (a.X == b.X and a.Z < b.Z)
        end)
        local lower, upper = {}, {}
        for _, point in ipairs(points) do
            while #lower >= 2 and cross(lower[#lower - 1], lower[#lower], point) <= 0 do
                table.remove(lower)
            end
            table.insert(lower, point)
        end
        for i = #points, 1, -1 do
            local point = points[i]
            while #upper >= 2 and cross(upper[#upper - 1], upper[#upper], point) <= 0 do
                table.remove(upper)
            end
            table.insert(upper, point)
        end
        table.remove(lower)
        table.remove(upper)
        for _, point in ipairs(upper) do
            table.insert(lower, point)
        end
        return lower
    end
    local function segmentDistance(point, a, b)
        local delta = b - a
        local t = math.clamp((point - a):Dot(delta) / delta:Dot(delta), 0, 1)
        return (point - (a + delta * t)).Magnitude
    end
    local function routePoint(point, polygon, connectors)
        local inside, distance = true, math.huge
        for i, a in ipairs(polygon) do
            local b = polygon[i % #polygon + 1]
            if cross(a, b, point) < 0 then
                inside = false
            end
            distance = math.min(distance, segmentDistance(point, a, b))
        end
        if not inside and distance <= cfg.route_width then
            return true
        end
        for _, line in ipairs(connectors) do
            for i = 1, #line - 1 do
                if segmentDistance(point, line[i], line[i + 1]) <= cfg.route_width / 2 then
                    return true
                end
            end
        end
        return false
    end
    local ray = RaycastParams.new()
    ray.FilterType = Enum.RaycastFilterType.Include
    ray.FilterDescendantsInstances = { terrain }
    ray.IgnoreWater = false
    local report = {
        dryRun = cfg.dry_run,
        material = cfg.material,
        plans = {},
        structuralArchiveCount = #removed,
        proposedHeavenClearance = 12.3,
    }
    local pending = {}
    local resolution = cfg.voxel_resolution
    local half = resolution / 2 - cfg.cell_sample_inset
    for _, pond in ipairs(cfg.ponds) do
        local source = assert(fishing:FindFirstChild(pond.name), "Missing pond")
        local points, approaches = {}, 0
        for n = 1, pond.stations do
            local deck = assert(source:FindFirstChild("FishingStation" .. n), "Missing dock")
            for _, x in ipairs({ -deck.Size.X / 2, deck.Size.X / 2 }) do
                for _, z in ipairs({ -deck.Size.Z / 2, deck.Size.Z / 2 }) do
                    local point = deck.CFrame:PointToWorldSpace(V.new(x, 0, z))
                    table.insert(points, V.new(point.X, 0, point.Z))
                end
            end
        end
        for _, object in ipairs(fishing:GetDescendants()) do
            if object.Name == "DryBankApproach" and object.Parent.Parent.Name == pond.name then
                approaches += 1
            end
        end
        local polygon, connectors = hull(points), {}
        for _, line in ipairs(pond.connectors) do
            local vertices = {}
            for _, at in ipairs(line) do
                table.insert(vertices, V.new(at[1], 0, at[2]))
            end
            table.insert(connectors, vertices)
        end
        local region = Region3.new(V.new(unpack(pond.region_min)), V.new(unpack(pond.region_max)))
            :ExpandToGrid(resolution)
        local minimum = region.CFrame.Position - region.Size / 2
        local channels = terrain:ReadVoxelChannels(
            region,
            resolution,
            { "SolidMaterial", "SolidOccupancy", "LiquidOccupancy" }
        )
        local materials, solid, liquid =
            channels.SolidMaterial, channels.SolidOccupancy, channels.LiquidOccupancy
        local result = {
            pond = pond.name,
            stations = pond.stations,
            existingApproaches = approaches,
            proposedCells = 0,
            alreadyPainted = 0,
            blockedStructure = 0,
            blockedGround = 0,
            blockedField = 0,
            blockers = {},
            hull = {},
        }
        for _, point in ipairs(polygon) do
            table.insert(result.hull, { point.X, point.Z })
        end
        local seenBlockers, edits = {}, {}
        for ix = 1, #materials do
            for iz = 1, #materials[ix][1] do
                local x, z =
                    minimum.X + (ix - 0.5) * resolution, minimum.Z + (iz - 0.5) * resolution
                if routePoint(V.new(x, 0, z), polygon, connectors) then
                    local field = false
                    for _, rectangle in ipairs(cfg.protected_fields) do
                        if
                            x + half > rectangle.min_x
                            and x - half < rectangle.max_x
                            and z + half > rectangle.min_z
                            and z - half < rectangle.max_z
                        then
                            field = true
                        end
                    end
                    local groundOK, lowY, highY = true, math.huge, -math.huge
                    for _, dx in ipairs({ -half, 0, half }) do
                        for _, dz in ipairs({ -half, 0, half }) do
                            local hit = workspace:Raycast(
                                V.new(x + dx, cfg.ray_origin_y, z + dz),
                                V.new(0, -cfg.ray_length, 0),
                                ray
                            )
                            if
                                not hit
                                or hit.Material == Enum.Material.Water
                                or hit.Position.Y < cfg.ground_y_min
                                or hit.Position.Y > cfg.ground_y_max
                                or hit.Normal.Y < cfg.minimum_normal_y
                            then
                                groundOK = false
                            else
                                lowY, highY =
                                    math.min(lowY, hit.Position.Y), math.max(highY, hit.Position.Y)
                            end
                        end
                    end
                    local blocker
                    if groundOK then
                        for _, item in ipairs(structures) do
                            if
                                item.high.X > x - half
                                and item.low.X < x + half
                                and item.high.Z > z - half
                                and item.low.Z < z + half
                                and item.high.Y > lowY + cfg.structure_ground_offset
                                and item.low.Y < highY + cfg.structure_height
                            then
                                blocker = item.path
                                break
                            end
                        end
                    end
                    if field then
                        result.blockedField += 1
                    elseif not groundOK then
                        result.blockedGround += 1
                    elseif blocker then
                        result.blockedStructure += 1
                        if
                            not seenBlockers[blocker]
                            and #result.blockers < cfg.max_blocker_examples
                        then
                            seenBlockers[blocker] = true
                            table.insert(result.blockers, blocker)
                        end
                    else
                        local iy
                        local wet = false
                        for y = 1, #materials[ix] do
                            if liquid[ix][y][iz] > 0 then
                                wet = true
                            end
                            if solid[ix][y][iz] > 0 then
                                iy = y
                            end
                        end
                        if
                            iy
                            and not wet
                            and table.find(cfg.allowed_source_materials, materials[ix][iy][iz].Name)
                        then
                            if materials[ix][iy][iz] == Enum.Material[cfg.material] then
                                result.alreadyPainted += 1
                            else
                                table.insert(edits, { ix, iy, iz, materials[ix][iy][iz].Name })
                                materials[ix][iy][iz] = Enum.Material[cfg.material]
                                result.proposedCells += 1
                            end
                        else
                            result.blockedGround += 1
                        end
                    end
                end
            end
        end
        table.insert(report.plans, result)
        table.insert(pending, {
            name = pond.name,
            region = region,
            minimum = minimum,
            materials = materials,
            solid = solid,
            liquid = liquid,
            edits = edits,
        })
    end
    -- Everything above is read-only. No archives, attributes or materials change during audit.
    if cfg.dry_run then
        return report
    end
    local backup = storage:FindFirstChild(cfg.backup)
    if not backup then
        backup = Instance.new("Folder")
        backup.Name, backup.Parent = cfg.backup, storage
    end
    if parapet:GetAttribute("ShoreRouteOriginalCFrame") == nil then
        parapet:SetAttribute("ShoreRouteOriginalCFrame", parapet.CFrame)
        parapet:SetAttribute("ShoreRouteOriginalSize", parapet.Size)
    end
    parapet.CFrame, parapet.Size = targetCF, targetSize
    for _, item in ipairs(removed) do
        item:SetAttribute("ShoreRouteOriginalParent", garden:GetFullName())
        item.Parent = backup
    end
    local http = game:GetService("HttpService")
    for _, job in ipairs(pending) do
        local name = job.name .. "OriginalCells"
        local saved = backup:FindFirstChild(name)
        local previous = saved and http:JSONDecode(saved.Value) or {}
        local already = {}
        for _, cell in ipairs(previous) do
            already[table.concat({ cell[1], cell[2], cell[3] }, ",")] = true
        end
        for _, edit in ipairs(job.edits) do
            local cell = {
                job.minimum.X / resolution + edit[1] - 1,
                job.minimum.Y / resolution + edit[2] - 1,
                job.minimum.Z / resolution + edit[3] - 1,
                edit[4],
            }
            local key = table.concat({ cell[1], cell[2], cell[3] }, ",")
            if not already[key] then
                table.insert(previous, cell)
                already[key] = true
            end
        end
        if not saved then
            saved = Instance.new("StringValue")
            saved.Name, saved.Parent = name, backup
        end
        saved.Value = http:JSONEncode(previous)
        -- Deliberately omit both occupancy channels: neither terrain shape nor water is written.
        terrain:WriteVoxelChannels(job.region, resolution, { SolidMaterial = job.materials })
        local after = terrain:ReadVoxelChannels(
            job.region,
            resolution,
            { "SolidOccupancy", "LiquidOccupancy" }
        )
        for x = 1, #job.solid do
            for y = 1, #job.solid[x] do
                for z = 1, #job.solid[x][y] do
                    assert(
                        after.SolidOccupancy[x][y][z] == job.solid[x][y][z],
                        "Unexpected solid occupancy change"
                    )
                    assert(
                        after.LiquidOccupancy[x][y][z] == job.liquid[x][y][z],
                        "Unexpected water occupancy change"
                    )
                end
            end
        end
    end
    report.occupancyVerifiedUnchanged = true
    return report
end
