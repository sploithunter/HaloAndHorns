-- Client-only isolated viewers/prompts; no live player ownership or profile changes.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Smoke = {}

function Smoke.run()
    local Controller = require(Players.LocalPlayer.PlayerScripts.Client.Systems.MergeBayClaimPrompt)
    local roots, cleanup = {}, {}
    local function make(className)
        local instance = Instance.new(className)
        roots[#roots + 1] = instance
        return instance
    end
    local ok, result = pcall(function()
        local bay, owner, newcomer = make("Model"), make("Folder"), make("Folder")
        bay:SetAttribute("MergeEggBayAvailable", true)
        owner:SetAttribute("MergeEggBayId", "heaven_01")
        local ownerPrompt, newcomerPrompt = make("ProximityPrompt"), make("ProximityPrompt")
        cleanup[#cleanup + 1] = Controller.bind(owner, ownerPrompt, bay)
        cleanup[#cleanup + 1] = Controller.bind(newcomer, newcomerPrompt, bay)
        local function check(ownerEnabled, newcomerEnabled, reason)
            RunService.Heartbeat:Wait()
            assert(ownerPrompt.Enabled == ownerEnabled, reason .. " (owner)")
            assert(newcomerPrompt.Enabled == newcomerEnabled, reason .. " (newcomer)")
        end
        check(false, true, "Entry claim must not affect another viewer")
        owner:SetAttribute("InMergeEggPrototype", true)
        check(false, true, "Active bay")
        ownerPrompt.Enabled = true -- Simulate a server release update for this empty target bay.
        check(false, true, "Server Enabled update must not bypass the local mask")
        owner:SetAttribute("InMergeEggPrototype", nil)
        check(false, true, "Pets/claim still cleaning up")
        owner:SetAttribute("MergeEggBayId", nil)
        check(true, true, "Released player can claim again")
        bay:SetAttribute("MergeEggBayAvailable", false)
        check(false, false, "Another player claimed the target")
        bay:SetAttribute("MergeEggBayAvailable", true)
        check(true, true, "Target released")
        newcomer:SetAttribute("InMission", "fixture")
        check(true, false, "Mission viewer")
        newcomer:SetAttribute("InMission", nil)
        check(true, true, "Mission returned")
        return {
            passed = true,
            independentViewers = 2,
            entryAndCleanup = true,
            serverUpdateMasked = true,
        }
    end)
    for _, disconnect in ipairs(cleanup) do
        disconnect()
    end
    for _, instance in ipairs(roots) do
        instance:Destroy()
    end
    assert(ok, result)
    return result
end

return Smoke
