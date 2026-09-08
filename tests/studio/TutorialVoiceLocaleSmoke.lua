-- Client fixture: no server calls, saved preferences, tutorial progress or grants.
local Smoke = {}
function Smoke.run()
    local storage = game:GetService("ReplicatedStorage")
    local systems = game:GetService("Players").LocalPlayer.PlayerScripts.Client.Systems
    local Narrator = require(systems.TutorialNarrator)
    local locales = require(storage.Configs.tutorial_voice_locales).locales
    local players = {}
    local report = { tracks = 0, switches = 0 }
    local ok, err = pcall(function()
        for _, track in { "tutorial", "merge_tutorial" } do
            local lines = require(storage.Configs[track .. "_voice_lines"])
            local assets = require(storage.Configs[track .. "_voice_assets"]).clips
            local config = table.clone(require(storage.Configs.tutorial_voice))
            config.audio = table.clone(config.audio)
            config.audio.group_name = "TutorialVoiceLocaleSmoke_" .. track
            local p = Narrator.new({
                config = config,
                lines = lines,
                assets = assets,
                localeId = "es-MX",
            })
            table.insert(players, p)
            local cue = track == "tutorial" and "tutorial.hatch_first_egg"
                or "merge_tutorial.hell.collect_setup"
            p:setCue(cue, "0", { remind = true })
            assert(
                p.current.language == "es" and p.current.assetId == locales.es[cue].asset_id,
                "Spanish cue missing"
            )
            local original = p.current.sound
            local volume, group = original.Volume, original.SoundGroup
            p:setLocale("es-ES")
            assert(p.current.sound == original, "Equivalent locale restarted narration")
            p.nextCue = cue
            p.current.reminder, p.current.completion = true, true
            p.hasReminded, p.idleSeconds = true, 13
            p:setLocale("pt-BR")
            assert(original.Parent == nil, "Old language sound leaked")
            assert(p.current.assetId == locales["pt-br"][cue].asset_id, "Portuguese cue missing")
            assert(p.current.language == "pt-br" and p.nextCue == cue, "Switch lost queue")
            assert(
                p.current.reminder and p.current.completion and p.hasReminded,
                "Switch lost flags"
            )
            assert(
                p.idleSeconds == 13
                    and p.current.sound.Volume == volume
                    and p.current.sound.SoundGroup == group,
                "Switch changed timing or voice mix"
            )
            assert(
                p.presentation.gui:GetAttribute("VoiceLanguage") == "pt-br",
                "Presentation language stale"
            )
            local unavailable = p.current
            assert(p:_fallback(unavailable), "Missing localized audio did not fall back")
            assert(unavailable.sound.Parent == nil, "Failed sound leaked")
            assert(
                p.current.language == "en" and p.current.assetId == assets[cue].asset_id,
                "Wrong fallback"
            )
            assert(
                p.current.reminder and p.current.completion and p.nextCue == cue,
                "Fallback lost sequence"
            )
            assert(not p:_fallback(p.current), "English failure loops")
            p:_play(cue)
            assert(p.current.language == "en", "Failed translation retried within session")
            p:setLocale("es-MX")
            assert(p.current.language == "es", "One unavailable locale disabled another")
            p:setLocale("en-US")
            assert(p.current.assetId == assets[cue].asset_id, "English preference ignored")
            p:setLocale("de-DE")
            assert(p.current.language == "en", "Unsupported locale did not fall back")
            p:cancel()
            p:setLocale("pt-BR")
            assert(
                p.current == nil and p.nextCue == nil and p.identity == nil,
                "Locale change revived cancelled lesson"
            )
            report.tracks += 1
            report.switches += 5
        end
    end)
    for _, p in ipairs(players) do
        p:destroy()
        for _, connection in ipairs(p.connections) do
            assert(not connection.Connected, "Narrator connection leaked")
        end
    end
    assert(ok, err)
    return report
end
return Smoke
