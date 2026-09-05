-- Reuse Merge's ordinary economy/encounters with a private session map. No fake Player
-- instances, client remotes, alternate prices, or duplicated combat simulation.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Principal = require(ReplicatedStorage.Shared.Game.Principal)
local PetView = require(ReplicatedStorage.Shared.Inventory.PetInventoryView)
local Runtime = {}

local function noop() end

function Runtime.new(modules, actor, config)
    local merge = table.clone(modules.MergeEggPrototypeService)
    merge._activeByPlayer, merge._enteringByPlayer, merge._enteringRecordByPlayer = {}, {}, {}
    merge._portalTransitByPlayer, merge._towerShots, merge._combatTrainingReturns = {}, {}, {}
    merge._mergeAnalyticsService, merge._achievementBannerService = nil, nil
    merge._settingsService, merge._worldBindingService = nil, nil
    merge._automationService = nil
    merge._bindWorldControls, merge._ensureBayQuartermaster = noop, noop
    merge._analytics, merge._analyticsFailure = noop, noop
    merge._schedulePlayerAssetWarmup, merge._startTutorial = noop, noop
    local autoplay = table.clone(modules.MergeAutoplayService)
    autoplay._merge = merge
    autoplay._states, autoplay._requests, autoplay._reports = {}, {}, {}
    -- Eligibility was checked before acquiring this account; remote users cannot enter here.
    autoplay._owned = function(_, candidate)
        return candidate == actor and actor.Parent ~= nil
    end
    return setmetatable({
        merge = merge,
        autoplay = autoplay,
        actor = actor,
        config = config,
        modules = modules,
        nextNavigation = 0,
    }, { __index = Runtime })
end

function Runtime:syncSquad()
    local actor, modules = self.actor, self.modules
    local record = self.merge:_recordFor(actor)
    if not record or record.playerCombatMode ~= "full" then
        return
    end
    local data = modules.DataService:GetData(actor)
    local inventory = data and data.Inventory and data.Inventory.pets
    if not inventory then
        return
    end
    local inv = modules.InventoryService
    local configured = inv._inventoryConfig.equipped.pets.slots
    local maximum = inv:_getMaxEquippedSlots(actor, "pets", configured)
    local slots = PetView.resolveEquipped(inventory.items, data.Equipped.pets, maximum)
    local locks = inv:_lockedPetSlots(actor)
    local folder = self.merge:_playerPetFolder(actor, true)
    folder:SetAttribute("NpcSquad", true)
    folder:SetAttribute("OfflineOwnedSquad", true)
    folder:SetAttribute("NpcOwner", actor.Name)
    folder:SetAttribute("CombatTargetOpen", true)
    for slot, desc in pairs(slots) do
        local name = tostring(slot)
        if not folder:FindFirstChild(name) and not locks["slot_" .. name] and not locks[slot] then
            local key = desc.uid or desc.stackKey
            local item = inventory.items[key]
            local model = modules.NpcPrincipalService:_clonePet(desc.id, desc.variant)
            if model then
                model.Name = name
                model:SetAttribute("PetType", desc.id)
                model:SetAttribute("PetVariant", desc.variant or "basic")
                model:SetAttribute("Variant", desc.variant or "basic")
                model:SetAttribute("PetRecordKey", key)
                model:SetAttribute("LockoutSpecial", desc.kind == "special")
                model:SetAttribute("LockoutUid", desc.uid)
                model:SetAttribute("LockoutKey", desc.stackKey)
                model:SetAttribute("PrincipalLevel", actor:GetAttribute("Level"))
                model:SetAttribute("CombatTargetOpen", true)
                modules.NpcPrincipalService:_applyHuge(
                    model,
                    { pet = desc.id, huge = item.huge },
                    modules.ConfigLoader:LoadConfig("pets")
                )
                local position = model:FindFirstChild("PositionNumber") or Instance.new("IntValue")
                position.Name, position.Value, position.Parent = "PositionNumber", slot, model
                model:PivotTo(actor.Character:GetPivot())
                model.Parent = folder
            end
        end
    end
    Principal.register({
        name = actor.Name,
        level = actor:GetAttribute("Level"),
        character = actor.Character,
        petFolderName = actor.Name,
        owner = actor,
    })
