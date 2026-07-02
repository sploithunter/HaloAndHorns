--[[
    FusionLogic — pure functional core for Chaotic fusion (Feature 20).

    No Roblox APIs. The service supplies the two inputs' elements/themes; these
    rules decide whether the fusion is legal and what the output looks like.

      validateInputs(elemA, elemB, config)              -> { ok, reason?, message? }
      outputElement(config)                             -> "chaotic"
      resolveTheme(themeA, themeB, config)              -> theme
      fusionRecord(playerId, inAId, inBId, outId, ts)   -> table

    Rules (from the GWT spec):
      - Reject any Chaotic input    -> "Cannot fuse Chaotic pets"
      - Reject any Neutral input    -> "Fusion requires aligned pets (Light + Shadow)"
      - Require exactly one Light + one Shadow -> "Fusion requires one Light and one Shadow pet"
]]

local FusionLogic = {}

local CHAOTIC_MSG = "Cannot fuse Chaotic pets"
local NEUTRAL_MSG = "Fusion requires aligned pets (Light + Shadow)"
local PAIR_MSG = "Fusion requires one Light and one Shadow pet"

function FusionLogic.validateInputs(elemA, elemB, config)
    -- Chaotic rejection takes precedence (clearest signal to the player).
    if elemA == "chaotic" or elemB == "chaotic" then
        return { ok = false, reason = "chaotic_input", message = CHAOTIC_MSG }
    end
    if elemA == "neutral" or elemB == "neutral" then
        return { ok = false, reason = "neutral_input", message = NEUTRAL_MSG }
    end
    local req = (config and config.required_elements) or { "light", "shadow" }
    local a, b = req[1], req[2]
    local valid = (elemA == a and elemB == b) or (elemA == b and elemB == a)
    if not valid then
        return { ok = false, reason = "not_light_shadow", message = PAIR_MSG }
    end
    return { ok = true }
end

function FusionLogic.outputElement(config)
    return (config and config.output_element) or "chaotic"
end

-- The output theme: an explicit recipe (sorted "themeA+themeB" key) wins; otherwise
-- it inherits from the configured input (default input A).
function FusionLogic.resolveTheme(themeA, themeB, config)
    local recipes = (config and config.recipes) or {}
    local lo, hi = themeA, themeB
    if lo and hi and tostring(hi) < tostring(lo) then
        lo, hi = hi, lo
    end
    local key = tostring(lo) .. "+" .. tostring(hi)
    if recipes[key] then
        return recipes[key]
    end
    local from = (config and config.default_output_theme_from) or "input_a"
    if from == "input_b" then
        return themeB
    end
    return themeA
end

function FusionLogic.fusionRecord(playerId, inputAId, inputBId, outputId, timestamp)
    return {
        player = playerId,
        input_a = inputAId,
        input_b = inputBId,
        output = outputId,
        timestamp = timestamp,
    }
end

return FusionLogic
