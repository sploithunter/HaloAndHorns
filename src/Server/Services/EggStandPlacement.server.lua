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
local WorldContext = require(ReplicatedStorage.Shared.Game.WorldContext)
local EggStandResolver = require(ReplicatedStorage.Shared.Game.EggStandResolver)
local BootReadiness = require(ReplicatedStorage.Shared.Boot.BootReadiness)

local matrix = petConfig.realm_area_eggs
if type(matrix) ~= "table" or next(matrix) == nil then
    return
end
local defaults = petConfig.egg_stand_defaults or {}
local SCALE = defaults.scale or 1
local OFFSET_Y = defaults.offset_y or 0

-- An egg-hatcher stand is an authored Model carrying a `UIanchor` part (the egg-centering anchor).
local function isStand(inst)
    return inst:IsA("Model") and inst:FindFirstChild("UIanchor") ~= nil
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
    local cf = uprightCFrame(stand)
    if not cf then
        return
    end
    if OFFSET_Y ~= 0 then
        cf = cf * CFrame.new(0, OFFSET_Y, 0)
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
        if SCALE ~= 1 then
            pcall(function()
                egg:ScaleTo(SCALE)
            end)
        end
        if egg.PrimaryPart then
            egg:PivotTo(cf)
        end
    elseif egg:IsA("BasePart") then
        if SCALE ~= 1 then
            egg.Size = egg.Size * SCALE
        end
        egg.CFrame = cf
    end
    egg.Parent = stand
    -- Make it a real, hatchable target (same wiring as before): tag + EggId register it in
    -- EggWorldQuery; stamp the EGG (not the stand) so proximity preview + hatch anchor on it.
    egg:SetAttribute("EggId", tostring(eggId))
    if not CollectionService:HasTag(egg, "EggStand") then
        CollectionService:AddTag(egg, "EggStand")
    end
    return egg
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
print(
    ("[EggStandPlacement] placed eggs on %d/%d authored stands across the worlds"):format(
        _queued,
        _standCount
    )
)
BootReadiness.signal("eggs_placed")
