-- SquadDisplayMode — persisted squad HUD presentation preference.

local SquadDisplayMode = {}

SquadDisplayMode.MODES = { "classic", "bar", "circle" }

function SquadDisplayMode.normalize(mode)
    if mode == "bar" or mode == "circle" then
        return mode
    end
    return "classic"
end

return SquadDisplayMode
