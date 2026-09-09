-- One shared, server-owned encounter on the authored arena floor.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Debris = game:GetService("Debris")
local Rules = require(ReplicatedStorage.Shared.Game.CrossroadsArenaRules)
local Population = require(ReplicatedStorage.Shared.Worldgen.MissionPopulation)
local PlaceRuntime = require(ReplicatedStorage.Shared.Game.PlaceRuntime)
local Arena = {}
Arena.__index = Arena

local function resolve(path)
    local node = workspace
    for _, name in ipairs(path) do
        node = node and node:FindFirstChild(name)
    end
    return node
end

function Arena.new()
    return setmetatable({}, Arena)
end

function Arena:Init()
    self.cfg = self._modules.ConfigLoader:LoadConfig("crossroads_arena")
    self.missions = self._modules.ConfigLoader:LoadConfig("missions")
    self.places = self._modules.ConfigLoader:LoadConfig("places")
    self.enemy = self._modules.EnemyService
    self.data = self._modules.DataService
    self.nextAt = 0
end

function Arena:_inside(player, inset)
    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    if not root or not hum or hum.Health <= 0 or not self.bounds or not self.floor then
        return false
    end
    local p = self.bounds.CFrame:PointToObjectSpace(root.Position)
    local floorY = self.floor.Position.Y + self.floor.Size.Y / 2
    return math.abs(p.X) <= self.bounds.Size.X / 2 - inset
        and math.abs(p.Z) <= self.bounds.Size.Z / 2 - inset
        and root.Position.Y >= floorY - self.cfg.participant_below_floor
        and root.Position.Y <= floorY + self.cfg.participant_height
end

function Arena:_eligible(player)
    if not self:_inside(player, self.cfg.entry_inset) or not self.data:GetData(player) then
        return false
    end
    if player:GetAttribute("MissionId") or player:GetAttribute("SpiritForm") == true then
        return false
    end
    local folders = workspace:FindFirstChild("PlayerPets")
    local folder = folders and folders:FindFirstChild(player.Name)
    for _, pet in ipairs(folder and folder:GetChildren() or {}) do
        if pet:IsA("Model") and not pet:GetAttribute("CombatDowned") then
            return true
        end
    end
    return false
end

function Arena:_clear(reason)
    local run = self.run
    self.run = nil -- invalidates every yielding spawn before teardown
    if run then
        for _, model in ipairs(run.models) do
            self.enemy:DespawnModel(model)
        end
        for _, marker in ipairs(run.markers) do
            marker:Destroy()
        end
    end
    if self.bounds and self.bounds.Parent then
        self.bounds:SetAttribute("ArenaState", reason)
        self.bounds:SetAttribute("ArenaEnemies", 0)
    end
    self.nextAt = os.clock() + self.cfg.round_pause_seconds
end

