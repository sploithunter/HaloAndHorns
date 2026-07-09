--[[
    MissionGatePrompt — stamps WHICH trial a quest-aware realm gate will deal
    onto its E-prompt (Jason, 2026-07-09: "a good reminder that the mission
    you're about to enter is Hell Lava Trial 1 on the E button").

    The door's ProximityPrompt is ONE shared instance but the deal is
    per-player (active quest binding + your own sequence head), so the text
    is overridden LOCALLY from the server-published NextTrialLabel attribute
    (MissionInstanceService). Only auto/random doors are stamped — fixed
    MissionId doors already name their mission in the ActionText.
]]

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")

local PROMPT_NAME = "MissionDoorPrompt"

local MissionGatePrompt = {}

function MissionGatePrompt.start()
    local player = Players.LocalPlayer
    local shown -- the auto-gate prompt currently on screen (if any)

    local function stamp(prompt)
        local label = player:GetAttribute("NextTrialLabel")
        if label and label ~= "" then
            prompt.ObjectText = label
        end
    end

    ProximityPromptService.PromptShown:Connect(function(prompt)
        if prompt.Name ~= PROMPT_NAME then
            return
        end
        local part = prompt.Parent
        local missionId = part and part:GetAttribute("MissionId")
        if missionId == "auto" or missionId == "random" then
            shown = prompt
            stamp(prompt)
        end
    end)
    ProximityPromptService.PromptHidden:Connect(function(prompt)
        if prompt == shown then
            shown = nil
        end
    end)
    -- activating/deactivating a branch while standing at the gate
    player:GetAttributeChangedSignal("NextTrialLabel"):Connect(function()
        if shown then
            stamp(shown)
        end
    end)
end

return MissionGatePrompt
