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
    PHONE = "phone",
    TABLET = "tablet",
    DESKTOP = "desktop",
    -- Legacy alias: phone and tablet are both compact HUD surfaces.
    COMPACT = "compact",
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
    local shortEdge = math.min(width, height)
    local longEdge = math.max(width, height)
    local aspect = longEdge / math.max(shortEdge, 1)
    local touch = capabilities.touch == true
    local keyboard = capabilities.keyboard == true
    -- A phone/tablet can report a hardware keyboard. Keep those touch-first
    -- below a large-desktop short edge; a touch-screen monitor stays desktop.
    local touchFirst = touch and (not keyboard or shortEdge <= 1024)
    -- Studio device emulators often omit TouchEnabled. Classify from the
    -- viewport: landscape phones are ~2:1 with a short edge < 600; iPads
    -- are ~4:3 with a short edge in the 600–1024 band (1080×810).
    if shortEdge < 600 then
        if touchFirst or aspect >= 1.9 then
            return InputPlatform.DISPLAY.PHONE
        end
        return InputPlatform.DISPLAY.DESKTOP
    end
    if shortEdge <= 1024 and aspect <= 1.55 then
        return InputPlatform.DISPLAY.TABLET
    end
    if touchFirst then
        return InputPlatform.DISPLAY.TABLET
    end
    return InputPlatform.DISPLAY.DESKTOP
end

function InputPlatform.isCompactDisplay(displayClass)
    return displayClass == InputPlatform.DISPLAY.PHONE
        or displayClass == InputPlatform.DISPLAY.TABLET
        or displayClass == InputPlatform.DISPLAY.COMPACT
end

function InputPlatform.isGamepad(inputMode)
    return inputMode == InputPlatform.MODE.GAMEPAD
end

return InputPlatform
