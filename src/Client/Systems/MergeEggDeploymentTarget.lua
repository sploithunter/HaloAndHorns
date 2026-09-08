-- Touch placement targets: visible owned eggs/pads first, then nearby compatible slots.
local Target = {}

function Target.pick(workspace, camera, point, pads, objectives, sourceTier, snapPixels)
    if not camera then
        return nil
    end
    local byTeam, byInstance, included, centers = {}, {}, {}, {}
    for _, pad in ipairs(pads) do
        local teamId = tonumber(pad:GetAttribute("MergeEggDeploymentTeamId"))
        if
            pad:IsA("BasePart")
            and pad:GetAttribute("MergeEggDeploymentAvailable") == true
            and teamId
        then
            byTeam[teamId] = pad
            byInstance[pad] = pad
            centers[pad] = { pad.Position }
            included[#included + 1] = pad
        end
    end
    for _, objective in ipairs(objectives) do
        local pad = byTeam[tonumber(objective:GetAttribute("MergeEggTeamId"))]
        if
            pad
            and objective:IsA("Model")
            and objective:GetAttribute("MergeEggObjective") == true
        then
            byInstance[objective] = pad
            table.insert(centers[pad], objective:GetPivot().Position)
            included[#included + 1] = objective
        end
    end
    if #included == 0 then
        return nil
    end
    local ray = camera:ScreenPointToRay(point.X, point.Y)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Include
    params.FilterDescendantsInstances = included
    local hit = workspace:Raycast(ray.Origin, ray.Direction * 1000, params)
    local instance = hit and hit.Instance
    while instance do
        if byInstance[instance] then
            return byInstance[instance]
        end
        instance = instance.Parent
    end

    -- A near miss may snap only to an empty or matching-tier slot. Measure in screen
    -- pixels so a distant, foreshortened floor pad is still practical to tap on a phone.
    local nearest, nearestDistance, nearestDepth, nearestTeam = nil, math.huge, math.huge, math.huge
    for teamId, pad in pairs(byTeam) do
        local tier = tonumber(pad:GetAttribute("MergeEggDeploymentTier")) or 0
        if tier == 0 or tier == sourceTier then
            for _, center in ipairs(centers[pad]) do
                local projected, visible = camera:WorldToScreenPoint(center)
                if visible and projected.Z > 0 then
                    local distance =
                        Vector2.new(projected.X - point.X, projected.Y - point.Y).Magnitude
                    if
                        distance <= snapPixels
                        and (
                            distance < nearestDistance
                            or distance == nearestDistance
                                and (projected.Z < nearestDepth or projected.Z == nearestDepth and teamId < nearestTeam)
                        )
                    then
                        nearest, nearestDistance, nearestDepth, nearestTeam =
                            pad, distance, projected.Z, teamId
                    end
                end
            end
        end
    end
    return nearest
end

return Target
