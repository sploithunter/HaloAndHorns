--[[
    DropService (server, #167 + #177) — physical GEM pickups + Magnet collection.

    When a crystal breaks, BreakableSpawner hands the resolved COIN award to SpawnCoinDrop instead of
    crediting it instantly. The award SPLITS into one or more GEMS (payout by count — a fat node
    bursts a fistful) that pop out and rest on the ground; a single Heartbeat loop collects them when
    the owner walks within `collect_radius` (+ the Magnet power's MagnetBuff bonus), flying them in
    once close. Coins are never lost: a gem auto-collects to its owner on despawn-timeout or when the
    per-server cap is exceeded. XP / pet-xp / realm cuts stay instant in BreakableSpawner.

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

local DropService = {}
DropService.__index = DropService

local function color3(t)
    return Color3.fromRGB(t[1] or 240, t[2] or 200, t[3] or 70)
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
    self._config = (self._configLoader and self._configLoader:LoadConfig("drops"))
        or require(ReplicatedStorage.Configs:WaitForChild("drops"))
    self._gems = (self._configLoader and self._configLoader:LoadConfig("gems"))
        or require(ReplicatedStorage.Configs:WaitForChild("gems"))

    self._active = {} -- live drop records
    self._pool = {} -- recycled gem models, keyed "color|form" (or "ball")
    self._templates = {} -- built gem model templates, keyed "color|form"

    if not self._config.enabled then
        return -- inert: BreakableSpawner credits instantly when SpawnCoinDrop returns false
    end

    self._folder = Instance.new("Folder")
    self._folder.Name = "CoinDrops"
    self._folder.Parent = Workspace
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
    end)

    self._conn = RunService.Heartbeat:Connect(function()
        self:_step()
    end)
end

function DropService:IsEnabled()
    return self._config and self._config.enabled == true
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

-- Spawn gem pickups for a coin award. Returns true if drops were created (caller must NOT credit),
-- false to credit instantly (disabled / too small / no position). Never throws.
function DropService:SpawnCoinDrop(player, currencyType, amount, position)
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

    local color = self:_colorFor(currencyType)
    local chunks = self:_split(amount)
    local pop = self._config.pop_up or 7
    local out = self._config.pop_out or 5

    for i, chunkAmount in ipairs(chunks) do
        -- cap: auto-collect the oldest live drop so the world never floods
        if #self._active >= (self._config.max_active or 90) then
            self:_collect(self._active[1], true)
        end
        local form = self:_formFor(chunkAmount)
        local model, part = self:_acquireGem(color, form)
        local ang = ((#self._active + i) % 12) * (math.pi / 6)
        local hx = position.X + math.cos(ang) * out
        local hz = position.Z + math.sin(ang) * out
        local groundY = self:_groundY(hx, hz, position.Y, position.Y - 1)
        local radius = part.Size.Y * 0.5
        local rest = Vector3.new(hx, groundY + radius, hz)
        local apex = position
            + Vector3.new(math.cos(ang) * out * 0.5, pop, math.sin(ang) * out * 0.5)
        -- random resting yaw so gems don't all turn in lockstep (they settle facing
        -- random directions; the _step spin then carries each from its own phase)
        local yaw = math.random() * (2 * math.pi)
        part.CFrame = CFrame.new(apex) * CFrame.Angles(0, yaw, 0)

        -- visibility filter: gems are owner-only pickups, so they're owner-only
        -- VISIBLE too (DropVisibility hides foreign gems client-side — Jason: "it
        -- makes it really confusing if gems are everywhere and they're not yours")
        model:SetAttribute("DropOwner", player.UserId)
        local rec = {
            model = model,
            part = part,
            poolKey = color .. "|" .. form,
            owner = player.UserId,
            currency = tostring(currencyType or "coins"),
            amount = math.floor(chunkAmount),
            spawnAt = os.clock(),
            settling = true,
        }
        self._active[#self._active + 1] = rec

        local TweenService = game:GetService("TweenService")
        TweenService:Create(
            part,
            TweenInfo.new(
                self._config.pop_time or 0.35,
                Enum.EasingStyle.Quad,
                Enum.EasingDirection.Out
            ),
            { CFrame = CFrame.new(rest) * CFrame.Angles(0, yaw, 0) }
        ):Play()
        task.delay(self._config.pop_time or 0.35, function()
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
function DropService:TrySpawnEnhancementDrop(player, source, position)
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
    local chance = (source == "enemy" and drops.enemy_chance) or drops.breakable_chance or 0
    -- Windfall (drop_rate axis): an active drop-rate buff multiplies the loot chance.
    if (player:GetAttribute("DropRateBuffUntil") or 0) > os.time() then
        chance = chance * (1 + (tonumber(player:GetAttribute("DropRateBuff")) or 0))
    end
    -- Showering Saturday (drop_rate global event): same axis, server-wide.
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
    local enh = self._moduleLoader and self._moduleLoader:Get("EnhancementService")
    if not (enh and enh.RollDrop) then
        return false
    end
    -- pre-origin players (no Archetype chosen yet) get NATURAL drops — origin gear
    -- would be unslottable dead weight for them (Jason)
    local data = self._dataService and self._dataService:GetData(player)
    local hasOrigin = data and data.Archetype ~= nil
    local record = enh:RollDrop(nil, player:GetAttribute("CurrentArea"), {
        natural = not hasOrigin,
        playerLevel = player:GetAttribute("Level"), -- band follows the player past the area top
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
    -- Windfall (drop_rate axis): an active drop-rate buff multiplies the loot chance.
    if (player:GetAttribute("DropRateBuffUntil") or 0) > os.time() then
        chance = chance * (1 + (tonumber(player:GetAttribute("DropRateBuff")) or 0))
    end
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
                    local Signals = require(ReplicatedStorage.Shared.Network.Signals)
                    Signals.GameEvent:FireClient(plr, "enhancement_pickup", {
                        name = res.name,
                        origins = rec.record.origins,
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
                    local Signals = require(ReplicatedStorage.Shared.Network.Signals)
                    local cfg = self._potionConfig
                    local pc = cfg and cfg.potions and cfg.potions[rec.potionId]
                    Signals.GameEvent:FireClient(
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

function DropService:_step()
    local now = os.clock()
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
            self:_collect(rec, true)
        else
            local plr, rootPos = ownerRoot(rec.owner)
            if not plr then
                self:_collect(rec, true)
            elseif rootPos and not rec.settling then
                local bonus = 0
                if (plr:GetAttribute("MagnetBuffUntil") or 0) > nowT then
                    bonus = tonumber(plr:GetAttribute("MagnetBuff")) or 0
                end
                local dist = (rec.part.Position - rootPos).Magnitude
                if dist <= pullR then
                    self:_collect(rec)
                elseif dist <= (baseR + bonus) then
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
