--[[
    PetAnimator — client-side skeletal animation for rigged pets (RigClass attribute).

    Each client animates every rigged pet it can see (own squad AND other players' pets):
    Animator playback is purely visual and never replicates, so every observer runs its own
    tracks locally — same philosophy as the shared combat FX. Movement/damage stay exactly
    where they were (PetFollowController pivots, server authority).

    Driven by PetFollowController: `update(model, speed)` each frame (idle/run via the pure
    PetAnimState hysteresis) and `punch(model)` on each REAL server swing (Combat_PetHit).
    Clips per rig class live in configs/animations.lua.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PetAnimState = require(ReplicatedStorage.Shared.Game.PetAnimState)

local PetAnimator = {}

local config -- configs/animations.lua (lazy)
local petRoles -- configs/pet_roles.lua (lazy; same resolution as PetFollowController)
local rigs = setmetatable({}, { __mode = "k" }) -- model -> { tracks, state, failed }

local function getConfig()
    if not config then
        config = require(ReplicatedStorage.Configs:WaitForChild("animations"))
    end
    return config
end

function PetAnimator.isRigged(model)
    return model and model:GetAttribute("RigClass") ~= nil
end

-- The pet's combat role: PetRole attr -> pet_roles.by_type[PetType] -> default.
local function roleOf(model)
    if not petRoles then
        petRoles = require(ReplicatedStorage.Configs:WaitForChild("pet_roles"))
    end
    return model:GetAttribute("PetRole")
        or (petRoles.by_type and petRoles.by_type[model:GetAttribute("PetType")])
        or petRoles.default
end

-- Stable per-pet seed for pool picks: lockout identity (uid for specials, id:variant for
-- stacks) + the equip slot, so two identical commons in one squad can differ but a given
-- pet keeps its clips for the life of the model.
local function seedOf(model)
    local base = model:GetAttribute("LockoutUid") or model:GetAttribute("LockoutKey") or model.Name
    local slot = model:FindFirstChild("PositionNumber")
    return tostring(base) .. "#" .. tostring(slot and slot.Value or 0)
end

-- A clip entry is one id, a pool, or (attack only) a role map of ids/pools. Resolve to the
-- one id THIS pet plays.
local function resolveClip(entry, role, seed)
    if type(entry) == "table" and #entry == 0 then
        -- role map (no array part): the pet's lane, falling back to `default`
        entry = entry[role] or entry.default
    end
    return PetAnimState.pick(entry, seed)
end

local function ensure(model)
    local rig = rigs[model]
    if rig then
        return not rig.failed and rig or nil
    end
    local cfg = getConfig()
    local clips = cfg.rig_classes and cfg.rig_classes[model:GetAttribute("RigClass")]
    local controller = model:FindFirstChildWhichIsA("AnimationController", true)
    if not clips or not controller then
        rigs[model] = { failed = true }
        return nil
    end
    local animator = controller:FindFirstChildWhichIsA("Animator")
    if not animator then
        animator = Instance.new("Animator")
        animator.Parent = controller
    end
    local role = roleOf(model)
    local seed = seedOf(model)
    local knobs = cfg.class_knobs and cfg.class_knobs[model:GetAttribute("RigClass")] or {}
    -- per-pet substitutions (configs/animations.lua clip_overrides) win over
    -- the class pool pick — for rigs a specific pool clip misbehaves on.
    local overrides = cfg.clip_overrides
        and cfg.clip_overrides[tostring(model:GetAttribute("PetType"))]
    rig = { tracks = {}, state = nil, runSpeedMult = tonumber(knobs.run_speed_mult) }
    for name, entry in pairs(clips) do
        local id = resolveClip(overrides and overrides[name] or entry, role, seed)
        if type(id) == "string" then
            local anim = Instance.new("Animation")
            anim.AnimationId = id
            local ok, track = pcall(animator.LoadAnimation, animator, anim)
            if ok then
                rig.tracks[name] = track
            end
        end
    end
    rigs[model] = rig
    return rig
end

--- Per-frame locomotion: speed in studs/sec (horizontal). Crossfades idle<->run.
function PetAnimator.update(model, speed)
    local rig = ensure(model)
    if not rig then
        return
    end
    local cfg = getConfig()
    local loco = cfg.locomotion or {}
    local nextState = PetAnimState.resolve(rig.state, speed, loco)
    if nextState == rig.state then
        return
    end
    local fade = tonumber(loco.fade) or 0.2
    local prevTrack = rig.state and rig.tracks[rig.state]
    if prevTrack then
        prevTrack:Stop(fade)
    end
    local track = rig.tracks[nextState]
    if track then
        track.Looped = true
        track:Play(fade)
        -- classes without a real run clip reuse the walk clip at run tempo (class_knobs)
        if nextState == "run" and rig.runSpeedMult then
            track:AdjustSpeed(rig.runSpeedMult)
        end
    end
    rig.state = nextState
end

--- One-shot attack swing, layered over locomotion. Called per real server hit.
function PetAnimator.punch(model)
    local rig = ensure(model)
    if not rig then
        return
    end
    local track = rig.tracks.attack
    if not track then
        return
    end
    local atk = getConfig().attack or {}
    track.Looped = false
    track.Priority = Enum.AnimationPriority.Action
    if track.IsPlaying then
        track:Stop(0)
    end
    track:Play(tonumber(atk.fade) or 0.1, 1, tonumber(atk.speed) or 1)
end

return PetAnimator
