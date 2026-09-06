-- Temporary, local background attenuation. Never changes saved settings or bus Volume.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local SoundGroups = require(ReplicatedStorage.Shared.Effects.SoundGroups)
local Director = require(ReplicatedStorage.Shared.Game.MergeWatcherDirector)

local Mixer = {}
Mixer.__index = Mixer

function Mixer.new(config)
    local sourceBus = SoundGroups.get(config.bus)
    local group = SoundService:FindFirstChild(config.group_name)
    if not group then
        group = Instance.new("SoundGroup")
        group.Name = config.group_name
        group.Parent = SoundService
    end
    -- Mirror the user's ordinary Effects/master preference, but not its ducking effect.
    group.Volume = sourceBus.Volume
    sourceBus:GetPropertyChangedSignal("Volume"):Connect(function()
        group.Volume = sourceBus.Volume
    end)
    return setmetatable(
        { config = config, group = group, amount = 0, speaking = false, effects = {} },
        Mixer
    )
end

function Mixer:setSpeaking(speaking)
    self.speaking = speaking == true
end

function Mixer:step(dt)
    local speaking = self.speaking and self.group.Volume > 0
    local amount = Director.duckAmount(self.amount, speaking, dt, self.config.ducking)
    if amount == self.amount then
        return
    end
    self.amount = amount
    for bus, gain in pairs(self.config.ducking.gains_db) do
        local effect = self.effects[bus]
        if amount == 0 then
            if effect then
                effect:Destroy()
                self.effects[bus] = nil
            end
        else
            if not effect then
                effect = Instance.new("EqualizerSoundEffect")
                effect.Name = "WatcherBackgroundDuck"
                effect.HighGain, effect.MidGain, effect.LowGain = 0, 0, 0
                effect.Parent = SoundGroups.get(bus)
                self.effects[bus] = effect
            end
            -- All three bands receive the same attenuation: no change of timbre is intended.
            effect.HighGain, effect.MidGain, effect.LowGain =
                gain * amount, gain * amount, gain * amount
        end
    end
end

return Mixer
