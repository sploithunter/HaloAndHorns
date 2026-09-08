-- Client-only delivery check. Does not play sounds or touch player progress/settings.
local Delivery = {}
local report

function Delivery.start(entries)
    assert(not report or report.done == report.expected, "Previous delivery check is still running")
    if not entries then
        entries = {}
        local config = require(game:GetService("ReplicatedStorage").Configs.tutorial_voice_locales)
        for locale, clips in pairs(config.locales) do
            for cue, asset in pairs(clips) do
                table.insert(entries, { locale = locale, cue = cue, asset_id = asset.asset_id })
            end
        end
    end
    report = { expected = #entries, done = 0, loaded = 0, clips = {} }
    local index = 0
    for _ = 1, 6 do
        task.spawn(function()
            while true do
                index += 1
                local entry = entries[index]
                if not entry then
                    return
                end
                local result = table.clone(entry)
                local sound = Instance.new("Sound")
                sound.Name = "TutorialVoiceDeliveryCheck"
                sound.SoundId = "rbxassetid://" .. tostring(entry.asset_id)
                -- An unparented Sound can return from PreloadAsync without fetching in Studio.
                sound.Parent = game:GetService("SoundService")
                local ok, err = pcall(function()
                    game:GetService("ContentProvider"):PreloadAsync({ sound }, function(_, status)
                        result.fetchStatus = tostring(status)
                    end)
                end)
                result.loaded = ok and sound.IsLoaded and sound.TimeLength > 0
                result.timeLength = sound.TimeLength
                result.error = not ok and tostring(err) or nil
                sound:Destroy()
                table.insert(report.clips, result)
                report.done += 1
                if result.loaded then
                    report.loaded += 1
                end
            end
        end)
    end
    return { expected = report.expected }
end

function Delivery.read()
    return report
end

return Delivery
