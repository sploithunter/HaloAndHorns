local Locale = loadModule("src/Shared/Game/TutorialVoiceLocale.lua")
local Language = loadModule("src/Shared/Game/TutorialLocalization.lua")
local Director = loadModule("src/Shared/Game/TutorialVoiceDirector.lua")
local locales = loadModule("configs/tutorial_voice_locales.lua").locales

return function()
    describe("Localized tutorial recordings", function()
        it("covers every Farm, combat, Heaven and Hell cue in both supported languages", function()
            for _, language in { "es", "pt-br" } do
                local expected = {}
                for _, track in { "tutorial", "merge_tutorial" } do
                    local english = loadModule("configs/" .. track .. "_voice_assets.lua").clips
                    local lines = loadModule("configs/" .. track .. "_voice_lines.lua")
                    for cue in pairs(Director.catalog(lines)) do
                        expected[cue] = true
                        local asset, resolved = Locale.resolve(language, cue, english, locales)
                        expect(resolved).to.equal(language)
                        expect(asset.asset_id > 0).to.equal(true)
                        expect(asset.asset_id ~= english[cue].asset_id).to.equal(true)
                        expect(asset.seconds > 0).to.equal(true)
                    end
                end
                local count = 0
                for cue in pairs(locales[language]) do
                    expect(expected[cue]).to.equal(true)
                    count += 1
                end
                expect(count).to.equal(172)
            end
        end)
        it("uses the same locale normalization as written tutorials", function()
            local cue = "tutorial.choose_companion"
            local english = loadModule("configs/tutorial_voice_assets.lua").clips
            for localeId, expected in { ["es-MX"] = "es", pt_PT = "pt-br", ["fr-FR"] = "en" } do
                local _, language =
                    Locale.resolve(Language.languageFor(localeId), cue, english, locales)
                expect(language).to.equal(expected)
            end
        end)
        it("falls back per cue without disabling the rest of a language", function()
            local english = { welcome = { asset_id = 1 }, next = { asset_id = 2 } }
            local translated = { es = { welcome = { asset_id = 3 } } }
            local asset, language = Locale.resolve("es", "next", english, translated)
            expect(asset).to.equal(english.next)
            expect(language).to.equal("en")
            local available, spanish = Locale.resolve("es", "welcome", english, translated)
            expect(available).to.equal(translated.es.welcome)
            expect(spanish).to.equal("es")
            local fallback, fallbackLanguage =
                Locale.resolve("es", "welcome", english, translated, { [3] = true })
            expect(fallback).to.equal(english.welcome)
            expect(fallbackLanguage).to.equal("en")
            expect(Locale.resolve("es", "unknown", english, translated)).to.equal(nil)
        end)
    end)
end
