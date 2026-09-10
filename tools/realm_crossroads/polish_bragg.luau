-- Edit-only authored art; source instances retain their stable podium/board identities.
return function(world, cfg)
    assert(not game:GetService("RunService"):IsRunning(), "Stop Play before Bragg polish")
    assert(world and world:IsA("Model"), "Pass the existing RealmCrossroadsR4 Model")
    local root = world:FindFirstChild(cfg.root_name)
    assert(root and root:IsA("Model"), "Missing authored Bragg root")
    local bays = root:FindFirstChild("PodiumAlcoves")
    local floors = root:FindFirstChild("TerraceAndEntry")
    assert(bays and floors, "Bragg requires PodiumAlcoves and TerraceAndEntry")
    local V, C = Vector3, CFrame
    local colors = {}
    for key, value in pairs(cfg.palette) do
        colors[key] = Color3.fromRGB(unpack(value))
    end
    local backup = root:FindFirstChild(cfg.backup_name)
    if not backup then
        backup = Instance.new("Folder")
        backup.Name = cfg.backup_name
        backup.Parent = root
    end
    -- Only actual replaced floor parts are cloned. Material edits retain originals as attributes.
    local function remember(p)
        if p:GetAttribute("BraggOriginalColor") == nil then
            p:SetAttribute("BraggOriginalColor", p.Color)
            p:SetAttribute("BraggOriginalMaterial", p.Material.Name)
        end
    end
    local function recolor(p, key, material)
        if p and p:IsA("BasePart") then
            remember(p)
            p.Color = colors[key]
            p.Material = Enum.Material[material or "Limestone"]
        end
    end
    local function part(parent, name, size, cf, key, material, collide)
        local p = Instance.new("Part")
        p.Name = name
        p.Size = V.new(unpack(size))
        p.CFrame = cf
        p.Anchored = true
        p.CanCollide = collide == true
        p.CanQuery = collide == true
        p.CanTouch = false
        p.CastShadow = false
        p.Material = Enum.Material[material or "Limestone"]
        p.Color = colors[key]
        p.TopSurface = Enum.SurfaceType.Smooth
        p.BottomSurface = Enum.SurfaceType.Smooth
        p.Parent = parent
        return p
    end
    local stats = { figures = 0, bays = 0, cornerClosures = 0, floor = "disabled", warnings = {} }
    local floorResult, runnerResult, innerCourtResult
    local sourceFloor = backup:FindFirstChild("OriginalCircularCourt")
        or floors:FindFirstChild("CircularCourt")
    if cfg.floor.enabled then
        assert(
            sourceFloor and sourceFloor:IsA("BasePart"),
            "Missing CircularCourt; preserve floor names"
        )
        local temporary = Instance.new("Folder")
        temporary.Name = "BraggPolishCSGTemporary"
        temporary.Parent = workspace
        local function cylinder(name, radius, height)
            local p = part(
                temporary,
                name,
                { height, radius * 2, radius * 2 },
                C.new(unpack(cfg.floor.center)) * C.Angles(0, 0, math.pi / 2),
                "runner",
                "Limestone",
                false
            )
            p.Shape = Enum.PartType.Cylinder
            return p
        end
        -- All boolean work succeeds before any live floor is replaced. The inset and floor
        -- occupy disjoint volumes, with exactly matched tops: no coplanar layered decoration.
        local ok, err = pcall(function()
            -- Inner cutter extends beyond BOTH runner and tall outer cutter: no
            -- coincident top/bottom faces while creating the subtracting annulus.
            assert(
                cfg.floor.inner_cutter_height > cfg.floor.cutter_height,
                "Inner cut must exceed outer height"
            )
            local outer = cylinder("RunnerOuter", cfg.floor.outer_radius, cfg.floor.thickness)
            local inner =
                cylinder("RunnerInner", cfg.floor.inner_radius, cfg.floor.inner_cutter_height)
            runnerResult =
                outer:SubtractAsync({ inner }, Enum.CollisionFidelity.PreciseConvexDecomposition)
            runnerResult.Parent = temporary
            local cutterOuter =
                cylinder("CutOuter", cfg.floor.outer_radius, cfg.floor.cutter_height)
            -- Separate connected solids avoid collision bridges between a combined
            -- inner disk and outer court. Both interfaces use the same CSG cylinders.
            floorResult = sourceFloor:SubtractAsync(
                { cutterOuter },
                Enum.CollisionFidelity.PreciseConvexDecomposition
            )
            floorResult.Parent = temporary
            local innerSeed =
                cylinder("InnerCourtSeed", cfg.floor.inner_radius, cfg.floor.thickness)
            local interior = part(temporary, "InnerCourtBakeHelper", {
                cfg.floor.inner_radius / 4,
                cfg.floor.thickness / 2,
                cfg.floor.inner_radius / 4,
            }, C.new(unpack(cfg.floor.center)), "light_stone", "Limestone", false)
            -- A fully contained helper simply bakes the primitive into the same CSG
            -- representation as the adjoining cut, without adding external geometry.
            innerCourtResult = innerSeed:UnionAsync(
                { interior },
                Enum.CollisionFidelity.PreciseConvexDecomposition
            )
            innerCourtResult.Parent = temporary
        end)
        if not ok then
            temporary:Destroy()
            error("Bragg floor CSG failed before replacement: " .. tostring(err))
        end
        floorResult.Parent = nil
        runnerResult.Parent = nil
        innerCourtResult.Parent = nil
        temporary:Destroy()
    end
    local previous = root:FindFirstChild(cfg.output_name)
    if previous then
        previous:Destroy()
    end
    local out = Instance.new("Model")
    out.Name = cfg.output_name
    out:SetAttribute("PreviewOnly", cfg.preview_only)
    out:SetAttribute("ArtRevision", cfg.revision)
    out.Parent = root
    if floorResult then
        if not backup:FindFirstChild("OriginalCircularCourt") then
            local copy = sourceFloor:Clone()
            copy.Name = "OriginalCircularCourt"
            copy.Parent = backup
            -- A backup under Workspace must not render or collide.
            copy.Transparency = 1
            copy.CanCollide = false
            copy.CanQuery = false
            copy.CanTouch = false
        end
        local current = floors:FindFirstChild("CircularCourt")
        if current then
            current:Destroy()
        end
        floorResult.Name = "CircularCourt"
        floorResult.Transparency = 0
        floorResult.UsePartColor = true
        floorResult.Anchored = true
        floorResult.CanCollide = true
        floorResult.CanTouch = false
        floorResult.CanQuery = true
        floorResult.Color = colors.light_stone
        floorResult.Material = Enum.Material.Limestone
        floorResult.Parent = floors
        runnerResult.Name = "FittedViewingPromenade"
        runnerResult.UsePartColor = true
        runnerResult.Color = colors.runner
        runnerResult.Material = Enum.Material.Limestone
        runnerResult.Anchored = true
        runnerResult.CanCollide = true
        runnerResult.CanTouch = false
        runnerResult.CanQuery = true
        runnerResult.Parent = out
        innerCourtResult.Name = "FittedInnerCourt"
        innerCourtResult.UsePartColor = true
        innerCourtResult.Color = colors.light_stone
        innerCourtResult.Material = Enum.Material.Limestone
        innerCourtResult.Anchored = true
        innerCourtResult.CanCollide = true
        innerCourtResult.CanTouch = false
        innerCourtResult.CanQuery = true
        innerCourtResult.Parent = out
        for _, p in ipairs(floors:GetChildren()) do
            if p.Name == "InnerInlay" or p.Name == "OuterInlay" then
                local copy = p:Clone()
                copy.Transparency = 1
                copy.CanCollide = false
                copy.CanQuery = false
                copy.CanTouch = false
                copy.Parent = backup
                p:Destroy()
            end
        end
        stats.floor = "three_disjoint_court_solids"
    end
    local a = cfg.architecture
    local indexed = {}
    for _, bay in ipairs(bays:GetChildren()) do
        local wall = bay:FindFirstChild("RearWall")
        local cornice = bay:FindFirstChild("Cornice")
        if wall and wall:IsA("BasePart") and cornice and cornice:IsA("BasePart") then
            stats.bays += 1
            local number = tonumber(string.match(bay.Name, "(%d+)$"))
            if number then
                indexed[number] = { wall = wall, cornice = cornice }
            end
            local decor = bay:FindFirstChild("RealmDecor")
            local isHell = decor and decor:GetAttribute("Theme") == "hell"
            recolor(wall, isHell and "hell_stone" or "stone")
            recolor(bay:FindFirstChild("WallInset"), isHell and "hell_stone" or "light_stone")
            recolor(cornice, "light_stone")
            for _, column in ipairs(bay:GetChildren()) do
                if column.Name == "Column" and column:IsA("BasePart") then
                    local bottom = column.Position.Y - column.Size.Y / 2
                    local baseCF = C.new(
                        column.Position.X,
                        bottom + a.column_base_size[2] / 2,
                        column.Position.Z
                    ) * column.CFrame.Rotation
                    part(out, bay.Name .. "_ColumnFoot", a.column_base_size, baseCF, "stone")
                    part(
                        out,
                        bay.Name .. "_ColumnCollar",
                        a.column_collar_size,
                        C.new(column.Position.X, bottom + a.collar_offset, column.Position.Z)
                            * column.CFrame.Rotation,
                        "bronze",
                        "Metal"
                    )
                end
            end
            for rank = 1, 3 do
                local podium = bay:FindFirstChild("Podium" .. rank)
                local cap = bay:FindFirstChild("PodiumCap" .. rank)
                if podium and podium:IsA("BasePart") then
                    recolor(podium, "stone")
                    recolor(cap, "rank" .. rank, "Metal")
                    local bottom = podium.Position.Y - podium.Size.Y / 2
                    part(
                        out,
                        bay.Name .. "_PodiumFoot" .. rank,
                        { cfg.podium.base_width, cfg.podium.base_height, cfg.podium.base_width },
                        C.new(
                            podium.Position.X,
                            bottom + cfg.podium.base_height / 2,
                            podium.Position.Z
                        ) * podium.CFrame.Rotation,
                        "bronze",
                        "Metal"
                    )
                    -- Existing numeral, cap and figure anchors remain untouched.
                    local anchor = Instance.new("Attachment")
                    anchor.Name = bay.Name .. "_Rank" .. rank .. "Anchor"
                    anchor.CFrame = podium.CFrame:ToObjectSpace(
                        cap and cap.CFrame * C.new(0, cap.Size.Y / 2, 0)
                            or podium.CFrame * C.new(0, podium.Size.Y / 2, 0)
                    )
                    anchor:SetAttribute("BoardId", bay:GetAttribute("BoardId") or "")
                    anchor:SetAttribute("Rank", rank)
                    anchor:SetAttribute("IntendedBinding", "LeaderboardDisplayOnly")
                    anchor:SetAttribute("PreviewOnly", true)
                    -- Store anchors under generated invisible hosts, not original podiums.
                    local host = part(
                        out,
                        anchor.Name .. "Host",
                        cfg.podium.anchor_host_size,
                        podium.CFrame,
                        "stone"
                    )
                    host.Transparency = 1
                    anchor.Parent = host
                end
            end
            if decor then
                local base = wall.CFrame * C.new(0, -wall.Size.Y / 2, a.wall_local_z)
                for _, sign in ipairs({ -1, 1 }) do
                    part(
                        out,
                        bay.Name .. "_ExhibitFoot",
                        cfg.exhibits.foot_size,
                        base
                            * C.new(
                                sign * cfg.exhibits.foot_x,
                                cfg.exhibits.foot_y,
                                cfg.exhibits.foot_z
                            ),
                        isHell and "hell_stone" or "stone"
                    )
                end
            end
        else
            table.insert(stats.warnings, "Skipped unsupported bay: " .. bay.Name)
        end
    end
    -- Only consecutive existing display bays, never the intentional entrance closure.
    for index = 1, a.bay_count - 1 do
        local left, right = indexed[index], indexed[index + 1]
        if left and right then
            local bestA, bestB, bestDistance
            for _, signA in ipairs({ -1, 1 }) do
                for _, signB in ipairs({ -1, 1 }) do
                    local p = left.wall.CFrame:PointToWorldSpace(
                        V.new(signA * a.wall_endpoint_half_span, 0, 0)
                    )
                    local q = right.wall.CFrame:PointToWorldSpace(
                        V.new(signB * a.wall_endpoint_half_span, 0, 0)
                    )
                    local distance = (p - q).Magnitude
                    if not bestDistance or distance < bestDistance then
                        bestA, bestB, bestDistance = p, q, distance
                    end
                end
            end
            if
                bestDistance
                and bestDistance > a.joint_end_clearance * 2
                and bestDistance < a.corner_max_gap
            then
                local center = (bestA + bestB) / 2
                local cf = C.lookAt(center, bestB)
                part(
                    out,
                    "RearCornerJoint" .. index,
                    { a.wall_depth, a.wall_height, bestDistance - a.joint_end_clearance * 2 },
                    cf,
                    "stone",
                    "Limestone",
                    true
                )
                local crownY = (left.cornice.Position.Y + right.cornice.Position.Y) / 2
                part(out, "SupportedCorniceJoint" .. index, {
                    a.connector_depth,
                    a.connector_height,
                    bestDistance - a.joint_end_clearance * 2,
                }, C.new(center.X, crownY, center.Z) * cf.Rotation, "light_stone")
                stats.cornerClosures += 1
            end
        end
    end
    local figureFolder = root:FindFirstChild(cfg.figures.folder_name)
    if figureFolder then
        for _, model in ipairs(figureFolder:GetChildren()) do
            if model:IsA("Model") then
                local body = model:FindFirstChildOfClass("BodyColors")
                if not body then
                    body = Instance.new("BodyColors")
                    body.Parent = model
                end
                for _, property in ipairs({
                    "HeadColor3",
                    "LeftArmColor3",
                    "RightArmColor3",
                    "LeftLegColor3",
                    "RightLegColor3",
                    "TorsoColor3",
                }) do
                    if body:GetAttribute("BraggOriginal_" .. property) == nil then
                        body:SetAttribute("BraggOriginal_" .. property, body[property])
                    end
                end
                body.HeadColor3 = colors.figure_skin
                body.LeftArmColor3 = colors.figure_hands
                body.RightArmColor3 = colors.figure_hands
                body.LeftLegColor3 = colors.figure_legs
                body.RightLegColor3 = colors.figure_legs
                body.TorsoColor3 = colors.figure_shirt
                for _, p in ipairs(model:GetDescendants()) do
                    if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
                        local key = "figure_shirt"
                        if p.Name == "Head" then
                            key = "figure_skin"
                        elseif string.find(p.Name, "Leg") or string.find(p.Name, "Foot") then
                            key = "figure_legs"
                        elseif string.find(p.Name, "Arm") or string.find(p.Name, "Hand") then
                            key = "figure_hands"
                        end
                        recolor(p, key, cfg.figures.body_material)
                    end
                end
                model:SetAttribute("PreviewOnly", true)
                stats.figures += 1
            end
        end
    end
    if stats.figures ~= cfg.figures.expected_count then
        table.insert(
            stats.warnings,
            "Expected " .. cfg.figures.expected_count .. " podium figures; found " .. stats.figures
        )
    end
    out:SetAttribute("FigureCount", stats.figures)
    return stats
end
