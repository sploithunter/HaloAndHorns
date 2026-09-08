-- Edit-authored disjoint floor inlay and a few native category sculptures. No title changes.
return function(world, cfg)
    assert(not game:GetService("RunService"):IsRunning(), "Stop Play before heraldry polish")
    local core = world and world:FindFirstChild(cfg.core_root)
    local seal = core and core:FindFirstChild(cfg.seal_root)
    local bragg = world and world:FindFirstChild(cfg.bragg_root)
    assert(seal and bragg, "Existing ArrivalSeal and Bragg required")
    local storage = game:GetService("ServerStorage")
    local backup = storage:FindFirstChild(cfg.backup_name)
    local original = seal:FindFirstChild(cfg.seal_inset)
        or (backup and backup:FindFirstChild(cfg.seal_inset))
    assert(original and original:IsA("BasePart"), "Missing original SealInset")
    local V, C = Vector3, CFrame
    local colors = {}
    for key, rgb in pairs(cfg.palette) do
        colors[key] = Color3.fromRGB(unpack(rgb))
    end
    local out = Instance.new("Model")
    out.Name = cfg.output_name .. "Preparing"
    out.Parent = workspace
    local stats = { sealParts = 0, emblems = 0, skipped = {} }
    local function part(name, size, cf, color, material)
        local p = Instance.new("Part")
        p.Name = name
        p.Size = V.new(unpack(size))
        p.CFrame = cf
        p.Color = colors[color]
        p.Material = Enum.Material[material or "Limestone"]
        p.Anchored = true
        p.CanCollide = false
        p.CanTouch = false
        p.CanQuery = false
        p.CastShadow = false
        p.Parent = out
        return p
    end
    local function finish(p, name, color, material, collide)
        p.Name = name
        p.Color = colors[color]
        p.Material = Enum.Material[material]
        p.Anchored = true
        p.CanCollide = collide
        p.CanQuery = collide
        p.CanTouch = false
        p.CastShadow = false
        p.UsePartColor = true
        p.Transparency = 0
        p.Parent = out
    end
    local function strippedClone(template)
        local m = template:Clone()
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
        return m
    end
    local ok, err = pcall(function()
        local s = cfg.seal
        local center = V.new(unpack(s.center))
        local cf = C.new(center)
        assert(
            (original.Position - center).Magnitude < s.thickness,
            "Seal datum changed; update heraldry config first"
        )
        local shapes = {}
        local function add(p)
            table.insert(shapes, p)
        end
        add(
            part(
                "CompassNorthSouth",
                { s.cross_width, s.thickness, s.cross_span },
                cf,
                "gold",
                "Metal"
            )
        )
        add(
            part(
                "CompassEastWest",
                { s.cross_span, s.thickness, s.cross_width },
                cf,
                "gold",
                "Metal"
            )
        )
        add(
            part(
                "CompassMeetingDiamond",
                { s.diamond_size, s.thickness, s.diamond_size },
                cf * C.Angles(0, math.pi / 4, 0),
                "gold",
                "Metal"
            )
        )
        local function stroke(points, name)
            local a = center + V.new(points[1][1], 0, points[1][2])
            local b = center + V.new(points[2][1], 0, points[2][2])
            add(
                part(
                    name,
                    { s.stroke_width, s.thickness, (a - b).Magnitude },
                    C.lookAt((a + b) / 2, b),
                    "gold",
                    "Metal"
                )
            )
        end
        for _, points in ipairs(s.feather_segments) do
            stroke(points, "HeavenFeatherStroke")
        end
        for _, points in ipairs(s.horn_segments) do
            stroke(points, "HellHornStroke")
        end
        for _, shape in ipairs(shapes) do
            for _, x in ipairs({ -1, 1 }) do
                for _, z in ipairs({ -1, 1 }) do
                    local corner = shape.CFrame:PointToWorldSpace(
                        V.new(x * shape.Size.X / 2, 0, z * shape.Size.Z / 2)
                    ) - center
                    assert(
                        V.new(corner.X, 0, corner.Z).Magnitude <= s.radius,
                        "Seal stroke exceeds inset footprint"
                    )
                end
            end
        end
        local first = table.remove(shapes, 1)
        local motif = first:UnionAsync(
            shapes,
            Enum.CollisionFidelity.PreciseConvexDecomposition,
            Enum.RenderFidelity.Precise
        )
        motif.Parent = out
        first:Destroy()
        for _, p in ipairs(shapes) do
            p:Destroy()
        end
        -- Every motif stroke was designed inside the radius. Verify actual union bounds too.
        local boxSize = motif.Size
        assert(boxSize.Magnitude > 0, "Empty compass motif")
        -- A full-depth cutter avoids residual coplanar skins on thin source disks.
        local motifCutter = motif:Clone()
        motifCutter.Name = "CompassCutTemporary"
        motifCutter.Size = V.new(motif.Size.X, s.cutter_height, motif.Size.Z)
        motifCutter.Parent = out
        local rest = original:SubtractAsync(
            { motifCutter },
            Enum.CollisionFidelity.PreciseConvexDecomposition,
            Enum.RenderFidelity.Precise
        )
        rest.Parent = out
        motifCutter:Destroy()
        local split = s.partition_size
        local eastCut = part("EastCutTemporary", split, cf * C.new(split[1] / 2, 0, 0), "hell")
        local westCut = part("WestCutTemporary", split, cf * C.new(-split[1] / 2, 0, 0), "heaven")
        local heaven = rest:SubtractAsync(
            { eastCut },
            Enum.CollisionFidelity.PreciseConvexDecomposition,
            Enum.RenderFidelity.Precise
        )
        heaven.Parent = out
        local hell = rest:SubtractAsync(
            { westCut },
            Enum.CollisionFidelity.PreciseConvexDecomposition,
            Enum.RenderFidelity.Precise
        )
        hell.Parent = out
        rest:Destroy()
        eastCut:Destroy()
        westCut:Destroy()
        finish(heaven, "SealHeavenStone", "heaven", "Limestone", true)
        finish(hell, "SealHellStone", "hell", "Slate", true)
        finish(motif, "SealCompassInlay", "gold", "Metal", true)
        stats.sealParts = 3
        local ec = cfg.emblems
        local bays = bragg:FindFirstChild("PodiumAlcoves")
        assert(bays, "Missing Bragg PodiumAlcoves")
        for _, spec in ipairs(ec.bindings) do
            local bay
            for _, b in ipairs(bays:GetChildren()) do
                if b:GetAttribute("BoardId") == spec.board_id then
                    bay = b
                    break
                end
            end
            local cornice = bay and bay:FindFirstChild("Cornice")
            local header = bay and bay:FindFirstChild("SculptedHeader")
            local template
            for _, folderName in ipairs(ec.caches) do
                local folder = storage:FindFirstChild(folderName)
                template = folder and folder:FindFirstChild(spec.model)
                if template then
                    break
                end
            end
            if
                not (
                    cornice
                    and cornice:IsA("BasePart")
                    and header
                    and template
                    and template:IsA("Model")
                )
            then
                table.insert(
                    stats.skipped,
                    spec.board_id .. ": missing semantic native asset or supported header/cornice"
                )
                continue
            end
            local corniceTop = cornice.Position.Y + cornice.Size.Y / 2
            local headerTop = -math.huge
            for _, p in ipairs(header:GetDescendants()) do
                if p:IsA("BasePart") then
                    local half = p.Size / 2
                    local cfPart = p.CFrame
                    local extent = math.abs(cfPart.RightVector.Y) * half.X
                        + math.abs(cfPart.UpVector.Y) * half.Y
                        + math.abs(cfPart.LookVector.Y) * half.Z
                    headerTop = math.max(headerTop, p.Position.Y + extent)
                end
            end
            if
                cornice.Size.X < ec.minimum_cornice_width
                or cornice.Size.Z < ec.minimum_cornice_depth
                or corniceTop < headerTop + ec.header_clearance
            then
                table.insert(stats.skipped, spec.board_id .. ": insufficient clear mount envelope")
                continue
            end
            local m = strippedClone(template)
            m:PivotTo(C.new())
            local size = m:GetExtentsSize()
            if size.X <= 0 or size.Y <= 0 or size.Z <= 0 then
                m:Destroy()
                table.insert(stats.skipped, spec.board_id .. ": empty native model")
                continue
            end
            local scale = math.min(ec.height / size.Y, ec.max_width / size.X, ec.max_depth / size.Z)
            if scale <= 0 or size.Magnitude <= 0 then
                m:Destroy()
                table.insert(stats.skipped, spec.board_id .. ": invalid native dimensions")
                continue
            end
            m:ScaleTo(m:GetScale() * scale)
            local box, extents = m:GetBoundingBox()
            local foot = C.new(box.Position.X, box.Position.Y - extents.Y / 2, box.Position.Z)
            local top = corniceTop + ec.base_size[2] + extents.Y
            if top > ec.max_top_y then
                m:Destroy()
                table.insert(stats.skipped, spec.board_id .. ": exceeds roof envelope")
                continue
            end
            local baseCF = C.new(cornice.Position.X, corniceTop, cornice.Position.Z)
                * cornice.CFrame.Rotation
            part(
                "EmblemBase_" .. spec.board_id,
                ec.base_size,
                baseCF * C.new(0, ec.base_size[2] / 2, 0),
                "stone"
            )
            m:PivotTo(
                baseCF
                    * C.new(0, ec.base_size[2], 0)
                    * C.Angles(0, math.rad(spec.yaw), 0)
                    * foot:Inverse()
                    * m:GetPivot()
            )
            m.Name = "NativeCategoryEmblem_" .. spec.board_id
            m:SetAttribute("BoardId", spec.board_id)
            m:SetAttribute("PreviewOnly", true)
            m:SetAttribute("SourceModelName", spec.model)
            m.Parent = out
            stats.emblems += 1
        end
    end)
    if not ok then
        out:Destroy()
        error("Heraldry preparation failed; existing inset retained: " .. tostring(err))
    end
    if not backup then
        backup = Instance.new("Folder")
        backup.Name = cfg.backup_name
        backup.Parent = storage
    end
    local current = seal:FindFirstChild(cfg.seal_inset)
    if current then
        local previousBackup = backup:FindFirstChild(cfg.seal_inset)
        if previousBackup then
            previousBackup:Destroy()
        end
        current.Parent = backup
    end
    local old = world:FindFirstChild(cfg.output_name)
    if old then
        old:Destroy()
    end
    out.Name = cfg.output_name
    out:SetAttribute("PreviewOnly", true)
    out:SetAttribute("ArtRevision", cfg.revision)
    out.Parent = world
    return stats
end
