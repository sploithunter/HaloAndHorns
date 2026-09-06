-- Isolated Client pool lifecycle; no live drops or ownership changes.
local Players = game:GetService("Players")
local Visibility = require(Players.LocalPlayer.PlayerScripts.Client.Systems.DropVisibility)
local folder = Instance.new("Folder")
local model = Instance.new("Model")
local part = Instance.new("Part")
part.Parent = model
local light = Instance.new("PointLight")
light.Parent = part
model:SetAttribute("DropOwner", 1)
model.Parent = folder
local stop = Visibility.bind(folder, 1)
local ok, result = pcall(function()
    for _ = 1, 20 do
        model:SetAttribute("DropOwner", 2)
        task.wait()
        assert(part.LocalTransparencyModifier == 1 and not light.Enabled, "foreign pickup visible")
        model.Parent = nil
        task.wait()
        model:SetAttribute("DropOwner", 1)
        task.wait()
        assert(part.LocalTransparencyModifier == 1, "detached pickup still watched")
        model.Parent = folder
        task.wait()
        assert(
            part.LocalTransparencyModifier == 0 and light.Enabled,
            "pooled pickup did not refresh"
        )
    end
    local added = Instance.new("Part")
    model:SetAttribute("DropOwner", 2)
    added.Parent = model
    task.wait()
    assert(added.LocalTransparencyModifier == 1, "late descendant not hidden")
    local bare = Instance.new("Part")
    bare:SetAttribute("DropOwner", 2)
    bare.Parent = folder
    task.wait()
    assert(bare.LocalTransparencyModifier == 1, "bare-part pickup not hidden")
    stop()
    model:SetAttribute("DropOwner", 1)
    task.wait()
    assert(part.LocalTransparencyModifier == 1, "disposed binding still active")
    return "PASS: 20 pool cycles, owner changes, detach cleanup, late parts, bare parts, disposal"
end)
stop()
model:Destroy()
folder:Destroy()
assert(ok, result)
return result
