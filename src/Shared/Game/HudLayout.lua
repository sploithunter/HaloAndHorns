--!strict

-- Pure policy for selecting the HUD presentation. "auto" follows the device, while
-- explicit compact/classic choices are stable across device changes and rejoin.
local HudLayout = {}

HudLayout.MODES = { "auto", "compact", "classic" }

function HudLayout.normalize(mode)
    if mode == "compact" or mode == "classic" then
        return mode
    end
    return "auto"
end

function HudLayout.isMobile(viewportWidth, viewportHeight, touchEnabled, keyboardEnabled)
    if touchEnabled ~= true then
        return false
    end
    local shortEdge = math.min(tonumber(viewportWidth) or 0, tonumber(viewportHeight) or 0)
    -- A phone/tablet can report a hardware keyboard. Keep Auto mobile on normal tablet-sized
    -- viewports, but do not flip a large touch-screen desktop into the compact layout.
    return keyboardEnabled ~= true or shortEdge <= 1024
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
