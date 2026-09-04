-- Coin-only online autoplay. Client navigation is advisory: the server chooses every action,
-- revalidates its price/record, and invokes ordinary distance-checked gameplay methods.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Policy = require(ReplicatedStorage.Shared.Game.MergeAutoplayPolicy)
local Towers = require(ReplicatedStorage.Shared.Game.MergeTowerProgression)
local Bulwarks = require(ReplicatedStorage.Shared.Game.MergeBulwarkProgression)
local Replacement = require(ReplicatedStorage.Shared.Game.MergeReplacementConfirmation)
local Signals = require(ReplicatedStorage.Shared.Network.Signals)
local Service = {}

local function part(instance)
    if not instance then
        return nil
    end
    if instance:IsA("BasePart") then
        return instance
    end
    return instance:FindFirstChildWhichIsA("BasePart", true)
end

function Service:Init()
    self._config = self._modules.ConfigLoader:LoadConfig("merge_autoplay")
    self._merge = self._modules.MergeEggPrototypeService
    self._data = self._modules.DataService
    self._economy = self._modules.EconomyService
    self._states, self._requests, self._reports = {}, {}, {}
end

function Service:_owned(player)
    return self._data:GetFeature(player, self._config.entitlement_feature) == true
end

function Service:_status(player, key, target)
    player:SetAttribute("MergeAutoplayStatus", self._config.labels[key])
    player:SetAttribute("MergeAutoplayTarget", target)
end

function Service:Report(player)
    local state = self._states[player]
    if not state then
        return self._reports[player]
    end
    return {
        strategy = state.strategy,
        elapsedSeconds = os.clock() - state.started,
        wave = state.record.waveIndex,
        startingWave = state.startingWave,
        actions = table.clone(state.actions),
        coinsSpent = state.spent,
        navigationFailures = state.navigationFailures,
        history = table.clone(state.history),
        testing = state.testing,
        xpEarned = math.max(0, (player:GetAttribute("XPTotal") or 0) - state.startingXP),
    }
end

function Service:Stop(player, reason)
    self._reports[player] = self:Report(player)
    self._states[player] = nil
    player:SetAttribute("MergeAutoplayEnabled", false)
    self:_status(player, reason or "stopped", nil)
end

function Service:_begin(player, options)
    options = options or {}
    local record = self._merge:_recordFor(player)
    if
        not self._config.enabled
        or not self._merge:_allowsGameplayActions()
        or not record
        or not self._merge:_isRecordActive(record)
        or record.entryInitializing
        or record.terminal
        or not record.encounterSpawned
    then
        self:_status(player, "session_ended", nil)
        return false, "session_ended"
    end
    if not self:_owned(player) then
        self:_status(player, "pass_required", nil)
        return false, "pass_required"
    end
    if record.coinRunnerRunning then
        return false, "busy"
    end
    local testing = RunService:IsStudio() and options.testing == true
    local strategy = testing and options.strategy or self._config.default_strategy
    if not self._config.strategies[strategy] then
        return false, "invalid_strategy"
    end
    self:Stop(player)
    self._states[player] = {
        record = record,
        character = player.Character,
        strategy = strategy,
        testing = testing,
        allowReplacement = testing and options.allowReplacement == true,
        started = os.clock(),
        startingWave = record.waveIndex,
        startingXP = player:GetAttribute("XPTotal") or 0,
        cursor = 1,
        blocked = {},
        actions = {},
        history = {},
        spent = 0,
        failures = 0,
        navigationFailures = 0,
        nextAction = 0,
        nextReport = os.clock() + self._config.report_seconds,
    }
    player:SetAttribute("MergeAutoplayEnabled", true)
    self:_status(player, "ready", nil)
    return true
end

function Service:HandleToggle(player, request)
    if type(request) ~= "table" or type(request.enabled) ~= "boolean" then
        return
    end
    -- Stop is never rate-limited, and the production request cannot supply testing options.
    if not request.enabled then
        self:Stop(player)
        return
    end
    local now = os.clock()
    if now < (self._requests[player] or 0) then
        return
    end
    self._requests[player] = now + self._config.request_seconds
    if not self._states[player] then
        self:_begin(player)
    end
end

function Service:_station(record)
    return part(record.world:FindFirstChild(self._merge._config.world.egg_merge_control, true))
end

function Service:_vendor(record, category, slot)
    local folder =
        record.world:FindFirstChild(category == "cannon" and "MergeEggTowers" or "MergeEggBulwarks")
    if not folder then
        return nil
    end
    if category == "cannon" then
        local commander = self._merge:_findArtilleryCommander(folder, slot)
        return commander and commander:GetAttribute("MergeVendorPosted") == true and part(commander)
            or nil
    end
    for _, child in ipairs(folder:GetChildren()) do
        if
            child:GetAttribute("MergeBulwarkSlot") == slot
            and child:GetAttribute("MergeVendorPosted") == true
        then
            return part(child)
        end
    end
    return nil
end

