-- Cue identities and speakers stay canonical; only the recording changes with tutorial language.
local Locale = {}

function Locale.resolve(language, cue, english, locales, unavailable)
    local translated = locales[language] and locales[language][cue]
    if translated and not (unavailable and unavailable[translated.asset_id]) then
        return translated, language
    end
    return english[cue], "en"
end

return Locale
