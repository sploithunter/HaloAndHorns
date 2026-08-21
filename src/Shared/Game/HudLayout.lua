--!strict

-- Pure policy for selecting the HUD presentation. "auto" follows the device, while
-- explicit compact/classic choices are stable across device changes and rejoin.
local InputPlatform = require(script.Parent.InputPlatform)

local HudLayout = {}

HudLayout.MODES = { "auto", "compact", "classic" }

function HudLayout.normalize(mode)
    if mode == "compact" or mode == "classic" then
        return mode
    end
    return "auto"
end

function HudLayout.isMobile(viewportWidth, viewportHeight, touchEnabled, keyboardEnabled)
    local display = InputPlatform.displayClass(false, viewportWidth, viewportHeight, {
        touch = touchEnabled == true,
        keyboard = keyboardEnabled == true,
    })
    return InputPlatform.isCompactDisplay(display)
end

function HudLayout.resolve(mode, viewportWidth, viewportHeight, touchEnabled, keyboardEnabled)
    mode = HudLayout.normalize(mode)
    if mode ~= "auto" then
        return mode
    end
    return HudLayout.isMobile(viewportWidth, viewportHeight, touchEnabled, keyboardEnabled)
            and "compact"
        or "classic"
end

return HudLayout
