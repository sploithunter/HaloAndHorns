-- Pure keyboard-to-hotbar mapping. Roblox may mark Shift+digit as handled by CoreGui
-- (notably while Shift Lock is active), and some keyboard layouts report the shifted
-- punctuation KeyCode instead of the physical digit. Both forms must reach slots 11..20.

local HotbarKeyboard = {}

local DIGIT_SLOT = {
    One = 1,
    Two = 2,
    Three = 3,
    Four = 4,
    Five = 5,
    Six = 6,
    Seven = 7,
    Eight = 8,
    Nine = 9,
    Zero = 10,
}

local SHIFTED_DIGIT_SLOT = {
    Exclamation = 1,
    At = 2,
    Hash = 3,
    Dollar = 4,
    Percent = 5,
    Caret = 6,
    Ampersand = 7,
    Asterisk = 8,
    LeftParenthesis = 9,
    RightParenthesis = 10,
}

function HotbarKeyboard.resolve(keyName, shiftDown, gameProcessed, textFocused, robloxMenuOpen)
    if textFocused or robloxMenuOpen then
        return nil
    end

    keyName = tostring(keyName or "")
    local base = DIGIT_SLOT[keyName] or SHIFTED_DIGIT_SLOT[keyName]
    if not base then
        return nil
    end

    local shifted = shiftDown == true or SHIFTED_DIGIT_SLOT[keyName] ~= nil
    -- CoreGui may claim Shift+digit for Shift Lock before this listener runs. Allow that
    -- specific chord through, while preserving the normal processed-input guard.
    if gameProcessed and not shifted then
        return nil
    end

    return shifted and (base + 10) or base
end

return HotbarKeyboard
