--[[
    SoundGroups — named volume buses so the Settings panel can actually control audio.

    Roblox routes a Sound's loudness through its SoundGroup: effective volume = Sound.Volume *
    SoundGroup.Volume * SoundService.MasterVolume. Before this module, game sounds were parented
    straight to SoundService with no group, so the "Effects Volume" / "Music Volume" sliders had
    nothing to turn — they were stubs. Now every sound is tagged into one of four buses and the
    sliders set that bus's Volume (0 = silence, 1 = unchanged).

    Buses:
      "effects" — combat/mining/power VFX + egg-hatch sounds (RangedFX, EnchantLightning, hatch)
      "music"   — background music (no sources yet; the control is wired and ready)
      "ui"      — button clicks / panel open-close (Button, MenuManager)
      "voices"  — spoken dialogue; a dedicated preference can amplify up to the configured limit

    Groups are created lazily under SoundService at Volume = 1 (so the default is "no change" —
    routing a sound never makes it quieter on its own). Safe on client and server; harmless if a
    sound is server-side. Idempotent: re-uses an existing group of the same name.
]]

local SoundService = game:GetService("SoundService")

local SoundGroups = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ConfigLoader = require(ReplicatedStorage.Shared.ConfigLoader)
local busConfig = ConfigLoader:LoadConfig("audio").buses

local function ensure(config)
    local name = config.name
    local existing = SoundService:FindFirstChild(name)
    if existing and existing:IsA("SoundGroup") then
        return existing
    end
    local group = Instance.new("SoundGroup")
    group.Name = name
    group.Volume = config.default_volume
    group.Parent = SoundService
    return group
end

-- Resolve (creating if needed) the SoundGroup for a bus key; unknown keys fall back to effects.
function SoundGroups.get(which)
    return ensure(busConfig[which] or busConfig.effects)
end

-- Tag a Sound into a bus. No-op for non-Sound inputs so call sites can stay terse.
function SoundGroups.assign(sound, which)
    if typeof(sound) == "Instance" and sound:IsA("Sound") then
        sound.SoundGroup = SoundGroups.get(which)
    end
    return sound
end

-- Set a bus volume within its configured limit; voices may amplify, other buses stay at unity.
function SoundGroups.setVolume(which, volume)
    local config = busConfig[which] or busConfig.effects
    local value = tonumber(volume)
    if not value or value ~= value or math.abs(value) == math.huge then
        value = config.default_volume
    end
    SoundGroups.get(which).Volume = math.clamp(value, 0, config.maximum_volume)
end

return SoundGroups