function Service:_defenses(state, candidates, category)
    local merge, record = self._merge, state.record
    local progression = category == "cannon" and Towers or Bulwarks
    local cfg = category == "cannon" and merge:_edgeTowerConfig() or merge:_edgeBulwarkConfig()
    local strategy = self._config.strategies[state.strategy]
    for _, slot in ipairs(progression.slots.ids()) do
        local menu = category == "cannon" and merge:_cannonMenuState(record, slot)
            or merge:_bulwarkMenuState(record, slot)
        local host = self:_vendor(record, category, slot)
        local vendor = category == "cannon" and "artillery" or "bulwark"
        if host and menu.slotUnlocked and merge:_tutorialVendorsReady(record, vendor, slot) then
            local family = menu.family
            if not family or state.allowReplacement then
                for _, preferred in
                    ipairs(category == "cannon" and strategy.cannons or strategy.bulwarks)
                do
                    if menu.owned[preferred] and progression.canInstall(preferred, slot) then
                        family = preferred
                        break
                    end
                end
            end
            local replacing = menu.family ~= nil and family ~= menu.family
            local operation = menu.family == family and "upgrade" or "select"
            local tier = operation == "upgrade" and menu.tier + 1 or 1
            if family and tier <= menu.maximumTier then
                local cost = progression.actionCost(cfg, operation, family, tier)
                candidates[#candidates + 1] = {
                    key = category .. ":" .. slot .. ":" .. family .. ":" .. tier,
                    kind = category,
                    category = category,
                    host = host,
                    family = family,
                    slot = slot,
                    operation = operation,
                    amount = cost.amount,
                    currency = cost.currency,
                    replacing = replacing,
                    confirmation = Replacement.key(slot, menu.family, menu.tier, family),
                }
            end
        end
    end
end

function Service:_candidates(state)
    local merge, record, cfg = self._merge, state.record, self._config
    local candidates, host = {}, self:_station(record)
    local function add(kind, cost, freePriority, target)
        candidates[#candidates + 1] = {
            key = kind,
            kind = kind,
            category = "eggs",
            host = target or host,
            currency = cost and cost.currency or cfg.currency,
            amount = cost and cost.amount or 0,
            freePriority = freePriority,
            priority = kind == "upgrade_base" and 1 or 2,
        }
    end
    if host then
        if #merge:_equipBestPlan(record) > 0 then
            local board = merge:_ensureMergeBoard(record.world)
            add("place", nil, 1, board and board.PrimaryPart)
        elseif merge:_mergeableEggTier(record) then
            add("merge", nil, 2)
        end
        if merge:_canUpgradeBaseEgg(record) then
            local cost = merge:_baseEggUpgradeCost(record)
            if cost then
                add("upgrade_base", cost)
            end
        end
        if merge:_eggInventoryTotal(record) < merge:_mergeBoardCapacity(record) then
            add("create", merge:_baseEggCreationCost(record))
        end
    end
    self:_defenses(state, candidates, "cannon")
    self:_defenses(state, candidates, "bulwark")
    return candidates
end

function Service:_execute(player, action)
    local merge = self._merge
    if action.kind == "create" then
        return merge:CreateBaseEgg(player, { managementBoard = true })
    end
    if action.kind == "upgrade_base" then
        return merge:UpgradeBaseEgg(player, { managementBoard = true })
    end
    if action.kind == "place" then
        return merge:EquipBestHatchers(player)
    end
    if action.kind == "merge" then
        return merge:MergeBoardEggs(player, {})
    end
    local request = {
        slot = action.slot,
        family = action.family,
        replacementConfirmationKey = action.confirmation,
    }
    if action.kind == "cannon" then
        request.cannonAction = action.operation
        return merge:PurchaseCannonAction(player, request)
    elseif action.kind == "bulwark" then
        request.bulwarkAction = action.operation
        return merge:PurchaseBulwarkAction(player, request)
    end
    return false, "unsupported_action"
end

