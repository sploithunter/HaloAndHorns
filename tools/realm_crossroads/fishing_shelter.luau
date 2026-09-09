-- Small authored rest shelter. Root applies in the existing Edit preview.
return function(world, cfg)
    assert(
        game.PlaceId == 0 and not game:GetService("RunService"):IsRunning(),
        "Local Edit preview only"
    )
    local V, C = Vector3, CFrame
    local terrain, storage = workspace.Terrain, game:GetService("ServerStorage")
    local center = V.new(unpack(cfg.center))
    local ray = RaycastParams.new()
    ray.FilterType = Enum.RaycastFilterType.Include
    ray.FilterDescendantsInstances = { terrain }
    ray.IgnoreWater = false
    local function ground(x, z)
        local hit = workspace:Raycast(
            V.new(x, cfg.survey.ray_y, z),
            V.new(0, -cfg.survey.ray_depth, 0),
            ray
        )
        assert(hit and hit.Material ~= Enum.Material.Water, "Shelter site must stay dry")
        assert(
            hit.Position.Y >= cfg.survey.min_y and hit.Position.Y <= cfg.survey.max_y,
            "Shelter bank height changed"
        )
        return hit.Position.Y
    end
    for _, x in ipairs({ center.X - cfg.width / 2, center.X, center.X + cfg.width / 2 }) do
        for _, z in ipairs({ center.Z - cfg.depth / 2, center.Z, center.Z + cfg.depth / 2 }) do
            ground(x, z)
        end
    end
    local old = world:FindFirstChild(cfg.root)
    if old then
        for _, instance in ipairs(old:GetDescendants()) do
            assert(
                not instance:IsA("Seat") or not instance.Occupant,
                "Leave occupied shelter unchanged"
            )
        end
        old:Destroy()
    end
    local root = Instance.new("Model")
    root.Name, root.Parent = cfg.root, world
    root:SetAttribute("GameplayConnected", false)
    root:SetAttribute("NativeSeatCount", 4)
    local colors = {}
    for name, value in pairs(cfg.palette) do
        colors[name] = Color3.fromRGB(unpack(value))
    end
    local function part(name, size, cf, color, material, collide, class)
        local p = Instance.new(class or "Part")
        p.Name, p.Size, p.CFrame = name, size, cf
        p.Color, p.Material = colors[color], material or Enum.Material.Wood
        p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow =
            true, collide == true, false, collide == true, false
        p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
        p.Parent = root
        return p
    end
    local function member(name, a, b, width, height, color)
        return part(
            name,
            V.new(width, height, (b - a).Magnitude),
            C.lookAt((a + b) / 2, b),
            color,
            Enum.Material.Wood,
            false
        )
    end
    local roof, posts = cfg.roof, cfg.posts
    local function roofY(x)
        return center.Y + roof.eave_height + roof.bow_rise * (1 - (x / (cfg.width / 2)) ^ 2)
    end
    assert(
        roofY(0) + roof.thickness / 2 <= roof.max_world_y,
        "Shelter roof exceeds silhouette limit"
    )
    local supportTop = roofY(posts.x) - roof.thickness / 2
    for _, sx in ipairs({ -1, 1 }) do
        part(
            "LongitudinalSupport",
            V.new(posts.support_width, posts.support_height, cfg.depth),
            C.new(center.X + sx * posts.x, supportTop - posts.support_height / 2, center.Z),
            "frame"
        )
        for _, sz in ipairs({ -1, 1 }) do
            local x, z = center.X + sx * posts.x, center.Z + sz * posts.z
            local floor = ground(x, z)
            part(
                "StonePostFoot",
                V.new(posts.foot_width, posts.foot_height, posts.foot_width),
                C.new(x, floor + posts.foot_height / 2, z),
                "stone",
                Enum.Material.Limestone,
                true
            )
            local bottom, top = floor + posts.foot_height, supportTop - posts.support_height
            part(
                "TimberPost",
                V.new(posts.width, top - bottom, posts.width),
                C.new(x, (top + bottom) / 2, z),
                "timber",
                Enum.Material.Wood,
                true
            )
            member(
                "KneeBrace",
                V.new(x, top - posts.brace_drop, z),
                V.new(x, top, z - sz * posts.brace_run),
                posts.brace_width,
                posts.brace_width,
                "bronze"
            )
        end
    end
    -- Roof slats and ribs follow chord segments of one shallow bow. No flat floor overlay.
    for n = 1, roof.slat_count do
        local z = center.Z
            - cfg.depth / 2
            + roof.slat_width / 2
            + (n - 1) * (cfg.depth - roof.slat_width) / (roof.slat_count - 1)
        for i = 1, roof.segments do
            local a = -cfg.width / 2 + (i - 1) * cfg.width / roof.segments
            local b = -cfg.width / 2 + i * cfg.width / roof.segments
            member(
                "BowedRoofSlat",
                V.new(center.X + a, roofY(a), z),
                V.new(center.X + b, roofY(b), z),
                roof.slat_width,
                roof.thickness,
                "timber"
            )
        end
    end
    for _, sign in ipairs({ -1, 1 }) do
        local z = center.Z + sign * posts.z
        for i = 1, roof.segments do
            local a = -cfg.width / 2 + (i - 1) * cfg.width / roof.segments
            local b = -cfg.width / 2 + i * cfg.width / roof.segments
            local drop = roof.thickness / 2 + roof.rib_height / 2
            member(
                "BowRib",
                V.new(center.X + a, roofY(a) - drop, z),
                V.new(center.X + b, roofY(b) - drop, z),
                roof.rib_width,
                roof.rib_height,
                "frame"
            )
        end
    end
    local bench = cfg.benches
    local seats = 0
    for index, x in ipairs(bench.centers_x) do
        local at = center + V.new(x, 0, bench.center_z)
        local floor = ground(at.X, at.Z)
        local cf = C.lookAt(V.new(at.X, floor, at.Z), V.new(at.X, floor, at.Z + 1))
        local seatSize = V.new(unpack(bench.seat_size))
        local seatBottom = bench.seat_top_height - seatSize.Y
        local frameBottom = seatBottom - bench.frame_height
        part(
            "BenchUnderframe",
            V.new(bench.width, bench.frame_height, bench.frame_depth),
            cf * C.new(0, seatBottom - bench.frame_height / 2, 0),
            "frame"
        )
        for _, sx in ipairs({ -1, 1 }) do
            for _, sz in ipairs({ -1, 1 }) do
                part(
                    "BenchLeg",
                    V.new(bench.leg_width, frameBottom, bench.leg_width),
                    cf * C.new(sx * bench.leg_offset_x, frameBottom / 2, sz * bench.leg_offset_z),
                    "frame"
                )
            end
            part(
                "BenchArm",
                V.new(bench.arm_width, bench.arm_width, bench.frame_depth),
                cf
                    * C.new(
                        sx * (bench.width - bench.arm_width) / 2,
                        bench.seat_top_height + bench.arm_height,
                        0
                    ),
                "bronze",
                Enum.Material.Metal
            )
            part(
                "BenchBackPost",
                V.new(bench.arm_width, bench.back_height, bench.back_thickness),
                cf
                    * C.new(
                        sx * (bench.width - bench.arm_width) / 2,
                        bench.seat_top_height + bench.back_height / 2,
                        bench.frame_depth / 2
                    ),
                "frame"
            )
        end
        for row = 1, bench.back_slats do
            local height = bench.back_height / (bench.back_slats * 2)
            part(
                "BenchBackSlat",
                V.new(bench.width - 2 * bench.arm_width, height, bench.back_thickness),
                cf
                    * C.new(
                        0,
                        bench.seat_top_height + (row - 0.5) * bench.back_height / bench.back_slats,
                        bench.frame_depth / 2
                    ),
                "timber"
            )
        end
        for column, offset in ipairs(bench.seat_offsets_x) do
            local seat = part(
                "RestSeat_" .. index .. "_" .. column,
                seatSize,
                cf * C.new(offset, bench.seat_top_height - seatSize.Y / 2, 0),
                "seat",
                Enum.Material.Wood,
                true,
                "Seat"
            )
            seat.CanTouch = true
            seat.Disabled = false
            seat:SetAttribute("RestSeat", true)
            seats += 1
        end
    end
    for _, bay in ipairs(cfg.pet_bays) do
        local marker = part(
            bay.name,
            V.new(bay.size[1], 1, bay.size[2]),
            C.new(center + V.new(unpack(bay.offset))),
            "stone",
            Enum.Material.SmoothPlastic
        )
        marker.Transparency = 1
        marker:SetAttribute("DisplayOnly", true)
        marker:SetAttribute("AutomaticPetPlacement", false)
    end
    local cache = storage:FindFirstChild(cfg.flora.cache)
    if cache then
        for _, item in ipairs(cfg.flora.entries) do
            local template = cache:FindFirstChild(item.name)
            if template and template:IsA("Model") then
                local model = template:Clone()
                model.Name, model.Parent = item.display_name or "ShelterFlower", root
                local _, size = model:GetBoundingBox()
                model:ScaleTo(
                    model:GetScale()
                        * math.min(
                            item.height / size.Y,
                            (item.max_width or cfg.flora.max_width) / math.max(size.X, size.Z)
                        )
                )
                for _, child in ipairs(model:GetDescendants()) do
                    if child:IsA("BasePart") then
                        child.Anchored, child.CanCollide, child.CanTouch, child.CanQuery =
                            true, false, false, false
                    elseif child:IsA("LuaSourceContainer") or child:IsA("ProximityPrompt") then
                        child:Destroy()
                    end
                end
                local position = center + V.new(unpack(item.offset))
                model:PivotTo(C.new(position))
                local box, bounds = model:GetBoundingBox()
                if item.backdrop then
                    -- The entire visible canopy remains behind the roof and main path.
                    model:PivotTo(
                        model:GetPivot()
                            + V.new(position.X - box.Position.X, 0, position.Z - box.Position.Z)
                    )
                    box, bounds = model:GetBoundingBox()
                    assert(
                        box.Position.Z + bounds.Z / 2
                            <= center.Z - cfg.depth / 2 - cfg.flora.backdrop_rear_clearance,
                        "Backdrop intrudes on shelter roof"
                    )
                    model:SetAttribute("Backdrop", true)
                    model:SetAttribute("MeasuredHeight", bounds.Y)
                end
                model:PivotTo(
                    model:GetPivot()
                        + V.new(
                            0,
                            ground(position.X, position.Z)
                                - cfg.flora.embed
                                - (box.Position.Y - bounds.Y / 2),
                            0
                        )
                )
            end
        end
    end
    -- Ten-stud nominal dry spur; authored Terrain grid makes its material edge approximate.
    local spur = cfg.spur
    local region = Region3.new(
        V.new(spur.x_min, spur.y_min, spur.z_min),
        V.new(spur.x_max, spur.y_max, spur.z_max)
    ):ExpandToGrid(spur.resolution)
    local minimum = region.CFrame.Position - region.Size / 2
    local channels = terrain:ReadVoxelChannels(
        region,
        spur.resolution,
        { "SolidMaterial", "SolidOccupancy", "LiquidOccupancy" }
    )
    local materials, solid, liquid =
        channels.SolidMaterial, channels.SolidOccupancy, channels.LiquidOccupancy
    local edited = {}
    for ix = 1, #materials do
        for iz = 1, #materials[ix][1] do
            local x, z =
                minimum.X + (ix - 0.5) * spur.resolution, minimum.Z + (iz - 0.5) * spur.resolution
            if x >= spur.x_min and x <= spur.x_max and z >= spur.z_min and z <= spur.z_max then
                local dry = true
                local half = spur.resolution / 2 - spur.sample_inset
                for _, dx in ipairs({ -half, 0, half }) do
                    for _, dz in ipairs({ -half, 0, half }) do
                        local hit = workspace:Raycast(
                            V.new(x + dx, cfg.survey.ray_y, z + dz),
                            V.new(0, -cfg.survey.ray_depth, 0),
                            ray
                        )
                        if
                            not hit
                            or hit.Material == Enum.Material.Water
                            or hit.Position.Y < spur.height_min
                            or hit.Position.Y > spur.height_max
                        then
                            dry = false
                        end
                    end
                end
                local index, wet
                for y = 1, #solid[ix] do
                    if solid[ix][y][iz] > 0 then
                        index = y
                    end
                    if liquid[ix][y][iz] > 0 then
                        wet = true
                    end
                end
                if
                    dry
                    and not wet
                    and index
                    and table.find(spur.allowed_materials, materials[ix][index][iz].Name)
                    and materials[ix][index][iz] ~= Enum.Material[spur.material]
                then
                    table.insert(edited, {
                        minimum.X / spur.resolution + ix - 1,
                        minimum.Y / spur.resolution + index - 1,
                        minimum.Z / spur.resolution + iz - 1,
                        materials[ix][index][iz].Name,
                    })
                    materials[ix][index][iz] = Enum.Material[spur.material]
                end
            end
        end
    end
    local backup = storage:FindFirstChild(cfg.backup)
    if not backup then
        backup = Instance.new("Folder")
        backup.Name, backup.Parent = cfg.backup, storage
    end
    local saved = backup:FindFirstChild("OriginalMaterialCells")
    if not saved then
        saved = Instance.new("StringValue")
        saved.Name, saved.Value, saved.Parent = "OriginalMaterialCells", "[]", backup
    end
    local http = game:GetService("HttpService")
    local previous = http:JSONDecode(saved.Value)
    for _, cell in ipairs(edited) do
        table.insert(previous, cell)
    end
    saved.Value = http:JSONEncode(previous)
    terrain:WriteVoxelChannels(region, spur.resolution, { SolidMaterial = materials })
    local after =
        terrain:ReadVoxelChannels(region, spur.resolution, { "SolidOccupancy", "LiquidOccupancy" })
    for x = 1, #solid do
        for y = 1, #solid[x] do
            for z = 1, #solid[x][y] do
                assert(
                    after.SolidOccupancy[x][y][z] == solid[x][y][z],
                    "Shelter changed solid occupancy"
                )
                assert(
                    after.LiquidOccupancy[x][y][z] == liquid[x][y][z],
                    "Shelter changed water occupancy"
                )
            end
        end
    end
    return {
        seats = seats,
        roofTopY = roofY(0) + roof.thickness / 2,
        materialCells = #edited,
        occupancyVerifiedUnchanged = true,
    }
end
