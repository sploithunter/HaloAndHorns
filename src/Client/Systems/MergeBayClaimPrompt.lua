-- Empty bays stay available to other players, but must not offer a second claim to their owner.
-- Track only tagged prompts; no polling or whole-Workspace scans. BayId is assigned before
-- yielding entry and cleared after pet restoration/teardown, so it covers both transition edges.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Policy = require(ReplicatedStorage.Shared.Game.MergeBayClaimPolicy)

local Controller = {}
local TAG = "MergeEggBayClaimPrompt"
local started = false

-- Export the binding seam for isolated multi-viewer Studio fixtures.
function Controller.bind(player, prompt, bay)
    local connections = {}
    local function refresh()
        local enabled = Policy.canOffer(player, bay:GetAttribute("MergeEggBayAvailable"))
        if prompt.Enabled ~= enabled then
            prompt.Enabled = enabled
        end
    end
    for _, attribute in ipairs({
        "MergeEggBayId",
        "InMergeEggPrototype",
        "InMission",
        "InPrologue",
        "InCombatTutorial",
        "GauntletMode",
    }) do
        connections[#connections + 1] = player:GetAttributeChangedSignal(attribute):Connect(refresh)
    end
    connections[#connections + 1] = bay:GetAttributeChangedSignal("MergeEggBayAvailable")
        :Connect(refresh)
    -- Server claim/release may replicate Enabled after the bay attribute; reapply our local mask.
    connections[#connections + 1] = prompt:GetPropertyChangedSignal("Enabled"):Connect(refresh)
    refresh()
    return function()
        for _, connection in ipairs(connections) do
            connection:Disconnect()
        end
    end
end

function Controller.start()
    if started then
        return
    end
    started = true
    local bindings = {}
    local function remove(prompt)
        if bindings[prompt] then
            bindings[prompt]()
            bindings[prompt] = nil
        end
    end
    local function add(prompt)
        if bindings[prompt] or not prompt:IsA("ProximityPrompt") then
            return
        end
        local bay = prompt.Parent
        while bay and bay:GetAttribute("MergeEggBayAvailable") == nil do
            bay = bay.Parent
        end
        if bay then
            bindings[prompt] = Controller.bind(Players.LocalPlayer, prompt, bay)
        end
    end
    CollectionService:GetInstanceAddedSignal(TAG):Connect(add)
    CollectionService:GetInstanceRemovedSignal(TAG):Connect(remove)
    for _, prompt in ipairs(CollectionService:GetTagged(TAG)) do
        add(prompt)
    end
end

return Controller
