-- QuestDisplayMode — persisted quest/objective HUD presentation preference.

local QuestDisplayMode = {}

QuestDisplayMode.MODES = { "full", "pill", "ring" }

function QuestDisplayMode.normalize(mode)
    if mode == "pill" or mode == "ring" then
        return mode
    end
    return "full"
end

return QuestDisplayMode
