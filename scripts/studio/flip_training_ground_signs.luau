-- Edit-mode: yaw the Training Ground gate signs 180° in place.
-- Range faces +X (east, into the field). TG is on the far side of the
-- same field, so the same yaw shows the back of the wood. Do not rotate
-- the Range pair.

local ChangeHistoryService = game:GetService("ChangeHistoryService")

local tile07 = workspace.Maps.FuturePath.Tiles.Tile07_corner
local names = { "TrainingGroundGuide", "TrainingGroundLeaderboard" }
local yaw = CFrame.Angles(0, math.pi, 0)

ChangeHistoryService:SetWaypoint("Flip Training Ground signs")
local out = {}
for _, name in ipairs(names) do
    local model = tile07:FindFirstChild(name)
    if not (model and model:IsA("Model")) then
        table.insert(out, { name = name, ok = false, reason = "missing" })
    else
        local before = model:GetPivot()
        model:PivotTo(before * yaw)
        local after = model:GetPivot()
        table.insert(out, {
            name = name,
            ok = true,
            look_before = { before.LookVector.X, before.LookVector.Z },
            look_after = { after.LookVector.X, after.LookVector.Z },
        })
    end
end
ChangeHistoryService:SetWaypoint("Training Ground signs flipped")
return { ok = true, signs = out }
