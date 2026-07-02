--[[
    PetFollowController — CLIENT-side pet movement visualisation (issue #4 retry).

    Positions the local player's pets every RenderStepped (full framerate -> smooth,
    no jerk). Pets are ANCHORED by the server (PetFollowService), so they can never
    fall/drift — this controller just sets their CFrame kinematically each frame,
    lerping toward a moving target (momentum feel; frame-rate independent).

    Follow:  pets hold a config formation behind the player.
    Attack:  pets SURROUND the target in an animated ring (orbit/static_ring/lunge).
             Switch live with localPlayer:SetAttribute("PetAttackStyle", "lunge").

    Damage + target assignment are server-side; this is pure visualisation. Other
    clients seeing a player's pets move (position replication) is a documented
    follow-up; this drives the LOCAL player's view.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local PetFormation = require(ReplicatedStorage.Shared.Game.PetFormation)
local PetMeander = require(ReplicatedStorage.Shared.Game.PetMeander)
local Gait = require(ReplicatedStorage.Shared.Game.Gait)
local HitReact = require(ReplicatedStorage.Shared.Game.HitReact)
local AttackAnim = require(ReplicatedStorage.Shared.Game.AttackAnim)
local CombatOrigin = require(ReplicatedStorage.Shared.Game.CombatOrigin)
local RangedFX = require(ReplicatedStorage.Shared.Effects.RangedFX)
local CombatHitFX = require(ReplicatedStorage.Shared.Effects.CombatHitFX)
local AreaFX = require(ReplicatedStorage.Shared.Effects.AreaFX)
local CombatFX = require(ReplicatedStorage.Shared.Effects.CombatFX)
local FloatingText = require(ReplicatedStorage.Shared.Effects.FloatingText)
local PowerSound = require(ReplicatedStorage.Shared.Effects.PowerSound)
local PowerFXRender = require(ReplicatedStorage.Shared.Effects.PowerFXRender)
local PetRoles = require(ReplicatedStorage.Configs:WaitForChild("pet_roles"))
local Signals = require(ReplicatedStorage.Shared.Network.Signals)

-- A pet's combat role (matches SquadHud): PetRole attr -> by_type[PetType] -> default.
local function petRoleId(pet)
    return pet:GetAttribute("PetRole")
        or (PetRoles.by_type and PetRoles.by_type[pet:GetAttribute("PetType")])
        or PetRoles.default
end

-- Combat ring SLOT priority (lower = nearer slot-0, the player-facing "peel" anchor). The attack
-- ring's slot-0 sits between you and the target; whoever holds it shoves the enemy AWAY from you
-- (the bodyguard peel). The enemy keeps its range from its aggro-holder — the TANK — so the tank
-- MUST own slot-0 or the fight inverts (a huge tank, size-sorted to a far slot, draws the enemy
-- TOWARD you — Jason's "polar bear is driving it at me" bug, which only shows with 2+ pets).
-- Tank first, then the front line, then standoff roles last (they want the far slots anyway).
-- Ties (e.g. multiple tanks) fall through to the stable size/equip-slot sort = current ordering.
local COMBAT_SLOT_PRIORITY = { tank = 0, melee = 1, control = 2, ranged = 3, support = 4 }
local function combatSlotPriority(pet)
    return COMBAT_SLOT_PRIORITY[petRoleId(pet)] or 2
end

-- Studs the pet holds back from its target in the attack formation (role.standoff).
local function roleStandoff(pet)
    local def = PetRoles.roles and PetRoles.roles[petRoleId(pet)]
    return (def and tonumber(def.standoff)) or 0
end

-- Kiters (role.kite) hold their player-formation slot and snipe rather than orbiting the
-- target, so a chasing enemy must close on them instead of drifting with the orbit.
local function roleKites(pet)
    local def = PetRoles.roles and PetRoles.roles[petRoleId(pet)]
    return def and def.kite == true
end

-- How far the pet can hit from (role.attack_range). Used to decide whether a kiter can snipe
-- its target from the player formation, or must advance to engage it.
local function attackRangeOf(pet)
    local def = PetRoles.roles and PetRoles.roles[petRoleId(pet)]
    return (def and tonumber(def.attack_range)) or 9
end

-- Map-collision clamp for pet attack slots (Jason: a kiting/standoff pet marched off the map —
-- pets are non-colliding). Mirrors the crystal spawner's blocker rule: a slot is BLOCKED if a
-- solid (CanCollide + opaque + queryable) part sits in an ELEVATED box at it. The band is above
-- the floor, so flat sidewalks/baseplate never count — only WALLS/ROCKS reach into it. The map
-- floor extends past the walls, so "is there floor?" can't bound it; the wall does (the pet hits
-- the wall before it could reach the floor on the far side). `exclude` drops everything dynamic
-- (Workspace.Game = crystals/enemies/drops, PlayerPets, characters) so only authored map blocks.
local CLEAR_BOX_W = 4 -- pet body footprint (studs) sampled for an obstacle
local CLEAR_BOX_H = 6 -- vertical band height — skips flat ground, catches walls/rocks
local CLEAR_BOX_Y = 2 -- box centre, this far above the slot (keeps the band off the floor)
local function slotBlocked(pos, exclude)
    local params = OverlapParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = exclude
    params.MaxParts = 8
    local parts = Workspace:GetPartBoundsInBox(
        CFrame.new(pos + Vector3.new(0, CLEAR_BOX_Y, 0)),
        Vector3.new(CLEAR_BOX_W, CLEAR_BOX_H, CLEAR_BOX_W),
        params
    )
    for _, part in ipairs(parts) do
        if part.CanCollide and part.CanQuery and part.Transparency < 0.95 then
            return true -- a wall/rock occupies the slot
        end
    end
    return false
end

local PetFollowController = {}

local localPlayer = Players.LocalPlayer

-- Per-pet footprint (studs) for size-aware formations — the model's larger XZ extent, so huge
-- pets read bigger. Measured ONCE and stamped on the pet (an attribute persists for the model's
-- life), then QUANTIZED to 0.1 studs. Both matter: pet idle animations make GetExtentsSize
-- breathe by a hair, so two identical pets read minutely different + fluctuating extents — left
-- raw, that made the size-sort flip them frame to frame (the "swapping" bug). Quantizing collapses
-- identical pets to the exact same value so the stable tiebreak (equip slot) wins; stamping keeps
-- it from ever being recomputed.
local function petFootprint(pet, config)
    local stored = pet:GetAttribute("PetFootprint")
    if stored then
        return stored
    end
    local f
    local ok, ext = pcall(function()
        return pet:GetExtentsSize()
    end)
    if ok and ext then
        f = math.max(ext.X, ext.Z)
    end
    if not f or f <= 0 then
        f = (config.formation.size and config.formation.size.default_footprint) or 4
    end
    f = math.floor(f * 10 + 0.5) / 10 -- quantize to 0.1 stud
    pet:SetAttribute("PetFootprint", f)
    return f
end

-- Vertical float touch-up (studs): huge models scale up but keep the flat formation.height, so
-- most float and a few tall tanks sink. config.float_offsets (pet_follow.lua) is EXTENSIBLE +
-- OPTIONAL — everything defaults to 0. Resolution: by_type[petType].{huge|normal} overrides the
-- class default (huge/normal). Added to the follow target Y (below the bob, so the bob rides it).
local function floatTouchup(pet, config)
    local fo = config.float_offsets
    if not fo then
        return 0
    end
    local isHuge = pet:GetAttribute("Huge") == true
    local byType = fo.by_type and fo.by_type[pet:GetAttribute("PetType")]
    if byType then
        local v = isHuge and byType.huge or byType.normal
        if v ~= nil then
            return v
        end
    end
    return (isHuge and fo.huge or fo.normal) or 0
end

-- Stable per-pet ordering key (the equip slot). Distinct + stable per equipped pet, so sorts
-- that tie on size (identical pets) stay deterministic instead of swapping frame to frame.
local function petSlot(pet)
    local n = pet:FindFirstChild("PositionNumber")
    return (n and n.Value) or 0
end

local function findBreakable(targetType, world, id)
    local game = Workspace:FindFirstChild("Game")
    if not game then
        return nil
    end
    if targetType == "Enemy" then
        local enemies = game:FindFirstChild("Enemies")
        if not enemies then
            return nil
        end
        for _, desc in ipairs(enemies:GetDescendants()) do
            if desc.Name == "BreakableID" and desc:IsA("NumberValue") and desc.Value == id then
                return desc.Parent
            end
        end
        return nil
    end
    local breakables = game:FindFirstChild("Breakables")
    if not breakables then
        return nil
    end
    local typeFolder = targetType and breakables:FindFirstChild(targetType)
    local scope = typeFolder and (typeFolder:FindFirstChild(world) or typeFolder)
    if not scope then
        return nil
    end
    for _, desc in ipairs(scope:GetDescendants()) do
        if desc.Name == "BreakableID" and desc:IsA("NumberValue") and desc.Value == id then
            return desc.Parent
        end
    end
    return nil
end

function PetFollowController.start()
    local config = require(ReplicatedStorage:WaitForChild("Configs"):WaitForChild("pet_follow"))
    if not config.service_owned then
        return -- legacy scripts own movement; controller idle
    end
    local startClock = os.clock()
    -- Idle meander (PetMeander): per-pet stroll state + how long the PLAYER has
    -- been standing still (the gate that releases the squad to wander).
    local meanderCfg = config.meander or {}
    local meanderStates = {}
    local lastPlayerPos = nil
    local playerStillFor = 0
    local reportAccum = 0
    local reportInterval = (config.replication and config.replication.interval) or 0.1

    -- Procedural walk gait (shared with enemies — src/Shared/Game/Gait.lua). Resolved
    -- per PetType (gait_by_type override merged over the default), cached. baseCF holds
    -- each pet's CLEAN target pivot (no gait) so the lerp + position report never feed
    -- the bob/tilt back into themselves; gaitState carries the per-pet phase/amplitude.
    local defaultGait = config.gait or {}
    local gaitByType = config.gait_by_type or {}
    local gaitCache = {}
    local function resolveGait(petType)
        local key = petType or "_default"
        local cached = gaitCache[key]
        if cached then
            return cached
        end
        local g = Gait.resolve(defaultGait, gaitByType[petType])
        gaitCache[key] = g
        return g
    end
    local baseCF = setmetatable({}, { __mode = "k" }) -- pet model -> clean CFrame (no gait)
    local gaitState = setmetatable({}, { __mode = "k" }) -- pet model -> { phase, amp }
    local attackTimer = setmetatable({}, { __mode = "k" }) -- pet model -> { t } (attack-anim clock)
    -- HIT-REACT (Jason: don't stay frozen when struck): a rise in CombatDamageTaken
    -- means this pet just got bitten -> flinch it backward. flinchState holds the
    -- per-pet HitReact state; lastDmg tracks the previous damage to detect the rise.
    local flinchState = setmetatable({}, { __mode = "k" })
    local lastDmg = setmetatable({}, { __mode = "k" })

    -- Attack flourishes (layered like the gait): one per target type, resolved once.
    -- mining = breakables/ore (spin), combat = enemies (face for now). See AttackAnim.
    local animCfg = (config.attack and config.attack.anim) or {}
    local miningAnim = AttackAnim.resolve(animCfg.mining)
    local combatAnim = AttackAnim.resolve(animCfg.combat)

    -- Facing tuning: turn toward the heading when moving faster than this, else rest facing.
    local faceTurnRate = (config.movement and config.movement.face_turn_rate) or 12
    local faceMoveSpeed = (config.movement and config.movement.face_move_speed) or 2

    -- Attack VFX config (RangedFX). Firing is driven by the server's real hit (Combat_PetHit,
    -- handler below) — not a client timer — so the bolt/impact/sound/crit are the swing that
    -- actually landed. Clone + rebuild target_offset as a Vector3 (stored {x,y,z} so the config
    -- stays headless-requireable, where Vector3 doesn't exist).
    local boltCfg = table.clone(config.ranged_bolt or {})
    local castLockSeconds = boltCfg.cast_lock_seconds or 0
    if type(boltCfg.target_offset) == "table" then
        local o = boltCfg.target_offset
        boltCfg.target_offset = Vector3.new(o[1] or 0, o[2] or 0, o[3] or 0)
    end

    -- Combat-origin element (CombatOrigin). Each pet fights as its own biome element (interim:
    -- read from PetType via origin.pettype_element); origin.unify_to_player makes the whole squad
    -- fight as the player's archetype element instead. The element drives the projectile kind
    -- (origin.element_kind) and the per-biome melee/impact look (RangedFX melee_by_element).
    local originCfg = require(ReplicatedStorage.Configs:WaitForChild("combat_fx")).origin or {}
    local petTypeElement = originCfg.pettype_element or {}
    local elementKind = originCfg.element_kind or {}
    local function elementFor(pet)
        local pe = petTypeElement[pet:GetAttribute("PetType")]
        local archetype = localPlayer and localPlayer:GetAttribute("Archetype")
        return CombatOrigin.resolve(pe, archetype, originCfg)
    end

    -- Floating combat text (damage / crit / MISS numbers over the target). Config-driven.
    local ctCfg = config.combat_text or {}
    local function ctRGB(t, dr, dg, db)
        if type(t) == "table" and t[1] then
            return Color3.fromRGB(t[1], t[2] or 0, t[3] or 0)
        end
        return Color3.fromRGB(dr, dg, db)
    end

    -- Area power VFX (Cataclysm etc.): the server fires Power_AreaFx with the engagement centre +
    -- per-enemy hits. Play the element eruption + a lingering molten pool, then float each number.
    local areaCfg = require(ReplicatedStorage.Configs:WaitForChild("area_fx"))
    Signals.Power_AreaFx.OnClientEvent:Connect(function(data)
        if type(data) ~= "table" then
            return
        end
        -- Family-mapped power FX (PowerService:Cast): a registry primitive rendered on the local
        -- caster (source) or at an enemy (target), with (effect/sound TBD) placeholders.
        if data.primId then
            local opts = { primId = data.primId, element = data.element, kind = data.kind }
            if data.kind == "target" then
                opts.target = data.target
            else
                local char = Players.LocalPlayer.Character
                opts.caster = char and char:FindFirstChild("HumanoidRootPart")
            end
            pcall(PowerFXRender.play, opts)
            return
        end
        local center = data.center
        local element = data.element or "lava"
        if typeof(center) == "Vector3" then
            -- data.radius (AoE pets pass their splash_radius) sizes the effect to the real damage
            -- zone, so the fire circle lands exactly at the AoE edge — nil falls back to config.
            pcall(
                AreaFX.Play,
                areaCfg,
                element,
                data.variant or "targeted",
                center,
                center,
                nil,
                { radius = data.radius }
            )
            -- Reusable element-themed ground bloom at the strike (replaces the old lingering tar "pit"):
            -- a mechanically-instant BURST — motes pop, the rim ring expands, the disc flashes — sized
            -- to the real AoE radius. Drives BOTH pet-cast AoEs (variant "self") and targeted AoEs
            -- (Cataclysm/Colorado, variant "targeted"). The upfront eruption above stays as the strike.
            pcall(function()
                CombatFX.groundField({
                    element = element,
                    radius = tonumber(data.radius) or 12,
                    anchor = center,
                    duration = 0.9,
                    burst = true,
                })
            end)
            -- element SFX from the power_fx registry: self burst ⇒ cast clip, else ⇒ impact clip
            -- (silent if none authored for this element/phase).
            local phase = (data.variant == "self") and "cast" or "impact"
            -- Optional per-fire volume scale (the bear aura passes 0.5 because it re-fires each tick;
            -- nil ⇒ registry default). Applies to both the phase clip and the slam boom.
            local vol = tonumber(data.volume)
            pcall(PowerSound.play, phase, element, center, vol)
            -- the heavy "lands hard" boom under every AoE (slam.neutral ⇒ all elements get it).
            pcall(PowerSound.play, "slam", element, center, vol)
        end
        for _, h in ipairs(data.hits or {}) do
            if type(h) == "table" and typeof(h.pos) == "Vector3" and h.amount then
                FloatingText.show(h.pos + Vector3.new(0, 4, 0), tostring(h.amount), {
                    color = ctRGB(ctCfg.colors and ctCfg.colors.crit, 255, 150, 60),
                    size = (ctCfg.size or 22) + 4,
                })
            end
        end
    end)
    -- Mining impact FX (impact-library test bed + mining visual): each mined ore plays a named
    -- impact on a cadence. Keyed by the breakable model so multiple pets on one ore share a stream.
    local miningFx = config.mining_fx or {}
    local nextMineFx = setmetatable({}, { __mode = "k" }) -- breakable model -> next os.clock to fire

    -- Cast-lock: a ranged pet that just fired can't move until this clock — a melee enemy
    -- gets a window to close the gap (counterplay to kiting). Set when the pet's hit lands.
    local castLockUntil = setmetatable({}, { __mode = "k" })

    -- Server-driven attack visuals: the server fires Combat_PetHit on each real pet swing.
    -- Ranged pets (role.kite) launch their configured projectile/bolt at the target; everyone
    -- else plays a "melee" impact at the target. crit drives the bigger impact tier; the sound
    -- + impact ride the actual hit. Replaces the old client-side bolt timer.
    Signals.Combat_PetHit.OnClientEvent:Connect(function(data)
        if type(data) ~= "table" then
            return
        end
        local pet, target = data.pet, data.target
        if typeof(pet) ~= "Instance" or typeof(target) ~= "Instance" then
            return
        end
        if not pet.Parent or not target.Parent then
            return
        end
        local isCrit = data.crit == true
        local element = elementFor(pet)
        local ranged = roleKites(pet)
        -- ranged cast-lock is a PET-only counterplay (a pet that just fired can't move); not part
        -- of "how they attack", so it stays here rather than in the shared dispatcher.
        if ranged and castLockSeconds > 0 then
            castLockUntil[pet] = os.clock() + castLockSeconds
        end
        -- Same attack-FX path the enemies use (CombatHitFX): resolve the kind + fire it via RangedFX.
        -- ranged -> the per-pet by_type override or the biome element bolt; melee -> impact look.
        -- AoE SPLASH (data.splash): SKIP the per-target attack FX entirely — the fire-ring eruption
        -- (Power_AreaFx, fired once at the cluster) is the AoE animation; the splashed neighbor only
        -- floats its damage number below, no bolt/impact per target.
        if not data.splash then
            pcall(CombatHitFX.play, pet, target, {
                boltCfg = boltCfg,
                ranged = ranged,
                byType = pet:GetAttribute("PetType"),
                byTypeMap = boltCfg.by_type,
                element = element,
                elementKind = elementKind,
                defaultKind = boltCfg.kind or "lightning",
                crit = isCrit,
            })
        end

        -- CRIT ROAR: ANY pet's critical hit roars (Jason: a tank polar bear's crit must sound too),
        -- but the sound SPLITS by role to match the attack-VFX split: ranged -> the per-element crit
        -- BLAST (power_fx sounds.crit, e.g. ice = SuddenBlast); melee/tank/other -> the heavier
        -- CONCUSSION (sounds.crit_melee, neutral boom_swoosh for every element). Unauthored gaps stay
        -- silent. Positional at the target -> shared-world (every nearby client hears it).
        if isCrit then
            local okPos, pos = pcall(function()
                return target:GetPivot().Position
            end)
            if okPos and pos then
                pcall(PowerSound.play, ranged and "crit" or "crit_melee", element, pos)
            end
        end

        -- Floating combat text: the damage number (or MISS) pops + rises above the target.
        -- Renders for FOREIGN hits too (Jason: "this is supposed to be a team effect game"
        -- — shared world effects are fully shared, damage stream included; only private
        -- events like achievements/hatching stay owner-only).
        if ctCfg.enabled ~= false then
            local pos = (target.PrimaryPart and target.PrimaryPart.Position)
                or target:GetPivot().Position
            local up = 3
            local okE, ext = pcall(function()
                return target:GetExtentsSize()
            end)
            if okE and ext then
                up = ext.Y * 0.5 + 1
            end
            pos = pos + Vector3.new(0, up, 0)
            local cols = ctCfg.colors or {}
            if data.miss then
                FloatingText.show(pos, ctCfg.miss_text or "MISS", {
                    color = ctRGB(cols.miss, 170, 170, 170),
                    size = ctCfg.size or 22,
                    rise = ctCfg.rise,
                    duration = ctCfg.duration,
                })
            elseif isCrit then
                FloatingText.show(pos, tostring(data.amount or 0) .. "!", {
                    color = ctRGB(cols.crit, 255, 200, 60),
                    size = ctCfg.crit_size or 32,
                    rise = (ctCfg.rise or 6) + 2,
                    duration = (ctCfg.duration or 0.9) + 0.2,
                })
            else
                FloatingText.show(pos, tostring(data.amount or 0), {
                    color = ctRGB(cols.normal, 255, 255, 255),
                    size = ctCfg.size or 22,
                    rise = ctCfg.rise,
                    duration = ctCfg.duration,
                })
            end
        end
    end)

    -- Heal numbers: a green "+N" floats over a healed pet (support auto-heal / heal power, to
    -- the owner) or a healed enemy (enemy healer, broadcast — the "kill the healer" tell).
    Signals.Combat_Heal.OnClientEvent:Connect(function(data)
        if ctCfg.enabled == false or type(data) ~= "table" then
            return
        end
        local target = data.target
        if typeof(target) ~= "Instance" or not target.Parent then
            return
        end
        local pos = (target.PrimaryPart and target.PrimaryPart.Position)
            or (target:IsA("Model") and target:GetPivot().Position)
        if not pos then
            return
        end
        local up = 3
        local okE, ext = pcall(function()
            return target:GetExtentsSize()
        end)
        if okE and ext then
            up = ext.Y * 0.5 + 1
        end
        local cols = ctCfg.colors or {}
        FloatingText.show(pos + Vector3.new(0, up, 0), "+" .. tostring(data.amount or 0), {
            color = ctRGB(cols.heal, 90, 230, 110),
            size = ctCfg.size or 22,
            rise = ctCfg.rise,
            duration = ctCfg.duration,
        })
    end)

    -- OTHER players' pets, server-relayed (the server never relays our own — those stay local).
    local remoteTargets = setmetatable({}, { __mode = "k" }) -- pet model -> latest relayed CFrame
    Signals.PetPositionsRelay.OnClientEvent:Connect(function(list)
        if type(list) ~= "table" then
            return
        end
        for _, e in ipairs(list) do
            if type(e) == "table" and typeof(e.pet) == "Instance" and typeof(e.cf) == "CFrame" then
                remoteTargets[e.pet] = e.cf
            end
        end
    end)

    RunService.RenderStepped:Connect(function(dt)
        -- Smooth OTHER players' pets toward their relayed transforms (always, even if we have no
        -- pets of our own). Our own pets are handled below, purely locally.
        local remoteAlpha = 1 - math.exp(-(config.movement.remote_lerp_rate or 14) * dt)
        for pet, targetCf in pairs(remoteTargets) do
            if pet.Parent and pet:IsA("Model") and pet.PrimaryPart then
                pet:PivotTo(pet:GetPivot():Lerp(targetCf, remoteAlpha))
            else
                remoteTargets[pet] = nil
            end
        end

        local char = localPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local petsFolder = Workspace:FindFirstChild("PlayerPets")
            and Workspace.PlayerPets:FindFirstChild(localPlayer.Name)
        if not hrp or not petsFolder then
            return
        end

        -- Downed pets are OUT of the fight: hide them (client-only LocalTransparencyModifier
        -- so we never touch base Transparency) + any billboards, and skip positioning them.
        -- They reappear when the player summons them (server clears CombatDowned).
        local pets = {}
        for _, m in ipairs(petsFolder:GetChildren()) do
            if m:IsA("Model") and m.PrimaryPart then
                local downed = m:GetAttribute("CombatDowned")
                for _, d in ipairs(m:GetDescendants()) do
                    if d:IsA("BasePart") then
                        d.LocalTransparencyModifier = downed and 1 or 0
                    elseif d:IsA("BillboardGui") then
                        d.Enabled = not downed
                    end
                end
                if not downed then
                    table.insert(pets, m)
                else
                    -- Forget the cached transform while down (Jason's wandering-revive
                    -- saga): the client skips positioning downed pets, so the server's
                    -- revive teleport replicates cleanly — but resuming the lerp from
                    -- this stale cache rendered the pet back at its death spot. With
                    -- the cache cleared, revival reads the fresh (at-the-player) pivot.
                    baseCF[m] = nil
                end
            end
        end
        local count = #pets
        if count == 0 then
            return
        end

        local cf = hrp.CFrame
        local frame = {
            position = { x = cf.Position.X, y = cf.Position.Y, z = cf.Position.Z },
            look = { x = cf.LookVector.X, y = cf.LookVector.Y, z = cf.LookVector.Z },
            right = { x = cf.RightVector.X, y = cf.RightVector.Y, z = cf.RightVector.Z },
        }
        local phase = os.clock() - startClock
        local flat = Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z)
        local upFwd = flat.Magnitude > 0.01 and flat.Unit or Vector3.new(0, 0, -1)

        -- Player stillness clock (meander gate): any real movement resets it, so the
        -- squad snaps to formation while travelling and only wanders once you settle.
        if lastPlayerPos and (cf.Position - lastPlayerPos).Magnitude < 0.5 then
            playerStillFor += dt
        else
            playerStillFor = 0
        end
        lastPlayerPos = cf.Position
        local meanderActive = meanderCfg.enabled ~= false
            and playerStillFor >= (tonumber(meanderCfg.player_still_seconds) or 2)

        -- Idle stroll offset for an untargeted follower; everyone else glides home.
        local function meanderOffset(model, isIdle)
            local state = meanderStates[model]
            if not (isIdle and meanderActive) then
                if state then
                    PetMeander.reset(state, meanderCfg, math.random)
                end
                return 0, 0
            end
            if not state then
                state = PetMeander.newState(meanderCfg, math.random)
                meanderStates[model] = state
            end
            return PetMeander.step(state, dt, meanderCfg, math.random)
        end

        -- Frame-rate-independent smoothing (momentum feel), scaled per pet by move speed:
        -- the player's PetMoveSpeed stat times the pet's optional MoveSpeedMult. Higher = the
        -- pet catches its slot / repositions faster.
        local followRate = config.movement.follow_lerp_rate or 10
        local attackRate = config.movement.attack_lerp_rate or 16
        local speedCfg = config.movement.speed
        local maxTravel = config.movement.max_travel_speed
        local playerSpeed = localPlayer:GetAttribute("PetMoveSpeed")
        -- Swift (move_speed axis): the player's move-speed buff speeds the pets up too (+fraction).
        -- power (MoveSpeedBuff) + potion (MoveSpeedBuffPotion) ADD, each gated by its own Until.
        do
            local nowT = os.time()
            local moveFrac = 0
            if (localPlayer:GetAttribute("MoveSpeedBuffUntil") or 0) > nowT then
                moveFrac += localPlayer:GetAttribute("MoveSpeedBuff") or 0
            end
            if (localPlayer:GetAttribute("MoveSpeedBuffPotionUntil") or 0) > nowT then
                moveFrac += localPlayer:GetAttribute("MoveSpeedBuffPotion") or 0
            end
            if moveFrac ~= 0 then
                playerSpeed = (playerSpeed or 1) * (1 + moveFrac)
            end
        end

        -- Move a pet toward its goal at `baseRate` smoothing, scaled by its move-speed
        -- multiplier. Snap if catastrophically far (the player teleported). Otherwise
        -- smooth-lerp BUT cap the per-frame travel to max_travel_speed*mult so a pet
        -- flies over to a new target at a bounded speed instead of teleporting onto it
        -- (the exponential lerp alone covers any distance almost instantly). Orientation
        -- still uses the full lerp; only linear position is capped.
        local catchupDist = config.movement.catchup_distance

        -- Pick this frame's HEADING: face the way the pet is actually moving when it's
        -- travelling above face_move_speed (so it heads forward instead of sliding), else
        -- settle onto restDir (player-forward following / the target when attacking). The
        -- turn is eased so it never snaps. Returns a horizontal unit Vector3.
        local function facingFor(cur, curPos, newPos, restDir)
            local moveVec = Vector3.new(newPos.X - curPos.X, 0, newPos.Z - curPos.Z)
            local speed = moveVec.Magnitude / math.max(dt, 1e-3)
            local desired
            if speed > faceMoveSpeed and moveVec.Magnitude > 1e-4 then
                desired = moveVec.Unit
            elseif restDir and restDir.Magnitude > 1e-4 then
                desired = restDir.Unit
            end
            local curLook = Vector3.new(cur.LookVector.X, 0, cur.LookVector.Z)
            curLook = (curLook.Magnitude > 1e-4) and curLook.Unit or upFwd
            if not desired then
                return curLook
            end
            local turnAlpha = 1 - math.exp(-faceTurnRate * dt)
            local newLook = curLook:Lerp(desired, turnAlpha)
            return (newLook.Magnitude > 1e-4) and newLook.Unit or desired
        end

        -- Store the clean (gait-free, anim-free) pivot, then PivotTo with the walk gait AND
        -- any attack flourish layered on. Keeping baseCF clean means neither feeds back into
        -- the lerp or the position report. `anim` is a resolved AttackAnim (or nil to follow).
        local function applyMotion(model, cleanPivot, stepDist, anim)
            baseCF[model] = cleanPivot
            local st = gaitState[model]
            if not st then
                st = { phase = 0, amp = 0 }
                gaitState[model] = st
            end
            local gait = resolveGait(model:GetAttribute("PetType"))
            local bob, roll, yaw = Gait.advance(st, gait, stepDist, dt)

            -- Attack flourish (spin / pounce). Resets its clock when the pet stops attacking.
            local aYaw, aLunge, aBob = 0, 0, 0
            if anim and anim.enabled then
                local ts = attackTimer[model]
                if not ts then
                    ts = { t = 0 }
                    attackTimer[model] = ts
                end
                aYaw, aLunge, aBob = AttackAnim.advance(ts, anim, dt)
            else
                attackTimer[model] = nil
            end

            local pivot = cleanPivot
            if aLunge ~= 0 then
                pivot = cleanPivot * CFrame.new(0, 0, -aLunge) -- jab forward toward the faced target
            end

            -- Hit-react: a rise in CombatDamageTaken = this pet was just bitten. Flinch it
            -- backward (recoil along -look) + a twist; decays to 0 so it never sticks.
            local dmg = tonumber(model:GetAttribute("CombatDamageTaken")) or 0
            local prev = lastDmg[model]
            if prev and dmg > prev then
                local fs = flinchState[model]
                if not fs then
                    fs = {}
                    flinchState[model] = fs
                end
                local lv = cleanPivot.LookVector
                HitReact.start(fs, os.clock(), -lv.X, -lv.Z, math.random() < 0.5 and 1 or -1)
            end
            lastDmg[model] = dmg

            local cf = CFrame.new(0, bob + aBob, 0) * pivot * CFrame.Angles(0, yaw + aYaw, roll)
            local fs = flinchState[model]
            if fs then
                local fx, fz, fyaw = HitReact.sample(fs, os.clock())
                if fx ~= 0 or fz ~= 0 or fyaw ~= 0 then
                    cf = (cf + Vector3.new(fx, 0, fz)) * CFrame.Angles(0, fyaw, 0)
                end
            end
            model:PivotTo(cf)
        end

        -- Move a pet toward goalPos (Vector3), facing its heading while moving / restDir at
        -- rest, at baseRate smoothing scaled by move speed. `anim` (optional) layers a flourish.
        local function moveToward(model, goalPos, restDir, baseRate, anim)
            -- Cast-locked (just-fired ranged pet): hold position so it can't kite freely, but
            -- keep facing its target (restDir) so it still aims at its prey while "casting".
            if castLockUntil[model] and dt and os.clock() < castLockUntil[model] then
                local cur = baseCF[model] or model:GetPivot()
                local face = facingFor(cur, cur.Position, cur.Position, restDir)
                applyMotion(model, CFrame.lookAt(cur.Position, cur.Position + face), 0, anim)
                return
            end
            local mult = PetFormation.moveSpeedMultiplier(
                playerSpeed,
                model:GetAttribute("MoveSpeedMult"),
                speedCfg
            )
            local cur = baseCF[model] or model:GetPivot()
            local curPos = cur.Position
            if PetFormation.shouldSnap((curPos - goalPos).Magnitude, catchupDist) then
                local face = (restDir and restDir.Magnitude > 1e-4) and restDir.Unit or upFwd
                applyMotion(model, CFrame.lookAt(goalPos, goalPos + face), 0, anim) -- teleport
                return
            end
            local alpha = 1 - math.exp(-(baseRate * mult) * dt)
            local newPos = curPos:Lerp(goalPos, alpha)
            if maxTravel and maxTravel > 0 then
                local step = newPos - curPos
                local maxStep = maxTravel * mult * dt
                if step.Magnitude > maxStep then
                    newPos = curPos + step.Unit * maxStep
                end
            end
            local face = facingFor(cur, curPos, newPos, restDir)
            local cleanPivot = CFrame.lookAt(newPos, newPos + face)
            local stepDist = (Vector3.new(newPos.X, 0, newPos.Z) - Vector3.new(
                curPos.X,
                0,
                curPos.Z
            )).Magnitude
            applyMotion(model, cleanPivot, stepDist, anim)
        end

        -- Full attack config (so every style's params reach attackOffset). The per-pet STYLE is
        -- resolved in the group loop below (role-driven in "individual" mode, shared in "team");
        -- a PetAttackStyle attribute still force-overrides the whole squad for live testing.
        local attackCfg = table.clone(config.attack)
        local styleOverride = localPlayer:GetAttribute("PetAttackStyle")

        local groups = {} -- id -> { center, pets = {} }   (melee/tank: orbit the target)
        local followers = {}
        local followPlace = {} -- resolved follower placements (separated before moving)
        local kiterFace = {} -- kiter pet -> its target model (so it faces what it snipes)
        for slot, pet in ipairs(pets) do
            local tid = pet:FindFirstChild("TargetID")
            local breakable = nil
            if tid and tid.Value ~= 0 then
                local tt = pet:FindFirstChild("TargetType")
                local tw = pet:FindFirstChild("TargetWorld")
                breakable = findBreakable(tt and tt.Value, tw and tw.Value, tid.Value)
            end
            local posNV = pet:FindFirstChild("PositionNumber")
            local index = (posNV and posNV.Value > 0) and posNV.Value or slot
            -- A kiter snipes from the player formation ONLY while its target is within range of
            -- the formation; if the target is farther than attack_range it advances to engage
            -- (joins the attack group, holding at its standoff). Decision is target-vs-formation
            -- (stable) so it doesn't flip-flop as the pet moves.
            local kiteSnipe = false
            if breakable and roleKites(pet) then
                local c = breakable:GetPivot().Position
                local petPos = pet:GetPivot().Position
                -- Snipe-in-place ONLY if the pet's formation SLOT would actually be within attack
                -- range of the target — otherwise advance to a forward standoff and fire from there.
                -- The old check measured PLAYER->target minus a fixed 8-stud fudge, but a kiter's slot
                -- sits ~10-15 studs BEHIND the player; when the player stood ~20 out from a target the
                -- pet "sniped" from ~33 (outside its 28 range) and froze forever (Jason's gold dragon
                -- "stays at my shoulder, never fires"). Estimate the slot as player->target plus the
                -- pet's own current distance-behind-the-player (its formation depth); the triangle-
                -- inequality over-estimate errs toward ADVANCING, which is what we want for engaging.
                -- As the pet advances forward its depth grows, so it stays in advance mode (no flip-
                -- flop) and holds at the attack-group standoff, which is inside range.
                local playerToTarget =
                    Vector3.new(cf.Position.X - c.X, 0, cf.Position.Z - c.Z).Magnitude
                local formationDepth =
                    Vector3.new(petPos.X - cf.Position.X, 0, petPos.Z - cf.Position.Z).Magnitude
                kiteSnipe = (playerToTarget + formationDepth) <= attackRangeOf(pet)
            end
            if kiteSnipe then
                -- Ranged in range: hold the player formation and fire, facing the target.
                table.insert(followers, { pet = pet, index = index })
                kiterFace[pet] = breakable
            elseif breakable then
                local g = groups[tid.Value]
                if not g then
                    g = {
                        center = breakable:GetPivot().Position,
                        model = breakable,
                        isEnemy = breakable:GetAttribute("IsEnemy") == true,
                        pets = {},
                    }
                    groups[tid.Value] = g
                end
                table.insert(g.pets, pet)
            else
                table.insert(followers, { pet = pet, index = index })
            end
        end

        -- A follower's rest facing: player-forward, unless it's a ranged kiter — then it
        -- faces the target it's firing on (computed per pet from its world position).
        local function followerRestDir(pet, targetPos)
            local kt = kiterFace[pet]
            if kt and kt.Parent and kt.PrimaryPart then
                local p = kt:GetPivot().Position
                local d = Vector3.new(p.X - targetPos.X, 0, p.Z - targetPos.Z)
                if d.Magnitude > 1e-3 then
                    return d.Unit
                end
            end
            return upFwd
        end

        -- Followers: hold the formation slot behind the player.
        -- Mode comes from the player's saved setting (PetFormationMode attribute, stage 3) or the
        -- config default. The size-aware modes sort by footprint + scale spacing via resolve();
        -- anything else falls back to the legacy index-based path.
        local mode = localPlayer:GetAttribute("PetFormationMode") or config.formation.default_mode
        local sizeAware = mode == "conga" or mode == "risers" or mode == "arc"

        if sizeAware and #followers > 0 then
            -- Stable input order by equip slot so equal-size pets keep a deterministic order.
            table.sort(followers, function(lhs, rhs)
                return lhs.index < rhs.index
            end)
            local input = {}
            for _, f in ipairs(followers) do
                input[#input + 1] = { model = f.pet, footprint = petFootprint(f.pet, config) }
            end
            local fm = table.clone(config.formation)
            fm.mode = mode
            local placed = PetFormation.resolve(input, fm)
            for slot, e in ipairs(placed) do
                local model = e.pet.model
                local t = PetFormation.toWorld(frame, e.offset)
                local bob = PetFormation.floatOffset(phase + slot, config.float)
                local mx, mz = meanderOffset(model, kiterFace[model] == nil)
                followPlace[#followPlace + 1] = {
                    model = model,
                    target = Vector3.new(
                        t.x + mx,
                        t.y + bob + floatTouchup(model, config),
                        t.z + mz
                    ),
                }
            end
        else
            for _, f in ipairs(followers) do
                local t = PetFormation.targetPosition(frame, f.index, count, config.formation)
                local bob = PetFormation.floatOffset(phase + f.index, config.float)
                local mx, mz = meanderOffset(f.pet, kiterFace[f.pet] == nil)
                followPlace[#followPlace + 1] = {
                    model = f.pet,
                    target = Vector3.new(
                        t.x + mx,
                        t.y + bob + floatTouchup(f.pet, config),
                        t.z + mz
                    ),
                }
            end
        end

        -- Soft separation (no collisions): overlapping TARGETS get pushed apart and
        -- the regular moveToward smoothing walks the pets off each other.
        local sepDist = tonumber(meanderCfg.separation) or 0
        if sepDist > 0 and #followPlace > 1 then
            local pts = {}
            for i, p in ipairs(followPlace) do
                pts[i] = { x = p.target.X, z = p.target.Z }
            end
            local push = PetMeander.separate(pts, sepDist)
            for i, p in ipairs(followPlace) do
                p.target = p.target + Vector3.new(push[i].x, 0, push[i].z)
            end
        end
        for _, p in ipairs(followPlace) do
            moveToward(p.model, p.target, followerRestDir(p.model, p.target), followRate)
        end

        -- Map-collision exclude set (built once/frame): everything dynamic the pet should pass
        -- through — Workspace.Game (crystals/enemies/drops), all players' pets, and characters —
        -- so slotBlocked() only ever flags authored MAP walls/rocks.
        local mapExclude = {}
        local gameFolder = Workspace:FindFirstChild("Game")
        if gameFolder then
            mapExclude[#mapExclude + 1] = gameFolder
        end
        local petsRoot = Workspace:FindFirstChild("PlayerPets")
        if petsRoot then
            mapExclude[#mapExclude + 1] = petsRoot
        end
        for _, pl in ipairs(Players:GetPlayers()) do
            if pl.Character then
                mapExclude[#mapExclude + 1] = pl.Character
            end
        end

        -- Attackers: arrange around the target per the attack style, facing the center.
        for _, g in pairs(groups) do
            -- Combat (enemy) rings: ROLE first so the tank owns slot-0 (the peel anchor) regardless
            -- of size — otherwise a huge tank size-sorts to a far slot and draws the enemy toward you.
            -- Mining rings: smallest -> first slot, so huge pets take the outer slots (spiral arm /
            -- line ends). Either way, tiebreak by equip slot so identical pets keep a fixed order
            -- (no frame-to-frame swap), which is also how multiple same-role tanks order.
            table.sort(g.pets, function(p1, p2)
                if g.isEnemy then
                    local r1, r2 = combatSlotPriority(p1), combatSlotPriority(p2)
                    if r1 ~= r2 then
                        return r1 < r2
                    end
                end
                local f1, f2 = petFootprint(p1, config), petFootprint(p2, config)
                if f1 ~= f2 then
                    return f1 < f2
                end
                return petSlot(p1) < petSlot(p2)
            end)
            local gcount = #g.pets
            for gi, pet in ipairs(g.pets) do
                -- per-pet style: role-driven in "individual" mode, team-shared otherwise (g.isEnemy
                -- picks the combat vs mining mode lane). Mutating .style is cheap — no per-frame alloc.
                attackCfg.style = PetFormation.resolveStyle(
                    config.attack,
                    petRoleId(pet),
                    g.isEnemy,
                    styleOverride
                )
                local off = PetFormation.attackOffset(gi, gcount, phase, attackCfg)
                -- Role standoff: ranged/support hold further out (push the slot radially
                -- away from the target) so melee crowds in and ranged kites at distance.
                local standoff = roleStandoff(pet)
                if standoff > 0 then
                    local horiz = Vector3.new(off.x, 0, off.z)
                    if horiz.Magnitude > 0.01 then
                        local pushed = horiz + horiz.Unit * standoff
                        off = { x = pushed.X, y = off.y, z = pushed.Z }
                    end
                end
                -- Orient the attack ring toward the PLAYER (combat). The wheel's angle-0 is world
                -- +x, so a lone attacker always sat on the +x side of its target → the enemy chased
                -- it that way and the pair walked the same compass direction off the map no matter
                -- where it spawned. Rotating the offset so angle-0 points target->player makes pets
                -- engage from YOUR side and draws enemies back toward you (the on-map anchor).
                if g.isEnemy then
                    local toP =
                        Vector3.new(cf.Position.X - g.center.X, 0, cf.Position.Z - g.center.Z)
                    if toP.Magnitude > 0.01 then
                        local a = math.atan2(toP.Z, toP.X)
                        -- Flip the pole if configured: "away_from_player" points angle-0 AWAY from
                        -- you, so pets take the far side and DRAW enemies toward you (vs the default
                        -- "toward_player", which peels/shoves them away). See pet_follow.lua.
                        if config.attack.combat_ring_zero == "away_from_player" then
                            a = a + math.pi
                        end
                        local ca, sa = math.cos(a), math.sin(a)
                        off =
                            { x = off.x * ca - off.z * sa, y = off.y, z = off.x * sa + off.z * ca }
                    end
                end
                local target = g.center + Vector3.new(off.x, off.y, off.z)
                -- Map clamp: the standoff slot can land inside authored geometry (a rock/cliff the
                -- foe hovers against, a cactus). Do NOT freeze the pet at its current spot — that
                -- strands the whole squad whenever an enemy sits near terrain (combat just stops,
                -- the exact "pets do nothing" bug). Pets don't collide, so instead walk the goal
                -- back along pet->target to the nearest CLEAR point: the pet still advances as far
                -- as it can and gets into range. Only if the entire approach is blocked do we hold.
                if g.isEnemy and slotBlocked(target, mapExclude) then
                    local from = (baseCF[pet] and baseCF[pet].Position) or pet:GetPivot().Position
                    local cleared
                    for step = 1, 6 do
                        local probe = target:Lerp(from, step / 7) -- from the goal back toward the pet
                        if not slotBlocked(probe, mapExclude) then
                            cleared = probe
                            break
                        end
                    end
                    target = cleared or from
                end
                local toC = Vector3.new(g.center.X - target.X, 0, g.center.Z - target.Z)
                local dir = toC.Magnitude > 0.01 and toC.Unit or upFwd
                -- Mining (breakables) spins; combat (enemies) faces the target. The flourish
                -- layers on the facing — a spinning pet still orients to its prey underneath.
                local anim = g.isEnemy and combatAnim or miningAnim
                moveToward(pet, target, dir, attackRate, anim)
            end

            -- Mining impact FX: play a library impact at the ore on cadence (test bed + visual).
            if miningFx.enabled and not g.isEnemy and g.model and g.model.Parent then
                local nowC = os.clock()
                if not nextMineFx[g.model] or nowC >= nextMineFx[g.model] then
                    nextMineFx[g.model] = nowC + (miningFx.interval or 0.7)
                    local cols = miningFx.colors or {}
                    RangedFX.playImpact(
                        miningFx.impact or "small",
                        g.center + Vector3.new(0, 1, 0),
                        cols[1] or { 255, 150, 40 },
                        cols[2] or cols[1] or { 255, 90, 20 },
                        { scale = miningFx.scale, sparks = miningFx.sparks }
                    )
                end
            end
        end

        -- (Attack visuals are no longer fired on a client timer here — they're driven by the
        --  server's real hit via Combat_PetHit, connected once below in start().)

        -- Throttled: report this player's pet positions to the server (drives the mining gate;
        -- foundation for multiplayer pet visibility). Positions are post-move (this frame).
        -- prune meander states for despawned pets (recall/down/re-team)
        for model in pairs(meanderStates) do
            if not model.Parent then
                meanderStates[model] = nil
            end
        end

        reportAccum += dt
        if reportAccum >= reportInterval then
            reportAccum = 0
            local report = {}
            for _, m in ipairs(pets) do
                -- Report the clean base (no gait bob/tilt) so the server mining gate
                -- measures true position, not the cosmetic waddle offset.
                report[#report + 1] = { pet = m, cf = baseCF[m] or m:GetPivot() }
            end
            Signals.PetReportPositions:FireServer(report)
        end
    end)
end

return PetFollowController
