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
local FloatingText = require(ReplicatedStorage.Shared.Effects.FloatingText)

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

    -- Colour + label an enemy's name tag by its difficulty relative to MY level (so it's
    -- per-viewer): white = even, yellow/red/purple harder, blue/green/gray easier.
    local function updateLabel(model)
        local pp = model.PrimaryPart
        local tag = pp and pp:FindFirstChild("NameTag")
        local lbl = tag and tag:FindFirstChild("Name")
        if not lbl then
            return
        end
        local enemyLevel = model:GetAttribute("Level") or 1
        local myLevel = localPlayer:GetAttribute("Level") or 1
        lbl.TextColor3 = tierColor[LevelScale.tier(enemyLevel - myLevel)] or WHITE
        lbl.Text = (model:GetAttribute("DisplayName") or "Enemy") .. "  Lv " .. tostring(enemyLevel)
    end

    -- Resolve (once per enemyId) the merged gait: per-enemy override fields win over the
    -- shared default. Cached so we don't rebuild the table every frame.
    local gaitCache = {}
    local function resolveGait(enemyId)
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
        -- A whiff floats "MISS" over the PET (same FloatingText path the pets use over enemies).
        -- A Sandstorm-blinded attacker recolours it orange (combat_text.colors.blind_miss) so the
        -- accuracy cut reads at a glance; a plain accuracy miss stays grey.
        if data.miss then
            local ctCfg = petCfg.combat_text or {}
            if ctCfg.enabled ~= false then
                local cols = ctCfg.colors or {}
                -- Blind whiff -> orange: config colour if present, else a hardcoded orange so a blind
                -- miss is NEVER silently grey (don't let it hinge on the new config key syncing).
                -- Plain accuracy miss -> grey.
                local rgb
                if data.blind then
                    rgb = cols.blind_miss or { 255, 150, 40 }
                else
                    rgb = cols.miss or { 175, 175, 175 }
                end
                local up = 3
                local okE, ext = pcall(function()
                    return target:GetExtentsSize()
                end)
                if okE and ext then
                    up = ext.Y * 0.5 + 1
                end
                local pos = (
                    (target.PrimaryPart and target.PrimaryPart.Position)
                    or target:GetPivot().Position
                ) + Vector3.new(0, up, 0)
                pcall(FloatingText.show, pos, ctCfg.miss_text or "MISS", {
                    color = Color3.fromRGB(rgb[1] or 175, rgb[2] or 175, rgb[3] or 175),
                    size = ctCfg.size or 22,
                    rise = ctCfg.rise,
                    duration = ctCfg.duration,
                })
            end
        end
    end)

    RunService.RenderStepped:Connect(function(dt)
        local folder = enemiesFolder()
        if not folder then
            return
        end
        local alpha = 1 - math.exp(-rate * dt)
        for _, model in ipairs(folder:GetChildren()) do
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
