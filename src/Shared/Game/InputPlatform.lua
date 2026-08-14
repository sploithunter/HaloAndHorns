-- InputPlatform — pure classification helpers shared by the live client and headless tests.
-- Input mode describes the last device the player used; display class describes the screen.

local InputPlatform = {}

InputPlatform.MODE = {
    GAMEPAD = "gamepad",
    MOUSE_KEYBOARD = "mouse_keyboard",
    TOUCH = "touch",
}

InputPlatform.DISPLAY = {
    TEN_FOOT = "ten_foot",
    COMPACT = "compact",
    DESKTOP = "desktop",
}

local function token(value)
    return string.lower(tostring(value or ""))
end

function InputPlatform.inputMode(preferredInput, capabilities)
    capabilities = capabilities or {}
    local name = token(preferredInput)
    if string.find(name, "gamepad", 1, true) then
        return InputPlatform.MODE.GAMEPAD
    elseif string.find(name, "touch", 1, true) then
        return InputPlatform.MODE.TOUCH
    elseif string.find(name, "keyboard", 1, true) or string.find(name, "mouse", 1, true) then
        return InputPlatform.MODE.MOUSE_KEYBOARD
    end
    if capabilities.gamepad then
        return InputPlatform.MODE.GAMEPAD
    elseif capabilities.touch and not capabilities.keyboard then
        return InputPlatform.MODE.TOUCH
    end
    return InputPlatform.MODE.MOUSE_KEYBOARD
end

function InputPlatform.displayClass(isTenFoot, width, height, capabilities)
    if isTenFoot then
        return InputPlatform.DISPLAY.TEN_FOOT
    end
    capabilities = capabilities or {}
    width = tonumber(width) or 1280
    height = tonumber(height) or 720
    if (capabilities.touch and not capabilities.keyboard) or width < 900 or height < 560 then
        return InputPlatform.DISPLAY.COMPACT
    end
    return InputPlatform.DISPLAY.DESKTOP
end

function InputPlatform.isGamepad(inputMode)
    return inputMode == InputPlatform.MODE.GAMEPAD
end

return InputPlatform
