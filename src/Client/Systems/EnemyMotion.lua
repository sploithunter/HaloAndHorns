--[[
    EnemyMotion — CLIENT-side smoothing + procedural walk gait for enemies (Feature 10).

    EnemyService moves each enemy server-side in ~update_interval steps (the server is
    authoritative — entry.pos / the MoveTarget attribute drives the mining gate). It no
    longer pivots the model, so the client fully owns the visible CFrame:

      1) SMOOTHING — lerp the model toward the server's MoveTarget every RenderStepped,
         so chasing reads smooth despite the coarse server tick.
      2) GAIT — these enemies are rig-less single-mesh models, so there's no skeletal
         animation. Instead we layer a procedural motion on the smoothed base CFrame,
         driven by distance travelled (so it scales with speed and rests when still).

    The gait is per-enemy: combat.engagement.gait is the default and each enemy in
    configs/enemies.lua can override any field via its own `gait = {...}`, so different
    pets move differently. `style` picks the motion SHAPE (see STYLES below).
]]

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Gait = require(ReplicatedStorage.Shared.Game.Gait)
local LevelScale = require(ReplicatedStorage.Shared.Game.LevelScale)
local HitReact = require(ReplicatedStorage.Shared.Game.HitReact)
local CombatDeath = require(ReplicatedStorage.Shared.Game.CombatDeath)
local Signals = require(ReplicatedStorage.Shared.Network.Signals)
local CombatHitFX = require(ReplicatedStorage.Shared.Effects.CombatHitFX)
local TweenService = game:GetService("TweenService")

local EnemyMotion = {}

local localPlayer = Players.LocalPlayer

local function enemiesFolder()
    local game = Workspace:FindFirstChild("Game")
    return game and game:FindFirstChild("Enemies")
end

