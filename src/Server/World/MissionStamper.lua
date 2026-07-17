--[[
    MissionStamper — LayoutSpec → cloned tile Instances under an instance slot.
    (docs/MISSION_WORLDGEN.md §5.1)

    stamp(spec, opts) → container, hooks
        spec: LayoutSolver.solve output (placements are { x, z, rot } with
              rot ∈ 0..3 quarter turns — converted here, nowhere else:
              slotOrigin * CFrame.new(x, 0, z) * CFrame.Angles(0, rot*π/2, 0))
        opts:
            kitFolder   (Folder, required) tile Models named by tileId
            slotOrigin  (CFrame, required) instance slot origin
            instanceId  (string, required) unique id for this instance
            areaId      (string?) default "mission:<instanceId>"
            parent      (Instance?) default Workspace.MissionInstances (created)
            yieldEvery  (number?) tiles per task.wait() batch; 0 = never yield
                        (Edit-mode / synchronous callers). Default 25.

    Behaviour per contract:
      - builds DETACHED, parents once at the end (single replication burst)
      - per tile: ModelStreamingMode = Atomic, strip Bounds, rewrite every
        "$MISSION" attribute placeholder to the areaId
      - hooks collected by tag: PlayerSpawn, MissionObjective, SpawnZone
      - container attributes: Seed, KitId, AreaId, InstanceId, Synthetic=true
        (the WorldBindingService convention for generated content)
]]

local CollectionService = game:GetService("CollectionService")

local MissionStamper = {}

local HOOK_TAGS = { "PlayerSpawn", "MissionObjective", "SpawnZone" }

local function rewritePlaceholders(instance, areaId)
    for name, value in pairs(instance:GetAttributes()) do
        if type(value) == "string" and value:find("$MISSION", 1, true) then
            instance:SetAttribute(name, value:gsub("%$MISSION", areaId))
        end
    end
end

local function collectHooks(model, hooks)
    for _, desc in ipairs(model:GetDescendants()) do
        for _, tag in ipairs(HOOK_TAGS) do
            if CollectionService:HasTag(desc, tag) then
                hooks[tag] = hooks[tag] or {}
                table.insert(hooks[tag], desc)
            end
        end
    end
end

function MissionStamper.stamp(spec, opts)
    assert(type(spec) == "table" and spec.tiles, "MissionStamper.stamp: LayoutSpec required")
    assert(opts and opts.kitFolder, "MissionStamper.stamp: opts.kitFolder required")
    assert(opts.slotOrigin, "MissionStamper.stamp: opts.slotOrigin required")
    assert(type(opts.instanceId) == "string", "MissionStamper.stamp: opts.instanceId required")

    local areaId = opts.areaId or ("mission:" .. opts.instanceId)
    local yieldEvery = opts.yieldEvery or 25

    local container = Instance.new("Model")
    container.Name = "MissionInstance_" .. opts.instanceId
    container:SetAttribute("InstanceId", opts.instanceId)
    container:SetAttribute("AreaId", areaId)
    container:SetAttribute("KitId", spec.kitId)
    container:SetAttribute("Seed", spec.seed)
    container:SetAttribute("Synthetic", true)
    -- keep WorldBindingService (and any authored-map hook sweep) out of
    -- generated content — mission hooks use synthetic mission:* area ids
    container:SetAttribute("WorldBindingIgnore", true)

    local hooks = {}

    for i, t in ipairs(spec.tiles) do
        local template = opts.kitFolder:FindFirstChild(t.tileId)
        assert(
            template,
            ("MissionStamper: kit %q has no tile %q"):format(
                tostring(spec.kitId),
                tostring(t.tileId)
            )
        )

        local clone = template:Clone()
        clone.Name = ("%s_%d"):format(t.tileId, i)
        clone.ModelStreamingMode = Enum.ModelStreamingMode.Atomic

        -- TileRoot is the placement contract. Reassert it on the clone so a
        -- stale/captured Model.WorldPivot can never offset the stamped floor.
        local tileRoot = clone:FindFirstChild("TileRoot")
        assert(
            tileRoot and tileRoot:IsA("BasePart"),
            ("MissionStamper: tile %q has no BasePart TileRoot"):format(tostring(t.tileId))
        )
        clone.PrimaryPart = tileRoot

        local bounds = clone:FindFirstChild("Bounds")
        if bounds then
            bounds:Destroy()
        end

        clone:PivotTo(
            opts.slotOrigin * CFrame.new(t.x, 0, t.z) * CFrame.Angles(0, t.rot * math.pi / 2, 0)
        )

        rewritePlaceholders(clone, areaId)
        for _, desc in ipairs(clone:GetDescendants()) do
            rewritePlaceholders(desc, areaId)
        end
        collectHooks(clone, hooks)

        clone.Parent = container

        if yieldEvery > 0 and i % yieldEvery == 0 then
            task.wait()
        end
    end

    local parent = opts.parent
    if not parent then
        parent = workspace:FindFirstChild("MissionInstances")
        if not parent then
            parent = Instance.new("Folder")
            parent.Name = "MissionInstances"
            parent.Parent = workspace
        end
    end
    container.Parent = parent

    return container, hooks
end

return MissionStamper
