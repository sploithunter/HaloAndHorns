-- Pure preference normalization, shared by the client mixer and profile writer.
local VoiceVolume = {}

function VoiceVolume.level(value, config)
    local level = tonumber(value)
    if not level or level ~= level or math.abs(level) == math.huge then
        level = config.default_level
    end
    return math.clamp(level, config.min_level, config.max_level)
end

function VoiceVolume.gain(value, config)
    local level = VoiceVolume.level(value, config)
    local fraction = (level - config.min_level) / (config.max_level - config.min_level)
    return config.maximum_gain * fraction ^ config.curve_exponent
end

return VoiceVolume