function Arena:_begin(player, entrants)
    local tuner = self.enemy:_resolveEnemyTuner(player)
    local level = tonumber(tuner:GetAttribute("EffectiveLevel") or tuner:GetAttribute("Level"))
    if not level then
        return
    end
    local count = 0
    for _, member in ipairs(entrants) do
        if member == player or self.enemy:_onTeamName(player, member.Name) then
            count += 1
        end
    end
    local plan = Rules.plan(
        self.cfg,
        self.missions,
        level,
        tuner:GetAttribute("TrialGroupScale"),
        count,
        Random.new():NextInteger(1, self.cfg.seed_max),
        Population
    )
    if not plan then
        return
    end
    local run = {
        id = HttpService:GenerateGUID(false),
        models = {},
        markers = {},
        remaining = 0,
        pending = true,
        startedAt = os.clock(),
        player = player,
    }
    self.run = run
    self.bounds:SetAttribute("ArenaState", "arriving")
    self.bounds:SetAttribute("ArenaTeam", plan.team.name)
    self.bounds:SetAttribute("ArenaTuner", tuner.UserId)
    self.bounds:SetAttribute("ArenaLevel", level)
    self.bounds:SetAttribute("ArenaGroupScale", plan.groupScale)
    self.bounds:SetAttribute("ArenaTeamScale", plan.teamScale)
    task.spawn(function()
        local ok, err = pcall(function()
            local center = self.bounds.Position
            local floorY = self.floor.Position.Y + self.floor.Size.Y / 2
            local shape = {
                kind = "box",
                cx = center.X,
                cz = center.Z,
                halfX = self.bounds.Size.X / 2,
                halfZ = self.bounds.Size.Z / 2,
            }
            local hpMult, damageMult = Rules.onramp(self.cfg, level)
            local prepared = {}
            for index, unit in ipairs(plan.units) do
                if self.run ~= run or not self:_eligible(player) then
                    return
                end
                local rank = table.clone(self.missions.pet_ranks[unit.rank])
                rank.tier = self.cfg.rank_tiers[unit.rank]
                local def = assert(
                    self.enemy:SynthesizePetEnemy(unit.pet, rank, level),
                    "Missing arena pet"
                )
                def.hp = math.max(1, math.floor(def.hp * hpMult))
                def.attack.damage *= damageMult
                if def.abilities then
                    for _, ability in pairs(def.abilities) do
                        if type(ability) == "table" and type(ability.damage) == "number" then
                            ability.damage *= damageMult
                        end
                    end
                end
                def.exclusive_egg = Rules.egg(self.missions, plan.team, def.tier)
                -- Snapshot the selected content level. SpawnEnemy still adds the live menu/rank offset.
                def.level = level
                local grid = self.cfg.spawn_grid
                local col, row = (index - 1) % grid.columns, math.floor((index - 1) / grid.columns)
                local position = Vector3.new(
                    center.X + (col - (grid.columns - 1) / 2) * grid.spacing,
                    floorY + self.cfg.spawn_height,
                    center.Z + (row - (grid.rows - 1) / 2) * grid.spacing
                )
                local marker = Instance.new("Part")
                marker.Name = run.id .. "_" .. index
                marker.Anchored, marker.CanCollide, marker.CanTouch, marker.CanQuery =
                    true, false, false, false
                marker.Transparency = 1
                marker.Position = Vector3.new(position.X, floorY, position.Z)
                marker:SetAttribute(
                    "ArrivalAt",
                    workspace:GetServerTimeNow() + self.cfg.arrival_seconds
                )
                marker.Parent = self.arrivals
                table.insert(run.markers, marker)
                table.insert(
                    prepared,
                    { unit = unit, def = def, position = position, marker = marker }
                )
            end
            task.wait(self.cfg.arrival_seconds)
            for _, item in ipairs(prepared) do
                local unit, def, position, marker = item.unit, item.def, item.position, item.marker
                if self.run ~= run or not self:_eligible(player) then
                    return
                end
                local result = self.enemy:SpawnEnemy(player, "petinv_" .. unit.pet, {
                    def = def,
                    position = position,
                    home = position,
                    encounterGroup = self.bounds,
                    engagedTeamSize = count,
                    persistent = true,
                    ungated = true,
                    movementLeash = {
                        shapes = { shape },
                        inset = self.cfg.enemy_inset,
                        bodyInset = true,
                        restrictEngagement = true,
                        minY = floorY - self.cfg.participant_below_floor,
                        maxY = floorY + self.cfg.participant_height,
                        recovery = position,
                    },
                    rewardPolicy = RunService:IsStudio() and not self.cfg.studio_rewards and "none"
                        or "normal",
                    onDefeated = function()
                        if self.run == run then
                            run.remaining -= 1
                        end
                    end,
                })
                assert(result and result.ok, "Arena spawn failed")
                if self.run ~= run then
                    self.enemy:DespawnModel(result.model)
                    return
                end
                result.model:SetAttribute("CrossroadsArenaRun", run.id)
                result.model:SetAttribute("CrossroadsArenaPet", unit.pet)
                run.remaining += 1
                table.insert(run.models, result.model)
                Debris:AddItem(marker, self.cfg.arrival_seconds)
            end
            run.pending = false
        end)
        if self.run == run and (not ok or run.pending) then
            if not ok then
                self._modules.Logger:Warn(
                    "Crossroads arena spawn failed",
                    { error = tostring(err) }
                )
            end
            self:_clear("cancelled")
        end
    end)
end

function Arena:_tick()
    local bounds, floor = resolve(self.cfg.bounds_path), resolve(self.cfg.floor_path)
    if bounds ~= self.bounds or floor ~= self.floor then
        self:_clear("map_changed")
        self.bounds, self.floor = bounds, floor
    end
    if not bounds or not floor then
        return
    end
    -- Current authoring contract is an axis-aligned rectangle. Fail closed after unsupported rotation.
    if math.abs(bounds.CFrame.RightVector.X) < self.cfg.axis_tolerance then
        self:_clear("invalid_bounds")
        return
    end
    bounds:SetAttribute("GameplayConnected", true)
    local entrants = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if self:_eligible(player) then
            table.insert(entrants, player)
        end
    end
    local now = os.clock()
    local run = self.run
    if run then
        bounds:SetAttribute("ArenaEnemies", run.remaining)
        if #entrants == 0 then
            run.emptySince = run.emptySince or now
        else
            run.emptySince = nil
        end
        if
            (run.emptySince and now - run.emptySince >= self.cfg.abandoned_seconds)
            or now - run.startedAt >= self.cfg.max_round_seconds
        then
            self:_clear("abandoned")
        elseif not run.pending and run.remaining == 0 then
            self:_clear("cleared")
        elseif not run.pending then
            bounds:SetAttribute("ArenaState", "fighting")
        end
    elseif now >= self.nextAt and #entrants > 0 then
        table.sort(entrants, function(a, b)
            return a.UserId < b.UserId
        end)
        self:_begin(entrants[1], entrants)
    end
end

function Arena:Start()
    if not self.cfg.enabled or PlaceRuntime.isMerge(game.PlaceId, self.places) then
        return
    end
    self.arrivals = Instance.new("Folder")
    self.arrivals.Name = self.cfg.arrival_fx.runtime_name
    self.arrivals.Parent = workspace
    local elapsed, busy = 0, false
    RunService.Heartbeat:Connect(function(dt)
        elapsed += dt
        if elapsed >= self.cfg.poll_seconds and not busy then
            elapsed, busy = 0, true
            local ok, err = pcall(function()
                self:_tick()
            end)
            busy = false
            if not ok then
                self:_clear("unavailable")
                self._modules.Logger:Warn(
                    "Crossroads arena update failed",
                    { error = tostring(err) }
                )
            end
        end
    end)
    game:BindToClose(function()
        self:_clear("shutdown")
    end)
end

return Arena
