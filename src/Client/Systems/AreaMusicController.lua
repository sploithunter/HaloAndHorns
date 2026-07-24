--[[
    AreaMusicController — looping background music that follows the player's CURRENT area, and
    swaps to COMBAT music while the player is fighting.

    One Sound, Looped, routed through the "music" SoundGroup bus (so the Settings "Music Volume"
    slider controls it). On spawn and whenever CurrentArea (or HomeArea as a fallback) changes, it
    resolves the area's track from configs/sounds.lua (`area_music` area->key, `music` key->{id,volume})
    and CROSSFADES: fade the current track down, swap the SoundId, fade the new one up. A token guards
    against rapid area changes so only the latest swap wins.

    COMBAT: while the server-set Player attribute `InCombat` is true, the desired track becomes a
    RANDOM key from the combat pool instead of the area track — chosen ONCE on entry and held
    for the whole fight. When InCombat clears we wait `combat_music_exit_delay` seconds before fading
    back to the area track, so brief aggro flicker (enemy drops + re-acquires) doesn't restart music.
    The pool is REALM-FLAVORED (`combat_music_by_realm`): fights in Heaven_* zones / heaven missions
    draw the heaven pool, Hell_* / hell missions the hell pool; everywhere else uses `combat_music`.

    SAFETY NET: every track swap is watched — if the chosen asset never loads (still moderating at
    publish, or taken down post-approval), within FALLBACK_LOAD_TIMEOUT we swap to `music_fallback`
    (a guaranteed-approved track) so an area is never silent. SFX (PowerSound) are already safe by
    their gaps-are-silent design; this covers the one noticeable case — looping area/combat music.

    Add tracks + remap areas + grow the combat list entirely in configs/sounds.lua — no code here
    except the mission_<realm>_<element> prefer path (element trials share MissionArea across
    realms for drops/RPS; music must still be realm-flavored).
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
    local combatByRealm = sounds.combat_music_by_realm or {}
    local combatExitDelay = sounds.combat_music_exit_delay or 3.0
    local rng = Random.new()

    -- The combat pool for wherever the player is standing RIGHT NOW.
    -- Prefer CurrentRealm (set on hell/heaven trials even when MissionArea is
    -- an element like "grass" → CurrentArea "mission_grass"). Fall back to
    -- area-name prefixes for open-world Heaven_*/Hell_* zones.
    local function combatPool()
        -- THE PROLOGUE fights hell adversaries wherever the room floats (Jason: "start with
        -- the hell music") — the hell pool wins outright while the cold open runs.
        if localPlayer:GetAttribute("InPrologue") == true then
            local pool = sounds.prologue_combat_music or combatByRealm.hell
            if pool then
                return pool
            end
        end
        local realm = tostring(localPlayer:GetAttribute("CurrentRealm") or "")
        if realm == "heaven" and combatByRealm.heaven then
            return combatByRealm.heaven
        end
        if realm == "hell" and combatByRealm.hell then
            return combatByRealm.hell
        end
        local area = tostring(
            localPlayer:GetAttribute("CurrentArea") or localPlayer:GetAttribute("HomeArea") or ""
        )
        if (area:sub(1, 7) == "Heaven_" or area == "mission_heaven") and combatByRealm.heaven then
            return combatByRealm.heaven
        end
        if (area:sub(1, 5) == "Hell_" or area == "mission_hell") and combatByRealm.hell then
            return combatByRealm.hell
        end
        return combatList
    end

    -- PRELOAD the prologue battle tracks: the cold open needs its music at second zero,
    -- and a cold asset cache is exactly when the load watchdog used to misfire.
    task.spawn(function()
        local ids = {}
        for _, k in ipairs(sounds.prologue_combat_music or {}) do
            local def = music[k]
            if def and def.id then
                local s2 = Instance.new("Sound")
                s2.SoundId = def.id
                ids[#ids + 1] = s2
            end
        end
        if #ids > 0 then
            pcall(function()
                game:GetService("ContentProvider"):PreloadAsync(ids)
            end)
            for _, s2 in ipairs(ids) do
                s2:Destroy()
            end
        end
    end)

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
        area = tostring(area or "")
        -- Element trials keep MissionArea = grass/lava/... (biome RPS / drops
        -- stay on mission_<element>), but hell grass must not share Spawn's
        -- spa bed. Prefer mission_<realm>_<element> when CurrentRealm is set
        -- (Jason 2026-07-15: Hell Grass Trial played cheerful Spawn music).
        if area:sub(1, 8) == "mission_" then
            local realm = tostring(localPlayer:GetAttribute("CurrentRealm") or "")
            local element = area:sub(9) -- "grass", "lava", "hell", ...
            if
                (realm == "hell" or realm == "heaven")
                and element ~= ""
                and element ~= "hell"
                and element ~= "heaven"
            then
                local flavored = "mission_" .. realm .. "_" .. element
                local flavoredKey = areaMap[flavored]
                if flavoredKey and music[flavoredKey] then
                    return flavoredKey, music[flavoredKey]
                end
            end
        end
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
                -- COMBAT stays combat (Jason: "the battle music didn't play that time" —
                -- a stalled hell-track load was swapping in the HUB THEME mid-battle): while
                -- fighting, fall back to another member of the current combat pool before
                -- ever reaching for the area fallback.
                local fbKey = sounds.music_fallback
                if inCombat then
                    for _, k in ipairs(combatPool()) do
                        if k ~= key and music[k] and music[k].id then
                            fbKey = k
                            combatKey = k -- the held fight-track follows the swap
                            break
                        end
                    end
                end
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
    -- The prologue counts as combat FROM ITS FIRST FRAME (Jason: the reveal played the
    -- intro spa bed over a battle) — InPrologue ORs in, so the hell track is already
    -- rolling under the black title card and holds through the whole cold open.
    local function onCombatChanged()
        local fighting = localPlayer:GetAttribute("InCombat") == true
            or localPlayer:GetAttribute("InPrologue") == true
        if fighting then
            exitToken += 1 -- cancel any pending return-to-area fade
            if not inCombat then
                inCombat = true
                local pool = combatPool()
                if #pool > 0 then
                    combatKey = pool[rng:NextInteger(1, #pool)]
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

    -- FIRST APPLY: a prologue-bound boot must open STRAIGHT onto battle music (Jason:
    -- "there was some environmental music in there... if the pets are battling, it should
    -- be battle music without any other music"). The controller can boot before InPrologue
    -- replicates, and starting the area bed just to crossfade it away plays BOTH tracks
    -- under the title card. Same bounded race window as the boot card: hold silent until
    -- the prologue gate resolves, then start on whichever track is actually right.
    task.spawn(function()
        local deadline = os.clock() + 8
        while os.clock() < deadline do
            if
                localPlayer:GetAttribute("InPrologue") ~= nil
                or localPlayer:GetAttribute("PrologueGate") ~= nil
            then
                break
            end
            task.wait(0.1)
        end
        if localPlayer:GetAttribute("InPrologue") == true then
            onCombatChanged() -- straight to the battle pool; no area bed ever starts
        else
            apply()
            onCombatChanged() -- in case we spawn already in combat
        end
    end)
    localPlayer:GetAttributeChangedSignal("CurrentArea"):Connect(apply)
    localPlayer:GetAttributeChangedSignal("HomeArea"):Connect(apply)
    localPlayer:GetAttributeChangedSignal("InCombat"):Connect(onCombatChanged)
    localPlayer:GetAttributeChangedSignal("InPrologue"):Connect(onCombatChanged)
end

return AreaMusicController
