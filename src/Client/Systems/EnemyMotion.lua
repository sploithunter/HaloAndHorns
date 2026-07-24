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
local Signals = require(ReplicatedStorage.Shared.Network.Signals)
local CombatHitFX = require(ReplicatedStorage.Shared.Effects.CombatHitFX)

local EnemyMotion = {}

local localPlayer = Players.LocalPlayer

local function enemiesFolder()
    local game = Workspace:FindFirstChild("Game")
    return game and game:FindFirstChild("Enemies")
end

-- MoveTarget-driven models that AREN'T enemies: an NPC principal's squad
-- (docs/CREATOR_SUMMON.md). Pet movement is normally client-driven by the OWNING player's
-- client — but an NPC has no client, so its pets would never move. Rather than couple them
-- to the summoner's client (which breaks for every other player, and dies if that one
-- disconnects), the server stamps the same `MoveTarget` contract enemies use and this
-- renderer smooths it. Attributes replicate, so every client renders them, with the
-- procedural gait for free.
local function npcSquadFolders()
    local out = {}
    local root = Workspace:FindFirstChild("PlayerPets")
    if not root then
        return out
    end
    for _, folder in ipairs(root:GetChildren()) do
        -- NPC folders are marked by the server; a real player's folder is never touched here
        -- (their own client owns it, and double-driving would fight it).
        if folder:GetAttribute("NpcSquad") == true then
            out[#out + 1] = folder
        end
    end
    return out
end

function EnemyMotion.start()
    local petCfg = require(ReplicatedStorage:WaitForChild("Configs"):WaitForChild("pet_follow"))
    if not petCfg.service_owned then
        return -- legacy path owns movement; this layer is inert
    end
    local combat = require(ReplicatedStorage.Configs:WaitForChild("combat"))
    local enemiesCfg = require(ReplicatedStorage.Configs:WaitForChild("enemies"))
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
        local folder = enemiesFolder()
        local models = folder and folder:GetChildren() or {}
        for _, squad in ipairs(npcSquadFolders()) do
            for _, m in ipairs(squad:GetChildren()) do
                models[#models + 1] = m
            end
        end
        if #models == 0 then
            return
        end
        for _, model in ipairs(models) do
            if model:IsA("Model") and model.PrimaryPart then
                updateLabel(model) -- difficulty-coloured name tag (every enemy, moving or not)
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
    end)
end

return EnemyMotion
