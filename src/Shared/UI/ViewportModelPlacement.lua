--[[
    ViewportModelPlacement

    Positions a model at the viewport origin without resetting its authored
    rotation. AssetPreloadService has already applied each pet's configured
    asset_transform orientation; card renderers must preserve it.
]]

local ViewportModelPlacement = {}

function ViewportModelPlacement.centerPreservingOrientation(model)
    if not model or not model:IsA("Model") then
        return false
    end

    local boundingBox = model:GetBoundingBox()
    local pivot = model:GetPivot()
    model:PivotTo(CFrame.new(-boundingBox.Position) * pivot)
    return true
end

return ViewportModelPlacement
