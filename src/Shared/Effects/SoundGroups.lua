--[[
    SoundGroups — named volume buses so the Settings panel can actually control audio.

    Roblox routes a Sound's loudness through its SoundGroup: effective volume = Sound.Volume *
    SoundGroup.Volume * SoundService.MasterVolume. Before this module, game sounds were parented
    straight to SoundService with no group, so the "Effects Volume" / "Music Volume" sliders had
    nothing to turn — they were stubs. Now every sound is tagged into one of three buses and the
    sliders set that bus's Volume (0 = silence, 1 = unchanged).

    Buses:
      "effects" — combat/mining/power VFX + egg-hatch sounds (RangedFX, EnchantLightning, hatch)
      "music"   — background music (no sources yet; the control is wired and ready)
      "ui"      — button clicks / panel open-close (Button, MenuManager)

    Groups are created lazily under SoundService at Volume = 1 (so the default is "no change" —
    routing a sound never makes it quieter on its own). Safe on client and server; harmless if a
    sound is server-side. Idempotent: re-uses an existing group of the same name.
]]

local SoundService = game:GetService("SoundService")

local SoundGroups = {}

-- bus key -> SoundGroup instance name under SoundService
local GROUP_NAMES = {
    effects = "Effects",
    music = "Music",
    ui = "UI",
}

local DEFAULT_VOLUME = 1

local function ensure(name)
    local existing = SoundService:FindFirstChild(name)
    if existing and existing:IsA("SoundGroup") then
        return existing
    end
    local group = Instance.new("SoundGroup")
    group.Name = name
    group.Volume = DEFAULT_VOLUME
    group.Parent = SoundService
    return group
end

-- Resolve (creating if needed) the SoundGroup for a bus key; unknown keys fall back to effects.
function SoundGroups.get(which)
    return ensure(GROUP_NAMES[which] or GROUP_NAMES.effects)
end

-- Tag a Sound into a bus. No-op for non-Sound inputs so call sites can stay terse.
function SoundGroups.assign(sound, which)
    if typeof(sound) == "Instance" and sound:IsA("Sound") then
        sound.SoundGroup = SoundGroups.get(which)
    end
    return sound
end

-- Set a bus volume (the slider/toggle hook). Clamped to [0, 1]; 0 silences the whole bus.
function SoundGroups.setVolume(which, volume)
    SoundGroups.get(which).Volume = math.clamp(tonumber(volume) or DEFAULT_VOLUME, 0, 1)
end

return SoundGroups
