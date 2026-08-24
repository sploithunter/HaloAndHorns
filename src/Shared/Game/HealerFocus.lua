--[[
    HealerFocus — healer-hunt click cue (KILL THIS) as a pure tick.

    Click is one way to hide the sign. Pets already swinging that healer also
    count — they can auto-pick it. Once the healer is dead, never ask for
    another click (the enemy card is gone).
]]

local HealerFocus = {}

function HealerFocus.tick(state, input)
    state = type(state) == "table" and state or {}
    input = type(input) == "table" and input or {}
    local focus = {
        committed = state.committed == true,
        engaged = state.engaged == true,
        lost = state.lost == true,
        cue = state.cue == true,
    }
    if input.alive ~= true then
        focus.cue = false
        return focus, {}
    end
    if input.justClicked == true then
        focus.committed = true
        focus.engaged = false
        focus.lost = false
        focus.cue = false
    end
    if input.attacking == true then
        focus.committed = true
        focus.engaged = true
        focus.lost = false
        focus.cue = false
        return focus, {}
    end
    if focus.committed and focus.engaged and not focus.lost then
        focus.lost = true
        focus.cue = true
        return focus, { lost_banner = true }
    end
    return focus, {}
end

return HealerFocus