end

function Runtime:begin(bayId)
    local ok, reason = self.merge:_begin(self.actor, bayId)
    if not ok then
        return false, reason
    end
    self:syncSquad()
    self.navigationGeneration = 0
    self.targetChanged = self.actor
        :GetAttributeChangedSignal("MergeAutoplayTarget")
        :Connect(function()
            self.navigationGeneration += 1
            if self.actor:GetAttribute("MergeAutoplayTarget") == nil then
                local root = self.actor.Character
                    and self.actor.Character:FindFirstChild("HumanoidRootPart")
                local hum = self.actor.Character
                    and self.actor.Character:FindFirstChildOfClass("Humanoid")
                if root and hum then
                    hum:MoveTo(root.Position)
                end
            end
        end)
    return self.autoplay:_begin(self.actor)
end

function Runtime:navigate(target, hum, root)
    if self.navigationBusy then
        return
    end
    self.navigationBusy = true
    local generation = self.navigationGeneration
    local nav = self.autoplay._config.navigation
    task.spawn(function()
        local function current()
            return not self.stopped
                and self.actor.Parent
                and root.Parent
                and hum.Parent
                and generation == self.navigationGeneration
        end
        local ok, err = pcall(function()
            local path = game:GetService("PathfindingService"):CreatePath({
                AgentRadius = nav.agent_radius,
                AgentHeight = nav.agent_height,
                AgentCanJump = true,
                WaypointSpacing = nav.waypoint_spacing,
            })
            local destination = Vector3.new(target.X, root.Position.Y, target.Z)
            path:ComputeAsync(root.Position, destination)
            if not current() or path.Status ~= Enum.PathStatus.Success then
                return
            end
            local points = path:GetWaypoints()
            if #points > self.config.max_navigation_waypoints then
                return
            end
            for _, point in ipairs(points) do
                if not current() then
                    break
                end
                if point.Action == Enum.PathWaypointAction.Jump then
                    hum.Jump = true
                end
                hum:MoveTo(point.Position)
                local deadline = os.clock() + nav.waypoint_timeout_seconds
                while current() and os.clock() < deadline do
                    local delta = root.Position - point.Position
                    if Vector3.new(delta.X, 0, delta.Z).Magnitude <= nav.waypoint_distance then
                        break
                    end
                    task.wait(nav.poll_seconds)
                end
                if os.clock() >= deadline then
                    break
                end
            end
        end)
        if not ok and self.actor.Parent then
            self.actor:SetAttribute("OfflineNavigationError", tostring(err))
        end
        self.navigationBusy = false
    end)
end

function Runtime:step(dt)
    local actor = self.actor
    local record = self.merge:_recordFor(actor)
    if not record then
        return false, "session_ended"
    end
    self.merge:_step(dt)
    local state = self.autoplay._states[actor]
    if state then
        self.autoplay:_tick(actor, state)
    elseif not record.terminal then
        self.autoplay:_begin(actor)
    end
    if os.clock() >= self.nextNavigation then
        self.nextNavigation = os.clock() + self.config.navigation_seconds
        self:syncSquad()
        local target = actor:GetAttribute("MergeAutoplayTarget")
        local hum = actor.Character:FindFirstChildOfClass("Humanoid")
        local root = actor.Character:FindFirstChild("HumanoidRootPart")
        if not hum or hum.Health <= 0 then
            return false, "character_down"
        end
        if target and root then
            self:navigate(target, hum, root)
        end
    end
    return true
end

function Runtime:stop()
    self.stopped = true
    if self.targetChanged then
        self.targetChanged:Disconnect()
    end
    self.autoplay:Stop(self.actor)
    local record = self.merge:_recordFor(self.actor)
    local ok, err = pcall(function()
        if record then
            self.merge:_end(record, false, true)
        end
    end)
    -- Always remove the owner's personal squad even if encounter teardown reports an error.
    Principal.unregister(self.actor.Name)
    local folder = self.merge:_playerPetFolder(self.actor, false)
    if folder then
        folder:Destroy()
    end
    if not ok then
        error(err)
    end
end

return Runtime
