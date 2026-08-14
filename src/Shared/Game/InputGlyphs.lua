-- InputGlyphs — semantic control labels. Keep gameplay copy independent from Enum key names.

local InputGlyphs = {}

local GAMEPAD = {
    confirm = "A",
    back = "B",
    interact = "X",
    farm = "Y",
    previous_power = "LB",
    next_power = "RB",
    cast = "RT",
    autocast = "LT",
    pets = "D-pad Left",
    powers = "D-pad Right",
    quests = "D-pad Up",
    menu = "D-pad Down",
}

local DESKTOP = {
    confirm = "Enter",
    back = "Esc",
    interact = "E",
    farm = "Farm",
    previous_power = "Previous",
    next_power = "Next",
    cast = "number key",
    autocast = "right-click",
    pets = "Pets",
    powers = "Powers",
    quests = "Quest",
    menu = "Menu",
}

function InputGlyphs.get(inputMode, action)
    local map = inputMode == "gamepad" and GAMEPAD or DESKTOP
    return map[action] or tostring(action or "")
end

function InputGlyphs.hotbarLegend(inputMode)
    if inputMode ~= "gamepad" then
        return ""
    end
    return "LB/RB SELECT   •   RT CAST   •   LT AUTO   •   Y FARM"
end

return InputGlyphs
