-- Isolated Client fixture. No live pets, profiles, or world presentation are modified.
local Players = game:GetService("Players")
local Visibility = require(Players.LocalPlayer.PlayerScripts.Client.Systems.PetDownedVisibility)
local root = Instance.new("Folder")
local folder = Instance.new("Folder")
folder.Parent = root
local model = Instance.new("Model")
model.Parent = folder
local part = Instance.new("Part")
part.LocalTransparencyModifier = 0.25
part.Parent = model
local label = Instance.new("BillboardGui")
label.Enabled = false
label.Parent = part
local stop = Visibility.bind(root)
local ok, result = pcall(function()
    assert(
        part.LocalTransparencyModifier == 0.25 and not label.Enabled,
        "healthy state overwritten"
    )
    model:SetAttribute("CombatDowned", true)
    task.wait()
    assert(part.LocalTransparencyModifier == 1 and not label.Enabled, "downed pet visible")
    local added = Instance.new("Part")
    added.Parent = model
    task.wait()
    assert(added.LocalTransparencyModifier == 1, "late part visible")
    label.Enabled = true
    task.wait()
    assert(not label.Enabled, "external billboard write escaped downed override")
    added.Parent = nil
    task.wait()
    assert(added.LocalTransparencyModifier == 0, "detached part retains downed override")
    added:Destroy()
    model:SetAttribute("CombatDowned", false)
    task.wait()
    assert(
        part.LocalTransparencyModifier == 0.25 and label.Enabled,
        "revive lost normal presentation state"
    )
    local emitter = Instance.new("ParticleEmitter")
    emitter.Enabled = true
    emitter.Parent = part
    model:SetAttribute("MergePresentationHidden", true)
    task.wait()
    assert(
        part.LocalTransparencyModifier == 1 and not label.Enabled and not emitter.Enabled,
        "distant pet leaked visuals"
    )
    model:SetAttribute("CombatDowned", true)
    model:SetAttribute("MergePresentationHidden", nil)
    task.wait()
    assert(
        part.LocalTransparencyModifier == 1 and not emitter.Enabled,
        "approaching revived a downed pet"
    )
    model:SetAttribute("CombatDowned", false)
    task.wait()
    assert(
        part.LocalTransparencyModifier == 0.25 and label.Enabled and emitter.Enabled,
        "nearby revival did not restore visuals"
    )
    model:SetAttribute("CombatDowned", true)
    task.wait()
    model.Parent = nil
    task.wait()
    assert(
        part.LocalTransparencyModifier == 0.25 and label.Enabled,
        "removed model did not clean up"
    )
    model.Parent = folder
    task.wait()
    assert(
        part.LocalTransparencyModifier == 1 and not label.Enabled,
        "reparented downed model visible"
    )
    stop()
    assert(
        part.LocalTransparencyModifier == 0.25 and label.Enabled,
        "binding disposal did not restore"
    )
    return "PASS: healthy/downed/distant/revive, effects, late descendants, external billboard writes, removal/reparent and disposal"
end)
stop()
model:Destroy()
root:Destroy()
assert(ok, result)
return result
