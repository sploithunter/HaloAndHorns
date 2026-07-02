--[[
    PetAnimState — pure locomotion-state resolver for rigged (skeletal) pets.

    Maps a pet's horizontal speed to "idle" | "walk" | "run" with hysteresis: a state's exit
    threshold sits below its enter threshold (enter × cfg.hysteresis) so a pet hovering at a
    boundary never flickers between clips. The meander stroll reads as a WALK; formation
    chasing reads as a RUN. Consumed by PetAnimator (client) each frame; knobs in
    configs/animations.lua `locomotion`.
]]

local PetAnimState = {}

--- prev: "idle" | "walk" | "run" (nil treated as "idle"); speed: studs/sec; cfg: locomotion.
function PetAnimState.resolve(prev, speed, cfg)
    cfg = cfg or {}
    local walkAt = tonumber(cfg.walk_speed) or 1.0
    local runAt = tonumber(cfg.run_speed) or 8.0
    local h = tonumber(cfg.hysteresis) or 0.7
    speed = tonumber(speed) or 0

    -- a state is KEPT until speed leaves its band by the hysteresis margin
    local exitRun = runAt * h
    local exitWalk = walkAt * h

    if prev == "run" then
        if speed >= exitRun then
            return "run"
        end
        return speed >= exitWalk and "walk" or "idle"
    end
    if prev == "walk" then
        if speed >= runAt then
            return "run"
        end
        return speed >= exitWalk and "walk" or "idle"
    end
    -- idle (or unknown)
    if speed >= runAt then
        return "run"
    end
    return speed >= walkAt and "walk" or "idle"
end

--- Stable pool pick: a clip entry may be one id or a POOL of ids; each pet picks one,
--- deterministically from its seed string, so a squad varies but no pet ever re-rolls.
--- Accepts a string (returned as-is), a non-empty array, or nil.
function PetAnimState.pick(entry, seed)
    if type(entry) == "string" then
        return entry
    end
    if type(entry) ~= "table" or #entry == 0 then
        return nil
    end
    local hash = 5381
    for i = 1, #tostring(seed or "") do
        hash = (hash * 33 + string.byte(seed, i)) % 2147483647
    end
    return entry[(hash % #entry) + 1]
end

return PetAnimState