function EnemyMotion.start()
    local petCfg = require(ReplicatedStorage:WaitForChild("Configs"):WaitForChild("pet_follow"))
    if not petCfg.service_owned then
        return -- legacy path owns movement; this layer is inert
    end
    local combat = require(ReplicatedStorage.Configs:WaitForChild("combat"))
    local enemiesCfg = require(ReplicatedStorage.Configs:WaitForChild("enemies"))
    local deathsCfg = require(ReplicatedStorage.Configs:WaitForChild("combat_deaths"))
    local leveling = require(ReplicatedStorage.Configs:WaitForChild("leveling"))
    local eng = combat.engagement or {}
    local rate = eng.render_lerp_rate or 12
    local defaultGait = eng.gait or {}

    -- Difficulty colours by tier key (from leveling.tier_colors), built once.
    local tierColor = {}
    for key, rgb in pairs(leveling.tier_colors or {}) do
        tierColor[key] = Color3.fromRGB(rgb[1] or 245, rgb[2] or 245, rgb[3] or 245)
    end
    local WHITE = Color3.fromRGB(245, 245, 245)

    -- SEEN GATE (Jason: "I shouldn't be able to see healthbars through walls
    -- ... until I have seen the enemy or my pet has engaged it"): billboards
    -- are AlwaysOnTop, so unseen enemies leak intel through mission walls.
    -- Per-VIEWER state (this is a client system): an enemy's overhead UI stays
    -- hidden until (a) it's damaged/engaged, or (b) I get real line of sight.
    -- Once seen it stays visible — through-wall bars on a fight you've met is
    -- the CoH tracking feature, not a leak. Weak keys: despawns self-clean.
    local seen = setmetatable({}, { __mode = "k" })
    local losAt = setmetatable({}, { __mode = "k" }) -- last LOS probe time
    local camera = Workspace.CurrentCamera
    local losParams = RaycastParams.new()
    losParams.FilterType = Enum.RaycastFilterType.Exclude
    local SEEN_RANGE = 130
    local LOS_INTERVAL = 0.25

    local function setOverheadsEnabled(pp, on)
        for _, name in ipairs({ "NameTag", "HealthBar", "HeldBadge" }) do
            local bb = pp:FindFirstChild(name)
            if bb and bb:IsA("BillboardGui") and bb.Enabled ~= on then
                bb.Enabled = on
            end
        end
    end

    local function seenGate(model, pp, now)
        if seen[model] then
            setOverheadsEnabled(pp, true) -- late-created bars (HeldBadge) join in
            return
        end
        -- engaged: anything that hurt it reveals it (my pets included)
        local hp = model:GetAttribute("HP")
        local maxHp = model:GetAttribute("MaxHP")
        if hp and maxHp and hp < maxHp then
            seen[model] = true
            setOverheadsEnabled(pp, true)
            return
        end
        -- LOS probe (throttled per enemy): camera → enemy, blocked by world
        local last = losAt[model]
        if not last or now - last >= LOS_INTERVAL then
            losAt[model] = now
            local cam = camera or Workspace.CurrentCamera
            camera = cam
            local char = localPlayer.Character
            if cam and pp.Position then
                local origin = cam.CFrame.Position
                local delta = pp.Position - origin
                if delta.Magnitude <= SEEN_RANGE and delta:Dot(cam.CFrame.LookVector) > 0 then
                    losParams.FilterDescendantsInstances = { model, char }
                    local hit = Workspace:Raycast(origin, delta, losParams)
                    if not hit then
                        seen[model] = true
                        setOverheadsEnabled(pp, true)
                        return
                    end
                end
            end
        end
        setOverheadsEnabled(pp, false)
    end

    -- Colour + label an enemy's name tag by its difficulty relative to MY level (so it's
    -- per-viewer): white = even, yellow/red/purple harder, blue/green/gray easier.
    local function updateLabel(model)
        local pp = model.PrimaryPart
        seenGate(model, pp, os.clock())
        local tag = pp and pp:FindFirstChild("NameTag")
        local lbl = tag and tag:FindFirstChild("Name")
        if not lbl then
            return
        end
        local enemyLevel = model:GetAttribute("Level") or 1
        -- COMBAT level (EffectiveLevel = sidekick-synced), not earned Level, so the con
        -- colour matches how the fight will actually roll for a sidekicked player.
        local myLevel = localPlayer:GetAttribute("EffectiveLevel")
            or localPlayer:GetAttribute("Level")
            or 1
        lbl.TextColor3 = tierColor[LevelScale.tier(enemyLevel - myLevel)] or WHITE
        lbl.Text = (model:GetAttribute("DisplayName") or "Enemy") .. "  Lv " .. tostring(enemyLevel)
    end

    -- Resolve (once per enemyId) the merged gait: per-enemy override fields win over the
    -- shared default. Cached so we don't rebuild the table every frame.
    local gaitCache = {}
    local function resolveGait(enemyId)
        -- NPC-squad pets carry no EnemyId; a nil key here crashed every RenderStepped
        -- ("table index is nil" x thousands — Jason's console flood). They get the default
        -- gait under a sentinel key.
        enemyId = enemyId or "__default"
        local cached = gaitCache[enemyId]
        if cached then
            return cached
        end
        local entry = enemiesCfg.enemies and enemiesCfg.enemies[enemyId]
        local g = Gait.resolve(defaultGait, entry and entry.gait)
        gaitCache[enemyId] = g
        return g
    end

    local function toColor3(rgb, fallback)
        if type(rgb) == "table" then
            return Color3.fromRGB(rgb[1] or 235, rgb[2] or 90, rgb[3] or 90)
        end
        return fallback or Color3.fromRGB(235, 90, 90)
    end

    -- Tiny gold Robux cubes: pop out one by one, arc onto the ground, fade.
    local function spawnRobuxCubes(origin, style)
        local cubes = style.cubes or {}
        local size = math.max(0.16, tonumber(cubes.size) or 0.36)
        local image = tostring(cubes.image or "rbxasset://textures/ui/common/robux.png")
        local color = toColor3(style.color, Color3.fromRGB(245, 205, 55))
        local groundY = origin.Y - 1.15
        local plan = CombatDeath.cubePlan(style, math.random)
        for _, step in ipairs(plan) do
            task.delay(step.delay, function()
                local part = Instance.new("Part")
                part.Name = "DeathRobuxCube"
                part.Size = Vector3.new(size, size, size)
                part.Anchored = true
                part.CanCollide = false
                part.CanQuery = false
                part.CastShadow = false
                part.Material = Enum.Material.SmoothPlastic
                part.Color = color
                part.CFrame = CFrame.new(origin)
                part.Parent = Workspace
                local gui = Instance.new("SurfaceGui")
                gui.Face = Enum.NormalId.Front
                gui.LightInfluence = 0
                gui.Parent = part
                local img = Instance.new("ImageLabel")
                img.BackgroundTransparency = 1
                img.Size = UDim2.fromScale(1, 1)
                img.Image = image
                img.ImageColor3 = Color3.fromRGB(40, 28, 8)
                img.Parent = gui
                local land = Vector3.new(origin.X + step.x, groundY, origin.Z + step.z)
                local mid = Vector3.new(
                    (origin.X + land.X) * 0.5,
                    origin.Y + step.peak,
                    (origin.Z + land.Z) * 0.5
                )
                local up = TweenService:Create(part, TweenInfo.new(0.28, Enum.EasingStyle.Quad), {
                    CFrame = CFrame.new(mid) * CFrame.Angles(0.4, step.delay * 8, 0.2),
                })
                local down = TweenService:Create(
                    part,
                    TweenInfo.new(0.38, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
                    {
                        CFrame = CFrame.new(land) * CFrame.Angles(0.15, step.delay * 14, 0.1),
                    }
                )
                up.Completed:Connect(function()
                    down:Play()
                end)
                up:Play()
                task.delay(math.max(0.6, step.lifetime - 0.45), function()
                    if not part.Parent then
                        return
                    end
                    TweenService:Create(part, TweenInfo.new(0.45, Enum.EasingStyle.Quad), {
                        Transparency = 1,
                        Size = part.Size * 0.35,
                    }):Play()
                end)
                task.delay(step.lifetime + 0.15, function()
                    if part.Parent then
                        part:Destroy()
                    end
                end)
            end)
        end
    end

    local function spawnDeathBurst(origin, style)
        if type(style) == "table" and type(style.cubes) == "table" then
            spawnRobuxCubes(origin, style)
            return
        end
        local color = toColor3(style and style.color, Color3.fromRGB(235, 90, 90))
        for i = 1, 14 do
            local part = Instance.new("Part")
            part.Size = Vector3.new(0.28, 0.28, 0.28)
            part.Anchored = true
            part.CanCollide = false
            part.CanQuery = false
            part.CastShadow = false
            part.Material = Enum.Material.Neon
            part.Color = color
            part.CFrame = CFrame.new(origin)
            part.Parent = Workspace
            local ang = (i / 14) * math.pi * 2
            local dist = 2.8 + (i % 4)
            TweenService
                :Create(part, TweenInfo.new(0.7, Enum.EasingStyle.Quad), {
                    CFrame = CFrame.new(
                        origin
                            + Vector3.new(math.cos(ang) * dist, 1.6 + (i % 3), math.sin(ang) * dist)
                    ),
                    Transparency = 1,
                })
                :Play()
            task.delay(0.8, function()
                if part.Parent then
                    part:Destroy()
                end
            end)
        end
    end

    -- model -> { base = CFrame (no gait), phase, amp }. Weak keys so enemies drop out.
    local state = setmetatable({}, { __mode = "k" })
    -- HIT-REACT (Jason: don't stay frozen when struck): a pet swing fires Combat_PetHit
    -- {pet,target}; flinch the target enemy away from the pet. Per-model weak-keyed state.
    local flinch = setmetatable({}, { __mode = "k" })
    Signals.Combat_PetHit.OnClientEvent:Connect(function(data)
        local target = data and data.target
        if typeof(target) ~= "Instance" or not target:IsA("Model") then
            return
        end
        local fs = flinch[target]
        if not fs then
            fs = {}
            flinch[target] = fs
        end
        -- shove away from the attacker (pet -> enemy); fall back to the enemy's -look
        local dx, dz = 0, 0
        local tp = target.PrimaryPart and target.PrimaryPart.Position
        local pet = data.pet
        local pp = typeof(pet) == "Instance"
            and pet:IsA("Model")
            and pet.PrimaryPart
            and pet.PrimaryPart.Position
        if tp and pp then
            dx, dz = tp.X - pp.X, tp.Z - pp.Z
        elseif tp then
            local lv = target.PrimaryPart.CFrame.LookVector
            dx, dz = -lv.X, -lv.Z
        end
        HitReact.start(fs, os.clock(), dx, dz, math.random() < 0.5 and 1 or -1)
    end)

    -- Enemy swing FX: the server fires Combat_EnemyHit {enemy,target,kind,crit,ranged} on EVERY
    -- enemy attack (damage already applied server-side). Same attack-FX path the pets use
    -- (CombatHitFX, off Combat_PetHit): ranged -> a themed bolt enemy->pet (bolt_kind), melee ->
    -- an impact at the pet. So a ranged enemy reads as ranged, and a melee bite lands a hit like a
    -- pet's swing. One code path for "how a combatant attacks".
    local boltCfg = petCfg.ranged_bolt or {}
    Signals.Combat_EnemyHit.OnClientEvent:Connect(function(data)
        if type(data) ~= "table" then
            return
        end
        local enemy, target = data.enemy, data.target
        if typeof(enemy) ~= "Instance" or typeof(target) ~= "Instance" then
            return
        end
        if not enemy.Parent or not target.Parent then
            return
        end
        pcall(CombatHitFX.play, enemy, target, {
            boltCfg = boltCfg,
            ranged = data.ranged == true,
            kind = data.kind,
            defaultKind = boltCfg.kind or "plasma",
            crit = data.crit == true,
        })
    end)

    RunService.RenderStepped:Connect(function(dt)
        local alpha = 1 - math.exp(-rate * dt)
        -- Enemies plus any NPC-principal squads: both drive off the same MoveTarget contract.
        -- The Enemies folder is OPTIONAL here (it appears lazily with the first enemy spawn):
        -- the old early-return when it was absent silently killed NPC-squad rendering too —
        -- live: Jason in the prologue room, squad frozen, Game.Enemies=false.
        -- NPC-squad pets are now driven by PetFollowController's driveAnchor (the same
        -- code path as the player's own squad — real formations/meander/gait), so they no
        -- longer render here; two writers on one pivot fight each other.
        local folder = enemiesFolder()
        local models = folder and folder:GetChildren() or {}
        if #models == 0 then
            return
        end
        for _, model in ipairs(models) do
            if model:IsA("Model") and model.PrimaryPart then
                updateLabel(model) -- difficulty-coloured name tag (every enemy, moving or not)
                if model:GetAttribute("Dying") == true then
                    local st = state[model]
                    if not st then
                        st = { base = model:GetPivot(), phase = 0, amp = 0 }
                        state[model] = st
                    end
                    if not st.deathBurst then
                        st.deathBurst = true
                        setOverheadsEnabled(model.PrimaryPart, false)
                        local styleId = model:GetAttribute("DeathStyle") or "flop"
                        local style = CombatDeath.styleById(deathsCfg, styleId)
                        local origin = model:GetPivot().Position + Vector3.new(0, 1.2, 0)
                        spawnDeathBurst(origin, style)
                    end
                    local started = tonumber(model:GetAttribute("DeathAt"))
                        or Workspace:GetServerTimeNow()
                    local dur = math.max(0.35, tonumber(model:GetAttribute("DeathSeconds")) or 0.85)
                    local t = math.clamp((Workspace:GetServerTimeNow() - started) / dur, 0, 1)
                    local pose = CombatDeath.sample(model:GetAttribute("DeathStyle") or "flop", t)
                    local cf, scale, fade = CombatDeath.applyPose(st.base, pose)
                    if model.ScaleTo and math.abs(scale - (st.deathScale or 1)) > 0.02 then
                        pcall(function()
                            model:ScaleTo(scale)
                        end)
                        st.deathScale = scale
                    end
                    if fade > 0 then
                        for _, part in ipairs(model:GetDescendants()) do
                            if part:IsA("BasePart") then
                                part.LocalTransparencyModifier = fade
                            end
                        end
                    end
                    model:PivotTo(cf)
                else
                    local target = model:GetAttribute("MoveTarget")
                    if target then
                        local face = model:GetAttribute("MoveFace")
                        local goal
                        if face and (face - target).Magnitude > 1e-3 then
                            goal = CFrame.lookAt(target, face)
                        else
                            goal = CFrame.new(target)
                        end

                        local st = state[model]
                        if not st then
                            st = { base = model:GetPivot(), phase = 0, amp = 0 }
                            state[model] = st
                        end

                        -- 1) Smoothed base position (no gait — kept clean for next lerp).
                        local base = st.base:Lerp(goal, alpha)
                        local stepDist = (Vector3.new(base.X, 0, base.Z) - Vector3.new(
                            st.base.X,
                            0,
                            st.base.Z
                        )).Magnitude
                        st.base = base

                        -- 2) Layer the procedural gait (shared with pets) on the clean base.
                        local gait = resolveGait(model:GetAttribute("EnemyId"))
                        local bob, roll, yaw = Gait.advance(st, gait, stepDist, dt)
                        local cf = CFrame.new(0, bob, 0) * base * CFrame.Angles(0, yaw, roll)
                        -- 3) Hit-react flinch: world-space recoil + a local twist, decaying to 0.
                        local fs = flinch[model]
                        if fs then
                            local fx, fz, fyaw = HitReact.sample(fs, os.clock())
                            if fx ~= 0 or fz ~= 0 or fyaw ~= 0 then
                                cf = (cf + Vector3.new(fx, 0, fz)) * CFrame.Angles(0, fyaw, 0)
                            end
                        end
                        model:PivotTo(cf)
                    end
                end
            end
        end
    end)
end

return EnemyMotion
