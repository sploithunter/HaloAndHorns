--!strict

-- Pure motion math for the five-bone banner chain. The runtime owns Bone.Transform; this module
-- only supplies bounded, deterministic samples so it stays headless-testable.

local AchievementBannerMotion = {}

function AchievementBannerMotion.phase(x: number, z: number): number
    local seed = math.sin(x * 12.9898 + z * 78.233) * 43758.5453
    return (seed - math.floor(seed)) * math.pi * 2
end

function AchievementBannerMotion.sample(
    now: number,
    phase: number,
    boneIndex: number,
    motion: any
): { pitch: number, yaw: number, roll: number }
    local amplitudes = motion.amplitudes_degrees
    assert(type(amplitudes) == "table", "motion.amplitudes_degrees is required")
    local degrees = amplitudes[boneIndex]
    assert(type(degrees) == "number", "missing amplitude for banner bone")
    local amplitude = math.rad(degrees)
    local carrier = now * motion.speed + phase + (boneIndex - 1) * motion.phase_step
    return {
        pitch = math.sin(carrier * 0.81 + 0.4) * amplitude * motion.pitch_ratio,
        yaw = math.sin(carrier * 0.57 - 0.8) * amplitude * motion.yaw_ratio,
        roll = math.sin(carrier) * amplitude * motion.roll_ratio,
    }
end

function AchievementBannerMotion.radius(motion: any): number
    return motion.radius
end

return AchievementBannerMotion
