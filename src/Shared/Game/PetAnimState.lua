--[[
    PetAnimState — pure locomotion-state resolver for rigged (skeletal) pets.

    Maps a pet's horizontal speed to "idle" | "run" with hysteresis: the run threshold and the
    idle threshold differ so a pet hovering at one speed never flickers between clips.
    Consumed by PetAnimator (client) each frame; knobs in configs/animations.lua `locomotion`.
]]

local PetAnimState = {}

--- prev: "idle" | "run" (nil treated as "idle"); speed: studs/sec (>=0); cfg: locomotion knobs.
function PetAnimState.resolve(prev, speed, cfg)
    cfg = cfg or {}
    local runAt = tonumber(cfg.run_speed) or 2.0
    local idleAt = tonumber(cfg.idle_speed) or 0.8
    speed = tonumber(speed) or 0

    if prev == "run" then
        -- keep running until we drop below the LOWER threshold
        if speed < idleAt then
            return "idle"
        end
        return "run"
    end
    -- idle (or unknown) until we exceed the UPPER threshold
    if speed > runAt then
        return "run"
    end
    return "idle"
end

return PetAnimState