function Service:_tick(player, state)
    local cfg, merge = self._config, self._merge
    local humanoid = player.Character and player.Character:FindFirstChildWhichIsA("Humanoid")
    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if self._states[player] ~= state then
        return
    end
    if
        player.Character ~= state.character
        or not root
        or not humanoid
        or humanoid.Health <= 0
        or merge:_recordFor(player) ~= state.record
        or not merge:_isRecordActive(state.record)
        or state.record.terminal
        or state.record.coinRunnerRunning
        or (merge._portalTransitByPlayer or {})[player]
        or not self:_owned(player)
    then
        self:Stop(player, "session_ended")
        return
    end
    local now = os.clock()
    for key, untilTime in pairs(state.blocked) do
        if untilTime <= now then
            state.blocked[key] = nil
        end
    end
    if now >= state.nextReport then
        state.nextReport = now + cfg.report_seconds
        self._modules.Logger:Info("Merge autoplay interval", self:Report(player))
    end
    if now < state.nextAction then
        return
    end
    local candidates = self:_candidates(state)
    local action = Policy.choose(candidates, state, cfg, now)
    if not action or action.amount > (self._economy:GetCurrency(player, cfg.currency) or 0) then
        local drop = merge:_nearestPrototypeCoinDrop(player)
        if drop and not state.blocked[drop] then
            action = {
                kind = "collect",
                key = drop,
                host = part(drop),
                amount = 0,
                currency = cfg.currency,
            }
        else
            action = nil
        end
    end
    if not action or not action.host or not action.host.Parent then
        self:_status(player, "idle", nil)
        state.targetKey = nil
        return
    end
    if state.targetKey ~= action.key then
        state.targetKey = action.key
        state.targetSince = now
    end
    if now - state.targetSince > cfg.target_timeout_seconds then
        state.blocked[action.key] = now + cfg.blocked_retry_seconds
        state.targetKey = nil
        state.navigationFailures += 1
        state.failures += 1
        if state.failures >= cfg.maximum_failures then
            self:Stop(player, "navigation_failed")
        end
        return
    end
    local destination = action.host.Position
    self:_status(player, action.kind, destination)
    local offset = root.Position - destination
    local radius = action.kind == "collect" and cfg.collect_distance or cfg.arrival_distance
    if
        Vector3.new(offset.X, 0, offset.Z).Magnitude > radius
        or math.abs(offset.Y) > cfg.maximum_vertical_distance
    then
        return
    end
    if action.kind == "collect" then
        return
    end -- DropService alone collects/grants through normal proximity.
    -- Candidates were just rebuilt from authoritative current costs and ownership. No client
    -- action payload ever reaches this whitelist, including on the Studio strategy path.
    if not Policy.allowed(action, cfg, state.testing and state.allowReplacement) then
        return
    end
    self:_status(player, action.kind, nil)
    local before = self._economy:GetCurrency(player, cfg.currency) or 0
    local ok, reason = self:_execute(player, action)
    if self._states[player] ~= state then
        return
    end
    state.nextAction = os.clock() + cfg.action_seconds
    state.targetKey = nil
    if ok then
        state.failures = 0
        state.spent += math.max(0, before - (self._economy:GetCurrency(player, cfg.currency) or 0))
        state.actions[action.kind] = (state.actions[action.kind] or 0) + 1
        if action.cursor then
            state.cursor = action.cursor + 1
        end
    else
        state.blocked[action.key] = os.clock() + cfg.blocked_retry_seconds
        state.failures += 1
    end
    state.history[#state.history + 1] = {
        kind = action.kind,
        slot = action.slot,
        family = action.family,
        wave = state.record.waveIndex,
        ok = ok == true,
        reason = ok and nil or tostring(reason),
    }
    if #state.history > cfg.history_limit then
        table.remove(state.history, 1)
    end
    if state.failures >= cfg.maximum_failures then
        self:Stop(player, "error")
    end
end

-- Studio-only server BindableFunction, never a replicated remote. Uses normal cost/proximity
-- checks, no balance grants, no production rebirth switch, and requires explicit confirmation.
function Service:StudioControl(player, request)
    if not RunService:IsStudio() or type(request) ~= "table" then
        return false
    end
    if request.action == "report" then
        return self:Report(player)
    end
    if request.action == "start" then
        return self:_begin(player, {
            testing = true,
            strategy = request.strategy or self._config.default_strategy,
            allowReplacement = request.allowReplacement == true,
        })
    end
    if request.action == "stop" then
        self:Stop(player)
        return true
    end
    if request.action == "rebirth" and request.confirmRebirth == true then
        self:Stop(player)
        local record = self._merge:_recordFor(player)
        local status = record and self._merge:_rebirthStatus(record)
        if not status or not status.price or status.price.currency ~= self._config.currency then
            return false
        end
        return self._merge:PurchaseRebirth(player, { confirm = true })
    end
    return false
end

function Service:Start()
    if not self._config.enabled then
        return
    end
    Signals.MergeAutoplayToggle.OnServerEvent:Connect(function(player, request)
        self:HandleToggle(player, request)
    end)
    Players.PlayerRemoving:Connect(function(player)
        self:Stop(player)
        self._requests[player] = nil
        self._reports[player] = nil
    end)
    if RunService:IsStudio() then
        local control = Instance.new("BindableFunction")
        control.Name = "MergeAutoplayStudioControl"
        control.OnInvoke = function(player, request)
            return self:StudioControl(player, request)
        end
        control.Parent = ServerStorage
    end
    local elapsed = 0
    RunService.Heartbeat:Connect(function(dt)
        elapsed += dt
        if elapsed >= self._config.tick_seconds then
            elapsed = 0
            for _, player in ipairs(Players:GetPlayers()) do
                player:SetAttribute("MergeAutoplayOwned", self:_owned(player))
                local state = self._states[player]
                if state and not state.busy then
                    state.busy = true
                    task.spawn(function()
                        local ok, err = pcall(self._tick, self, player, state)
                        state.busy = false
                        if not ok then
                            self._modules.Logger:Warn(
                                "Autoplay stopped safely",
                                { player = player.Name, error = tostring(err) }
                            )
                            if self._states[player] == state then
                                self:Stop(player, "error")
                            end
                        end
                    end)
                end
            end
        end
    end)
end

return Service
