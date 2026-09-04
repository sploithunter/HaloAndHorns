--[[
    MergeEggRealmBuilder -- authored-realm bake and runtime bay binding.

    Studio calls Bake exactly when an author wants to rebuild the editable five-by-two blockout.
    Runtime only adopts and validates that baked geometry, then owns transient server-local claims.
    Entering the realm must never regenerate, recolor, or reposition authored map Instances.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")

local MergeEggRealmLayout = require(ReplicatedStorage.Shared.Game.MergeEggRealmLayout)

local MergeEggRealmBuilder = {}
MergeEggRealmBuilder.__index = MergeEggRealmBuilder

local CLAIM_PROMPT = "MergeEggBayClaimPrompt"

local function color(value, fallback)
    value = type(value) == "table" and value or fallback or { 255, 255, 255 }
    return Color3.fromRGB(
        tonumber(value[1]) or 255,
        tonumber(value[2]) or 255,
        tonumber(value[3]) or 255
    )
end

local function firstPart(root, name)
    local found = root and root:FindFirstChild(tostring(name or ""), true)
    if found and found:IsA("BasePart") then
        return found
    end
    return found and found:FindFirstChildWhichIsA("BasePart", true) or nil
end

local function authoredClaimFixtures(model)
    local fixtures = {}
    local candidates = 0
    for _, descendant in ipairs(model:GetDescendants()) do
        if
            descendant:IsA("BasePart")
            and (
                descendant:GetAttribute("MergeEggBayClaimPad") == true
                or descendant.Name == "BayClaimPad"
            )
        then
            candidates += 1
            local prompt = descendant:FindFirstChild(CLAIM_PROMPT, true)
            local surface = descendant:FindFirstChild("BayClaimSurface", true)
            local label = surface and surface:FindFirstChild("Label", true)
            if
                not (prompt and prompt:IsA("ProximityPrompt") and label and label:IsA("TextLabel"))
            then
                return nil, "incomplete"
            end
            table.insert(fixtures, {
                pad = descendant,
                prompt = prompt,
                label = label,
            })
        end
    end
    if candidates == 0 then
        return nil, "missing"
    end
    table.sort(fixtures, function(left, right)
        if left.pad.Position.Y ~= right.pad.Position.Y then
            return left.pad.Position.Y > right.pad.Position.Y
        end
        return left.pad:GetFullName() < right.pad:GetFullName()
    end)
    return fixtures
end

local function makePart(parent, name, size, cframe, material, tint, transparency)
    local part = Instance.new("Part")
    part.Name = name
    part.Anchored = true
    part.CanCollide = true
    part.CanTouch = false
    part.CanQuery = true
    part.Size = size
    part.CFrame = cframe
    part.Material = material
    part.Color = tint
    part.Transparency = transparency or 0
    part.TopSurface = Enum.SurfaceType.Smooth
    part.BottomSurface = Enum.SurfaceType.Smooth
    part.Parent = parent
    return part
end

local function makeBeam(parent, name, fromPosition, toPosition, thickness, material, tint)
    local delta = toPosition - fromPosition
    local length = delta.Magnitude
    if length < 0.01 then
        return nil
    end
    return makePart(
        parent,
        name,
        Vector3.new(thickness, thickness, length),
        CFrame.lookAt((fromPosition + toPosition) * 0.5, toPosition),
        material,
        tint
    )
end

local function makeDisc(parent, name, diameter, height, position, material, tint, transparency)
    local disc = makePart(
        parent,
        name,
        Vector3.new(height, diameter, diameter),
        CFrame.new(position) * CFrame.Angles(0, 0, math.pi * 0.5),
        material,
        tint,
        transparency
    )
    disc.Shape = Enum.PartType.Cylinder
    return disc
end

local function sanitizeAsset(root)
    for _, descendant in ipairs(root:GetDescendants()) do
        if descendant:IsA("BasePart") then
            descendant.Anchored = true
            descendant.CanCollide = false
            descendant.CanTouch = false
            descendant.CanQuery = false
            descendant.Massless = true
        elseif
            descendant:IsA("Script")
            or descendant:IsA("LocalScript")
            or descendant:IsA("ModuleScript")
        then
            descendant:Destroy()
        end
    end
end

local function assetTemplate(name)
    local ModelTemplateStore = require(ReplicatedStorage.Shared.Utils.ModelTemplateStore)
    local models = ModelTemplateStore.root()
    local flora = models and models:FindFirstChild("Flora")
    local missionProps = ServerStorage:FindFirstChild("MissionProps")
        or ReplicatedStorage:FindFirstChild("MissionProps") -- migration-safe fallback
    return (flora and flora:FindFirstChild(name))
        or (missionProps and missionProps:FindFirstChild(name))
end

local function placeAsset(parent, assetName, target, targetHeight)
    local template = assetTemplate(assetName)
    if not template then
        return nil
    end
    local clone = template:Clone()
    if clone:IsA("BasePart") then
        local model = Instance.new("Model")
        clone.Parent = model
        model.PrimaryPart = clone
        clone = model
    end
    if not clone:IsA("Model") then
        clone:Destroy()
        return nil
    end
    sanitizeAsset(clone)
    local box, size = clone:GetBoundingBox()
    clone.WorldPivot = CFrame.new(box.Position)
    if tonumber(targetHeight) and size.Y > 0.01 then
        pcall(function()
            clone:ScaleTo(clone:GetScale() * math.clamp(targetHeight / size.Y, 0.15, 6))
        end)
        box, size = clone:GetBoundingBox()
        clone.WorldPivot = CFrame.new(box.Position)
    end
    clone.Name = "RealmDecor_" .. assetName
    clone.Parent = parent
    clone:PivotTo(target * CFrame.new(0, size.Y * 0.5, 0))
    local placed, placedSize = clone:GetBoundingBox()
    local bottom = placed.Position.Y - placedSize.Y * 0.5
    local floorY = target.Position.Y
    clone:PivotTo(clone:GetPivot() - Vector3.new(0, bottom - floorY, 0))
    return clone
end

local function addTopLabel(host, name, text, textColor)
    local surface = Instance.new("SurfaceGui")
    surface.Name = name
    surface.Face = Enum.NormalId.Top
    surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    surface.PixelsPerStud = 28
    surface.LightInfluence = 0
    surface.AlwaysOnTop = false
    surface.Parent = host
    local label = Instance.new("TextLabel")
    label.Name = "Label"
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamBlack
    label.Text = text
    label.TextColor3 = textColor
    label.TextScaled = true
    label.TextStrokeColor3 = Color3.new(0, 0, 0)
    label.TextStrokeTransparency = 0.25
    label.Parent = surface
    return label
end

local function ancestorMaps(instance)
    local current = instance
    while current do
        if current.Name == "Maps" and (current:IsA("Folder") or current:IsA("Model")) then
            return current
        end
        current = current.Parent
    end
    return Workspace:FindFirstChild("Maps")
end

local function removeBakedBayAdditions(model)
    local removals = {}
    for _, descendant in ipairs(model:GetDescendants()) do
        if
            descendant.Name == "RealmDecor"
            or descendant:GetAttribute("MergeEggBayClaimPad") == true
            or descendant.Name == "BayClaimPad"
        then
            table.insert(removals, descendant)
        end
    end
    for _, descendant in ipairs(removals) do
        if descendant.Parent then
            descendant:Destroy()
        end
    end
end

function MergeEggRealmBuilder.new(config, logger)
    local self = setmetatable({}, MergeEggRealmBuilder)
    self._config = type(config) == "table" and config or {}
    self._logger = logger
    self._bays = {}
    self._claimsByUserId = {}
    self._claimHandler = nil
    self._random = Random.new()
    return self
end

function MergeEggRealmBuilder:_log(level, message, data)
    if self._logger and self._logger[level] then
        self._logger[level](self._logger, message, data)
    end
end

function MergeEggRealmBuilder:_styleBay(model, bay)
    removeBakedBayAdditions(model)
    local theme = type(self._config.themes) == "table" and self._config.themes[bay.side] or {}
    theme = type(theme) == "table" and theme or {}
    local accent =
        color(theme.accent, bay.side == "heaven" and { 120, 225, 255 } or { 255, 65, 35 })
    local floor = firstPart(model, "LandStrip")
    local platform = firstPart(model, "StartPlatform")
    if floor then
        floor.Material = bay.side == "heaven" and Enum.Material.Limestone or Enum.Material.Basalt
        floor.Color =
            color(theme.floor, bay.side == "heaven" and { 178, 190, 198 } or { 50, 40, 48 })
    end
    if platform then
        platform.Material = bay.side == "heaven" and Enum.Material.Marble or Enum.Material.Slate
        platform.Color =
            color(theme.platform, bay.side == "heaven" and { 215, 225, 230 } or { 70, 45, 58 })
    end
    for _, name in ipairs({ "EastWall", "WestWall", "NorthEndWall", "SouthEndWall" }) do
        local wall = firstPart(model, name)
        if wall then
            wall.Material = Enum.Material.Rock
            wall.Color =
                color(theme.wall, bay.side == "heaven" and { 118, 137, 155 } or { 42, 29, 37 })
            if name == "EastWall" or name == "WestWall" then
                local visibleHeight =
                    math.max(1, tonumber(self._config.lane_visible_wall_height) or 4)
                local bottomY = wall.Position.Y - wall.Size.Y * 0.5
                wall.Size = Vector3.new(wall.Size.X, visibleHeight, wall.Size.Z)
                wall.CFrame = CFrame.new(
                    wall.Position.X,
                    bottomY + visibleHeight * 0.5,
                    wall.Position.Z
                ) * wall.CFrame.Rotation
                wall:SetAttribute("MergeEggLowSightlineWall", true)
            end
        end
    end
    -- The atomic lane's player-end cap becomes its public entrance in the multi-bay realm.
    local entranceWall = firstPart(model, "NorthEndWall")
    if entranceWall then
        entranceWall.Transparency = 1
        entranceWall.CanCollide = false
        entranceWall.CanTouch = false
        entranceWall.CanQuery = false
    end

    local decor = Instance.new("Folder")
    decor.Name = "RealmDecor"
    decor.Parent = model
    local anchor = floor and floor.CFrame or model:GetPivot()
    local assetSets = type(theme.asset_sets) == "table" and theme.asset_sets or {}
    local assets = type(assetSets[bay.column]) == "table" and assetSets[bay.column] or assetSets[1]
    assets = type(assets) == "table" and assets or {}
    local placements = {
        -- Decorations live outside the 96-stud playable lane. They fill the 16-stud seams
        -- between bays like Hull's bluffs without obscuring the merge board or pickups.
        { x = -58, z = -115, yaw = 25, height = 18 },
        { x = 58, z = -75, yaw = -30, height = 13 },
        { x = bay.column % 2 == 0 and -58 or 58, z = 72, yaw = 160, height = 16 },
    }
    for index, assetName in ipairs(assets) do
        local placement = placements[index]
        if placement and type(assetName) == "string" then
            placeAsset(
                decor,
                assetName,
                anchor
                    * CFrame.new(placement.x, floor and floor.Size.Y * 0.5 or 1, placement.z)
                    * CFrame.Angles(0, math.rad(placement.yaw), 0),
                placement.height
            )
        end
    end

    if floor then
        local mallDrop = math.max(4, tonumber(self._config.mall_drop) or 9)
        local foundation = makePart(
            decor,
            "BayTerraceFoundation",
            Vector3.new(floor.Size.X + 6, mallDrop, floor.Size.Z),
            floor.CFrame * CFrame.new(0, -floor.Size.Y * 0.5 - mallDrop * 0.5, 0),
            Enum.Material.Rock,
            accent:Lerp(Color3.new(0.12, 0.12, 0.15), 0.72)
        )
        foundation:SetAttribute("MergeEggBayFoundation", true)
        local boundaryHeight = math.max(8, tonumber(self._config.lane_boundary_height) or 22)
        local boundaryOffset =
            math.max(floor.Size.X * 0.5, tonumber(self._config.lane_boundary_offset) or 52)
        local boundaryExtension = math.max(0, tonumber(self._config.lane_boundary_extension) or 14)
        for side = -1, 1, 2 do
            local boundary = makePart(
                decor,
                side < 0 and "WestBoundaryInvisible" or "EastBoundaryInvisible",
                Vector3.new(1.5, boundaryHeight, floor.Size.Z + boundaryExtension),
                floor.CFrame
                    * CFrame.new(
                        side * boundaryOffset,
                        floor.Size.Y * 0.5 + boundaryHeight * 0.5,
                        -boundaryExtension * 0.5
                    ),
                Enum.Material.SmoothPlastic,
                Color3.new(1, 1, 1),
                1
            )
            boundary.CanQuery = false
            boundary:SetAttribute("MergeEggBayBoundary", true)
        end
        for side = -1, 1, 2 do
            makePart(
                decor,
                "BayEntrancePillar",
                Vector3.new(5, 16, 5),
                floor.CFrame * CFrame.new(side * 43, 8, -151),
                Enum.Material.Rock,
                accent:Lerp(Color3.new(0.12, 0.12, 0.15), 0.45)
            )
        end

        local trimTint = bay.side == "heaven" and Color3.fromRGB(113, 210, 235)
            or Color3.fromRGB(205, 105, 38)
        for side = -1, 1, 2 do
            local trim = makePart(
                decor,
                "BayPerimeterTrim",
                Vector3.new(0.8, 0.65, floor.Size.Z - 12),
                floor.CFrame
                    * CFrame.new(side * (floor.Size.X * 0.5 - 2.5), floor.Size.Y * 0.5 + 0.34, 0),
                Enum.Material.Metal,
                trimTint
            )
            trim:SetAttribute("MergeEggBayArchitecturalTrim", true)
        end

        -- Architecture only: gameplay still binds to the authored enemy portal hooks inside the
        -- bay. This visible gate makes the outer wall read as the enemy source from the mall.
        local gate = Instance.new("Model")
        gate.Name = "OuterSpawnGate"
        gate:SetAttribute("MergeEggOuterSpawnGate", true)
        gate.Parent = decor
        local gateZ = floor.Size.Z * 0.5 - 3
        local gateStone =
            color(theme.wall, bay.side == "heaven" and { 118, 137, 155 } or { 42, 29, 37 })
        for side = -1, 1, 2 do
            makePart(
                gate,
                "GateTower",
                Vector3.new(9, 28, 9),
                floor.CFrame * CFrame.new(side * 34, floor.Size.Y * 0.5 + 14, gateZ),
                Enum.Material.Rock,
                gateStone
            )
            makePart(
                gate,
                "GateFinial",
                Vector3.new(4.5, 7, 4.5),
                floor.CFrame * CFrame.new(side * 34, floor.Size.Y * 0.5 + 31.5, gateZ),
                Enum.Material.Neon,
                accent,
                0.08
            )
        end
        makePart(
            gate,
            "GateLintel",
            Vector3.new(77, 7, 9),
            floor.CFrame * CFrame.new(0, floor.Size.Y * 0.5 + 25, gateZ),
            Enum.Material.Rock,
            gateStone
        )
        local portal = makePart(
            gate,
            "GatePortal",
            Vector3.new(56, 19, 1),
            floor.CFrame * CFrame.new(0, floor.Size.Y * 0.5 + 10.5, gateZ - 0.3),
            Enum.Material.Neon,
            Color3.fromRGB(112, 43, 214),
            0.28
        )
        portal.CanCollide = false
        portal.CanQuery = false
    end

    local spawn = firstPart(model, "PlayerSpawn") or platform or floor
    if spawn then
        local towardArena =
            Vector3.new(floor.Position.X - spawn.Position.X, 0, floor.Position.Z - spawn.Position.Z)
        towardArena = towardArena.Magnitude > 0.01 and towardArena.Unit or spawn.CFrame.LookVector
        local right = Vector3.new(towardArena.Z, 0, -towardArena.X)
        local padPosition = spawn.Position + right * 15 - towardArena * 1
        local padCenterY = floor.Position.Y + floor.Size.Y * 0.5 + 0.2
        local pad = makePart(
            model,
            "BayClaimPad",
            Vector3.new(18, 0.4, 8),
            CFrame.lookAt(
                Vector3.new(padPosition.X, padCenterY, padPosition.Z),
                Vector3.new(padPosition.X, padCenterY, padPosition.Z) + towardArena
            ),
            Enum.Material.Neon,
            accent,
            0.15
        )
        pad.CanCollide = false
        pad:SetAttribute("MergeEggBayClaimPad", true)
        local label = addTopLabel(
            pad,
            "BayClaimSurface",
            string.upper(bay.displayName .. "\nAVAILABLE"),
            Color3.new(1, 1, 1)
        )
        local prompt = Instance.new("ProximityPrompt")
        prompt.Name = CLAIM_PROMPT
        prompt.ActionText = "Claim Bay"
        prompt.ObjectText = bay.displayName
        prompt.KeyboardKeyCode = Enum.KeyCode.E
        prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
        prompt.HoldDuration = 0.15
        prompt.MaxActivationDistance = 14
        prompt.RequiresLineOfSight = false
        prompt.Parent = pad
        -- Trigger connections are runtime state. They are attached when the authored realm is
        -- adopted, not persisted by the Edit-mode bake.
    end
end

function MergeEggRealmBuilder:_registerBay(model, bay)
    model:SetAttribute("MergeEggBayId", bay.id)
    model:SetAttribute("MergeEggBaySide", bay.side)
    model:SetAttribute("MergeEggBayColumn", bay.column)
    model:SetAttribute("MergeEggBayOwnerUserId", 0)
    model:SetAttribute("MergeEggBayOwnerName", nil)
    model:SetAttribute("MergeEggBayAvailable", true)

    local claimFixtures, fixtureReason = authoredClaimFixtures(model)
    if not claimFixtures then
        return nil, "authored_claim_fixture_" .. tostring(fixtureReason) .. ":" .. bay.id
    end

    local record = {
        descriptor = bay,
        model = model,
        ownerUserId = nil,
        claimFixtures = claimFixtures,
        -- Preserve the original aliases for callers that only need one wayfinding target.
        pad = claimFixtures[1].pad,
        label = claimFixtures[1].label,
        prompt = claimFixtures[1].prompt,
    }
    self._bays[bay.id] = record
    for _, fixture in ipairs(claimFixtures) do
        CollectionService:AddTag(fixture.prompt, CLAIM_PROMPT)
        fixture.prompt.Enabled = true
        fixture.prompt.ActionText = "Claim Bay"
        fixture.prompt.ObjectText = bay.displayName
        fixture.label.Text = string.upper(bay.displayName .. "\nAVAILABLE")
        fixture.prompt.Triggered:Connect(function(player)
            if self._claimHandler then
                self._claimHandler(player, bay.id)
            end
        end)
    end
    return record
end

-- Retained as a callable authoring comparison while the broad mall blockout is evaluated.
-- Bake uses `_buildHall` below; runtime never calls either authoring function.
function MergeEggRealmBuilder:_buildLegacyRiverHall(root)
    local config = self._config
    local centerX = tonumber(config.center_x) or -16000
    local centerZ = tonumber(config.center_z) or -325
    local y = tonumber(config.floor_y) or 1
    local perSide = math.max(1, math.floor(tonumber(config.bays_per_side) or 5))
    local length = math.max(96, (perSide - 1) * (tonumber(config.bay_pitch) or 112) + 108)
    local gap = math.max(64, tonumber(config.corridor_gap) or 96)
    local riverWidth =
        math.clamp(tonumber(config.river_width) or tonumber(config.rift_width) or 24, 10, gap - 30)
    local waveAmplitude = math.clamp(
        tonumber(config.river_wave_amplitude) or 4,
        0,
        math.max(0, (gap - riverWidth - 24) * 0.5)
    )
    local riverEnvelope = riverWidth + waveAmplitude * 2
    local promenadeWidth = (gap - riverEnvelope) * 0.5
    local hall = Instance.new("Model")
    hall.Name = "CentralHall"
    hall.Parent = root
    hall:SetAttribute("MergeEggCentralCommons", true)
    local heavenTint =
        color((config.themes or {}).heaven and config.themes.heaven.accent, { 120, 225, 255 })
    local hellTint =
        color((config.themes or {}).hell and config.themes.hell.accent, { 255, 65, 35 })

    local commons = Instance.new("Model")
    commons.Name = "RiverCommons"
    commons.Parent = hall
    makePart(
        commons,
        "HeavenGardenWalk",
        Vector3.new(length, 1, promenadeWidth),
        CFrame.new(centerX, y, centerZ + (riverEnvelope + promenadeWidth) * 0.5),
        Enum.Material.Marble,
        Color3.fromRGB(170, 184, 198)
    )
    makePart(
        commons,
        "HellGardenWalk",
        Vector3.new(length, 1, promenadeWidth),
        CFrame.new(centerX, y, centerZ - (riverEnvelope + promenadeWidth) * 0.5),
        Enum.Material.Basalt,
        Color3.fromRGB(55, 39, 48)
    )

    local river = Instance.new("Model")
    river.Name = "CentralRiver"
    river:SetAttribute("MergeEggRiverWidth", riverWidth)
    river:SetAttribute("MergeEggRiverWaveAmplitude", waveAmplitude)
    river.Parent = commons
    local riverSegments = math.max(8, math.floor(tonumber(config.river_segments) or 16))
    local segmentLength = length / riverSegments
    local waterColor = Color3.fromRGB(55, 154, 220)
    for index = 1, riverSegments do
        local t = (index - 0.5) / riverSegments
        local x = centerX - length * 0.5 + segmentLength * (index - 0.5)
        local z = centerZ + math.sin(t * math.pi * 3) * waveAmplitude
        local nextT = math.min(1, t + 0.01)
        local nextZ = centerZ + math.sin(nextT * math.pi * 3) * waveAmplitude
        local nextX = x + length * 0.01
        local angle = math.atan2(nextZ - z, nextX - x)
        local bed = makePart(
            river,
            string.format("RiverBed%02d", index),
            Vector3.new(segmentLength + 4, 1, riverWidth + 5),
            CFrame.new(x, y - 1.05, z) * CFrame.Angles(0, -angle, 0),
            Enum.Material.Slate,
            Color3.fromRGB(35, 61, 78)
        )
        bed.CanQuery = false
        bed:SetAttribute("MergeEggRiverBed", true)
        local water = makePart(
            river,
            string.format("RiverWater%02d", index),
            Vector3.new(segmentLength + 4.5, 0.45, riverWidth),
            CFrame.new(x, y - 0.35, z) * CFrame.Angles(0, -angle, 0),
            Enum.Material.Glass,
            waterColor,
            0.18
        )
        water.CanCollide = false
        water.CanQuery = false
        water:SetAttribute("MergeEggRiverWater", true)
    end

    local bridges = Instance.new("Model")
    bridges.Name = "Bridges"
    bridges.Parent = commons
    for column = 1, perSide do
        local x = centerX + (column - (perSide + 1) * 0.5) * (tonumber(config.bay_pitch) or 112)
        local bridge = makePart(
            bridges,
            "RiverBridge" .. column,
            Vector3.new(18, 0.9, riverEnvelope + 8),
            CFrame.new(x, y + 0.45, centerZ),
            Enum.Material.WoodPlanks,
            Color3.fromRGB(112, 91, 73)
        )
        local seam = makePart(
            bridges,
            "BridgeSeam" .. column,
            Vector3.new(1.2, 0.12, riverEnvelope + 5),
            bridge.CFrame * CFrame.new(0, 0.52, 0),
            Enum.Material.Neon,
            column % 2 == 0 and hellTint or heavenTint,
            0.05
        )
        seam.CanCollide = false
        for side = -1, 1, 2 do
            local rail = makePart(
                bridges,
                "BridgeRail" .. column,
                Vector3.new(0.65, 2.1, riverEnvelope + 8),
                bridge.CFrame * CFrame.new(side * 8.65, 1.25, 0),
                Enum.Material.Metal,
                Color3.fromRGB(68, 65, 72)
            )
            rail:SetAttribute("MergeEggBridgeRail", true)
        end
    end

    local gardens = Instance.new("Model")
    gardens.Name = "CommonGardens"
    gardens.Parent = commons
    for divider = 1, perSide - 1 do
        local x = centerX + (divider - perSide * 0.5) * (tonumber(config.bay_pitch) or 112)
        for _, row in ipairs({
            {
                z = centerZ + (riverEnvelope + promenadeWidth) * 0.5,
                tint = heavenTint,
                asset = divider % 2 == 0 and "cloud_sapling" or "frosted_pine_1",
            },
            {
                z = centerZ - (riverEnvelope + promenadeWidth) * 0.5,
                tint = hellTint,
                asset = divider % 2 == 0 and "withered_sapling" or "coldfire_pine",
            },
        }) do
            makePart(
                gardens,
                "GardenPlanter",
                Vector3.new(16, 1.5, math.max(8, promenadeWidth - 9)),
                CFrame.new(x, y + 0.75, row.z),
                Enum.Material.Rock,
                row.tint:Lerp(Color3.new(0.14, 0.14, 0.16), 0.68)
            )
            placeAsset(gardens, row.asset, CFrame.new(x, y + 1.5, row.z), 10)
        end
    end

    local plazas = Instance.new("Model")
    plazas.Name = "RiverEndPlazas"
    plazas.Parent = hall
    local plazaDiameter = math.max(52, tonumber(config.plaza_diameter) or 72)
    local plazaRadius = plazaDiameter * 0.5
    local plazaInset = plazaRadius * 0.35
    local plazaTop = y + 2.5
    local plazaByDirection = {}
    for _, direction in ipairs({ -1, 1 }) do
        local plazaX = centerX + direction * (length * 0.5 + plazaRadius - plazaInset)
        plazaByDirection[direction] = plazaX
        local plaza = makePart(
            plazas,
            direction < 0 and "SourcePlaza" or "FallsPlaza",
            Vector3.new(3, plazaDiameter, plazaDiameter),
            CFrame.new(plazaX, y + 1, centerZ) * CFrame.Angles(0, 0, math.pi * 0.5),
            Enum.Material.Cobblestone,
            Color3.fromRGB(105, 108, 115)
        )
        plaza.Shape = Enum.PartType.Cylinder
        plaza:SetAttribute("MergeEggRiverPlaza", true)
        local pool = makePart(
            plazas,
            direction < 0 and "SourcePool" or "FallsPool",
            Vector3.new(0.45, plazaDiameter * 0.48, plazaDiameter * 0.48),
            CFrame.new(plazaX, plazaTop + 0.2, centerZ) * CFrame.Angles(0, 0, math.pi * 0.5),
            Enum.Material.Glass,
            waterColor,
            0.16
        )
        pool.Shape = Enum.PartType.Cylinder
        pool.CanCollide = false
        pool.CanQuery = false

        local stairWidth = math.max(10, promenadeWidth - 6)
        local innerEdge = plazaX - direction * plazaRadius
        for bankSide = -1, 1, 2 do
            local stairZ = centerZ + bankSide * (riverEnvelope * 0.5 + stairWidth * 0.5)
            for step = 1, 3 do
                local topY = plazaTop - step * ((plazaTop - (y + 0.5)) / 3)
                makePart(
                    plazas,
                    "PlazaStair",
                    Vector3.new(4.4, 0.65, stairWidth),
                    CFrame.new(innerEdge - direction * (step - 0.5) * 4.2, topY - 0.325, stairZ),
                    Enum.Material.Cobblestone,
                    Color3.fromRGB(115, 116, 122)
                )
            end
        end
    end

    local lowerPark = Instance.new("Model")
    lowerPark.Name = "LowerWaterfallPark"
    lowerPark.Parent = hall
    local fallsPlazaX = plazaByDirection[1]
    local lowerDrop = math.max(14, tonumber(config.lower_park_drop) or 22)
    local lowerTop = y - lowerDrop
    local fallsLipX = fallsPlazaX + plazaRadius - 2
    local parkDiameter = math.max(72, tonumber(config.lower_park_diameter) or 90)
    local parkX = fallsLipX + parkDiameter * 0.43
    local park = makePart(
        lowerPark,
        "LowerGarden",
        Vector3.new(3, parkDiameter, parkDiameter),
        CFrame.new(parkX, lowerTop - 1.5, centerZ) * CFrame.Angles(0, 0, math.pi * 0.5),
        Enum.Material.Grass,
        Color3.fromRGB(70, 112, 73)
    )
    park.Shape = Enum.PartType.Cylinder
    park:SetAttribute("MergeEggLowerPark", true)
    local lowerPool = makePart(
        lowerPark,
        "WaterfallPool",
        Vector3.new(0.45, parkDiameter * 0.42, parkDiameter * 0.42),
        CFrame.new(parkX - parkDiameter * 0.18, lowerTop + 0.25, centerZ)
            * CFrame.Angles(0, 0, math.pi * 0.5),
        Enum.Material.Glass,
        waterColor,
        0.12
    )
    lowerPool.Shape = Enum.PartType.Cylinder
    lowerPool.CanCollide = false
    lowerPool.CanQuery = false
    local spillway = makePart(
        lowerPark,
        "PlazaSpillway",
        Vector3.new(plazaRadius + 5, 0.4, 16),
        CFrame.new(fallsPlazaX + plazaRadius * 0.5, plazaTop + 0.18, centerZ),
        Enum.Material.Glass,
        waterColor,
        0.12
    )
    spillway.CanCollide = false
    spillway.CanQuery = false
    local waterfallHeight = plazaTop - lowerTop + 1
    local waterfall = makePart(
        lowerPark,
        "Waterfall",
        Vector3.new(1.1, waterfallHeight, 18),
        CFrame.new(fallsLipX, lowerTop + waterfallHeight * 0.5, centerZ),
        Enum.Material.Glass,
        waterColor,
        0.08
    )
    waterfall.CanCollide = false
    waterfall.CanQuery = false
    waterfall:SetAttribute("MergeEggWaterfall", true)

    local stairCount = 28
    local stairStartX = fallsLipX - 2
    local stairZ = centerZ + plazaRadius * 0.68
    local stairRun = stairCount * 2.2
    local stairDrop = plazaTop - lowerTop
    local stairFoundation = makePart(
        lowerPark,
        "LowerParkStairFoundation",
        Vector3.new(stairRun + 3, 2, 16),
        CFrame.new(stairStartX + stairRun * 0.5, plazaTop - stairDrop * 0.5 - 1.2, stairZ)
            * CFrame.Angles(0, 0, -math.atan2(stairDrop, stairRun)),
        Enum.Material.Rock,
        Color3.fromRGB(73, 74, 80)
    )
    stairFoundation:SetAttribute("MergeEggLowerParkAccess", true)
    for step = 1, stairCount do
        local alpha = step / stairCount
        makePart(
            lowerPark,
            "LowerParkStair",
            Vector3.new(2.6, 0.75, 14),
            CFrame.new(stairStartX + step * 2.2, plazaTop - stairDrop * alpha - 0.375, stairZ),
            Enum.Material.Cobblestone,
            Color3.fromRGB(104, 105, 111)
        )
    end
    placeAsset(
        lowerPark,
        "luminous_canopy_tree",
        CFrame.new(parkX + 15, lowerTop + 0.1, centerZ - 25),
        14
    )
    placeAsset(
        lowerPark,
        "dreadthorn_tree",
        CFrame.new(parkX - 5, lowerTop + 0.1, centerZ + 32),
        13
    )
    placeAsset(lowerPark, "pearl_quartz", CFrame.new(parkX - 2, lowerTop + 0.1, centerZ - 30), 7)

    local curbSegments = 14
    for segment = 1, curbSegments do
        local theta = (segment - 1) / curbSegments * math.pi * 2
        -- Leave the northwest arc open for the descending stair.
        if not (theta > math.pi * 0.63 and theta < math.pi * 1.12) then
            local radius = parkDiameter * 0.49
            local position = Vector3.new(
                parkX + math.cos(theta) * radius,
                lowerTop + 1.3,
                centerZ + math.sin(theta) * radius
            )
            makePart(
                lowerPark,
                "ParkCurb",
                Vector3.new(parkDiameter * math.pi / curbSegments * 0.9, 2.6, 1.8),
                CFrame.new(position) * CFrame.Angles(0, -(theta + math.pi * 0.5), 0),
                Enum.Material.Rock,
                Color3.fromRGB(77, 81, 78)
            )
        end
    end
end

-- Retained as an editable comparison while the approved architectural mall replaces it.
function MergeEggRealmBuilder:_buildRoughOpposingFlowMall(root)
    local config = self._config
    local centerX = tonumber(config.center_x) or -16000
    local centerZ = tonumber(config.center_z) or -325
    local bayCenterY = tonumber(config.floor_y) or 1
    local perSide = math.max(1, math.floor(tonumber(config.bays_per_side) or 5))
    local pitch = tonumber(config.bay_pitch) or 112
    local gap = math.max(160, tonumber(config.corridor_gap) or 220)
    local mallLength = math.max(520, tonumber(config.mall_length) or 620)
    local mallWidth = math.clamp(tonumber(config.mall_width) or 158, 120, gap - 34)
    local mallDrop = math.max(4, tonumber(config.mall_drop) or 9)
    local mallCenterY = bayCenterY - mallDrop
    local mallTop = mallCenterY + 1
    local bayTop = bayCenterY + 1
    local riverWidth = math.clamp(tonumber(config.river_width) or 18, 12, mallWidth - 80)
    local waveAmplitude = math.clamp(tonumber(config.river_wave_amplitude) or 6, 0, 12)
    local heavenTint =
        color((config.themes or {}).heaven and config.themes.heaven.accent, { 120, 225, 255 })
    local hellTint =
        color((config.themes or {}).hell and config.themes.hell.accent, { 255, 65, 35 })
    local waterTint = Color3.fromRGB(55, 154, 220)
    local lavaTint = Color3.fromRGB(234, 71, 35)
    local stoneTint = Color3.fromRGB(104, 105, 111)
    local darkStoneTint = Color3.fromRGB(55, 54, 62)

    local hall = Instance.new("Model")
    hall.Name = "CentralHall"
    hall:SetAttribute("MergeEggCentralCommons", true)
    hall:SetAttribute("MergeEggMallLength", mallLength)
    hall:SetAttribute("MergeEggMallWidth", mallWidth)
    hall:SetAttribute("MergeEggMallDrop", mallDrop)
    hall.Parent = root

    local mall = Instance.new("Model")
    mall.Name = "SunkenMall"
    mall.Parent = hall
    local mallFloor = makePart(
        mall,
        "MallFloor",
        Vector3.new(mallLength, 2, mallWidth),
        CFrame.new(centerX, mallCenterY, centerZ),
        Enum.Material.Cobblestone,
        Color3.fromRGB(108, 110, 116)
    )
    mallFloor:SetAttribute("MergeEggSunkenMall", true)

    local promenadeWidth = 40
    for _, bank in ipairs({
        {
            name = "HeavenPromenade",
            direction = 1,
            material = Enum.Material.Marble,
            tint = heavenTint,
        },
        {
            name = "HellPromenade",
            direction = -1,
            material = Enum.Material.Basalt,
            tint = hellTint,
        },
    }) do
        local walk = makePart(
            mall,
            bank.name,
            Vector3.new(mallLength - 20, 0.35, promenadeWidth),
            CFrame.new(
                centerX,
                mallTop + 0.18,
                centerZ + bank.direction * (mallWidth * 0.5 - promenadeWidth * 0.5)
            ),
            bank.material,
            bank.tint:Lerp(Color3.new(0.52, 0.52, 0.56), 0.62),
            0.08
        )
        walk:SetAttribute("MergeEggMallPromenade", bank.name)
        makePart(
            mall,
            bank.name .. "Garden",
            Vector3.new(mallLength - 44, 0.55, 14),
            CFrame.new(centerX, mallTop + 0.28, centerZ + bank.direction * 29),
            Enum.Material.Grass,
            bank.direction > 0 and Color3.fromRGB(84, 130, 89) or Color3.fromRGB(85, 61, 58)
        )
    end

    local bayApproaches = Instance.new("Model")
    bayApproaches.Name = "BayApproaches"
    bayApproaches.Parent = hall
    local bayStairSteps = math.max(8, math.floor(tonumber(config.bay_stair_steps) or 12))
    local bayStairWidth = math.max(32, tonumber(config.bay_stair_width) or 48)
    local stairRun = math.max(20, (gap - mallWidth) * 0.5)
    local stairDepth = stairRun / bayStairSteps
    local stairRise = bayTop - mallTop
    for _, direction in ipairs({ 1, -1 }) do
        local sideName = direction > 0 and "Heaven" or "Hell"
        local stairTint = direction > 0 and heavenTint or hellTint
        for column = 1, perSide do
            local x = centerX + (column - (perSide + 1) * 0.5) * pitch
            local flight = Instance.new("Model")
            flight.Name = string.format("%sBayStair%02d", sideName, column)
            flight:SetAttribute("MergeEggBayStair", true)
            flight.Parent = bayApproaches
            for step = 1, bayStairSteps do
                local alpha = step / bayStairSteps
                local topY = mallTop + stairRise * alpha
                makePart(
                    flight,
                    "Step",
                    Vector3.new(bayStairWidth, stairRise / bayStairSteps, stairDepth + 0.18),
                    CFrame.new(
                        x,
                        topY - stairRise / bayStairSteps * 0.5,
                        centerZ + direction * (mallWidth * 0.5 + (step - 0.5) * stairDepth)
                    ),
                    Enum.Material.Cobblestone,
                    stairTint:Lerp(stoneTint, 0.65)
                )
            end
            makePart(
                flight,
                "BayLanding",
                Vector3.new(bayStairWidth + 10, 0.7, 14),
                CFrame.new(x, bayTop - 0.35, centerZ + direction * (gap * 0.5 + 7)),
                Enum.Material.Cobblestone,
                stairTint:Lerp(stoneTint, 0.52)
            )
        end
    end

    local river = Instance.new("Model")
    river.Name = "OpposingFlows"
    river:SetAttribute("MergeEggRiverWidth", riverWidth)
    river:SetAttribute("MergeEggRiverWaveAmplitude", waveAmplitude)
    river.Parent = mall
    local riverSegments = math.max(18, math.floor(tonumber(config.river_segments) or 36))
    local flowLength = mallLength - 46
    local segmentLength = flowLength / riverSegments
    for index = 1, riverSegments do
        local t = (index - 0.5) / riverSegments
        local x = centerX - flowLength * 0.5 + segmentLength * (index - 0.5)
        local z = centerZ + math.sin((index - 0.5) * 0.44) * waveAmplitude
        local nextZ = centerZ + math.sin((index + 0.5) * 0.44) * waveAmplitude
        local angle = math.atan2(nextZ - z, segmentLength)
        local flowTint = x < centerX and lavaTint or waterTint
        local flowName = x < centerX and "Lava" or "Water"
        local bed = makePart(
            river,
            string.format("%sBed%02d", flowName, index),
            Vector3.new(segmentLength + 2, 1, riverWidth + 5),
            CFrame.new(x, mallTop - 0.42, z) * CFrame.Angles(0, -angle, 0),
            Enum.Material.Slate,
            darkStoneTint
        )
        bed.CanQuery = false
        bed:SetAttribute("MergeEggFlowBed", flowName)
        local surface = makePart(
            river,
            string.format("%sFlow%02d", flowName, index),
            Vector3.new(segmentLength + 2.4, 0.42, riverWidth),
            CFrame.new(x, mallTop + 0.12, z) * CFrame.Angles(0, -angle, 0),
            flowName == "Lava" and Enum.Material.Neon or Enum.Material.Glass,
            flowTint,
            flowName == "Lava" and 0.08 or 0.16
        )
        surface.CanCollide = false
        surface.CanQuery = false
        surface:SetAttribute("MergeEggOpposingFlow", flowName)
    end

    local bridges = Instance.new("Model")
    bridges.Name = "Bridges"
    bridges.Parent = mall
    for column = 1, perSide do
        local x = centerX + (column - (perSide + 1) * 0.5) * pitch
        local bridge = makePart(
            bridges,
            "RiverBridge" .. column,
            Vector3.new(34, 1.2, riverWidth + 12),
            CFrame.new(x, mallTop + 0.68, centerZ),
            Enum.Material.Cobblestone,
            darkStoneTint
        )
        bridge:SetAttribute("MergeEggRiverBridge", true)
        local inset = makePart(
            bridges,
            "BridgeInset" .. column,
            Vector3.new(27, 0.22, riverWidth + 13),
            bridge.CFrame * CFrame.new(0, 0.7, 0),
            Enum.Material.Neon,
            column % 2 == 0 and hellTint or heavenTint,
            0.12
        )
        inset.CanCollide = false
    end

    local convergence = Instance.new("Model")
    convergence.Name = "Convergence"
    convergence:SetAttribute("MergeEggConvergence", true)
    convergence.Parent = hall
    local island = makePart(
        convergence,
        "ConvergenceIsland",
        Vector3.new(1.5, 54, 54),
        CFrame.new(centerX, mallTop + 0.7, centerZ) * CFrame.Angles(0, 0, math.pi * 0.5),
        Enum.Material.Slate,
        darkStoneTint
    )
    island.Shape = Enum.PartType.Cylinder
    local plinth = makePart(
        convergence,
        "ConvergencePlinth",
        Vector3.new(1.5, 22, 22),
        CFrame.new(centerX, mallTop + 4.2, centerZ) * CFrame.Angles(0, 0, math.pi * 0.5),
        Enum.Material.Metal,
        Color3.fromRGB(164, 132, 47)
    )
    plinth.Shape = Enum.PartType.Cylinder
    local core = makePart(
        convergence,
        "ConvergenceCore",
        Vector3.new(18, 18, 18),
        CFrame.new(centerX, mallTop + 17, centerZ),
        Enum.Material.Neon,
        Color3.fromRGB(255, 215, 76),
        0.08
    )
    core.Shape = Enum.PartType.Ball
    core.CanCollide = false
    core:SetAttribute("MergeEggConvergenceVfxPlaceholder", true)
    local light = Instance.new("PointLight")
    light.Name = "ConvergenceLight"
    light.Color = core.Color
    light.Range = 48
    light.Brightness = 2.5
    light.Parent = core
    for index, ring in ipairs({
        { diameter = 38, height = mallTop + 8, tint = lavaTint },
        { diameter = 46, height = mallTop + 15, tint = waterTint },
        { diameter = 32, height = mallTop + 23, tint = core.Color },
    }) do
        local disc = makePart(
            convergence,
            "ConvergenceRing" .. index,
            Vector3.new(0.35, ring.diameter, ring.diameter),
            CFrame.new(centerX, ring.height, centerZ) * CFrame.Angles(0, 0, math.pi * 0.5),
            Enum.Material.Neon,
            ring.tint,
            0.72
        )
        disc.Shape = Enum.PartType.Cylinder
        disc.CanCollide = false
        disc.CanQuery = false
    end

    local endPlazas = Instance.new("Model")
    endPlazas.Name = "EndPlazas"
    endPlazas.Parent = hall
    local plazaStairSteps = math.max(8, math.floor(tonumber(config.plaza_stair_steps) or 12))
    local plazaStairRun = math.max(24, tonumber(config.plaza_stair_run) or 34)
    local plazaStepDepth = plazaStairRun / plazaStairSteps
    local westInnerEdge = centerX - mallLength * 0.5
    local eastInnerEdge = centerX + mallLength * 0.5

    local hellPlazaSizeX = math.max(140, tonumber(config.hell_plaza_size_x) or 184)
    local hellPlazaSizeZ = math.max(mallWidth, tonumber(config.hell_plaza_size_z) or 220)
    local hellPlazaX = westInnerEdge - hellPlazaSizeX * 0.5
    local hellFoundation = makePart(
        endPlazas,
        "HellPlazaFoundation",
        Vector3.new(hellPlazaSizeX, mallDrop, hellPlazaSizeZ),
        CFrame.new(hellPlazaX, bayCenterY - 1 - mallDrop * 0.5, centerZ),
        Enum.Material.Rock,
        hellTint:Lerp(darkStoneTint, 0.75)
    )
    hellFoundation:SetAttribute("MergeEggEndPlaza", "Hell")
    makePart(
        endPlazas,
        "HellArrivalPlaza",
        Vector3.new(hellPlazaSizeX, 2, hellPlazaSizeZ),
        CFrame.new(hellPlazaX, bayCenterY, centerZ),
        Enum.Material.Basalt,
        hellTint:Lerp(Color3.fromRGB(70, 42, 42), 0.66)
    )

    local heavenPlazaSizeX = math.max(132, tonumber(config.heaven_plaza_size_x) or 160)
    local heavenPlazaSizeZ = math.max(mallWidth, tonumber(config.heaven_plaza_size_z) or 186)
    local heavenPlazaX = eastInnerEdge + heavenPlazaSizeX * 0.5
    local heavenFoundation = makePart(
        endPlazas,
        "HeavenPlazaFoundation",
        Vector3.new(heavenPlazaSizeX, mallDrop, heavenPlazaSizeZ),
        CFrame.new(heavenPlazaX, bayCenterY - 1 - mallDrop * 0.5, centerZ),
        Enum.Material.Rock,
        heavenTint:Lerp(darkStoneTint, 0.75)
    )
    heavenFoundation:SetAttribute("MergeEggEndPlaza", "Heaven")
    makePart(
        endPlazas,
        "HeavenOverlookPlaza",
        Vector3.new(heavenPlazaSizeX, 2, heavenPlazaSizeZ),
        CFrame.new(heavenPlazaX, bayCenterY, centerZ),
        Enum.Material.Marble,
        heavenTint:Lerp(Color3.fromRGB(190, 204, 215), 0.55)
    )

    local function plazaStair(name, edgeX, direction, tint)
        local flight = Instance.new("Model")
        flight.Name = name
        flight.Parent = endPlazas
        for step = 1, plazaStairSteps do
            local alpha = step / plazaStairSteps
            local topY = bayTop - (bayTop - mallTop) * alpha
            makePart(
                flight,
                "Step",
                Vector3.new(plazaStepDepth + 0.16, (bayTop - mallTop) / plazaStairSteps, mallWidth),
                CFrame.new(
                    edgeX + direction * (step - 0.5) * plazaStepDepth,
                    topY - (bayTop - mallTop) / plazaStairSteps * 0.5,
                    centerZ
                ),
                Enum.Material.Cobblestone,
                tint:Lerp(stoneTint, 0.72)
            )
        end
    end
    plazaStair("HellCivicStair", westInnerEdge, 1, hellTint)
    plazaStair("HeavenCivicStair", eastInnerEdge, -1, heavenTint)

    local function sourcePool(name, x, tint, material)
        local basin = makePart(
            endPlazas,
            name .. "Basin",
            Vector3.new(2.2, 48, 48),
            CFrame.new(x, bayTop + 1.1, centerZ) * CFrame.Angles(0, 0, math.pi * 0.5),
            Enum.Material.Slate,
            darkStoneTint
        )
        basin.Shape = Enum.PartType.Cylinder
        local source = makePart(
            endPlazas,
            name,
            Vector3.new(0.7, 38, 38),
            CFrame.new(x, bayTop + 2.2, centerZ) * CFrame.Angles(0, 0, math.pi * 0.5),
            material,
            tint,
            material == Enum.Material.Glass and 0.14 or 0.05
        )
        source.Shape = Enum.PartType.Cylinder
        source.CanCollide = false
        source.CanQuery = false
    end
    sourcePool("LavaSource", hellPlazaX - 20, lavaTint, Enum.Material.Neon)
    sourcePool("WaterSource", heavenPlazaX + 18, waterTint, Enum.Material.Glass)

    local function inwardFall(name, x, tint, material)
        local fall = makePart(
            endPlazas,
            name,
            Vector3.new(4.5, bayTop - mallTop, riverWidth),
            CFrame.new(x, mallTop + (bayTop - mallTop) * 0.5, centerZ),
            material,
            tint,
            material == Enum.Material.Glass and 0.12 or 0.05
        )
        fall.CanCollide = false
        fall.CanQuery = false
        fall:SetAttribute("MergeEggInwardFall", true)
    end
    inwardFall("LavaFallToMall", westInnerEdge + plazaStairRun * 0.68, lavaTint, Enum.Material.Neon)
    inwardFall(
        "WaterFallToMall",
        eastInnerEdge - plazaStairRun * 0.68,
        waterTint,
        Enum.Material.Glass
    )

    local lowerPark = Instance.new("Model")
    lowerPark.Name = "LowerWaterfallPark"
    lowerPark.Parent = hall
    local lowerDrop = math.max(14, tonumber(config.lower_park_drop) or 22)
    local lowerTop = mallTop - lowerDrop
    local parkSizeX = math.max(160, tonumber(config.lower_park_size_x) or 190)
    local parkSizeZ = math.max(180, tonumber(config.lower_park_size_z) or 220)
    local farPlazaEdge = eastInnerEdge + heavenPlazaSizeX
    local parkX = farPlazaEdge + parkSizeX * 0.3
    local park = makePart(
        lowerPark,
        "LowerGarden",
        Vector3.new(parkSizeX, 2, parkSizeZ),
        CFrame.new(parkX, lowerTop - 1, centerZ),
        Enum.Material.Grass,
        Color3.fromRGB(70, 112, 73)
    )
    park:SetAttribute("MergeEggLowerPark", true)
    local pool = makePart(
        lowerPark,
        "WaterfallPool",
        Vector3.new(0.55, 84, 84),
        CFrame.new(parkX - 34, lowerTop + 0.25, centerZ) * CFrame.Angles(0, 0, math.pi * 0.5),
        Enum.Material.Glass,
        waterTint,
        0.12
    )
    pool.Shape = Enum.PartType.Cylinder
    pool.CanCollide = false
    pool.CanQuery = false
    local waterfallHeight = bayTop - lowerTop
    local waterfall = makePart(
        lowerPark,
        "Waterfall",
        Vector3.new(5, waterfallHeight, 28),
        CFrame.new(farPlazaEdge, lowerTop + waterfallHeight * 0.5, centerZ),
        Enum.Material.Glass,
        waterTint,
        0.08
    )
    waterfall.CanCollide = false
    waterfall.CanQuery = false
    waterfall:SetAttribute("MergeEggWaterfall", true)

    local lowerStairCount = 28
    local lowerStairRun = math.max(64, parkX - farPlazaEdge + 20)
    for _, zOffset in ipairs({ -68, 68 }) do
        for step = 1, lowerStairCount do
            local alpha = step / lowerStairCount
            makePart(
                lowerPark,
                "LowerParkStair",
                Vector3.new(
                    lowerStairRun / lowerStairCount + 0.14,
                    waterfallHeight / lowerStairCount,
                    46
                ),
                CFrame.new(
                    farPlazaEdge + (step - 0.5) * (lowerStairRun / lowerStairCount),
                    bayTop - waterfallHeight * alpha - waterfallHeight / lowerStairCount * 0.5,
                    centerZ + zOffset
                ),
                Enum.Material.Cobblestone,
                stoneTint
            )
        end
    end

    local decor = Instance.new("Model")
    decor.Name = "MallDecor"
    decor.Parent = hall
    local heavenAssets = { "cloud_sapling", "frosted_pine_1" }
    local hellAssets = { "withered_sapling", "coldfire_pine" }
    for divider = 1, perSide - 1 do
        local x = centerX + (divider - perSide * 0.5) * pitch
        placeAsset(
            decor,
            heavenAssets[(divider - 1) % #heavenAssets + 1],
            CFrame.new(x, mallTop + 0.55, centerZ + 29),
            12
        )
        placeAsset(
            decor,
            hellAssets[(divider - 1) % #hellAssets + 1],
            CFrame.new(x + 28, mallTop + 0.55, centerZ - 29),
            12
        )
    end
    placeAsset(
        lowerPark,
        "luminous_canopy_tree",
        CFrame.new(parkX + 28, lowerTop, centerZ - 70),
        16
    )
    placeAsset(lowerPark, "dreadthorn_tree", CFrame.new(parkX + 12, lowerTop, centerZ + 72), 16)
end

-- Permanent architectural blockout: a formal, symmetric civic canyon rather than an open test
-- strip. The ten gameplay bays remain independent authored Models; this function owns only their
-- shared terraces, approaches, river mall, and end-cap landmarks.
function MergeEggRealmBuilder:_buildHall(root)
    local config = self._config
    local centerX = tonumber(config.center_x) or -16000
    local centerZ = tonumber(config.center_z) or -325
    local bayCenterY = tonumber(config.floor_y) or 1
    local bayTop = bayCenterY + 1
    local perSide = math.max(1, math.floor(tonumber(config.bays_per_side) or 5))
    local pitch = math.max(112, tonumber(config.bay_pitch) or 136)
    local mallLength = math.max(640, tonumber(config.mall_length) or 680)
    local mallWidth = math.max(160, tonumber(config.mall_width) or 180)
    local mallDrop = math.max(8, tonumber(config.mall_drop) or 10)
    local mallTop = bayTop - mallDrop
    local mallCenterY = mallTop - 1
    local riverWidth = math.clamp(tonumber(config.river_width) or 18, 14, 24)
    local stairSteps = math.max(8, math.floor(tonumber(config.bay_stair_steps) or 10))
    local stairWidth = math.max(44, tonumber(config.bay_stair_width) or 56)
    local stairRun = math.max(36, tonumber(config.bay_stair_run) or 44)
    local outerZ = mallWidth * 0.5
    local rise = bayTop - mallTop
    local middle = (perSide + 1) * 0.5
    local hellTint = Color3.fromRGB(205, 72, 31)
    local heavenTint = Color3.fromRGB(85, 188, 226)
    local lavaTint = Color3.fromRGB(245, 73, 24)
    local waterTint = Color3.fromRGB(48, 162, 224)
    local pearlTint = Color3.fromRGB(226, 229, 220)
    local goldTint = Color3.fromRGB(199, 148, 52)
    local stoneTint = Color3.fromRGB(104, 104, 108)
    local lightStoneTint = Color3.fromRGB(154, 151, 145)
    local darkStoneTint = Color3.fromRGB(44, 42, 49)

    local hall = Instance.new("Model")
    hall.Name = "CentralHall"
    hall:SetAttribute("MergeEggCentralCommons", true)
    hall:SetAttribute("MergeEggArchitecturalBlockout", true)
    hall:SetAttribute("MergeEggMallLength", mallLength)
    hall:SetAttribute("MergeEggMallWidth", mallWidth)
    hall:SetAttribute("MergeEggMallDrop", mallDrop)
    hall.Parent = root

    local mall = Instance.new("Model")
    mall.Name = "SunkenMall"
    mall.Parent = hall
    local floor = makePart(
        mall,
        "MallFloor",
        Vector3.new(mallLength, 2, mallWidth),
        CFrame.new(centerX, mallCenterY, centerZ),
        Enum.Material.Cobblestone,
        Color3.fromRGB(115, 112, 108)
    )
    floor:SetAttribute("MergeEggSunkenMall", true)

    local promenadeWidth = (mallWidth - riverWidth) * 0.5
    for _, bank in ipairs({
        { name = "HeavenPromenade", direction = 1, tint = heavenTint },
        { name = "HellPromenade", direction = -1, tint = hellTint },
    }) do
        local paving = makePart(
            mall,
            bank.name,
            Vector3.new(mallLength - 8, 0.34, promenadeWidth - 5),
            CFrame.new(
                centerX,
                mallTop + 0.18,
                centerZ + bank.direction * (riverWidth * 0.5 + promenadeWidth * 0.5)
            ),
            bank.direction > 0 and Enum.Material.Limestone or Enum.Material.Basalt,
            bank.tint:Lerp(lightStoneTint, 0.78)
        )
        paving:SetAttribute("MergeEggMallPromenade", bank.name)
        makePart(
            mall,
            bank.name .. "RiverCurb",
            Vector3.new(mallLength - 12, 1.4, 2.2),
            CFrame.new(centerX, mallTop + 0.7, centerZ + bank.direction * (riverWidth * 0.5 + 1.1)),
            Enum.Material.Metal,
            goldTint
        )
    end

    local river = Instance.new("Model")
    river.Name = "CenterRiver"
    river:SetAttribute("MergeEggRiverWidth", riverWidth)
    river.Parent = mall
    makePart(
        river,
        "RiverBed",
        Vector3.new(mallLength - 12, 2.6, riverWidth + 5),
        CFrame.new(centerX, mallTop - 1.25, centerZ),
        Enum.Material.Slate,
        Color3.fromRGB(29, 31, 38)
    )
    local cancellationWidth = 26
    local halfFlowLength = (mallLength - cancellationWidth - 20) * 0.5
    for _, flow in ipairs({
        { name = "Lava", direction = -1, tint = lavaTint, material = Enum.Material.Neon },
        { name = "Water", direction = 1, tint = waterTint, material = Enum.Material.Glass },
    }) do
        local surface = makePart(
            river,
            flow.name .. "Flow",
            Vector3.new(halfFlowLength, 0.48, riverWidth),
            CFrame.new(
                centerX + flow.direction * (cancellationWidth * 0.5 + halfFlowLength * 0.5),
                mallTop + 0.12,
                centerZ
            ),
            flow.material,
            flow.tint,
            flow.name == "Water" and 0.14 or 0.04
        )
        surface.CanCollide = false
        surface.CanQuery = false
        surface:SetAttribute("MergeEggOpposingFlow", flow.name)
    end
    local cancelSurface = makePart(
        river,
        "CancellationBand",
        Vector3.new(cancellationWidth, 0.62, riverWidth),
        CFrame.new(centerX, mallTop + 0.2, centerZ),
        Enum.Material.Glass,
        pearlTint,
        0.16
    )
    cancelSurface.CanCollide = false
    cancelSurface.CanQuery = false
    cancelSurface:SetAttribute("MergeEggConvergence", true)
    for index = 1, 9 do
        local side = index % 2 == 0 and 1 or -1
        local steam = makePart(
            river,
            "SteamPlume" .. index,
            Vector3.new(3.8 + (index % 3), 3.8 + (index % 4), 3.8 + (index % 3)),
            CFrame.new(
                centerX - 11 + index * 2.2,
                mallTop + 2.2 + (index % 3) * 1.8,
                centerZ + side * (2 + (index % 3) * 1.7)
            ),
            Enum.Material.Glass,
            pearlTint,
            0.42
        )
        steam.Shape = Enum.PartType.Ball
        steam.CanCollide = false
        steam.CanQuery = false
    end

    local centers = {}
    for column = 1, perSide do
        centers[column] = centerX + (column - middle) * pitch
    end

    local retaining = Instance.new("Model")
    retaining.Name = "RetainingWalls"
    retaining.Parent = hall
    local openingHalf = stairWidth * 0.5 + 4
    local mallMinX = centerX - mallLength * 0.5
    local mallMaxX = centerX + mallLength * 0.5
    for _, side in ipairs({
        { direction = 1, name = "Heaven", tint = heavenTint },
        { direction = -1, name = "Hell", tint = hellTint },
    }) do
        local cursor = mallMinX
        for column = 1, perSide do
            local openingStart = centers[column] - openingHalf
            if openingStart > cursor then
                local segmentLength = openingStart - cursor
                makePart(
                    retaining,
                    side.name .. "RetainingWall",
                    Vector3.new(segmentLength, rise, 5),
                    CFrame.new(
                        cursor + segmentLength * 0.5,
                        mallTop + rise * 0.5,
                        centerZ + side.direction * (outerZ - 2.5)
                    ),
                    Enum.Material.Rock,
                    side.tint:Lerp(darkStoneTint, 0.78)
                )
                makePart(
                    retaining,
                    side.name .. "WallCap",
                    Vector3.new(segmentLength + 1, 1.2, 7),
                    CFrame.new(
                        cursor + segmentLength * 0.5,
                        bayTop + 0.6,
                        centerZ + side.direction * (outerZ - 2.5)
                    ),
                    Enum.Material.Metal,
                    goldTint
                )
            end
            cursor = centers[column] + openingHalf
        end
        if cursor < mallMaxX then
            local segmentLength = mallMaxX - cursor
            makePart(
                retaining,
                side.name .. "RetainingWall",
                Vector3.new(segmentLength, rise, 5),
                CFrame.new(
                    cursor + segmentLength * 0.5,
                    mallTop + rise * 0.5,
                    centerZ + side.direction * (outerZ - 2.5)
                ),
                Enum.Material.Rock,
                side.tint:Lerp(darkStoneTint, 0.78)
            )
            makePart(
                retaining,
                side.name .. "WallCap",
                Vector3.new(segmentLength + 1, 1.2, 7),
                CFrame.new(
                    cursor + segmentLength * 0.5,
                    bayTop + 0.6,
                    centerZ + side.direction * (outerZ - 2.5)
                ),
                Enum.Material.Metal,
                goldTint
            )
        end
    end

    local approaches = Instance.new("Model")
    approaches.Name = "BayApproaches"
    approaches.Parent = hall
    local stepDepth = stairRun / stairSteps
    local stepRise = rise / stairSteps
    for _, side in ipairs({
        { direction = 1, name = "Heaven", tint = heavenTint },
        { direction = -1, name = "Hell", tint = hellTint },
    }) do
        for column = 1, perSide do
            local x = centers[column]
            local flight = Instance.new("Model")
            flight.Name = string.format("%sBayStair%02d", side.name, column)
            flight:SetAttribute("MergeEggBayStair", true)
            flight.Parent = approaches
            for step = 1, stairSteps do
                local topY = mallTop + stepRise * step
                local z = centerZ + side.direction * (outerZ - stairRun + (step - 0.5) * stepDepth)
                makePart(
                    flight,
                    "Step",
                    Vector3.new(stairWidth, stepRise, stepDepth + 0.18),
                    CFrame.new(x, topY - stepRise * 0.5, z),
                    Enum.Material.Cobblestone,
                    side.tint:Lerp(lightStoneTint, 0.72)
                )
                makePart(
                    flight,
                    "StepNosing",
                    Vector3.new(stairWidth + 0.5, 0.16, 0.42),
                    CFrame.new(x, topY + 0.08, z + side.direction * (stepDepth * 0.5 - 0.21)),
                    Enum.Material.Metal,
                    goldTint
                )
            end
            makePart(
                flight,
                "BayLanding",
                Vector3.new(stairWidth + 12, 0.8, 13),
                CFrame.new(x, bayTop - 0.4, centerZ + side.direction * (outerZ + 6.5)),
                Enum.Material.Cobblestone,
                side.tint:Lerp(lightStoneTint, 0.62)
            )
            for railSide = -1, 1, 2 do
                local railX = x + railSide * (stairWidth * 0.5 + 2)
                local bottom = Vector3.new(
                    railX,
                    mallTop + 2.2,
                    centerZ + side.direction * (outerZ - stairRun)
                )
                local top = Vector3.new(railX, bayTop + 2.6, centerZ + side.direction * outerZ)
                makeBeam(flight, "BalustradeRail", bottom, top, 1.1, Enum.Material.Metal, goldTint)
                for _, alpha in ipairs({ 0, 0.5, 1 }) do
                    local position = bottom:Lerp(top, alpha)
                    makePart(
                        flight,
                        "BalustradePost",
                        Vector3.new(1.5, 4.2, 1.5),
                        CFrame.new(position.X, position.Y - 0.5, position.Z),
                        Enum.Material.Metal,
                        goldTint
                    )
                end
            end
            for pillarSide = -1, 1, 2 do
                makePart(
                    flight,
                    "StairMouthPillar",
                    Vector3.new(5, 13, 5),
                    CFrame.new(
                        x + pillarSide * (stairWidth * 0.5 + 4),
                        mallTop + 6.5,
                        centerZ + side.direction * (outerZ - 2.5)
                    ),
                    Enum.Material.Rock,
                    side.tint:Lerp(darkStoneTint, 0.68)
                )
            end
        end
    end

    local bridges = Instance.new("Model")
    bridges.Name = "Bridges"
    bridges.Parent = mall
    for divider = 1, perSide - 1 do
        local x = (centers[divider] + centers[divider + 1]) * 0.5
        local bridge = makePart(
            bridges,
            "RiverBridge" .. divider,
            Vector3.new(22, 1.2, riverWidth + 20),
            CFrame.new(x, mallTop + 0.75, centerZ),
            Enum.Material.WoodPlanks,
            Color3.fromRGB(91, 67, 48)
        )
        bridge:SetAttribute("MergeEggRiverBridge", true)
        for railSide = -1, 1, 2 do
            local railX = x + railSide * 10
            local from = Vector3.new(railX, mallTop + 3.1, centerZ - riverWidth * 0.5 - 7)
            local to = Vector3.new(railX, mallTop + 3.1, centerZ + riverWidth * 0.5 + 7)
            makeBeam(bridges, "BridgeRail", from, to, 0.85, Enum.Material.Metal, goldTint)
            for _, z in ipairs({ from.Z, centerZ, to.Z }) do
                makePart(
                    bridges,
                    "BridgePost",
                    Vector3.new(1.2, 4.4, 1.2),
                    CFrame.new(railX, mallTop + 2.2, z),
                    Enum.Material.Metal,
                    goldTint
                )
            end
        end
    end

    local civicDetails = Instance.new("Model")
    civicDetails.Name = "CivicDetails"
    civicDetails.Parent = hall
    for divider = 1, perSide - 1 do
        local x = (centers[divider] + centers[divider + 1]) * 0.5
        for _, direction in ipairs({ -1, 1 }) do
            local planter = makePart(
                civicDetails,
                direction > 0 and "HeavenBermPlanter" or "HellBermPlanter",
                Vector3.new(34, 1.5, 16),
                CFrame.new(x, mallTop + 0.75, centerZ + direction * 65),
                Enum.Material.Rock,
                direction > 0 and Color3.fromRGB(92, 120, 126) or Color3.fromRGB(74, 48, 43)
            )
            planter:SetAttribute("MergeEggMallBerm", true)
            makePart(
                civicDetails,
                "LampPost",
                Vector3.new(1.4, 11, 1.4),
                CFrame.new(x, mallTop + 6.2, centerZ + direction * 36),
                Enum.Material.Metal,
                darkStoneTint
            )
            local lamp = makePart(
                civicDetails,
                "Lamp",
                Vector3.new(3.8, 3.8, 3.8),
                CFrame.new(x, mallTop + 12.5, centerZ + direction * 36),
                Enum.Material.Neon,
                direction > 0 and heavenTint or hellTint,
                0.08
            )
            lamp.Shape = Enum.PartType.Ball
            lamp.CanCollide = false
            local light = Instance.new("PointLight")
            light.Color = lamp.Color
            light.Range = 24
            light.Brightness = 1.4
            light.Parent = lamp
        end
    end

    local endPlazas = Instance.new("Model")
    endPlazas.Name = "EndPlazas"
    endPlazas.Parent = hall
    local plazaDiameter = math.max(160, tonumber(config.end_plaza_diameter) or 184)
    local plazaRadius = plazaDiameter * 0.5
    local plazaOffset = mallLength * 0.5 + plazaRadius - 24
    local plazaStairSteps = math.max(8, math.floor(tonumber(config.plaza_stair_steps) or 10))
    local plazaStairRun = math.max(36, tonumber(config.plaza_stair_run) or 44)

    local function buildEndPlaza(name, direction, tint, flowTint, flowMaterial)
        local plaza = Instance.new("Model")
        plaza.Name = name .. "EndCap"
        plaza:SetAttribute("MergeEggEndPlaza", name)
        plaza.Parent = endPlazas
        local plazaX = centerX + direction * plazaOffset
        makeDisc(
            plaza,
            name .. "Foundation",
            plazaDiameter,
            mallDrop + 2,
            Vector3.new(plazaX, mallTop + (mallDrop + 2) * 0.5, centerZ),
            Enum.Material.Rock,
            tint:Lerp(darkStoneTint, 0.75)
        )
        makeDisc(
            plaza,
            name .. "Plaza",
            plazaDiameter - 6,
            1.6,
            Vector3.new(plazaX, bayTop - 0.8, centerZ),
            name == "Heaven" and Enum.Material.Marble or Enum.Material.Basalt,
            tint:Lerp(lightStoneTint, name == "Heaven" and 0.68 or 0.82)
        )
        makeDisc(
            plaza,
            name .. "InnerTerrace",
            plazaDiameter - 38,
            0.8,
            Vector3.new(plazaX, bayTop + 0.4, centerZ),
            Enum.Material.Cobblestone,
            tint:Lerp(stoneTint, 0.66)
        )
        makeDisc(
            plaza,
            name .. "SourceBasin",
            62,
            1.6,
            Vector3.new(plazaX, bayTop + 1.2, centerZ),
            Enum.Material.Slate,
            darkStoneTint
        )
        local source = makeDisc(
            plaza,
            name .. "Source",
            50,
            0.5,
            Vector3.new(plazaX, bayTop + 2.15, centerZ),
            flowMaterial,
            flowTint,
            flowMaterial == Enum.Material.Glass and 0.12 or 0.04
        )
        source.CanCollide = false
        source.CanQuery = false

        local bottomX = centerX + direction * (mallLength * 0.5 - 8)
        local stepDepthX = plazaStairRun / plazaStairSteps
        for step = 1, plazaStairSteps do
            local topY = mallTop + rise * (step / plazaStairSteps)
            makePart(
                plaza,
                "CivicStep",
                Vector3.new(stepDepthX + 0.18, rise / plazaStairSteps, 82),
                CFrame.new(
                    bottomX + direction * (step - 0.5) * stepDepthX,
                    topY - rise / plazaStairSteps * 0.5,
                    centerZ
                ),
                Enum.Material.Cobblestone,
                tint:Lerp(lightStoneTint, 0.72)
            )
        end
        for railSide = -1, 1, 2 do
            local railZ = centerZ + railSide * 43
            makeBeam(
                plaza,
                "CivicStairRail",
                Vector3.new(bottomX, mallTop + 2.2, railZ),
                Vector3.new(bottomX + direction * plazaStairRun, bayTop + 2.5, railZ),
                1.2,
                Enum.Material.Metal,
                goldTint
            )
        end

        local fallX = centerX + direction * (mallLength * 0.5 - 2)
        local fall = makePart(
            plaza,
            name .. "FallToRiver",
            Vector3.new(5, rise, riverWidth),
            CFrame.new(fallX, mallTop + rise * 0.5, centerZ),
            flowMaterial,
            flowTint,
            flowMaterial == Enum.Material.Glass and 0.12 or 0.04
        )
        fall.CanCollide = false
        fall.CanQuery = false

        for index = 1, 12 do
            local angle = math.rad(index * 30)
            local radial = Vector3.new(math.cos(angle), 0, math.sin(angle)) * (plazaRadius - 10)
            local post = makePart(
                plaza,
                "PerimeterSpire",
                Vector3.new(4, 15 + (index % 2) * 4, 4),
                CFrame.new(plazaX + radial.X, bayTop + 7.5, centerZ + radial.Z),
                Enum.Material.Rock,
                tint:Lerp(darkStoneTint, 0.62)
            )
            post:SetAttribute("MergeEggEndCapSpire", true)
        end
        return plaza, plazaX
    end

    local hellPlaza, hellPlazaX = buildEndPlaza("Hell", -1, hellTint, lavaTint, Enum.Material.Neon)
    local heavenPlaza, heavenPlazaX =
        buildEndPlaza("Heaven", 1, heavenTint, waterTint, Enum.Material.Glass)

    local hellCliff = Instance.new("Model")
    hellCliff.Name = "HellCliff"
    hellCliff.Parent = hellPlaza
    for index, zOffset in ipairs({ -56, -30, 0, 30, 56 }) do
        local height = 22 + (3 - math.abs(index - 3)) * 10
        makePart(
            hellCliff,
            "BasaltSpire",
            Vector3.new(18, height, 18),
            CFrame.new(hellPlazaX - plazaRadius + 10, bayTop + height * 0.5, centerZ + zOffset),
            Enum.Material.Basalt,
            Color3.fromRGB(38, 29, 33)
        )
    end
    local outwardLava = makePart(
        hellCliff,
        "OutwardLavafall",
        Vector3.new(5, 28, 24),
        CFrame.new(hellPlazaX - plazaRadius + 3, mallTop - 4, centerZ),
        Enum.Material.Neon,
        lavaTint,
        0.04
    )
    outwardLava.CanCollide = false
    outwardLava.CanQuery = false

    local heavenCliff = Instance.new("Model")
    heavenCliff.Name = "HeavenIceCliff"
    heavenCliff.Parent = heavenPlaza
    for index, zOffset in ipairs({ -60, -34, 0, 34, 60 }) do
        local height = 28 + (3 - math.abs(index - 3)) * 12
        makePart(
            heavenCliff,
            "IceCliff",
            Vector3.new(22, height, 22),
            CFrame.new(heavenPlazaX + plazaRadius - 8, bayTop + height * 0.5, centerZ + zOffset),
            Enum.Material.Glacier,
            Color3.fromRGB(172, 216, 230)
        )
    end
    local cliffWaterfall = makePart(
        heavenCliff,
        "CliffWaterfall",
        Vector3.new(5, 44, 26),
        CFrame.new(heavenPlazaX + plazaRadius - 18, bayTop + 20, centerZ),
        Enum.Material.Glass,
        waterTint,
        0.1
    )
    cliffWaterfall.CanCollide = false
    cliffWaterfall.CanQuery = false
    cliffWaterfall:SetAttribute("MergeEggWaterfall", true)

    local decor = Instance.new("Model")
    decor.Name = "MallDecor"
    decor.Parent = hall
    for divider = 1, perSide - 1 do
        local x = (centers[divider] + centers[divider + 1]) * 0.5
        placeAsset(
            decor,
            divider % 2 == 0 and "cloud_sapling" or "frosted_pine_1",
            CFrame.new(x, bayTop, centerZ + outerZ + 22),
            15
        )
        placeAsset(
            decor,
            divider % 2 == 0 and "dreadthorn_tree" or "coldfire_pine",
            CFrame.new(x, bayTop, centerZ - outerZ - 22),
            15
        )
    end
end

function MergeEggRealmBuilder:_adoptAuthoredRealm(root)
    if not (root and root:IsA("Model")) then
        return nil, "authored_realm_missing"
    end
    if root:GetAttribute("MergeEggAuthoredRealm") ~= true then
        return nil, "realm_is_not_authored"
    end

    self._bays = {}
    self._root = root
    local modelsById = {}
    for _, descendant in ipairs(root:GetDescendants()) do
        if descendant:IsA("Model") then
            local bayId = descendant:GetAttribute("MergeEggBayId")
            if type(bayId) == "string" and bayId ~= "" then
                modelsById[bayId] = descendant
            end
        end
    end

    local layout = MergeEggRealmLayout.bays(self._config)
    for _, bay in ipairs(layout) do
        local model = modelsById[bay.id]
        if not model then
            self._bays = {}
            self._root = nil
            return nil, "authored_bay_missing:" .. bay.id
        end
        local registered, reason = self:_registerBay(model, bay)
        if not registered then
            self._bays = {}
            self._root = nil
            return nil, reason
        end
    end

    root:SetAttribute("MergeEggBayCount", #layout)
    self:_log("Info", "Merge Egg authored realm bound", { bays = #layout })
    return self._bays
end

function MergeEggRealmBuilder:Ensure(mapsOrTemplate)
    if next(self._bays) ~= nil then
        return self._bays
    end
    local maps = ancestorMaps(mapsOrTemplate)
    local rootName = tostring(self._config.root_name or "MergeEggRealm")
    local root = maps and maps:FindFirstChild(rootName)
    if root and root:GetAttribute("MergeEggAuthoredRealm") == true then
        return self:_adoptAuthoredRealm(root)
    end

    return nil, root and "authored_realm_invalid" or "authored_realm_missing"
end

-- Explicit Edit-mode authoring operation. This is intentionally never called by Ensure/runtime.
function MergeEggRealmBuilder:Bake(template)
    if not (template and template:IsA("Model")) then
        return nil, "bay_template_missing"
    end
    local maps = ancestorMaps(template)
    if not maps then
        return nil, "maps_root_missing"
    end

    local templateCopy = template:Clone()
    removeBakedBayAdditions(templateCopy)
    local sourceFloor = firstPart(templateCopy, "LandStrip")
    if not sourceFloor then
        templateCopy:Destroy()
        return nil, "bay_template_floor_missing"
    end
    local sourceFloorCFrame = sourceFloor.CFrame

    local rootName = tostring(self._config.root_name or "MergeEggRealm")
    local temporaryName = rootName .. "__BAKE"
    local previousTemporary = maps:FindFirstChild(temporaryName)
    if previousTemporary then
        previousTemporary:Destroy()
    end
    local root = Instance.new("Model")
    root.Name = temporaryName
    root:SetAttribute("MapKind", "AuthoredMergeEggRealm")
    root:SetAttribute("MergeEggAuthoredRealm", true)
    root:SetAttribute("MergeEggGeneratedRealm", nil)
    root:SetAttribute("UsesTileSystem", false)
    root:SetAttribute("UsesTileStreaming", false)
    root.Parent = maps
    local baysFolder = Instance.new("Folder")
    baysFolder.Name = "Bays"
    baysFolder.Parent = root
    self._root = root
    self._bays = {}

    local layout = MergeEggRealmLayout.bays(self._config)
    for _, bay in ipairs(layout) do
        local model = templateCopy:Clone()
        model.Name = "MergeBay_" .. bay.id
        model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
        model.Parent = baysFolder
        local desiredFloor = CFrame.new(bay.centerX, sourceFloor.Position.Y, bay.centerZ)
            * CFrame.Angles(0, math.rad(bay.yawDegrees), 0)
        model:PivotTo(desiredFloor * sourceFloorCFrame:Inverse() * model:GetPivot())
        self:_styleBay(model, bay)
        local registered, reason = self:_registerBay(model, bay)
        if not registered then
            root:Destroy()
            templateCopy:Destroy()
            self._bays = {}
            self._root = nil
            return nil, reason
        end
    end
    templateCopy:Destroy()
    self:_buildHall(root)
    root:SetAttribute("MergeEggBayCount", #layout)
    root:SetAttribute("MergeEggHeavenBayCount", math.floor(#layout * 0.5))
    root:SetAttribute("MergeEggHellBayCount", math.ceil(#layout * 0.5))

    local stale = maps:FindFirstChild(rootName)
    if stale and stale ~= root then
        stale:Destroy()
    end
    local sourceName = tostring(self._config.source_model_name or "MergeEggPrototype")
    local topLevelSource = maps:FindFirstChild(sourceName)
    if topLevelSource and topLevelSource ~= root then
        topLevelSource:Destroy()
    end
    root.Name = rootName
    self:_log("Info", "Merge Egg permanent realm baked", { bays = #layout })
    return root, self._bays
end

function MergeEggRealmBuilder:SetClaimHandler(handler)
    self._claimHandler = type(handler) == "function" and handler or nil
end

function MergeEggRealmBuilder:GetBay(bayId)
    local bay = self._bays[tostring(bayId or "")]
    return bay and bay.model or nil
end

function MergeEggRealmBuilder:GetBays()
    return self._bays
end

function MergeEggRealmBuilder:Claim(player, bayId)
    local userId = player and player.UserId
    local bay = self._bays[tostring(bayId or "")]
    if not (userId and bay) then
        return nil, "bay_unavailable"
    end
    if bay.ownerUserId and bay.ownerUserId ~= userId then
        return nil, "bay_occupied"
    end
    local existing = self._claimsByUserId[userId]
    if existing and existing ~= bayId then
        return nil, "player_already_has_bay"
    end
    bay.ownerUserId = userId
    self._claimsByUserId[userId] = bayId
    bay.model:SetAttribute("MergeEggBayOwnerUserId", userId)
    bay.model:SetAttribute("MergeEggBayOwnerName", player.Name)
    bay.model:SetAttribute("MergeEggBayAvailable", false)
    for _, fixture in ipairs(bay.claimFixtures or {}) do
        fixture.prompt.Enabled = false
        fixture.prompt.ActionText = "Claimed"
        fixture.prompt.ObjectText = player.DisplayName .. "'s " .. bay.descriptor.displayName
        fixture.label.Text = string.upper(bay.descriptor.displayName .. "\n" .. player.DisplayName)
    end
    player:SetAttribute("MergeEggBayId", bayId)
    player:SetAttribute("MergeEggBaySide", bay.descriptor.side)
    player:SetAttribute("MergeEggBayColumn", bay.descriptor.column)
    return bay.model, bayId
end

function MergeEggRealmBuilder:ClaimRandom(player)
    local occupied = {}
    for id, bay in pairs(self._bays) do
        if bay.ownerUserId then
            occupied[id] = true
        end
    end
    local selected =
        MergeEggRealmLayout.pickAvailable(self._config, occupied, self._random:NextNumber())
    if not selected then
        return nil, "realm_full"
    end
    return self:Claim(player, selected.id)
end

function MergeEggRealmBuilder:Release(player)
    local userId = player and player.UserId
    local bayId = userId and self._claimsByUserId[userId]
    local bay = bayId and self._bays[bayId]
    if not bay then
        return false
    end
    bay.ownerUserId = nil
    self._claimsByUserId[userId] = nil
    bay.model:SetAttribute("MergeEggBayOwnerUserId", 0)
    bay.model:SetAttribute("MergeEggBayOwnerName", nil)
    bay.model:SetAttribute("MergeEggBayAvailable", true)
    for _, fixture in ipairs(bay.claimFixtures or {}) do
        fixture.prompt.Enabled = true
        fixture.prompt.ActionText = "Claim Bay"
        fixture.prompt.ObjectText = bay.descriptor.displayName
        fixture.label.Text = string.upper(bay.descriptor.displayName .. "\nAVAILABLE")
    end
    player:SetAttribute("MergeEggBayId", nil)
    player:SetAttribute("MergeEggBaySide", nil)
    player:SetAttribute("MergeEggBayColumn", nil)
    return true
end

return MergeEggRealmBuilder
