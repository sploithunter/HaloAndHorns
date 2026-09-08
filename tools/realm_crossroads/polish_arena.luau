-- Reversible Edit-only spectator craftsmanship pass. No live gameplay behavior.
return function(world, cfg)
    assert(not game:GetService("RunService"):IsRunning(), "Arena polish requires Edit mode")
    assert(not cfg.preview_only or game.PlaceId == 0, "Isolated preview only")
    local V, C = Vector3, CFrame
    local leisure = assert(world:FindFirstChild(cfg.leisure_root), "Missing leisure root")
    local stand = assert(leisure:FindFirstChild(cfg.stands), "Missing spectator stands")
    local arena = assert(world[cfg.activity_root]:FindFirstChild(cfg.arena), "Missing patrol arena")
    local storage = game:GetService("ServerStorage")
    local backup = storage:FindFirstChild(cfg.backup)
    if not backup then
        backup = Instance.new("Folder")
        backup.Name, backup.Parent = cfg.backup, storage
    end
    local function archived(name)
        local folder = backup:FindFirstChild(name)
        if not folder then
            folder = Instance.new("Folder")
            folder.Name, folder.Parent = name, backup
        end
        return folder
    end
    local function savePart(p, folder)
        p:SetAttribute("ArenaPolishOriginalParent", p.Parent:GetFullName())
        p.Parent = folder
    end
    local old = world:FindFirstChild(cfg.root)
    if old then
        old:Destroy()
    end
    local root = Instance.new("Model")
    root.Name, root.Parent = cfg.root, world
    root:SetAttribute("GameplayConnected", false)
    local colors = {}
    for name, value in pairs(cfg.palette) do
        colors[name] = Color3.fromRGB(unpack(value))
    end
    local function part(parent, name, size, cf, color, material, collide)
        local p = Instance.new("Part")
        p.Name, p.Size, p.CFrame = name, size, cf
        p.Color, p.Material = colors[color], material or Enum.Material.Slate
        p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow =
            true, collide == true, false, collide == true, false
        p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
        p.Parent = parent
        return p
    end
    local function group(name)
        local m = Instance.new("Model")
        m.Name, m.Parent = name, root
        return m
    end
    local chairs = archived("ChairVisuals")
    local steps = archived("Steps")
    local tiers = archived("RearTiers")
    local rails = archived("Rails")
    local ruin = archived("RuinMasonry")
    for _, p in ipairs(stand:GetChildren()) do
        if p:IsA("BasePart") then
            if p.Name == "ChairBack" or p.Name == "ChairLeg" or p.Name == "ArmRest" then
                savePart(p, chairs)
            elseif string.match(p.Name, "^AisleStep%d+$") then
                savePart(p, steps)
            elseif p.Name == "Tier4" then
                savePart(p, tiers)
            elseif
                p.Name == "EndRail"
                or p.Name == "RailPost"
                or p.Name == "RearRail"
                or p.Name == "RearPost"
            then
                savePart(p, rails)
            end
        end
    end
    for _, p in ipairs(arena:GetChildren()) do
        if
            p:IsA("BasePart")
            and (p.Name == "RuinPier" or p.Name == "RuinCap" or p.Name == "RearRuinWall")
        then
            savePart(p, ruin)
        end
    end
    local report = { seats = 0, enabledSeats = 0, steps = 0, facadeBays = 0, ornaments = 0 }
    local chairRoot = group("CraftedChairs")
    local q = cfg.chair
    for _, seat in ipairs(stand:GetChildren()) do
        if seat:IsA("Seat") then
            if seat:GetAttribute("ArenaPolishOriginalColor") == nil then
                seat:SetAttribute("ArenaPolishOriginalColor", seat.Color)
                seat:SetAttribute("ArenaPolishOriginalMaterial", seat.Material.Name)
            end
            seat.Color, seat.Material = colors.pad, Enum.Material.Fabric
            local shell = Instance.new("Model")
            shell.Name, shell.Parent = "Shell_" .. seat.Name, chairRoot
            shell:SetAttribute("PodiumSpectatorSlot", seat:GetAttribute("PodiumSpectatorSlot"))
            local cf = seat.CFrame
            local seatBottom = -seat.Size.Y / 2
            local legHeight = q.seat_height - seat.Size.Y / 2
            for _, side in ipairs({ -1, 1 }) do
                for _, front in ipairs({ -1, 1 }) do
                    part(
                        shell,
                        "GroundedLeg",
                        V.new(q.leg_width, legHeight, q.leg_width),
                        cf * C.new(side * q.leg_x, seatBottom - legHeight / 2, front * q.leg_z),
                        "metal",
                        Enum.Material.Metal
                    )
                end
                part(
                    shell,
                    "SeatFrameSide",
                    V.new(q.frame_width, q.frame_width, seat.Size.Z),
                    cf * C.new(side * (seat.Size.X + q.frame_width) / 2, seatBottom, 0),
                    "metal",
                    Enum.Material.Metal
                )
                part(
                    shell,
                    "ArmRest",
                    V.new(q.arm_width, q.arm_width, q.arm_length),
                    cf * C.new(side * q.arm_x, q.arm_y, 0),
                    "bronze",
                    Enum.Material.Metal
                )
                part(
                    shell,
                    "ArmSupport",
                    V.new(q.arm_width, q.arm_y, q.arm_width),
                    cf * C.new(side * q.arm_x, q.arm_y / 2, q.arm_length / 3),
                    "metal",
                    Enum.Material.Metal
                )
                part(
                    shell,
                    "BackUpright",
                    V.new(q.frame_width, q.back_height, q.back_depth),
                    cf
                        * C.new(
                            side * (q.back_width - q.frame_width) / 2,
                            q.back_height / 2,
                            q.back_z
                        ),
                    "metal",
                    Enum.Material.Metal
                )
                part(
                    shell,
                    "Fastener",
                    V.new(q.fastener_size, q.fastener_size, q.fastener_size),
                    cf
                        * C.new(
                            side * (q.back_width - q.frame_width) / 2,
                            q.back_height - q.frame_width,
                            q.back_z - q.back_depth / 2 - q.fastener_size / 2
                        ),
                    "bronze",
                    Enum.Material.Metal
                )
            end
            part(
                shell,
                "BackCushion",
                V.new(
                    q.back_width - 2 * q.frame_width,
                    q.back_height - 2 * q.frame_width,
                    q.back_depth - q.pad_inset
                ),
                cf * C.new(0, q.back_height / 2, q.back_z),
                "pad",
                Enum.Material.Fabric
            )
            for _, y in ipairs({ q.frame_width / 2, q.back_height - q.frame_width / 2 }) do
                part(
                    shell,
                    "BackCrossbar",
                    V.new(q.back_width - 2 * q.frame_width, q.frame_width, q.back_depth),
                    cf * C.new(0, y, q.back_z),
                    "metal",
                    Enum.Material.Metal
                )
            end
            part(
                shell,
                "SeatFrontFrame",
                V.new(seat.Size.X, q.frame_width, q.frame_width),
                cf * C.new(0, seatBottom, -(seat.Size.Z + q.frame_width) / 2),
                "bronze",
                Enum.Material.Metal
            )
            report.seats += 1
            if not seat.Disabled then
                report.enabledSeats += 1
            end
        end
    end
    assert(report.seats == q.expected_seats, "Unexpected spectator seat count")
    local stepRoot = group("CutNosingStairs")
    for _, original in ipairs(steps:GetChildren()) do
        local depth = cfg.steps.nosing_depth
        assert(original.Size.X > depth, "Step narrower than nosing")
        part(
            stepRoot,
            original.Name .. "Body",
            V.new(original.Size.X - depth, original.Size.Y, original.Size.Z),
            original.CFrame * C.new(depth / 2, 0, 0),
            "stone",
            Enum.Material.Slate,
            true
        )
        part(
            stepRoot,
            original.Name .. "Nose",
            V.new(depth, original.Size.Y, original.Size.Z),
            original.CFrame * C.new(-(original.Size.X - depth) / 2, 0, 0),
            "edge",
            Enum.Material.Limestone,
            true
        )
        report.steps += 1
    end
    local facade = group("RecessedRearFacade")
    local f = cfg.facade
    local cache = storage:FindFirstChild(f.ornament_cache)
    local ornament = cache and cache:FindFirstChild(f.ornament_name)
    for _, original in ipairs(tiers:GetChildren()) do
        local maxX = original.Position.X + original.Size.X / 2
        assert(maxX <= f.max_x, "Existing rear tier exceeds protected plane")
        part(
            facade,
            "RetainingCore",
            V.new(original.Size.X - f.skin_depth, original.Size.Y, original.Size.Z),
            original.CFrame * C.new(-f.skin_depth / 2, 0, 0),
            "stone",
            Enum.Material.Slate,
            true
        )
        local minY = original.Position.Y - original.Size.Y / 2
        local minZ = original.Position.Z - original.Size.Z / 2
        local skinX = maxX - f.skin_depth / 2
        part(
            facade,
            "Footing",
            V.new(f.skin_depth, f.footing_height, original.Size.Z),
            C.new(skinX, minY + f.footing_height / 2, original.Position.Z),
            "edge",
            Enum.Material.Slate,
            true
        )
        part(
            facade,
            "Cap",
            V.new(f.skin_depth, f.cap_height, original.Size.Z),
            C.new(skinX, minY + original.Size.Y - f.cap_height / 2, original.Position.Z),
            "edge",
            Enum.Material.Slate,
            true
        )
        local bodyHeight = original.Size.Y - f.footing_height - f.cap_height
        local bodyY = minY + f.footing_height + bodyHeight / 2
        local bayWidth = (original.Size.Z - (f.bays_per_tier + 1) * f.pier_width) / f.bays_per_tier
        for i = 0, f.bays_per_tier do
            part(
                facade,
                "EngagedPier",
                V.new(f.skin_depth, bodyHeight, f.pier_width),
                C.new(skinX, bodyY, minZ + f.pier_width / 2 + i * (bayWidth + f.pier_width)),
                "stone",
                Enum.Material.Slate,
                true
            )
        end
        for i = 1, f.bays_per_tier do
            local z = minZ + f.pier_width + (i - 1) * (bayWidth + f.pier_width) + bayWidth / 2
            for _, sign in ipairs({ -1, 1 }) do
                part(
                    facade,
                    "RecessedMasonryBay",
                    V.new(f.skin_depth - f.panel_recess, (bodyHeight - f.joint) / 2, bayWidth),
                    C.new(
                        maxX - f.skin_depth + (f.skin_depth - f.panel_recess) / 2,
                        bodyY + sign * (bodyHeight + f.joint) / 4,
                        z
                    ),
                    "panel",
                    Enum.Material.Slate,
                    true
                )
            end
            if ornament and ornament:IsA("Model") and i % 2 == 0 then
                local model = ornament:Clone()
                model.Name, model.Parent = "NativeSkullRelief", facade
                model:PivotTo(C.Angles(0, math.pi / 2, 0))
                local _, size = model:GetBoundingBox()
                model:ScaleTo(
                    model:GetScale()
                        * math.min(f.ornament_height / size.Y, f.ornament_depth / size.X)
                )
                for _, child in ipairs(model:GetDescendants()) do
                    if child:IsA("BasePart") then
                        child.Anchored, child.CanCollide, child.CanTouch, child.CanQuery =
                            true, false, false, false
                    elseif child:IsA("LuaSourceContainer") or child:IsA("ProximityPrompt") then
                        child:Destroy()
                    end
                end
                local box, bounds = model:GetBoundingBox()
                local target = V.new(maxX - f.ornament_face_margin - bounds.X / 2, bodyY, z)
                model:PivotTo(model:GetPivot() + target - box.Position)
                report.ornaments += 1
            end
            report.facadeBays += 1
        end
    end
    local railRoot = group("FinishedGuardRails")
    local r = cfg.rails
    for _, z in ipairs(r.end_z) do
        for i, x in ipairs(r.row_x) do
            local floor = r.row_top[i]
            for _, height in ipairs({ r.middle_height, r.height }) do
                part(
                    railRoot,
                    "EndRail",
                    V.new(r.row_depth - r.post_width, r.bar_width, r.bar_width),
                    C.new(x, floor + height, z),
                    "bronze",
                    Enum.Material.Metal,
                    true
                )
            end
            for _, sign in ipairs({ -1, 1 }) do
                part(
                    railRoot,
                    "EndPost",
                    V.new(r.post_width, r.height, r.post_width),
                    C.new(x + sign * (r.row_depth - r.post_width) / 2, floor + r.height / 2, z),
                    "metal",
                    Enum.Material.Metal,
                    true
                )
            end
        end
    end
    for _, height in ipairs({ r.middle_height, r.height }) do
        part(
            railRoot,
            "RearRail",
            V.new(r.bar_width, r.bar_width, r.rear_z_max - r.rear_z_min),
            C.new(r.rear_x, r.rear_top + height, (r.rear_z_min + r.rear_z_max) / 2),
            "bronze",
            Enum.Material.Metal,
            true
        )
    end
    for z = r.rear_z_min, r.rear_z_max, r.rear_post_step do
        part(
            railRoot,
            "RearPost",
            V.new(r.post_width, r.height, r.post_width),
            C.new(r.rear_x, r.rear_top + r.height / 2, z),
            "metal",
            Enum.Material.Metal,
            true
        )
    end
    local pavilion = group("EncounterMasonry")
    local p = cfg.pavilion
    local center = V.new(unpack(p.center))
    for _, dx in ipairs(p.pier_center_x_offsets) do
        local at = center + V.new(dx, 0, p.pier_z_offset)
        part(
            pavilion,
            "PierFoot",
            V.new(p.base_width, p.base_height, p.base_width),
            C.new(at + V.new(0, p.base_height / 2, 0)),
            "edge",
            Enum.Material.Limestone,
            true
        )
        local count = math.floor((p.pier_height - p.base_height) / p.course_height)
        local course = (p.pier_height - p.base_height) / count
        for i = 1, count do
            part(
                pavilion,
                "PierCourse",
                V.new(p.pier_width, course - p.joint, p.pier_width),
                C.new(at + V.new(0, p.base_height + (i - 0.5) * course, 0)),
                i % 2 == 0 and "panel" or "stone",
                Enum.Material.Slate,
                true
            )
        end
        part(
            pavilion,
            "PierCapital",
            V.new(p.cap_width, p.cap_height, p.cap_width),
            C.new(at + V.new(0, p.pier_height + p.cap_height / 2, 0)),
            "edge",
            Enum.Material.Limestone,
            true
        )
    end
    local rear = V.new(unpack(p.rear_wall_size))
    for i = 1, p.rear_bays do
        local width = rear.X / p.rear_bays
        part(
            pavilion,
            "RearWallBay",
            V.new(width - p.joint, rear.Y, rear.Z),
            C.new(
                center.X - rear.X / 2 + (i - 0.5) * width,
                center.Y + rear.Y / 2,
                center.Z + p.rear_wall_z_offset
            ),
            i % 2 == 0 and "stone" or "panel",
            Enum.Material.Slate,
            true
        )
    end
    for _, dx in ipairs(p.banner_base_offsets) do
        local size = V.new(unpack(p.banner_base_size))
        part(
            pavilion,
            "BannerFooting",
            size,
            C.new(center.X + dx, p.banner_floor + size.Y / 2, center.Z + p.banner_z_offset),
            "edge",
            Enum.Material.Slate,
            false
        )
    end
    for _, name in ipairs(p.banner_names) do
        local banner = arena:FindFirstChild(name)
        if banner and banner:IsA("Model") then
            local original = banner:GetAttribute("ArenaPolishOriginalPivot")
            if typeof(original) ~= "CFrame" then
                original = banner:GetPivot()
                banner:SetAttribute("ArenaPolishOriginalPivot", original)
            end
            banner:PivotTo(original + V.new(0, p.banner_base_size[2], 0))
        end
    end
    local anchors = group("IntegrationAnchors")
    for _, spec in ipairs(cfg.anchors) do
        local anchor = part(
            anchors,
            spec.name,
            V.one,
            C.new(unpack(spec.position)),
            "bronze",
            Enum.Material.Metal,
            false
        )
        anchor.Transparency = 1
        anchor:SetAttribute("IntendedBinding", spec.binding)
        anchor:SetAttribute("GameplayConnected", false)
        local attachment = Instance.new("Attachment")
        attachment.Name, attachment.Parent = spec.name, anchor
    end
    root:SetAttribute("NativeSeatCount", report.seats)
    root:SetAttribute("EnabledSeatCount", report.enabledSeats)
    root:SetAttribute("RearMaximumX", f.max_x)
    return report
end
