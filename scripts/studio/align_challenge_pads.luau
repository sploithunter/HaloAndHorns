-- Edit-mode: sit Range / Training Ground MissionDoor pads on their gate
-- visuals. The E-prompt parents to the pad; a rotated arch leaves the old
-- pad hanging in empty space. Does not move signs.

local ChangeHistoryService = game:GetService("ChangeHistoryService")

local hall = workspace:FindFirstChild("Maps") and workspace.Maps:FindFirstChild("FuturePath")
assert(hall, "Workspace.Maps.FuturePath is required")

local function findNamed(name)
    return hall:FindFirstChild(name, true)
end

local function align(padName, visualName)
    local pad = findNamed(padName)
    local visual = findNamed(visualName)
    if not (pad and pad:IsA("BasePart") and visual) then
        return {
            name = padName,
            ok = false,
            reason = (not pad and "missing pad") or (not visual and "missing visual") or "pad not a BasePart",
        }
    end
    local gate = visual:IsA("Model") and visual:GetPivot() or visual.CFrame
    local look = Vector3.new(gate.LookVector.X, 0, gate.LookVector.Z)
    if look.Magnitude < 0.05 then
        look = Vector3.new(0, 0, -1)
    else
        look = look.Unit
    end
    local pos = Vector3.new(gate.Position.X, 0.8, gate.Position.Z)
    local before = pad.CFrame
    pad.CFrame = CFrame.lookAt(pos, pos + look)
    return {
        name = padName,
        ok = true,
        from = { x = before.X, z = before.Z },
        to = { x = pos.X, z = pos.Z },
    }
end

ChangeHistoryService:SetWaypoint("Align challenge pads")
local placed = {
    align("RangePad", "RangePadGateVisual"),
    align("TrainingGroundPad", "TrainingGroundPadGateVisual"),
}
ChangeHistoryService:SetWaypoint("Challenge pads aligned")
return { ok = true, placed = placed }
