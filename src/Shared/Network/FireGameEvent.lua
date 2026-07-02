--[[
    FireGameEvent — server-side one-liner for the GameEvents bus (docs/GAME_EVENTS.md).

    Usage (any server service):
        local fireGameEvent = require(ReplicatedStorage.Shared.Network.FireGameEvent)
        fireGameEvent(player, "quest_complete", { quest = questId })

    Sends Signals.GameEvent to that player's client, where GameEvents.start() dispatches the
    reactions declared in configs/game_events.lua (sound / vfx / ...). Firing an event with no
    config entry is a no-op, so sources can fire unconditionally and reactions stay config-only.
    pcall'd: a celebration must never break the gameplay mutation that triggered it.

    SERVER TAP: fireGameEvent.tap(fn) registers a server-side observer of EVERY event —
    fn(player, name, ctx) runs (pcall'd) before the client send. This is how cross-cutting
    consumers (the tutorial) react to gameplay without any gameplay service knowing they exist.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local Signals = require(ReplicatedStorage.Shared.Network.Signals)

local listeners = {}

-- WORLD SOUND (Jason: "everybody should hear those sounds... localized to the map"):
-- a config row with `world_sound = "<sounds.lua key>"` plays POSITIONALLY at the
-- player's character, SERVER-created — it replicates to every client with natural
-- 3D falloff (nearby players hear it; across the map they don't). Rows use EITHER
-- `sound` (personal, client-played) OR `world_sound` (everyone nearby) — both would
-- echo for the owner.
local _events, _sounds
local function worldSound(player, name)
    if _events == nil then
        local ok1, ev = pcall(function()
            return require(ReplicatedStorage.Configs:WaitForChild("game_events"))
        end)
        local ok2, snd = pcall(function()
            return require(ReplicatedStorage.Configs:WaitForChild("sounds"))
        end)
        _events = ok1 and ev or {}
        _sounds = ok2 and snd or {}
    end
    local row = _events[name]
    local key = row and row.world_sound
    local def = key and _sounds[key]
    if not (def and def.id) then
        return
    end
    local char = player and player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then
        return
    end
    local sound = Instance.new("Sound")
    sound.SoundId = def.id
    sound.Volume = tonumber(def.volume) or 0.5
    sound.PlaybackSpeed = tonumber(def.playback_speed) or 1
    sound.RollOffMode = Enum.RollOffMode.InverseTapered
    sound.RollOffMaxDistance = tonumber(row.world_sound_range) or 120
    sound.Parent = root
    sound:Play()
    Debris:AddItem(sound, 10)
end

local FireGameEvent = setmetatable({}, {
    __call = function(_, player, name, ctx)
        for _, fn in ipairs(listeners) do
            pcall(fn, player, name, ctx)
        end
        pcall(worldSound, player, name)
        pcall(function()
            Signals.GameEvent:FireClient(player, name, ctx)
        end)
    end,
})

function FireGameEvent.tap(fn)
    table.insert(listeners, fn)
end

return FireGameEvent
