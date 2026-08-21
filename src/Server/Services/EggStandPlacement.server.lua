--[[
    EggStandPlacement — put the right egg on every AUTHORED egg-hatcher stand, resolved by world +
    area (no per-stand config, no fabricated stands).

    A stand is an authored map Model with a `UIanchor` part. This script walks every world folder
    under `Workspace.Maps`, and for each stand inside it:
        • realm = WorldContext.parseName(world folder).realm   (Home -> base, Heaven_1 -> heaven…)
        • egg   = EggStandResolver.eggFor(realm, stand.Name, pets.realm_area_eggs)   (name carries
                  the area: "Lava" -> lava, "Ice" -> ice)
    then clones the loaded egg model (ReplicatedStorage.Assets.Models.Eggs[eggId]) and centers it
    UPRIGHT on the stand's anchor (yaw only — never inherit the stand's pitch/roll, which is what
    put the old fabricated stand's egg on its side). Purely visual placement; the placed egg is
    tagged `EggStand` + stamped `EggId` so the existing hatch/preview path picks it up.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local petConfig = require(ReplicatedStorage:WaitForChild("Configs"):WaitForChild("pets"))
local hallConfig = require(ReplicatedStorage.Configs.hall_of_worlds)
local WorldContext = require(ReplicatedStorage.Shared.Game.WorldContext)
local EggStandResolver = require(ReplicatedStorage.Shared.Game.EggStandResolver)
local HallEggStand = require(ReplicatedStorage.Shared.Game.HallEggStand)
local BootReadiness = require(ReplicatedStorage.Shared.Boot.BootReadiness)

local matrix = petConfig.realm_area_eggs
if type(matrix) ~= "table" or next(matrix) == nil then
    return
end
local defaults = petConfig.egg_stand_defaults or {}
local SCALE = defaults.scale or 1
local OFFSET_Y = defaults.offset_y or 0
local hallStandSpec = type(hallConfig.egg_stand) == "table" and hallConfig.egg_stand or {}

local function isHallStand(stand)
    return stand.Name:find("HallEggStand", 1, true) ~= nil
end

local function placementScale(stand)
    if isHallStand(stand) then
        return tonumber(hallStandSpec.egg_scale) or SCALE
    end
    return SCALE
end

local function placementOffsetY(stand)
    if isHallStand(stand) then
        local offset = tonumber(hallStandSpec.egg_offset_y)
        if offset then
            return offset
        end
    end
    return OFFSET_Y
end

-- An egg-hatcher stand is an authored Model carrying a `UIanchor` part (the egg-centering anchor).
local function isStand(inst)
    return inst:IsA("Model") and inst:FindFirstChild("UIanchor") ~= nil
end

local function hallStandMesh(stand)
    local mesh = stand:FindFirstChild("hall_egg_stand", true)
    if mesh and mesh:IsA("BasePart") then
        return mesh
    end
    return nil
end

local function standMeshTopY(stand)
    local mesh = hallStandMesh(stand)
    if mesh then
        return mesh.Position.Y + mesh.Size.Y * 0.5
    end
    local maxY = -math.huge
    for _, descendant in ipairs(stand:GetDescendants()) do
        if
            descendant:IsA("BasePart")
            and descendant.Name ~= "UIanchor"
            and not descendant:FindFirstAncestor("PlacedEgg")
            and not descendant:FindFirstAncestor("DisplayEgg")
        then
            maxY = math.max(maxY, descendant.Position.Y + descendant.Size.Y * 0.5)
        end
    end
    if maxY == -math.huge then
        local bounds, size = stand:GetBoundingBox()
        return bounds.Position.Y + size.Y * 0.5
    end
    return maxY
end

local function alignHallStandToMesh(stand)
    local mesh = hallStandMesh(stand)
    if not mesh then
        return stand:GetPivot()
    end
    local _, yaw = mesh.CFrame:ToEulerAnglesYXZ()
    stand.WorldPivot = CFrame.new(mesh.Position.X, mesh.Position.Y, mesh.Position.Z)
        * CFrame.Angles(0, yaw, 0)
    return stand:GetPivot()
end

-- Hall eggs follow the visible pedestal mesh, not a stale model pivot.
local function snapHallAnchorToStand(stand)
    local pivot = alignHallStandToMesh(stand)
    local mesh = hallStandMesh(stand)
    local hover = tonumber(hallStandSpec.egg_hover_height) or 1.25
    local sourceX, sourceZ = HallEggStand.visualXZ(
        mesh and mesh.Position.X,
        mesh and mesh.Position.Z,
        pivot.Position.X,
        pivot.Position.Z
    )
    local x, y, z = HallEggStand.cupPosition(
        sourceX,
        sourceZ,
        standMeshTopY(stand),
        hover
    )
    if not x then
        return nil
    end
    local anchor = stand:FindFirstChild("UIanchor")
    if anchor and not anchor:IsA("BasePart") then
        anchor:Destroy()
        anchor = nil
    end
    if not anchor then
        anchor = Instance.new("Part")
        anchor.Name = "UIanchor"
        anchor.Size = Vector3.new(1, 1, 1)
        anchor.Transparency = 1
        anchor.Anchored = true
        anchor.CanCollide = false
        anchor.CanTouch = false
        anchor.CanQuery = false
        anchor.Parent = stand
    end
    local _, yaw = pivot:ToEulerAnglesYXZ()
    anchor.CFrame = CFrame.new(x, y, z) * CFrame.Angles(0, yaw, 0)
    return anchor
end

local function attachHallBayToStand(stand)
    local bayIndex = tonumber(stand:GetAttribute("BayIndex"))
    if not bayIndex then
        return
    end
    for _, marker in ipairs(CollectionService:GetTagged("HallEggBay")) do
        if tonumber(marker:GetAttribute("BayIndex")) == bayIndex then
            marker.CFrame = stand:GetPivot()
            marker.Parent = stand
        end
    end
end

-- Upright placement CFrame: the anchor's POSITION with YAW only, so the egg always stands up
-- regardless of how the stand mesh is tilted. Falls back to the model pivot if there's no anchor.
local function uprightCFrame(stand)
    local pos, yaw
    local anchor = stand:FindFirstChild("UIanchor")
    if anchor and anchor:IsA("BasePart") then
        pos = anchor.Position
        local _, y = anchor.CFrame:ToEulerAnglesYXZ()
        yaw = y
    else
        local ok, pivot = pcall(function()
            return stand:GetPivot()
        end)
        if ok then
            pos = pivot.Position
            local _, y = pivot:ToEulerAnglesYXZ()
            yaw = y
        end
    end
    if not pos then
        return nil
    end
    return CFrame.new(pos) * CFrame.Angles(0, yaw or 0, 0)
end

local function placeEgg(stand, eggTemplate, eggId)
    local existing = stand:FindFirstChild("PlacedEgg")
    if existing then
        existing:Destroy()
    end
    if isHallStand(stand) then
        snapHallAnchorToStand(stand)
        attachHallBayToStand(stand)
    end
    local cf = uprightCFrame(stand)
    if not cf then
        return
    end
    local offsetY = placementOffsetY(stand)
    local scale = placementScale(stand)
    if offsetY ~= 0 then
        cf = cf * CFrame.new(0, offsetY, 0)
    end
    local egg = eggTemplate:Clone()
    egg.Name = "PlacedEgg"
    for _, p in ipairs(egg:GetDescendants()) do
        if p:IsA("BasePart") then
            p.Anchored = true
            p.CanCollide = false
            p.CanQuery = false
        end
    end
    if egg:IsA("Model") then
        if not egg.PrimaryPart then
            egg.PrimaryPart = egg:FindFirstChildWhichIsA("BasePart")
        end
        if scale ~= 1 then
            pcall(function()
                egg:ScaleTo(scale)
            end)
        end
        if egg.PrimaryPart then
            egg:PivotTo(cf)
        end
    elseif egg:IsA("BasePart") then
        if scale ~= 1 then
            egg.Size = egg.Size * scale
        end
        egg.CFrame = cf
    end
    egg.Parent = stand
    egg:SetAttribute("IdleBaseOffsetY", offsetY)
    -- Make it a real, hatchable target (same wiring as before): tag + EggId register it in
    -- EggWorldQuery; stamp the EGG (not the stand) so proximity preview + hatch anchor on it.
    egg:SetAttribute("EggId", tostring(eggId))
    if not CollectionService:HasTag(egg, "EggStand") then
        CollectionService:AddTag(egg, "EggStand")
    end
    -- Hall query used to miss a stand whose PlacedEgg streamed late. The authored pedestal
    -- already carries EggId; tag it too so the hatch card can bind to UIanchor directly.
    if isHallStand(stand) then
        stand:SetAttribute("EggId", tostring(eggId))
        if not CollectionService:HasTag(stand, "EggStand") then
            CollectionService:AddTag(stand, "EggStand")
        end
    end
    if isHallStand(stand) then
        local adornee = egg:IsA("BasePart") and egg
            or egg.PrimaryPart
            or egg:FindFirstChildWhichIsA("BasePart", true)
        if adornee then
            local gui = Instance.new("BillboardGui")
            gui.Name = "HallHatchPrompt"
            gui.Adornee = adornee
            gui.AlwaysOnTop = true
            gui.Size = UDim2.fromOffset(150, 44)
            gui.StudsOffsetWorldSpace =
                Vector3.new(0, tonumber(hallStandSpec.prompt_height) or 4.8, 0)
            gui.MaxDistance = 28
            gui.Parent = egg
            local label = Instance.new("TextLabel")
            label.BackgroundColor3 = Color3.fromRGB(28, 18, 8)
            label.BackgroundTransparency = 0.15
            label.Size = UDim2.fromScale(1, 1)
            label.Font = Enum.Font.GothamBlack
            label.Text = "E  HATCH"
            label.TextColor3 = Color3.fromRGB(255, 245, 183)
            label.TextScaled = true
            label.Parent = gui
            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(0, 8)
            corner.Parent = label
        end
    end
    return egg
end

local function findAuthoredHallStand(marker)
    local bay = tostring(marker:GetAttribute("BayIndex") or "")
    local name = "HallEggStand" .. bay
    local ancestor = marker.Parent
    while ancestor and ancestor ~= Workspace do
        if ancestor.Name == name and ancestor:IsA("Model") then
            return ancestor
        end
        ancestor = ancestor.Parent
    end
    local parent = marker.Parent
    local stand = parent and parent:FindFirstChild(name)
    if stand and stand:IsA("Model") and stand:FindFirstChild("UIanchor") then
        return stand
    end
    local maps = Workspace:FindFirstChild("Maps")
    local hall = maps and maps:FindFirstChild("FuturePath")
    stand = hall and hall:FindFirstChild(name, true)
    if stand and stand:IsA("Model") then
        return stand
    end
    return nil
end

-- Dependency gate: the egg model TEMPLATES (Assets.Models.Eggs.*) are built by AssetPreloadService
-- AFTER this script first runs. Await its milestone (event-driven, race-free even if the signal
-- already fired) rather than polling an attribute. See docs/BOOT_ORCHESTRATION.md.
BootReadiness.await("models_ready")
BootReadiness.begin("eggs_placed") -- boot stage start (paired with signal below)

local assets = ReplicatedStorage:WaitForChild("Assets")
local eggsFolder = assets:WaitForChild("Models"):WaitForChild("Eggs")
local maps = Workspace:WaitForChild("Maps")

-- Discover authored stands per world and place their resolved egg.
local _standCount, _queued = 0, 0
for _, world in ipairs(maps:GetChildren()) do
    local parsed = WorldContext.parseName(world.Name)
    local realm = parsed and parsed.realm
    -- Layer-aware: prefer the depth-specific matrix ("heaven_2") when it exists, else fall back to
    -- the bare realm ("heaven") so Heaven_1/Hell_1 keep resolving exactly as before.
    local depth = parsed and parsed.depth
    local realmKey = realm
    if realm and depth and type(matrix[realm .. "_" .. depth]) == "table" then
        realmKey = realm .. "_" .. depth
    end
    if realmKey and type(matrix[realmKey]) == "table" then
        for _, inst in ipairs(world:GetDescendants()) do
            if isStand(inst) then
                _standCount += 1
                local eggId = EggStandResolver.eggFor(realmKey, inst.Name, matrix)
                if eggId then
                    -- ModelsReady guarantees every template is built, so a miss here is a real
                    -- config error (egg id with no model), not a load race.
                    local template = eggsFolder:FindFirstChild(tostring(eggId))
                    if template then
                        _queued += 1
                        placeEgg(inst, template, eggId)
                    else
                        warn(
                            ("[EggStandPlacement] no egg template '%s' for stand %s"):format(
                                tostring(eggId),
                                inst:GetFullName()
                            )
                        )
                    end
                end
            end
        end
    end
end

local function configuredHallEggId(marker)
    local authoredEggId = marker:GetAttribute("EggId")
    if type(authoredEggId) == "string" and authoredEggId ~= "" then
        return authoredEggId
    end

    -- The baked map can lag config while Hall content is being brought online. Resolve the route
    -- as the runtime authority so a finished egg never remains a dead preview merely because its
    -- Studio marker predates the gameplay configuration.
    local bayIndex = tonumber(marker:GetAttribute("BayIndex"))
    local route = type(hallConfig.route) == "table" and hallConfig.route[bayIndex]
    local egg = type(route) == "table" and route.egg
    local configuredEggId = type(egg) == "table" and egg.egg_id
    if type(configuredEggId) == "string" and configuredEggId ~= "" then
        return configuredEggId
    end
    return nil
end

local function retireHallPreview(stand)
    if not stand then
        return
    end
    local preview = stand:FindFirstChild("DisplayEgg")
    if preview then
        preview:Destroy()
    end
end

-- Hall pedestals are authored map fixtures (same as Crystal World). Runtime only places the
-- live egg on UIanchor. Route config can activate a bay even when an older baked marker
-- still lacks EggId; inactive bays keep their preview egg on the same stand.
if hallConfig.enabled and type(hallStandSpec) == "table" then
    local hallBays = CollectionService:GetTagged("HallEggBay")
    table.sort(hallBays, function(a, b)
        return (tonumber(a:GetAttribute("BayIndex")) or math.huge)
            < (tonumber(b:GetAttribute("BayIndex")) or math.huge)
    end)
    for _, marker in ipairs(hallBays) do
        if marker:IsA("BasePart") then
            local eggId = configuredHallEggId(marker)
            if type(eggId) == "string" and eggId ~= "" then
                local stand = findAuthoredHallStand(marker)
                retireHallPreview(stand)
                _standCount += 1
                local template = eggsFolder:FindFirstChild(eggId)
                if not stand then
                    warn(
                        ("[EggStandPlacement] Hall bay %s has no authored stand; run wire_hall_of_worlds"):format(
                            tostring(marker:GetAttribute("BayIndex"))
                        )
                    )
                elseif template then
                    local egg = placeEgg(stand, template, eggId)
                    if egg then
                        egg:SetAttribute(
                            "IdleFloatAmplitude",
                            tonumber(hallStandSpec.float_amplitude) or 0
                        )
                        egg:SetAttribute(
                            "IdleFloatPeriod",
                            tonumber(hallStandSpec.float_period) or 3.4
                        )
                        egg:SetAttribute("IdleBaseOffsetY", placementOffsetY(stand))
                        _queued += 1
                    end
                else
                    warn(("[EggStandPlacement] no Hall egg template '%s'"):format(eggId))
                end
            end
        end
    end
end
print(
    ("[EggStandPlacement] placed eggs on %d/%d authored stands across the worlds"):format(
        _queued,
        _standCount
    )
)
BootReadiness.signal("eggs_placed")
