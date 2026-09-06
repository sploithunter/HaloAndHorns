-- Isolated Edit test of the production actor classifier and flat enemy visibility.
assert(game:GetService("RunService"):IsStudio(), "Studio diagnostics only")
local systems = game.StarterPlayer.StarterPlayerScripts.Client.Systems
local source = systems.MergeBayPresentation.Source
local first = assert(source:find("        local function evaluate(", 1, true))
local markFirst = assert(source:find("    local function mark(", 1, true))
local markLast = assert(source:find("    RunService.Heartbeat:Connect", markFirst, true))
local last =
    assert(source:find('        local pets = Workspace:FindFirstChild("PlayerPets")', first, true))
local fixtures = Instance.new("Folder")
fixtures.Name = "IsolatedBayPresentationSmoke"
fixtures.Parent = game.ServerStorage
systems.PetAnimator:Clone().Parent = fixtures
local visibilityModule = systems.PetDownedVisibility:Clone()
visibilityModule.Parent = fixtures
local classifier = Instance.new("ModuleScript")
classifier.Source = [[
local Policy = require(game.ReplicatedStorage.Shared.Game.MergePresentationPolicy)
local cfg = require(game.ReplicatedStorage.Configs.merge_egg_prototype).distant_presentation
local bays = {
 {id="heaven",side="heaven",column=1,x=215,z=0},
 {id="hell",side="hell",column=1,x=-215,z=0},
}
local position = Vector3.new(215,0,0)
local focus = bays[1]
local summaries = {}
local hidden = {}
local Workspace = workspace
]] .. source:sub(markFirst, markLast - 1) .. source:sub(first, last - 1) .. "\nreturn evaluate"
classifier.Parent = fixtures
local root = Instance.new("Folder")
root.Name = "IsolatedBayPresentationActors"
root.Parent = workspace
local model = Instance.new("Model")
local part = Instance.new("Part")
part.Anchored = true
part.CanCollide = false
part.CanQuery = false
part.CastShadow = false
part.Transparency = 1
part.Position = Vector3.new(0, -50000, 0)
part.Parent = model
model.Parent = root
model:SetAttribute("NpcCombatPosition", Vector3.new(-215, 0, 0))
local stop
local ok, result = pcall(function()
    local evaluate = require(classifier)
    evaluate(model, false, true)
    assert(model:GetAttribute("MergePresentationHidden"), "offline personal squad not classified")
    stop = require(visibilityModule).bind(root, true)
    assert(part.LocalTransparencyModifier == 1, "existing direct-child enemy not hidden")
    evaluate(model, true, true)
    task.wait()
    assert(part.LocalTransparencyModifier == 0, "own squad not restored")
    assert(
        (model:GetPivot().Position - model:GetAttribute("NpcCombatPosition")).Magnitude < 0.001,
        "re-entry resumed at stale pose"
    )
    evaluate(model, false, false)
    assert(not model:GetAttribute("MergePresentationHidden"), "non-Merge actor hidden")
    stop()
    stop = nil
    return "PASS: offline personal squad classification, own/non-Merge exclusions, existing direct-child visibility and restore"
end)
if stop then
    stop()
end
root:Destroy()
fixtures:Destroy()
assert(ok, result)
return result
