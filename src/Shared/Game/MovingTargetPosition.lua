--[[
    MovingTargetPosition — authoritative position precedence for work targets.

    Moving enemies keep their server authority in EnemyService entry.pos and publish it through
    the model's MoveTarget attribute. Their anchored model pivot is intentionally left at spawn so
    clients can render smooth movement without fighting replicated CFrames. Static breakables do
    not publish MoveTarget and therefore use their ordinary model position.

    Keep this pure: services gather the Vector3 candidates; this module only selects the source.
]]

local MovingTargetPosition = {}

function MovingTargetPosition.resolve(publishedPosition, primaryPosition, pivotPosition)
    return publishedPosition or primaryPosition or pivotPosition
end

return MovingTargetPosition
