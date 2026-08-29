--[[
    DropService (server, #167 + #177) — physical currency pickups + Magnet collection.

    When a breakable breaks, BreakableSpawner hands the resolved currency award to SpawnCoinDrop
    instead of crediting it instantly. Origin awards render as gems; currencies such as Hall
    Waycoins can provide their own physical pickup. The award splits into one or more pickups that
    pop out and rest on the ground; a single Heartbeat loop collects them when the owner walks within
    `collect_radius` (+ the Magnet power's MagnetBuff bonus), flying them in once close. Currency is
    never lost: a pickup auto-collects to its owner on despawn-timeout or when the per-server cap is
    exceeded. XP / pet-xp / realm cuts stay instant in BreakableSpawner.

    Each gem is a MODEL: a MeshPart (one of 3 shared form meshes + the biome-colour texture) with a
    PointLight inside for glow (configs/gems.lua). Gem colour = biome currency; gem FORM = the chunk
    it carries (single/pile/bag). Templates are built once (async) and cloned per drop; a tinted ball
    is the fallback if a mesh fails to build, so drops never break. All numbers in configs/drops.lua
    + configs/gems.lua.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local MeshAssembly = require(ReplicatedStorage.Shared.Assets.MeshAssembly)

local LevelDiffYield = require(ReplicatedStorage.Shared.Game.LevelDiffYield)
local EffectiveStats = require(ReplicatedStorage.Shared.Game.EffectiveStats)
local MagnetRadius = require(ReplicatedStorage.Shared.Game.MagnetRadius)
local fireGameEvent = require(ReplicatedStorage.Shared.Network.FireGameEvent)
local buffsConfig = require(ReplicatedStorage.Configs:WaitForChild("buffs"))

local DropService = {}
DropService.__index = DropService

local function color3(t)
    return Color3.fromRGB(t[1] or 240, t[2] or 200, t[3] or 70)
end

local function containedDropTarget(startX, startZ, targetX, targetZ, bounds)
    if type(bounds) ~= "table" then
        return targetX, targetZ, nil, nil, false
    end
    local centerX = tonumber(bounds.centerX)
    local centerZ = tonumber(bounds.centerZ)
    local halfX = tonumber(bounds.halfX)
    local halfZ = tonumber(bounds.halfZ)
    local inset = math.max(0, tonumber(bounds.inset) or 0)
    if not (centerX and centerZ and halfX and halfZ and halfX > inset and halfZ > inset) then
        return targetX, targetZ, nil, nil, false
    end

    local minX, maxX = centerX - halfX + inset, centerX + halfX - inset
    local minZ, maxZ = centerZ - halfZ + inset, centerZ + halfZ - inset
    if targetX >= minX and targetX <= maxX and targetZ >= minZ and targetZ <= maxZ then
        return targetX, targetZ, nil, nil, false
    end

    local reflectedX = targetX < minX and (minX + (minX - targetX))
        or targetX > maxX and (maxX - (targetX - maxX))
        or targetX
    local reflectedZ = targetZ < minZ and (minZ + (minZ - targetZ))
        or targetZ > maxZ and (maxZ - (targetZ - maxZ))
        or targetZ
    reflectedX = math.clamp(reflectedX, minX, maxX)
    reflectedZ = math.clamp(reflectedZ, minZ, maxZ)

    local dx, dz = targetX - startX, targetZ - startZ
    local impactT = 1
    if targetX < minX and dx < 0 then
        impactT = math.min(impactT, math.clamp((minX - startX) / dx, 0, 1))
    elseif targetX > maxX and dx > 0 then
        impactT = math.min(impactT, math.clamp((maxX - startX) / dx, 0, 1))
    end
    if targetZ < minZ and dz < 0 then
        impactT = math.min(impactT, math.clamp((minZ - startZ) / dz, 0, 1))
    elseif targetZ > maxZ and dz > 0 then
        impactT = math.min(impactT, math.clamp((maxZ - startZ) / dz, 0, 1))
    end
    local impactX = math.clamp(startX + dx * impactT, minX, maxX)
    local impactZ = math.clamp(startZ + dz * impactT, minZ, maxZ)
    return reflectedX, reflectedZ, impactX, impactZ, true
end

function DropService:Init()
    self._logger = self._modules and self._modules.Logger
    self._configLoader = self._modules and self._modules.ConfigLoader
    -- DataService for the enhancement-drop origin gate (Jason: was getting ONLY
    -- natural drops — hasOrigin was always false so TrySpawnEnhancementDrop forced
    -- natural=true). Prefer the injected dep; fall back to the lazy loader (the
    -- same path the EnhancementService/EconomyService lookups below use) so a
    -- missing dependency declaration can never silently nil this out again.
    self._dataService = (self._modules and self._modules.DataService)
        or (self._moduleLoader and self._moduleLoader:Get("DataService"))
    self._modifierService = self._modules and self._modules.ModifierService
    self._config = (self._configLoader and self._configLoader:LoadConfig("drops"))
        or require(ReplicatedStorage.Configs:WaitForChild("drops"))
    self._gems = (self._configLoader and self._configLoader:LoadConfig("gems"))
        or require(ReplicatedStorage.Configs:WaitForChild("gems"))

    self._active = {} -- live drop records
    self._pool = {} -- recycled gem models, keyed "color|form" (or "ball")
    self._templates = {} -- built gem model templates, keyed "color|form"
    self._currencyTemplates = {} -- non-gem pickup templates, keyed by saved currency id
    self._collectRadiusEnchantCache = setmetatable({}, { __mode = "k" })
    self._autoCollectors = {} -- userId -> passive collector movement state
    self._lastStepAt = os.clock()

    if not self._config.enabled then
        return -- inert: BreakableSpawner credits instantly when SpawnCoinDrop returns false
    end

    self._folder = Instance.new("Folder")
    self._folder.Name = "CoinDrops"
    self._folder.Parent = Workspace
    local staleCollectors = Workspace:FindFirstChild("AutoCollectors")
    if staleCollectors then
        staleCollectors:Destroy()
    end
    self._autoCollectorFolder = Instance.new("Folder")
    self._autoCollectorFolder.Name = "AutoCollectors"
    self._autoCollectorFolder.Parent = Workspace
    self._templateHolder = Instance.new("Folder")
    self._templateHolder.Name = "_GemTemplates"
    self._templateHolder.Parent = self._folder

    -- pre-build the gem templates off the hot path (CreateMeshPartAsync yields). Each colour+form is
    -- its OWN mesh+texture pair (every Meshy gem gen has its own UV layout — there is no shared mesh),
    -- so forms come from the per-colour texture table.
    task.spawn(function()
        for color, forms in pairs(self._gems.textures or {}) do
            for form in pairs(forms) do
                self:_ensureTemplate(color, form)
            end
        end
        for currency in pairs(self._config.currency_pickups or {}) do
            self:_ensureCurrencyTemplate(currency)
        end
    end)

    self._conn = RunService.Heartbeat:Connect(function()
        self:_step()
    end)
    self._playerRemoving = Players.PlayerRemoving:Connect(function(player)
        self:_removeAutoCollector(player.UserId)
    end)
end

-- Resolve the equipped Magnet enchants through their authoritative modifier provider, but never do
-- a profile/equip walk once per physical drop. A short cache keeps live equip/reroll response crisp
-- while bounding the work to four resolutions per second per player during active loot.
function DropService:_collectRadiusEnchantBonus(plr)
    local now = os.clock()
    local cached = self._collectRadiusEnchantCache[plr]
    if cached and cached.expiresAt > now then
        return cached.bonus
    end

    local bonus = tonumber(plr:GetAttribute("EnchantCollectRadius")) or 0
    if self._modifierService and self._modifierService.Resolve then
        local ok, factor = pcall(function()
            return self._modifierService:Resolve(1, {
                player = plr,
                kind = "collect_radius",
                source = "DropService",
            })
        end)
        if ok and tonumber(factor) then
            bonus = math.max(0, tonumber(factor) - 1)
        end
    end
    self._collectRadiusEnchantCache[plr] = {
        bonus = bonus,
        expiresAt = now + 0.25,
    }
    return bonus
end

function DropService:IsEnabled()
    return self._config and self._config.enabled == true
end

-- The Game Pass collector is deliberately manifested outside PlayerPets. That gives it the same
-- authored pet presentation without inventory/equip records, HUD slots, combat enumeration, aggro,
-- or offense. The normal pet prototype is already normalized by AssetPreloadService, so cloning it
-- here preserves the exact Hall visual and variant treatment.
function DropService:_cloneAutoCollectorModel(player)
    local cfg = self._config.auto_collector or {}
    local assets = ReplicatedStorage:FindFirstChild("Assets")
    local models = assets and assets:FindFirstChild("Models")
    local pets = models and models:FindFirstChild("Pets")
    local typeFolder = pets and pets:FindFirstChild(tostring(cfg.pet or "trail_pup"))
    local prototype = typeFolder
        and (
            typeFolder:FindFirstChild(tostring(cfg.variant or "basic"))
            or typeFolder:FindFirstChild("basic")
        )
    if not prototype then
        return nil
    end
    local model = prototype:Clone()
    if not model.PrimaryPart then
        local candidate
        for _, descendant in ipairs(model:GetDescendants()) do
            if descendant:IsA("BasePart") then
                local lowerName = string.lower(descendant.Name)
                if lowerName:find("face", 1, true) or lowerName:find("head", 1, true) then
                    candidate = descendant
                    break
                end
                candidate = candidate or descendant
            end
        end
        model.PrimaryPart = candidate
    end
    if not model.PrimaryPart then
        model:Destroy()
        return nil
    end
    for _, descendant in ipairs(model:GetDescendants()) do
        if descendant:IsA("BasePart") then
            descendant.Anchored = true
            descendant.CanCollide = false
            descendant.CanTouch = false
            descendant.CanQuery = false
        end
    end
    model.Name = player.Name .. "_AutoCollector"
    model:SetAttribute("AutoCollectorPet", true)
    model:SetAttribute("AutoCollectorOwnerUserId", player.UserId)
    model:SetAttribute("PetType", tostring(cfg.pet or "trail_pup"))
    model:SetAttribute("PetVariant", tostring(cfg.variant or "basic"))
    model:SetAttribute("GhostPet", true)
    model:SetAttribute("NoPetOffense", true)
    model:SetAttribute("NoEnemyAggro", true)
    model:SetAttribute(
        "AutoCollectorCollectRadius",
        math.max(0, tonumber(cfg.collect_radius) or 11)
    )
    return model
end

function DropService:_removeAutoCollector(userId)
    local state = self._autoCollectors and self._autoCollectors[userId]
    if state and state.model then
        state.model:Destroy()
    end
    if self._autoCollectors then
        self._autoCollectors[userId] = nil
    end
end

function DropService:_ensureAutoCollector(player, now)
    local state = self._autoCollectors[player.UserId]
    if state and state.model and state.model.Parent then
        return state
    end
    if state and now < (state.retryAt or 0) then
        return nil
    end
    local model = self:_cloneAutoCollectorModel(player)
    if not model then
        state = state or {}
        state.retryAt = now + 1
        self._autoCollectors[player.UserId] = state
        return nil
    end
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local rootPosition = root and root.Position
    local position = rootPosition or Vector3.zero
    model:PivotTo(CFrame.new(position))
    model:SetAttribute("AutoCollectorPosition", position)
    model:SetAttribute("AutoCollectorLookVector", Vector3.new(0, 0, -1))
    model:SetAttribute("AutoCollectorMode", "follow")
    model.Parent = self._autoCollectorFolder
    state = {
        model = model,
        position = position,
        look = Vector3.new(0, 0, -1),
        nextTargetAt = 0,
        nextPublishAt = 0,
    }
    self._autoCollectors[player.UserId] = state
    return state
end

-- While the merge-defense player works behind the breach, idle companions heel at the same
-- server-authored anchor as the reserve squad. Crossing forward restores ordinary live following.
function DropService:_autoCollectorFollowFrame(player)
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root then
        return nil
    end
    local frame = root.CFrame
    if player:GetAttribute("InMergeEggPrototype") == true then
        local position = player:GetAttribute("MergeEggEscortAnchorPosition")
        local look = player:GetAttribute("MergeEggEscortAnchorLookVector")
        if
            typeof(position) == "Vector3"
            and typeof(look) == "Vector3"
            and look.Magnitude > 0.01
        then
            local flatLook = Vector3.new(look.X, 0, look.Z)
            if flatLook.Magnitude > 0.01 then
                flatLook = flatLook.Unit
                local fromAnchor =
                    Vector3.new(root.Position.X - position.X, 0, root.Position.Z - position.Z)
                if fromAnchor:Dot(flatLook) < 0 then
                    frame = CFrame.lookAt(position, position + flatLook)
                end
            end
        end
    end
    return frame
end

function DropService:_nearestAutoCollectorDrop(userId, position)
    local nearest, nearestDistance
    for _, rec in ipairs(self._active) do
        if
            rec
            and rec._done ~= true
            and rec.kind == nil
            and rec.owner == userId
            and rec.currency ~= nil
            and rec.settling ~= true
            and rec.part
            and rec.part.Parent
        then
            local distance = (rec.part.Position - position).Magnitude
            if not nearestDistance or distance < nearestDistance then
                nearest = rec
                nearestDistance = distance
            end
        end
    end
    return nearest
end

function DropService:_stepAutoCollectors(now, dt)
    local cfg = self._config.auto_collector or {}
    if cfg.enabled == false then
        return
    end
    local entitlementAttribute = tostring(cfg.entitlement_attribute or "AutoCollectorEnabled")
    local present = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player:GetAttribute(entitlementAttribute) == true then
            present[player.UserId] = true
            local state = self:_ensureAutoCollector(player, now)
            local frame = state and self:_autoCollectorFollowFrame(player)
            if state and frame then
                local target = state.target
                if
                    not target
                    or target._done == true
                    or target.kind ~= nil
                    or target.owner ~= player.UserId
                    or target.settling == true
                    or not (target.part and target.part.Parent)
                    or now >= (state.nextTargetAt or 0)
                then
                    target = self:_nearestAutoCollectorDrop(player.UserId, state.position)
                    state.target = target
                    state.nextTargetAt = now
                        + math.max(0.02, tonumber(cfg.target_refresh_seconds) or 0.1)
                end

                local goal
                local mode = "follow"
                if target and target.part and target.part.Parent then
                    local targetHeight = tonumber(cfg.target_height) or 2
                    goal = target.part.Position + Vector3.new(0, targetHeight, 0)
                    mode = "collect"
                else
                    local offset = cfg.follow_offset or {}
                    goal = (frame * CFrame.new(
                        tonumber(offset.x) or 5,
                        tonumber(offset.y) or 2,
                        tonumber(offset.back) or 6
                    )).Position
                end

                local current = state.position
                local delta = goal - current
                local speedMultiplier =
                    math.max(0.05, tonumber(player:GetAttribute("Eff_Speed")) or 1)
                local speed = math.max(0.1, tonumber(cfg.base_travel_speed) or 26) * speedMultiplier
                local catchup = math.max(0, tonumber(cfg.catchup_distance) or 200)
                if mode == "follow" and catchup > 0 and delta.Magnitude > catchup then
                    current = goal
                elseif delta.Magnitude > 0.001 then
                    current += delta.Unit * math.min(delta.Magnitude, speed * dt)
                end
                state.position = current

                local flatMove = Vector3.new(delta.X, 0, delta.Z)
                local flatFrameLook = Vector3.new(frame.LookVector.X, 0, frame.LookVector.Z)
                if flatMove.Magnitude > 0.01 then
                    state.look = flatMove.Unit
                elseif flatFrameLook.Magnitude > 0.01 then
                    state.look = flatFrameLook.Unit
                end

                local radius = math.max(0, tonumber(cfg.collect_radius) or 11)
                if
                    target
                    and target._done ~= true
                    and target.part
                    and target.part.Parent
                    and (target.part.Position - current).Magnitude <= radius
                then
                    -- Collector pickup is direct-to-wallet: the physical drop does not fly to the
                    -- character and the player's own Magnet radius is never consulted.
                    self:_collect(target)
                    state.target = nil
                    state.nextTargetAt = 0
                end

                if now >= (state.nextPublishAt or 0) then
                    state.nextPublishAt = now
                        + math.max(0.02, tonumber(cfg.replication_seconds) or 0.05)
                    state.model:SetAttribute("AutoCollectorPosition", state.position)
                    state.model:SetAttribute("AutoCollectorLookVector", state.look)
                    state.model:SetAttribute(
                        "AutoCollectorTargetPosition",
                        state.target and state.target.part and state.target.part.Position or nil
                    )
                    state.model:SetAttribute("AutoCollectorMode", mode)
                    state.model:SetAttribute("AutoCollectorSpeedMultiplier", speedMultiplier)
                end
            end
        end
    end
    for userId in pairs(self._autoCollectors) do
        if not present[userId] then
            self:_removeAutoCollector(userId)
        end
    end
end

-- Target widest-side studs for a gem of this form (per-form so piles/bags read bigger than singles).
function DropService:_sizeFor(form)
    local s = self._gems.size
    if type(s) == "table" then
        return s[form] or self._gems.default_size or 1.5
    end
    return s or self._gems.default_size or 1.5
end

-- ---- gem template construction -----------------------------------------

-- Build (once) and cache the gem MODEL template for a colour+form: a MeshPart (mesh + texture,
-- scaled, glassy) wrapped in a Model, with a PointLight inside for glow. Yields on first build.
function DropService:_ensureTemplate(color, form)
    local key = color .. "|" .. form
    if self._templates[key] then
        return self._templates[key]
    end
    local meshId = self._gems.meshes and self._gems.meshes[color] and self._gems.meshes[color][form]
    local texId = self._gems.textures
        and self._gems.textures[color]
        and self._gems.textures[color][form]
    if not (meshId and texId) then
        return nil
    end
    -- THE single combine path (shared with pets/enemies/eggs): mesh + texture -> textured Model.
    local model = MeshAssembly.build(meshId, texId, { modelName = "GemDrop", partName = "Gem" })
    if not model then
        if self._logger and self._logger.Warn then
            self._logger:Warn("Gem mesh build failed", { key = key })
        end
        return nil -- caller falls back to a tinted ball
    end
    local mesh = model.PrimaryPart
    -- gem-specific tuning on the textured MeshPart
    mesh.CanQuery = false
    mesh.CanTouch = false
    mesh.Massless = true
    mesh.Material = Enum.Material.Glass
    -- scale so the widest side ≈ the per-form target studs
    local widest = math.max(mesh.Size.X, mesh.Size.Y, mesh.Size.Z)
    if widest > 0 then
        mesh.Size = mesh.Size * (self:_sizeFor(form) / widest)
    end
    local light = Instance.new("PointLight")
    light.Color = color3((self._gems.light_color and self._gems.light_color[color]) or {})
    light.Range = self._gems.light_range or 9
    light.Brightness = self._gems.light_brightness or 2.5
    light.Parent = mesh
    model.Parent = self._templateHolder
    self._templates[key] = model
    return model
end

-- Acquire a gem (or ball) instance for colour+form: pool hit, else clone the template, else a ball.
-- Returns the Model and its movable PrimaryPart.
function DropService:_acquireGem(color, form)
    local key = color .. "|" .. form
    local pooled = self._pool[key] and table.remove(self._pool[key])
    if pooled then
        pooled.Parent = self._folder
        return pooled, pooled.PrimaryPart
    end
    local template = self._templates[key]
    if template then
        local clone = template:Clone()
        clone.Parent = self._folder
        return clone, clone.PrimaryPart
    end
    -- fallback: a tinted ball wrapped in a Model (template not built yet / mesh failed)
    local ball = Instance.new("Part")
    ball.Shape = Enum.PartType.Ball
    ball.Material = Enum.Material.Neon
    ball.Color = color3((self._gems.light_color and self._gems.light_color[color]) or {})
    local bs = self:_sizeFor(form)
    ball.Size = Vector3.new(bs, bs, bs)
    ball.Anchored = true
    ball.CanCollide = false
    ball.CanQuery = false
    ball.CanTouch = false
    ball.Massless = true
    ball.Name = "Gem"
    local light = Instance.new("PointLight")
    light.Color = ball.Color
    light.Range = self._gems.light_range or 9
    light.Brightness = self._gems.light_brightness or 2.5
    light.Parent = ball
    local model = Instance.new("Model")
    model.Name = "GemDrop"
    ball.Parent = model
    model.PrimaryPart = ball
    model.Parent = self._folder
    return model, ball
end

-- Hall Waycoins and future non-gem currencies stay on the same reliable drop/collection pipeline,
-- but can provide an authored physical pickup instead of inheriting the emerald-gem fallback.
function DropService:_ensureCurrencyTemplate(currency)
    currency = tostring(currency)
    if self._currencyTemplates[currency] then
        return self._currencyTemplates[currency]
    end
    local cfg = self._config.currency_pickups and self._config.currency_pickups[currency]
    if not (cfg and cfg.mesh and cfg.texture) then
        return nil
    end
    local model = MeshAssembly.build(cfg.mesh, cfg.texture, {
        modelName = "CurrencyDrop",
        partName = "Currency",
    })
    local part = model and model.PrimaryPart
    if not part then
        return nil
    end
    part.Color = Color3.new(1, 1, 1)
    part.CanQuery = false
    part.CanTouch = false
    part.Massless = true
    local widest = math.max(part.Size.X, part.Size.Y, part.Size.Z)
    local target = tonumber(cfg.size) or 1.35
    if widest > 0 then
        part.Size = part.Size * (target / widest)
    end

    -- Imported currency art may need a one-time presentation correction. Keep that correction on
    -- the visual beneath a neutral root so the shared drop loop can rotate/move the root exactly as
    -- it does for gems. Applying the correction directly to the moving part made Waycoins rest at
    -- one angle and visibly rotate 90 degrees during Magnet collection.
    local orientation = cfg.orientation or {}
    local x = tonumber(orientation.x) or 0
    local y = tonumber(orientation.y) or 0
    local z = tonumber(orientation.z) or 0
    if x ~= 0 or y ~= 0 or z ~= 0 then
        local root = Instance.new("Part")
        root.Name = "Root"
        root.Size = Vector3.new(0.05, 0.05, 0.05)
        root.Transparency = 1
        root.Anchored = true
        root.CanCollide = false
        root.CanQuery = false
        root.CanTouch = false
        root.CFrame = CFrame.new()
        root.Parent = model

        part.Anchored = false
        part.CFrame = root.CFrame * CFrame.Angles(math.rad(x), math.rad(y), math.rad(z))

        local weld = Instance.new("WeldConstraint")
        weld.Name = "VisualWeld"
        weld.Part0 = root
        weld.Part1 = part
        weld.Parent = root
        model.PrimaryPart = root
    end
    model.Parent = self._templateHolder
    self._currencyTemplates[currency] = model
    return model
end

function DropService:_acquireCurrency(currency)
    currency = tostring(currency)
    local key = "currency|" .. currency
    local pooled = self._pool[key] and table.remove(self._pool[key])
    if pooled then
        pooled.Parent = self._folder
        return pooled, pooled.PrimaryPart
    end
    local template = self._currencyTemplates[currency] or self:_ensureCurrencyTemplate(currency)
    if not template then
        return nil, nil
    end
    local clone = template:Clone()
    clone.Parent = self._folder
    return clone, clone.PrimaryPart
end

function DropService:_recycle(rec)
    local model = rec.model
    if not model then
        return
    end
    if rec.noPool then
        model:Destroy()
        return
    end
    model.Parent = nil
    local key = rec.poolKey or "ball"
    self._pool[key] = self._pool[key] or {}
    if #self._pool[key] < 40 then
        self._pool[key][#self._pool[key] + 1] = model
    else
        model:Destroy()
    end
end

-- ---- payout split ------------------------------------------------------

function DropService:_colorFor(currency)
    local map = self._gems.currency_color or {}
    return map[tostring(currency)] or self._gems.default_color or "emerald"
end

function DropService:_formFor(amount)
    for _, tier in ipairs(self._gems.form_tiers or {}) do
        if amount >= (tier.min or 0) then
            return tier.form
        end
    end
    return "single"
end

-- Split a coin award into gem chunks (payout by COUNT): one extra gem per `split_step`, clamped to
-- `max_gems`; the award is divided across them (first gem keeps the remainder so the sum is exact).
function DropService:_split(amount)
    local step = self._gems.split_step or 250
    local maxGems = self._gems.max_gems or 6
    local count = math.clamp(1 + math.floor(amount / math.max(1, step)), 1, maxGems)
    local per = math.floor(amount / count)
    local rem = amount - per * count
    local chunks = {}
    for i = 1, count do
        local a = per + (i == 1 and rem or 0)
        if a > 0 then
            chunks[#chunks + 1] = a
        end
    end
    if #chunks == 0 then
        chunks[1] = amount
    end
    return chunks
end

-- ---- spawn -------------------------------------------------------------

-- Floor height under (x, z); ignores drops/pets/characters so gems rest on the terrain.
function DropService:_groundY(x, z, fromY, fallbackY)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local exclude = { self._folder }
    local pp = Workspace:FindFirstChild("PlayerPets")
    if pp then
        exclude[#exclude + 1] = pp
    end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr.Character then
            exclude[#exclude + 1] = plr.Character
        end
    end
    params.FilterDescendantsInstances = exclude
    local result = Workspace:Raycast(Vector3.new(x, fromY + 8, z), Vector3.new(0, -200, 0), params)
    return result and result.Position.Y or fallbackY
end

-- Spawn physical currency pickups for an award. Returns true if drops were created (caller must
-- NOT credit), false to credit instantly (disabled / too small / no position). `options` may give
-- a mode its own base radius or live radius attribute without changing ordinary-game collection.
-- Never throws.
function DropService:SpawnCoinDrop(player, currencyType, amount, position, options)
    amount = tonumber(amount) or 0
    if not self:IsEnabled() then
        return false
    end
    if not (player and position and amount >= (self._config.min_coins_for_drop or 1)) then
        return false
    end
    if typeof(position) ~= "Vector3" then
        return false
    end

    local currencyId = tostring(currencyType or "coins")
    options = type(options) == "table" and options or {}
    local baseCollectRadius = tonumber(options.baseCollectRadius)
    if baseCollectRadius then
        baseCollectRadius = math.max(0, baseCollectRadius)
    end
    local collectRadiusAttribute = type(options.collectRadiusAttribute) == "string"
            and options.collectRadiusAttribute ~= ""
            and options.collectRadiusAttribute
        or nil
    local usePlayerModifiers = options.usePlayerModifiers ~= false
    local source = type(options.source) == "string" and options.source or nil
    local visualScale = math.max(0.1, tonumber(options.visualScale) or 1)
    local despawnSeconds = tonumber(options.despawnSeconds)
    if despawnSeconds then
        despawnSeconds = math.max(1, despawnSeconds)
    end
    local containmentBounds = type(options.containmentBounds) == "table"
            and options.containmentBounds
        or nil
    local configuredPickup = self._config.currency_pickups
        and self._config.currency_pickups[currencyId]
    local color = self:_colorFor(currencyId)
    local chunks = self:_split(amount)
    local pop = self._config.pop_up or 7
    local out = self._config.pop_out or 5

    for i, chunkAmount in ipairs(chunks) do
        -- cap: auto-collect the oldest live drop so the world never floods
        if #self._active >= (self._config.max_active or 90) then
            self:_collect(self._active[1], true)
        end
        local form = self:_formFor(chunkAmount)
        local model, part
        local pickupCfg = configuredPickup
        if pickupCfg then
            model, part = self:_acquireCurrency(currencyId)
        end
        if not (model and part) then
            model, part = self:_acquireGem(color, form)
            pickupCfg = nil
        end
        pcall(function()
            model:ScaleTo(visualScale)
        end)
        local ang = ((#self._active + i) % 12) * (math.pi / 6)
        local rawX = position.X + math.cos(ang) * out
        local rawZ = position.Z + math.sin(ang) * out
        local hx, hz, impactX, impactZ, bounced =
            containedDropTarget(position.X, position.Z, rawX, rawZ, containmentBounds)
        local groundY = self:_groundY(hx, hz, position.Y, position.Y - 1)
        local apex = position
            + Vector3.new(math.cos(ang) * out * 0.5, pop, math.sin(ang) * out * 0.5)
        -- random resting yaw so gems don't all turn in lockstep (they settle facing
        -- random directions; the _step spin then carries each from its own phase)
        local yaw = math.random() * (2 * math.pi)
        local rotation = CFrame.Angles(0, yaw, 0)
        part.CFrame = CFrame.new(apex) * rotation
        local _, orientedSize = model:GetBoundingBox()
        local rest = Vector3.new(hx, groundY + orientedSize.Y * 0.5, hz)

        -- visibility filter: gems are owner-only pickups, so they're owner-only
        -- VISIBLE too (DropVisibility hides foreign gems client-side — Jason: "it
        -- makes it really confusing if gems are everywhere and they're not yours")
        model:SetAttribute("DropOwner", player.UserId)
        model:SetAttribute("DropCurrency", currencyId)
        model:SetAttribute("DropAmount", math.floor(chunkAmount))
        model:SetAttribute("DropBaseCollectRadius", baseCollectRadius)
        model:SetAttribute("DropCollectRadiusAttribute", collectRadiusAttribute)
        model:SetAttribute("DropUsesPlayerModifiers", usePlayerModifiers)
        model:SetAttribute("DropSource", source)
        model:SetAttribute("DropVisualScale", visualScale)
        model:SetAttribute("DropDespawnSeconds", despawnSeconds)
        model:SetAttribute("DropBouncedInside", bounced)
        local rec = {
            model = model,
            part = part,
            poolKey = pickupCfg and ("currency|" .. currencyId) or (color .. "|" .. form),
            owner = player.UserId,
            currency = currencyId,
            amount = math.floor(chunkAmount),
            baseCollectRadius = baseCollectRadius,
            collectRadiusAttribute = collectRadiusAttribute,
            usePlayerModifiers = usePlayerModifiers,
            source = source,
            spawnAt = os.clock(),
            despawnSeconds = despawnSeconds,
            settling = true,
        }
        self._active[#self._active + 1] = rec

        local TweenService = game:GetService("TweenService")
        local popTime = math.max(0.05, tonumber(self._config.pop_time) or 0.35)
        if bounced and impactX and impactZ then
            local impactGroundY = self:_groundY(impactX, impactZ, position.Y, groundY)
            local impact = Vector3.new(
                impactX,
                math.max(impactGroundY + orientedSize.Y * 0.5, (apex.Y + rest.Y) * 0.5),
                impactZ
            )
            local first = TweenService:Create(
                part,
                TweenInfo.new(popTime * 0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
                { CFrame = CFrame.new(impact) * rotation }
            )
            first.Completed:Connect(function()
                if model.Parent and part.Parent then
                    TweenService:Create(
                        part,
                        TweenInfo.new(
                            popTime * 0.45,
                            Enum.EasingStyle.Quad,
                            Enum.EasingDirection.Out
                        ),
                        { CFrame = CFrame.new(rest) * rotation }
                    ):Play()
                end
            end)
            first:Play()
        else
            TweenService:Create(
                part,
                TweenInfo.new(popTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                { CFrame = CFrame.new(rest) * rotation }
            ):Play()
        end
        task.delay(popTime, function()
            rec.settling = false
        end)
    end
    return true
end

-- Build (once) and cache the COGWHEEL MeshPart template for a color (the enhancement drop
-- model: one shared mesh, per-color texture — configs/enhancements.lua drops.cog). Yields on
-- first build; nil when the mesh fails (caller falls back to the placeholder orb).
function DropService:_ensureCogTemplate(cog, color)
    self._cogTemplates = self._cogTemplates or {}
    if self._cogTemplates[color] then
        return self._cogTemplates[color]
    end
    local texId = cog.textures and cog.textures[color]
    if not (cog.mesh and texId) then
        return nil
    end
    -- THE single combine path (shared with pets/enemies/gems/eggs): mesh + texture -> textured Model.
    local model =
        MeshAssembly.build(cog.mesh, texId, { modelName = "EnhancementDrop", partName = "Body" })
    if not model then
        return nil
    end
    local mesh = model.PrimaryPart
    local target = tonumber(cog.size) or 1.6
    local widest = math.max(mesh.Size.X, mesh.Size.Y, mesh.Size.Z)
    if widest > 0 then
        mesh.Size = mesh.Size * (target / widest)
    end
    mesh.CanQuery = false
    mesh.Material = Enum.Material.Metal
    local light = Instance.new("PointLight")
    light.Range = 7
    light.Brightness = 0.8
    light.Parent = mesh
    self._cogTemplates[color] = model
    return model
end

-- The cog COLOR for a rolled enhancement record: singles hint their origin's color on the
-- ground (type stays hidden); duals read purple (mixed); silver = fallback/unknown.
local function cogColorFor(cog, record)
    local origins = record and record.origins or {}
    if #origins == 1 then
        return (cog.origin_colors and cog.origin_colors[origins[1]]) or cog.fallback_color
    elseif #origins == 2 then
        return cog.dual_color or cog.fallback_color
    end
    return cog.fallback_color
end

-- Try to spawn an ENHANCEMENT drop (Jason's design: identity hidden until pickup).
-- source = "breakable" | "enemy" (chance per configs/enhancements.lua drops). The model is
-- semi-generic: authored Model (drops.model_name under ReplicatedStorage.Assets.Models) when
-- set, else a placeholder gold neon orb with a "?" tag. Returns true when a drop spawned.
function DropService:TrySpawnEnhancementDrop(player, source, position, opts)
    if not (player and typeof(position) == "Vector3") then
        return false
    end
    local enhCfg = self._enhConfig
    if not enhCfg then
        local ok, cfg = pcall(function()
            return (self._configLoader and self._configLoader:LoadConfig("enhancements"))
                or require(ReplicatedStorage.Configs:WaitForChild("enhancements"))
        end)
        enhCfg = ok and cfg or nil
        self._enhConfig = enhCfg
    end
    local drops = enhCfg and enhCfg.drops
    if not (drops and drops.enabled) then
        return false
    end
    -- "treasure" = mission chests: opening one is the gate, the payout is
    -- guaranteed (docs/MISSION_WORLDGEN.md M5)
    local chance = (source == "enemy" and drops.enemy_chance)
        or (source == "treasure" and 1)
        or drops.breakable_chance
        or 0
    -- RANK PREMIUM (Jason, Magma Wyrm playtest: "that was really hard" —
    -- bosses rolled the same flat odds as trash): kills pass the enemy's
    -- tier; enemy_rank_mult scales the odds. chance may exceed 1: the whole
    -- part is GUARANTEED drops, the fraction is one extra roll (a boss at
    -- 0.16 x 6 = 0.96 ≈ a sure find; archvillain 1.92 = 1 + 92% of a 2nd).
    if type(opts) == "table" then
        local mult = tonumber(opts.chance_mult)
        if not mult and opts.tier then
            mult = tonumber((drops.enemy_rank_mult or {})[opts.tier])
        end
        if mult then
            chance = chance * math.max(0, mult)
        end
        -- LEVEL-DIFF SCALING (Jason 2026-07-09: "very difficult to get
        -- high-end drops from a minus-three boss, much more likely from a
        -- plus-three"): kill drops scale by the con-color gap — closes the
        -- gray-boss farm hole the rank premium opened. Kills only (chests
        -- pass no enemy_level).
        if source == "enemy" and tonumber(opts.enemy_level) and drops.level_diff then
            local myLevel = tonumber(player:GetAttribute("EffectiveLevel"))
                or tonumber(player:GetAttribute("Level"))
                or 1
            chance = chance
                * LevelDiffYield.payout(myLevel, tonumber(opts.enemy_level), drops.level_diff)
        end
    end
    -- Windfall power + deployed tester-pet aura share THE additive drop_rate axis.
    chance = chance
        * EffectiveStats.multiplier("drop_rate", function(name)
            return player:GetAttribute(name)
        end, os.time(), (buffsConfig.axes or {}).drop_rate)
    chance = chance * (1 + (tonumber(player:GetAttribute("PetAbilityDropRate")) or 0))
    -- Showering Saturday (drop_rate global event): same axis, server-wide.
    local eventService = self._moduleLoader and self._moduleLoader:Get("EventService")
    if eventService then
        local m = tonumber(eventService:GetModifier("drop_rate", 0)) or 0
        if m > 0 then
            chance = chance * (1 + m)
        end
        -- Warpath Thursday (enemy_drop_rate): ENEMY kills only — the fight
        -- day's loot lever, distinct from Saturday's everything-drops
        if source == "enemy" then
            local em = tonumber(eventService:GetModifier("enemy_drop_rate", 0)) or 0
            if em > 0 then
                chance = chance * (1 + em)
            end
        end
    end
    -- resolve the roll into a COUNT (premium odds can exceed 1). Chests
    -- ("treasure") stay exactly one per call — that includes the recursive
    -- premium extras below, so windfall can't compound them.
    local count
    if source == "treasure" then
        count = 1
    else
        count = math.floor(chance)
        if math.random() < (chance - count) then
            count += 1
        end
    end
    if count == 0 then
        return false
    end
    -- extras beyond the first spawn as guaranteed rolls ringed around the
    -- kill site (each recursive call spawns exactly one)
    for i = 2, count do
        local off = Vector3.new(math.cos(i * 2.1) * 2.5, 0, math.sin(i * 2.1) * 2.5)
        local extraOpts = (type(opts) == "table" and (opts.enemy_level or opts.tier))
                and { enemy_level = opts.enemy_level, tier = opts.tier }
            or nil
        task.defer(function()
            self:TrySpawnEnhancementDrop(player, "treasure", position + off, extraOpts)
        end)
    end
    local enh = self._moduleLoader and self._moduleLoader:Get("EnhancementService")
    if not (enh and enh.RollDrop) then
        return false
    end
    -- pre-origin players (no Archetype chosen yet) get NATURAL drops — origin gear
    -- would be unslottable dead weight for them (Jason)
    local data = self._dataService and self._dataService:GetData(player)
    local hasOrigin = data and data.Archetype ~= nil
    -- DROP LEVEL: kills roll gear from the ENEMY's level band ("punch up
    -- for future-band gear" — the CoH placement gate makes +N drops a
    -- bank-it-for-next-level moment); everything else follows the player.
    local rollLevel = (type(opts) == "table" and tonumber(opts.enemy_level))
        or player:GetAttribute("Level")
    -- RANK QUALITY: lieutenants/bosses drop the desirable stuff — fewer
    -- naturals, more singles (drops.rank_quality by tier)
    local quality = (type(opts) == "table" and opts.tier) and (drops.rank_quality or {})[opts.tier]
        or nil
    -- chests are rare: never junk (drops.treasure_quality — Jason)
    if source == "treasure" then
        quality = quality or drops.treasure_quality
    end
    local record = enh:RollDrop(nil, player:GetAttribute("CurrentArea"), {
        natural = not hasOrigin,
        playerLevel = rollLevel,
        natural_chance = quality and quality.natural_chance,
        single_chance = quality and quality.single_chance,
    })

    -- model: authored Assets model (override) > the cogwheel mesh (per-color) > mystery orb
    local model
    if drops.model_name then
        local assets = ReplicatedStorage:FindFirstChild("Assets")
        local models = assets and assets:FindFirstChild("Models")
        local tpl = models and models:FindFirstChild(drops.model_name)
        if tpl then
            model = tpl:Clone()
        end
    end
    if not model and drops.cog then
        local tpl = self:_ensureCogTemplate(drops.cog, cogColorFor(drops.cog, record))
        if tpl then
            model = tpl:Clone()
        end
    end
    local part
    if model then
        part = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
    end
    if not part then
        model = Instance.new("Model")
        model.Name = "EnhancementDrop"
        part = Instance.new("Part")
        part.Shape = Enum.PartType.Ball
        part.Size = Vector3.new(1.6, 1.6, 1.6)
        part.Material = Enum.Material.Neon
        part.Color = Color3.fromRGB(255, 200, 90)
        part.CanCollide = false
        part.CanQuery = false
        part.Anchored = true
        part.Parent = model
        model.PrimaryPart = part
        local bb = Instance.new("BillboardGui")
        bb.Size = UDim2.fromOffset(26, 26)
        bb.StudsOffset = Vector3.new(0, 1.6, 0)
        bb.AlwaysOnTop = true
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.fromScale(1, 1)
        lbl.BackgroundTransparency = 1
        lbl.Font = Enum.Font.GothamBlack
        lbl.TextScaled = true
        lbl.TextColor3 = Color3.fromRGB(255, 235, 170)
        lbl.Text = "?"
        lbl.Parent = bb
        bb.Parent = part
    end
    part.Anchored = true
    local groundY = self:_groundY(position.X, position.Z, position.Y, position.Y - 1)
    part.CFrame = CFrame.new(position.X, groundY + part.Size.Y * 0.5 + 0.2, position.Z)

    -- OWNER-ONLY VISIBLE (Jason: other players could see enhancement drops): stamp
    -- DropOwner BEFORE parenting, and parent into CoinDrops (not bare Workspace) so
    -- the client DropVisibility filter hides it for non-owners — same as gems. The
    -- attribute is set first so it's already correct on the client's ChildAdded.
    model:SetAttribute("DropOwner", player.UserId)
    model.Parent = self._folder or Workspace
    self._active[#self._active + 1] = {
        kind = "enhancement",
        record = record,
        model = model,
        part = part,
        noPool = true,
        owner = player.UserId,
        spawnAt = os.clock(),
        despawnSeconds = drops.despawn_seconds or 45,
        settling = false,
    }
    return true
end

-- Try to spawn a POTION drop (Jason: same odds as enhancements). source = "breakable" | "enemy".
-- The drop is colour-hinted by its meter and reveals its name on pickup (DropService:_collect →
-- PotionService:Grant). Windfall (drop_rate) + the drop_rate event scale the chance, same as the
-- enhancement path. Returns true when a drop spawned.
function DropService:TrySpawnPotionDrop(player, source, position)
    if not (player and typeof(position) == "Vector3") then
        return false
    end
    local potions = self._moduleLoader and self._moduleLoader:Get("PotionService")
    if not (potions and potions.RollDrop and potions.Grant) then
        return false
    end
    local cfg = self._potionConfig
    if not cfg then
        local ok, c = pcall(function()
            return (self._configLoader and self._configLoader:LoadConfig("potions"))
                or require(ReplicatedStorage.Configs:WaitForChild("potions"))
        end)
        cfg = ok and c or nil
        self._potionConfig = cfg
    end
    local drops = cfg and cfg.drops
    if not (drops and drops.enabled) then
        return false
    end
    local chance = (source == "enemy" and drops.enemy_chance) or drops.breakable_chance or 0
    -- Windfall power + deployed tester-pet aura share THE additive drop_rate axis.
    chance = chance
        * EffectiveStats.multiplier("drop_rate", function(name)
            return player:GetAttribute(name)
        end, os.time(), (buffsConfig.axes or {}).drop_rate)
    chance = chance * (1 + (tonumber(player:GetAttribute("PetAbilityDropRate")) or 0))
    -- drop_rate global event (e.g. Showering Saturday): same axis, server-wide.
    local eventService = self._moduleLoader and self._moduleLoader:Get("EventService")
    if eventService then
        local m = tonumber(eventService:GetModifier("drop_rate", 0)) or 0
        if m > 0 then
            chance = chance * (1 + m)
        end
    end
    if math.random() >= chance then
        return false
    end
    local potionId = potions:RollDrop()
    if not potionId then
        return false
    end

    -- colour the drop by the potion's meter (a hint); the name is revealed on pickup
    local potCfg = cfg.potions and cfg.potions[potionId]
    local meterCfg = potCfg and cfg.meters and cfg.meters[potCfg.meter]
    local rgb = (meterCfg and meterCfg.color) or { 190, 130, 240 }
    local color = Color3.fromRGB(rgb[1] or 190, rgb[2] or 130, rgb[3] or 240)

    -- model: authored Assets model (override) > tinted neon flask placeholder
    local model
    if drops.model_name then
        local assets = ReplicatedStorage:FindFirstChild("Assets")
        local models = assets and assets:FindFirstChild("Models")
        local tpl = models and models:FindFirstChild(drops.model_name)
        if tpl then
            model = tpl:Clone()
        end
    end
    local part = model and (model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart"))
    if not part then
        model = Instance.new("Model")
        model.Name = "PotionDrop"
        part = Instance.new("Part")
        part.Shape = Enum.PartType.Ball
        part.Size = Vector3.new(1.5, 1.5, 1.5)
        part.Material = Enum.Material.Neon
        part.Color = color
        part.CanCollide = false
        part.CanQuery = false
        part.Anchored = true
        part.Parent = model
        model.PrimaryPart = part
        local bb = Instance.new("BillboardGui")
        bb.Size = UDim2.fromOffset(28, 28)
        bb.StudsOffset = Vector3.new(0, 1.6, 0)
        bb.AlwaysOnTop = true
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.fromScale(1, 1)
        lbl.BackgroundTransparency = 1
        lbl.Font = Enum.Font.GothamBlack
        lbl.TextScaled = true
        lbl.Text = "🧪"
        lbl.Parent = bb
        bb.Parent = part
    end
    part.Anchored = true
    local groundY = self:_groundY(position.X, position.Z, position.Y, position.Y - 1)
    part.CFrame = CFrame.new(position.X, groundY + part.Size.Y * 0.5 + 0.2, position.Z)

    -- OWNER-ONLY VISIBLE (same as enhancement/gem drops): DropOwner before parenting so the client
    -- DropVisibility filter hides it for non-owners.
    model:SetAttribute("DropOwner", player.UserId)
    model.Parent = self._folder or Workspace
    self._active[#self._active + 1] = {
        kind = "potion",
        potionId = potionId,
        model = model,
        part = part,
        noPool = true,
        owner = player.UserId,
        spawnAt = os.clock(),
        despawnSeconds = drops.despawn_seconds or 45,
        settling = false,
    }
    return true
end

-- ---- collect loop ------------------------------------------------------

local function ownerRoot(userId)
    local plr = Players:GetPlayerByUserId(userId)
    if not plr then
        return nil, nil
    end
    local char = plr.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    return plr, hrp and hrp.Position
end

-- BOSS EXCLUSIVE EGG drop: a real 3D egg at the kill site (owner-only
-- visible like enhancements), MAGNET-IMMUNE — Jason: seeing it in the world
-- is the moment; you walk to it. Despawn is a forced collect (never lost).
function DropService:TrySpawnEggDrop(player, eggId, displayName, position)
    if not (player and eggId and typeof(position) == "Vector3") then
        return false
    end
    task.spawn(function()
        -- textured egg mesh via MeshAssembly (THE one mesh+texture combine);
        -- the egg def carries mesh/texture (resolved image ids)
        local part
        pcall(function()
            local petsConfig = require(ReplicatedStorage.Configs:WaitForChild("pets"))
            local def = petsConfig.egg_sources and petsConfig.egg_sources[eggId]
            if def and def.mesh_asset then
                local MeshAssembly = require(ReplicatedStorage.Shared.Assets.MeshAssembly)
                local built = MeshAssembly.build(def.mesh_asset, def.texture_asset, {
                    modelName = "ExclusiveEggDrop",
                })
                local mesh = built and built.PrimaryPart
                if mesh then
                    mesh.Size = mesh.Size * (4 / math.max(mesh.Size.Y, 0.05)) -- ~4 studs tall
                    mesh.Parent = nil
                    built:Destroy()
                    part = mesh
                end
            end
        end)
        if not part then
            part = Instance.new("Part")
            part.Shape = Enum.PartType.Ball
            part.Size = Vector3.new(2.4, 3, 2.4)
            part.Color = Color3.fromRGB(90, 70, 110)
            part.Material = Enum.Material.Slate
        end
        part.Name = "ExclusiveEggDrop"
        part.Anchored = true
        part.CanCollide = false
        part.CanQuery = false
        local model = Instance.new("Model")
        model.Name = "ExclusiveEggDrop"
        part.Parent = model
        model.PrimaryPart = part
        local bb = Instance.new("BillboardGui")
        bb.Size = UDim2.fromOffset(160, 28)
        bb.StudsOffset = Vector3.new(0, 3, 0)
        bb.AlwaysOnTop = true
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.fromScale(1, 1)
        lbl.BackgroundTransparency = 1
        lbl.Font = Enum.Font.GothamBlack
        lbl.TextScaled = true
        lbl.TextColor3 = Color3.fromRGB(255, 220, 120)
        lbl.TextStrokeTransparency = 0.3
        lbl.Text = displayName or "Mysterious Egg"
        lbl.Parent = bb
        bb.Parent = part
        local groundY = self:_groundY(position.X, position.Z, position.Y, position.Y - 1)
        part.CFrame = CFrame.new(position.X, groundY + part.Size.Y * 0.5 + 0.2, position.Z)
        model:SetAttribute("DropOwner", player.UserId)
        model.Parent = self._folder or Workspace
        self._active[#self._active + 1] = {
            kind = "egg_item",
            eggId = eggId,
            eggName = displayName,
            source = "boss_drop",
            model = model,
            part = part,
            noPool = true,
            -- magnet pulls eggs like any loot (Jason 2026-07-09: the world
            -- drop just needs to be SEEABLE, not ceremonially walked to)
            collectOnDespawn = true, -- an exclusive egg is never lost
            owner = player.UserId,
            spawnAt = os.clock(),
            despawnSeconds = 120,
            settling = false,
        }
    end)
    return true
end

-- Expire an unclaimed drop: no grant, just cleanup (mirror of _collect's
-- bookkeeping so the _active sweep drops it the same way).
function DropService:_discard(rec)
    if not rec or rec._done then
        return
    end
    rec._done = true
    for index, active in ipairs(self._active) do
        if active == rec then
            table.remove(self._active, index)
            break
        end
    end
    self:_recycle(rec)
end

-- Remove only matching live drops without granting them. Prototype automation uses this before it
-- restores the tester's saved balance, preventing an old pickup from crediting after reset.
function DropService:DiscardDrops(player, source)
    local owner = typeof(player) == "Instance" and player.UserId or tonumber(player)
    local discarded = 0
    for index = #self._active, 1, -1 do
        local rec = self._active[index]
        if
            rec
            and rec._done ~= true
            and (owner == nil or rec.owner == owner)
            and (source == nil or rec.source == source)
        then
            self:_discard(rec)
            discarded += 1
        end
    end
    return discarded
end

function DropService:_collect(rec, _force)
    if not rec or rec._done then
        return
    end
    rec._done = true
    local plr = Players:GetPlayerByUserId(rec.owner)
    if plr and rec.kind == "enhancement" then
        -- IDENTITY REVEALED AT PICKUP: grant to the inventory + float the name (GameEvents).
        local enh = self._moduleLoader and self._moduleLoader:Get("EnhancementService")
        if enh and enh.Grant then
            local res
            pcall(function()
                res = enh:Grant(plr, rec.record)
            end)
            if res and res.ok then
                pcall(function()
                    fireGameEvent(plr, "enhancement_pickup", {
                        name = res.name,
                        origins = rec.record.origins,
                    })
                end)
            end
        end
    elseif plr and rec.kind == "egg_item" then
        -- BOSS EXCLUSIVE EGG: into the eggs inventory bucket (hatch from
        -- inventory via egg_item.hatch — the Colorado path)
        local inv = self._moduleLoader and self._moduleLoader:Get("InventoryService")
        if inv and inv.AddItem then
            local granted
            pcall(function()
                granted = inv:AddItem(plr, "eggs", {
                    id = rec.eggId,
                    name = rec.eggName or rec.eggId,
                    source = rec.source or "boss_drop",
                })
            end)
            if granted then
                pcall(function()
                    fireGameEvent(plr, "exclusive_egg_pickup", {
                        name = (rec.eggName or "Mysterious Egg") .. " acquired!",
                        egg = rec.eggId,
                    })
                end)
            end
        end
    elseif plr and rec.kind == "potion" then
        -- grant the potion to the bucket + float its name (revealed at pickup, like enhancements)
        local potions = self._moduleLoader and self._moduleLoader:Get("PotionService")
        if potions and potions.Grant then
            local res
            pcall(function()
                res = potions:Grant(plr, rec.potionId, 1)
            end)
            if res and res.ok then
                pcall(function()
                    local cfg = self._potionConfig
                    local pc = cfg and cfg.potions and cfg.potions[rec.potionId]
                    fireGameEvent(
                        plr,
                        "potion_pickup",
                        { name = (pc and pc.display_name) or "Potion" }
                    )
                end)
            end
        end
    elseif plr and rec.amount and rec.amount > 0 then
        local economy = self._moduleLoader and self._moduleLoader:Get("EconomyService")
        if economy and economy.AddCurrency then
            pcall(function()
                economy:AddCurrency(plr, rec.currency, rec.amount, "drop_collect")
            end)
        end
    end
    for i, r in ipairs(self._active) do
        if r == rec then
            table.remove(self._active, i)
            break
        end
    end
    self:_recycle(rec)
end

-- THE player collect radius — ONE source of truth (Jason 2026-07-14: "we should
-- have one source of truth... and only ever reference that variable"). This
-- is the ONLY server consumer of the shared formula: base + Magnet power, floored by pet-ability
-- reach, then multiplied by equipped Magnet enchants. Auto Collector is a separate passive actor
-- and never enters this formula. The result is PUBLISHED
-- as the CollectRadius attribute; the Active Buffs HUD (and anything else)
-- displays that attribute VERBATIM — no client-side re-derivation, so the
-- display can never drift from what the server actually collects with.
function DropService:_effectiveCollectRadius(plr, baseR, nowT)
    local magnetBonus = (plr:GetAttribute("MagnetBuffUntil") or 0) > nowT
            and (tonumber(plr:GetAttribute("MagnetBuff")) or 0)
        or 0
    local r = MagnetRadius.resolve(
        baseR,
        magnetBonus,
        plr:GetAttribute("PetAbilityCollectRange"),
        self:_collectRadiusEnchantBonus(plr)
    )
    if plr:GetAttribute("CollectRadius") ~= r then
        plr:SetAttribute("CollectRadius", r)
    end
    return r
end

function DropService:_step()
    local now = os.clock()
    local dt = math.clamp(now - (self._lastStepAt or now), 0, 0.25)
    self._lastStepAt = now
    self:_stepAutoCollectors(now, dt)
    local cfg = self._config
    local baseR = cfg.collect_radius or 11
    local pullR = cfg.magnet_pull_radius or 6
    local pullSpeed = cfg.magnet_pull_speed or 60
    local despawn = cfg.despawn_seconds or 30
    local spin = math.rad(cfg.part_spin or 90) * (1 / 60)
    local nowT = os.time()

    for i = #self._active, 1, -1 do
        local rec = self._active[i]
        if not rec or rec._done or not rec.part or not rec.part.Parent then
            if rec and not rec._done then
                self:_collect(rec, true)
            end
        elseif now - rec.spawnAt >= (rec.despawnSeconds or despawn) then
            -- DESPAWN ≠ COLLECT (Jason 2026-07-09: "why would you need a
            -- magnet? You could just AFK farm and get everything"): unclaimed
            -- drops now EXPIRE. Only drops that opt in (exclusive eggs — too
            -- rare to ever lose) force-collect at timeout.
            if rec.collectOnDespawn then
                self:_collect(rec, true)
            else
                self:_discard(rec)
            end
        else
            local plr, rootPos = ownerRoot(rec.owner)
            if not plr then
                self:_collect(rec, true)
            elseif rootPos and not rec.settling then
                -- (magnet stays ON in missions — Jason: the CHEST is the
                -- anti-cheese gate; loot only exists once a cleared room's
                -- chest is opened, so magnet can't steal anything early)
                -- magnetImmune (exclusive EGG drops): the find is the moment —
                -- walk to it; base collect radius still applies up close
                local rarePull = plr:GetAttribute("PetAbilityRareDropPull") == true
                local pickupBaseR = tonumber(rec.baseCollectRadius) or baseR
                if rec.collectRadiusAttribute then
                    pickupBaseR = tonumber(plr:GetAttribute(rec.collectRadiusAttribute))
                        or pickupBaseR
                end
                pickupBaseR = math.max(0, pickupBaseR)
                local radius
                if (rec.magnetImmune and not rarePull) or rec.usePlayerModifiers == false then
                    radius = pickupBaseR
                else
                    radius = self:_effectiveCollectRadius(plr, pickupBaseR, nowT)
                end
                local dist = (rec.part.Position - rootPos).Magnitude
                if dist <= math.min(pullR, radius) then
                    self:_collect(rec)
                elseif dist <= radius then
                    local dir = (rootPos - rec.part.Position)
                    local stepLen = math.min(pullSpeed / 60, dir.Magnitude)
                    rec.part.CFrame = rec.part.CFrame * CFrame.Angles(0, spin, 0)
                        + dir.Unit * stepLen
                else
                    rec.part.CFrame = rec.part.CFrame * CFrame.Angles(0, spin, 0)
                end
            elseif not rec.settling then
                rec.part.CFrame = rec.part.CFrame * CFrame.Angles(0, spin, 0)
            end
        end
    end
end

return DropService
