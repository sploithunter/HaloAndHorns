-- Native architecture only; keeps all field/pond/egg/title geometry and transforms intact.
return function(world, cfg)
    assert(not game:GetService("RunService"):IsRunning(), "Stop Play before garden polish")
    assert(world and world:IsA("Model"), "Pass the existing RealmCrossroadsR4 Model")
    local activities = world:FindFirstChild(cfg.activity_root)
    local garden = activities and activities:FindFirstChild(cfg.garden_name)
    assert(garden, "Missing authored CoinGarden")
    local floor = garden:FindFirstChild("PavilionFloor")
    local title = garden:FindFirstChild("EggTitlePanel")
    local egg = garden:FindFirstChild("wayfinder_egg")
    local stand = garden:FindFirstChild("hall_egg_stand")
    assert(
        floor and floor:IsA("BasePart") and title and title:IsA("BasePart"),
        "Missing pavilion floor/title"
    )
    assert(egg and stand, "Native egg and stand must remain present")
    local V, C = Vector3, CFrame
    local origin = C.new(unpack(cfg.center))
    local palette = {}
    for key, rgb in pairs(cfg.palette) do
        palette[key] = Color3.fromRGB(unpack(rgb))
    end
    local stats = { seats = 0, nativePlants = 0, replaced = 0, warnings = {} }
    local out = Instance.new("Model")
    out.Name = cfg.output_name .. "Preparing"
    out.Parent = workspace
    local function part(name, size, cf, color, material, collide, class)
        local p = Instance.new(class or "Part")
        p.Name = name
        p.Size = V.new(unpack(size))
        p.CFrame = cf
        p.Anchored = true
        p.CanCollide = collide == true
        p.CanQuery = collide == true
        p.CanTouch = class == "Seat"
        p.CastShadow = false
        p.Color = palette[color]
        p.Material = Enum.Material[material or "Limestone"]
        p.TopSurface = Enum.SurfaceType.Smooth
        p.BottomSurface = Enum.SurfaceType.Smooth
        p.Parent = out
        return p
    end
    local function beam(name, p, q, width, depth, color, material)
        return part(
            name,
            { width, depth, (p - q).Magnitude },
            C.lookAt((p + q) / 2, q),
            color,
            material
        )
    end
    local function nativeAsset(spec, base, side)
        local template
        for _, folderName in ipairs(cfg.asset_caches) do
            local folder = game:GetService("ServerStorage"):FindFirstChild(folderName)
            if folder then
                template = folder:FindFirstChild(spec.model)
                if template then
                    break
                end
            end
        end
        if not template or not template:IsA("Model") then
            table.insert(
                stats.warnings,
                "Native cache missing model " .. spec.model .. "; no substitute generated"
            )
            return
        end
        local m = template:Clone()
        m.Name = "GardenNative_" .. spec.model
        for _, item in ipairs(m:GetDescendants()) do
            for _, tag in ipairs(game:GetService("CollectionService"):GetTags(item)) do
                game:GetService("CollectionService"):RemoveTag(item, tag)
            end
            if item:IsA("BasePart") then
                item.Anchored = true
                item.CanCollide = false
                item.CanTouch = false
                item.CanQuery = false
            elseif
                item:IsA("LuaSourceContainer")
                or item:IsA("ProximityPrompt")
                or item:IsA("LayerCollector")
            then
                item:Destroy()
            end
        end
        for _, tag in ipairs(game:GetService("CollectionService"):GetTags(m)) do
            game:GetService("CollectionService"):RemoveTag(m, tag)
        end
        m:PivotTo(C.new())
        local height = m:GetExtentsSize().Y
        if height <= 0 then
            m:Destroy()
            table.insert(stats.warnings, "Empty native model " .. spec.model)
            return
        end
        m:ScaleTo(m:GetScale() * spec.height / height)
        local extent = m:GetExtentsSize()
        local fit =
            math.min(1, cfg.beds.max_plant_width / extent.X, cfg.beds.max_plant_depth / extent.Z)
        m:ScaleTo(m:GetScale() * fit)
        local box, size = m:GetBoundingBox()
        local foot = C.new(box.Position.X, box.Position.Y - size.Y / 2, box.Position.Z)
        m:PivotTo(
            base
                * C.new(spec.offset[1] * side, spec.offset[2], spec.offset[3])
                * C.Angles(0, math.rad(spec.yaw * side), 0)
                * foot:Inverse()
                * m:GetPivot()
        )
        m:SetAttribute("PreviewOnly", true)
        m.Parent = out
        stats.nativePlants += 1
    end
    local ok, err = pcall(function()
        local col = cfg.columns
        for _, sx in ipairs({ -1, 1 }) do
            for _, sz in ipairs({ -1, 1 }) do
                local base = origin * C.new(sx * col.x, cfg.floor_offset, sz * col.z)
                part(
                    "PavilionPlinth",
                    col.base_size,
                    base * C.new(0, col.base_size[2] / 2, 0),
                    "stone",
                    nil,
                    true
                )
                part(
                    "PavilionPlinthUpper",
                    col.plinth_size,
                    base * C.new(0, col.plinth_y, 0),
                    "light"
                )
                part(
                    "PavilionShaft",
                    { col.shaft_width, col.shaft_height, col.shaft_width },
                    base * C.new(0, col.shaft_bottom + col.shaft_height / 2, 0),
                    "light",
                    nil,
                    true
                )
                for _, y in ipairs(col.collar_ys) do
                    part("PavilionCollar", col.collar_size, base * C.new(0, y, 0), "gold", "Metal")
                end
                part(
                    "PavilionCapital",
                    col.capital_size,
                    base * C.new(0, col.capital_y, 0),
                    "stone"
                )
                local bracketStart =
                    base:PointToWorldSpace(V.new(0, col.capital_y - cfg.brackets.drop, 0))
                local bracketEnd =
                    base:PointToWorldSpace(V.new(-sx * cfg.brackets.inset, col.capital_y, 0))
                beam(
                    "CarvedDiagonalBracket",
                    bracketStart,
                    bracketEnd,
                    cfg.brackets.width,
                    cfg.brackets.depth,
                    "dark_gold",
                    "Metal"
                )
            end
        end
        -- One elliptical arch profile, cloned to front/back. Boolean helpers are destroyed.
        local a = cfg.arch
        local archCF = origin * C.new(0, a.spring_y, 0)
        local outer = part(
            "ArchOuterTemporary",
            { a.depth, a.half_width * 2, a.half_width * 2 },
            archCF * C.Angles(0, math.pi / 2, 0),
            "light"
        )
        outer.Shape = Enum.PartType.Cylinder
        local inner = part(
            "ArchInnerTemporary",
            { a.cutter_depth, a.inner_half_width * 2, a.inner_half_width * 2 },
            archCF
                * C.new(0, a.inner_rise / a.rise * a.half_width - a.inner_half_width, 0)
                * C.Angles(0, math.pi / 2, 0),
            "light"
        )
        inner.Shape = Enum.PartType.Cylinder
        local below = part(
            "ArchLowerTemporary",
            a.lower_cutter_size,
            archCF * C.new(0, -a.lower_cutter_size[2] / 2, 0),
            "light"
        )
        local arch = outer:SubtractAsync({ inner, below }, Enum.CollisionFidelity.Hull)
        arch.Name = "SculptedArchFront"
        arch.Anchored = true
        arch.CanCollide = false
        arch.CanQuery = false
        arch.CanTouch = false
        arch.UsePartColor = true
        arch.Color = palette.light
        -- Cylinder CSG ignores an elliptical primitive cross-section. Cut circles first,
        -- then flatten the resulting union, preserving its exact supported spring line.
        arch.Size = V.new(a.depth, a.rise, a.half_width * 2)
        arch.CFrame = origin
            * C.new(0, a.spring_y + a.rise / 2, a.z_offsets[2])
            * C.Angles(0, math.pi / 2, 0)
        arch.Parent = out
        local rear = arch:Clone()
        rear.Name = "SculptedArchRear"
        rear.CFrame += V.new(0, 0, a.z_offsets[1] - a.z_offsets[2])
        rear.Parent = out
        outer:Destroy()
        inner:Destroy()
        below:Destroy()
        local h = cfg.halo
        local haloCF = origin * C.new(0, h.center_y, 0)
        local haloOuter = part(
            "HaloOuterTemporary",
            { h.thickness, h.radius * 2, h.radius * 2 },
            haloCF * C.Angles(0, 0, math.pi / 2),
            "gold",
            "Metal"
        )
        haloOuter.Shape = Enum.PartType.Cylinder
        local haloInner = part(
            "HaloInnerTemporary",
            { a.cutter_depth, h.inner_radius * 2, h.inner_radius * 2 },
            haloCF * C.Angles(0, 0, math.pi / 2),
            "gold",
            "Metal"
        )
        haloInner.Shape = Enum.PartType.Cylinder
        local halo = haloOuter:SubtractAsync({ haloInner }, Enum.CollisionFidelity.Hull)
        halo.Name = "OpenCelestialHalo"
        halo.Anchored = true
        halo.CanCollide = false
        halo.CanQuery = false
        halo.CanTouch = false
        halo.UsePartColor = true
        halo.Color = palette.gold
        halo.Material = Enum.Material.Metal
        halo.Parent = out
        haloOuter:Destroy()
        haloInner:Destroy()
        for _, sign in ipairs({ -1, 1 }) do
            beam(
                "HaloStructuralSupport",
                origin:PointToWorldSpace(
                    V.new(0, a.spring_y + a.rise, sign * math.abs(a.z_offsets[1]))
                ),
                origin:PointToWorldSpace(V.new(0, h.center_y, sign * h.support_z)),
                h.support_width,
                h.support_depth,
                "gold",
                "Metal"
            )
        end
        local t = cfg.title_frame
        for _, sign in ipairs({ -1, 1 }) do
            part(
                "TitleSideReveal",
                t.side_size,
                title.CFrame * C.new(sign * t.half_width, 0, 0),
                "stone"
            )
        end
        part(
            "TitleLowerReveal",
            t.lower_size,
            title.CFrame * C.new(0, t.lower_y, 0),
            "gold",
            "Metal"
        )
        part("TitleUpperReveal", t.top_size, title.CFrame * C.new(0, t.top_y, 0), "gold", "Metal")
        -- Native planting remains in the pavilion's outer wings, north of the lawn.
        local bed = cfg.beds
        for _, x in ipairs(bed.x_offsets) do
            local base = origin * C.new(x, cfg.floor_offset, 0)
            local halfX, halfZ = bed.size[1] / 2, bed.size[3] / 2
            local top = bed.size[2]
            local wallHeight = top
            for _, sign in ipairs({ -1, 1 }) do
                part(
                    "FlowerBedLongWall",
                    { bed.rim_width, wallHeight, bed.size[3] },
                    base * C.new(sign * (halfX - bed.rim_width / 2), wallHeight / 2, 0),
                    "stone",
                    nil,
                    true
                )
                part(
                    "FlowerBedEndWall",
                    { bed.size[1] - 2 * bed.rim_width, wallHeight, bed.rim_width },
                    base * C.new(0, wallHeight / 2, sign * (halfZ - bed.rim_width / 2)),
                    "stone",
                    nil,
                    true
                )
            end
            -- Soil has its own interior footprint and recessed top: no doubled flat faces.
            part("FlowerBedSoil", {
                bed.size[1] - 2 * bed.rim_width,
                top - bed.soil_drop,
                bed.size[3] - 2 * bed.rim_width,
            }, base * C.new(0, (top - bed.soil_drop) / 2, 0), "soil", "Ground")
            for _, spec in ipairs(bed.asset_specs) do
                nativeAsset(spec, base * C.new(0, top - bed.soil_drop, 0), x < 0 and -1 or 1)
            end
        end
        local s = cfg.seats
        for _, x in ipairs(s.x_offsets) do
            local base = origin
                * C.new(x, cfg.floor_offset + s.seat_height, s.z)
                * C.Angles(0, math.rad(s.yaw), 0)
            local seat = part("VisitorSeat", s.size, base, "wood", "Wood", true, "Seat")
            seat.Disabled = false
            seat:SetAttribute("PreviewOnly", true)
            for _, sx in ipairs({ -1, 1 }) do
                for _, sz in ipairs({ -1, 1 }) do
                    part(
                        "SeatLeg",
                        s.foot_size,
                        base
                            * C.new(
                                sx * s.foot_x,
                                -s.size[2] / 2 - s.foot_size[2] / 2,
                                sz * s.foot_z
                            ),
                        "stone"
                    )
                end
            end
            part("SeatBack", s.back_size, base * C.new(0, s.back_y, s.back_z), "stone")
            stats.seats += 1
        end
        local p = cfg.prompt
        local host = part(
            "WeeklyEggPresentationHost",
            p.host_size,
            origin * C.new(unpack(p.host_offset)),
            "light"
        )
        host.Transparency = 1
        host:SetAttribute("IntendedBinding", "WeeklyEggInspectPreview")
        host:SetAttribute("GameplayConnected", false)
        host:SetAttribute("PreviewOnly", true)
        local prompt = Instance.new("ProximityPrompt")
        prompt.Name = p.name
        prompt.ActionText = p.action
        prompt.ObjectText = p.object
        prompt.MaxActivationDistance = p.range
        prompt.HoldDuration = p.hold
        prompt.Enabled = false
        prompt.Parent = host
        for name, offset in pairs({
            PresentationCamera = p.camera_offset,
            PresentationFocus = p.focus_offset,
        }) do
            local attachment = Instance.new("Attachment")
            attachment.Name = name
            attachment.CFrame = host.CFrame:ToObjectSpace(origin * C.new(unpack(offset)))
            attachment.Parent = host
        end
    end)
    if not ok then
        out:Destroy()
        error("Garden polish preparation failed; original pergola retained: " .. tostring(err))
    end
    -- Commit only when the complete replacement exists. Store originals outside Workspace.
    local storage = game:GetService("ServerStorage")
    local backup = storage:FindFirstChild(cfg.backup_name)
    if not backup then
        backup = Instance.new("Folder")
        backup.Name = cfg.backup_name
        backup.Parent = storage
    end
    local replace = {}
    for _, name in ipairs(cfg.replace_names) do
        replace[name] = true
    end
    for _, item in ipairs(garden:GetChildren()) do
        if replace[item.Name] then
            item.Parent = backup
            stats.replaced += 1
        end
    end
    local old = garden:FindFirstChild(cfg.output_name)
    if old then
        old:Destroy()
    end
    out.Name = cfg.output_name
    out:SetAttribute("PreviewOnly", true)
    out:SetAttribute("GameplayConnected", false)
    out:SetAttribute("ArtRevision", cfg.revision)
    out.Parent = garden
    return stats
end
