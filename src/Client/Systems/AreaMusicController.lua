--[[
    AreaMusicController — looping background music that follows the player's CURRENT area, and
    swaps to COMBAT music while the player is fighting.

    One Sound, Looped, routed through the "music" SoundGroup bus (so the Settings "Music Volume"
    slider controls it). On spawn and whenever CurrentArea (or HomeArea as a fallback) changes, it
    resolves the area's track from configs/sounds.lua (`area_music` area->key, `music` key->{id,volume})
    and CROSSFADES: fade the current track down, swap the SoundId, fade the new one up. A token guards
    against rapid area changes so only the latest swap wins.

    COMBAT: while the server-set Player attribute `InCombat` is true, the desired track becomes a
    RANDOM key from `combat_music` (config) instead of the area track — chosen ONCE on entry and held
    for the whole fight. When InCombat clears we wait `combat_music_exit_delay` seconds before fading
    back to the area track, so brief aggro flicker (enemy drops + re-acquires) doesn't restart music.

    SAFETY NET: every track swap is watched — if the chosen asset never loads (still moderating at
    publish, or taken down post-approval), within FALLBACK_LOAD_TIMEOUT we swap to `music_fallback`
    (a guaranteed-approved track) so an area is never silent. SFX (PowerSound) are already safe by
    their gaps-are-silent design; this covers the one noticeable case — looping area/combat music.

    Add tracks + remap areas + grow the combat list entirely in configs/sounds.lua — no code here.
]]

local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SoundGroups = require(ReplicatedStorage.Shared.Effects.SoundGroups)
local sounds = require(ReplicatedStorage.Configs:WaitForChild("sounds"))

local AreaMusicController = {}

local FADE = 1.5 -- seconds for each half of the crossfade
local FALLBACK_LOAD_TIMEOUT = 6 -- seconds to let a track load before assuming a dead asset
local localPlayer = Players.LocalPlayer

function AreaMusicController.start()
    local music = sounds.music or {}
    local areaMap = sounds.area_music or {}
    local combatList = sounds.combat_music or {}
    local combatExitDelay = sounds.combat_music_exit_delay or 3.0
    local rng = Random.new()

    local sound = Instance.new("Sound")
    sound.Name = "AreaMusic"
    sound.Looped = true
    sound.Volume = 0
    SoundGroups.assign(sound, "music")
    sound.Parent = SoundService

    local currentKey -- the track key currently playing
    local token = 0
    local inCombat = false -- are we currently in the combat-music state?
    local combatKey -- the combat track chosen for THIS fight (held until it ends)
    local exitToken = 0 -- cancels a pending "return to area music" when combat re-engages

    local function trackForArea(area)
        local key = areaMap[area] or areaMap.default
        return key, key and music[key]
    end

    -- The track we WANT playing right now: a held random combat track while fighting, else the area
    -- track. Area changes mid-combat are no-ops (combat track wins until the fight ends).
    local function desiredTrack()
        if inCombat and combatKey then
            return combatKey, music[combatKey]
        end
        local area = localPlayer:GetAttribute("CurrentArea")
            or localPlayer:GetAttribute("HomeArea")
            or "Spawn"
        return trackForArea(area)
    end

    local function apply()
        local key, def = desiredTrack()
        if not def or not def.id or key == currentKey then
            return -- unknown area/track, or already playing the right one
        end
        currentKey = key

        token += 1
        local myToken = token
        local target = def.volume or 0.45

        -- If the chosen asset never loads (still moderating at publish, or taken down post-approval),
        -- fall back to music_fallback so the area is never silent. Guarded by token (a newer swap wins)
        -- and won't recurse onto itself.
        local function watchLoad()
            task.delay(FALLBACK_LOAD_TIMEOUT, function()
                if myToken ~= token then
                    return -- superseded by a newer swap
                end
                if sound.IsLoaded and sound.TimeLength > 0 then
                    return -- loaded fine, nothing to do
                end
                local fbKey = sounds.music_fallback
                local fbDef = fbKey and music[fbKey]
                if not fbDef or not fbDef.id or key == fbKey then
                    return -- no fallback, or we're already on it (avoid a loop)
                end
                currentKey = fbKey
                sound.SoundId = fbDef.id
                sound:Play()
                TweenService:Create(sound, TweenInfo.new(FADE), { Volume = fbDef.volume or 0.45 })
                    :Play()
            end)
        end

        local function swapIn()
            if myToken ~= token then
                return -- a newer area change superseded this one
            end
            sound.SoundId = def.id
            sound:Play()
            TweenService:Create(sound, TweenInfo.new(FADE), { Volume = target }):Play()
            watchLoad()
        end

        if sound.IsPlaying and sound.Volume > 0 then
            local fadeOut = TweenService:Create(sound, TweenInfo.new(FADE), { Volume = 0 })
            fadeOut.Completed:Once(swapIn)
            fadeOut:Play()
        else
            swapIn()
        end
    end

    -- Combat-music transitions, driven by the server-set `InCombat` Player attribute.
    local function onCombatChanged()
        local fighting = localPlayer:GetAttribute("InCombat") == true
        if fighting then
            exitToken += 1 -- cancel any pending return-to-area fade
            if not inCombat then
                inCombat = true
                if #combatList > 0 then
                    combatKey = combatList[rng:NextInteger(1, #combatList)]
                end
                apply()
            end
        elseif inCombat then
            -- Left combat: wait out brief aggro flicker before fading back to the area track.
            exitToken += 1
            local myExit = exitToken
            task.delay(combatExitDelay, function()
                if myExit ~= exitToken then
                    return -- combat re-engaged within the delay; stay on the combat track
                end
                inCombat = false
                combatKey = nil
                apply()
            end)
        end
    end

    apply()
    onCombatChanged() -- in case we spawn already in combat
    localPlayer:GetAttributeChangedSignal("CurrentArea"):Connect(apply)
    localPlayer:GetAttributeChangedSignal("HomeArea"):Connect(apply)
    localPlayer:GetAttributeChangedSignal("InCombat"):Connect(onCombatChanged)
end

return AreaMusicController
