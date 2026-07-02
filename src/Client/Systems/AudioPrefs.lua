--[[
    AudioPrefs (client) — persist + restore the audio sliders (Jason: "lowering the volume
    in settings is temporary").

    The Settings panel only mutated a local table that re-defaulted to 1.0 every boot.
    Persistence rides the command bus: `settings.set` stores the audio table in the profile
    (data.Settings.ClientPrefs), `settings.get` returns it. start() loads + APPLIES at boot,
    so saved volumes are live before the Settings panel is ever opened; the panel seeds its
    sliders from loaded() and calls save() on change (debounced — slider drags fire a lot).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local SoundGroups = require(ReplicatedStorage.Shared.Effects.SoundGroups)

local AudioPrefs = {}
local loadedAudio = nil -- last known persisted table (nil until the bus answers)
local loadResolved = false -- the initial settings.get completed (success or no prefs)
local saveQueued = false

local function callBus(name, args)
    local remote = ReplicatedStorage:WaitForChild("GameAPICommand", 15)
    if not remote then
        return nil
    end
    local ok, envelope = pcall(function()
        return remote:InvokeServer(name, args or {})
    end)
    if not ok or type(envelope) ~= "table" then
        return nil
    end
    return envelope.result or envelope.data or envelope
end

-- Same bus math the Settings panel uses (master folds into every bus).
function AudioPrefs.apply(audio)
    if type(audio) ~= "table" then
        return
    end
    local master = tonumber(audio.masterVolume) or 1
    SoundGroups.setVolume("effects", (tonumber(audio.effectsVolume) or 1) * master)
    SoundGroups.setVolume("music", (tonumber(audio.musicVolume) or 1) * master)
    SoundGroups.setVolume("ui", (audio.uiSoundsEnabled ~= false and 1 or 0) * master)
end

-- The persisted audio table, or nil if none saved / not loaded yet.
function AudioPrefs.loaded()
    return loadedAudio
end

-- Debounced persist (1s): the LAST values win; slider drags collapse to one save.
-- HARD GUARD: never persist before the initial load resolves — the Settings panel
-- syncs-and-saves on build, and doing that pre-load CLOBBERED the stored prefs with
-- defaults (Jason's "sometimes it's at 100%" race).
function AudioPrefs.save(audio)
    loadedAudio = audio
    if not loadResolved or saveQueued then
        return
    end
    saveQueued = true
    task.delay(1, function()
        saveQueued = false
        callBus("settings.set", { audio = loadedAudio })
    end)
end

-- Route CHARACTER sounds (Roblox's RbxCharacterSounds: footsteps, jump, land, swim)
-- onto the effects bus — they spawn ungrouped, so they ignored the SFX slider (Jason:
-- "the stepping is not being controlled by effects volume"). Covers every player's
-- character, including respawns and late joiners.
local function busCharacterSounds()
    local function tag(inst)
        if inst:IsA("Sound") then
            SoundGroups.assign(inst, "effects")
        end
    end
    local function busCharacter(char)
        for _, d in ipairs(char:GetDescendants()) do
            tag(d)
        end
        char.DescendantAdded:Connect(tag)
    end
    local function busPlayer(p)
        if p.Character then
            busCharacter(p.Character)
        end
        p.CharacterAdded:Connect(busCharacter)
    end
    for _, p in ipairs(Players:GetPlayers()) do
        busPlayer(p)
    end
    Players.PlayerAdded:Connect(busPlayer)
end

function AudioPrefs.start()
    busCharacterSounds()
    task.spawn(function()
        -- RETRY until the profile answers: client boot often beats DataService, and the
        -- single-shot get returned data_not_loaded -> defaults stuck at 100% (Jason).
        for attempt = 1, 30 do
            local res = callBus("settings.get")
            if type(res) == "table" and res.ok ~= false then
                local audio = type(res.audio) == "table" and res.audio or nil
                if audio then
                    loadedAudio = audio
                    AudioPrefs.apply(audio)
                end
                loadResolved = true -- success (with or without stored prefs): saves may flow
                return
            end
            task.wait(attempt <= 5 and 0.5 or 2)
        end
        loadResolved = true -- give up gracefully; allow saves so the session still works
    end)
end

return AudioPrefs
